import QtQuick
import QtQuick.Effects

Item {
    id: panel
    objectName: "frostedPanel"
    property Item sourceScene: null
    property real radius: 12
    property bool glassEnabled: true
    property bool dark: true
    property bool specular: true
    property bool captureLive: true
    property real amount: 0.82
    property real opacityLevel: 0.72
    property real tintStrength: 0.55
    property real chroma: 0.18
    property color tintColor: "#141415"
    property color accent: "#1677ff"
    readonly property bool hardwareAvailable: GraphicsInfo.api !== GraphicsInfo.Software && GraphicsInfo.api !== GraphicsInfo.Unknown
    readonly property bool frosted: glassEnabled && visible && hardwareAvailable && sourceScene !== null && width > 0 && height > 0
    readonly property real sampleScale: Math.min(1, Math.max(0.5, Screen.devicePixelRatio * 0.5))
    readonly property real blurPadding: 40
    readonly property point origin: {
        let x=0,y=0,node=panel;
        while(node){x+=node.x;y+=node.y;node=node.parent;}
        node=sourceScene;
        while(node){x-=node.x;y-=node.y;node=node.parent;}
        return Qt.point(x,y);
    }
    readonly property rect sampleRect: {
        const left=Math.max(0,Math.floor(origin.x-blurPadding));
        const top=Math.max(0,Math.floor(origin.y-blurPadding));
        const right=Math.min(sourceScene?sourceScene.width:1,Math.ceil(origin.x+width+blurPadding));
        const bottom=Math.min(sourceScene?sourceScene.height:1,Math.ceil(origin.y+height+blurPadding));
        return Qt.rect(left,top,Math.max(1,right-left),Math.max(1,bottom-top));
    }
    readonly property color tinted: Qt.tint(tintColor,Qt.rgba(accent.r,accent.g,accent.b,Math.max(0,Math.min(1,tintStrength))*0.075))
    readonly property real fillAlpha: frosted ? Math.min(0.92,Math.max(0.20,0.20+opacityLevel*0.64)) : 0.96
    clip: true

    ShaderEffectSource {
        id: crop
        objectName: "glassBackdropCapture"
        visible: false
        sourceItem: panel.frosted ? panel.sourceScene : null
        sourceRect: panel.sampleRect
        width: panel.sampleRect.width; height: panel.sampleRect.height
        textureSize: Qt.size(Math.ceil(width*panel.sampleScale),Math.ceil(height*panel.sampleScale))
        live: panel.frosted && panel.captureLive
        hideSource: false; recursive: false; smooth: true
    }
    Item {
        id: mask
        width: panel.sampleRect.width; height: panel.sampleRect.height
        visible: false; layer.enabled: panel.frosted
        Rectangle {
            x: panel.origin.x-panel.sampleRect.x; y: panel.origin.y-panel.sampleRect.y
            width: panel.width; height: panel.height; radius: panel.radius
            color: "white"
        }
    }
    MultiEffect {
        objectName: "glassBackdropBlur"
        visible: panel.frosted
        x: panel.sampleRect.x-panel.origin.x; y: panel.sampleRect.y-panel.origin.y
        width: panel.sampleRect.width; height: panel.sampleRect.height
        source: crop
        autoPaddingEnabled: false
        blurEnabled: panel.amount > 0
        blurMax: 32; blur: Math.max(0,Math.min(1,panel.amount))
        saturation: Math.max(0,Math.min(0.3,panel.chroma))
        maskEnabled: true; maskSource: mask
    }
    Rectangle {
        anchors.fill: parent; radius: panel.radius
        color: Qt.rgba(panel.tinted.r,panel.tinted.g,panel.tinted.b,panel.fillAlpha)
        border.width: 1
        border.color: panel.dark ? Qt.rgba(1,1,1,.16) : Qt.rgba(0,0,0,.14)
    }
    Rectangle {
        x: 1; y: 1; width: Math.max(0,panel.width-2); height: Math.max(0,panel.height-2)
        radius: Math.max(0,panel.radius-1)
        visible: panel.specular && panel.glassEnabled
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1,1,1,panel.dark?.10:.42) }
            GradientStop { position: .26; color: Qt.rgba(1,1,1,panel.dark?.018:.06) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    SurfaceSheen {
        anchors.fill: parent; cornerRadius: panel.radius
        visible: panel.specular && panel.glassEnabled
        highlightColor: Qt.rgba(1,1,1,panel.dark?.30:.72)
    }
}
