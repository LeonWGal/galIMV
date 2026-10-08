#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QDir>
#include <QSettings>
#include <QPixmapCache>
#include <QQmlError>
#include <iostream>
#include "gallery_model.h"
#include "tag_autocomplete.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("galIMV");
    app.setApplicationDisplayName("galIMV");
    app.setOrganizationName("galIMV");
    app.setWindowIcon(QIcon(":/galIMV/resources/app.ico"));

    // Set generous pixmap cache (256 MB) to prevent disk thrashing when scrolling deep libraries
    QPixmapCache::setCacheLimit(256 * 1024);

    QQuickStyle::setStyle("Basic");

    TagAutocomplete tagAutocomplete;
    tagAutocomplete.autoLoadCsvAsync(); // Fast async background load (instant UI window launch)

    GalleryModel galleryModel(&tagAutocomplete);

    // Restore last selected folder from QSettings
    QSettings settings = galIMVSettings();
    QString savedFolder = settings.value("library/lastFolder", settings.value("lastFolder")).toString();
    if (!savedFolder.isEmpty() && QDir(savedFolder).exists()) {
        std::cout << "[+] Restoring previous active folder: " << savedFolder.toUtf8().constData() << std::endl;
        galleryModel.openFolder(savedFolder);
    } else {
        QString testDir = QDir(QCoreApplication::applicationDirPath()).filePath("test_gallery");
        if (QDir(testDir).exists()) {
            galleryModel.openFolder(testDir);
        }
    }

    QQmlApplicationEngine engine;
    
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError>& warnings) {
        for (const auto& w : warnings) {
            std::cerr << "[QML Warning/Error] " << w.toString().toUtf8().constData() << std::endl;
        }
    });

    engine.rootContext()->setContextProperty("tagAuto", &tagAutocomplete);
    engine.rootContext()->setContextProperty("gallery", &galleryModel);

    const QUrl url("qrc:/galIMV/qml/main.qml");
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
            std::cerr << "[-] Failed to load QML root object!" << std::endl;
            QCoreApplication::exit(-1);
        }
    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
