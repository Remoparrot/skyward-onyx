# 架构

> 状态：**现行**
> 对应版本：`v0.3.0-onyx.1`
> 读者：要改代码 / 要判断某个现象该看哪一层的人。

---

## 1. 全景

Skyward 的构建分两半：**宿主侧**把上游 Rust 源码编成打包器 `skyward-pack`；**手机侧**编出 `skyward` 和 `system-init`；最后用打包器把「原厂 recovery + 手机侧二进制 + 设备配置 + 字体」压成一个整分区镜像。

```mermaid
flowchart LR
  OTA["官方全量包<br/>onyx-ota_full-OS4.0.2.0.XOLCNXM"] -->|"skyward-pack stock"| STOCK["stock/recovery.img<br/>104857600 B"]
  UP["kirklin/skyward @ ff1668f<br/>+ patches/*.patch"] -->|"build-phone"| BIN["skyward<br/>aarch64-linux-android"]
  UP -->|"build-system-init"| SYSINIT["system-init<br/>static aarch64"]
  STOCK --> PACK["skyward-pack recovery"]
  BIN --> PACK
  SYSINIT --> PACK
  CFG["devices/onyx.toml"] --> PACK
  FONT["MiSansVF.ttf<br/>KirkMono-Regular.ttf"] --> PACK
  PACK --> IMG["recovery.img<br/>100 MB 整分区"]
```

没有 AOSP 源码树，也没有 Gradle / Soong。打包器只做三件事：解原厂 ramdisk、替换 / 新增条目、按原分区大小重新压回去并写 AVB footer。

---

## 2. 镜像布局

`recovery.img` 是**整分区**镜像，不是 `boot.img`：

| 偏移 / 结构 | 值 |
| --- | --- |
| boot header | v4 |
| kernel | 0 字节（内核由 boot 分区提供，和原厂 recovery 一致） |
| ramdisk | 50,625,278 字节，LZ4 legacy 帧 |
| ramdisk 解压后 | 以 `verify-image.sh` / AVB footer 的实际值为准 |
| cpio 条目 | 1062（原厂 1051 + 新增 11） |
| 分区大小 | 104,857,600 字节（100 MiB） |
| AVB footer | 未签名，`OriginalImageSize` 指向真正内容大小 |

### ramdisk 里改了什么

`skyward-pack list recovery.img` 可以直接看：

| 条目 | 变化 | 说明 |
| --- | --- | --- |
| `system/bin/recovery` | 替换：stock → **8,655,096** 字节 | Skyward 本体（aarch64 PIE，解释器 `/system/bin/linker64`） |
| `skyward/` | 新增目录 | 设备配置、字体、system-init |
| `skyward/device.toml` | 新增 8,367 字节 | `devices/onyx.toml` 的副本，运行时读 |
| `skyward/system-init` | 新增 1,038,104 字节 | 静态可执行，安装第二系统时用 |
| `skyward/wpa-aidl-shim.so` | 新增 5,312 字节 | `LD_PRELOAD` 给 vendor supplicant，应答 recovery 不认的 AIDL 注册 |
| `skyward/MiSansVF.ttf` | 新增 20,093,424 字节 | UI 字体 |
| `skyward/KirkMono-Regular.ttf` | 新增 270,456 字节 | 终端字体 |
| `skyward/KirkMono-OFL.txt` | 新增 4,483 字节 | 终端字体许可 |
| `system/bin/7za` `avbctl` `resetprop` `zstd` | 新增符号链接 | 都指向 `system/bin/recovery`，由 skyward 按 argv[0] 分派 |
| `system/etc/init/skyward-mtp.rc` | 新增 1,223 字节 | MTP 的 init rc |
| `system/etc/task_profiles.json` | 新增 1,709 字节 | 性能配置 |
| `prop.default` | 追加 | `ro.secure=0`、`ro.adb.secure=0`、`ro.debuggable=1`、`ro.ota.allow_downgrade=true` |

> OS4 原厂 stock ramdisk 是 30,175,673 字节 / 1051 条；v0.3.0-onyx.1 是 50,625,278 字节 / 1062 条。旧 README 里写的「998 / 996 条」是 v2/v3 时期的数字；以 `skyward-pack list` 为准。

---

## 3. 启动与服务

init 仍然是原厂 recovery 的 init，它启动的 `system/bin/recovery` 变成了 Skyward。Skyward 读 `skyward/device.toml`，按 `[[service]]` 拉起设备自己的 daemon，并用 `ready_property` / `ready_service` 等它们就绪：

```mermaid
flowchart TB
  INIT["原厂 init"] --> REC["system/bin/recovery<br/>= skyward"]
  REC --> TOUCH["touch_report_debug<br/>/odm/bin"]
  REC --> QSEE["qseecomd<br/>/vendor/bin"]
  QSEE --> KM["keymint-qti<br/>IKeyMintDevice/default"]
  REC --> GK["gatekeeper-qti<br/>IGatekeeper/default"]
  REC --> SE["secure_element qti<br/>ISecureElement/eSE1"]
  REC --> WV["weaver nxp<br/>IWeaver/default"]
  REC --> BOOT["boot control qti<br/>IBootControl/default"]
  REC --> MTP["skyward-mtp.rc → mtp"]
  WV -. "OMAPI（实验）" .-> OM["skyward omapi"]
  OM -. binder .-> SE
```

`devices/onyx.toml` 里一共 7 个服务：

| 服务 | 路径 | 作用 |
| --- | --- | --- |
| `touch_report_debug` | `/odm/bin/` | 读 `/dev/xiaomi-touch` raw 帧，转成触摸 |
| `qseecomd` | `/vendor/bin/` | 安全世界通道；`vendor.sys.listeners.registered` 就绪 |
| `keymint-qti` | `/vendor/bin/hw/` | 解 data 的密钥服务；同时注册 secureclock / sharedsecret / remotelyprovisioned |
| `gatekeeper-qti` | `/vendor/bin/hw/` | 校验锁屏凭据；VINTF 用 `manifest_sun.xml` |
| `secure_element qti` | `/vendor/bin/hw/` | eSE1 读卡器；weaver 的底层通道 |
| `weaver nxp` | `/odm/bin/hw/` | NXP weaver HAL；`ese_weaver.so` |
| `boot control qti` | `/vendor/bin/hw/` | 切 slot / 重启到系统 |

安全性相关的点：

- `gatekeeper` 和 `secure_element` 的 VINTF 描述不在 recovery 自己的 manifest 目录里，配置用 `description = ...` 单独交给它们；
- `weaver` 的 manifest 把接口名和实例名分开写，不能靠注册名反推，所以也用 `description`；
- `/system/etc/vintf/manifest/` 里不能留任何坏文件——一个坏文件会让整份清单变 NULL，所有服务注册失败（见 [`06-pitfalls.md`](06-pitfalls.md)）。

---

## 4. data 解密链路

Android 的 `/data` 有两层：

1. **设备级（DE / metadata）**：`/data` 整体用 dm-default-key 加密，密钥由 keymint 解出。v3 起这项已通，开机自动挂载。
2. **用户级（CE）**：每个用户的 `/data/media/<user>`、`/data/data` 等用 per-user CE key 加密；CE key 存在 `/data/misc/vold/user_keys/ce/<user>/current`，外面包着 `encrypted_key`，由**合成密码（SP）派生的 file secret** 做软件包裹。

Skyward 要做的是：从用户输入的锁屏密码拿到 SP，解出 CE key，再 `add_key` 到 fscrypt keyring，`/data/media/0` 才会出现真实文件名。

### v4 的实际路径

```mermaid
sequenceDiagram
  participant U as 用户
  participant S as skyward (data.rs)
  participant G as gatekeeper
  participant K as keymint
  participant F as fscrypt
  U->>S: 锁屏密码
  S->>S: 读 /data/system_de/0/spblob/<id>.{spblob,pwd,weaver|secdis}
  alt 记录中的 protector 绑 weaver，且 weaver 可用
    S->>S: weaver.config() / weaver.read(slot)
    S->>S: secret = weaver_protector_secret(stretched, value)
  else weaver 不可用（onyx 的实际情况）
    S->>S: 遍历同用户其他 protector
    S->>S: 只挑 Secdiscardable + 有 .pwd 的
    S->>G: verify(100000+user, enrolled, stretched)
    G-->>S: note
    S->>S: secret = protector_secret(stretched, secdis)
  end
  S->>K: gcm_decrypt(key_blob, nonce, body, note)
  K-->>S: inner
  S->>S: SP = open_inner(secret, inner)
  S->>S: file_secret = file_secret(SP)
  S->>S: CE key = stored.unwrap(file_secret)
  S->>F: add_key(CE key)
  S-->>U: /data/media/0 可见
```

关键常量（`crates/skyward-crypto/src/data.rs`）：

| 常量 | 值 | 含义 |
| --- | --- | --- |
| `TYPED_SLOT` | `100_000` | 用户输入的凭据登记在「用户号 + 100000」的 gatekeeper slot |
| `PROTECTORS` | `/data/system_de` | protector 根目录 |
| `BLOBS` | `spblob` | 每个用户的 blob 目录 |
| `SECRET_HANDLE` | `0000000000000000.handle` | 安全世界给用户 secret 的 handle |
| `USER_KEYS` | `/data/misc/vold/user_keys` | CE key 所在 |
| `MOUNT` | `/data` | fscrypt 挂载点 |

### 为什么两份 protector 都能开

`spblob` 里的 `inner` 是同一个 SP 的密文，差别只在「谁保管解它的 secret」：

- weaver 绑定：secret 由 eSE 槽位 1 的值 + stretched credential 派生；
- secdiscardable 绑定：secret 由 `.secdis` 的字节 + stretched credential 派生，凭据由 gatekeeper 校验。

两份 `.pwd` 的 salt / scrypt 参数相同，所以**同一个锁屏密码**都能算出同一个 `stretched`；SP 在改锁屏密码时不变，CE 的 `encrypted_key` 又是 SP 派生的 file secret 包的，所以从任意一份拿到 SP 都能解 CE key。

v4 的补丁只改 `data.rs` 一个文件：把 `protector()` 拆成 `protector_ids()` / `protector_named()`，把 `open_user_files()` 拆出 `open_with_protector()`，并在 weaver 不可用时按上面的条件回退。完整分析见 [`05-design-notes.md`](05-design-notes.md)。

---

## 5. OMAPI 桥（实验，非 v4 必需）

`patches/0002` 给 `skyward-binder` 补了**服务端**能力：接收 `BR_TRANSACTION`、回 `BC_REPLY`、在等待答复时处理对方回调、传递 binder 对象。然后 `crates/skyward/src/omapi.rs` 注册：

```
android.se.omapi.ISecureElementService/default
```

把 weaver 的 `getReaders` / `getReader` / `openSession` / `openBasicChannel` / `transmit` 等方法转发到已经运行的：

```
android.hardware.secure_element.ISecureElement/eSE1
```

它有两个 CLI 入口：

```sh
skyward omapi   # 起桥接服务
skyward se      # 只问 SE HAL「你是什么、在不在」，不需要凭据
```

但 v4 **没有**把它接进解密主路径：

- 它只是 `skyward` 的子命令，不会被 init 自动启动；
- weaver 通过它查询槽位时，SE HAL 的 `init()` 会卡住（eSE TA 未起来），历史测试中触发过黑屏重启；
- user 0 已经有 gatekeeper 回退，不需要 eSE。

保留它的原因：user 999 只有 weaver 绑定的 protector，将来要解 999 只能走这条路；同时 `skyward se` 是排查 eSE 的有用探针。**不要**在没有真机看护的情况下把它接到开机流程里。

---

## 6. 触摸链路

onyx 的触摸不是标准的 `/dev/input/eventN`：

```mermaid
flowchart LR
  PANEL["触摸控制器<br/>Novatek NT38771"] -->|raw 帧| XT["/dev/xiaomi-touch"]
  XT --> TR["/odm/bin/touch_report_debug"]
  LIB["/odm/lib64/libtouchreport.so<br/>/odm/firmware/o10u_nova_csot_thp_config.ini"] --> TR
  TR -->|写回虚拟输入设备| EV["/dev/input/event7"]
  EV --> UI["skyward UI / input.rs"]
```

实测：直接 `getevent /dev/input/event7` 90 秒、用户滑动，**零事件**；把 `enable_touch_raw` 从 1 改 0、重刷触摸固件都没有用。拉起 `touch_report_debug` 后触摸立即恢复。onyx 的 ODM 里**没有** `touch_report`，只有 `touch_report_debug`。

---

## 6.5 WLAN 链路

```
[modules] sources（vendor_boot / vendor_dlkm / vendor / system_dlkm）
  → rfkill（system_dlkm，cfg80211 的依赖）
  → qca_cld3_wcn7750（vendor_dlkm，依赖 icnss2 / cnss_utils / cfg80211 …）
  → 写 /sys/kernel/icnss/wlan_en_delay、wpss_boot
  → 固件从 /vendor/firmware/wcn7750 由 ueventd 加载
  → /etc/firmware/wlan/qca_cld/wcn7750/{WCNSS_qcom_cfg.ini,wlan_mac.bin}（从 vendor / persist 拷）
  → wlan0
  → /vendor/bin/hw/wpa_supplicant（LD_PRELOAD=skyward/wpa-aidl-shim.so）
  → per-interface SOCK_DGRAM control socket（/skyward/run/supplicant/sockets/wlan0）
  → SCAN / ADD_NETWORK / SET_NETWORK / SELECT_NETWORK / DHCP
```

`wpa-aidl-shim.so` 只覆盖 `AServiceManager_addService`，返回 0。recovery 的 servicemanager / VINTF 不认 vendor 的 AIDL 服务，原返回值是 `-129`（`EX_TRANSACTION_FAILED`）；Skyward 不使用 AIDL，所以只需要 supplicant 继续走到 per-interface socket。

## 6.6 振动链路

AW8697（`awinic_haptic`）在 i2c `5-005a`，input `event5` 有 FF，但它的自定义波形格式是 Awinic 的 RTP / waveform，不是 qcom 的裸 i8 采样。因此 `haptics.rs` 新增 sysfs 后端：

```
/sys/bus/i2c/devices/5-005a/effect_id  ← 0
/sys/bus/i2c/devices/5-005a/duration   ← 16（点击）/ 10（熄屏 ticks）ms
/sys/bus/i2c/devices/5-005a/gain       ← 0x00–0x80
/sys/bus/i2c/devices/5-005a/activate   ← 1，睡 duration，再写 0
```

设置页的滑杆与触摸反馈都走 `Haptics::click`；`skyward haptic` 可直接测。

## 7. 补丁文件级说明

| 补丁 | 文件 | 改了什么 | 为什么 |
| --- | --- | --- | --- |
| `0001-windows-host-build.patch` | `crates/skyward-bootimg/src/ramdisk.rs` | 给 `Ramdisk::unpack` / `c_path` / `set_time` 及 imports 加 `#[cfg(unix)]`，测试模块改成 `#[cfg(all(test, unix))]` | 这些函数只在 Unix 上成立；宿主打包器只走内存里的 cpio，不需要它们。不加就无法在 Windows 上编 `skyward-pack` |
| `0002-omapi-se-bridge.patch` | `crates/skyward-binder/src/{driver,parcel,service}.rs` | binder 服务端：收 `BR_TRANSACTION`、回 `BC_REPLY`、等待期间处理回调、传 binder 对象、注册服务时 stability=3 | weaver 只走 OMAPI；recovery 没有 system_server 的 `omapiSeService`，只能自己起一个 |
|  | `crates/skyward/src/main.rs` | 加 `Omapi` / `Se` 两个子命令 | 手动起桥 / 探针，不进自动流程 |
|  | `crates/skyward/src/omapi.rs`（新文件） | `android.se.omapi` 的最小子集，转发到 SE HAL | 让 NXP weaver 能在 recovery 里查 eSE 槽位 |
| `0003-onyx-ce-fallback.patch` | `crates/skyward-crypto/src/data.rs` | 拆 `protector_ids` / `protector_named`；`open_user_files` 在 `WeaverUnusable` 时回退；抽出 `open_with_protector` | onyx user 0 有第二份 gatekeeper 绑定的 protector，不需要 weaver 就能拿 SP |
| `0004-onyx-v0.3.0-wifi-ui.patch` | 16 个文件（config / net / pack / UI / skyward） | OS4 路径校验、WLAN preload + EBUSY 重试 + 自动连接、AW8697 sysfs 振动、锁屏（每次亮屏）/ 双击亮屏 / AVB 页、Skyward 更新仓库、`--extra` | 本次 v0.3.0 的全部代码；细节见 `patches/README.md` |

补丁顺序固定，`scripts/bootstrap.sh` 按 `0001 → 0002 → 0003 → 0004` 应用。上游 commit 与每个补丁的说明见 [`patches/README.md`](../patches/README.md)。

---

## 8. 设备配置（`devices/onyx.toml`）

| 段 | 关键值 | 说明 |
| --- | --- | --- |
| `[device]` | `codename = "onyx"`、`ab = true`、`os_version_prop` | 设备身份与系统版本来源 |
| `[display]` | 1280 × 2772、density **512**、6.83" | 400 dp 宽；按屏高反推 1109 会让 UI 溢出 |
| `[modules]` | `sources = vendor_boot, vendor_dlkm, vendor, system_dlkm`；`load = nt38771_touch, xiaomi_touch` | 触摸与分区模块 |
| `[[service]]` × 7 | 见第 3 节 | 触摸 + 安全世界 + boot control |
| `[update]` | MIUI 更新服务器 + `skyward = "Remoparrot/skyward-onyx"` | 系统更新 + Skyward 自身更新 |
| `[wlan]` | `qca_cld3_wcn7750` + `rfkill`；`wpss_boot`；`preload`；系统优先的 `libraries` | WLAN 驱动、固件、supplicant |
| `[haptics]` | AW8697 的 `activate` / `duration` / `effect_id` / `gain` | 振动 |
| `[stock]` | `OS4.0.2.0.XOLCNXM`、全量包 URL、recovery SHA-256 | `skyward-pack stock` 用它按需取原厂 recovery |

---

## 9. 运行时目录

| 路径 | 内容 |
| --- | --- |
| `/skyward/device.toml` | 配置副本（ramdisk 内） |
| `/data/system_de/<user>/spblob/` | protector blobs（`.spblob` / `.pwd` / `.weaver` / `.secdis`） |
| `/data/misc/vold/user_keys/ce/<user>/current` | CE key（`encrypted_key` + `version`） |
| `/data/media/<user>` | 用户共享存储 |
| `/tmp` | 开发时 adb push 的临时二进制；不随镜像 |
| `/sys/fs/pstore` | 崩溃后的内核日志；黑屏排查先看这里 |

---

## 10. 相关文档

- 构建命令：[`03-build.md`](03-build.md)
- 刷入 / 回滚：[`04-install.md`](04-install.md)
- 为什么这样设计：[`05-design-notes.md`](05-design-notes.md)
- 踩过的坑：[`06-pitfalls.md`](06-pitfalls.md)
