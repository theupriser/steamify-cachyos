#!/bin/sh
# Installed by Steamify CachyOS (SteamOS conversion): what Steam shows in its
# System settings besides the OS name, which stays CachyOS's: Steamify as the
# variant with its version, and the SteamOS release it follows as the
# codename (/etc/os-release's VARIANT, VERSION_CODENAME). No VERSION_ID: KDE's
# About this System would show it after CachyOS's name ("CachyOS Linux 2.9.0"). NAME and
# PRETTY_NAME are never touched: limine-snapper-sync finds the boot entries by
# the OS name. The zz-steamify-os-release hook runs this after cachyos-hooks.
sed -i -e '/^VARIANT=/d' -e '/^VARIANT_ID=/d' -e '/^VERSION_ID=/d' -e '/^VERSION_CODENAME=/d' /etc/os-release
printf '%s\n' 'VARIANT="Steamify @VERSION@"' 'VARIANT_ID=steamify' >> /etc/os-release
[ -n "@CODENAME@" ] && echo 'VERSION_CODENAME=@CODENAME@' >> /etc/os-release
exit 0
