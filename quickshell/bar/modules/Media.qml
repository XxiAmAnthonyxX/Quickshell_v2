import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs

ChamferPill {
    id: root

    width: 260

    property var player: {
        const players = Mpris.players.values
        return players.find(p => p.isPlaying) ?? players[0] ?? null
    }

    readonly property string displayText: root.player
        ? `${root.player.trackTitle}  //  ${root.player.trackArtist}`.toUpperCase()
        : "ERROR // SIGNAL LOST"

    Item {
        anchors.fill: parent
        clip: true

        TextMetrics {
            id: textMetrics
            text: root.displayText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: Theme.fontBold
            font.letterSpacing: Theme.fontLetterSpacing
        }

        Row {
            id: marquee
            anchors.verticalCenter: parent.verticalCenter
            spacing: 48

            Text {
                id: text1
                text: root.displayText
                color: root.player ? Theme.foreground : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: Theme.fontBold
                font.letterSpacing: Theme.fontLetterSpacing
            }

            Text {
                text: root.displayText
                color: text1.color
                font: text1.font
            }
        }

        NumberAnimation {
            id: scrollAnim
            target: marquee
            property: "x"
            from: 0
            to: -(text1.width + marquee.spacing)
            duration: Math.max(5000, (text1.width + marquee.spacing) * 20)
            loops: Animation.Infinite
            running: true
        }

        onVisibleChanged: {
            if (visible) {
                marquee.x = 0
                scrollAnim.restart()
            }
        }

        Connections {
            target: root
            function onDisplayTextChanged() {
                marquee.x = 0
                scrollAnim.restart()
            }
        }
    }
}
