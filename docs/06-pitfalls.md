# 踩坑记录

> 状态：**现行**
> 规则：每条固定四段 **现象 → 根因 → 解法 → 如何避免**。新坑追加在末尾，不改写历史。

---

## 1. VINTF 目录里一个坏文件让所有服务注册失败

**现象**：补完 qseecomd / keymint / gatekeeper 后，所有安全世界服务都起不来，`servicemanager` 里什么都查不到；日志没有明显指向某个文件。

**根因**：当时为了测 `/system/etc/vintf/manifest/` 是否可写，`touch` 了一个 `.w` 空文件。Android 的 VINTF 在解析这个目录时，遇到一个空 / 非法的 manifest 片段，整份清单变成 NULL，后续所有 HAL 注册失败。

**解法**：删掉那个空文件，重新打包。服务立刻恢复。

**如何避免**：

- 不要用 `touch` 测可写性，用 `test -w` 或写一个真实文件再删；
- 打包后跑 `skyward-pack list` 检查 `system/etc/vintf/manifest/` 条目，确认没有多出来的空文件；
- 服务注册失败时，先把该目录列一遍。

---

## 2. `setprop ctl.stop recovery` 会让整机重启

**现象**：在 recovery 里执行 `setprop ctl.stop recovery` 想停 UI 进程换版本，手机立刻 adb 断开、屏幕黑掉、按键无反应，只能长按电源重启。发生了两次。

**根因**：未完全查清。`recovery` 服务是 init 拉起的 oneshot / critical 服务，停掉它可能触发 init 的 `onrestart` 或整机 `reboot` 逻辑。`pstore` 为空，`bootinfo.pureason=0x40001`。

**解法**：不要停服务。换 UI 版本直接刷整分区镜像：

```sh
fastboot flash recovery 新版本.img
fastboot reboot recovery
```

**如何避免**：把这条写进 README 和 agent.md 的禁止事项；任何「热替换 recovery 二进制」的想法都先否掉。

---

## 3. 二进制命名为 `recovery` 会无视子命令

**现象**：`adb push skyward /tmp/recovery` 然后 `/tmp/recovery data --user 0`，结果整个 recovery 又起了一遍，和已有服务抢触摸 / 安全世界硬件，手机黑屏重启。

**根因**：skyward 用 `argv[0]` 判断自己是不是被 init 拉起的 recovery；名字是 `recovery` 时走 recovery 主流程，忽略后面的子命令。

**解法**：用 `skyward` / `sw` / 任意非 `recovery` 的名字：

```sh
adb push skyward /tmp/skyward
adb shell chmod +x /tmp/skyward
adb shell /tmp/skyward data --user 0
```

**如何避免**：开发测试统一用 `/tmp/skyward`；脚本里不要 `cp ... /tmp/recovery`。

---

## 4. onyx 没有 `touch_report`，只有 `touch_report_debug`

**现象**：v2 按 fuxi / ishtar / nuwa 的配置拉起 `/odm/bin/touch_report`，屏幕出现诊断页，`bring_up` 失败，提示 `devices not brought up: /odm/bin/touch_report is missing`，无触摸。

**根因**：onyx 的 ODM 里只提供 `touch_report_debug`，没有非 debug 版本。

**解法**：配置改成 `touch_report_debug`，触摸立即正常。

**如何避免**：移植新机型时先 `ls /odm/bin | grep touch`，不要照抄别的机型。

---

## 5. 直接读 `/dev/input/event7` 收不到触摸

**现象**：`getevent /dev/input/event7` 90 秒、用户滑动，零事件；`enable_touch_raw=0`、重刷触摸固件都没用。

**根因**：NT38771 驱动复位后只回传 raw 帧，坐标要由小米的 `libtouchreport.so` 计算并写回 input 设备。面板自己的 input 设备不带触摸。

**解法**：拉起 `touch_report_debug`，由它读 `/dev/xiaomi-touch` 并写回。

**如何避免**：不要把「input 设备存在」当成「触摸可用」；先用 `getevent` 验证有没有事件。

---

## 6. density 按屏高反推，UI 放大 2.2 倍

**现象**：v1 的 UI 字巨大、卡片溢出，屏幕只显示半页。

**根因**：`density = 2772 ÷ 400 × 160 = 1109`，按**高度**反推；实际应按宽度 `1280 ÷ 400 × 160 = 512`。

**解法**：改成 512。

**如何避免**：density 永远按「宽度 ÷ 目标 dp 宽 × 160」算；参考机型用 400 dp 时不要按高度算。

---

## 7. Windows 上 `dlltool` 在 `%TEMP%` 建不了文件

**现象**：

```
error: dlltool could not create import library ...
Cannot create temporary file in C:\Users\...\AppData\Local\Temp\: Permission denied
```

编 `getrandom` / `windows-sys` 时失败。

**根因**：该账号的系统临时目录不可写；`dlltool` 需要在那里建 `.def` / `.lib`。

**解法**：`TMPDIR` / `TEMP` / `TMP` 指到仓库内 `tmp/`（`scripts/env.sh` 已做）。

**如何避免**：Windows 构建一律走脚本，不要手工 `cargo build`。

---

## 8. MSYS 的 `link.exe` 遮蔽 MSVC 链接器

**现象**：`link: extra operand '...'`，或 `error: linker 'link.exe' not found`。

**根因**：rustup 默认宿主是 msvc；PATH 里的 `link.exe` 先命中 MSYS coreutils 的 `link`。

**解法**：`RUSTUP_TOOLCHAIN=stable-x86_64-pc-windows-gnu`。

**如何避免**：脚本里显式设宿主三元组，不依赖默认。

---

## 9. 上游 `ramdisk.rs` 的 Unix-only 代码挡住 Windows 打包器

**现象**：Windows 上编 `skyward-pack` 报 `Ramdisk::unpack` / `c_path` / `set_time` 相关错误。

**根因**：这些函数用了 Unix 的权限 / 时间 API；宿主打包器只走内存 cpio，不需要它们。

**解法**：`patches/0001` 用 `#[cfg(unix)]` 围起来，测试模块改成 `#[cfg(all(test, unix))]`。

**如何避免**：保持补丁独立；上游升级后先重放 0001 并跑一次宿主构建。

---

## 10. OMAPI 桥的三个硬约束

**现象**：桥注册成功但 weaver 连不上；或连上后 `associateClass` 判定 descriptor 为空；或回包被当成非法。

**根因**：

1. 服务 stability 必须是 **3**，1/2/16/32/48 都被 `Stability: Can only set known stability` 拒；
2. 交给对方的 binder 对象也必须带 stability 3，否则 descriptor 为空；
3. AIDL 方法编号从 **1** 开始（`getReaders=1, getReader=2, isSecureElementPresent=3`）；
4. 回 `_NTF` / 版本 / 哈希 / pid / ping 时，前面**不能**有 status 字——libbinder 的裸回包格式和普通事务不同。

**解法**：按上面的约束实现；`skyward se` 可单独探 SE HAL。

**如何避免**：不要凭「AIDL 一般从 0 开始」的直觉写；先反汇编 / 对照 `libbinder` 的 parcel 布局。

---

## 11. SE HAL 的 `init()` 卡住，继续碰会黑屏

**现象**：桥接完成三级调用后，转发给 `eSE1` 的 `init()` 永远不返回；继续查 TEE / NFC 时手机黑屏重启。

**根因**：eSE TA 没在安全世界里起来，SE HAL 一直等；`Failed on initalize eSE TA`。

**解法**：v4 不走 OMAPI，改用 gatekeeper 回退。桥保留为实验。

**如何避免**：涉及 eSE / TEE 的测试先在 `/tmp` 二进制上做，并准备好长按电源；不要在主力机上一上来就接开机流程。

---

## 12. user 999 只有 weaver 绑定的 protector

**现象**：user 0 的相册能读，user 999（第二空间 / 应用分身）仍然全是密文。

**根因**：999 的 `spblob` 只有 `.weaver`，没有 `.secdis` / `.pwd`；weaver 在 recovery 里拿不到 eSE，回退无路。

**解法**：暂不解决。要解只能走 OMAPI 桥或直接 APDU。

**如何避免**：文档明确写「user 999 不支持」；不要让用户以为密码错了。

---

## 13. payload extent 用块号还是字节偏移

**现象**：从官方全量包抽 recovery 时，得到的镜像头部不对 / 大小不对。

**根因**：payload 的 extent 是**块号**，要乘 block size 换成字节偏移；早期脚本直接当字节偏移用。

**解法**：`offset = block * 4096`（按 payload 的 block size），再按 `num_blocks` 读。

**如何避免**：优先用 `skyward-pack stock`（它已经处理），不要自己写第二套抽取脚本。

---

## 14. 文档数字和实际镜像对不上（996 vs 998）

**现象**：旧 README 写「998 个 cpio 条目」，`skyward-pack list` 实际输出 996。

**根因**：998 是 v2 时期的数字；v3 调整条目后没有同步文档。

**解法**：以 `skyward-pack list` 为准，v4 是 996（stock 984 + 新增 12）。

**如何避免**：每次发版把 `list` 的头部和条目数写进会话记录；不要从旧 README 抄数字。

---

## 15. `cargo: not found` / `lz4: command not found`

**现象**：后台构建脚本报 `exec: cargo: not found`，或打包时报 `lz4` 找不到。

**根因**：非登录 shell 的 PATH 不含 `~/.cargo/bin`；lz4 没装 / 不在 PATH。

**解法**：

```sh
export PATH="$HOME/.cargo/bin:$PATH"
# lz4 放进 PATH，或 export PATH="$PWD/tools:$PATH"
```

**如何避免**：`scripts/env.sh` 已加 cargo 路径；lz4 由 `check-deps.sh` 检查。

---

## 16. 镜像哈希和参考值不同

**现象**：自己编出来的 `recovery.img` 不是 `b41bee5b…`。

**根因**：Rust / clang 版本、路径、依赖、stock 字节不同都会改变输出；Rust 构建不保证逐字节可复现。

**解法**：比对结构（大小 / 头部 / 条目 / 二进制 sha256）和真机行为，不要只比整镜像哈希。

**如何避免**：Release 说明里写清「参考哈希」和「你的构建可能不同」。

---

## 17. GitHub 单文件 100 MB 限制

**现象**：`git push` 被拒，提示文件超过 100 MB。

**根因**：`recovery.img` 正好 100 MiB（104,857,600 字节），GitHub 对单文件硬上限 100 MB。

**解法**：镜像只放 Release，`.gitignore` 掉 `*.img` / `*.zip`。

**如何避免**：提交前 `git status` 检查；`.gitignore` 已覆盖。

---

## 18. 改完源码忘了重新打补丁

**现象**：`vendor/skyward` 里改好了，重新 bootstrap 后改动消失；或者 Release 镜像和 `patches/` 对不上。

**根因**：直接改 `vendor/`，没有生成 / 更新 `patches/`。

**解法**：在 `vendor/skyward` 里改 → `git diff` 生成补丁 → 覆盖 `patches/` → 从干净源码重放验证。

**如何避免**：agent.md 已把「不要直接改 vendor 后发版」列为禁止事项。
