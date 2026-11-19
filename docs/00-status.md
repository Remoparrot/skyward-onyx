# 当前状态

> 状态：**现行**
> 最后更新：2026-11-19
> 对应版本：`v0.3.1-onyx.3`
> 设备：Redmi Turbo 4 Pro（`onyx`）· 构建底包 OS4.0.2.0.XOLCNXM（Android 17）；真机系统已到 OS4.0.4.0.XOLCNXM

---

## 1. 当前版本

| 项 | 值 |
| --- | --- |
| 版本 | `v0.3.1-onyx.3`（上游 v0.3.1 + onyx.2 的安装期两处修复 + data 备份跳过 `/data/extm`） |
| 构建日期 | 2026-11-19 |
| 镜像 | `recovery.img` · 104,857,600 字节 |
| 镜像 SHA-256 | `a525afa9fef1d2166547b7b2ac21f8c99053960730e93f77f94199c063d06376` |
| ramdisk | 50,815,375 字节（LZ4）· 1062 个 cpio 条目 |
| 内含 skyward | 8,965,824 字节 · `d470bc4068b821759c67813d3593e67e64bf89831c40f3cd27211f153cd19e13` |
| zip（在线更新用） | 本次未打；在线更新优先取 release 里的裸 `recovery.img`，不需要 zip |
| 原厂 recovery | `recovery-stock-OS4.0.2.0.XOLCNXM.img` · 104,857,600 字节 · `ce53850714fe2ca9ab22600a00e71813df2775dc94244192c83a224d7ecd3357` |
| 上游 | `kirklin/skyward` @ `bd34c05`（v0.3.1）+ 0001–0007 |
| 真机 | ✅ 已刷入 onyx：`/data` 自动挂载、user 0 CE 自动解开（旧版保存的锁屏密码）、WLAN 自动连接 5 GHz 并上网、首页读数、息屏再点亮先出锁屏（模糊快照）、设置页新滑块/开关、关于本机显示 `0.3.1-onyx.3`。data 备份 34.4 GB 跑通并校验，验证时用的是与本版只差版本号的测试镜像（本版刷入后没有复跑备份）。触摸与振动未逐项复测，见第 2/3 节。onyx.2 的安装期修复本身尚未跑过一次完整 OTA，见第 3 节 |

发布资产在 [Releases](https://github.com/Remoparrot/skyward-onyx/releases)；仓库内只有源码、补丁、配置和文档。

### 历史镜像

| 版本 | 镜像 SHA-256 | 结果 |
| --- | --- | --- |
| v1 | `78bbf052…6640` | 首次构建；密度错、无触摸 |
| v2 | `9ae3c85e…9dd` | 密度修好；仍无触摸 |
| v3 | `b1374ccd…b5ee` | 触摸、`/data` 设备级解密修好；user 0 CE 仍锁 |
| v4 | `b41bee5b…f83f` | user 0 CE 解开；OS3.0.306.0 底包 |
| v0.3.0-onyx.1 | `714dfc27…0ba5` | OS4.0.2.0 底包；WLAN / 振动 / 锁屏（每次亮屏）/ 双击亮屏 / 自动解密页 / AVB 页；控制中心已按用户要求删除 |
| v0.3.0-onyx.2 | `ebed2df2…3060` | 首页机型卡片四列读数；在线更新接受裸 `recovery.img`、支持本地刷入 |
| v0.3.0-onyx.3 | `d0a67128…60c5` | 更新下载最多 512 连接并行；可用空间读数在解密后补齐；更新页对本地刷入显示进度/结果 |
| v0.3.0-onyx.4 | `239d0fbb…f3ea` | 旧版；「下载」页改成图形浏览器（HTML/CSS 子集 + 图片 + 链接）；URL 下载走 512 并行；关于本机署名加上 Remoparrot。浏览器在 onyx.5 删除 |
| v0.3.0-onyx.5 | `ac9be2c5…0de2` | 删掉浏览器、下载页回归；锁屏背景模糊 + 强度滑杆 + 滑块拖动修复（浅色/深色）；5 GHz WLAN（监管域/扫描/PMF）；解密前不锁屏；同日重建：调色恢复采样原值（撤销 P3 + 饱和度 0.68 校正）；不再有色彩风格切换 |
| v0.3.1-onyx.1 | `27fbfc1c…cf5f` | 上游同步到 v0.3.1（UI 状态机拆分、`skyward-programs` 自动发现密钥服务、自带 `skyward-omapi`）；onyx 的 WLAN / 振动 / 锁屏模糊与滑块 / 首页读数 / 下载页全部移植；补丁 6 个；同日修复 keymint 因缺 `libvndksupport.so` 启动失败（库路径加安装系统 `/system/lib64` 与 bootstrap） |
| v0.3.1-onyx.2 | `f1b7685e…7d38` | 旧版；安装期两处修复（补丁 7）：整包刷完自动把 Skyward 写回目标槽的 recovery 分区（不再被 update_engine 留下的只读标志挡住）、写入进度只按 payload 区间计数（不再一上来就 100%）；底包仍是 OS4.0.2.0 |
| v0.3.1-onyx.3 | `a525afa9…0376` | **当前**；`[backup] data_skipped = ["extm"]`（坑 33）修掉 data 备份必失败；版本号升到 0.3.1-onyx.3；其余与 onyx.2 相同 |

> 2026-11-19 13:31 真机刷入：`fastboot flash recovery` 写入本版镜像，重启后 `/system/bin/recovery` 8,959,728 字节、sha256 `6e2c030e…6840`（与构建记录一致），`/data` 自动打开、user 0 自动解开、MTP 正常。刷后验证时误执行 `/system/bin/recovery --version`，按第 3 条坑触发黑屏重启，重启后 USB 暂未枚举，UI 未复验；详见 `sessions/2026-11-19-flash-onyx2.md`。另：该次启动的 cmdline 为 `swinfo.fingerprint=onyx:15/OS4.0.3.1.XOLCN:user`，用户确认**系统最近更新过**：设备底包现为 `OS4.0.3.1.XOLCN`，而本版镜像仍基于 `OS4.0.2.0` 原厂 recovery 构建；本次启动 `/data`、MTP、WLAN 模块加载正常，触摸 / 锁屏 / 读数未复测，服务路径与 VINTF 需按新底包复核。

> 2026-11-19 19:23 复刷（验证 `/data/extm` 修复）：同一份 `system/bin/recovery`（`6e2c030e…6840`）加新 `device.toml` 打成 `out/test-skip-extm.img`（`0c3b1498…af98`）刷入；本次启动底包已是 `OS4.0.4.0.XOLCNXM`，`/data` 自动打开、MTP / WLAN / 截帧正常，data 备份 34.4 GB 跑通并校验（备份副本验证后已按用户要求删除）。

> 2026-11-19 19:37 发版复验 `v0.3.1-onyx.3`：版本号升到 0.3.1-onyx.3 后重编二进制（8,965,824 字节 · `d470bc40…9e13`）并打镜像（`a525afa9…0376`），`fastboot flash recovery` 刷入；`dmesg` 为 `onyx 0.3.1-onyx.3 recovery up`，关于本机显示 0.3.1-onyx.3，配置含 `data_skipped`。刷入后按用户要求没有再跑一遍备份；随后把手机重启回系统并清掉两次验证备份（`/data` 从 98 GB 回落到 55 GB）。

---

## 2. 已验证（真机）

验证环境：onyx，HyperOS `OS4.0.2.0.XOLCNXM`，bootloader 已解锁，刷入方式 `fastboot flash recovery`。

| 项 | 证据 |
| --- | --- |
| 镜像结构 | `header v4  kernel 0 bytes  ramdisk 50692327 bytes`；`skyward-pack list` 1062 条 |
| 版本 | `dmesg`：`onyx 0.3.0-onyx.5 recovery up` |
| 触摸服务 | `touch_report_debug` 由 `prepare()` 拉起；本次未逐项做滑动验证（v4 已验） |
| `/data` 自动打开 | `dmesg`：`/dev/block/dm-9 holds f2fs at /data`；开机首屏即「解密」（解密前不锁屏），记住密码时自动打开 |
| user 0 CE | `skyward data --credential <用户锁屏密码>`：`/data/media/0` 出现真实文件名，`DCIM/Camera` 的 JPEG 可读；user 999 仍锁 |
| WLAN 扫描 | 5 GHz / 2.4 GHz 共 20+ 个网络；`wpa_state=COMPLETED`，SSID `CMCC-A9s7-5G`，`key_mgmt=SAE` |
| 5 GHz WLAN（onyx.5 配置） | `/skyward/run/supplicant/wpa_supplicant.conf` 为 `country=CN`、`disable_scan_offload=1`、`sae_pwe=2`；`iw dev wlan0 link`：`SSID: CMCC-A9s7-5G`、`freq: 5260`；`dmesg`：`wlan0 has 192.168.1.227`、`the network on wlan0 reaches the internet`；主机 `ping 192.168.1.227` 通 |
| WLAN 自动连接 | 重启 recovery 后自动连上，`ifconfig wlan0`：`192.168.1.227/24`，IPv6 全局地址；密码由 `/metadata/skyward/settings.json` 保存（0600） |
| 振动 | `skyward haptic --config /skyward/device.toml`：驱动 `awinic_haptic` 进入 RAM 模式，`level=0x40`，`duration=16`；实际振感待用户确认 |
| recovery 锁屏（亮屏） | 启动时不再弹锁屏，直接进「解密」；data 解密后息屏再点亮才显示锁屏（无恢复密码为滑动解锁，有密码为数字键盘） |
| 每次息屏点亮锁屏 | 用 `sendevent` 注入 `pmic_pwrkey` 电源键：息屏后背光 0，再按点亮背光；`App::wake()` 在 data 已解密时把 `Lock` 压栈，解锁后回原页 |
| 锁屏背景模糊 | 浅色/深色各截一张：背景是上一页的模糊快照（`remember()` 1/10 采样 + 盒式模糊 + 双线性拉伸），上面压半透明层；设置页滑杆 0～1 实时生效并存进 `settings.json` |
| 锁屏滑块拖动 | 按住圆形按钮拖到 50% 截图：轨道区域仍是模糊背景 + 半透明蓝色进度，圆角外像素随模糊画面变化（`(235,236,239)` 等）；修复前是整块 `(243,243,243)` |
| 色彩风格删除 | 设置页无「色彩风格」行，搜索无此项；`settings.json` 不再写 `vivid`；调色板保持 `LIGHT`/`DARK` 采样原值（初版的 P3 + 饱和度 0.68 校正在同日重建中撤销） |
| 调色恢复原值 | 设置页蓝色滑杆取色 `(74,128,247)`（重建前 `(97,126,200)`）；首页图标蓝 `(52,130,255)`，与 onyx.4 截图 `beforeLock.png` / `adv1.png` 逐像素一致；浅色/深色、锁屏均复验 |
| 唤醒黑屏修复 | 第一版 `wake` 后物理屏黑、后台截图却是锁屏页；原因是面板被 `surface.rest()`/`turn_off()` 后本机不恢复。改为息屏只关背光、面板保持 On，唤醒后背光 10926、DPMS On，锁屏帧重新 present |
| 记住密码 / 自动解密 | 解密页打开「记住密码」并输入手机锁屏密码后成功；重启 recovery，滑动锁屏后日志从 `[0, 999]` 变为 `[999]`，user 0 自动打开，页面显示「data 分区已解密」 |
| 解密完成倒计时 | 自动解密后截图「完成 · 3 秒后进入主界面」；3 秒后自动回到主界面，主界面已有「下载」行 |
| 下载页 | 主界面「下载」；键盘「确定」打开文本网页；二维码页面 `http://192.168.1.227:8080/` 可打开并回传 URL；用 `adb reverse` 的本地 HTTP 服务下载 `test.bin` 到 `/sdcard/Download`，内容校验一致 |
| 文本网页 | 键盘「确定」打开 `https://ys.mihoyo.com`，显示标题《原神》官方网站…和文本；无 JS/CSS/图片，不是 Chromium |
| 高级页面 | Skyward 更新、禁用 AVB 2.0 已从设置移到高级；设置页不再有这两行 |
| 首页机型卡片读数 | 卡片下四列：`B / 当前槽位`、`已解密 / 数据分区`、`175.1GB / 可用空间`、`100% / 未充电`；「可用空间」在解密完成后补齐（之前整列缺失） |
| 在线更新（自更新） | `0.3.0-onyx.1` → `0.3.0-onyx.2`：检查到新版本、下载 45.85 MB zip、SHA-256 校验后写入槽位 B；重启 `dmesg`：`onyx 0.3.0-onyx.2 recovery up` |
| 并行下载 512 连接 | 同上 zip 用新下载器 17.2 s 下完并校验通过；单连接此前约 17 分钟（≈40 KB/s） |
| 本地 recovery.img 刷入 | `0.3.0-onyx.2` → `0.3.0-onyx.3`：`/sdcard/Download/recovery.img` 写入槽位 B；onyx.3 上再刷一次，页面显示进度与「更新成功 · 已将 Skyward 刷入槽位 B 的 recovery 分区。」 |
| 锁屏滑动（注入触摸） | 用 `sendevent` 往 `/dev/input/event7` 注入从滑锁轨道左到右的拖动：`/data` 挂载、进入解密页 |
| 自动连接持久化 | 自动连接之后 settings 中的 `wlan.password` 仍为原密码（修复了首次自动连接会把密码写空的问题） |

> 早期测试中两次黑屏重启，均对应执行了 `setprop ctl.stop recovery`；之后不再使用该命令。

### v0.3.1-onyx.1 复验（2026-11-14）

| 项 | 证据 |
| --- | --- |
| 版本 | `dmesg`：`skyward: onyx 0.3.1-onyx.1 recovery up, misc command "boot-recovery"`；`/tmp/skyward info`：`recovery = 0.3.1-onyx.1` |
| 密钥服务自动发现 | `skyward keys`：qseecomd / ssgtzd / hlosminkdaemon / keymint / gatekeeper / secure_element(eSE1) / OMAPI / weaver / boot-control 共 8 个程序；`dmesg`：`keymint ... ready with IKeyMintDevice/default` |
| `/data` | `dmesg`：`/dev/block/dm-9 holds f2fs at /data` |
| user 0 CE | `dmesg`：`the users whose own files are still closed: [999]`（user 0 已开）；`ls /sdcard/DCIM/Camera` 列出真实 JPEG（`IMG_20260713_143045.jpg` 等，大小正常） |
| 自动解密 | 未在本次手动输入密码；旧版本存在 `/metadata/skyward/settings.json` 的「记住密码」，新版本启动后自动解开 user 0（说明 0.3.0 → 0.3.1 的 settings 兼容） |
| WLAN 自动连接（5 GHz） | `iw dev wlan0 link`：`SSID: CMCC-A9s7-5G`、`freq: 5260`；`dmesg`：`wlan0 has 192.168.1.227`、`the network on wlan0 reaches the internet` |
| 首页读数 | 截图：`B / 当前槽位`、`已解密 / 数据分区`、`175.6GB / 可用空间`、`67% / 充电中` |
| 锁屏 | 电源键注入息屏→点亮：截图显示日期 / 时钟 / 电量 / 模糊快照 /「滑动解锁」胶囊；解锁回原页 |
| 设置页 | 截图：浅色/深色、屏幕亮度、锁屏背景模糊滑杆（「中」）、双击亮屏开关都在 |
| 关于本机 | 截图：`0.3.1-onyx.1`、`© 2026 Kirk Lin & Remoparrot` |
| 未验证 | 触摸服务未重新注入复测（0.3.0 已验证）；振动未听感复测；下载页/网页页/AVB 页未点；纯数字键盘锁屏未点 |

---

## 3. 未验证 / 已知限制

| 项 | 状态 | 说明 |
| --- | --- | --- |
| 安装期两处修复（onyx.2） | ⚠️ | 代码路径有单元测试（payload 区间计数），`BLKROSET` 那段按上游 #48 的真机结论实现；**尚未在 onyx 上再跑一次完整 OTA**。复验方法：进 Skyward 安装页选官方整包，观察进度是否从 0 走到 100%（不再一上来 100% 卡住）、结束时是否出现「已将 Skyward 重新刷入B 的 recovery 分区」；重启进 recovery 看是否还是 Skyward |
| user 0 CE（相册 / 微信） | ✅ | 用用户锁屏密码通过 `skyward data --credential` 验证：`/data/media/0` 真实文件名，`DCIM/Camera` 的 JPEG 可读 |
| user 999（第二空间 / 应用分身） | ❌ | 只有 weaver 绑定的 protector；recovery 没有 eSE 通道；不再作为解密页的等待项 |
| recovery 锁屏（输入解锁） | ⚠️ | 滑动锁屏已用注入触摸验证（点亮 → 解锁 → 回原页）；4–8 位数字键盘未手动点过 |
| 纯文本网页页 | ⚠️ | 删掉浏览器后保留的上游网页页（标题/正文/链接）；未逐项点过 |
| 双击亮屏 | ⚠️ | 已实现（息屏 400 ms 内两次点击）；有注入触摸手段，但未逐项点过 |
| 禁用 AVB 2.0 | ⚠️ | 页面与 `avbctl` 调用已实现；**按要求未测试** |
| Skyward 在线更新 | ✅ | `0.3.0-onyx.1` → `0.3.0-onyx.2` 全流程实测；onyx.3 起优先下 release 里的裸 `recovery.img`，没有再退回 zip |
| 并行下载（512 连接） | ✅ | 45.85 MB 17.2 s；DNS 查询已缓存，服务端不认 Range 会退回单连接 |
| 系统 OTA 并行下载 | ⚠️ | 走同一条并行下载路径；未在真机完整下载过几 GB 的 OTA |
| WLAN 密码安全 | ⚠️ | 明文存 `/metadata/skyward/settings.json`（0600）；recovery 内 adb 本来就是 root，但共享镜像/换机前应删掉 |
| 振动强度 | ⚠️ | 驱动 `gain` 0x00–0x80 映射；实际振感与强度曲线待用户确认 |
| 备份 / 安装 / 文件管理 / 终端 / MTP | ⚠️ | 上游能力。**data 备份**于 2026-11-19 真机跑通（`[backup] data_skipped = ["extm"]` 之后，34.4 GB + 校验通过，见 `sessions/2026-11-19-backup-extm.md`）；**恢复**、系统分区 / 启动分区 / EFS 备份、U 盘目标、文件管理、终端未逐项验证 |
| 双系统 / OTA / fastbootd | ⚠️ | 未在 onyx 上验证，不建议依赖 |
| 换底包 | ⚠️ | 本镜像只对 OS4.0.2.0.XOLCNXM 验证；换版本后服务路径 / VINTF / WLAN 固件路径可能变 |
| `setprop ctl.stop recovery` | ❌ | 实测会重启整机，禁止使用 |

---

## 4. 当前阻塞 / 下一步

> **onyx 特性构建（2026-11-19，版本号仍为 v0.3.1-onyx.3）**：补丁 0008 已应用到源码并重编，镜像 `out/skyward-v0.3.1-onyx.3-features.img`（sha256 `1512e723d9d78d1ce86097dbcd9e5ad2f52ed38908d883eaf89ddf835a0816db`）已 `fastboot flash recovery` 刷入 onyx，启动到解密页；`dmesg` 为 `onyx 0.3.1-onyx.3 recovery up`，qseecomd / ssgtzd / keymint / gatekeeper 在跑。文件管理入口 / 分区工具 / Root 模块页面待解锁后复验。该镜像未替换 Release 资产。


0. **`/data/extm` 修复已随 `v0.3.1-onyx.3` 发出**（2026-11-19 晚）：`devices/onyx.toml` 的 `[backup] data_skipped = ["extm"]` 解决 data 备份必失败（坑 33），真机刷入本版并核对版本 / 配置 / 二进制哈希；备份复跑按用户要求中止。剩余：恢复（restore）流程、系统分区 / 启动分区 / EFS 备份、U 盘目标未验证。详见 `sessions/2026-11-19-backup-extm.md`。
0b. **onyx.2 的安装期修复要在真机上再刷一次整包才算闭环**：刷入 onyx.2 → 进「安装」选官方整包 → 看进度是否从 0 走到 100%、结束有没有「已将 Skyward 重新刷入B 的 recovery 分区」→ 重启进 recovery 是否还是 Skyward → `dmesg | grep 'install:'` 应有 `this recovery written back to [B]: Ok(())`。步骤见 [`07-changelog.md`](07-changelog.md) 与 [坑 31/32](06-pitfalls.md)。
1. **触摸与振动复测**：0.3.1 的触摸服务仍由 `[[service]]` 拉起、振动配置未变，但本次只验证了「服务在跑」，没有重新注入滑动 / 听感复测；下次刷机补一次。
2. **下载页 / 纯文本网页 / AVB**：代码已随 0005 移植并编译通过，页面未逐项点；AVB 按用户要求不测试。
3. **纯数字键盘锁屏**：设置有 recovery 密码时的数字键盘路径未在本版点过；滑动锁屏已验。
4. **user 999**：仍然只有 weaver 绑定的 protector；0.3.1 的 OMAPI 桥由上游自动起，但还没有接输入流程，不要贸然接。
5. **zip 资产**：本次只发裸 `recovery.img`；在线更新优先取它，zip 需要按官方 OTA 结构重打（未做）。
6. **系统 OTA 并行下载**：与 Skyward 更新共用 512 并行路径；未完整下载过几 GB 的系统 OTA。
7. **上游继续演进**：0.3.1 的 `app/*` 与 `skyward-programs` 都在变化；下次同步优先核对 `0005` 与 `0003` 的库路径，并先手动跑 keymint 驻留测试。

---

## 5. 构建环境（参考）

| 组件 | 版本 |
| --- | --- |
| 宿主 | Windows 10/11 + MSYS2 bash |
| Rust | 1.100.0 `1.100.0-x86_64-pc-windows-gnu`，target `aarch64-linux-android` |
| Android NDK | r29（29.0.14206865） |
| MinGW-w64 | gcc 16.2.0 + binutils 2.47 |
| lz4 | 1.10.0（PATH） |
| 原厂包 | `onyx-ota_full-OS4.0.2.0.XOLCNXM-user-17.0-dbe344d29d.zip` |

完整命令见 [`03-build.md`](03-build.md)。

---

## 6. 发布检查单

- [x] 镜像大小 104,857,600
- [x] 头部 v4 / kernel 0 / ramdisk 50,811,639
- [x] `system/bin/recovery`、`skyward/system-init`、`skyward/device.toml`、`skyward/wpa-aidl-shim.so` 存在
- [x] 镜像内二进制与编译产物 sha256 一致
- [x] 原厂 recovery 的 sha256 与配置 `[stock] recovery` 一致（`ce538507…`）
- [x] 真机：`/data` 自动打开 / user 0 CE / WLAN 自动连接（5 GHz）/ 首页读数 / 锁屏（本版未复测触摸与振动）
- [x] `SHA256SUMS` 已更新
- [x] `docs/07-changelog.md` 顶部已记录
- [x] README 版本 / 哈希表已更新
- [x] user 0 CE 在 OS4 上用 `skyward data --credential` 验证
- [x] 锁屏背景模糊（浅色/深色）与滑块拖动（浅色/深色）
- [x] 设置/搜索中的「色彩风格」已删除；调色为 `LIGHT`/`DARK` 采样原值（无 P3 / 饱和度校正）
- [ ] 锁屏滑动 / 双击亮屏（锁屏滑动已注入验证；双击未点）
- [ ] AVB 2.0（明确不测试）
