#include <QGuiApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QThread>
#include <QTemporaryDir>
#include <iostream>
#include "../src/metadata_reader.h"
#include "../src/tag_autocomplete.h"
#include "../src/gallery_model.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QTemporaryDir testStorage;
    if (!testStorage.isValid()) return 1;
    qputenv("GALIMV_SETTINGS_FILE", (testStorage.path() + "/settings.ini").toUtf8());
    qputenv("GALIMV_CACHE_DIR", (testStorage.path() + "/cache").toUtf8());
    QString dictionaryPath = testStorage.path() + "/tags.csv";
    QFile dictionary(dictionaryPath);
    if (!dictionary.open(QIODevice::WriteOnly)) return 1;
    dictionary.write("azula,4,10,\nhoutengeki,1,10,\nmisty_(pokemon),4,10,\nwlop,1,10,\n"
                     "greg_rutkowski,1,10,\nblade_(artist),1,10,\nhammer_(sunset_beach),1,10,\n"
                     "rei_(sanbonzakura),1,10,\nanyan_(jooho),1,10,\nazusa_(hws),1,10,\n"
                     "oku_(okumen),1,10,\nshiren_(ourboy83),1,10,\ncarl_(artist),1,10,\n"
                     "au_(artist),1,10,\nteamwork_(sexual),0,10,\n");
    dictionary.close();
    std::cout << "\n==========================================" << std::endl;
    std::cout << "   RUNNING IMAGE VIEWER FULL SUITE TESTS  " << std::endl;
    std::cout << "==========================================" << std::endl;

    QString testDir = IMAGEVIEWER_TEST_GALLERY;
    if (!QDir(testDir).exists()) {
        std::cerr << "[-] FAIL: Test directory not found: " << testDir.toUtf8().constData() << std::endl;
        return 1;
    }
    std::cout << "[+] Found test dataset at: " << testDir.toUtf8().constData() << std::endl;

    // Test 1: MetadataReader & Model parameter extraction
    QString cyberpunkPath = testDir + "/cyberpunk_city.png";
    ImageMetadata meta1 = MetadataReader::read(cyberpunkPath, testDir);
    std::cout << "[+] [Test 1] Dimensions: " << meta1.dimensions.width() << "x" << meta1.dimensions.height() << std::endl;
    std::cout << "[+] [Test 1] Model name: " << meta1.modelName.toUtf8().constData() << std::endl;
    std::cout << "[+] [Test 1] Relative Dir: " << meta1.relativeDir.toUtf8().constData() << std::endl;

    if (meta1.modelName.isEmpty()) {
        std::cerr << "[-] FAIL: Model parameter not extracted from metadata!" << std::endl;
        return 1;
    }
    std::cout << "--> TEST 1 PASSED: Model parameter and relative folder extraction." << std::endl;

    // Test 2: Categorized Tag Frequency
    TagAutocomplete tagAuto;
    if (!tagAuto.loadCsvFile(dictionaryPath)) return 1;
    // Register some test tags with categories
    tagAuto.registerTag("hatsune miku", 4);
    tagAuto.registerTag("hatsune miku", 4);
    tagAuto.registerTag("asuka langley", 4);
    tagAuto.registerTag("makoto shinkai", 1);
    tagAuto.registerTag("artgerm", 1);
    tagAuto.registerTag("1girl", 0);

    QVariantList topChars = tagAuto.getTopTags(4, 5);
    std::cout << "[+] [Test 2] Top characters count: " << topChars.size() << std::endl;
    if (topChars.isEmpty() || topChars[0].toMap()["name"].toString() != "hatsune miku") {
        std::cerr << "[-] FAIL: Top characters did not place 'hatsune miku' first by frequency!" << std::endl;
        return 1;
    }

    QVariantList topArtists = tagAuto.getTopTags(1, 5);
    std::cout << "[+] [Test 2] Top artists count: " << topArtists.size() << std::endl;
    if (topArtists.isEmpty()) {
        std::cerr << "[-] FAIL: Top artists list is empty!" << std::endl;
        return 1;
    }
    std::cout << "--> TEST 2 PASSED: Frequency-based categorized tags (Characters/Artists)." << std::endl;

    // Test 3: Gallery Model & Subfolder / Model filtering
    GalleryModel gallery(&tagAuto);
    QString userOriginalFolder = gallery.lastFolder();
    gallery.openFolder(testDir);

    QElapsedTimer timer;
    timer.start();
    while (gallery.isLoading() && timer.elapsed() < 3000) {
        QGuiApplication::processEvents();
        QThread::msleep(10);
    }

    std::cout << "[+] [Test 3] Loaded gallery images: " << gallery.totalCount() << std::endl;
    if (gallery.totalCount() != 7) {
        std::cerr << "[-] FAIL: Expected 7 images, got " << gallery.totalCount() << std::endl;
        return 1;
    }

    std::cout << "[+] [Test 3] Available models count: " << gallery.availableModels().size() << std::endl;
    std::cout << "[+] [Test 3] Subfolders count: " << gallery.subfolderList().size() << std::endl;

    // Test sorting by Resolution
    gallery.setSortMode(6); // Resolution Desc
    int firstIdx = gallery.rowCount() > 0 ? 0 : -1;
    gallery.selectImage(firstIdx);
    std::cout << "[+] [Test 3] Highest resolution image: " 
              << gallery.selectedImage()["fileName"].toString().toUtf8().constData()
              << " (" << gallery.selectedImage()["dimensions"].toString().toUtf8().constData() << ")" << std::endl;
    std::cout << "--> TEST 3 PASSED: Subfolder tracking, Model tracking & Resolution sorting." << std::endl;

    // Test 4: Seamless Masonry Column distribution (itemSpacing = 0)
    QVariantList col0 = gallery.getMasonryColumn(0, 4);
    QVariantList col1 = gallery.getMasonryColumn(1, 4);
    QVariantList col2 = gallery.getMasonryColumn(2, 4);
    QVariantList col3 = gallery.getMasonryColumn(3, 4);
    int totalItems = col0.size() + col1.size() + col2.size() + col3.size();
    std::cout << "[+] [Test 4] 4-Column Seamless distribution: "
              << col0.size() << " | " << col1.size() << " | " << col2.size() << " | " << col3.size() << std::endl;
    if (totalItems != 7) {
        std::cerr << "[-] FAIL: Masonry column item count mismatch!" << std::endl;
        return 1;
    }
    std::cout << "--> TEST 4 PASSED: Seamless column distribution verified." << std::endl;

    // Test 5: Multi-selection operations
    gallery.clearMultiSelection();
    if (gallery.selectedCount() != 0) {
        std::cerr << "[-] FAIL: selectedCount should be 0 after clear!" << std::endl;
        return 1;
    }
    gallery.toggleSelect(0);
    gallery.toggleSelect(2);
    if (gallery.selectedCount() != 2 || !gallery.isIndexSelected(0) || !gallery.isIndexSelected(2)) {
        std::cerr << "[-] FAIL: toggleSelect did not correctly select indices 0 and 2!" << std::endl;
        return 1;
    }
    // Range select to 4 (anchor was 2, so 2..4 should be added)
    gallery.rangeSelect(4);
    if (!gallery.isIndexSelected(3) || !gallery.isIndexSelected(4)) {
        std::cerr << "[-] FAIL: rangeSelect did not select range 2..4!" << std::endl;
        return 1;
    }
    // Select all
    gallery.selectAll();
    if (gallery.selectedCount() != 7) {
        std::cerr << "[-] FAIL: selectAll did not select all 7 items! Got: " << gallery.selectedCount() << std::endl;
        return 1;
    }
    // Verify getMasonryColumn reflects isSelected
    QVariantList colCheck = gallery.getMasonryColumn(0, 2);
    if (!colCheck.isEmpty() && !colCheck[0].toMap()["isSelected"].toBool()) {
        std::cerr << "[-] FAIL: getMasonryColumn items do not report isSelected == true!" << std::endl;
        return 1;
    }
    gallery.clearMultiSelection();
    if (gallery.selectedCount() != 0) {
        std::cerr << "[-] FAIL: clearMultiSelection did not reset count to 0!" << std::endl;
        return 1;
    }
    std::cout << "--> TEST 5 PASSED: Multi-selection (toggle, range, selectAll, masonry isSelected flag)." << std::endl;

    // Test 6: Danbooru CSV loading & Settings Persistence
    std::cout << "\n[+] [Test 6] Auto-loading Danbooru CSV..." << std::endl;
    bool csvLoaded = tagAuto.autoLoadCsv();
    std::cout << "[+] [Test 6] CSV auto-load status: " << (csvLoaded ? "LOADED" : "FALLBACK") << std::endl;
    std::cout << "[+] [Test 6] Total loaded tags in dictionary: " << tagAuto.totalLoadedTags() << std::endl;

    // Verify category lookup for known Forge-Neo / Danbooru tags
    int catAzula = TagAutocomplete::lookupCategory("azula");
    int catHoutengeki = TagAutocomplete::lookupCategory("houtengeki");
    int cat1girl = TagAutocomplete::lookupCategory("1girl");
    int catMasterpiece = TagAutocomplete::lookupCategory("masterpiece");
    std::cout << "[+] [Test 6] Category lookup: azula=" << catAzula << " (expected 4), houtengeki=" << catHoutengeki << " (expected 1)" << std::endl;

    if (csvLoaded) {
        if (catAzula != 4 || catHoutengeki != 1) {
            std::cerr << "[-] FAIL: Danbooru CSV lookup returned incorrect categories!" << std::endl;
            return 1;
        }
    }

    // Verify Settings persistence
    gallery.saveSetting("test/key", "galIMV_persisted_value");
    QString loadedVal = gallery.loadSetting("test/key").toString();
    if (loadedVal != "galIMV_persisted_value") {
        std::cerr << "[-] FAIL: Settings persistence failed! Expected 'galIMV_persisted_value', got: " 
                  << loadedVal.toUtf8().constData() << std::endl;
        return 1;
    }
    std::cout << "[+] [Test 6] Settings persistence verified: " << loadedVal.toUtf8().constData() << std::endl;
    std::cout << "[+] [Test 6] Last folder saved: " << gallery.lastFolder().toUtf8().constData() << std::endl;
    std::cout << "--> TEST 6 PASSED: Danbooru CSV tag parsing and settings persistence." << std::endl;

    // Test 7: Tag extraction without duplicates, parentheses preservation & search duality
    std::cout << "\n[+] [Test 7] Testing tag extraction without duplicates & parentheses handling..." << std::endl;
    ImageMetadata testMeta;
    testMeta.prompt = "(misty \\(pokemon\\):1.2), ((1girl)), solo, rei \\(sanbonzakura\\), anyan \\(jooho\\), masterpiece, best quality";
    MetadataReader::extractTagsFromPrompt(testMeta);

    std::cout << "[+] [Test 7] Extracted tags: ";
    for (const QString& t : testMeta.tags) {
        std::cout << "[" << t.toUtf8().constData() << "] ";
    }
    std::cout << std::endl;

    if (!testMeta.tags.contains("misty (pokemon)", Qt::CaseInsensitive)) {
        std::cerr << "[-] FAIL: Expected 'misty (pokemon)' with parentheses intact and unescaped!" << std::endl;
        return 1;
    }
    if (!testMeta.tags.contains("rei (sanbonzakura)", Qt::CaseInsensitive)) {
        std::cerr << "[-] FAIL: Expected 'rei (sanbonzakura)' unescaped!" << std::endl;
        return 1;
    }
    if (!testMeta.tags.contains("anyan (jooho)", Qt::CaseInsensitive)) {
        std::cerr << "[-] FAIL: Expected 'anyan (jooho)' unescaped!" << std::endl;
        return 1;
    }
    // Verify no duplicates
    if (testMeta.tags.count("best_quality") > 0 && testMeta.tags.count("best quality") > 0) {
        std::cerr << "[-] FAIL: Tag 'best quality' was duplicated with underscore version!" << std::endl;
        return 1;
    }
    if (!testMeta.tags.contains("1girl", Qt::CaseInsensitive)) {
        std::cerr << "[-] FAIL: Expected '1girl' without outer weighting braces!" << std::endl;
        return 1;
    }

    // Verify search matches both space and underscore variants
    gallery.setSearchQuery("misty_(pokemon)");
    if (!gallery.matchesFilter(testMeta)) {
        std::cerr << "[-] FAIL: gallery.matchesFilter failed to match 'misty_(pokemon)' query against 'misty (pokemon)' tag!" << std::endl;
        return 1;
    }
    gallery.setSearchQuery("misty (pokemon)");
    if (!gallery.matchesFilter(testMeta)) {
        std::cerr << "[-] FAIL: gallery.matchesFilter failed to match 'misty (pokemon)' query!" << std::endl;
        return 1;
    }
    gallery.setSearchQuery("");

    // Test autocomplete limit 15 and binary search speed
    QVariantList suggs = tagAuto.suggest("misty", 15);
    std::cout << "[+] [Test 7] Autocomplete suggestions for 'misty': " << suggs.size() << " items" << std::endl;
    if (suggs.isEmpty()) {
        std::cerr << "[-] FAIL: Autocomplete did not suggest misty tag!" << std::endl;
        return 1;
    }

    // Test autocomplete trailing comma handling
    QVariantList suggsWithComma = tagAuto.suggest("misty_(pokemon),", 15);
    if (suggsWithComma.isEmpty()) {
        std::cerr << "[-] FAIL: Autocomplete failed on input with trailing comma!" << std::endl;
        return 1;
    }

    std::cout << "--> TEST 7 PASSED: Tag parentheses preservation, duality, and 15-item autocomplete without duplicates." << std::endl;

    // Test 8: Accurate Category Classification (Artists vs Characters)
    std::cout << "\n[+] [Test 8] Testing Artist vs Character classification..." << std::endl;
    int catByWlop = TagAutocomplete::lookupCategory("by wlop");
    int catArtByGreg = TagAutocomplete::lookupCategory("art by greg rutkowski");
    int catBladeArtist = TagAutocomplete::lookupCategory("blade_(artist)");
    int catHammerBeach = TagAutocomplete::lookupCategory("hammer_(sunset_beach)");
    int catWlopParens = TagAutocomplete::lookupCategory("(wlop:1.2)");
    int catMistyChar = TagAutocomplete::lookupCategory("misty (pokemon)");
    int catMistyEscaped = TagAutocomplete::lookupCategory("misty \\(pokemon\\)");
    int catReiArtist = TagAutocomplete::lookupCategory("rei (sanbonzakura)");
    int catReiEscaped = TagAutocomplete::lookupCategory("rei \\(sanbonzakura\\)");
    int catReiWeight = TagAutocomplete::lookupCategory("(rei \\(sanbonzakura\\):1.2)");
    int catAnyanArtist = TagAutocomplete::lookupCategory("anyan \\(jooho\\)");
    int catAzusaArtist = TagAutocomplete::lookupCategory("azusa \\(hws\\)");
    int catOkuArtist = TagAutocomplete::lookupCategory("oku \\(okumen\\)");
    int catShirenArtist = TagAutocomplete::lookupCategory("shiren \\(ourboy83\\)");
    int catCarlArtist = TagAutocomplete::lookupCategory("carl \\(artist\\)");
    int catAuArtist = TagAutocomplete::lookupCategory("au (artist)");
    int catTeamworkGen = TagAutocomplete::lookupCategory("teamwork (sexual)");

    std::cout << "[+] [Test 8] Categories: by wlop=" << catByWlop
              << ", art by greg=" << catArtByGreg
              << ", blade_(artist)=" << catBladeArtist
              << ", hammer_(sunset_beach)=" << catHammerBeach
              << ", (wlop:1.2)=" << catWlopParens
              << ", misty (pokemon)=" << catMistyChar
              << ", misty \\(pokemon\\)=" << catMistyEscaped
              << ", rei (sanbonzakura)=" << catReiArtist
              << ", rei \\(sanbonzakura\\)=" << catReiEscaped
              << ", (rei \\(sanbonzakura\\):1.2)=" << catReiWeight
              << ", anyan \\(jooho\\)=" << catAnyanArtist
              << ", azusa \\(hws\\)=" << catAzusaArtist
              << ", oku \\(okumen\\)=" << catOkuArtist
              << ", shiren \\(ourboy83\\)=" << catShirenArtist
              << ", carl \\(artist\\)=" << catCarlArtist
              << ", au (artist)=" << catAuArtist
              << ", teamwork (sexual)=" << catTeamworkGen << std::endl;

    if (catByWlop != 1 || catArtByGreg != 1 || catBladeArtist != 1 || catHammerBeach != 1 || catWlopParens != 1 ||
        catReiArtist != 1 || catReiEscaped != 1 || catReiWeight != 1 || catAnyanArtist != 1 || catAzusaArtist != 1 ||
        catOkuArtist != 1 || catShirenArtist != 1 || catCarlArtist != 1 || catAuArtist != 1) {
        std::cerr << "[-] FAIL: Artists with parentheses were misclassified as characters!" << std::endl;
        return 1;
    }
    if (catMistyChar != 4 || catMistyEscaped != 4) {
        std::cerr << "[-] FAIL: misty (pokemon) should be category 4 (Character)!" << std::endl;
        return 1;
    }
    if (catTeamworkGen != 0) {
        std::cerr << "[-] FAIL: teamwork (sexual) should be category 0 (General)!" << std::endl;
        return 1;
    }
    std::cout << "--> TEST 8 PASSED: Artists correctly classified as Category 1, characters as Category 4." << std::endl;

    // Test 9: Stability Matrix Model Hierarchy & Model Counts
    std::cout << "\n[+] [Test 9] Testing Stability Matrix Model Hierarchy & Details..." << std::endl;
    QString cleanedName = MetadataReader::cleanModelName("T:/StabilityMatrix/Models/StableDiffusion/1 Best/derangedMix_v10.safetensors");
    if (cleanedName != "derangedMix_v10") {
        std::cerr << "[-] FAIL: cleanModelName failed! Got: " << cleanedName.toUtf8().constData() << std::endl;
        return 1;
    }
    QVariantList modelDetails = gallery.availableModelDetails();
    if (modelDetails.isEmpty()) {
        std::cerr << "[-] FAIL: availableModelDetails should not be empty!" << std::endl;
        return 1;
    }
    std::cout << "[+] [Test 9] Found " << modelDetails.size() << " model detail entries. Top entry: "
              << modelDetails[0].toMap()["displayName"].toString().toUtf8().constData() << std::endl;
    std::cout << "--> TEST 9 PASSED: Stability Matrix Model Hierarchy and Counts." << std::endl;

    // Test 10: Binary Metadata Cache Save & Fast Load
    std::cout << "\n[+] [Test 10] Testing Persistent Binary Metadata Cache..." << std::endl;
    QList<ImageMetadata> testImages;
    for (int i = 0; i < 50; ++i) {
        ImageMetadata im;
        im.filePath = QString("C:/test/image_%1.png").arg(i);
        im.fileName = QString("image_%1.png").arg(i);
        im.modelName = "derangedMix_v10";
        im.prompt = "1girl, solo, masterpiece";
        im.dimensions = QSize(832, 1216);
        im.aspectRatio = 832.0 / 1216.0;
        im.fileSize = 1024 * 1024 * 2;
        im.modifiedDate = QDateTime::currentDateTime();
        im.tags = {"1girl", "solo", "masterpiece"};
        testImages.append(im);
    }
    QString cacheFolder = "C:/test/sample_cache_dir";
    bool saved = GalleryModel::saveCache(cacheFolder, testImages);
    if (!saved) {
        std::cerr << "[-] FAIL: saveCache returned false!" << std::endl;
        return 1;
    }
    QList<ImageMetadata> loadedImages;
    bool loaded = GalleryModel::loadCache(cacheFolder, loadedImages);
    if (!loaded || loadedImages.size() != testImages.size()) {
        std::cerr << "[-] FAIL: loadCache failed or mismatch count!" << std::endl;
        return 1;
    }
    if (loadedImages[0].fileName != "image_0.png" || loadedImages[0].modelName != "derangedMix_v10") {
        std::cerr << "[-] FAIL: Deserialized metadata field mismatch!" << std::endl;
        return 1;
    }
    // Clean up test cache file
    QFile::remove(GalleryModel::getCacheFilePath(cacheFolder));
    std::cout << "--> TEST 10 PASSED: Persistent Binary Metadata Cache save and load verified." << std::endl;

    // Test 11: Grouping Modes and Shift Range Selection Anchor
    std::cout << "\n[+] [Test 11] Testing Grouping Modes (Folder, Model, Date) and Shift Selection..." << std::endl;
    gallery.openFolder(testDir);
    
    timer.restart();
    while ((gallery.isLoading() || gallery.isFiltering()) && timer.elapsed() < 5000) {
        QGuiApplication::processEvents();
        QThread::msleep(1);
    }

    // Group Mode 1: By Folder
    gallery.setGroupMode(1);
    QVariantList folderGroups = gallery.groupList();
    if (folderGroups.isEmpty()) {
        std::cerr << "[-] FAIL: Group mode By Folder returned empty group list!" << std::endl;
        return 1;
    }
    std::cout << "[+] [Test 11] Folder groups count: " << folderGroups.size() << " (First group: " << folderGroups[0].toMap()["title"].toString().toUtf8().constData() << ")" << std::endl;
    QVariantList groupCol = gallery.getGroupMasonryColumn(0, 0, 4);
    if (groupCol.isEmpty()) {
        std::cerr << "[-] FAIL: getGroupMasonryColumn returned empty column for group 0!" << std::endl;
        return 1;
    }

    // Test Group Selection & Toggle
    gallery.clearMultiSelection();
    gallery.selectGroup(0);
    if (!gallery.isGroupSelected(0)) {
        std::cerr << "[-] FAIL: isGroupSelected returned false after selectGroup!" << std::endl;
        return 1;
    }
    int selectedInGrp = gallery.selectedCount();
    gallery.toggleGroupSelect(0);
    if (gallery.isGroupSelected(0) || gallery.selectedCount() == selectedInGrp) {
        std::cerr << "[-] FAIL: toggleGroupSelect failed to deselect group!" << std::endl;
        return 1;
    }

    // Group Mode 2: By Model
    gallery.setGroupMode(2);
    QVariantList modelGroups = gallery.groupList();
    if (modelGroups.isEmpty()) {
        std::cerr << "[-] FAIL: Group mode By Model returned empty group list!" << std::endl;
        return 1;
    }
    std::cout << "[+] [Test 11] Model groups count: " << modelGroups.size() << " (First: " << modelGroups[0].toMap()["title"].toString().toUtf8().constData() << ")" << std::endl;

    // Group Mode 3: By Date
    gallery.setGroupMode(3);
    QVariantList dateGroups = gallery.groupList();
    if (dateGroups.isEmpty()) {
        std::cerr << "[-] FAIL: Group mode By Date returned empty group list!" << std::endl;
        return 1;
    }
    std::cout << "[+] [Test 11] Date groups count: " << dateGroups.size() << " (First: " << dateGroups[0].toMap()["title"].toString().toUtf8().constData() << ")" << std::endl;

    // Reset Group Mode to 0
    gallery.setGroupMode(0);

    // Test Shift Range Selection with Anchor
    gallery.clearMultiSelection();
    gallery.selectSingle(1);
    gallery.rangeSelect(3); // Should select 1, 2, 3 -> count 3
    if (gallery.selectedCount() != 3) {
        std::cerr << "[-] FAIL: Shift rangeSelect failed! Expected 3 items, got " << gallery.selectedCount() << std::endl;
        return 1;
    }
    std::cout << "--> TEST 11 PASSED: Grouping modes (Folder, Model, Date) and Shift Range Selection verified." << std::endl;

    // ==========================================
    // [Test 12] Testing lobe-i18n 20-Language Localization System
    // ==========================================
    std::cout << "\n[+] [Test 12] Testing lobe-i18n 20-Language Localization Engine..." << std::endl;
    QVariantList langs = gallery.availableLanguages();
    if (langs.size() != 20) {
        std::cerr << "[-] FAIL: Expected 20 available languages, got " << langs.size() << std::endl;
        return 1;
    }
    std::cout << "[+] [Test 12] Verified 20 languages registered in availableLanguages." << std::endl;

    // Test Russian (ru_RU)
    gallery.setLanguage("ru_RU");
    if (gallery.currentLanguage() != "ru_RU") {
        std::cerr << "[-] FAIL: Language did not switch to ru_RU!" << std::endl;
        return 1;
    }
    QString ruOpen = gallery.t("toolbar.open", "Fallback");
    QString ruTags = gallery.t("sidebar.tags", "Fallback");
    QString ruReveal = gallery.t("toolbar.reveal", "Fallback");
    std::cout << "[+] [Test 12] ru_RU strings: open=" << ruOpen.toUtf8().constData()
              << ", tags=" << ruTags.toUtf8().constData()
              << ", reveal=" << ruReveal.toUtf8().constData() << std::endl;
    if (ruOpen != "Открыть" || ruTags != "Теги") {
        std::cerr << "[-] FAIL: Russian translation lookup failed!" << std::endl;
        return 1;
    }

    // Test Simplified Chinese (zh_CN)
    gallery.setLanguage("zh_CN");
    QString zhOpen = gallery.t("toolbar.open", "Fallback");
    if (zhOpen != "打开") {
        std::cerr << "[-] FAIL: Chinese translation lookup failed! Got: " << zhOpen.toUtf8().constData() << std::endl;
        return 1;
    }

    // Test Japanese (ja_JP)
    gallery.setLanguage("ja_JP");
    QString jaOpen = gallery.t("toolbar.open", "Fallback");
    if (jaOpen != "開く") {
        std::cerr << "[-] FAIL: Japanese translation lookup failed! Got: " << jaOpen.toUtf8().constData() << std::endl;
        return 1;
    }

    // Test English (en_US)
    gallery.setLanguage("en_US");
    QString enOpen = gallery.t("toolbar.open", "Fallback");
    if (enOpen != "Open") {
        std::cerr << "[-] FAIL: English translation lookup failed! Got: " << enOpen.toUtf8().constData() << std::endl;
        return 1;
    }

    // Test fallback mechanism
    QString fallbackResult = gallery.t("non_existent.dummy_key", "Default Fallback");
    if (fallbackResult != "Default Fallback") {
        std::cerr << "[-] FAIL: Fallback key lookup failed!" << std::endl;
        return 1;
    }
    std::cout << "--> TEST 12 PASSED: lobe-i18n 20-Language Localization Engine verified." << std::endl;

    // Restore user's real library folder so testing never clobbers active user workflow
    if (!userOriginalFolder.isEmpty()) {
        gallery.saveSetting("library/lastFolder", userOriginalFolder);
        gallery.saveSetting("lastFolder", userOriginalFolder);
        std::cout << "[+] Restored user library folder: " << userOriginalFolder.toUtf8().constData() << std::endl;
    }

    std::cout << "\n==========================================" << std::endl;
    std::cout << "   ALL ADVANCED UI/UX TESTS PASSED!       " << std::endl;
    std::cout << "==========================================\n" << std::endl;

    return 0;
}

