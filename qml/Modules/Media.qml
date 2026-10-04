import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import QtQuick.Effects
import "../"

// Media panel + collapsed pill, driven purely by D-Bus MPRIS through
// Quickshell.Services.Mpris. Every MPRIS-capable app (Spotify, mpv, browsers,
// players exposing playerctl) shows up here without extra wiring, and the
// player list is event driven rather than polled.
//
// `mode` mirrors the shell: "pill" while collapsed, "panel" inside the notch.
Item {
    id: media

    property string mode: "panel"

    // ------------------------------------------------ player discovery

    // Everything MPRIS advertises, including browsers.
    readonly property var allPlayers: Mpris.players.values

    // Configured ids to hide, lowercased once.
    readonly property var ignoreList: {
        const raw = Config.mediaIgnore;
        if (!raw)
            return [];
        return raw.split(",").map(s => s.trim().toLowerCase()).filter(s => s.length > 0);
    }

    // Browser bus names carry a per-window instance suffix, so compare on the
    // first path element: org.mpris.MediaPlayer2.<key>[.instance...].
    function playerKey(p) {
        const m = /^org\.mpris\.mediaplayer2\.([^.]+)/i.exec(p.dbusName || "");
        return m ? m[1].toLowerCase() : "";
    }

    function isIgnored(p) {
        if (!p || media.ignoreList.length === 0)
            return false;
        const entry = (p.desktopEntry || "").toLowerCase().replace(/\.desktop$/, "");
        const ident = (p.identity || "").toLowerCase();
        const key = media.playerKey(p);
        for (let i = 0; i < media.ignoreList.length; i++) {
            const t = media.ignoreList[i];
            if (key === t || entry === t || ident === t)
                return true;
        }
        return false;
    }

    readonly property var players: {
        media.rev;
        const all = media.allPlayers;
        if (!all)
            return [];
        const kept = [];
        for (let i = 0; i < all.length; i++) {
            if (!media.isIgnored(all[i]))
                kept.push(all[i]);
        }
        return kept;
    }

    readonly property int playerCount: players.length

    // Set once the user picks a dot; empty means "follow whatever is playing".
    property string pinnedName: ""
    property int rev: 0

    // Prefer a player that is both playing and has a track. Browsers otherwise
    // win the "is playing" race and the pill flickers between them and a real
    // player as each one's state changes.
    function betterThan(a, b) {
        if (!a)
            return b;
        if (!b)
            return a;
        const score = function (p) {
            return (p.isPlaying === true ? 2 : 0) + (p.trackTitle !== "" ? 1 : 0);
        };
        return score(b) > score(a) ? b : a;
    }

    readonly property var player: {
        media.rev;
        const all = media.players;
        if (!all || all.length === 0)
            return null;
        if (media.pinnedName !== "") {
            for (let i = 0; i < all.length; i++) {
                if (all[i].dbusName === media.pinnedName)
                    return all[i];
            }
        }
        let best = null;
        for (let i = 0; i < all.length; i++)
            best = media.betterThan(best, all[i]);
        return best;
    }

    readonly property bool isPlaying: player !== null && player.isPlaying === true
    readonly property bool hasTrack: player !== null && player.trackTitle !== ""

    // A session is "active" while a track is loaded, not only while playing, so
    // the pill doesn't disappear every time playback pauses.
    readonly property bool hasSession: player !== null
        && (media.isPlaying || (Config.mediaShowPaused && media.hasTrack))
    readonly property bool canControl: player !== null && player.canControl === true

    readonly property string title: player !== null ? player.trackTitle : ""
    readonly property string artist: player !== null ? player.trackArtist : ""
    readonly property string identity: player !== null ? player.identity : ""
    readonly property string artUrl: media.resolveArt(player !== null ? player.trackArtUrl : "")

    readonly property real length: player !== null && player.lengthSupported ? player.length : 0
    readonly property bool volumeSupported: player !== null && player.volumeSupported === true
    readonly property real volume: player !== null ? player.volume : 0
    readonly property real volumeMax: player !== null ? Math.max(1, player.volume) : 1

    property real position: 0

    // Keep the progress readout moving between MPRIS position updates, which
    // only fire on seeks rather than once a second.
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!media.player) {
                media.position = 0;
                return;
            }
            if (media.player.isPlaying === true) {
                const cap = media.length > 0 ? media.length : media.position + 1;
                media.position = Math.min(cap, media.position + 1);
            } else {
                media.position = media.player.position;
            }
        }
    }

    Connections {
        target: media
        function onPlayerChanged() {
            media.position = 0;
        }
    }

    Connections {
        target: media.player
        function onTrackChanged() {
            media.position = 0;
        }
    }

    // Bump `rev` whenever any player starts or stops playing so the `player`
    // binding above can follow playback without a polling timer.
    Instantiator {
        model: media.players

        delegate: Item {
            required property var modelData

            Connections {
                target: modelData
                function onIsPlayingChanged() {
                    media.rev++;
                }
                function onTrackChanged() {
                    media.rev++;
                }
            }
        }
    }

    // ------------------------------------------------ geometry

    readonly property real minPillWidth: Config.collapsedWidth
    readonly property real pillHeight: Config.collapsedHeight
    readonly property int pillTitleWidth: 158
    readonly property int pillArtSize: 20
    readonly property int pillDotsWidth: playerCount > 1 ? (playerCount * 6 + (playerCount - 1) * 5) + 12 : 0
    readonly property real pillWidth: Math.max(minPillWidth, 26 + pillArtWidth + pillDotsWidth + pillTitleWidth)

    readonly property int pillArtWidth: artUrl !== "" ? pillArtSize + 8 : 0

    // ------------------------------------------------ helpers

    function resolveArt(raw) {
        if (!raw)
            return "";
        return raw;
    }

    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        const pad = v => (v < 10 ? "0" : "") + v;
        return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : m + ":" + pad(sec);
    }

    function selectPlayer(name) {
        media.pinnedName = media.pinnedName === name ? "" : name;
        media.position = 0;
    }

    function playPause() {
        if (media.canControl)
            media.player.togglePlaying();
    }

    function next() {
        if (media.canControl && media.player.canGoNext)
            media.player.next();
    }

    function previous() {
        if (media.canControl && media.player.canGoPrevious)
            media.player.previous();
    }

    function setVolume(v) {
        if (media.volumeSupported)
            media.player.volume = Math.max(0, Math.min(media.volumeMax, v));
    }

    // ------------------------------------------------ pill

    Row {
        id: pillRow

        spacing: 8
        anchors.centerIn: parent
        visible: media.mode === "pill"

        Rectangle {
            width: media.pillArtSize
            height: media.pillArtSize
            radius: 5
            visible: media.artUrl !== ""
            anchors.verticalCenter: parent.verticalCenter
            color: "#1a1a1c"
            clip: true

            Image {
                anchors.fill: parent
                source: media.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
            }
        }

        Text {
            id: pillTitle

            anchors.verticalCenter: parent.verticalCenter
            width: media.pillTitleWidth
            text: media.title !== "" ? media.title : (media.identity !== "" ? media.identity : "Not playing")
            color: media.title !== "" ? "#f5f5f5" : "#8a8a90"
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
        }

        PlayerDots {
            anchors.verticalCenter: parent.verticalCenter
            list: media.players
            active: media.player
            onPicked: name => media.selectPlayer(name)
        }
    }

    // ------------------------------------------------ panel

    Item {
        id: panel

        anchors.fill: parent
        visible: media.mode === "panel"

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 8

            // ---- artwork + track info ----
            Item {
                width: parent.width
                height: 92

                Item {
                    id: thumbArea

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    // Leave room for the album-art bloom to fade out before it
                    // reaches the notch edge, otherwise it gets sliced off.
                    anchors.leftMargin: 16
                    width: 84
                    height: 84

                    Image {
                        id: glowSource

                        anchors.centerIn: parent
                        width: parent.width * 1.5
                        height: parent.height * 1.5
                        source: media.artUrl
                        sourceSize: Qt.size(40, 40)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        cache: false
                        visible: false
                    }

                    MultiEffect {
                        source: glowSource
                        anchors.fill: glowSource
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 72
                        opacity: media.artUrl !== "" ? 0.45 : 0
                    }

                    Rectangle {
                        id: thumbBox

                        anchors.fill: parent
                        radius: width / 2
                        color: media.artUrl !== "" ? "#1a1a1c" : "#161619"
                        border.color: "#2a2a2e"
                        border.width: 1
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: media.artUrl
                            sourceSize: Qt.size(80, 80)
                            fillMode: Image.PreserveAspectCrop
                            mipmap: true
                            asynchronous: true
                            smooth: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: media.artUrl === ""
                            text: "󰲸" // md-playlist_music
                            color: "#3a3a40"
                            font.pixelSize: 26
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            visible: media.isPlaying
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.55
                                    color: "transparent"
                                }
                                GradientStop {
                                    position: 1.0
                                    color: "#55000000"
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors.left: thumbArea.right
                    anchors.leftMargin: 16
                    anchors.right: playerBlock.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: media.title !== "" ? media.title : "Nothing playing"
                        color: media.title !== "" ? "#f5f5f5" : "#6a6a70"
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: media.artist !== "" ? media.artist : (media.identity !== "" ? media.identity : "No MPRIS session")
                        color: "#9a9aa2"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: media.identity !== "" && media.artist !== ""
                        text: media.identity
                        color: "#5f5f66"
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }

                Column {
                    id: playerBlock

                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    // Collapses to nothing for a single player so the title
                    // keeps the full width.
                    visible: media.playerCount > 1

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: media.pinnedName !== "" ? "pinned" : "auto"
                        color: "#4a4a50"
                        font.pixelSize: 8
                    }

                    PlayerDots {
                        anchors.horizontalCenter: parent.horizontalCenter
                        list: media.players
                        active: media.player
                        dotSize: 7
                        dotSpacing: 6
                        onPicked: name => media.selectPlayer(name)
                    }
                }
            }

            // ---- progress ----
            Item {
                width: parent.width
                height: 24

                Text {
                    id: posText

                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    text: media.formatTime(media.position)
                    color: "#8a8a90"
                    font.pixelSize: 9
                    font.family: "monospace"
                }

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    text: media.length > 0 ? media.formatTime(media.length) : "--:--"
                    color: "#8a8a90"
                    font.pixelSize: 9
                    font.family: "monospace"
                }

                Item {
                    id: seekBar

                    property real pos: media.length > 0 ? Math.max(0, Math.min(1, media.position / media.length)) : 0

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 14

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: "#26262a"
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * seekBar.pos
                        height: 4
                        radius: 2
                        color: "#f5f5f5"
                    }

                    Rectangle {
                        width: 10
                        height: 10
                        radius: width / 2
                        color: "#f5f5f5"
                        visible: seekBar.pos > 0
                        x: parent.width * seekBar.pos - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        id: seekArea

                        anchors.fill: parent
                        enabled: media.length > 0 && media.canControl
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onPressed: seekBar.seekTo(mouse.x / width)
                        onPositionChanged: if (pressed) seekBar.seekTo(mouse.x / width)
                    }

                    function seekTo(fraction) {
                        if (media.length > 0)
                            media.player.seek(media.length * Math.max(0, Math.min(1, fraction)));
                    }
                }
            }

            // ---- transport ----
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22

                Rectangle {
                    width: 34
                    height: 34
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: shuffleArea.containsMouse ? "#26262a" : "transparent"
                    border.color: media.player !== null && media.player.shuffleSupported && media.player.shuffle ? "#f5f5f5" : (shuffleArea.containsMouse ? "#3a3a3f" : "transparent")
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰒝" // md-shuffle
                        color: media.player !== null && media.player.shuffleSupported && media.player.shuffle ? "#f5f5f5" : (shuffleArea.containsMouse ? "#e5e5e5" : "#6a6a70")
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: shuffleArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: media.canControl && media.player !== null && media.player.shuffleSupported
                        onClicked: media.player.shuffle = !media.player.shuffle
                    }
                }

                Rectangle {
                    width: 42
                    height: 42
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: prevArea.containsMouse ? "#262626" : "#242426"

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮" // md-skip_previous
                        color: prevArea.containsMouse ? "#f5f5f5" : "#999999"
                        font.pixelSize: 22
                        opacity: media.canControl && media.player.canGoPrevious ? 1 : 0.35
                    }

                    MouseArea {
                        id: prevArea

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: media.previous()
                    }
                }

                Rectangle {
                    id: toggleCircle

                    width: 58
                    height: 58
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: toggleArea.containsMouse ? "#2e2e31" : "#1c1c1e"
                    border.color: toggleArea.containsMouse ? "#4a4a4d" : "#2a2a2c"
                    border.width: 1
                    opacity: media.player !== null ? 1 : 0.4

                    Rectangle {
                        id: pulse

                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        radius: width / 2
                        color: "transparent"
                        border.color: "#e5e5e5"
                        border.width: 2
                        opacity: 0
                        scale: 1
                    }

                    Text {
                        id: playIcon

                        anchors.centerIn: parent
                        text: "󰐊" // md-play
                        color: toggleArea.containsMouse ? "#ffffff" : "#e5e5e5"
                        font.pixelSize: 30
                        opacity: media.isPlaying ? 1 : 0
                        scale: media.isPlaying ? 1 : 0.4
                        rotation: media.isPlaying ? 0 : -90

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutBack
                                easing.overshoot: 2
                            }
                        }
                        Behavior on rotation {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        id: pauseIcon

                        anchors.centerIn: parent
                        text: "󰏤" // md-pause
                        color: toggleArea.containsMouse ? "#ffffff" : "#e5e5e5"
                        font.pixelSize: 30
                        opacity: media.isPlaying ? 0 : 1
                        scale: media.isPlaying ? 0.4 : 1
                        rotation: media.isPlaying ? 90 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutBack
                                easing.overshoot: 2
                            }
                        }
                        Behavior on rotation {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: toggleArea

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            media.playPause();
                            pulseScaleAnim.start();
                            pulseOpacityAnim.start();
                        }
                    }

                    NumberAnimation {
                        id: pulseScaleAnim

                        target: pulse
                        property: "scale"
                        from: 1.0
                        to: 1.35
                        duration: 400
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        id: pulseOpacityAnim

                        target: pulse
                        property: "opacity"
                        from: 0.6
                        to: 0
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    width: 42
                    height: 42
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: nextArea.containsMouse ? "#262626" : "#242426"

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭" // md-skip_next
                        color: nextArea.containsMouse ? "#f5f5f5" : "#999999"
                        font.pixelSize: 22
                        opacity: media.canControl && media.player.canGoNext ? 1 : 0.35
                    }

                    MouseArea {
                        id: nextArea

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: media.next()
                    }
                }

                Rectangle {
                    width: 34
                    height: 34
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: repeatArea.containsMouse ? "#26262a" : "transparent"
                    border.color: media.player !== null && media.player.loopSupported && media.player.loopState !== 0 ? "#f5f5f5" : (repeatArea.containsMouse ? "#3a3a3f" : "transparent")
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰑖" // md-repeat
                        color: media.player !== null && media.player.loopSupported && media.player.loopState !== 0 ? "#f5f5f5" : (repeatArea.containsMouse ? "#e5e5e5" : "#6a6a70")
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: repeatArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: media.canControl && media.player !== null && media.player.loopSupported
                        onClicked: media.player.loopState = media.player.loopState === 1 ? 0 : (media.player.loopState === 0 ? 2 : 0)
                    }
                }
            }

            // ---- volume + source ----
            Item {
                width: parent.width
                height: 26

                Text {
                    id: volIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: media.volume <= 0.001 ? "󰝟" : "󰕾" // md-volume_mute : md-volume_high
                    color: "#8a8a90"
                    font.pixelSize: 13
                }

                Item {
                    id: volBar

                    property real pos: media.volumeSupported && media.volumeMax > 0 ? Math.max(0, Math.min(1, media.volume / media.volumeMax)) : 0

                    anchors.left: volIcon.right
                    anchors.leftMargin: 8
                    anchors.right: sourceText.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 14

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: "#26262a"
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * volBar.pos
                        height: 4
                        radius: 2
                        color: "#8a8a90"
                    }

                    Rectangle {
                        width: 10
                        height: 10
                        radius: width / 2
                        color: "#e8e8e8"
                        x: parent.width * volBar.pos - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: media.volumeSupported && media.canControl
                        cursorShape: Qt.PointingHandCursor
                        onPressed: volBar.setFrom(mouse.x / width)
                        onPositionChanged: if (pressed) volBar.setFrom(mouse.x / width)
                    }

                    function setFrom(fraction) {
                        media.setVolume(Math.max(0, Math.min(1, fraction)) * media.volumeMax);
                    }
                }

                Text {
                    id: sourceText

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: media.playerCount + (media.playerCount === 1 ? " player" : " players")
                    color: "#4a4a50"
                    font.pixelSize: 9
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: media.player === null
            text: "No MPRIS player detected"
            color: "#6a6a70"
            font.pixelSize: 12
        }
    }
}