#!/usr/bin/env bash
#
# build-dylib.sh —— 只出 dylib（arm64 单架构）
#
# 用法:
#   ./build-dylib.sh
#
# 环境要求（二选一）:
#   A. macOS + Xcode 命令行工具：直接用 clang
#   B. Linux：装 zig（0.13+），脚本用 zig 自带 clang/lld
#
# iOS SDK 放这两处任意一个即可:
#   $THEOS/sdks/iPhoneOS16.5.sdk
#   ./sdks/iPhoneOS16.5.sdk
#
# 产物: dist/WCCornerReverse.dylib（已 ldid 伪签名）
#

set -euo pipefail

PKG_NAME="WCCornerReverse"
MIN_IOS="14.0"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# ---------- 1. 找 SDK ----------
find_sdk() {
  local cand
  for cand in \
    "${SDK:-}" \
    "${THEOS:-}/sdks/iPhoneOS16.5.sdk" \
    "$HOME/theos/sdks/iPhoneOS16.5.sdk" \
    "$ROOT/sdks/iPhoneOS16.5.sdk" \
    "$ROOT/../sdks/iPhoneOS16.5.sdk"; do
    [ -n "$cand" ] && [ -d "$cand/System/Library/Frameworks" ] && { echo "$cand"; return 0; }
  done
  for cand in "${THEOS:-}/sdks"/iPhoneOS*.sdk "$HOME/theos/sdks"/iPhoneOS*.sdk "$ROOT/sdks"/iPhoneOS*.sdk; do
    [ -d "$cand/System/Library/Frameworks" ] && { echo "$cand"; return 0; }
  done
  return 1
}

SDK="$(find_sdk)" || { echo "!! 找不到 iPhoneOS SDK，请设 THEOS 或把 SDK 放进 ./sdks/"; exit 1; }
echo "==> SDK: $SDK"

# ---------- 2. 找编译器 ----------
if command -v xcrun >/dev/null 2>&1; then
  CC="$(xcrun --sdk iphoneos --find clang)"
  TRIPLE="arm64-apple-ios${MIN_IOS}"
elif command -v zig >/dev/null 2>&1; then
  CC="zig cc"
  TRIPLE="aarch64-ios.${MIN_IOS}"
elif [ -n "${ZIG:-}" ]; then
  CC="$ZIG cc"
  TRIPLE="aarch64-ios.${MIN_IOS}"
else
  echo "!! 没有可用编译器（macOS 装 Xcode 命令行工具，Linux 装 zig）"; exit 1
fi
echo "==> CC: $CC ($TRIPLE)"

# ---------- 3. logos 预处理 ----------
mkdir -p .build/obj dist
LOGOS=""
for cand in "${THEOS:-}/vendor/logos/bin/logos.pl" "$HOME/theos/vendor/logos/bin/logos.pl" "$ROOT/theos/vendor/logos/bin/logos.pl"; do
  [ -f "$cand" ] && { LOGOS="$cand"; break; }
done

if [ -n "$LOGOS" ]; then
  PERL5LIB="$(dirname "$(dirname "$LOGOS")")/lib" perl "$LOGOS" src/Tweak.xm > .build/Tweak.mm
  echo "==> logos: $LOGOS"
else
  # 预生成的 Tweak.mm（等价 logos 输出），没装 theos 也能编
  if [ -f prebuilt/Tweak.mm ]; then
    cp prebuilt/Tweak.mm .build/Tweak.mm
    echo "==> logos: 用 prebuilt/Tweak.mm"
  else
    echo "!! 找不到 logos.pl，也没有 prebuilt/Tweak.mm"; exit 1
  fi
fi

# ---------- 4. 编译 ----------
CFLAGS=(
  -target "$TRIPLE"
  -isysroot "$SDK"
  -isystem "$SDK/usr/include"
  -F "$SDK/System/Library/Frameworks"
  -Iinclude
  -fobjc-arc -fblocks -std=c++17 -O2
  -Wno-everything
)

OBJS=()
for f in src/*.mm .build/Tweak.mm; do
  o=".build/obj/$(basename "${f%.*}").o"
  echo "    compile $(basename "$f")"
  $CC "${CFLAGS[@]}" -c "$f" -o "$o"
  OBJS+=("$o")
done

# ---------- 5. 链接 ----------
echo "==> link"
$CC "${CFLAGS[@]}" \
  -L "$SDK/usr/lib" \
  -dynamiclib \
  -framework UIKit -framework Foundation -framework CoreGraphics \
  -Wl,-undefined -Wl,dynamic_lookup \
  -install_name "/var/jb/Library/MobileSubstrate/DynamicLibraries/${PKG_NAME}.dylib" \
  "${OBJS[@]}" -o "dist/${PKG_NAME}.dylib"

# ---------- 6. 签名 ----------
if command -v ldid >/dev/null 2>&1; then
  ldid -S "dist/${PKG_NAME}.dylib"
elif [ -n "${LDID:-}" ] && [ -x "$LDID" ]; then
  "$LDID" -S "dist/${PKG_NAME}.dylib"
else
  echo "!! 没找到 ldid，dylib 未签名（越狱设备多数仍可加载，建议装上 ldid）"
fi

echo
echo "OK -> dist/${PKG_NAME}.dylib"
file "dist/${PKG_NAME}.dylib" || true
