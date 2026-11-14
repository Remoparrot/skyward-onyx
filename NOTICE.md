# NOTICE

本仓库是 [kirklin/skyward](https://github.com/kirklin/skyward) 的**设备移植**，不是上游官方仓库。

## 上游

- 项目：Skyward
- 仓库：https://github.com/kirklin/skyward
- 版本：v0.3.1（commit `bd34c05`，`chore: release 0.3.1`）
- 许可：GPL-3.0（本仓库的 `LICENSE` 即上游同一份 GPL-3.0）

`patches/` 里的补丁是对上游源码的修改；`scripts/bootstrap.sh` 会取回固定版本的上游源码再应用补丁。发布镜像中包含的 `skyward` 二进制由这份「上游 + 补丁」编译而来。

## 字体

镜像内包含 Skyward UI 的两款字体：

| 文件 | 来源 / 许可 |
| --- | --- |
| `MiSansVF.ttf` | 小米 MiSans，随上游仓库分发；版权归小米 |
| `KirkMono-Regular.ttf` | KirkMono，SIL Open Font License 1.1，见上游 `resources/fonts/KirkMono-OFL.txt` |

字体不单独在本仓库重新分发；构建时从上游源码取。

## Android 接口

`android.se.omapi` 与 `android.hardware.secure_element` 的最小实现来自上游 v0.3.1 的 `crates/skyward-omapi` 与 `crates/skyward-binder/src/serve.rs`；这些接口定义归 AOSP（Apache-2.0）。本仓库的补丁不再包含 OMAPI 实现。0.3.0 及以前由 `patches/0002-omapi-se-bridge.patch` 提供，已随版本升级退休。

## 手机自己的程序

0.3.1 起，qseecomd / keymint / gatekeeper / secure_element / weaver / boot-control 等程序由上游 `skyward-programs` 从手机安装系统的 `system_ext` / `vendor` / `odm` 分区**在运行时读取并启动**，本仓库不复制、不分发这些二进制；`devices/onyx.toml` 只保留触摸服务。

## 设备固件

- 原厂 recovery 提取自小米官方全量包 `onyx-ota_full-OS4.0.2.0.XOLCNXM-user-17.0-dbe344d29d.zip`，仅用于重打包；
- 原厂 recovery 镜像作为回滚资产随 Release 提供，不放入 git 仓库；
- 本项目**不**分发完整 HyperOS 固件包。

Xiaomi、Redmi、HyperOS 是小米通讯技术有限公司的商标。本项目与小米无隶属关系，也未获其背书。

## WLAN AIDL shim

`shim/wpa-aidl-shim.c` 是本仓库自己的代码（GPL-3.0），只定义一个覆盖 `AServiceManager_addService` 的符号，让 vendor 的 `wpa_supplicant` 在 recovery 的 servicemanager 前继续启动；不包含 vendor 库或 AOSP 头文件。

## 第三方代码

Skyward 自身依赖的 crate 许可见上游 `Cargo.lock` 与各 crate 的 `LICENSE`；本仓库不修改这些依赖的许可。
