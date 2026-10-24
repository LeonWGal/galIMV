#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QHash>
#include <QMap>
#include <QSet>
#include <QFutureWatcher>
#include <QSettings>
#include "app_paths.h"

inline QSettings galIMVSettings()
{
    const QString file = qEnvironmentVariable("GALIMV_SETTINGS_FILE");
    if (!file.isEmpty()) return QSettings(file, QSettings::IniFormat);
    const QString directory = AppPaths::dataDirectory("galIMV");
    AppPaths::requireDirectory(directory);
    const QString target = directory + "/settings.ini";
    QSettings current(target, QSettings::IniFormat);
    if (!current.value("storage/migrated", false).toBool()) {
        QSettings previous("galIMV", "galIMV");
        for (const auto &key : previous.allKeys())
            if (!current.contains(key)) current.setValue(key, previous.value(key));
        current.setValue("storage/migrated", true);
        current.sync();
        if (current.status() != QSettings::NoError) qFatal("Cannot migrate galIMV settings.");
    }
    return QSettings(target, QSettings::IniFormat);
}

struct TagInfo {
    QString name;
    int category = 0; // 0: general, 1: artist, 3: copyright, 4: character, 5: meta
    int count = 0;
};

class TagAutocomplete : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool isCsvLoaded READ isCsvLoaded NOTIFY csvLoadedChanged)
    Q_PROPERTY(int totalLoadedTags READ totalLoadedTags NOTIFY csvLoadedChanged)
    Q_PROPERTY(QString csvPath READ csvPath NOTIFY csvPathChanged)

public:
    explicit TagAutocomplete(QObject* parent = nullptr);
    ~TagAutocomplete() override;

    bool isCsvLoaded() const;
    int totalLoadedTags() const;
    QString csvPath() const;

    // Static lookup powered by the Danbooru CSV database
    static int lookupCategory(const QString& rawTag);
    static bool loadDanbooruCsv(const QString& filePath);
    static QString autoDetectCsvPath();
    static bool isCsvLoadedStatic();
    static int totalLoadedTagsStatic();
    static QString getCategoryColor(int category);

    // QML-invokable methods
    Q_INVOKABLE bool loadCsvFile(const QString& filePath);
    Q_INVOKABLE void loadCsvFileAsync(const QString& filePath);
    Q_INVOKABLE bool autoLoadCsv();
    Q_INVOKABLE void autoLoadCsvAsync();
    Q_INVOKABLE QVariantList suggest(const QString& prefix, int limit = 15);
    Q_INVOKABLE QVariantList getTopTags(int category, int limit = 80);
    Q_INVOKABLE void registerTag(const QString& tag, int category = 0);
    Q_INVOKABLE void clearLibraryTags();
    void replaceLibraryTags(const QMap<QString, TagInfo>& tags, const QStringList& names);
    Q_INVOKABLE bool loadCsv(const QString& filePath); // compatibility

signals:
    void loadFailed(const QString& message, const QString& translationKey = QString(), const QString& detail = QString());
    void tagsUpdated();
    void csvLoadedChanged();
    void csvPathChanged();

private:
    void loadDefaults();
    QFutureWatcher<bool> m_csvWatcher;
    QString m_loadingPath;

    // Scanned library tags in the current session
    QMap<QString, TagInfo> m_tags;
    QStringList m_tagNames;

    // Global Danbooru Database
    static QHash<QString, quint8> s_categoryMap;
    static QHash<QString, int> s_postCounts;
    static QStringList s_danbooruTagNames;
    static QString s_currentCsvPath;
    static bool s_isLoaded;
};
