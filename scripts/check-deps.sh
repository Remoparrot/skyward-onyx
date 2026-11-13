#!/usr/bin/env bash
# 检查构建依赖是否齐全。不下载、不修改任何东西。
set -uo pipefail

ok=0
fail=0
check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "✓ $name"
    ok=$((ok + 1))
  else
    echo "✗ $name"
    fail=$((fail + 1))
  fi
}

check "bash" bash --version
check "git" git --version
check "cargo" cargo --version
check "rustup" rustup --version
check "lz4" lz4 --version

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) check "gcc（Windows 宿主链接）" gcc --version ;;
esac

if [[ -n "${ANDROID_NDK:-}" && -d "$ANDROID_NDK/toolchains/llvm/prebuilt" ]]; then
  echo "✓ ANDROID_NDK=$ANDROID_NDK"
  ok=$((ok + 1))
else
  echo "✗ ANDROID_NDK（未设置或路径不对）"
  fail=$((fail + 1))
fi

echo
echo "通过 $ok 项，失败 $fail 项。"
[[ "$fail" -eq 0 ]]
