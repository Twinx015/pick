import QtQuick

// One dot per discovered MPRIS player. Stays hidden while a single player is
// around and only becomes a control once two or more are running, so the
// notch never grows a "switch player" affordance for nothing.
//
// `list` is the raw `Mpris.players.values` array, `active` is the player the
// media controls are currently pointed at.
Row {
    id: dots

    property var list: []
    property var active: null
    property real dotSize: 6
    property real dotSpacing: 5

    signal picked(string dbusName)

    spacing: dots.dotSpacing
    visible: dots.count > 1

    readonly property int count: dots.list ? dots.list.length : 0

    Repeater {
        model: dots.list

        delegate: Rectangle {
            id: dot

            required property var modelData
            required property int index

            readonly property bool current: dot.modelData === dots.active

            // Mirrored from the MouseArea below: a delegate's own bindings are
            // evaluated before its children exist.
            property bool hover: false

            width: dots.dotSize
            height: dots.dotSize
            radius: width / 2
            color: dot.current ? "#f5f5f5" : (dot.hover ? "#9a9aa2" : "#45454b")

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: dot.hover = true
                onExited: dot.hover = false
                onClicked: dots.picked(dot.modelData.dbusName)
            }
        }
    }
}