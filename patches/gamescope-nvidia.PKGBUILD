# Maintainer: theupriser
# Based on Arch Linux's gamescope PKGBUILD (Maxime Gauduin, Giancarlo Razzolini, Sven-Hendrik Haase and contributors).
#
# gamescope with GBM-allocated scan-out buffers for NVIDIA (opt-in: gamescope_drm_gbm_scanout=1).
# The patches are gamescope-gbm-scanout.patch and gamescope-ui-native.patch (next to this file, applied in this order); see the
# README for where they come from.
# UPSTREAM_VERSION (next to this file) names the gamescope tag the patches are made for.

pkgname=steamify-gamescope-nvidia
_srcname=gamescope
pkgver=3.16.31
pkgrel=3
pkgdesc='SteamOS session compositing window manager, with GBM scan-out for NVIDIA (opt-in: gamescope_drm_gbm_scanout=1)'
arch=(x86_64)
url=https://github.com/theupriser/steamify-gamescope-nvidia
license=(
  BSD-2-Clause
  BSD-3-Clause
  LicenseRef-Reshade
)
provides=("gamescope=$pkgver")
conflicts=(gamescope gamescope-nvidia-gbm)
replaces=(gamescope-nvidia-gbm)
depends=(
  glibc
  mesa
  libstdc++
  libgcc
  lcms2
  libavif
  libcap.so
  libdecor
  libdrm
  libei
  libinput
  libpipewire-0.3.so
  libx11
  libxcb
  libxcomposite
  libxcursor
  libxdamage
  libxext
  libxfixes
  libxi
  libxkbcommon.so
  libxmu
  libxrender
  libxres
  libxtst
  libxxf86vm
  luajit
  pixman
  sdl2
  seatd
  systemd-libs
  vulkan-icd-loader
  wayland
  xcb-util-errors
  xcb-util-wm
  xorg-server-xwayland
)
makedepends=(
  benchmark
  cmake
  git
  glslang
  meson
  ninja
  vulkan-headers
  wayland-protocols
  catch2
)
source=(
  gamescope::git+https://github.com/ValveSoftware/gamescope.git#commit=${pkgver}
  gamescope-gbm-scanout.patch
  gamescope-ui-native.patch
  git+https://gitlab.freedesktop.org/emersion/libdisplay-info.git
  git+https://gitlab.freedesktop.org/emersion/libliftoff.git
  git+https://github.com/ValveSoftware/openvr.git
  git+https://github.com/Joshua-Ashton/reshade.git
  git+https://github.com/KhronosGroup/SPIRV-Headers.git
  git+https://github.com/Joshua-Ashton/vkroots.git
  git+https://gitlab.freedesktop.org/wlroots/wlroots.git
)
b2sums=('SKIP'
        'SKIP'
        'SKIP'
        'SKIP'
        'SKIP'
        'SKIP'
        'SKIP'
        'SKIP'
        'SKIP'
        'SKIP')

prepare() {
  cd gamescope

  # GBM scan-out for NVIDIA. If it no longer applies to this gamescope version, stop here: the build must not
  # silently produce an unpatched gamescope under this package's name.
  git apply --check ../gamescope-gbm-scanout.patch || { echo "gbm patch does not apply to gamescope ${pkgver}" >&2; return 1; }
  git apply ../gamescope-gbm-scanout.patch
  git apply --check ../gamescope-ui-native.patch || { echo "ui-native patch does not apply to gamescope ${pkgver}" >&2; return 1; }
  git apply ../gamescope-ui-native.patch

  meson subprojects download

  for submodule in src/reshade subprojects/{libdisplay-info,libliftoff,openvr,vkroots,wlroots} thirdparty/SPIRV-Headers; do
    git submodule init ${submodule}
    git config submodule.${submodule}.url ../${submodule##*/}
  done
  git -c protocol.file.allow=always submodule update
}

build() {
  arch-meson gamescope build \
    -Dforce_fallback_for=glm,stb,libdisplay-info,libliftoff,vkroots \
    -Dpipewire=enabled
  meson compile -C build
}

package() {
  DESTDIR="${pkgdir}" meson install -C build \
    --skip-subprojects
  install -Dm 644 gamescope/LICENSE -t "${pkgdir}"/usr/share/licenses/${pkgname}/
}

# vim: ts=2 sw=2 et:
