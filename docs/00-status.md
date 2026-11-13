# 当前状态

> 状态：**现行**
> 最后更新：2026-11-13
> 对应版本：`v0.3.0-onyx.1`
> 设备：Redmi Turbo 4 Pro（`onyx`）· 底包 OS4.0.2.0.XOLCNXM（Android 17）

---

## 1. 当前版本

| 项 | 值 |
| --- | --- |
| 版本 | `v0.3.0-onyx.1`（OS4 底包 + WLAN / 振动 / UI） |
| 构建日期 | 2026-11-13 |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| 镜像 SHA-256 | `84ec2df675c150941537acbc8151231ce14e5d8a908dfde79fa5c6b18faa8103` |
| ramdisk | 50,626,095 字节（LZ4）· 1062 个 cpio 条目 |
| 内含 skyward | 8,655,096 字节 · `7aa1920f618c2151dab4f0ffa7690f5d8648dba2090bb6d9b112f0a11e6fb90c` |
| zip（在线更新用） | `skyward-v0.3.0-onyx.1-onyx-OS4.0.2.0.XOLCNXM.zip` · 45,804,158 字节 · `0d3f0bfcae34a5c64373047933e1f3385f9bd09c06b1b73435a36977abe85a90` |
| 原厂 recovery | `recovery-stock-OS4.0.2.0.XOLCNXM.img` · 104,857,600 字节 · `ce53850714fe2ca9ab22600a00e71813df2775dc94244192c83a224d7ecd3357` |
| 上游 | `kirklin/skyward` @ `ff1668fdb72a46f22152a6540f49728c42081aba`（v0.2.0）+ 0001–0004 |
| 真机 | ✅ 已刷入 onyx：触摸服务、`/data` 自动挂载、WLAN 自动连接、振动驱动、自动进入解密页；锁屏/控制中心/双击亮屏已实现，见第 3 节 |

发布资产在 [Releases](https://github.com/Remoparrot/skyward-onyx/releases)；仓库内只有源码、补丁、配置和文档。

### 历史镜像

| 版本 | 镜像 SHA-256 | 结果 |
| --- | --- | --- |
| v1 | `78bbf052…6640` | 首次构建；密度错、无触摸 |
| v2 | `9ae3c85e…9dd` | 密度修好；仍无触摸 |
| v3 | `b1374ccd…b5ee` | 触摸、`/data` 设备级解密修好；user 0 CE 仍锁 |
| v4 | `b41bee5b…f83f` | user 0 CE 解开；OS3.0.306.0 底包 |
| v0.3.0-onyx.1 | `baf93862…78b0` | **当前**；OS4.0.2.0 底包；WLAN / 振动 / 锁屏 / 控制中心 / 双击亮屏 / 自动解密页 / AVB 页 |

---

## 2. 已验证（真机）

验证环境：onyx，HyperOS `OS4.0.2.0.XOLCNXM`，bootloader 已解锁，刷入方式 `fastboot flash recovery`。

| 项 | 证据 |
| --- | --- |
| 镜像结构 | `header v4  kernel 0 bytes  ramdisk 50625278 bytes`；`skyward-pack list` 1062 条 |
| 版本 | `dmesg`：`onyx 0.3.0-onyx.1 recovery up` |
| 触摸服务 | `touch_report_debug` 由 `prepare()` 拉起；本次未逐项做滑动验证（v4 已验） |
| `/data` 自动打开 | `dmesg`：`/dev/block/dm-9 holds f2fs at /data`；首屏即「解密」 |
| WLAN 扫描 | 5 GHz / 2.4 GHz 共 20+ 个网络；`wpa_state=COMPLETED`，SSID `CMCC-A9s7-5G`，`key_mgmt=SAE` |
| WLAN 自动连接 | 重启 recovery 后自动连上，`ifconfig wlan0`：`192.168.1.227/24`，IPv6 全局地址；密码由 `/metadata/skyward/settings.json` 保存（0600） |
| 振动 | `skyward haptic --config /skyward/device.toml`：驱动 `awinic_haptic` 进入 RAM 模式，`level=0x40`，`duration=16`；实际振感待用户确认 |
| recovery 锁屏（启动） | 种入 4 位锁后重启：UI 存活、`/data` **没有**挂载；移除锁后恢复自动解密 |
| 自动连接持久化 | 自动连接之后 settings 中的 `wlan.password` 仍为原密码（修复了首次自动连接会把密码写空的问题） |

> 早期测试中两次黑屏重启，均对应执行了 `setprop ctl.stop recovery`；之后不再使用该命令。

---

## 3. 未验证 / 已知限制

| 项 | 状态 | 说明 |
| --- | --- | --- |
| user 0 CE（相册 / 微信） | ⚠️ | 逻辑沿用 v4；本次没有在 OS4 底包上重新输入用户锁屏密码验证 `/data/media/0` |
| user 999（第二空间 / 应用分身） | ❌ | 只有 weaver 绑定的 protector；recovery 没有 eSE 通道 |
| recovery 锁屏（输入解锁） | ⚠️ | 启动锁屏与「未解锁不打开 data」已验；4 位码输入解锁未在真机手动点过（逻辑有单元测试，未跑） |
| 控制中心 | ⚠️ | 从屏幕顶部下滑打开，面板从上方落下；未在真机手动打开逐项点过 |
| 双击亮屏 | ⚠️ | 已实现（息屏 400 ms 内两次点击）；本次没有可注入真机触摸的手段，未手动验证 |
| 禁用 AVB 2.0 | ⚠️ | 页面与 `avbctl` 调用已实现；**按要求未测试** |
| Skyward 在线更新 | ⚠️ | 已指向 `Remoparrot/skyward-onyx`，asset 命名与版本比较已改；没有「更新到更高版本」可测，未跑完整下载/写入 |
| WLAN 密码安全 | ⚠️ | 明文存 `/metadata/skyward/settings.json`（0600）；recovery 内 adb 本来就是 root，但共享镜像/换机前应删掉 |
| 振动强度 | ⚠️ | 驱动 `gain` 0x00–0x80 映射；实际振感与强度曲线待用户确认 |
| 备份 / 安装 / 文件管理 / 终端 / MTP | ⚠️ | 上游能力，未逐项验证 |
| 双系统 / OTA / fastbootd | ⚠️ | 未在 onyx 上验证，不建议依赖 |
| 换底包 | ⚠️ | 本镜像只对 OS4.0.2.0.XOLCNXM 验证；换版本后服务路径 / VINTF / WLAN 固件路径可能变 |
| `setprop ctl.stop recovery` | ❌ | 实测会重启整机，禁止使用 |

---

## 4. 当前阻塞 / 下一步

1. **user 0 CE 在 OS4 底包回归**：由用户输入锁屏密码，确认 `/data/media/0`、相册与微信目录可读。
2. **WLAN 自动连接的用户可见验证**：在 UI「解密」页输入锁屏密码后，确认 WLAN 图标/设置页显示已连接。
3. **锁屏输入、控制中心、双击亮屏**：需要真机触摸逐项点；这次只验证了启动路径。
4. **Skyward 在线更新**：发一个更高的 `v0.3.0-onyx.2` 测试「检查 → 下载 → 写入 recovery」；当前版本只能验证「已是最新」。
5. **AVB 2.0**：用户明确不测试；如果以后要测，先备份 `vbmeta_a/b` 与 boot，并确认能 `fastboot flash vbmeta` 回滚。
6. **WLAN AIDL shim 的上游化**：现在靠 `LD_PRELOAD` 应答 `AServiceManager_addService`；如果 vendor 更新后 supplicant 行为变化，需要重新对。
7. **user 999**：仍然只有 weaver 绑定的 protector，收益低、风险高，暂不做。

---

## 5. 构建环境（参考）

| 组件 | 版本 |
| --- | --- |
| 宿主 | Windows 10/11 + MSYS2 bash |
| Rust | 1.99.1 `stable-x86_64-pc-windows-gnu`，target `aarch64-linux-android` |
| Android NDK | r29（29.0.14206865） |
| MinGW-w64 | gcc 16.2.0 + binutils 2.47 |
| lz4 | 1.10.0（PATH） |
| 原厂包 | `onyx-ota_full-OS4.0.2.0.XOLCNXM-user-17.0-dbe344d29d.zip` |

完整命令见 [`03-build.md`](03-build.md)。

---

## 6. 发布检查单

- [x] 镜像大小 104,857,600
- [x] 头部 v4 / kernel 0 / ramdisk 50,626,095
- [x] `system/bin/recovery`、`skyward/system-init`、`skyward/device.toml`、`skyward/wpa-aidl-shim.so` 存在
- [x] 镜像内二进制与编译产物 sha256 一致
- [x] 原厂 recovery 的 sha256 与配置 `[stock] recovery` 一致（`ce538507…`）
- [x] 真机：触摸服务 / `/data` 自动打开 / WLAN 自动连接 / 振动驱动
- [x] `SHA256SUMS` 已更新
- [x] `docs/07-changelog.md` 顶部已记录
- [x] README 版本 / 哈希表已更新
- [ ] user 0 CE 在 OS4 上重新输入密码（待用户）
- [ ] 锁屏输入 / 控制中心 / 双击亮屏（待真机触摸）
- [ ] AVB 2.0（明确不测试）
