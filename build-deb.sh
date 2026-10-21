#!/usr/bin/env bash
#
# build-deb.sh —— 本地一键出 deb（rootless / iphoneos-arm64，单架构 arm64）
#
# 直接复用 build-dylib.sh 编出来的 dylib，只做打包。
#
# 用法:
#   ./build-deb.sh
#
# 产物: packages/com.wcr.corner.reverse_<版本>_iphoneos-arm64.deb
#

set -euo pipefail

PKG_ID="com.wcr.corner.reverse"
PKG_NAME="WCCornerReverse"
VERSION="1.0.1"
ARCH="iphoneos-arm64"

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "==> 1/2 编 dylib"
./build-dylib.sh

echo "==> 2/2 打 deb"
STAGE="$ROOT/.build/stage"
rm -rf "$STAGE"
LIBDIR="$STAGE/var/jb/Library/MobileSubstrate/DynamicLibraries"
mkdir -p "$LIBDIR" "$STAGE/DEBIAN"

cp "dist/${PKG_NAME}.dylib" "$LIBDIR/"
cp "${PKG_NAME}.plist" "$LIBDIR/"

SIZE_KB=$(du -sk "$STAGE/var" | cut -f1)
cat > "$STAGE/DEBIAN/control" <<EOF
Package: ${PKG_ID}
Name: ${PKG_NAME}
Version: ${VERSION}
Architecture: ${ARCH}
Description: WCRefine「界面圆角」板块完整逆向复刻（设置界面 + 全部功能项 + 圆角渲染引擎）
Maintainer: wcr
Author: wcr
Section: Tweaks
Depends: mobilesubstrate
Installed-Size: ${SIZE_KB}
EOF

mkdir -p "$ROOT/packages"
DEB="$ROOT/packages/${PKG_ID}_${VERSION}_${ARCH}.deb"
dpkg-deb -b --root-owner-group "$STAGE" "$DEB" >/dev/null
echo "OK -> $DEB"
dpkg-deb -I "$DEB"
