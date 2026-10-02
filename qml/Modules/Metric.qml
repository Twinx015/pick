import QtQuick

// Compact stat tile: icon, headline value, caption, optional progress bar.
// Used by System.qml for CPU / RAM / ROM / storage style readouts.
Rectangle {
    id: card

    property string iconText: ""
    property string valueText: "--"
    property string labelText: ""
    property string subText: ""
    property real ratio: -1 // 0..1, negative hides the bar
    property color accent: "#3f8fe0"

    radius: 9
    color: "#121216"
    border.color: "#26262b"
    border.width: 1
    implicitHeight: 74

    Text {
        id: icon

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 9
        text: card.iconText
        color: "#6a6a70"
        font.pixelSize: 13
    }

    Text {
        id: value

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 9
        text: card.valueText
        color: "#f5f5f5"
        font.pixelSize: 16
        font.bold: true
        elide: Text.ElideRight
        width: Math.max(0, parent.width - icon.width - 26)
    }

    Text {
        id: label

        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.top: value.bottom
        anchors.topMargin: 1
        width: parent.width - 18
        text: card.labelText
        color: "#8a8a90"
        font.pixelSize: 9
        font.bold: true
        elide: Text.ElideRight
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.right: parent.right
        anchors.rightMargin: 9
        anchors.top: label.bottom
        anchors.topMargin: 1
        visible: card.subText !== ""
        text: card.subText
        color: "#5f5f66"
        font.pixelSize: 8
        elide: Text.ElideRight
    }

    // Progress bar pinned to the bottom edge of the tile.
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        height: 4
        visible: card.ratio >= 0

        Rectangle {
            anchors.fill: parent
            radius: 2
            color: "#26262a"
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * Math.max(0, Math.min(1, card.ratio))
            height: parent.height
            radius: 2
            color: card.accent

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}