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

mkdir -p "$ROOT/stock"
"$PACK" stock --config "$ROOT/devices/onyx.toml" --out "$ROOT/stock/recovery.img"

echo
echo "stock/recovery.img："
ls -l "$ROOT/stock/recovery.img"
sha256sum "$ROOT/stock/recovery.img"
