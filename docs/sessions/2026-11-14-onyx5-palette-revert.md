# onyx.5：调色恢复原样（2026-11-14）

状态：已完成
关联版本：v0.3.0-onyx.5（同版本重建，未升版本号）
关联提交：0178ffb

## 1. TL;DR

用户嫌 onyx.5 初版颜色「太淡」，要求换回原来的调色、版本号不变。撤销 0008 里那层调色板色域校正（sRGB → Display P3 + 饱和度 0.68），`LIGHT` / `DARK` 采样值原样绘制；同一版本重建并刷入真机，设置页蓝色由 `(97,126,200)` 回到 `(74,128,247)`，首页图标蓝与 onyx.4 截图逐像素一致。

## 2. 对话重点

- 用户要求（原话）：「颜色太淡了，换回原来的调色，版本号不变」。
- 决策：只撤销调色板校正这一层，不动 onyx.5 的其他改动（锁屏模糊与滑块、5 GHz WLAN、下载页回归、解密前不锁屏）。
- 决策：版本号保持 `v0.3.0-onyx.5`——`Cargo.toml`、`scripts/build-image.sh` 的 `OUT` 名、README / 状态文档的版本号都不动。
- 明确否掉：升到 onyx.6（用户明确说版本号不变）；把饱和度 0.68 调成 0.85 之类的折中值（用户要的是「原来的调色」，折中值仍不是原色）。
- 范围外：锁屏那层半透明白色蒙层的观感（用户此前要的「浅色时白色、深色时浅色」模糊），本次不动。

## 3. 修复内容

| 文件 | 改了什么 | 为什么 |
| --- | --- | --- |
| `crates/skyward-ui/src/theme.rs` | 删掉 `Theme::graded()`、`Palette::original()`、`fn stock()` 与 `Theme::ink()`；`Theme::light/dark` 不再调用 `.graded()`；import 回到 `{over, Rgba}` | 这四处就是 onyx.5 加的整套调色板校正，是「太淡」的唯一来源 |
| `crates/skyward-ui/src/color.rs` | 删掉 `p3()`、`desaturated()` | 只有 `stock()` 在调，留着是死代码 |
| `crates/skyward-ui/src/icons.rs` | `tile()` 去掉 `let color = t.ink(color);` | 图标底色原本也被单独校正了一次 |
| `patches/0008-onyx.5-lock-display-wifi.patch` | 去掉 color.rs / icons.rs / theme.rs 三段（5,399 行 → 5,243 行） | 补丁必须能和 vendor 树逐字对上；这三段已经不成立 |
| `README.md`、`docs/00-status.md`、`docs/07-changelog.md`、`SHA256SUMS`、`agent.md` | 哈希 / 大小换成重建产物，并加一节「同日重建」 | 当前状态文档必须指向当前镜像 |
| `docs/06-pitfalls.md` | 新增第 27 条 | 记下「整体调色板校正会让颜色发灰」这个坑 |

## 4. 设计思路

- 问题本质：面板把帧缓冲数值当 Display P3 解释，onyx.5 为了让页面「接近系统原色」，把整套 sRGB 采样值先转 P3、再把饱和度压到 0.68（`Theme::graded()` → `Palette::original()` → `stock()`，图标底色另走 `Theme::ink()`）。压饱和度等于把每个彩色往灰里拉，用户看到的就是「淡」：蓝色 `(74,128,247)` → `(97,126,200)`，首页图标蓝 `(52,130,255)` → `(84,126,204)`。
- 方案 A（采纳）：整层删掉，回到 onyx.1–onyx.4 的采样原值。必须连入口一起删（`graded` / `original` / `stock` / `ink` / `p3` / `desaturated`），留半层只会让日后又慢慢漂回去。
- 方案 B（否）：把 0.68 调到 0.85 之类的折中值。用户要的是原来的观感，折中值仍不是原色，而且多一个可调常量。
- 方案 C（否）：恢复「色彩风格」切换项。用户在 onyx.5 已明确不要这个开关。
- 取舍：颜色回到更艳的采样值，不再和系统设置截图逐像素一致；但这是用户偏好，且与 onyx.4 完全一致。

## 5. 踩过的坑

**现象**：改完 `theme.rs` / `icons.rs`，`git status` 一直显示这两个文件是 `M`，但 `git diff` 是空的。
**根因**：Windows 上 `core.autocrlf=true`，文件被 Python 以 LF 重写后内容与索引 blob 相同，但 stat 缓存没刷新，`git status` 先按 stat 判脏。
**解法**：用 `git diff --numstat` / `git hash-object` 确认内容与 HEAD 相同即可，不必额外提交。
**如何避免**：判断「有没有改」以 `git diff` 输出为准，不看 `git status` 的 `M`。

**现象**：宿主侧 `cargo build --release -p skyward-preview` 在 Windows 上失败：`rsproperties` 的 `SocketFlags::CLOEXEC` 不存在、`E0432` / `E0308`（`E0599` 等共 26 个错误）。
**根因**：上游只有手机侧目标被维护；`skyward-preview` 依赖的 `rsproperties` 在 Windows 上没有对应实现，0001 补丁只修了 `skyward-pack` 需要的那部分宿主构建。
**解法**：放弃宿主渲染验证，直接真机截图 + 取色对比（本来也是最终验收）。
**如何避免**：想快速看颜色用 `skyward-ui.sh shot`；宿主侧只保证 `skyward-pack` 能编。

**现象**：`build-image.sh` 报 `run lz4 (install it, e.g. brew install lz4) / program not found`。
**根因**：`lz4.exe` 在 `/d/skyward-work/tools/`，不在 PATH；`env.sh` 只打警告不阻止。
**解法**：`export PATH="/d/skyward-work/tools:$PATH"` 后再跑。
**如何避免**：跑打包脚本前先 `which lz4`。

## 6. 验证与证据

- 构建环境：`ANDROID_NDK=/d/skyward-work/ndk/android-ndk-r29`、`PATH` 加 `/d/skyward-work/tools`。
- `scripts/build-phone.sh`：`Finished release profile in 59.32 s`（2 个上游遗留 warning，均为 `omapi.rs` 的 `unused_doc_comments`）。
- `scripts/build-image.sh`：`wrote .../skyward-v0.3.0-onyx.5-OS4.0.2.0.XOLCNXM.img (0 bytes kernel, 50692327 bytes ramdisk, 104857600 bytes in all)`。
- `scripts/verify-image.sh`：大小 ✓、`system/bin/recovery` ✓、`skyward/system-init` ✓、`skyward/device.toml` ✓、`skyward/MiSansVF.ttf` ✓；1062 个 cpio 条目。
- 镜像 SHA-256：`ac9be2c5f8d9604e2384d57c99f544df3c002c3f65b430ceb0b1f822fc9e0de2`。
- 镜像内二进制：`skyward-pack cat recovery.img system/bin/recovery | sha256sum` = `4b712147e584ab227d56f5006187b8306fbb1b9f3b7fbec66c3e7a7e2fc0c846`，与 `build/phone/.../skyward` 一致（8,769,040 字节）。
- zip：45,860,277 字节 · `6f54c7ec721e7ed25c012a9ddbbd5ce3d9765810ba5cf5a1011e79e5ffbd5c91`。
- 补丁：`tmp/verify` 里 `git reset --hard` 到 `ff1668f` 后依次 apply 0001–0008 全部成功；`diff -r --strip-trailing-cr --exclude=.git/target/out/.onyx-patched` 与 `vendor/skyward` 对比 `rc=0`。
- 刷机：`fastboot flash recovery`（Writing OKAY 0.076 s）→ `fastboot reboot recovery`；`dmesg`：`skyward: onyx 0.3.0-onyx.5 recovery up`。
- 取色（真机截图 1280×2772，`adb exec-out cat` 出来的原图直接取像素）：
  - 设置页（浅色）蓝色滑块：重建后 `(74,128,247)`；重建前 `(97,126,200)`；与更早的 `render-out/colour5-vivid.png` 相同；
  - 首页图标蓝：`(52,130,255)`，与 onyx.4 的 `render-out/beforeLock.png` / `adv1.png` 相同；重建前 `(84,126,204)`；
  - 设置页卡片 / 背景仍为 `(255,255,255)` / `(243,243,243)`，未被波及；
  - 与 `render-out/settings-page.png`（重建前）逐像素 diff：变化只落在蓝色元素（主题卡、亮度滑杆、模糊滑杆、双击亮屏开关），灰色组件不变。
- 页面：浅色 / 深色设置页截图正常；息屏再点亮显示锁屏（模糊背景），滑开回到原页面。
- 未验证：备份 / 恢复 / 安装 / 文件管理等页面没有逐页截图取色，只按调色板入口推断。

## 7. 未完成 / 下一步 / 风险

- 未完成：GitHub Release 的资产是否替换成本节的新镜像（同一 tag `v0.3.0-onyx.5`）由用户定；若替换，release 说明里的哈希也要同步。
- 下一步：真机把主要页面转一圈，确认没有「某处颜色异常」；若有个别页面异常，只改那一处，不要再引入整体校正。
- 风险：撤掉校正后，面板上颜色会比系统设置更艳（这是原样的观感）；日后若有人想加回 `Theme::graded()`，先读 `docs/06-pitfalls.md` 第 27 条。
