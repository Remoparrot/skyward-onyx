# vermeer 移植与两处通用修复（2026-11-19）

状态：**部分完成**（源码改动已落地；onyx 未重编未上机）
关联版本：v0.3.1-onyx.3（源码领先于已发布镜像）
关联提交：（本次提交）

## 1. TL;DR

为 Redmi K70（vermeer）做 Skyward 移植时，反过来修了两处对 onyx 也成立的问题：密钥程序的库顺序（VNDK 优先）与按设备显示版本；另加了分区工具 / Root 模块管理 / 文件管理入口。onyx 镜像没有重打，所有新代码只经过 vermeer 真机验证。

## 2. 对话重点

- 用户要求：按 skyward-onyx 的功能给红米 K70 编 Skyward 0.3.1；刷入并 root；随后修 data 解密 / 5 GHz / 版本号 / 锁屏；文件管理放首页；安装页加分区工具；加 Root 模块管理。
- 决策：vermeer 的详细工作放到新仓库 `Remoparrot/skyward-vermeer`；本仓库只保留通用改动（补丁 0008 与脚本的 CONFIG 化）。
- 否决：不把 vermeer 的设备配置、文档、镜像混进 onyx 仓库。
- 范围外：KernelSU root 仍未做。

## 3. 修复内容

| 文件 | 改了什么 | 为什么 |
| --- | --- | --- |
| `patches/0008-libraries-version-files.patch` | 新增；9 个文件 +534 行 | 密钥程序库顺序、`[device] version`、文件管理入口、分区工具、Root 模块管理 |
| `scripts/build-image.sh` | `CONFIG` 可覆盖；镜像大小按 STOCK 校验 | 同一套脚本服务多设备 |
| `scripts/fetch-stock.sh` | `CONFIG` / `OUT` 可覆盖 | 取任意设备原厂 recovery |
| `scripts/verify-image.sh` | `EXPECTED_SIZE` 可覆盖 | 不再写死 104857600 |
| `scripts/build-phone.sh` | 读 `[device] version` → `SKYWARD_VERSION` | 显示版本跟设备走 |
| `devices/onyx.toml` | 加 `version = "0.3.1-onyx.3"` | 显示版本来源明确 |

## 4. 设计思路

- **库顺序**：vendor/odm 程序的 VNDK bundle 必须在安装系统库之前；不能删补丁 0003 的安装系统路径（onyx 可能依赖），只调整插入位置。
- **显示版本**：放在设备配置里，构建时注入，避免每台设备改 Cargo 版本；onyx 的 `0.3.1-onyx.3` 保持原样。
- **新页面**：分区/根模块都用现有 `Screen` + `Effect` 模式；长列表复用 `Rows` 按需绘制，避免 133 个分区撑爆画布。

## 5. 踩过的坑

- qseecomd 每秒退出、`/data` 解不开 → 见 vermeer 仓库 `docs/06-pitfalls.md` 第 1 条（`libdmabufheap.so` 解析到安装系统副本，连带缺 `libandroidicu.so`）。
- 分区列表超过 3 屏画布被截断 → 改用 `Rows` 长列表，按需绘制。
- `fastboot flash` 的 `Too many links` 是 USB 链路，不是镜像。

## 6. 验证与证据

- vermeer 真机（K70，b 槽）：`dmesg` 显示 `vermeer 0.3.1-vermeer.1 recovery up`；qseecomd / ssgtzd / keymint / gatekeeper 全起来，`/data` 解密；5 GHz 连上 5260 MHz；锁屏、文件管理、Root 模块页、分区页（A/B 合并 + 搜索）在真机打开。
- 镜像：`e661d91741689cb10ed7f57df0a2771e3b3f6ca35c1ab38dcf02ef58f31fe2fd`（vermeer 仓库）。
- **onyx 未验证**：本次没有重编 onyx 镜像、没有在 onyx 上刷机；新代码对 onyx 的影响只经过代码审查（库顺序对 onyx 也应更正确）。

## 7. 未完成 / 下一步 / 风险

- 重打 onyx 镜像并在 onyx 上刷一次，确认 0008 的库顺序与首页改动没有回归（尤其 qseecomd 与文件管理入口）。
- KernelSU root 未做。
- 风险：0008 改的是所有设备的服务启动路径；onyx 上没跑过，发版前必须真机验证。
