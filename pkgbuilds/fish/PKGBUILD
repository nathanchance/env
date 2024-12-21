# Maintainer: Levente Polyak <anthraxx[at]archlinux[dot]org>
# Contributor: Bartłomiej Piotrowski <bpiotrowski@archlinux.org>
# Contributor: Kaiting Chen <kaitocracy@gmail.com>
# Contributor: Abhishek Dasgupta <abhidg@gmail.com>
# Contributor: Eric Belanger <eric@archlinux.org>
# Contributor: Jan Fader <jan.fader@web.de>

pkgname=fish
pkgver=4.0b1
pkgrel=0
pkgdesc='Smart and user friendly shell intended mostly for interactive use'
url='https://fishshell.com/'
arch=('x86_64')
license=('GPL-2.0-only AND BSD-3-Clause AND ISC AND MIT AND PSF-2.0')
depends=('glibc' 'gcc-libs' 'ncurses' 'pcre2')
optdepends=('python: man page completion parser / web config tool'
            'pkgfile: command-not-found hook')
makedepends=('cargo' 'cmake' 'python-sphinx' 'jq')
checkdepends=('expect' 'procps-ng')
install=fish.install
options=(!lto) # breaks the build and it is not necessary
backup=(etc/fish/config.fish)
source=(https://github.com/fish-shell/fish-shell/releases/download/${pkgver}/${pkgname}-${pkgver}.tar.xz{,.asc})
validpgpkeys=(003837986104878835FA516D7A67D962D88A709A) # David Adam <zanchey@gmail.com>
sha256sums=('534334e10f85722214e9daff82a57cc3501235523f16f8f131c2344e4ec98da7'
            'SKIP')
sha512sums=('9f9740076e09e5b3487586be3e8572b42b8d2084b6616fb1792e94d24da8d46bc38f7d55b8728cfc0a3dc9820136de7608528c37dc6aaec474a208a663f07f3b'
            'SKIP')

build() {
  cd ${pkgname}-${pkgver}
  export CXXFLAGS+=" ${CPPFLAGS}"
  cmake \
    -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_SYSCONFDIR=/etc \
    -DBUILD_DOCS=True \
    -Wno-dev
  make -C build VERBOSE=1
}

check() {
  cd ${pkgname}-${pkgver}
  make -C build test
}

package() {
  cd ${pkgname}-${pkgver}

  make -C build DESTDIR="${pkgdir}" install
}

# vim: ts=2 sw=2 et:
