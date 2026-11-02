import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

PanelWindow {
    id: root

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    color: "transparent"
    visible: false
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clipboard"

    property bool open: false
    property string previewText: ""
    property string previewImage: ""

    ListModel { id: fullModel }
    ListModel { id: filteredModel }

    onOpenChanged: {
        visible = open
        if (open) {
            searchField.text = ""
            refresh()
            searchField.forceActiveFocus()
        } else {
            previewText = ""
            previewImage = ""
        }
    }

    function refresh() {
        fullModel.clear()
        filteredModel.clear()
        getClips.running = true
    }

    function applyFilter(query) {
        filteredModel.clear()
        const q = query.trim().toLowerCase()
        for (let i = 0; i < fullModel.count; i++) {
            const item = fullModel.get(i)
            if (q === "" || item.preview.toLowerCase().includes(q))
                filteredModel.append(item)
        }
        list.currentIndex = filteredModel.count > 0 ? 0 : -1
        updatePreview()
    }

    function updatePreview() {
        if (list.currentIndex < 0 || list.currentIndex >= filteredModel.count) {
            previewText = ""
            previewImage = ""
            return
        }
        const item = filteredModel.get(list.currentIndex)
        if (item.preview.startsWith("[[ binary data ")
            || item.preview.toLowerCase().includes("image/")) {
            previewText = "[IMAGE]"
            previewImage = ""
        } else {
            getFullText.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist decode", "_", item.id]
            getFullText.running = true
            previewImage = ""
        }
    }

    function selectItem(index) {
        if (index < 0 || index >= filteredModel.count)
            return
        const item = filteredModel.get(index)
        copyProc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", item.id]
        copyProc.running = true
        root.open = false
    }

    Process {
        id: getClips
        command: ["cliphist", "list"]
        running: false
        stdout: SplitParser {
            onRead: line => {
                const trimmed = line.trim()
                if (!trimmed)
                    return
                const tab = trimmed.indexOf("\t")
                if (tab === -1)
                    return
                fullModel.append({
                    id: trimmed.substring(0, tab),
                    preview: trimmed.substring(tab + 1)
                })
            }
        }
        onRunningChanged: {
            if (!running)
                applyFilter(searchField.text)
        }
    }

    Process {
        id: getFullText
        stdout: StdioCollector {
            onStreamFinished: previewText = this.text
        }
    }

    Process { id: copyProc }

    // Dim backdrop
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.open = false
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(760, parent.width - 48)
        height: Math.min(520, parent.height - 48)
        radius: 16
        color: Theme.background
        border.color: Theme.muted
        border.width: 1

        // Top accent hairline
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
            spacing: 12

            // Header
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "CLIPBOARD"
                    color: Theme.accentBright
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                    font.letterSpacing: Theme.fontLetterSpacing
                }
                Text {
                    text: filteredModel.count + " ENTRY" + (filteredModel.count !== 1 ? "S" : "")
                          + "  //  CLIPHIST"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: Theme.fontBold
                    font.letterSpacing: Theme.fontLetterSpacing
                }
            }

            // Search
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "SEARCH BUFFER…"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: Theme.fontBold
                font.letterSpacing: Theme.fontLetterSpacing
                placeholderTextColor: Theme.muted

                background: Rectangle {
                    color: Qt.darker(Theme.background, 1.25)
                    radius: 10
                    border.color: searchField.activeFocus ? Theme.accent : Theme.muted
                    border.width: 1
                }

                onTextChanged: applyFilter(text)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.open = false
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        selectItem(list.currentIndex)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        list.incrementCurrentIndex()
                        updatePreview()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        list.decrementCurrentIndex()
                        updatePreview()
                        event.accepted = true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // List
                ListView {
                    id: list
                    Layout.preferredWidth: 300
                    Layout.fillHeight: true
                    clip: true
                    model: filteredModel
                    currentIndex: 0
                    spacing: 4

                    onCurrentIndexChanged: updatePreview()

                    delegate: Rectangle {
                        width: list.width
                        height: 44
                        radius: 8
                        color: ListView.isCurrentItem
                               ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
                               : "transparent"
                        border.color: ListView.isCurrentItem ? Theme.accent : "transparent"
                        border.width: 1

                        Text {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                margins: 12
                            }
                            text: model.preview
                            color: ListView.isCurrentItem ? Theme.accentBright : Theme.foreground
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.bold: Theme.fontBold
                            font.letterSpacing: Theme.fontLetterSpacing
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: list.currentIndex = index
                            onDoubleClicked: selectItem(index)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: filteredModel.count === 0
                        text: fullModel.count === 0
                              ? "BUFFER EMPTY\n// NO HISTORY"
                              : "NO MATCH"
                        color: Theme.muted
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: Theme.fontBold
                        font.letterSpacing: Theme.fontLetterSpacing
                    }
                }

                // Preview pane
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.darker(Theme.background, 1.18)
                    border.color: Theme.muted
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 14
                        visible: previewText !== "[IMAGE]" && previewText !== ""
                        clip: true

                        Text {
                            width: parent.width
                            text: previewText
                            color: Theme.foreground
                            wrapMode: Text.Wrap
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.letterSpacing: Theme.fontLetterSpacing
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: previewText === "" && previewImage === ""
                        text: "SELECT AN ENTRY\n// PREVIEW"
                        color: Theme.muted
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: Theme.fontBold
                        font.letterSpacing: Theme.fontLetterSpacing
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: previewText === "[IMAGE]"
                        text: "IMAGE\n// PREVIEW PENDING"
                        color: Theme.muted
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: Theme.fontBold
                        font.letterSpacing: Theme.fontLetterSpacing
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "↑↓ NAV  //  ⏎ PASTE  //  ESC CLOSE"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: Theme.fontBold
                font.letterSpacing: Theme.fontLetterSpacing
                opacity: 0.85
            }
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.open = !root.open }
        function open(): void { root.open = true }
        function close(): void { root.open = false }
    }
}
