# 版本记录

> 状态：**现行**
> 规则：新版本加在**顶部**；旧条目只能追加勘误，不能改写。
> 版本格式：`v<上游版本>-onyx.<n>`。

---

## v0.3.0-onyx.1 · 2026-11-13

**主题：OS4 底包 + WLAN 自动连接 + 振动 + 锁屏（每次亮屏）/ 双击亮屏 + 自动解密页**

| 项 | 值 |
| --- | --- |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| SHA-256 | `73016303620c5d59a72b608ba2dd1684bbc888b1ec4620cf3aed0eec26fd760c` |
| 内含 skyward | 8,655,096 字节 · `0ec8397febf8931e8aafc37bb1e428e7f2c7a1780458cf575187a505164c9a87` |
| ramdisk | 50,623,471 字节 · 1062 条 |
| 底包 | OS4.0.2.0.XOLCNXM（Android 17） |
| zip | `skyward-v0.3.0-onyx.1-onyx-OS4.0.2.0.XOLCNXM.zip` · 45,801,113 字节 · `e8df16ad…d636` |
| 原厂 recovery | `recovery-stock-OS4.0.2.0.XOLCNXM.img` · `ce538507…cd3357` |

### 改了什么

- **底包**：`[stock]` 从 OS3.0.306.0 换到 OS4.0.2.0.XOLCNXM；版本号改为 `0.3.0-onyx.1`；`has_root` 代替 `is_absolute` 以兼容 Windows 宿主校验。
- **WLAN**：`[wlan]` 配置 `qca_cld3_wcn7750` + `rfkill`，`wpss_boot` / `wlan_en_delay`，固件从 vendor 与 persist 取；`wlan.rs` 对 `EBUSY` 重试、启动自动开 WLAN；`wpa-aidl-shim` 让 AIDL supplicant 跳过 recovery 不认的 `addService`；UI 保存上次网络并在下次启动自动加入。
- **振动**：AW8697 的 sysfs 后端（`activate` / `duration` / `effect_id` / `gain`），`skyward haptic` 可测。
- **UI**：图 1 滑动锁屏（有 4–8 位 recovery 密码时改数字键盘）；**每次息屏再点亮都先显示**，解锁回原页；开机首屏滑动后自动进入解密页；双击亮屏；AVB 2.0 禁用页（未测）。控制中心已按用户要求删除。
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
- 锁屏滑动已用注入触摸验证；4–8 位键盘、双击亮屏未逐项点过；
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
