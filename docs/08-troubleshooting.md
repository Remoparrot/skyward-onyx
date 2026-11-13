# 排错

> 状态：**现行**
> 原则：**先收集证据，再动手；不要急着重刷，更不要 wipe。**

---

## 0. 先收集什么

```sh
# 设备在不在
adb devices
fastboot devices

# 内核 / recovery 日志
adb shell dmesg | tail -100
adb shell logcat -d | tail -200

# 崩溃残留
adb shell ls -l /sys/fs/pstore
adb shell cat /sys/fs/pstore/console-ramoops-0 2>/dev/null | tail -100

# 镜像结构
skyward-pack list recovery.img | head -3
skyward-pack list recovery.img | grep -E 'system/bin/recovery|skyward/'

# 哈希
sha256sum recovery.img
```

把「现象 + 上面命令的输出」一起看，不要只描述「起不来」。

---

## 1. 刷入后进不了 recovery，但能进系统

**症状**：`fastboot reboot recovery` 后黑屏 / 停在小米 logo / 直接进系统。

**检查**：

```sh
fastboot getvar current-slot
fastboot flash recovery recovery.img
fastboot reboot recovery
```

**可能原因与处置**：

| 原因 | 处置 |
| --- | --- |
| 刷错分区 / 刷到旧 slot | 确认 `fastboot flash recovery` 输出 `OKAY`；A/B 设备可试 `fastboot --set-active=a` 后再刷 |
| 镜像损坏 | 重新下载，核对 SHA-256 |
| 底包不是 OS3.0.306.0 | 换回匹配底包，或刷 stock |
| recovery 分区大小不对 | `verify-image.sh` 必须显示 104,857,600 |

**兜底**：刷回 `recovery-stock-OS3.0.306.0.WOLCNXM.img`，手机照常进系统。

---

## 2. 黑屏 / 自动重启

**症状**：recovery 里突然黑屏、adb 断开、按键无反应；或整机重启。

**已知原因**：

- 执行了 `setprop ctl.stop recovery`（两次实测都重启；**不要再用**）；
- 早期 OMAPI / eSE 测试触发过（`init()` 卡住后继续碰 TEE）；
- 其他原因未查清：`pstore` 为空，`bootinfo.pureason=0x40001`。

**处置**：

1. 长按电源重启；
2. 进系统后 `adb shell cat /sys/fs/pstore/console-ramoops-0`，或 recovery 里 `adb shell dmesg | tail`；
3. 如果发生在刷入新镜像后，刷回上一个版本 / stock；
4. 记录「黑屏前最后一条命令」，写进会话记录。

**不要**：连续反复刷同一个镜像、在 recovery 里跑不认识的命令。

---

## 3. 触摸没反应

**症状**：界面能显示，但点 / 滑都没反应。

**检查**：

```sh
adb shell getevent -lt /dev/input/event7   # 滑动 10 秒，看有没有事件
adb shell ps -A | grep touch_report
adb shell dmesg | grep -iE 'touch|input'
```

**判断**：

- `getevent` 零事件 + `touch_report_debug` 没进程 → 服务没起来；
- 服务起了但仍无事件 → `libtouchreport.so` / firmware 配置路径不对；
- 有事件但 UI 不动 → skyward 的 input 层问题，不是触摸服务。

**处置**：

- 确认 `devices/onyx.toml` 里是 `/odm/bin/touch_report_debug`（不是 `touch_report`）；
- 确认 `/odm/lib64/libtouchreport.so`、`/odm/firmware/o10u_nova_csot_thp_config.ini` 存在；
- 看 `dmesg` 里 `devices not brought up` 的具体原因；
- 早期 v2 的屏幕诊断页会直接把结果打出来。

---

## 4. 解密时提示密码错误

**症状**：输入锁屏密码后提示错误 / 一直转圈。

**先排除**：

- 密码确实是系统当前的锁屏密码（不是小米账号密码）；
- 输入法 / 大小写 / 数字键盘没问题；
- 没有连续试太多次（gatekeeper 可能限流）。

**如果确定密码对**：

```sh
adb shell ls -l /data/system_de/0/spblob/
adb shell dmesg | grep -iE 'gatekeeper|weaver|keymint|skyward'
```

看：

- 是否有第二份 `.secdis` + `.pwd`（v4 依赖它）；
- 日志里是 `WeaverUnusable` 还是 `gatekeeper` 拒绝；
- `Failed to retrieve slots info` → weaver 仍不可用，但 v4 本不该走 weaver；
- 如果只有 `.weaver` 没有 `.secdis`，说明这台机器 / 这个用户没有回退路径（例如 user 999）。

**处置**：

- 用户 999 打不开是已知限制；
- user 0 只有 `.weaver` 时，需要 OMAPI 桥（未完成），不要反复试密码；
- 记录 `spblob` 文件列表和错误日志，再判断。

---

## 5. `/data` 挂载了，但 `/data/media/0` 还是密文

**症状**：文件管理里能看到 `/data`，但 `0/` 下文件名乱码，读文件报 `Required key not available`。

**含义**：设备级（DE）解了，用户级（CE）没解。

**检查**：

```sh
adb shell ls -l /data/system_de/0/spblob/
adb shell ls -l /data/misc/vold/user_keys/ce/0/current/
adb shell dmesg | grep -iE 'fscrypt|key|skyward|ce'
```

**处置**：

- 走「解密」页重新输入密码；
- 看日志里回退是否发生（`WeaverUnusable` → 第二份 protector → gatekeeper）；
- 如果报 `the phone keeps user 0's secret behind the blob ... which is not among ...`，说明系统记录的 protector 与文件不一致，记录后反馈；
- 不要 `rm` / `mv` `spblob` 里的任何文件。

---

## 6. user 999 解不开

**症状**：user 0 正常，第二空间 / 应用分身（999）全是密文。

**原因**：999 只有 weaver 绑定的 protector，没有 gatekeeper 回退；recovery 没有 eSE 通道。

**处置**：目前不支持。不要尝试改 999 的 `spblob`，会破坏系统对该用户的解锁。

---

## 7. adb 连不上

| 现象 | 检查 | 处置 |
| --- | --- | --- |
| `adb devices` 空 | 数据线 / 驱动 / USB 调试 | 换线、换口；Windows 装小米 USB 驱动 |
| `unauthorized` | recovery 的 adb 是 root 免授权 | 正常不应出现；重启 recovery |
| `device offline` | adb 版本 / 进程 | `adb kill-server && adb devices` |
| 系统里能连，recovery 不能 | 驱动模式切换 | 重新插拔；看设备管理器 |

---

## 8. fastboot 不识别

```sh
fastboot devices
```

- 空：换线 / 换 USB 2.0 口；Windows 装驱动；手机关机后音量下 + 电源；
- `waiting for any device`：驱动没装好；
- 能识别但 `flash` 失败：看具体错误（分区不存在 / 镜像大小不对 / 未解锁）。

---

## 9. 镜像哈希不对

```sh
sha256sum recovery.img
```

与 Release 的 `SHA256SUMS` 对比。不一致：

- 重新下载（浏览器 / `curl -L`）；
- 确认没有被网盘 / 聊天软件改写过；
- 自己编的镜像哈希不同是正常的（见 [`03-build.md`](03-build.md) 第 8 节），但结构校验必须过。

---

## 10. 没有 WLAN / 振动

**原因**：`devices/onyx.toml` 没有 `[wlan]` / 振动段，Skyward 的设置页就不会出现对应入口。

**处置**：

- 需要真机核对固件路径 / sysfs 后再补配置；
- 不要凭别的机型抄 `[wlan]`，路径不对会让服务起不来，甚至中断启动。

---

## 11. 构建失败

见 [`03-build.md`](03-build.md) 第 10 节的错误表。最常见的三个：

- `cargo: not found` → PATH；
- `dlltool` 临时目录 → 用 `scripts/env.sh`；
- `lz4: command not found` → 放进 PATH。

---

## 12. 需要回滚时

```sh
fastboot flash recovery recovery-stock-OS3.0.306.0.WOLCNXM.img
fastboot reboot
```

回滚只动 recovery 分区，不影响系统与数据。回滚后如果系统 OTA 提示更新，可以正常更。

---

## 13. 仍然解决不了

收集：

1. 机型 / 底包 / 镜像 SHA-256；
2. 复现步骤（从哪一步开始）；
3. `adb shell dmesg | tail -100`；
4. `adb shell ls -l /data/system_de/0/spblob/`（只列文件名，不要上传 blob 内容）；
5. 屏幕照片 / 报错文字。

**不要**上传：锁屏密码、账号、设备序列号、`spblob` / `secdis` / `.pwd` 的完整内容。
