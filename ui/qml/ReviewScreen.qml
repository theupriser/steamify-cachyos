// What a run will change, with a summary; Apply asks for the password.
import QtQuick
import QtQuick.Controls.Basic

Item {
    required property AppState app
    Column {
        x: 40; y: 32; width: 740; spacing: 14
        Text { text: app.plan.length === 0 ? "Nothing to change" : "This will"; color: Theme.text; font.family: Theme.display; font.pixelSize: 34; font.weight: Font.DemiBold }
        ListView {
            width: 740; clip: true; spacing: 8
            height: Math.min(contentHeight, parent.parent.height - 32 - 50 - 14 - 66 - 64 - 32)
            model: app.plan
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: Rectangle {
                id: step
                required property var modelData
                readonly property var st: Texts.actions[modelData.action] || ["", Theme.text, Theme.card]
                width: 740; height: 56; radius: 12; color: Theme.card
                Row { anchors.fill: parent; anchors.leftMargin: 18; spacing: 14
                    Chip { text: step.st[0]; fg: step.st[1]; bgc: step.st[2]; width: 84; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: Texts.label(step.modelData.id); color: Theme.textHi; font.family: Theme.body; font.pixelSize: 17; font.weight: Font.DemiBold
                           anchors.verticalCenter: parent.verticalCenter }
                    Badge { isNew: !!step.modelData.isNew; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        Rectangle { width: 740; height: 52; radius: 12; color: Theme.note
            Text { anchors.verticalCenter: parent.verticalCenter; x: 18; text: "Your password is asked once. Changes to how the PC starts need a restart."
                   color: Theme.soft; font.family: Theme.body; font.pixelSize: 14 } }
    }
    Rectangle {
        x: parent.width - 468; y: 32; width: 428; height: 250; radius: 16; color: Theme.card
        Column { anchors.fill: parent; anchors.margins: 24; spacing: 12
            Text { text: "SUMMARY"; color: Theme.faint; font.family: Theme.body; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 0.8 }
            Repeater { model: [["Turn on", "on"], ["Update", "update"], ["Re-apply", "again"], ["Turn off", "off"]]
                Row { required property var modelData; width: 380
                    Text { text: parent.modelData[0]; color: Theme.soft; font.family: Theme.body; font.pixelSize: 15; width: 300 }
                    Text { readonly property string action: parent.modelData[1]
                           text: app.plan.filter(function (p) { return p.action === action; }).length
                           color: Theme.text; font.family: Theme.mono; font.pixelSize: 15; width: 80; horizontalAlignment: Text.AlignRight } } }
        }
    }
    Bar {
        Btn { anchors.left: parent.left; anchors.leftMargin: 40; anchors.verticalCenter: parent.verticalCenter; k: Input.g.back; text: "Back to the menu"; onClicked: app.act("back") }
        Btn { anchors.right: parent.right; anchors.rightMargin: 40; anchors.verticalCenter: parent.verticalCenter; k: Input.g.ok; text: "Apply"; primary: true
              visible: app.plan.length > 0; onClicked: app.onApplyPressed() }
    }
}
