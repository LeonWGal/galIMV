#include "gallery_model.h"
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QRegularExpression>
#include <QMutexLocker>
#include <QSettings>
#include <QStandardPaths>
#include <QCryptographicHash>
#include <QDataStream>
#include <QSet>
#include <QProcess>
#include <QDesktopServices>
#include <QUrl>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QLocale>
#include <algorithm>
#include <QtConcurrent>
#include <QSaveFile>
#include <QTemporaryDir>
#include <QCollator>

#if defined(Q_OS_WIN)
#include <windows.h>
#include <shlobj.h>
#endif

namespace {
QString formatBytes(qint64 bytes) {
    if (bytes < 1024) return QString::number(bytes) + " B";
    qreal kb = bytes / 1024.0;
    if (kb < 1024.0) return QString::number(kb, 'f', 1) + " KB";
    qreal mb = kb / 1024.0;
    if (mb < 1024.0) return QString::number(mb, 'f', 1) + " MB";
    qreal gb = mb / 1024.0;
    return QString::number(gb, 'f', 2) + " GB";
}
}

// ================= ScannerWorker =================
ScannerWorker::ScannerWorker(const QString& rootPath, const QHash<QString, CachedFileInfo>& existingCache, QObject* parent)
    : QThread(parent)
    , m_rootPath(rootPath)
    , m_existingCache(existingCache)
{
}

void ScannerWorker::cancel()
{
    m_cancelRequested = true;
}

void ScannerWorker::run()
{
    QList<ImageMetadata> cachedImages;
    if (m_loadCache && GalleryModel::loadCache(m_rootPath, cachedImages) && !m_cancelRequested) {
        for (const auto& item : cachedImages)
            m_existingCache[item.filePath] = {item.fileSize, item.modifiedDate.toMSecsSinceEpoch(),
                                             item.sidecarSize, item.sidecarModifiedMSecs};
        emit cacheReady(cachedImages);
    }
    QStringList nameFilters;
    nameFilters << "*.png" << "*.jpg" << "*.jpeg" << "*.webp" << "*.bmp" << "*.jfif";

    // Fast pass: collect file paths upfront for accurate, smooth progress calculation
    QStringList allFilePaths;
    QSet<QString> diskPaths;
    {
        QDirIterator itFast(m_rootPath, nameFilters, QDir::Files, QDirIterator::Subdirectories);
        while (itFast.hasNext() && !m_cancelRequested) {
            QString p = QDir::cleanPath(QFileInfo(itFast.next()).absoluteFilePath());
            allFilePaths.append(p);
            diskPaths.insert(p);
        }
    }
    int totalFiles = allFilePaths.size();
    if (m_cancelRequested) {
        emit finished(0);
        return;
    }

    // Detect removed files if existing cache was provided
    if (!m_existingCache.isEmpty()) {
        QStringList removed;
        for (auto it = m_existingCache.constBegin(); it != m_existingCache.constEnd(); ++it) {
            if (!diskPaths.contains(it.key())) {
                removed.append(it.key());
            }
        }
        if (!removed.isEmpty() && !m_cancelRequested) {
            emit filesRemoved(removed);
        }
    }

    QList<ImageMetadata> batch;
    batch.reserve(256);
    int totalFound = 0;
    int batchThreshold = 16; // Instant first batch for <30ms paint!

    for (int idx = 0; idx < totalFiles && !m_cancelRequested; ++idx) {
        const QString& filePath = allFilePaths[idx];
        totalFound++;

        QFileInfo fi(filePath);
        bool needRead = true;

        if (m_existingCache.contains(filePath)) {
            const auto& cached = m_existingCache.value(filePath);
            QFileInfo txt(fi.absolutePath() + "/" + fi.completeBaseName() + ".txt");
            if (fi.size() == cached.size && fi.lastModified().toMSecsSinceEpoch() == cached.modifiedMSecs &&
                (txt.exists() ? txt.size() : -1) == cached.sidecarSize &&
                (txt.exists() ? txt.lastModified().toMSecsSinceEpoch() : 0) == cached.sidecarModifiedMSecs) {
                needRead = false; // Unchanged file from persistent cache
            }
        }

        if (needRead) {
            batch.append(MetadataReader::read(filePath, m_rootPath));

            if (batch.size() >= batchThreshold) {
                emit batchFound(batch);
                batch.clear();
                batch.reserve(256);
                if (batchThreshold < 128) {
                    batchThreshold = (batchThreshold == 16) ? 48 : 128;
                }
            }
        }

        if (idx % 60 == 0 || idx == totalFiles - 1) {
            qreal prog = static_cast<qreal>(idx + 1) / static_cast<qreal>(totalFiles);
            QFileInfo fi(filePath);
            emit progress(totalFound, fi.dir().dirName(), prog, totalFiles);
        }
    }

    if (!batch.isEmpty() && !m_cancelRequested) {
        emit batchFound(batch);
    }

    emit finished(totalFiles);
}

// ================= GalleryModel =================
GalleryModel::GalleryModel(TagAutocomplete* tagAuto, QObject* parent)
    : QAbstractListModel(parent)
    , m_tagAuto(tagAuto)
{
    m_subfolderList << "All";
    m_availableModels << "All";
    QSettings settings = galIMVSettings();
    m_sortMode = settings.value("library/sortMode", 0).toInt();
    m_selectedModel = settings.value("library/selectedModel", "All").toString();
    m_groupMode = settings.value("library/groupMode", 0).toInt();

    QString savedLang = settings.value("ui/language", "").toString();
    if (savedLang.isEmpty()) {
        QString sys = QLocale::system().name();
        static const QStringList supported = {
            "en_US", "zh_CN", "ru_RU", "es_ES", "ja_JP",
            "de_DE", "fr_FR", "pt_BR", "ko_KR", "zh_TW",
            "pl_PL", "tr_TR", "it_IT", "uk_UA", "id_ID",
            "vi_VN", "th_TH", "ar_SA", "hi_IN", "nl_NL"
        };
        if (supported.contains(sys)) {
            savedLang = sys;
        } else {
            QString prefix = sys.split('_').first().toLower();
            for (const QString& code : supported) {
                if (code.toLower().startsWith(prefix)) {
                    savedLang = code;
                    break;
                }
            }
        }
        if (savedLang.isEmpty()) savedLang = "en_US";
    }
    loadTranslations(savedLang);

    loadStabilityMatrixModels();
    m_viewTimer.setSingleShot(true);
    m_viewTimer.setInterval(80);
    connect(&m_viewTimer, &QTimer::timeout, this, &GalleryModel::startViewCalculation);
    connect(&m_viewWatcher, &QFutureWatcher<ViewResult>::finished, this, [this]() {
        if (m_runningViewGeneration == m_viewGeneration) applyView(m_viewWatcher.result());
        else startViewCalculation();
    });
    connect(&m_layoutWatcher, &QFutureWatcher<LayoutResult>::finished, this, [this]() {
        if (m_runningLayoutGeneration != m_layoutGeneration) { requestLayout(); return; }
        m_layout = m_layoutWatcher.result();
        setLayoutHeight(m_layout.height);
        updateViewport();
    });
    connect(&m_cacheWatcher, &QFutureWatcher<bool>::finished, this, [this]() {
        if (!m_cacheWatcher.result()) emit operationFailed(tr("Could not save the metadata cache."));
        startCacheSave();
    });
    if (m_tagAuto) connect(m_tagAuto, &TagAutocomplete::csvLoadedChanged, this, &GalleryModel::applyFilter);
}

GalleryModel::~GalleryModel()
{
    m_viewTimer.stop();
    cancelScan();
    for (auto* worker : std::as_const(m_scanners)) {
        disconnect(worker, nullptr, this, nullptr);
        worker->cancel();
        worker->wait();
    }
    m_viewWatcher.waitForFinished();
    m_layoutWatcher.waitForFinished();
    m_cacheWatcher.waitForFinished();
    if (m_cachePending) saveCache(m_pendingCacheRoot, m_pendingCacheImages);
}

int GalleryModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid()) return 0;
    QMutexLocker locker(&m_mutex);
    return m_filteredIndices.size();
}

QVariant GalleryModel::data(const QModelIndex& index, int role) const
{
    QMutexLocker locker(&m_mutex);
    if (!index.isValid() || index.row() < 0 || index.row() >= m_filteredIndices.size())
        return QVariant();

    const ImageMetadata& meta = m_allImages.at(m_filteredIndices.at(index.row()));

    switch (role) {
    case UrlRole:
        return QUrl::fromLocalFile(meta.filePath);
    case FilePathRole:
        return meta.filePath;
    case FileNameRole:
        return meta.fileName;
    case FileSizeRole:
        return formatBytes(meta.fileSize);
    case WidthRole:
        return meta.dimensions.width();
    case HeightRole:
        return meta.dimensions.height();
    case AspectRatioRole:
        return meta.aspectRatio;
    case PromptRole:
        return meta.prompt;
    case NegativePromptRole:
        return meta.negativePrompt;
    case OtherParamsRole:
        return meta.otherParams;
    case ModelNameRole:
        return meta.modelName.isEmpty() ? "Unknown" : meta.modelName;
    case RelativeDirRole:
        return meta.relativeDir;
    case TagsRole:
        return meta.tags;
    case IndexRole:
        return index.row();
    case IsSelectedRole:
        return m_selectedPaths.contains(meta.filePath);
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> GalleryModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[UrlRole] = "url";
    roles[FilePathRole] = "filePath";
    roles[FileNameRole] = "fileName";
    roles[FileSizeRole] = "fileSize";
    roles[WidthRole] = "imgWidth";
    roles[HeightRole] = "imgHeight";
    roles[AspectRatioRole] = "aspectRatio";
    roles[PromptRole] = "prompt";
    roles[NegativePromptRole] = "negativePrompt";
    roles[OtherParamsRole] = "otherParams";
    roles[ModelNameRole] = "modelName";
    roles[RelativeDirRole] = "relativeDir";
    roles[TagsRole] = "tags";
    roles[IndexRole] = "itemIndex";
    roles[IsSelectedRole] = "isSelected";
    return roles;
}

void GalleryModel::setSelectedSubfolder(const QString& folder)
{
    if (m_selectedSubfolder == folder) return;
    m_selectedSubfolder = folder;
    emit selectedSubfolderChanged();
    emit subfolderListChanged();
    applyFilter();
}

QVariantList GalleryModel::subfolderDetails() const
{
    QMutexLocker locker(&m_mutex);
    QVariantList result;

    QVariantMap allMap;
    allMap["name"] = "All";
    allMap["displayName"] = QString::fromUtf8("Все папки (All)");
    allMap["count"] = m_subfolderCounts.value("All", m_allImages.size());
    allMap["isSelected"] = (m_selectedSubfolder == "All");
    result.append(allMap);

    for (const QString& folder : m_subfolderList) {
        if (folder == "All") continue;
        QVariantMap map;
        map["name"] = folder;
        map["displayName"] = folder;
        map["count"] = m_subfolderCounts.value(folder, 0);
        map["isSelected"] = (m_selectedSubfolder == folder);
        result.append(map);
    }
    return result;
}

void GalleryModel::setSelectedModel(const QString& model)
{
    if (m_selectedModel == model) return;
    m_selectedModel = model;
    {
        QSettings settings = galIMVSettings();
        settings.setValue("library/selectedModel", model);
    }
    emit selectedModelChanged();
    applyFilter();
}

void GalleryModel::setSortMode(int mode)
{
    if (mode < 0 || mode > 6 || m_sortMode == mode) return;
    m_sortMode = mode;
    saveSetting("library/sortMode", mode);
    emit sortModeChanged();
    applyFilter();
}

void GalleryModel::setGroupMode(int mode)
{
    if (mode < 0 || mode > 3 || m_groupMode == mode) return;
    m_groupMode = mode;
    saveSetting("library/groupMode", mode);
    emit groupModeChanged();
    applyFilter();
}

void GalleryModel::cancelScan()
{
    ++m_scanGeneration;
    if (m_worker) m_worker->cancel();
    m_worker = nullptr;
    if (m_isLoading) {
        m_isLoading = false;
        emit isLoadingChanged();
    }
}

void GalleryModel::openFolder(const QString& folderPath)
{
    const QString local = folderPath.startsWith("file:") ? QUrl(folderPath).toLocalFile() : folderPath;
    const QString path = QDir::cleanPath(QFileInfo(local).absoluteFilePath());
    if (!QDir(path).exists()) {
        emit operationFailed(tr("Folder not found: %1").arg(path));
        return;
    }
    cancelScan();
    ++m_viewGeneration;
    ++m_layoutGeneration;
    m_viewTimer.stop();
    m_currentFolder = path;
    loadStabilityMatrixModels();
    saveSetting("library/lastFolder", path);
    saveSetting("lastFolder", path);
    beginResetModel();
    m_allImages.clear();
    m_filteredIndices.clear();
    m_pathIndex.clear();
    m_selectedPaths.clear();
    m_lastSelectedAnchor.clear();
    m_selectedImage.clear();
    m_groups.clear();
    m_topTags.clear();
    m_subfolderCounts.clear();
    m_modelCounts.clear();
    m_subfolderList = {"All"};
    m_availableModels = {"All"};
    m_columnCache.clear();
    m_groupColumnCache.clear();
    m_layout = {};
    setLayoutHeight(0);
    m_displayedCount = 120;
    ++m_selectionEpoch;
    endResetModel();
    updateViewport();
    m_isLoading = true;
    m_scanProgress = 0;
    m_scanStatus = tr("Scanning directory tree...");
    emit currentFolderChanged();
    emit isLoadingChanged();
    emit scanProgressChanged();
    emit scanStatusChanged();
    emit countChanged();
    emit selectionChanged();
    emit selectedImageChanged();
    emit subfolderListChanged();
    emit availableModelsChanged();
    emit groupListChanged();
    emit tagsChanged();
    emit displayedCountChanged();

    startScanner(true);
}

void GalleryModel::startScanner(bool readCache)
{
    m_isLoading = true;
    m_scanStatus = tr("Scanning directory tree...");
    emit isLoadingChanged();
    emit scanStatusChanged();
    QHash<QString, ScannerWorker::CachedFileInfo> cache;
    if (!readCache) {
        for (const auto& image : m_allImages)
            cache.insert(image.filePath, {image.fileSize,image.modifiedDate.toMSecsSinceEpoch(),
                                          image.sidecarSize,image.sidecarModifiedMSecs});
    }
    auto* worker = new ScannerWorker(m_currentFolder, cache, this);
    worker->setLoadCache(readCache);
    m_worker = worker;
    m_scanners.insert(worker);
    const auto generation = m_scanGeneration;
    connect(worker, &ScannerWorker::cacheReady, this, [this, generation](const auto& images) {
        if (generation == m_scanGeneration) onBatchFound(images);
    });
    connect(worker, &ScannerWorker::batchFound, this, [this, generation](const auto& batch) {
        if (generation == m_scanGeneration) onBatchFound(batch);
    });
    connect(worker, &ScannerWorker::filesRemoved, this, [this, generation](const auto& paths) {
        if (generation == m_scanGeneration) onFilesRemoved(paths);
    });
    connect(worker, &ScannerWorker::progress, this, [this, generation](int n, const QString& folder, qreal ratio, int total) {
        if (generation == m_scanGeneration) onProgress(n, folder, ratio, total);
    });
    connect(worker, &ScannerWorker::finished, this, [this, generation](int total) {
        if (generation == m_scanGeneration) onScanFinished(total);
    });
    connect(worker, &QThread::finished, this, [this, worker]() {
        m_scanners.remove(worker);
        if (m_worker == worker) m_worker = nullptr;
        worker->deleteLater();
    });
    worker->start();
}

void GalleryModel::onBatchFound(const QList<ImageMetadata>& batch)
{
    for (const auto& item : batch) {
        const int index = m_pathIndex.value(item.filePath, -1);
        if (index >= 0) m_allImages[index] = item;
        else {
            m_pathIndex.insert(item.filePath, m_allImages.size());
            m_allImages.append(item);
        }
    }
    applyFilter();
}

void GalleryModel::onProgress(int count, const QString& currentFolder, qreal progressRatio, int totalFiles)
{
    m_scanProgress = progressRatio;
    m_scanStatus = QString("Indexing: %1 / %2 files (%3%) - %4")
        .arg(count)
        .arg(totalFiles)
        .arg(qRound(progressRatio * 100))
        .arg(currentFolder);
    emit scanProgressChanged();
    emit scanStatusChanged();
}

void GalleryModel::onScanFinished(int)
{
    m_isLoading = false;
    m_scanProgress = 1;
    m_scanStatus = tr("Library indexed: %1 items").arg(m_allImages.size());
    m_viewTimer.stop();
    startViewCalculation();
    requestCacheSave();
    emit isLoadingChanged();
    emit scanProgressChanged();
    emit scanStatusChanged();
}

void GalleryModel::loadMore()
{
    QMutexLocker locker(&m_mutex);
    if (m_displayedCount < m_filteredIndices.size()) {
        m_displayedCount = std::min(m_displayedCount + BatchSize, static_cast<int>(m_filteredIndices.size()));
        m_columnsDirty = true;
        m_groupColumnsDirty = true;
        emit displayedCountChanged();
        emit layoutNeedsRefresh();
    }
}

void GalleryModel::resetDisplayCount()
{
    QMutexLocker locker(&m_mutex);
    m_displayedCount = 120;
    m_columnsDirty = true;
    m_groupColumnsDirty = true;
    emit displayedCountChanged();
    emit layoutNeedsRefresh();
}

void GalleryModel::setSearchQuery(const QString& query)
{
    if (m_positiveQuery == query) return;
    m_positiveQuery = query;
    applyFilter();
}

void GalleryModel::setNegativeFilter(const QString& query)
{
    if (m_negativeQuery == query) return;
    m_negativeQuery = query;
    applyFilter();
}

QList<GalleryModel::QueryTerm> GalleryModel::parseQueryTerms(const QString& query)
{
    QList<QueryTerm> terms;
    QString trimmed = query.trimmed();
    if (trimmed.isEmpty()) return terms;

    QStringList rawList;
    if (trimmed.contains(',')) {
        rawList = trimmed.split(',', Qt::SkipEmptyParts);
    } else {
        static const QRegularExpression wsRegex("\\s+");
        rawList = trimmed.split(wsRegex, Qt::SkipEmptyParts);
    }

    for (const QString& term : rawList) {
        QString clean = term.trimmed();
        while (clean.endsWith(',')) { clean.chop(1); clean = clean.trimmed(); }
        if (clean.contains('\\')) {
            clean.replace(R"(\()", "(")
                 .replace(R"(\))", ")")
                 .replace(R"(\[)", "[")
                 .replace(R"(\])", "]")
                 .replace('\\', "");
            clean = clean.trimmed();
        }
        if (clean.isEmpty()) continue;

        QueryTerm qt;
        qt.clean = clean;
        qt.cleanSpace = clean; qt.cleanSpace.replace('_', ' ');
        qt.cleanUnder = clean; qt.cleanUnder.replace(' ', '_');
        terms.append(qt);
    }
    return terms;
}

bool GalleryModel::matchesFilterFast(const ImageMetadata& meta, const QList<QueryTerm>& posTerms, const QList<QueryTerm>& negTerms, bool isFolderModelFilter, const QString& targetModelFolder) const
{
    // Subfolder filter
    if (m_selectedSubfolder != "All") {
        if (meta.relativeDir != m_selectedSubfolder) {
            return false;
        }
    }

    // Model filter
    if (m_selectedModel != "All") {
        if (isFolderModelFilter) {
            if (getModelFolder(meta.modelName) != targetModelFolder) {
                return false;
            }
        } else {
            if (meta.modelName.compare(m_selectedModel, Qt::CaseInsensitive) != 0) {
                return false;
            }
        }
    }

    // Positive Query / Tags
    for (const auto& term : posTerms) {
        bool termFound = false;
        for (const QString& tag : meta.tags) {
            if (tag.contains(term.clean, Qt::CaseInsensitive) ||
                tag.contains(term.cleanSpace, Qt::CaseInsensitive) ||
                tag.contains(term.cleanUnder, Qt::CaseInsensitive)) {
                termFound = true;
                break;
            }
        }
        if (!termFound) {
            if (meta.prompt.contains(term.clean, Qt::CaseInsensitive) ||
                meta.prompt.contains(term.cleanSpace, Qt::CaseInsensitive) ||
                meta.prompt.contains(term.cleanUnder, Qt::CaseInsensitive) ||
                meta.fileName.contains(term.clean, Qt::CaseInsensitive)) {
                termFound = true;
            }
        }
        if (!termFound) return false;
    }

    // Negative Query / Tags
    for (const auto& term : negTerms) {
        for (const QString& tag : meta.tags) {
            if (tag.contains(term.clean, Qt::CaseInsensitive) ||
                tag.contains(term.cleanSpace, Qt::CaseInsensitive) ||
                tag.contains(term.cleanUnder, Qt::CaseInsensitive)) {
                return false;
            }
        }
        if (meta.prompt.contains(term.clean, Qt::CaseInsensitive) ||
            meta.prompt.contains(term.cleanSpace, Qt::CaseInsensitive) ||
            meta.prompt.contains(term.cleanUnder, Qt::CaseInsensitive) ||
            meta.fileName.contains(term.clean, Qt::CaseInsensitive)) {
            return false;
        }
    }

    return true;
}

bool GalleryModel::matchesFilter(const ImageMetadata& meta) const
{
    bool isFolderModelFilter = false;
    QString targetModelFolder;
    if (m_selectedModel.startsWith("folder:")) {
        isFolderModelFilter = true;
        targetModelFolder = m_selectedModel.mid(7);
    }
    return matchesFilterFast(meta, parseQueryTerms(m_positiveQuery), parseQueryTerms(m_negativeQuery), isFolderModelFilter, targetModelFolder);
}

void GalleryModel::applyFilter()
{
    ++m_viewGeneration;
    if (!m_isFiltering) { m_isFiltering = true; emit isFilteringChanged(); }
    if (m_allImages.size() <= 256) {
        m_viewTimer.stop();
        applyView(computeView(viewSnapshot()));
    } else {
        m_viewTimer.start();
    }
}

GalleryModel::ViewSnapshot GalleryModel::viewSnapshot() const
{
    return {m_allImages, m_positiveQuery, m_negativeQuery, m_selectedSubfolder, m_selectedModel,
            m_sortMode, m_groupMode, m_modelToFolder, m_modelFolderOrder};
}

void GalleryModel::startViewCalculation()
{
    if (m_viewWatcher.isRunning()) return;
    m_runningViewGeneration = m_viewGeneration;
    auto snapshot = viewSnapshot();
    if (snapshot.images.size() <= 256) { applyView(computeView(snapshot)); return; }
    m_viewWatcher.setFuture(QtConcurrent::run([snapshot]() { return computeView(snapshot); }));
}

void GalleryModel::applyView(ViewResult result)
{
    beginResetModel();
    m_filteredIndices = std::move(result.indices);
    m_groups = std::move(result.groups);
    m_subfolderCounts = std::move(result.folderCounts);
    m_modelCounts = std::move(result.modelCounts);
    m_subfolderList = {"All"}; m_subfolderList.append(m_subfolderCounts.keys());
    m_subfolderList.removeDuplicates();
    m_availableModels = {"All"}; m_availableModels.append(m_modelCounts.keys());
    m_topTags = std::move(result.topTags);
    m_columnsDirty = true;
    m_groupColumnsDirty = true;
    m_groupColumnCache.clear();
    m_groupCachedTotalCols.clear();
    if (m_tagAuto) m_tagAuto->replaceLibraryTags(result.libraryTags, result.libraryTagNames);
    reconcileSelection();
    endResetModel();
    m_layout = {};
    setLayoutHeight(0);
    updateViewport();
    m_isFiltering = false;
    emit isFilteringChanged();
    emit selectionChanged();
    emit countChanged();
    emit tagsChanged();
    emit groupListChanged();
    emit subfolderListChanged();
    emit availableModelsChanged();
    emit displayedCountChanged();
    requestLayout();
    emit layoutNeedsRefresh();
}

void GalleryModel::rebuildPathIndex()
{
    m_pathIndex.clear();
    for (int i = 0; i < m_allImages.size(); ++i) m_pathIndex.insert(m_allImages[i].filePath, i);
}

QString GalleryModel::pathAt(int filteredIndex) const
{
    if (filteredIndex < 0 || filteredIndex >= m_filteredIndices.size()) return {};
    int original = m_filteredIndices[filteredIndex];
    return original >= 0 && original < m_allImages.size() ? m_allImages[original].filePath : QString{};
}

int GalleryModel::indexForPath(const QString& path) const
{
    QString local = path.startsWith("file:") ? QUrl(path).toLocalFile() : path;
    local = QDir::cleanPath(QFileInfo(local).absoluteFilePath());
    return m_filteredIndices.indexOf(m_pathIndex.value(local, -1));
}

void GalleryModel::reconcileSelection()
{
    QSet<QString> visible;
    for (int index : m_filteredIndices) visible.insert(m_allImages[index].filePath);
    m_selectedPaths.intersect(visible);
    if (!visible.contains(m_lastSelectedAnchor)) m_lastSelectedAnchor.clear();
    const QString inspected = m_selectedImage.value("filePath").toString();
    int index = inspected.isEmpty() ? -1 : indexForPath(inspected);
    if (index >= 0) {
        const QString anchor = m_lastSelectedAnchor;
        selectImage(index);
        m_lastSelectedAnchor = anchor;
    } else if (!m_selectedImage.isEmpty()) clearSelection();
    ++m_selectionEpoch;
}


GalleryModel::ViewResult GalleryModel::computeView(const ViewSnapshot& snapshot)
{
    ViewResult result;
    const auto posTerms = parseQueryTerms(snapshot.positive), negTerms = parseQueryTerms(snapshot.negative);
    const bool isFolderModelFilter = snapshot.model.startsWith("folder:");
    const QString targetModelFolder = snapshot.model.mid(7);
    auto getModelFolder = [&](const QString& model) {
        return model.isEmpty() ? QString("Unknown") : snapshot.modelToFolder.value(model.toLower(), "Other");
    };
    auto getModelFolderOrder = [&](const QString& model) {
        const auto folder = getModelFolder(model);
        return snapshot.folderOrder.value(folder, folder == "Other" ? 990 : 999);
    };
    auto matches = [&](const ImageMetadata& meta) {

    // Subfolder filter
    if (snapshot.subfolder != "All") {
        if (meta.relativeDir != snapshot.subfolder) {
            return false;
        }
    }

    // Model filter
    if (snapshot.model != "All") {
        if (isFolderModelFilter) {
            if (getModelFolder(meta.modelName) != targetModelFolder) {
                return false;
            }
        } else {
            if (meta.modelName.compare(snapshot.model, Qt::CaseInsensitive) != 0) {
                return false;
            }
        }
    }

    // Positive Query / Tags
    for (const auto& term : posTerms) {
        bool termFound = false;
        for (const QString& tag : meta.tags) {
            if (tag.contains(term.clean, Qt::CaseInsensitive) ||
                tag.contains(term.cleanSpace, Qt::CaseInsensitive) ||
                tag.contains(term.cleanUnder, Qt::CaseInsensitive)) {
                termFound = true;
                break;
            }
        }
        if (!termFound) {
            if (meta.prompt.contains(term.clean, Qt::CaseInsensitive) ||
                meta.prompt.contains(term.cleanSpace, Qt::CaseInsensitive) ||
                meta.prompt.contains(term.cleanUnder, Qt::CaseInsensitive) ||
                meta.fileName.contains(term.clean, Qt::CaseInsensitive)) {
                termFound = true;
            }
        }
        if (!termFound) return false;
    }

    // Negative Query / Tags
    for (const auto& term : negTerms) {
        for (const QString& tag : meta.tags) {
            if (tag.contains(term.clean, Qt::CaseInsensitive) ||
                tag.contains(term.cleanSpace, Qt::CaseInsensitive) ||
                tag.contains(term.cleanUnder, Qt::CaseInsensitive)) {
                return false;
            }
        }
        if (meta.prompt.contains(term.clean, Qt::CaseInsensitive) ||
            meta.prompt.contains(term.cleanSpace, Qt::CaseInsensitive) ||
            meta.prompt.contains(term.cleanUnder, Qt::CaseInsensitive) ||
            meta.fileName.contains(term.clean, Qt::CaseInsensitive)) {
            return false;
        }
    }

    return true;

    };
    QHash<QString, int> filteredTags;
    for (int i = 0; i < snapshot.images.size(); ++i) {
        const auto& image = snapshot.images[i];
        result.folderCounts[image.relativeDir]++;
        if (!image.modelName.isEmpty()) result.modelCounts[image.modelName]++;
        bool match = matches(image);
        if (match) result.indices.append(i);
        for (const auto& raw : image.tags) {
            QString canon = raw.trimmed().toLower(); canon.replace(' ', '_');
            if (canon.isEmpty()) continue;
            if (!result.libraryTags.contains(canon)) {
                result.libraryTags.insert(canon, {raw, MetadataReader::inferTagCategory(raw), 0});
                result.libraryTagNames.append(raw.toLower());
            }
            result.libraryTags[canon].count++;
            if (match) filteredTags[canon]++;
        }
    }
    result.folderCounts["All"] = snapshot.images.size();
    QList<QPair<QString,int>> sorted;
    for (auto it=filteredTags.begin(); it!=filteredTags.end(); ++it) sorted.append({it.key(),it.value()});
    std::sort(sorted.begin(), sorted.end(), [](const auto& a, const auto& b) {
        return a.second == b.second ? a.first < b.first : a.second > b.second;
    });
    for (const auto& pair : sorted) {
        const auto& tag = result.libraryTags[pair.first];
        const QVariantMap item{{"name", tag.name}, {"category", tag.category}, {"count", pair.second},
                               {"color", TagAutocomplete::getCategoryColor(tag.category)}};
        if (result.topTags[-1].size() < 1000) result.topTags[-1].append(item);
        if (result.topTags[tag.category].size() < 1000) result.topTags[tag.category].append(item);
    }

    std::stable_sort(result.indices.begin(), result.indices.end(), [&](int a, int b) {
        const auto& itemA = snapshot.images[a];
        const auto& itemB = snapshot.images[b];

        switch (snapshot.sortMode) {
        case 0: // Date Desc (Newest first)
            return itemA.modifiedDate > itemB.modifiedDate;
        case 1: // Date Asc (Oldest first)
            return itemA.modifiedDate < itemB.modifiedDate;
        case 2: // Name A-Z
            return itemA.fileName.localeAwareCompare(itemB.fileName) < 0;
        case 3: // Name Z-A
            return itemA.fileName.localeAwareCompare(itemB.fileName) > 0;
        case 4: { // Model Name & Stability Matrix folder hierarchy
            int orderA = getModelFolderOrder(itemA.modelName);
            int orderB = getModelFolderOrder(itemB.modelName);
            if (orderA != orderB) {
                return orderA < orderB;
            }
            QString folderA = getModelFolder(itemA.modelName);
            QString folderB = getModelFolder(itemB.modelName);
            if (folderA != folderB) {
                return folderA.localeAwareCompare(folderB) < 0;
            }
            int cmp = itemA.modelName.localeAwareCompare(itemB.modelName);
            if (cmp != 0) return cmp < 0;
            return itemA.modifiedDate > itemB.modifiedDate;
        }
        case 5: // File Size Desc
            return itemA.fileSize > itemB.fileSize;
        case 6: // Resolution Desc (Width * Height)
            return (qint64(itemA.dimensions.width()) * itemA.dimensions.height()) >
                   (qint64(itemB.dimensions.width()) * itemB.dimensions.height());
        default:
            return a < b;
        }
    });


    result.groups.clear();




    if (snapshot.groupMode == 0 || result.indices.isEmpty()) {

        return result;
    }

    if (snapshot.groupMode == 1) { // By Folder
        QMap<QString, QList<int>> folderMap;
        for (int fIdx = 0; fIdx < result.indices.size(); ++fIdx) {
            int origIdx = result.indices[fIdx];
            const auto& meta = snapshot.images[origIdx];
            QString key = meta.relativeDir.trimmed();
            if (key.isEmpty()) key = "Root";
            folderMap[key].append(fIdx);
        }

        int gIdx = 0;
        QStringList keys = folderMap.keys();
        if (keys.contains("Root")) {
            keys.removeAll("Root");
            keys.prepend("Root");
        }

        for (const QString& key : keys) {
            GroupInfo grp;
            grp.id = QString("folder_%1").arg(gIdx);
            grp.key = key;
            grp.title = key;
            grp.groupIndex = gIdx++;
            grp.filteredIndices = folderMap[key];
            result.groups.append(grp);
        }
    } else if (snapshot.groupMode == 2) { // By Model
        QMap<QString, QList<int>> modelMap;
        for (int fIdx = 0; fIdx < result.indices.size(); ++fIdx) {
            int origIdx = result.indices[fIdx];
            const auto& meta = snapshot.images[origIdx];
            QString key = meta.modelName.trimmed();
            if (key.isEmpty()) key = "Unknown";
            modelMap[key].append(fIdx);
        }

        struct ModelGroupItem {
            QString name;
            QString folder;
            int folderOrder;
            QList<int> indices;
        };
        QList<ModelGroupItem> items;
        for (auto it = modelMap.constBegin(); it != modelMap.constEnd(); ++it) {
            ModelGroupItem mitem;
            mitem.name = it.key();
            mitem.folder = getModelFolder(it.key());
            mitem.folderOrder = getModelFolderOrder(it.key());
            mitem.indices = it.value();
            items.append(mitem);
        }

        std::sort(items.begin(), items.end(), [](const ModelGroupItem& a, const ModelGroupItem& b) {
            if (a.folderOrder != b.folderOrder) return a.folderOrder < b.folderOrder;
            if (a.folder != b.folder) return a.folder.localeAwareCompare(b.folder) < 0;
            return a.name.localeAwareCompare(b.name) < 0;
        });

        int gIdx = 0;
        for (const auto& item : items) {
            GroupInfo grp;
            grp.id = QString("model_%1").arg(gIdx);
            grp.key = item.name;
            if (item.folder != "Other" && item.folder != "Unknown") {
                grp.title = QString("%1 / %2").arg(item.folder, item.name);
            } else {
                grp.title = item.name;
            }
            grp.groupIndex = gIdx++;
            grp.filteredIndices = item.indices;
            result.groups.append(grp);
        }
    } else if (snapshot.groupMode == 3) { // By Date
        QMap<QString, QList<int>> dateMap;
        for (int fIdx = 0; fIdx < result.indices.size(); ++fIdx) {
            int origIdx = result.indices[fIdx];
            const auto& meta = snapshot.images[origIdx];
            QString dateKey = meta.modifiedDate.isValid() 
                ? meta.modifiedDate.toString("yyyy-MM-dd") 
                : "Unknown Date";
            dateMap[dateKey].append(fIdx);
        }

        QStringList dates = dateMap.keys();
        std::sort(dates.begin(), dates.end(), [](const QString& a, const QString& b) {
            if (a == "Unknown Date") return false;
            if (b == "Unknown Date") return true;
            return a > b;
        });

        int gIdx = 0;
        for (const QString& d : dates) {
            GroupInfo grp;
            grp.id = QString("date_%1").arg(gIdx);
            grp.key = d;
            grp.title = d;
            grp.groupIndex = gIdx++;
            grp.filteredIndices = dateMap[d];
            result.groups.append(grp);
        }
    }



    // Group headers define the displayed order. Keep row navigation and Shift ranges
    // in that same order, while selection identity remains the file path.
    QList<int> displayed;
    displayed.reserve(result.indices.size());
    for (auto& group : result.groups) {
        group.id = QString::number(snapshot.groupMode) + ":" + group.key;
        for (int& row : group.filteredIndices) {
            const int original = result.indices[row];
            row = displayed.size();
            displayed.append(original);
        }
    }
    result.indices = std::move(displayed);
    return result;
}

void GalleryModel::selectImage(int filteredIndex)
{
    QMutexLocker locker(&m_mutex);
    if (filteredIndex < 0 || filteredIndex >= m_filteredIndices.size()) {
        clearSelection();
        return;
    }

    m_lastSelectedAnchor = pathAt(filteredIndex);
    const ImageMetadata& meta = m_allImages.at(m_filteredIndices.at(filteredIndex));
    m_selectedImage.clear();
    m_selectedImage["url"] = QUrl::fromLocalFile(meta.filePath);
    m_selectedImage["filePath"] = meta.filePath;
    m_selectedImage["fileName"] = meta.fileName;
    m_selectedImage["fileSize"] = formatBytes(meta.fileSize);
    m_selectedImage["dimensions"] = QString("%1 x %2").arg(meta.dimensions.width()).arg(meta.dimensions.height());
    m_selectedImage["aspectRatio"] = meta.aspectRatio;
    m_selectedImage["prompt"] = meta.prompt;
    m_selectedImage["negativePrompt"] = meta.negativePrompt;
    m_selectedImage["otherParams"] = meta.otherParams;
    m_selectedImage["modelName"] = meta.modelName;
    m_selectedImage["relativeDir"] = meta.relativeDir;
    m_selectedImage["tags"] = meta.tags;
    m_selectedImage["filteredIndex"] = filteredIndex;

    emit selectedImageChanged();
}

void GalleryModel::clearSelection()
{
    m_selectedImage.clear();
    emit selectedImageChanged();
}

namespace {
QString localPath(const QString& value) {
    return QDir::cleanPath(QFileInfo(value.startsWith("file:") ? QUrl(value).toLocalFile() : value).absoluteFilePath());
}
QString sidecarPath(const QString& image) {
    const QFileInfo info(image);
    return info.absolutePath() + "/" + info.completeBaseName() + ".txt";
}
bool sharesSidecar(const QString& image) {
    const QFileInfo info(image);
    const auto files = QDir(info.absolutePath()).entryInfoList(QDir::Files);
    const QStringList suffixes{"png","jpg","jpeg","webp","bmp","jfif"};
    for (const auto& other : files) {
        if (other.absoluteFilePath() != info.absoluteFilePath() &&
            other.completeBaseName().compare(info.completeBaseName(), Qt::CaseInsensitive)==0 &&
            suffixes.contains(other.suffix().toLower())) return true;
    }
    return false;
}
bool moveImagePair(const QString& source, const QString& target, QString& error) {
    if (source == target) return true;
    const QString txt = sidecarPath(source), targetTxt = sidecarPath(target);
    const bool hasTxt = QFile::exists(txt);
    const bool shared = hasTxt && sharesSidecar(source);
    if (QFile::exists(target) || (hasTxt && QFile::exists(targetTxt))) {
        error = QObject::tr("A file with this name already exists: %1").arg(target);
        return false;
    }
    if (!QFile::rename(source,target)) {
        error = QObject::tr("Could not move %1 to %2").arg(source,target);
        return false;
    }
    if (hasTxt && !(shared ? QFile::copy(txt,targetTxt) : QFile::rename(txt,targetTxt))) {
        const bool restored = QFile::rename(target,source);
        error = restored ? QObject::tr("Could not move the associated text file: %1. The image was restored.").arg(txt)
                         : QObject::tr("Could not move %1 or restore the image. The image is now at %2.").arg(txt,target);
        return false;
    }
    return true;
}
bool deleteImagePair(const QString& source, bool trash, QString& error) {
    const QFileInfo image(source);
    const QString txt = sidecarPath(source);
    const bool hasTxt = QFile::exists(txt) && !sharesSidecar(source);
    if (trash) {
        if (!QFile::moveToTrash(source)) {
            error = QObject::tr("Could not move the image to the recycle bin: %1").arg(source);
            return false;
        }
        if (hasTxt && !QFile::moveToTrash(txt))
            error = QObject::tr("The image was moved to the recycle bin, but its text file remains at %1").arg(txt);
        return true;
    }
    QTemporaryDir stage(image.absolutePath() + "/.galimv-delete-XXXXXX");
    if (!stage.isValid()) { error = QObject::tr("Could not prepare deletion of %1").arg(source); return false; }
    const QString stagedImage = stage.filePath(image.fileName());
    const QString stagedTxt = stage.filePath(QFileInfo(txt).fileName());
    if (!QFile::rename(source,stagedImage)) {
        error = QObject::tr("Could not delete %1").arg(source); return false;
    }
    stage.setAutoRemove(false);
    if (hasTxt && !QFile::rename(txt,stagedTxt)) {
        const bool restored = QFile::rename(stagedImage,source);
        QDir().rmdir(stage.path());
        error = restored ? QObject::tr("Could not delete the associated text file: %1").arg(txt)
                         : QObject::tr("Deletion failed. The original image remains at %1").arg(stagedImage);
        return false;
    }
    // Disable automatic cleanup: a failed operation must never silently destroy staged originals.
    stage.setAutoRemove(false);
    if (QFile::remove(stagedImage)) {
        if (!hasTxt || QFile::remove(stagedTxt)) { QDir().rmdir(stage.path()); return true; }
        QFile::rename(stagedTxt,txt);
        QDir().rmdir(stage.path());
        error = QObject::tr("The image was deleted, but the associated text file could not be deleted: %1").arg(txt);
        return true; // The caller must remove the deleted image from the library.
    }
    const bool restoredImage = QFile::rename(stagedImage,source);
    const bool restoredText = !hasTxt || QFile::rename(stagedTxt,txt);
    QDir().rmdir(stage.path());
    error = restoredImage && restoredText ? QObject::tr("Deletion failed; the original files were restored: %1").arg(source)
                                         : QObject::tr("Deletion failed. Some original files remain in %1").arg(stage.path());
    return false;
}
}

bool GalleryModel::deleteImage(int filteredIndex, bool useTrash)
{
    return deleteFile(pathAt(filteredIndex),useTrash);
}

bool GalleryModel::deleteFile(const QString& path, bool useTrash)
{
    const QString source = localPath(path);
    if (path.isEmpty() || !m_pathIndex.contains(source)) {
        emit operationFailed(tr("The selected image is no longer in the library."));
        return false;
    }
    m_resumeScan = m_resumeScan || m_isLoading;
    cancelScan();
    QString error;
    bool success = deleteImagePair(source,useTrash,error);
    if (!error.isEmpty()) emit operationFailed(error);
    if (success) {
        m_selectedPaths.remove(source);
        if (m_fileBatch) m_removedPaths.insert(source);
        else {
            beginResetModel();
            m_filteredIndices.clear();
            m_allImages.removeAt(m_pathIndex.value(source));
            endResetModel();
            finishFileChanges();
        }
    } else if (!m_fileBatch) {
        if (!QFile::exists(source)) { m_resumeScan = true; onFilesRemoved({source}); }
        else if (m_resumeScan) finishFileChanges();
    }
    return success;
}

bool GalleryModel::moveImage(int filteredIndex, const QString& destinationFolder)
{
    return moveFile(pathAt(filteredIndex),destinationFolder);
}

bool GalleryModel::moveFile(const QString& path, const QString& destinationFolder)
{
    const QString source = localPath(path), destination = localPath(destinationFolder);
    if (path.isEmpty() || destinationFolder.isEmpty() || !m_pathIndex.contains(source)) {
        emit operationFailed(tr("The selected image or destination is no longer available."));
        return false;
    }
    if (!QDir().mkpath(destination)) {
        emit operationFailed(tr("Could not create destination folder: %1").arg(destination));
        return false;
    }
    m_resumeScan = m_resumeScan || m_isLoading;
    cancelScan();
    QString error;
    const QString target = QDir(destination).filePath(QFileInfo(source).fileName());
    if (!moveImagePair(source,target,error)) {
        emit operationFailed(error);
        if (!QFile::exists(source)) {
            m_resumeScan = true;
            if (m_fileBatch) m_removedPaths.insert(source);
            else onFilesRemoved({source});
        } else if (m_resumeScan && !m_fileBatch) finishFileChanges();
        return false;
    }
    if (source == target) { if (m_resumeScan && !m_fileBatch) finishFileChanges(); return true; }
    if (!m_fileBatch) { beginResetModel(); m_filteredIndices.clear(); }
    int original = m_pathIndex.value(source);
    const QString relative = QDir(m_currentFolder).relativeFilePath(target);
    bool inside = relative != ".." && !relative.startsWith("../") && !QDir::isAbsolutePath(relative);
    if (inside) {
        m_allImages[original] = MetadataReader::read(target,m_currentFolder);
        if (m_selectedPaths.remove(source)) m_selectedPaths.insert(target);
        if (m_lastSelectedAnchor == source) m_lastSelectedAnchor = target;
        if (m_selectedImage.value("filePath").toString()==source) m_selectedImage["filePath"]=target;
    } else {
        if (m_fileBatch) m_removedPaths.insert(source);
        else m_allImages.removeAt(original);
        m_selectedPaths.remove(source);
    }
    if (!m_fileBatch) { endResetModel(); finishFileChanges(); }
    return true;
}

void GalleryModel::finishFileChanges()
{
    ++m_layoutGeneration;
    rebuildPathIndex();
    m_groups.clear();
    m_layout = {}; setLayoutHeight(0);
    updateViewport();
    applyFilter();
    requestCacheSave();
    if (m_resumeScan) {
        m_resumeScan = false;
        const auto generation = m_scanGeneration;
        QTimer::singleShot(0, this, [this, generation]() {
            if (generation == m_scanGeneration && !m_worker && !m_currentFolder.isEmpty()) startScanner(false);
        });
    }
}


void GalleryModel::setViewport(qreal top, qreal height, qreal width, int columns, qreal gap, const QVariantMap& collapsed)
{
    if (width <= 0 || height <= 0) return;
    columns = std::clamp(columns,1,32);
    gap = std::clamp(gap,qreal(0),qreal(100));
    bool geometryChanged = m_viewWidth!=width || m_viewColumns!=columns || m_viewGap!=gap || m_collapsedGroups!=collapsed;
    m_viewTop=std::max(qreal(0),top); m_viewHeight=height; m_viewWidth=width;
    m_viewColumns=columns; m_viewGap=gap; m_collapsedGroups=collapsed;
    if (geometryChanged) { ++m_layoutGeneration; requestLayout(); }
    else updateViewport();
}

void GalleryModel::requestLayout()
{
    ++m_layoutGeneration;
    if (m_layoutWatcher.isRunning()) return;
    const auto images=m_allImages;
    const auto indices=m_filteredIndices;
    const auto groups=m_groups;
    const auto collapsed=m_collapsedGroups;
    const int columns=m_viewColumns;
    const qreal width=m_viewWidth, gap=m_viewGap;
    m_runningLayoutGeneration=m_layoutGeneration;
    auto calculate=[images,indices,groups,collapsed,columns,width,gap]() {
        LayoutResult result;
        result.columns.resize(columns);
        const qreal columnWidth=std::max(qreal(1),(width-(columns-1)*gap)/columns);
        qreal offset=0;
        auto append=[&](const QList<int>& rows) {
            QVector<qreal> heights(columns,offset);
            for (int row : rows) {
                if (row<0 || row>=indices.size()) continue;
                const auto& image=images[indices[row]];
                auto min=std::min_element(heights.begin(),heights.end());
                int col=std::distance(heights.begin(),min);
                qreal height=std::max(qreal(60),columnWidth/std::max(qreal(0.01),image.aspectRatio));
                result.columns[col].append({row,col*(columnWidth+gap),*min,columnWidth,height});
                *min+=height+gap;
            }
            offset=*std::max_element(heights.begin(),heights.end());
        };
        if (groups.isEmpty()) {
            QList<int> rows; rows.reserve(indices.size());
            for (int i=0;i<indices.size();++i) rows.append(i);
            append(rows);
        } else {
            for (const auto& group : groups) {
                offset+=12;
                result.headers.append(QVariantMap{{"id",group.id},{"key",group.key},{"title",group.title},
                    {"count",group.filteredIndices.size()},{"groupIndex",group.groupIndex},{"headerY",offset}});
                offset+=46;
                if (!collapsed.value(group.id).toBool()) append(group.filteredIndices);
                offset+=20;
            }
        }
        result.height=offset+60;
        return result;
    };
    if (indices.size()<=256) {
        m_layout=calculate(); setLayoutHeight(m_layout.height); updateViewport();
    } else {
        m_layoutWatcher.setFuture(QtConcurrent::run(calculate));
    }
}

void GalleryModel::setLayoutHeight(qreal height)
{
    if (m_layoutHeight == height) return;
    m_layoutHeight = height;
    emit layoutHeightChanged();
}

QVariantMap GalleryModel::cardGeometry(int filteredIndex) const
{
    for (const auto& column : m_layout.columns) {
        for (const auto& item : column) {
            if (item.index == filteredIndex)
                return {{"y", item.y}, {"height", item.height}};
        }
    }
    // A collapsed group still provides a visible destination for keyboard navigation.
    for (const auto& group : m_groups) {
        if (!group.filteredIndices.contains(filteredIndex)) continue;
        for (const auto& header : m_layout.headers) {
            const auto info = header.toMap();
            if (info.value("id").toString() == group.id)
                return {{"y", info.value("headerY")}, {"height", 38}, {"groupId", group.id}};
        }
    }
    return {};
}

void GalleryModel::updateViewport()
{
    const qreal first=std::max(qreal(0),m_viewTop-400), last=m_viewTop+m_viewHeight+400;
    QVariantList cards, headers;
    for (const auto& column : m_layout.columns) {
        auto item=std::lower_bound(column.begin(),column.end(),first,[](const LayoutItem& item,qreal top) {
            return item.y+item.height<top;
        });
        for (;item!=column.end() && item->y<=last;++item) {
            if (item->index<0 || item->index>=m_filteredIndices.size()) continue;
            const auto& image=m_allImages[m_filteredIndices[item->index]];
            cards.append(QVariantMap{{"filteredIndex",item->index},{"url",QUrl::fromLocalFile(image.filePath)},
                {"filePath",image.filePath},{"fileName",image.fileName},{"aspectRatio",image.aspectRatio},
                {"imgWidth",image.dimensions.width()},{"imgHeight",image.dimensions.height()},
                {"prompt",image.prompt},{"modelName",image.modelName},{"relativeDir",image.relativeDir},
                {"cardX",item->x},{"cardY",item->y},{"cardWidth",item->width},{"cardHeight",item->height}});
        }
    }
    for (const auto& header : m_layout.headers) {
        qreal y=header.toMap().value("headerY").toReal();
        if (y+38>=first && y<=last) headers.append(header);
    }
    m_visibleCards=std::move(cards);
    m_visibleGroups=std::move(headers);
    emit viewportChanged();
}

void GalleryModel::rebuildColumnCache(int totalColumns) const
{
    m_columnCache.clear();
    m_columnCache.resize(totalColumns);
    m_cachedTotalCols = totalColumns;

    int limit = std::min(m_displayedCount, static_cast<int>(m_filteredIndices.size()));
    QVector<qreal> columnHeights(totalColumns, 0.0);

    for (int i = 0; i < limit; ++i) {
        int originalIdx = m_filteredIndices[i];
        const ImageMetadata& meta = m_allImages[originalIdx];

        int minCol = 0;
        qreal minH = columnHeights[0];
        for (int c = 1; c < totalColumns; ++c) {
            if (columnHeights[c] < minH) {
                minH = columnHeights[c];
                minCol = c;
            }
        }

        qreal relativeH = (meta.aspectRatio > 0.05) ? (1.0 / meta.aspectRatio) : 1.0;

        QVariantMap item;
        item["filteredIndex"] = i;
        item["url"] = QUrl::fromLocalFile(meta.filePath);
        item["filePath"] = meta.filePath;
        item["fileName"] = meta.fileName;
        item["aspectRatio"] = meta.aspectRatio;
        item["imgWidth"] = meta.dimensions.width();
        item["imgHeight"] = meta.dimensions.height();
        item["prompt"] = meta.prompt;
        item["modelName"] = meta.modelName;
        item["relativeDir"] = meta.relativeDir;
        item["isSelected"] = m_selectedPaths.contains(pathAt(i));
        m_columnCache[minCol].append(item);

        columnHeights[minCol] += relativeH;
    }
    m_columnsDirty = false;
}

QVariantList GalleryModel::getMasonryColumn(int colIndex, int totalColumns)
{
    if (totalColumns <= 0 || colIndex < 0 || colIndex >= totalColumns) return QVariantList();

    QMutexLocker locker(&m_mutex);
    if (m_columnsDirty || m_cachedTotalCols != totalColumns) {
        rebuildColumnCache(totalColumns);
    }

    if (colIndex >= 0 && colIndex < m_columnCache.size()) {
        return m_columnCache[colIndex];
    }
    return QVariantList();
}

void GalleryModel::updateSelectionInCache()
{
    for (auto& col : m_columnCache) {
        for (int i = 0; i < col.size(); ++i) {
            QVariantMap map = col[i].toMap();
            int fIdx = map.value("filteredIndex", -1).toInt();
            if (fIdx >= 0) {
                map["isSelected"] = m_selectedPaths.contains(pathAt(fIdx));
                col[i] = map;
            }
        }
    }

    for (auto it = m_groupColumnCache.begin(); it != m_groupColumnCache.end(); ++it) {
        auto& cols = it.value();
        for (auto& col : cols) {
            for (int i = 0; i < col.size(); ++i) {
                QVariantMap map = col[i].toMap();
                int fIdx = map.value("filteredIndex", -1).toInt();
                if (fIdx >= 0) {
                    map["isSelected"] = m_selectedPaths.contains(pathAt(fIdx));
                    col[i] = map;
                }
            }
        }
    }
}

QVariantList GalleryModel::groupList() const
{
    QMutexLocker locker(&m_mutex);
    QVariantList list;
    for (const auto& grp : m_groups) {
        QVariantMap map;
        map["id"] = grp.id;
        map["key"] = grp.key;
        map["title"] = grp.title;
        map["count"] = grp.filteredIndices.size();
        map["groupIndex"] = grp.groupIndex;
        list.append(map);
    }
    return list;
}

QVariantList GalleryModel::getGroupMasonryColumn(int groupIndex, int colIndex, int totalColumns)
{
    if (totalColumns <= 0 || colIndex < 0 || colIndex >= totalColumns) return QVariantList();

    QMutexLocker locker(&m_mutex);
    if (groupIndex < 0 || groupIndex >= m_groups.size()) return QVariantList();

    const auto& grp = m_groups[groupIndex];
    if (m_groupColumnsDirty) {
        m_groupColumnCache.clear();
        m_groupCachedTotalCols.clear();
        m_groupColumnsDirty = false;
    }
    if (!m_groupColumnCache.contains(groupIndex) || m_groupCachedTotalCols.value(groupIndex, -1) != totalColumns) {
        QVector<QVariantList> cols(totalColumns);
        QVector<qreal> colHeights(totalColumns, 0.0);

        for (int fIdx : grp.filteredIndices) {
            if (fIdx >= m_displayedCount) continue;
            if (fIdx < 0 || fIdx >= m_filteredIndices.size()) continue;
            int origIdx = m_filteredIndices[fIdx];
            if (origIdx < 0 || origIdx >= m_allImages.size()) continue;

            const auto& meta = m_allImages[origIdx];
            qreal aspect = meta.aspectRatio > 0.0 ? meta.aspectRatio : 1.0;
            qreal relativeH = 1.0 / aspect;

            int minCol = 0;
            qreal minH = colHeights[0];
            for (int c = 1; c < totalColumns; ++c) {
                if (colHeights[c] < minH) {
                    minH = colHeights[c];
                    minCol = c;
                }
            }

            QVariantMap item;
            item["filteredIndex"] = fIdx;
            item["filePath"] = meta.filePath;
            item["fileName"] = meta.fileName;
            item["url"] = QUrl::fromLocalFile(meta.filePath);
            item["aspectRatio"] = aspect;
            item["imgWidth"] = meta.dimensions.width();
            item["imgHeight"] = meta.dimensions.height();
            item["prompt"] = meta.prompt;
            item["modelName"] = meta.modelName;
            item["relativeDir"] = meta.relativeDir;
            item["isSelected"] = m_selectedPaths.contains(pathAt(fIdx));

            cols[minCol].append(item);
            colHeights[minCol] += relativeH;
        }

        m_groupColumnCache[groupIndex] = cols;
        m_groupCachedTotalCols[groupIndex] = totalColumns;
    }

    if (m_groupColumnCache.contains(groupIndex) && colIndex < m_groupColumnCache[groupIndex].size()) {
        return m_groupColumnCache[groupIndex][colIndex];
    }
    return QVariantList();
}

void GalleryModel::selectGroup(int groupIndex)
{
    {
        QMutexLocker locker(&m_mutex);
        if (groupIndex < 0 || groupIndex >= m_groups.size()) return;
        const auto& grp = m_groups[groupIndex];
        for (int fIdx : grp.filteredIndices) {
            m_selectedPaths.insert(pathAt(fIdx));
            m_lastSelectedAnchor = pathAt(fIdx);
        }
        m_selectionEpoch++;
        updateSelectionInCache();
    }
    emit selectionChanged();
}

void GalleryModel::toggleGroupSelect(int groupIndex)
{
    QString nextInspected;
    bool activeRemoved = false;
    {
        QMutexLocker locker(&m_mutex);
        if (groupIndex < 0 || groupIndex >= m_groups.size()) return;
        const auto& grp = m_groups[groupIndex];
        if (grp.filteredIndices.isEmpty()) return;

        bool allSelected = true;
        for (int fIdx : grp.filteredIndices) {
            if (!m_selectedPaths.contains(pathAt(fIdx))) {
                allSelected = false;
                break;
            }
        }
        if (allSelected) {
            for (int fIdx : grp.filteredIndices) {
                m_selectedPaths.remove(pathAt(fIdx));
            }
            activeRemoved = !m_selectedImage.isEmpty() && !m_selectedPaths.contains(m_selectedImage.value("filePath").toString());
            if (activeRemoved) {
                for (int row = 0; row < m_filteredIndices.size(); ++row) {
                    if (m_selectedPaths.contains(pathAt(row))) { nextInspected = pathAt(row); break; }
                }
            }
        } else {
            for (int fIdx : grp.filteredIndices) {
                m_selectedPaths.insert(pathAt(fIdx));
                m_lastSelectedAnchor = pathAt(fIdx);
            }
        }
        m_selectionEpoch++;
        updateSelectionInCache();
    }
    if (activeRemoved) {
        if (nextInspected.isEmpty()) clearSelection();
        else selectImage(indexForPath(nextInspected));
    }
    emit selectionChanged();
}

bool GalleryModel::isGroupSelected(int groupIndex) const
{
    QMutexLocker locker(&m_mutex);
    if (groupIndex < 0 || groupIndex >= m_groups.size()) return false;
    const auto& grp = m_groups[groupIndex];
    if (grp.filteredIndices.isEmpty()) return false;
    for (int fIdx : grp.filteredIndices) {
        if (!m_selectedPaths.contains(pathAt(fIdx))) return false;
    }
    return true;
}

QVariantList GalleryModel::selectedList() const
{
    QVariantList list;
    for (int i=0; i<m_filteredIndices.size(); ++i) {
        const QString path = pathAt(i);
        if (!m_selectedPaths.contains(path)) continue;
        const auto& meta = m_allImages[m_filteredIndices[i]];
        list.append(QVariantMap{{"filteredIndex",i},{"filePath",path},{"fileName",meta.fileName},
                                {"url",QUrl::fromLocalFile(path)}});
    }
    return list;
}

void GalleryModel::selectSingle(int filteredIndex)
{
    {
        QMutexLocker locker(&m_mutex);
        m_selectedPaths.clear();
        if (filteredIndex >= 0 && filteredIndex < m_filteredIndices.size()) {
            m_selectedPaths.insert(pathAt(filteredIndex));
            m_lastSelectedAnchor = pathAt(filteredIndex);
        }
        m_selectionEpoch++;
        updateSelectionInCache();
    }
    selectImage(filteredIndex);
    emit selectionChanged();
}

void GalleryModel::toggleSelect(int filteredIndex)
{
    int nextInspectIndex = -1;
    bool wasActiveDeselected = false;
    {
        QMutexLocker locker(&m_mutex);
        if (filteredIndex < 0 || filteredIndex >= m_filteredIndices.size()) return;

        if (m_selectedPaths.contains(pathAt(filteredIndex))) {
            m_selectedPaths.remove(pathAt(filteredIndex));
            if (m_selectedImage.contains("filteredIndex") && 
                m_selectedImage.value("filteredIndex").toInt() == filteredIndex) {
                wasActiveDeselected = true;
                if (!m_selectedPaths.isEmpty()) {
                    nextInspectIndex = indexForPath(*m_selectedPaths.begin());
                }
            }
        } else {
            m_selectedPaths.insert(pathAt(filteredIndex));
            m_lastSelectedAnchor = pathAt(filteredIndex);
            nextInspectIndex = filteredIndex;
        }
        m_selectionEpoch++;
        updateSelectionInCache();
    }
    if (wasActiveDeselected) {
        if (nextInspectIndex >= 0) {
            selectImage(nextInspectIndex);
        } else {
            clearSelection();
        }
    } else if (nextInspectIndex >= 0) {
        selectImage(nextInspectIndex);
    }
    emit selectionChanged();
}

void GalleryModel::rangeSelect(int filteredIndex, bool additive)
{
    QString anchor;
    {
        QMutexLocker locker(&m_mutex);
        if (filteredIndex < 0 || filteredIndex >= m_filteredIndices.size()) return;

        int start = indexForPath(m_lastSelectedAnchor);
        if (start < 0) {
            if (m_selectedImage.contains("filteredIndex")) {
                start = m_selectedImage.value("filteredIndex").toInt();
            } else {
                start = filteredIndex;
            }
        }
        int from = std::min(start, filteredIndex);
        int to = std::max(start, filteredIndex);
        anchor = pathAt(start);
        if (!additive) m_selectedPaths.clear();
        for (int i = from; i <= to; ++i) {
            m_selectedPaths.insert(pathAt(i));
        }
        m_lastSelectedAnchor = anchor;
        m_selectionEpoch++;
        updateSelectionInCache();
    }
    selectImage(filteredIndex);
    m_lastSelectedAnchor = anchor;
    emit selectionChanged();
}

void GalleryModel::selectAll()
{
    {
        QMutexLocker locker(&m_mutex);
        m_selectedPaths.clear();
        for (int i = 0; i < m_filteredIndices.size(); ++i) {
            m_selectedPaths.insert(pathAt(i));
        }
        m_selectionEpoch++;
        updateSelectionInCache();
    }
    emit selectionChanged();
}

void GalleryModel::clearMultiSelection()
{
    {
        QMutexLocker locker(&m_mutex);
        m_selectedPaths.clear();
        m_lastSelectedAnchor.clear();
        m_selectionEpoch++;
        updateSelectionInCache();
    }
    clearSelection();
    emit selectionChanged();
}

bool GalleryModel::isIndexSelected(int filteredIndex) const
{
    QMutexLocker locker(&m_mutex);
    return m_selectedPaths.contains(pathAt(filteredIndex));
}

bool GalleryModel::isPathSelected(const QString& path) const
{
    QMutexLocker locker(&m_mutex);
    return m_selectedPaths.contains(path);
}

int GalleryModel::deleteSelected(bool useTrash)
{
    return deleteFiles(m_selectedPaths.values(),useTrash);
}

int GalleryModel::moveSelected(const QString& destinationFolder)
{
    return moveFiles(m_selectedPaths.values(),destinationFolder);
}

int GalleryModel::deleteFiles(const QStringList& paths, bool useTrash)
{
    if (paths.isEmpty()) return 0;
    beginResetModel();
    m_filteredIndices.clear();
    m_fileBatch = true;
    int count = 0;
    for (const auto& path : paths) {
        if (m_removedPaths.contains(localPath(path))) continue;
        if (deleteFile(path,useTrash)) ++count;
    }
    m_fileBatch = false;
    m_allImages.removeIf([this](const auto& image) { return m_removedPaths.contains(image.filePath); });
    m_removedPaths.clear();
    endResetModel();
    finishFileChanges();
    return count;
}

int GalleryModel::moveFiles(const QStringList& paths, const QString& destinationFolder)
{
    if (paths.isEmpty()) return 0;
    beginResetModel();
    m_filteredIndices.clear();
    m_fileBatch = true;
    int count = 0;
    for (const auto& path : paths) {
        if (m_removedPaths.contains(localPath(path))) continue;
        if (moveFile(path,destinationFolder)) ++count;
    }
    m_fileBatch = false;
    m_allImages.removeIf([this](const auto& image) { return m_removedPaths.contains(image.filePath); });
    m_removedPaths.clear();
    endResetModel();
    finishFileChanges();
    return count;
}

void GalleryModel::revealInExplorer(const QString& filePath)
{
    QString path = filePath;
    if (path.startsWith("file:", Qt::CaseInsensitive)) {
        path = QUrl(path).toLocalFile();
    }
    path = QDir::toNativeSeparators(path);
    if (!QFileInfo::exists(path)) return;

#if defined(Q_OS_WIN)
    PIDLIST_ABSOLUTE pidl = ILCreateFromPathW(reinterpret_cast<PCWSTR>(path.utf16()));
    if (pidl) {
        HRESULT hr = SHOpenFolderAndSelectItems(pidl, 0, nullptr, 0);
        ILFree(pidl);
        if (SUCCEEDED(hr)) {
            return;
        }
    }
    QFileInfo fi(path);
    QString folder = fi.isDir() ? fi.absoluteFilePath() : fi.absolutePath();
    QDesktopServices::openUrl(QUrl::fromLocalFile(folder));
#elif defined(Q_OS_MAC)
    QStringList args;
    args << "-e" << QString("tell application \"Finder\" to reveal POSIX file \"%1\"").arg(path);
    args << "-e" << "tell application \"Finder\" to activate";
    QProcess::startDetached("osascript", args);
#else
    QFileInfo fi(path);
    QDesktopServices::openUrl(QUrl::fromLocalFile(fi.absolutePath()));
#endif
}

void GalleryModel::revealSelectedInExplorer()
{
    QString path = m_selectedImage.value("filePath").toString();
    if (path.isEmpty() && !m_selectedPaths.isEmpty()) path = *m_selectedPaths.begin();
    if (!path.isEmpty()) revealInExplorer(path);
}

void GalleryModel::revealIndexInExplorer(int filteredIndex)
{
    QString fp;
    {
        QMutexLocker locker(&m_mutex);
        if (filteredIndex >= 0 && filteredIndex < m_filteredIndices.size()) {
            int origIdx = m_filteredIndices[filteredIndex];
            if (origIdx >= 0 && origIdx < m_allImages.size()) {
                fp = m_allImages[origIdx].filePath;
            }
        }
    }
    if (!fp.isEmpty()) {
        revealInExplorer(fp);
    }
}

QVariantList GalleryModel::getFilteredTopTags(int category, int limit) const
{
    const auto items = m_topTags.value(category);
    return items.mid(0, std::max(0, limit));
}

QString GalleryModel::lastFolder() const
{
    QSettings settings = galIMVSettings();
    return settings.value("library/lastFolder", settings.value("lastFolder")).toString();
}

void GalleryModel::saveSetting(const QString& key, const QVariant& value)
{
    QSettings settings = galIMVSettings();
    settings.setValue(key, value);
}

QVariant GalleryModel::loadSetting(const QString& key, const QVariant& defaultValue) const
{
    QSettings settings = galIMVSettings();
    return settings.value(key, defaultValue);
}

void GalleryModel::refreshLayout()
{
    {
        QMutexLocker locker(&m_mutex);
        m_columnsDirty = true;
        m_groupColumnsDirty = true;
    }
    emit layoutNeedsRefresh();
}

void GalleryModel::onFilesRemoved(const QStringList& removedPaths)
{
    const QSet<QString> removed(removedPaths.begin(), removedPaths.end());
    beginResetModel();
    m_filteredIndices.clear();
    m_allImages.removeIf([&](const auto& image) { return removed.contains(image.filePath); });
    endResetModel();
    finishFileChanges();
}

QVariantList GalleryModel::availableModelDetails() const
{
    QMutexLocker locker(&m_mutex);
    QVariantList result;

    // "All" entry
    QVariantMap allMap;
    allMap["name"] = "All";
    allMap["displayName"] = QString("All (%1)").arg(m_allImages.size());
    allMap["count"] = m_allImages.size();
    allMap["folder"] = "";
    allMap["folderOrder"] = 0;
    allMap["isSelected"] = (m_selectedModel == "All");
    result.append(allMap);

    struct ModelRow {
        QString name;
        QString folder;
        int folderOrder;
        int count;
    };
    QList<ModelRow> rows;

    for (auto it = m_modelCounts.constBegin(); it != m_modelCounts.constEnd(); ++it) {
        const QString& model = it.key();
        if (model.isEmpty() || model == "All") continue;
        ModelRow row;
        row.name = model;
        row.folder = getModelFolder(model);
        row.folderOrder = getModelFolderOrder(model);
        row.count = it.value();
        rows.append(row);
    }

    std::sort(rows.begin(), rows.end(), [](const ModelRow& a, const ModelRow& b) {
        if (a.folderOrder != b.folderOrder) return a.folderOrder < b.folderOrder;
        if (a.folder != b.folder) return a.folder.localeAwareCompare(b.folder) < 0;
        return a.name.localeAwareCompare(b.name) < 0;
    });

    for (const auto& row : rows) {
        QVariantMap map;
        map["name"] = row.name;
        if (row.folder != "Other" && row.folder != "Unknown") {
            map["displayName"] = QString("%1 / %2 (%3)").arg(row.folder, row.name).arg(row.count);
        } else {
            map["displayName"] = QString("%1 (%2)").arg(row.name).arg(row.count);
        }
        map["folder"] = row.folder;
        map["folderOrder"] = row.folderOrder;
        map["count"] = row.count;
        map["isSelected"] = (m_selectedModel == row.name);
        result.append(map);
    }

    return result;
}

QString GalleryModel::getCacheFilePath(const QString& rootPath)
{
    QString baseDir = qEnvironmentVariable("GALIMV_CACHE_DIR");
    if (baseDir.isEmpty()) baseDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (baseDir.isEmpty()) {
        baseDir = QDir::homePath() + "/.galIMV";
    }
    QDir dir(baseDir + "/cache");
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    QByteArray hash = QCryptographicHash::hash(rootPath.toUtf8(), QCryptographicHash::Md5).toHex();
    return dir.filePath(QString("meta_cache_%1.bin").arg(QString::fromLatin1(hash)));
}

bool GalleryModel::saveCache(const QString& rootPath, const QList<ImageMetadata>& images)
{
    if (rootPath.isEmpty()) return false;
    QSaveFile file(getCacheFilePath(rootPath));
    if (!file.open(QIODevice::WriteOnly)) return false;
    QDataStream stream(&file);
    stream.setVersion(QDataStream::Qt_6_5);
    stream << quint32(0x47414C49) << quint32(2) << rootPath << qint64(images.size());
    for (const auto& image : images) {
        stream << image;
        if (stream.status() != QDataStream::Ok) { file.cancelWriting(); return false; }
    }
    return stream.status() == QDataStream::Ok && file.commit();
}

bool GalleryModel::loadCache(const QString& rootPath, QList<ImageMetadata>& outImages)
{
    outImages.clear();
    QFile file(getCacheFilePath(rootPath));
    if (!file.open(QIODevice::ReadOnly) || file.size() > 512LL * 1024 * 1024) return false;
    QDataStream stream(&file);
    stream.setVersion(QDataStream::Qt_6_5);
    quint32 magic=0, version=0;
    QString root;
    qint64 count=0;
    stream >> magic >> version;
    if (magic != 0x47414C49 || version != 2) return false;
    stream >> root >> count;
    if (stream.status()!=QDataStream::Ok || root!=rootPath || count<0 ||
        count>1000000 || count>file.size()/32) return false;
    QList<ImageMetadata> images;
    QSet<QString> paths;
    images.reserve(count);
    for (qint64 i=0; i<count; ++i) {
        ImageMetadata image;
        stream >> image;
        if (stream.status()!=QDataStream::Ok || image.filePath.isEmpty() || paths.contains(image.filePath))
            return false;
        paths.insert(image.filePath);
        images.append(image);
    }
    if (!stream.atEnd()) return false;
    outImages = std::move(images);
    return true;
}

void GalleryModel::requestCacheSave()
{
    m_pendingCacheRoot = m_currentFolder;
    m_pendingCacheImages = m_allImages;
    m_cachePending = !m_currentFolder.isEmpty();
    startCacheSave();
}

void GalleryModel::startCacheSave()
{
    if (!m_cachePending || m_cacheWatcher.isRunning()) return;
    const auto path = m_pendingCacheRoot;
    const auto images = m_pendingCacheImages;
    m_cachePending = false;
    m_pendingCacheImages.clear();
    m_cacheWatcher.setFuture(QtConcurrent::run([path, images]() { return saveCache(path, images); }));
}

QString GalleryModel::findStabilityMatrixModelsDir() const
{
    QStringList candidates = {
        "T:/StabilityMatrix/Models/StableDiffusion",
        "T:/StabilityMatrix/Models/Stable-diffusion"
    };
    for (const auto& c : candidates) {
        if (QDir(c).exists()) return c;
    }
    if (!m_currentFolder.isEmpty()) {
        QDir cur(m_currentFolder);
        cur.cdUp();
        cur.cdUp();
        QString rel1 = cur.filePath("Models/StableDiffusion");
        if (QDir(rel1).exists()) return rel1;
        QString rel2 = cur.filePath("Models/Stable-diffusion");
        if (QDir(rel2).exists()) return rel2;
    }
    QSettings settings = galIMVSettings();
    QString customPath = settings.value("stabilityMatrix/modelsDir").toString();
    if (!customPath.isEmpty() && QDir(customPath).exists()) return customPath;

    return QString();
}

void GalleryModel::loadStabilityMatrixModels()
{
    m_modelToFolder.clear();
    m_modelFolderOrder.clear();

    QString modelsDir = findStabilityMatrixModelsDir();
    if (modelsDir.isEmpty() || !QDir(modelsDir).exists()) return;

    QDir dir(modelsDir);
    QFileInfoList subdirs = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);

    int order = 1;
    for (const QFileInfo& sinfo : subdirs) {
        QString folderName = sinfo.fileName();
        m_modelFolderOrder[folderName] = order++;

        QDir subDir(sinfo.absoluteFilePath());
        QStringList filters = {"*.safetensors", "*.ckpt", "*.pt"};
        QFileInfoList modelFiles = subDir.entryInfoList(filters, QDir::Files, QDir::Name);
        for (const QFileInfo& mfile : modelFiles) {
            QString baseName = MetadataReader::cleanModelName(mfile.fileName());
            m_modelToFolder[baseName.toLower()] = folderName;
        }
    }
}

QString GalleryModel::getModelFolder(const QString& rawModel) const
{
    if (rawModel.isEmpty()) return "Unknown";
    QString clean = rawModel.toLower();
    if (m_modelToFolder.contains(clean)) {
        return m_modelToFolder.value(clean);
    }
    return "Other";
}

int GalleryModel::getModelFolderOrder(const QString& rawModel) const
{
    QString folder = getModelFolder(rawModel);
    if (m_modelFolderOrder.contains(folder)) {
        return m_modelFolderOrder.value(folder);
    }
    if (folder == "Other") return 990;
    return 999;
}

// ================= Multi-Language Localization System (lobe-i18n) =================

void GalleryModel::flattenJson(const QString& prefix, const QJsonObject& obj, QHash<QString, QString>& outMap)
{
    for (auto it = obj.constBegin(); it != obj.constEnd(); ++it) {
        QString key = prefix.isEmpty() ? it.key() : (prefix + "." + it.key());
        if (it.value().isObject()) {
            flattenJson(key, it.value().toObject(), outMap);
        } else if (it.value().isString()) {
            outMap.insert(key, it.value().toString());
        }
    }
}

void GalleryModel::loadTranslations(const QString& langCode)
{
    // 1. Ensure fallback English cache is populated
    if (m_fallbackEnCache.isEmpty()) {
        QString enPath = "locales/en_US.json";
        QFile enFile(enPath);
        if (!enFile.exists()) {
            enPath = ":/galIMV/locales/en_US.json";
            enFile.setFileName(enPath);
        }
        if (enFile.open(QIODevice::ReadOnly)) {
            QJsonDocument doc = QJsonDocument::fromJson(enFile.readAll());
            if (doc.isObject()) {
                flattenJson("", doc.object(), m_fallbackEnCache);
            }
        }
    }

    // 2. Load requested locale
    QString localePath = QString("locales/%1.json").arg(langCode);
    QFile file(localePath);
    if (!file.exists()) {
        localePath = QString(":/galIMV/locales/%1.json").arg(langCode);
        file.setFileName(localePath);
    }

    m_translationCache.clear();
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        if (doc.isObject()) {
            m_translations = doc.object().toVariantMap();
            flattenJson("", doc.object(), m_translationCache);
        }
    } else {
        m_translationCache = m_fallbackEnCache;
    }

    m_currentLanguage = langCode;
    m_languageEpoch++;
    emit languageChanged();
    emit languageEpochChanged();
}

void GalleryModel::setLanguage(const QString& langCode)
{
    if (m_currentLanguage == langCode) return;
    loadTranslations(langCode);
    saveSetting("ui/language", langCode);
}

QString GalleryModel::t(const QString& key, const QString& fallback) const
{
    if (m_translationCache.contains(key)) {
        return m_translationCache.value(key);
    }
    if (m_fallbackEnCache.contains(key)) {
        return m_fallbackEnCache.value(key);
    }
    return fallback.isEmpty() ? key : fallback;
}

QVariantList GalleryModel::availableLanguages() const
{
    static const QVariantList langs = {
        QVariantMap{{"code", "en_US"}, {"name", "English"}, {"nativeName", "English"}, {"region", "US / Global"}},
        QVariantMap{{"code", "zh_CN"}, {"name", "Chinese (Simplified)"}, {"nativeName", "简体中文"}, {"region", "China"}},
        QVariantMap{{"code", "ru_RU"}, {"name", "Russian"}, {"nativeName", "Русский"}, {"region", "Russia"}},
        QVariantMap{{"code", "es_ES"}, {"name", "Spanish"}, {"nativeName", "Español"}, {"region", "Spain / Latin America"}},
        QVariantMap{{"code", "ja_JP"}, {"name", "Japanese"}, {"nativeName", "日本語"}, {"region", "Japan"}},
        QVariantMap{{"code", "de_DE"}, {"name", "German"}, {"nativeName", "Deutsch"}, {"region", "Germany"}},
        QVariantMap{{"code", "fr_FR"}, {"name", "French"}, {"nativeName", "Français"}, {"region", "France"}},
        QVariantMap{{"code", "pt_BR"}, {"name", "Portuguese (Brazil)"}, {"nativeName", "Português (Brasil)"}, {"region", "Brazil"}},
        QVariantMap{{"code", "ko_KR"}, {"name", "Korean"}, {"nativeName", "한국어"}, {"region", "Korea"}},
        QVariantMap{{"code", "zh_TW"}, {"name", "Chinese (Traditional)"}, {"nativeName", "繁體中文"}, {"region", "Taiwan / Hong Kong"}},
        QVariantMap{{"code", "pl_PL"}, {"name", "Polish"}, {"nativeName", "Polski"}, {"region", "Poland"}},
        QVariantMap{{"code", "tr_TR"}, {"name", "Turkish"}, {"nativeName", "Türkçe"}, {"region", "Turkey"}},
        QVariantMap{{"code", "it_IT"}, {"name", "Italian"}, {"nativeName", "Italiano"}, {"region", "Italy"}},
        QVariantMap{{"code", "uk_UA"}, {"name", "Ukrainian"}, {"nativeName", "Українська"}, {"region", "Ukraine"}},
        QVariantMap{{"code", "id_ID"}, {"name", "Indonesian"}, {"nativeName", "Bahasa Indonesia"}, {"region", "Indonesia"}},
        QVariantMap{{"code", "vi_VN"}, {"name", "Vietnamese"}, {"nativeName", "Tiếng Việt"}, {"region", "Vietnam"}},
        QVariantMap{{"code", "th_TH"}, {"name", "Thai"}, {"nativeName", "ไทย"}, {"region", "Thailand"}},
        QVariantMap{{"code", "ar_SA"}, {"name", "Arabic"}, {"nativeName", "العربية"}, {"region", "Saudi Arabia / MENA"}},
        QVariantMap{{"code", "hi_IN"}, {"name", "Hindi"}, {"nativeName", "हिन्दी"}, {"region", "India"}},
        QVariantMap{{"code", "nl_NL"}, {"name", "Dutch"}, {"nativeName", "Nederlands"}, {"region", "Netherlands"}}
    };
    return langs;
}
