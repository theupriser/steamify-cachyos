// A button with the input's button name in front.
import QtQuick

Rectangle {
    id: btn
    property string k
    property string text
    property bool primary: false
    property bool focusRing: false
    signal clicked
    height: 48; radius: 12; width: row.implicitWidth + 36
    color: primary ? Theme.accent : Theme.button
    border.width: focusRing && enabled ? 2 : 0; border.color: Theme.textHi
    // Greyed out while there's nothing to do.
    opacity: enabled ? 1 : 0.4
    Row { id: row; anchors.centerIn: parent; spacing: 10
        Glyph { k: btn.k; visible: btn.k !== ""; dark: btn.primary; anchors.verticalCenter: parent.verticalCenter }
        Text { text: btn.text; color: btn.primary ? Theme.ink : Theme.text; font.family: Theme.body; font.pixelSize: 15; font.weight: Font.DemiBold
               anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { anchors.fill: parent; enabled: btn.enabled; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
}
