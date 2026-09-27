# Patches and extra sources

Files Steamify builds or applies, kept out of the shell code so they can be
read and reviewed on their own. `lib/*.sh` reads them with `patch_file
<name>`; the single-file build (`.github/tools/bundle.sh`) embeds them.

| File | Used by | What |
|---|---|---|
| `steamify-fremont-poweroff.c` | `lib/fremont-poweroff.sh` (Steam Machine support) | Kernel module (DKMS): clears GPIO 18's S4/S5 wake bit before power-off, so the Steam Machine stays off on kernels 7.2 and newer |
| `cros-ec-cec-single-port.patch` | `lib/cec.sh` (HDMI-CEC) | Makes Valve's Steam Machine CEC driver find amdgpu's HDMI port |
