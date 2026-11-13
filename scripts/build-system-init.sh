#!/usr/bin/env bash
# 交叉编译手机侧的 skyward-system-init（静态链接）。
# 产物：build/system-init/aarch64-linux-android/release/system-init
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

if [[ ! -d "$SKYWARD_SRC" ]]; then
  echo "没有 $SKYWARD_SRC，先运行 scripts/bootstrap.sh" >&2
  exit 1
fi

export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$ROOT/build/system-init}"
# 静态链接，recovery 的 /system 里没有它依赖的动态库。
export CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS="-C target-feature=+crt-static -C link-arg=--target=aarch64-linux-android$ANDROID_API"

cd "$SKYWARD_SRC"
exec cargo build --release --target aarch64-linux-android -p skyward-system-init "$@"
