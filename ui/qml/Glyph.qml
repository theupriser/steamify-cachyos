// A button name (A, Enter, OK...), round for a controller's face buttons.
import QtQuick

Rectangle {
    id: glyph
    property string k
    property bool dark: false
    height: 26; width: Math.max(26, gt.implicitWidth + 14)
    radius: (Input.type === "controller" || Input.type === "steam") && k.length === 1 ? 13 : 7
    color: dark ? Theme.ink : Theme.key
    Text { id: gt; anchors.centerIn: parent; text: glyph.k; color: glyph.dark ? Theme.accent : Theme.textHi
           font.family: Theme.body; font.pixelSize: 12; font.weight: Font.DemiBold }
}
