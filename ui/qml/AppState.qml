// State and logic of the app: menu -> review -> password -> applying -> done,
// and the BIOS update (check -> warning 1 -> warning 2 -> flash). The
// screens only show this and call its functions.
import QtQuick

Item {
    id: app
    required property var backend
    required property var gamepad

    property string screen: "menu"          // menu review password applying done bios1 bios2
    property double remoteAt: 0
    property var want: ({})
    property string boot: "gamescope"
    property int sel: 0                      // row index; rows.length = the Apply button
    property bool reapply: false
    property var plan: []                    // [{id, action, isNew}]
    property var steps: ({})                 // id -> "wait"|"run"|"ok"|"fail"
    property var failed: []
    property bool restartNeeded: false
    // Review & apply only when something would change; "Re-apply what's on"
    // is for when nothing did.
    readonly property bool canApply: computePlan().length > 0
    onCanApplyChanged: if (!canApply && sel === rows.length) sel = Math.max(0, rows.length - 1)
    property string runError: ""
    property bool wrongPassword: false
    property bool typing: false              // a text field has the keys
    property int doneCount: 0
    property string pending: "apply"         // what the password is for: apply | bios
    property string sessionPassword: ""      // kept between the BIOS steps only
    property var biosInfo: ({})
    property bool biosRun: false
    property bool biosChecking: false        // the invisible check before the warnings
    property int biosFocus: 0                // warning 1: 0 = Cancel, 1 = continue
    property real holdProgress: 0            // warning 2: hold A/OK for 5 s
    property bool holding: false
    readonly property alias log: logModel

    readonly property var status: backend.status || ({})
    readonly property var items: status.items || []
    readonly property var rows: items.filter(function (i) { return !i.parent || want[i.parent]; })
    readonly property var bios: status.bios || null

    signal passwordRequested()
    signal passwordRejected()
    signal passwordSubmitRequested()         // A/OK on the password screen

    ListModel { id: logModel }

    function nowOn(id) {
        for (var i = 0; i < items.length; i++) if (items[i].id === id) return items[i].on;
        return false;
    }
    function label(item) { return Texts.label(item.id, item.label); }
    function biosHint() {
        if (!bios) return "";
        if (!bios.newest) return "Now " + bios.current + ", newest unknown (offline?)";
        if (bios.current === bios.newest) return bios.current + " is up to date";
        return "Now " + bios.current + ", newest " + bios.newest + " · at your own risk";
    }
    function syncFromStatus() {
        reapply = false;
        var w = {};
        for (var i = 0; i < items.length; i++) w[items[i].id] = items[i].kind === "action" ? false : items[i].wanted;
        want = w;
        boot = nowOn("boot") ? "desktop" : "gamescope";
        if (sel > rows.length) sel = 0;
    }
    Connections { target: backend; function onStatusChanged() { if (app.screen === "menu" || app.screen === "done") app.syncFromStatus(); } }

    // --- Menu ---
    function toggle(id) {
        var cur = items.find(function (i) { return i.id === id; });
        if (cur && cur.kind === "toggle" && cur.selectable === false) return;
        var w = Object.assign({}, want);
        w[id] = !w[id];
        // The same rules as the terminal menu (toggle_component).
        if (id === "gaming" && !w.gaming) w.single = false;
        if (id === "single" && w.single) w.gaming = true;
        if (id === "nvidia") w.bigpicture = w.nvidia;
        if (id === "bigpicture" && w.bigpicture) w.nvidia = true;
        if (id === "machine") w.poweroff = w.machine;
        if (id === "poweroff" && w.poweroff) w.machine = true;
        if (id === "machine" && !w.machine) w.kpin = false;
        if (id === "kpin" && w.kpin) w.machine = true;
        if (id === "launcher" && items.some(function (i) { return i.id === "steamgame"; })) w.steamgame = w.launcher;
        if (id === "steamgame" && w.steamgame) w.launcher = true;
        want = w;
    }
    function computePlan() {
        var p = [];
        for (var i = 0; i < items.length; i++) {
            var it = items[i];
            if (it.kind !== "toggle") continue;
            if (it.parent && !want[it.parent]) { if (it.on) p.push({ id: it.id, action: "off" }); continue; }
            if (want[it.id] && !it.on) p.push({ id: it.id, action: "on", isNew: !!it["new"] });
            else if (!want[it.id] && it.on) p.push({ id: it.id, action: "off" });
            else if (want[it.id] && (reapply || it.update)) p.push({ id: it.id, action: reapply ? "again" : "update" });
        }
        var bootNow = nowOn("boot") ? "desktop" : "gamescope";
        if (want.gaming && boot !== bootNow) p.push({ id: "boot", action: boot === "desktop" ? "desktop" : "gaming" });
        return p;
    }
    function goReview(again) {
        if (!again && !canApply) return;
        reapply = again; plan = computePlan(); screen = "review";
    }
    function wantedIds() {
        var ids = [];
        for (var i = 0; i < items.length; i++)
            if (items[i].kind === "toggle" && want[items[i].id] && (!items[i].parent || want[items[i].parent])) ids.push(items[i].id);
        return ids;
    }

    // --- Password and apply ---
    function resetRun() { steps = {}; failed = []; restartNeeded = false; runError = ""; doneCount = 0; logModel.clear(); }
    function startApply(password) {
        resetRun();
        var s = {};
        for (var i = 0; i < plan.length; i++) s[plan[i].id] = "wait";
        steps = s;
        screen = "applying";
        backend.apply(wantedIds(), want.gaming ? boot : "", reapply, password || "");
    }
    function askPassword(forWhat) {
        pending = forWhat;
        if (!backend.needsPassword()) return false;
        wrongPassword = false; screen = "password"; passwordRequested();
        return true;
    }
    function onApplyPressed() {
        if (plan.length === 0) return;
        if (!askPassword("apply")) startApply("");
    }
    function submitPassword(p) {
        if (!backend.checkPassword(p)) { wrongPassword = true; passwordRejected(); return; }
        if (pending === "bios") { sessionPassword = p; biosCheck(); }
        else startApply(p);
    }
    function passwordBack() { screen = pending === "bios" ? "menu" : "review"; }

    // --- BIOS ---
    function startBios() {
        if (!bios || !bios.selectable) return;
        biosInfo = {}; sessionPassword = "";
        if (!askPassword("bios")) biosCheck();
    }
    function biosCheck() {
        // Invisible: stay on the menu (the BIOS row says "Checking…"),
        // then the first warning.
        failed = []; runError = ""; logModel.clear();
        plan = [{ id: "bios", action: "check" }];
        biosRun = true; biosChecking = true; screen = "menu";
        backend.biosPrepare(sessionPassword);
    }
    function biosCancel() { sessionPassword = ""; holdProgress = 0; holding = false; biosRun = false; syncFromStatus(); screen = "menu"; }
    function biosContinue() { holdProgress = 0; screen = "bios2"; }
    function biosFlash() {
        holdProgress = 0; holding = false;
        resetRun();
        plan = [{ id: "bios", action: "flash" }];
        steps = { bios: "wait" };
        biosRun = true; screen = "applying";
        backend.biosFlash(sessionPassword);
    }
    Timer {
        interval: 50; repeat: true; running: app.screen === "bios2" && app.holding
        onTriggered: { app.holdProgress = Math.min(1, app.holdProgress + 0.01); if (app.holdProgress >= 1) app.biosFlash(); }
    }

    function backToMenu() { biosRun = false; syncFromStatus(); screen = "menu"; }

    // --- Backend events ---
    function errorText(e) {
        return e === "wrong-password" ? "The password didn't work." : (e === "start" ? "Steamify couldn't start the changes." : (e ? "sudo isn't available." : ""));
    }
    Connections {
        target: app.backend
        function onEvent(ev) {
            var s = Object.assign({}, app.steps);
            if (ev.event === "start") { s[ev.id] = "run"; app.steps = s; }
            else if (ev.event === "done") { s[ev.id] = ev.ok ? "ok" : "fail"; app.steps = s; app.doneCount++; }
            else if (ev.event === "log") { logModel.append({ line: ev.line }); if (logModel.count > 400) logModel.remove(0); }
            else if (ev.event === "bios-ready") { app.biosChecking = false; app.biosInfo = ev; app.biosFocus = 0; app.holdProgress = 0; app.screen = "bios1"; }
            else if (ev.event === "finished" && app.biosChecking) {
                // The check found nothing to do or a problem: say so.
                app.biosChecking = false; app.sessionPassword = "";
                app.failed = ev.failed || []; app.restartNeeded = false;
                app.runError = ev.nothing && !ev.error ? "The BIOS is already the newest version." : app.errorText(ev.error);
                app.screen = "done";
            }
            else if (ev.event === "finished") {
                // A successful BIOS check ends with bios-ready instead, keeping
                // the password for the flash.
                app.sessionPassword = "";
                app.failed = ev.failed || []; app.restartNeeded = !!ev.restart;
                app.runError = app.errorText(ev.error);
                app.screen = "done";
            }
        }
        function onRemotePressed() { app.remoteAt = Date.now(); Input.type = "remote"; }
    }

    // --- Input: one set of actions for controller, keyboard and remote ---
    function act(a) {
        if (screen === "menu") {
            if (biosChecking) return;
            if (a === "up") sel = Math.max(0, sel - 1);
            // The greyed-out Apply button can't be selected.
            else if (a === "down") sel = Math.min(canApply ? rows.length : rows.length - 1, sel + 1);
            else if (a === "accept") {
                if (sel === rows.length) { goReview(false); return; }
                var r = rows[sel];
                if (r.kind === "action" && r.id === "bios") startBios();
                else if (r.kind === "choice") boot = boot === "gamescope" ? "desktop" : "gamescope";
                else if (r.kind === "toggle") toggle(r.id);
            }
            else if ((a === "left" || a === "right") && sel < rows.length && rows[sel].kind === "choice")
                boot = a === "left" ? "gamescope" : "desktop";
            else if (a === "apply") goReview(false);
            else if (a === "reapply") goReview(true);
            // B/Esc/Back don't quit: Steam's desktop layout sends Esc for a
            // Steam Controller's B, which should only ever go back.
            else if (a === "quit") Qt.quit();
        } else if (screen === "review") {
            if (a === "accept" || a === "apply") onApplyPressed();
            else if (a === "back") { reapply = false; screen = "menu"; }
        } else if (screen === "password") {
            if (a === "accept" || a === "apply") passwordSubmitRequested();
            else if (a === "back") passwordBack();
        } else if (screen === "bios1") {
            if (a === "left") biosFocus = 0;
            else if (a === "right") biosFocus = 1;
            else if (a === "accept") { if (biosFocus === 1) biosContinue(); else biosCancel(); }
            else if (a === "back") biosCancel();
        } else if (screen === "bios2") {
            if (a === "back") biosCancel();
            else if (a === "hold") holding = true;
            else if (a === "release") { holding = false; if (holdProgress < 1) holdProgress = 0; }
        } else if (screen === "done") {
            if (a === "accept" && restartNeeded) backend.restart();
            else if (a === "back" || a === "accept") backToMenu();
        }
    }
    Connections {
        target: app.gamepad
        function onButton(b) {
            if (b === "a_up") { if (app.screen === "bios2") app.act("release"); return; }
            if (b.slice(-3) === "_up") return;
            Input.type = "controller";
            if (b === "a" && app.screen === "bios2") { app.act("hold"); return; }
            var map = { a: "accept", b: "back", x: "apply", y: "reapply", start: "apply", up: "up", down: "down", left: "left", right: "right" };
            if (map[b]) app.act(map[b]);
        }
    }
    function keyPressed(e) {
        // A text field handles its own keys, except Escape and Enter.
        if (typing && e.key !== Qt.Key_Escape && e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter) return;
        var fromRemote = Date.now() - remoteAt < 400;
        if (screen === "bios2" && Input.type !== "keyboard" && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) {
            if (!e.isAutoRepeat) act("hold"); e.accepted = true; return;
        }
        if (!fromRemote) Input.type = Input.fromSteam ? "steam" : "keyboard";
        var k = e.key;
        if (k === Qt.Key_Up) act("up");
        else if (k === Qt.Key_Down) act("down");
        else if (k === Qt.Key_Left) act("left");
        else if (k === Qt.Key_Right) act("right");
        else if (k === Qt.Key_Space) act("accept");
        // Enter selects, like A on a controller: Steam's desktop layout sends
        // Enter for a Steam Controller's A (and Space for Y). Ctrl+Enter
        // goes straight to Review & apply.
        else if ((k === Qt.Key_Return || k === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) act("apply");
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) act("accept");
        else if (k === Qt.Key_Escape || k === Qt.Key_Back || k === Qt.Key_Backspace) { if (!e.isAutoRepeat) act("back"); }
        else if (k === Qt.Key_R) act("reapply");
        else if (k === Qt.Key_Q && (e.modifiers & Qt.ControlModifier)) act("quit");
        else return;
        e.accepted = true;
    }
    function keyReleased(e) {
        if (screen === "bios2" && !e.isAutoRepeat && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) act("release");
    }
}
