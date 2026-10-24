import QtQuick

Item {
    id: rim
    objectName: "surfaceSheen"
    property real cornerRadius: 0
    property color highlightColor: "transparent"
    readonly property real effectiveRadius: Math.min(Math.max(0,cornerRadius),Math.max(0,width/2),Math.max(0,height/2))
    // Clip a real rounded outline to its upper edge, including both corner arcs.
    Item {
        objectName: "surfaceSheenClip"
        width: rim.width
        height: rim.height >= 3 ? Math.min(rim.height,rim.effectiveRadius+1) : 0
        clip: true
        Rectangle {
            objectName: "surfaceSheenOutline"
            width: rim.width; height: rim.height
            radius: rim.effectiveRadius
            color: "transparent"
            border.width: 1; border.color: rim.highlightColor
            antialiasing: true
        }
    }
}
