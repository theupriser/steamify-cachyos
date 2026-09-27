// One menu item: name, badge and hint on the left; its control (switch,
// Gaming/Desktop choice or action button) on the right. Sub-items fold in
// and out with their parent.
import QtQuick

Item {
    id: row
    required property var modelData
    required property int index
    required property AppState app
    readonly property var it: modelData
    readonly property bool shown: !it.parent || !!app.want[it.parent]
    readonly property int rowIndex: app.rows.findIndex(function (r) { return r.id === it.id; })
    readonly property bool selected: shown && rowIndex === app.sel
    readonly property bool on: !!app.want[it.id]
    // Greyed out: an action with nothing to do, or an option this machine
    // can't turn on.
    readonly property bool unavailable: (it.kind === "action" && !(app.bios && app.bios.selectable)) || (it.kind === "toggle" && it.selectable === false)
    readonly property string hint: it.id === "bios" ? app.biosHint()
                                 : it.selectable === false ? it.hint
                                 : ((Texts.items[it.id] || {}).hint || it.hint)

    height: shown ? 62 : 0
    opacity: shown ? 1 : 0
    clip: true
    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Rectangle {
        width: parent.width; height: 56; radius: 12
        color: row.selected ? Theme.cardSel : Theme.card
        border.width: row.selected ? 2 : 0; border.color: Theme.accent
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { Input.type = "keyboard"; if (row.selected) app.act("accept"); else app.sel = row.rowIndex; } }

        Text { visible: !!row.it.parent; x: 20; anchors.verticalCenter: parent.verticalCenter; text: "└"; color: "#56627a"; font.pixelSize: 18 }
        Column {
            anchors.verticalCenter: parent.verticalCenter; spacing: 2
            x: row.it.parent ? 46 : 16
            width: controls.x - x - 16
            opacity: row.unavailable ? 0.6 : 1
            Row { width: parent.width; spacing: 10
                Text { text: app.label(row.it); color: Theme.textHi; font.family: Theme.body; font.pixelSize: 17; font.weight: Font.DemiBold; elide: Text.ElideRight
                       width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + parent.spacing : 0)) }
                Badge { id: badge; update: !!row.it.update; isNew: !!row.it["new"]; anchors.verticalCenter: parent.verticalCenter } }
            Text { text: row.hint; color: Theme.mute; font.family: Theme.body; font.pixelSize: 13; elide: Text.ElideRight; width: parent.width }
        }

        // Every control ends on the same edge.
        Item {
            id: controls
            opacity: row.it.kind === "toggle" && row.it.selectable === false ? 0.4 : 1
            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
            width: 180; height: 32
            // choice
            Rectangle { visible: row.it.kind === "choice"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: 172; height: 32; radius: 10; color: Theme.bg
                Row { anchors.centerIn: parent; spacing: 4
                    Repeater { model: [["gamescope", "Gaming"], ["desktop", "Desktop"]]
                        Rectangle { required property var modelData
                            readonly property bool picked: app.boot === modelData[0]
                            width: 80; height: 26; radius: 7; color: picked ? Theme.accent : "transparent"
                            Text { anchors.centerIn: parent; text: parent.modelData[1]; color: parent.picked ? Theme.ink : Theme.mute
                                   font.family: Theme.body; font.pixelSize: 13; font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; onClicked: app.boot = parent.modelData[0] } } } } }
            // toggle: "now on/off" left of the switch
            Rectangle { id: sw; visible: row.it.kind === "toggle"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: 46; height: 26; radius: 13; color: row.on ? Theme.accent : "#343f50"
                Behavior on color { ColorAnimation { duration: 120 } }
                Rectangle { width: 20; height: 20; radius: 10; color: "#f4f7fb"; y: 3; x: row.on ? 23 : 3; Behavior on x { NumberAnimation { duration: 120 } } } }
            Text { visible: row.it.kind === "toggle"; anchors.right: sw.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                   text: row.it.on ? "now on" : "now off"; color: row.it.on ? Theme.good : Theme.faint; font.family: Theme.mono; font.pixelSize: 12 }
            // action (Update BIOS)
            Rectangle { visible: row.it.kind === "action"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: at.implicitWidth + 24; height: 30; radius: 8; color: Theme.warnBg
                Text { id: at; anchors.centerIn: parent; color: Theme.warn; font.family: Theme.body; font.pixelSize: 13; font.weight: Font.DemiBold
                       text: app.biosChecking ? "Checking…" : app.bios && app.bios.selectable ? "Update…" : (app.bios && app.bios.newest ? "Up to date" : "Unavailable") } }
        }
    }
}
