#include <QtTest>
#include <QAbstractItemModelTester>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickWindow>
#include <QQuickStyle>
#include <QTemporaryDir>
#include <QImage>
#include <QFile>
#include <QDir>
#include <QDataStream>
#include <QtEndian>
#include <zlib.h>
#include "../src/gallery_model.h"

class RegressionTests : public QObject {
    Q_OBJECT
    QTemporaryDir storage;
    int cardCount(QQuickItem* item) {
        int count = item->objectName() == "virtualGalleryCard" ? 1 : 0;
        for (auto* child : item->childItems()) count += cardCount(child);
        return count;
    }
    QQuickItem* findItem(QQuickItem* item, const QString& name) {
        if (item->objectName() == name) return item;
        for (auto* child : item->childItems()) if (auto* found = findItem(child, name)) return found;
        return nullptr;
    }
    QString fixture(const QString& name, int width=16) {
        const QString path=storage.filePath(name);
        QDir().mkpath(QFileInfo(path).absolutePath());
        QImage image(width,16,QImage::Format_RGB32);
        image.fill(Qt::red);
        image.save(path);
        return path;
    }
    void write(const QString& path,const QByteArray& value) {
        QFile file(path); QVERIFY(file.open(QIODevice::WriteOnly)); QCOMPARE(file.write(value),value.size());
    }
    bool ready(GalleryModel& gallery) {
        QElapsedTimer timer; timer.start();
        while ((gallery.isLoading() || gallery.isFiltering()) && timer.elapsed()<10000) {
            QCoreApplication::processEvents(); QTest::qWait(1);
        }
        return !gallery.isLoading() && !gallery.isFiltering();
    }
    void scan(GalleryModel& gallery,const QString& folder) {
        gallery.openFolder(folder); QVERIFY2(ready(gallery),"Scanning/filtering did not finish");
    }
    QByteArray pngChunk(const QByteArray& type,const QByteArray& data) {
        QByteArray bytes(4,0);
        qToBigEndian<quint32>(data.size(),reinterpret_cast<uchar*>(bytes.data()));
        bytes+=type; bytes+=data;
        uLong crc=crc32(0,reinterpret_cast<const Bytef*>(type.constData()),type.size());
        crc=crc32(crc,reinterpret_cast<const Bytef*>(data.constData()),data.size());
        QByteArray tail(4,0); qToBigEndian<quint32>(crc,reinterpret_cast<uchar*>(tail.data()));
        return bytes+tail;
    }
    QByteArray compressed(const QByteArray& data) {
        uLongf size=compressBound(data.size());
        QByteArray out(size,0);
        if (compress2(reinterpret_cast<Bytef*>(out.data()),&size,
                      reinterpret_cast<const Bytef*>(data.constData()),data.size(),Z_BEST_SPEED)!=Z_OK) return {};
        out.resize(size); return out;
    }
    void insertChunk(const QString& path,const QByteArray& chunk,bool afterPixels) {
        QFile file(path); QVERIFY(file.open(QIODevice::ReadOnly)); auto bytes=file.readAll(); file.close();
        int position=33;
        if (afterPixels) {
            position=8;
            while (position+8<bytes.size()) {
                quint32 size=qFromBigEndian<quint32>(reinterpret_cast<const uchar*>(bytes.constData()+position));
                if (bytes.mid(position+4,4)=="IEND") break;
                position+=size+12;
            }
        }
        bytes.insert(position,chunk); write(path,bytes);
    }

private slots:
    void initTestCase() {
        QVERIFY(storage.isValid());
        qputenv("GALIMV_SETTINGS_FILE",storage.filePath("settings.ini").toUtf8());
        qputenv("GALIMV_CACHE_DIR",storage.filePath("cache").toUtf8());
        QQuickStyle::setStyle("Basic");
    }
    void init() {
        auto settings=imageViewerSettings(); settings.clear(); settings.sync();
    }
    void selectionSurvivesSortingAndDeletion() {
        fixture("selection/a.png"); fixture("selection/z.png");
        TagAutocomplete tags; GalleryModel gallery(&tags);
        QAbstractItemModelTester tester(&gallery,QAbstractItemModelTester::FailureReportingMode::QtTest);
        scan(gallery,storage.filePath("selection"));
        gallery.setSortMode(2); gallery.selectSingle(0);
        const auto selected=gallery.selectedImage().value("filePath").toString();
        gallery.setSortMode(3);
        QCOMPARE(gallery.selectedList().first().toMap().value("filePath").toString(),selected);
        QCOMPARE(gallery.selectedImage().value("filteredIndex").toInt(),1);
        QVERIFY(gallery.deleteImage(0,false));
        QCOMPARE(gallery.selectedCount(),1);
        QCOMPARE(gallery.selectedList().size(),1);
        QCOMPARE(gallery.selectedList().first().toMap().value("filePath").toString(),selected);
        QCOMPARE(gallery.selectedImage().value("filteredIndex").toInt(),0);
    }
    void shiftAnchorFollowsItsFile() {
        fixture("anchor/a.png");fixture("anchor/b.png");fixture("anchor/c.png");
        TagAutocomplete tags; GalleryModel gallery(&tags); scan(gallery,storage.filePath("anchor"));
        gallery.setSortMode(2); gallery.selectSingle(0); gallery.setSortMode(3); gallery.rangeSelect(1);
        QCOMPARE(gallery.selectedCount(),2);
        QVERIFY(gallery.isIndexSelected(1)); QVERIFY(gallery.isIndexSelected(2));
    }
    void changedImageReplacesCachedRecord() {
        const auto file=fixture("updates/a.png");
        TagAutocomplete tags;
        {
            GalleryModel gallery(&tags); scan(gallery,storage.filePath("updates"));
        }
        fixture("updates/a.png",31);
        GalleryModel gallery(&tags); scan(gallery,storage.filePath("updates"));
        QCOMPARE(gallery.totalCount(),1);
        QCOMPARE(gallery.data(gallery.index(0,0),GalleryModel::WidthRole).toInt(),31);
        gallery.openFolder(storage.filePath("updates")); QVERIFY(ready(gallery));
        QCOMPARE(gallery.totalCount(),1);
    }
    void sidecarChangesAndRemovalInvalidateCache() {
        fixture("sidecar/a.png");
        const auto txt=storage.filePath("sidecar/a.txt"); write(txt,"old");
        TagAutocomplete tags;
        { GalleryModel gallery(&tags);scan(gallery,storage.filePath("sidecar")); }
        write(txt,"new prompt");
        { GalleryModel gallery(&tags);scan(gallery,storage.filePath("sidecar"));
          gallery.selectImage(0);QCOMPARE(gallery.selectedImage().value("prompt").toString(),QString("new prompt")); }
        QVERIFY(QFile::remove(txt));
        GalleryModel gallery(&tags);scan(gallery,storage.filePath("sidecar"));gallery.selectImage(0);
        QCOMPARE(gallery.totalCount(),1);QVERIFY(gallery.selectedImage().value("prompt").toString().isEmpty());
    }
    void staleScansCannotPopulateNewFolder() {
        fixture("old-folder/a.png");fixture("new-folder/z.png");
        TagAutocomplete tags; GalleryModel gallery(&tags);
        gallery.openFolder(storage.filePath("old-folder"));
        gallery.openFolder(storage.filePath("new-folder")); QVERIFY(ready(gallery));
        QCOMPARE(gallery.totalCount(),1);
        QCOMPARE(QFileInfo(gallery.pathAt(0)).fileName(),QString("z.png"));
    }
    void fileMutationResumesIncompleteScan() {
        const auto first=fixture("resume/a.png");fixture("resume/z.png");
        TagAutocomplete tags;GalleryModel gallery(&tags);
        gallery.openFolder(storage.filePath("resume"));
        auto item=MetadataReader::read(first,storage.filePath("resume"));
        QList<ImageMetadata> batch{item};
        QVERIFY(QMetaObject::invokeMethod(&gallery,"onBatchFound",Qt::DirectConnection,Q_ARG(QList<ImageMetadata>,batch)));
        QVERIFY(gallery.deleteFile(first,false));
        QCoreApplication::processEvents();QVERIFY(ready(gallery));
        QCOMPARE(gallery.totalCount(),1);
        QCOMPARE(QFileInfo(gallery.pathAt(0)).fileName(),QString("z.png"));
    }
    void movingPairUpdatesRelativeFolderAndCounts() {
        const auto image=fixture("move/a.png"); write(storage.filePath("move/a.txt"),"prompt");
        const auto target=storage.filePath("move/nested/target");
        TagAutocomplete tags;GalleryModel gallery(&tags);scan(gallery,storage.filePath("move"));
        gallery.selectSingle(0);QVERIFY(gallery.moveFile(image,target));
        QVERIFY(QFile::exists(target+"/a.png"));QVERIFY(QFile::exists(target+"/a.txt"));
        QVERIFY(!QFile::exists(storage.filePath("move/a.txt")));
        gallery.selectImage(0);QCOMPARE(gallery.selectedImage().value("relativeDir").toString(),QString("nested/target"));
        QCOMPARE(gallery.selectedCount(),1);
        gallery.setSelectedSubfolder("nested/target");QCOMPARE(gallery.rowCount(),1);
        QVERIFY(gallery.moveSelected(storage.filePath("outside"))==1);
        QCOMPARE(gallery.totalCount(),0);QCOMPARE(gallery.selectedCount(),0);
        QVERIFY(QFile::exists(storage.filePath("outside/a.txt")));
    }
    void collisionsPreserveOriginalsAndFailedSelections() {
        const auto first=fixture("collision/a.png");fixture("collision/z.png");
        write(storage.filePath("collision/a.txt"),"keep me");
        fixture("collision-dest/a.png");
        TagAutocomplete tags;GalleryModel gallery(&tags);scan(gallery,storage.filePath("collision"));
        gallery.setSortMode(2);gallery.selectAll();
        QSignalSpy failures(&gallery,&GalleryModel::operationFailed);
        QCOMPARE(gallery.moveSelected(storage.filePath("collision-dest")),1);
        QVERIFY(!failures.isEmpty());QVERIFY(QFile::exists(first));
        QVERIFY(QFile::exists(storage.filePath("collision/a.txt")));
        QCOMPARE(gallery.selectedCount(),1);
        QCOMPARE(gallery.selectedList().first().toMap().value("filePath").toString(),first);
    }
    void deletionRemovesPairAndPreservesUnrelatedSelection() {
        const auto first=fixture("delete/a.png"); const auto second=fixture("delete/z.png");
        write(storage.filePath("delete/a.txt"),"prompt");
        TagAutocomplete tags;GalleryModel gallery(&tags);scan(gallery,storage.filePath("delete"));
        gallery.setSortMode(2);gallery.selectSingle(1);
        QVERIFY(gallery.deleteFile(first,false));
        QVERIFY(!QFile::exists(first));QVERIFY(!QFile::exists(storage.filePath("delete/a.txt")));
        QCOMPARE(gallery.selectedCount(),1);QCOMPARE(gallery.pathAt(0),second);
        QVERIFY(gallery.deleteFile(second,false));QCOMPARE(gallery.totalCount(),0);
        QVERIFY(gallery.selectedImage().isEmpty());QCOMPARE(gallery.selectedCount(),0);
    }
    void sharedSidecarsRemainWithTheOtherImage() {
        const auto png=fixture("shared/a.png");fixture("shared/a.jpg");
        const auto txt=storage.filePath("shared/a.txt");write(txt,"shared prompt");
        TagAutocomplete tags;GalleryModel gallery(&tags);scan(gallery,storage.filePath("shared"));
        const auto target=storage.filePath("shared-target");
        QVERIFY(gallery.moveFile(png,target));QVERIFY(QFile::exists(txt));
        QVERIFY(QFile::exists(target+"/a.txt"));QCOMPARE(gallery.totalCount(),1);
        QVERIFY(gallery.deleteFile(gallery.pathAt(0),false));QVERIFY(!QFile::exists(txt));
        QVERIFY(QFile::exists(target+"/a.txt"));
    }
    void truncatedAndOldCachesAreRejected() {
        const QString root=storage.filePath("corrupt");
        write(GalleryModel::getCacheFilePath(root),QByteArray("GALI"));
        QList<ImageMetadata> images;
        QVERIFY(!GalleryModel::loadCache(root,images));QVERIFY(images.isEmpty());
        QFile old(GalleryModel::getCacheFilePath(root));QVERIFY(old.open(QIODevice::WriteOnly));
        QDataStream legacy(&old);legacy.setVersion(QDataStream::Qt_6_5);
        legacy << quint32(0x47414C49) << quint32(1) << root << qint64(0);old.close();
        QVERIFY(!GalleryModel::loadCache(root,images));QVERIFY(images.isEmpty());
        ImageMetadata image;image.filePath="test";QVERIFY(GalleryModel::saveCache(root,{image}));
        QFile file(GalleryModel::getCacheFilePath(root));QVERIFY(file.open(QIODevice::ReadWrite));
        QVERIFY(file.resize(file.size()-3));file.close();
        QVERIFY(!GalleryModel::loadCache(root,images));QVERIFY(images.isEmpty());
    }
    void pngTextFormats_data() {
        QTest::addColumn<QByteArray>("type");QTest::addColumn<bool>("compress");QTest::addColumn<bool>("after");
        QTest::newRow("tEXt-after-IDAT")<<QByteArray("tEXt")<<false<<true;
        QTest::newRow("zTXt-before-IDAT")<<QByteArray("zTXt")<<true<<false;
        QTest::newRow("zTXt-after-IDAT")<<QByteArray("zTXt")<<true<<true;
        QTest::newRow("iTXt-uncompressed")<<QByteArray("iTXt")<<false<<true;
        QTest::newRow("iTXt-compressed")<<QByteArray("iTXt")<<true<<true;
    }
    void pngTextFormats() {
        QFETCH(QByteArray,type);QFETCH(bool,compress);QFETCH(bool,after);
        const auto file=fixture("png-"+QString::fromLatin1(QTest::currentDataTag())+".png");
        const QString prompt=type=="tEXt" ? QString("positive prompt") : QString::fromUtf8("Привет 世界");
        QByteArray text=prompt.toUtf8()+QByteArray("\nNegative prompt: bad\nSteps: 20, Model: example");
        QByteArray data("parameters");data.append(char(0));
        if (type=="zTXt") {data.append(char(0));data+=compressed(text);}
        else if (type=="iTXt") {
            data.append(char(compress));data.append(char(0));data.append(char(0));data.append(char(0));
            data+=compress?compressed(text):text;
        } else data+=text;
        insertChunk(file,pngChunk(type,data),after);
        auto metadata=MetadataReader::read(file);
        QCOMPARE(metadata.prompt,prompt);QCOMPARE(metadata.negativePrompt,QString("bad"));
        QCOMPARE(metadata.modelName,QString("example"));QCOMPARE(metadata.dimensions,QSize(16,16));
    }
    void comfyUsesConditioningLinks() {
        const auto file=fixture("comfy.png");
        QByteArray graph=R"({"1":{"class_type":"CLIPTextEncode","inputs":{"text":"NEGATIVE"}},"2":{"class_type":"CLIPTextEncode","inputs":{"text":"POSITIVE"}},"3":{"class_type":"KSampler","inputs":{"positive":["4",0],"negative":["1",0]}},"4":{"class_type":"ConditioningCombine","inputs":{"conditioning_1":["2",0],"conditioning_2":["5",0]}},"5":{"class_type":"CLIPTextEncode","inputs":{"text":"POSITIVE TWO"}}})";
        QByteArray data("prompt");data.append(char(0));data+=graph;
        insertChunk(file,pngChunk("tEXt",data),true);
        auto metadata=MetadataReader::read(file);
        QCOMPARE(metadata.prompt,QString("POSITIVE\nPOSITIVE TWO"));
        QCOMPARE(metadata.negativePrompt,QString("NEGATIVE"));
    }
    void malformedPngAndOversizedInflationAreSafe() {
        const auto path=storage.filePath("broken.png");
        write(path,QByteArray("\x89PNG\r\n\x1a\n",8)+QByteArray("\0\0\0\rIHDR",8)+QByteArray("xx"));
        QVERIFY(MetadataReader::read(path).prompt.isEmpty());
        const auto valid=fixture("inflate-limit.png");
        QByteArray data("parameters");data.append(char(0));data.append(char(0));
        data+=compressed(QByteArray(21*1024*1024,'x'));
        insertChunk(valid,pngChunk("zTXt",data),false);
        QVERIFY(MetadataReader::read(valid).prompt.isEmpty());
    }
    void newestAsyncQueryWinsAndGroupingIsLimited() {
        TagAutocomplete tags;GalleryModel gallery(&tags);
        QList<ImageMetadata> images;
        for (int i=0;i<10000;++i) {
            ImageMetadata item;item.filePath=QString("C:/review/%1.png").arg(i);item.fileName=QString::number(i);
            item.prompt=i%2?"beta":"alpha";item.tags={item.prompt};item.relativeDir="Root";
            images.append(item);
        }
        QVERIFY(QMetaObject::invokeMethod(&gallery,"onBatchFound",Qt::DirectConnection,Q_ARG(QList<ImageMetadata>,images)));
        gallery.setSearchQuery("alpha");
        QTest::qWait(90);
        gallery.setSearchQuery("beta");
        QVERIFY(ready(gallery));QCOMPARE(gallery.rowCount(),5000);
        QCOMPARE(gallery.data(gallery.index(0,0),GalleryModel::PromptRole).toString(),QString("beta"));
        gallery.setSearchQuery("");gallery.setGroupMode(1);QVERIFY(ready(gallery));
        int count=0;
        for (int col=0;col<4;++col) count+=gallery.getGroupMasonryColumn(0,col,4).size();
        QCOMPARE(count,120);
        gallery.setViewport(0,800,1000,4,0,{});
        QTRY_VERIFY_WITH_TIMEOUT(gallery.layoutHeight()>100000,5000);
        QVERIFY(gallery.visibleCards().size()<100);
        gallery.setViewport(100000,800,1000,4,0,{});
        QVERIFY(!gallery.visibleCards().isEmpty());QVERIFY(gallery.visibleCards().size()<100);
    }
    void asyncDictionaryAndEncodedPaths() {
        const QString dir=storage.filePath("dictionary with spaces");QDir().mkpath(dir);
        const auto csv=dir+"/tags.csv";
        write(csv,"sample_artist,1,42,\nsample_character,4,12,\n");
        TagAutocomplete tags;
        QSignalSpy loaded(&tags,&TagAutocomplete::csvLoadedChanged);
        tags.loadCsvFileAsync(QUrl::fromLocalFile(csv).toString());
        QTRY_VERIFY_WITH_TIMEOUT(!loaded.isEmpty(),5000);
        QCOMPARE(TagAutocomplete::lookupCategory("sample artist"),1);
        QVERIFY(!tags.suggest("sample").isEmpty());
    }
    void qmlInstantiatesOnlyViewportCards() {
        const QString folder=storage.filePath("ui");
        for (int i=0;i<1500;++i) fixture("ui/"+QString::number(i)+".png");
        TagAutocomplete tags;GalleryModel gallery(&tags);scan(gallery,folder);
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("gallery",&gallery);
        engine.rootContext()->setContextProperty("tagAuto",&tags);
        QList<QQmlError> warnings;
        connect(&engine,&QQmlApplicationEngine::warnings,this,[&](const auto& list){ warnings.append(list); });
        engine.load(QUrl("qrc:/ImageViewer/qml/main.qml"));
        QVERIFY(!engine.rootObjects().isEmpty());
        auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());QVERIFY(window);
        QTRY_VERIFY_WITH_TIMEOUT(!gallery.visibleCards().isEmpty(),5000);
        QTRY_VERIFY_WITH_TIMEOUT(cardCount(window->contentItem())>0,5000);
        QVERIFY(cardCount(window->contentItem())<100);
        auto* viewport = findItem(window->contentItem(), "masonryViewport");QVERIFY(viewport);
        viewport->setProperty("contentY",5000);
        QTRY_VERIFY_WITH_TIMEOUT(gallery.visibleCards().first().toMap().value("cardY").toReal()>3000,5000);
        QVERIFY(cardCount(window->contentItem())<100);
        gallery.setGroupMode(1);QVERIFY(ready(gallery));
        QTest::qWait(200);
        QVERIFY(cardCount(window->contentItem())<100);
        const auto groupId=gallery.groupList().first().toMap().value("id").toString();
        window->setProperty("collapsedGroups",QVariantMap{{groupId,true}});
        QTRY_COMPARE_WITH_TIMEOUT(cardCount(window->contentItem()),0,5000);
        window->setProperty("collapsedGroups",QVariantMap{});
        QTRY_VERIFY_WITH_TIMEOUT(cardCount(window->contentItem())>0,5000);
        for (const auto& warning : warnings)
            QVERIFY2(!warning.description().contains("ReferenceError") && !warning.description().contains("TypeError"),
                     qPrintable(warning.toString()));
        window->close();
    }
    void groupRangesFollowDisplayedOrderAndKeepAnchor() {
        const auto a = fixture("range-groups/Alpha/a.png");
        const auto c = fixture("range-groups/Alpha/c.png");
        const auto b = fixture("range-groups/Beta/b.png");
        const auto d = fixture("range-groups/Beta/d.png");
        TagAutocomplete tags; GalleryModel gallery(&tags);
        scan(gallery, storage.filePath("range-groups")); gallery.setSortMode(2); gallery.setGroupMode(1);
        QVERIFY(ready(gallery));
        QCOMPARE(gallery.pathAt(0), a); QCOMPARE(gallery.pathAt(1), c);
        QCOMPARE(gallery.pathAt(2), b); QCOMPARE(gallery.pathAt(3), d);
        gallery.selectSingle(0); gallery.rangeSelect(1);
        QCOMPARE(gallery.selectedCount(), 2); QVERIFY(!gallery.isPathSelected(b));
        gallery.rangeSelect(3); QCOMPARE(gallery.selectedCount(), 4);
        gallery.rangeSelect(1); QCOMPARE(gallery.selectedCount(), 2);
        gallery.rangeSelect(3, true); QCOMPARE(gallery.selectedCount(), 4);
        gallery.selectSingle(gallery.indexForPath(c));
        gallery.setGroupMode(0); QVERIFY(ready(gallery));
        QVERIFY(gallery.isPathSelected(c)); QCOMPARE(gallery.selectedCount(), 1);
        gallery.setGroupMode(1); QVERIFY(ready(gallery));
        gallery.toggleGroupSelect(0); QCOMPARE(gallery.selectedCount(), 2);
        gallery.toggleGroupSelect(0); QCOMPARE(gallery.selectedCount(), 0);
        QVERIFY(gallery.selectedImage().isEmpty());
    }
    void selectionSurvivesEveryGroupingMode_data() {
        QTest::addColumn<int>("mode");
        QTest::newRow("folders") << 1;
        QTest::newRow("models") << 2;
        QTest::newRow("dates") << 3;
    }
    void selectionSurvivesEveryGroupingMode() {
        QFETCH(int, mode);
        TagAutocomplete tags; GalleryModel gallery(&tags);
        QList<ImageMetadata> images;
        for (int i = 0; i < 8; ++i) {
            auto item = MetadataReader::read(fixture(QString("all-groups/%1/%2.png").arg(mode).arg(i)));
            item.relativeDir = i % 2 ? "Beta" : "Alpha";
            item.modelName = i % 2 ? "model_b" : "model_a";
            item.modifiedDate = QDateTime(QDate(2026, 10, i % 2 ? 2 : 1), QTime(12, 0));
            images.append(item);
        }
        QVERIFY(QMetaObject::invokeMethod(&gallery, "onBatchFound", Qt::DirectConnection, Q_ARG(QList<ImageMetadata>, images)));
        gallery.setSortMode(2); QVERIFY(ready(gallery));
        gallery.selectSingle(gallery.indexForPath(images[4].filePath));
        gallery.setGroupMode(mode); QVERIFY(ready(gallery));
        QVERIFY(gallery.isPathSelected(images[4].filePath)); QCOMPARE(gallery.selectedCount(), 1);
        QCOMPARE(gallery.groupList().size(), 2);
        gallery.selectSingle(0); gallery.rangeSelect(3);
        QCOMPARE(gallery.selectedCount(), 4); QVERIFY(gallery.isGroupSelected(0));
        QVERIFY(!gallery.isGroupSelected(1));
        const auto selected = gallery.selectedList();
        gallery.setGroupMode(0); QVERIFY(ready(gallery));
        for (const auto& item : selected) QVERIFY(gallery.isPathSelected(item.toMap().value("filePath").toString()));
        gallery.setGroupMode(mode); QVERIFY(ready(gallery));
        gallery.toggleGroupSelect(0); QCOMPARE(gallery.selectedCount(), 0);
        QVERIFY(gallery.selectedImage().isEmpty());
    }
    void selectionBadgeStaysVisibleDuringHoverAndRegrouping() {
        for (int i = 0; i < 8; ++i) fixture(QString("hover-groups/%1/%2.png").arg(i % 2 ? "Beta" : "Alpha").arg(i));
        TagAutocomplete tags; GalleryModel gallery(&tags); scan(gallery, storage.filePath("hover-groups"));
        gallery.setSortMode(2);
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("gallery", &gallery);
        engine.rootContext()->setContextProperty("tagAuto", &tags);
        engine.load(QUrl("qrc:/ImageViewer/qml/main.qml")); QVERIFY(!engine.rootObjects().isEmpty());
        auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().first()); QVERIFY(window);
        auto* viewport = findItem(window->contentItem(), "masonryViewport"); QVERIFY(viewport);
        QTRY_VERIFY(cardCount(window->contentItem()) > 0);
        QTest::qWait(250);
        auto* card = findItem(window->contentItem(), "virtualGalleryCard"); QVERIFY(card);
        auto* badge = findItem(card, "cardSelectionBadge"); QVERIFY(badge);
        const auto path = gallery.visibleCards().first().toMap().value("filePath").toString();
        QVERIFY(!path.isEmpty());
        QTest::mouseMove(window, card->mapToScene(QPointF(50, 50)).toPoint());
        QTRY_VERIFY(badge->isVisible());
        QSignalSpy visibility(badge, &QQuickItem::visibleChanged);
        const auto center = badge->mapToScene(QPointF(12, 12)).toPoint();
        for (int step = 0; step < 16; ++step) {
            QTest::mouseMove(window, center + QPoint(step % 3 - 1, step % 5 - 2), 12);
            QVERIFY(badge->isVisible());
        }
        QTest::qWait(400); QVERIFY(badge->isVisible()); QCOMPARE(visibility.size(), 0);
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, center);
        QTRY_COMPARE(gallery.selectedCount(), 1); QVERIFY(gallery.isPathSelected(path));
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, center);
        QTRY_COMPARE(gallery.selectedCount(), 0); QVERIFY(badge->isVisible());
        gallery.selectSingle(gallery.indexForPath(path));
        gallery.setGroupMode(1); QVERIFY(ready(gallery));
        QTRY_VERIFY(cardCount(window->contentItem()) > 0);
        QVERIFY(gallery.isPathSelected(path));
        gallery.toggleGroupSelect(0); QCOMPARE(gallery.selectedCount(), 4);
        QVERIFY(gallery.isGroupSelected(0));
        auto* header = findItem(window->contentItem(), "galleryGroupHeader"); QVERIFY(header);
        QPointer<QQuickItem> stableHeader(header);
        viewport->setProperty("contentY", 10);
        QTest::qWait(100); QVERIFY(stableHeader);
        auto* groupButton = findItem(header, "groupSelectionButton"); QVERIFY(groupButton);
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, groupButton->mapToScene(QPointF(groupButton->width() / 2, groupButton->height() / 2)).toPoint());
        QTRY_COMPARE(gallery.selectedCount(), 0);
        window->close();
    }
    void confirmationKeepsFileIdentityAfterSorting() {
        const auto first=fixture("dialog/a.png");const auto second=fixture("dialog/z.png");
        TagAutocomplete tags;GalleryModel gallery(&tags);scan(gallery,storage.filePath("dialog"));
        gallery.setSortMode(2);
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("gallery",&gallery);
        engine.rootContext()->setContextProperty("tagAuto",&tags);
        engine.load(QUrl("qrc:/ImageViewer/qml/main.qml"));QVERIFY(!engine.rootObjects().isEmpty());
        auto* root=engine.rootObjects().first();
        root->setProperty("confirmDelete",true);root->setProperty("useRecycleBin",false);
        QVERIFY(QMetaObject::invokeMethod(root,"requestDelete",Q_ARG(QVariant,QVariant(0))));
        gallery.setSortMode(3);
        auto* dialog=root->findChild<QObject*>("deleteImageDialog");QVERIFY(dialog);
        QVERIFY(QMetaObject::invokeMethod(dialog,"accept"));
        QVERIFY(!QFile::exists(first));QVERIFY(QFile::exists(second));QCOMPARE(gallery.totalCount(),1);
    }
    void uiSearchSelectionAndNavigation() {
        for (int i = 0; i < 80; ++i) fixture(QString("ux/%1.png").arg(i, 3, 10, QLatin1Char('0')));
        TagAutocomplete tags; GalleryModel gallery(&tags);
        scan(gallery, storage.filePath("ux")); gallery.setSortMode(2);
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("gallery", &gallery);
        engine.rootContext()->setContextProperty("tagAuto", &tags);
        QList<QQmlError> warnings;
        connect(&engine, &QQmlApplicationEngine::warnings, this, [&](const auto& list) { warnings.append(list); });
        engine.load(QUrl("qrc:/ImageViewer/qml/main.qml"));
        QVERIFY(!engine.rootObjects().isEmpty());
        auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().first()); QVERIFY(window);
        window->setWidth(1040); window->setHeight(700);
        auto* viewport = findItem(window->contentItem(), "masonryViewport"); QVERIFY(viewport);
        auto* search = findItem(window->contentItem(), "searchInput"); QVERIFY(search);
        QTRY_VERIFY_WITH_TIMEOUT(search->width() >= 180, 5000);
        QVERIFY(search->mapToScene(QPointF()).x() >= 0);
        QTRY_VERIFY(search->mapToScene(QPointF(search->width(), 0)).x() <= window->width());
        QTRY_VERIFY_WITH_TIMEOUT(!gallery.visibleCards().isEmpty(), 5000);
        QTest::qWait(250);
        auto clickCard = [&](int index, Qt::KeyboardModifiers modifiers) {
            const auto cards = gallery.visibleCards();
            for (const auto& value : cards) {
                const auto card = value.toMap();
                if (card.value("filteredIndex").toInt() != index) continue;
                const auto position = viewport->mapToScene(QPointF(
                    card.value("cardX").toReal() + card.value("cardWidth").toReal() / 2,
                    card.value("cardY").toReal() - viewport->property("contentY").toReal() + card.value("cardHeight").toReal() / 2));
                QTest::mouseClick(window, Qt::LeftButton, modifiers, position.toPoint());
                return;
            }
            QFAIL("Expected visible card was not found");
        };
        clickCard(0, Qt::NoModifier); QTRY_COMPARE(gallery.selectedCount(), 1);
        clickCard(1, Qt::ControlModifier); QTRY_COMPARE(gallery.selectedCount(), 2);
        clickCard(2, Qt::NoModifier); QTRY_COMPARE(gallery.selectedCount(), 1);
        QVERIFY(gallery.isIndexSelected(2));
        clickCard(0, Qt::ShiftModifier); QTRY_COMPARE(gallery.selectedCount(), 3);
        gallery.selectSingle(0);
        QVERIFY(QMetaObject::invokeMethod(window, "navigateGallery", Q_ARG(QVariant, QVariant(60))));
        QTRY_VERIFY(viewport->property("contentY").toReal() > 0);
        QCOMPARE(gallery.selectedImage().value("filteredIndex").toInt(), 60);
        const auto geometry = gallery.cardGeometry(60);
        QVERIFY(geometry.value("y").toReal() >= viewport->property("contentY").toReal());
        QVERIFY(geometry.value("y").toReal() + geometry.value("height").toReal() <= viewport->property("contentY").toReal() + viewport->height());

        // Typing, including Delete and Space, must not execute gallery actions.
        search->forceActiveFocus(); search->setProperty("text", "xyz");
        QTRY_VERIFY(!window->property("galleryShortcutsEnabled").toBool());
        QTest::keyClick(window, Qt::Key_Delete);
        QTest::keyClick(window, Qt::Key_Space);
        QCOMPARE(gallery.totalCount(), 80); QCOMPARE(window->property("activeModalUrl").toString(), QString());
        search->setProperty("text", "no-such-image");
        QTRY_COMPARE_WITH_TIMEOUT(gallery.rowCount(), 0, 5000);
        auto* empty = findItem(window->contentItem(), "galleryEmptyState"); QVERIFY(empty);
        QTRY_VERIFY(empty->isVisible());
        auto* reset = findItem(window->contentItem(), "resetFiltersButton"); QVERIFY(reset);
        reset->forceActiveFocus(); QTest::keyClick(window, Qt::Key_Space);
        QTRY_COMPARE_WITH_TIMEOUT(gallery.rowCount(), 80, 5000);
        QCOMPARE(search->property("text").toString(), QString());
        QCOMPARE(viewport->property("contentY").toReal(), 0.0);
        QVERIFY(!empty->isVisible());

        gallery.setGroupMode(1); QVERIFY(ready(gallery));
        const auto groupId = gallery.groupList().first().toMap().value("id").toString();
        window->setProperty("collapsedGroups", QVariantMap{{groupId, true}});
        QTRY_COMPARE(cardCount(window->contentItem()), 0);
        gallery.selectImage(0);
        QVERIFY(QMetaObject::invokeMethod(window, "navigateGallery", Q_ARG(QVariant, QVariant(1))));
        QTRY_VERIFY(cardCount(window->contentItem()) > 0);
        QVERIFY(!window->property("collapsedGroups").toMap().value(groupId).toBool());

        window->setProperty("settingsModalOpen", true);
        QTRY_VERIFY(!window->property("galleryShortcutsEnabled").toBool());
        QTest::keyClick(window, Qt::Key_Delete); QCOMPARE(gallery.totalCount(), 80);
        window->setProperty("settingsModalOpen", false);
        for (const auto& warning : warnings)
            QVERIFY2(!warning.description().contains("ReferenceError") && !warning.description().contains("TypeError") &&
                     !warning.description().contains("Binding loop"), qPrintable(warning.toString()));
        window->close();
    }
    void uiVisualReview() {
        const auto captureDir = qEnvironmentVariable("GALIMV_UI_CAPTURE_DIR");
        if (captureDir.isEmpty()) QSKIP("Set GALIMV_UI_CAPTURE_DIR to capture the actual interface.");
        QDir().mkpath(captureDir);
        TagAutocomplete tags; GalleryModel gallery(&tags);
        gallery.setLanguage("ru_RU");
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("gallery", &gallery);
        engine.rootContext()->setContextProperty("tagAuto", &tags);
        engine.load(QUrl("qrc:/ImageViewer/qml/main.qml"));
        QVERIFY(!engine.rootObjects().isEmpty());
        auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().first()); QVERIFY(window);
        auto capture = [&](const QString& name) {
            QTest::qWait(600);
            const auto image = window->grabWindow();
            QVERIFY(!image.isNull());
            QVERIFY(image.save(captureDir + "/" + name + ".png"));
        };
        auto* empty = findItem(window->contentItem(), "galleryEmptyState"); QVERIFY(empty);
        QVERIFY(empty->isVisible()); capture("welcome");
        auto* aurora = findItem(window->contentItem(), "auroraBackground"); QVERIFY(aurora);
        window->setProperty("auroraAnimated", false);
        window->setProperty("lobeAccent", QColor("#52c41a")); capture("aurora-green");
        aurora->setProperty("phase", 0.42); capture("aurora-green-drift");
        window->setProperty("isDarkTheme", false); capture("aurora-light");
        window->setProperty("isDarkTheme", true);
        window->setProperty("lobeAccent", QColor("#1677ff"));
        window->setProperty("auroraAnimated", true);
        scan(gallery, QString::fromUtf8(IMAGEVIEWER_TEST_GALLERY));
        QTRY_VERIFY_WITH_TIMEOUT(cardCount(window->contentItem()) > 0, 5000);
        QVERIFY(!empty->isVisible());
        capture("gallery");
        gallery.selectSingle(0); capture("inspector");
        window->setProperty("width", 1040); window->setProperty("height", 700); capture("compact");
        gallery.selectAll(); capture("batch");
        gallery.clearSelection();
        auto* search = findItem(window->contentItem(), "searchInput"); QVERIFY(search);
        search->setProperty("text", "no-such-image");
        QTRY_COMPARE_WITH_TIMEOUT(gallery.rowCount(), 0, 5000); capture("no-results");
        QVERIFY(QMetaObject::invokeMethod(window, "resetFilters")); QVERIFY(ready(gallery));
        gallery.selectSingle(0);
        window->setProperty("isDarkTheme", false); capture("light");
        window->setProperty("settingsModalOpen", true); capture("settings");
        window->setProperty("settingsModalOpen", false);
        window->setProperty("isDarkTheme", true);
        QVERIFY(QMetaObject::invokeMethod(window, "openSelectedImage")); capture("viewer");
        window->setProperty("activeModalUrl", "");
        window->setProperty("confirmDelete", true);
        QVERIFY(QMetaObject::invokeMethod(window, "requestDelete", Q_ARG(QVariant, QVariant(0)))); capture("confirmation");
        auto* dialog = window->findChild<QObject*>("deleteImageDialog"); QVERIFY(dialog);
        QVERIFY(QMetaObject::invokeMethod(dialog, "reject"));
        const auto examples = QDir(QString::fromUtf8(IMAGEVIEWER_TEST_GALLERY)).entryInfoList({"*.png"}, QDir::Files);
        const auto groupedFolder = storage.filePath("visual-groups");
        for (int i = 0; i < examples.size(); ++i) {
            const auto destination = groupedFolder + (i % 2 ? "/Beta/" : "/Alpha/");
            QDir().mkpath(destination); QVERIFY(QFile::copy(examples[i].filePath(), destination + examples[i].fileName()));
        }
        scan(gallery, groupedFolder); gallery.setGroupMode(1); QVERIFY(ready(gallery));
        gallery.toggleGroupSelect(0); capture("group-selection");
        window->close();
    }
    void auroraPausesAndHonorsAppearanceSettings() {
        TagAutocomplete tags; GalleryModel gallery(&tags);
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("gallery", &gallery);
        engine.rootContext()->setContextProperty("tagAuto", &tags);
        engine.load(QUrl("qrc:/ImageViewer/qml/main.qml")); QVERIFY(!engine.rootObjects().isEmpty());
        auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().first()); QVERIFY(window);
        auto* aurora = findItem(window->contentItem(), "auroraBackground"); QVERIFY(aurora);
        auto* animation = window->findChild<QObject*>("auroraAnimation"); QVERIFY(animation);
        window->requestActivate(); QTRY_VERIFY(window->isActive());
        QTRY_VERIFY(!animation->property("paused").toBool());
        window->setProperty("auroraAnimated", false);
        QTRY_VERIFY(animation->property("paused").toBool());
        const double phase = aurora->property("phase").toDouble();
        QTest::qWait(160); QCOMPARE(aurora->property("phase").toDouble(), phase);
        window->setProperty("auroraIntensity", 0.35);
        QVERIFY(qFuzzyCompare(aurora->opacity(), 0.35 * 0.92));
        window->setProperty("isDarkTheme", false);
        QVERIFY(qFuzzyCompare(aurora->opacity(), 0.35 * 0.36));
        window->setProperty("enableAurora", false); QVERIFY(!aurora->isVisible());
        window->setProperty("auroraAnimated", true); QVERIFY(animation->property("paused").toBool());
        window->setProperty("enableAurora", true); QTRY_VERIFY(!animation->property("paused").toBool());
        window->setProperty("settingsModalOpen", true); QTRY_VERIFY(animation->property("paused").toBool());
        window->setProperty("settingsModalOpen", false); QTRY_VERIFY(!animation->property("paused").toBool());
        QCOMPARE(gallery.loadSetting("ui/auroraIntensity").toDouble(), 0.35);
        window->setProperty("isDarkTheme", true);
        window->setProperty("auroraAnimated", false);
        window->setProperty("auroraIntensity", 1.0);
        window->setProperty("lobeAccent", QColor("#52c41a"));
        window->setProperty("showLeftSidebar", false);
        window->setProperty("showInspector", false);
        QTest::qWait(400);
        const auto image = window->grabWindow(); QVERIFY(!image.isNull());
        // A glow may vary in brightness, but must not end in a sharp horizontal band.
        for (int x : {image.width() / 5, image.width() * 4 / 5}) {
            for (int y = 150; y < std::min(650, image.height() - 2); ++y) {
                const auto above = image.pixelColor(x, y), below = image.pixelColor(x, y + 1);
                const int jump = std::max({qAbs(above.red() - below.red()), qAbs(above.green() - below.green()), qAbs(above.blue() - below.blue())});
                QVERIFY2(jump <= 5, qPrintable(QString("Hard aurora edge at %1,%2 (jump %3)").arg(x).arg(y).arg(jump)));
            }
        }
        window->close();
    }
};
QTEST_MAIN(RegressionTests)
#include "test_regressions.moc"
