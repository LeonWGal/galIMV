#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>
#include <QRecursiveMutex>
#include <QThread>
#include <QSet>
#include <atomic>
#include <QFutureWatcher>
#include <QTimer>
#include "metadata_reader.h"
#include "tag_autocomplete.h"

class ScannerWorker : public QThread {
    Q_OBJECT
public:
    struct CachedFileInfo {
        qint64 size = 0;
        qint64 modifiedMSecs = 0;
        qint64 sidecarSize = -1;
        qint64 sidecarModifiedMSecs = 0;
    };

    explicit ScannerWorker(const QString& rootPath, const QHash<QString, CachedFileInfo>& existingCache = {}, QObject* parent = nullptr);
    void cancel();
    void setLoadCache(bool enabled) { m_loadCache = enabled; }

signals:
    void cacheReady(const QList<ImageMetadata>& images);
    void batchFound(const QList<ImageMetadata>& batch);
    void filesRemoved(const QStringList& removedPaths);
    void progress(int count, const QString& currentFolder, qreal progressRatio, int totalFiles);
    void finished(int totalCount);

protected:
    void run() override;

private:
    QString m_rootPath;
    QHash<QString, CachedFileInfo> m_existingCache;
    std::atomic<bool> m_cancelRequested{false};
    bool m_loadCache = true;
};

class GalleryModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)
    Q_PROPERTY(qreal scanProgress READ scanProgress NOTIFY scanProgressChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY countChanged)
    Q_PROPERTY(int filteredCount READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int displayedCount READ displayedCount NOTIFY displayedCountChanged)
    Q_PROPERTY(QString currentFolder READ currentFolder NOTIFY currentFolderChanged)
    Q_PROPERTY(QString scanStatus READ scanStatus NOTIFY scanStatusChanged)
    Q_PROPERTY(QVariantMap selectedImage READ selectedImage NOTIFY selectedImageChanged)

    // Multi-selection
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY selectionChanged)
    Q_PROPERTY(QVariantList selectedList READ selectedList NOTIFY selectionChanged)
    Q_PROPERTY(quint64 selectionEpoch READ selectionEpoch NOTIFY selectionChanged)

    // Subfolders & Models for Navigation and Grouping
    Q_PROPERTY(QStringList subfolderList READ subfolderList NOTIFY subfolderListChanged)
    Q_PROPERTY(QVariantList subfolderDetails READ subfolderDetails NOTIFY subfolderListChanged)
    Q_PROPERTY(QString selectedSubfolder READ selectedSubfolder WRITE setSelectedSubfolder NOTIFY selectedSubfolderChanged)
    Q_PROPERTY(QStringList availableModels READ availableModels NOTIFY availableModelsChanged)
    Q_PROPERTY(QVariantList availableModelDetails READ availableModelDetails NOTIFY availableModelsChanged)
    Q_PROPERTY(QString selectedModel READ selectedModel WRITE setSelectedModel NOTIFY selectedModelChanged)
    Q_PROPERTY(int sortMode READ sortMode WRITE setSortMode NOTIFY sortModeChanged)
    Q_PROPERTY(int groupMode READ groupMode WRITE setGroupMode NOTIFY groupModeChanged)
    Q_PROPERTY(QVariantList groupList READ groupList NOTIFY groupListChanged)
    Q_PROPERTY(bool isFiltering READ isFiltering NOTIFY isFilteringChanged)
    Q_PROPERTY(QVariantList visibleCards READ visibleCards NOTIFY viewportChanged)
    Q_PROPERTY(QVariantList visibleGroups READ visibleGroups NOTIFY viewportChanged)
    Q_PROPERTY(qreal layoutHeight READ layoutHeight NOTIFY layoutHeightChanged)

    // Multi-Language Localization System (lobe-i18n)
    Q_PROPERTY(QString currentLanguage READ currentLanguage WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(int languageEpoch READ languageEpoch NOTIFY languageEpochChanged)
    Q_PROPERTY(QVariantMap translations READ translations NOTIFY languageChanged)
    Q_PROPERTY(QVariantList availableLanguages READ availableLanguages CONSTANT)

public:
    enum Roles {
        UrlRole = Qt::UserRole + 1,
        FilePathRole,
        FileNameRole,
        FileSizeRole,
        WidthRole,
        HeightRole,
        AspectRatioRole,
        PromptRole,
        NegativePromptRole,
        OtherParamsRole,
        ModelNameRole,
        RelativeDirRole,
        TagsRole,
        IndexRole,
        IsSelectedRole
    };

    explicit GalleryModel(TagAutocomplete* tagAuto, QObject* parent = nullptr);
    ~GalleryModel() override;

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool isLoading() const { return m_isLoading; }
    qreal scanProgress() const { return m_scanProgress; }
    int totalCount() const { return m_allImages.size(); }
    int displayedCount() const { return m_displayedCount; }
    QString currentFolder() const { return m_currentFolder; }
    QString scanStatus() const { return m_scanStatus; }
    QVariantMap selectedImage() const { return m_selectedImage; }

    int selectedCount() const { return m_selectedPaths.size(); }
    QVariantList selectedList() const;
    quint64 selectionEpoch() const { return m_selectionEpoch; }

    QStringList subfolderList() const { return m_subfolderList; }
    QVariantList subfolderDetails() const;
    QString selectedSubfolder() const { return m_selectedSubfolder; }
    void setSelectedSubfolder(const QString& folder);

    QStringList availableModels() const { return m_availableModels; }
    QVariantList availableModelDetails() const;
    QString selectedModel() const { return m_selectedModel; }
    void setSelectedModel(const QString& model);

    int sortMode() const { return m_sortMode; }
    void setSortMode(int mode);

    int groupMode() const { return m_groupMode; }
    void setGroupMode(int mode);
    QVariantList groupList() const;

    Q_INVOKABLE void openFolder(const QString& folderPath);
    Q_INVOKABLE void cancelScan();
    Q_INVOKABLE void setSearchQuery(const QString& query);
    Q_INVOKABLE void setNegativeFilter(const QString& query);
    Q_INVOKABLE void selectImage(int filteredIndex);
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE void loadMore();
    Q_INVOKABLE void resetDisplayCount();
    
    // Multi-selection operations
    Q_INVOKABLE void selectSingle(int filteredIndex);
    Q_INVOKABLE void toggleSelect(int filteredIndex);
    Q_INVOKABLE void rangeSelect(int filteredIndex, bool additive = false);
    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void clearMultiSelection();
    Q_INVOKABLE bool isIndexSelected(int filteredIndex) const;
    Q_INVOKABLE bool isPathSelected(const QString& path) const;
    Q_INVOKABLE int indexForPath(const QString& path) const;
    Q_INVOKABLE QString pathAt(int filteredIndex) const;
    Q_INVOKABLE bool deleteFile(const QString& path, bool useTrash);
    Q_INVOKABLE bool moveFile(const QString& path, const QString& destinationFolder);
    Q_INVOKABLE void setViewport(qreal top, qreal height, qreal width, int columns, qreal gap, const QVariantMap& collapsedGroups);
    bool isFiltering() const { return m_isFiltering; }
    QVariantList visibleCards() const { return m_visibleCards; }
    Q_INVOKABLE QVariantMap cardGeometry(int filteredIndex) const;
    QVariantList visibleGroups() const { return m_visibleGroups; }
    qreal layoutHeight() const { return m_layoutHeight; }

    // File Management (single & batch)
    Q_INVOKABLE bool deleteImage(int filteredIndex, bool useTrash);
    Q_INVOKABLE bool moveImage(int filteredIndex, const QString& destinationFolder);
    Q_INVOKABLE int deleteSelected(bool useTrash);
    Q_INVOKABLE int moveSelected(const QString& destinationFolder);
    Q_INVOKABLE int deleteFiles(const QStringList& paths, bool useTrash);
    Q_INVOKABLE int moveFiles(const QStringList& paths, const QString& destinationFolder);
    Q_INVOKABLE void revealInExplorer(const QString& filePath);
    Q_INVOKABLE void revealSelectedInExplorer();
    Q_INVOKABLE void revealIndexInExplorer(int filteredIndex);

    // Masonry helper
    Q_INVOKABLE QVariantList getMasonryColumn(int colIndex, int totalColumns);
    Q_INVOKABLE QVariantList getGroupMasonryColumn(int groupIndex, int colIndex, int totalColumns);
    Q_INVOKABLE void selectGroup(int groupIndex);
    Q_INVOKABLE void toggleGroupSelect(int groupIndex);
    Q_INVOKABLE bool isGroupSelected(int groupIndex) const;

    // Dynamic Tag Statistics
    Q_INVOKABLE QVariantList getFilteredTopTags(int category, int limit = 80) const;
    Q_INVOKABLE void refreshLayout();
    bool matchesFilter(const ImageMetadata& meta) const;

    // Persistent Settings Management
    Q_INVOKABLE QString lastFolder() const;
    Q_INVOKABLE void saveSetting(const QString& key, const QVariant& value);
    Q_INVOKABLE QVariant loadSetting(const QString& key, const QVariant& defaultValue = QVariant()) const;

    // Multi-Language Localization System (lobe-i18n)
    QString currentLanguage() const { return m_currentLanguage; }
    int languageEpoch() const { return m_languageEpoch; }
    QVariantMap translations() const { return m_translations; }
    QVariantList availableLanguages() const;
    Q_INVOKABLE void setLanguage(const QString& langCode);
    Q_INVOKABLE QString t(const QString& key, const QString& fallback = QString()) const;

    // Cache persistence
    static QString getCacheFilePath(const QString& rootPath);
    static bool saveCache(const QString& rootPath, const QList<ImageMetadata>& images);
    static bool loadCache(const QString& rootPath, QList<ImageMetadata>& outImages);

signals:
    void operationFailed(const QString& message);
    void isFilteringChanged();
    void viewportChanged();
    void layoutHeightChanged();
    void isLoadingChanged();
    void scanProgressChanged();
    void countChanged();
    void displayedCountChanged();
    void currentFolderChanged();
    void scanStatusChanged();
    void selectedImageChanged();
    void selectionChanged();
    void layoutNeedsRefresh();
    void subfolderListChanged();
    void selectedSubfolderChanged();
    void availableModelsChanged();
    void selectedModelChanged();
    void sortModeChanged();
    void groupModeChanged();
    void groupListChanged();
    void tagsChanged();
    void languageChanged();
    void languageEpochChanged();

private slots:
    void onBatchFound(const QList<ImageMetadata>& batch);
    void onFilesRemoved(const QStringList& removedPaths);
    void onProgress(int count, const QString& currentFolder, qreal progressRatio, int totalFiles);
    void onScanFinished(int totalCount);

private:
    struct QueryTerm {
        QString clean;
        QString cleanSpace;
        QString cleanUnder;
    };

    static QList<QueryTerm> parseQueryTerms(const QString& query);
    void applyFilter();
    bool matchesFilterFast(const ImageMetadata& meta, const QList<QueryTerm>& posTerms, const QList<QueryTerm>& negTerms, bool isFolderModelFilter, const QString& targetModelFolder) const;
    void rebuildColumnCache(int totalColumns) const;
    void updateSelectionInCache();

    // Stability Matrix Model Hierarchy
    QString findStabilityMatrixModelsDir() const;
    void loadStabilityMatrixModels();
    QString getModelFolder(const QString& rawModel) const;
    int getModelFolderOrder(const QString& rawModel) const;

    TagAutocomplete* m_tagAuto = nullptr;
    ScannerWorker* m_worker = nullptr;

    QString m_currentFolder;
    QString m_scanStatus;
    bool m_isLoading = false;
    qreal m_scanProgress = 0.0;

    QString m_positiveQuery;
    QString m_negativeQuery;
    QString m_selectedSubfolder = "All";
    QString m_selectedModel = "All";
    int m_sortMode = 0; // 0: Date Desc, 1: Date Asc, 2: Name A-Z, 3: Name Z-A, 4: Model, 5: Size, 6: Res

    QStringList m_subfolderList;
    QMap<QString, int> m_subfolderCounts;
    QStringList m_availableModels;
    QMap<QString, int> m_modelCounts;
    QMap<QString, QString> m_modelToFolder;
    QMap<QString, int> m_modelFolderOrder;

    QList<ImageMetadata> m_allImages;
    QList<int> m_filteredIndices;
    QSet<QString> m_selectedPaths;
    QString m_lastSelectedAnchor;
    quint64 m_selectionEpoch = 0;

    int m_displayedCount = 120;
    static constexpr int BatchSize = 60;

    mutable QVector<QVariantList> m_columnCache;
    mutable int m_cachedTotalCols = 0;
    mutable bool m_columnsDirty = true;

    struct GroupInfo {
        QString id;
        QString key;
        QString title;
        int groupIndex = 0;
        QList<int> filteredIndices;
    };


    int m_groupMode = 0; // 0: None, 1: Folder, 2: Model, 3: Date
    QList<GroupInfo> m_groups;
    struct ViewResult {
        QList<int> indices;
        QList<GroupInfo> groups;
        QMap<QString, int> folderCounts;
        QMap<QString, int> modelCounts;
        QHash<int, QVariantList> topTags;
        QMap<QString, TagInfo> libraryTags;
        QStringList libraryTagNames;
    };
    struct LayoutItem { int index; qreal x, y, width, height; };
    struct LayoutResult {
        QVector<QVector<LayoutItem>> columns;
        QVariantList headers;
        qreal height = 0;
    };
    struct ViewSnapshot {
        QList<ImageMetadata> images;
        QString positive, negative, subfolder, model;
        int sortMode, groupMode;
        QMap<QString, QString> modelToFolder;
        QMap<QString, int> folderOrder;
    };
    ViewSnapshot viewSnapshot() const;
    static ViewResult computeView(const ViewSnapshot& snapshot);
    void startViewCalculation();
    void applyView(ViewResult result);
    void reconcileSelection();
    void rebuildPathIndex();
    void requestCacheSave();
    void startCacheSave();
    void requestLayout();
    void updateViewport();
    void setLayoutHeight(qreal height);
    void finishFileChanges();
    void startScanner(bool loadCache);
    bool m_resumeScan = false;
    bool m_fileBatch = false;
    QSet<QString> m_removedPaths;
    QHash<QString, int> m_pathIndex;
    QSet<ScannerWorker*> m_scanners;
    quint64 m_scanGeneration = 0;
    quint64 m_viewGeneration = 0;
    quint64 m_runningViewGeneration = 0;
    quint64 m_layoutGeneration = 0;
    quint64 m_runningLayoutGeneration = 0;
    bool m_isFiltering = false;
    QTimer m_viewTimer;
    QFutureWatcher<ViewResult> m_viewWatcher;
    QFutureWatcher<LayoutResult> m_layoutWatcher;
    QFutureWatcher<bool> m_cacheWatcher;
    QString m_pendingCacheRoot;
    QList<ImageMetadata> m_pendingCacheImages;
    bool m_cachePending = false;
    qreal m_viewTop = 0, m_viewHeight = 800, m_viewWidth = 1000, m_viewGap = 0;
    int m_viewColumns = 4;
    QVariantMap m_collapsedGroups;
    LayoutResult m_layout;
    QVariantList m_visibleCards, m_visibleGroups;
    qreal m_layoutHeight = 0;
    QHash<int, QVariantList> m_topTags;
    mutable QHash<int, QVector<QVariantList>> m_groupColumnCache;
    mutable QHash<int, int> m_groupCachedTotalCols;
    mutable bool m_groupColumnsDirty = true;

    QVariantMap m_selectedImage;
    mutable QRecursiveMutex m_mutex;

    void loadTranslations(const QString& langCode);
    void flattenJson(const QString& prefix, const class QJsonObject& obj, QHash<QString, QString>& outMap);

    QString m_currentLanguage = "en_US";
    int m_languageEpoch = 0;
    QVariantMap m_translations;
    QHash<QString, QString> m_translationCache;
    QHash<QString, QString> m_fallbackEnCache;
};
