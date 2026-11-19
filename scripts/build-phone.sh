#!/usr/bin/env bash
# 交叉编译手机侧的 skyward（aarch64-linux-android）。
# 产物：build/phone/aarch64-linux-android/release/skyward
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

if [[ ! -d "$SKYWARD_SRC" ]]; then
  echo "没有 $SKYWARD_SRC，先运行 scripts/bootstrap.sh" >&2
  exit 1
fi

# The library preloaded into the vendor's AIDL wpa_supplicant, which the
# recovery's service directory would otherwise turn away before the
# supplicant opens its interface. It is small, and built from source here.
SHIM_C="$ROOT/shim/wpa-aidl-shim.c"
SHIM_SO="$ROOT/build/phone/wpa-aidl-shim.so"
if [[ -f "$SHIM_C" ]]; then
  mkdir -p "$(dirname "$SHIM_SO")"
  "$NDK_BIN/clang$EXE" --target="aarch64-linux-android$ANDROID_API" -shared -fPIC -O2 -o "$SHIM_SO" "$SHIM_C"
  echo "shim: $SHIM_SO"
fi

# The version the build shows: the device's own, when its configuration
# names one, so that the same tree builds for more than one phone and each
# phone's About page carries its own name.
CONFIG="${CONFIG:-$ROOT/devices/onyx.toml}"
if [[ -f "$CONFIG" ]]; then
  version="$(awk '/^\[device\]/{f=1;next} /^\[/{f=0} f && /^version[[:space:]]*=/{sub(/^version[[:space:]]*=[[:space:]]*"/,"");sub(/".*/,"");print;exit}' "$CONFIG")"
  if [[ -n "$version" ]]; then
    export SKYWARD_VERSION="$version"
    echo "version: $SKYWARD_VERSION"
  fi
fi

export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$ROOT/build/phone}"
cd "$SKYWARD_SRC"
exec cargo build --release --target aarch64-linux-android -p skyward "$@"
