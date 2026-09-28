#!/bin/sh
# Installed by Steamify CachyOS (SteamOS conversion): what Steam shows in its
# System settings. The OS name is `lsb_release -d` (DISTRIB_DESCRIPTION in
# /etc/lsb-release); the version comes from /etc/os-release's VARIANT and
# VERSION_ID. CachyOS's hooks reset lsb-release on updates of lsb-release and
# cachyos-hooks; the zz-steamify-os-release hook runs this after them.
# os-release's NAME and PRETTY_NAME stay CachyOS's: limine-snapper-sync finds
# the boot entries by the OS name.
sed -i 's|^DISTRIB_DESCRIPTION=.*$|DISTRIB_DESCRIPTION="CachyOS with Steamify"|' /etc/lsb-release
sed -i -e '/^VARIANT=/d' -e '/^VARIANT_ID=/d' -e '/^VERSION_ID=/d' /etc/os-release
printf '%s\n' 'VARIANT="Steamify"' 'VARIANT_ID=steamify' 'VERSION_ID=@VERSION@' >> /etc/os-release
