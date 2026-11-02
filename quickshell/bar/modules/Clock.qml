import QtQuick
import qs

ChamferPill {
    id: root

    width: clockText.implicitWidth + (Theme.chamfer + 4) * 2 + 12

    Text {
        id: clockText
        anchors.centerIn: parent

        property date now: new Date()

        text: {
            const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
            const day  = days[now.getDay()]
            const date = Qt.formatDate(now, "MM.dd")
            const time = Qt.formatTime(now, "HH:mm")
            return `${day}  ${date}  ${time}`
        }

        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: Theme.fontBold
        font.letterSpacing: Theme.fontLetterSpacing

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: clockText.now = new Date()
        }
    }
}
