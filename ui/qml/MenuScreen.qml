// The menu: every item on the left, what the selected one does and the
// system on the right, Review & apply at the bottom.
import QtQuick
import QtQuick.Controls.Basic

Item {
    id: screen
    required property AppState app
    readonly property var g: Input.g

    Text {
        visible: app.items.length === 0
        anchors.centerIn: parent; color: Theme.mute; font.family: Theme.body; font.pixelSize: 18
        text: app.status.error ? "Couldn't read the current state:\n" + app.status.error : "Checking what's on…"
        horizontalAlignment: Text.AlignHCenter
    }

    Item {
        visible: app.items.length > 0
        x: 40; y: 28; width: parent.width - 80; height: parent.height - 28 - 64 - 20
        Column {
            width: 740; height: parent.height; spacing: 10
            Text { text: "What do you want?"; color: Theme.text; font.family: Theme.display; font.pixelSize: 30; font.weight: Font.DemiBold }
            ListView {
                id: list; width: parent.width; height: parent.height - 50; clip: true
                // A fixed model: sub-items fold in and out instead of the
                // list being rebuilt (and jumping) on every tick.
                model: app.items
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: MenuRow {
                    app: screen.app
                    width: list.width - 12; x: 2
                    onSelectedChanged: if (selected) Qt.callLater(list.positionViewAtIndex, index, ListView.Contain)
                }
            }
        }
        Column {
            x: 772; width: parent.width - 772; height: parent.height; spacing: 16
            DetailPanel { app: screen.app; width: parent.width; height: parent.height - sys.height - 16 }
            Rectangle {
                id: sys; width: parent.width; height: 82; radius: 16; color: Theme.card
                Grid { anchors.fill: parent; anchors.margins: 16; anchors.leftMargin: 20; anchors.rightMargin: 20; columns: 2; columnSpacing: 20; rowSpacing: 10
                    Repeater {
                        model: [["Kernel", (app.status.kernel || "").replace("-cachyos", "")],
                                ["LED bar", app.status.steamMachine ? (app.status.leds || 0) + " LEDs" : "—"],
                                ["HDMI-CEC", app.status.cecDevices ? "/dev/" + app.status.cecDevices.split(" ")[0] : "none"],
                                ["Version", app.status.version || ""]]
                        Row { required property var modelData; width: (sys.width - 60) / 2
                            Text { text: parent.modelData[0]; color: Theme.faint; font.family: Theme.body; font.pixelSize: 13; width: parent.width / 2 }
                            Text { text: parent.modelData[1]; color: Theme.text; font.family: Theme.mono; font.pixelSize: 13; width: parent.width / 2
                                   horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft } }
                    }
                }
            }
        }
    }

    Bar {
        Row {
            anchors.left: parent.left; anchors.leftMargin: 40; anchors.verticalCenter: parent.verticalCenter; spacing: 28
            Repeater {
                model: [[screen.g.toggle, "Toggle"], [screen.g.choose, "Choose"], [screen.g.reapply, "Re-apply what's on"], [screen.g.quit, "Quit"]]
                Row { required property var modelData; spacing: 8
                    Glyph { k: parent.modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: parent.modelData[1]; color: Theme.label; font.family: Theme.body; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter } }
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 40; anchors.verticalCenter: parent.verticalCenter; spacing: 16
            Text { readonly property int n: app.computePlan().length
                   text: n === 0 ? "Everything is the way you want it" : n + (n === 1 ? " change" : " changes")
                   color: Theme.faint; font.family: Theme.body; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
            Btn { k: screen.g.apply; text: "Review & apply"; primary: true; enabled: app.canApply
                  focusRing: app.sel === app.rows.length; height: 44; onClicked: app.goReview(false) }
        }
    }
}
