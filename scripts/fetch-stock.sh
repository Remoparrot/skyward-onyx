#!/usr/bin/env bash
# 从官方全量包取出 onyx 的原厂 recovery（只读需要的那一段，不下载整个 10 GB 包）。
# 产物：stock/recovery.img
#
# 需要先编译打包器：scripts/build-pack.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK="${PACK:-$ROOT/build/host/release/skyward-pack}"
[[ -x "$PACK" ]] || PACK="$PACK.exe"
if [[ ! -x "$PACK" ]]; then
  echo "找不到打包器 $PACK，先运行 scripts/build-pack.sh" >&2
  exit 1
fi

CONFIG="${CONFIG:-$ROOT/devices/onyx.toml}"
OUT="${OUT:-$ROOT/stock/recovery.img}"
mkdir -p "$(dirname "$OUT")"
"$PACK" stock --config "$CONFIG" --out "$OUT"

echo
echo "$OUT："
ls -l "$OUT"
sha256sum "$OUT"
