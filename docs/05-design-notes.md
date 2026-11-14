# 设计思路

> 状态：**现行**
> 对应版本：`v0.3.0-onyx.1`
> 读者：想理解「为什么这样做、为什么不那样做」的人。

---

## 1. 问题的本质

一开始的表象是「recovery 里输锁屏密码，提示密码不对」。但拆开看是三层：

1. `/data` 的**设备级**加密：keymint 能取到密钥，`/data` 已经挂载，`/data/app`、`/data/misc` 都能读；
2. `/data/media/0` 的**用户级（CE）**加密：文件名是密文，读写报 `Required key not available`；
3. 用户密钥的解锁链：锁屏密码 → 合成密码（SP）→ file secret → CE key。

第 3 层卡住的原因不是密码错，而是 **weaver 拿不到它保管的值**：

```
E/OmapiTransport: Failed to start omapiSeService null
E/OmapiTransport: Failed to connect to OMAPI
E/weaver-impl: GetSlots Failed to perform getSlot Request
```

NXP 的 weaver HAL 只走 OMAPI；OMAPI 的服务在正常系统里由 system_server 提供，recovery 没有。gatekeeper 本身是好的（用一个不存在的凭据去问，它会正确回答「不认识」），缺的只是通往 eSE 的那条通道。

---

## 2. 两条路：OMAPI 桥 vs gatekeeper 回退

### 方案 A：在 recovery 里实现 OMAPI → SE HAL 桥

做法：给 `skyward-binder` 加服务端，注册 `android.se.omapi.ISecureElementService/default`，把 weaver 的调用转发给 `android.hardware.secure_element.ISecureElement/eSE1`。

已经做到：

- binder 服务端能收 `BR_TRANSACTION`、回 `BC_REPLY`、在等待答复时处理对方回调、传 binder 对象；
- 服务用 stability **3** 注册（试过 1/2/16/32/48 都被 `Stability: Can only set known stability` 拒掉）；
- AIDL 方法编号从 **1** 开始：`getReaders=1, getReader=2, isSecureElementPresent=3`，session / channel 同理；
- 真机上 weaver 已经依次调用 `getReaders → getReader("eSE1") → isSecureElementPresent`，说明桥接、编号、对象交接都对。

卡住的地方：

- SE HAL 的 `init()` 不返回（`Failed on initalize eSE TA`），因为 eSE TA 没在安全世界里起来；
- 继续往下查要碰 TEE / NFC 链路，历史测试中触发过整机黑屏重启；
- 即使打通，收益只是「让 weaver 可用」，而 user 999 还需要额外的凭据输入流程。

**结论：不作为 v4 的主路径。** 代码留在 `patches/0002`，CLI 是 `skyward omapi` / `skyward se`，不自动启动。

### 方案 B：回退到 gatekeeper 绑定的第二份 protector

真机检查发现 user 0 在 `/data/system_de/0/spblob/` 下有**两份** protector：

| 文件 | 绑定 | 说明 |
| --- | --- | --- |
| `f599a28814fc768a` | `.weaver` → 槽位 1 | 系统记录为「当前凭据打开的那份」；weaver 不可用 |
| `f599a28814fc768b` | `.secdis`（58 字节 gatekeeper handle） | 同一用户、同一把锁屏密码也能打开 |

两份的 salt / scrypt 参数完全相同，所以同一个密码能算出同一个 `stretched`；`spblob` 里的 `inner` 是同一个 SP 的密文，差别只在「谁保管解它的 secret」：

- weaver：secret 由 eSE 槽位 1 的值派生；
- secdiscardable：secret 由 `.secdis` 的字节派生，凭据由 gatekeeper 校验。

而 CE 的 `encrypted_key` 是用 **SP 派生的 file secret** 做软件包裹的，不是绑 weaver 的。所以从任意一份 protector 拿到 SP，都能解出同一个 CE key。

实现（`patches/0003`，只改 `data.rs`）：

```text
open_user_files:
  1. protector(user) 读系统记录的那份
  2. 先按原逻辑开
  3. 若错误是 WeaverUnusable：
       a. 没有 credential → 原样返回
       b. 遍历 protector_ids(user)
       c. 跳过当前 id
       d. 只保留 Bound::Secdiscardable + lock.is_some() 的
       e. 用同一个 credential 再开一次（gatekeeper 校验）
       f. 成功即返回；全失败返回最后一个错误
```

**为什么选 B：**

- 不碰 eSE / TEE，不增加黑屏风险；
- 不改数据、不写 `/data`；
- 用的是系统自己留下的第二份 protector，不是破解；
- 代码改动小（约 90 行），失败时能明确报错。

**代价：**

- 只对「有第二份 secdiscardable protector」的用户有效；user 999 只有 weaver 绑定的，仍然打不开；
- 依赖 `.pwd` 的 salt / scrypt 参数与 `.spblob` 匹配；换底包 / 改锁屏方式后要重新确认；
- 如果系统记录的当前 protector 变了、或第二份被清理，回退会失败。

---

## 3. 为什么不是「直接跟 eSE 里的 applet 讲 APDU」

理论上可以绕过 weaver HAL，直接通过 SE HAL 发 APDU 给 weaver applet。不做：

- applet 的 APDU 协议是 NXP 私有的，要从 `ese_weaver.so` 反推；
- 一旦 APDU 写错，可能触发 eSE 复位 / 安全世界异常，风险远高于收益；
- user 0 已有 gatekeeper 回退，user 999 的收益不足以承担这个风险。

---

## 4. 触摸：为什么不能直接读 `/dev/input/event7`

现象：`getevent /dev/input/event7` 90 秒、用户滑动，**零事件**；把 `enable_touch_raw` 从 1 改 0、重刷触摸固件也没有用。

根因：onyx 的 NT38771 驱动在连接时复位控制器，之后只回传 raw 帧；面板自己的 input 设备不带触摸。小米的 `touch_report_debug` 才负责：

```
读 /dev/xiaomi-touch 的 raw 帧
  → /odm/lib64/libtouchreport.so + /odm/firmware/o10u_nova_csot_thp_config.ini
  → 写回面板输入设备
  → skyward 的 UI 才能收到
```

所以配置里是：

```toml
[[service]]
path = "/odm/bin/touch_report_debug"
libraries = ["/odm/lib64", "/vendor/lib64", "/vendor/lib64/hw", "/system/lib64"]
user = "root"
groups = ["root", "uhid", "input"]
capabilities = ["SYS_NICE"]
```

注意 onyx 的 ODM 里**没有** `touch_report`，只有 `_debug`。v2 按 fuxi / ishtar / nuwa 的写法拉了 `touch_report`，服务起不来，屏幕给出诊断页，这就是 v2 无触摸的全部原因。

---

## 5. 密度：为什么是 512 而不是 1109

- 屏幕 1280 × 2772；
- 目标布局宽度 400 dp（和测试过的机型一致）；
- `1280 ÷ 400 × 160 = 512`。

v1 用 `1109 = 2772 ÷ 400 × 160`，是按**高度**反推的，导致布局宽度只有约 184 dp，UI 整体放大 2.2 倍并溢出。

---

## 6. Windows 宿主构建：为什么需要补丁 0001

上游 `skyward-bootimg` 的 `Ramdisk::unpack` / `c_path` / `set_time` 用了 Unix 的权限 / 时间 API；宿主打包器只走内存里的 cpio，不需要这些函数。用 `#[cfg(unix)]` 围起来后，Windows 上可以只编打包器，手机侧照样交叉编译。

这不是「为了 Windows 改上游行为」，而是让同一个 crate 在不同宿主上只编需要的部分。

---

## 7. 关键取舍

| 取舍 | 选择 | 理由 |
| --- | --- | --- |
| 解密路径 | gatekeeper 回退优先 | 不碰 eSE，风险最低；user 0 已覆盖 |
| OMAPI 桥 | 保留代码，不自动启动 | 给 user 999 / 排错留路，但不进主路径 |
| 触摸 | 拉起小米自己的 `touch_report_debug` | 不自己解析 raw 帧，不重写驱动 |
| 密度 | 512 | 400 dp 宽，和测试机型一致 |
| 镜像 | 整分区 100 MB | 与原厂 recovery 分区一致，AVB footer 正确 |
| 数据 | 只读挂载验证，不写 `/data` | 用户数据不可替代 |
| 发布 | 镜像进 Release，不进 git | 单文件 100 MB，超过 GitHub 限制 |

---

## 8. 什么时候会失效

以下任一变化都可能让 v4 的回退失效：

- 底包不是 OS4.0.2.0.XOLCNXM；
- 用户在系统里改过锁屏方式，第二份 protector 被清理；
- `.pwd` 的 salt / scrypt 参数与 `.spblob` 不再匹配；
- 系统把「当前 protector」记录改成了另一份；
- keymint 的 note / key blob 布局变化；
- `/data` 的 `encrypted_key` 版本变化。

出现这些情况时，回退会报明确的错误（而不是静默失败）；按 [`08-troubleshooting.md`](08-troubleshooting.md) 收集 `spblob` 列表、`locksettings` 记录和日志，再决定是否走 OMAPI 桥。

---

## 9. v0.3.0 的设计补充

### 9.1 为什么换 OS4 底包

手机实际运行 OS4.0.2.0（Android 17），而 v4 的 recovery 是 OS3（Android 16）的 ramdisk。vendor 的 `wpa_supplicant` 与 OS3 的 `/system/lib64` 在 libc++ / `libvndksupport` / `libdl_android` 上错位，换多少库顺序都不稳。把 recovery 也换到 OS4 的官方 recovery 后，libs 同代，WLAN 才能继续。WLAN 的 sysfs / 固件路径也按用户这台机器核对。

### 9.2 为什么 AIDL 用 shim

vendor supplicant 带 AIDL；recovery 的 servicemanager 不认它的注册，`AServiceManager_addService` 返回 `-129`，它在打开 per-interface socket 前就退出。Skyward 的 WLAN 只用 per-interface `SOCK_DGRAM` control socket，不需要 AIDL。`shim/wpa-aidl-shim.c` 只覆盖这一个符号，把注册应答为 0；风险限于 supplicant 子进程。

### 9.3 为什么保存 WLAN 密码

「自动连接」要跨重启，supplicant 的 `update_config=0` 不保存网络，所以密码只能由 Skyward 保存。放在 `/metadata/skyward/settings.json`，目录 0700、文件 0600；recovery 内 adb 本来就是 root，这个锁只防「误看」，不防「拿到手机的人」。换机 / 共享镜像前删除。

### 9.4 锁屏与自动解密

- 开机一律先 `Lock`：没有 recovery 密码时是图 1 的滑动锁屏（日期、时钟、电量、「滑动解锁」），有 recovery 密码时是 4–8 位键盘；
- 滑动/解锁后才把栈换成 `Decrypt`，`Decrypt` 的 `arrive()` 发 `Effect::OpenData`，所以「进入 recovery 自动进入解密页」不需要额外入口；
- 手机锁屏密码只在 `Decrypt` 页输入；`skyward data --credential` 用同一个密码验证过 user 0 CE；
- recovery 密码只存 salt + SHA-256；锁屏不是安全边界：recovery 的 root adb 仍能改 settings / 读分区。

### 9.5 每次息屏点亮都锁屏

`wake()` 是面板从暗到亮的唯一入口（电源键、双击、插线都会走到它）。它在点亮时检查当前页：不是 `Lock` 就往栈顶压一个 `Lock`，并置 `wake_lock = true`。滑动/解锁后：

- `wake_lock` 为真：`Action::Unlock` 把 `Lock` 弹掉，回到息屏前那一页，不重新开 data；
- `wake_lock` 为假（开机首屏的锁）：栈换成 `Decrypt` 并 `open_data()`，即「进入 recovery 自动进解密页」。

`sleep()` 只关面板，不改栈；所以熄屏再亮屏时，锁屏在旧页之上，解锁后原样回去。开机、电源键、双击、插线四条路都覆盖。

onyx 的 DSI 面板被 `surface.rest()` 或 `surface.turn_off()` 后，再 `present()` 会出现「背光亮、DPMS On、物理屏黑」；因此在 `ui.rs` 里息屏只把背光降到 0、保留面板 On，让下一次 `present()` 直接把锁屏画上去。

### 9.6 双击亮屏

`App::touch` 在 `display_on == false` 时记录最后一次 `Down` 的时间与坐标；400 ms 内第二次 `Down` 落在 80 px 内就 `wake()`。设置页可关。输入设备在息屏时仍然打开（`Wakeful` 持有），所以触摸能唤醒 CPU。

### 9.7 版本与在线更新

上游 `github.rs` 硬编码 `kirklin/skyward`；onyx 的资产在 `Remoparrot/skyward-onyx`。用 `[update].skyward` 配置仓库，workspace 版本改成 `0.3.0-onyx.N`，asset 名 `skyward-v0.3.0-onyx.N-onyx-OS4.0.2.0.XOLCNXM.zip`，`semver` 才能正确比较 `onyx.N` 的前后。

## 9. 相关记录

- v1–v3 的构建与真机结论：[`sessions/2026-11-11-onyx-bringup.md`](sessions/2026-11-11-onyx-bringup.md)
- v4 的发现与验证：[`sessions/2026-11-12-ce-unlock-v4.md`](sessions/2026-11-12-ce-unlock-v4.md)
- 坑的完整列表：[`06-pitfalls.md`](06-pitfalls.md)

## 勘误 2026-11-14（v0.3.1-onyx.1）

- 原文「方案 A：在 recovery 里实现 OMAPI → SE HAL 桥……代码留在 `patches/0002`」**已过时**：上游 v0.3.1 自带 `crates/skyward-omapi` 与 `crates/skyward-binder/src/serve.rs`，并会在密钥程序就绪后自动 `serve android.se.omapi.ISecureElementService/default`。本仓库的 `0002-omapi-se-bridge` 已删除；user 0 仍走 gatekeeper 回退，OMAPI 只留给 user 999 与排错。
- 「设备服务写死在 `devices/onyx.toml`」**已过时**：0.3.1 的 `skyward-programs` 从安装系统的 `system_ext` / `vendor` / `odm` 分区读 init 脚本与 VINTF 描述，自动发现并启动密钥服务。onyx 的配置只剩触摸服务。
- 自动发现带来的新坑：`/vendor` 程序的库目录必须补上安装系统的 `/system/lib64` 与 `/system/lib64/bootstrap`（`libvndksupport.so`），否则 keymint exit 1、`/data` 打不开、也没有锁屏输入。见 [`06-pitfalls.md`](06-pitfalls.md) 第 28 条。
- 设计取舍不变：**user 0 用 gatekeeper 回退，不依赖 weaver / OMAPI**。0.3.1 只是把这个「工具链」换成上游的，解密主路径仍是 `0002` 的回退。
