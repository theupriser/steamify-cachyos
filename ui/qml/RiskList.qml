// The BIOS update's risks.
import QtQuick

Column {
    id: list
    spacing: 8
    Repeater {
        model: ["A failed or interrupted BIOS update can leave the machine unable to start (bricked). Steamify, CachyOS and Valve take no responsibility for that.",
                "NEVER turn off the power, unplug the machine or press the power button while it updates, including the restart(s) afterwards.",
                "The screen can stay black for several minutes. Wait.",
                "Only on mains power, with all other programs closed."]
        Row { required property string modelData; spacing: 10; width: list.width
            Rectangle { width: 6; height: 6; radius: 3; color: Theme.bad; y: 9 }
            Text { text: parent.modelData; width: parent.width - 16; wrapMode: Text.WordWrap; color: Theme.soft
                   font.family: Theme.body; font.pixelSize: 15; lineHeight: 1.3 } }
    }
}
