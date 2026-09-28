#!/bin/sh
# Installed by Steamify CachyOS (SteamOS conversion): what Steam shows in its
# System settings besides the OS name, which stays CachyOS's: the SteamOS
# release Steamify follows as the OS version (VERSION_ID, e.g. steamos-3.9),
# steam-machine as the codename, and Steamify with its version as the variant
# (VARIANT_ID, which Steam shows). KDE's About this System would show
# VERSION_ID after the name: the conversion sets its UseOSReleaseVersion, so it
# shows os-release's VERSION instead, which CachyOS doesn't have. NAME and
# PRETTY_NAME are never touched: limine-snapper-sync finds the boot entries by
# the OS name. The zz-steamify-os-release hook runs this after cachyos-hooks.
sed -i -e '/^VARIANT=/d' -e '/^VARIANT_ID=/d' -e '/^VERSION_ID=/d' -e '/^VERSION_CODENAME=/d' /etc/os-release
printf '%s\n' 'VARIANT="Steamify @VERSION@"' 'VARIANT_ID=steamify-@VERSION@' 'VERSION_CODENAME=steam-machine' >> /etc/os-release
[ -n "@STEAMOS@" ] && echo 'VERSION_ID=@STEAMOS@' >> /etc/os-release
exit 0
