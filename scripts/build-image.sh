#!/usr/bin/env bash
# 把编译好的 skyward / system-init / 原厂 recovery 打成整分区镜像。
#
#   CONFIG        设备配置，默认 devices/onyx.toml
#   STOCK         原厂 recovery，默认 stock/recovery.img
#   SKYWARD_BIN   手机侧 skyward，默认 build/phone/aarch64-linux-android/release/skyward
#   SYSTEM_INIT   手机侧 system-init，默认 build/system-init/aarch64-linux-android/release/system-init
#   PACK          宿主侧 skyward-pack，默认 build/host/release/skyward-pack[.exe]
#   OUT           输出镜像，默认 out/skyward-v0.3.1-onyx.2-OS4.0.2.0.XOLCNXM.img
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CONFIG:-$ROOT/devices/onyx.toml}"
STOCK="${STOCK:-$ROOT/stock/recovery.img}"
SKYWARD_BIN="${SKYWARD_BIN:-$ROOT/build/phone/aarch64-linux-android/release/skyward}"
SYSTEM_INIT="${SYSTEM_INIT:-$ROOT/build/system-init/aarch64-linux-android/release/system-init}"
PACK="${PACK:-$ROOT/build/host/release/skyward-pack}"
[[ -x "$PACK" ]] || PACK="$PACK.exe"
OUT="${OUT:-$ROOT/out/skyward-v0.3.1-onyx.2-OS4.0.2.0.XOLCNXM.img}"
FONT="${FONT:-$ROOT/vendor/skyward/resources/fonts/MiSansVF.ttf}"
MONO="${MONO:-$ROOT/vendor/skyward/resources/fonts/KirkMono-Regular.ttf}"
MONO_LICENSE="${MONO_LICENSE:-$ROOT/vendor/skyward/resources/fonts/KirkMono-OFL.txt}"
SHIM="${SHIM:-$ROOT/build/phone/wpa-aidl-shim.so}"

for f in "$STOCK" "$SKYWARD_BIN" "$SYSTEM_INIT" "$PACK" "$FONT" "$MONO" "$MONO_LICENSE"; do
  if [[ ! -f "$f" ]]; then
    echo "缺少输入：$f" >&2
    exit 1
  fi
done
if [[ -n "$SHIM" && ! -f "$SHIM" ]]; then
  echo "缺少输入：$SHIM（先运行 scripts/build-phone.sh）" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
echo "==> 打镜像"
"$PACK" recovery \
  --stock "$STOCK" \
  --binary "$SKYWARD_BIN" \
  --system-init "$SYSTEM_INIT" \
  --config "$CONFIG" \
  --font "$FONT" \
  --mono "$MONO" \
  --mono-license "$MONO_LICENSE" \
  ${SHIM:+--extra "skyward/wpa-aidl-shim.so=$SHIM"} \
  --out "$OUT"

size=$(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT")
stock_size=$(stat -c%s "$STOCK" 2>/dev/null || stat -f%z "$STOCK")
if [[ "$size" != "$stock_size" ]]; then
  echo "镜像大小 $size，不是分区大小 $stock_size" >&2
  exit 1
fi

echo
echo "==> 完成：$OUT"
ls -l "$OUT"
sha256sum "$OUT"
echo
echo "下一步：scripts/verify-image.sh \"$OUT\""
