import QtQuick
import qs

Item {
    id: root

    property alias content: contentItem.data
    property color fill: Theme.background

    height: Theme.pillHeight

    // Simple rectangle pill – no border, no chamfer
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Qt.rgba(root.fill.r, root.fill.g, root.fill.b, Theme.pillOpacity)
    }

    // Content area
    Item {
        id: contentItem
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        clip: true
    }
}
