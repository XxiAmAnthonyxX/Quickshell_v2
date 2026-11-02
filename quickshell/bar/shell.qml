import Quickshell
import QtQuick
import qs

ShellRoot {
    PanelWindow {
        id: bar

        anchors {
            top: true
            left: true
            right: true
        }

        // Uniform with Hyprland gaps (both 5)
        implicitHeight: Theme.pillHeight + 5   // 5 + pill + 5
        color: "transparent"

        Item {
            anchors.fill: parent
            anchors.leftMargin: 8     // gaps_out
            anchors.rightMargin: 8    // gaps_out

            // LEFT – Visualizer pill
Visualizer {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.topMargin: 5          // or 5 if you want a top inset
}

Clock {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 5
}

Media {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 5
}
        }
    }
}
