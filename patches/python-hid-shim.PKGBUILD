# Maintainer: theupriser
# An empty package that only tells pacman "python-hid is there". For a PC that keeps python-hidapi (liquidctl needs it):
# the real python-hid conflicts with it, and jupiter-hw-support (a dependency of gamescope-session-cachyos) wants python-hid.
# Only Valve's Steam Deck controller firmware updater in jupiter-hw-support uses it, which a PC doesn't run.
# Steamify (lib/packages.sh) builds it with makepkg and installs it before the conversion's packages.
pkgname=steamify-python-hid-shim
pkgver=1
pkgrel=1
pkgdesc='Placeholder: python-hid for PCs that keep python-hidapi (they conflict)'
arch=(any)
license=(MIT)
depends=(python-hidapi)
provides=('python-hid=99')

package() {
    :
}
