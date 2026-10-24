#include "tag_autocomplete.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QCoreApplication>
#include <QSettings>
#include <QVariantMap>
#include <QThread>
#include <QtConcurrent>
#include <QUrl>
#include <QMutex>
#include <QMutexLocker>
#include <QRegularExpression>
#include <atomic>
#include <algorithm>
#include <iostream>

static QMutex s_csvMutex;
static std::atomic<bool> s_isLoadingCsv{false};
static std::atomic<quint64> s_csvGeneration{0};

// Static members
QHash<QString, quint8> TagAutocomplete::s_categoryMap;
QHash<QString, int> TagAutocomplete::s_postCounts;
QStringList TagAutocomplete::s_danbooruTagNames;
QString TagAutocomplete::s_currentCsvPath;
bool TagAutocomplete::s_isLoaded = false;

TagAutocomplete::TagAutocomplete(QObject* parent)
    : QObject(parent)
{
    loadDefaults();
    connect(&m_csvWatcher, &QFutureWatcher<bool>::finished, this, [this]() {
        s_isLoadingCsv.store(false);
        if (m_csvWatcher.result()) {
            QSettings settings = galIMVSettings();
            settings.setValue("tags/csvPath", m_loadingPath);
            emit csvLoadedChanged();
            emit csvPathChanged();
            emit tagsUpdated();
        } else {
            emit loadFailed(tr("Could not load the tag dictionary."), "backend.tag_load_failed");
        }
    });
}

TagAutocomplete::~TagAutocomplete()
{
    m_csvWatcher.waitForFinished();
}

bool TagAutocomplete::isCsvLoaded() const
{
    QMutexLocker locker(&s_csvMutex);
    return s_isLoaded;
}

int TagAutocomplete::totalLoadedTags() const
{
    QMutexLocker locker(&s_csvMutex);
    return s_categoryMap.size();
}

QString TagAutocomplete::csvPath() const
{
    QMutexLocker locker(&s_csvMutex);
    return s_currentCsvPath;
}

bool TagAutocomplete::isCsvLoadedStatic()
{
    QMutexLocker locker(&s_csvMutex);
    return s_isLoaded;
}

int TagAutocomplete::totalLoadedTagsStatic()
{
    QMutexLocker locker(&s_csvMutex);
    return s_categoryMap.size();
}

QString TagAutocomplete::getCategoryColor(int category)
{
    switch (category) {
    case 1: return "#f43f5e"; // Artist (rose/red)
    case 3: return "#a855f7"; // Copyright (purple)
    case 4: return "#10b981"; // Character (emerald green)
    case 5: return "#f59e0b"; // Meta / Quality (amber)
    case 0:
    default: return "#38bdf8"; // General (sky blue)
    }
}

QString TagAutocomplete::autoDetectCsvPath()
{
    QSettings settings = galIMVSettings();
    QString savedPath = settings.value("tags/csvPath").toString();
    if (!savedPath.isEmpty() && QFile::exists(savedPath)) {
        return savedPath;
    }

    const QStringList candidatePaths = {
        "T:/StabilityMatrix/Packages/Forge-Neo/extensions/a1111-sd-webui-tagcomplete/tags/danbooru.csv",
        "T:/StabilityMatrix/Tags/danbooru.csv",
        "T:/StabilityMatrix/Tags/danbooru_e621_merged.csv",
        "T:/StabilityMatrix/Packages/Forge Neo/extensions/a1111-sd-webui-tagcomplete/tags/danbooru.csv",
        "T:/StabilityMatrix/Packages/ForgeNeo/extensions/a1111-sd-webui-tagcomplete/tags/danbooru.csv",
        QDir::currentPath() + "/danbooru.csv",
        QCoreApplication::applicationDirPath() + "/danbooru.csv"
    };

    for (const QString& path : candidatePaths) {
        if (QFile::exists(path)) {
            return path;
        }
    }

    return QString();
}

bool TagAutocomplete::autoLoadCsv()
{
    {
        QMutexLocker locker(&s_csvMutex);
        if (s_isLoaded) return true;
    }
    QString path = autoDetectCsvPath();
    if (!path.isEmpty()) {
        bool ok = loadDanbooruCsv(path);
        if (ok) {
            emit csvLoadedChanged();
            emit csvPathChanged();
            emit tagsUpdated();
        }
        return ok;
    }
    return false;
}

void TagAutocomplete::autoLoadCsvAsync()
{
    {
        QMutexLocker locker(&s_csvMutex);
        if (s_isLoaded) return;
    }
    const QString path = autoDetectCsvPath();
    if (!path.isEmpty()) loadCsvFileAsync(path);
}

void TagAutocomplete::loadCsvFileAsync(const QString& filePath)
{
    if (m_csvWatcher.isRunning()) {
        emit loadFailed(tr("A tag dictionary is already being loaded."), "backend.tag_busy");
        return;
    }
    QString path = filePath.startsWith("file:") ? QUrl(filePath).toLocalFile() : filePath;
    if (!QFileInfo::exists(path)) {
        emit loadFailed(tr("Tag dictionary not found: %1").arg(path), "backend.tag_missing", path);
        return;
    }
    m_loadingPath = path;
    s_isLoadingCsv.store(true);
    m_csvWatcher.setFuture(QtConcurrent::run([path]() { return loadDanbooruCsv(path); }));
}

bool TagAutocomplete::loadCsvFile(const QString& filePath)
{
    const QString cleanPath = filePath.startsWith("file:") ? QUrl(filePath).toLocalFile() : filePath;

    bool success = loadDanbooruCsv(cleanPath);
    if (success) {
        QSettings settings = galIMVSettings();
        settings.setValue("tags/csvPath", cleanPath);
        emit csvLoadedChanged();
        emit csvPathChanged();
        emit tagsUpdated();
    }
    return success;
}

bool TagAutocomplete::loadDanbooruCsv(const QString& filePath)
{
    const quint64 generation = ++s_csvGeneration;
    {
        QMutexLocker locker(&s_csvMutex);
        if (s_isLoaded && s_currentCsvPath == filePath) return true;
    }
    QHash<QString, quint8> categories;
    QHash<QString, int> counts;
    QStringList names;

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }



    // Fast parsing using QByteArray lines
    int loadedCount = 0;
    while (!file.atEnd()) {
        QByteArray line = file.readLine();
        line = line.trimmed();
        if (line.isEmpty() || line.startsWith('#')) continue;

        int comma1 = line.indexOf(',');
        if (comma1 <= 0) continue;

        QByteArray nameBytes = line.left(comma1).trimmed();
        int comma2 = line.indexOf(',', comma1 + 1);
        
        quint8 category = 0;
        if (comma2 > comma1) {
            category = static_cast<quint8>(line.mid(comma1 + 1, comma2 - comma1 - 1).trimmed().toUShort());
        }

        int comma3 = (comma2 != -1) ? line.indexOf(',', comma2 + 1) : -1;
        int postCount = 0;
        if (comma2 != -1) {
            int countLen = (comma3 != -1) ? (comma3 - comma2 - 1) : (line.length() - comma2 - 1);
            postCount = line.mid(comma2 + 1, countLen).trimmed().toInt();
        }

        QString name = QString::fromUtf8(nameBytes).toLower();
        categories.insert(name, category);
        counts.insert(name, postCount);
        names.append(name);

        // Also index space-separated version (Danbooru uses underscores, prompts often use spaces)
        // Also index space-separated version (Danbooru uses underscores, prompts often use spaces)
        if (name.contains('_')) {
            QString spaceName = name;
            spaceName.replace('_', ' ');
            categories.insert(spaceName, category);
            counts.insert(spaceName, postCount);
        }

        // Also index mixed version where space is before parentheses: hammer_(sunset_beach) -> hammer (sunset_beach)
        if (name.contains("_(")) {
            QString mixedName = name;
            mixedName.replace("_(", " (");
            if (!categories.contains(mixedName)) {
                categories.insert(mixedName, category);
                counts.insert(mixedName, postCount);
            }
        }

        // Aliases if available
        if (comma3 != -1 && comma3 < line.length() - 1) {
            QByteArray aliasBytes = line.mid(comma3 + 1).trimmed();
            if (aliasBytes.startsWith('"') && aliasBytes.endsWith('"')) {
                aliasBytes = aliasBytes.mid(1, aliasBytes.length() - 2);
            }
            QList<QByteArray> aliasList = aliasBytes.split(',');
            for (const QByteArray& ab : aliasList) {
                QString alias = QString::fromUtf8(ab).trimmed().toLower();
                if (!alias.isEmpty() && !categories.contains(alias)) {
                    categories.insert(alias, category);
                    counts.insert(alias, postCount);
                    if (alias.contains('_')) {
                        QString spaceAlias = alias;
                        spaceAlias.replace('_', ' ');
                        categories.insert(spaceAlias, category);
                        counts.insert(spaceAlias, postCount);
                    }
                    if (alias.contains("_(")) {
                        QString mixedAlias = alias;
                        mixedAlias.replace("_(", " (");
                        if (!categories.contains(mixedAlias)) {
                            categories.insert(mixedAlias, category);
                            counts.insert(mixedAlias, postCount);
                        }
                    }
                }
            }
        }

        loadedCount++;
    }

    std::sort(names.begin(), names.end());
    names.erase(std::unique(names.begin(), names.end()), names.end());

    if (categories.isEmpty()) return false;
    QMutexLocker locker(&s_csvMutex);
    if (generation != s_csvGeneration.load()) return false;
    s_categoryMap.swap(categories);
    s_postCounts.swap(counts);
    s_danbooruTagNames.swap(names);
    s_currentCsvPath = filePath;
    s_isLoaded = true;
    std::cout << "[+] Loaded " << loadedCount << " tags from Danbooru CSV: " 
              << filePath.toUtf8().constData() 
              << " (Total entries with variations: " << s_categoryMap.size() << ")" << std::endl;

    return s_isLoaded;
}

int TagAutocomplete::lookupCategory(const QString& rawTag)
{
    QMutexLocker locker(&s_csvMutex);
    QString tag = rawTag.trimmed().toLower();
    if (tag.isEmpty()) return 0;

    // 1. Remove SD prompt weighting suffix like :1.2, :0.85 at the end
    static const QRegularExpression weightRegex(R"(:\s*[-+]?[0-9]*\.?[0-9]+\s*([\\\)\]\}]*)$)");
    auto match = weightRegex.match(tag);
    if (match.hasMatch()) {
        QString trailing = match.captured(1);
        tag = tag.left(match.capturedStart()) + trailing;
        tag = tag.trimmed();
    }

    // 2. Unescape prompt-escaped parentheses and brackets (\( -> (, \) -> ), etc.)
    tag.replace(R"(\()", "(")
       .replace(R"(\))", ")")
       .replace(R"(\[)", "[")
       .replace(R"(\])", "]")
       .replace(R"(\{)", "{")
       .replace(R"(\})", "}")
       .replace('\\', "");
    tag = tag.trimmed();

    // 3. Strip outer emphasis brackets e.g. "(wlop)", "((tag))", "[tag]"
    while (tag.length() >= 2 &&
           ((tag.startsWith('(') && tag.endsWith(')')) ||
            (tag.startsWith('[') && tag.endsWith(']')) ||
            (tag.startsWith('{') && tag.endsWith('}')))) {
        QString inner = tag.mid(1, tag.length() - 2).trimmed();
        if (inner.isEmpty()) break;
        QString innerUnder = QString(inner).replace(' ', '_');
        if (s_categoryMap.contains(inner) || s_categoryMap.contains(innerUnder)) {
            tag = inner;
        } else if (inner.count('(') >= 1 && inner.count(')') >= 1) {
            tag = inner;
        } else {
            tag = inner;
        }
    }
    if (tag.isEmpty()) return 0;

    // 4. Direct Danbooru lookup
    auto it = s_categoryMap.constFind(tag);
    if (it != s_categoryMap.constEnd()) {
        return it.value();
    }

    // 5. Try with ALL underscores (e.g. "rei (sanbonzakura)" -> "rei_(sanbonzakura)")
    if (tag.contains(' ')) {
        QString under = tag;
        under.replace(' ', '_');
        it = s_categoryMap.constFind(under);
        if (it != s_categoryMap.constEnd()) {
            return it.value();
        }
    }

    // 6. Try with ALL spaces (e.g. "rei_(sanbonzakura)" -> "rei (sanbonzakura)")
    if (tag.contains('_')) {
        QString space = tag;
        space.replace('_', ' ');
        it = s_categoryMap.constFind(space);
        if (it != s_categoryMap.constEnd()) {
            return it.value();
        }
    }

    // 7. Try replacing " (" with "_(" (Danbooru convention: tag_(disambiguation))
    if (tag.contains(" (")) {
        QString mixed = tag;
        mixed.replace(" (", "_(");
        it = s_categoryMap.constFind(mixed);
        if (it != s_categoryMap.constEnd()) {
            return it.value();
        }
    }

    // 8. Artist prefixes (e.g. "by ke-ta", "art by wlop", "artist:greg rutkowski")
    if (tag.startsWith("by ") || tag.startsWith("art by ") || tag.startsWith("artist:") ||
        tag.startsWith("drawn by ") || tag.startsWith("illust by ") || tag.startsWith("illustration by ") ||
        tag.startsWith("art:")) {
        return 1; // Category 1: Artist
    }

    // 9. Artist suffixes and disambiguation
    if (tag.endsWith("(artist)") || tag.endsWith("_(artist)") || tag.endsWith(" (artist)") ||
        tag.endsWith("(circle)") || tag.endsWith("_(circle)") || tag.endsWith(" (circle)") ||
        tag.endsWith("(style)") || tag.endsWith("_(style)") || tag.endsWith(" (style)") ||
        tag.endsWith(" style") || tag.endsWith("(art)") || tag.endsWith("_(art)") ||
        tag.endsWith("(illustrator)") || tag.endsWith("_(illustrator)") ||
        tag.endsWith("(pixiv)") || tag.endsWith("_(pixiv)") ||
        tag.endsWith("(twitter)") || tag.endsWith("_(twitter)") ||
        tag.endsWith("(mangaka)") || tag.endsWith("_(mangaka)") ||
        tag.endsWith("(doujinshi)") || tag.endsWith("_(doujinshi)")) {
        return 1; // Category 1: Artist
    }

    // 10. Meta / Quality tags (Category 5)
    static const QStringList metaKeywords = {
        "masterpiece", "best quality", "best_quality", "highres", "high resolution", "high_resolution",
        "extremely detailed", "extremely_detailed", "aesthetic", "absurdres", "newest", "monochrome",
        "greyscale", "censored", "uncensored", "very detailed", "hdr", "4k", "8k", "raw photo"
    };
    for (const QString& kw : metaKeywords) {
        if (tag == kw) return 5;
    }

    // 11. Known artist keywords
    if (tag.contains("shinkai") || tag.contains("rutkowski") || tag.contains("mucha") ||
        tag.contains("artgerm") || tag.contains("wlop") || tag.contains("cutesexyrobutts") ||
        tag.contains("ke-ta") || tag.contains("kantoku") || tag.contains("krenz") ||
        tag.contains("range murata") || tag.contains("fuzichoco") || tag.contains("rebecca_(keinelove)") ||
        tag.contains("sanbonzakura") || tag.contains("jooho") || tag.contains("okumen") ||
        tag.contains("ourboy83") || tag.contains("baalbuddy") || tag.contains("sunset_beach") ||
        tag.contains("hws")) {
        return 1;
    }

    // 12. Parentheses analysis (when tag wasn't in Danbooru directly)
    if (tag.contains('(') && tag.contains(')')) {
        int openP = tag.lastIndexOf('(');
        int closeP = tag.indexOf(')', openP);
        if (closeP > openP) {
            QString inside = tag.mid(openP + 1, closeP - openP - 1).trimmed();
            QString insideUnder = QString(inside).replace(' ', '_');
            QString before = tag.left(openP).trimmed();
            QString beforeUnder = QString(before).replace(' ', '_');

            // 12a. Artist indicators inside parentheses
            static const QStringList artistParens = {
                "artist", "circle", "style", "art", "illustrator", "pixiv", "twitter",
                "mangaka", "draws", "doujinshi", "comic", "studio"
            };
            for (const QString& ap : artistParens) {
                if (inside == ap || insideUnder == ap) return 1; // Artist
            }

            // 12b. Franchise / Copyright inside parentheses (Category 3 in Danbooru) indicates character!
            // E.g. "misty (pokemon)" -> "pokemon" is Category 3
            if (s_categoryMap.value(inside) == 3 || s_categoryMap.value(insideUnder) == 3) {
                return 4; // Character
            }

            // 12c. Series keywords inside parentheses
            if (inside.endsWith("series") || inside.endsWith("anime") ||
                inside.endsWith("game") || inside.endsWith("franchise") ||
                inside.endsWith("project") || inside.endsWith("manga")) {
                return 4; // Character
            }

            // 12d. Character name before parentheses is a known character
            // E.g. "asuka (summer)" -> "asuka" is Category 4
            if (s_categoryMap.value(before) == 4 || s_categoryMap.value(beforeUnder) == 4) {
                return 4; // Character
            }

            // 12e. Character variant / costume keywords inside parentheses
            static const QStringList charVariantParens = {
                "cosplay", "costume", "outfit", "swimsuit", "summer", "winter",
                "school uniform", "uniform", "maid", "bunny", "bikini", "armor", "casual",
                "alter", "ver", "version", "form"
            };
            for (const QString& cv : charVariantParens) {
                if (inside == cv || insideUnder == cv) return 4; // Character
            }

            // Unknown tag with parentheses: DO NOT assume it's a character!
            // If it didn't match a known copyright or character, return 0 (General).
            return 0;
        }
    }

    // 13. Known character names
    static const QStringList charKeywords = {
        "hatsune miku", "miku", "rem", "ram", "asuka", "asuka langley", "rei ayanami",
        "goku", "naruto", "megumin", "raiden shogun", "furina", "hutao", "ganyu", "azula",
        "gwen tennyson", "tennyson"
    };
    for (const QString& ck : charKeywords) {
        if (tag == ck || tag.startsWith(ck + " ") || tag.startsWith(ck + "_")) return 4;
    }

    return 0; // General
}

void TagAutocomplete::loadDefaults()
{
    static const struct { const char* name; int cat; } defaults[] = {
        {"masterpiece", 5}, {"best quality", 5}, {"high resolution", 5}, {"extremely detailed", 5},
        {"1girl", 0}, {"solo", 0}, {"long hair", 0}, {"short hair", 0}, {"blue eyes", 0},
        {"brown eyes", 0}, {"black hair", 0}, {"blonde hair", 0}, {"smile", 0}, {"open mouth", 0},
        {"looking at viewer", 0}, {"standing", 0}, {"sitting", 0}, {"portrait", 0}, {"upper body", 0},
        {"full body", 0}, {"dress", 0}, {"skirt", 0}, {"school uniform", 0}, {"jacket", 0},
        {"scenery", 0}, {"nature", 0}, {"outdoors", 0}, {"indoors", 0}, {"sky", 0}, {"clouds", 0},
        {"sunlight", 0}, {"sunset", 0}, {"night", 0}, {"city", 0}, {"cyberpunk", 0}, {"fantasy", 0},
        {"hatsune miku", 4}, {"rem (re:zero)", 4}, {"asuka langley", 4}, {"goku", 4}, {"naruto", 4},
        {"misty (pokemon)", 4}, {"misty_(pokemon)", 4},
        {"makoto shinkai", 1}, {"greg rutkowski", 1}, {"alphonse mucha", 1}, {"artgerm", 1}, {"wlop", 1}
    };

    for (const auto& item : defaults) {
        registerTag(QString::fromLatin1(item.name), item.cat);
    }
}

void TagAutocomplete::replaceLibraryTags(const QMap<QString, TagInfo>& tags, const QStringList& names)
{
    m_tags = tags;
    m_tagNames = names;
    emit tagsUpdated();
}

void TagAutocomplete::clearLibraryTags()
{
    m_tags.clear();
    m_tagNames.clear();
    loadDefaults();
}

void TagAutocomplete::registerTag(const QString& tag, int category)
{
    QString cleaned = tag.trimmed().toLower();
    if (cleaned.isEmpty()) return;

    // Unescape any prompt backslashes
    cleaned.replace(R"(\()", "(")
           .replace(R"(\))", ")")
           .replace(R"(\[)", "[")
           .replace(R"(\])", "]")
           .replace('\\', "");
    cleaned = cleaned.trimmed();
    if (cleaned.isEmpty()) return;

    // Canonical key so space vs underscore variants don't duplicate
    QString canon = cleaned;
    canon.replace(' ', '_');

    // If category is not specified or general, check Danbooru lookup
    if (category == 0) {
        category = lookupCategory(cleaned);
    }

    if (!m_tags.contains(canon)) {
        TagInfo info;
        info.name = cleaned;
        info.category = category;
        info.count = 1;
        m_tags.insert(canon, info);
        m_tagNames.append(cleaned);
    } else {
        m_tags[canon].count++;
        if (category != 0 && m_tags[canon].category == 0) {
            m_tags[canon].category = category;
        }
    }
}

QVariantList TagAutocomplete::getTopTags(int category, int limit)
{
    QList<TagInfo> filtered;
    for (auto it = m_tags.constBegin(); it != m_tags.constEnd(); ++it) {
        if (category == -1 || it.value().category == category) {
            filtered.append(it.value());
        }
    }

    std::sort(filtered.begin(), filtered.end(), [](const TagInfo& a, const TagInfo& b) {
        return a.count > b.count;
    });

    QVariantList results;
    int count = std::min(limit, static_cast<int>(filtered.size()));
    for (int i = 0; i < count; ++i) {
        QVariantMap map;
        map["name"] = filtered[i].name;
        map["category"] = filtered[i].category;
        map["color"] = getCategoryColor(filtered[i].category);
        map["count"] = filtered[i].count;
        results.append(map);
    }
    return results;
}

QVariantList TagAutocomplete::suggest(const QString& prefix, int limit)
{
    QVariantList results;
    QHash<QString, quint8> categories;
    QHash<QString, int> counts;
    QStringList names;
    bool loaded;
    {
        QMutexLocker locker(&s_csvMutex);
        categories = s_categoryMap;
        counts = s_postCounts;
        names = s_danbooruTagNames;
        loaded = s_isLoaded;
    }
    QString query = prefix.trimmed().toLower();
    while (query.endsWith(',') || query.endsWith(' ')) {
        query.chop(1);
        query = query.trimmed();
    }
    if (query.isEmpty()) return results;

    QString queryUnder = query; queryUnder.replace(' ', '_');
    QString querySpace = query; querySpace.replace('_', ' ');

    QSet<QString> addedCanonical;
    int found = 0;

    auto tryAdd = [&](const QString& name, int cat, int count) {
        QString canon = name.toLower();
        canon.replace(' ', '_');
        if (addedCanonical.contains(canon)) return false;
        addedCanonical.insert(canon);

        QVariantMap map;
        map["name"] = name;
        map["category"] = cat;
        map["color"] = getCategoryColor(cat);
        map["count"] = count;
        results.append(map);
        return (++found >= limit);
    };

    // 1. First priority: prefix match from currently scanned library
    for (const QString& tag : m_tagNames) {
        if (tag.startsWith(query) || tag.startsWith(queryUnder) || tag.startsWith(querySpace)) {
            QString canon = tag; canon.replace(' ', '_');
            const TagInfo info = m_tags.value(canon);
            if (tryAdd(info.name, info.category, info.count)) return results;
        }
    }

    // 2. Second priority: Danbooru Global Dictionary tags with O(log N) binary search
    if (loaded && found < limit) {
        auto it = std::lower_bound(names.cbegin(), names.cend(), queryUnder);
        for (; it != names.cend() && found < limit; ++it) {
            if (!it->startsWith(queryUnder)) break;
            int cat = categories.value(*it, 0);
            int pCount = counts.value(*it, 0);
            if (tryAdd(*it, cat, pCount)) return results;
        }

        if (found < limit && querySpace != queryUnder) {
            auto it2 = std::lower_bound(names.cbegin(), names.cend(), querySpace);
            for (; it2 != names.cend() && found < limit; ++it2) {
                if (!it2->startsWith(querySpace)) break;
                int cat = categories.value(*it2, 0);
                int pCount = counts.value(*it2, 0);
                if (tryAdd(*it2, cat, pCount)) return results;
            }
        }
    }

    // 3. Substring matching in library if still space
    if (found < limit) {
        for (const QString& tag : m_tagNames) {
            QString tLower = tag.toLower();
            if (!tLower.startsWith(query) && !tLower.startsWith(queryUnder) &&
                (tLower.contains(query) || tLower.contains(queryUnder) || tLower.contains(querySpace))) {
                QString canon = tag; canon.replace(' ', '_');
                const TagInfo info = m_tags.value(canon);
                if (tryAdd(info.name, info.category, info.count)) return results;
            }
        }
    }

    // 4. Substring matching in Danbooru dictionary if still space
    if (loaded && found < limit) {
        for (const QString& dTag : names) {
            QString dLower = dTag.toLower();
            if (!dLower.startsWith(query) && !dLower.startsWith(queryUnder) &&
                (dLower.contains(query) || dLower.contains(queryUnder) || dLower.contains(querySpace))) {
                int cat = categories.value(dTag, 0);
                int pCount = counts.value(dTag, 0);
                if (tryAdd(dTag, cat, pCount)) return results;
            }
        }
    }

    return results;
}

bool TagAutocomplete::loadCsv(const QString& filePath)
{
    return loadCsvFile(filePath);
}
