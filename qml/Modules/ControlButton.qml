import QtQuick

// Compact tile button (icon + label). Clicking opens the matching detail panel.
Rectangle {
    id: btn

    property string iconText: ""
    property string labelText: ""
    property bool active: false
    property bool powered: false

    signal clicked()

    width: 92
    height: 56
    radius: 8
    color: btnHover.containsMouse || btn.active ? "#1e1e22" : "#141417"
    border.color: btn.active ? "#414146" : (btnHover.containsMouse ? "#2d2d31" : "#1f1f22")
    border.width: 1

    Column {
        anchors.centerIn: parent
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: btn.iconText
            color: btn.powered || btn.active ? "#f5f5f5" : "#8b8b90"
            font.pixelSize: 16
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: btn.labelText
            color: "#c9c9cd"
            font.pixelSize: 10
        }
    }

    MouseArea {
        id: btnHover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}