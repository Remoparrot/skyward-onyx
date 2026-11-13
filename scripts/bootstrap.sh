#!/usr/bin/env bash
# 取回固定版本的 Skyward 源码，并打上本仓库的三个补丁。
#
#   UPSTREAM_URL     默认 https://github.com/kirklin/skyward.git
#   UPSTREAM_COMMIT  默认 ff1668fdb72a46f22152a6540f49728c42081aba（v0.2.0）
#   SKYWARD_SRC      默认 <repo>/vendor/skyward
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/kirklin/skyward.git}"
UPSTREAM_COMMIT="${UPSTREAM_COMMIT:-ff1668fdb72a46f22152a6540f49728c42081aba}"
SKYWARD_SRC="${SKYWARD_SRC:-$ROOT/vendor/skyward}"

if [[ -f "$SKYWARD_SRC/.onyx-patched" ]]; then
  echo "已经打好补丁：$SKYWARD_SRC"
  echo "要重新来一遍：rm -rf $SKYWARD_SRC && $0"
  exit 0
fi

mkdir -p "$(dirname "$SKYWARD_SRC")"

if [[ ! -d "$SKYWARD_SRC/.git" ]]; then
  echo "==> clone $UPSTREAM_URL"
  git clone "$UPSTREAM_URL" "$SKYWARD_SRC"
fi

echo "==> 检出 $UPSTREAM_COMMIT"
if ! git -C "$SKYWARD_SRC" cat-file -e "$UPSTREAM_COMMIT^{commit}" 2>/dev/null; then
  git -C "$SKYWARD_SRC" fetch --depth=1 origin "$UPSTREAM_COMMIT" ||
    git -C "$SKYWARD_SRC" fetch origin
fi
git -C "$SKYWARD_SRC" checkout --detach "$UPSTREAM_COMMIT"

echo "==> 打补丁"
for patch in "$ROOT"/patches/*.patch; do
  name="$(basename "$patch")"
  echo "    $name"
  git -C "$SKYWARD_SRC" apply --check "$patch"
  git -C "$SKYWARD_SRC" apply "$patch"
done

touch "$SKYWARD_SRC/.onyx-patched"
echo
echo "完成：$SKYWARD_SRC"
echo "下一步：scripts/build-phone.sh / build-system-init.sh / build-pack.sh"
