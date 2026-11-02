import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

PanelWindow {
    id: root

    visible: true
    implicitWidth: 440
    implicitHeight: 540
    color: "transparent"
    focusable: true
    aboveWindows: true

    property string search: ""
    property string selectedEmoji: ""

    property var emojis: [
        "😀","😃","😄","😁","😆","😅","😂","🤣",
        "🥹","😊","😇","🙂","🙃","😉","😍","🥰",
        "😘","😋","😎","🤓","🧐","🤔","🤫","🤭",
        "😭","😢","😤","😡","🤯","🥳","😴","🤤",
        "❤️","🧡","💛","💚","💙","💜","🖤","🤍",
        "💔","💕","💞","💖","💗","💘","💝","💯",
        "👍","👎","👏","🙌","🫶","🤝","🙏","💪",
        "👋","🤙","✌️","🤞","🫡","🫰","👌","🖕",
        "🐱","🐈","🐶","🐕","🐸","🐼","🐻","🦊",
        "🐻‍❄️","🐨","🐯","🦁","🐮","🐷","🐵","🐧",
        "🍎","🍉","🍇","🍓","🍒","🍑","🥭","🍍",
        "🍕","🍔","🍟","🌮","🍜","🍣","🍩","🍪",
        "☕","🧋","🍵","🥤","🎂","🍰","🧁","🍫",
        "✨","⭐","🌟","💫","🔥","💀","👻","🤖",
        "🎉","🎊","🎮","🎧","🎵","💻","🖥️","⌨️",
        "🚀","🌈","☀️","🌙","⚡","❄️","🌸","🍀",
        "✅","❌","⚠️","❗","❓","💬","💡","🔒"
    ]

    property var filteredEmojis: {
        if (search.trim() === "")
            return emojis
        return emojis.filter(e => e.indexOf(search.trim()) !== -1)
    }

    Process {
        id: clipboard
        command: ["wl-copy", root.selectedEmoji]
    }

    IpcHandler {
        target: "emoji"

        function toggle(): void {
            root.visible = !root.visible
            if (root.visible)
                searchField.forceActiveFocus()
        }

        function show(): void {
            root.visible = true
            searchField.forceActiveFocus()
        }

        function hide(): void {
            root.visible = false
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: "#171821"
        border.width: 1
        border.color: "#343644"

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            Row {
                width: parent.width
                spacing: 10

                Text {
                    text: "Emoji"
                    color: "#f2f0ff"
                    font.pixelSize: 24
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: 1; height: 1 }

                Text {
                    text: "✕"
                    color: "#aaaabd"
                    font.pixelSize: 20
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: root.visible = false
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            TextField {
                id: searchField
                width: parent.width
                placeholderText: "Search emojis…"
                color: "#f2f0ff"
                placeholderTextColor: "#88899b"
                font.pixelSize: 15
                selectByMouse: true
                onTextChanged: root.search = text

                background: Rectangle {
                    radius: 12
                    color: "#252735"
                    border.width: searchField.activeFocus ? 1 : 0
                    border.color: "#b9a0ff"
                }
            }

            Text {
                text: root.filteredEmojis.length + " emojis"
                color: "#9698ad"
                font.pixelSize: 12
            }

            GridView {
                id: emojiGrid
                width: parent.width
                height: parent.height - 115
                clip: true
                cellWidth: 50
                cellHeight: 50
                model: root.filteredEmojis

                delegate: Rectangle {
                    required property string modelData
                    width: 44
                    height: 44
                    radius: 10
                    color: mouse.containsMouse ? "#39334e" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.family: "Noto Color Emoji"
                        font.pixelSize: 27
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.selectedEmoji = modelData
                            clipboard.running = false
                            clipboard.running = true
                        }
                    }
                }
            }

            Text {
                width: parent.width
                text: "Click an emoji to copy it"
                color: "#9698ad"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
}

3. Run it

Start your emoji picker:
bash

qs -p ~/.config/quickshell/emoji/shell.qml

You should get a floating emoji window. Search filters the included emoji set, and clicking an emoji copies it to your Wayland clipboard with wl-copy.
4. Add a keyboard shortcut in Hyprland

Add this to ~/.config/hypr/hyprland.conf:
ini

bind = SUPER, E, exec, qs ipc call emoji toggle

Reload Hyprland:
bash

hyprctl reload

The shortcut uses Quickshell's IPC handler to toggle the picker. Keep the Quickshell process running for the shortcut to work.

If the picker is already running in a terminal, leave that process alive; later, you can start it automatically with your shell.

One note: this is a starter emoji collection with text filtering, not the complete Unicode emoji database. The Noto font provides the rendering, while the QML array determines which emojis appear.

