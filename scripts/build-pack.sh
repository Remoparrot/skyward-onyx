#!/usr/bin/env bash
# 编译宿主侧的打包器 skyward-pack（Windows 上要用 MinGW 的 gcc 链接）。
# 产物：build/host/release/skyward-pack[.exe]
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

if [[ ! -d "$SKYWARD_SRC" ]]; then
  echo "没有 $SKYWARD_SRC，先运行 scripts/bootstrap.sh" >&2
  exit 1
fi

export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$ROOT/build/host}"
cd "$SKYWARD_SRC"
exec cargo build --release -p skyward-pack "$@"
