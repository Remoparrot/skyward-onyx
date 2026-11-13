# 概览

> 状态：**现行**
> 读者：第一次接触本项目的人 / 新开的 AI 会话。

---

## 1. Skyward 是什么

[Skyward](https://github.com/kirklin/skyward) 是一个用 Rust 从零写的 Android recovery，不是 TWRP 的分支，也不是 AOSP recovery 的换皮。它有几个和传统 recovery 不同的地方：

- **不基于 AOSP 源码树**：它直接以设备原厂 recovery 镜像为底，替换 `system/bin/recovery` 和少量依赖，再按原分区大小重新打包；
- **复用原厂的安全世界服务**：qseecomd、keymint、gatekeeper、secure_element、weaver、boot 都由设备的 vendor 分区提供，recovery 只负责把它们拉起来；
- **UI 是 HyperOS / miuix 风格**：触摸、深浅色、中文界面；
- **功能齐全**：解密 data、安装 zip / img、备份恢复、文件管理、终端、MTP、双系统、OTA（具体到某台设备是否可用，要看移植）。

上游目前的正式支持机型是小米 17 Ultra（`nezha`）和小米 13 Ultra（`ishtar`），其余机型标「施工中」。onyx 不在上游支持列表里，本仓库就是把它补上。

## 2. 为什么要有这个仓库

红米 Turbo 4 Pro（`onyx`）有几个和上游示例机不一样的点：

| 差异 | 影响 |
| --- | --- |
| 触摸控制器只回传 raw 帧 | 直接读 `/dev/input/eventN` 收不到触摸，必须拉起小米自己的 `touch_report_debug` |
| 用户密钥绑在 NXP eSE 的 weaver 插槽 | recovery 里没有 system_server 的 OMAPI 服务，weaver 没法查槽位 |
| 但 user 0 还有第二份 gatekeeper 绑定的 protector | 可以绕过 weaver，用同一个锁屏密码解开 CE |
| 屏幕 1280 × 2772，400 dp 宽 | density 必须是 512，按屏高反推会算成 1109 |
| 安全世界服务依赖 VINTF fragment | 目录里一个坏文件就会让整份清单变 NULL，所有服务注册失败 |

这些差异不是「换个 device tree」就能解决的，所以本仓库把设备配置、源码补丁、构建链和真机结论都固化下来。

## 3. 本仓库是什么 / 不是什么

**是**：

- onyx 的设备配置 `devices/onyx.toml`；
- 相对上游 v0.2.0 的三个补丁（Windows 构建、OMAPI 桥、CE 回退）；
- 可复现的构建脚本（取上游、取原厂镜像、编译、打包、校验）；
- 真机验证记录、设计思路、踩坑、排错、版本记录；
- 一个可以直接刷的 Release 镜像。

**不是**：

- 上游 Skyward 的官方仓库（上游是 [kirklin/skyward](https://github.com/kirklin/skyward)）；
- 通用 recovery（只对 onyx + OS4.0.2.0.XOLCNXM 验证）；
- 完整 HyperOS 固件包的分发渠道；
- 数据恢复工具（它不会「找回」已删除的数据，只是让 recovery 能读已加密的 `/data`）。

## 4. 设备

| 项 | 值 |
| --- | --- |
| 机型 | Redmi Turbo 4 Pro |
| 代号 | `onyx` |
| SoC | 第四代骁龙 8s（SM8735） |
| 屏幕 | 6.83"，1280 × 2772，density 512（400 dp 宽） |
| 触摸 | Novatek NT38771 + 小米触摸层；`/odm/bin/touch_report_debug` + `libtouchreport.so` |
| 分区 | A/B；recovery 独立分区，104,857,600 字节 |
| 底包 | HyperOS OS4.0.2.0.XOLCNXM（Android 17） |
| 安全芯片 | NXP eSE（weaver 插槽 1 绑 user 0 的第一份 protector） |

## 5. 能力边界

| 能力 | 状态 | 备注 |
| --- | --- | --- |
| 触摸 | ✅ | 真机验证 |
| `/data` 设备级解密 | ✅ | 真机验证；开机自动挂载 |
| user 0 CE（相册 / 微信） | ✅ | 真机验证；锁屏密码 |
| user 999 | ❌ | 只有 weaver 绑定的 protector |
| adb root | ✅ | recovery 内无需授权 |
| 备份 / 安装 / 文件管理 / 终端 | ⚠️ | 上游能力，未逐项验证 |
| MTP | ⚠️ | 带 rc，未逐项验证 |
| WLAN | ✅ | 扫描 / 加入 / 重启自动连接；密码存 `/metadata`（0600） |
| Skyward 在线更新 | ✅ | 查 `Remoparrot/skyward-onyx` 的 Release；需要 WLAN |
| 振动 | ✅ | AW8697 sysfs；实际振感待用户确认 |
| recovery 锁屏 / 控制中心 / 双击亮屏 | ✅ | 控制中心从顶部下滑；已实现；锁屏输入 / 控制中心 / 双击亮屏未手动逐项点过 |
| 自动进入解密页 | ✅ | 正常进 recovery 首屏即解密 |
| 禁用 AVB 2.0 | ⚠️ | 已实现；按要求未测试 |
| 双系统 / OTA / fastbootd | ⚠️ | 未验证，不建议依赖 |

「⚠️」表示二进制里有、上游也支持，但**没有在 onyx 上逐项跑过**。不要把它当成「已经能用」对外承诺；v0.3.0-onyx.1 的诚实边界见 [`00-status.md`](00-status.md)。

## 6. 四次迭代

| 版本 | 做了什么 | 结果 |
| --- | --- | --- |
| v1 | 首次构建：stock recovery + skyward，密度 1109，`enable_touch_raw=0` | 能启动，UI 放大溢出，无触摸 |
| v2 | density 512；改拉起 `/odm/bin/touch_report`；加屏幕诊断 | 仍无触摸——onyx 没有 `touch_report`，只有 `_debug` |
| v3 | 改 `touch_report_debug`；补 qseecomd / keymint / gatekeeper / secure_element / weaver / boot | 触摸正常，`/data` 自动解密；CE 仍锁 |
| v4 | `data.rs` 在 weaver 不可用时回退到 gatekeeper 绑定的 protector | **user 0 CE 解开**；相册、微信可读 |
| v0.3.0-onyx.1 | OS4 底包；WLAN + 自动连接；AW8697 振动；首屏自动解密；锁屏 / 控制中心 / 双击亮屏 / AVB 页 | 真机：`/data` 自动打开、WLAN 自动连、振动驱动；其余见状态页 |

完整哈希与验证见 [`00-status.md`](00-status.md) 和 [`07-changelog.md`](07-changelog.md)。

## 7. 一分钟上手

```sh
# 只想刷机
# 1. 从 Releases 下 recovery.img + SHA256SUMS，核对
sha256sum -c SHA256SUMS --ignore-missing
# 2. fastboot 刷入
fastboot flash recovery recovery.img
fastboot reboot recovery
# 3. 回滚
fastboot flash recovery recovery-stock-OS4.0.2.0.XOLCNXM.img
```

```sh
# 想自己编
export ANDROID_NDK=/path/to/android-ndk-r29
scripts/bootstrap.sh && scripts/build-pack.sh && scripts/fetch-stock.sh
scripts/build-phone.sh && scripts/build-system-init.sh && scripts/build-image.sh
```

下一步：刷机看 [`04-install.md`](04-install.md)，编译看 [`03-build.md`](03-build.md)，原理看 [`02-architecture.md`](02-architecture.md) 与 [`05-design-notes.md`](05-design-notes.md)。
