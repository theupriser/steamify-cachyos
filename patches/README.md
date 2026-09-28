# Patches and extra sources

Files Steamify builds or applies, kept out of the shell code so they can be
read and reviewed on their own. `lib/*.sh` reads them with `patch_file
<name>` (piped through `fill KEY=value...` for `@KEY@` placeholders); the single-file build (`.github/tools/bundle.sh`) embeds them.

| File | Used by | What |
|---|---|---|
| `steamify-fremont-poweroff.c` | `lib/fremont-poweroff.sh` (Steam Machine support) | Kernel module (DKMS): clears GPIO 18's S4/S5 wake bit before power-off, so the Steam Machine stays off with recent kernels |
| `sync-steamos-session.sh` | `lib/login-manager.sh` (SteamOS conversion, plasma-login-manager) | The sync bridge: copies Steam's session choice from `zz-steamos-autologin.conf` into `plasmalogin.conf`'s `[Autologin]` |
| `ensure-kernel-headers.sh` | `lib/steam-machine.sh` (Steam Machine support) | Run at boot: installs missing headers for every installed kernel |
| `leds-valve-dkms.conf` | `lib/steam-machine.sh` (Steam Machine support) | `/etc/dkms` override: build the LED driver for DKMS's target kernel; appended to someone's own override, which is backed up and restored |
| `steamify-fremont-poweroff.dkms.conf`, `steamify-cros-ec-cec.dkms.conf` | `lib/fremont-poweroff.sh`, `lib/cec.sh` | The DKMS modules' `dkms.conf` (`fill NAME=... VERSION=...`) |
| `steam-shortcuts.py` | `lib/steam-game.sh` (Add as non-Steam game) | Reads and writes Steam's binary `shortcuts.vdf` (find, add or update, remove) |
| `steamify-notifier.py` | `lib/update-notifier.sh` (Update notifications) | The daily check: notification and tray icon when there's a new release |
| `steamify-os-release.sh`, `steamify-os-release.hook` | `lib/login-manager.sh` (SteamOS conversion) | What Steam's System settings show besides the OS name (which stays CachyOS's): `VERSION_ID=steamos-X.Y`, `VERSION_CODENAME=steam-machine`, `VARIANT`/`VARIANT_ID` Steamify with its version, in `/etc/os-release`; the pacman hook runs it again after cachyos-hooks (`fill SCRIPT=... VERSION=... STEAMOS=...`) |
| `cros-ec-cec-single-port.patch` | `lib/cec.sh` (HDMI-CEC) | Makes Valve's Steam Machine CEC driver find amdgpu's HDMI port |
