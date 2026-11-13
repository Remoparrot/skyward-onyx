# 安装、解密与回滚

> 状态：**现行**
> 适用：Redmi Turbo 4 Pro（`onyx`）· 底包 OS4.0.2.0.XOLCNXM
> 风险等级：**中**（只写 recovery 分区；但 recovery 内的 adb 是 root）

---

## 0. 先读这一段

- 需要**已解锁 bootloader**；未解锁请先按小米官方流程解锁（会清数据，且等待期因账号而异）。
- 本镜像**只写 recovery 分区**，不动 boot / system / vendor / userdata。即使 recovery 起不来，手机仍能正常进系统，刷回官方 recovery 即可。
- **第一次刷之前备份重要数据**。虽然本项目的验证过程没有改动 `/data`，但任何刷机都有风险。
- recovery 里的 adb 是 **root 且无需手机授权**；手机处于 recovery 时，任何人拿到手机 + 数据线都能读存储。刷完请重启回系统。
- **不要**执行 `setprop ctl.stop recovery`：本机实测两次都会导致整机重启（原因未查清）。
- 只在 `OS4.0.2.0.XOLCNXM` 上验证过。换底包后服务路径 / VINTF 可能变化，不要直接套用。

---

## 1. 下载与校验

从 [Releases](https://github.com/Remoparrot/skyward-onyx/releases) 下载：

| 文件 | 用途 | SHA-256 |
| --- | --- | --- |
| `recovery.img` | 要刷的 Skyward recovery | `baf93862fc3f8eebf04a82b4d250c985c5b3e77523e14e6358e82c6d947078b0` |
| `recovery-stock-OS4.0.2.0.XOLCNXM.img` | 回滚用官方 recovery | `ce53850714fe2ca9ab22600a00e71813df2775dc94244192c83a224d7ecd3357` |
| `skyward-v0.3.0-onyx.1-onyx-OS4.0.2.0.XOLCNXM.zip` | 官方格式 zip（内含同一个 img，供在线更新） | `0d0c2f035b73189484b3bb8f44341dd70bf347018da2ab0a9ec60d732b54dbb5` |
| `SHA256SUMS` | 校验和 | — |

```sh
sha256sum -c SHA256SUMS --ignore-missing
```

Windows PowerShell：

```powershell
Get-FileHash .\recovery.img -Algorithm SHA256
```

哈希不对就不要刷。

---

## 2. 进 fastboot

```sh
adb devices           # 确认手机在系统里能被识别
adb reboot bootloader
fastboot devices      # 应看到一串序列号 + fastboot
```

`adb` 不可用时：关机后按住 **音量下 + 电源** 进 fastboot。

---

## 3. 刷入

```sh
fastboot flash recovery recovery.img
fastboot reboot recovery
```

说明：

- onyx 是 A/B 设备，但有独立的 `recovery` 分区；`fastboot flash recovery` 写当前 slot 的 recovery；
- 不要 `fastboot flash boot` / `system` / `super`；
- 刷完第一次启动可能比平时慢几秒，属于正常。

无法用命令进 recovery 时：关机后按住 **音量上 + 电源**，看到小米 logo 后松开。

---

## 4. 第一次进入

正常情况下应该看到：

- 首屏是 **解密**：Skyward 自动打开 `/data`；有 recovery 锁屏时先显示锁屏；
- 解锁 / 打开后首页有 `Redmi Turbo 4 Pro` / `onyx` / `OS4.0.2.0…` 的设备卡；
- 触摸可用（点击、滑动都正常）；
- 顶部状态栏、深浅色切换正常；
- 「安装」「备份」「文件」「终端」等入口在。

### 4.1 解密 `/data`

1. 正常进 recovery 会**自动停在「解密」页**（也可从首页的解锁入口进）；
2. 输入**与系统相同的锁屏密码 / PIN**；
3. 等待挂载完成；
4. 返回文件管理，`/data/media/0` 应出现真实文件名（相册、Download、微信目录）。

判断成功的标志：

- `/data` 已挂载；
- `/data/media/0/DCIM` 里的 JPEG 能打开（文件头 `ffd8ffe1` 正常）；
- `/data/data/com.tencent.mm` 可读；
- `/data/media/0/Android/data/com.tencent.mm` 可读。

失败时不要连续试很多次；先看 [`08-troubleshooting.md`](08-troubleshooting.md)。

> user 999（第二空间 / 应用分身）打不开是**已知限制**，不是密码错。

### 4.1.1 WLAN 与自动连接

- 开机自动打开 WLAN；连上过一次的网络会保存，下次启动自动加入；
- 密码存在 `/metadata/skyward/settings.json`（0600）；换机 / 共享镜像前删掉这个文件；
- 设置页的「WLAN」可扫描、加入、断开；「自动连接」开关控制下次启动是否自动加入。

### 4.1.2 recovery 锁屏

- 设置 → 安全 → 「恢复模式锁屏」可设 4–8 位数字；
- 只保存 salt + SHA-256，不保存明文；
- 开机先锁屏，解锁后才自动打开 `/data`；
- 忘记密码时，可在 recovery 的 adb root 下删 `/metadata/skyward/settings.json` 的 `lock` 字段（或整个文件）。

### 4.2 用 adb（可选）

```sh
adb devices
adb shell
# recovery 内是 root
```

开发时把二进制推到 `/tmp` 跑，不要反复刷机：

```sh
adb push skyward /tmp/skyward
adb shell chmod +x /tmp/skyward
adb shell /tmp/skyward data --user 0   # 具体子命令以 --help 为准
```

> 二进制**不要命名成 `recovery`**：skyward 会按 argv[0] 判断「我是不是被 init 拉起的 recovery」，名字是 `recovery` 时会忽略子命令、把整个 recovery 再起一遍，和已有服务抢硬件。用 `skyward` / `sw` 之类的名字。

---

## 5. 回滚

任何时候都可以刷回官方 recovery：

```sh
fastboot flash recovery recovery-stock-OS4.0.2.0.XOLCNXM.img
fastboot reboot
```

或者刷回旧的 v3（本机保留，不在 Release）：

```sh
fastboot flash recovery recovery-v3-backup.img
```

回滚只影响 recovery 分区，不影响系统与数据。

---

## 6. 更新 / 换版本

- **不要**在 recovery 里停服务再换 UI 版本（会重启整机）；
- 直接刷整分区镜像：

  ```sh
  fastboot flash recovery 新版本.img
  fastboot reboot recovery
  ```

- 刷之前记下当前镜像的 SHA-256，方便回退；
- 如果新版本起不来，刷回上一个版本或官方 stock。

---

## 7. 卸载

严格说没有「安装」，只是换了 recovery 分区：

```sh
fastboot flash recovery recovery-stock-OS4.0.2.0.XOLCNXM.img
```

刷回官方后，系统 OTA 可以正常覆盖 recovery。

---

## 8. 安全与数据

| 风险 | 说明 | 处置 |
| --- | --- | --- |
| 数据丢失 | 正常刷 recovery 不动 userdata；误操作 `wipe` / `mkfs` 会 | 不要执行不认识的命令；先备份 |
| 隐私 | recovery 内 adb 是 root，无授权 | 用完重启回系统；不要把手机留在 recovery 借给别人 |
| 变砖 | 只写 recovery 分区，boot/system 不动；最坏是进不了 recovery | 刷回 stock recovery |
| 底包不匹配 | 服务路径 / VINTF 变化，可能起不来 | 只在 OS4.0.2.0.XOLCNXM 上用 |
| 黑屏重启 | 停 recovery 服务会触发；其他原因未查清 | 不要停服务；看 `dmesg` / `pstore` |

---

## 9. 刷入后检查单

```markdown
- [ ] `fastboot flash recovery` 输出 OKAY
- [ ] `fastboot reboot recovery` 后能看到 Skyward 首页
- [ ] 设备卡显示 onyx / OS4.0.2.0
- [ ] 触摸可点、可滑
- [ ] 「解密」输入锁屏密码后 `/data/media/0` 有真实文件名
- [ ] 相册 JPEG 能打开
- [ ] 微信目录可读
- [ ] 回滚镜像在手（stock recovery）
```

任何一项不符合，先看 [`08-troubleshooting.md`](08-troubleshooting.md)，不要急着重刷。
