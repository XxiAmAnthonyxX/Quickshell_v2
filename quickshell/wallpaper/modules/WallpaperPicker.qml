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
    WlrLayershell.namespace: "quickshell-wallpaper"

    property bool open: false
    property int selectedIndex: 0
    property string statusText: ""

    // Merged if the directory exists
    readonly property var wallpaperDirs: [
        "/mnt/backup/Files/Wallpapers",
        Quickshell.env("HOME") + "/Pictures/Wallpapers",
        Quickshell.env("HOME") + "/Pictures/wallpapers",
        Quickshell.env("HOME") + "/wallpapers",
        Quickshell.env("HOME") + "/.config/hypr/wallpapers",
        Quickshell.env("HOME") + "/.config/quickshell/wallpapers"
    ]

    ListModel { id: fullModel }
    ListModel { id: filteredModel }

    onOpenChanged: {
        visible = open
        if (open) {
            searchField.text = ""
            statusText = ""
            selectedIndex = 0
            scanWallpapers()
            searchField.forceActiveFocus()
        }
    }

    function scanWallpapers() {
        fullModel.clear()
        filteredModel.clear()
        scanProc.running = true
    }

    function applyFilter(query) {
        filteredModel.clear()
        const q = query.trim().toLowerCase()
        for (let i = 0; i < fullModel.count; i++) {
            const item = fullModel.get(i)
            if (q === "" || item.name.toLowerCase().includes(q) || item.kind.includes(q))
                filteredModel.append(item)
        }
        selectedIndex = filteredModel.count > 0 ? 0 : -1
    }

    function selectCurrent() {
        if (selectedIndex < 0 || selectedIndex >= filteredModel.count)
            return
        applyWallpaper(filteredModel.get(selectedIndex).path, filteredModel.get(selectedIndex).kind)
    }

    function columnsOfGrid() {
        return Math.max(1, Math.floor((grid.width + grid.spacing) / (160 + grid.spacing)))
    }

    function isVideoPath(path) {
        const lower = path.toLowerCase()
        return lower.endsWith(".gif")
            || lower.endsWith(".mp4")
            || lower.endsWith(".webm")
            || lower.endsWith(".mkv")
            || lower.endsWith(".mov")
    }

    function applyWallpaper(path, kind) {
        statusText = "APPLYING…"
        const isVideo = kind === "video" || isVideoPath(path)

        // Pipeline:
        // 1) stop previous backends (mpvpaper / awww / swaybg)
        // 2) still frame → lock cache + wal (videos need a frame)
        // 3) set wallpaper (mpvpaper vs awww/hyprpaper/swaybg)
        // 4) reload kitty + pywalfox
        applyProc.command = [
            "sh", "-c",
            'WP="$1"; IS_VIDEO="$2"; ' +
            'CACHE="$HOME/.cache/quickshell"; mkdir -p "$CACHE"; ' +
            'LOCK="$CACHE/lock_wallpaper.png"; ' +
            'CURRENT="$CACHE/current_wallpaper"; ' +
            'command -v wal >/dev/null 2>&1 || { echo "wal not found"; exit 1; }; ' +

            // Stop previous wallpaper processes
            'pkill -x mpvpaper 2>/dev/null || true; ' +
            'pkill -x swaybg 2>/dev/null || true; ' +
            'if command -v awww >/dev/null 2>&1 && pgrep -x awww-daemon >/dev/null 2>&1; then ' +
            '  awww clear 2>/dev/null || true; ' +
            'fi; ' +
            'sleep 0.15; ' +

            'if [ "$IS_VIDEO" = "1" ]; then ' +
            // Still for wal + lock
            '  if command -v ffmpeg >/dev/null 2>&1; then ' +
            '    ffmpeg -y -ss 00:00:01 -i "$WP" -frames:v 1 -q:v 2 "$LOCK" >/dev/null 2>&1 ' +
            '      || ffmpeg -y -i "$WP" -frames:v 1 -q:v 2 "$LOCK" >/dev/null 2>&1; ' +
            '  elif command -v ffmpegthumbnailer >/dev/null 2>&1; then ' +
            '    ffmpegthumbnailer -i "$WP" -o "$LOCK" -s 0 -q 8 2>/dev/null; ' +
            '  else ' +
            '    echo "ffmpeg required for video themes"; exit 1; ' +
            '  fi; ' +
            '  [ -f "$LOCK" ] || { echo "frame extract failed"; exit 1; }; ' +
            '  wal -i "$LOCK" -n -q; ' +
            // Animated wallpaper via mpvpaper (all monitors from hyprctl, fallback pair)
            '  if ! command -v mpvpaper >/dev/null 2>&1; then echo "mpvpaper not found"; exit 1; fi; ' +
            '  OPTS="loop panscan=1.0 no-audio hwdec=auto-safe profile=fast vf=fps=30 scale=bilinear"; ' +
            '  MONS=$(hyprctl monitors -j 2>/dev/null | jq -r \'.[].name\' 2>/dev/null); ' +
            '  if [ -z "$MONS" ]; then MONS="DP-1 HDMI-A-1"; fi; ' +
            '  for mon in $MONS; do ' +
            '    setsid mpvpaper -o "$OPTS" "$mon" "$WP" >/dev/null 2>&1 & ' +
            '  done; ' +
            'else ' +
            // Static image
            '  if command -v convert >/dev/null 2>&1; then ' +
            '    convert "$WP" "$LOCK" 2>/dev/null || cp -f "$WP" "$LOCK" 2>/dev/null || true; ' +
            '  else ' +
            '    cp -f "$WP" "$LOCK" 2>/dev/null || true; ' +
            '  fi; ' +
            '  wal -i "$WP" -n -q; ' +
            '  if command -v awww >/dev/null 2>&1; then ' +
            '    if ! pgrep -x awww-daemon >/dev/null 2>&1; then awww-daemon >/dev/null 2>&1 & sleep 0.35; fi; ' +
            '    awww img "$WP" --transition-type fade --transition-duration 0.55; ' +
            '  elif command -v hyprctl >/dev/null 2>&1 && hyprctl hyprpaper unload all >/dev/null 2>&1; then ' +
            '    hyprctl hyprpaper preload "$WP"; ' +
            '    for mon in $(hyprctl monitors -j 2>/dev/null | jq -r \'.[].name\'); do ' +
            '      hyprctl hyprpaper wallpaper "$mon,$WP"; ' +
            '    done; ' +
            '  elif command -v swaybg >/dev/null 2>&1; then ' +
            '    swaybg -i "$WP" -m fill >/dev/null 2>&1 & ' +
            '  else ' +
            '    echo "no static wallpaper backend (awww/hyprpaper/swaybg)"; exit 1; ' +
            '  fi; ' +
            'fi; ' +

            'printf "%s\\n" "$WP" > "$CURRENT"; ' +
            'pkill -SIGUSR1 kitty 2>/dev/null || true; ' +
            'command -v pywalfox >/dev/null 2>&1 && pywalfox update >/dev/null 2>&1 || true; ' +
            'echo ok',
            "_", path, isVideo ? "1" : "0"
        ]
        applyProc.running = true
    }

    Process {
        id: scanProc
        command: [
            "sh", "-c",
            'dirs=""; ' +
            'for d in "/mnt/backup/Files/Wallpapers" ' +
            '         "$HOME/Pictures/Wallpapers" "$HOME/Pictures/wallpapers" ' +
            '         "$HOME/wallpapers" "$HOME/.config/hypr/scripts/theme/wallpapers" ' +
            '         "$HOME/.config/quickshell/wallpapers"; do ' +
            '  [ -d "$d" ] && dirs="$dirs $d"; ' +
            'done; ' +
            'if [ -z "$dirs" ]; then exit 0; fi; ' +
            'find $dirs -type f \\( ' +
            '  -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o ' +
            '  -iname "*.webp" -o -iname "*.bmp" -o -iname "*.jxl" -o ' +
            '  -iname "*.gif" -o -iname "*.mp4" -o -iname "*.webm" -o ' +
            '  -iname "*.mkv" -o -iname "*.mov" ' +
            '\\) 2>/dev/null | sort'
        ]
        stdout: SplitParser {
            onRead: line => {
                const path = line.trim()
                if (!path)
                    return
                const name = path.split("/").pop()
                const kind = root.isVideoPath(path) ? "video" : "image"
                fullModel.append({ path: path, name: name, kind: kind })
            }
        }
        onRunningChanged: {
            if (!running)
                applyFilter(searchField.text)
        }
    }

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                if (out === "ok") {
                    root.statusText = "THEME UPDATED"
                    closeTimer.start()
                } else {
                    root.statusText = (out || "FAILED").toUpperCase()
                }
            }
        }
        onRunningChanged: {
            if (!running && root.statusText === "APPLYING…")
                root.statusText = "DONE"
        }
    }

    Timer {
        id: closeTimer
        interval: 500
        onTriggered: root.open = false
    }

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
        width: Math.min(920, parent.width - 64)
        height: Math.min(640, parent.height - 64)
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
            spacing: 12

            // Header
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "WALLPAPERS"
                    color: Theme.accentBright
                    font.pixelSize: 15
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.letterSpacing: Theme.fontLetterSpacing
                }
                Text {
                    text: {
                        let n = filteredModel.count
                        let s = n + " FILE" + (n !== 1 ? "S" : "") + "  //  STATIC + ANIMATED"
                        if (root.statusText !== "")
                            s += "  //  " + root.statusText
                        return s
                    }
                    color: Theme.muted
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                    font.bold: Theme.fontBold
                    font.letterSpacing: Theme.fontLetterSpacing
                }
            }

            // Search
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "SEARCH  //  TYPE VIDEO OR IMAGE…"
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
                        root.selectCurrent()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        root.selectedIndex = Math.min(root.selectedIndex + root.columnsOfGrid(), filteredModel.count - 1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        root.selectedIndex = Math.max(root.selectedIndex - root.columnsOfGrid(), 0)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right) {
                        root.selectedIndex = Math.min(root.selectedIndex + 1, filteredModel.count - 1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                        event.accepted = true
                    }
                }
            }

            // Grid
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 160
                cellHeight: 114
                model: filteredModel
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                onCurrentIndexChanged: root.selectedIndex = currentIndex

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight
                    required property int index
                    required property string path
                    required property string name
                    required property string kind

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 10
                        color: Qt.darker(Theme.background, 1.15)
                        border.color: root.selectedIndex === index ? Theme.accentBright : Theme.muted
                        border.width: root.selectedIndex === index ? 2 : 1
                        clip: true

                        // Image preview (static only)
                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            visible: kind === "image"
                            source: kind === "image" ? ("file://" + path) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 320
                            sourceSize.height: 220
                        }

                        // Video placeholder
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            visible: kind === "video"
                            color: Qt.darker(Theme.background, 1.35)

                            Column {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "▶"
                                    color: Theme.accentBright
                                    font.pixelSize: 22
                                    font.family: Theme.fontFamily
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "VIDEO"
                                    color: Theme.muted
                                    font.pixelSize: 11
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.letterSpacing: Theme.fontLetterSpacing
                                }
                            }
                        }

                        // Kind badge
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            height: 18
                            width: badgeLbl.width + 10
                            radius: 4
                            color: Qt.rgba(0, 0, 0, 0.65)
                            border.color: kind === "video" ? Theme.accent : Theme.muted
                            border.width: 1

                            Text {
                                id: badgeLbl
                                anchors.centerIn: parent
                                text: kind === "video" ? "VID" : "IMG"
                                color: kind === "video" ? Theme.accentBright : Theme.muted
                                font.pixelSize: 9
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.letterSpacing: 1.2
                            }
                        }

                        // Filename
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 22
                            color: Qt.rgba(0, 0, 0, 0.6)

                            Text {
                                anchors.fill: parent
                                anchors.margins: 4
                                text: name
                                color: Theme.foreground
                                font.pixelSize: 10
                                font.family: Theme.fontFamily
                                font.bold: Theme.fontBold
                                font.letterSpacing: 0.8
                                elide: Text.ElideMiddle
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedIndex = index
                            onClicked: root.selectedIndex = index
                            onDoubleClicked: root.applyWallpaper(path, kind)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: filteredModel.count === 0
                    text: fullModel.count === 0
                          ? "NO SIGNAL\n// ADD FILES TO WALLPAPER DIRS"
                          : "NO MATCH"
                    color: Theme.muted
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
                    font.family: Theme.fontFamily
                    font.bold: Theme.fontBold
                    font.letterSpacing: Theme.fontLetterSpacing
                }
            }

            // Footer
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "↑↓←→ NAV  //  ⏎ APPLY + THEME  //  ESC CLOSE"
                    color: Theme.muted
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                    font.bold: Theme.fontBold
                    font.letterSpacing: Theme.fontLetterSpacing
                    Layout.fillWidth: true
                    opacity: 0.85
                }

                Rectangle {
                    height: 30
                    width: applyLbl.width + 22
                    radius: 8
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
                    border.color: Theme.accent
                    border.width: 1
                    opacity: root.selectedIndex >= 0 ? 1 : 0.35

                    Text {
                        id: applyLbl
                        anchors.centerIn: parent
                        text: "APPLY + THEME"
                        color: Theme.accentBright
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.letterSpacing: Theme.fontLetterSpacing
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.selectedIndex >= 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectCurrent()
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "wallpaper"
        function open(): void { root.open = true }
        function toggle(): void { root.open = !root.open }
        function close(): void { root.open = false }
        function refresh(): void {
            if (root.open)
                root.scanWallpapers()
        }
    }
}
