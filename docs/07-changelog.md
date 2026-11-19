# 版本记录

> 状态：**现行**
> 规则：新版本加在**顶部**；旧条目只能追加勘误，不能改写。
> 版本格式：`v<上游版本>-onyx.<n>`。

---

## v0.3.1-onyx.3 · 2026-11-19

**主题：data 备份不再被小米内存扩展的 `/data/extm` 交换文件卡死**

| 项 | 值 |
| --- | --- |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| SHA-256 | `a525afa9fef1d2166547b7b2ac21f8c99053960730e93f77f94199c063d06376` |
| 内含 skyward | 8,965,824 字节 · `d470bc4068b821759c67813d3593e67e64bf89831c40f3cd27211f153cd19e13` |
| ramdisk | 50,815,375 字节 · 1062 条 |
| 底包 | OS4.0.2.0.XOLCNXM（构建底包不变；真机系统已到 OS4.0.4.0.XOLCNXM，见 `00-status.md`） |
| 上游 | `kirklin/skyward` @ `bd34c05`（v0.3.1）+ 0001–0007 |
| zip | 未打（在线更新取裸 `recovery.img`） |
| 原厂 recovery | `recovery-stock-OS4.0.2.0.XOLCNXM.img` · `ce538507…cd3357`（未改动） |

### 1. 备份 data 每次都失败在进度约 45%

**现象**：备份页勾「data 分区」→ 内部存储 → 完成后校验，备份能跑起来，写到约 17 GB（进度约 45%）时失败，进度页转成失败页；`dmesg` 只有一行：

```
skyward: backup failed: back up the data partition's files:
archive /data/extm/OuEEYQAAAAAriBSUBbu0U1W8A4UpuT1s:
open /data/extm/OuEEYQAAAAAriBSUBbu0U1W8A4UpuT1s: Required key not available (os error 126)
```

**根因**：`/data/extm` 是 HyperOS「内存扩展」放交换文件的目录（本机 6 GiB，文件名每次开机重起，内容用与安全世界绑定的密钥封装）。换一次启动再打开就是 `ENOKEY`，recovery 里永远打不开它；它还是易失的内存内容，备份回去也没有意义。

**修法**：`devices/onyx.toml` 新增 `[backup] data_skipped = ["extm"]`，与上游默认表里跳过 `vendor/goodix`、`vendor/tzstorage`（指纹 / 安全世界）同一机制；解包侧同样跳过，恢复时不会把交换文件写回去。改动只在设备配置，Rust 代码与上游一致。详见 [`sessions/2026-11-19-backup-extm.md`](sessions/2026-11-19-backup-extm.md) 与 [坑 33](06-pitfalls.md)。

### 2. 版本号

`patches/0006` 与 `vendor/skyward/Cargo.toml` / `Cargo.lock` 的 workspace 版本从 `0.3.1-onyx.2` 改为 `0.3.1-onyx.3`（关于本机显示 `0.3.1-onyx.3`）。

### 3. 测试与验证

- 构建：`build-phone.sh` / `build-image.sh` / `verify-image.sh` 全绿；镜像 104,857,600 字节、ramdisk 50,815,375 字节、1062 条；镜像内 `system/bin/recovery` 含 `0.3.1-onyx.3`，其 SHA-256 与构建产物一致（`d470bc40…9e13`）。
- data 备份（修复本体）：在**只差版本号的测试镜像**上跑通——同一份代码与 `device.toml`，勾 data + 内部存储 + 完成后校验，34.4 GB 写完并校验（`backup saved in /sdcard/Skyward/backups/…`，`backup.toml` 中 size/stored 34,833,827,840、sha256 `8c98ce7c…2dfc`），比修复前少 6.5 GB、不再卡在 `/data/extm`。
- 真机（本版）：`fastboot flash recovery` 刷入；`dmesg`：`onyx 0.3.1-onyx.3 recovery up`；`sha256sum /system/bin/recovery` 为 `d470bc40…9e13`；`/skyward/device.toml` 含 `data_skipped = ["extm"]`；关于本机显示 `0.3.1-onyx.3`、`OS4.0.4.0.XOLCNXM`。
- **未做**：本版刷入后按用户要求没有再跑第二遍 data 备份（第一次验证备份与随后的复跑均已删除）；恢复（restore）全流程未跑；onyx.2 的两处安装期修复仍待在真机上跑一次完整官方整包（见 `00-status.md` 第 4 节）。

---

## v0.3.1-onyx.2 · 2026-11-19

**主题：修「官方整包刷完不自动刷回 Skyward」与「刷整包时进度卡在 100%」**

| 项 | 值 |
| --- | --- |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| SHA-256 | `f1b7685e60498e92a19cda4c27202b4e470074702dcc8f8991376bb4429a7d38` |
| 内含 skyward | 8,959,728 字节 · `6e2c030e0e216845a4ec242ac8a7ff99f7448fa4e0ce9c06d56be0442ea06840` |
| ramdisk | 50,811,639 字节 · 1062 条 |
| 底包 | OS4.0.2.0.XOLCNXM（Android 17；与 onyx.1 相同） |
| 上游 | `kirklin/skyward` @ `bd34c05`（v0.3.1）+ 0001–0007 |
| zip | 未打（在线更新取裸 `recovery.img`） |

### 1. 整包刷完，recovery 还是原厂的

**现象**：在「安装」里选官方整包（`payload.bin` 那种），update_engine 一路成功，重启能进新系统；但再进 recovery 是原厂界面。`dmesg` 里要么没有 `install: this recovery written back to …`，要么是 `Reflashed(Failed("write /dev/block/by-name/recovery_b: Operation not permitted"))`。

**根因**：Android 17 的 `update_engine` 在校验（`FilesystemVerifierAction`）结束后会把刚写完的目标块设备置为只读（`BLKRO`）。Skyward 收尾用 `Kept::write()` 打开 `recovery_<目标槽>` 写回自己时拿到 `EPERM`，于是 `Reflashed` 落到 `Failed`，recovery 分区里留着包里的原厂镜像。同一结论见上游 PR #48 的实机记录（「update_engine 校验后留下目标块设备只读、导致保留 recovery 写入 EPERM」）。

**修法**（补丁 0007，`crates/skyward-install/src/image/protection.rs` + `image.rs`）：`image::flash()` 在写每个设备之前先用 `BLKROGET` 读标志，只读就用 `BLKROSET 0` 清掉；写完、`sync_all`、读回校验完再把标志恢复原样（成功与出错路径都恢复，`ReadOnly` 的 `Drop` 兜底并写 kmsg）。只对**这次选中的设备**做，普通文件不碰 ioctl。顺手加两条 kmsg：没打开「自动重新刷入 Skyward」、以及收尾判断「两个槽位都已经是这个 build、不用写」，下次看 `dmesg` 就能分辨是没触发还是写失败。

### 2. 刷整包时进度一到 100% 就不动

**现象**：进度条很快跳到 100%，之后十几分钟一动不动，实际还在写；写完才跳「完成」。

**根因**：进度取的是「包被读到的最远字节」（`Mount::served()`）。`package::identify` 要读 zip 末尾的中央目录，那一下 `served()` 就等于整个包的大小，`done = served - payload_offset` 被 clamp 成 `total`，于是从第一秒就是 100%。

**修法**（补丁 0007，`fuse.rs` + `run.rs`）：`apply()` 先用 `Mount::watch_payload(payload_offset, payload_size)` 标出 payload 区间，FUSE 服务端只累计落在这个区间里的读字节（`Mount::payload_read()`），`Stage::Writing` 于是跟着 update_engine 真正读到的 payload 走；之后的校验阶段仍按分区显示「第 2 步，共 3 步：校验 …（n/m）」。

### 3. 测试与验证

- 单测：`crates/skyward-install/src/fuse.rs` 新增 `only_bytes_of_the_payload_range_count`（区间外的读不计、重复读同区间重复计、由调用方 clamp）。
- 构建：三个产物（`skyward` / `system-init` / `skyward-pack`）重编通过；镜像 `skyward-pack list` 1062 条、`scripts/verify-image.sh` 全绿；镜像内 `system/bin/recovery` 含 `0.3.1-onyx.2`、`clear the read-only flag of`、两条新 kmsg 文案。
- **未做**：没有在 onyx 上再刷一次完整 OTA。`BLKRO` 那一段依据的是上游 #48 在同类 Android 17 机器上的实机结论 + 本次代码；复验步骤见 [`00-status.md`](00-status.md) 第 3 节。

---

## v0.3.1-onyx.1 · 2026-11-14

**主题：同步上游 v0.3.1（新 UI 状态机、密钥服务自动发现、自带 OMAPI）+ 保留 onyx 全部设备能力**

| 项 | 值 |
| --- | --- |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| SHA-256 | `27fbfc1c442b969fa3134fa9577f83031a34ed0979c0e697cbfa5f805f73cf5f` |
| 内含 skyward | 8,955,824 字节 · `81e6e4d92b8afa0da5c74c7d626ce1ee87cc6cd8f7990385ac1c10c17b4c66f1` |
| ramdisk | 50,668,045 字节 · 1062 条 |
| 底包 | OS4.0.2.0.XOLCNXM（Android 17） |
| zip | 未打（在线更新取裸 `recovery.img`） |
| 原厂 recovery | `recovery-stock-OS4.0.2.0.XOLCNXM.img` · `ce538507…cd3357`（未改动） |
| 上游 | `kirklin/skyward` @ `bd34c05`（v0.3.1）+ 0001–0006 |

### 上游带来了什么

- **UI 状态机拆分**：`crates/skyward-ui/src/app.rs` 拆成 `app/*.rs`（按页面分模块），`skyward/src/ui.rs` 的 `run()` 收缩成 `Pages` 结构 + 每类事件一个方法；
- **密钥服务自动发现**：新增 `skyward-programs`，从安装系统的 `system_ext` / `vendor` / `odm` 分区读 init 脚本与 VINTF 描述，按手机自己的顺序拉起 qseecomd / keymint / gatekeeper / secure_element / weaver / boot-control，`devices/*.toml` 不再写这些服务；
- **自带 OMAPI 与 binder 服务端**：`skyward-omapi` crate 提供 `android.se.omapi.ISecureElementService`，`skyward-binder/src/serve.rs` 提供 binder 服务端。我们旧的 `0002-omapi-se-bridge` 因此退休；
- **其他**：Rust 1.100 / edition 2024、DNS 多服务器、长 kmsg 分条、boot 分区写前回填、MTP 在 Linux 宿主上可编、`skyward-pack described` 子命令等。

### 改了什么（onyx 侧）

- **补丁重排**：`0001` Windows 宿主编译（新增 `skyward-pack` 的 `described` feature 门控）、`0002` CE 的 gatekeeper 回退、`0003` 配置 / WLAN / 振动 / 密钥服务库路径、`0004` 并行下载 / 自更新 / 本地刷入、`0005` UI（锁屏模糊与滑块、首页读数、解密页、下载页、设置页、双击亮屏、AVB 页）、`0006` 版本与 `Cargo.lock`；
- **`devices/onyx.toml`**：删掉 6 个写死的密钥服务（含 `description` 字段），只留触摸 + WLAN / 振动 / 更新 / 底包配置；
- **UI 移植**：把 onyx.1–onyx.5 的改动从旧 `app.rs` 迁到新的 `app/*.rs`；锁屏、首页读数、解密页倒计时、下载页、二维码、纯文本网页、设置项、双击亮屏都保留；
- **面板不 rest**：沿用 onyx 的「息屏只关背光、面板保持 On」修复，上游的 rest/turn_off 逻辑没有启用。

### 踩到的坑（本次新增）

1. **keymint 一启动就退出**：`skyward-programs` 给 `/vendor` 程序只给 `/system/lib64:/vendor/lib64`，Android 17 recovery 没有 `libvndksupport.so`，keymint 报 `CANNOT LINK EXECUTABLE ... library "libvndksupport.so" not found` 后 exit 1，`/data` 因此打不开、也就没有锁屏。修法：`VENDOR_LIBRARIES` 加上 `/vendor/lib64/hw`、`/mnt/system/system/lib64`、`/mnt/system/system/lib64/bootstrap`（与我们 0.3.0 写死的服务表一致）。详见 [`06-pitfalls.md`](06-pitfalls.md)。
2. **Windows 宿主编 `skyward-pack`**：上游新加的 `described` 子命令依赖 `skyward-programs`，后者要 Unix 的 libc 接口。用 `--no-default-features` 把 `described` 关掉即可（`scripts/build-pack.sh` 已改）。
3. **旧 settings 兼容**：0.3.0 的 `settings.json` 里的 `remember_data` / `data_password` / WLAN 字段被新结构直接读到，升级后自动解密与自动连 WLAN 都还在。

### 真机验证

- `fastboot flash recovery` 后 `dmesg`：`onyx 0.3.1-onyx.1 recovery up`；
- `skyward keys`：自动发现 8 个程序（qseecomd / ssgtzd / hlosminkdaemon / keymint / gatekeeper / secure_element eSE1 / OMAPI / weaver / boot-control）；
- `/data`：`/dev/block/dm-9 holds f2fs at /data`；user 0 CE 自动解开（旧版记住的锁屏密码），`/sdcard/DCIM/Camera` 的 JPEG 可读；user 999 仍锁，日志说明原因；
- WLAN：`CMCC-A9s7-5G`、`freq: 5260`、`wlan0 has 192.168.1.227`、`reaches the internet`；
- 首页读数、锁屏（模糊快照 + 滑动解锁）、设置页（锁屏模糊滑杆、双击亮屏）、关于本机（`0.3.1-onyx.1`、`© 2026 Kirk Lin & Remoparrot`）均有截图；
- 未验证：触摸服务未重新注入复测（0.3.0 已验证）、振动未听感复测、下载/网页/AVB 页未点、数字键盘锁屏未点。

---

## v0.3.0-onyx.5 · 2026-11-14

**主题：下载页回归（删掉图形浏览器）+ 锁屏模糊与滑块 + 5 GHz WLAN + 解密前不锁屏 + 颜色按面板色域校正**

| 项 | 值 |
| --- | --- |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| SHA-256 | `e66006df7673e4340770635d1f82ae701b6be11e579e89abce089a2b5b2853e1` |
| 内含 skyward | 8,769,424 字节 · `a339f899c9fbded0830c05bc998fb760b7f14fe09b011d9cb715f095896fa183` |
| ramdisk | 50,694,276 字节 · 1062 条 |
| 底包 | OS4.0.2.0.XOLCNXM（Android 17） |
| zip | `skyward-v0.3.0-onyx.5-onyx-OS4.0.2.0.XOLCNXM.zip` · 45,861,788 字节 · `a428f0c9ea3b8797e6e0a0d2aedaf8c5110ffc6eafd5a734887eb6ea00621805` |
| 原厂 recovery | `recovery-stock-OS4.0.2.0.XOLCNXM.img` · `ce538507…cd3357`（未改动） |

### 改了什么

- **删掉图形浏览器**：回退 0007 的 `skyward-ui/src/web/`（HTML/CSS 排版、图片、链接、地址栏与键盘，约 2,700 行），「下载」页回到 onyx.3：网址输入 + 开始下载 + `/sdcard/Download/link.txt` + 二维码回传 + 进度卡；按键盘「确定」打开上游的纯文本网页页（只取标题/正文/链接）。
- **锁屏背景模糊**：锁屏画上一页的模糊快照（1/10 采样的小图拉伸），上面压一层半透明：浅色白 56、深色黑 88；设置页新增「锁屏背景模糊」滑杆（0 为关闭），值存 `/metadata/skyward/settings.json`。
- **锁屏滑块修复**：拖动圆形按钮时，原来用页面底色 `pal.bg` 把控件区域抹平，锁屏上就留下「背后一块纯色」；改为把控件所在行按页重画，模糊快照随页面一起回来（浅色/深色都验过）。
- **5 GHz WLAN**：`wpa_supplicant.conf` 写入 `country=<机型属性，默认 CN>`、`disable_scan_offload=1`、`sae_pwe=2`，去掉全局 `pmf=1`；WPA2-PSK 网络加 `ieee80211w=1`（可选 PMF），SAE 仍是 `ieee80211w=2`。世界监管域把 5.8 GHz 留给被动扫描、芯片 offload 扫描覆盖不全，是 5 GHz AP 扫不到/连不上的原因。
- **解密前不锁屏**：启动首屏直接是「解密」页；recovery 锁屏只在 data 解密后、息屏再点亮时出现。
- **颜色**：调色板统一做 sRGB → Display P3 + 饱和度 0.68 校正，观感接近系统「原色」；「色彩风格」页、设置项与搜索项一并删除（旧的 `vivid` 字段会被忽略）。
- **版本/补丁**：`0.3.0-onyx.5`；`patches/0008-onyx.5-lock-display-wifi.patch` 用干净上游重建（0001–0008 依次 apply 无警告，`diff -r` 与 vendor 树逐字一致）。

### 真机验证

- `fastboot flash recovery` 后 `dmesg`：`skyward: onyx 0.3.0-onyx.5 recovery up`。
- 首页：「下载」行回归、没有「浏览器」；设置页没有「色彩风格」行；`settings.json` 不再写 `vivid`。
- 锁屏（浅色/深色）：息屏 → 点亮，背景是上一页的模糊快照；按住滑块拖到 50% 截图，轨道与圆角处仍是模糊背景（圆角外取像素 `(235,236,239)`、`(240,242,244)`，随模糊画面变化；修复前是整块 `(243,243,243)`）。
- 5 GHz WLAN：`iw dev wlan0 link` 显示 `SSID: CMCC-A9s7-5G`、`freq: 5260`；`dmesg`：`wlan0 has 192.168.1.227`、`the network on wlan0 reaches the internet`；状态栏出现 WiFi 图标。
- 未验证：纯文本网页页未逐项点过；下载页的网址下载/二维码回传未逐项复测；数字键盘锁屏未复测。

### 同日重建：调色恢复原样（版本号不变，2026-11-14）

- **现象**：用户反馈初版 onyx.5「颜色太淡了」。根因是页面把 sRGB 采样值先转 Display P3、再压饱和度 0.68（`Theme::graded()` → `Palette::original()` → `stock()`，图标底色另走 `Theme::ink()`），等于把每个彩色往灰里拉：设置页滑杆蓝 `(74,128,247)` → `(97,126,200)`。
- **处理**：整层撤销——删 `theme.rs` 的 `graded()` / `Palette::original()` / `stock()` / `Theme::ink()`，删 `color.rs` 的 `p3()` / `desaturated()`，`icons::tile()` 不再调 `t.ink()`；`patches/0008` 里对应三段一并删除，干净上游 apply 0001–0008 后 `diff -r` 与 vendor 树 rc=0。版本号仍是 `v0.3.0-onyx.5`（用户明确要求不变）。
- **重建产物**（上面的表是初版数值，以本小节为准）：

| 项 | 值 |
| --- | --- |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| SHA-256 | `ac9be2c5f8d9604e2384d57c99f544df3c002c3f65b430ceb0b1f822fc9e0de2` |
| 内含 skyward | 8,769,040 字节 · `4b712147e584ab227d56f5006187b8306fbb1b9f3b7fbec66c3e7a7e2fc0c846` |
| ramdisk | 50,692,327 字节 · 1062 条 |
| zip | `skyward-v0.3.0-onyx.5-onyx-OS4.0.2.0.XOLCNXM.zip` · 45,860,277 字节 · `6f54c7ec721e7ed25c012a9ddbbd5ce3d9765810ba5cf5a1011e79e5ffbd5c91` |
| 原厂 recovery | 未改动 · `ce538507…cd3357` |

- **真机**：`fastboot flash recovery` 后 `dmesg` 仍是 `onyx 0.3.0-onyx.5 recovery up`；设置页滑杆取色回到 `(74,128,247)`，首页图标蓝 `(52,130,255)` 与 onyx.4 截图一致；浅色/深色与锁屏复验正常。

## v0.3.0-onyx.4 · 2026-11-14

**主题：「下载」页改成图形浏览器（自带 HTML/CSS 排版与图片，不跑 JavaScript）+ 浏览器里的下载走 512 并行 + 关于本机署名**

| 项 | 值 |
| --- | --- |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| SHA-256 | `239d0fbb38c2dbde16595c1335ffe038df3ff48001d167bf3a9c2cfd4020f3ea` |
| 内含 skyward | 9,532,768 字节 · `84342335344898eda01fd9977a3b1be272c49a1cb92945d2be21bfb0a7fc6a85` |
| ramdisk | 51,185,270 字节 · 1062 条 |
| 底包 | OS4.0.2.0.XOLCNXM（Android 17） |
| zip | `skyward-v0.3.0-onyx.4-onyx-OS4.0.2.0.XOLCNXM.zip` · 46,292,174 字节 · `bdbff7e77664d1e5471ebb32d2cbc1fecd64083504568bdfbc949ebbc8de5935` |
| 原厂 recovery | `recovery-stock-OS4.0.2.0.XOLCNXM.img` · `ce538507…cd3357`（未改动） |

### 改了什么

- **浏览器**（新模块 `skyward-ui/src/web/`，约 2,700 行）：自带的小排版引擎——HTML 容错解析、CSS 子集（display / 颜色 / 字号 / 粗细 / 对齐 / 边距 / 行高 / 背景色 / 列表 / 宽度）、块与行内排版与折行（中文逐字可断行）、`<img>` 图片（PNG / JPEG / WebP / GIF，线性缩放）、链接命中与跳转、后退/刷新、地址栏 + 屏幕键盘、触摸滚动、按屏幕分批绘制（长页不占内存）；字符集按 `Content-Type` / `<meta charset>`，中文站常见 GBK 也能读。
- **只由脚本生成的页面**（原神/星穹铁道等官网）：页面本身没有内容时，浏览器改用页面自报的信息渲染——`<title>`、`meta description`、`og:image` 与内联样式里的图片、页面里的链接，并给出提示而不是一片空白。
- **浏览器内下载**：地址栏「下载」或点到非 HTML 的链接即开始下载，进度卡（网速 / 暂停 / 继续 / 停止）留在浏览器页里；`skyward-net/download.rs` 新增 `save_fast`：先用 `Range: bytes=0-0` 问长度，服务端支持分段就走与更新同一套「64 KiB 分段、最多 512 连接」的并行下载，不支持就退回单连接。
- **修复**：页面读取完成后的后续动作（如自动下载）原来被丢弃，现在与按键动作走同一条 effect 队列；二维码回传的 URL 会被截断的问题属已知项（页面读取只取一次 head）。
- **关于本机**：署名由「© 2026 Kirk Lin」改为「© 2026 Kirk Lin & Remoparrot」。
- **版本号**：`0.3.0-onyx.4`；新增 `patches/0007-onyx.4-browser.patch`（0001–0007 用干净上游重建，295 个文件逐字一致）。

### 真机验证

- `fastboot flash recovery` 写入 `0.3.0-onyx.4`；`dmesg`：`onyx 0.3.0-onyx.4 recovery up`；`/system/bin/recovery` 的 sha256 与镜像内一致。
- Bing 搜索页（`cn.bing.com/search?q=skyward+recovery`）：约 600 ms 取回，排版后 700+ 文本段 / 250+ 链接；截图确认标题、摘要、链接、颜色都对，点链接可跳转，`后退` 能回来。
- `bilibili.com`：SSR 的文字与 12 张封面图都渲染出来（导航、分类、卡片标题、横幅图）。
- `ys.mihoyo.com/main/`（纯脚本页）：显示官网标题、2.3 版本简介与页面自带的图，不再是白屏。
- 本机测试页（标题/段落/背景色/图片/列表/链接）：全部正常；点「去第二页」跳转、`后退` 回第一页。
- 下载：`/sdcard/Download/photo.png`（33 KB）与 `/sdcard/Download/x.img`（104,857,600 字节）都经浏览器下载完成；后者走 512 并行，本机 range 服务器约 12 秒（≈8.7 MB/s），与 Skyward 更新同一套速度。
- 关于本机：署名显示「© 2026 Kirk Lin & Remoparrot」。

### 已知限制

- 不运行 JavaScript，也没有 flex/grid 版式（按块排版）：脚本应用类站点（原神官网的动效、B 站的播放器、Bing 首页）只能显示静态内容；视频、WebGL 不予支持。
- 图片按页面里 `<img>` 与内联样式取，CSS 外部样式表里的背景图不取；HTTPS 只走系统内置根证书。
- 二维码回传的 URL 偶发被截短（服务器只读一次请求头）；地址栏直接输入或用 `keyboard` 不受影响。

## v0.3.0-onyx.3 · 2026-11-13

**主题：更新下载改为最多 512 连接并行（GitHub 45.85 MB 从约 17 分钟降到 17.2 秒）+ 首页读数在解密后补齐 + 更新页对本地刷入的进度/结果反馈**

| 项 | 值 |
| --- | --- |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| SHA-256 | `d0a67128ee1fbc54033dadae2cf9c55b429733c4b163e1528dedbaca370360c5` |
| 内含 skyward | 8,753,632 字节 · `bb75d7e4aef48a3a5f3b986e6b0974ad7daf531ed5e25d7fbb88611fc942ba44` |
| ramdisk | 50,681,746 字节 · 1062 条 |
| 底包 | OS4.0.2.0.XOLCNXM（Android 17） |
| zip | `skyward-v0.3.0-onyx.3-onyx-OS4.0.2.0.XOLCNXM.zip` · 46,347,671 字节 · `9f41916f651927de297222832a2f3295f2a445fdc87e44f16480957fdbbeb874` |
| 原厂 recovery | `recovery-stock-OS4.0.2.0.XOLCNXM.img` · `ce538507…cd3357` |

### 改了什么

- **并行下载**：`skyward-net/download.rs` 把带校验和的包（Skyward 更新、系统 OTA）按 64 KiB 分段、每段一个 `Range` 请求，最多 512 个连接同时取；全部写完再整文件核对 SHA-256 / MD5。单段失败重试（最多 4 次，退避 200 ms×n）；服务端不认 `Range`（回 200）时退回单连接；停止或失败时删除 `.part`，不会拿半截文件续传。
- **DNS 缓存**：`skyward-net/http.rs` 的自定义解析器按 (host, port) 缓存 5 分钟。512 个连接不再各查一次 DNS——实测路由器的 DNS 会拒答突发查询（`Query Refused`），这也是第一次 512 连接测试失败的原因。
- **首页读数补齐**：`skyward/src/ui.rs` 在 `/data` 打开或解锁完成后重新 `skyward_info::collect`，机型卡片的「可用空间」不再因为开机时 `/data` 未挂载而整块消失。
- **更新页反馈**：`skyward-ui/pages.rs` 把更新任务（进度 / 成功 / 失败）从「在线更新」段中独立出来；本地 `recovery.img` 刷入也用同一张进度卡和「更新成功 · 已将 Skyward 刷入槽位 B 的 recovery 分区。」。`SkywardJob` 新增 `local` 字段区分来源，本地刷入的版本号未知，文案不再写版本号。
- **版本号**：`0.3.0-onyx.3`；新增 `patches/0006-onyx.3-fast-download.patch`。

### 真机验证

- 同一份下载器代码（`skyward-net` 的 example `fetch`）在 onyx 上从 GitHub 下载 `v0.3.0-onyx.2` 的 45.85 MB zip：**17.2 s**，SHA-256 校验通过；此前单连接约 17 分钟（≈40 KB/s）。
- 本地 range 服务器 100 MB：并行 5.9 s（≈17.8 MB/s）、单连接 3.7 s（≈28 MB/s）——并行在快链路上有连接开销，收益主要来自 GitHub 这种单连接被限速的链路。
- `0.3.0-onyx.1` 高级 → Skyward 更新：检查到 `0.3.0-onyx.2`、下载并写入槽位 B；重启后 `dmesg`：`onyx 0.3.0-onyx.2 recovery up`，首页读数出现。
- 在 `0.3.0-onyx.2` 的更新页用「从本地 recovery.img 刷入」写入 `0.3.0-onyx.3` 镜像；`dmesg`：`Skyward's build written to [B]: Ok(())`。
- 重启后 `dmesg`：`onyx 0.3.0-onyx.3 recovery up`；`/system/bin/recovery` 的 sha256 与镜像内一致（`bb75d7e4…`）。
- onyx.3 首页机型卡片：`B / 当前槽位`、`已解密 / 数据分区`、`175.1GB / 可用空间`、`100% / 未充电`；可用空间在解密完成后出现（此前整列缺失）。
- onyx.3 再走一次本地刷入：页面出现进度卡，随后「更新成功 · 已将 Skyward 刷入槽位 B 的 recovery 分区。」与「重启到恢复模式」。

### 已知限制

- GitHub 直连在中国大陆时快时慢、偶尔完全连不上；本地刷入（`/sdcard/Download/recovery.img`）是兜底方案。
- 并行下载不续传：停止或失败会删掉 `.part`，下次从 0 开始。
- 512 是上限，实际连接数 = min(512, ⌈包大小 / 64 KiB⌉)。
- 系统 OTA（几 GB）同走并行路径；未在真机完整下载过 OTA。

---

## v0.3.0-onyx.1 · 2026-11-13

**主题：OS4 底包 + WLAN 自动连接 + 振动 + 锁屏（每次亮屏）/ 双击亮屏 + 自动解密页**

| 项 | 值 |
| --- | --- |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| SHA-256 | `714dfc27be9ae76c18366ebd36fc5dff587a9fa4c17873a803d55c8aa1210ba5` |
| 内含 skyward | 8,655,096 字节 · `fb67d123ac80eae2d71ba9fac706a8e577a2cf3532edda48550a2c1161452629` |
| ramdisk | 50,669,556 字节 · 1062 条 |
| 底包 | OS4.0.2.0.XOLCNXM（Android 17） |
| zip | `skyward-v0.3.0-onyx.1-onyx-OS4.0.2.0.XOLCNXM.zip` · 45,840,075 字节 · `ab7bb064…6f62` |
| 原厂 recovery | `recovery-stock-OS4.0.2.0.XOLCNXM.img` · `ce538507…cd3357` |

### 改了什么

- **底包**：`[stock]` 从 OS3.0.306.0 换到 OS4.0.2.0.XOLCNXM；版本号改为 `0.3.0-onyx.1`；`has_root` 代替 `is_absolute` 以兼容 Windows 宿主校验。
- **WLAN**：`[wlan]` 配置 `qca_cld3_wcn7750` + `rfkill`，`wpss_boot` / `wlan_en_delay`，固件从 vendor 与 persist 取；`wlan.rs` 对 `EBUSY` 重试、启动自动开 WLAN；`wpa-aidl-shim` 让 AIDL supplicant 跳过 recovery 不认的 `addService`；UI 保存上次网络并在下次启动自动加入。
- **振动**：AW8697 的 sysfs 后端（`activate` / `duration` / `effect_id` / `gain`），`skyward haptic` 可测。
- **UI**：图 1 滑动锁屏（有 4–8 位 recovery 密码时改数字键盘）；**每次息屏再点亮都先显示**，解锁回原页；开机首屏滑动后自动进入解密页；双击亮屏；AVB 2.0 禁用页（未测）。控制中心已按用户要求删除。
- **记住密码**：解密页可记住手机锁屏密码，下次开机滑动后自动打开 user 0；密码换掉时自动失败、清空并回到手动输入；密码明文存 `/metadata`（0600）。
- **解密倒计时**：data 打开后「完成 · N 秒后进入主界面」，3 秒自动回主界面。
- **下载**：主界面「下载」；键盘「确定」打开文本网页，「开始下载」才下载；`link.txt`、二维码回传网页；文件存 `/sdcard/Download`，进度显示网速，可暂停/继续/停止；user 999 不再阻塞解密页。
- **网页**：内置文本浏览器（HTTP/HTTPS、重定向、HTML 取字/标题、滚动）；**无 JavaScript/CSS/图片**，不是 Chromium；`ys.mihoyo.com` 可显示标题与文本。
- **高级**：Skyward 更新与禁用 AVB 2.0 移到「高级」，设置页不再放。
- **Skyward 更新**：检查 `Remoparrot/skyward-onyx` 的 Release，asset 命名 `skyward-<tag>-onyx-*.zip`；版本比较按 `0.3.0-onyx.N`。
- **打包**：`skyward-pack recovery --extra RAMDISK=HOST`；`build-phone.sh` 编 shim，`build-image.sh` 把 shim 放进 `skyward/`。

### 真机验证

- 刷入后 `dmesg`：`onyx 0.3.0-onyx.1 recovery up`；
- `/data` 自动打开：`/dev/block/dm-9 holds f2fs at /data`；
- WLAN 扫描 CMCC-A9s7-5G（5 GHz / SAE），`wpa_state=COMPLETED`；重启后自动连接，`192.168.1.227/24`；
- 振动驱动：`awinic_haptic` 进入 RAM 模式，`level=0x40`，`duration=16`；
- 锁屏启动：无 recovery 密码时为滑动锁屏，`/data` 不打开；种入 4 位锁后为键盘，UI 存活。
- 注入触摸：从滑锁轨道左到右拖动后 `/data` 挂载、进入解密页；`pmic_pwrkey` 注入电源键，息屏后点亮背光，`wake()` 压入锁屏。
- 唤醒黑屏修复：面板不再 `rest`/`turn_off`，息屏只关背光；唤醒后 DPMS On、背光 10926，锁屏页可见。
- user 0 CE：`skyward data --credential <用户锁屏密码>` 后 `/data/media/0` 真实文件名，`DCIM/Camera` 的 JPEG 可读；user 999 仍锁。

### 已知限制

- user 0 CE 已用用户锁屏密码 + `skyward data --credential` 验证；
- 锁屏滑动、记住密码/自动解密、解密倒计时已用注入触摸验证；4–8 位键盘、双击亮屏未逐项点过；
- 下载页/二维码表单/本地 HTTP 下载/文本网页已验证；暂停/继续的 UI 按钮已实现，未在慢速大文件上逐项点过；
- AVB 2.0 按要求未测试；
- WLAN 密码明文存 `/metadata`（0600）；
- Skyward 在线更新只验证到配置/API，缺更高版本可测完整写入。

---

## v0.2.0-onyx.4 · 2026-11-12

**主题：user 0 的 CE 数据解开（gatekeeper 回退）**

| 项 | 值 |
| --- | --- |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| SHA-256 | `b41bee5b5342e5a2f0f32ba01e9a0cca3c0ab69b520799e4e29ee49957f1f83f` |
| 内含 skyward | 8,619,216 字节 · `51e902f6995918df4ff430c2acccdbaaa29ee00e8963588029a1f7423e86c7e5` |
| ramdisk | 49,643,317 字节 · 996 条 |
| zip | `skyward-v0.2.0-onyx-OS3.0.306.0.WOLCNXM.zip` · `667e0163…abb87` |

### 改了什么

- `crates/skyward-crypto/src/data.rs`：
  - `protector()` 拆成 `protector_ids()` / `protector_named()`，便于枚举同一用户的全部 protector；
  - `open_user_files()` 在 weaver 返回 `WeaverUnusable` 时，遍历同用户其他「`Bound::Secdiscardable` + 有 `.pwd`」的 protector，用同一个凭据走 gatekeeper 重试；
  - 抽出 `open_with_protector()`，保持原逻辑不变；
  - 新增 `WeaverUnusable` 错误类型，区分「weaver 不可用」与「凭据错误」。
- `crates/skyward-binder` + `crates/skyward/src/omapi.rs`：OMAPI → SE HAL 桥（实验，不自动启动）。
- `devices/onyx.toml`：v3 已有的 7 个服务配置保持不变。

### 真机验证

- 界面「解密」输入锁屏密码 → `/data` 挂载，`/data/media/0` 出现真实文件名；
- 相册 89 张，JPEG 头 `ffd8ffe1` 正常；
- `/data/data/com.tencent.mm`、`/data/media/0/Android/data/com.tencent.mm` 可读；
- f2fs 检查 0 错误；
- 只刷 recovery 分区，重启后系统正常进入。

### 已知限制

- user 999 仍锁（只有 weaver 绑定的 protector）；
- WLAN / 振动未配置；
- `setprop ctl.stop recovery` 会重启整机，禁止使用。

---

## v0.2.0-onyx.3 · 2026-11-12 00:07

**主题：触摸修好 + `/data` 设备级解密**

| 项 | 值 |
| --- | --- |
| 镜像 SHA-256 | `b1374ccd3e58017de8e9e794045f446525098f21fce0d6192ea2c5905017b5ee` |
| 状态 | 已备份为 `recovery-v3-backup.img`，不随 Release 分发 |

### 改了什么

- `devices/onyx.toml`：
  - 触摸服务从 `/odm/bin/touch_report` 改为 `/odm/bin/touch_report_debug`（onyx 没有非 debug 版本）；
  - 补 6 个安全世界服务：`qseecomd`、`keymint-qti`、`gatekeeper-qti`、`secure_element qti`、`weaver nxp`、`boot control qti`；
  - `gatekeeper` / `secure_element` / `weaver` 用 `description` 单独交 VINTF 片段。
- 去掉「写 `enable_touch_raw=0`」的尝试（无效）。

### 真机验证

- 触摸正常（`/dev/input/event7` 直接读仍无事件，证明来自 `touch_report_debug`）；
- `/data` 自动解密挂载，`/data/app`、`/data/misc`、`/data/media` 可读；
- user 0 / 999 的 CE 仍锁（当时的结论是「必须 weaver」）；
- 期间发现：VINTF 目录里一个空文件会让整份清单变 NULL（见踩坑 1）。

---

## v0.2.0-onyx.2 · 2026-11-11 23:16

**主题：密度修正 + 触摸改走小米触摸层 + 屏幕诊断**

| 项 | 值 |
| --- | --- |
| 镜像 SHA-256 | `9ae3c85e6db90f7802f217b75279e5ee81aacfa19377984c4cb41913d93ef9dd` |
| ramdisk | 998 条（当时的数字；v3 之后为 996） |

### 改了什么

- `density`：1109 → **512**（1280 ÷ 400 × 160）；
- 触摸：不再写 `enable_touch_raw`，改为拉起 `/odm/bin/touch_report`；
- 添加屏幕诊断：`bring_up` 结果、已挂载分区、已加载模块、`/dev/input` 设备名、touch 相关内核日志最后 28 行。

### 结果

- 密度正确，UI 不再溢出；
- 仍无触摸：onyx 没有 `touch_report`，服务起不来；
- 诊断页直接指出 `devices not brought up: /odm/bin/touch_report is missing`，为 v3 定位省了时间。

---

## v0.2.0-onyx.1 · 2026-11-11 22:35

**主题：首次构建**

| 项 | 值 |
| --- | --- |
| 镜像 SHA-256 | `78bbf0527829e78e35399ce6cba070181dad5066e54b8c7ce97d10bac2df6640` |
| ramdisk | 996 条（首次） |

### 做了什么

- 从官方全量包抽 stock recovery（`OS3.0.306.0.WOLCNXM`）；
- Rust gnu 宿主 + NDK r29 交叉编译 skyward / system-init；MinGW 链接宿主 `skyward-pack`；
- `patches/0001`：给 `ramdisk.rs` 的 Unix-only 函数加 `#[cfg(unix)]`；
- 首次打包：`system/bin/recovery` 换成 skyward，加 `skyward/`、符号链接、`prop.default` 属性；
- 结构级验证：header v4、kernel 0、ramdisk LZ4、996 条、aarch64 PIE、AVB footer。

### 结果

- 可以启动，但 density 1109 导致 UI 放大、无触摸（见 v2）。

---

## 仓库开源 · 2026-11-13

- 新建 `Remoparrot/skyward-onyx`，把 `devices/onyx.toml`、三个补丁、构建脚本、文档和真机结论整理进来；
- Release `v0.2.0-onyx.4` 提供 `recovery.img`、stock recovery、zip、`SHA256SUMS`；
- 新增 `agent.md`、`docs/00-status.md`、`docs/README.md`、`docs/sessions/`；
- 镜像与 zip 不进 git（100 MB 单文件限制），只放 Release。
