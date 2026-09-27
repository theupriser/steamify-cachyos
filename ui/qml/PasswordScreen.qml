// The sudo password, asked once per run; never stored.
import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: screen
    required property AppState app
    color: "#0c1016"
    function submit() { var p = pw.text; pw.text = ""; app.submitPassword(p); }

    Connections {
        target: screen.app
        function onPasswordRequested() { pw.text = ""; pw.shown = false; pw.forceActiveFocus(); }
        function onPasswordRejected() { pw.forceActiveFocus(); }
        function onPasswordSubmitRequested() { screen.submit(); }
    }
    Binding { target: screen.app; property: "typing"; value: pw.activeFocus; when: screen.visible }

    Rectangle {
        anchors.centerIn: parent; width: 560; height: col.implicitHeight + 72; radius: 20; color: Theme.card; border.width: 1; border.color: Theme.line
        Column {
            id: col; anchors.fill: parent; anchors.margins: 36; anchors.leftMargin: 40; anchors.rightMargin: 40; spacing: 18
            Row { spacing: 14
                Rectangle { width: 48; height: 48; radius: 14; color: Theme.infoBg
                    // A padlock.
                    Canvas { anchors.centerIn: parent; width: 24; height: 24
                        onPaint: { var c = getContext("2d"); c.strokeStyle = Theme.info; c.lineWidth = 1.8; c.beginPath(); c.roundedRect(4.5, 10.5, 15, 10, 2.5, 2.5); c.stroke();
                                   c.beginPath(); c.moveTo(8, 10.5); c.lineTo(8, 8); c.arc(12, 8, 4, Math.PI, 0); c.lineTo(16, 10.5); c.stroke(); } } }
                Column { spacing: 2; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Your password, once"; color: Theme.text; font.family: Theme.display; font.pixelSize: 30; font.weight: Font.DemiBold }
                    Text { text: "Steamify needs it to change system settings."; color: Theme.mute; font.family: Theme.body; font.pixelSize: 14 } }
            }
            Text { text: "Password for " + app.backend.user(); color: Theme.soft; font.family: Theme.body; font.pixelSize: 14; font.weight: Font.DemiBold }
            TextField {
                id: pw; width: parent.width; height: 52; echoMode: shown ? TextInput.Normal : TextInput.Password
                property bool shown: false
                color: Theme.textHi; font.family: Theme.body; font.pixelSize: 18; leftPadding: 16; rightPadding: 56
                placeholderText: "Password"; placeholderTextColor: "#6b778a"
                background: Rectangle { radius: 12; color: Theme.bg; border.width: 2; border.color: app.wrongPassword ? Theme.bad : Theme.accent }
                Keys.onReturnPressed: screen.submit()
                Keys.onEnterPressed: screen.submit()
                Keys.onEscapePressed: app.act("back")
                Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: pw.shown ? "Hide" : "Show"
                       color: Theme.label; font.family: Theme.body; font.pixelSize: 13
                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: pw.shown = !pw.shown } }
            }
            Text { visible: app.wrongPassword; text: "That password didn't work. Try again."; color: Theme.bad; font.family: Theme.body; font.pixelSize: 14 }
            Rectangle { width: parent.width; height: 46; radius: 12; color: Theme.note
                Text { anchors.verticalCenter: parent.verticalCenter; x: 14; color: Theme.soft; font.family: Theme.body; font.pixelSize: 14
                       text: ({ controller: "Press Steam + X for the on-screen keyboard.", keyboard: "Type your password and press Enter.", steam: "Press X for Steam's on-screen keyboard, type your password and press A.", remote: "Select the field for the on-screen keyboard." })[Input.type] } }
            Item { width: parent.width; height: 48
                Btn { k: Input.g.back; text: "Back"; onClicked: app.act("back") }
                Btn { anchors.right: parent.right; k: Input.g.ok; text: "Apply"; primary: true; onClicked: screen.submit() } }
            Text { text: "Only used for this run. Steamify never stores it."; color: Theme.faint; font.family: Theme.body; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }
}
