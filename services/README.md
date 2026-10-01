# Services

The systemd units Steamify installs, kept out of the shell code so they can
be read and reviewed on their own. `lib/*.sh` reads them with `service_file
<name> [KEY=value...]`, which fills in `@KEY@` placeholders (paths the
scripts define); the single-file build (`.github/tools/bundle.sh`) embeds
them. Small drop-ins that only add a line or two to someone else's unit stay
in the shell code.

| File | Used by | What |
|---|---|---|
| `steamify-boot-desktop.service` | `lib/boot-session.sh` (Boot into: desktop) | Sets the Plasma session before the login manager starts |
| `sync-steamos-session.path`, `.service` | `lib/login-manager.sh` (SteamOS conversion, plasma-login-manager) | The sync bridge: copies Steam's session choice into `plasmalogin.conf` |
| `steamify-steam-autostart.service` | `lib/nvidia.sh` (Gaming on NVIDIA) | Steam at login on the Plasma desktop, normal or in Big Picture (user unit) |
| `steam-desktop-autostart.service` | `lib/steam-desktop.sh` (SteamOS conversion) | Steam in the background on the Plasma desktop (user unit) |
| `ensure-kernel-headers.service` | `lib/steam-machine.sh` (Steam Machine support) | Installs missing kernel headers at boot, so DKMS builds for every kernel |
| `steamify-update-check.service`, `.timer` | `lib/update-notifier.sh` (Update notifications) | The daily and login check for a new release (user units) |
