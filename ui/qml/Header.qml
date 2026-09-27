// Logo, the screen's name (the version on the menu) and the machine.
import QtQuick

Rectangle {
    required property AppState app
    required property string iconUrl
    readonly property var titles: ({ review: "Review", password: "Password", applying: app.biosRun ? "BIOS update" : "Applying",
                                     done: "Done", bios1: "BIOS update", bios2: "BIOS update" })
    width: parent.width; height: 72; color: Theme.bar
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
    Row {
        anchors.left: parent.left; anchors.leftMargin: 40; anchors.verticalCenter: parent.verticalCenter; spacing: 14
        Image { source: iconUrl; width: 40; height: 40; sourceSize: Qt.size(80, 80); anchors.verticalCenter: parent.verticalCenter }
        Text { text: "Steamify"; color: Theme.text; font.family: Theme.display; font.pixelSize: 28; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
        Text { readonly property bool menu: app.screen === "menu"
               text: menu ? "v" + (app.status.version || "") : "/ " + titles[app.screen]
               color: Theme.faint; font.family: menu ? Theme.mono : Theme.body; font.pixelSize: menu ? 13 : 15; anchors.verticalCenter: parent.verticalCenter }
    }
    Rectangle {
        visible: app.status.steamMachine === true
        anchors.right: parent.right; anchors.rightMargin: 40; anchors.verticalCenter: parent.verticalCenter
        height: 34; radius: 17; color: "#1b2330"; width: mt.implicitWidth + 28
        Text { id: mt; anchors.centerIn: parent; text: "Steam Machine · CachyOS"; color: Theme.label; font.family: Theme.body; font.pixelSize: 14 }
    }
}
