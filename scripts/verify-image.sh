#!/usr/bin/env bash
# 校验打出来的整分区镜像：大小、头部、关键 ramdisk 条目、SHA-256。
#
#   scripts/verify-image.sh out/recovery.img
#   scripts/verify-image.sh out/recovery.img b41bee5b5342e5a2f0f32ba01e9a0cca3c0ab69b520799e4e29ee49957f1f83f
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMG="${1:-}"
EXPECTED="${2:-}"
PACK="${PACK:-$ROOT/build/host/release/skyward-pack}"
[[ -x "$PACK" ]] || PACK="$PACK.exe"

if [[ -z "$IMG" || ! -f "$IMG" ]]; then
  echo "用法：$0 <image> [expected-sha256]" >&2
  exit 1
fi
if [[ ! -x "$PACK" ]]; then
  echo "找不到打包器 $PACK，先运行 scripts/build-pack.sh" >&2
  exit 1
fi

size=$(stat -c%s "$IMG" 2>/dev/null || stat -f%z "$IMG")
echo "大小：$size 字节"
expected_size="${EXPECTED_SIZE:-104857600}"
if [[ "$size" != "$expected_size" ]]; then
  echo "✗ 不是 recovery 分区大小（$expected_size）" >&2
  exit 1
fi
echo "✓ 大小 $expected_size 字节"

listing="$("$PACK" list "$IMG")"
echo "$listing" | head -1
for name in system/bin/recovery skyward/system-init skyward/device.toml skyward/MiSansVF.ttf; do
  if echo "$listing" | grep -q " $name\$"; then
    echo "✓ $name"
  else
    echo "✗ 缺少 $name" >&2
    exit 1
  fi
done

entries="$(echo "$listing" | grep -oE '^[0-9]+ entries$' | awk '{print $1}')"
echo "ramdisk 条目：${entries:-未知}"

actual="$(sha256sum "$IMG" | awk '{print $1}')"
echo "SHA-256：$actual"
if [[ -n "$EXPECTED" ]]; then
  if [[ "${actual,,}" == "${EXPECTED,,}" ]]; then
    echo "✓ 与预期一致"
  else
    echo "✗ 与预期不一致（预期 $EXPECTED）" >&2
    exit 1
  fi
fi
