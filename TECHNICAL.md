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

## Single user mode: no locking

Turning it on turns off everything that asks for a
password or another user, per user: `action/lock_screen`, `switch_user` and
`start_new_session` restrictions in `kdeglobals`, no automatic locking
(`kscreenlockerrc`), Meta+L and Ctrl+Alt+Del unbound, and the launcher shows
only Sleep / Restart / Shut Down (kickoff `primaryActions=3`), which hides
the Session dropdown with Log Out. (Restricting `action/logout` would also
hide Restart and Shut Down.) Turning it off restores all of that.

**Login.** With the SteamOS conversion, single user mode also decides how the
PC logs in. On: autologin at every start (`10-gamescope-autologin.conf`:
`User=`, `Relogin=true`). Off (multi-user): no autologin, so the PC starts at
the login screen, while switching between gaming mode and the desktop while
logged in still doesn't show it. plasma-login-manager logs in again by itself
only with `User=` and `Relogin=true`, so `steamify-relogin.path` watches the
files a switch writes (`zz-steamos-autologin.conf`, `zzt-holo-temp-login.conf`,
`zzt-steamos-temp-login.conf`) and `steamify-relogin.service` writes them for
the user logged in on seat0 into `zzt-steamify-relogin.conf`, and empties
that file again when the next session is there (after 40 s at the latest).
The file is empty at every login manager start (a drop-in for
`plasmalogin.service`, which also keeps it on the login manager's file list,
see below), so a reboot always ends at the login screen, and a Log Out
(which no switch triggers) does too. Steam's own lock screen (Settings >
Security: "On system wake and power up", "When switching to desktop mode")
is a PIN screen inside Steam and independent of all of this.

The login screen preselects the session "Boot into" says (gamescope, or the
desktop), not the one used last: plasma-login-manager keeps the last session per
user in `/var/lib/plasmalogin/.local/state/plasma-login-greeterstaterc`
(`LastLoggedInSession`, a JSON object), and a drop-in for `plasmalogin.service`
runs `steamify-greeter-session` before every start to set it.

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

**Without the conversion** (any PC with it off; on NVIDIA that is before 2.12.0 or after turning it off) nothing else logs in by itself, so single user mode
does that too: `single_login_enable` (`lib/single-user.sh`) writes
`/etc/plasmalogin.conf.d/zzz-steamify-autologin.conf` (`User=`, `Session=plasma.desktop`, `Relogin=true`; named to sort after
`steam-set-session`'s `zz-steamos-autologin.conf`, which may still say gamescope from an earlier conversion), and drops any
`[Autologin]` from `/etc/plasmalogin.conf`. Turning it off removes the file. With the
conversion on, the conversion does the login as before. Ticking single user mode only ticks the conversion where the
conversion is offered.

The conversion uses **plasma-login-manager** (CachyOS's default since March
2026). Versions before 2.12.1 put single user mode on SDDM; the first run of
2.12.1 moves those back and removes the SDDM autologin files.

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

Since 2.12.1 the script leaves `[Autologin]` out of the base config
altogether (a backup is kept) and puts `User=`, `Session=` and `Relogin=true` in
`/etc/plasmalogin.conf.d/10-gamescope-autologin.conf`. What switches sessions
writes later-sorting fragments (`steam-set-session`: `zz-steamos-autologin.conf`;
Steam's "Switch to Desktop" through `steamos-manager`:
`zzt-holo-temp-login.conf`), which then win, so no bridge is needed. plasma-login-manager
re-reads the files it knows on every login but lists the directory only once, at start, so
a drop-in for `plasmalogin.service` (`zz-steamify-temp-login.conf`, after steamos-manager's
own `reset-oneshot-boot.conf`, which removes the `zzt-*` files at every start) creates them
empty; Steam's one-shot switch then fills a file the login manager already watches. Older versions
copied the session into the base config with a watcher on
`zz-steamos-autologin.conf` only, and with SDDM (single user mode) a Steam that
switches through `steamos-manager`, which only writes plasma-login-manager's files,
logged straight back in to gamescope.

## What each component changes

**SteamOS conversion** (`lib/login-manager.sh`, `lib/steam-desktop.sh`,
`lib/desktop-shortcut.sh`):

- installs missing packages: `gamescope-session-cachyos`, `steam`,
  `mangohud`, `xterm`, `ttf-liberation`, `wqy-zenhei`, `plasma-keyboard`;
- *plasma-login-manager:* creates `/etc/plasmalogin.conf.d`, backs up
  `/etc/plasmalogin.conf` and drops its `[Autologin]` section, writes
  `10-gamescope-autologin.conf`, removes stray `zzz-steamos-autologin*.conf`
  files from manual troubleshooting (never `zz-steamos-autologin.conf`, which
  CachyOS's tools own), and removes what older versions installed: the SDDM
  autologin files and the sync bridge;
- `KWIN_IM_SHOW_ALWAYS=1` for the virtual keyboard; the sub-option `silent`
  ("Start Steam silently in desktop mode", opt-in, always shown) writes
  `~/.config/autostart/steam.desktop` (the system steam.desktop with `-steamdeck -silent` in its Exec line). That is the
  file Steam's own setting "Run Steam when my computer starts" creates and removes, so the setting shows it. An older
  `steam-desktop-autostart` user unit is removed;
- the **Return to Gaming Mode** shortcut ("Switch to Gaming Mode" when "Boot into" is the desktop); on plasma-login-manager with a
  narrow sudoers rule (`/etc/sudoers.d/gamescope-session-switch`) so it can
  restart the login manager without a password prompt.

Turning it off restores `/etc/plasmalogin.conf` from its backup, removes the
our fragment and the session fragments, shortcut, sudoers rule and Steam autostart, and
switches back to plasma-login-manager.

The conversion also sets what Steam's System settings show, see
[below](#what-steams-system-settings-show).

**Steam Deck/Machine icons:** `STEAM_GAMEPADUI_ARGS="-gamepadui -steamos3"`
in `~/.config/environment.d/` (and gamescope-session's own environment
file), which makes Steam show Steam Deck button glyphs in gaming mode. It is a sub-option of the SteamOS conversion (`gaming`):
it does nothing without gaming mode, ticking it ticks the conversion and turning the conversion off turns it off.

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

## What Steam's System settings show

With the SteamOS conversion on, `/etc/os-release` gets:

| Key | Value | Shown in Steam as |
|---|---|---|
| `VERSION_ID` | `steamos-3.9`: the newest SteamOS release in Valve's repo (offline: the previous value) | OS Version |
| `VERSION_CODENAME` | `steam-machine` | OS Codename |
| `VARIANT` / `VARIANT_ID` | `Steamify 2.9.0` / `steamify-2.9.0` | OS Variant (`VARIANT_ID`) |

The OS name stays CachyOS everywhere: Steam's OS Name comes from
`lsb_release -d`, which isn't touched, and `NAME`/`PRETTY_NAME` stay
CachyOS's. limine-snapper-sync finds the boot entries by that name, so
changing it would break snapshot boot entries; `/etc/default/limine` gets
`TARGET_OS_NAME="CachyOS"` as a guard when it has none.

KDE's About this System would show `VERSION_ID` after the name
("CachyOS Linux steamos-3.9"); `UseOSReleaseVersion=true` in
`~/.config/kcm-about-distrorc` makes it show `VERSION`, which CachyOS doesn't
have, so it keeps saying "CachyOS Linux".

CachyOS's own hooks (`cachyos-hooks`) reset os-release on updates of
`filesystem`; the pacman hook `zz-steamify-os-release` runs after them and
sets the keys again (`/usr/local/libexec/steamify-os-release`). The values are
refreshed after every Steamify run that changes something. Turning the
conversion off removes the hook and runs CachyOS's `cachyos-branding` again.

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
  DMI data;
- makes the serial number readable for Steam, which shows it in its System
  settings (`/etc/tmpfiles.d/steamify-serial.conf`: `product_serial` is
  root-only by default);
- makes Steam's Wi-Fi backend setting work: steamos-manager switches it in
  `/etc/NetworkManager/conf.d/99-valve-wifi-backend.conf`, which is created
  with `wifi.backend=wpa_supplicant` (NetworkManager's default) when no
  backend is set anywhere yet.

Turning it off removes all of that again (the AUR helper is kept).

The opt-in **Fan monitoring / control (DKMS)** subcomponent is shown only
below Steam Machine support on Fremont hardware. It stays off when the parent
is first enabled, and turning the parent off turns this child off first. The
terminal menu, `--defaults`, backend and QML use the same relationship. Its
ownership and transaction state lives in `lib/steamdeck-hwmon-state.sh` in
Steamify's per-user `STATE_DIR` and stores only eight values: schema, the
current `none|install|remove`
operation, ownership of DKMS and autoload, `jupiter_origin`, its adoption
notice derived from that origin, ownership and previous state of a service
mask, and a restart boot ID. Initial state creation is atomic. System artifacts are marked owned only
after their exact marker, content or registration has been verified; an
interrupted operation is resumed by observing the real system rather than by
maintaining per-step intent/done flags. A missing or invalid state next to
Steamify-specific DKMS or autoload markers remains fail-closed. The one
deliberate recovery exception is the official `jupiter-fan-control` package:
during an explicit enable after lost state, an installed native package
(`pacman -Qn`) with matching metadata from a `cachyos*` sync repository
(`pacman -Si`) becomes `jupiter_origin=adopted`, which also drives the later
UI notice. A normal first enable records an existing package as
`preexisting`, so Steamify will not remove it.

`lib/steamdeck-hwmon-install.sh` implements the component's enable
transaction. It records package ownership before the first system change,
ensures headers for every installed kernel, then runs the provider plan
independently for each target kernel. Only kernels with missing safe providers
are passed to DKMS; blocked or partially foreign providers stop the whole operation before
the DKMS source is installed. The source is registered under
`steamify-steamdeck/1`, and every successful build is re-checked through the
same provider plan. Missing `jupiter-fan-control` is installed by addressing
the verified `cachyos*` repository explicitly. A fresh package must expose
its vendor-enabled unit, but Steamify never calls `systemctl enable`, `start`
or `restart`, so an inactive service still counts as installed. A user-owned
service mask is left alone; a mask previously created and recorded by
Steamify during removal is unmasked after the drivers and autoload are ready,
without starting the service. The owned modules-load file lists `steamdeck` before
`steamdeck_hwmon`; neither module is loaded during installation. The compact
`operation=install` marker proves that a package was absent before
Pacman ran. If Pacman completed immediately before an interruption, the next
run can therefore attribute only that official package to Steamify. A
no-change re-apply performs no system writes. The current boot ID itself is
the restart-pending marker.

`lib/steamdeck-hwmon-remove.sh` implements the matching reboot-based removal
transaction. It verifies ownership and all target-kernel providers before
changing anything. It also parses each target kernel's `modules.dep` and fails
closed when an unrelated module depends on either owned provider, or when the
dependency metadata is unavailable. An active `jupiter-fan-control.service`
is stopped normally first so its packaged `ExecStopPost=... --stop` firmware
handoff runs; a stop failure aborts before package, autoload or DKMS removal.
Steamify removes the package only when it installed or explicitly adopted it,
and uses `pacman -R` so user configuration is not purged. A retained package
is persistently masked before Steamify removes a provider on which its
vendor-enabled unit could depend. Mask ownership and the previously observed
enabled state are recorded so a later enable can restore only Steamify's own
change. Only the exact owned modules-load file and the verified
`steamify-steamdeck/1` DKMS tree are removed. Loaded modules are deliberately
left alone until reboot: removal never calls `modprobe -r` or unbinds devices.

Installation and removal checkpoints include the current kernel boot ID from
`/proc/sys/kernel/random/boot_id`. A matching ID keeps the restart request
pending in the terminal and graphical restart displays; a changed ID clears
the displayed request. This avoids separate installed/removed
phases and does not rely on uptime. Repeated application reconciles the real
package, DKMS and file state idempotently.

The CachyOS `jupiter-fan-control` package currently installs a vendor enable
symlink under `multi-user.target.wants`. Its unit has normal service
dependencies and no explicit `After=systemd-modules-load.service`;
`systemd-modules-load.service` itself has `DefaultDependencies=no`, is wanted
by `sysinit.target`, and is ordered before `sysinit.target`. This gives the
expected indirect boot order on the development host, but the VM acceptance
test must still verify the resolved transaction (`systemctl show` or
`systemd-analyze critical-chain`) and that the module providers exist before
fan control starts. If that proof fails, a narrow ordering drop-in belongs in
the later service-integration phase.

The LEDs appear as `/sys/class/leds/valve-leds*`. The driver's Makefile
builds against the running kernel (`uname -r`) instead of the kernel DKMS
builds for, so the wizard adds a DKMS override
(`/etc/dkms/leds-valve-dkms.conf`) that passes DKMS's target kernel in. With
it, DKMS rebuilds the driver whenever a kernel or its headers are installed
or upgraded. A newly added kernel doesn't come with its headers, so
`ensure-kernel-headers.service` checks at every boot and installs any
missing `-headers` package, which makes DKMS build the driver for it.

## Extended controller support

`extended_controller_support` (`lib/controllers.sh`, top-level, off by default, 2.10.0) installs two kernel drivers from CachyOS's own
repo (no AUR): `xone-dkms` with `xone-dongle-firmware` for the Xbox wireless dongle (the kernel has no driver for it; wired
Xbox controllers go through the same driver), and `xpadneo-dkms` for Xbox One/Series controllers over Bluetooth (without it
they work as plain gamepads but miss rumble including the triggers, the right button mapping and the battery level). Both are
DKMS modules, built for every installed kernel, so `install_kernel_headers` (`lib/steam-machine.sh`) makes sure each kernel has its
headers first. A PC that already has the AUR's `xone-dkms-git` keeps it: it provides the same driver and conflicts with the repo's
`xone-dkms`. Status is the three packages being installed. Off removes only what Steamify installed (state
`extended_controller_support`, `installed_pkgs`); the headers stay. The drivers load when the device shows up: the dongle is
plugged in again, or the controller reconnected. Its test is in steamify-cachyos-dev (`tests/controllers-test.sh`).

## NVIDIA graphics cards

**The problem.** gamescope's gaming mode shows a corrupted picture on NVIDIA graphics cards: NVIDIA's open bug 5240452 (flicker
and artifacts in the DRM session at modes above 2560x1440@120, seen up to driver 595 and on RTX 3070 Ti, 4090, 5090 and 5080; also
[gamescope#2309](https://github.com/ValveSoftware/gamescope/issues/2309)). The kernel parameters `nvidia-drm.modeset=1`/`fbdev=1`
and loading the NVIDIA modules early don't change it, and gamescope nested inside KDE artifacts too.

**The fix.** gamescope with GBM-allocated scan-out buffers, opt-in through the environment variable
`gamescope_drm_gbm_scanout=1`. The patch is nine commits of [farnoy/gamescope](https://github.com/farnoy/gamescope)
(`nvidia-gbm-wayland`). A second small patch keeps Steam's UI server (Steam with `-steamos3` asks gamescope for 1920x1080) at the
display's size. Both are built into one package, `steamify-gamescope-nvidia` (it provides and conflicts with `gamescope`), in
[theupriser/steamify-gamescope-nvidia](https://github.com/theupriser/steamify-gamescope-nvidia): the patches, the PKGBUILD, and CI.
Tested on an RTX 5080 (driver 615.78.08, 3440x1440@175): clean picture, widescreen and sharp Steam UI, Proton games start.
Everything below is `lib/gamescope-nvidia.sh` unless named otherwise.

**What the SteamOS conversion does on an NVIDIA PC** (`gaming_enable` calls `gsn_enable`; `nvidia_present`: PCI vendor 0x10de,
display class, its driver providing `nvidia_drm`; `nvidia_supported`: GTX 16 / RTX 20 series or newer, Turing and later):
1. `gsn_preflight`: no pacman lock, at least 1.5 GB free on `/`. A failure stops before anything changes.
2. `nvidia_swap_out`: turns "Gaming on NVIDIA" off if it was on (see below).
3. On a supported card the kernel parameters, early modules, suspend memory and 32-bit libraries (`nvidia_kernel_enable`,
   `nvidia_extras_enable`, `lib/nvidia.sh`, described below).
4. `gsn_install_package`: the patched gamescope (next paragraph).
5. `gsn_env_enable`: `gamescope_drm_gbm_scanout=1` in `~/.config/gamescope-session/environment` and
   `~/.config/environment.d/99-steamify-gamescope-nvidia.conf`.
6. `gsn_display_enable`: the display wrapper. `patches/gamescope-display-wrapper.sh` is installed as `gamescope` in Steamify's bin
   folder and put first in the gaming session's PATH with a drop-in of `gamescope-session.service` (`steamify-display.conf`). It
   starts gamescope on the mode KDE has saved for the connected display (`~/.config/kwinoutputconfig.json`, modes from
   `modetest`), else the biggest mode at the highest refresh rate; with several displays connected it passes nothing and gamescope
   chooses. `--print-args` shows what it would use.
7. `single_login_release` (`lib/single-user.sh`): single user mode's `zzz-steamify-autologin.conf` is read last and would pin the
   Plasma session, so it goes (turning the conversion off sets it up again). `python_hid_shim_ensure` (`lib/packages.sh`): the
   conversion's dependency jupiter-hw-support wants `python-hid`, which conflicts with `python-hidapi` (liquidctl needs it): an
   empty package providing `python-hid` (`patches/python-hid-shim.PKGBUILD`) makes both work.
Turning the conversion off removes the setting, the wrapper and the kernel settings, and keeps the packages. When the setup
fails, `gsn_fail_mark` records it (state `gamescope_nvidia`, key `failed`) and sends a desktop notification; the menu reminds
(`gsn_fail_note`) until a setup works. A failed option's sub-options aren't applied.

**Getting the package, and keeping it current.** gamescope changes every few weeks, so the package is downloaded, not carried.
CI builds it in CachyOS's container, once per CPU level like CachyOS's repositories: generic, x86-64-v3, v4 and znver4, each with an
explicit `-march` (a `-march=native` build died with SIGILL on a Ryzen) and checked for instructions beyond its level and for both
patches. A release is `<gamescope version>-<package release>` (for example `3.16.31-3`) with `SHA256SUMS`. `gsn_cpu_variant`
picks the build for this CPU (the dynamic loader's x86-64 level; AMD with `avx512_bf16` is znver4) and generic is the fallback.
`gsn_fetch_package` tries, for the CPU's variant and then generic: the newest release on GitHub (if newer than the pin), the release
Steamify was tested with (`GSN_VERSION`, hashes in `GSN_SHA256`: from GitHub, the cache, or the copy the ISO leaves in
`/usr/local/share/steamify/gamescope`); only files with the expected sha256 count (newer releases: their `.sha256`). If nothing is
reachable, `gsn_build_package` builds from `patches/gamescope-nvidia.PKGBUILD` and the two patches (`makepkg` as the user in
`~/.cache/steamify`). `gsn_install_package` installs with `pacman -U --ask 4`; `gsn_smoke_test` then starts gamescope headless
and installs the generic build instead if it doesn't start. Nothing else changes before a package is installed. A newer release than
the installed package shows the conversion as an update (`gsn_update_pending`, looked up at most every six hours, quiet offline).
A new pin = the release's tag and each variant's sha256 in `GSN_VERSION` and `GSN_SHA256` plus the PKGBUILD's pkgver/pkgrel; the patches in `patches/` must
stay identical to that repository's. New gamescope versions: the repository's daily check bumps the version when the patch still
applies, or opens an issue when it needs a rebase; a person merges and tags the release.

**What the kernel side does** (`lib/nvidia.sh`; a supported card only): `nvidia-drm.modeset=1 nvidia-drm.fbdev=1` on the kernel command
line (Limine, systemd-boot or GRUB; the file is backed up first; on Limine into the existing `KERNEL_CMDLINE[default]="..."` or
`+="..."` line, never an extra appended line, which ends up as text), and `/etc/mkinitcpio.conf.d/90-steamify-nvidia.conf`
(`MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)`), then the initramfs and boot entries are rebuilt and checked. The
early-load drop-in is only there while every installed kernel has the NVIDIA modules (mkinitcpio fails on a missing module): a
pacman hook (`/etc/pacman.d/hooks/85-steamify-nvidia-initramfs.hook`) runs `/usr/local/libexec/steamify-nvidia-initramfs` at every
kernel or driver change and decides again. `nvidia_extras_enable` adds `NVreg_PreserveVideoMemoryAllocations=1`
(`/etc/modprobe.d/90-steamify-nvidia.conf`), enables `nvidia-suspend`/`resume`/`hibernate` and installs `lib32-nvidia-utils` and
`lib32-libxkbcommon`. Takes effect at the next boot. The tests are in steamify-cachyos-dev: `tests/nvidia-test.sh` (a fake GPU, a
stub `pacman` and `systemctl`, a temp home) and `tests/nvidia-hardware-test.sh` (a real NVIDIA PC).

**Limits.** Tested on one PC (RTX 5080, Ryzen). The "Add as non-Steam game" option isn't offered on NVIDIA PCs yet. Steam must keep
running with `-steamos3` (the Display settings' "Maximum Game Resolution" exists only with it, and dropping it or setting
`XWAYLAND_COUNT=1` stopped games from launching). If upstream fixes the bug, the patched package and this section go, and Steamify
goes back to the stock gamescope.

**"Gaming on NVIDIA" (before 2.12.0).** With an NVIDIA GPU the SteamOS conversion (`gaming`, and its options `boot`, `single`, `glyphs`) wasn't offered, unless
it was already on. `nvidia` ("Gaming on NVIDIA", `lib/nvidia.sh`) took its place (both would start Steam at login): it installs `steam` when missing (recorded in state `nvidia`, removed again only then) and enables the user
unit `steamify-steam-autostart.service` (`services/`, `ExecStart=/usr/bin/steam @ARGS@`, Plasma only). Its sub-option
`bigpicture` ("Steam starts in Big Picture", ticked along with it) rewrites the unit with `-gamepadui` and sets
`ksmserverrc [General] loginMode=emptySession` (`kset`, undone with `krevert bigpicture`), so windows of the last session
(Discord, a browser) aren't restored on top of Big Picture; unticked, Steam starts in its normal window. The opt-in sub-option `nvsilent` ("Start Steam silently") rewrites the unit with `-silent`
(tray only); it and `bigpicture` exclude each other. The PC always boots into the desktop: there is no gamescope session. Takes effect at the next
login.

On a supported card (RTX 20 series or newer: not on chwd's legacy lists `/var/lib/chwd/ids/nvidia-*.ids`, the VRAM booster's
check, `vram_nvidia_legacy_id`; `nvidia_supported`) enabling it also does what NVIDIA's DRM stack wants, though it didn't cure
gamescope: `nvidia-drm.modeset=1 nvidia-drm.fbdev=1` on the kernel command line (Limine, systemd-boot or GRUB; the file is
backed up first; on Limine into the existing `KERNEL_CMDLINE[default]="..."` or `+="..."` line, never an extra appended line,
which ends up as text; the kernel treats `nvidia_drm` and `nvidia-drm` alike) and
`/etc/mkinitcpio.conf.d/90-steamify-nvidia.conf` (`MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)`), then the initramfs
and boot entries are rebuilt and checked for the parameters. The early-load drop-in is only there while every installed kernel
has the NVIDIA modules (mkinitcpio fails on a missing module, and `limine-mkinitcpio` then skips that kernel's boot entry):
a pacman hook (`/etc/pacman.d/hooks/85-steamify-nvidia-initramfs.hook`, after DKMS, before the initramfs is built) runs
`/usr/local/libexec/steamify-nvidia-initramfs` at every kernel or driver change and decides again. Turning it off removes
all of it. The tests are in steamify-cachyos-dev: `tests/nvidia-test.sh` (a fake GPU, a stub `pacman` and `systemctl`, a temp home) and `tests/nvidia-hardware-test.sh` (a real NVIDIA PC).

Tried and dropped (notes in steamify-cachyos-dev, `nvidia/HARDWARE-RESULTS.md`): a gamescope session that opens Big Picture in Plasma (it needed the `start-gamescope-session`
command shadowed in `/usr/local/bin`, and showed the desktop for a few seconds, then a Steam window with a black border);
a KWin session without Plasma (the mouse stuttered every second or two).

## HDMI-CEC

The **HDMI-CEC** item (on every PC; ticked by default only on a Steam
Machine) installs
Valve's CEC stack from its SteamOS `holo` repository, the newest `holo-X.Y`
on `steamdeck-packages.steamos.cloud`, each package checked against the
SHA-256 in Valve's package index:

- `cecd`, Valve's CEC daemon (a user service started with the desktop and
  gaming mode): TV remote keys become normal key presses (arrows, Enter,
  Back), and it turns the TV on and off with the PC;
- `cec-audio-control`: volume of the TV or receiver (the TV remote's volume
  keys); its user socket is enabled by Steamify, since SteamOS enables it
  through a preset that pacman doesn't apply;
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

## HDMI-CEC volume (Steam Machine)

On SteamOS, Steam's Audio settings show **TV Volume** buttons (minus, plus, mute) and an "Enable HDMI CEC control" toggle
when the output is the TV; on CachyOS they show a slider that doesn't reach the TV (#107). Steam only shows the buttons when
PipeWire tells it the HDMI output's volume is handled externally, and that is something Valve patched into its own builds:
Valve's `libspa-alsa.so` reads the sink property `api.alsa.external-volume-control` (the socket of `cec-audio-control`,
`org.pipewire.ExternalVolume`, a varlink service) and its WirePlumber gates it with the setting
`monitor.alsa.enable-external-volume-control`; CachyOS's PipeWire (1.6.10) and WirePlumber have neither. Found by comparing
the two builds and by testing on a Steam Machine: with only Valve's WirePlumber Steam showed the toggle with "The connected
device does not support HDMI CEC for volume and mute settings" (nothing ever connected to the socket); with both, the
buttons appear. The TV doesn't have to report its volume (a Sony TV that answers Feature Abort to the audio-status queries
showed them).

The **HDMI-CEC volume** sub-option of HDMI-CEC (`cecaudio`, `lib/cec-audio.sh`, only on a Steam Machine, ticked along with
HDMI-CEC like the power-off fix) therefore **replaces CachyOS's PipeWire and WirePlumber by Valve's builds**:

- `patches/steamify-valve-audio.sh` (installed as `/usr/local/lib/steamify/steamify-valve-audio`) fills a **local pacman
  repository**, `/var/lib/steamify/valve-audio` (`steamify-valve-audio`), with the installed `pipewire`, `libpipewire`,
  `pipewire-audio`, `-alsa`, `-pulse`, `gst-plugin-pipewire`, `wireplumber` and `libwireplumber` (and `lib32-pipewire`,
  `lib32-libpipewire` when installed) from Valve's newest `jupiter-X.Y` repository (64-bit) and `multilib-X.Y` (32-bit,
  plain Arch builds at the same upstream version), each checked against the SHA-256 in Valve's package index. It copies the
  database to `/var/lib/pacman/sync` itself (no `pacman -Sy`, which would refresh every other repository: a partial upgrade).
- The repository is listed in `/etc/pacman.conf` **before** CachyOS's repositories (backed up with `backup_file`): the first
  repository with a package decides which version pacman takes, so `pacman -Syu` keeps Valve's build instead of upgrading to
  CachyOS's, and takes a newer Valve build once the repository has it. Adding Valve's own repository to the list wouldn't
  work: pacman can't take a few packages from a repository, and its kernel, Mesa and systemd would replace CachyOS's.
- A weekly timer (`steamify-valve-audio.timer`) runs that script, so the repository follows Valve's releases; it never
  installs anything itself. Valve is usually a few patch releases behind Arch (1.6.8 against 1.6.10 at the time of writing)
  and re-patches per SteamOS release: the build is "Valve's current one", not the newest PipeWire.
- Valve's `pipewire` package has symlinks in `/etc/pipewire` (`client.conf.d` and `client-rt.conf.d`, to `/run/pipewire`) where
  CachyOS's `libpipewire` has empty directories, and pacman doesn't turn a directory into a symlink: the two (empty)
  directories are removed first. Valve's packages also pull in `steamdeck-dsp` and `noisetorch`; `steamdeck-dsp` owns
  `/etc/wireplumber` (a symlink to a `/run` directory that doesn't exist), so the WirePlumber rule goes in the user's
  `~/.config/wireplumber/wireplumber.conf.d/90-steamify-cec-volume.conf`: the HDMI sound card gets the socket as
  `api.alsa.external-volume-control`, the description "HDMI / DisplayPort" (what Steam shows on SteamOS) and
  `monitor.alsa.enable-external-volume-control = true`.
- **A restart is asked for** (the same prompt as the login changes), and nothing is restarted live: PipeWire, WirePlumber and
  everything using them (Sunshine and a Moonlight stream, games, Steam) keep running with the old libraries until then. A live
  restart was tried first and took Moonlight's host down: Sunshine's unit rate-limits starts (five in 500 s) and a few
  on/off rounds hit that. Not every PC has Sunshine, or another program that depends on PipeWire staying up, so the option
  doesn't look for them. Steam shows the buttons after that restart.

Turning it off removes the unit, the script, the rule, the repository and its `pacman.conf` section (the file is identical to
its backup afterwards), reinstalls the packages it swapped from CachyOS's repositories and removes the packages Valve's
brought along. Tested on a Steam Machine (Sony TV): on, off, and on again leave the same state; Steam shows the buttons only
with it on; PipeWire's graph timing on the HDMI output (quantum 1024 at 48 kHz, 0 dropouts) is the same with either build.
The 32-bit libraries are moved to Valve's version too, so all of PipeWire is one version.

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

## Wi-Fi firmware (Steam Machine)

The Steam Machine's Wi-Fi adapter is a Qualcomm QCNFA765 (`17cb:1103`, QCA2066, `ath11k_pci`). CachyOS's
`linux-firmware-atheros` and SteamOS report the same firmware version
(`WLAN.HSP.1.1-03926.13-...`), but their `amss.bin` differs (builds from
2025-07-16 10:33 and 10:46; decompressed SHA-256 `6be9c226...` and
`a0c75e4c...`; `board-2.bin` and `m3.bin` are identical). With CachyOS's, a
suspend with Wake-on-WLAN on (`iw phy phyN wowlan enable magic-packet`) ends at
once: the adapter raises a PCIe PME (`Triggering wakeup from IRQ 40`, the
root port, `RootSta: PME ReqID 0600`) and the machine wakes. With SteamOS's it
stays asleep and wakes on a Wi-Fi magic packet (found and tested by a user,
#108).

Valve ships its build as `linux-firmware-holo` in the `holo-main` repository of
its package mirror (not in the numbered `holo-X.Y` repositories, and not in
`core`, which has the same `amss.bin` as CachyOS), under
`usr/lib/firmware/updates/`. The **Wi-Fi firmware from SteamOS** sub-option of Steam
Machine support (`wifi`, `lib/fremont-wifi.sh`, opt-in, only offered on a
Steam Machine with that adapter) downloads that package with the checksum from
Valve's package index (`fetch_holo_pkg`) and installs only
`ath11k/QCA2066/hw2.1/amss.bin.zst` to the same place. The kernel reads
`/usr/lib/firmware/updates` before `/usr/lib/firmware`, so no file of
`linux-firmware` is changed (its updates don't undo this, and there is nothing
to back up); turning the item off removes the one file. The menu row says which `amss.bin` the kernel will load (the decompressed SHA-256 against the two
known builds: Valve's, CachyOS's, or another one, e.g. from a newer `linux-firmware`), and nothing is
installed when the package already ships Valve's. The new firmware is
loaded at the next restart. Tested on a Steam Machine: after the restart
`dmesg | grep fw_build_timestamp` shows `2025-07-16 10:46` (CachyOS's own build is `10:33`).

## Wake-on-LAN and Wake-on-WLAN (Steam Machine)

Two opt-in sub-options of Steam Machine support (`wol` and `wowlan`, `lib/wake-on-lan.sh`). Linux doesn't keep either
setting: `ethtool -s ... wol g` and `iw phy ... wowlan enable magic-packet` are gone after a restart.

- **Wired** (`wol`) is offered where there is an `en*` network device. NetworkManager sets it for the connections that
  don't have their own value (`default`): one drop-in, `/etc/NetworkManager/conf.d/90-steamify-wake-on-lan.conf`
  (`ethernet.wake-on-lan=64`, magic packet, in a `connection-steamify-wake-on-lan` section), and nothing of
  NetworkManager's own files is edited. After writing it the item reloads NetworkManager's configuration
  (`nmcli general reload conf`) and re-applies the wired devices (`nmcli device reapply`), which doesn't drop the
  connection. Off removes the file. It wakes the machine from **sleep** (s2idle); it does not wake it from a power-off:
  tried on a Steam Machine with the BIOS's "S4/S5 WoL" and "S4 WoWiFi" both on, a magic packet for the wired adapter's MAC
  did not start it (the machine stayed off for over two minutes, a wrong-MAC packet and no packet did nothing either), while
  from sleep it woke 3 times out of 3. The link was not checked while off (is the port's light on?), and hibernate (S4) is
  untested.
- **Wireless** (`wowlan`) is only offered with the QCA2066 adapter and wakes from sleep only (the BIOS has an "S4 WoWiFi"
  switch for hibernate, which is untested). NetworkManager can't do it here: with the iwd backend (the Steam Machine's, in
  `99-valve-wifi-backend.conf`) it ignores `wifi.wake-on-wlan`, also set on the connection itself and after a reconnect
  (tried on a Steam Machine), and with any backend it can't change it on a live connection. So two small scripts run
  `iw phy ... wowlan enable magic-packet`: a **NetworkManager dispatcher script**,
  `/etc/NetworkManager/dispatcher.d/90-steamify-wowlan` ([`patches/steamify-wowlan-dispatcher.sh`](patches/steamify-wowlan-dispatcher.sh)),
  when a Wi-Fi connection comes up (and once right away for a Wi-Fi that is already connected when the item is turned on), and
  a systemd sleep hook, `/usr/lib/systemd/system-sleep/steamify-wowlan`
  ([`patches/steamify-wowlan-sleep.sh`](patches/steamify-wowlan-sleep.sh)), right before each suspend (`pre`). The hook alone, the
  2.14.0 and 2.14.1 way, was too late for the **first suspend of a boot**: with WoWLAN still off before it, that suspend did not wake
  on a Wi-Fi magic packet (tested on a Steam Machine: the packet got no wake in 33 s, a wired one did; the second suspend of the same
  boot woke on the Wi-Fi packet in 4 s). A user found it (#108) and found that enabling it while the Wi-Fi is connected avoids it, with
  the iwd and the wpa_supplicant backend alike. The hook stays as a fallback; both are idempotent. The item installs `iw` when it
  is missing. Off removes both and turns the setting off. It needs the
  [SteamOS Wi-Fi firmware](#wi-fi-firmware-steam-machine): with CachyOS's own the machine wakes up again at once.
  Ticking it ticks that item; unticking the firmware unticks it. A `90-steamify-wake-on-wlan.conf` of a development
  build of 2.14.0 is removed when found.

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
closed (`steam -shutdown`) for the edit and started again (`steam -silent`). That's refused in gaming
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
| `~/.config/autostart/steam.desktop` | the `silent` option (Steam's "Run Steam when my computer starts") |
| `~/.config/systemd/user/` | `steamify-update-check.*` |

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

`steamify.sh --boot gamescope|desktop` sets where the PC starts after a
restart (the menu's Boot into row) from a script: it needs the SteamOS
conversion and changes nothing else, not even the updates a normal run would
apply. Exit code 1 without the conversion or with another value.

## Install-time mode (`--defaults`)

For an installer (the Steam Machine ISO), without a session or prompts
(passwordless sudo required):

```bash
steamify.sh --defaults                                  # what the menu would preselect
steamify.sh --defaults --options gaming,theme,cec,machine --boot desktop
steamify.sh --defaults --list                           # what --defaults can set up here, as JSON
```

`--options` turns on exactly the listed items (the menu's ids: `gaming`,
`theme`, `glyphs`, `single`, `launcher`, `notify`, `vram`, `cec`, `machine`,
`poweroff`), everything else off; an item that's on brings its parent
(single user the conversion, the power-off fix Steam Machine support). An
item this PC can't use (e.g. `vram` without a VRAM region) is left off with
a warning. `--boot desktop` needs `gaming`. Unknown options, ids, `boot` or
`bios` in the list: exit code 1 before anything changes. What needs a
Plasma session waits for the first login (`lib/first-login.sh`). The same step (and the online theme path) replaces Plasma's default taskbar pins, which include Discover
(not installed on CachyOS: a blank icon), by CachyOS's own (`taskbar_drop_discover` in `lib/vapor-theme.sh`; skipped when Discover is
installed or the taskbar already has its own `launchers`).

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
| `lib/login-manager.sh` | SteamOS conversion: plasma-login-manager autologin |
| `lib/steam-desktop.sh` | Steam in the Plasma session; Steam Deck/Machine icons |
| `lib/desktop-shortcut.sh` | Return to Gaming Mode shortcut and its sudoers rule |
| `lib/vapor-theme.sh` | SteamOS theme: installs and switches to `cachyos-vapor` |
| `lib/steamos-extras.sh` | SteamOS desktop extras from Valve's package (Add to Steam, Nested Desktop, icon, keyboard rule, KWallet) |
| `lib/single-user.sh` | Single user mode: no lock screen, user switching or log out |
| `lib/wizard-shortcut.sh` | Steamify shortcut: desktop icon and launcher entry that run the newest release |
| `lib/bios.sh` | Update BIOS (Steam Machine, opt-in): current/newest version, double confirmation, fwupd |
| `lib/cec.sh` | HDMI-CEC: Valve's `cecd` and friends from its `holo` repository |
| `lib/cec-audio.sh` | Steam Machine: the TV's volume buttons in Steam (Valve's PipeWire and WirePlumber from a local pacman repository) |
| `lib/steam-machine.sh` | Steam Machine support: LED driver, LED access, steamos-manager |
| `lib/steamdeck-hwmon.sh` | Steam Machine fan support: per-kernel provider detection, DKMS conflict protection and staging/build decisions for the pinned MFD/hwmon sources |
| `lib/steamdeck-hwmon-state.sh` | Steam Machine fan support: compact persistent ownership, one resumable operation and Boot-ID restart marker |
| `lib/steamdeck-hwmon-install.sh` | Steam Machine fan support: transactional DKMS/package installation and next-boot module autoload preparation; never loads modules or starts fan control live |
| `lib/steamdeck-hwmon-remove.sh` | Steam Machine fan support: transactional service handoff and owned-artifact removal; retained vendor-enabled packages are safely masked and loaded modules stay untouched until reboot |
| `lib/fremont-poweroff.sh` | Steam Machine support: the power-off fix (DKMS module from `patches/`) |
| `lib/fremont-wifi.sh` | Steam Machine support: Wi-Fi firmware from SteamOS (Wake-on-WLAN) |
| `lib/wake-on-lan.sh` | Steam Machine support: Wake-on-LAN and Wake-on-WLAN (NetworkManager drop-ins) |
| `lib/steam-game.sh` | Add as non-Steam game: Steamify in the Steam library (`patches/steam-shortcuts.py`) |
| `lib/update-notifier.sh` | Update notifications: the notifier from `patches/` and its user timer |
| `lib/first-login.sh` | `--defaults` without a session (the Steam Machine ISO's installer): the one-time first-login step that sets up single user's launcher on Plasma's new layout and opens the app |
| `lib/controllers.sh` | Extended controller support: Xbox wireless dongle (xone) and Xbox Bluetooth (xpadneo) from the CachyOS repo |
| `lib/gamescope-nvidia.sh` | gamescope on NVIDIA: builds and installs the patched gamescope (GBM scan-out) from steamify-gamescope-nvidia and sets `gamescope_drm_gbm_scanout=1` for the SteamOS conversion |
| `lib/nvidia.sh` | Gaming on NVIDIA: Steam on the desktop, started at login, optionally in Big Picture (replaces the SteamOS conversion there) |
| `lib/vram-booster.sh` | VRAM booster (`dmemcg-booster`, `plasma-foreground-booster`) |
| `services/` | The systemd units the scripts install (`service_file`, `@KEY@` placeholders); see its README |
| `patches/` | Module sources and patches the scripts build or apply (`patch_file`); see its README |
| `.github/tools/bundle.sh` | Builds the single-file version (`dist/steamify.sh`), with `patches/` and `services/` embedded |
| `.github/workflows/bundle.yml` | Builds and checks it on every push (GitHub and a Gitea mirror); publishes it on `main`, and starts the Steamify ISO's release |

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
