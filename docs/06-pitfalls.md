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

**2026-11-19 复现**：在运行中的 recovery 里执行 `/system/bin/recovery --version`（本意是读版本号）同样触发：命令无输出，随后黑屏重启，adb / fastboot 一起掉线（未写坏分区）。验收版本请用 `ls -l` + `sha256sum /system/bin/recovery`，不要去执行它。

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

---

## 19. Windows 宿主上把手机路径当 Windows 路径校验

**现象**：`[wlan] firmware: /vendor/... is not an absolute path`，`[haptics] resonance: /sys/... is not an absolute path`，宿主打不了镜像。

**根因**：`Path::is_absolute()` 在 Windows 上要求盘符 / UNC；`/vendor` 在手机上是绝对路径，在 Windows 上不是。

**解法**：手机侧绝对路径统一用 `Path::has_root()`（`/vendor` 在 Windows 上也以 `RootDir` 开头）。已改 `[[owners]]`、`[wlan] firmware`、`[haptics] resonance`。

**如何避免**：配置里描述的是**手机**，不是宿主；校验用 `has_root`，不要用 `is_absolute`。

## 20. vendor AIDL supplicant 的 `addService` 返回 -129

**现象**：`wpa_supplicant` 打 `Starting AIDL supplicant` 后立刻 `Failed to initialize wpa_supplicant`；LD_PRELOAD 探针显示 `AServiceManager_addService(...) -> -129`。

**根因**：`-129` 是 `EX_TRANSACTION_FAILED`；recovery 的 servicemanager / VINTF 不认这个 vendor AIDL 服务。

**解法**：`shim/wpa-aidl-shim.c` 预加载，覆盖 `AServiceManager_addService` 返回 0；Skyward 只用 per-interface control socket。

**如何避免**：先看 `addService` 返回值，不要先怀疑 SELinux / 库；换 vendor 后重新确认 supplicant 仍开 per-interface socket。

## 21. wlan0 出现后立刻 `set_up` 报 EBUSY

**现象**：`bring wlan0 up: Device or resource busy (os error 16)`，但 FW 日志还在初始化。

**根因**：接口节点先出现，驱动还没准备好。

**解法**：`bring_up` 对 `iface::set_up` 重试 10 秒（200 ms 一次）。

**如何避免**：设备节点出现 ≠ 可用；驱动初始化要有重试。

## 22. 自动连接把 WLAN 密码写空

**现象**：首次自动连接成功，但 settings 的 `wlan.password` 变成空串，下一次启动连不上。

**根因**：`set_wlan` 保存时只取 `state.wlan_password`；自动连接没有「用户刚输入的密码」。

**解法**：保存时优先用本次输入的密码，否则沿用同一 SSID / 名字的已存密码。

**如何避免**：手动连接和自动连接共用保存路径；测试「没有新密码时保留旧密码」。

## 23. AW8697 的 FF 波形格式与 qcom 不同

**现象**：qcom 上能用的 FF 点击，在 onyx 上不振动。

**根因**：AW8697 的 `FF_PERIODIC` 自定义数据是 Awinic RTP / waveform，不是裸 i8 采样。

**解法**：sysfs 后端（`activate` / `duration` / `effect_id` / `gain`）。

**如何避免**：先查 `/proc/bus/input/devices`、`/sys/bus/i2c/devices/*` 和驱动日志，不要假设 FF 通用。


## 24. 锁屏滑块一拖，背后就是一块纯色

**现象**：锁屏上按住圆形按钮往右拖，滑块轨道那一整块矩形变成纯色（浅色 `#f3f3f3`、深色黑），松手才恢复模糊。

**根因**：`paint_knob` 每次移动都 `fill_rect(track, t.pal.bg)` 清掉控件区域再画控件；普通页面底色就是 `pal.bg` 所以看不出来，锁屏的底色是模糊快照，一清就是纯色块（圆角外的四个角尤其明显）。

**解法**：改成把控件所在行标脏（`redraw_rows` → `stale`），由 `render()` 按页重画这几行，模糊快照随页面一起回来。

**如何避免**：就地重画控件时不要用主题底色清洗；除非能证明控件背后就是主题底色。

## 25. 锁屏模糊「采样率太低」

**现象**：锁屏背景糊成一团色块；用户反馈「采样率太低」，连色彩切换都看不出来。

**根因**：`remember()` 最初每 22 px 取一点，再叠压暗层，细节全没了；模糊半径固定。

**解法**：每 10 px 采样、按 `lock_blur` 调模糊半径；`lock_blur=0` 时不保存快照，锁屏退回主题底色。

**如何避免**：小图只用来做背景，别指望看清内容；强度为 0 要有独立路径。

## 26. 5 GHz WiFi 扫不到 / 连不上

**现象**：2.4 GHz 能连，5 GHz 网络不出现或连不上；`iw reg get` 为 `country 00: DFS-UNSET`。

**根因**：`wpa_supplicant.conf` 没写监管域，内核按世界规则把 5.8 GHz 留给被动扫描；芯片 offload 扫描覆盖不全；WPA2 网络没给 PMF（有的 5 GHz AP 要求）。

**解法**：写 `country=<ro.boot.ptcountrycode / ro.vendor.radio.build_region / ro.product.locale.region，默认 CN>`、`disable_scan_offload=1`、`sae_pwe=2`；WPA2-PSK 网络 `ieee80211w=1`，SAE 仍是 `2`；去掉全局 `pmf=1`。

**如何避免**：接 WLAN 前先看 `iw reg get` 与 `wpa_supplicant.conf` 里有没有 `country`；`sae_pwe` 用 2（H2E 与 hunting-and-pecking 都试）而不是 1（只 H2E）。

## 27. 调色板整体「色域校正」让颜色发灰

**现象**：onyx.5 初版刷上后用户反馈「颜色太淡了」；设置页蓝色滑杆从 `(74,128,247)` 变成 `(97,126,200)`，首页图标蓝从 `(52,130,255)` 变成 `(84,126,204)`。

**根因**：为了让页面「接近系统原色」，`Theme::light/dark` 对整套 `LIGHT`/`DARK` 采样值做了 sRGB → Display P3 再压饱和度 0.68（`graded()` → `Palette::original()` → `stock()`），图标底色又单独走 `Theme::ink()`。压饱和度那一步等于把每个彩色往灰里拉。

**解法**：把这一层整套删掉（`graded` / `original` / `stock` / `ink`、`color::p3`、`color::desaturated`、`icons::tile()` 里的 `t.ink()`），采样值原样绘制；`patches/0008` 里对应三段一起删，干净上游 apply 0001–0008 后 `diff -r` 仍与 vendor 树一致。

**如何避免**：显示效果以用户实际观感为准，别拿「更接近系统」当理由整体改调色板；真要试色域就做成可选、默认关，并先给用户看两张对比图。

## 28. 0.3.1 自动发现的 keymint 一启动就退出，data 打不开、也没有锁屏输入

**现象**：刷入 v0.3.1-onyx.1 后开机停在解密页；`dmesg` 里 keymint 每秒重启一次：

```
skyward: /vendor/bin/hw/android.hardware.security.keymint-service-qti: pid 562 ended: exit status: 1
skyward: the data partition stays closed: ...IKeyMintDevice/default is not running
```

于是 `/data` 不挂载、user 0 的锁屏密码页也不出现（用户看到的「data 没解开，没有锁屏」）。

**根因**：0.3.1 的 `skyward-programs` 给 `/vendor` 程序只给 `/system/lib64:/vendor/lib64`；Android 17 的 recovery 里没有 `libvndksupport.so`。手动执行可复现：

```
CANNOT LINK EXECUTABLE "/vendor/bin/hw/android.hardware.security.keymint-service-qti":
library "libvndksupport.so" not found: needed by /vendor/lib64/libhardware.so
```

而我们 0.3.0 写死的服务表里一直带着 `/mnt/system/system/lib64` 与 `/mnt/system/system/lib64/bootstrap`，所以以前没暴露。

**解法**：`patches/0003` 把 `/vendor` 程序的库目录补成 `/system/lib64:/vendor/lib64:/vendor/lib64/hw:/mnt/system/system/lib64:/mnt/system/system/lib64/bootstrap`（`crates/skyward-programs/src/secure.rs` 的 `VENDOR_LIBRARIES`）。刷入后 keymint 正常注册，`/data` 挂载，user 0 自动解开，锁屏也回来了。

**如何避免**：把「服务启动命令 + 库路径」当成会随底包 / 上游变化的东西；每次换上游或底包，先在 recovery 里手动跑一遍 HAL 二进制（带 `LD_LIBRARY_PATH`）确认能驻留，再依赖自动发现。HAL 退出时 Skyward 只记 `exit status: 1`，看不到程序自己打的链接错误；必要时临时把子进程 stderr 写到文件。

## 29. Windows 上编不过 0.3.1 的 `skyward-pack`

**现象**：`scripts/build-pack.sh` 在 Windows 上报 `skyward-block` 的 `std::os::unix`、`libc::statvfs` 等错误。

**根因**：0.3.1 的打包器新增 `described` 子命令，依赖 `skyward-programs` → `skyward-omapi` → 一串只面向 Android/Linux 的 crate；宿主 Windows 编不了。

**解法**：把 `described` 做成 Cargo feature（默认开），`scripts/build-pack.sh` 用 `--no-default-features` 编宿主打包器。`recovery` / `stock` / `list` / `cat` / `repack` / `boot` 都不受影响；只有「从官方全量包抽某机型分区描述」这个 CI 用的子命令被关掉。

**如何避免**：宿主工具与手机运行时共用 workspace 时，把「只在手机侧用」的子命令做成 feature；下次上游再加这类子命令时，先看 `cargo check -p skyward-pack --no-default-features`。

## 30. 0.3.0 → 0.3.1 的 `settings.json` 兼容

**现象**：升级后以为要重新输锁屏密码 / 重新连 WLAN。

**根因**：0.3.1 把设置拆成 `Settings` 的多个结构体，但字段名（`remember_data`、`data_password`、`wlan.*`、`lock_blur`）没换；`settings.rs` 的 `read` 对未知字段与缺字段都容忍。

**验证**：旧版本保存过密码的机器，刷 0.3.1 后第一次启动不走解密键盘，`dmesg` 从 `[0, 999]` 直接变成 `[999]`，WLAN 自动连上 `CMCC-A9s7-5G`。

**如何避免**：改设置字段名时同时写迁移（或明确 `/metadata/skyward` 要清）；升级前先备份该文件。

## 31. 整包刷完不自动刷回 Skyward：收尾写 recovery 报 EPERM

**现象**：在「安装」里刷官方整包，`update_engine` 成功、系统能起；再进 recovery 是原厂界面。安装页底部没有「已将 Skyward 重新刷入…」，或者显示「未能将 Skyward 重新刷入 recovery 分区」+ `write /dev/block/by-name/recovery_b: Operation not permitted`。

**根因**：Android 17 的 `update_engine` 在 `FilesystemVerifierAction` 校验完写入的分区后，会把目标块设备置成只读（`BLKRO`）。recovery 分区是物理分区，也在被它写与校验的名单里；Skyward 收尾的 `Kept::write()` → `image::flash()` 用 `O_RDWR` 打开 `recovery_<目标槽>` 写，内核回 `EPERM`（只读块设备拒绝一切写，和文件权限无关），于是 `Reflashed(Failed)`。

**解法**：`patches/0007` 的 `crates/skyward-install/src/image/protection.rs`：写之前对这次选中的设备 `BLKROGET`，只读就 `BLKROSET 0` 清掉；写完 `sync_all` + 读回校验完再 `BLKROSET 1` 恢复（成功/出错都恢复，`ReadOnly` 的 `Drop` 兜底并写 kmsg）。只对块设备做（`FileTypeExt::is_block_device`），普通文件不会被 ioctl 碰到。

**如何避免**：任何「安装收尾还要写分区」的逻辑，都默认目标设备可能被 `update_engine` 置成只读；`open(O_RDWR)` 成功不代表能写。另外 `/dmesg` 现在会分得清三种情况：没勾开关（`not asked to be kept`）、两个槽都已经是这个 build（`hold this build already`）、真的写失败（`Install: this recovery written back to … Err(...)`）。上游同类实机结论见 PR #48。

## 32. 刷整包的进度一上来就 100%，然后十几分钟不动

**现象**：安装页进度条几乎立刻到 100%，之后整个写入期都不动，写完才跳「完成」。实际刷入是成功的，只是「等好久」。

**根因**：进度取的是「包被读到的最远字节」`Mount::served()`。`package::identify` 为了拿 zip 目录会读文件末尾的中央目录，`served()` 一下等于整个包的大小；`done = served - payload_offset` 超过 `total` 被 clamp 成 `total`，于是第一秒就 100%。`payload.bin` 在 zip 里靠前，但中央目录在最后，这个坑与机型无关。

**解法**：`patches/0007`：`apply()` 先用 `Mount::watch_payload(payload_offset, payload_size)` 标出 payload 区间；FUSE 的 `Server::read()` 只累计落在这个区间里的字节（`payload_read`），`Stage::Writing` 用它、再由调用方 clamp 到 payload 大小。之后 `update_engine` 的校验阶段仍按分区显示「第 2 步，共 3 步：校验 …（n/m）」。

**如何避免**：文件系统层统计「读了多少」时，先想清楚这个文件的哪一段才是业务进度；zip/镜像这类容器先读目录、后读数据，用「最远偏移」当进度一定失真。单测 `only_bytes_of_the_payload_range_count` 固定了这个行为。

## 33. HyperOS 的 `/data/extm` 交换文件让 data 备份必然失败

**现象**：备份页勾「data 分区」→ 内部存储 → 完成后校验，备份能跑起来，写到约 17 GB（进度约 45%）时失败，进度页转成失败页；`dmesg` 只有一行：

```
skyward: backup failed: back up the data partition's files: archive /data/extm/OuEEYQAAAAAriBSUBbu0U1W8A4UpuT1s:
open /data/extm/OuEEYQAAAAAriBSUBbu0U1W8A4UpuT1s: Required key not available (os error 126)
```

**根因**：`/data/extm` 是 HyperOS「内存扩展」的交换文件目录（本机一个 6442450944 字节的文件，root:system 0600）。文件名每次开机重新生成，内容用与安全世界绑定的密钥封装；换一次启动（Android → recovery）再打开就是 `ENOKEY`（`os error 126`）。备份需要的空间也因此多算 6 GB（40.9 GB → 34.4 GB）。

**解法**：`devices/onyx.toml` 加

```toml
[backup]
data_skipped = ["extm"]
```

机制与上游默认表里的 `vendor/goodix`、`vendor/tzstorage` 相同：点名跳过「本机安全世界自己管、旧副本打不开」的目录。恢复时解包同样跳过它，所以不会把交换文件写回去。刷入后同一台机器 data 备份 34.4 GB 跑完，`skyward: backup saved in /sdcard/Skyward/backups/20261119-192419`。

**如何避免**：备份失败先看 `dmesg` 里 `os error 126`（`ENOKEY`）——那是「文件还在，但打开它的钥匙没了」，通常是你这台机器上一次启动才有的易失文件，不该进备份。Xiaomi/HyperOS 先看 `/data/extm`；换底包后如新增同类目录，往 `[backup] data_skipped` 里点名加，不要去改 `archive::pack` 的语义（那会把真的读失败也吞掉）。
