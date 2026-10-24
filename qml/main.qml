import QtQuick
import "DesignSystem.js" as UI
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import QtQuick.Shapes

ApplicationWindow {
    id: root
    width: 1480
    height: 920
    minimumWidth: 1040
    minimumHeight: 660
    visible: true
    title: qsTr("galIMV")
    color: root.bgApp

    readonly property var uiDesign: UI.design
    readonly property int controlHeight: UI.design.metrics.control
    // High-DPI Scaling Factor
    readonly property real dpr: (Screen.devicePixelRatio > 0) ? Screen.devicePixelRatio : 1.0

    // ================= 1. THEME & PALETTE SYSTEM =================
    property bool isDarkTheme: true

    // Signature Accent Colors Palette - Lobe
    readonly property var lobeColors: UI.design.accents
    property color lobeAccent: "#1677ff"
    property string lobeAccentName: "Lobe Blue"
    property bool appearanceReady: false
    readonly property var backgroundTones: UI.neutralTones
    property string backgroundToneName: "zinc"
    onBackgroundToneNameChanged: if(appearanceReady)gallery.saveSetting("ui/backgroundToneName",backgroundToneName)

    // Background Tone & Darkness Properties (Dark Theme)
    // 0 = Neutral Zinc, 1 = Cool Slate, 2 = Mauve, 3 = Pure OLED
    property int bgTonePreset: 0
    property real bgDarkness: 0.08 // 0.0 (OLED #000000) to 0.32 (Medium Slate Gray)

    // Background Tone & Brightness Properties (Light Theme)
    // 0 = Neutral Zinc, 1 = Cool Slate, 2 = Warm Paper, 3 = Pure Snow
    property int lightTonePreset: 0
    property real lightBrightness: 0.04 // 0.00 (Pure White) to 0.25 (Soft Muted Gray)

    property bool enableSpecular: true

    // Glassmorphism / Liquid Glass Settings
    property bool enableGlass: true
    property real glassOpacity: 0.72        // was 0.78
    property real glassBlurAmount: 0.82     // was 0.75 — stronger blur for liquid glass

    // Liquid Glass tint strength (0.0 = clear, 1.0 = heavy tint)
    property real glassTintStrength: 0.55
    // Liquid Glass refraction shimmer (chroma shift effect via saturation boost)
    property real glassChroma: 0.18

    // Aurora Borealis Settings & Dynamic Harmonic Color Palettes
    property bool enableAurora: true
    onEnableAuroraChanged: gallery.saveSetting("ui/enableAurora", enableAurora)
    property real auroraIntensity: 0.70
    property bool auroraAnimated: true
    onAuroraIntensityChanged: gallery.saveSetting("ui/auroraIntensity", auroraIntensity)
    onAuroraAnimatedChanged: gallery.saveSetting("ui/auroraAnimated", auroraAnimated)

    readonly property color auroraColor1: root.isDarkTheme ? root.lobeAccent : Qt.hsla(Qt.color(root.lobeAccent).hslHue,.82,.42,1)
    readonly property color auroraColor2: {
        var c = Qt.color(root.lobeAccent)
        var h = (c.hslHue + 0.14) % 1.0
        return Qt.hsla(h, Math.min(1.0, c.hslSaturation * 1.10), Math.max(0.42, Math.min(0.68, c.hslLightness)), 1.0)
    }
    readonly property color auroraColor3: {
        var c = Qt.color(root.lobeAccent)
        var h = (c.hslHue - 0.12 + 1.0) % 1.0
        return Qt.hsla(h, Math.min(1.0, c.hslSaturation * 1.05), Math.max(0.38, Math.min(0.62, c.hslLightness)), 1.0)
    }
    readonly property color auroraColor4: {
        var c = Qt.color(root.lobeAccent)
        var h = (c.hslHue + 0.45) % 1.0
        return Qt.hsla(h, Math.min(0.90, c.hslSaturation * 0.90), Math.max(0.48, Math.min(0.72, c.hslLightness)), 1.0)
    }

    function toneDefinition(name) {
        for(let i=0;i<backgroundTones.length;i++)if(backgroundTones[i].id===name)return backgroundTones[i];
        return null;
    }
    function toneTitle(option,dark) {
        return tr("undertones."+option.id+"."+(dark?"dark":"light"),option[dark?"darkName":"lightName"]);
    }
    function toneColorFor(name,dark,level) {
        const option=toneDefinition(name)||backgroundTones[0];
        if(option.pure)return option[dark?"dark":"light"];
        const c=Qt.color(option[dark?"dark":"light"]);
        const lightness=dark?Math.max(0,Math.min(.38,c.hslLightness+level-.08)):Math.max(.68,Math.min(1,c.hslLightness+.04-level));
        return Qt.hsla(c.hslHue,c.hslSaturation,lightness,1);
    }
    readonly property color darkToneColor: toneColorFor(backgroundToneName,true,bgDarkness)
    readonly property color lightToneColor: toneColorFor(backgroundToneName,false,lightBrightness)
    readonly property real darkToneR: darkToneColor.r
    readonly property real darkToneG: darkToneColor.g
    readonly property real darkToneB: darkToneColor.b
    readonly property real lightToneR: lightToneColor.r
    readonly property real lightToneG: lightToneColor.g
    readonly property real lightToneB: lightToneColor.b

    // Direct Reactive Color Palette for both Dark & Light Themes
    readonly property color bgApp: isDarkTheme ?
        Qt.rgba(darkToneR, darkToneG, darkToneB, 1.0) :
        Qt.rgba(lightToneR, lightToneG, lightToneB, 1.0)

    readonly property color bgSurface: isDarkTheme ?
        Qt.rgba(Math.min(1.0, darkToneR + 0.04), Math.min(1.0, darkToneG + 0.04), Math.min(1.0, darkToneB + 0.06), enableGlass ? Math.min(0.70, glassOpacity * 0.65) : 1.0) :
        (enableGlass ? Qt.rgba(Math.min(1.0, lightToneR + 0.02), Math.min(1.0, lightToneG + 0.02), Math.min(1.0, lightToneB + 0.02), Math.min(0.72, glassOpacity * 0.66)) : Qt.rgba(Math.min(1.0, lightToneR + 0.01), Math.min(1.0, lightToneG + 0.01), Math.min(1.0, lightToneB + 0.01), 1.0))

    readonly property color bgCard: isDarkTheme ?
        Qt.rgba(Math.min(1.0, darkToneR + 0.07), Math.min(1.0, darkToneG + 0.07), Math.min(1.0, darkToneB + 0.10), enableGlass ? Math.min(0.72, glassOpacity * 0.68) : 1.0) :
        (enableGlass ? Qt.rgba(Math.min(1.0, lightToneR - 0.01), Math.min(1.0, lightToneG - 0.01), Math.min(1.0, lightToneB - 0.01), Math.min(0.78, glassOpacity * 0.72)) : Qt.rgba(Math.max(0.0, lightToneR - 0.02), Math.max(0.0, lightToneG - 0.02), Math.max(0.0, lightToneB - 0.02), 1.0))

    // Solid input surfaces keep text legible while surrounding panels retain glass.
    readonly property color bgInput: isDarkTheme ?
        Qt.rgba(Math.min(1.0,darkToneR+0.03),Math.min(1.0,darkToneG+0.03),Math.min(1.0,darkToneB+0.04),1.0) :
        Qt.rgba(Math.min(1.0,lightToneR+0.02),Math.min(1.0,lightToneG+0.02),Math.min(1.0,lightToneB+0.02),1.0)

    readonly property color bgGlassPanel: enableGlass ? 
        (isDarkTheme ? 
            Qt.rgba(Math.min(1.0, darkToneR + 0.03), Math.min(1.0, darkToneG + 0.03), Math.min(1.0, darkToneB + 0.05), Math.min(0.78, glassOpacity * 0.74)) : 
            Qt.rgba(Math.min(1.0, lightToneR), Math.min(1.0, lightToneG), Math.min(1.0, lightToneB), Math.min(0.80, glassOpacity * 0.76))) : 
        bgSurface

    readonly property color borderSubtle: isDarkTheme ?
        (enableGlass ? Qt.rgba(1.0, 1.0, 1.0, 0.14 + (bgDarkness * 0.14)) : Qt.rgba(0.20 + bgDarkness, 0.20 + bgDarkness, 0.23 + bgDarkness, 1.0)) :
        (enableGlass ? Qt.rgba(0.0, 0.0, 0.0, 0.09 + (lightBrightness * 0.12)) : Qt.rgba(0.86 - lightBrightness, 0.86 - lightBrightness, 0.88 - lightBrightness, 1.0))

    readonly property color borderSpecular: {
        if (!enableSpecular || !enableGlass) return "transparent";
        if (!isDarkTheme) return Qt.rgba(1.0, 1.0, 1.0, Math.max(0.30, 0.92 - (lightBrightness * 0.85)));
        return Qt.rgba(1.0, 1.0, 1.0, 0.22);
    }
    readonly property color borderHighlight: isDarkTheme ? Qt.rgba(1.0, 1.0, 1.0, 0.28) : Qt.rgba(0.0, 0.0, 0.0, 0.24)

    readonly property color borderFocus: lobeAccent
    readonly property color accentDanger: "#ef4444"
    readonly property color textPrimary: isDarkTheme ? UI.design.colors.dark.text : UI.design.colors.light.text
    readonly property color textSecondary: isDarkTheme ? UI.design.colors.dark.secondary : UI.design.colors.light.secondary
    readonly property color textMuted: isDarkTheme ? (bgDarkness > 0.20 ? "#d0d0da" : UI.design.colors.dark.muted) : UI.design.colors.light.muted

    // Typography
    readonly property string fontMain: Qt.platform.os === "windows" ? "Segoe UI" : Qt.application.font.family
    readonly property string fontMono: Qt.platform.os === "windows" ? "Consolas" : "monospace"
    font.family: fontMain
    font.pixelSize: 13

    // Layout & Viewport Settings
    property bool autoColumns: true
    property int manualColumns: 5
    property int columnCount: autoColumns ? Math.max(1, Math.round(viewportArea.width / 240)) : manualColumns
    property int itemSpacing: 0 // 0px seamless masonry wall
    property real columnWidth: (viewportArea.width - ((columnCount - 1) * itemSpacing)) / columnCount

    // Modal & Dialog state
    property bool settingsModalOpen: false
    onSettingsModalOpenChanged: if (!settingsModalOpen) root.focusMain()
    property string activeModalUrl: ""
    property int activeModalIndex: -1
    property real modalZoomScale: 1.0
    property bool showModalPromptSheet: false
    property int activeSettingsTab: 0 // 0: Appearance, 1: Grid, 2: File Ops, 3: Language, 4: About
    property var collapsedGroups: ({})
    function isGroupCollapsed(key) { return !!collapsedGroups[key] }
    function toggleGroupCollapsed(key) {
        var c = Object.assign({}, collapsedGroups)
        c[key] = !c[key]
        collapsedGroups = c
    }

    onActiveModalUrlChanged: {
        root.modalZoomScale = 1.0
        root.showModalPromptSheet = false
    }

    onActiveModalIndexChanged: {
        root.modalZoomScale = 1.0
    }

    // User Preferences (File Operations)
    property bool useRecycleBin: true
    property bool confirmDelete: false

    // Active Category Tab for Suggested Tags: 4=Characters, 1=Artists, 0=General, 5=Styles
    property int activeTagCategory: 4

    // Left Sidebar Navigation Mode: 0 = Tags, 1 = Explorer (Subfolders)
    property int leftSidebarMode: 0

    // Adaptability & Sidebar Toggles
    property bool showLeftSidebar: true
    property bool showInspector: true
    property int leftSidebarWidth: 270
    readonly property int inspectorWidth: Math.min(440, Math.max(340, Math.round(root.width * 0.25)))

    // Inspector Preview Customization
    property int previewDisplayMode: 0 // 0: Right Inspector, 1: Floating Hover Popup (Hold), 2: Disabled
    property int inspectorPreviewHeight: 290
    property int previewSizePreset: 1 // 0: S (200px), 1: M (290px), 2: L (390px), 3: Auto
    property int previewFitMode: 0     // 0: AspectFit, 1: AspectCrop
    property bool enableHoverPreview: true
    property int maxSidebarTags: 80    // Maximum tags shown in sidebar (20 to 200)

    // Floating Hold-to-Preview Active State
    property var activeHoverData: null
    property var activeHoverCard: null
    property real hoverPopupX: 0
    property real hoverPopupY: 0
    property real hoverPopupW: 320
    property real hoverPopupH: 320

    readonly property int previewTargetHeight: {
        if (root.previewSizePreset === 0) return 200
        if (root.previewSizePreset === 1) return 290
        if (root.previewSizePreset === 2) return 390
        if (root.previewSizePreset === 3) return 360
        return root.inspectorPreviewHeight
    }

    Timer {
        id: dismissHoverTimer
        interval: 140
        repeat: false
        onTriggered: {
            if (typeof hoverCardMouse !== "undefined" && !hoverCardMouse.containsMouse) {
                root.activeHoverData = null
                root.activeHoverCard = null
            }
        }
    }

    function focusMain() {
        if (typeof mainContent !== "undefined" && mainContent && typeof mainContent.forceActiveFocus === "function") {
            mainContent.forceActiveFocus()
        }
    }

    // Multi-Language Localization System (lobe-i18n powered)
    readonly property int langEpoch: gallery.languageEpoch
    function tr(key, fallback) {
        var _ = root.langEpoch
        return gallery.t(key, fallback !== undefined ? fallback : "")
    }

    function accentDefinition(name) {
        const canonical=name.indexOf("GestArt ")===0 ? "Lobe "+name.substring(8) : name;
        for(let i=0;i<lobeColors.length;i++)if(lobeColors[i].name===canonical)return lobeColors[i];
        return null;
    }
    function accentColorFor(option) { return (isDarkTheme?option.dark:option.light) || option.hex; }
    function chooseAccent(name) {
        const option=accentDefinition(name);if(!option)return;
        lobeAccentName=option.name;lobeAccent=accentColorFor(option);
    }
    function applySelectedAccent() {
        const option=accentDefinition(lobeAccentName)||accentDefinition("Lobe Blue");
        if(option){lobeAccentName=option.name;lobeAccent=accentColorFor(option);}
    }

    function getAccentContrastColor(c) { return UI.textOn(c ? c : root.lobeAccent) }
    function sharedIconSource(name,color) { return UI.iconSource(name,color) }

    function dismissHoverPreviewDelayed() {
        dismissHoverTimer.restart()
    }

    function showHoverPreviewForCard(cardItem, data) {
        if (!cardItem || !data || root.previewDisplayMode !== 1) return
        dismissHoverTimer.stop()
        
        var ar = (data.aspectRatio && data.aspectRatio > 0.05) ? data.aspectRatio : 1.0
        var maxW = Math.max(260, viewportArea.width - 48)
        var maxH = Math.max(260, viewportArea.height - 48)

        // Scale factors: popup preview MUST be noticeably larger than the masonry card!
        var scaleFactor = 1.65
        if (root.previewSizePreset === 0) scaleFactor = 1.35
        else if (root.previewSizePreset === 1) scaleFactor = 1.65
        else if (root.previewSizePreset === 2) scaleFactor = 2.05
        else if (root.previewSizePreset === 3) scaleFactor = 2.25

        // Slider offset factor if user changed slider
        var sliderBonus = (root.inspectorPreviewHeight - 290) * 0.8

        var targetW = 0
        var targetH = 0

        if (ar < 1.0) {
            // Vertical image: scale based on card height so it is noticeably taller and wider than the card in masonry!
            var desiredH = (cardItem.height * scaleFactor) + sliderBonus
            targetH = Math.min(maxH, Math.max(480, desiredH))
            targetW = Math.round(targetH * ar)
            if (targetW > maxW) {
                targetW = maxW
                targetH = Math.round(targetW / ar)
            }
        } else {
            // Horizontal or square image: scale based on card width so it's noticeably wider than the card!
            var desiredW = (cardItem.width * scaleFactor) + (sliderBonus * ar)
            targetW = Math.min(maxW, Math.max(480, desiredW))
            targetH = Math.round(targetW / ar)
            if (targetH > maxH) {
                targetH = maxH
                targetW = Math.round(targetH * ar)
            }
        }

        var pt = cardItem.mapToItem(viewportArea, 0, 0)
        var centerX = pt.x + (cardItem.width / 2)
        var centerY = pt.y + (cardItem.height / 2)

        var posX = centerX - (targetW / 2)
        // Position directly above card if there's enough space, otherwise center over card
        var posY = pt.y - targetH - 10
        if (posY < 12 || (posY + targetH) > viewportArea.height) {
            posY = centerY - (targetH / 2)
        }

        // Clamp securely inside viewportArea
        posX = Math.max(12, Math.min(viewportArea.width - targetW - 12, posX))
        posY = Math.max(12, Math.min(viewportArea.height - targetH - 12, posY))

        root.hoverPopupX = posX
        root.hoverPopupY = posY
        root.hoverPopupW = targetW
        root.hoverPopupH = targetH
        root.activeHoverCard = cardItem
        root.activeHoverData = data
    }

    // Restore Saved UI Preferences on Startup
    Component.onCompleted: {
        root.isDarkTheme = gallery.loadSetting("ui/isDarkTheme", true)
        root.lobeAccent = gallery.loadSetting("ui/lobeAccent", "#1677ff")
        root.lobeAccentName = gallery.loadSetting("ui/lobeAccentName", "Lobe Blue")
        root.appearanceReady=true;root.applySelectedAccent()
        root.glassOpacity=Math.max(0.3,Math.min(1,gallery.loadSetting("ui/glassOpacity",0.72)))
        root.glassBlurAmount=Math.max(0.1,Math.min(1,gallery.loadSetting("ui/glassBlurAmount",0.82)))
        root.glassTintStrength=Math.max(0,Math.min(1,gallery.loadSetting("ui/glassTintStrength",0.55)))
        root.glassChroma=Math.max(0,Math.min(.3,gallery.loadSetting("ui/glassChroma",0.18)))
        root.bgTonePreset = gallery.loadSetting("ui/bgTonePreset", 0)
        if (root.bgTonePreset >= 3) root.bgTonePreset = 0
        root.bgDarkness = gallery.loadSetting("ui/bgDarkness", 0.08)
        root.lightTonePreset = gallery.loadSetting("ui/lightTonePreset", 0)
        root.lightBrightness = gallery.loadSetting("ui/lightBrightness", 0.04)
        const savedTone=gallery.loadSetting("ui/backgroundToneName","");
        const legacyTone=root.isDarkTheme?(root.bgTonePreset===1?"slate":root.bgTonePreset===2?"obsidian":"zinc"):(root.lightTonePreset===3?"pure":root.lightTonePreset===2?"charcoal":root.lightTonePreset===1?"slate":"zinc");
        root.backgroundToneName=root.toneDefinition(savedTone)?savedTone:legacyTone;
        gallery.saveSetting("ui/backgroundToneName",root.backgroundToneName);
        root.updateApplicationIcon();
        root.enableGlass = gallery.loadSetting("ui/enableGlass", true)
        root.enableSpecular = gallery.loadSetting("ui/enableSpecular", true)
        root.enableAurora = gallery.loadSetting("ui/enableAurora", true)
        root.auroraIntensity = Math.max(0, Math.min(1, gallery.loadSetting("ui/auroraIntensity", 0.70)))
        root.auroraAnimated = gallery.loadSetting("ui/auroraAnimated", true)
        root.autoColumns = gallery.loadSetting("ui/autoColumns", true)
        root.manualColumns = gallery.loadSetting("ui/manualColumns", 5)
        root.itemSpacing = gallery.loadSetting("ui/itemSpacing", 0)
        root.useRecycleBin = gallery.loadSetting("ui/useRecycleBin", true)
        root.confirmDelete = gallery.loadSetting("ui/confirmDelete", false)
        root.leftSidebarMode = gallery.loadSetting("ui/leftSidebarMode", 0)
        root.showLeftSidebar = gallery.loadSetting("ui/showLeftSidebar", true)
        root.showInspector = gallery.loadSetting("ui/showInspector", true)
        root.previewDisplayMode = gallery.loadSetting("ui/previewDisplayMode", 0)
        root.inspectorPreviewHeight = gallery.loadSetting("ui/inspectorPreviewHeight", 290)
        root.previewSizePreset = gallery.loadSetting("ui/previewSizePreset", 1)
        root.previewFitMode = gallery.loadSetting("ui/previewFitMode", 0)
        root.enableHoverPreview = gallery.loadSetting("ui/enableHoverPreview", true)
        root.maxSidebarTags = gallery.loadSetting("ui/maxSidebarTags", 80)

        // Automatic folder restoration: ensure saved folder is actively loaded
        if (gallery.currentFolder === "") {
            var last = gallery.lastFolder()
            if (last && last.length > 0) {
                gallery.openFolder(last)
            }
        } else {
            masonryFlickable.updateViewport()
            masonryFlickable.syncCards()
        }
    }

    onIsDarkThemeChanged: {gallery.saveSetting("ui/isDarkTheme", isDarkTheme);if(appearanceReady)applySelectedAccent()}
    onLobeAccentChanged: gallery.saveSetting("ui/lobeAccent", lobeAccent)
    function updateApplicationIcon() {
        const option=accentDefinition(lobeAccentName);
        if(option&&typeof appIdentity!=="undefined")appIdentity.setAccent(option.key);
    }
    onLobeAccentNameChanged: {gallery.saveSetting("ui/lobeAccentName",lobeAccentName);updateApplicationIcon()}
    onBgTonePresetChanged: gallery.saveSetting("ui/bgTonePreset", bgTonePreset)
    onBgDarknessChanged: gallery.saveSetting("ui/bgDarkness", bgDarkness)
    onLightTonePresetChanged: gallery.saveSetting("ui/lightTonePreset", lightTonePreset)
    onLightBrightnessChanged: gallery.saveSetting("ui/lightBrightness", lightBrightness)
    onGlassOpacityChanged: gallery.saveSetting("ui/glassOpacity",glassOpacity)
    onGlassBlurAmountChanged: gallery.saveSetting("ui/glassBlurAmount",glassBlurAmount)
    onGlassTintStrengthChanged: gallery.saveSetting("ui/glassTintStrength",glassTintStrength)
    onGlassChromaChanged: gallery.saveSetting("ui/glassChroma",glassChroma)
    onEnableGlassChanged: gallery.saveSetting("ui/enableGlass", enableGlass)
    onEnableSpecularChanged: gallery.saveSetting("ui/enableSpecular", enableSpecular)
    onAutoColumnsChanged: gallery.saveSetting("ui/autoColumns", autoColumns)
    onManualColumnsChanged: gallery.saveSetting("ui/manualColumns", manualColumns)
    onItemSpacingChanged: gallery.saveSetting("ui/itemSpacing", itemSpacing)
    onUseRecycleBinChanged: gallery.saveSetting("ui/useRecycleBin", useRecycleBin)
    onConfirmDeleteChanged: gallery.saveSetting("ui/confirmDelete", confirmDelete)
    onLeftSidebarModeChanged: gallery.saveSetting("ui/leftSidebarMode", leftSidebarMode)
    onShowLeftSidebarChanged: gallery.saveSetting("ui/showLeftSidebar", showLeftSidebar)
    onShowInspectorChanged: gallery.saveSetting("ui/showInspector", showInspector)
    onPreviewDisplayModeChanged: gallery.saveSetting("ui/previewDisplayMode", previewDisplayMode)
    onInspectorPreviewHeightChanged: gallery.saveSetting("ui/inspectorPreviewHeight", inspectorPreviewHeight)
    onPreviewSizePresetChanged: gallery.saveSetting("ui/previewSizePreset", previewSizePreset)
    onPreviewFitModeChanged: gallery.saveSetting("ui/previewFitMode", previewFitMode)
    onEnableHoverPreviewChanged: gallery.saveSetting("ui/enableHoverPreview", enableHoverPreview)
    onMaxSidebarTagsChanged: gallery.saveSetting("ui/maxSidebarTags", maxSidebarTags)

    readonly property bool hasActiveFilters: searchInput.text.trim() !== "" || negInput.text.trim() !== "" ||
                                             gallery.selectedModel !== "All" || gallery.selectedSubfolder !== "All"
    readonly property bool isInputFocused: activeFocusItem !== null &&
                                           activeFocusItem.text !== undefined && activeFocusItem.selectByMouse !== undefined
    readonly property bool dialogOpen: deleteDialog.visible || batchDeleteDialog.visible || operationErrorDialog.visible ||
                                      folderDialog.visible || moveFolderDialog.visible || batchMoveFolderDialog.visible || csvFileDialog.visible
    readonly property bool galleryShortcutsEnabled: !settingsModalOpen && !dialogOpen && !isInputFocused &&
                                                    (activeFocusItem === mainContent || activeFocusItem === null)
    property string pendingRevealPath: ""
    readonly property bool libraryBusy: gallery.isLoading || gallery.isFiltering
    readonly property string libraryStatusText: {
        if (gallery.isFiltering && !gallery.isLoading) return root.tr("ux.filtering", "Updating results…")
        if (gallery.isLoading) {
            var percent = Math.round(gallery.scanProgress * 100)
            return (gallery.scanStatus || root.tr("status.scanning", "Scanning...")) + (percent > 0 ? " (" + percent + "%)" : "")
        }
        if (gallery.totalCount > 0)
            return root.tr("status.library_indexed", "Library indexed:") + " " + gallery.totalCount + " " + root.tr("gallery.items", "items")
        return gallery.scanStatus || (gallery.totalCount > 0 ? root.tr("status.ready", "Ready") : root.tr("status.idle", "Idle"))
    }

    function resetFilters() {
        searchInput.text = ""
        negInput.text = ""
        searchDebounceTimer.stop()
        negDebounceTimer.stop()
        tagPopup.close()
        gallery.setSearchQuery("")
        gallery.setNegativeFilter("")
        gallery.selectedModel = "All"
        gallery.selectedSubfolder = "All"
        pendingRevealPath = ""
        masonryFlickable.contentY = 0
        root.focusMain()
    }
    function openSelectedImage() {
        if (gallery.selectedImage.filteredIndex === undefined) return
        root.activeModalIndex = gallery.selectedImage.filteredIndex
        root.activeModalUrl = gallery.selectedImage.url
    }
    function navigateGallery(delta) {
        if (gallery.filteredCount === 0 || gallery.isFiltering) return
        var current = gallery.selectedImage.filteredIndex
        var target = current === undefined ? 0 : Math.max(0, Math.min(gallery.filteredCount - 1, current + delta))
        gallery.selectImage(target)
        if (root.activeModalUrl !== "") root.openSelectedImage()
        else {
            root.pendingRevealPath = gallery.selectedImage.filePath
            root.revealPendingCard()
        }
    }
    function revealPendingCard() {
        if (pendingRevealPath === "" || gallery.isFiltering) return
        var index = gallery.indexForPath(pendingRevealPath)
        if (index < 0) { pendingRevealPath = ""; return }
        var rect = gallery.cardGeometry(index)
        if (rect.y === undefined) return
        if (rect.groupId !== undefined && root.isGroupCollapsed(rect.groupId)) {
            root.toggleGroupCollapsed(rect.groupId)
            return
        }
        pendingRevealPath = ""
        var top = masonryFlickable.contentY
        var bottom = top + masonryFlickable.height
        var destination = top
        if (rect.y < top + 12 || rect.height > masonryFlickable.height - 24) destination = rect.y - 12
        else if (rect.y + rect.height > bottom - 12) destination = rect.y + rect.height - masonryFlickable.height + 12
        masonryFlickable.contentY = Math.max(0, Math.min(Math.max(0, masonryFlickable.contentHeight - masonryFlickable.height), destination))
    }

    // Keyboard Shortcuts (Application-wide with proper context)
    Shortcut {
        sequence: "Esc"
        context: Qt.ApplicationShortcut
        enabled: !root.dialogOpen
        onActivated: {
            if (root.settingsModalOpen) {
                root.settingsModalOpen = false
            } else if (root.isInputFocused || tagPopup.opened) {
                tagPopup.close()
            } else if (activeModalUrl !== "") {
                activeModalUrl = "" // Only close modal, preserve multi-selection!
            } else if (gallery.selectedCount > 0) {
                gallery.clearMultiSelection()
            } else if (gallery.selectedImage.filePath !== undefined) {
                gallery.clearSelection()
            }
            root.focusMain()
        }
    }

    Shortcut {
        sequence: "Ctrl+F"
        enabled: !root.settingsModalOpen && !root.dialogOpen && root.activeModalUrl === ""
        onActivated: { searchInput.forceActiveFocus(); searchInput.selectAll() }
    }
    Shortcut {
        sequence: "Ctrl+O"
        enabled: !root.settingsModalOpen && !root.dialogOpen
        onActivated: folderDialog.open()
    }

    Shortcut {
        sequence: "Space"
        context: Qt.ApplicationShortcut
        enabled: root.galleryShortcutsEnabled
        onActivated: {
            if (activeModalUrl !== "") {
                activeModalUrl = ""
            } else if (gallery.selectedImage.filePath !== undefined) {
                root.activeModalIndex = gallery.selectedImage.filteredIndex
                root.activeModalUrl = gallery.selectedImage.url
            } else if (gallery.filteredCount > 0) {
                gallery.selectImage(0)
                root.activeModalIndex = 0
                root.activeModalUrl = gallery.selectedImage.url
            }
        }
    }

    Shortcut {
        sequence: "Return"
        context: Qt.ApplicationShortcut
        enabled: root.galleryShortcutsEnabled
        onActivated: {
            if (activeModalUrl !== "") {
                activeModalUrl = ""
            } else if (gallery.selectedImage.filePath !== undefined) {
                root.activeModalIndex = gallery.selectedImage.filteredIndex
                root.activeModalUrl = gallery.selectedImage.url
            }
        }
    }

    Shortcut {
        sequence: "F"
        context: Qt.ApplicationShortcut
        enabled: root.galleryShortcutsEnabled
        onActivated: {
            if (activeModalUrl !== "") {
                activeModalUrl = ""
            } else if (gallery.selectedImage.filePath !== undefined) {
                root.activeModalIndex = gallery.selectedImage.filteredIndex
                root.activeModalUrl = gallery.selectedImage.url
            }
        }
    }

    Shortcut {
        sequence: "B"
        context: Qt.ApplicationShortcut
        enabled: root.galleryShortcutsEnabled
        onActivated: root.showLeftSidebar = !root.showLeftSidebar
    }

    Shortcut {
        sequence: "I"
        context: Qt.ApplicationShortcut
        enabled: root.galleryShortcutsEnabled
        onActivated: root.showInspector = !root.showInspector
    }

    Shortcut {
        sequence: "Ctrl+A"
        context: Qt.ApplicationShortcut
        enabled: root.galleryShortcutsEnabled
        onActivated: gallery.selectAll()
    }

    Shortcut {
        sequence: "Ctrl+,"
        context: Qt.ApplicationShortcut
        enabled: !root.dialogOpen
        onActivated: root.settingsModalOpen = !root.settingsModalOpen
    }

    Shortcut {
        sequence: "Delete"
        context: Qt.ApplicationShortcut
        enabled: root.galleryShortcutsEnabled
        onActivated: {
            if (gallery.selectedCount > 0) {
                requestBatchDelete()
            } else if (gallery.selectedImage.filteredIndex !== undefined) {
                requestDelete(gallery.selectedImage.filteredIndex)
            }
        }
    }

    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut
        enabled: root.galleryShortcutsEnabled
        onActivated: root.navigateGallery(-1)
    }

    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut
        enabled: root.galleryShortcutsEnabled
        onActivated: root.navigateGallery(1)
    }

    Shortcut {
        sequence: "Up"
        context: Qt.ApplicationShortcut
        enabled: root.galleryShortcutsEnabled && root.activeModalUrl === ""
        onActivated: root.navigateGallery(-root.columnCount)
    }

    Shortcut {
        sequence: "Down"
        context: Qt.ApplicationShortcut
        enabled: root.galleryShortcutsEnabled && root.activeModalUrl === ""
        onActivated: root.navigateGallery(root.columnCount)
    }

    Shortcut {
        sequence: "+"
        context: Qt.ApplicationShortcut
        enabled: !root.settingsModalOpen && !root.dialogOpen && root.activeModalUrl !== ""
        onActivated: root.modalZoomScale = Math.min(6.0, Math.round(root.modalZoomScale * 1.25 * 100) / 100)
    }

    Shortcut {
        sequence: "="
        context: Qt.ApplicationShortcut
        enabled: !root.settingsModalOpen && !root.dialogOpen && root.activeModalUrl !== ""
        onActivated: root.modalZoomScale = Math.min(6.0, Math.round(root.modalZoomScale * 1.25 * 100) / 100)
    }

    Shortcut {
        sequence: "-"
        context: Qt.ApplicationShortcut
        enabled: !root.settingsModalOpen && !root.dialogOpen && root.activeModalUrl !== ""
        onActivated: root.modalZoomScale = Math.max(1.0, Math.round(root.modalZoomScale / 1.25 * 100) / 100)
    }

    Shortcut {
        sequence: "0"
        context: Qt.ApplicationShortcut
        enabled: !root.settingsModalOpen && !root.dialogOpen && root.activeModalUrl !== ""
        onActivated: root.modalZoomScale = 1.0
    }

    Shortcut {
        sequence: "P"
        context: Qt.ApplicationShortcut
        enabled: !root.settingsModalOpen && !root.dialogOpen && root.activeModalUrl !== "" && !root.isInputFocused
        onActivated: root.showModalPromptSheet = !root.showModalPromptSheet
    }

    // Hidden Clipboard Helper for clean copying
    TextEdit {
        id: clipboardHelper
        visible: false
        function copyText(str) {
            text = str
            selectAll()
            copy()
            deselect()
        }
    }

    // ================= CUSTOM STYLED REUSABLE CONTROLS =================
    component InspectorWelcome: ColumnLayout {
        id: welcomePanel
        objectName: "inspectorWelcome"
        Layout.fillWidth: true
        spacing: 24

        Text {
            text: root.tr("inspector.title", "Inspector")
            color: root.textSecondary
            font.family: root.fontMain; font.pixelSize: 16; font.weight: Font.DemiBold
            Layout.topMargin: 16
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: welcomeContent.implicitHeight + 48
            radius: 12
            color: root.bgCard
            border.color: root.borderSubtle
            SurfaceSheen {
                anchors.fill: parent
                cornerRadius: parent.radius || 0
                highlightColor: root.borderSpecular
            }
            ColumnLayout {
                id: welcomeContent
                anchors.fill: parent; anchors.margins: 24
                spacing: 12
                Item {
                    Layout.preferredWidth: 72; Layout.preferredHeight: 64
                    Rectangle {
                        width: 48; height: 48; x: 16; y: 4; rotation: 10; radius: 10
                        color: Qt.rgba(root.auroraColor3.r, root.auroraColor3.g, root.auroraColor3.b, 0.12)
                        border.color: root.borderSubtle
                    }
                    Rectangle {
                        width: 48; height: 48; x: 4; y: 12; radius: 10
                        color: Qt.rgba(root.lobeAccent.r, root.lobeAccent.g, root.lobeAccent.b, 0.12)
                        border.color: Qt.rgba(root.lobeAccent.r, root.lobeAccent.g, root.lobeAccent.b, 0.35)
                        LobeIcon { anchors.centerIn: parent; name: "image"; size: 24; color: root.lobeAccent }
                    }
                }
                Text {
                    objectName: "inspectorWelcomeTitle"
                    Layout.fillWidth: true
                    text: root.tr(gallery.currentFolder ? "ux.inspect_select" : "ux.inspect_start",
                                  gallery.currentFolder ? "Select an image" : "Get to know your images")
                    color: root.textPrimary
                    font.family: root.fontMain; font.pixelSize: 20; font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }
                Text {
                    Layout.fillWidth: true
                    text: root.tr(gallery.currentFolder ? "ux.inspect_select_hint" : "ux.inspect_start_hint",
                                  gallery.currentFolder ? "Click a thumbnail. Its preview, prompt and generation settings will appear here." : "Open a folder to explore your images and the details behind each generation.")
                    color: root.textSecondary
                    font.family: root.fontMain; font.pixelSize: 12
                    lineHeight: 1.4; wrapMode: Text.WordWrap
                }
                LobeButton {
                    objectName: "inspectorWelcomeAction"
                    Layout.fillWidth: true; Layout.topMargin: 8
                    type: "primary"
                    iconName: gallery.filteredCount > 0 ? "image" : (root.hasActiveFilters ? "filter" : "folder-open")
                    text: gallery.filteredCount > 0 ? root.tr("ux.inspect_first", "Inspect first image") :
                          (root.hasActiveFilters ? root.tr("ux.reset_filters", "Reset filters") : root.tr("ux.open_folder", "Open folder"))
                    enabled: !gallery.isLoading && !gallery.isFiltering
                    onClicked: {
                        if (gallery.filteredCount > 0) {
                            gallery.selectSingle(0)
                            root.navigateGallery(0)
                            root.focusMain()
                        } else if (root.hasActiveFilters) root.resetFilters()
                        else folderDialog.open()
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; spacing: 16
            Text {
                text: root.tr("ux.inspect_details", "Image details, at a glance")
                color: root.textPrimary; font.family: root.fontMain; font.pixelSize: 14; font.weight: Font.DemiBold
            }
            Repeater {
                model: [
                    { icon: "image", title: root.tr("ux.inspect_preview", "Preview & file"), hint: root.tr("ux.inspect_preview_hint", "Dimensions, size and location") },
                    { icon: "sparkles", title: root.tr("ux.inspect_prompt", "Prompt & generation"), hint: root.tr("ux.inspect_prompt_hint", "Prompt, model and saved parameters") },
                    { icon: "tag", title: root.tr("ux.inspect_tags", "Tags"), hint: root.tr("ux.inspect_tags_hint", "Explore and copy image tags") }
                ]
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 12
                    LobeIcon { name: modelData.icon; size: 20; color: root.textMuted }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        Text { text: modelData.title; color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 12 }
                        Text { Layout.fillWidth: true; text: modelData.hint; color: root.textMuted; font.family: root.fontMain; font.pixelSize: 12; wrapMode: Text.WordWrap }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; spacing: 8
            visible: gallery.currentFolder !== ""
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                LobeIcon { name: "folder"; size: 14; color: root.textMuted }
                Text {
                    Layout.fillWidth: true
                    text: gallery.selectedSubfolder === "All" ? root.tr("sidebar.all_folders", "All folders") : gallery.selectedSubfolder
                    color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 12; elide: Text.ElideMiddle
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: [
                        { value: gallery.filteredCount, label: root.tr("ux.inspect_visible", "In this view") },
                        { value: gallery.totalCount, label: root.tr("ux.inspect_total", "In the library") }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 80
                        radius: 8; color: root.bgCard; border.color: root.borderSubtle
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 4
                            Text { text: modelData.value; color: root.textPrimary; font.family: root.fontMain; font.pixelSize: 20; font.weight: Font.DemiBold }
                            Text { text: modelData.label; color: root.textMuted; font.family: root.fontMain; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; spacing: 12
            Repeater {
                model: [
                    { key: "Space", text: root.tr("ux.inspect_fullscreen", "Open selected image") },
                    { key: "Ctrl / Shift", text: root.tr("ux.inspect_multi", "Select several images") }
                ]
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 12
                    Rectangle {
                        implicitWidth: keyText.implicitWidth + 16; implicitHeight: 24
                        radius: 4; color: root.bgCard; border.color: root.borderSubtle
                        Text { id: keyText; anchors.centerIn: parent; text: modelData.key; color: root.textSecondary; font.family: root.fontMono; font.pixelSize: 10 }
                    }
                    Text { Layout.fillWidth: true; text: modelData.text; color: root.textMuted; font.family: root.fontMain; font.pixelSize: 12; wrapMode: Text.WordWrap }
                }
            }
        }
        Item { implicitHeight: 8 }
    }

    component LobeSlider: Slider {
        id: sliderControl
        implicitHeight: 24

        background: Rectangle {
            x: sliderControl.leftPadding
            y: sliderControl.topPadding + sliderControl.availableHeight / 2 - height / 2
            implicitWidth: 200
            implicitHeight: 4
            width: sliderControl.availableWidth
            height: implicitHeight
            radius: 2
            color: root.isDarkTheme ? "#2c2c36" : "#e2e2e8"

            Rectangle {
                width: sliderControl.visualPosition * parent.width
                height: parent.height
                color: root.lobeAccent
                radius: 2
            }
        }

        handle: Rectangle {
            x: sliderControl.leftPadding + sliderControl.visualPosition * (sliderControl.availableWidth - width)
            y: sliderControl.topPadding + sliderControl.availableHeight / 2 - height / 2
            implicitWidth: 16
            implicitHeight: 16
            radius: 8
            color: sliderControl.pressed ? root.lobeAccent : "#ffffff"
            border.color: root.lobeAccent
            border.width: 2

            Rectangle {
                anchors.centerIn: parent
                width: 4; height: 4; radius: 2
                color: root.lobeAccent
                visible: !sliderControl.pressed
            }
        }
    }

    // Sleek iOS/Lobe Switch Toggle (Zero checkmarks / ticks)
    component LobeSwitch: RowLayout {
        id: switchControl
        property string text: ""
        property bool checked: false
        spacing: 10
        activeFocusOnTab: true
        implicitHeight: 32
        Accessible.role: Accessible.CheckBox
        Accessible.name: text
        Accessible.checked: checked
        Accessible.onToggleAction: checked = !checked
        Keys.onSpacePressed: checked = !checked
        Keys.onReturnPressed: checked = !checked

        Rectangle {
            id: track
            width: 36
            height: 20
            radius: 10
            color: switchControl.checked ? root.lobeAccent : (root.isDarkTheme ? "#2c2c36" : "#d2d2dc")
            border.color: switchControl.activeFocus ? root.borderFocus : (switchControl.checked ? root.lobeAccent : root.borderSubtle)
            border.width: switchControl.activeFocus ? 2 : 1
            clip: true

            SurfaceSheen {
                anchors.fill: parent
                cornerRadius: parent.radius || 0
                highlightColor: root.borderSpecular
            }

            Rectangle {
                id: thumb
                width: 16
                height: 16
                radius: 8
                y: 2
                x: switchControl.checked ? 18 : 2
                color: "#ffffff"
                Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -6; anchors.bottomMargin: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: switchControl.checked = !switchControl.checked
            }
        }

        Text {
            text: switchControl.text
            color: root.textPrimary
            font.family: root.fontMain
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: switchControl.checked = !switchControl.checked
            }
        }
    }

    // Alias for seamless backward compatibility
    component LobeCheckBox: LobeSwitch {}

    // ================= LOBE UI LUCIDE ICON (Vector SVG Renderer) =================
    component LobeIcon: Item {
        id: lobeIcon
        property string name: ""
        property color color: root.textPrimary
        property int size: 16

        implicitWidth: size
        implicitHeight: size

        // Both viewers use the same 24px Tabler SVG catalog and 2px stroke.
        readonly property string svgData: UI.iconSource(name,color)

        Image {
            anchors.fill: parent
            source: lobeIcon.svgData
            sourceSize.width: Math.max(8, Math.round(lobeIcon.size * root.dpr))
            sourceSize.height: Math.max(8, Math.round(lobeIcon.size * root.dpr))
            visible: lobeIcon.svgData !== ""
            asynchronous: false
            smooth: true
            cache: true
        }


    }

    // Paint the soft curtain only when its size or palette changes; animate the cached texture.
    component AuroraRibbon: Item {
        id: ribbon
        property color startColor
        property color endColor
        property real strength: 0.24
        onStartColorChanged: if (ribbonCanvas) ribbonCanvas.requestPaint()
        onEndColorChanged: if (ribbonCanvas) ribbonCanvas.requestPaint()
        onStrengthChanged: if (ribbonCanvas) ribbonCanvas.requestPaint()
        Canvas {
            id: ribbonCanvas
            anchors.fill: parent
            renderTarget: Canvas.Image
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                if (!ctx || width <= 0 || height <= 0) return
                ctx.reset()
                var w = width, h = height
                var a = ribbon.startColor, b = ribbon.endColor
                // Continuous soft light across each column avoids geometry seams on either renderer.
                for (var x = 0; x < w; x += 2) {
                    var u = x / w
                    var center = h * (0.33 + 0.075 * Math.sin(u * Math.PI * 2 + 0.4) + 0.025 * Math.sin(u * Math.PI * 4))
                    var spread = h * (0.18 + 0.035 * Math.cos(u * Math.PI * 2))
                    var gradient = ctx.createLinearGradient(0, center - spread, 0, center + spread)
                    gradient.addColorStop(0.00, "transparent")
                    gradient.addColorStop(0.22, Qt.rgba(a.r, a.g, a.b, ribbon.strength * 0.12))
                    gradient.addColorStop(0.42, Qt.rgba(a.r, a.g, a.b, ribbon.strength * 0.65))
                    gradient.addColorStop(0.52, Qt.rgba(a.r, a.g, a.b, ribbon.strength))
                    gradient.addColorStop(0.66, Qt.rgba(b.r, b.g, b.b, ribbon.strength * 0.35))
                    gradient.addColorStop(0.84, Qt.rgba(b.r, b.g, b.b, ribbon.strength * 0.08))
                    gradient.addColorStop(1.00, "transparent")
                    ctx.fillStyle = gradient
                    ctx.fillRect(x, 0, Math.min(2, w - x), h)
                }
            }
        }
    }

    // ================= LOBE UI BUTTON (@lobehub/ui Specification) =================
    component LobeButton: Button {
        id: lobeBtn

        // Variant type: "default" | "primary" | "ghost" | "text" | "danger"
        property string type: "default"
        // Size: "small" | "middle" | "large"
        property string size: "middle"
        // Glassmorphism effect toggle
        property bool glass: root.enableGlass
        // Optional leading icon symbol
        property string iconName: ""
        // Accent color override (defaults to root.lobeAccent)
        property color accentColor: root.lobeAccent

        implicitHeight: size === "small" ? UI.design.metrics.compact : (size === "large" ? UI.design.metrics.large : UI.design.metrics.control)
        implicitWidth: Math.max(implicitHeight, btnRow.implicitWidth + leftPadding + rightPadding)
        Layout.minimumWidth: type === "primary" && iconName !== "" ? implicitWidth : implicitHeight
        leftPadding: size === "small" ? 8 : 12
        rightPadding: leftPadding
        focusPolicy: Qt.StrongFocus
        Accessible.name: text

        font.family: root.fontMain
        font.pixelSize: size === "small" ? 12 : 13
        font.weight: type === "primary" ? Font.DemiBold : Font.Medium

        scale: lobeBtn.down ? 0.98 : 1.0
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
        opacity: lobeBtn.enabled ? 1.0 : 0.45

        background: Rectangle {
            id: bgRect
            radius: UI.design.metrics.radius
            clip: true

            readonly property color baseColor: {
                if (lobeBtn.type === "primary") {
                    return lobeBtn.down ? Qt.darker(lobeBtn.accentColor, 1.1) : (lobeBtn.hovered ? Qt.lighter(lobeBtn.accentColor, 1.08) : lobeBtn.accentColor)
                } else if (lobeBtn.type === "danger") {
                    return lobeBtn.down ? (root.isDarkTheme ? "#551919" : "#fca5a5") : (lobeBtn.hovered ? (root.isDarkTheme ? "#421515" : "#fee2e2") : (root.isDarkTheme ? "#2a1212" : "#fef2f2"))
                } else if (lobeBtn.type === "ghost" || lobeBtn.type === "text") {
                    return lobeBtn.hovered ? (root.isDarkTheme ? "#252530" : "#eaeaf0") : "transparent"
                } else {
                    // "default"
                    if (lobeBtn.glass) {
                        return lobeBtn.hovered ? 
                            (root.isDarkTheme ? Qt.rgba(0.18, 0.18, 0.25, 0.92) : Qt.rgba(0.92, 0.92, 0.96, 0.95)) : 
                            (root.isDarkTheme ? Qt.rgba(0.10, 0.10, 0.14, 0.85) : Qt.rgba(1.0, 1.0, 1.0, 0.88))
                    }
                    return lobeBtn.hovered ? (root.isDarkTheme ? "#2c2c38" : "#dedee4") : root.bgCard
                }
            }

            color: baseColor
            Behavior on color { ColorAnimation { duration: 130 } }

            border.color: {
                if (lobeBtn.visualFocus) return root.borderFocus
                if (lobeBtn.type === "primary") return Qt.darker(lobeBtn.accentColor, 1.15)
                if (lobeBtn.type === "danger") return root.isDarkTheme ? "#5c2424" : "#fca5a5"
                if (lobeBtn.type === "ghost" || lobeBtn.type === "text") return "transparent"
                return lobeBtn.hovered ? root.borderHighlight : root.borderSubtle
            }
            border.width: lobeBtn.visualFocus ? 2 : ((lobeBtn.type === "ghost" || lobeBtn.type === "text") ? 0 : 1)

            // Specular Top Edge Highlight Line (Lobe UI Signature)
            SurfaceSheen {
                anchors.fill: parent
                cornerRadius: parent.radius || 0
                highlightColor: lobeBtn.type === "primary" ? Qt.rgba(1, 1, 1, 0.35) : root.borderSpecular
                visible: root.enableSpecular && lobeBtn.type !== "ghost" && lobeBtn.type !== "text"
            }
        }

        contentItem: RowLayout {
            id: btnRow
            spacing: UI.design.metrics.gap

            LobeIcon {
                name: lobeBtn.iconName
                visible: lobeBtn.iconName !== ""
                color: {
                    if (lobeBtn.type === "primary") return root.getAccentContrastColor(lobeBtn.accentColor)
                    if (lobeBtn.type === "danger") return root.isDarkTheme ? "#f87171" : "#dc2626"
                    return root.textPrimary
                }
                size: UI.design.metrics.icon
            }

            Text {
                Layout.fillWidth: true
                text: lobeBtn.text
                elide: Text.ElideRight
                visible: lobeBtn.text !== ""
                color: {
                    if (lobeBtn.type === "primary") return root.getAccentContrastColor(lobeBtn.accentColor)
                    if (lobeBtn.type === "danger") return root.isDarkTheme ? "#f87171" : "#dc2626"
                    return root.textPrimary
                }
                font: lobeBtn.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: lobeBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            acceptedButtons: Qt.NoButton
        }
    }

    // ================= LOBE UI ACTION ICON (@lobehub/ui Specification) =================
    component LobeActionIcon: Item {
        id: actionIcon

        property string icon: ""
        property string title: "" // Tooltip
        property string size: "middle" // "small" (24px) | "middle" (28px) | "large" (36px)
        property string type: "ghost" // "ghost" | "default" | "primary" | "danger"
        property bool active: false
        property bool glass: root.enableGlass
        property color accentColor: root.lobeAccent

        signal clicked()

        implicitWidth: size === "small" ? UI.design.metrics.compact : (size === "large" ? UI.design.metrics.large : UI.design.metrics.control)
        implicitHeight: implicitWidth
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: title
        Accessible.onPressAction: if (enabled) clicked()
        Keys.onSpacePressed: if (enabled) clicked()
        Keys.onReturnPressed: if (enabled) clicked()

        scale: iconMouse.pressed ? 0.98 : 1.0
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
        opacity: enabled ? 1.0 : 0.45

        Rectangle {
            id: iconBg
            anchors.fill: parent
            radius: UI.design.metrics.radius
            clip: true

            readonly property color baseColor: {
                if (actionIcon.type === "primary" || actionIcon.active) {
                    return iconMouse.pressed ? Qt.darker(actionIcon.accentColor, 1.15) : 
                           (iconMouse.containsMouse ? Qt.lighter(actionIcon.accentColor, 1.1) : actionIcon.accentColor)
                } else if (actionIcon.type === "danger") {
                    return iconMouse.pressed ? (root.isDarkTheme ? "#551919" : "#fca5a5") : 
                           (iconMouse.containsMouse ? (root.isDarkTheme ? "#421515" : "#fee2e2") : "transparent")
                } else if (actionIcon.type === "default") {
                    if (actionIcon.glass) {
                        return iconMouse.containsMouse ? 
                            (root.isDarkTheme ? Qt.rgba(0.22, 0.22, 0.30, 0.95) : Qt.rgba(0.90, 0.90, 0.95, 0.95)) : 
                            (root.isDarkTheme ? Qt.rgba(0.12, 0.12, 0.16, 0.85) : Qt.rgba(1.0, 1.0, 1.0, 0.88))
                    }
                    return iconMouse.containsMouse ? (root.isDarkTheme ? "#2c2c38" : "#dedee4") : root.bgCard
                } else {
                    // ghost
                    return iconMouse.containsMouse ? (root.isDarkTheme ? "#2c2c38" : "#e5e5eb") : "transparent"
                }
            }

            color: baseColor
            Behavior on color { ColorAnimation { duration: 120 } }

            border.color: {
                if (actionIcon.activeFocus) return root.borderFocus
                if (actionIcon.type === "primary" || actionIcon.active) return Qt.darker(actionIcon.accentColor, 1.2)
                if (actionIcon.type === "default") return iconMouse.containsMouse ? root.borderHighlight : root.borderSubtle
                return "transparent"
            }
            border.width: actionIcon.activeFocus ? 2 : ((actionIcon.type === "ghost") ? 0 : 1)

            LobeIcon {
                anchors.centerIn: parent
                name: actionIcon.icon
                color: {
                    if (actionIcon.type === "primary" || actionIcon.active) return root.getAccentContrastColor(actionIcon.accentColor)
                    if (actionIcon.type === "danger") return root.isDarkTheme ? "#f87171" : "#dc2626"
                    if (iconMouse.containsMouse) return root.textPrimary
                    return root.textSecondary
                }
                size: actionIcon.size === "small" ? UI.design.metrics.smallIcon : (actionIcon.size === "large" ? 20 : UI.design.metrics.icon)
            }
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: actionIcon.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: actionIcon.clicked()
        }

        ToolTip.visible: actionIcon.title !== "" && (iconMouse.containsMouse || actionIcon.activeFocus)
        ToolTip.text: actionIcon.title
        ToolTip.delay: 500
    }

    // ================= LOBE UI TAG (@lobehub/ui Specification) =================
    component LobeTag: Item {
        id: lobeTag

        property string text: ""
        property string count: ""
        property color dotColor: "transparent"
        property string size: "small" // "small" (22px) | "middle" (26px)
        property bool closable: false
        property bool checkable: false
        property bool checked: false
        property color tagColor: "transparent"
        property bool glass: root.enableGlass

        signal clicked()
        signal close()

        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: text
        function activate() {
            if (checkable) checked = !checked
            clicked()
        }
        Accessible.onPressAction: activate()
        Keys.onSpacePressed: activate()
        Keys.onReturnPressed: activate()

        implicitHeight: size === "middle" ? 30 : 26
        implicitWidth: tagLayout.implicitWidth + (size === "middle" ? 20 : 16)
        width: Math.min(implicitWidth, parent ? parent.width : implicitWidth)
        ToolTip.visible: tagMouse.containsMouse && tagText.truncated
        ToolTip.text: text

        scale: tagMouse.pressed ? 0.96 : (tagMouse.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

        Rectangle {
            id: tagBg
            anchors.fill: parent
            radius: lobeTag.size === "middle" ? 6 : 4
            clip: true

            readonly property color baseColor: {
                if (lobeTag.checked) return root.lobeAccent
                if (tagMouse.containsMouse) {
                    return root.isDarkTheme ? Qt.rgba(0.20, 0.20, 0.28, 0.95) : Qt.rgba(0.90, 0.90, 0.95, 0.95)
                }
                if (lobeTag.tagColor && lobeTag.tagColor !== "transparent" && lobeTag.tagColor !== "#00000000") {
                    try {
                        var tc = Qt.color(lobeTag.tagColor)
                        if (tc && tc.a > 0) {
                            return Qt.rgba(tc.r, tc.g, tc.b, root.isDarkTheme ? 0.18 : 0.12)
                        }
                    } catch(e) {}
                }
                return lobeTag.glass ? 
                    (root.isDarkTheme ? Qt.rgba(0.12, 0.12, 0.16, 0.85) : Qt.rgba(1.0, 1.0, 1.0, 0.85)) : 
                    root.bgCard
            }

            color: baseColor
            Behavior on color { ColorAnimation { duration: 120 } }

            border.color: {
                if (lobeTag.activeFocus) return root.borderFocus
                if (lobeTag.checked) return Qt.darker(root.lobeAccent, 1.15)
                if (tagMouse.containsMouse) return root.borderHighlight
                if (lobeTag.tagColor && lobeTag.tagColor !== "transparent" && lobeTag.tagColor !== "#00000000") {
                    try {
                        var tc = Qt.color(lobeTag.tagColor)
                        if (tc && tc.a > 0) {
                            return Qt.rgba(tc.r, tc.g, tc.b, 0.4)
                        }
                    } catch(e) {}
                }
                return root.borderSubtle
            }
            border.width: 1


            RowLayout {
                id: tagLayout
                anchors.fill: parent
                anchors.leftMargin: 6; anchors.rightMargin: 6
                spacing: 5

                // Optional Category Dot
                Rectangle {
                    width: 5; height: 5; radius: 2.5
                    color: lobeTag.dotColor
                    visible: lobeTag.dotColor != "transparent" && !lobeTag.checked
                }

                Text {
                    id: tagText
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: lobeTag.text
                    color: lobeTag.checked ? root.getAccentContrastColor(root.lobeAccent) : root.textPrimary
                    font.family: root.fontMain
                    font.pixelSize: lobeTag.size === "middle" ? 13 : 12
                    font.weight: lobeTag.checked ? Font.DemiBold : Font.Normal
                    verticalAlignment: Text.AlignVCenter
                }

                // Optional Numeric Count
                Text {
                    text: lobeTag.count
                    color: lobeTag.checked ? Qt.rgba(1, 1, 1, 0.75) : root.textMuted
                    font.family: root.fontMono
                    font.pixelSize: 9
                    visible: lobeTag.count !== ""
                    verticalAlignment: Text.AlignVCenter
                }

                // Optional Close "×" Button
                Text {
                    text: "×"
                    color: lobeTag.checked ? root.getAccentContrastColor(root.lobeAccent) : (closeTagMouse.containsMouse ? root.textPrimary : root.textMuted)
                    font.family: root.fontMain
                    font.pixelSize: 12
                    visible: lobeTag.closable
                    verticalAlignment: Text.AlignVCenter

                    MouseArea {
                        id: closeTagMouse
                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: lobeTag.close()
                    }
                }
            }

            MouseArea {
                id: tagMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    lobeTag.activate()
                }
            }
        }
    }

    // ================= LOBE UI BADGE (@lobehub/ui Specification) =================
    component LobeBadge: Item {
        id: lobeBadge

        property var count: 0
        property int maxCount: 99
        property bool dot: false
        property color badgeColor: root.lobeAccent
        property color textColor: root.getAccentContrastColor(badgeColor)

        readonly property string displayCount: {
            if (dot) return ""
            if (typeof count === "number" && count > maxCount) return maxCount + "+"
            return "" + count
        }

        implicitHeight: dot ? 6 : 18
        implicitWidth: dot ? 6 : Math.max(18, badgeText.implicitWidth + 8)

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: lobeBadge.badgeColor
            clip: true


            Text {
                id: badgeText
                anchors.centerIn: parent
                text: lobeBadge.displayCount
                color: lobeBadge.textColor
                font.family: root.fontMono
                font.pixelSize: 9
                font.weight: Font.DemiBold
                visible: !lobeBadge.dot && lobeBadge.displayCount !== ""
            }
        }
    }

    // Context Menu for image cards (Global / Root accessible)
    Menu {
        id: cardContextMenu
        property int filteredIndex: -1
        property string filePath: ""
        onAboutToShow: filePath = gallery.pathAt(filteredIndex)

        background: Rectangle {
            implicitWidth: 190
            color: root.bgGlassPanel
            border.color: root.enableGlass ? (root.isDarkTheme ? Qt.rgba(1.0, 1.0, 1.0, 0.14) : Qt.rgba(0.0, 0.0, 0.0, 0.10)) : root.borderSubtle
            border.width: 1
            radius: 8
            clip: true
            SurfaceSheen {
                anchors.fill: parent
                cornerRadius: parent.radius || 0
                highlightColor: root.borderSpecular
            }
        }

        delegate: MenuItem {
            id: cMenuItem
            implicitHeight: 28
            contentItem: Text {
                leftPadding: 10
                rightPadding: 10
                text: cMenuItem.text
                color: cMenuItem.highlighted ? (root.isDarkTheme ? "#ffffff" : "#000000") : root.textPrimary
                font.family: root.fontMain
                font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 4
                color: cMenuItem.highlighted ? (root.isDarkTheme ? Qt.rgba(1.0, 1.0, 1.0, 0.12) : Qt.rgba(0.0, 0.0, 0.0, 0.08)) : "transparent"
            }
        }

        Action {
            text: root.tr("context.toggle_select", "Select / Unselect")
            onTriggered: gallery.toggleSelect(gallery.indexForPath(cardContextMenu.filePath))
        }
        Action {
            text: root.tr("context.reveal", "Reveal in File Explorer")
            onTriggered: gallery.revealInExplorer(cardContextMenu.filePath)
        }
        Action {
            text: root.tr("context.move_to_folder", "Move to Folder...")
            onTriggered: {
                moveFolderDialog.targetFilePath = cardContextMenu.filePath
                moveFolderDialog.open()
            }
        }
        Action {
            text: root.tr("context.delete_image", "Delete Image")
            onTriggered: root.requestDeletePath(cardContextMenu.filePath)
        }
    }

    // Reusable Gallery Card Component for Seamless Masonry and Grouped Sections
    component GalleryCard: Rectangle {
        id: card
        property var cardData
        readonly property bool hovered: cardHover.hovered
        width: root.columnWidth
        height: Math.max(60, width / (cardData && cardData.aspectRatio > 0 ? cardData.aspectRatio : 1.0))
        color: root.bgCard
        radius: root.itemSpacing > 0 ? 6 : 0 // Clean 0 radius for seamless mode
        clip: true
        z: (card.isCardSelected || card.isCardActive) ? 10 : (card.hovered ? 5 : 1)
        scale: 1.0

        readonly property bool isCardSelected: (gallery.selectionEpoch >= 0 && !!cardData && gallery.isPathSelected(cardData.filePath))
        readonly property bool isCardActive: (!!cardData && gallery.selectedImage.filePath === cardData.filePath)

        border.width: 0

        HoverHandler {
            id: cardHover
            blocking: false
        }

        Timer {
            id: holdPreviewTimer
            interval: 380
            repeat: false
            onTriggered: {
                if (root.previewDisplayMode === 1 && card.cardData && card.hovered && !badgeHover.hovered) {
                    root.showHoverPreviewForCard(card, card.cardData)
                }
            }
        }

        Image {
            id: cardImg
            anchors.fill: parent
            source: cardData ? cardData.url : ""
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.max(160, Math.round(card.width * root.dpr))
            mipmap: false
            cache: true
            opacity: status === Image.Ready ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
            }
        }

        LobeIcon {
            anchors.centerIn: parent
            name: "image"; size: 24; color: root.textMuted
            visible: cardImg.status === Image.Error
        }

        // Tinted overlay if selected
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.lobeAccent.r, root.lobeAccent.g, root.lobeAccent.b, 0.22)
            visible: card.isCardSelected
            z: 2
        }

        // Selection & Focus Border Overlay (Zero layout shift, strictly shown on selected items)
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: card.radius
            border.color: card.isCardActive ? (root.isDarkTheme ? "#ffffff" : root.lobeAccent) : root.lobeAccent
            border.width: 2
            visible: card.isCardSelected || card.isCardActive
            z: 4
        }

        // Subtle Hover Overlay (Zero layout shift, zero border popping)
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: card.hovered ? (root.isDarkTheme ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)) : "transparent"
            z: 3
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        // Keep the hit target stable while the pointer crosses into the badge.
        Rectangle {
            id: selectBadge
            objectName: "cardSelectionBadge"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 6
            width: 24
            height: 24
            radius: 12
            clip: true
            color: card.isCardSelected ? root.lobeAccent : (badgeHover.hovered ? "#b3000000" : "#70000000")
            border.color: card.isCardSelected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.85)
            border.width: card.isCardSelected ? 2 : 1.5
            visible: card.isCardSelected || card.hovered
            z: 10
            Accessible.role: Accessible.CheckBox
            Accessible.name: root.tr("ux.select_image", "Select image") + ": " + (card.cardData ? card.cardData.fileName : "")
            Accessible.checked: card.isCardSelected
            Accessible.onToggleAction: if (card.cardData) gallery.toggleSelect(card.cardData.filteredIndex)
            HoverHandler { id: badgeHover; blocking: false }

            // Inner solid accent dot when selected (no checkmarks)
            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: "#ffffff"
                visible: card.isCardSelected
            }

            MouseArea {
                id: badgeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                property string pressedPath: ""
                onPressed: pressedPath = card.cardData ? card.cardData.filePath : ""

                onClicked: (mouse) => {
                    root.focusMain()
                    var index = gallery.indexForPath(pressedPath)
                    if (index >= 0) {
                        if (mouse.modifiers & Qt.ShiftModifier) gallery.rangeSelect(index, !!(mouse.modifiers & Qt.ControlModifier))
                        else gallery.toggleSelect(index)
                    }
                }
            }
        }

        // Frosted Metadata watermark on hover
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 22
            color: root.isDarkTheme ? Qt.rgba(0.06, 0.06, 0.08, 0.85) : Qt.rgba(1.0, 1.0, 1.0, 0.88)
            visible: card.hovered && !!card.cardData
            z: 8

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                Text {
                    text: card.cardData ? (card.cardData.imgWidth + "×" + card.cardData.imgHeight) : ""
                    color: root.textSecondary
                    font.family: root.fontMono
                    font.pixelSize: 10
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: (card.cardData && card.cardData.modelName) ? card.cardData.modelName : ""
                    color: root.textMuted
                    font.family: root.fontMain
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property string pressedPath: ""
            onPressed: pressedPath = card.cardData ? card.cardData.filePath : ""
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                if (root.previewDisplayMode === 1) {
                    holdPreviewTimer.restart()
                }
            }
            onExited: {
                holdPreviewTimer.stop()
                if (root.activeHoverCard === card) {
                    root.dismissHoverPreviewDelayed()
                }
            }
            onPositionChanged: {
                if (root.previewDisplayMode === 1 && !root.activeHoverData) {
                    holdPreviewTimer.restart()
                }
            }
            onClicked: (mouse) => {
                root.focusMain()
                holdPreviewTimer.stop()
                root.activeHoverData = null
                root.activeHoverCard = null
                if (!card.cardData || typeof card.cardData.filteredIndex !== "number") return
                var fIdx = gallery.indexForPath(pressedPath)
                if (fIdx < 0) return
                if (mouse.button === Qt.RightButton) {
                    cardContextMenu.filteredIndex = fIdx
                    cardContextMenu.popup()
                } else {
                    if (mouse.modifiers & Qt.ShiftModifier) {
                        gallery.rangeSelect(fIdx, !!(mouse.modifiers & Qt.ControlModifier))
                    } else if (mouse.modifiers & Qt.ControlModifier) {
                        gallery.toggleSelect(fIdx)
                    } else {
                        gallery.selectSingle(fIdx)
                    }
                }
            }
            onDoubleClicked: {
                root.focusMain()
                holdPreviewTimer.stop()
                root.activeHoverData = null
                root.activeHoverCard = null
                if (!card.cardData || typeof card.cardData.filteredIndex !== "number") return
                var index = gallery.indexForPath(pressedPath)
                if (index < 0) return
                gallery.selectImage(index)
                root.openSelectedImage()
            }
        }
    }

    // Danbooru CSV Tag File Dialog
    FileDialog {
        id: csvFileDialog
        title: root.tr("settings.select_csv", "Select Danbooru / Booru CSV Tags")
        nameFilters: ["CSV files (*.csv)", "All files (*)"]
        onAccepted: {
            if (selectedFile) {
                tagAuto.loadCsvFileAsync(selectedFile)
            }
        }
    }

    // Folder Dialogs
    FolderDialog {
        id: folderDialog
        title: root.tr("toolbar.open", "Select Library Root Folder")
        onAccepted: gallery.openFolder(selectedFolder)
    }

    FolderDialog {
        id: moveFolderDialog
        title: root.tr("common.move", "Select Destination Folder")
        property int targetFilteredIndex: -1
        property string targetFilePath: ""
        onAccepted: {
            if (targetFilePath !== "") {
                gallery.moveFile(targetFilePath, selectedFolder)
            }
        }
    }

    FolderDialog {
        id: batchMoveFolderDialog
        property var targetFiles: []
        onVisibleChanged: if (visible) targetFiles = gallery.selectedList
        title: root.tr("common.move", "Move Selected Images")
        onAccepted: {
            gallery.moveFiles(targetFiles.map(function(item) { return item.filePath }), selectedFolder)
        }
    }

    // Deletion confirmation dialogs
    Dialog {
        id: deleteDialog
        objectName: "deleteImageDialog"
        title: root.useRecycleBin ? root.tr("common.recycle", "Recycle") : root.tr("common.delete", "Delete")
        padding: 20
        header: Text {
            text: parent.title; padding: 20; bottomPadding: 0
            font.family: root.fontMain; font.pixelSize: 18; font.weight: Font.DemiBold; color: root.textPrimary
        }
        modal: true
        anchors.centerIn: parent
        width: 420
        onOpened: cancelSingleDelete.forceActiveFocus()
        footer: RowLayout {
            spacing: 8
            height: 54
            Item { implicitWidth: 20 }
            Item { Layout.fillWidth: true }
            LobeButton { id: cancelSingleDelete; text: root.tr("common.cancel", "Cancel"); onClicked: deleteDialog.reject() }
            LobeButton {
                text: root.useRecycleBin ? root.tr("common.recycle", "Recycle") : root.tr("common.delete", "Delete")
                type: "danger"; iconName: "trash"; onClicked: deleteDialog.accept()
            }
            Item { implicitWidth: 20 }
        }
        property int targetFilteredIndex: -1
        property string targetFilePath: ""

        background: Rectangle {
            color: root.isDarkTheme ? "#202027" : "#fafafa"
            border.color: borderSubtle
            radius: 8
            clip: true
            SurfaceSheen {
                anchors.fill: parent
                cornerRadius: parent.radius || 0
                highlightColor: root.borderSpecular
            }
        }

        contentItem: ColumnLayout {
            spacing: 12
            Text {
                text: root.useRecycleBin ? 
                    (root.tr("common.recycle", "Recycle") + "?") : 
                    (root.tr("common.delete", "Delete") + "?")
                color: textPrimary
                font.family: fontMain
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Text {
                text: deleteDialog.targetFilePath.replace(/\\/g, "/").split("/").pop()
                color: textSecondary
                font.family: fontMono
                font.pixelSize: 11
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
        }

        onAccepted: {
            if (targetFilePath !== "") {
                gallery.deleteFile(targetFilePath, root.useRecycleBin)
            }
        }
    }

    Dialog {
        id: batchDeleteDialog
        property var targetFiles: []
        onAboutToShow: targetFiles = gallery.selectedList
        title: root.useRecycleBin ? root.tr("common.recycle", "Recycle") : root.tr("common.delete", "Delete")
        padding: 20
        header: Text {
            text: parent.title; padding: 20; bottomPadding: 0
            font.family: root.fontMain; font.pixelSize: 18; font.weight: Font.DemiBold; color: root.textPrimary
        }
        modal: true
        anchors.centerIn: parent
        width: 420
        onOpened: cancelBatchDelete.forceActiveFocus()
        footer: RowLayout {
            spacing: 8
            height: 54
            Item { implicitWidth: 20 }
            Item { Layout.fillWidth: true }
            LobeButton { id: cancelBatchDelete; text: root.tr("common.cancel", "Cancel"); onClicked: batchDeleteDialog.reject() }
            LobeButton {
                text: root.useRecycleBin ? root.tr("common.recycle", "Recycle") : root.tr("common.delete", "Delete")
                type: "danger"; iconName: "trash"; onClicked: batchDeleteDialog.accept()
            }
            Item { implicitWidth: 20 }
        }

        background: Rectangle {
            color: root.isDarkTheme ? "#202027" : "#fafafa"
            border.color: borderSubtle
            radius: 8
            clip: true
            SurfaceSheen {
                anchors.fill: parent
                cornerRadius: parent.radius || 0
                highlightColor: root.borderSpecular
            }
        }

        contentItem: ColumnLayout {
            spacing: 12
            Text {
                text: root.useRecycleBin ? 
                    (root.tr("common.recycle", "Recycle") + " (" + batchDeleteDialog.targetFiles.length + ")?") : 
                    (root.tr("common.delete", "Delete") + " (" + batchDeleteDialog.targetFiles.length + ")?")
                color: textPrimary
                font.family: fontMain
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Text {
                text: batchDeleteDialog.targetFiles.length + " " + root.tr("status.selected", "selected")
                color: textMuted
                font.family: fontMain
                font.pixelSize: 11
            }
        }

        onAccepted: {
            gallery.deleteFiles(targetFiles.map(function(item) { return item.filePath }), root.useRecycleBin)
        }
    }

    function requestDelete(filteredIndex) {
        requestDeletePath(gallery.pathAt(filteredIndex))
    }

    function requestDeletePath(path) {
        if (root.confirmDelete) {
            deleteDialog.targetFilePath = path
            deleteDialog.open()
        } else {
            gallery.deleteFile(path, root.useRecycleBin)
        }
    }

    function requestBatchDelete() {
        if (root.confirmDelete) {
            batchDeleteDialog.open()
        } else {
            gallery.deleteSelected(root.useRecycleBin)
        }
    }

    Dialog {
        id: operationErrorDialog
        objectName: "operationErrorDialog"
        property string message: ""
        title: root.tr("common.error", "Operation failed")
        modal: true
        anchors.centerIn: parent
        width: Math.min(520, root.width - 40)
        padding: 20
        header: Text {
            text: operationErrorDialog.title; padding: 20; bottomPadding: 0
            font.family: root.fontMain; font.pixelSize: 18; font.weight: Font.DemiBold; color: root.textPrimary
        }
        background: Rectangle {
            color: root.isDarkTheme ? "#202027" : "#fafafa"
            radius: 12; border.color: root.borderSubtle
        }
        footer: LobeButton { text: root.tr("common.ok", "OK"); onClicked: operationErrorDialog.accept() }
        contentItem: TextEdit {
            readOnly: true
            selectByMouse: true
            color: root.textPrimary
            text: operationErrorDialog.message
            wrapMode: TextEdit.Wrap
            font.family: root.fontMain
            font.pixelSize: 13
        }
    }
    Connections {
        target: gallery
        function onOperationFailed(message) {
            operationErrorDialog.message = message
            operationErrorDialog.open()
        }
        function onSelectedImageChanged() {
            if (root.activeModalUrl !== "") {
                if (gallery.selectedImage.filteredIndex === undefined) {
                    root.activeModalIndex = -1
                    root.activeModalUrl = ""
                } else {
                    root.activeModalIndex = gallery.selectedImage.filteredIndex
                    root.activeModalUrl = gallery.selectedImage.url.toString()
                }
            }
        }
    }
    Connections {
        target: tagAuto
        function onLoadFailed(message, translationKey, detail) {
            var translated = translationKey ? root.tr(translationKey, message) : message
            operationErrorDialog.message = detail ? translated.arg(detail) : translated
            operationErrorDialog.open()
        }
    }

    // ================= 2. MAIN APPLICATION WORKSPACE =================
    Rectangle {
        id: mainContent
        anchors.fill: parent
        color: root.bgApp
        clip: true
        focus: true

        // Full-window glow fades continuously; fixed paths move without being rebuilt each frame.
        Item {
            id: backdropScene
            objectName: "glassBackdropScene"
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: root.bgApp }
        Item {
            id: auroraContainer
            objectName: "auroraBackground"
            anchors.fill: parent
            z: 0
            visible: root.enableAurora
            opacity: root.auroraIntensity * (root.isDarkTheme ? 0.92 : 1.0)
            clip: true
            property real phase: 0
            readonly property real angle: phase * Math.PI * 2
            NumberAnimation on phase {
                objectName: "auroraAnimation"
                from: 0; to: 1; duration: 64000; loops: Animation.Infinite
                running: true
                paused: !root.enableAurora || !root.auroraAnimated || !root.visible || !root.active ||
                        root.visibility === Window.Minimized || root.settingsModalOpen || root.activeModalUrl !== ""
            }

            Shape {
                id: auroraCenterGlow
                width: auroraContainer.width * 1.22; height: auroraContainer.height
                x: auroraContainer.width * (-0.11 + 0.035 * Math.sin(auroraContainer.angle + 0))
                y: auroraContainer.height * -0.22
                opacity: 0.88 + 0.12 * Math.cos(auroraContainer.angle + 0)
                ShapePath {
                    strokeColor: "transparent"; strokeWidth: 0
                    fillGradient: RadialGradient {
                        centerX: auroraCenterGlow.width * 0.5; centerY: auroraCenterGlow.height * 0.08
                        focalX: centerX; focalY: centerY
                        centerRadius: Math.max(auroraCenterGlow.width * 0.42, auroraCenterGlow.height * 0.72)
                        GradientStop { position: 0.00; color: Qt.rgba(root.auroraColor1.r, root.auroraColor1.g, root.auroraColor1.b, (root.isDarkTheme?0.4:0.66)) }
                        GradientStop { position: 0.28; color: Qt.rgba(root.auroraColor1.r, root.auroraColor1.g, root.auroraColor1.b, (root.isDarkTheme?0.232:0.3828)) }
                        GradientStop { position: 0.62; color: Qt.rgba(root.auroraColor1.r, root.auroraColor1.g, root.auroraColor1.b, (root.isDarkTheme?0.060:0.09899999999999999)) }
                        GradientStop { position: 1.00; color: "transparent" }
                    }
                    startX: 0; startY: 0
                    PathLine { x: auroraCenterGlow.width; y: 0 }
                    PathLine { x: auroraCenterGlow.width; y: auroraCenterGlow.height }
                    PathLine { x: 0; y: auroraCenterGlow.height }
                    PathLine { x: 0; y: 0 }
                }
            }

            Shape {
                id: auroraWestGlow
                width: auroraContainer.width * 0.9; height: auroraContainer.height
                x: auroraContainer.width * (-0.25 + 0.035 * Math.sin(auroraContainer.angle + 2.1))
                y: auroraContainer.height * -0.16
                opacity: 0.88 + 0.12 * Math.cos(auroraContainer.angle + 2.1)
                ShapePath {
                    strokeColor: "transparent"; strokeWidth: 0
                    fillGradient: RadialGradient {
                        centerX: auroraWestGlow.width * 0.38; centerY: auroraWestGlow.height * 0.1
                        focalX: centerX; focalY: centerY
                        centerRadius: Math.max(auroraWestGlow.width * 0.52, auroraWestGlow.height * 0.72)
                        GradientStop { position: 0.00; color: Qt.rgba(root.auroraColor2.r, root.auroraColor2.g, root.auroraColor2.b, (root.isDarkTheme?0.32:0.528)) }
                        GradientStop { position: 0.28; color: Qt.rgba(root.auroraColor2.r, root.auroraColor2.g, root.auroraColor2.b, (root.isDarkTheme?0.186:0.3069)) }
                        GradientStop { position: 0.62; color: Qt.rgba(root.auroraColor2.r, root.auroraColor2.g, root.auroraColor2.b, (root.isDarkTheme?0.048:0.07919999999999999)) }
                        GradientStop { position: 1.00; color: "transparent" }
                    }
                    startX: 0; startY: 0
                    PathLine { x: auroraWestGlow.width; y: 0 }
                    PathLine { x: auroraWestGlow.width; y: auroraWestGlow.height }
                    PathLine { x: 0; y: auroraWestGlow.height }
                    PathLine { x: 0; y: 0 }
                }
            }

            Shape {
                id: auroraEastGlow
                width: auroraContainer.width * 0.9; height: auroraContainer.height
                x: auroraContainer.width * (0.35 + 0.035 * Math.sin(auroraContainer.angle + 4.2))
                y: auroraContainer.height * -0.18
                opacity: 0.88 + 0.12 * Math.cos(auroraContainer.angle + 4.2)
                ShapePath {
                    strokeColor: "transparent"; strokeWidth: 0
                    fillGradient: RadialGradient {
                        centerX: auroraEastGlow.width * 0.62; centerY: auroraEastGlow.height * 0.1
                        focalX: centerX; focalY: centerY
                        centerRadius: Math.max(auroraEastGlow.width * 0.52, auroraEastGlow.height * 0.72)
                        GradientStop { position: 0.00; color: Qt.rgba(root.auroraColor3.r, root.auroraColor3.g, root.auroraColor3.b, 0.3) }
                        GradientStop { position: 0.28; color: Qt.rgba(root.auroraColor3.r, root.auroraColor3.g, root.auroraColor3.b, 0.174) }
                        GradientStop { position: 0.62; color: Qt.rgba(root.auroraColor3.r, root.auroraColor3.g, root.auroraColor3.b, 0.045) }
                        GradientStop { position: 1.00; color: "transparent" }
                    }
                    startX: 0; startY: 0
                    PathLine { x: auroraEastGlow.width; y: 0 }
                    PathLine { x: auroraEastGlow.width; y: auroraEastGlow.height }
                    PathLine { x: 0; y: auroraEastGlow.height }
                    PathLine { x: 0; y: 0 }
                }
            }

            AuroraRibbon {
                width: auroraContainer.width * 1.22; height: auroraContainer.height * 0.78
                x: -auroraContainer.width * 0.11 + Math.sin(auroraContainer.angle + 0.8) * 24
                y: auroraContainer.height * 0.015 + Math.cos(auroraContainer.angle + 0.8) * 12
                rotation: 3
                opacity: 0.80 + 0.20 * Math.sin(auroraContainer.angle + 0.8)
                startColor: root.auroraColor3; endColor: root.auroraColor1; strength: 0.28
            }
            AuroraRibbon {
                width: auroraContainer.width * 1.22; height: auroraContainer.height * 0.78
                x: -auroraContainer.width * 0.11 + Math.sin(auroraContainer.angle + 3.0) * 24
                y: auroraContainer.height * 0.075 + Math.cos(auroraContainer.angle + 3.0) * 12
                rotation: -3
                opacity: 0.80 + 0.20 * Math.sin(auroraContainer.angle + 3.0)
                startColor: root.auroraColor2; endColor: root.auroraColor4; strength: 0.20
            }
        }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            z: 1

            // ---------------- 2.1 PRIMARY TOOLBAR (Frosted Glass & Custom Controls) ----------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: root.enableGlass ? "transparent" : root.bgSurface
                border.color: root.enableGlass ? "transparent" : root.borderSubtle
                border.width: root.enableGlass ? 0 : 1
                FrostedPanel {
                    objectName: "toolbarGlass"
                    anchors.fill: parent; radius: 0
                    sourceScene: backdropScene; visible: root.enableGlass; glassEnabled: root.enableGlass
                    dark: root.isDarkTheme; specular: root.enableSpecular
                    tintColor: root.bgApp; accent: root.lobeAccent
                    amount: root.glassBlurAmount; opacityLevel: root.glassOpacity
                    tintStrength: root.glassTintStrength; chroma: root.glassChroma
                    captureLive: root.active && root.visible && !root.settingsModalOpen
                }

                z: 100

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    BrandBadge {
                        accentColor: root.lobeAccent
                        primaryColor: root.textPrimary
                        backgroundColor: root.bgSurface
                        fontFamily: root.fontMain
                    }

                    // Left Sidebar Toggle (Lobe Action Icon)
                    LobeActionIcon {
                        id: sidebarToggleBtn
                        icon: "panel-left"
                        title: root.tr("toolbar.toggle_sidebar", "Sidebar (B)")
                        active: root.showLeftSidebar
                        onClicked: root.showLeftSidebar = !root.showLeftSidebar
                    }

                    Rectangle { width: 1; height: 18; color: borderSubtle }

                    // Open Library Button (Lobe UI Primary Pill)
                    LobeButton {
                        text: root.tr("toolbar.open", "Open")
                        iconName: "folder-open"
                        type: "primary"
                        size: "middle"
                        onClicked: folderDialog.open()
                    }

                    // Search Prompt with Autocomplete (High Contrast Frosted Glass Input)
                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 180
                        Layout.preferredHeight: 36

                        Rectangle {
                            anchors.fill: parent
                            color: bgInput
                            border.color: searchInput.activeFocus ? borderFocus : borderSubtle
                            border.width: 1
                            radius: 6
                            clip: true

                            SurfaceSheen {
                                anchors.fill: parent
                                cornerRadius: parent.radius || 0
                                highlightColor: root.borderSpecular
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 6

                                LobeIcon {
                                    name: "search"
                                    color: textMuted
                                    size: 14
                                }

                                TextInput {
                                    id: searchInput
                                    objectName: "searchInput"
                                    Accessible.name: root.tr("ux.search", "Search library")
                                    Layout.fillWidth: true
                                    color: textPrimary
                                    font.family: fontMain
                                    font.pixelSize: 13
                                    selectByMouse: true
                                    clip: true
                                    property string placeholder: root.tr("toolbar.search_placeholder", "Search prompt, tags, characters...")

                                    Text {
                                        anchors.fill: parent
                                        text: searchInput.placeholder
                                        color: textMuted
                                        font.family: fontMain
                                        font.pixelSize: 13
                                        visible: !searchInput.text && !searchInput.activeFocus
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Timer {
                                        id: searchDebounceTimer
                                        interval: 220
                                        repeat: false
                                        onTriggered: {
                                            gallery.setSearchQuery(searchInput.text)
                                        }
                                    }

                                    function applySelectedTag(tagName) {
                                        searchDebounceTimer.stop()
                                        var lastCommaIdx = searchInput.text.lastIndexOf(",")
                                        var prefix = (lastCommaIdx >= 0) ? searchInput.text.substring(0, lastCommaIdx + 1).trim() + " " : ""
                                        searchInput.text = prefix + tagName + ", "
                                        gallery.setSearchQuery(searchInput.text)
                                        tagPopup.close()
                                        searchInput.forceActiveFocus()
                                    }

                                    onActiveFocusChanged: if (!activeFocus) tagPopup.close()
                                    onTextChanged: {
                                        searchDebounceTimer.restart()
                                        var lastCommaIdx = text.lastIndexOf(",")
                                        var currentWord = (lastCommaIdx >= 0 ? text.substring(lastCommaIdx + 1) : text).trim()
                                        if (activeFocus && currentWord.length >= 2) {
                                            tagPopupList.model = tagAuto.suggest(currentWord, 15)
                                            tagPopupList.currentIndex = 0
                                            tagPopup.open()
                                        } else {
                                            tagPopup.close()
                                        }
                                    }

                                    Keys.onDownPressed: (event) => {
                                        if (tagPopup.opened && tagPopupList.count > 0) {
                                            tagPopupList.currentIndex = (tagPopupList.currentIndex + 1) % tagPopupList.count
                                            tagPopupList.positionViewAtIndex(tagPopupList.currentIndex, ListView.Contain)
                                            event.accepted = true
                                        } else {
                                            event.accepted = false
                                        }
                                    }

                                    Keys.onUpPressed: (event) => {
                                        if (tagPopup.opened && tagPopupList.count > 0) {
                                            tagPopupList.currentIndex = (tagPopupList.currentIndex - 1 + tagPopupList.count) % tagPopupList.count
                                            tagPopupList.positionViewAtIndex(tagPopupList.currentIndex, ListView.Contain)
                                            event.accepted = true
                                        } else {
                                            event.accepted = false
                                        }
                                    }

                                    Keys.onTabPressed: (event) => {
                                        if (tagPopup.opened && tagPopupList.count > 0 && tagPopupList.currentIndex >= 0 && tagPopupList.currentIndex < tagPopupList.count) {
                                            var sel = tagPopupList.model[tagPopupList.currentIndex]
                                            var selTag = (typeof sel === "object" && sel.name !== undefined) ? sel.name : sel
                                            applySelectedTag(selTag)
                                            event.accepted = true
                                        } else {
                                            event.accepted = false
                                        }
                                    }

                                    onAccepted: {
                                        if (tagPopup.opened && tagPopupList.count > 0 && tagPopupList.currentIndex >= 0 && tagPopupList.currentIndex < tagPopupList.count) {
                                            var sel = tagPopupList.model[tagPopupList.currentIndex]
                                            var selTag = (typeof sel === "object" && sel.name !== undefined) ? sel.name : sel
                                            applySelectedTag(selTag)
                                        } else {
                                            searchDebounceTimer.stop()
                                            gallery.setSearchQuery(text)
                                            tagPopup.close()
                                        }
                                    }
                                }

                                LobeActionIcon {
                                    icon: "x"
                                    size: "small"
                                    title: root.tr("common.clear", "Clear")
                                    visible: searchInput.text.length > 0
                                    onClicked: {
                                        searchDebounceTimer.stop()
                                        searchInput.text = ""
                                        gallery.setSearchQuery("")
                                        tagPopup.close()
                                    }
                                }
                            }
                        }

                        // Autocomplete Glass Popup
                        Popup {
                            id: tagPopup
                            y: parent.height + 4
                            width: parent.width
                            padding: 6
                            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                            background: Rectangle {
                                color: root.bgGlassPanel
                                border.color: root.enableGlass ? (root.isDarkTheme ? Qt.rgba(1.0, 1.0, 1.0, 0.14) : Qt.rgba(0.0, 0.0, 0.0, 0.10)) : root.borderSubtle
                                border.width: 1
                                radius: 8
                                clip: true
                                SurfaceSheen {
                                    anchors.fill: parent
                                    cornerRadius: parent.radius || 0
                                    highlightColor: root.borderSpecular
                                }
                            }

                            ListView {
                                id: tagPopupList
                                implicitHeight: Math.min(contentHeight, 380)
                                width: parent.width
                                clip: true

                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                    width: 4
                                    background: Rectangle { color: "transparent" }
                                    contentItem: Rectangle {
                                        radius: 2
                                        color: root.isDarkTheme ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.25)
                                    }
                                }

                                delegate: Rectangle {
                                    width: tagPopupList.width
                                    height: 28
                                    radius: 4
                                    color: (itemArea.containsMouse || tagPopupList.currentIndex === index) ? 
                                        (isDarkTheme ? "#2b2b36" : "#e8e8ee") : "transparent"
                                    border.color: tagPopupList.currentIndex === index ? root.lobeAccent : "transparent"
                                    border.width: tagPopupList.currentIndex === index ? 1 : 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Rectangle {
                                            width: 6; height: 6; radius: 3
                                            color: modelData.color
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            color: textPrimary
                                            font.family: fontMain
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: modelData.count > 1 ? modelData.count : ""
                                            color: textMuted
                                            font.family: fontMono
                                            font.pixelSize: 10
                                        }
                                    }

                                    MouseArea {
                                        id: itemArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchInput.applySelectedTag(modelData.name)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Reveal in File Explorer (Lobe Action Icon)
                    LobeActionIcon {
                        id: topBarRevealBtn
                        icon: "folder-open"
                        title: root.tr("toolbar.reveal", "Reveal in File Explorer")
                        enabled: (gallery.selectedImage && gallery.selectedImage.filePath !== undefined && gallery.selectedImage.filePath !== "") || gallery.selectedCount > 0
                        opacity: enabled ? 1.0 : 0.4
                        onClicked: gallery.revealSelectedInExplorer()
                    }

                    // Theme Toggle (Lobe Action Icon)
                    LobeActionIcon {
                        icon: root.isDarkTheme ? "moon" : "sun"
                        title: root.isDarkTheme ? root.tr("toolbar.switch_light", "Switch to Light mode") : root.tr("toolbar.switch_dark", "Switch to Dark mode")
                        onClicked: root.isDarkTheme = !root.isDarkTheme
                    }

                    // Inspector Sidebar Toggle (Lobe Action Icon)
                    LobeActionIcon {
                        id: inspectorToggleBtn
                        icon: "panel-right"
                        title: root.tr("toolbar.toggle_inspector", "Inspector (I)")
                        active: root.showInspector
                        onClicked: root.showInspector = !root.showInspector
                    }

                    // Settings (Lobe Action Icon)
                    LobeActionIcon {
                        icon: "settings"
                        title: root.tr("toolbar.settings", "Settings (Ctrl+,)")
                        active: root.settingsModalOpen
                        onClicked: root.settingsModalOpen = true
                    }
                }
            }

            // Library context and view controls share a separate, compact row.
            Rectangle {
                id: libraryContextBar
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: root.bgSurface
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.borderSubtle }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16; anchors.rightMargin: 16
                    spacing: 12
                    LobeIcon { name: "folder"; size: 16; color: root.textMuted }
                    Text {
                        id: libraryPathLabel
                        Layout.fillWidth: true
                        Layout.minimumWidth: 50
                        text: gallery.currentFolder ? gallery.currentFolder.replace(/\\/g, "/").split("/").filter(Boolean).pop() : root.tr("ux.library", "Library")
                        color: root.textSecondary
                        font.family: root.fontMain; font.pixelSize: 13; font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                        ToolTip.visible: libraryPathMouse.containsMouse && gallery.currentFolder !== ""
                        ToolTip.text: gallery.currentFolder
                        MouseArea { id: libraryPathMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    }
                    LobeButton {
                        id: libraryStatusButton
                        objectName: "libraryStatusButton"
                        size: "small"; type: root.libraryBusy ? "default" : "ghost"
                        iconName: root.libraryBusy ? "clock" : "image"
                        text: root.libraryBusy ?
                            (gallery.isLoading ? Math.round(gallery.scanProgress * 100) + "%" : root.tr("ux.updating_short", "Updating…")) :
                            gallery.filteredCount + " / " + gallery.totalCount
                        Accessible.name: root.tr("ux.library_status", "Library status") + ": " + root.libraryStatusText
                        ToolTip.visible: hovered
                        ToolTip.text: root.libraryStatusText + "\n" + gallery.filteredCount + " " + root.tr("status.matching", "matching") + " / " + gallery.totalCount + " " + root.tr("status.total", "total")
                        onClicked: libraryStatusPopup.open()
                    }
                    // Custom Styled Model ComboBox
                    RowLayout {
                        spacing: 6
                        Text {
                            text: root.tr("toolbar.model", "Model")
                            color: textMuted
                            font.family: fontMain
                            font.pixelSize: 13
                        }

                        ComboBox {
                            id: modelCombo
                            Accessible.name: root.tr("toolbar.model", "Model")
                            model: gallery.availableModelDetails
                            textRole: "displayName"
                            valueRole: "name"
                            implicitHeight: 32
                            implicitWidth: root.width < 1200 ? 150 : 175
                            font.family: root.fontMain
                            font.pixelSize: 13

                            function syncIndex() {
                                if (!model || model.length === 0) return
                                var target = gallery.selectedModel
                                for (var i = 0; i < model.length; ++i) {
                                    var item = model[i]
                                    var name = (item && item.name !== undefined) ? item.name : item
                                    if (name === target) {
                                        if (currentIndex !== i) currentIndex = i
                                        return
                                    }
                                }
                                currentIndex = 0
                            }

                            onModelChanged: syncIndex()
                            onActivated: (index) => {
                                if (index >= 0 && index < model.length) {
                                    var item = model[index]
                                    gallery.selectedModel = (item && item.name !== undefined) ? item.name : item
                                }
                            }

                            Connections {
                                target: gallery
                                function onSelectedModelChanged() {
                                    modelCombo.syncIndex()
                                }
                                function onAvailableModelsChanged() {
                                    modelCombo.syncIndex()
                                }
                            }

                            background: Rectangle {
                                color: modelCombo.hovered ? (root.isDarkTheme ? "#262632" : "#f0f0f4") : root.bgInput
                                border.color: modelCombo.activeFocus ? root.borderFocus : root.borderSubtle
                                border.width: 1
                                radius: 6
                                clip: true
                                SurfaceSheen {
                                    anchors.fill: parent
                                    cornerRadius: parent.radius || 0
                                    highlightColor: root.borderSpecular
                                }
                            }

                            contentItem: Text {
                                leftPadding: 10
                                rightPadding: 20
                                text: {
                                    if (modelCombo.currentIndex === 0 || gallery.selectedModel === "All") {
                                        var cnt = (modelCombo.model && modelCombo.model.length > 0 && modelCombo.model[0].count !== undefined) ? modelCombo.model[0].count : gallery.totalImagesCount
                                        return root.tr("common.all", "All") + " (" + cnt + ")"
                                    }
                                    return modelCombo.displayText
                                }
                                font: modelCombo.font
                                color: root.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            indicator: Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "▾"
                                color: root.textMuted
                                font.pixelSize: 13
                            }

                            popup: Popup {
                                y: modelCombo.height + 4
                                width: Math.max(modelCombo.width, 280)
                                padding: 4
                                background: Rectangle {
                                    color: root.bgGlassPanel
                                    border.color: root.enableGlass ? (root.isDarkTheme ? Qt.rgba(1.0, 1.0, 1.0, 0.14) : Qt.rgba(0.0, 0.0, 0.0, 0.10)) : root.borderSubtle
                                    border.width: 1
                                    radius: 8
                                    clip: true
                                    SurfaceSheen {
                                        anchors.fill: parent
                                        cornerRadius: parent.radius || 0
                                        highlightColor: root.borderSpecular
                                    }
                                }
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: Math.min(contentHeight, 260)
                                    model: modelCombo.popup.visible ? modelCombo.delegateModel : null
                                    currentIndex: modelCombo.highlightedIndex
                                }
                            }

                            delegate: ItemDelegate {
                                width: ListView.view ? ListView.view.width : 280
                                height: 30
                                background: Rectangle {
                                    radius: 4
                                    color: highlighted ? (root.isDarkTheme ? "#2c2c38" : "#e8e8ee") : "transparent"
                                }
                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6
                                    Text {
                                        text: (modelData && modelData.folder && modelData.folder !== "Other" && modelData.folder !== "Unknown") ? (modelData.folder + " /") : ""
                                        color: root.lobeAccent
                                        font.family: root.fontMain
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        visible: text.length > 0
                                    }
                                    Text {
                                        text: {
                                            var rawName = (modelData && modelData.name !== undefined) ? modelData.name : (modelData || "")
                                            if (rawName === "All") return root.tr("common.all", "All")
                                            return rawName
                                        }
                                        color: highlighted ? root.lobeAccent : root.textPrimary
                                        font.family: root.fontMain
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: (modelData && modelData.count !== undefined) ? ("" + modelData.count) : ""
                                        color: root.textMuted
                                        font.family: root.fontMono
                                        font.pixelSize: 10
                                        visible: text.length > 0
                                    }
                                }
                            }
                        }
                    }

                    // Custom Styled Sort ComboBox
                    RowLayout {
                        spacing: 6
                        Text {
                            text: root.tr("toolbar.sort", "Sort")
                            color: textMuted
                            font.family: fontMain
                            font.pixelSize: 13
                        }

                        ComboBox {
                            id: sortCombo
                            Accessible.name: root.tr("toolbar.sort", "Sort")
                            model: [
                                root.tr("sort.newest", "Newest First"),
                                root.tr("sort.oldest", "Oldest First"),
                                root.tr("sort.name_asc", "Name (A-Z)"),
                                root.tr("sort.name_desc", "Name (Z-A)"),
                                root.tr("sort.by_model", "Model"),
                                root.tr("sort.size_desc", "File Size"),
                                root.tr("sort.res_desc", "Resolution")
                            ]
                            onModelChanged: {
                                if (currentIndex !== gallery.sortMode) currentIndex = gallery.sortMode
                            }
                            implicitHeight: 32
                            implicitWidth: root.width < 1200 ? 150 : 175
                            font.family: root.fontMain
                            font.pixelSize: 13
                            currentIndex: gallery.sortMode
                            onActivated: (index) => { gallery.sortMode = index }

                            Connections {
                                target: gallery
                                function onSortModeChanged() {
                                    if (sortCombo.currentIndex !== gallery.sortMode) {
                                        sortCombo.currentIndex = gallery.sortMode
                                    }
                                }
                            }

                            background: Rectangle {
                                color: sortCombo.hovered ? (root.isDarkTheme ? "#262632" : "#f0f0f4") : root.bgInput
                                border.color: sortCombo.activeFocus ? root.borderFocus : root.borderSubtle
                                border.width: 1
                                radius: 6
                                clip: true
                                SurfaceSheen {
                                    anchors.fill: parent
                                    cornerRadius: parent.radius || 0
                                    highlightColor: root.borderSpecular
                                }
                            }

                            contentItem: Text {
                                leftPadding: 10
                                rightPadding: 20
                                text: sortCombo.displayText
                                font: sortCombo.font
                                color: root.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            indicator: Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "▾"
                                color: root.textMuted
                                font.pixelSize: 13
                            }

                            popup: Popup {
                                y: sortCombo.height + 4
                                width: Math.max(sortCombo.width, 175)
                                padding: 4
                                background: Rectangle {
                                    color: root.bgGlassPanel
                                    border.color: root.enableGlass ? (root.isDarkTheme ? Qt.rgba(1.0, 1.0, 1.0, 0.14) : Qt.rgba(0.0, 0.0, 0.0, 0.10)) : root.borderSubtle
                                    border.width: 1
                                    radius: 8
                                    clip: true
                                    SurfaceSheen {
                                        anchors.fill: parent
                                        cornerRadius: parent.radius || 0
                                        highlightColor: root.borderSpecular
                                    }
                                }
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: Math.min(contentHeight, 220)
                                    model: sortCombo.popup.visible ? sortCombo.delegateModel : null
                                    currentIndex: sortCombo.highlightedIndex
                                }
                            }

                            delegate: ItemDelegate {
                                width: ListView.view ? ListView.view.width : 160
                                height: 28
                                background: Rectangle {
                                    radius: 4
                                    color: highlighted ? (root.isDarkTheme ? "#2c2c38" : "#e8e8ee") : "transparent"
                                }
                                contentItem: Text {
                                    text: modelData
                                    color: highlighted ? root.lobeAccent : root.textPrimary
                                    font.family: root.fontMain
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 8
                                }
                            }
                        }
                    }

                    // Custom Styled Group ComboBox
                    RowLayout {
                        spacing: 6
                        Text {
                            text: root.tr("toolbar.group", "Group")
                            color: textMuted
                            font.family: fontMain
                            font.pixelSize: 13
                        }

                        ComboBox {
                            id: groupCombo
                            Accessible.name: root.tr("toolbar.group", "Group")
                            model: [
                                root.tr("group.none", "None"),
                                root.tr("group.by_folder", "By Folder"),
                                root.tr("group.by_model", "By Model"),
                                root.tr("group.by_date", "By Date")
                            ]
                            onModelChanged: {
                                if (currentIndex !== gallery.groupMode) currentIndex = gallery.groupMode
                            }
                            implicitHeight: 32
                            implicitWidth: 120
                            font.family: root.fontMain
                            font.pixelSize: 13
                            currentIndex: gallery.groupMode
                            onActivated: (index) => { gallery.groupMode = index }

                            Connections {
                                target: gallery
                                function onGroupModeChanged() {
                                    if (groupCombo.currentIndex !== gallery.groupMode) {
                                        groupCombo.currentIndex = gallery.groupMode
                                    }
                                }
                            }

                            background: Rectangle {
                                color: groupCombo.hovered ? (root.isDarkTheme ? "#262632" : "#f0f0f4") : root.bgInput
                                border.color: groupCombo.activeFocus ? root.borderFocus : root.borderSubtle
                                border.width: 1
                                radius: 6
                                clip: true
                                SurfaceSheen {
                                    anchors.fill: parent
                                    cornerRadius: parent.radius || 0
                                    highlightColor: root.borderSpecular
                                }
                            }

                            contentItem: Text {
                                leftPadding: 10
                                rightPadding: 20
                                text: groupCombo.displayText
                                font: groupCombo.font
                                color: root.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            indicator: Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "▾"
                                color: root.textMuted
                                font.pixelSize: 13
                            }

                            popup: Popup {
                                y: groupCombo.height + 4
                                width: Math.max(groupCombo.width, 140)
                                padding: 4
                                background: Rectangle {
                                    color: root.bgGlassPanel
                                    border.color: root.enableGlass ? (root.isDarkTheme ? Qt.rgba(1.0, 1.0, 1.0, 0.14) : Qt.rgba(0.0, 0.0, 0.0, 0.10)) : root.borderSubtle
                                    border.width: 1
                                    radius: 8
                                    clip: true
                                    SurfaceSheen {
                                        anchors.fill: parent
                                        cornerRadius: parent.radius || 0
                                        highlightColor: root.borderSpecular
                                    }
                                }
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: Math.min(contentHeight, 200)
                                    model: groupCombo.popup.visible ? groupCombo.delegateModel : null
                                    currentIndex: groupCombo.highlightedIndex
                                }
                            }

                            delegate: ItemDelegate {
                                width: ListView.view ? ListView.view.width : 130
                                height: 28
                                background: Rectangle {
                                    radius: 4
                                    color: highlighted ? (root.isDarkTheme ? "#2c2c38" : "#e8e8ee") : "transparent"
                                }
                                contentItem: Text {
                                    text: modelData
                                    color: highlighted ? root.lobeAccent : root.textPrimary
                                    font.family: root.fontMain
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 8
                                }
                            }
                        }
                    }
                    LobeButton {
                        objectName: "resetFiltersButton"
                        iconName: "x"; type: root.hasActiveFilters ? "primary" : "ghost"
                        text: root.tr("ux.reset_short", "Reset")
                        ToolTip.visible: hovered
                        ToolTip.text: root.tr("ux.reset_filters", "Reset filters")
                        enabled: root.hasActiveFilters
                        onClicked: root.resetFilters()
                    }
                }
                ProgressBar {
                    objectName: "libraryProgress"
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: 2
                    visible: root.libraryBusy
                    value: gallery.scanProgress
                    indeterminate: gallery.isFiltering && !gallery.isLoading
                    background: Rectangle { color: root.borderSubtle }
                    contentItem: Item {
                        clip: true
                        Rectangle {
                            id: libraryProgressFill
                            height: parent.height
                            width: gallery.isLoading ? parent.width * Math.max(0, Math.min(1, gallery.scanProgress)) : parent.width * 0.28
                            color: root.lobeAccent
                            x: gallery.isLoading ? 0 : (parent.width + width) * filterProgressAnimation.progress - width
                            QtObject { id: filterProgressAnimation; property real progress: 0 }
                            NumberAnimation {
                                target: filterProgressAnimation; property: "progress"; from: 0; to: 1
                                duration: 1100; loops: Animation.Infinite
                                running: gallery.isFiltering && !gallery.isLoading && root.visible
                            }
                        }
                    }
                }
            }

            // ---------------- 2.3 MAIN WORKSPACE ----------------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // A. LEFT SIDEBAR: FLOATING FROSTED GLASS ISLAND (Tags & Folder Explorer)
                Rectangle {
                    id: leftSidebarRect
                    Layout.preferredWidth: root.showLeftSidebar ? root.leftSidebarWidth : 0
                    Layout.fillHeight: true
                    Layout.topMargin: root.showLeftSidebar ? 8 : 0
                    Layout.bottomMargin: root.showLeftSidebar ? 8 : 0
                    Layout.leftMargin: root.showLeftSidebar ? 8 : 0
                    Layout.rightMargin: root.showLeftSidebar ? 4 : 0
                    radius: 14
                    clip: true
                    opacity: root.showLeftSidebar ? 1.0 : 0.0
                    visible: Layout.preferredWidth > 0
                    Behavior on Layout.preferredWidth {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                    }
                    color: root.enableGlass ? "transparent" : root.bgSurface
                    border.color: root.enableGlass ? "transparent" : root.borderSubtle
                    border.width: root.enableGlass ? 0 : 1
                    FrostedPanel {
                        objectName: "leftSidebarGlass"
                        anchors.fill: parent; radius: parent.radius
                        sourceScene: backdropScene; visible: root.enableGlass; glassEnabled: root.enableGlass
                        dark: root.isDarkTheme; specular: root.enableSpecular
                        tintColor: root.bgApp; accent: root.lobeAccent
                        amount: root.glassBlurAmount; opacityLevel: root.glassOpacity
                        tintStrength: root.glassTintStrength; chroma: root.glassChroma
                        captureLive: root.active && root.visible && !root.settingsModalOpen
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // 1. Segmented Switcher: [Теги / Tags] [Проводник / Explorer]
                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: 8
                            color: root.bgInput
                            border.color: root.borderSubtle
                            clip: true

                            SurfaceSheen {
                                anchors.fill: parent
                                cornerRadius: parent.radius || 0
                                highlightColor: root.borderSpecular
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 2
                                spacing: 2

                                // Tags Mode Button
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 6
                                    color: root.leftSidebarMode === 0 ? root.bgCard : (tagsTabMouse.containsMouse ? (isDarkTheme ? "#262632" : "#eaebee") : "transparent")
                                    border.color: root.leftSidebarMode === 0 ? root.borderSubtle : "transparent"
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        LobeIcon {
                                            name: "tag"
                                            size: 13
                                            color: root.leftSidebarMode === 0 ? root.lobeAccent : root.textSecondary
                                        }
                                        Text {
                                            text: root.tr("sidebar.tags", "Tags")
                                            color: root.leftSidebarMode === 0 ? root.textPrimary : root.textSecondary
                                            font.family: root.fontMain
                                            font.pixelSize: 12
                                            font.weight: root.leftSidebarMode === 0 ? Font.DemiBold : Font.Normal
                                        }
                                    }

                                    MouseArea {
                                        id: tagsTabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.leftSidebarMode = 0
                                    }
                                }

                                // Explorer Mode Button
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 6
                                    color: root.leftSidebarMode === 1 ? root.bgCard : (explorerTabMouse.containsMouse ? (isDarkTheme ? "#262632" : "#eaebee") : "transparent")
                                    border.color: root.leftSidebarMode === 1 ? root.borderSubtle : "transparent"
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        LobeIcon {
                                            name: "folder"
                                            size: 13
                                            color: root.leftSidebarMode === 1 ? root.lobeAccent : root.textSecondary
                                        }
                                        Text {
                                            text: root.tr("sidebar.folders", "Folders")
                                            color: root.leftSidebarMode === 1 ? root.textPrimary : root.textSecondary
                                            font.family: root.fontMain
                                            font.pixelSize: 12
                                            font.weight: root.leftSidebarMode === 1 ? Font.DemiBold : Font.Normal
                                        }
                                    }

                                    MouseArea {
                                        id: explorerTabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.leftSidebarMode = 1
                                    }
                                }
                            }
                        }

                        // 2. TAGS VIEW (visible when root.leftSidebarMode === 0)
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8
                            visible: root.leftSidebarMode === 0

                            // Category Tabs with Harmonious Accent & Colored Dots
                            GridLayout {
                                columns: 2
                                Layout.fillWidth: true
                                columnSpacing: 4
                                rowSpacing: 4

                                Repeater {
                                    model: [
                                        { id: 4, name: root.tr("sidebar.chars", "Chars"), dot: "#10b981" },
                                        { id: 1, name: root.tr("sidebar.artists", "Artists"), dot: "#f43f5e" },
                                        { id: 0, name: root.tr("sidebar.general", "General"), dot: "#38bdf8" },
                                        { id: 5, name: root.tr("sidebar.styles", "Styles"), dot: "#f59e0b" }
                                    ]
                                    delegate: Rectangle {
                                        id: categoryTab
                                        activeFocusOnTab: true
                                        Accessible.role: Accessible.Button
                                        Accessible.name: modelData.name
                                        function activate() { root.activeTagCategory = modelData.id; tagCloudRepeater.model = gallery.getFilteredTopTags(root.activeTagCategory, root.maxSidebarTags) }
                                        Keys.onSpacePressed: activate()
                                        Keys.onReturnPressed: activate()
                                        Accessible.onPressAction: activate()
                                        Layout.fillWidth: true
                                        height: 30
                                        radius: 5
                                        clip: true
                                        color: root.activeTagCategory === modelData.id ? 
                                            (root.isDarkTheme ? Qt.rgba(root.lobeAccent.r, root.lobeAccent.g, root.lobeAccent.b, 0.22) : Qt.rgba(root.lobeAccent.r, root.lobeAccent.g, root.lobeAccent.b, 0.14)) : 
                                            (catMouse.containsMouse ? (isDarkTheme ? "#262632" : "#eaebee") : bgCard)
                                        border.color: categoryTab.activeFocus || root.activeTagCategory === modelData.id ? root.lobeAccent : borderSubtle
                                        border.width: 1


                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 4
                                            Rectangle {
                                                width: 5; height: 5; radius: 2.5
                                                color: modelData.dot
                                            }
                                            Text {
                                                text: modelData.name
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                color: root.activeTagCategory === modelData.id ? (root.isDarkTheme ? root.getAccentContrastColor(root.lobeAccent) : root.textPrimary) : textSecondary
                                                font.family: fontMain
                                                font.pixelSize: 12
                                                font.weight: root.activeTagCategory === modelData.id ? Font.DemiBold : Font.Normal
                                            }
                                        }

                                        MouseArea {
                                            id: catMouse
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                categoryTab.activate()
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: root.tr("sidebar.frequent_tags", "Frequent tags:")
                                    color: textMuted
                                    font.family: fontMain
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                }
                                Rectangle {
                                    height: 18
                                    width: limitLabel.width + 12
                                    radius: 9
                                    color: root.isDarkTheme ? "#202028" : "#ebebf0"
                                    border.color: root.borderSubtle
                                    clip: true
                                    Text {
                                        id: limitLabel
                                        anchors.centerIn: parent
                                        text: root.tr("sidebar.limit_label", "Top %1").arg(root.maxSidebarTags)
                                        color: root.lobeAccent
                                        font.family: fontMono
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        ToolTip.visible: containsMouse
                                        ToolTip.text: root.tr("sidebar.limit_hint", "Change tag limit: 40 / 80 / 120 / 200")
                                        onClicked: {
                                            if (root.maxSidebarTags <= 40) root.maxSidebarTags = 80
                                            else if (root.maxSidebarTags <= 80) root.maxSidebarTags = 120
                                            else if (root.maxSidebarTags <= 120) root.maxSidebarTags = 200
                                            else root.maxSidebarTags = 40
                                        }
                                    }
                                }
                            }

                            // Categorized Dynamic Tag Cloud (Direct Reactive Connection)
                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentHeight: tagCloudFlow.height + 16
                                clip: true
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                Connections {
                                    target: gallery
                                    function onTagsChanged() {
                                        tagCloudRepeater.model = gallery.getFilteredTopTags(root.activeTagCategory, root.maxSidebarTags)
                                    }
                                }

                                Connections {
                                    target: root
                                    function onMaxSidebarTagsChanged() {
                                        tagCloudRepeater.model = 0
                                        tagCloudRepeater.model = gallery.getFilteredTopTags(root.activeTagCategory, root.maxSidebarTags)
                                    }
                                }

                                Flow {
                                    id: tagCloudFlow
                                    width: parent.width
                                    spacing: 4

                                    Repeater {
                                        id: tagCloudRepeater
                                        model: gallery.getFilteredTopTags(root.activeTagCategory, root.maxSidebarTags)

                                        delegate: LobeTag {
                                            text: (modelData.name || "").replace(/\\([()])/g, "$1")
                                            count: "" + modelData.count
                                            dotColor: modelData.color
                                            onClicked: {
                                                var cleanTag = modelData.name
                                                if (searchInput.text.length > 0 && !searchInput.text.endsWith(" ")) {
                                                    searchInput.text += ", " + cleanTag + ", "
                                                } else {
                                                    searchInput.text += cleanTag + ", "
                                                }
                                                gallery.setSearchQuery(searchInput.text)
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: borderSubtle }

                            // Exclude Tags Box
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    spacing: 4
                                    Rectangle { width: 6; height: 6; radius: 3; color: "#ef4444" }
                                    Text {
                                        text: root.tr("sidebar.exclude_tags", "Exclude Tags")
                                        color: textMuted
                                        font.family: fontMain
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    color: bgInput
                                    border.color: negInput.activeFocus || negInput.text.length > 0 ? root.borderFocus : root.borderSubtle
                                    radius: 5
                                    clip: true

                                    SurfaceSheen {
                                        anchors.fill: parent
                                        cornerRadius: parent.radius || 0
                                        highlightColor: root.borderSpecular
                                    }

                                    TextInput {
                                        id: negInput
                                        objectName: "negativeFilterInput"
                                        clip: true
                                        Accessible.name: root.tr("sidebar.exclude_tags", "Exclude tags")
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        color: textPrimary
                                        font.family: fontMain
                                        font.pixelSize: 12
                                        selectByMouse: true
                                        verticalAlignment: Text.AlignVCenter
                                        property string placeholder: root.tr("sidebar.exclude_placeholder", "e.g. text, watermark...")

                                        Text {
                                            anchors.fill: parent
                                            text: negInput.placeholder
                                            color: textMuted
                                            font.family: fontMain
                                            font.pixelSize: 12
                                            visible: !negInput.text
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Timer {
                                            id: negDebounceTimer
                                            interval: 220
                                            repeat: false
                                            onTriggered: {
                                                gallery.setNegativeFilter(negInput.text)
                                            }
                                        }

                                        onTextChanged: negDebounceTimer.restart()
                                        onAccepted: {
                                            negDebounceTimer.stop()
                                            gallery.setNegativeFilter(text)
                                        }
                                    }
                                }
                            }
                        }

                        // 3. EXPLORER / SUBFOLDERS VIEW (visible when root.leftSidebarMode === 1)
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8
                            visible: root.leftSidebarMode === 1

                            // Subfolder Search Filter Box
                            Rectangle {
                                Layout.fillWidth: true
                                height: 28
                                radius: 6
                                color: root.bgInput
                                border.color: root.borderSubtle
                                clip: true

                                SurfaceSheen {
                                    anchors.fill: parent
                                    cornerRadius: parent.radius || 0
                                    highlightColor: root.borderSpecular
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    Text {
                                        text: "⌕"
                                        color: root.textMuted
                                        font.pixelSize: 12
                                    }

                                    TextInput {
                                        id: folderFilterInput
                                        Layout.fillWidth: true
                                        color: root.textPrimary
                                        font.family: root.fontMain
                                        font.pixelSize: 12
                                        selectByMouse: true
                                        verticalAlignment: Text.AlignVCenter
                                        property string placeholder: "Filter folders..."

                                        Text {
                                            anchors.fill: parent
                                            text: folderFilterInput.placeholder
                                            color: root.textMuted
                                            font.family: root.fontMain
                                            font.pixelSize: 12
                                            visible: !folderFilterInput.text && !folderFilterInput.activeFocus
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }

                                    Rectangle {
                                        width: 14; height: 14; radius: 7
                                        color: isDarkTheme ? "#2c2c36" : "#d8d8de"
                                        visible: folderFilterInput.text.length > 0
                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            color: textPrimary
                                            font.pixelSize: 10
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: folderFilterInput.text = ""
                                        }
                                    }
                                }
                            }

                            // Subfolder List Header
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: (root.tr("sidebar.folders", "Folders")).toUpperCase()
                                    color: textSecondary
                                    font.family: fontMain
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.0
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: (gallery.subfolderList.length > 1 ? (gallery.subfolderList.length - 1) : 0) + " " + root.tr("status.matching", "found")
                                    color: textMuted
                                    font.family: fontMono
                                    font.pixelSize: 10
                                }
                            }

                            // Subfolders ListView
                            ListView {
                                id: folderListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 3
                                model: {
                                    var list = gallery.subfolderDetails
                                    var filter = folderFilterInput.text.toLowerCase().trim()
                                    if (!filter) return list
                                    var filtered = []
                                    for (var i = 0; i < list.length; ++i) {
                                        var item = list[i]
                                        if (item.name.toLowerCase().indexOf(filter) !== -1 ||
                                            item.displayName.toLowerCase().indexOf(filter) !== -1) {
                                            filtered.push(item)
                                        }
                                    }
                                    return filtered
                                }
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                delegate: Rectangle {
                                    id: folderItem
                                    width: folderListView.width
                                    height: 32
                                    radius: 6
                                    clip: true
                                    color: (gallery.selectedSubfolder === modelData.name) ? 
                                        root.lobeAccent : 
                                        (folderMouse.containsMouse ? (root.isDarkTheme ? "#262634" : "#e4e4ed") : "transparent")
                                    border.color: (gallery.selectedSubfolder === modelData.name) ? root.lobeAccent : "transparent"

                                    SurfaceSheen {
                                        anchors.fill: parent
                                        cornerRadius: parent.radius || 0
                                        highlightColor: (gallery.selectedSubfolder === modelData.name) ? root.borderSpecular : "transparent"
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        LobeIcon {
                                            name: modelData.name === "All" ? "folder-open" : "folder"
                                            size: 14
                                            color: (gallery.selectedSubfolder === modelData.name) ? root.getAccentContrastColor(root.lobeAccent) : root.textSecondary
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name === "All" ? root.tr("sidebar.all_folders", "All") : modelData.displayName
                                            color: (gallery.selectedSubfolder === modelData.name) ? root.getAccentContrastColor(root.lobeAccent) : root.textPrimary
                                            font.family: root.fontMain
                                            font.pixelSize: 12
                                            font.weight: (gallery.selectedSubfolder === modelData.name) ? Font.DemiBold : Font.Normal
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            height: 18
                                            width: folderCountText.width + 10
                                            radius: 9
                                            color: (gallery.selectedSubfolder === modelData.name) ? 
                                                Qt.rgba(1, 1, 1, 0.25) : 
                                                (root.isDarkTheme ? "#2c2c36" : "#dedee6")

                                            Text {
                                                id: folderCountText
                                                anchors.centerIn: parent
                                                text: modelData.count
                                                color: (gallery.selectedSubfolder === modelData.name) ? root.getAccentContrastColor(root.lobeAccent) : root.textMuted
                                                font.family: root.fontMono
                                                font.pixelSize: 10
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: folderMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            gallery.selectedSubfolder = modelData.name
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // B. CENTER GALLERY: SEAMLESS MASONRY WALL
                Rectangle {
                    id: viewportArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.enableAurora ? "transparent" : bgApp
                    clip: true

                    Flickable {
                        id: masonryFlickable
                        objectName: "masonryViewport"
                        Accessible.role: Accessible.List
                        Accessible.name: root.tr("ux.library", "Library")
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: gallery.layoutHeight
                        boundsBehavior: Flickable.StopAtBounds
                        pixelAligned: true
                        maximumFlickVelocity: 4500
                        flickDeceleration: 3000

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 6
                            background: Rectangle { color: "transparent" }
                            contentItem: Rectangle {
                                radius: 3
                                color: root.isDarkTheme ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.2)
                            }
                        }

                        onContentYChanged: {
                            if (root.activeHoverData !== null) {
                                root.activeHoverData = null
                                root.activeHoverCard = null
                            }
                            updateViewport()
                        }

                        // Background click to focus gallery and clear multi-selection
                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            onClicked: {
                                root.focusMain()
                                gallery.clearSelection()
                            }
                        }

                        ListModel { id: visibleCardModel }
                        ListModel { id: visibleGroupModel }

                        function syncCards() {
                            var items = gallery.visibleCards
                            var paths = {}
                            for (var i = 0; i < items.length; ++i) paths[items[i].filePath] = true
                            for (var row = visibleCardModel.count - 1; row >= 0; --row) {
                                if (!paths[visibleCardModel.get(row).filePath]) visibleCardModel.remove(row)
                            }
                            var existing = {}
                            for (var row = 0; row < visibleCardModel.count; ++row)
                                existing[visibleCardModel.get(row).filePath] = row
                            for (var i = 0; i < items.length; ++i) {
                                var data = Object.assign({}, items[i])
                                data.url = data.url.toString()
                                if (existing[data.filePath] !== undefined) visibleCardModel.set(existing[data.filePath], data)
                                else visibleCardModel.append(data)
                            }
                            var groups = gallery.visibleGroups
                            var groupIds = {}
                            for (var i = 0; i < groups.length; ++i) groupIds[groups[i].id] = true
                            for (var row = visibleGroupModel.count - 1; row >= 0; --row)
                                if (!groupIds[visibleGroupModel.get(row).id]) visibleGroupModel.remove(row)
                            var groupRows = {}
                            for (var row = 0; row < visibleGroupModel.count; ++row) groupRows[visibleGroupModel.get(row).id] = row
                            for (var i = 0; i < groups.length; ++i) {
                                if (groupRows[groups[i].id] !== undefined) visibleGroupModel.set(groupRows[groups[i].id], groups[i])
                                else visibleGroupModel.append(groups[i])
                            }
                        }

                        function updateViewport() {
                            gallery.setViewport(contentY, height, width, root.columnCount, root.itemSpacing, root.collapsedGroups)
                        }
                        Component.onCompleted: { updateViewport(); syncCards() }
                        onWidthChanged: updateViewport()
                        onHeightChanged: updateViewport()
                        Connections {
                            target: root
                            function onColumnCountChanged() { masonryFlickable.updateViewport() }
                            function onItemSpacingChanged() { masonryFlickable.updateViewport() }
                            function onCollapsedGroupsChanged() { masonryFlickable.updateViewport() }
                        }
                        Connections {
                            target: gallery
                            function onViewportChanged() { masonryFlickable.syncCards(); Qt.callLater(root.revealPendingCard) }
                        }
                        Repeater {
                            model: visibleCardModel
                            GalleryCard {
                                objectName: "virtualGalleryCard"
                                cardData: model
                                x: model.cardX
                                y: model.cardY
                                width: model.cardWidth
                                height: model.cardHeight
                                enabled: !gallery.isFiltering
                            }
                        }
                        Repeater {
                            model: visibleGroupModel
                            Item {
                                id: groupSection
                                objectName: "galleryGroupHeader"
                                property var groupInfo: model
                                property bool isCollapsed: root.isGroupCollapsed(groupInfo.id)
                                z: 20
                                width: masonryFlickable.width
                                height: 38
                                y: groupInfo.headerY
                                enabled: !gallery.isFiltering
                                    // Group Frosted Glass Header Capsule
                                    Rectangle {
                                        width: Math.max(220, groupSection.width - 24)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        height: 38
                                        radius: 8
                                        clip: true
                                        color: root.isDarkTheme ? 
                                            (root.enableGlass ? Qt.rgba(root.darkToneR + 0.05, root.darkToneG + 0.05, root.darkToneB + 0.07, groupSection.isCollapsed ? 0.65 : 0.50) : "#1c1c24") : 
                                            (root.enableGlass ? Qt.rgba(1.0, 1.0, 1.0, groupSection.isCollapsed ? 0.72 : 0.58) : "#f0f0f5")
                                        border.color: root.enableGlass ? (root.isDarkTheme ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)) : root.borderSubtle
                                        border.width: 1

                                        // Specular highlight line
                                        SurfaceSheen {
                                            anchors.fill: parent
                                            cornerRadius: parent.radius || 0
                                            highlightColor: root.borderSpecular
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            // Vector Chevron
                                            LobeIcon {
                                                name: "chevron-down"
                                                size: 13
                                                color: root.lobeAccent
                                                rotation: groupSection.isCollapsed ? -90 : 0
                                                Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                            }

                                            // Vector Group Mode Icon (Box / Folder / Clock)
                                            LobeIcon {
                                                name: gallery.groupMode === 1 ? "folder" : (gallery.groupMode === 2 ? "box" : "clock")
                                                size: 14
                                                color: root.textSecondary
                                            }

                                            // Group Title
                                            Text {
                                                text: gallery.groupMode === 1 && groupInfo.title === "Root" ? root.tr("backend.message_22", "Root folder") : (groupInfo.title || root.tr("toolbar.group", "Group"))
                                                color: root.textPrimary
                                                font.family: root.fontMain
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                            }

                                            // Count badge
                                            Rectangle {
                                                height: 18
                                                width: grpCountTxt.width + 12
                                                radius: 9
                                                color: root.isDarkTheme ? "#282834" : "#dedee6"
                                                Text {
                                                    id: grpCountTxt
                                                    anchors.centerIn: parent
                                                    text: groupInfo.count
                                                    color: root.textMuted
                                                    font.family: root.fontMono
                                                    font.pixelSize: 10
                                                }
                                            }

                                            LobeButton {
                                                objectName: "groupSelectionButton"
                                                size: "small"
                                                readonly property bool isSelected: gallery.selectionEpoch >= 0 && gallery.isGroupSelected(groupInfo.groupIndex)
                                                property string actionTitle: isSelected ? root.tr("ux.deselect_group", "Clear group selection") : root.tr("ux.select_group", "Select group")
                                                text: groupSection.width < 540 ? "" : actionTitle
                                                iconName: isSelected ? "minus" : "check"
                                                type: isSelected ? "primary" : "default"
                                                Accessible.name: actionTitle
                                                ToolTip.visible: hovered
                                                ToolTip.text: actionTitle
                                                onClicked: { root.focusMain(); gallery.toggleGroupSelect(groupInfo.groupIndex) }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            z: -1
                                            onClicked: {
                                                root.focusMain()
                                                root.toggleGroupCollapsed(groupInfo.id || groupInfo.key)
                                            }
                                        }
                                    }

                            }
                        }
                    }

                    ColumnLayout {
                        objectName: "galleryEmptyState"
                        anchors.centerIn: parent
                        width: Math.min(360, parent.width - 48)
                        spacing: 16
                        visible: gallery.filteredCount === 0
                        readonly property bool busy: gallery.isLoading || gallery.isFiltering
                        BusyIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            running: parent.busy; visible: running
                            implicitWidth: 40; implicitHeight: 40
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 64; height: 64; radius: 20
                            color: root.bgCard; border.color: root.borderSubtle
                            visible: !parent.busy
                            LobeIcon {
                                anchors.centerIn: parent; size: 28; color: root.lobeAccent
                                name: gallery.currentFolder === "" ? "folder-open" : (root.hasActiveFilters ? "search" : "image")
                            }
                        }
                        Text {
                            objectName: "emptyStateTitle"
                            Layout.fillWidth: true
                            text: parent.busy ? root.tr("ux.loading", "Preparing your library…") :
                                (gallery.currentFolder === "" ? root.tr("ux.welcome", "Your images, in one place") :
                                (root.hasActiveFilters ? root.tr("ux.no_results", "No matches found") : root.tr("ux.empty_folder", "No images in this folder")))
                            color: root.textPrimary; font.family: root.fontMain
                            font.pixelSize: 20; font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            text: parent.busy ? root.tr("ux.loading_hint", "Images will appear as they are indexed.") :
                                (gallery.currentFolder === "" ? root.tr("ux.welcome_hint", "Open a folder to browse images, prompts and generation settings.") :
                                (root.hasActiveFilters ? root.tr("ux.no_results_hint", "Try fewer tags, or reset the search, exclusions, model and folder filters.") : root.tr("ux.empty_folder_hint", "Choose another folder containing PNG, JPEG, WebP or other supported images.")))
                            color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        }
                        LobeButton {
                            objectName: "emptyStateAction"
                            Layout.alignment: Qt.AlignHCenter
                            type: "primary"; size: "large"
                            visible: !parent.busy
                            iconName: root.hasActiveFilters ? "x" : "folder-open"
                            text: root.hasActiveFilters ? root.tr("ux.reset_filters", "Reset filters") : root.tr("toolbar.open", "Open folder")
                            onClicked: root.hasActiveFilters ? root.resetFilters() : folderDialog.open()
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: !parent.busy && gallery.currentFolder === ""
                            text: "Ctrl+O"; color: root.textMuted; font.family: root.fontMono; font.pixelSize: 12
                        }
                    }

                    // Floating Hold-to-Preview Popup (Over / Above the hovered image)
                    Rectangle {
                        id: hoverPreviewPopup
                        x: root.hoverPopupX
                        y: root.hoverPopupY
                        width: root.hoverPopupW
                        height: root.hoverPopupH
                        radius: 8
                        clip: true
                        z: 280
                        visible: opacity > 0.001
                        opacity: (root.previewDisplayMode === 1 && root.activeHoverData !== null) ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                        // Soft Ambient Elevation Shadow
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: 12
                            color: root.isDarkTheme ? Qt.rgba(0, 0, 0, 0.60) : Qt.rgba(0, 0, 0, 0.20)
                            z: -1
                        }

                        color: root.enableGlass ? 
                            (root.isDarkTheme ? Qt.rgba(0.08, 0.08, 0.12, 0.95) : Qt.rgba(0.98, 0.98, 1.0, 0.96)) : 
                            root.bgCard
                        border.color: root.enableGlass ? 
                            (root.isDarkTheme ? Qt.rgba(1.0, 1.0, 1.0, 0.15) : Qt.rgba(0.0, 0.0, 0.0, 0.10)) : 
                            root.borderSubtle
                        border.width: 1

                        // Specular Highlight Rim
                        SurfaceSheen {
                            anchors.fill: parent
                            cornerRadius: parent.radius || 0
                            highlightColor: root.borderSpecular
                            z: 5
                        }

                        // Checkerboard pattern behind transparent images
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 6
                            color: root.isDarkTheme ? "#0e0e12" : "#f1f1f5"
                            opacity: 0.5
                        }

                        Image {
                            id: hoverPreviewImage
                            anchors.fill: parent
                            anchors.margins: 3
                            anchors.bottomMargin: 28
                            source: root.activeHoverData ? root.activeHoverData.url : ""
                            fillMode: root.previewFitMode === 0 ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                            sourceSize.width: Math.max(360, Math.round(hoverPreviewPopup.width * root.dpr * 1.5))
                            asynchronous: true
                            smooth: true
                            mipmap: false
                            cache: true
                        }

                        // Bottom Metadata Capsule
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 26
                            color: root.isDarkTheme ? Qt.rgba(0.06, 0.06, 0.09, 0.92) : Qt.rgba(1.0, 1.0, 1.0, 0.92)
                            border.color: root.borderSubtle
                            border.width: 1
                            z: 6

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: root.activeHoverData ? (root.activeHoverData.imgWidth + "×" + root.activeHoverData.imgHeight) : ""
                                    color: root.textPrimary
                                    font.family: root.fontMono
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: (root.activeHoverData && root.activeHoverData.modelName) ? root.activeHoverData.modelName : ""
                                    color: root.textSecondary
                                    font.family: root.fontMain
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.tr("gallery.click_to_expand", "Click to expand")
                                    color: root.lobeAccent
                                    font.family: root.fontMain
                                    font.pixelSize: 10
                                }
                            }
                        }

                        MouseArea {
                            id: hoverCardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activeHoverData) {
                                    var data = root.activeHoverData
                                    root.activeHoverData = null
                                    root.activeHoverCard = null
                                    if (data && typeof data.filteredIndex === "number") {
                                        root.activeModalIndex = data.filteredIndex
                                        root.activeModalUrl = data.url || ""
                                        gallery.selectImage(data.filteredIndex)
                                    }
                                }
                            }
                            onExited: {
                                root.activeHoverData = null
                                root.activeHoverCard = null
                            }
                        }
                    }

                    // Floating Multi-Selection Action Bar (Frosted Glass Pill with Elevation)
                    Item {
                        id: floatingBatchBarContainer
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 24
                        height: 44
                        width: Math.min(parent.width - 24, batchBarRow.implicitWidth + 24)
                        z: 300
                        visible: gallery.selectedCount > 1 && !root.settingsModalOpen

                        // Soft Ambient Elevation Shadow
                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 4
                            anchors.bottomMargin: -4
                            radius: 22
                            color: root.isDarkTheme ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.14)
                        }

                        Rectangle {
                            id: floatingBatchBar
                            anchors.fill: parent
                            radius: 22
                            clip: true

                            color: root.enableGlass ? 
                                (root.isDarkTheme ? Qt.rgba(Math.min(1.0, root.darkToneR + 0.05), Math.min(1.0, root.darkToneG + 0.05), Math.min(1.0, root.darkToneB + 0.06), 0.90) : Qt.rgba(1.0, 1.0, 1.0, 0.92)) : 
                                root.bgSurface
                            border.color: root.borderSubtle
                            border.width: 1

                            // Glass Sheen Gradient upper half
                            Rectangle {
                                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                                height: parent.height * 0.5
                                radius: 22
                                clip: true
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: root.isDarkTheme ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.45) }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }

                            RowLayout {
                                id: batchBarRow
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                LobeBadge {
                                    count: gallery.selectedCount
                                }

                                Text {
                                    text: root.tr("status.selected", "selected")
                                    visible: viewportArea.width >= 560
                                    color: root.textPrimary
                                    font.family: root.fontMain
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }

                                Rectangle { width: 1; height: 16; color: root.borderSubtle }

                                LobeButton {
                                    visible: viewportArea.width >= 660
                                    text: root.tr("common.select_all", "Select All")
                                    type: "ghost"
                                    size: "small"
                                    onClicked: gallery.selectAll()
                                }

                                LobeButton {
                                    text: root.tr("common.clear", "Clear")
                                    type: "ghost"
                                    size: "small"
                                    onClicked: gallery.clearMultiSelection()
                                }

                                Rectangle { width: 1; height: 16; color: root.borderSubtle }

                                LobeButton {
                                    visible: viewportArea.width >= 660
                                    text: root.tr("common.reveal", "Reveal")
                                    iconName: "folder-open"
                                    type: "ghost"
                                    size: "small"
                                    onClicked: gallery.revealSelectedInExplorer()
                                }

                                LobeButton {
                                    text: root.tr("ux.move_short", "Move")
                                    iconName: "folder"
                                    type: "default"
                                    size: "small"
                                    onClicked: batchMoveFolderDialog.open()
                                }

                                LobeButton {
                                    text: root.useRecycleBin ? root.tr("ux.recycle_short", "Recycle") : root.tr("common.delete", "Delete")
                                    iconName: "trash"
                                    type: "danger"
                                    size: "small"
                                    onClicked: root.requestBatchDelete()
                                }
                            }
                        }
                    }

                    // Floating "Scroll to Top" Glass Button
                    Rectangle {
                        id: scrollToTopBtn
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 24
                        anchors.bottomMargin: (gallery.selectedCount > 0 && !root.settingsModalOpen) ? 80 : 24
                        width: 40
                        height: 40
                        radius: 20
                        z: 290
                        visible: opacity > 0.01
                        opacity: masonryFlickable.contentY > 1000 ? 1.0 : 0.0
                        Behavior on opacity {
                            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                        }
                        Behavior on anchors.bottomMargin {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        color: root.enableGlass ? 
                            (root.isDarkTheme ? Qt.rgba(0.12, 0.12, 0.17, scrollMouse.containsMouse ? 0.95 : 0.84) : Qt.rgba(1.0, 1.0, 1.0, scrollMouse.containsMouse ? 0.98 : 0.90)) : 
                            (root.isDarkTheme ? (scrollMouse.containsMouse ? "#2a2a35" : "#1c1c22") : (scrollMouse.containsMouse ? "#f4f4f6" : "#ffffff"))
                        border.color: scrollMouse.containsMouse ? root.lobeAccent : (root.isDarkTheme ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12))
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "↑"
                            color: scrollMouse.containsMouse ? root.lobeAccent : root.textPrimary
                            font.family: root.fontMain
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: scrollMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                scrollToTopAnim.restart()
                            }
                        }

                        NumberAnimation {
                            id: scrollToTopAnim
                            target: masonryFlickable
                            property: "contentY"
                            to: 0
                            duration: Math.min(450, Math.max(220, masonryFlickable.contentY / 7))
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // C. RIGHT SIDEBAR: INSPECTOR & FILE ACTIONS (Floating Frosted Glass)
                Rectangle {
                    id: inspectorSidebarRect
                    Layout.preferredWidth: root.showInspector ? root.inspectorWidth : 0
                    Layout.fillHeight: true
                    Layout.topMargin: root.showInspector ? 8 : 0
                    Layout.bottomMargin: root.showInspector ? 8 : 0
                    Layout.rightMargin: root.showInspector ? 8 : 0
                    Layout.leftMargin: root.showInspector ? 4 : 0
                    radius: 14
                    clip: true
                    opacity: root.showInspector ? 1.0 : 0.0
                    visible: root.showInspector && Layout.preferredWidth > 0
                    Behavior on Layout.preferredWidth {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                    }
                    color: root.enableGlass ? "transparent" : root.bgSurface
                    border.color: root.enableGlass ? "transparent" : root.borderSubtle
                    border.width: root.enableGlass ? 0 : 1
                    FrostedPanel {
                        objectName: "inspectorGlass"
                        anchors.fill: parent; radius: parent.radius
                        sourceScene: backdropScene; visible: root.enableGlass; glassEnabled: root.enableGlass
                        dark: root.isDarkTheme; specular: root.enableSpecular
                        tintColor: root.bgApp; accent: root.lobeAccent
                        amount: root.glassBlurAmount; opacityLevel: root.glassOpacity
                        tintStrength: root.glassTintStrength; chroma: root.glassChroma
                        captureLive: root.active && root.visible && !root.settingsModalOpen
                    }

                    Flickable {
                        anchors.fill: parent
                        contentHeight: inspectorLayout.height + 32
                        clip: true
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        ColumnLayout {
                            id: inspectorLayout
                            width: parent.width - 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12

                            Item { height: 2 }

                            // The inspector explains its purpose until an image is selected.
                            InspectorWelcome {
                                visible: gallery.selectedCount <= 1 && gallery.selectedImage.filePath === undefined
                            }

                            // Multi-Selection Summary View
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                visible: gallery.selectedCount > 1

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: (root.tr("status.selected", "Selected")).toUpperCase()
                                        color: textSecondary
                                        font.family: fontMain
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 1.2
                                    }
                                    Item { Layout.fillWidth: true }
                                    LobeButton {
                                        text: root.tr("common.clear", "Clear")
                                        type: "ghost"
                                        size: "small"
                                        onClicked: gallery.clearMultiSelection()
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 84
                                    color: bgCard
                                    radius: 6
                                    border.color: borderSubtle
                                    clip: true

                                    SurfaceSheen {
                                        anchors.fill: parent
                                        cornerRadius: parent.radius || 0
                                        highlightColor: root.borderSpecular
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            text: gallery.selectedCount + " " + root.tr("status.selected", "selected")
                                            color: textPrimary
                                            font.family: fontMain
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Text {
                                            text: root.tr("status.ready", "Ready")
                                            color: textMuted
                                            font.family: fontMain
                                            font.pixelSize: 12
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    LobeButton {
                                        Layout.fillWidth: true
                                        iconName: root.inspectorWidth >= 380 ? "folder-open" : ""
                                        font.pixelSize: 12
                                        text: root.tr("common.reveal", "Reveal")
                                        type: "default"
                                        size: "middle"
                                        onClicked: gallery.revealSelectedInExplorer()
                                    }

                                    LobeButton {
                                        Layout.fillWidth: true
                                        iconName: root.inspectorWidth >= 380 ? "folder" : ""
                                        font.pixelSize: 12
                                        text: root.tr("ux.move_short", "Move")
                                        type: "default"
                                        size: "middle"
                                        onClicked: batchMoveFolderDialog.open()
                                    }

                                    LobeButton {
                                        Layout.fillWidth: true
                                        iconName: root.inspectorWidth >= 380 ? "trash" : ""
                                        font.pixelSize: 12
                                        text: root.useRecycleBin ? root.tr("ux.recycle_short", "Recycle") : root.tr("common.delete", "Delete")
                                        type: "danger"
                                        size: "middle"
                                        onClicked: root.requestBatchDelete()
                                    }
                                }
                            }

                            // Single Selection View
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                visible: gallery.selectedCount <= 1 && gallery.selectedImage.filePath !== undefined

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.tr("inspector.title", "Inspector")
                                        color: root.textPrimary; font.family: root.fontMain
                                        font.pixelSize: 16; font.weight: Font.DemiBold
                                    }
                                    LobeActionIcon {
                                        icon: "maximize"; size: "small"
                                        title: root.tr("ux.open_viewer", "Open viewer (Space)")
                                        onClicked: root.openSelectedImage()
                                    }
                                    LobeActionIcon {
                                        icon: "x"; size: "small"
                                        title: root.tr("common.clear", "Clear selection")
                                        onClicked: gallery.clearSelection()
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    visible: root.previewDisplayMode === 0
                                    Repeater {
                                        model: ["S", "M", "L", root.tr("status.auto", "Auto")]
                                        delegate: LobeButton {
                                            required property int index
                                            required property string modelData
                                            text: modelData; size: "small"
                                            type: root.previewSizePreset === index ? "primary" : "default"
                                            onClicked: root.previewSizePreset = index
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    LobeButton {
                                        size: "small"
                                        text: root.previewFitMode === 0 ? root.tr("common.fit", "Fit") : root.tr("common.fill", "Fill")
                                        onClicked: root.previewFitMode = root.previewFitMode === 0 ? 1 : 0
                                    }
                                }

                                // Interactive Inspector Preview Card with Animated Dynamic Height
                                Rectangle {
                                    id: inspectorPreviewBox
                                    Layout.fillWidth: true

                                    readonly property int computedHeight: {
                                        if (root.previewSizePreset === 0) return 200
                                        if (root.previewSizePreset === 1) return 290
                                        if (root.previewSizePreset === 2) return 390
                                        // Auto Preset (Preset 3): calculate from image aspect ratio
                                        var ar = gallery.selectedImage.aspectRatio
                                        if (ar && ar > 0.05) {
                                            var target = Math.round(width / ar)
                                            return Math.min(480, Math.max(180, target))
                                        }
                                        return root.inspectorPreviewHeight
                                    }

                                    Layout.preferredHeight: (root.previewDisplayMode === 0) ? computedHeight : 0
                                    visible: (root.previewDisplayMode === 0) && (opacity > 0.001)
                                    opacity: (root.previewDisplayMode === 0) ? 1.0 : 0.0
                                    Behavior on Layout.preferredHeight {
                                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                                    }

                                    color: bgCard
                                    radius: 8
                                    clip: true
                                    border.color: borderSubtle
                                    border.width: 1

                                    SurfaceSheen {
                                        anchors.fill: parent
                                        cornerRadius: parent.radius || 0
                                        highlightColor: root.borderSpecular
                                    }

                                    // Checkerboard pattern under transparent images
                                    Rectangle {
                                        anchors.fill: parent
                                        color: root.isDarkTheme ? "#0e0e12" : "#f1f1f5"
                                        opacity: 0.5
                                    }

                                    Image {
                                        id: inspectorPreviewImage
                                        anchors.fill: parent
                                        source: gallery.selectedImage.url || ""
                                        fillMode: root.previewFitMode === 0 ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                                        sourceSize.width: Math.max(360, Math.round(inspectorPreviewBox.width * root.dpr * 1.5))
                                        asynchronous: true
                                        smooth: true
                                        mipmap: false
                                        cache: true
                                    }

                                    // Floating Info Glass Pill (Dimensions & File Size)
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 8
                                        height: 22
                                        width: previewResText.width + 16
                                        radius: 4
                                        clip: true
                                        color: root.isDarkTheme ? Qt.rgba(0.08, 0.08, 0.12, 0.78) : Qt.rgba(1.0, 1.0, 1.0, 0.85)
                                        border.color: root.borderSubtle
                                        border.width: 1
                                        visible: !!gallery.selectedImage.dimensions

                                        SurfaceSheen {
                                            anchors.fill: parent
                                            cornerRadius: parent.radius || 0
                                            highlightColor: root.borderSpecular
                                        }

                                        Text {
                                            id: previewResText
                                            anchors.centerIn: parent
                                            text: (gallery.selectedImage.dimensions || "") + (gallery.selectedImage.fileSize ? (" • " + gallery.selectedImage.fileSize) : "")
                                            color: root.textSecondary
                                            font.family: root.fontMono
                                            font.pixelSize: 10
                                        }
                                    }

                                    // Hover Expand Icon Button Overlay (Bottom-Right)
                                    Rectangle {
                                        id: previewExpandBtn
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 8
                                        width: 24
                                        height: 22
                                        radius: 4
                                        clip: true
                                        color: previewAreaMouse.containsMouse ? (root.isDarkTheme ? Qt.rgba(0.18, 0.18, 0.24, 0.90) : Qt.rgba(1.0, 1.0, 1.0, 0.95)) : (root.isDarkTheme ? Qt.rgba(0.08, 0.08, 0.12, 0.78) : Qt.rgba(1.0, 1.0, 1.0, 0.85))
                                        border.color: root.borderSubtle
                                        border.width: 1

                                        SurfaceSheen {
                                            anchors.fill: parent
                                            cornerRadius: parent.radius || 0
                                            highlightColor: root.borderSpecular
                                        }

                                        LobeIcon {
                                            anchors.centerIn: parent
                                            name: "maximize"
                                            size: 12
                                            color: root.textPrimary
                                        }
                                    }

                                    // Click preview to open Fullscreen Modal
                                    MouseArea {
                                        id: previewAreaMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (gallery.selectedImage && gallery.selectedImage.filteredIndex !== undefined) {
                                                root.activeModalIndex = gallery.selectedImage.filteredIndex
                                                root.activeModalUrl = gallery.selectedImage.url || ""
                                            }
                                        }
                                    }
                                }

                                // File Action Buttons (Lobe UI Standard)
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    LobeButton {
                                        Layout.fillWidth: true
                                        iconName: root.inspectorWidth >= 380 ? "folder-open" : ""
                                        font.pixelSize: 12
                                        text: root.tr("common.reveal", "Reveal")
                                        type: "default"
                                        size: "middle"
                                        onClicked: gallery.revealSelectedInExplorer()
                                    }

                                    LobeButton {
                                        Layout.fillWidth: true
                                        iconName: root.inspectorWidth >= 380 ? "folder" : ""
                                        font.pixelSize: 12
                                        text: root.tr("ux.move_short", "Move")
                                        type: "default"
                                        size: "middle"
                                        onClicked: {
                                            moveFolderDialog.targetFilePath = gallery.selectedImage.filePath
                                            moveFolderDialog.open()
                                        }
                                    }

                                    LobeButton {
                                        Layout.fillWidth: true
                                        iconName: root.inspectorWidth >= 380 ? "trash" : ""
                                        font.pixelSize: 12
                                        text: root.useRecycleBin ? root.tr("ux.recycle_short", "Recycle") : root.tr("common.delete", "Delete")
                                        type: "danger"
                                        size: "middle"
                                        onClicked: root.requestDelete(gallery.selectedImage.filteredIndex)
                                    }
                                }

                                // File Attributes
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        text: gallery.selectedImage.fileName || ""
                                        color: textPrimary
                                        font.family: fontMain
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideMiddle
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: root.tr("inspector.folder", "Folder"); color: textMuted; font.family: fontMain; font.pixelSize: 12 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: gallery.selectedImage.isLibraryRoot ? root.tr("backend.message_22", "Root folder") : (gallery.selectedImage.relativeDir || root.tr("backend.message_22", "Root folder")); color: textSecondary; font.family: fontMain; font.pixelSize: 12; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideMiddle }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: root.tr("inspector.model", "Model"); color: textMuted; font.family: fontMain; font.pixelSize: 12 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: (gallery.selectedImage.modelName && gallery.selectedImage.modelName !== "Unknown") ? gallery.selectedImage.modelName : root.tr("common.unknown", "Unknown"); color: textSecondary; font.family: fontMain; font.pixelSize: 12; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideMiddle }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: root.tr("inspector.dimensions", "Dimensions"); color: textMuted; font.family: fontMain; font.pixelSize: 12 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: gallery.selectedImage.dimensions || "-"; color: textSecondary; font.family: fontMono; font.pixelSize: 12 }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: root.tr("inspector.filesize", "File Size"); color: textMuted; font.family: fontMain; font.pixelSize: 12 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: gallery.selectedImage.fileSize || "-"; color: textSecondary; font.family: fontMono; font.pixelSize: 12 }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: borderSubtle }

                                // Prompt Section with Copy Button
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        LobeIcon { name: "sparkles"; size: 16; color: root.textSecondary }
                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            text: root.tr("inspector.prompt", "Prompt")
                                            color: textSecondary
                                            font.family: fontMain
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            id: promptCopiedFeedback
                                            text: root.tr("common.copied", "Copied!")
                                            color: root.lobeAccent
                                            font.family: fontMain
                                            font.pixelSize: 10
                                            visible: false
                                        }
                                        LobeActionIcon {
                                            objectName: "inspectorCopyPrompt"
                                            icon: promptCopiedFeedback.visible ? "check" : "copy"
                                            size: "small"; type: "default"
                                            title: root.tr("context.copy_prompt", "Copy prompt")
                                            enabled: !!gallery.selectedImage.prompt
                                            onClicked: {
                                                clipboardHelper.copyText(gallery.selectedImage.prompt)
                                                promptCopiedFeedback.visible=true;promptTimer.restart()
                                            }
                                        }
                                        Timer {
                                            id: promptTimer
                                            interval: 1500
                                            onTriggered: promptCopiedFeedback.visible = false
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Math.max(64, Math.min(140, promptBox.contentHeight + 16))
                                        color: bgInput
                                        border.color: borderSubtle
                                        radius: UI.design.metrics.radius
                                        clip: true

                                        SurfaceSheen {
                                            anchors.fill: parent
                                            cornerRadius: parent.radius || 0
                                            highlightColor: root.borderSpecular
                                        }

                                        Flickable {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            contentHeight: promptBox.height
                                            clip: true
                                            TextArea {
                                                id: promptBox
                                                width: parent.width
                                                text: gallery.selectedImage.prompt || root.tr("common.no_prompt", "(No generation prompt)")
                                                color: gallery.selectedImage.prompt ? textPrimary : textMuted
                                                font.family: fontMain
                                                font.pixelSize: 13
                                                wrapMode: Text.Wrap
                                                readOnly: true
                                                background: null
                                                selectByMouse: true
                                            }
                                        }
                                    }
                                }

                                // Negative Prompt
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    visible: !!gallery.selectedImage.negativePrompt

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 8
                                        LobeIcon { name: "circle-minus"; size: 16; color: root.textSecondary }
                                        Text {
                                            Layout.fillWidth: true; elide: Text.ElideRight
                                            text: root.tr("inspector.negative_prompt", "Negative Prompt")
                                            color: textSecondary; font.family: fontMain
                                            font.pixelSize: 13; font.weight: Font.Medium
                                        }
                                        LobeActionIcon {
                                            id: negativeCopy; objectName: "inspectorCopyNegative"
                                            property bool copied: false
                                            icon: copied ? "check" : "copy"; size: "small"; type: "default"
                                            title: root.tr("context.copy_neg_prompt", "Copy negative prompt")
                                            onClicked: {
                                                clipboardHelper.copyText(gallery.selectedImage.negativePrompt || "")
                                                copied=true;negativeCopyTimer.restart()
                                            }
                                        }
                                        Timer { id: negativeCopyTimer; interval: 1500; onTriggered: negativeCopy.copied=false }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Math.max(50, Math.min(100, negBox.contentHeight + 16))
                                        color: bgInput
                                        border.color: borderSubtle
                                        radius: UI.design.metrics.radius
                                        clip: true

                                        SurfaceSheen {
                                            anchors.fill: parent
                                            cornerRadius: parent.radius || 0
                                            highlightColor: root.borderSpecular
                                        }

                                        Flickable {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            contentHeight: negBox.height
                                            clip: true
                                            TextArea {
                                                id: negBox
                                                width: parent.width
                                                text: gallery.selectedImage.negativePrompt || ""
                                                color: textSecondary
                                                font.family: fontMain
                                                font.pixelSize: 13
                                                wrapMode: Text.Wrap
                                                readOnly: true
                                                background: null
                                                selectByMouse: true
                                            }
                                        }
                                    }
                                }

                                // Tags Flow
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: root.tr("inspector.tags", "Tags")
                                            color: textSecondary
                                            font.family: fontMain
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                        }
                                        LobeBadge {
                                            count: gallery.selectedImage.tags ? gallery.selectedImage.tags.length : 0
                                        }
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: gallery.selectedImage.tags || []
                                            delegate: LobeTag {
                                                text: modelData
                                                onClicked: {
                                                    searchInput.text = modelData
                                                    gallery.setSearchQuery(modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }
    }

    // Library details remain available without a permanent footer.
    Popup {
        id: libraryStatusPopup
        objectName: "libraryStatusPopup"
        parent: root.contentItem
        popupType: Popup.Item
        focus: true
        z: 500
        width: 320; padding: 16
        onAboutToShow: {
            var anchor = libraryStatusButton.mapToItem(root.contentItem, 0, libraryStatusButton.height)
            x = Math.max(8, Math.min(root.width - width - 8, anchor.x))
            y = anchor.y + 8
        }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            radius: 12
            color: root.isDarkTheme ?
                Qt.rgba(root.darkToneR + 0.04, root.darkToneG + 0.04, root.darkToneB + 0.06, 0.97) :
                Qt.rgba(root.lightToneR, root.lightToneG, root.lightToneB, 0.97)
            border.color: root.borderSubtle
            SurfaceSheen {
                anchors.fill: parent
                cornerRadius: parent.radius || 0
                highlightColor: root.borderSpecular
            }
        }
        contentItem: ColumnLayout {
            spacing: 12
            Text {
                text: root.tr("ux.library_status", "Library status")
                color: root.textPrimary; font.family: root.fontMain; font.pixelSize: 14; font.weight: Font.DemiBold
            }
            Text {
                objectName: "libraryStatusDetails"
                Layout.fillWidth: true
                text: root.libraryStatusText
                color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 12; wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                text: gallery.filteredCount + " " + root.tr("status.matching", "matching") + " / " + gallery.totalCount + " " + root.tr("status.total", "total")
                color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 12
            }
            Text {
                Layout.fillWidth: true
                visible: gallery.currentFolder !== ""
                text: gallery.currentFolder
                color: root.textMuted; font.family: root.fontMain; font.pixelSize: 12; wrapMode: Text.WrapAnywhere
            }
            LobeButton {
                Layout.fillWidth: true
                visible: gallery.isLoading
                text: root.tr("ux.stop_scan", "Stop scanning"); iconName: "x"
                onClicked: gallery.cancelScan()
            }
            LobeButton {
                objectName: "libraryGridSettings"
                Layout.fillWidth: true
                text: root.columnCount + " " + root.tr("status.columns", "columns") + " · " + root.itemSpacing + " px"
                iconName: "settings"
                ToolTip.visible: hovered
                ToolTip.text: root.tr("settings.tab_grid", "Grid & Layout")
                onClicked: { libraryStatusPopup.close(); root.activeSettingsTab = 1; root.settingsModalOpen = true }
            }
        }
    }

    // ================= 3. CENTERED LOBE-STYLE SETTINGS MODAL =================
    Popup {
        id: modalBackdrop
        objectName: "settingsPopup"
        width: root.width
        height: root.height
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        background: Item {}
        visible: root.settingsModalOpen
        onClosed: root.settingsModalOpen = false
        z: 900

        // Backdrop Hardware Blur on Underlying Gallery
        MultiEffect {
            anchors.fill: parent
            source: root.settingsModalOpen ? mainContent : null
            blurEnabled: root.enableGlass
            blurMax: 40
            blur: root.glassBlurAmount
            saturation: root.isDarkTheme ? -0.10 : 0.08
            visible: root.enableGlass && root.settingsModalOpen && GraphicsInfo.api !== GraphicsInfo.Software
        }

        // Frosted Dimmer Scrim
        Rectangle {
            anchors.fill: parent
            color: root.isDarkTheme ? 
                Qt.rgba(0.02, 0.02, 0.05, 0.78) : 
                Qt.rgba(0.94, 0.94, 0.97, 0.74)

            MouseArea {
                anchors.fill: parent
                onClicked: root.settingsModalOpen = false
            }
        }

        // Centered Floating Settings Card (Responsive & Harmonized Curves)
        Rectangle {
            id: settingsCard
            width: Math.min(parent.width - 60, 800)
            height: Math.min(parent.height - 60, 640)
            anchors.centerIn: parent
            radius: 14
            clip: true // Prevents any inner square borders from poking outside curved corners
            color: root.isDarkTheme ? "#14141a" : "#ffffff"
            border.color: root.borderSubtle
            border.width: 1

            // Specular Top Border with matching radius
            SurfaceSheen {
                anchors.fill: parent
                cornerRadius: parent.radius || 0
                highlightColor: root.borderSpecular
            }

            // Block clicks from passing to scrim
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Header without sharp outer border
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 16

                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: root.tr("settings.title", "Settings")
                                color: root.textPrimary
                                font.family: root.fontMain
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: root.tr("settings.header_desc", "Configure galIMV appearance, colors, glassmorphism, and layout")
                                color: root.textMuted
                                font.family: root.fontMain
                                font.pixelSize: 11
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Close button (X)
                        LobeActionIcon {
                            icon: "x"
                            size: "middle"
                            title: root.tr("common.close", "Close") + " (Esc)"
                            onClicked: root.settingsModalOpen = false
                        }
                    }
                }

                // Clean 1px Header Bottom Separator
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.borderSubtle
                }

                // Body: Tabs on left, Content on right
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Left Tab Sidebar
                    Rectangle {
                        Layout.preferredWidth: 170
                        Layout.fillHeight: true
                        color: root.isDarkTheme ? (root.enableGlass ? Qt.rgba(0.07, 0.07, 0.10, 0.65) : "#131316") : "#f7f7fa"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Repeater {
                                model: [
                                    root.tr("settings.tab_appearance", "Appearance"),
                                    root.tr("settings.tab_grid", "Grid & Layout"),
                                    root.tr("settings.tab_files", "File Operations"),
                                    root.tr("settings.tab_language", "Language"),
                                    root.tr("settings.tab_about", "About")
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: 34
                                    radius: 6
                                    clip: true
                                    color: root.activeSettingsTab === index ? root.lobeAccent : (tabMouse.containsMouse ? (root.isDarkTheme ? "#24242e" : "#ebebef") : "transparent")

                                    SurfaceSheen {
                                        anchors.fill: parent
                                        cornerRadius: parent.radius || 0
                                        highlightColor: root.borderSpecular
                                        visible: root.activeSettingsTab === index
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData
                                        objectName: root.activeSettingsTab === index ? "activeSettingsNavigationLabel" : ""
                                        color: root.activeSettingsTab === index ? root.getAccentContrastColor(root.lobeAccent) : root.textPrimary
                                        font.family: root.fontMain
                                        font.pixelSize: 12
                                        font.weight: root.activeSettingsTab === index ? Font.DemiBold : Font.Normal
                                    }

                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activeSettingsTab = index
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }

                    // Clean 1px Vertical Separator
                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        color: root.borderSubtle
                    }

                    // Right Content Area with ScrollBar
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Flickable {
                            id: settingsFlickable
                            anchors.fill: parent
                            anchors.margins: 20
                            contentHeight: tabContentLayout.height + 40
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                                width: 6
                                background: Rectangle { color: "transparent" }
                                contentItem: Rectangle {
                                    radius: 3
                                    color: root.isDarkTheme ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.25)
                                }
                            }

                            ColumnLayout {
                                id: tabContentLayout
                                width: parent.width - 12
                                spacing: 18

                                // ================= TAB 0: APPEARANCE =================
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 16
                                    visible: root.activeSettingsTab === 0

                                    // Theme Mode
                                    ColumnLayout {
                                        spacing: 8
                                        Text {
                                            text: root.tr("settings.theme_mode", "Theme Mode")
                                            color: root.textPrimary
                                            font.family: root.fontMain
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }

                                        RowLayout {
                                            spacing: 8

                                            Rectangle {
                                                width: 110; height: 34; radius: 6
                                                clip: true
                                                color: root.isDarkTheme ? root.lobeAccent : root.bgCard
                                                border.color: root.isDarkTheme ? root.lobeAccent : root.borderSubtle
                                                SurfaceSheen {
                                                    anchors.fill: parent
                                                    cornerRadius: parent.radius || 0
                                                    highlightColor: root.borderSpecular
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.tr("settings.dark", "Dark Theme")
                                                    color: root.isDarkTheme ? root.getAccentContrastColor(root.lobeAccent) : root.textPrimary
                                                    font.family: fontMain
                                                    font.pixelSize: 12
                                                    font.weight: root.isDarkTheme ? Font.DemiBold : Font.Normal
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.isDarkTheme = true
                                                }
                                            }

                                            Rectangle {
                                                width: 110; height: 34; radius: 6
                                                clip: true
                                                color: !root.isDarkTheme ? root.lobeAccent : root.bgCard
                                                border.color: !root.isDarkTheme ? root.lobeAccent : root.borderSubtle
                                                SurfaceSheen {
                                                    anchors.fill: parent
                                                    cornerRadius: parent.radius || 0
                                                    highlightColor: root.borderSpecular
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.tr("settings.light", "Light Theme")
                                                    color: !root.isDarkTheme ? root.getAccentContrastColor(root.lobeAccent) : root.textPrimary
                                                    font.family: fontMain
                                                    font.pixelSize: 12
                                                    font.weight: !root.isDarkTheme ? Font.DemiBold : Font.Normal
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.isDarkTheme = false
                                                }
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.borderSubtle }

                                    // ALL LOBE THEME NEO ACCENT COLORS (19 hues)
                                    ColumnLayout {
                                        spacing: 8
                                        Text {
                                            text: root.tr("settings.accent_color_title", "Accent Color (Lobe Theme Neo)")
                                            color: root.textPrimary
                                            font.family: root.fontMain
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }

                                        Repeater {
                                            model: [
                                                { title: "Lobe — 12", colors: root.lobeColors }
                                            ]
                                            delegate: ColumnLayout {
                                                id: accentGroup
                                                required property var modelData
                                                Layout.fillWidth: true; spacing: 8
                                                Text { text: accentGroup.modelData.title; color: root.textSecondary; font.pixelSize: 12 }
                                                Flow {
                                                    Layout.fillWidth: true; spacing: 8
                                                    Repeater {
                                                        model: accentGroup.modelData.colors
                                                        delegate: Rectangle {
                                                            id: swatch
                                                            required property var modelData
                                                            width: 36; height: 36; radius: 10
                                                            color: root.accentColorFor(modelData)
                                                            border.width: activeFocus || root.lobeAccentName===modelData.name ? 2 : 1
                                                            border.color: activeFocus || root.lobeAccentName===modelData.name ? root.textPrimary : root.borderSubtle
                                                            activeFocusOnTab: true
                                                            Accessible.role: Accessible.Button
                                                            Accessible.name: modelData.name
                                                            Accessible.onPressAction: root.chooseAccent(modelData.name)
                                                            Keys.onSpacePressed: root.chooseAccent(modelData.name)
                                                            Keys.onReturnPressed: root.chooseAccent(modelData.name)
                                                            Rectangle {
                                                                anchors.centerIn: parent; width: 8; height: 8; radius: 4
                                                                color: root.getAccentContrastColor(parent.color)
                                                                visible: root.lobeAccentName===swatch.modelData.name
                                                            }
                                                            MouseArea { id: swatchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.chooseAccent(swatch.modelData.name) }
                                                            ToolTip.visible: swatchMouse.containsMouse || activeFocus
                                                            ToolTip.text: modelData.name; ToolTip.delay: 400
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: root.tr("settings.selected_accent", "Selected Accent:") + " " + root.lobeAccentName + " (" + root.lobeAccent + ")"
                                            color: root.textMuted
                                            font.family: root.fontMono
                                            font.pixelSize: 11
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.borderSubtle }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Text {
                                            text: root.tr("settings.background_palette", "Background undertone")
                                            color: root.textPrimary; font.family: root.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold
                                        }
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Repeater {
                                                model: root.backgroundTones
                                                delegate: Rectangle {
                                                    id: toneSwatch
                                                    required property var modelData
                                                    readonly property string toneTitle: root.toneTitle(modelData,root.isDarkTheme)
                                                    width: 170; height: 38; radius: 8
                                                    color: root.toneColorFor(modelData.id,root.isDarkTheme,root.isDarkTheme?.08:.04)
                                                    border.width: activeFocus || root.backgroundToneName===modelData.id ? 2 : 1
                                                    border.color: activeFocus || root.backgroundToneName===modelData.id ? root.textPrimary : root.borderSubtle
                                                    activeFocusOnTab: true
                                                    Accessible.role: Accessible.Button
                                                    Accessible.name: toneTitle
                                                    Accessible.onPressAction: root.backgroundToneName=modelData.id
                                                    Keys.onSpacePressed: root.backgroundToneName=modelData.id
                                                    Keys.onReturnPressed: root.backgroundToneName=modelData.id
                                                    Text {
                                                        anchors.left: parent.left; anchors.leftMargin: 12; anchors.right: parent.right; anchors.rightMargin: 34; anchors.verticalCenter: parent.verticalCenter
                                                        elide: Text.ElideRight
                                                        text: toneSwatch.toneTitle
                                                        color: root.getAccentContrastColor(toneSwatch.color)
                                                        font.family: root.fontMain; font.pixelSize: 12; font.weight: Font.Medium
                                                    }
                                                    Image {
                                                        anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter
                                                        width: 16; height: 16
                                                        visible: root.backgroundToneName===toneSwatch.modelData.id
                                                        source: root.sharedIconSource("check",root.getAccentContrastColor(toneSwatch.color))
                                                        sourceSize: Qt.size(16*root.dpr,16*root.dpr)
                                                    }
                                                    MouseArea {
                                                        id: toneMouse; anchors.fill: parent; hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.backgroundToneName=toneSwatch.modelData.id
                                                    }
                                                    ToolTip.visible: toneMouse.containsMouse || activeFocus
                                                    ToolTip.text: toneTitle; ToolTip.delay: 350
                                                }
                                            }
                                        }
                                        Text {
                                            text: root.tr("settings.selected_undertone","Selected undertone:")+" "+root.toneTitle(root.toneDefinition(root.backgroundToneName)||root.backgroundTones[0],root.isDarkTheme)
                                            color: root.textMuted; font.family: root.fontMain; font.pixelSize: 11
                                        }
                                        Text {
                                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                                            text: root.tr("settings.paired_undertone","A coordinated material pair connects the dark and light themes.")
                                            color: root.textMuted; font.family: root.fontMain; font.pixelSize: 11
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: root.isDarkTheme?root.tr("settings.background_brightness","Background brightness"):root.tr("settings.background_softness","Background softness")
                                                color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: root.backgroundToneName==="pure"?(root.isDarkTheme?"#000000":"#ffffff"):Math.round((root.isDarkTheme?root.bgDarkness:root.lightBrightness)*100)+"%"
                                                color: root.textMuted; font.family: root.fontMono; font.pixelSize: 11
                                            }
                                        }
                                        LobeSlider {
                                            Layout.fillWidth: true
                                            enabled: root.backgroundToneName!=="pure"
                                            visible: root.isDarkTheme
                                            from: 0; to: .38; stepSize: .01; value: root.bgDarkness
                                            onMoved: root.bgDarkness=value
                                        }
                                        LobeSlider {
                                            Layout.fillWidth: true
                                            enabled: root.backgroundToneName!=="pure"
                                            visible: !root.isDarkTheme
                                            from: 0; to: .32; stepSize: .01; value: root.lightBrightness
                                            onMoved: root.lightBrightness=value
                                        }
                                    }
                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.borderSubtle }

                                    // GLASSMORHISM ADVANCED CONTROLS
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Text {
                                            text: root.tr("settings.glass_atmosphere_title", "Glassmorphism & Atmospheric Effects")
                                            color: root.textPrimary
                                            font.family: root.fontMain
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }

                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 16
                                            LobeSwitch {
                                                text: root.tr("settings.glass_enable", "Enable Frosted Glass & Translucency")
                                                checked: root.enableGlass
                                                onCheckedChanged: root.enableGlass = checked
                                            }

                                            LobeSwitch {
                                                text: root.tr("settings.specular_enable", "Specular Edge Highlights")
                                                checked: root.enableSpecular
                                                onCheckedChanged: root.enableSpecular = checked
                                            }

                                            LobeSwitch {
                                                text: root.tr("settings.aurora_enable", "Aurora Borealis Glow")
                                                checked: root.enableAurora
                                                onCheckedChanged: root.enableAurora = checked
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            visible: root.enableAurora
                                            spacing: 8
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: root.tr("ux.aurora_intensity", "Aurora intensity"); color: root.textPrimary; font.family: root.fontMain; font.pixelSize: 12; Layout.fillWidth: true }
                                                Text { text: Math.round(root.auroraIntensity * 100) + "%"; color: root.textMuted; font.family: root.fontMono; font.pixelSize: 11 }
                                            }
                                            LobeSlider {
                                                Layout.fillWidth: true
                                                from: 0; to: 1; stepSize: 0.01; value: root.auroraIntensity
                                                Accessible.name: root.tr("ux.aurora_intensity", "Aurora intensity")
                                                onMoved: root.auroraIntensity = value
                                            }
                                            LobeSwitch {
                                                text: root.tr("ux.aurora_motion", "Slow aurora movement")
                                                checked: root.auroraAnimated
                                                onCheckedChanged: root.auroraAnimated = checked
                                            }
                                        }

                                        ColumnLayout {
                                            visible: root.enableGlass
                                            Layout.fillWidth: true
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: root.tr("settings.glass_opacity_title", "Surface Glass Translucency (Opacity)")
                                                    color: root.textPrimary
                                                    font.family: root.fontMain
                                                    font.pixelSize: 11
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: Math.round(root.glassOpacity * 100) + "%"
                                                    color: root.textMuted
                                                    font.family: root.fontMono
                                                    font.pixelSize: 11
                                                }
                                            }

                                            LobeSlider {
                                                from: 0.35
                                                to: 0.98
                                                stepSize: 0.02
                                                value: root.glassOpacity
                                                Layout.fillWidth: true
                                                onValueChanged: root.glassOpacity = value
                                            }
                                        }

                                        ColumnLayout {
                                            visible: root.enableGlass
                                            Layout.fillWidth: true
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: root.tr("settings.glass_blur_title", "Backdrop Blur Intensity")
                                                    color: root.textPrimary
                                                    font.family: root.fontMain
                                                    font.pixelSize: 11
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: Math.round(root.glassBlurAmount * 100) + "%"
                                                    color: root.textMuted
                                                    font.family: root.fontMono
                                                    font.pixelSize: 11
                                                }
                                            }

                                            LobeSlider {
                                                from: 0.10
                                                to: 1.0
                                                stepSize: 0.05
                                                value: root.glassBlurAmount
                                                Layout.fillWidth: true
                                                onValueChanged: root.glassBlurAmount = value
                                            }
                                        }
                                    }
                                }

                                // ================= TAB 1: GRID & LAYOUT =================
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 16
                                    visible: root.activeSettingsTab === 1

                                    Text {
                                        text: root.tr("settings.masonry_title", "Masonry Wall & Columns")
                                        color: root.textPrimary
                                        font.family: root.fontMain
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }

                                    LobeSwitch {
                                        text: root.tr("settings.auto_columns", "Auto Columns (Adaptive to window width)")
                                        checked: root.autoColumns
                                        onCheckedChanged: root.autoColumns = checked
                                    }

                                    ColumnLayout {
                                        visible: !root.autoColumns
                                        Layout.fillWidth: true
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: root.tr("settings.manual_columns", "Manual Columns"); color: root.textPrimary; font.family: root.fontMain; font.pixelSize: 11 }
                                            Item { Layout.fillWidth: true }
                                            Text { text: root.manualColumns + " " + root.tr("settings.columns_unit", "columns"); color: root.textMuted; font.family: root.fontMono; font.pixelSize: 11 }
                                        }

                                        LobeSlider {
                                            from: 1
                                            to: 10
                                            stepSize: 1
                                            value: root.manualColumns
                                            Layout.fillWidth: true
                                            onValueChanged: root.manualColumns = Math.round(value)
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.borderSubtle }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: root.tr("settings.card_gap", "Card Gap / Margin"); color: root.textPrimary; font.family: root.fontMain; font.pixelSize: 11 }
                                            Item { Layout.fillWidth: true }
                                            Text { text: root.itemSpacing + " px"; color: root.textMuted; font.family: root.fontMono; font.pixelSize: 11 }
                                        }

                                        LobeSlider {
                                            from: 0
                                            to: 16
                                            stepSize: 1
                                            value: root.itemSpacing
                                            Layout.fillWidth: true
                                            onValueChanged: root.itemSpacing = Math.round(value)
                                        }

                                        LobeButton {
                                            text: root.tr("settings.seamless_wall", "Set 0px Seamless Wall")
                                            type: root.itemSpacing === 0 ? "primary" : "default"
                                            size: "small"
                                            onClicked: root.itemSpacing = 0
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.borderSubtle }

                                    // Inspector & Hover Preview Settings
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Text {
                                            text: root.tr("settings.preview_mode", "Preview Mode")
                                            color: root.textPrimary
                                            font.family: root.fontMain
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }

                                        // Mode Selector: Right Inspector vs Floating Hover Popup vs Disabled
                                        RowLayout {
                                            spacing: 8

                                            Repeater {
                                                model: [
                                                    { name: root.tr("settings.preview_right", "Right Inspector"), mode: 0 },
                                                    { name: root.tr("settings.preview_hover", "Hover Popup (Hold)"), mode: 1 },
                                                    { name: root.tr("settings.preview_disabled", "Disabled"), mode: 2 }
                                                ]
                                                delegate: Rectangle {
                                                    height: 28
                                                    width: modeLabel.width + 20
                                                    radius: 6
                                                    clip: true
                                                    color: root.previewDisplayMode === modelData.mode ? root.lobeAccent : root.bgCard
                                                    border.color: root.previewDisplayMode === modelData.mode ? root.lobeAccent : root.borderSubtle
                                                    border.width: 1
                                                    SurfaceSheen {
                                                        anchors.fill: parent
                                                        cornerRadius: parent.radius || 0
                                                        highlightColor: root.borderSpecular
                                                    }
                                                    Text {
                                                         id: modeLabel
                                                         anchors.centerIn: parent
                                                         text: modelData.name
                                                         color: root.previewDisplayMode === modelData.mode ? root.getAccentContrastColor(root.lobeAccent) : root.textPrimary
                                                         font.family: root.fontMain
                                                         font.pixelSize: 11
                                                         font.weight: root.previewDisplayMode === modelData.mode ? Font.DemiBold : Font.Normal
                                                    }
                                                    MouseArea {
                                                         anchors.fill: parent
                                                         cursorShape: Qt.PointingHandCursor
                                                         onClicked: root.previewDisplayMode = modelData.mode
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: root.tr("settings.preview_desc", "Inspector Preview and Hover Popup are mutually exclusive. Hover popup appears after holding the mouse cursor on an image for ~380ms.")
                                            color: root.textMuted
                                            font.family: root.fontMain
                                            font.pixelSize: 11
                                        }

                                        // Size Presets Row
                                        RowLayout {
                                            spacing: 8
                                            Text { text: root.tr("settings.preview_size", "Preview Size:"); color: root.textMuted; font.family: root.fontMain; font.pixelSize: 11 }

                                            Repeater {
                                                model: [
                                                    { name: root.tr("settings.size_small", "Small (200px)"), preset: 0 },
                                                    { name: root.tr("settings.size_medium", "Medium (290px)"), preset: 1 },
                                                    { name: root.tr("settings.size_large", "Large (390px)"), preset: 2 },
                                                    { name: root.tr("settings.size_auto", "Auto (Aspect Ratio)"), preset: 3 }
                                                ]
                                                delegate: Rectangle {
                                                    height: 26
                                                    width: presetLabel.width + 16
                                                    radius: 5
                                                    clip: true
                                                    color: root.previewSizePreset === modelData.preset ? root.lobeAccent : root.bgCard
                                                    border.color: root.previewSizePreset === modelData.preset ? root.lobeAccent : root.borderSubtle
                                                    SurfaceSheen {
                                                        anchors.fill: parent
                                                        cornerRadius: parent.radius || 0
                                                        highlightColor: root.borderSpecular
                                                    }
                                                    Text {
                                                        id: presetLabel
                                                        anchors.centerIn: parent
                                                        text: modelData.name
                                                        color: root.previewSizePreset === modelData.preset ? root.getAccentContrastColor(root.lobeAccent) : root.textPrimary
                                                        font.family: root.fontMain
                                                        font.pixelSize: 11
                                                        font.weight: root.previewSizePreset === modelData.preset ? Font.DemiBold : Font.Normal
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.previewSizePreset = modelData.preset
                                                    }
                                                }
                                            }
                                        }

                                        // Custom Height Slider (Active when not Auto)
                                        ColumnLayout {
                                            visible: root.previewSizePreset !== 3
                                            Layout.fillWidth: true
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: root.tr("settings.manual_preview_height", "Manual Preview Height"); color: root.textPrimary; font.family: root.fontMain; font.pixelSize: 11 }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: root.inspectorPreviewHeight + " px"
                                                    color: root.textMuted
                                                    font.family: root.fontMono
                                                    font.pixelSize: 11
                                                }
                                            }

                                            LobeSlider {
                                                from: 180
                                                to: 480
                                                stepSize: 10
                                                value: root.inspectorPreviewHeight
                                                Layout.fillWidth: true
                                                onValueChanged: {
                                                    root.inspectorPreviewHeight = Math.round(value)
                                                }
                                            }
                                        }

                                        // Fit Mode Switch
                                        RowLayout {
                                            spacing: 8
                                            Text { text: root.tr("settings.image_display_mode", "Image Display Mode:"); color: root.textMuted; font.family: root.fontMain; font.pixelSize: 11 }

                                            Rectangle {
                                                height: 26
                                                width: Math.max(130, fitPreserveText.implicitWidth + 24)
                                                radius: 5
                                                clip: true
                                                color: root.previewFitMode === 0 ? root.lobeAccent : root.bgCard
                                                border.color: root.previewFitMode === 0 ? root.lobeAccent : root.borderSubtle
                                                SurfaceSheen {
                                                    anchors.fill: parent
                                                    cornerRadius: parent.radius || 0
                                                    highlightColor: root.borderSpecular
                                                }
                                                Text {
                                                    id: fitPreserveText
                                                    anchors.centerIn: parent
                                                    text: root.tr("settings.fit_preserve", "Aspect Fit (Preserve)")
                                                    color: root.previewFitMode === 0 ? root.getAccentContrastColor(root.lobeAccent) : root.textPrimary
                                                    font.family: root.fontMain
                                                    font.pixelSize: 11
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.previewFitMode = 0
                                                }
                                            }

                                            Rectangle {
                                                height: 26
                                                width: Math.max(130, fillCropText.implicitWidth + 24)
                                                radius: 5
                                                clip: true
                                                color: root.previewFitMode === 1 ? root.lobeAccent : root.bgCard
                                                border.color: root.previewFitMode === 1 ? root.lobeAccent : root.borderSubtle
                                                SurfaceSheen {
                                                    anchors.fill: parent
                                                    cornerRadius: parent.radius || 0
                                                    highlightColor: root.borderSpecular
                                                }
                                                Text {
                                                    id: fillCropText
                                                    anchors.centerIn: parent
                                                    text: root.tr("settings.fill_crop", "Aspect Fill (Crop)")
                                                    color: root.previewFitMode === 1 ? root.getAccentContrastColor(root.lobeAccent) : root.textPrimary
                                                    font.family: root.fontMain
                                                    font.pixelSize: 11
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.previewFitMode = 1
                                                }
                                            }
                                        }

                                    }
                                }

                                // ================= TAB 2: FILE OPERATIONS & TAGS =================
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 16
                                    visible: root.activeSettingsTab === 2

                                    Text {
                                        text: root.tr("settings.file_prefs", "File Management Preferences")
                                        color: root.textPrimary
                                        font.family: root.fontMain
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }

                                    LobeSwitch {
                                        text: root.tr("settings.recycle_bin", "Use Recycle Bin (safe delete, undoable in Windows Trash)")
                                        checked: root.useRecycleBin
                                        onCheckedChanged: root.useRecycleBin = checked
                                    }

                                    LobeSwitch {
                                        text: root.tr("settings.confirm_delete", "Confirm before deleting images")
                                        checked: root.confirmDelete
                                        onCheckedChanged: root.confirmDelete = checked
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.borderSubtle }

                                    // Left Sidebar Tag Cloud Limit
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: root.tr("settings.tag_limit_title", "Sidebar Tag Cloud Limit")
                                            color: root.textPrimary
                                            font.family: root.fontMain
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: root.tr("settings.max_tags_sidebar", "Max Tags Displayed in Sidebar")
                                                color: root.textMuted
                                                font.family: root.fontMain
                                                font.pixelSize: 11
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: root.maxSidebarTags + " " + root.tr("inspector.tags", "tags")
                                                color: root.lobeAccent
                                                font.family: root.fontMono
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                            }
                                        }

                                        LobeSlider {
                                            from: 20
                                            to: 200
                                            stepSize: 5
                                            value: root.maxSidebarTags
                                            Layout.fillWidth: true
                                            onValueChanged: root.maxSidebarTags = Math.round(value)
                                        }

                                        Text {
                                            text: root.tr("settings.tag_limit_desc", "Default: 80 tags. Sets how many frequent tags are shown in the left sidebar (range: 20 to 200).")
                                            color: root.textMuted
                                            font.family: root.fontMain
                                            font.pixelSize: 10
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.borderSubtle }

                                    // Active Library Path & Persistence
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: root.tr("settings.active_library_path", "Active Library Path (Auto-saved & Restored at Startup):")
                                            color: root.textMuted
                                            font.family: root.fontMain
                                            font.pixelSize: 11
                                        }

                                        Text {
                                            text: gallery.currentFolder || root.tr("settings.no_folder_opened", "(No folder opened)")
                                            color: root.textPrimary
                                            font.family: root.fontMono
                                            font.pixelSize: 11
                                            wrapMode: Text.WrapAnywhere
                                            Layout.fillWidth: true
                                        }

                                        LobeButton {
                                            text: root.tr("settings.change_library_folder", "Change Library Folder...")
                                            type: "default"
                                            size: "small"
                                            onClicked: folderDialog.open()
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.borderSubtle }

                                    // Forge-Neo Danbooru CSV Tag Database
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: root.tr("settings.danbooru_dict_title", "Danbooru & TagComplete Dictionary (Forge-Neo)")
                                            color: root.textPrimary
                                            font.family: root.fontMain
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }

                                        RowLayout {
                                            spacing: 6
                                            Rectangle {
                                                width: 8; height: 8; radius: 4
                                                color: tagAuto.isCsvLoaded ? "#10b981" : "#f59e0b"
                                            }
                                            Text {
                                                text: tagAuto.isCsvLoaded ? 
                                                    root.tr("settings.danbooru_active", "Danbooru dictionary active: %1 tags indexed").replace("%1", tagAuto.totalLoadedTags) : 
                                                    root.tr("settings.danbooru_inactive", "Default built-in heuristics active (no CSV loaded)")
                                                color: root.textPrimary
                                                font.family: root.fontMain
                                                font.pixelSize: 11
                                            }
                                        }

                                        Text {
                                            text: tagAuto.csvPath || "(Auto-detect path)"
                                            color: root.textMuted
                                            font.family: root.fontMono
                                            font.pixelSize: 10
                                            wrapMode: Text.WrapAnywhere
                                            Layout.fillWidth: true
                                        }

                                        RowLayout {
                                            spacing: 8

                                            LobeButton {
                                                text: root.tr("settings.select_csv", "Select Booru CSV...")
                                                type: "primary"
                                                size: "small"
                                                onClicked: csvFileDialog.open()
                                            }

                                            LobeButton {
                                                text: root.tr("settings.autodetect_csv", "Auto-Detect Forge-Neo CSV")
                                                type: "default"
                                                size: "small"
                                                onClicked: tagAuto.autoLoadCsvAsync()
                                            }
                                        }

                                        Text {
                                            text: root.tr("settings.csv_desc", "Tags from CSV classify Characters, Artists, Series, and Meta styles in the left sidebar.")
                                            color: root.textMuted
                                            font.family: root.fontMain
                                            font.pixelSize: 10
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                // ================= TAB 3: LANGUAGE =================
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 16
                                    visible: root.activeSettingsTab === 3

                                    ColumnLayout {
                                        spacing: 4
                                        Text {
                                            text: root.tr("settings.language_label", "Interface Language")
                                            color: root.textPrimary
                                            font.family: root.fontMain
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            text: root.tr("settings.language_desc", "Select language across the application (20 popular languages)")
                                            color: root.textMuted
                                            font.family: root.fontMain
                                            font.pixelSize: 11
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.borderSubtle }

                                    GridLayout {
                                        columns: 2
                                        columnSpacing: 10
                                        rowSpacing: 10
                                        Layout.fillWidth: true

                                        Repeater {
                                            model: gallery.availableLanguages
                                            delegate: Rectangle {
                                                id: langCard
                                                Layout.fillWidth: true
                                                height: 50
                                                radius: 8
                                                clip: true
                                                property bool isSelected: gallery.currentLanguage === modelData.code
                                                color: isSelected ? 
                                                    (root.isDarkTheme ? Qt.rgba(root.lobeAccent.r, root.lobeAccent.g, root.lobeAccent.b, 0.22) : Qt.rgba(root.lobeAccent.r, root.lobeAccent.g, root.lobeAccent.b, 0.12)) : 
                                                    (langCardMouse.containsMouse ? (root.isDarkTheme ? "#23232b" : "#f1f1f5") : root.bgCard)
                                                border.color: isSelected ? root.lobeAccent : (langCardMouse.containsMouse ? root.borderSpecular : root.borderSubtle)
                                                border.width: isSelected ? 1.5 : 1

                                                SurfaceSheen {
                                                    anchors.fill: parent
                                                    cornerRadius: parent.radius || 0
                                                    highlightColor: root.borderSpecular
                                                    visible: !isSelected
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 10
                                                    spacing: 10

                                                    // Radio circle indicator
                                                    Rectangle {
                                                        width: 16; height: 16; radius: 8
                                                        color: "transparent"
                                                        border.color: langCard.isSelected ? root.lobeAccent : root.textMuted
                                                        border.width: 1.5

                                                        Rectangle {
                                                            anchors.centerIn: parent
                                                            width: 8; height: 8; radius: 4
                                                            color: root.lobeAccent
                                                            visible: langCard.isSelected
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 2

                                                        RowLayout {
                                                            spacing: 6
                                                            Text {
                                                                text: modelData.nativeName
                                                                color: langCard.isSelected ? (root.isDarkTheme ? "#ffffff" : root.lobeAccent) : root.textPrimary
                                                                font.family: root.fontMain
                                                                font.pixelSize: 12
                                                                font.weight: langCard.isSelected ? Font.DemiBold : Font.Normal
                                                            }
                                                            Text {
                                                                text: modelData.name !== modelData.nativeName ? ("(" + modelData.name + ")") : ""
                                                                color: root.textMuted
                                                                font.family: root.fontMain
                                                                font.pixelSize: 10
                                                                visible: modelData.name !== modelData.nativeName
                                                            }
                                                        }

                                                        Text {
                                                            text: modelData.region + " • " + modelData.code
                                                            color: root.textSecondary
                                                            font.family: root.fontMono
                                                            font.pixelSize: 9
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: langCardMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: gallery.setLanguage(modelData.code)
                                                }
                                            }
                                        }
                                    }
                                }

                                // ================= TAB 4: ABOUT =================
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 14
                                    visible: root.activeSettingsTab === 4

                                    RowLayout {
                                        spacing: 10
                                        Rectangle {
                                            width: 14; height: 14; radius: 7
                                            color: root.lobeAccent
                                        }
                                        Text {
                                            text: "galIMV"
                                            color: root.textPrimary
                                            font.family: root.fontMain
                                            font.pixelSize: 18
                                            font.weight: Font.Bold
                                        }
                                        Rectangle {
                                            height: 20
                                            width: vText.width + 12
                                            radius: 4
                                            color: Qt.rgba(root.lobeAccent.r, root.lobeAccent.g, root.lobeAccent.b, 0.15)
                                            border.color: root.lobeAccent
                                            border.width: 1
                                            Text {
                                                id: vText
                                                anchors.centerIn: parent
                                                text: "v1.2.0"
                                                color: root.lobeAccent
                                                font.family: root.fontMono
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                            }
                                        }
                                    }

                                    Text {
                                        text: root.tr("settings.about_subtitle", "Local image viewer and Stable Diffusion generation metadata studio.")
                                        color: root.textPrimary
                                        font.family: root.fontMain
                                        font.pixelSize: 12
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.borderSubtle }

                                    Text {
                                        text: root.tr("settings.about_tech_specs", "TECHNICAL SPECIFICATIONS")
                                        color: root.textSecondary
                                        font.family: root.fontMain
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 1.0
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 5
                                        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.tech_core", "• Core: C++20, Qt 6.8 (64-bit MinGW)"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.tech_parser", "• Metadata: PNG text chunks, ComfyUI graphs and companion .txt files"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.tech_formats", "• Generation data: Automatic1111 parameters, ComfyUI graphs, NovelAI JSON"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.tech_cache", "• Indexing: Local on-disk binary metadata cache for instant startup"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.tech_autocomplete", "• Autocomplete: Danbooru CSV prefix & substring matching (15 suggestions)"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.tech_grouping", "• Grouping: Folder, Checkpoint / Model, Creation Date"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.borderSubtle }

                                    Text {
                                        text: root.tr("settings.about_shortcuts", "KEYBOARD SHORTCUTS")
                                        color: root.textSecondary
                                        font.family: root.fontMain
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 1.0
                                    }

                                    GridLayout {
                                        columns: 2
                                        columnSpacing: 24
                                        rowSpacing: 6
                                        Layout.fillWidth: true

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Rectangle { width: 70; height: 20; radius: 4; color: root.bgCard; border.color: root.borderSubtle; border.width: 1; Text { anchors.centerIn: parent; text: "Space / F"; color: root.textPrimary; font.family: root.fontMono; font.pixelSize: 10 } }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.sc_fullscreen", "Fullscreen preview"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Rectangle { width: 70; height: 20; radius: 4; color: root.bgCard; border.color: root.borderSubtle; border.width: 1; Text { anchors.centerIn: parent; text: "Esc"; color: root.textPrimary; font.family: root.fontMono; font.pixelSize: 10 } }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.sc_close", "Close / Deselect / Clear"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Rectangle { width: 70; height: 20; radius: 4; color: root.bgCard; border.color: root.borderSubtle; border.width: 1; Text { anchors.centerIn: parent; text: "← / →"; color: root.textPrimary; font.family: root.fontMono; font.pixelSize: 10 } }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.sc_prev_next", "Previous / Next image"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Rectangle { width: 70; height: 20; radius: 4; color: root.bgCard; border.color: root.borderSubtle; border.width: 1; Text { anchors.centerIn: parent; text: "Ctrl + A"; color: root.textPrimary; font.family: root.fontMono; font.pixelSize: 10 } }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.sc_select_all", "Select all visible"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Rectangle { width: 150; height: 20; radius: 4; color: root.bgCard; border.color: root.borderSubtle; border.width: 1; Text { anchors.centerIn: parent; text: root.tr("settings.key_shift_click", "Shift+Click"); color: root.textPrimary; font.family: root.fontMono; font.pixelSize: 10 } }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.sc_range_select", "Range selection"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Rectangle { width: 150; height: 20; radius: 4; color: root.bgCard; border.color: root.borderSubtle; border.width: 1; Text { anchors.centerIn: parent; text: root.tr("settings.key_ctrl_click", "Ctrl+Click"); color: root.textPrimary; font.family: root.fontMono; font.pixelSize: 10 } }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.sc_toggle_select", "Toggle individual selection"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Rectangle { width: 70; height: 20; radius: 4; color: root.bgCard; border.color: root.borderSubtle; border.width: 1; Text { anchors.centerIn: parent; text: "Delete"; color: root.textPrimary; font.family: root.fontMono; font.pixelSize: 10 } }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.sc_delete", "Send to Recycle Bin"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Rectangle { width: 70; height: 20; radius: 4; color: root.bgCard; border.color: root.borderSubtle; border.width: 1; Text { anchors.centerIn: parent; text: "B / I"; color: root.textPrimary; font.family: root.fontMono; font.pixelSize: 10 } }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.sc_sidebars", "Toggle Left / Right sidebars"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Rectangle { width: 70; height: 20; radius: 4; color: root.bgCard; border.color: root.borderSubtle; border.width: 1; Text { anchors.centerIn: parent; text: "Ctrl + ,"; color: root.textPrimary; font.family: root.fontMono; font.pixelSize: 10 } }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.sc_settings", "Settings dialog"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Rectangle { width: 70; height: 20; radius: 4; color: root.bgCard; border.color: root.borderSubtle; border.width: 1; Text { anchors.centerIn: parent; text: "+ / - / 0"; color: root.textPrimary; font.family: root.fontMono; font.pixelSize: 10 } }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.sc_zoom", "Zoom in / out / reset"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Rectangle { width: 70; height: 20; radius: 4; color: root.bgCard; border.color: root.borderSubtle; border.width: 1; Text { anchors.centerIn: parent; text: "P"; color: root.textPrimary; font.family: root.fontMono; font.pixelSize: 10 } }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.sc_prompt_sheet", "Toggle metadata sheet"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Rectangle { width: 150; height: 20; radius: 4; color: root.bgCard; border.color: root.borderSubtle; border.width: 1; Text { anchors.centerIn: parent; text: root.tr("settings.key_hold_mouse", "Hold Mouse"); color: root.textPrimary; font.family: root.fontMono; font.pixelSize: 10 } }
                                            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.tr("settings.sc_hover_preview", "Open hover preview"); color: root.textSecondary; font.family: root.fontMain; font.pixelSize: 11 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= 4. FULLSCREEN PREVIEW MODAL (With Pan, Zoom, Glassmorphism & Capsule Controls) =================
    Item {
        id: modalRoot
        anchors.fill: parent
        visible: opacity > 0.001
        opacity: root.activeModalUrl !== "" ? 1.0 : 0.0
        z: 999

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // Hardware MultiEffect Frosted Glass Blur over Gallery
        MultiEffect {
            anchors.fill: parent
            source: mainContent
            blurEnabled: root.enableGlass
            blurMax: 40
            blur: 0.92
            saturation: root.isDarkTheme ? -0.18 : 0.08
            visible: root.enableGlass
        }

        // Glass Backdrop Tint Scrim
        Rectangle {
            anchors.fill: parent
            color: root.isDarkTheme ? 
                (root.enableGlass ? Qt.rgba(0.04, 0.04, 0.07, 0.88) : "#f00c0c10") : 
                (root.enableGlass ? Qt.rgba(0.96, 0.96, 0.99, 0.88) : "#f2f6f6f9")

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.modalZoomScale > 1.05) {
                        root.modalZoomScale = 1.0
                    } else {
                        root.activeModalUrl = ""
                    }
                }
            }
        }

        // Viewport Flickable (Kinetic pan when zoomed)
        Flickable {
            id: modalFlickable
            anchors.fill: parent
            anchors.topMargin: 52
            anchors.bottomMargin: 72
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: root.modalZoomScale > 1.02
            contentWidth: Math.max(width, modalCanvas.width)
            contentHeight: Math.max(height, modalCanvas.height)

            Item {
                id: modalCanvas
                width: Math.max(modalFlickable.width, Math.round(baseW * root.modalZoomScale))
                height: Math.max(modalFlickable.height, Math.round(baseH * root.modalZoomScale))

                readonly property real imgAspect: (modalImage.implicitWidth > 0 && modalImage.implicitHeight > 0) ? 
                    (modalImage.implicitWidth / modalImage.implicitHeight) : 1.0
                readonly property real vpAspect: modalFlickable.width / Math.max(1, modalFlickable.height)
                readonly property real baseW: imgAspect > vpAspect ? (modalFlickable.width - 64) : ((modalFlickable.height - 64) * imgAspect)
                readonly property real baseH: imgAspect > vpAspect ? ((modalFlickable.width - 64) / imgAspect) : (modalFlickable.height - 64)

                Image {
                    id: modalImage
                    anchors.centerIn: parent
                    width: Math.round(modalCanvas.baseW * root.modalZoomScale)
                    height: Math.round(modalCanvas.baseH * root.modalZoomScale)
                    source: root.activeModalUrl
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.modalZoomScale > 1.02 ? Qt.OpenHandCursor : Qt.ArrowCursor
                    onDoubleClicked: {
                        if (root.modalZoomScale > 1.1) {
                            root.modalZoomScale = 1.0
                        } else {
                            root.modalZoomScale = 2.5
                        }
                    }
                    onClicked: {
                        if (root.showModalPromptSheet) {
                            root.showModalPromptSheet = false
                        }
                    }
                }
            }
        }

        // Interactive Wheel Zoom Handler
        WheelHandler {
            target: null
            onWheel: (event) => {
                if (root.activeModalUrl === "") return
                var factor = event.angleDelta.y > 0 ? 1.18 : (1.0 / 1.18)
                var next = Math.min(6.0, Math.max(1.0, Math.round(root.modalZoomScale * factor * 100) / 100))
                if (Math.abs(next - 1.0) < 0.05) next = 1.0
                root.modalZoomScale = next
            }
        }

        // Top Frosted Glass Navigation Bar
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            color: root.isDarkTheme ? "#111117" : "#f8f8fc"
            border.color: root.borderSubtle
            border.width: 1

            SurfaceSheen {
                anchors.fill: parent
                cornerRadius: parent.radius || 0
                highlightColor: root.borderSpecular
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16
                spacing: 12

                Text {
                    text: gallery.selectedImage.fileName || ""
                    color: root.textPrimary
                    font.family: root.fontMain
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                // Resolution & Size Badges
                Rectangle {
                    height: 24
                    width: modalResLabel.width + 16
                    radius: 4
                    color: root.bgCard
                    border.color: root.borderSubtle
                    visible: !!gallery.selectedImage.dimensions

                    Text {
                        id: modalResLabel
                        anchors.centerIn: parent
                        text: (gallery.selectedImage.dimensions || "") + (gallery.selectedImage.fileSize ? (" • " + gallery.selectedImage.fileSize) : "")
                        color: root.textMuted
                        font.family: root.fontMono
                        font.pixelSize: 11
                    }
                }

                // Quick Copy Prompt Button
                LobeButton {
                    text: modalCopyTimer.running ? root.tr("common.copied", "Copied!") : root.tr("context.copy_prompt", "Copy Prompt")
                    visible: !!gallery.selectedImage.prompt
                    type: modalCopyTimer.running ? "primary" : "default"
                    size: "small"
                    onClicked: {
                        clipboardHelper.copyText(gallery.selectedImage.prompt)
                        modalCopyTimer.restart()
                    }
                }
                Timer {
                    id: modalCopyTimer
                    interval: 1500
                }

                // Prompt Drawer Toggle Button (P)
                LobeButton {
                    text: root.showModalPromptSheet ? (root.tr("common.close", "Hide") + " (P)") : (root.tr("inspector.title", "Info") + " (P)")
                    visible: !!(gallery.selectedImage.prompt || gallery.selectedImage.modelName)
                    type: root.showModalPromptSheet ? "primary" : "default"
                    size: "small"
                    onClicked: root.showModalPromptSheet = !root.showModalPromptSheet
                }

                // Close Button
                LobeActionIcon {
                    icon: "x"
                    size: "middle"
                    title: root.tr("common.close", "Close") + " (Esc)"
                    onClicked: root.activeModalUrl = ""
                }
            }
        }

        // Side Navigation Arrow Buttons (Floating Frosted Glass Chevrons)
        Rectangle {
            id: modalPrevBtn
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 22
            visible: root.activeModalIndex > 0
            color: prevMouse.containsMouse ? 
                (root.isDarkTheme ? Qt.rgba(0.20, 0.20, 0.26, 0.92) : Qt.rgba(1.0, 1.0, 1.0, 0.98)) : 
                (root.isDarkTheme ? Qt.rgba(0.08, 0.08, 0.12, 0.72) : Qt.rgba(1.0, 1.0, 1.0, 0.80))
            border.color: prevMouse.containsMouse ? root.lobeAccent : Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
            scale: prevMouse.pressed ? 0.92 : (prevMouse.containsMouse ? 1.08 : 1.0)
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 110 } }

            LobeIcon {
                anchors.centerIn: parent
                name: "chevron-left"
                size: 26
                color: prevMouse.containsMouse ? root.lobeAccent : root.textPrimary
            }

            MouseArea {
                id: prevMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.activeModalIndex > 0) {
                        root.activeModalIndex--
                        gallery.selectImage(root.activeModalIndex)
                        root.activeModalUrl = gallery.selectedImage.url
                    }
                }
            }
        }

        Rectangle {
            id: modalNextBtn
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 22
            visible: root.activeModalIndex < gallery.filteredCount - 1
            color: nextMouse.containsMouse ? 
                (root.isDarkTheme ? Qt.rgba(0.20, 0.20, 0.26, 0.92) : Qt.rgba(1.0, 1.0, 1.0, 0.98)) : 
                (root.isDarkTheme ? Qt.rgba(0.08, 0.08, 0.12, 0.72) : Qt.rgba(1.0, 1.0, 1.0, 0.80))
            border.color: nextMouse.containsMouse ? root.lobeAccent : Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
            scale: nextMouse.pressed ? 0.92 : (nextMouse.containsMouse ? 1.08 : 1.0)
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 110 } }

            LobeIcon {
                anchors.centerIn: parent
                name: "chevron-right"
                size: 26
                color: nextMouse.containsMouse ? root.lobeAccent : root.textPrimary
            }

            MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.activeModalIndex < gallery.filteredCount - 1) {
                        root.activeModalIndex++
                        gallery.selectImage(root.activeModalIndex)
                        root.activeModalUrl = gallery.selectedImage.url
                    }
                }
            }
        }

        // Floating Bottom Glass Control Capsule
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            height: 42
            width: bottomCapsuleRow.width + 24
            radius: 21
            clip: true
            color: root.isDarkTheme ? "#111117" : "#f8f8fc"
            border.color: root.borderSubtle
            border.width: 1

            SurfaceSheen {
                anchors.fill: parent
                cornerRadius: parent.radius || 0
                highlightColor: root.borderSpecular
            }

            RowLayout {
                id: bottomCapsuleRow
                anchors.centerIn: parent
                spacing: 6

                // Zoom Out
                LobeActionIcon {
                    icon: "minus"
                    size: "small"
                    title: root.tr("settings.sc_zoom", "Zoom Out") + " (-)"
                    onClicked: root.modalZoomScale = Math.max(1.0, Math.round(root.modalZoomScale / 1.25 * 100) / 100)
                }

                // Zoom Level Badge / Reset Button
                LobeButton {
                    text: Math.round(root.modalZoomScale * 100) + "%"
                    size: "small"
                    type: root.modalZoomScale > 1.02 ? "primary" : "default"
                    onClicked: root.modalZoomScale = 1.0
                }

                // Zoom In
                LobeActionIcon {
                    icon: "plus"
                    size: "small"
                    title: root.tr("settings.sc_zoom", "Zoom In") + " (+)"
                    onClicked: root.modalZoomScale = Math.min(6.0, Math.round(root.modalZoomScale * 1.25 * 100) / 100)
                }

                Rectangle { width: 1; height: 18; color: root.borderSubtle }

                // Counter: Index / Total
                Text {
                    text: (root.activeModalIndex + 1) + " / " + gallery.filteredCount
                    color: root.textMuted
                    font.family: root.fontMono
                    font.pixelSize: 11
                }

                Rectangle { width: 1; height: 18; color: root.borderSubtle }

                // Reveal in Explorer Button
                LobeButton {
                    iconName: "folder-open"
                    text: root.tr("common.reveal", "Reveal")
                    size: "small"
                    onClicked: gallery.revealIndexInExplorer(root.activeModalIndex)
                }

                // Move Button
                LobeButton {
                    text: root.tr("common.move", "Move...")
                    size: "small"
                    onClicked: {
                        moveFolderDialog.targetFilePath = gallery.pathAt(root.activeModalIndex)
                        moveFolderDialog.open()
                    }
                }

                // Delete Button
                LobeButton {
                    text: root.useRecycleBin ? root.tr("common.recycle", "Recycle") : root.tr("common.delete", "Delete")
                    type: "danger"
                    size: "small"
                    onClicked: {
                        var idx = root.activeModalIndex
                        if (root.activeModalIndex < gallery.filteredCount - 1) {
                            root.activeModalIndex++
                            gallery.selectImage(root.activeModalIndex)
                            root.activeModalUrl = gallery.selectedImage.url
                        } else if (root.activeModalIndex > 0) {
                            root.activeModalIndex--
                            gallery.selectImage(root.activeModalIndex)
                            root.activeModalUrl = gallery.selectedImage.url
                        } else {
                            root.activeModalUrl = ""
                        }
                        root.requestDelete(idx)
                    }
                }
            }
        }

        // Expandable Floating Frosted Glass Prompt Drawer
        Rectangle {
            id: modalPromptDrawer
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 70
            anchors.rightMargin: 20
            width: Math.min(parent.width - 40, 480)
            height: Math.min(parent.height - 140, 360)
            radius: 10
            clip: true
            visible: root.showModalPromptSheet && !!(gallery.selectedImage.prompt || gallery.selectedImage.modelName)
            color: root.isDarkTheme ? "#111117" : "#f8f8fc"
            border.color: root.borderSubtle
            border.width: 1

            SurfaceSheen {
                anchors.fill: parent
                cornerRadius: parent.radius || 0
                highlightColor: root.borderSpecular
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                // Drawer Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: root.tr("inspector.parameters", "GENERATION METADATA").toUpperCase()
                        color: root.textSecondary
                        font.family: root.fontMain
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.1
                    }
                    Item { Layout.fillWidth: true }

                    LobeButton {
                        text: copyDrawerTimer.running ? root.tr("common.copied", "Copied All!") : (root.tr("common.copy", "Copy") + " " + root.tr("common.all", "All"))
                        type: copyDrawerTimer.running ? "primary" : "default"
                        size: "small"
                        onClicked: {
                            var allMeta = (gallery.selectedImage.prompt || "") + "\n\nNegative Prompt: " + (gallery.selectedImage.negativePrompt || "") + "\n\n" + (gallery.selectedImage.otherParams || "")
                            clipboardHelper.copyText(allMeta)
                            copyDrawerTimer.restart()
                        }
                    }
                    Timer { id: copyDrawerTimer; interval: 1500 }

                    LobeActionIcon {
                        icon: "x"
                        size: "small"
                        title: root.tr("common.close", "Close") + " (P)"
                        onClicked: root.showModalPromptSheet = false
                    }
                }

                // Scrollable Prompt & Details Body
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: drawerContentCol.height
                    clip: true

                    ColumnLayout {
                        id: drawerContentCol
                        width: parent.width
                        spacing: 8

                        // Positive Prompt
                        Text {
                            text: root.tr("inspector.prompt", "Prompt") + ":"
                            color: root.textMuted
                            font.family: root.fontMain
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: gallery.selectedImage.prompt || ("(" + root.tr("common.none", "None") + ")")
                            color: root.textPrimary
                            font.family: root.fontMain
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        // Negative Prompt
                        Text {
                            text: root.tr("inspector.negative_prompt", "Negative Prompt") + ":"
                            color: root.textMuted
                            font.family: root.fontMain
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            visible: !!gallery.selectedImage.negativePrompt
                        }
                        Text {
                            text: gallery.selectedImage.negativePrompt || ""
                            color: root.isDarkTheme ? "#f87171" : "#dc2626"
                            font.family: root.fontMain
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            visible: !!gallery.selectedImage.negativePrompt
                        }

                        // Model & Parameters
                        Text {
                            text: root.tr("inspector.parameters", "Parameters") + ":"
                            color: root.textMuted
                            font.family: root.fontMain
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            visible: !!(gallery.selectedImage.modelName || gallery.selectedImage.otherParams)
                        }
                        Text {
                            text: (gallery.selectedImage.modelName ? (root.tr("inspector.model", "Model") + ": " + gallery.selectedImage.modelName + "\n") : "") + (gallery.selectedImage.otherParams || "")
                            color: root.textSecondary
                            font.family: root.fontMono
                            font.pixelSize: 10
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            visible: !!(gallery.selectedImage.modelName || gallery.selectedImage.otherParams)
                        }
                    }
                }
            }
        }
    }
}
