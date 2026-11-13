# onyx 首次移植：v1 → v3（2026-11-11 ~ 2026-11-12）

状态：已完成
关联版本：无 → v0.2.0-onyx.3
关联提交：仓库首次提交（后补）

## 1. TL;DR

用上游 Skyward v0.2.0 在官方 `OS3.0.306.0.WOLCNXM` 的 stock recovery 上重打包，做出 onyx 的第一个可启动镜像；修好 density 与触摸，补齐 6 个安全世界服务让 `/data` 自动解密，但 user 0 的 CE 仍锁——当时判断卡在 weaver / OMAPI。最终 v3 镜像 `b1374ccd…17b5ee` 已刷入真机验证。

## 2. 对话重点

- 用户要求：编译一个「最近很火的 skyward」第三方 recovery，适配红米 Turbo 4 Pro，编完发 `recovery.img`。
- 用户强调：**数据很重要，不要清数据**；解密不了 data 要在不清数据的前提下修。
- 用户反馈：第一版 UI 大小不对、没有触摸；第二版仍无触摸；刷入后黑屏两次。
- 明确决策：
  - 不走 AOSP 源码树，直接用 stock recovery 重打包；
  - density 用 512（400 dp 宽），不用 1109；
  - 触摸改拉起小米自己的程序，不自己解析 raw 帧；
  - 补 qseecomd / keymint / gatekeeper / secure_element / weaver / boot 六个服务；
  - 不做 WLAN / 振动（没真机核对，怕起不来）。
- 范围外但被提到：WiFi 选项没有；后续再说。

## 3. 修复内容

| 文件 | 改了什么 | 为什么 |
| --- | --- | --- |
| `devices/onyx.toml` | 新建；display 1280×2772 / 512；modules `nt38771_touch` + `xiaomi_touch`；7 个 `[[service]]`；`[stock]` 底包信息 | 设备适配的核心 |
| `devices/onyx.toml`（v2） | density 1109 → 512 | 按屏高反推错误，UI 放大 2.2 倍 |
| `devices/onyx.toml`（v2） | 触摸服务改为拉起 `touch_report` | 原厂触摸只回 raw 帧 |
| `devices/onyx.toml`（v3） | `touch_report` → `touch_report_debug` | onyx 没有非 debug 版本 |
| `devices/onyx.toml`（v3） | 补 qseecomd / keymint / gatekeeper / secure_element / weaver / boot | 解 `/data` 设备级加密 |
| `crates/skyward-bootimg/src/ramdisk.rs` | Unix-only 函数加 `#[cfg(unix)]`（后来成为 `patches/0001`） | Windows 上编宿主打包器 |
| 构建脚本 | gnu 宿主工具链、TMPDIR 改仓库内、NDK clang、lz4 | 本机无 MSVC / 无管理员权限 |
| 诊断页 | 屏幕打印 bring_up / 分区 / 模块 / input 设备 / dmesg | 无触摸时能直接定位 |

## 4. 设计思路

- **问题本质**：onyx 不在上游支持列表，stock recovery 的 ramdisk 是唯一可靠的底；AOSP 树太大且没必要。
- **方案 A：AOSP + device tree** —— 放弃，需要 250 GB+、没有现成 onyx recovery device tree。
- **方案 B：stock recovery 重打包** —— 选择，Skyward 上游就是这么设计的；只需要 Rust + NDK。
- **触摸**：方案 A「写 `enable_touch_raw=0` 让驱动自己上报」失败（节点无效）；方案 B「拉起 `touch_report`」失败（不存在）；方案 C「`touch_report_debug`」成功。
- **density**：按宽度 1280 ÷ 400 × 160 = 512；按高度会得到 1109，布局宽度只剩 184 dp。
- **数据安全**：全程只刷 recovery 分区，`/data` 只读挂载。

## 5. 踩过的坑

1. **payload extent 用错单位**：现象是抽出的 recovery 头部不对；根因是 extent 是块号，脚本当字节偏移；解法是乘 block size；预防是优先用 `skyward-pack stock`。
2. **density 1109**：现象 UI 巨大溢出；根因按屏高反推；解法 512；预防按宽度算。
3. **`touch_report` 不存在**：现象诊断页提示 missing；根因 onyx 只有 `_debug`；解法改名；预防先 `ls /odm/bin`。
4. **`/dev/input/event7` 无事件**：现象 getevent 90 秒零事件；根因驱动只回 raw 帧；解法由 `touch_report_debug` 转坐标；预防不要拿 input 设备存在当触摸可用。
5. **VINTF 空文件**：现象所有服务注册失败；根因 `touch .w` 让清单变 NULL；解法删掉；预防不要用 touch 测可写。
6. **`setprop ctl.stop recovery` 重启**：现象黑屏、adb 断开；根因未查清；解法不要用；预防写进禁止事项。
7. **二进制命名 `recovery`**：现象子命令被忽略、recovery 再起一遍抢硬件；根因 argv[0] 判断；解法改名 `/tmp/skyward`；预防统一命名。
8. **MSYS `link.exe` / dlltool 临时目录**：现象链接失败；根因 msvc 默认 + `%TEMP%` 不可写；解法 gnu 工具链 + 仓库内 tmp；预防走脚本。

## 6. 验证与证据

```text
v1  78bbf0527829e78e35399ce6cba070181dad5066e54b8c7ce97d10bac2df6640
v2  9ae3c85e6db90f7802f217b75279e5ee81aacfa19377984c4cb41913d93ef9dd
v3  b1374ccd3e58017de8e9e794045f446525098f21fce0d6192ea2c5905017b5ee
```

- v1：`header v4  kernel 0 bytes`，996 条，`system/bin/recovery` 8.6 MB aarch64 PIE；可启动，无触摸。
- v2：density 512；诊断页显示 `/odm/bin/touch_report is missing`；仍无触摸。
- v3：触摸正常；`/data` 自动挂载；日志 `mounted ... /data`；`the users whose own files are still closed: [0, 999]`；user 0 CE 仍锁。
- 全程只刷 recovery 分区，`/data` 未改动；系统可正常启动。

未验证：WLAN、振动、MTP、备份 / 安装、双系统。

## 7. 未完成 / 下一步 / 风险

- **user 0 CE 仍锁**：下一步做 OMAPI → SE HAL 桥，或找别的回退；这正是 v4 的起点。
- **user 999 仍锁**：只有 weaver 绑定。
- **WLAN / 振动**：缺配置。
- **黑屏**：两次对应 `ctl.stop recovery`；其他原因未查清。
- 风险：继续碰 eSE / TEE 可能再次黑屏；任何改动前先确认 stock 回滚可用。
