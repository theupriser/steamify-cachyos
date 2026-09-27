#!/usr/bin/env python3
# Steamify CachyOS: update notifications (installed by the "Update
# notifications" menu item, run by a systemd user timer and at each Plasma
# login). Never updates anything itself: when GitHub has a newer release
# than the last Steamify that ran here, it shows a notification (Open
# Steamify / Skip this version) and a tray icon until you open the app,
# skip the version or pick "Remind me later". Nothing runs in between.
import configparser
import json
import os
import subprocess
import sys
import threading
import time
import urllib.request

REPO = "theupriser/steamify-cachyos"
STATE_DIR = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
                         "steamify")
STATE = os.path.join(STATE_DIR, "notify.state")
DATA = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
RUN_APP = os.path.join(DATA, "steamify", "bin", "run-app")
RUN_TERMINAL = os.path.join(DATA, "steamify", "bin", "run-wizard")
RELEASE = f"https://github.com/{REPO}/releases/latest/download"


def version(v):
    try:
        return tuple(int(p) for p in v.lstrip("v").split("."))
    except ValueError:
        return None


def state(key):
    cp = configparser.ConfigParser(interpolation=None)
    cp.read(STATE)
    return cp.get("State", key, fallback="")


def set_state(key, value):
    # Same ini as lib/state.sh's state_set writes.
    subprocess.run(["kwriteconfig6", "--file", STATE, "--group", "State", "--key", key, value], check=False)


def latest():
    req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/releases/latest",
                                 headers={"User-Agent": "steamify-notifier", "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)["tag_name"].lstrip("v")


def pending(new):
    # Newer than the last Steamify that ran here, and not skipped.
    seen = version(state("seen") or "0")
    return seen is not None and version(new) > seen and new != state("skipped")


def desktop():
    # Only on the Plasma desktop: gamescope doesn't show notifications or a
    # tray, so an update found in gaming mode waits for the next desktop login.
    return subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "plasmashell"],
                          stdout=subprocess.DEVNULL).returncode == 0


def main():
    if "--delay" in sys.argv:
        time.sleep(int(sys.argv[sys.argv.index("--delay") + 1]))
    if not desktop():
        return 0
    try:
        new = latest()
    except Exception as e:  # offline, rate limited: try again next time
        print(f"Couldn't check for a new Steamify: {e}", file=sys.stderr)
        return 0
    if version(new) is None or not pending(new):
        return 0

    from PySide6.QtCore import QObject, QTimer, Signal
    from PySide6.QtGui import QAction, QIcon
    from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

    app = QApplication(sys.argv[:1])
    app.setApplicationName("Steamify")
    app.setDesktopFileName("steamify-ui")
    app.setQuitOnLastWindowClosed(False)
    icon = QIcon.fromTheme("steamify", QIcon.fromTheme("steam"))

    def open_app():
        # The way Steamify was last used (the app or the terminal menu), the
        # newest release either way; it records its version as seen, which
        # ends the reminder. In its own unit: this one's processes are
        # stopped when the check exits.
        if state("frontend") == "terminal":
            cmd = ["konsole", "-e", RUN_TERMINAL] if os.access(RUN_TERMINAL, os.X_OK) else \
                  ["konsole", "-e", "bash", "-c",
                   f"set -o pipefail; curl -fsSL --max-time 30 {RELEASE}/steamify.sh | bash; read -rp 'Press Enter to close. ' _"]
        else:
            cmd = [RUN_APP] if os.access(RUN_APP, os.X_OK) else \
                  ["bash", "-c", f"set -o pipefail; curl -fsSL --max-time 30 {RELEASE}/steamify-app.sh | bash"]
        # A scope lives as long as anything in it: the start script puts the
        # app in the background and exits.
        subprocess.Popen(["systemd-run", "--user", "--scope", "--collect", "--quiet", *cmd],
                         start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        app.quit()

    def skip():
        set_state("skipped", new)
        app.quit()

    tray = QSystemTrayIcon(icon)
    tray.setToolTip(f"Steamify {new} is available")
    menu = QMenu()
    for text, fn in ((f"Open Steamify {new}", open_app), ("Skip this version", skip), ("Remind me later", app.quit)):
        a = QAction(text, menu)
        a.triggered.connect(fn)
        menu.addAction(a)
    tray.setContextMenu(menu)
    tray.activated.connect(lambda reason: open_app() if reason == QSystemTrayIcon.ActivationReason.Trigger else None)
    tray.show()

    # The notification's buttons: notify-send waits for the click, so it
    # runs beside the event loop. Closing it without a click keeps the icon.
    class Relay(QObject):
        picked = Signal(str)
    relay = Relay()
    relay.picked.connect(lambda a: open_app() if a == "open" else skip() if a == "skip" else None)

    def notify():
        r = subprocess.run(["notify-send", "--app-name=Steamify", "--icon=steamify",
                            "-A", "open=Open Steamify", "-A", "skip=Skip this version",
                            f"Steamify {new} is available",
                            "Open Steamify to see what's new and choose what to update."],
                           capture_output=True, text=True)
        relay.picked.emit(r.stdout.strip())
    threading.Thread(target=notify, daemon=True).start()

    # Opened some other way (the shortcut, the terminal): the reminder is done.
    poll = QTimer()
    poll.timeout.connect(lambda: None if pending(new) else app.quit())
    poll.start(60_000)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
