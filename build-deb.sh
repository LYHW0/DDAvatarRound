#!/usr/bin/env bash
#
# build-deb.sh —— 一键出 deb(rootless / iphoneos-arm64)
#
# 用法:
#   ./build-deb.sh
#
# 需要:
#   - iOS SDK(theos 的 sdks 目录,默认取 iPhoneOS16.5.sdk)
#   - 一个能交叉编译到 aarch64-apple-ios 的 clang(这里用 zig 自带的 clang/lld)
#   - ldid(签名)
#
# 产物: packages/com.wcr.corner.reverse_<版本>_iphoneos-arm64.deb
#

set -euo pipefail

PKG_ID="com.wcr.corner.reverse"
PKG_NAME="WCCornerReverse"
VERSION="1.0.0"
ARCH="iphoneos-arm64"
DYLIB_NAME="${PKG_NAME}.dylib"

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# ---- 工具链路径(按自己环境改) ----
ZIG="${ZIG:-zig}"
SDK="${SDK:-$HOME/theos/sdks/iPhoneOS16.5.sdk}"
THEOS="${THEOS:-$HOME/theos}"
LDID="${LDID:-ldid}"

TARGET="aarch64-ios.14.0"
CFLAGS=(
  -target "$TARGET"
  -isysroot "$SDK"
  -F "$SDK/System/Library/Frameworks"
  -L "$SDK/usr/lib"
  -I "$SDK/usr/include"
  -Iinclude
  -I"$THEOS/include"
  -I"$THEOS/vendor/include"
  -fobjc-arc -std=c++17 -fblocks -O2 -Wall
)
LDFLAGS=(
  -target "$TARGET"
  -isysroot "$SDK"
  -F "$SDK/System/Library/Frameworks"
  -L "$SDK/usr/lib"
  -dynamiclib
  -framework UIKit -framework Foundation -framework CoreGraphics
  -Wl,-undefined -Wl,dynamic_lookup
  -install_name "/var/jb/Library/MobileSubstrate/DynamicLibraries/${DYLIB_NAME}"
)

BUILD="$ROOT/.build"
OUT="$ROOT/packages"
mkdir -p "$BUILD/obj" "$OUT"

echo "==> 1/5 预处理 Tweak.xm(logos)"
perl "$THEOS/bin/logos.pl" src/Tweak.xm > "$BUILD/Tweak.mm"

echo "==> 2/5 编译"
OBJS=()
for f in src/*.mm "$BUILD/Tweak.mm"; do
  o="$BUILD/obj/$(basename "${f%.*}").o"
  echo "    $f"
  "$ZIG" cc "${CFLAGS[@]}" -c "$f" -o "$o"
  OBJS+=("$o")
done

echo "==> 3/5 链接"
"$ZIG" cc "${LDFLAGS[@]}" "${OBJS[@]}" -o "$BUILD/${DYLIB_NAME}"

echo "==> 4/5 签名"
"$LDID" -S "$BUILD/${DYLIB_NAME}"

echo "==> 5/5 打包 deb"
STAGE="$BUILD/stage"
rm -rf "$STAGE"
LIBDIR="$STAGE/var/jb/Library/MobileSubstrate/DynamicLibraries"
mkdir -p "$LIBDIR" "$STAGE/DEBIAN"
cp "$BUILD/${DYLIB_NAME}" "$LIBDIR/"
cp "${PKG_NAME}.plist" "$LIBDIR/"

SIZE_KB=$(du -sk "$STAGE/var" | cut -f1)
cat > "$STAGE/DEBIAN/control" <<EOF
Package: ${PKG_ID}
Name: ${PKG_NAME}
Version: ${VERSION}
Architecture: ${ARCH}
Description: WCRefine「界面圆角」板块完整逆向复刻(设置界面 + 全部功能项 + 圆角渲染引擎)
Maintainer: wcr
Author: wcr
Section: Tweaks
Depends: mobilesubstrate
Installed-Size: ${SIZE_KB}
EOF

DEB="$OUT/${PKG_ID}_${VERSION}_${ARCH}.deb"
dpkg-deb -b --root-owner-group "$STAGE" "$DEB" >/dev/null
echo "OK -> $DEB"
dpkg-deb -I "$DEB"
