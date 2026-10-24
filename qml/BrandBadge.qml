import QtQuick
import QtQuick.Layouts
import "DesignSystem.js" as UI

RowLayout {
    id: brand
    objectName: "viewerBrand"
    property color accentColor: "#1677ff"
    property color primaryColor: "#f8f8fc"
    property color backgroundColor: "#1e1e24"
    property string fontFamily: "Segoe UI"
    readonly property color ink: UI.readableAccent(accentColor,backgroundColor)
    readonly property var metrics: UI.design.brand
    spacing: metrics.gap
    Accessible.role: Accessible.StaticText
    Accessible.name: "galIMV"

    Rectangle {
        Layout.preferredWidth: brand.metrics.markSize
        Layout.preferredHeight: brand.metrics.markSize
        radius: brand.metrics.markRadius
        color: Qt.rgba(brand.ink.r,brand.ink.g,brand.ink.b,.10)
        border.width: 1
        border.color: Qt.rgba(brand.ink.r,brand.ink.g,brand.ink.b,.40)
        Image {
            anchors.centerIn: parent
            width: brand.metrics.iconSize; height: width
            source: UI.iconSource(brand.metrics.icon,brand.ink)
            sourceSize: Qt.size(width*Screen.devicePixelRatio,height*Screen.devicePixelRatio)
        }
    }
    Text {
        objectName: "brandWordmark"
        textFormat: Text.RichText
        text: '<span style="font-weight:400;color:'+brand.ink+'">gal</span>IMV'
        color: brand.primaryColor
        font.family: brand.fontFamily
        font.pixelSize: brand.metrics.fontSize
        font.weight: Font.Bold
        font.letterSpacing: brand.metrics.letterSpacing
    }
}
