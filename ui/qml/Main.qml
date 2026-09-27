// Steamify v2: the window. The state and logic are in AppState.qml, each
// screen in its own file (menu -> review -> password -> applying -> done,
// and the BIOS warnings). Designed at 1280x720 and scaled to the window, so
// it fits a TV too.
import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic

ApplicationWindow {
    id: win
    required property var backend
    required property var gamepad
    required property bool fullscreen
    required property string iconUrl

    width: 1280; height: 720
    minimumWidth: 960; minimumHeight: 540
    visibility: fullscreen ? Window.FullScreen : Window.Windowed
    title: "Steamify"
    color: Theme.bg

    AppState {
        id: steamify
        backend: win.backend
        gamepad: win.gamepad
        // Keys go back to the screen when a text field's screen closes.
        onScreenChanged: if (screen !== "password" && screen !== "bios2") stage.forceActiveFocus()
    }

    // The 1280x720 stage, scaled to the window: stretched to the window's
    // own shape, so the bars reach the edges and the content fills it.
    Item {
        id: stage
        readonly property real k: Math.min(win.width / 1280, win.height / 720)
        width: win.width / k; height: win.height / k
        transformOrigin: Item.TopLeft
        scale: k
        focus: true
        Keys.onPressed: function (e) { steamify.keyPressed(e); }
        Keys.onReleased: function (e) { steamify.keyReleased(e); }

        Header { id: header; app: steamify; iconUrl: win.iconUrl }

        Item {
            id: content
            anchors.top: header.bottom; anchors.bottom: parent.bottom; width: parent.width
            MenuScreen { anchors.fill: parent; app: steamify; visible: steamify.screen === "menu" }
            ReviewScreen { anchors.fill: parent; app: steamify; visible: steamify.screen === "review" }
            PasswordScreen { anchors.fill: parent; app: steamify; visible: steamify.screen === "password" }
            ApplyingScreen { anchors.fill: parent; app: steamify; visible: steamify.screen === "applying" }
            BiosWarningScreen { anchors.fill: parent; app: steamify; visible: steamify.screen === "bios1" }
            BiosConfirmScreen { anchors.fill: parent; app: steamify; visible: steamify.screen === "bios2" }
            DoneScreen { anchors.fill: parent; app: steamify; visible: steamify.screen === "done" }
        }
    }
}
