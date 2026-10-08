cmake_minimum_required(VERSION 3.21)

project(ImageViewer VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS 
    Core 
    Gui 
    Qml 
    Quick 
    QuickControls2 
    QuickDialogs2
    Concurrent
)
find_package(ZLIB REQUIRED)
qt_standard_project_setup(REQUIRES 6.8)

# Main Application
set_source_files_properties(resources/app.rc PROPERTIES
    OBJECT_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/resources/app.ico")
qt_add_executable(ImageViewer
    src/main.cpp
    src/metadata_reader.h
    src/metadata_reader.cpp
    src/tag_autocomplete.h
    src/tag_autocomplete.cpp
    src/gallery_model.h
    src/gallery_model.cpp
    resources/app.rc
)

qt_add_qml_module(ImageViewer
    URI ImageViewer
    VERSION 1.0
    RESOURCE_PREFIX /
    QML_FILES
        qml/main.qml
    RESOURCES
        resources/app.ico
        resources/app.svg
        resources/app.png
        locales/en_US.json
        locales/ru_RU.json
        locales/zh_CN.json
        locales/es_ES.json
        locales/ja_JP.json
        locales/de_DE.json
        locales/fr_FR.json
        locales/pt_BR.json
        locales/ko_KR.json
        locales/zh_TW.json
        locales/pl_PL.json
        locales/tr_TR.json
        locales/it_IT.json
        locales/uk_UA.json
        locales/id_ID.json
        locales/vi_VN.json
        locales/th_TH.json
        locales/ar_SA.json
        locales/hi_IN.json
        locales/nl_NL.json
)

target_link_libraries(ImageViewer PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::QuickDialogs2
    Qt6::Concurrent
    ZLIB::ZLIB
)

# Automated Test Suite
include(CTest)
if(BUILD_TESTING)
find_package(Qt6 6.8 REQUIRED COMPONENTS Test)
qt_add_executable(ImageViewerTests
    tests/test_main.cpp
    src/metadata_reader.h
    src/metadata_reader.cpp
    src/tag_autocomplete.h
    src/tag_autocomplete.cpp
    src/gallery_model.h
    src/gallery_model.cpp
)

target_link_libraries(ImageViewerTests PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Concurrent
    ZLIB::ZLIB
)
target_compile_definitions(ImageViewerTests PRIVATE IMAGEVIEWER_TEST_GALLERY="${CMAKE_CURRENT_SOURCE_DIR}/test_gallery")
add_test(NAME ImageViewer.Legacy COMMAND ImageViewerTests)
set_tests_properties(ImageViewer.Legacy PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;GALIMV_SETTINGS_FILE=${CMAKE_CURRENT_BINARY_DIR}/legacy-settings.ini;GALIMV_CACHE_DIR=${CMAKE_CURRENT_BINARY_DIR}/legacy-cache")

qt_add_executable(ImageViewerRegressionTests
    tests/test_regressions.cpp src/metadata_reader.cpp src/metadata_reader.h
    src/tag_autocomplete.cpp src/tag_autocomplete.h src/gallery_model.cpp src/gallery_model.h)
target_link_libraries(ImageViewerRegressionTests PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Test Qt6::Concurrent ZLIB::ZLIB)
set_target_properties(ImageViewerRegressionTests PROPERTIES WIN32_EXECUTABLE FALSE)
target_compile_definitions(ImageViewerRegressionTests PRIVATE IMAGEVIEWER_TEST_GALLERY="${CMAKE_CURRENT_SOURCE_DIR}/test_gallery")
qt_add_resources(ImageViewerRegressionTests regression_qml PREFIX /ImageViewer FILES qml/main.qml locales/en_US.json locales/ru_RU.json)
add_test(NAME ImageViewer.Regressions COMMAND ImageViewerRegressionTests -o -,txt)
set_tests_properties(ImageViewer.Regressions PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
endif()

install(TARGETS ImageViewer RUNTIME DESTINATION bin BUNDLE DESTINATION .)
qt_generate_deploy_qml_app_script(TARGET ImageViewer OUTPUT_SCRIPT deploy_script NO_UNSUPPORTED_PLATFORM_ERROR)
install(SCRIPT ${deploy_script})
