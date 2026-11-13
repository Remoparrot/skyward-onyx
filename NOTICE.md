# NOTICE

本仓库是 [kirklin/skyward](https://github.com/kirklin/skyward) 的**设备移植**，不是上游官方仓库。

## 上游

- 项目：Skyward
- 仓库：https://github.com/kirklin/skyward
- 版本：v0.2.0（commit `ff1668fdb72a46f22152a6540f49728c42081aba`）
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

`patches/0002-omapi-se-bridge.patch` 按 AOSP 的 AIDL 布局实现了 `android.se.omapi` 的最小子集，并对接 `android.hardware.secure_element`。这些接口定义归 AOSP（Apache-2.0）；补丁只包含为让 NXP weaver 能在 recovery 里查询 eSE 所需的方法编号与 parcel 布局。

## 设备固件

- 原厂 recovery 提取自小米官方全量包 `onyx-ota_full-OS4.0.2.0.XOLCNXM-user-17.0-dbe344d29d.zip`，仅用于重打包；
- 原厂 recovery 镜像作为回滚资产随 Release 提供，不放入 git 仓库；
- 本项目**不**分发完整 HyperOS 固件包。

Xiaomi、Redmi、HyperOS 是小米通讯技术有限公司的商标。本项目与小米无隶属关系，也未获其背书。

## WLAN AIDL shim

`shim/wpa-aidl-shim.c` 是本仓库自己的代码（GPL-3.0），只定义一个覆盖 `AServiceManager_addService` 的符号，让 vendor 的 `wpa_supplicant` 在 recovery 的 servicemanager 前继续启动；不包含 vendor 库或 AOSP 头文件。

## 第三方代码

Skyward 自身依赖的 crate 许可见上游 `Cargo.lock` 与各 crate 的 `LICENSE`；本仓库不修改这些依赖的许可。
