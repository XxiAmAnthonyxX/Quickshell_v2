import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs

Scope {
    id: root

    property int selectedIndex: -1

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            launcherPanel.visible = !launcherPanel.visible
            if (launcherPanel.visible) {
                searchInput.text = ""
                root.selectedIndex = -1
                searchInput.forceActiveFocus()
            }
        }

        function show(): void {
            launcherPanel.visible = true
            searchInput.text = ""
            root.selectedIndex = -1
            searchInput.forceActiveFocus()
        }

        function hide(): void {
            launcherPanel.visible = false
        }
    }

    ScriptModel {
        id: filteredApps
        objectProp: "id"
        values: {
            const all = [...DesktopEntries.applications.values]
            const q = searchInput.text.trim().toLowerCase()

            if (q === "")
                return all.sort((a, b) => a.name.localeCompare(b.name))

            return all.filter(d =>
                (d.name && d.name.toLowerCase().includes(q))
                || (d.genericName && d.genericName.toLowerCase().includes(q))
                || (d.comment && d.comment.toLowerCase().includes(q))
                || (d.keywords && d.keywords.some(k => k.toLowerCase().includes(q)))
                || (d.categories && d.categories.some(c => c.toLowerCase().includes(q)))
            ).sort((a, b) => {
                const an = (a.name || "").toLowerCase()
                const bn = (b.name || "").toLowerCase()
                const aStarts = an.startsWith(q)
                const bStarts = bn.startsWith(q)
                if (aStarts && !bStarts) return -1
                if (!aStarts && bStarts) return 1
                return an.localeCompare(bn)
            })
        }
    }

    function launchApp(entry) {
        if (entry) {
            entry.execute()
            launcherPanel.visible = false
        }
    }

    PanelWindow {
        id: launcherPanel
        visible: false
        focusable: true
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-launcher"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: launcherPanel.visible = false
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.55)
            }
        }

        Rectangle {
            id: launcherBox
            anchors.centerIn: parent
            width: Math.min(620, parent.width - 48)
            height: Math.min(540, parent.height - 48)
            radius: 16
            color: Theme.background
            border.color: Theme.muted
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.accent
                opacity: 0.7
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "APPLICATIONS"
                        color: Theme.accentBright
                        font.pixelSize: 15
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.letterSpacing: Theme.fontLetterSpacing
                    }
                    Text {
                        text: resultsList.count + " PROCESS" + (resultsList.count !== 1 ? "ES" : "")
                              + "  //  DESKTOP ENTRIES"
                        color: Theme.muted
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                        font.bold: Theme.fontBold
                        font.letterSpacing: Theme.fontLetterSpacing
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 46
                    radius: 12
                    color: Qt.darker(Theme.background, 1.18)
                    border.color: searchInput.activeFocus ? Theme.accent : Theme.muted
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            text: "󰍉"
                            color: Theme.muted
                            font.pixelSize: 18
                            font.family: Theme.fontFamily
                            Layout.alignment: Qt.AlignVCenter
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            color: Theme.foreground
                            font.pixelSize: 15
                            font.family: Theme.fontFamily
                            font.bold: Theme.fontBold
                            font.letterSpacing: Theme.fontLetterSpacing
                            clip: true
                            selectByMouse: true

                            Text {
                                anchors.fill: parent
                                text: "SEARCH APPS…"
                                color: Theme.muted
                                font: parent.font
                                visible: !parent.text && !parent.activeFocus
                                verticalAlignment: Text.AlignVCenter
                            }

                            onTextChanged: root.selectedIndex = text === "" ? -1 : 0

                            Keys.onEscapePressed: launcherPanel.visible = false

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                    event.accepted = true
                                    root.selectedIndex = Math.min(root.selectedIndex + 1, resultsList.count - 1)
                                    resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                    event.accepted = true
                                    root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                                    resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    event.accepted = true
                                    if (root.selectedIndex >= 0) {
                                        const entry = filteredApps.values[root.selectedIndex]
                                        root.launchApp(entry)
                                    }
                                }
                            }
                        }
                    }
                }

                ListView {
                    id: resultsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: filteredApps
                    clip: true
                    spacing: 3
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: root.selectedIndex
                    highlightMoveDuration: 120

                    highlight: Rectangle {
                        radius: 10
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
                        visible: root.selectedIndex >= 0

                        Rectangle {
                            width: 3
                            height: 22
                            radius: 1
                            color: Theme.accentBright
                            anchors.left: parent.left
                            anchors.leftMargin: 3
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    delegate: Rectangle {
                        id: delegateRoot
                        required property var modelData
                        required property int index

                        width: resultsList.width
                        height: 50
                        radius: 10
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            Item {
                                width: 30
                                height: 30
                                Layout.alignment: Qt.AlignVCenter

                                IconImage {
                                    anchors.fill: parent
                                    source: Quickshell.iconPath(delegateRoot.modelData.icon || "", true)
                                    visible: (delegateRoot.modelData.icon || "") !== ""
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: Qt.darker(Theme.background, 1.2)
                                    visible: (delegateRoot.modelData.icon || "") === ""

                                    Text {
                                        anchors.centerIn: parent
                                        text: (delegateRoot.modelData.name || "?")[0].toUpperCase()
                                        color: Theme.accentBright
                                        font.pixelSize: 14
                                        font.bold: true
                                        font.family: Theme.fontFamily
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    text: (delegateRoot.modelData.name || "").toUpperCase()
                                    color: Theme.foreground
                                    font.pixelSize: 13
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.letterSpacing: Theme.fontLetterSpacing
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: (delegateRoot.modelData.genericName
                                           || delegateRoot.modelData.comment
                                           || "").toUpperCase()
                                    color: Theme.muted
                                    font.pixelSize: 10
                                    font.family: Theme.fontFamily
                                    font.bold: Theme.fontBold
                                    font.letterSpacing: Theme.fontLetterSpacing
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchApp(delegateRoot.modelData)
                            onPositionChanged: root.selectedIndex = delegateRoot.index
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "NO SIGNAL\n// NO APPLICATIONS FOUND"
                        color: Theme.muted
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                        font.family: Theme.fontFamily
                        font.bold: Theme.fontBold
                        font.letterSpacing: Theme.fontLetterSpacing
                        visible: resultsList.count === 0 && searchInput.text !== ""
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "↑↓ NAV  //  ⏎ LAUNCH  //  ESC CLOSE"
                    color: Theme.muted
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                    font.bold: Theme.fontBold
                    font.letterSpacing: Theme.fontLetterSpacing
                    opacity: 0.85
                }
            }
        }
    }
}
