// Right of the menu: what the selected item does, or a nudge to review
// when the Apply button is selected.
import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: detail
    required property AppState app
    readonly property var it: app.sel < app.rows.length ? app.rows[app.sel] : null
    readonly property var tx: it ? Texts.of(it) : ({})
    radius: 16; color: Theme.card
    // Long texts scroll instead of running out of the card; each item
    // starts at the top.
    onItChanged: flick.contentY = 0

    Flickable {
        id: flick
        anchors.fill: parent; anchors.margins: 24; anchors.rightMargin: 12
        visible: detail.it !== null; clip: true
        contentHeight: col.implicitHeight; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
            id: col; width: flick.width - 12; spacing: 14
            Row { spacing: 10
                Chip { readonly property var it: detail.it
                       text: !it ? "" : it.kind === "choice" ? (app.boot === "desktop" ? "Desktop" : "Gaming") : it.kind === "action" ? "Opt-in" : (it.on ? "On" : "Off")
                       fg: it && it.on ? Theme.good : Theme.label; bgc: it && it.on ? Theme.goodBg : Theme.line }
                Chip { visible: !!detail.tx.experimental; text: "Experimental"; fg: Theme.warn; bgc: Theme.warnBg }
            }
            Text { text: detail.it ? app.label(detail.it) : ""; color: Theme.text; font.family: Theme.display; font.pixelSize: 26; font.weight: Font.DemiBold
                   wrapMode: Text.WordWrap; width: parent.width }
            Text { text: detail.tx.body || ""; color: Theme.soft; font.family: Theme.body; font.pixelSize: 15; lineHeight: 1.4; wrapMode: Text.WordWrap; width: parent.width }
            Text { text: "WHAT IT CHANGES"; color: Theme.faint; font.family: Theme.body; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 0.8; topPadding: 4 }
            Repeater { model: detail.tx.changes || []
                Text { required property string modelData; text: "•  " + modelData; color: Theme.soft; font.family: Theme.body; font.pixelSize: 14
                       wrapMode: Text.WordWrap; width: col.width } }
        }
    }
    Column {
        anchors.centerIn: parent; spacing: 8; visible: detail.it === null
        Text { text: app.computePlan().length === 0 ? "Everything is the way you want it" : "Review what will change"; color: Theme.text
               font.family: Theme.display; font.pixelSize: 24; anchors.horizontalCenter: parent.horizontalCenter }
        Text { text: "then apply it"; color: Theme.mute; font.family: Theme.body; font.pixelSize: 15; anchors.horizontalCenter: parent.horizontalCenter }
    }
}
