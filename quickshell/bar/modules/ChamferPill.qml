import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: root

    property alias content: contentItem.data
    property color fill: Theme.background
    property color borderColor: Theme.accent
    property real borderOpacity: 0.55
    property int chamfer: Theme.chamfer

    // Default size – children can override width
    height: Theme.pillHeight

    // Sharp chamfered shape (cut top-right + bottom-left)
    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            fillColor: Qt.rgba(root.fill.r, root.fill.g, root.fill.b, Theme.pillOpacity)
            strokeColor: Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, root.borderOpacity)
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin

            startX: 0
            startY: root.chamfer

            // Left side → top-left
            PathLine { x: 0; y: 0 }
            // Top edge → before top-right cut
            PathLine { x: root.width - root.chamfer; y: 0 }
            // Top-right chamfer
            PathLine { x: root.width; y: root.chamfer }
            // Right side → bottom-right
            PathLine { x: root.width; y: root.height }
            // Bottom edge → before bottom-left cut
            PathLine { x: root.chamfer; y: root.height }
            // Bottom-left chamfer
            PathLine { x: 0; y: root.height - root.chamfer }
            // Close
            PathLine { x: 0; y: root.chamfer }
        }
    }

    // Content area (slightly inset so text doesn’t touch the cut)
    Item {
        id: contentItem
        anchors.fill: parent
        anchors.leftMargin: root.chamfer + 4
        anchors.rightMargin: root.chamfer + 4
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        clip: true
    }
}
