import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import qs

ChamferPill {
    id: root

    width: 220

    property int bars: 40
    property int barWidth: 3
    property int spacing: 2
    property real maxHeight: 18

    property real peak: 0
    property real animationPhase: 0
    property var values: Array(bars).fill(0)

    readonly property bool isSilent: peak < 0.02

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    PwNodePeakMonitor {
        node: Pipewire.defaultAudioSink
        onPeaksChanged: {
            if (!peaks?.length) {
                root.peak = 0
                return
            }

            let maxPeak = 0
            for (let i = 0; i < peaks.length; i++)
                maxPeak = Math.max(maxPeak, peaks[i])

            root.peak = Math.max(0, Math.min(1, maxPeak))

            root.values = Array.from({ length: root.bars }, (_, i) => {
                const t = i / Math.max(1, root.bars - 1)
                const center = 1 - Math.pow(Math.abs(t - 0.5) * 1.8, 1.6)
                const wave = 0.78 + 0.22 * Math.sin(t * Math.PI * 4 + root.animationPhase)
                return root.peak * Math.max(0.08, center * wave)
            })
        }
    }

    NumberAnimation on animationPhase {
        running: root.peak > 0.01
        from: 0
        to: Math.PI * 2
        duration: 1100
        loops: Animation.Infinite
        easing.type: Easing.Linear
    }

    // Bars
    Row {
        anchors.centerIn: parent
        spacing: root.spacing
        visible: !root.isSilent
        opacity: root.isSilent ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Repeater {
            model: root.bars

            Rectangle {
                required property int index
                width: root.barWidth
                height: Math.max(2, (root.values[index] || 0) * root.maxHeight)
                anchors.verticalCenter: parent.verticalCenter
                radius: 0
                color: Theme.foreground
                opacity: 0.30 + Math.min(0.70, (root.values[index] || 0) * 1.15)

                Behavior on height {
                    NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // Idle scrolling text
    Item {
        anchors.fill: parent
        clip: true
        visible: root.isSilent
        opacity: root.isSilent ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        readonly property string idleText: "ERROR // SIGNAL LOST"

        Row {
            id: idleMarquee
            anchors.verticalCenter: parent.verticalCenter
            spacing: 48

            Text {
                id: idleText1
                text: parent.parent.idleText
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: Theme.fontBold
                font.letterSpacing: Theme.fontLetterSpacing
            }

            Text {
                text: parent.parent.idleText
                color: idleText1.color
                font: idleText1.font
            }
        }

        NumberAnimation {
            target: idleMarquee
            property: "x"
            from: 0
            to: -(idleText1.width + idleMarquee.spacing)
            duration: Math.max(5000, (idleText1.width + idleMarquee.spacing) * 20)
            loops: Animation.Infinite
            running: root.isSilent
        }
    }
}
