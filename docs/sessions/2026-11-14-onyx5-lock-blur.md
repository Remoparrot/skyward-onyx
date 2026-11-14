# 2026-11-14 · onyx.5：锁屏模糊与滑块、5 GHz WLAN、下载页回归、解密前不锁屏、颜色校正

状态：已完成（WLAN 5 GHz 本次开机未复测）

关联版本：v0.3.0-onyx.4 → v0.3.0-onyx.5

关联提交：`eb300eb`（本版本代码与文档；会话记录里这一行随后补齐）

## 1. TL;DR

把「下载」页从图形浏览器改回原来的下载页（浏览器整个删掉），锁屏改成「后面是上一页的模糊快照 + 半透明压暗层」，设置里加了模糊强度滑杆；修了 5 GHz WiFi（监管域、扫描、PMF/SAE 参数）、data 解密前不再先弹锁屏；屏幕颜色统一按面板色域校正（原「色彩风格切换」在用户试用后删除）。最后修掉锁屏滑块拖动时背后变成纯色块的 bug——拖动时改为重画滑块所在行，模糊背景跟着回来（浅色/深色都验过）。

## 2. 对话重点

- 用户要求（原话要点）：
  - 「锁屏的滑块有 bug，把背景改成半透明的模糊，浅色时白色，深色时浅色」；
  - 「在设置里加一个调锁屏背景模糊的选项」；
  - 「锁屏模糊的采样率太低了，色彩风格切换的效果几乎看不出来」；
  - 「有人说连不上 5 GHz 频段的 WiFi，请修复」；
  - 「把浏览器删了，换回下载」；
  - 「解密 data 前不要锁屏」；
  - 「屏幕颜色有点鲜艳了，要一个和系统一样的屏幕色彩风格切换」 → 之后改成「把色彩风格删了」；
  - 「锁屏滑块滑动时后面纯色背景，深色也是，请修复」。
- 决策：
  - 浏览器整套回退（撤销 0007 的 `skyward-ui/src/web/`），下载页沿用 onyx.3 的（URL 下载 + 文件选择 + 512 并行），并恢复「打开网页」的纯文本网页页（上游的 `WebPage`）。
  - 色彩不再提供切换项：调色直接按面板 P3 色域校正（sRGB → P3，饱和度 0.68），接近系统「原色」；用户试用后称切换看不出差别，改为一套。
  - 锁屏只在 data 解密之后、息屏再点亮时出现；开机首屏直接是解密页。
  - 锁屏模糊强度默认 0.32（`LOCK_BLUR_START`），设置页「锁屏背景模糊」滑杆 0～1。
- 范围外但被提到：无。

## 3. 修复内容

| 文件 | 改了什么 | 为什么 |
| --- | --- | --- |
| `crates/skyward-ui/src/app.rs` | 新增 `redraw_rows`：把控件所在行标记为 `stale`，由 `render()` 按页重画；`repaint_confirm` 改用它；删掉 `paint_knob`（原来 `fill_rect(track, t.pal.bg)` + 重画控件）和 `knob` 字段 | 锁屏画布是「模糊快照 + 压暗层」，用页面底色清洗控件区域会在滑块后面留一块纯色矩形（浅色 `243,243,243` / 深色 `0,0,0`），拖动时非常明显 |
| `crates/skyward-ui/src/theme.rs` | 去掉 `Theme::vivid`；`light`/`dark` 直接返回经过 `graded()` 的主题（`Palette::original` + `stock`），`ink()` 始终做色域校正 | 删除色彩风格切换，但保留「不偏艳」的观感 |
| `crates/skyward-ui/src/pages.rs` | 删掉 `color_style` 页与设置页「色彩风格」行 | 同上 |
| `crates/skyward-ui/src/settings.rs` | 删掉 `vivid` 字段（旧 `settings.json` 里的 `vivid` 会被忽略） | 同上 |
| `crates/skyward-ui/src/search.rs` | 删掉「色彩风格」搜索项 | 同上 |
| `crates/skyward-ui/src/pages.rs`（锁屏） | `lock_sheet`：快照 `blit_scaled` 铺满 + 半透明压暗（浅色白 56 / 深色黑 88）；`lock_swipe`、`lock`（数字键盘）都画在这层上 | 用户要的「半透明模糊背景」 |
| `crates/skyward-ui/src/widgets.rs` | 新增 `lock_confirm`：磨砂胶囊轨道 + 圆形按钮 + 蓝色进度 + 「滑动解锁」文字；`Canvas` 增加 `blit_scaled`（双线性缩放） | 锁屏滑块要玻璃观感，滑过的地方随背景透出来 |
| `crates/skyward-ui/src/app.rs` | `remember()`：每次合成（屏幕亮着且不在锁屏）把当前画面按 10 px 采样保存、做盒式模糊；`snapshot` 就是锁屏背景；锁屏不在时更新。`lock_blur` 为 0 时不保存（用主题底色） | 采样率 22 px 太糊，用户要求更清晰；同时保留「不保存」时的退化路径 |
| `crates/skyward-ui/src/app.rs` / `pages.rs` / `settings.rs` | 设置页加「锁屏背景模糊」滑杆（`Slider::LockBlur`）、`lock_blur` 持久化；锁屏模糊强度 0 时文案「关闭」 | 用户要求可调 |
| `crates/skyward/src/wlan.rs` | `wpa_supplicant.conf` 写入 `country=<机型属性里的国家，默认 CN>`、`disable_scan_offload=1`、`sae_pwe=2`，去掉全局 `pmf=1` | 世界监管域把 5.8 GHz 留给被动扫描，5 GHz AP 扫不到；芯片 offload 扫描覆盖不全；PMF 改为按网络设置 |
| `crates/skyward-net/src/supplicant.rs` | WPA2-PSK 网络加 `ieee80211w=1`（可选 PMF），SAE 仍是 `ieee80211w=2` | 有些 5 GHz AP 要求管理帧保护 |
| `crates/skyward/src/ui.rs` | 启动时不再把首屏换成 `Screen::Lock`；锁屏只在 `wake()` 且 data 已解密时压栈 | 用户要求 data 解密前不锁屏 |
| `crates/skyward-ui/src/web/` | 整套删除（`mod.rs`/`html.rs`/`css.rs`/`layout.rs`/`image.rs`，约 2,700 行），`lib.rs` 去掉 `pub mod web` | 用户要求删掉浏览器、换回下载页 |
| `crates/skyward/src/ui.rs` | 去掉 `web::` 的取页线程与 `Incoming::Fetched`，恢复上游纯文本网页页的 `WebFetcher`/`web_fetched` | 同上 |
| `Cargo.toml` / `Cargo.lock` | 版本 `0.3.0-onyx.5`；删掉浏览器的依赖（`image`、`ureq` 等不再进 UI） | 版本与构建 |

## 4. 设计思路

- **锁屏背景**：锁屏不能直接截屏（KMS 扫描缓冲读不到），所以平时就留一份 1/10 采样的小图（`App::snapshot`），做盒式模糊后按屏幕尺寸双线性拉伸。模糊是在小图上做的，代价与屏大小无关；锁屏页只多一次拉伸。
- **滑块拖动**：`pages::render` 把控件和页面画在同一张画布里，所以画完以后画布上已经没有「控件背后的背景」可抄。考虑过：
  - A. 拖动前把控件区域抠下来缓存，拖动时贴回去——要多存一块位图，页面一滚动/重画就失效；
  - B. 让控件自己把背景也画一遍——要把快照和压暗层塞进 `widgets`，接口变脏；
  - C. **（采用）** 把控件所在行标成 `stale`，由 `render()` 按页重画这几行——和「数据变了只重画几行」同一条路径，模糊背景、控件、文字一次画对，滚动过的长页也成立。代价是每次移动重排一次页面（锁屏页只有背景 + 时钟，实测不卡）。
- **颜色**：面板把帧缓冲数值按 Display P3 解释，sRGB 数值直接写会偏艳。把调色板整体做「sRGB → P3 + 饱和度 0.68」，观感接近系统设置。切换两套风格的差别太小（用户实测几乎看不出），所以只留一套，删掉开关与设置项。
- **5 GHz**：根因不是驱动，而是监管域与扫描方式：`country 00` 时 5.8 GHz 只被动扫描，`gSelect5GHzMargin` 也压不住；补上 `country=CN`、`disable_scan_offload=1`，PMF 按网络给（WPA2 可选、WPA3 必须）。

## 5. 踩过的坑

**坑 1：锁屏滑块一拖，后面就是一块纯色**
- 现象：锁屏上按住圆形按钮往右拖，滑块轨道那一整块矩形变成纯色（浅色 `#f3f3f3`、深色黑），松手才恢复模糊。
- 根因：`paint_knob` 每次移动都用 `fill_rect(track, t.pal.bg)` 清掉控件区域再画控件；普通页面底色就是 `pal.bg` 所以看不出来，锁屏的底色是模糊快照，一清就是纯色块（圆角外的四个角尤其明显）。
- 解法：改成 `redraw_rows(track)` 标脏，`render()` 重画这几行页面（见 §4 C）。
- 如何避免：凡「就地重画控件」的代码都不要用主题底色清洗——除非能证明控件背后就是主题底色。

**坑 2：模糊采样率**
- 现象：锁屏背景糊成一团色块，用户说「采样率太低」，连色彩切换都看不出来。
- 根因：`remember()` 最初每 22 px 取一点，再叠压暗层，细节全没了；改 10 px + 按强度调模糊半径。
- 解法：`STEP = 10`，`blur_reach(level)`；`lock_blur=0` 时退回主题底色。
- 如何避免：小图放大只能做背景，别指望看出内容；强度为 0 要有独立路径。

**坑 3：`scripts/build-image.sh` 的默认输出名还是 onyx.1**
- 现象：直接跑脚本产出 `skyward-v0.3.0-onyx.1-…img`，差点刷错包。
- 根因：默认 `OUT` 从 onyx.1 起就没跟着版本改。
- 解法：默认改成 onyx.5；另外发布/刷机时总是显式传 `OUT`。
- 如何避免：改版本号时同时改脚本默认值（已列入本会话检查项）。

## 6. 验证与证据

- 构建：`scripts/build-phone.sh` 用时 37.41 s（2 个上游遗留 warning）；`scripts/build-image.sh`：
  - `recovery.img` 104,857,600 字节，ramdisk 50,694,276 字节，1062 个 cpio 条目；
  - SHA-256 `e66006df7673e4340770635d1f82ae701b6be11e579e89abce089a2b5b2853e1`；
  - `scripts/verify-image.sh`：大小 ✓、`system/bin/recovery` ✓、`skyward/system-init` ✓、`skyward/device.toml` ✓、`skyward/MiSansVF.ttf` ✓。
- 补丁：干净克隆 `kirklin/skyward@ff1668f`，依次 `git apply` 0001–0008 全部成功且无 whitespace 警告；`diff -r --strip-trailing-cr`（排除 `.git`/`target`/`out`/`.onyx-patched`）与 `vendor/skyward` 逐字一致（rc=0）。
- 真机（onyx，`fastboot flash recovery` 后）：
  - `dmesg`：`skyward: onyx 0.3.0-onyx.5 recovery up`；
  - 首页截图：「下载」行回来，没有「浏览器」；设置页没有「色彩风格」行；`/metadata/skyward/settings.json` 里的 `vivid` 已随新代码写掉；
  - 锁屏（浅色）：等待息屏后按电源键点亮，背景是模糊后的上一页；拖动圆形按钮到 50% 时截图，轨道区域是模糊背景 + 半透明蓝色进度，不再是纯色矩形；取像素：轨道圆角外 `(235,236,239)`/`(240,242,244)`（随模糊画面变化），修复前同一处为 `(243,243,243)` 的整块纯色；
  - 锁屏（深色）：设置里点「深色模式」，同样拖动到 40% 截图，背景是深色模糊快照，轨道与圆角处没有纯色块；
  - 设置 `dark` 恢复为 `false`，`settings.json` 不再写 `vivid`；
  - 5 GHz WLAN（重建后的最终镜像）：`/skyward/run/supplicant/wpa_supplicant.conf` 为 `country=CN`、`disable_scan_offload=1`、`sae_pwe=2`；`iw dev wlan0 link`：
    `Connected to 48:e5:33:f3:fe:ca … SSID: CMCC-A9s7-5G … freq: 5260`；`dmesg`：`wlan0 has 192.168.1.227 … the network on wlan0 reaches the internet`；主机 `ping 192.168.1.227` 通，状态栏出现 WiFi 图标与速率；
  - 锁屏滑块拖动在最终镜像上复测：拖到 55% 截图，轨道是「模糊背景 + 半透明蓝色进度」，圆角外像素 `(235,236,239)`/`(240,242,244)` 与静止时一致（修复前是 `(243,243,243)` 整块纯色）。
- 未验证：
  - 「打开网页」的纯文本网页页未逐页点过（属上游能力，代码回到上游实现）；
  - 数字键盘锁屏（recovery 密码）未复测；
  - 下载页的网址下载 / `link.txt` / 二维码回传 / 选文件未逐项复测（代码回到 onyx.3 的实现）。

## 7. 未完成 / 下一步 / 风险

- WLAN 5 GHz 已在本机连上（5260 MHz）；若别的 AP 仍连不上，先看 `/skyward/run/supplicant/` 下的扫描结果与 `wpa_state`，再确认 `country` 是否匹配当地。
- 从浏览器回退后，「下载」页的 URL 输入、二维码、文件选择都回到 onyx.3 的实现，建议真机走一遍（尤其二维码回传）。
- 风险：锁屏背景在快速连续息屏/亮屏时是上一帧的快照（正常）；`lock_blur` 为 0 时不保存快照，锁屏用主题底色，这是有意为之。
- 发布：`v0.3.0-onyx.5` 资产（镜像 / zip / SHA256SUMS / 原厂 recovery）与 `patches/0008-onyx.5-lock-display-wifi.patch` 已按本记录生成。

## 勘误 2026-11-14

- 第 6 节的 `e66006df…`、ramdisk `50,694,276`、zip 45,861,788 是初版 onyx.5 的产物。当天按用户要求把调色改回采样原值后重建（版本号仍为 `v0.3.0-onyx.5`），新镜像 `ac9be2c5…0de2`（ramdisk 50,692,327、zip `6f54c7ec…5c91`），详见 [onyx.5：调色恢复原样](2026-11-14-onyx5-palette-revert.md)。
- 第 2 / 4 节记的「调色按面板色域校正」「sRGB → P3 + 饱和度 0.68」已被撤销，页面现在直接画 `LIGHT` / `DARK` 采样值。
