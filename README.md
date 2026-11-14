# Skyward for onyx · 红米 Turbo 4 Pro

> 把 [Skyward](https://github.com/kirklin/skyward)（Rust 从零写的第三方 recovery）移植到 **Redmi Turbo 4 Pro（onyx）**：触摸可用、`/data` 自动解密、**user 0 的 CE 存储（相册 / 微信）能用锁屏密码解开**，并补上 WLAN 自动连接、振动、recovery 锁屏（每次息屏点亮都显示滑动锁屏）、双击亮屏和 Skyward 在线更新；只改写 recovery 分区、不动用户数据。

[![Release](https://img.shields.io/github/v/release/Remoparrot/skyward-onyx?label=release&color=1f6feb)](https://github.com/Remoparrot/skyward-onyx/releases)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)
[![Device](https://img.shields.io/badge/device-onyx%20%C2%B7%20Redmi%20Turbo%204%20Pro-green)](#设备)
[![Base](https://img.shields.io/badge/base-OS4.0.2.0.XOLCNXM-orange)](#当前状态)
[![Upstream](https://img.shields.io/badge/upstream-kirklin%2Fskyward-8a2be2)](https://github.com/kirklin/skyward)

---

## 当前状态

| 项 | 值 |
| --- | --- |
| 最新 release | [`v0.3.0-onyx.5`](https://github.com/Remoparrot/skyward-onyx/releases/tag/v0.3.0-onyx.5) |
| 镜像 | `recovery.img` · **104,857,600 字节**（整分区） |
| SHA-256 | `e66006df7673e4340770635d1f82ae701b6be11e579e89abce089a2b5b2853e1` |
| ramdisk | 50,694,276 字节（LZ4）· 1062 个 cpio 条目 |
| 内含 skyward | 8,769,424 字节 · `a339f899c9fbded0830c05bc998fb760b7f14fe09b011d9cb715f095896fa183` |
| 底包 | HyperOS **OS4.0.2.0.XOLCNXM**（Android 17） |
| 上游 | `kirklin/skyward` @ `ff1668f`（v0.2.0）+ 8 个补丁 |
| 真机 | ✅ 已刷入 onyx 并验证：触摸服务、`/data` 自动挂载、user 0 CE（`/data/media/0` 与相册 JPEG 可读）、WLAN 自动连接（`CMCC-A9s7-5G`，`192.168.1.227`）、振动驱动；用 `sendevent` 注入触摸验证滑动锁屏；电源键注入验证息屏/点亮后先显示滑动锁屏（背景为上一页的模糊快照，浅色/深色，可调强度）；5 GHz WLAN 连上 `CMCC-A9s7-5G`（5260 MHz）；唤醒黑屏已修（面板不再 rest/off，息屏只关背光） |
| 风险 | ⚠️ 需要解锁 bootloader；只刷 recovery 分区，详见[安装](docs/04-install.md) |

> **一句话结论**：不需要 weaver，也不需要 OMAPI 桥。onyx 的 user 0 有两份 protector，其中一份绑在 gatekeeper 上；weaver 不可用时回退到它，用同一个锁屏密码即可拿到合成密码（SP），解开 CE。详细原理见[设计思路](docs/05-design-notes.md)。

### 能力

| 能力 | 状态 | 说明 |
| --- | --- | --- |
| 触摸 | ✅ | 拉起 `/odm/bin/touch_report_debug`，由 `libtouchreport.so` 把 raw 帧转成触摸 |
| `/data` 设备级解密 | ✅ | qseecomd / keymint / gatekeeper / secure_element / weaver / boot 六个服务就位，开机自动挂载 |
| user 0 CE（相册 / 微信） | ✅ | 锁屏密码 → gatekeeper 绑定的第二份 protector → SP → CE key；真机验证 JPEG / 微信目录可读 |
| user 999（第二空间 / 应用分身） | ❌ | 只有 weaver 绑定的 protector，recovery 里没有 eSE 通道；解密页现在只等 user 0，不再被 999 卡住 |
| adb root | ✅ | recovery 内 adb 是 root，无需手机授权 |
| 备份 / 安装 / 文件管理 / 终端 | ⚠️ | 上游能力，随镜像提供；未逐项真机验证 |
| MTP | ⚠️ | 已带 `skyward-mtp.rc`，未逐项验证 |
| WLAN | ✅ | `qca_cld3_wcn7750` + `rfkill` 从 vendor_dlkm 加载；wpa_supplicant 用 `skyward/wpa-aidl-shim.so` 跳过 recovery 不认的 AIDL 注册；开机自动连接上次网络（密码存 `/metadata`，0600） |
| Skyward 在线更新 | ✅ | 高级 → 「Skyward 更新」；查 `Remoparrot/skyward-onyx` 的 Release，优先下裸 `recovery.img`、没有才取 zip；下载最多 512 连接并行（45.85 MB 实测 17.2 s），需要 WLAN |
| 从本地 recovery.img 刷入 | ✅ | 同一页把 `/sdcard/Download/recovery.img` 校验后写入 recovery 分区，不需要网络；onyx.2 → onyx.3 实测 |
| 首页机型卡片读数 | ✅ | 机型名/底包下四列：当前槽位 / 数据分区 / 可用空间 / 电量（充电时写充电中）；读不到的项自动省略，解密完成后补上可用空间 |
| 振动 | ✅ | AW8697（`awinic_haptic`，i2c 5-005a）的 `activate` / `duration` / `gain`；设置页滑杆与触摸反馈走同一路径 |
| recovery 锁屏 | ✅ | 每次息屏再点亮都先显示滑动锁屏（日期 / 时钟 / 电量 / 滑动解锁），解锁回原页面；背景是上一页的模糊快照（浅色/深色），设置页可调模糊强度；开机首屏直接是解密页（data 解密前不锁屏）；设置 4–8 位 recovery 密码后改为数字键盘；只存 salt + SHA-256 |
| 双击亮屏 | ✅ | 息屏后 400 ms 内两次点击点亮；设置页可关 |
| 下载 | ✅ | 主界面「下载」：输入/粘贴网址后「开始下载」；进度卡显示网速，可暂停/继续/停止；文件存 `/sdcard/Download`，名字取网址最后一段。与 Skyward 更新共用同一套 512 连接并行分段（服务端支持 `Range` 时，不支持自动退回单连接）；也可从 `/sdcard/Download/link.txt` 读链接。二维码让另一台手机扫码输入网址回传（需先连 WLAN）。图形浏览器在 onyx.5 已按要求删除 |
| 网页（纯文本） | ⚠️ | 下载页里按键盘「确定」，按输入的网址打开上游的网页页：取回标题、正文和链接（不解析样式、不下载图片）。浏览器删除后保留这一项，未逐项真机验证 |
| 禁用 AVB 2.0 | ⚠️ | 高级 → 「禁用 AVB 2.0」页，写入当前槽位 vbmeta；**按要求未在真机点过** |
| 自动打开解密页 | ✅ | 正常进 recovery 首屏即「解密」，自动打开 `/data`（解密前不锁屏）；记住密码时自动解锁 |
| 记住解锁密码 | ✅ | 解密页「记住密码，下次自动解密」打开后，成功解锁即保存；下次开机自动解密 user 0。密码明文存 `/metadata/skyward/settings.json`（0600），换机/共享镜像前删掉 |
| 解密完成倒计时 | ✅ | data 打开后「完成」后面显示「完成 · N 秒后进入主界面」，3 秒后自动回主界面；点「完成」可立即走 |
| 双系统 / OTA / fastbootd | ⚠️ | 未在 onyx 上验证，不建议依赖 |

---

## 这是什么

Skyward 不是 TWRP 的换皮，也不是 AOSP recovery：它用 Rust 从零写了一套 recovery，**在原厂 recovery 的 ramdisk 上替换掉 `system/bin/recovery` 及其依赖**，内核仍由 boot 分区提供。因此它不需要 AOSP 源码树，也不会改动 boot / system / vendor。

本仓库是 onyx 的**设备移植**，包含：

1. `devices/onyx.toml` —— 设备配置：屏幕、触摸服务、安全世界服务、底包信息；
2. `patches/` —— 相对上游 v0.2.0 的四个补丁（Windows 宿主构建、OMAPI→SE 桥、onyx CE 回退、v0.3.0 的 OS4/WLAN/UI）；
3. `scripts/` —— 一条链的构建、取原厂镜像、打包、校验脚本；
4. `shim/` —— 让 vendor 的 AIDL `wpa_supplicant` 在 recovery 里跑起来的 `LD_PRELOAD` 小库（源码，构建时编进 ramdisk）；
5. `docs/` —— 架构、构建、刷入、设计、踩坑、排错、版本记录与会话记录。

镜像本身、原厂回滚镜像和 zip 在 [Releases](https://github.com/Remoparrot/skyward-onyx/releases) 里，不进仓库（单个 100 MB，超过 GitHub 单文件上限）。

### 设备

| 项 | 值 |
| --- | --- |
| 机型 | Redmi Turbo 4 Pro |
| 代号 | `onyx` |
| SoC | 第四代骁龙 8s（SM8735） |
| 屏幕 | 1280 × 2772，6.83"，density 512（400 dp 宽） |
| 分区 | A/B；recovery 为独立分区，大小 100 MB |
| 底包 | OS4.0.2.0.XOLCNXM（Android 17） |
| 触摸 | Novatek NT38771 + 小米触摸层（raw 帧） |

---

## 安装（刷入）

> 前提：bootloader 已解锁、电脑有 `adb` / `fastboot`、手机电量充足。**第一次刷之前先备份**。

1. 到 [Releases](https://github.com/Remoparrot/skyward-onyx/releases) 下载 `recovery.img` 与 `SHA256SUMS`，核对：

   ```sh
   sha256sum -c SHA256SUMS --ignore-missing
   ```

2. 手机进 fastboot：

   ```sh
   adb reboot bootloader
   fastboot devices
   ```

3. 刷入并重启到 recovery：

   ```sh
   fastboot flash recovery recovery.img
   fastboot reboot recovery
   ```

4. 第一次进入后：

   - 首屏是「解密」，自动打开 `/data`；首页能看到 `Redmi Turbo 4 Pro / onyx / OS4.0.2.0…`；
   - 触摸正常，说明 `touch_report_debug` 已拉起；
   - 在「解密」页输入**锁屏密码**，`/data` 与 `/data/media/0` 出现真实文件名；
   - 相册、微信目录可读，即 user 0 CE 已解开。

5. 回滚（随时可以）：

   ```sh
   fastboot flash recovery recovery-stock-OS4.0.2.0.XOLCNXM.img
   ```

刷 recovery 分区不会动 boot / system / userdata；即使 recovery 起不来，手机也能正常进系统，再用上面的命令刷回官方即可。完整步骤、风险与排错见 **[安装与回滚](docs/04-install.md)**。

> ⚠️ **不要在 recovery 里执行 `setprop ctl.stop recovery`**。本机实测两次都会导致整机重启（原因未查清）。换 UI 版本请直接刷镜像。
>
> ⚠️ recovery 里的 adb 是 **root 且无需授权**：手机在 recovery 时，任何人拿到手机和数据线都能读存储。用完请重启回系统。

---

## 从源码构建

不需要 AOSP。需要 Rust、Android NDK、MinGW-w64（仅 Windows 宿主）和 `lz4`。参考构建环境：

| 组件 | 版本 / 说明 |
| --- | --- |
| 宿主 | Windows 10/11 + MSYS2 bash（参考）；Linux 理论可行，未实测 |
| Rust | 1.99.1，`stable-x86_64-pc-windows-gnu` |
| Android NDK | r29（29.0.14206865） |
| MinGW-w64 | gcc 16.2.0 + binutils 2.47（只用于链接宿主侧 `skyward-pack`） |
| lz4 | 1.10.0，需在 `PATH` 上 |

```sh
git clone https://github.com/Remoparrot/skyward-onyx.git
cd skyward-onyx

# 1) 取上游 v0.2.0 并打 4 个补丁（只需一次）
scripts/bootstrap.sh

# 2) 指定 NDK 并自检
export ANDROID_NDK=/path/to/android-ndk-r29
scripts/check-deps.sh

# 3) 编译宿主打包器 + 取原厂 recovery + 编译手机侧两个二进制
scripts/build-pack.sh
scripts/fetch-stock.sh
scripts/build-phone.sh
scripts/build-system-init.sh

# 4) 打镜像并校验
scripts/build-image.sh
scripts/verify-image.sh out/skyward-v0.3.0-onyx.1-OS4.0.2.0.XOLCNXM.img
```

Windows 上有三个容易踩的点，脚本已经处理：`dlltool` 的系统临时目录不可写（改用仓库内 `tmp/`）、MSYS 的 `link.exe` 遮蔽 MSVC 链接器（强制 gnu 宿主工具链）、上游 `ramdisk.rs` 里有 Unix-only 代码（补丁 0001 用 `#[cfg(unix)]` 围起来）。

完整工具链、命令、校验方法和可复现性说明见 **[构建](docs/03-build.md)**。

---

## 仓库结构

```
README.md                     对外说明：是什么 / 怎么装 / 去哪下载
agent.md                      AI 与人类协作者的工作流（强制）
LICENSE                       GPL-3.0
NOTICE.md                     上游与第三方声明
SHA256SUMS                    发布产物的校验和
devices/onyx.toml             设备配置（屏幕、服务、底包）
patches/                      相对上游 v0.2.0 的补丁（按顺序应用）
  0001-windows-host-build.patch
  0002-omapi-se-bridge.patch
  0003-onyx-ce-fallback.patch
  0004-onyx-v0.3.0-wifi-ui.patch
shim/wpa-aidl-shim.c          AIDL wpa_supplicant 的 LD_PRELOAD 小库（源码）
scripts/                      bootstrap / 构建 / 取原厂镜像 / 打包 / 校验
docs/                         文档（入口 docs/README.md）
stock/                        原厂 recovery 的获取说明（镜像不进仓库）
out/                          本地构建输出（ignored）
```

---

## 文档

- **第一次来 / 新开一个 AI 会话** → [agent.md](agent.md) → [文档地图](docs/README.md) → [当前状态](docs/00-status.md)
- 想弄清原理 → [概览](docs/01-overview.md) + [架构](docs/02-architecture.md) + [设计思路](docs/05-design-notes.md)
- 想自己编 → [构建](docs/03-build.md)
- 想刷机 / 回滚 → [安装](docs/04-install.md)
- 出问题了 → [排错](docs/08-troubleshooting.md) + [踩坑记录](docs/06-pitfalls.md)
- 想看版本变化 → [版本记录](docs/07-changelog.md)
- 想接手上一次的工作 → [会话记录](docs/sessions/)

## 协作与记录

这个仓库把「文档」当项目的一部分，而不是附属品：

- 每次 AI / 人类会话结束前，**必须**在 [`docs/sessions/`](docs/sessions/) 写一份 7 节齐全的会话记录；
- 版本变化同步 [版本记录](docs/07-changelog.md)，新坑同步 [踩坑记录](docs/06-pitfalls.md)；
- 新增文档登记到 [文档地图](docs/README.md)。

**新开一个对话时，把这句话发给 AI：**

> 读 `agent.md`、`docs/00-status.md`、`docs/README.md` 和 `docs/sessions/` 最新一份记录，
> 先用 5 行给我接手确认，在我确认之前不要改代码、不要刷机。

---

## 已知问题（摘要）

- **停 recovery 服务会重启整机**：不要 `setprop ctl.stop recovery`。
- **偶发黑屏 / 重启**：两次对应上面停服务；其余原因未查清（`pstore` 为空）。出现时先看 `adb shell dmesg | tail` 与 `/sys/fs/pstore`。
- **user 999 仍锁着**：只有 weaver 绑定的 protector，不影响 user 0。
- **WLAN / 振动已启用**：WLAN 依赖 `skyward/wpa-aidl-shim.so`；换底包后要重新核对 `[wlan]` 的路径、服务名与 AIDL 行为。
- **这是为 onyx + OS4.0.2.0 构建的移植**：换底包后服务路径 / VINTF 可能变化；刷前先确认 stock 回滚镜像。
- **AVB 2.0 禁用页未实测**：改的是 vbmeta，误操作可能让系统起不来；没有回滚手段不要点。

完整清单与处置见 **[排错](docs/08-troubleshooting.md)**。

---

## 许可与致谢

- 本仓库的移植代码、脚本与文档：[GPL-3.0](LICENSE)（与上游一致）。
- 上游：[kirklin/skyward](https://github.com/kirklin/skyward)，GPL-3.0，Rust 写的 recovery。
- 字体：`MiSansVF.ttf`（小米）、`KirkMono-Regular.ttf`（OFL-1.1，见 `KirkMono-OFL.txt`），随上游源码分发，本仓库不再单独附带。
- 原厂 recovery / 固件归小米通讯技术有限公司所有；本项目与小米、Redmi 无隶属关系，不分发完整固件包。
- `android.se.omapi` / `android.hardware.secure_element` 的接口定义归 AOSP（Apache-2.0）；本仓库只按 AIDL 布局做最小实现。

仓库名 `skyward-onyx`；上游项目名 **Skyward**；设备代号 **onyx**。

---

## English

A device port of [Skyward](https://github.com/kirklin/skyward) (a Rust recovery) for the **Redmi Turbo 4 Pro (`onyx`)**, built on HyperOS `OS4.0.2.0.XOLCNXM`. Touch works, `/data` auto-decrypts, **user 0's credential-encrypted storage (photos, WeChat) unlocks with the lock-screen password**, and WLAN auto-connects, vibration, a recovery lock (shown on every screen-on), and double-tap-to-wake are included. Only the recovery partition is written; roll back with the stock image from the release. See [`docs/`](docs/README.md) for the full build, design, and troubleshooting notes (Chinese).
