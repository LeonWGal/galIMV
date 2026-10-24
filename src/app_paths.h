#pragma once
#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QLockFile>
#include <QSaveFile>
#include <QStandardPaths>

namespace AppPaths {
inline QString dataRoot() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
}
inline QString dataDirectory(const QString &program) {
    return QDir(dataRoot()).filePath("LeonWGal/" + program);
}
inline void requireDirectory(const QString &path) {
    if (!QDir().mkpath(path)) qFatal("Cannot create application directory: %s", qPrintable(path));
}
inline QString temporaryDirectory(const QString &program) {
    const QString suffix = "/LeonWGal/" + program;
    QString path = QDir::fromNativeSeparators(QDir::tempPath());
    if (!path.endsWith(suffix, Qt::CaseInsensitive)) path += suffix;
    requireDirectory(path);
    return path;
}
inline void configureTemporaryFiles(const QString &program) {
    const auto path = temporaryDirectory(program).toUtf8();
    qputenv("TEMP", path); qputenv("TMP", path); qputenv("TMPDIR", path);
}
inline void configureQmlCache(const QString &directory) {
    const QString cache = directory + "/cache/qml";
    requireDirectory(cache);
    qputenv("QML_DISK_CACHE_PATH", cache.toUtf8());
}
// Copy once, preserve the old profile, and never overwrite newer destination files.
inline void migrateProfile(const QString &source, const QString &destination) {
    const QString marker = destination + "/.storage-migrated";
    if (QFileInfo::exists(marker)) return;
    requireDirectory(destination);
    QLockFile migrationLock(destination + "/.storage-migration.lock");
    if (!migrationLock.tryLock(0)) qFatal("Application profile migration is already running.");
    if (QFileInfo::exists(marker)) return;
    QLockFile oldProfileLock(source + "/profile.lock");
    if (QDir(source).exists()) {
        if (!oldProfileLock.tryLock(0)) qFatal("Close the previous application before migrating its profile.");
        QDirIterator it(source, QDir::Files | QDir::Dirs | QDir::Hidden | QDir::NoDotAndDotDot,
                        QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString file = it.next();
            const QFileInfo info = it.fileInfo();
            if (info.isSymLink() || info.fileName().endsWith(".lock") || info.fileName() == "LOCK"
                || info.fileName().startsWith("Singleton")) continue;
            const QString target = QDir(destination).filePath(QDir(source).relativeFilePath(file));
            if (info.isDir()) requireDirectory(target);
            else if (!QFileInfo::exists(target)) {
                requireDirectory(QFileInfo(target).absolutePath());
                if (!QFile::copy(file, target)) qFatal("Cannot migrate profile file: %s", qPrintable(file));
            }
        }
    }
    QSaveFile done(marker);
    if (!done.open(QIODevice::WriteOnly) || done.write("1\n") != 2 || !done.commit())
        qFatal("Cannot finish application profile migration.");
}
}
