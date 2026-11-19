# data 备份每次失败：内存扩展的交换文件（2026-11-19）

状态：已完成
关联版本：`v0.3.1-onyx.2` → `v0.3.1-onyx.3`（真机刷入 onyx.3）
关联提交：a21ea0e（config）+ 本次 docs 提交

## 1. TL;DR

用户报「备份 data 每次都是失败」，失败在进度约 45% 处；复现抓到 kmsg 里是 `os error 126`（`ENOKEY`），落在 `/data/extm/` 里那个 6 GiB 的内存扩展交换文件上。在 `devices/onyx.toml` 加 `[backup] data_skipped = ["extm"]`，重建镜像刷入真机后，data 备份 34.4 GB 完整写完并校验通过。

## 2. 对话重点

- 用户要求：修好「备份 data 每次都是失败」。原话只有这一句，屏幕上的报错用户没记住；追问后确认**失败发生在进度条走到一半/收尾时**，目标为**内置存储**。
- 明确做出的决策：
  - 先复现、拿确切报错，再改代码，不按猜测改；
  - 复现手段：`adb push` 到 `/tmp/skyward`（不能叫 `recovery`，见坑 3），用它的 `capture` 子命令抓帧、`sendevent` 往 `/dev/input/event7` 注入触摸，自己把备份页点完；
  - 修复放在**设备配置**（`devices/onyx.toml` 的 `[backup] data_skipped`），不改上游 `skyward-backup` 的语义。
- 否决的方案：让 `archive::pack` 遇到 `ENOKEY` 的文件就跳过并继续——那会让备份「悄悄不完整」，上游没有这个语义，真读失败也会被吞掉。
- 范围外但被提到：设备当前底包已是 `OS4.0.4.0.XOLCNXM`（首页卡片读数），本镜像仍基于 `OS4.0.2.0` 原厂 recovery；本次没有按新底包逐项复核服务路径，只在本次真机操作里顺带确认 data 解密 / MTP / WLAN / 截帧正常。

## 3. 修复内容

| 文件 | 改了什么 | 为什么 |
| --- | --- | --- |
| `devices/onyx.toml` | 新增 `[backup]` 段，`data_skipped = ["extm"]`，并写明原因 | 不跳过时 data 备份必然在 `/data/extm/<随机名>` 上失败 |

没有改 Rust 代码；手机侧二进制与 `v0.3.1-onyx.2` 完全一致（sha256 `6e2c030e…6840`）。

## 4. 设计思路

- 问题本质：HyperOS 的「内存扩展」把交换文件放在 `/data/extm/`，本机是 6 GiB（6442450944 字节），文件名每次开机重新生成，内容用与安全世界绑定的密钥封装。换一次启动（包括从 Android 进 recovery）再打开就是 `ENOKEY`（`os error 126`）。它是**易失的内存内容**，不是用户数据：备份它没有价值，恢复回去也不可能打开。
- 方案 A（采纳）：在设备配置里点名跳过 `extm`。上游本来就为这类「本机安全世界自己管、旧副本还打不开」的目录留了 `[backup] data_skipped`（默认表里已有 `vendor/goodix`、`vendor/tzstorage` 这类指纹/安全世界目录），机制现成、改动最小、语义清楚。
- 方案 B（否决）：把 `pack` 改成「打不开的文件跳过并记数」。会掩盖真实的读失败（比如坏块），而且备份的完整性承诺会变模糊；以后真出现别的易失目录，再按 A 的方式点名加。
- 关键取舍：备份里没有 `extm`——本来也不该有；需要的空间从 **40.9 GB** 降到 **34.4 GB**，失败点随之消失。
- 恢复侧：`data_skipped` 在解包时同样生效（跳过的地方不删也不写），所以恢复 data 备份不会把交换文件写回去，这正是想要的。

## 5. 踩过的坑

**坑 33：HyperOS 的 `/data/extm` 交换文件让 data 备份必失败**（已写入 `06-pitfalls.md`）

- 现象：备份页勾 data → 内部存储 → 完成后校验，备份能跑起来、写到约 17 GB（进度约 45%）时失败，页面回到失败页；kmsg 一行：
  `backup failed: back up the data partition's files: archive /data/extm/OuEEYQAAAAAriBSUBbu0U1W8A4UpuT1s: open /data/extm/OuEEYQAAAAAriBSUBbu0U1W8A4UpuT1s: Required key not available (os error 126)`
- 根因：`extm` 是内存扩展的交换文件，每次开机用新密钥封装，recovery 里没有那把钥匙。
- 解法：`[backup] data_skipped = ["extm"]`。
- 如何避免：看到 `os error 126` 先怀疑「per-boot 加密的易失文件」；Xiaomi/HyperOS 机器先看 `/data/extm`。

**复现/验证过程中又碰到两件事**

- 在运行中的 recovery 里执行 `/system/bin/recovery <子命令>` 会按 `argv[0]` 重跑 recovery（坑 3）：命令没有输出，随后黑屏重启、adb/fastboot 一起掉线。正确做法是把同一个二进制 `adb push` 成 `/tmp/skyward` 再跑 `capture`。
- 刷完 `fastboot reboot recovery` 后 adb 一度 `error: closed`、设备从 USB 消失（和 11-19 13:31 那次一样）；**拔插一次数据线**即恢复枚举，不需要重刷。

## 6. 验证与证据

真机：onyx（Redmi Turbo 4 Pro），recovery 内 adb root，底包 `OS4.0.4.0.XOLCNXM`，data 已解密。

**修改前（复现故障）**

```
# 备份页：data 分区 + 内部存储 + 完成后校验，滑动开始
[  153.9] skyward: ... 正在备份 data，已备份 1.8GB，共 40.9GB（4%）
[  376.137694] skyward: backup failed: back up the data partition's files:
  archive /data/extm/OuEEYQAAAAAriBSUBbu0U1W8A4UpuT1s:
  open /data/extm/OuEEYQAAAAAriBSUBbu0U1W8A4UpuT1s: Required key not available (os error 126)
```

`/data/extm/` 里只有一个文件：`-rw------- root system 6442450944 2026-11-19 05:42 OuEEYQAAAAAriBSUBbu0U1W8A4UpuT1s`；失败的备份目录被自动删除（`unlink data.tar.000`、`rmdir 20261119-191727`）。

**修改后（构建 + 刷入 + 复跑）**

```
scripts/build-image.sh   # lz4 在 PATH 上（本机在 default-workspace/work/lz4）
out/test-skip-extm.img   104857600 字节
ramdisk 50811959 字节，1062 条目
SHA-256 0c3b149866c80b3650b2255678bad87406b826fecb5e1954d4121487fb2caf98
fastboot flash recovery out/test-skip-extm.img   # OKAY
/skyward/device.toml:98  data_skipped = ["extm"]
sha256sum /system/bin/recovery = 6e2c030e0e216845a4ec242ac8a7ff99f7448fa4e0ce9c06d56be0442ea06840   # 未重编，与 onyx.2 相同
```

复跑备份（同样勾选：data + 内部存储 + 完成后校验）：

```
正在备份 data，已备份 3.8GB，共 34.4GB（11%）   # 比修改前少 6.5 GB
[  520.637121] skyward: backup saved in /sdcard/Skyward/backups/20261119-192419
```

备份内容（`backup.toml`）：

```
format = 1
device = "onyx"
made = 1795087459
slot = "_b"
system = "OS4.0.4.0.XOLCNXM"
data_key = "19e0674ac9bec006fdaea5144c3167d8"
[[items]] part = "data"  files = data.tar.000 … data.tar.032
size = 34833827840   stored = 34833827840   compressed = false
sha256 = "8c98ce7cdf78d7b9965c177b4cd37792427813412f5985adb7e3f2a7934b2dfc"
```

界面显示「备份完成 · 已保存到内部存储的 Skyward/backups/20261119-192419 · data 已校验」。

**未验证**

- 恢复（restore）没有跑：35 GB 写回 /data 是破坏性操作，本次不做。`data_key` 校验、`data_skipped` 在解包侧的跳过逻辑只有单测覆盖。
- 底包 `OS4.0.4.0` 下服务路径 / VINTF 未逐项复核（本镜像仍构建在 `OS4.0.2.0` 原厂 recovery 上）。
- `v0.3.1-onyx.3` 刷入后按用户要求**没有再跑第二遍备份**（第二遍跑到 22% 时中止，随后连同第一遍的 34.4 GB 备份一起删除：`/data` 从 98 GB 回到 55 GB）。本版与跑通备份的测试镜像只差版本号字符串。

## 7. 未完成 / 下一步 / 风险

- **已发版**：`v0.3.1-onyx.3`（tag `v0.3.1-onyx.3`，release id `451265604`，<https://github.com/Remoparrot/skyward-onyx/releases/tag/v0.3.1-onyx.3>），资产 `recovery.img`（104,857,600 字节 · `a525afa9…0376`）、`recovery-stock-OS4.0.2.0.XOLCNXM.img`（`ce538507…cd3357`）、`SHA256SUMS`（182 字节）。版本号由补丁 0006 与 `Cargo.toml`/`Cargo.lock` 升到 `0.3.1-onyx.3`，二进制 8,965,824 字节 · `d470bc40…9e13`。
- 仍未做：恢复（restore）全流程；系统分区 / 启动分区 / EFS 备份与 U 盘目标；onyx.2 的安装期修复要在真机上完整跑一次官方整包（见 `00-status.md` 第 4 节）。
- 风险：如果 HyperOS 以后把交换文件搬到别的目录，data 备份会在新位置同样失败；这一条只对 `extm` 有效。恢复 data 备份时若 data 分区被重建过，会按设计拒绝（`Refusal::DataReset`）。
