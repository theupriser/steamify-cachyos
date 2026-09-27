// BIOS update, warning 2 (last chance): type UPDATE on a keyboard, or hold
// A/OK for 5 seconds on a controller or remote.
import QtQuick
import QtQuick.Controls.Basic

Item {
    id: screen
    required property AppState app
    onVisibleChanged: if (visible) { typed.text = ""; if (Input.type === "keyboard") typed.forceActiveFocus(); }
    Binding { target: screen.app; property: "typing"; value: typed.activeFocus; when: screen.visible }

    Rectangle {
        anchors.centerIn: parent; width: 760; height: col.implicitHeight + 64; radius: 20; color: Theme.dangerBg; border.width: 2; border.color: Theme.dangerLine
        Column { id: col; anchors.fill: parent; anchors.margins: 32; spacing: 18
            Text { text: "Last chance: this flashes BIOS " + (app.biosInfo.newest || ""); color: "#ffd9d3"; font.family: Theme.display; font.pixelSize: 32; font.weight: Font.DemiBold }
            Text { width: parent.width; wrapMode: Text.WordWrap; color: Theme.soft; font.family: Theme.body; font.pixelSize: 16; lineHeight: 1.3
                   text: "After this, keep the power on until the machine has fully started again. Don't touch it, even if the screen is black." }
            Column { visible: Input.type === "keyboard"; width: parent.width; spacing: 8
                Text { text: "Type UPDATE (in capitals) and press Enter to flash the BIOS:"; color: Theme.text; font.family: Theme.body; font.pixelSize: 15; font.weight: Font.DemiBold }
                TextField { id: typed; width: 320; height: 50; color: Theme.textHi; font.family: Theme.mono; font.pixelSize: 20; leftPadding: 14
                    placeholderText: "UPDATE"; placeholderTextColor: "#6b5a5a"
                    background: Rectangle { radius: 10; color: Theme.bg; border.width: 2; border.color: typed.text === "UPDATE" ? Theme.bad : "#5a3a3a" }
                    Keys.onReturnPressed: if (text === "UPDATE") app.biosFlash()
                    Keys.onEnterPressed: if (text === "UPDATE") app.biosFlash()
                    Keys.onEscapePressed: app.biosCancel() } }
            Column { visible: Input.type !== "keyboard"; width: parent.width; spacing: 10
                Text { text: "Hold " + Input.g.ok + " for 5 seconds to flash the BIOS. Let go to stop."; color: Theme.text; font.family: Theme.body; font.pixelSize: 15; font.weight: Font.DemiBold }
                Rectangle { width: parent.width; height: 14; radius: 7; color: "#3a2224"
                    Rectangle { height: 14; radius: 7; color: Theme.bad; width: parent.width * app.holdProgress } } }
            Row { spacing: 12
                Btn { k: Input.g.back; text: "Cancel"; onClicked: app.biosCancel() }
                Text { visible: app.bios && app.bios.dryRun; text: "Dry run: nothing will be flashed."; color: Theme.warn; font.family: Theme.body; font.pixelSize: 14
                       anchors.verticalCenter: parent.verticalCenter } }
        }
    }
}
