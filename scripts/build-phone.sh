#!/usr/bin/env bash
# 交叉编译手机侧的 skyward（aarch64-linux-android）。
# 产物：build/phone/aarch64-linux-android/release/skyward
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

if [[ ! -d "$SKYWARD_SRC" ]]; then
  echo "没有 $SKYWARD_SRC，先运行 scripts/bootstrap.sh" >&2
  exit 1
fi

export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$ROOT/build/phone}"
cd "$SKYWARD_SRC"
exec cargo build --release --target aarch64-linux-android -p skyward "$@"
