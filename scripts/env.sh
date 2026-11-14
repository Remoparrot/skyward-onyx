#!/usr/bin/env bash
# 公共环境：由其他脚本 source，不单独执行。
#
#   ANDROID_NDK  Android NDK 根目录（含 toolchains/llvm/...），必填
#   MINGW_BIN    Windows 下 MinGW-w64 的 bin 目录（默认自动找 /mingw64/bin 等）
#   ANDROID_API  target API level，默认 30
#
# 其余变量都可由调用者在外部覆盖。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKYWARD_SRC="${SKYWARD_SRC:-$ROOT/vendor/skyward}"
ANDROID_NDK="${ANDROID_NDK:-${ANDROID_NDK_ROOT:-}}"
ANDROID_API="${ANDROID_API:-30}"

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) HOST_TAG=windows-x86_64 ;;
  Linux*) HOST_TAG=linux-x86_64 ;;
  Darwin*) HOST_TAG=darwin-x86_64 ;;
  *)
    echo "不支持的宿主系统：$(uname -s)" >&2
    exit 1
    ;;
esac

EXE=""
if [[ "$HOST_TAG" == windows-* ]]; then
  EXE=".exe"
fi

if [[ -z "$ANDROID_NDK" ]]; then
  cat >&2 <<'EOF'
没有设置 ANDROID_NDK。

  export ANDROID_NDK=/path/to/android-ndk-r29
  # 或者：
  export ANDROID_NDK_ROOT=/path/to/android-ndk-r29

本仓库的参考构建使用 NDK r29（29.0.14206865）。
EOF
  exit 1
fi

NDK_BIN="$ANDROID_NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin"
if [[ ! -x "$NDK_BIN/clang$EXE" ]]; then
  echo "NDK 里找不到 $NDK_BIN/clang$EXE，请检查 ANDROID_NDK 与宿主平台。" >&2
  exit 1
fi

# Windows 上用 gnu 宿主工具链；上游 rust-toolchain.toml 只钉 stable，
# 不钉宿主三元组，所以这里显式选择，避免落到 msvc 后缺 link.exe。
if [[ "$HOST_TAG" == windows-* ]]; then
  export RUSTUP_TOOLCHAIN="${RUSTUP_TOOLCHAIN:-1.100.0-x86_64-pc-windows-gnu}"
  export PATH="$HOME/.cargo/bin:$PATH"

  if [[ -z "${MINGW_BIN:-}" ]]; then
    for candidate in /mingw64/bin /ucrt64/bin /d/msys2/mingw64/bin /c/msys64/mingw64/bin; do
      if [[ -x "$candidate/gcc.exe" ]]; then
        MINGW_BIN="$candidate"
        break
      fi
    done
  fi
  if [[ -z "${MINGW_BIN:-}" ]]; then
    echo "找不到 MinGW-w64 的 gcc。请设置 MINGW_BIN=/path/to/mingw64/bin" >&2
    exit 1
  fi
  export MINGW_BIN
  export PATH="$MINGW_BIN:$PATH"
  export CC=gcc
  export AR=ar

  # dlltool / cc 会在系统 %TEMP% 下建临时文件；这台机器的那个目录不可写，
  # 所以所有临时文件都放仓库自己的 tmp/ 里。
  export TMPDIR="$ROOT/tmp"
  mkdir -p "$TMPDIR"
  export TEMP="$(cygpath -w "$TMPDIR")"
  export TMP="$TEMP"
else
  export RUSTUP_TOOLCHAIN="${RUSTUP_TOOLCHAIN:-stable}"
fi

# 手机侧（aarch64-linux-android）的编译器 / 链接器 / C 依赖编译参数。
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$NDK_BIN/clang$EXE"
export CC_aarch64_linux_android="$NDK_BIN/clang$EXE"
export AR_aarch64_linux_android="$NDK_BIN/llvm-ar$EXE"
export CFLAGS_aarch64_linux_android="--target=aarch64-linux-android$ANDROID_API"
export BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android="--target=aarch64-linux-android$ANDROID_API"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS="-C link-arg=--target=aarch64-linux-android$ANDROID_API"

# 打包器会调用 PATH 上的 lz4。
if ! command -v lz4 >/dev/null 2>&1; then
  echo "警告：PATH 上没有 lz4，skyward-pack 打包 ramdisk 时会失败。" >&2
  echo "      把 lz4 可执行文件放进 PATH，或设置 PATH=\"$ROOT/tools:\$PATH\"。" >&2
fi

export SKYWARD_SRC ANDROID_NDK ANDROID_API HOST_TAG EXE
