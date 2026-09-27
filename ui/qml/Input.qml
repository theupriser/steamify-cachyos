// The input in use (controller, keyboard or remote) and the button names
// shown for it.
pragma Singleton
import QtQuick

QtObject {
    property string type: "keyboard"
    readonly property var glyphs: ({
        controller: { toggle: "A", choose: "◀ ▶", reapply: "Y", quit: "B", apply: "X", ok: "A", back: "B" },
        keyboard: { toggle: "Space", choose: "← →", reapply: "R", quit: "Esc", apply: "Enter", ok: "Enter", back: "Esc" },
        remote: { toggle: "OK", choose: "◀ ▶", reapply: "Red", quit: "Back", apply: "↓ Apply", ok: "OK", back: "Back" }
    })
    readonly property var g: glyphs[type]
}
