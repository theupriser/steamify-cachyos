// The result of a run: all done, a problem, or nothing changed.
import QtQuick

Item {
    required property AppState app
    readonly property bool problem: app.failed.length > 0 || app.runError !== ""
    readonly property string message: {
        if (app.runError) return app.runError;
        if (!app.biosRun) return app.plan.length + (app.plan.length === 1 ? " change" : " changes") + " applied." + (app.restartNeeded ? " Some take effect after a restart." : "");
        if (app.failed.length) return "The BIOS was not changed.";
        return (app.bios && app.bios.dryRun ? "Dry run: nothing was flashed. " : "BIOS " + (app.biosInfo.newest || "") + " is staged and is written during the restart. ")
             + "Keep the power on and don't touch the machine until it has fully started again, even if the screen stays black.";
    }
    Column {
        anchors.centerIn: parent; width: 760; spacing: 20
        Rectangle { width: 72; height: 72; radius: 36; anchors.horizontalCenter: parent.horizontalCenter; color: problem ? Theme.warnBg : Theme.goodBg
            Text { anchors.centerIn: parent; text: problem ? "!" : "✓"; color: problem ? Theme.warn : Theme.good; font.pixelSize: 36; font.weight: Font.Bold } }
        Text { text: app.runError ? "Nothing changed" : (app.biosRun && app.failed.length ? "The BIOS update stopped" : (app.failed.length ? "Done, with a problem" : "All done"))
               color: Theme.text; font.family: Theme.display; font.pixelSize: 40; font.weight: Font.DemiBold; anchors.horizontalCenter: parent.horizontalCenter }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; color: Theme.soft; font.family: Theme.body; font.pixelSize: 17; text: message }
        Rectangle { visible: app.failed.length > 0; anchors.horizontalCenter: parent.horizontalCenter; width: ft.implicitWidth + 32; height: 44; radius: 12; color: Theme.warnBg
            Text { id: ft; anchors.centerIn: parent; color: "#f2c27a"; font.family: Theme.body; font.pixelSize: 14
                   text: "Had a problem: " + app.failed.map(function (id) { return Texts.label(id); }).join(", ") + ". See the details." } }
        Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 14; topPadding: 8
            Btn { k: Input.g.back; text: "Back to the menu"; height: 52; onClicked: app.act("back") }
            Btn { visible: app.restartNeeded; k: Input.g.ok; text: "Restart now"; primary: true; height: 52; onClicked: app.backend.restart() } }
    }
}
