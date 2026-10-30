# Changelog

All notable changes, per version and per commit. Versions follow
[Semantic Versioning](https://semver.org/); the current one is `VERSION` in
`steamify.sh`. Versions before 0.7.0 were numbered afterwards,
one per merged pull request.

## 2.16.0 - 2026-10-15

- **chore: bump VERSION to 2.15.0 (now 2.16.0): this release was 2.14.0 (GNOME support, NVIDIA); 2.14.0 is now the Steam Beta, Wi-Fi firmware and Wake-on-LAN release. The GNOME theme's and the SteamOS conversion's feature versions follow**
- **feat: GNOME support (the "SteamOS theme for GNOME" option, GDM session switching, the GNOME launcher/notifier/tray behaviour): the Vapor colors, the Steam Deck wallpaper, Ubuntu Dock, Tiling Assistant, Desktop Icons NG, AppIndicator and Steamify's own Vapor shell extension, with Switch to Desktop remembering KDE or GNOME. Prototype work since 2.12.0: `5dfc916`, `fc28ea4`, `ae12c1b`, `2b84e6a`, `c5b59d9`, `62a30e6`, `039f269`, `12eb562`, `c7f5f51`, `7904833`, `ce1aa1b`, `ab3b581`, `eaa3f28`, `4221ae6`, `8432f63`, `09ef0b1`, `68342e7`, `0e0bf57`, `7a84b0d`, `dbaeaa1`**
- `2ca288d` **fix: the NVIDIA gaming mode setup no longer fails with "the patched gamescope doesn't start" on a gamescope that works: the smoke test judged gamescope's exit status through a pipe into `grep -q` under `pipefail`, so gamescope's crash on the closed pipe (or a hung shutdown) counted as a failed test, intermittently, for the CPU-specific and the generic build alike (seen on an RTX 5080). The test now reads gamescope's output from a file and kills a hung shutdown (`timeout -k`)**
- `645b331` **feat: the GNOME theme installs GNOME Settings with the "GNOME Desktop" panel (dock, desktop icons, tiling) as a prebuilt package, downloaded from the `settings` release of steamify-gnome-theme (built by GitHub Actions on current Arch, rebuilt weekly) and checked against its `.sha256`; a failure keeps the stock Settings. Turning the theme off puts the stock `gnome-control-center` back. Installs with the GNOME theme on re-apply it (feature version 2.14.0)**
- **fix: the app's logo (an SVG) shows on a fresh install: `pyside6` doesn't depend on `qt6-svg`, Qt's SVG plugin, so without it the header logo was empty and the window had no icon of its own; it is installed with PySide6 (the app's installer, the launcher, the update notifier)**
- **fix: the app's icon shows in GNOME's dock on a fresh install: GNOME couldn't draw the SVG (a blank icon: "Could not load a pixbuf from icon theme"), by path or by name. The app's installer and the launcher put a 256x256 PNG (`assets/steam-gaming-settings.png`, a release file next to the SVG) in the user's icon theme and the launchers refer to it by name; the SVG stays as the fallback for releases without the PNG**

- **feat: after the GNOME theme is applied in a GNOME session, the app's done screen has "Restart GNOME" (GNOME Shell on Wayland can't restart in place, and the dock, extensions and Settings panel only show after a new login): with GDM autologin (the SteamOS conversion) Steamify's relogin helper logs the user straight back into the session they were in (without changing the session gaming mode's boot goes back to), else it is a plain logout (`gnome-session-quit`)**
- **fix: the app on a desktop (a window, however large, also fullscreen) keeps the desktop's own scale instead of blowing its 1280x720 layout up to the screen's height (twice as big on a 1440p or ultrawide monitor): the layout fills the window at the scale of GNOME or KDE, and only a window smaller than 1280x720 shrinks it. The TV mode (`--fullscreen`, gamescope) still scales to the screen**
- **fix: in the app a click on a row only selects it (a second click on the selected row used to flip it, so a click on a switch needed two); a click on the switch itself, or on the BIOS update button, acts at once and selects the row too**
- **feat: a run that only needs a new GNOME login (the theme, no reboot) ends with a countdown on the done screen ("Restarting GNOME in 10 s", with Restart GNOME now and Cancel) and then logs in again by itself, the counterpart of KDE restarting plasmashell (GNOME Shell on Wayland is the compositor too and can't restart in place). A run that needs a reboot keeps "Restart now" (it loads GNOME fresh): before, the Restart GNOME button was hidden then, and nothing started by itself**
- **fix: Restart GNOME logs in to GNOME: after the SteamOS conversion the account's session is gaming mode, and the relogin went there (a restart that took a minute: Steam starting in gaming mode). `steamify-gdm-relogin` takes the session to log in to (the one the app runs in) for this login only and puts the account's session, the one the next boot goes to, back once the new session is up**
- **fix: turning the GNOME theme off also removes the dock's and tiling's settings schemas that were copied to `~/.local/share/glib-2.0/schemas` for GNOME Settings' panel (they stayed behind, for extensions that were gone). Desktop Icons NG and AppIndicator stay: they belong to the SteamOS conversion (the desktop shortcut and Steam's tray icon)**
- **fix: turning everything off gives GNOME back what Steamify added for the desktop and tray icons: Desktop Icons NG and AppIndicator (and Extension Manager), which the SteamOS conversion and now the GNOME theme both need. When the last of the two is turned off, the two extensions leave the user's list of enabled extensions and the packages Steamify installed (noted in `gnomeextras.list` before installing, so packages the user had stay) are removed; while the other one is still on they stay, and are enabled again (the theme's undo puts back the list it found). Before, nothing removed them. The theme installs them itself too**
- **feat: the GNOME theme puts the dock at the bottom of the screen (Ubuntu's own default is the left); it can still be moved in GNOME Settings > GNOME Desktop (the Dock panel)**
- **feat: the GNOME theme puts the desktop icons at the top right (Desktop Icons NG's start corner, like Ubuntu and macOS) and clears the saved positions of Steamify's own launchers (Return to Gaming Mode, Steamify, Steam) so they are placed from there, in name order; the user's own files keep theirs. Turning the theme off puts the start corner back**
- `7b45731` **chore: GNOME support is 2.14.0 (was 2.13.0): VERSION, the GNOME theme's feature version and the changelog heading**
- **chore: merge 2.13.1 into 2.14.0: the GNOME session tools and GDM now sit next to plasma-login-manager only (no SDDM), with 2.13's relogin helper and greeter session, the "Switch to Gaming Mode" shortcut name (also for GNOME's desktop icon and app grid entry) and the restored `gsn_enable`**
- `66036ef` **refactor: Valve's package mirror in one module (`lib/valve-mirror.sh`: newest repo, package database fields, checksummed download); the SteamOS extras, CEC driver, BIOS lookup and os-release version used four copies**
- `93510fd` **refactor: the rules between menu items are three tables (`REQUIRES`, `FOLLOWS`, `EXCLUDES` in `lib/menu.sh`) used by the menu's toggles and, as `normalize_wanted`, by the app's selection (it had its own copy of the rules). The app now also ticks the Steamify shortcut for "Add as non-Steam game" and unticks the game entry with it, like the menu**
- `3036400` **refactor: the entry point picks its mode once (`MODE`) and `--defaults` and `--boot` are functions with one failure report, instead of four booleans and two copies of the apply-and-report code; `NO_COLOR` gives plain output**
- `2899eb2` **refactor: `is_wanted` and `is_current` instead of repeated `[[ "${WANTED[x]}" == 1 ]]` checks in the menu, the app's backend and the entry point**
- `93df406` **refactor: the start of every item's JSON (id, label, hint, kind, parent) is built in one place (`json_item_head`) for the app and the installer page, and `json_bool` replaces the `&& echo true || echo false` copies**
- `be207c4` **ci: a Lint workflow runs shellcheck on the modules and helper scripts, ruff on the app and `patches/*.py` (`ruff.toml`) and qmllint on the QML (not blocking until it has run once on the runner); `make lint` runs the same locally**
- `91a6f2d` **refactor: `best_effort` for the steps whose failure doesn't matter (stopping or disabling units, removing packages, `modprobe -r`, ...): same behaviour, but their errors go to `~/.local/state/steamify/log/steamify.log` instead of `/dev/null`; temp dirs are registered with `make_tmpdir` and removed by the one exit handler (also when a run is interrupted), which replaces the menu's own `EXIT` trap**
- `b1de97a` **refactor: the retired kernel pin moved out of `lib/steam-machine.sh` into `lib/kernel-pin.sh`**
- `b00e1b6` **refactor: the shortcut's two start scripts are files in `patches/` (`steamify-start.sh`, `steamify-app-start.sh`) instead of heredocs in `launcher_enable`, and the 83-line LED driver install is split into steps (`led_write_dkms_override`, `led_install_package`, `led_build_all_kernels`, `led_load_module`); what gets installed is byte-identical**
- `5b50a36` **fix: the daily update check no longer crashes on a release tag that isn't a plain version number (`TypeError` comparing it, found by the new unit tests); it is simply never offered**
- `4d4f7b3` **refactor: `theme_enable` and `create_desktop_shortcut` split into steps; the Return to Gaming Mode shortcut is written with its mode already set (`install_executable`), like the other shortcuts, instead of chmod afterwards**
- `66036ef` **test: the menu rules, the plan and the app's and installer's JSON are checked against a golden file (`tests/menu-test.sh` in steamify-cachyos-dev); `make check`, `.editorconfig`, `.shellcheckrc`**
- `fac4670` **docs: README lists the sources and projects Steamify builds on, with licences and thanks**
- **chore: merge release/2.14.0 into the optimization branch (`feature/code-cleanup`): the refactors above on top of 2.12.1 to 2.14.0. The rule tables replace the inline rules of the app (checked equal on 9000 random selections over six hardware profiles; the one difference is the documented one: a ticked "Add as non-Steam game" also ticks the Steamify shortcut), the shortcut's start scripts are the files in `patches/` with 2.14's terminal choice and `zenity` fallback, `--desktop` is a mode of the entry point, and the desktop shortcut is one module for KDE and GNOME**
- **refactor: the login code of the SteamOS conversion: everything left by an older layout (SDDM files, the sync bridge, the shortcut's sudoers rule, the two drop-ins of 2.13.x) is removed by one function (`remove_legacy_login_setup`) instead of five places; units and drop-ins go through `unit_write` / `unit_remove` with one `daemon-reload` (`systemd_reload`) instead of seven; `set_login_mode` is the only writer of single user / multi-user login; the two plasma-login-manager drop-ins are one file (`zz-steamify.conf`; the update moves 2.13.x installs: the conversion shows an update); steps whose failure does not matter use `best_effort` and the real ones return an error; the desktop shortcut no longer touches login-manager leftovers**
- **ci: the Lint workflow ran on a runner for the first time: `qmllint` there has no `--max-warnings` (and 6.12 exits with an error on it even when nothing is reported), so the step checks the output for warnings and uses `--import disable` only where the option exists (it silences three false "not declared as singleton" warnings for `ui/qml/qmldir`); `make lint-qml` does the same. `ruff` found an unused `QIcon` import in `patches/steamify-notifier.py`: removed**
- **refactor: no more `LOGIN_MANAGER` global: `choose_login_manager` prints the login manager and `gaming_enable` asks it once (the menu's and the app's apply no longer set it for it); what has to follow a run (Steam's version, and the desktop shortcut's name when "Boot into" changed) is `refresh_after_apply`, so `lib/boot-session.sh` no longer calls into the shortcut module**
- **fix: the single user login of the refactor returned an error under `pipefail` (the drop-in writer ended in a failed `&&`), so the SteamOS conversion's update failed on a PC in single user mode (found on a Steam Machine; the tests now run with `pipefail`)**
- **fix: "Return to Gaming Mode" after Steam's "Switch to Desktop" landed on the desktop again: the one-shot login steamos-manager writes (`zzt-*-temp-login.conf`) sorts after the session steam-set-session picks and nothing removed it since 2.13.0 (the login manager's restart did before). The session helper (`steamify-relogin`, now in single user mode too, with `--relogin` only in multi-user mode) empties a one-shot that is older than the last pick: the last pick wins (found on a Steam Machine)**

## 2.13.2 - 2026-10-19

- `ca98c2c` **chore: bump VERSION to 2.13.2**
- `dd8b242` **fix: "Return to Gaming Mode" after Steam's "Switch to Desktop" landed on the desktop again: the one-shot login steamos-manager writes (`zzt-*-temp-login.conf`) sorts after the session steam-set-session picks and nothing removed it since 2.13.0 (the login manager's restart did before). The session helper (`steamify-relogin`, now installed in single user mode too, with `--relogin` only in multi-user mode) empties a one-shot that is older than the last pick: the last pick wins. Installs of 2.13.x get it with the update (feature version 2.13.2) (found on a Steam Machine)**
- **docs: the changelog entries of 2.13.2 get their commit hashes**

## 2.13.1 - 2026-10-19

- `ca2070a` **chore: bump VERSION to 2.13.1**
- `762271a` **fix: the SteamOS conversion installs and updates NVIDIA's patched gamescope again (`gsn_enable`) and releases single user mode's desktop autologin (`single_login_release`): both calls were dropped from `gaming_enable` in 2.12.1 and 2.13.0, so on NVIDIA PCs turning the conversion on left gamescope's picture corrupted, and a re-apply never updated the patched gamescope. Installs of 2.13.0 re-apply it (feature version 2.13.1). AMD and Intel PCs were not affected**
- **docs: the changelog entries of 2.13.1 get their commit hashes**

## 2.13.0 - 2026-10-19

- `e04a3a5` **feat: multi-user mode: with the SteamOS conversion, turning single user mode off now means the PC starts at the login screen (it logged in by itself before); switching between gaming mode and the desktop while logged in (Steam's Switch to Desktop, Return to Gaming Mode) still doesn't show it. A path unit and a helper (`steamify-relogin`) write the relogin entry plasma-login-manager needs for one switch. Single user mode on keeps autologin at every start**
- `e04a3a5` **change: the Return to Gaming Mode shortcut no longer restarts the login manager (it logs in again by itself), so its sudoers rule is removed**
- `9aecd2a` **feat: the login screen preselects the session "Boot into" says (gamescope, or the desktop) instead of the one used last (a drop-in for `plasmalogin.service` sets plasma-login-manager's greeter state before every start)**
- `9aecd2a` **change: the desktop shortcut is called "Switch to Gaming Mode" when the PC boots into the desktop (there is nothing to return to) and "Return to Gaming Mode" when it boots into gaming mode; changing "Boot into" renames it**
- `4183857` **change: the update from a setup with SDDM (single user mode before 2.12.1) leaves nothing of it behind: its autologin files, steam-set-session's file for SDDM, the empty folder, the old sync bridge and the shortcut's sudoers rule are removed**
- **docs: the changelog entries of 2.13.0 get their commit hashes**

## 2.12.1 - 2026-10-19

- `b4fbf12` **fix: "Switch to Desktop" in Steam looped back to gamescope with single user mode (SDDM): Steam's newer client switches through `steamos-manager`, which only writes plasma-login-manager's `/etc/plasmalogin.conf.d/zzt-holo-temp-login.conf`. The conversion, single user mode included, now uses plasma-login-manager only; an existing SDDM setup is moved over by the update. plasma-login-manager lists the conf.d files once, at start, and steamos-manager removes that file at every start, so a drop-in for `plasmalogin.service` creates it (empty) after that: Steam's switch then lands in the file the login manager reads**
- `b4fbf12` **refactor: no session sync bridge any more: the base `/etc/plasmalogin.conf` has no `[Autologin]` (backed up), `User=`/`Relogin=` are in `/etc/plasmalogin.conf.d/10-gamescope-autologin.conf`, and the conf.d fragments that `steam-set-session` and `steamos-manager` write win on their own. The Return to Gaming Mode shortcut's sudoers rule only allows restarting the login manager; the boot-into-desktop unit only runs `steam-set-session`**
- **docs: the changelog entries of 2.12.1 get their commit hash (`b4fbf12`)**

## 2.12.0 - 2026-10-13

- **feat: setting up the SteamOS conversion on NVIDIA first checks that nothing blocks it (a pacman lock, less than 1.5 GB free), and a failed setup is remembered: a desktop notification now and a reminder in the menu until a setup works**
- **docs: the README and TECHNICAL.md describe NVIDIA as it is now (the SteamOS conversion with the patched gamescope; "Gaming on NVIDIA" only as history); the NVIDIA menu screenshot is gone, NVIDIA PCs get the same menu**
- **feat: the patched gamescope comes in one build per CPU level, like CachyOS's repositories (generic, x86-64-v3, v4, znver4): Steamify picks the best one this CPU can run (`gsn_cpu_variant`), falls back to generic, and starts the installed gamescope once headless (`gsn_smoke_test`): a build that doesn't start is replaced by the generic one. CI compiles each with an explicit `-march` (a `-march=native` build died with SIGILL on a Ryzen) and checks the binary for instructions beyond its level.**
- **feat: on NVIDIA the gaming session runs on the display's own mode and Steam's interface at its size: a second gamescope patch (`gamescope-ui-native.patch`, release `3.16.31-3` of steamify-gamescope-nvidia, now the pin; built once per CPU level, see below) keeps Steam's UI X server at the output size when Steam (with `-steamos3`) asks for 1920x1080, and a wrapper (`gamescope-display-wrapper.sh`, set up by the conversion with a drop-in of `gamescope-session.service`) starts gamescope on the mode KDE has saved for the connected display, else the biggest mode at the highest refresh rate: before, gaming mode ran at the display's preferred mode (60 Hz on many monitors) with a 1080p Steam UI. Tested on an RTX 5080, 3440x1440@175: widescreen, sharp, a Proton game starts**

- **fix: on an NVIDIA PC that had single user mode on before the SteamOS conversion, "Return to Gaming Mode" and the boot choice work again: single user mode's desktop autologin (`zzz-steamify-autologin.conf`, read last) pinned the Plasma session; the conversion removes it, and turning the conversion off sets it up again**

- **fix: when an option fails, its sub-options are not applied any more (a failed conversion used to leave its "Boot into the desktop", silent start and icons on without it)**

- **fix: a PC that keeps `python-hidapi` (liquidctl needs it) can use the SteamOS conversion: jupiter-hw-support, which gamescope-session-cachyos depends on, wants `python-hid`, which conflicts with it and stopped the package install. Steamify builds and installs an empty placeholder package that provides `python-hid` first (`patches/python-hid-shim.PKGBUILD`); only the Steam Deck controller firmware updater uses it**

- **feat: the patched gamescope is downloaded as the newest release of steamify-gamescope-nvidia (checked against that release's `.sha256`), a newer one than the installed package shows the SteamOS conversion as an update, and what this Steamify was tested with is the fallback: the pinned package (sha256 in Steamify), the copy the ISO leaves, a build here; the repository's workflow builds each release in CachyOS's container**

- `124b424`, `f234c72` **fix: HDMI-CEC on the Steam Machine no longer needs GitHub: when downloading Valve's CEC driver fails, Steamify uses the copy it carries (`patches/cros-ec-cec.c`), checked against the same pinned sha256**

- `127b8cf`, `2811ecc`, `f3cd053`, `4325d80`, `03f9e87`, `5b5181f`, `06ffc8b`, `4d60dd2`, `0ba94b2` **feat: the SteamOS conversion is offered on NVIDIA PCs again (GTX 16 / RTX 20 series or newer: Turing and later, the cards NVIDIA's open kernel driver supports): it builds and installs a patched gamescope from the recipe and patch Steamify carries (`patches/`, prepared in [steamify-gamescope-nvidia](https://github.com/theupriser/steamify-gamescope-nvidia); gamescope 3.16.31, so a Steamify release builds the version it was tested with) (GBM-allocated scan-out buffers, NVIDIA's corrupted gaming-mode picture, gamescope#2309; a few minutes to build) and sets `gamescope_drm_gbm_scanout=1` for the session (`lib/gamescope-nvidia.sh`). It replaces "Gaming on NVIDIA", which is not offered any more (the kernel parameters, early modules, suspend memory and the 32-bit libraries come with the conversion on a supported card; a PC that had "Gaming on NVIDIA" on has it turned off when the conversion is turned on). Tested on an RTX 5080 (driver 615.78.08): Steam's gaming UI is clean with it and shows artifacts without. The package is pinned to one gamescope release: updating it is not automatic yet**

- `ce4bc67` **feat: "Gaming on NVIDIA" also keeps video memory over suspend (`NVreg_PreserveVideoMemoryAllocations=1` in `/etc/modprobe.d/90-steamify-nvidia.conf`, the initramfs is rebuilt), enables `nvidia-suspend`/`nvidia-resume`/`nvidia-hibernate`, and installs `lib32-nvidia-utils` and `lib32-libxkbcommon` (32-bit games, the 32-bit MangoHud preload) on a supported card; off removes only what Steamify added. Untested on hardware yet**

## 2.11.1 - 2026-10-02

- `d70aeb8` **docs: new README screenshots of the app (2.11 menu) on a Steam Machine and on an NVIDIA PC, and the README names the opt-in "Start Steam silently in desktop mode" and the icons as an option of the conversion**
## 2.11.0 - 2026-10-01

- `2e51d1d`, `3494924`, `fbdad5a`, `079e725`, `188799e` **feat: "Start Steam silently" sub-option: under the SteamOS conversion (`silent`, opt-in now: it was always on before; an existing one is moved from its systemd unit to the autostart entry by the "update") and under Gaming on NVIDIA (`nvsilent`, opt-in, not together with Big Picture); the SteamOS one is called "Start Steam silently in desktop mode" and is always shown, also on a Steam Machine; it is Steam's own autostart entry (`~/.config/autostart/steam.desktop`), so Steam's setting "Run Steam when my computer starts" follows it**
- `2f7b53f` **fix: the Steam Machine's serial number step no longer fails inside the ISO's installer (`/sys` is read-only in its chroot; the tmpfiles.d file applies at the next boot anyway), which made `machine` report an error and the install log end with `exit: 1`**
- `45a23af`, `bd8f387` **feat: `STEAMIFY_NO_DOWNLOAD` (the ISO's `steamify.nodownload` kernel parameter): the installed system's first login runs the Steamify bundle of the ISO instead of downloading the newest release (to test an unreleased Steamify)**
- `f3810a9` **fix: the SteamOS theme no longer leaves a blank Discover pin in the taskbar (Plasma's default taskbar pins Discover, which CachyOS doesn't install); the taskbar gets CachyOS's own pins (System Settings, files, browser), also on the ISO's first login**
- `7869b47` **feat: "Steam Deck/Machine icons" (`glyphs`) is a sub-option of the SteamOS conversion, like "Start Steam silently in desktop mode": it only changes gaming mode**
- `4d387b2` **chore: the Steamify unit tests (`controllers-test.sh`, `nvidia-test.sh`) and the NVIDIA hardware test live in steamify-cachyos-dev (`tests/`) now; `tests/` is removed here**

## 2.10.0 - 2026-10-01

- `d6db4f6` **feat: "Gaming on NVIDIA" (nvidia) replaces the SteamOS conversion on PCs with an NVIDIA GPU, where gamescope's gaming mode shows a corrupted picture (NVIDIA bug 5240452): Steam is installed when missing and starts at login on the Plasma desktop; the sub-option "Steam starts in Big Picture" (bigpicture) starts it in Big Picture, unticked in its normal window, on an empty Plasma session so windows of the last session don't cover it. On a supported card (RTX 20 series or newer) it also sets the NVIDIA kernel parameters and early modules. The conversion and its options are hidden there unless already on**
- `d1373e2` **feat: single user mode also works on NVIDIA PCs, without the SteamOS conversion**
- `5811f5c` **fix: "Add as non-Steam game" isn't offered on NVIDIA PCs (shown when already on, so it can be turned off)**
- `83248a8` **feat: Extended controller support (extended_controller_support, off by default): the Xbox wireless dongle (xone) and Xbox controllers over Bluetooth with rumble and battery level (xpadneo), built for every installed kernel; off removes only what Steamify installed**
- `01a77b7` **feat: a new opt-in option (unticked by default) shows the "new" badge in the menu and the app**
- `f1983a9` **docs: README screenshots of the 2.10.0 app, side by side: on a Steam Machine and on a PC with an NVIDIA card**

## 2.9.6 - 2026-09-30

- **fix(ci): a dev ISO from a release branch is built with that branch's own Steamify (input steamify_ref of the ISO workflow), not the newest published release: release/2.9.6 kept producing 2.9.5 ISOs**
- **docs: changelog hashes for 2.9.6**
- `9a2965d` **fix(ci): the ISO workflow always runs from master; main asks for a release ISO, a release branch for a dev ISO (input `kind` of iso-1-github-tag.yml; feat/steamify is no longer needed)**
- `c42d545` **fix(ci): a version published from main starts a real ISO release, a release branch a dev ISO (it always started the dev one)**
- `b3bed43` **chore: Version 2.9.6**

## 2.9.5 - 2026-09-30

- `70ecb56` **ci: trigger a mirror sync**
- `a7276cf` **ci: sync the git.upriser.nl mirror on every branch and tag**
- `b3549d4` **ci: sync the mirror on release branch pushes too**
- `a232a55` **feat(ci): sync the git.upriser.nl mirror on every push to main and every tag (git-upriser-sync.yml calls the mirror-sync API: the Gitea mirror builds at once instead of at its interval; secrets GIT_UPRISER_URL and GIT_UPRISER_TOKEN, retried, skipped on Gitea itself)**
- `3676c64` **docs: link the renamed steamify-cachyos-live-iso repo (the release dispatches the ISO workflow iso-1-github-tag.yml there)**
- `971e792` **chore: Version 2.9.5**

## 2.9.4 - 2026-09-29

- `619ef1f` **docs: AGENTS.md and TECHNICAL.md: the CEC driver cache, the one workflow for GitHub and a Gitea mirror, and that a new release starts the Steamify ISO's release**
- `b624053` **chore: Version 2.9.4**

## 2.9.3 - 2026-09-29

- `7f5d29c` **feat(ci): a new Steamify release starts the Steamify ISO's release (a test build from the ISO repo's feat/steamify; secret ISO_DISPATCH_TOKEN)**
- `cfe3ce7` **chore: Version 2.9.3**

## 2.9.2 - 2026-09-29

- **feat(ci): a Gitea mirror publishes its own release per version (akkuman/gitea-release-action; never overwrites one, notes from the changelog, links to the mirror)**
- **fix(ci): the build also runs on a Gitea mirror (act_runner): shellcheck through ludeeus/action-shellcheck, which brings its own binary; the artifact goes up there with christopherhx/gitea-upload-artifact (GitHub refuses a workflow that mentions the deprecated upload-artifact@v3); releases are only published on GitHub**
- `fe4f3f4` **chore: Version 2.9.2**

## 2.9.1 - 2026-09-29

- `c87e6c7` **docs: changelog for the CEC driver cache**
- `fc05725` **fix: HDMI-CEC: an older cached CEC driver is removed when a new pin is downloaded**
- `90bc5e4` **fix: HDMI-CEC: Valve's CEC driver is downloaded once and kept in /var/cache/steamify (GitHub rate-limits repeated downloads with HTTP 429, which left CEC off); turning CEC on again needs no network**
- `d99ff65` **chore: Version 2.9.1**

## 2.9.0 - 2026-09-28

- `d30d505` **chore: Version 2.9.0**
- `66ea63c` **docs: KDE Plasma only: other desktops and display managers "are not supported" (README, was "don't work yet")**
- `9b86cd1` **docs: KDE Plasma only: other desktops don't work yet (README)**
- `d73e71d` **docs: README, TECHNICAL and TROUBLESHOOTING for 2.9.0: Steam's System settings, serial number and Wi-Fi backend, --defaults --list, the Steamify ISO**
- `a72d848` **feat: Steam's OS Version is the SteamOS release Steamify follows (steamos-3.9), its OS Codename steam-machine; About this System keeps "CachyOS Linux" (UseOSReleaseVersion)**
- `27a4070` **fix: Steam's OS Variant shows Steamify's version (VARIANT_ID=steamify-2.9.0; Steam shows VARIANT_ID, not VARIANT)**
- `44bfe07` **fix: No VERSION_ID in os-release: About this System said "CachyOS Linux 2.9.0"; the version is in VARIANT ("Steamify 2.9.0")**
- `435f69c` **feat: Steam's System settings: the OS name stays CachyOS (no renaming, also not in About this System), Steamify <version> as the variant, the SteamOS release it follows as the codename (steamos-3.9)**
- `ce71b34` **feat: Steam's System settings and About this System like on SteamOS: OS name "CachyOS with Steamify" (lsb-release, kept through CachyOS updates by a pacman hook), Steamify as OS variant and version (os-release VARIANT/VERSION_ID; NAME/PRETTY_NAME stay CachyOS's for limine, TARGET_OS_NAME pinned), "CachyOS Linux with Steamify" in About this System; on a Steam Machine the serial number and Steam's Wi-Fi backend setting (existing installs get it as an update)**
- `07a94cd` **fix(ui): The progress screen's ✓ and ! stand upright: only a dot on the circle spins while a step runs (they kept the spinner's last angle)**

## 2.8.0 - 2026-09-28

- **chore: Version 2.8.0**
- **feat: steamify.sh --defaults --list: what --defaults can set up here, as JSON, for an installer page**

## 2.7.0 - 2026-09-28

- `4f6e6fd` **feat: --defaults takes --skip <ids> and --boot gamescope|desktop, for the Steam Machine ISO's installer pages**
- `5bf9da4` **fix: HDMI-CEC enables cec-audio-control.socket (the TV remote's volume keys); existing installs get it as an update**
- `14aa7c0` **fix: the app's progress screen says "Boot into desktop", not "Boot into Boot into"**
- `c4ec755` **feat: --defaults --options <ids> (exactly these on) replaces --skip; steamify.sh --boot gamescope|desktop on its own switches where an installed conversion starts**
- `eadbdda` **docs: release branches (release/X.Y.Z, feature/ and bugfix/ branches into it, the release into main); CI builds release/** pushes**
- `bee18b7` **docs: the agent merges feature/bugfix branches into the release branch; the release into main stays the user's**
- `501c0ba` **docs: gh or git for merging into the release branch**
- `b1adacb` **docs: gh is required for the release-branch pull requests; ask the user to install it**
- `ced4a45` **chore: the v2 app preview is gone (it is the released app): no preview pre-release step in CI, no mention in steamify-app.sh**
- **fix: turning the theme off no longer brings back single user's launcher restriction when single user was turned off in between**

## 2.6.0 - 2026-09-27

- `b948c20` **feat: --defaults applies the default setup without the menu, also from an installer (no session): the base for a Steam Machine ISO**

## 2.5.2 - 2026-09-27

- `0c96bed` **docs: README screenshot at 2.5.2: everything on, nothing to update**

## 2.5.1 - 2026-09-27

- **fix: Add as non-Steam game asks Steam to close again every 15 s (a Steam that was still starting ignored it)**
- `3a0692f` **docs: README screenshot at 2.5.1 with Add as non-Steam game**
- `e86ddcc` **feat: Add as non-Steam game: Steamify in the Steam library, under the shortcut; controller works when started from Steam**
- `389bc33` **fix(ui): B never quits (Steam sends Esc for it), Ctrl+Q does; started from Steam, the hints show the Steam Controller's buttons**
- `c6c1150` **fix(ui): Enter selects (a Steam Controller's A in Steam's desktop layout); Ctrl+Enter reviews and applies**
- `98e2eff` **fix(ui): Started from Steam, the app runs without Steam's overlay (Qt aborted) and stays in the foreground, so Steam Input gives it the controller**
- `431515b` **feat(ui): Review & apply greyed out while nothing would change; the Done screen shows why a run stopped**

## 2.5.0 - 2026-09-27

- **docs: README: what the VRAM booster says with NVIDIA's closed driver; shorter unsupported text in the app**
- `32c33e4` **fix: An option left unticked stays off: it came back ticked as "new" on the next run (since 2.3.0)**
- `2dd0f3a` **feat: VRAM booster with NVIDIA says what to do: update, switch to the open driver (chwd command), or not supported by the card**
- `57995bc` **docs: VRAM booster works with NVIDIA's open kernel modules (driver 615+); only the closed driver is greyed out**
- `d57e8d8` **docs: AGENTS.md and changelog for the vidmem detection**
- `5a34633` **feat: VRAM booster also for drivers that name their region vidmem (or numbered), NVIDIA included once its driver registers it**
- `479b70b` **feat: Everything in the home folder under steamify (state, scripts, icon), moved once from the old name**
- `2e0881b` **fix: fill takes values literally; the notifier path is quoted in its unit**
- `cce31e1` **refactor: DKMS confs in patches/; an existing leds-valve DKMS override is kept and restored**
- `bd4fa3a` **refactor: The session sync and kernel headers scripts in patches/**
- `8ffa0f2` **refactor: systemd units in services/, read with service_file like patches/**
- `8a2601d` **docs: README screenshot at 2.5.0 with Update notifications; AGENTS.md: retake it when rows change**
- `572417b` **fix: Open Steamify from the notification starts the app (own scope), the same way it was last used (app or terminal)**
- `cf73229` **feat: Update notifications: a notification and tray icon when there's a new Steamify**

## 2.4.1 - 2026-09-27

- **chore: Version 2.4.1**
- `6f598d1` **docs: README screenshot shows every option**
- `9bbe5fa` **docs: Screenshot of the app's menu in the README**

## 2.4.0 - 2026-09-27

- `03a8b8c` **chore: Version 2.4.0**
- `e699a3f` **refactor(ui): One QML file per screen; the HDMI boost's setup screens and backend commands removed**

## 2.3.0 - 2026-09-27

- `86b9744` **feat: VRAM booster greyed out with an NVIDIA card, with why**
- `b0947d7` **feat: VRAM booster only for GPUs with at least 2 GB of their own VRAM**
- `3f97c85` **feat: VRAM booster for every supported GPU, not only the Steam Machine**
- `fd162c1` **feat: New badge for default sub-options added in this version**
- `54ebddf` **feat: VRAM booster for the Steam Machine**

## 2.2.0 - 2026-09-27

- `ef585c0` **docs: Changelog entries per commit for 2.2.0**
- `32795bd` **feat(ui): Update badge on the progress screen**
- `3c8ca65` **fix(ui): Never write the sudo password to a file; Update label on the progress screen**
  - The app gave `sudo` the password through a short-lived file; the helper
    now reads it from a named pipe the app feeds from memory each time sudo
    asks. The progress screen showed "undefined" for an update.
- `11a91ef` **feat: Update badge on components that get a newer version**
  - The menu (terminal and app) shows "(update)" / an Update badge after
    the name of a component a normal run will update.
- `163f790` **feat: Feature versions are Steamify versions; Steam Machine support is 2.2.0**
  - Each component records the Steamify version of what it set up; when a
    release changes a component, installs with an older version are ticked
    and updated by a normal run ("update" in the plan and the app's
    review). A setup from before counts as 2.1.0, so Steam Machine support
    (2.2.0) is updated on machines set up with 2.1.0. New default
    sub-options (like the power-off fix) are ticked where their parent is on.
- `e121b06` **fix: Remove whatever is left of HDMI refresh boost, pin or no pin**
  - HDMI refresh boost needed the pinned kernel and is retired (newer
    kernels do HDMI 2.1 themselves): whatever is left of it (saved
    displays, also ones not connected, its hotplug script, the old kernel
    parameter) is unticked and removed by the next run.
- `19ca966` **docs: Drop the kernel pin and HDMI refresh boost descriptions**
- `56fb908` **docs: Power-off fix texts cover every affected kernel, not just 7.2**
- `6df19eb` **feat: Power-off fix as its own sub-option, drop the kernel pin, feature versions**
  - The power-off fix is a sub-option of Steam Machine support, ticked
    along with it (opt-out). The kernel pin is no longer offered: an
    existing pin is shown unticked, so the next run removes it and brings
    back CachyOS's current kernel.
- `7694c97` **feat: Power-off fix for the Steam Machine; the kernel pin is optional**
  - With recent kernels (newer 6.x, 7.0 and 7.1 updates, 7.2 and probably
    later ones) the Steam Machine started again right after shutting down:
    they keep the wake bit the firmware sets on GPIO pin 18, which Valve's
    own kernel clears in a patch that won't reach CachyOS. A small module,
    built with DKMS for each installed kernel, clears it right before
    power-off. Tested with CachyOS 7.2.8: stays off, and without the module
    it rebooted.
  - Module sources and patches live in `patches/` instead of inside the
    shell code; the single-file build and the app package include them. The
    Steam Machine CEC driver change is now
    `patches/cros-ec-cec-single-port.patch`.

## 2.1.0 - 2026-09-26

- **feat(ui): Manage button for HDMI refresh boost**
  - The item's switch is a button: Set up… while no display is saved,
    Manage after that. Manage lists the saved displays (connected or not),
    removes one with its Remove button, and sets up the connected display
    when it has no saved rates yet.
- **4cc87aa feat: HDMI refresh boost per display, with a Saved displays screen**
- **36d0a9d feat: HDMI refresh boost only for the display it was set up for**
  - The EDID override was on the kernel command line, so any display on that
    HDMI port got the first display's timings. Rates are now saved per
    display and loaded at boot and at every hotplug for the display that's
    connected (its ID read over DDC); a display without saved rates, or
    unplugging, puts the port back on the display's own EDID. No initramfs
    or boot loader change any more. An existing setup is moved over when
    re-applied (`a`).
  - The item shows on only while the connected display is boosted, so a new
    display can be set up by ticking it; unticking removes only that one.

## 2.0.3 - 2026-09-26

- **fix: HDMI-CEC on the Steam Machine**
  - Mainline's `cros_ec_cec` driver doesn't know the Steam Machine, so there
    was no `/dev/cec0`. HDMI-CEC now builds Valve's version of the driver
    with DKMS (`steamify-cros-ec-cec`) for every installed kernel, with a fix
    so it finds amdgpu's HDMI port even though amdgpu loads first. An
    existing HDMI-CEC install is ticked in the menu to add it.

## 2.0.2 - 2026-09-26

- **badfd84 docs: Non-affiliation disclaimer in the README**
  - States that the project isn't affiliated with Valve or CachyOS, and that
    Steam and SteamOS are Valve's trademarks.

## 2.0.1 - 2026-09-25

- **2b3f1de feat: The Steamify shortcut opens the app**
  - "Steamify CachyOS" on the desktop and in the launcher starts the newest
    app (in Konsole the first time, if PySide6 still has to be installed).
    The terminal menu is "Steamify Terminal" in the launcher. A shortcut from
    before 2.0.1 is ticked in the menu, so a normal run replaces it.
  - steamify-app.sh leaves the shortcut's launcher entry alone (it has the
    same id, `steamify-ui.desktop`, and always starts the newest release).

## 2.0.0 - 2026-09-25

- **feat: Steamify app (v2 UI)**
  - A graphical app for controller, keyboard and TV remote, driving the same
    components through `steamify.sh --backend`; the BIOS update with both
    warnings; built by GitHub and run with curl.
- **feat(ui): HDMI refresh boost in the app**
  - "Set up…" opens its own screen: the display, its resolution and the
    rates on offer (its own mode, calculated tens, the HDMI 2.0 limit). The
    display's own faster mode is switched to right away; every other rate
    has a Try button (switch live, wait for the picture, then keep it within
    15 s or it switches back) and a tick box. Install installs the ticked
    rates. All rates are loaded when the screen opens, so a try is only a
    mode switch.
  - Unticking Steam Machine support or the kernel pin unticks it, as in the
    menu.
- **fix(ui): The details panel scrolls instead of overflowing**
- **fix: Switching back to a rate like 59.97 Hz**
  - `hdmi_set_mode` compared it as a whole number and printed an error.

## 1.2.0 - 2026-09-25

- **feat: HDMI refresh boost (Steam Machine, pinned kernel)**
  - The pinned 7.1.6 kernel doesn't read the extra EDID block where monitors
    list their fast modes, and does no HDMI 2.1, so HDMI displays often stay
    at 60 Hz. The new menu item reads the display's EDID over DDC,
    calculates the highest rate that fits HDMI 2.0 at the desktop resolution
    (rounded down to ten, plus the hundred below as a safe option), tests
    each step live with a confirmation, and makes the confirmed ones
    permanent through `drm.edid_firmware` (Limine, sdboot-manage or GRUB).
- **feat: HDMI refresh boost and Update BIOS under Steam Machine support**
  - Both are sub-options now, shown only while Steam Machine support is
    ticked. Unticking it unticks them; unticking the kernel pin unticks the
    HDMI refresh boost.

## 1.1.4 - 2026-09-25

- **fix: No lock screen in single user mode before a restart**
  - The screen locker only read the new settings at the next login, so the
    PC still locked after 5 minutes idle until then. Turning single user
    mode on or off now tells it to reload them right away.

## 1.1.3 - 2026-09-25

- **fix: HDMI-CEC settings shown in Steam**
  - CachyOS's gaming mode script sets `STEAM_ENABLE_CEC=0`, which hides
    Steam's HDMI-CEC settings (and its CEC volume buttons). HDMI-CEC now adds
    a drop-in for `steam-launcher.service` that overrides it with
    `STEAM_ENABLE_CEC=1` (`/etc/steamify/steam-cec.env`).
  - HDMI-CEC set up by 1.1.0-1.1.2 shows as off and ticked, so a normal run
    (Enter) adds this.

## 1.1.2 - 2026-09-25

- **fix: Steam's HDMI-CEC settings reach cecd on a first run**
  - HDMI-CEC runs before Steam Machine support, which installs
    steamos-manager; so steamos-manager's `configure-cecd` unit couldn't be
    enabled and cecd ran without Steam's settings. Steam Machine support now
    links them once steamos-manager is there.

## 1.1.1 - 2026-09-25

- **perf: Pinned kernel before the LED driver**
  - With the kernel pin ticked, Steam Machine support installs kernel
    7.1.6-1 first, so DKMS builds the LED driver once, for that kernel,
    instead of for the current kernel first and then again. The LED driver
    then loads after the restart, which it now says instead of warning.
- **fix: steamos-manager starts after cecd**
  - It checks only at its start whether cecd runs; if it was first, Steam's
    HDMI-CEC settings were missing until it restarted. A drop-in
    (`/etc/systemd/user/steamos-manager.service.d/`) orders it after cecd.

## 1.1.0 - 2026-09-25

- **feat: HDMI-CEC** (experimental, on every PC; ticked by default only on a
  Steam Machine)
  - Valve's `cecd`, `cec-audio-control` and `inputattach-cec-units` from its
    SteamOS repository (SHA-256 checked): use Steam with the TV remote, and
    the TV turns on and off with the PC. On a Steam Machine, steamos-manager
    configures it from Steam's settings.
  - Works with any `/dev/cec*` (GPU or USB adapter); the menu lists them.
  - `CEC.md`: which PCs have CEC (NVIDIA doesn't, AMD/Intel only over some
    DisplayPort adapters), and USB adapters for your own build.
  - Restarts steamos-manager, which only offers Steam its HDMI-CEC settings
    when cecd was there at its start.
  - The README no longer says Steam Machine support alone gives HDMI-CEC:
    `cecd` wasn't installed, so it didn't.

## 1.0.0 - 2026-09-25

- **feat: Pin the kernel to 7.1.6-1 on a Steam Machine**
  - New sub-option under Steam Machine support, ticked along with it (opt
    out): newer CachyOS kernels make the Steam Machine reboot instead of
    shutting down. Installs `linux-cachyos` and `-headers` 7.1.6-1 and adds
    them to `IgnorePkg`; unticking removes the pin and updates the system.
  - The packages are kept in `/var/cache/steamify/kernel` and reinstalled
    from there without downloading; else from pacman's cache, the CachyOS
    archive, the CachyOS mirror, or `PINNED_KERNEL_URL`.
  - First download source: the `kernel-7.1.6-1` release of this repo, a
    one-off release that always has these files.
  - Every file is checked against its SHA-256 (in the script) and its
    CachyOS signature before it's installed; a bad file is deleted.
  - Installed kernel headers are no longer updated by the wizard, so the
    pinned kernel keeps matching headers.
  - The BIOS item moves down one (9 on a Steam Machine).
- **docs: Shorter README, with a Steam Machine section**
  - How it works moved to `TECHNICAL.md`, problems to `TROUBLESHOOTING.md`;
    the README links to them and to the files it mentions.
- **feat: No more KDE wallet password prompts in single user mode**
  - Uses Valve's empty, password-less wallet, like SteamOS; apps such as
    Brave no longer ask for the wallet password after autologin.
  - Your own wallet is moved to `kdewallet.kwl.bak-steamify` and comes back,
    unchanged, when single user mode is off; the single user wallet is kept
    and reused next time.
  - Moved from the SteamOS theme, where it only helped without any wallet.
- **fix: No second sudo password prompt while installing yay**
  - `makepkg -si` installs with `sudo -k`, which forgets the cached password;
    yay is now built with makepkg and installed with `sudo pacman -U`.
- **docs: LICENSE.md** with the MIT license the README already named.
- **chore: No more `setup-gamescope-boot.sh` release asset**
  - Only `steamify.sh` is published; the old name from before 0.9.0 is gone.

## 0.10.0 - 2026-09-24

- `0f503dd` **feat: Boot into gamescope or the desktop**
  - New menu row under the conversion, "Boot into: [gamescope] / desktop";
    gamescope stays the default and is never changed on a first run.
  - Desktop: `steamify-boot-desktop.service` sets the autologin session to
    Plasma at every boot, before the login manager starts; Return to Gaming
    Mode and Steam's Switch to Desktop keep working. Back to gamescope removes
    it. Choosing desktop turns the conversion on; turning the conversion off
    resets it to gamescope.
  - The later menu items move down one (BIOS is now 8 on a Steam Machine).
- `4895de3` **feat: "Boot into" is a sub-option of the conversion**
  - Shown indented under the SteamOS conversion, and only while it's ticked.
- `bd90e29` **feat: Left/Right arrows choose on the "Boot into" row**
  - Left = gamescope, right = desktop (Space still switches); the row says
    "←/→ choose" and the key help lists Left/Right.
- **fix: Messages say which way it boots**
  - "This will: boot into: gamescope (from the next boot)" instead of "turn
    off: Boot into the desktop instead of gaming mode", and the same in the
    progress line and the "Done" overview.

## 0.9.1 - 2026-09-24 (#10)

- `2e107e5` **fix: LED driver for every kernel on a fresh install**
  - The DKMS override was written to `/etc/dkms` before `dkms` was installed,
    when that folder doesn't exist yet, so it silently failed and the build
    for other kernels (e.g. LTS) failed as in 0.6. The folder is created first
    now, and a failed write stops with an error.
- `5ab83d6` **feat: Restart question on quit is "Restart now? [Y/n]"**
  - When something needs a restart, `q` asks with yes as the default; `n` goes
    back to the menu and the next `q` asks again. Ctrl+C quits without
    restarting; scripted input that runs out never restarts.

## 0.9.0 - 2026-09-24 (#9)

The wizard is now called **Steamify CachyOS**, and can put a shortcut to
itself on the desktop.

- `f01aa93` **feat: Wizard shortcut on the desktop and in the launcher**
  - New menu item: a desktop icon and app launcher entry
    that open the newest release of the wizard in Konsole (`curl | bash`).
  - Its icon: Valve's Return to Gaming Mode icon with a gear instead of the
    arrow (`assets/steam-gaming-settings.svg`), published with every release
    and downloaded from there.
  - Desktop files are written already executable, so Plasma runs them instead
    of opening them in an editor.
- `be874b8` **feat: Rename to Steamify CachyOS**
  - Menu header, the shortcut ("Steamify CachyOS", menu item "Steamify
    shortcut"), release titles, README and AGENTS.md.
- `1c34a97` **chore: Repository renamed to steamify-cachyos**
  - All URLs point to `github.com/theupriser/steamify-cachyos` (the old ones
    redirect). The script keeps its name, `setup-gamescope-boot.sh`, so the
    old download URL keeps working; internal names such as
    `~/.local/state/cachyos-gamescope-boot` stay, so existing installs can
    still be turned off.
- `69a420b` **feat: The script is now steamify.sh**
  - `setup-gamescope-boot.sh` is renamed to `steamify.sh`; releases publish the
    bundle under both names, so `.../download/setup-gamescope-boot.sh` keeps
    working. The Steamify shortcut runs `steamify.sh`.
- `b0553ae` **docs: Shorter README intro**
- `afc05b0` **feat: The shortcut's window closes itself after a countdown**
  - After the wizard ends, a 10-second countdown closes the Konsole window
    (Enter closes it right away); after an error it stays open until Enter.
  - A failed download now counts as an error (`pipefail`) instead of running
    an empty script.

## 0.8.0 - 2026-09-24 (#8)

An opt-in BIOS update for the Steam Machine, and a menu that comes back after
every run.

- `2f9b2a5` **feat: Opt-in BIOS update for the Steam Machine**
  - New menu item (Steam Machine only, never ticked by default) showing the
    current BIOS version and the newest from Valve's `fremont-hw-support`.
  - Two large warnings and two confirmations (y/N, then typing `UPDATE`),
    checksum-verified download, installed with fwupd; the wizard then offers
    the restart that writes it, with a warning to keep the power on.
- `40c9ee6` **fix: BIOS update only when newer, device check first, aligned warnings**
  - The item is greyed out and can't be ticked unless Valve has a newer BIOS.
  - Before any warning: SHA-256 of Valve's package, then fwupd confirms the
    firmware fits this machine's hardware; otherwise it stops.
  - Warning box drawn with a solid red frame whose edges line up, and the
    menu's "Now" column aligned.
- `b70c9d6` **fix: shellcheck in the bundle, and the docs for the BIOS checks**
  - A variable name in `lib/bios.sh` clashed with `lib/state.sh` in the bundle
    (CI's shellcheck would fail); README, AGENTS.md and this changelog updated.
- `54fc9e3` **feat: Menu comes back after each run, BIOS dry run, version 0.8.0**
  - After a run the menu returns with the new state; quit with `q`. When
    something needs a restart, choose between back to the menu (`m`) and
    restart now (`r`); quitting asks once more.
  - A staged BIOS update greys the item out until the restart.
  - `WIZARD_BIOS_DRY_RUN=1` walks through the whole BIOS update (download,
    checksum, both warnings) but only prints the install and never flashes.
  - README: the menu loop and the BIOS update step by step.
- `45a8757` **fix: BIOS dry run also walks through the restart choices**
  - A dry run counts as staged, so `[m]`/`[r]` and the restart question on `q`
    show up; in dry-run mode restarting only prints what it would do.
- `429e840` **fix: Shorter BIOS labels so the menu fits 80 columns**
  - "now F7F0107, newest F7F0108 (own risk)", "F7F0108 waits for a restart",
    "F7F0107 is up to date"; shorter dry-run line.
- `99a95ab` **fix: Kernel legend only mentions the LEDs on a Steam Machine**
- `c0014ee` **docs: Last commit hash in the changelog; 0.7.0 was released on its own (#6, #7)**

## 0.7.0 - 2026-09-24 (#6, #7)

The SteamOS theme comes from CachyOS's `cachyos-vapor` package, applied with
Vapor's own desktop layout, and gains the SteamOS desktop extras. The Steam
Machine LED driver works on every installed kernel and survives kernel updates.

- `978f5a1` **feat: SteamOS theme from cachyos-vapor with its desktop layout, plus SteamOS desktop extras**
  - Installs `cachyos-vapor` instead of extracting Valve's `steamdeck-kde-presets`
    into `~/.local/share`; removes it on disable if the wizard installed it.
  - Applies the Vapor global theme with "Desktop and window layout": Steam Deck
    wallpaper, SteamOS panel and launcher icon. Layout files are backed up and
    restored; every key from Vapor's defaults goes through the undo journal.
  - Restores the real previous color scheme on disable (CachyOS's BreezeDark
    colors have no scheme name), instead of falling back to light Breeze.
  - Registers Vapor as the dark theme, so Plasma's Dark Mode toggle shows on.
  - Drops the extra SteamOS desktop defaults (GTK, Konsole, gsettings, panel tweaks).
  - New SteamOS desktop extras, downloaded from Valve's newest
    `steamdeck-kde-presets` (checksum verified) into `/usr/local`: Add to Steam,
    Nested Desktop, the SteamOS Return to Gaming Mode icon, the Steam Keyboard
    window rule and an empty KWallet (only when there is no wallet yet).
  - Single user mode's launcher settings are re-applied after the layout reset.
- `7802d90` **fix: LED driver for every kernel, kernel headers at boot, console power button, kernel overview**
  - DKMS override (`/etc/dkms/leds-valve-dkms.conf`) so the LED driver builds
    for every installed kernel (the LTS kernel failed) and on kernel updates.
  - `ensure-kernel-headers.service` installs missing kernel headers at boot, so
    a newly added kernel gets the LED driver too.
  - Power button sleeps and no automatic suspend on mains power (Steam Machine).
  - Menu shows every kernel with its headers, Steam controller driver and LED
    driver, plus whether the LEDs are loaded.
  - The selected menu row is highlighted in full.
- `10b5164` **docs: Version 0.7.0 and CHANGELOG**
  - `VERSION` in the entry point, shown in the menu header and the bundle.
  - README and AGENTS.md updated for the theme, the extras and the LED driver.
- `eb3169e` **ci: Version and changelog in the release notes**
  - The `latest` release's title shows the version, and its notes include this
    version's section of `CHANGELOG.md`.
  - Fix a shellcheck warning in the bundle (a variable name shared with
    `lib/state.sh`), which would have failed the CI check.
- `d7231eb` **chore: Move the bundle tool to .github/tools/bundle.sh**
- `5c00504` **docs: Commit hashes in the changelog**
- `8aab946` **ci: A release per version (tag v0.7.0, ...) instead of overwriting "latest"**
  - Each push to `main` publishes release `v$VERSION` with that version's
    changelog; an already released version is never overwritten (pull requests
    get a warning when `VERSION` wasn't bumped).
  - Install with `.../releases/latest/download/setup-gamescope-boot.sh`, which
    always points to the newest release.
- `1604ed1` **docs: Versioning and release rules in AGENTS.md**
- `6afef78` **ci: The latest tag follows the newest version tag**
  - When a new version is released, the `latest` tag and release move to it
    (bundle replaced), so the older `.../releases/download/latest/...` URL
    also always gives the newest version.

## 0.6.2 - 2026-09-23

- `a501df2` **Update steam-machine.sh**: install and enable `inputplumber`
  next to `steamos-manager`.

## 0.6.1 - 2026-09-23 (#5)

- `c0bd16e` **fix: Use curl | bash in the docs**: `bash <(...)` doesn't work in fish.

## 0.6.0 - 2026-09-23 (#4)

- `d654d44` **fix: Single-file build for curl, published by GitHub Actions**:
  `tools/bundle.sh` inlines `lib/*.sh`; CI publishes it to the `latest` release.

## 0.5.0 - 2026-09-23 (#3)

- `b91fa4b` **fix: Replace the question flow with a menu that turns components on and off**
- `3d7f376` **fix: Interactive checkbox menu**: arrow keys to move, Space to select, Enter to run.

## 0.4.0 - 2026-09-23 (#2)

- `a0bc385` **fix: Add single user no password option with SDDM, fetch newest Vapor presets**

## 0.3.0 - 2026-09-23 (#1)

- `4ad6c2c` **fix: Fix setup bugs, add SteamOS desktop look and LED driver, split into modules**

## 0.2.0 - 2026-09-07

- `151a3bf` **add steam keyboard to desktop**
- `1999b6e` **Automatically change theme**

## 0.1.0 - 2026-09-06

First version of the script.

- `16a7739`, `97ee6f3`, `6be1051` **commit the script**
- `e1aee45`, `25bc8c0` **change return to gaming mode logo to original logo**
