import QtQuick

// Segmented tab strip shown across the top of the expanded notch. Click a tab
// or press Tab / Shift+Tab (handled by the shell) to move between sections.
Row {
    id: bar

    // Array of { key, label, icon }
    property var tabs: []
    property int currentIndex: 0
    property real tabHeight: 26
    property real tabPadding: 14

    signal tabClicked(string key)

    spacing: 4

    // Tabs divide the bar evenly instead of hugging their labels, so the strip
    // reads as one segmented control across the notch.
    readonly property int tabCount: tabs ? tabs.length : 0
    readonly property real slotWidth: tabCount > 0
        ? Math.max(0, (width - spacing * (tabCount - 1)) / tabCount)
        : 0

    Repeater {
        model: bar.tabs

        delegate: Rectangle {
            id: tab

            required property var modelData
            required property int index

            readonly property var spec: tab.modelData
            readonly property bool active: tab.index === bar.currentIndex

            // Mirrored from the MouseArea below: a delegate's own bindings are
            // evaluated before its children exist, so it cannot read
            // `area.containsMouse` directly.
            property bool hover: false

            objectName: tab.spec.key
            width: bar.slotWidth
            height: bar.tabHeight
            radius: height / 2
            color: tab.active ? "#1e1e22" : (tab.hover ? "#18181b" : "transparent")
            border.color: tab.active ? "#414146" : (tab.hover ? "#2d2d31" : "transparent")
            border.width: 1

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 140
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 5

                Text {
                    id: tabIcon

                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.spec.icon
                    color: tab.active ? "#f5f5f5" : "#7a7a82"
                    font.pixelSize: 12
                }

                Text {
                    id: tabLabel

                    anchors.verticalCenter: parent.verticalCenter
                    // Long labels stay inside their slot on a narrow notch.
                    width: Math.min(implicitWidth, Math.max(0, tab.width - bar.tabPadding))
                    horizontalAlignment: Text.AlignHCenter
                    text: tab.spec.label
                    color: tab.active ? "#f2f2f2" : "#9a9aa2"
                    font.pixelSize: 11
                    font.bold: tab.active
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: tab.hover = true
                onExited: tab.hover = false
                onClicked: bar.tabClicked(tab.spec.key)
            }
        }
    }
}