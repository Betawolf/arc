# Maintainer: Matthew Edwards <betawolf33 at yahoo dot com>
pkgname=arc
pkgver=0.1
pkgrel=1
pkgdesc="Script handing local backup and annotation of multi-format articles"
arch=('any')
url="https://github.com/Betawolf/arc"
license=('GPL3')
depends=('ncurses' 'rsync' 'sed' 'bash' 'wget' 'perl-file-mimeinfo' 'python-html2text' 'poppler' 'awk' 'xdg-utils' 'markdown' 'ruby-github-markdown') 
makedepends=('git')
source=('git+https://github.com/Betawolf/arc.git')
md5sums=('SKIP')
provides=('arc')

package(){
      install -Dm755 "$srcdir/$pkgname/arc" "$pkgdir/usr/bin/arc"
}
