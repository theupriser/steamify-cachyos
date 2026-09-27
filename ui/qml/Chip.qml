// A small label in capitals.
import QtQuick

Rectangle {
    id: chip
    property string text
    property color fg: Theme.good
    property color bgc: Theme.goodBg
    height: 24; radius: 6; width: ct.implicitWidth + 16; color: bgc
    Text { id: ct; anchors.centerIn: parent; text: chip.text.toUpperCase(); color: chip.fg
           font.family: Theme.body; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 0.6 }
}
