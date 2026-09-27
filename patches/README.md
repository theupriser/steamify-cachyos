# Patches and extra sources

Files Steamify builds or applies, kept out of the shell code so they can be
read and reviewed on their own. `lib/*.sh` reads them with `patch_file
<name>`; the single-file build (`.github/tools/bundle.sh`) embeds them.

| File | Used by | What |
|---|---|---|
| `steamify-fremont-poweroff.c` | `lib/fremont-poweroff.sh` (Steam Machine support) | Kernel module (DKMS): clears GPIO 18's S4/S5 wake bit before power-off, so the Steam Machine stays off with recent kernels |
| `sync-steamos-session.sh` | `lib/login-manager.sh` (SteamOS conversion, plasma-login-manager) | The sync bridge: copies Steam's session choice from `zz-steamos-autologin.conf` into `plasmalogin.conf`'s `[Autologin]` |
| `ensure-kernel-headers.sh` | `lib/steam-machine.sh` (Steam Machine support) | Run at boot: installs missing headers for every installed kernel |
| `steamify-notifier.py` | `lib/update-notifier.sh` (Update notifications) | The daily check: notification and tray icon when there's a new release |
| `cros-ec-cec-single-port.patch` | `lib/cec.sh` (HDMI-CEC) | Makes Valve's Steam Machine CEC driver find amdgpu's HDMI port |
