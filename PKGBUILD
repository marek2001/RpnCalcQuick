# Maintainer: Marek M. Marecki <marekmareckimm@interia.pl>
pkgname=rpncalcquick-git
pkgver=r58.73eb8b7
pkgrel=1
pkgdesc="RPN calculator built with Qt Quick (Git version)"
arch=('x86_64')
url="https://github.com/marek2001/RpnCalcQuick"
license=('GPL3')
depends=('qt6-base' 'qt6-declarative' 'qt6-5compat' 'qt6-shadertools')

makedepends=('git' 'cmake' 'ninja')
provides=("rpncalcquick")
conflicts=("rpncalcquick")

source=("git+https://github.com/marek2001/RpnCalcQuick.git")
sha256sums=('SKIP')

pkgver() {
    cd "RpnCalcQuick"
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

build() {
    cmake -B build -S "RpnCalcQuick" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -GNinja

    cmake --build build
}

package() {
    DESTDIR="$pkgdir" cmake --install build
}
