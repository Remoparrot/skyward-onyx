# 安装期两处修复：整包刷完自动刷回、写入进度（2026-11-19）

状态：代码/构建/单测完成；真机 OTA 复验待做
关联版本：v0.3.1-onyx.1 → v0.3.1-onyx.2
关联提交：`4cbd3d5`（补丁 0007、版本与构建脚本）；本记录所在提交见 `git log`

## 1. TL;DR

用户报「刷完 ROM 后不会自动刷回 Skyward recovery」和「刷 ROM 时进度卡在 100% 不动但能刷进去、就是等很久」。查上游后确认是两个已经有人踩过的坑：Android 17 的 `update_engine` 校验后把目标块设备置只读，收尾写 recovery 报 `EPERM`；进度取的是「包被读到的最远字节」，zip 中央目录在文件末尾，所以一开始就 100%。加补丁 0007（`fuse.rs` / `run.rs` / `image.rs` + 新增 `image/protection.rs`）把两处都修了，版本升到 `v0.3.1-onyx.2`，镜像与单测通过；还差在 onyx 上真刷一次整包复验。

## 2. 对话重点

- 用户要求（原话要点）：「看一下 skyward 的最新源码，刷完 ROM 后无法自动刷回 skyward recovery，刷 ROM 时进度在 100% 不动，但还是正常刷入，就是要等好久，请修复」。
- 决策：
  - 两处都按**上游通用修复**来做（不是 onyx 特调），放进新补丁 `0007`，将来上游合并后可以整块删掉；
  - 进度只统计 **payload 区间**的读字节，而不是改 UI 的百分比；校验阶段继续用「第 2 步，共 3 步：校验 …（n/m）」；
  - 只读标志**只对本次选中的设备**清、写完读回校验后**恢复原样**（成功/出错都恢复），不给普通文件发 ioctl；
  - 底包保持 OS4.0.2.0，不借这次一起升 OS4.0.4.0（用户手机虽然是 4.0.4.0，但换底包要重做 keymint/WLAN 验证，属于另一件事）。
- 范围外但提到的事：没有。

## 3. 修复内容

| 文件 | 改了什么 | 为什么 |
| --- | --- | --- |
| `crates/skyward-install/src/fuse.rs` | 新增 `Payload`（payload 区间）与 `Server::payload_read`；`Server::read()` 只累计落在区间里的字节；`Mount::watch_payload()` / `Mount::payload_read()`；单测 `only_bytes_of_the_payload_range_count` | 原来只有 `served()`（最远读），读 zip 中央目录时直接等于包大小 |
| `crates/skyward-install/src/run.rs` | `apply()` 开头 `mount.watch_payload(update.payload_offset, total)`，`Stage::Writing` 改用 `mount.payload_read().min(total)`；`hold()` / `reflash()` 各加一条 kmsg | 进度失真；另两条日志让下次能分辨「没勾开关 / 不用写 / 写失败」 |
| `crates/skyward-install/src/image.rs` | `flash()` 写每个设备前 `ReadOnly::clear(path)?`，全部写读校验完 `drop(outs)` 再逐个 `restore()` | `update_engine` 校验后目标块设备是 `BLKRO=1`，写会 `EPERM` |
| `crates/skyward-install/src/image/protection.rs`（新增） | `BLKROGET`/`BLKROSET` 的 `ReadOnly` 守卫：只对块设备生效，`Drop` 兜底恢复并写 kmsg | 同上；守卫保证任何出错路径都把标志放回去 |
| `Cargo.toml`、`Cargo.lock`（补丁 0006 内） | 版本 `0.3.1-onyx.2` | 发布与自更新比较 |

## 4. 设计思路

- **为什么不用「已读字节 / 包大小」**：`update_engine` 只读 payload 段，但同一份 FUSE 文件还服务 `package::identify`（读头 4 KiB + zip 中央目录）和脚本，任何一次「读文件末尾」都会把「最远偏移」顶到包大小。改成「只统计落在 `[payload_offset, payload_offset+payload_size)` 的读」，读多少算多少，重复读就重复计、由调用方 clamp —— 语义简单，且对 sideload 与本地文件两条路径一致。
- **为什么按块设备判断而不是按路径**：`image::flash()` 也用于把 `recovery.img` / `boot.img` 写到临时文件（单测、loop 设备）；`FileTypeExt::is_block_device()` 保证只有真块设备才发 `BLKROSET`，普通文件完全不受影响。
- **为什么恢复只读标志**：`update_engine` 把设备置只读是它自己的策略；Skyward 只是临时借用写权限，写完把现场还原，避免把「本来是只读的」改成可写而改变后续行为（也让 `keep::tests` 里「校验后 `wanted()` 为空」的语义保持干净）。
- **为什么保留 `served()`**：它仍是「包读到哪」的事实，单测与将来别的用途还在用；只是不再拿它算进度。

## 5. 踩过的坑

1. **Windows 宿主跑不了 `cargo test`**：`skyward-block` / `skyward-lp` / `rsproperties` 依赖 Unix 接口，宿主编不过（`SocketFlags::CLOEXEC`、`libc` 的 `open64` 等）。解法：把单测编到 `aarch64-linux-android`，`adb push` 到 `/data/local/tmp` 在手机上跑（`TMPDIR=/data/local/tmp`），123 个测试全过。教训：这台机器的「跑单测」= 编手机 target + 真机跑，不是 `cargo test` 本机。
2. **`cc`/gcc 的临时目录**：宿主 `cargo test` 时 `zstd-sys` 让 gcc 编译 C，gcc 报 `Cannot create temporary file in C:\Users\…\Temp: Permission denied`。`env.sh` 把 `TMPDIR`/`TEMP`/`TMP` 指到仓库 `tmp/` 就正常；手写命令时要三个都设（`export TEMP=x TMP="$TEMP"` 里 `TMP` 会拿到旧值，要分开写）。
3. **`adb push` 的路径被 MSYS 改写**：`adb push bin /data/local/tmp/x` 变成 `C:/Program Files/Git/data/local/tmp/x`。加 `MSYS_NO_PATHCONV=1`。
4. **补丁 0006 改版本号**：直接 `sed` 把 `0.3.1-onyx.1` 换成 `0.3.1-onyx.2` 即可（`+` 行变，`-` 行与上下文是上游值，不动；字符串等长，hunk 头不用改）。
5. **`cargo` 的构建产物时间戳**：`--release --target aarch64-linux-android` 的 rlib 在 `build/phone/aarch64-linux-android/release/deps`，但 `cargo test --no-run` 的可执行文件落在 `build/<crate>/<hash>/out/`（不是 `deps/`）；找测试二进制要按 cargo 打印的路径。

## 6. 验证与证据

- 补丁可重现：干净 `bd34c05` 上 `scripts/bootstrap.sh` 依次 apply 0001–0007 成功；与构建树 `diff -r` 只差 CRLF/LF（Windows 检出导致），内容一致。
- 构建：`skyward` 8,959,728 字节、`system-init` 1,039,320 字节、`skyward-pack` 5,394,432 字节；镜像 104,857,600 字节、ramdisk 50,811,639 字节 / 1062 条；`scripts/verify-image.sh` 全绿。
- 单测：`cargo test --release --target aarch64-linux-android -p skyward-install --lib --no-run` 编出测试二进制，在 onyx（HyperOS 4.0.4.0，Android 17）上跑 `123 passed; 0 failed`，含新增的 `fuse::tests::only_bytes_of_the_payload_range_count` 与 `keep::tests::*`。
- 镜像内容：`skyward-pack list` 里 `skyward/device.toml` 在（`is_skyward()` 认得出自己），`system/bin/recovery` 里能搜到 `0.3.1-onyx.2`、`read the read-only flag of`、`not asked to be kept`、`hold this build already`。
- **没有做**：真机完整 OTA 复验（见第 7 节）。

## 7. 未完成 / 下一步 / 风险

- **待真机复验**：把 onyx.2 刷进 onyx（`fastboot flash recovery`），进「安装」选一个官方整包，观察：①进度从 0 走到 100%（不再一上来 100%）；②结束时出现「已将 Skyward 重新刷入B 的 recovery 分区」；③重启进 recovery 仍是 Skyward；④`dmesg | grep 'install:'` 有 `this recovery written back to [B]: Ok(())`。
- **风险**：`BLKRO` 那段没有本机复现记录，依据是上游 #48 在同类 Android 17 机器上的结论 + 代码推理；如果 onyx 上 `update_engine` 的行为不同（例如不置只读），`ReadOnly::clear()` 是 no-op，不会更糟。
- **未做**：Release 资产（裸 `recovery.img`）要发布后才有；本次没打 zip。底包仍是 OS4.0.2.0，手机现跑 4.0.4.0 —— 换底包时 WLAN / keymint 的路径要重验。
- **顺手可做**：上游 PR #63（payload 进度）与本补丁思路一致，若上游合并，可把 0007 里 fuse/run 的部分删掉只留 `protection.rs`。
