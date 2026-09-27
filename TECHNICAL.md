# Technical details

How Steamify CachyOS works under the hood. For using it, see
[README.md](README.md); for problems, [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## How turning things on and off works

At startup every component checks whether it is on (`*_status` in `lib/`).
You choose; the wizard then turns off what you unticked (in reverse order)
and turns on what you ticked. To be able to undo:

- **System files** are backed up once, next to the original, with a
  `.bak-gamescope-wizard` suffix, and restored when you turn the component
  off.
- **KDE settings** in your home directory are recorded with their previous
  value the first time the wizard changes them, in an undo journal under
  `~/.local/state/steamify/`. Turning the component off writes
  the old values back (or removes keys that didn't exist before). Setups
  made by older versions of the script, without a journal, fall back to
  KDE's defaults.
- **Packages** installed for the conversion (Steam, gamescope-session, ...)
  are kept when you turn it off; Steam Machine support removes its own.

## Single user mode: SDDM, no locking

Turning it on switches to **SDDM** and turns off everything that asks for a
password or another user, per user: `action/lock_screen`, `switch_user` and
`start_new_session` restrictions in `kdeglobals`, no automatic locking
(`kscreenlockerrc`), Meta+L and Ctrl+Alt+Del unbound, and the launcher shows
only Sleep / Restart / Shut Down (kickoff `primaryActions=3`), which hides
the Session dropdown with Log Out. (Restricting `action/logout` would also
hide Restart and Shut Down.) Turning it off restores all of that and moves
the conversion back to plasma-login-manager.

**KDE wallet.** KDE normally unlocks your wallet with the password you log in
with; with autologin nobody types it, so apps that keep passwords in it (Brave,
for example) ask for the wallet password. Single user mode does what SteamOS
does: it uses Valve's empty wallet without a password (from
`steamdeck-kde-presets`, checksum verified). Your own wallet in
`~/.local/share/kwalletd/` is moved to `kdewallet.kwl.bak-steamify` (and
`.salt`). Turning single user mode off puts it back, unchanged; the single
user wallet, with anything saved in it meanwhile, is kept as
`kdewallet.kwl.steamify-single-user` and used again the next time it's on.
Passwords aren't shared between the two wallets.

**SDDM** is what SteamOS uses, and CachyOS's `steam-set-session` supports it
directly: it writes `/etc/sddm.conf.d/zz-steamos-autologin.conf`, which SDDM
honours. The script installs and enables `sddm` (active from the next boot),
writes `User=`, `Session=` and `Relogin=true` to
`/etc/sddm.conf.d/10-gamescope-autologin.conf`, and removes any
`[Autologin]` from `/etc/sddm.conf` (read last, so it would override both).
No sync bridge or sudoers rule is needed; the shortcut just runs
`steamos-session-select gamescope`, which logs out, and `Relogin=true` logs
straight back in to gamescope.

Without single user mode, the conversion uses **plasma-login-manager**
(CachyOS's default since March 2026), which needs the workarounds below.

## Why this is needed (plasma-login-manager)

CachyOS's `gamescope-session-cachyos` package ships `steamos-session-select`,
which is meant to work exactly like it does on real SteamOS. Since the March
2026 release, CachyOS uses `plasma-login-manager` instead of SDDM, and three
things get in the way:

1. **No `User=` written to the autologin config.**
   `steam-set-session` (called by `steamos-session-select`) only writes a
   `Session=` key. `plasma-login-manager` needs both `Session=` and `User=`
   to autologin at all; without `User=` it shows the greeter every boot.

2. **Missing `/etc/plasmalogin.conf.d` directory.**
   Without it, `steam-set-session` fails, and Steam's "Switch to Desktop"
   hangs forever. *(Fixed upstream in `gamescope-session-cachyos` 1.1.6; the
   script still creates the directory for older versions.)*

3. **The base `/etc/plasmalogin.conf` wins over conf.d, and CachyOS ships it
   with `Session=plasma`.**
   Every tool that changes sessions (`steamos-session-select`, Steam's power
   menu, and `cachyos-gamescope-autologin.service`, which resets you to
   gamescope after a desktop session) only writes
   `/etc/plasmalogin.conf.d/zz-steamos-autologin.conf`. The base file takes
   priority, so none of those switches stick.

The script sets `Session=`, `User=` and `Relogin=true` in the base config,
and installs a small systemd path watcher that copies whatever CachyOS's
tools write to the conf.d fragment into the base config.

## What each component changes

**SteamOS conversion** (`lib/login-manager.sh`, `lib/steam-desktop.sh`,
`lib/desktop-shortcut.sh`):

- installs missing packages: `gamescope-session-cachyos`, `steam`,
  `mangohud`, `xterm`, `ttf-liberation`, `wqy-zenhei`, `plasma-keyboard`;
- *SDDM (single user mode):* installs/enables SDDM and writes its autologin
  config;
- *plasma-login-manager:* creates `/etc/plasmalogin.conf.d`, backs up and
  rewrites the `[Autologin]` section of `/etc/plasmalogin.conf`, removes
  stray `zzz-steamos-autologin*.conf` files from manual troubleshooting
  (never `zz-steamos-autologin.conf`, which CachyOS's tools own), and
  installs `/usr/local/bin/sync-steamos-session.sh` plus
  `sync-steamos-session.path`/`.service`;
- `KWIN_IM_SHOW_ALWAYS=1` for the virtual keyboard and a
  `steam-desktop-autostart` systemd user service that starts Steam silently
  in Plasma only;
- the **Return to Gaming Mode** shortcut; on plasma-login-manager with a
  narrow sudoers rule (`/etc/sudoers.d/gamescope-session-switch`) so it can
  restart the login manager without a password prompt.

Turning it off restores `/etc/plasmalogin.conf` from its backup, removes the
SDDM autologin, sync bridge, shortcut, sudoers rule and Steam autostart, and
switches back to plasma-login-manager.

**Steam Deck/Machine icons:** `STEAM_GAMEPADUI_ARGS="-gamepadui -steamos3"`
in `~/.config/environment.d/` (and gamescope-session's own environment
file), which makes Steam show Steam Deck button glyphs in gaming mode.

## SteamOS desktop look

Installs CachyOS's `cachyos-vapor` package (the SteamOS Vapor theme the
CachyOS handheld edition uses) from the CachyOS repository and switches your
desktop to its Vapor global theme, including its desktop and window layout
(like ticking "Desktop and window layout" in System Settings): Vapor colors
and Plasma style, the SteamOS panel and launcher icon, and the Steam Deck
wallpaper. Run it from the Plasma desktop: applying the layout needs a
running Plasma session.

It also adds the SteamOS desktop extras that `cachyos-vapor` doesn't ship,
taken from the newest `steamdeck-kde-presets` on Valve's SteamOS mirror
(checksum verified) and installed to `/usr/local`:

- **Add to Steam** in the right-click menu of apps, AppImages and `.exe`
  files, and in the launcher: adds them to Steam as non-Steam games;
- **Nested Desktop**: add it to Steam from the launcher, then start it in
  gaming mode for a Plasma desktop inside gaming mode;
- the SteamOS **Return to Gaming Mode** icon (Steam logo with a return arrow);
- a window rule that keeps the **Steam keyboard** above other windows.

Turning it off restores your previous look and panel layout, and removes `cachyos-vapor` again
if the wizard installed it (and nothing else, like `cachyos-handheld`, needs it).

## Front LED bar (Steam Machine)

The **Steam Machine support** component, only shown on Fremont hardware
(DMI `Valve`/`Fremont`, or `OEM`/`F7F` on early units):

- installs an AUR helper (`yay`) if neither `yay` nor `paru` is present;
- installs the kernel headers for every installed kernel;
- installs `leds-valve-dkms-git` from the AUR - Valve's own driver from the
  SteamOS kernel - builds it for every installed kernel (so the LTS kernel
  works too), and loads it at every boot (`/etc/modules-load.d/leds-valve.conf`);
- adds a udev rule (`/etc/udev/rules.d/70-valve-leds-user.rules`) that gives
  your user the LED files, so Steam, which runs as you, can drive the bar;
- console-like power button: it puts the machine to sleep, and it never
  suspends by itself on mains power (the launcher's Shut Down still shuts down);
- installs and enables `steamos-manager`, the service Steam in gaming mode
  uses for hardware settings (fan, performance, and the HDMI-CEC settings
  when [HDMI-CEC](#hdmi-cec) is on); it recognises the Steam Machine from its
  DMI data.

Turning it off removes all of that again (the AUR helper is kept).

The LEDs appear as `/sys/class/leds/valve-leds*`. The driver's Makefile
builds against the running kernel (`uname -r`) instead of the kernel DKMS
builds for, so the wizard adds a DKMS override
(`/etc/dkms/leds-valve-dkms.conf`) that passes DKMS's target kernel in. With
it, DKMS rebuilds the driver whenever a kernel or its headers are installed
or upgraded. A newly added kernel doesn't come with its headers, so
`ensure-kernel-headers.service` checks at every boot and installs any
missing `-headers` package, which makes DKMS build the driver for it.

## HDMI-CEC

The **HDMI-CEC** item (on every PC; ticked by default only on a Steam
Machine) installs
Valve's CEC stack from its SteamOS `holo` repository, the newest `holo-X.Y`
on `steamdeck-packages.steamos.cloud`, each package checked against the
SHA-256 in Valve's package index:

- `cecd`, Valve's CEC daemon (a user service started with the desktop and
  gaming mode): TV remote keys become normal key presses (arrows, Enter,
  Back), and it turns the TV on and off with the PC;
- `cec-audio-control`: volume of the TV or receiver;
- `inputattach-cec-units` (with `linuxconsole` from CachyOS for
  `inputattach`): attaches USB CEC adapters (Pulse-Eight, RainShadow).

It works with any `/dev/cec*`: a GPU that has CEC on its HDMI port (the
Steam Machine; the CachyOS kernel has DisplayPort CEC built in) or a USB
adapter ([CEC.md](CEC.md) lists which PCs have one). The menu lists the CEC
devices found. Also turn on CEC on the TV
(Sony: BRAVIA Sync, Samsung: Anynet+, LG: SimpLink). On a Steam Machine
`steamos-manager` writes cecd's settings from Steam's (wake the TV, put it to
sleep), in `~/.config/cecd/config.d/`, and Steam shows its HDMI-CEC
settings; the wizard restarts steamos-manager so that happens right away.
CachyOS's gaming mode script (`/usr/lib/steamos/gamescope-session`) sets
`STEAM_ENABLE_CEC=0`, which hides those settings; Steam reads the script's
variables from `$XDG_RUNTIME_DIR/gamescope-environment`. HDMI-CEC adds a
drop-in for `steam-launcher.service`
(`/etc/systemd/user/steam-launcher.service.d/10-steamify-cec.conf`) with a
second `EnvironmentFile=` (`/etc/steamify/steam-cec.env`,
`STEAM_ENABLE_CEC=1`), which overrides it from the next gaming mode start.

It's experimental: on SteamOS itself CEC can wake the Steam Machine right
after it goes to sleep (Samsung TVs,
[SteamOS#2626](https://github.com/ValveSoftware/SteamOS/issues/2626)) and
upset CEC for the TV's other devices
([SteamOS#2817](https://github.com/ValveSoftware/SteamOS/issues/2817)).
Turning it off removes the packages again (`linuxconsole` only if the
wizard installed it).

## Power-off fix (Steam Machine)

With recent kernels a Steam Machine starts again right after powering off:
the newer 6.x, 7.0 and 7.1 updates and 7.2 (and probably every kernel after
it). Linux stopped clearing the S4/S5 wake bits at probe
(`pinctrl-amd: Don't clear S4 wake bits at probe`, in 7.2 and backported to
stable kernels), and the firmware leaves
that bit set on GPIO pin 18 (`_SB.PCI0.GPP6`). Valve's own kernel
(`linux-neptune-72`) clears it at probe on Fremont, in a patch marked not
for upstream ("until the firmware is fixed"), so CachyOS and mainline won't
get it.

The **Power-off fix** sub-option of Steam Machine support (ticked along with
it, can be unticked) builds a small module with DKMS for every installed
kernel, `steamify-fremont-poweroff` (source in
[`patches/steamify-fremont-poweroff.c`](patches/steamify-fremont-poweroff.c)).
It only loads on Fremont (DMI board name) and touches one register: right
before power-off (a `SYS_OFF_MODE_POWER_OFF_PREPARE` handler, after the
drivers have shut down) it clears that pin's S4/S5 wake bit. On a kernel
that already clears it, it does nothing. It logs the pin's state at load:
`dmesg | grep 'GPIO 18'`; `/sys/kernel/debug/gpio` shows the S4/S5 column.
Tested on a Steam Machine with `linux-cachyos-bore` 7.2.8: it stayed off
three times in a row, and rebooted right away with the module unloaded.

Where Steam Machine support was set up before 2.2.0, the menu ticks the
power-off fix as a new default sub-option (see feature versions below), so a
normal run adds it.

## Add as non-Steam game

A sub-option of the Steamify shortcut (`steamgame`, `lib/steam-game.sh`, new
in 2.5.1, ticked along with the shortcut): Steamify CachyOS in every Steam
account's non-Steam games (`~/.local/share/Steam/userdata/<id>/config/shortcuts.vdf`,
binary VDF, edited by `patches/steam-shortcuts.py`), starting the shortcut's
`run-app`, with the icon rendered as PNG (`~/.local/share/steamify/steamify.png`;
Steam shows no SVG). Why: while Steam runs, a Steam Controller only talks to
Steam, which gives its input to the game it started (Steam Input); on the
desktop through its desktop layout (A = Enter, B = Esc, Y = Space, X =
Steam's keyboard), in gaming mode as a gamepad.

Steam reads the list only at startup and writes it back on exit, so Steam is
closed (`steam -shutdown`) for the edit and started again (through
`steam-desktop-autostart.service` when it's there). That's refused in gaming
mode and when Steamify itself was started from Steam (`SteamGameId`), since
closing Steam would end it. An entry for the start script that's already
there (added by hand, or with the path from before 2.5.0) is updated, not
added twice; what was done is recorded per account (state `steamgame`:
`<account>=<appid> added|updated`) and a copy of each list is kept in the
state directory before the first change. Turning it off (or the shortcut)
removes every entry for the start script, since it can't start anything
without it.

Started from Steam, the app re-executes itself without Steam's overlay
(`LD_PRELOAD` of `gameoverlayrenderer.so` makes Qt abort) and
`steamify-app.sh` keeps it in the foreground (`SteamGameId`), or Steam
counts the game as ended right away and stops giving it the controller.

## Update notifications

The **Update notifications** option (new in 2.5.0, ticked by default)
installs `patches/steamify-notifier.py` as
`~/.local/share/steamify/bin/steamify-notifier` with two user
units in `~/.config/systemd/user`: `steamify-update-check.timer` (daily,
`Persistent=`) and `steamify-update-check.service` (also wanted by
`plasma-workspace.target`, so it checks a minute after each desktop login).
Nothing stays running while there's no update.

Every Steamify run records its version as `seen` (`notify.state`). The check
asks GitHub for the newest release; when it's newer than `seen` and not the
`skipped` version, it shows a notification (`notify-send` with the buttons
**Open Steamify** and **Skip this version**) and a tray icon (click: open;
menu: open, skip, remind me later). Closing the notification keeps the
icon; opening Steamify in any way records the new version and ends it. It
only runs on the Plasma desktop: gamescope shows no notifications or tray,
so an update found in gaming mode waits for the next desktop login. It never
installs anything: the shortcut always starts the newest release, which then
shows what's new or updated for this install.

## VRAM booster

SteamOS 3.9 manages the dGPU's VRAM per cgroup: the game in front is
protected, background apps are evicted first. Without it a game that needs
most of the VRAM (8 GB on the Steam Machine) can be pushed into system RAM
by the desktop and other apps, and stutter. The kernel side is the `dmem`
cgroup controller (7.2); amdgpu and Intel's xe register their VRAM with it
(`drm/<pci>/vram`), NVIDIA's open kernel modules from driver 615 too
(`nvidia/<pci>/vidmem`); `dmemcg-booster` protects every region it lists,
whatever its name. NVIDIA's closed modules don't: with such a card the option is shown greyed
out with what to do (`vram_nvidia_case`): open modules older than 615 ->
update; the closed driver on a card the open one supports (not in chwd's
legacy lists `/var/lib/chwd/ids/nvidia-{580,470,390}.ids`) -> the `chwd`
commands to switch, never switched by Steamify itself (a failed switch
means a black screen, and it can't be tested here); a legacy card or
nouveau -> not supported. Shown greyed
out, with why, until its driver lists a region: then it's offered like any
other (`WIZARD_VRAM_FAKE_NVIDIA=1` fakes the grey-out, `WIZARD_VRAM_CAPACITY=<file>`
reads the regions from a copy, for tests). Otherwise
the **VRAM booster** option is only shown when
`/sys/fs/cgroup/dmem.capacity` lists a VRAM region (`vram`, or `vidmem`
as other drivers name it, numbered with several) of at least 2 GB (a
dedicated GPU; an integrated one registers a small carve-out) or it's already on, and is
ticked by default; new in 2.3.0, so setups with the SteamOS conversion on
get it ticked. CachyOS packages the userspace side, which it installs:

- `dmemcg-booster`: `dmemcg-booster-system.service` enables the `dmem`
  controller and sets `dmem.low` for the cgroup in front;
  `dmemcg-booster-user.service` runs in the user session.
- `plasma-foreground-booster`: tells it which window is in front on the
  desktop. It only starts with `autostart=true` under `[Foreground Booster]`
  in `kcgroupsrc`, which the wizard sets (and reverts).

Check it with `cat /sys/fs/cgroup/cgroup.subtree_control` (lists `dmem`) and
the `dmem.low` of the slices under `user@<uid>.service`. Turning it off
disables the services and removes the packages the wizard installed.
Not added: a fixed `dmem.max` cap for `app.slice` (as some guides do); only
worth it if the booster itself turns out to cause stutter.

## Feature versions (updates)

Each component has a feature version (`FEATURE_VERSION` in `lib/menu.sh`):
the Steamify version in which what it sets up last changed (2.1.0 for
everything that hasn't changed since). After a component is turned on
successfully, that version is recorded in `~/.local/state/steamify/features.state`
(turning it off records `off`). Whether a component is on is always checked
on the system itself; the version only decides about updates:

- **On, recorded version older** than the current one: ticked and
  re-applied by a normal run; the plan (and the app's review) says
  "update". A setup from before versions were recorded counts as 2.1.0,
  so on a machine set up with 2.1.0, Steam Machine support (2.2.0) is
  updated.
- **A new default option** (not in `NO_PRESELECT`) whose parent is on (for
  a top-level one: the SteamOS conversion) and that was never turned on or
  off: ticked, so a normal run adds it. Turning it off once records `off`,
  so it isn't ticked again. The menu and the app show it with a **New**
  badge, and the plan says "new in this version".

Set a component's entry to the new `VERSION` whenever what its
`<id>_enable` sets up changes.

## BIOS updates (Steam Machine)

The **Update BIOS** item is only shown on a Steam Machine and is never ticked
by default. It shows the BIOS version you have now and the newest one Valve
ships (the `.cab` file in its `fremont-hw-support` package, looked up on
Valve's SteamOS mirror):

```
 [ ] Update BIOS: now F7F0107, newest F7F0108 (own risk)  (opt-in, runs once)
```

It can only be ticked when Valve has a newer BIOS than yours; when you're up
to date, when the newest version can't be looked up (offline), or when an
update is already waiting for a restart, it's greyed out.

When you run it, the wizard:

1. downloads Valve's package and checks its **SHA-256** against Valve's
   repository, so it's exactly Valve's file;
2. asks **fwupd** whether the firmware is for this very machine (fwupd compares
   the firmware's hardware IDs with the device) and stops if it isn't;
3. shows a large red **warning** with the current and the new version, and asks
   whether you understand the risks (default: no);
4. shows the warning **again** and only continues when you type `UPDATE`;
5. hands the firmware to fwupd, which writes it during the **next restart**:
   choose "restart now" or restart later yourself.

**At your own risk:** a failed or interrupted BIOS update can leave the machine
unable to start. Keep it on mains power, and never turn off the power, unplug
it or press the power button while it updates, including during the restart;
the screen can stay black for several minutes.

To walk through it without flashing anything, run the wizard with
`WIZARD_BIOS_DRY_RUN=1`: it downloads and checks the package and shows both
warnings, skips fwupd's device check, and only prints the install command.

## Where Steamify keeps its files

In the home folder, everything is under `steamify`:

| Where | What |
|---|---|
| `~/.local/state/steamify/` | State (`*.state`), undo journals (`*.journal`), the saved panel layout (`theme-layout/`) |
| `~/.local/share/steamify/app/` | The app (`steamify-app.sh` downloads it here) |
| `~/.local/share/steamify/bin/` | The shortcut's start scripts (`run-app`, `run-wizard`) and `steamify-notifier` |
| `~/.local/share/icons/hicolor/scalable/apps/steamify.svg` | The shortcut's icon |
| `~/.local/share/applications/steamify-*.desktop` | The launcher entries |
| `~/.config/systemd/user/` | `steamify-update-check.*`, `steam-desktop-autostart.service` |

System-wide: `/usr/local/lib/steamify/` (kernel headers script),
`/usr/src/steamify-*` (DKMS modules), `/var/cache/steamify/kernel` (the old
kernel pin's packages), and `*.bak-gamescope-wizard` backups next to the
system files that were edited (that name stays: it's how they're found again).

Before 2.5.0 the home folder paths used the project's old name
(`cachyos-gamescope-boot`). `migrate_layout` (`lib/state.sh`) moves them at
every start of a newer version, once, and leaves symlinks under the old names
so an older release still finds the same state; it fixes the paths in the
launcher entries and the update check's unit, and merges when both exist.
The headers script moves when Steam Machine support is set up again.

## Manual session control

```bash
steamos-session-select gamescope   # switch to gamescope right now
steamos-session-select plasma      # switch to desktop right now
steamos-session-select persistent  # remember the last-used session across reboots
steamos-session-select oneshot     # always start in gamescope (default, like a Deck)
```

With `Relogin=true`, a gamescope session that fails to start is restarted
immediately, which can turn into a loop - see
[TROUBLESHOOTING.md](TROUBLESHOOTING.md) for the way out.

## Project layout

| File | Responsibility |
|---|---|
| `steamify.sh` | Entry point: checks, menu, apply, summary, restart |
| `lib/menu.sh` | The menu: detect, toggle, plan and apply changes |
| `lib/state.sh` | Undo journal for KDE settings (`kset`/`krevert`) |
| `lib/common.sh` | Output helpers, prompts, backups, plasmashell handling |
| `lib/packages.sh` | Required packages, AUR helper (yay/paru) |
| `lib/boot-session.sh` | Boot into gamescope or the desktop (`steamify-boot-desktop.service`) |
| `lib/login-manager.sh` | SteamOS conversion: SDDM or plasmalogin autologin, sync bridge |
| `lib/steam-desktop.sh` | Steam in the Plasma session; Steam Deck/Machine icons |
| `lib/desktop-shortcut.sh` | Return to Gaming Mode shortcut and its sudoers rule |
| `lib/vapor-theme.sh` | SteamOS theme: installs and switches to `cachyos-vapor` |
| `lib/steamos-extras.sh` | SteamOS desktop extras from Valve's package (Add to Steam, Nested Desktop, icon, keyboard rule, KWallet) |
| `lib/single-user.sh` | Single user mode: no lock screen, user switching or log out |
| `lib/wizard-shortcut.sh` | Steamify shortcut: desktop icon and launcher entry that run the newest release |
| `lib/bios.sh` | Update BIOS (Steam Machine, opt-in): current/newest version, double confirmation, fwupd |
| `lib/cec.sh` | HDMI-CEC: Valve's `cecd` and friends from its `holo` repository |
| `lib/steam-machine.sh` | Steam Machine support: LED driver, LED access, steamos-manager |
| `lib/fremont-poweroff.sh` | Steam Machine support: the power-off fix (DKMS module from `patches/`) |
| `lib/steam-game.sh` | Add as non-Steam game: Steamify in the Steam library (`patches/steam-shortcuts.py`) |
| `lib/update-notifier.sh` | Update notifications: the notifier from `patches/` and its user timer |
| `lib/vram-booster.sh` | VRAM booster (`dmemcg-booster`, `plasma-foreground-booster`) |
| `services/` | The systemd units the scripts install (`service_file`, `@KEY@` placeholders); see its README |
| `patches/` | Module sources and patches the scripts build or apply (`patch_file`); see its README |
| `.github/tools/bundle.sh` | Builds the single-file version (`dist/steamify.sh`), with `patches/` and `services/` embedded |
| `.github/workflows/bundle.yml` | Builds and checks it on every push; publishes it on `main` |

The single-file version is generated: on every push to `main`, GitHub
Actions runs `.github/tools/bundle.sh`, checks the result with `bash -n` and
shellcheck, and publishes it as a release per version (tag `v<VERSION>`,
never overwritten; the newest is marked latest, and the `latest` tag follows
it). It inlines
`lib/*.sh` and wraps the entry point in `main()`, so bash has read the whole
file before anything runs; when stdin is a pipe (`curl | bash`) it reattaches
the terminal for the menu (set `WIZARD_KEEP_STDIN=1` to keep piped input).

Notes for contributors and AI coding agents are in [`AGENTS.md`](AGENTS.md).

## Caveats

- This works around CachyOS/`plasma-login-manager` behavior as of September
  2026. If CachyOS fixes `steam-set-session` upstream, parts of this script
  become unnecessary - please open an issue or PR if you notice that.
- Tested on a Valve Steam Machine running CachyOS Desktop edition. It should
  work on any CachyOS desktop install using `plasma-login-manager`, but
  hasn't been tested on Steam Deck/Legion Go hardware.

## Related upstream reports

- [CachyOS/gamescope-session#9](https://github.com/CachyOS/gamescope-session/issues/9) - "Switch to Desktop" hang due to missing `/etc/plasmalogin.conf.d`
