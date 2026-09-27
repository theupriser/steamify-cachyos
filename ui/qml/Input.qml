// The input in use (controller, keyboard or remote) and the button names
// shown for it.
pragma Singleton
import QtQuick

QtObject {
    property string type: "keyboard"
    // Started from Steam: keys come from a Steam Controller through Steam's
    // desktop layout (A = Enter, B = Esc, Y = Space, X = Steam's keyboard),
    // shown as "steam" with the controller's buttons.
    property bool fromSteam: false
    readonly property var glyphs: ({
        controller: { toggle: "A", choose: "◀ ▶", reapply: "Y", quit: "", apply: "X", ok: "A", back: "B" },
        keyboard: { toggle: "Enter", choose: "← →", reapply: "R", quit: "Ctrl+Q", apply: "Ctrl+Enter", ok: "Enter", back: "Esc" },
        steam: { toggle: "A", choose: "◀ ▶", reapply: "", quit: "", apply: "↓ A", ok: "A", back: "B" },
        remote: { toggle: "OK", choose: "◀ ▶", reapply: "Red", quit: "", apply: "↓ Apply", ok: "OK", back: "Back" }
    })
    readonly property var g: glyphs[type]
}
