// BIOS update, warning 1: the risks and what was checked; Cancel is
// selected first.
import QtQuick

Item {
    required property AppState app
    Rectangle {
        x: 40; y: 28; width: parent.width - 80; height: parent.height - 28 - 64 - 24; radius: 16; color: Theme.dangerBg; border.width: 2; border.color: Theme.dangerLine
        Row { anchors.fill: parent; anchors.margins: 32; spacing: 40
            Column { width: 640; spacing: 16
                Row { spacing: 12
                    Rectangle { width: 44; height: 44; radius: 12; color: "#3a1c1f"
                        Text { anchors.centerIn: parent; text: "!"; color: Theme.bad; font.pixelSize: 26; font.weight: Font.Bold } }
                    Text { text: "BIOS update – entirely at your own risk"; color: "#ffd9d3"; font.family: Theme.display; font.pixelSize: 30; font.weight: Font.DemiBold
                           anchors.verticalCenter: parent.verticalCenter } }
                RiskList { width: 640 }
            }
            Rectangle { width: 440; height: 250; radius: 14; color: Theme.card
                Column { anchors.fill: parent; anchors.margins: 22; spacing: 12
                    Repeater { model: [["Current BIOS", app.biosInfo.current || ""], ["New BIOS", app.biosInfo.newest || ""], ["Checksum", "OK (Valve's package)"],
                                       ["Compatible", app.biosInfo.compatible === "yes" ? "Yes (checked by fwupd)" : "Not checked (dry run)"]]
                        Row { required property var modelData; width: 396
                            Text { text: parent.modelData[0]; color: Theme.faint; font.family: Theme.body; font.pixelSize: 15; width: 150 }
                            Text { text: parent.modelData[1]; color: parent.modelData[1].indexOf("Not") === 0 ? Theme.warn : Theme.text; font.family: Theme.mono; font.pixelSize: 15
                                   width: 246; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft } } }
                } }
        }
    }
    Bar {
        Text { anchors.left: parent.left; anchors.leftMargin: 40; anchors.verticalCenter: parent.verticalCenter; text: "Do you understand the risks and want to continue?"
               color: Theme.soft; font.family: Theme.body; font.pixelSize: 15 }
        Row { anchors.right: parent.right; anchors.rightMargin: 40; anchors.verticalCenter: parent.verticalCenter; spacing: 12
            Btn { k: app.biosFocus === 0 ? Input.g.ok : "◀"; text: "Cancel"; focusRing: app.biosFocus === 0; onClicked: app.biosCancel() }
            Btn { k: app.biosFocus === 1 ? Input.g.ok : "▶"; text: "I understand, continue"; focusRing: app.biosFocus === 1; color: Theme.danger
                  onClicked: app.biosContinue() } }
    }
}
