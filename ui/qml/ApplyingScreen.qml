// Progress: every step of the plan on the left, the log on the right.
import QtQuick
import QtQuick.Controls.Basic

Item {
    required property AppState app
    readonly property bool checking: app.biosRun && app.plan.length > 0 && app.plan[0].action === "check"
    Column {
        x: 40; y: 32; width: 560; spacing: 18
        Text { text: app.biosRun ? (checking ? "Checking the BIOS update" : "Installing the BIOS update") : "Applying your changes"
               color: Theme.text; font.family: Theme.display; font.pixelSize: 34; font.weight: Font.DemiBold }
        Rectangle { width: 560; height: 10; radius: 5; color: Theme.line
            Rectangle { height: 10; radius: 5; color: Theme.accent; width: app.plan.length ? parent.width * Math.min(1, (app.doneCount + 0.3) / app.plan.length) : 0
                        Behavior on width { NumberAnimation { duration: 300 } } } }
        Row { width: 560
            Text { text: "Step " + Math.min(app.plan.length, app.doneCount + 1) + " of " + app.plan.length; color: Theme.mute; font.family: Theme.body; font.pixelSize: 14; width: 280 }
            Text { text: "Don't turn off the PC"; color: Theme.mute; font.family: Theme.body; font.pixelSize: 14; width: 280; horizontalAlignment: Text.AlignRight } }
        ListView {
            width: 560; clip: true; spacing: 8
            height: parent.parent.height - 32 - 156 - 32
            model: app.plan
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            // Follow the progress: the running step stays in view.
            readonly property int running: app.plan.findIndex(function (p) { return app.steps[p.id] === "run"; })
            onRunningChanged: if (running >= 0) positionViewAtIndex(running, ListView.Contain)
            delegate: Rectangle {
                id: step
                required property var modelData
                readonly property string st: app.steps[modelData.id] || "wait"
                width: 560; height: 54; radius: 12; color: st === "run" ? Theme.cardSel : Theme.card
                border.width: st === "run" ? 2 : 0; border.color: Theme.accent
                Row { anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18; spacing: 14
                    Rectangle { width: 22; height: 22; radius: 11; anchors.verticalCenter: parent.verticalCenter
                        color: step.st === "ok" ? Theme.goodBg : (step.st === "fail" ? Theme.badBg : "transparent")
                        border.width: step.st === "wait" || step.st === "run" ? 2 : 0; border.color: step.st === "run" ? Theme.accent : "#343f50"
                        Text { anchors.centerIn: parent; text: step.st === "ok" ? "✓" : (step.st === "fail" ? "!" : ""); color: step.st === "ok" ? Theme.good : Theme.bad
                               font.pixelSize: 13; font.weight: Font.Bold }
                        RotationAnimator on rotation { running: step.st === "run"; from: 0; to: 360; duration: 1000; loops: Animation.Infinite } }
                    Row { width: 380; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        Text { text: (Texts.actions[step.modelData.action] || [])[3] + Texts.label(step.modelData.id)
                               color: step.st === "wait" ? Theme.faint : Theme.textHi; font.family: Theme.body; font.pixelSize: 16; font.weight: Font.DemiBold
                               anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                               width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + parent.spacing : 0)) }
                        Badge { id: badge; update: step.modelData.action === "update"; isNew: !!step.modelData.isNew; anchors.verticalCenter: parent.verticalCenter } }
                    Text { text: ({ wait: "Waiting", run: "Working…", ok: "Done", fail: "Problem" })[step.st]
                           color: step.st === "ok" ? Theme.good : (step.st === "fail" ? Theme.bad : Theme.label); font.family: Theme.body; font.pixelSize: 13
                           anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
    Column {
        x: 632; y: 32; width: parent.width - 672; height: parent.height - 64; spacing: 10
        Text { text: "DETAILS"; color: Theme.faint; font.family: Theme.body; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 0.8 }
        Rectangle { width: parent.width; height: parent.height - 30; radius: 16; color: "#0b0e13"; border.width: 1; border.color: "#1d2531"
            ListView { id: logView; anchors.fill: parent; anchors.margins: 18; clip: true; model: app.log
                onCountChanged: positionViewAtEnd()
                delegate: Text { required property string line; width: logView.width; text: line; color: "#aab5c4"; font.family: Theme.mono; font.pixelSize: 13; wrapMode: Text.WrapAnywhere } } }
    }
}
