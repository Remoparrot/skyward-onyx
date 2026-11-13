# 当前状态

> 状态：**现行**
> 最后更新：2026-11-13
> 对应版本：`v0.2.0-onyx.4`
> 设备：Redmi Turbo 4 Pro（`onyx`）· 底包 OS3.0.306.0.WOLCNXM（Android 16）

---

## 1. 当前版本

| 项 | 值 |
| --- | --- |
| 版本 | `v0.2.0-onyx.4`（onyx 移植第 4 版） |
| 构建日期 | 2026-11-12 |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| 镜像 SHA-256 | `b41bee5b5342e5a2f0f32ba01e9a0cca3c0ab69b520799e4e29ee49957f1f83f` |
| ramdisk | 49,643,317 字节（LZ4）· 996 个 cpio 条目 |
| 内含 skyward | 8,619,216 字节 · `51e902f6995918df4ff430c2acccdbaaa29ee00e8963588029a1f7423e86c7e5` |
| zip | `skyward-v0.2.0-onyx-OS3.0.306.0.WOLCNXM.zip` · 45,324,069 字节 · `667e0163…abb87` |
| 原厂 recovery | `recovery-stock-OS3.0.306.0.WOLCNXM.img` · 104,857,600 字节 · `99047b63…549a2` |
| 上游 | `kirklin/skyward` @ `ff1668fdb72a46f22152a6540f49728c42081aba`（v0.2.0） |
| 真机 | ✅ 已刷入 onyx；触摸、`/data` 自动挂载、user 0 CE 解锁均已验证 |

发布资产在 [Releases](https://github.com/Remoparrot/skyward-onyx/releases)；仓库内只有源码、补丁、配置和文档。

### 历史镜像

| 版本 | 镜像 SHA-256 | 结果 |
| --- | --- | --- |
| v1 | `78bbf0527829e78e35399ce6cba070181dad5066e54b8c7ce97d10bac2df6640` | 首次构建；密度错、无触摸 |
| v2 | `9ae3c85e6db90f7802f217b75279e5ee81aacfa19377984c4cb41913d93ef9dd` | 密度修好；仍无触摸（`touch_report` 不存在） |
| v3 | `b1374ccd3e58017de8e9e794045f446525098f21fce0d6192ea2c5905017b5ee` | 触摸、`/data` 设备级解密修好；user 0 CE 仍锁 |
| v4 | `b41bee5b5342e5a2f0f32ba01e9a0cca3c0ab69b520799e4e29ee49957f1f83f` | **当前**；user 0 CE 解开 |

v3 备份镜像保留在本机 `skyward-onyx/recovery-v3-backup.img`，不随 Release 分发。

---

## 2. 已验证（真机）

验证环境：onyx，HyperOS `OS3.0.306.0.WOLCNXM`，bootloader 已解锁，刷入方式 `fastboot flash recovery`。

| 项 | 证据 |
| --- | --- |
| 镜像结构 | `header v4  kernel 0 bytes  ramdisk 49643317 bytes`；`skyward-pack list` 996 条；`OriginalImageSize=49635328` |
| 二进制一致 | 镜像内 `system/bin/recovery` = 8,619,216 字节，sha256 与编译产物一致 |
| 触摸 | 刷入后可正常滑动 / 点击；`/dev/input/event7` 直接 `getevent` 90 秒零事件，证明触摸来自 `touch_report_debug` |
| `/data` 自动解密 | 开机日志 `mounted ... /data`、`the check of /dev/block/dm-8 ended with 0`；`/data/app`、`/data/misc` 可读 |
| user 0 CE | 界面「解密」页输入锁屏密码后，`/data/media/0` 出现真实文件名；相册 89 张、JPEG 头 `ffd8ffe1` 正常；`/data/data/com.tencent.mm`、`/data/media/0/Android/data/com.tencent.mm` 可读 |
| f2fs | 检查 0 错误 |
| 数据未被改动 | 只刷 recovery 分区；`/data` 只读挂载验证；重启后系统正常进入 |
| 回滚 | `fastboot flash recovery recovery-stock-…img` 可用 |

> 早期测试中两次黑屏重启，均对应执行了 `setprop ctl.stop recovery`；之后不再使用该命令。

---

## 3. 未验证 / 已知限制

| 项 | 状态 | 说明 |
| --- | --- | --- |
| user 999（第二空间 / 应用分身） | ❌ | 只有 weaver 绑定的 protector；recovery 没有 eSE 通道，锁屏密码也打不开 |
| WLAN | ❌ | `onyx.toml` 没有 `[wlan]` 段，设置页不出现；WCN7750 的固件路径未在真机核对 |
| 振动 | ❌ | `aw8697-haptic` / `qcom-hv-haptics` 的 sysfs 未核实，未配置 |
| 备份 / 安装 / 文件管理 / 终端 / MTP | ⚠️ | 上游能力，镜像里带了对应 rc / 资源，但未在 onyx 上逐项验证 |
| 双系统 | ⚠️ | 上游功能，未验证；需要额外的 `[partitions]` / metadata 条件，不建议在主力机试 |
| OTA / 自动重刷 | ⚠️ | 需要 WLAN 与 update 服务，当前不可用 |
| fastbootd | ⚠️ | 未验证 |
| 更换底包 | ⚠️ | 本镜像只对 OS3.0.306.0.WOLCNXM 验证；换版本后服务路径 / VINTF 可能变 |
| `setprop ctl.stop recovery` | ❌ | 实测会重启整机，禁止使用 |
| 偶发黑屏 | ⚠️ | 两次对应停服务；其余原因未查清（`pstore` 为空，`bootinfo.pureason=0x40001`） |

---

## 4. 当前阻塞 / 下一步

按优先级：

1. **（可选）user 999**：需要让 weaver 在 recovery 里真正访问 eSE。OMAPI→SE 桥代码已在 `patches/0002`，卡在 SE HAL 的 `init()` 不返回（eSE TA 未起来）。继续做要小心，历史上有黑屏重启。
2. **WLAN**：从 vendor 分区核对 `qca_cld3_wcn7750` 固件路径、`WCNSS_qcom_cfg.ini`、`wpa_supplicant`，再补 `[wlan]`；需要真机。
3. **振动**：确认 `aw8697-haptic` / `qcom-hv-haptics` 的 sysfs，再补配置；需要真机。
4. **逐项验证上游能力**：安装 zip、备份 / 恢复、MTP、双系统；每项都要单独记录「验证到哪一步」。
5. **底包升级适配**：HyperOS 4 / 新版本的安全世界服务路径、VINTF fragment 可能变化，需要重新对 `onyx.toml`。

---

## 5. 构建环境（参考）

| 组件 | 版本 |
| --- | --- |
| 宿主 | Windows 10/11 + MSYS2 bash |
| Rust | 1.99.1 `stable-x86_64-pc-windows-gnu`，target `aarch64-linux-android` |
| Android NDK | r29（29.0.14206865） |
| MinGW-w64 | gcc 16.2.0 + binutils 2.47 |
| lz4 | 1.10.0（PATH） |
| 原厂包 | `onyx-ota_full-OS3.0.306.0.WOLCNXM-user-16.0-17ed95af98.zip` |

完整命令见 [`03-build.md`](03-build.md)。

---

## 6. 发布检查单

- [x] 镜像大小 104,857,600
- [x] 头部 v4 / kernel 0 / ramdisk 49,643,317
- [x] `system/bin/recovery`、`skyward/system-init`、`skyward/device.toml` 存在
- [x] 镜像内二进制与编译产物 sha256 一致
- [x] 原厂 recovery 的 sha256 与配置 `[stock] recovery` 一致
- [x] 真机：触摸 / `/data` / user 0 CE
- [x] `SHA256SUMS` 已更新
- [x] `docs/07-changelog.md` 顶部已记录
- [x] README 版本 / 哈希表已更新
- [ ] user 999（明确不做）
- [ ] WLAN / 振动（明确未做）
