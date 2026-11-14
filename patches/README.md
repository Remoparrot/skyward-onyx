# 补丁

相对上游 **Skyward v0.3.1** 的设备补丁，按编号顺序应用。

| 项 | 值 |
| --- | --- |
| 上游 | https://github.com/kirklin/skyward |
| 版本 | v0.3.1 |
| commit | `bd34c05`（`chore: release 0.3.1`） |
| 基线 | 该 commit 的干净工作树 |
| 应用方式 | `git apply`（`scripts/bootstrap.sh` 自动按顺序执行） |

> 上游从 v0.3.0 起重写了 UI 的页面状态机（`skyward-ui/src/app.rs` → `app/*.rs`）、把「手机自己的程序」改成从系统分区自动发现（`skyward-programs`），并自带 `skyward-omapi` 与 binder 服务端。因此旧的 `0002-omapi-se-bridge` 与 `0007-browser` 两个补丁**不再需要**，onyx 的密钥服务配置也从「写死 6 个服务」改成「交给上游发现」。

---

## 0001-windows-host-build.patch

**文件**：`crates/skyward-bootimg/src/ramdisk.rs`、`crates/skyward-pack/{Cargo.toml,src/main.rs}`

**行数**：约 150

1. 给只在 Unix 上成立的 `Ramdisk::unpack`、`c_path`、`set_time` 及其 imports 加 `#[cfg(unix)]`，测试模块改成 `#[cfg(all(test, unix))]`；
2. 把 `skyward-pack` 的 `described` 子命令做成 feature `described`（默认开）：它依赖 `skyward-programs`，而后者在 Windows 上编不过（要 libc 的 Unix 接口）。宿主侧只打镜像，用 `--no-default-features` 编译即可；`scripts/build-pack.sh` 已经这样调用。

**为什么**：宿主侧 `skyward-pack` 只走内存里的 cpio 与配置文件；Windows 上要能编。手机侧二进制不受影响。

---

## 0002-onyx-ce-fallback.patch

**文件**：`crates/skyward-crypto/src/data.rs`
**行数**：约 90

- `protector()` 拆成 `protector_ids()` / `protector_named()`；
- `open_user_files()` 在 `WeaverUnusable` 时，遍历同用户其他 `Bound::Secdiscardable` + 有 `.pwd` 的 protector，用同一个 credential 走 gatekeeper 重试；
- 抽出 `open_with_protector()`；
- 新增 `WeaverUnusable` 错误类型。

**为什么**：onyx 的 user 0 有两份 protector，第二份绑 gatekeeper；weaver 在 recovery 里不可用时，用锁屏密码就能拿到同一个 SP，解开 CE。**这是 v4 起能在真机上读相册 / 微信的原因，也是这次 0.3.1 上唯一必须保留的解密补丁。**

**边界**：

- 只在 `WeaverUnusable` 时回退，不把「密码错误」当成环境问题；
- 只挑 `Secdiscardable + lock.is_some()` 的 protector；
- user 999 只有 weaver 绑定，回退不适用。

---

## 0003-onyx-config-wlan-haptics.patch

**文件**：`crates/skyward-config/src/lib.rs`、`crates/skyward-programs/src/secure.rs`、`crates/skyward/src/{haptics,main,settings,wlan}.rs`

**行数**：约 250

1. **配置**：`[wlan] preload`（`LD_PRELOAD` 的 AIDL shim 路径）、`[update] skyward`（自更新仓库，`owner/name`）、`[haptics] activate/duration/effect/gain`（AW8697 的力反馈接口）；`Path::is_absolute` 改成 `has_root`，让宿主（Windows）也能校验手机侧绝对路径。
2. **密钥服务的库路径**：`skyward-programs` 给 `/vendor` 程序找库时，在 `/system/lib64:/vendor/lib64` 之后再加上 `/vendor/lib64/hw`、`/mnt/system/system/lib64`、`/mnt/system/system/lib64/bootstrap`。Android 17 的 recovery 里没有 `libvndksupport.so`，keymint 会 `CANNOT LINK EXECUTABLE ... library "libvndksupport.so" not found` 后退出 1；补上安装系统 /system 的库目录后正常。**这是 0.3.1 上 data 能不能解开的关键。**
3. **WLAN**：`wlan.rs` 的 `LD_PRELOAD` 与 `EBUSY` 重试、启动时自动开 WLAN / 加入上次网络、5 GHz 的 `country` / `disable_scan_offload=1` / `sae_pwe=2`；密码只写 `/metadata/skyward/settings.json`，0600。
4. **振动**：AW8697 的 `activate` / `duration` / `gain` 路径与播放。
5. **设置**：`skyward/src/settings.rs` 读写新增的锁屏、记住密码、上次 WLAN 等字段。
6. **启动**：正常进 recovery 首屏直接是「解密」页，解密前不锁屏。

---

## 0004-onyx-updates-downloads.patch

**文件**：`crates/skyward-net/src/{download,github,http,supplicant}.rs`、`crates/skyward/src/updates.rs`

**行数**：约 450

1. **并行下载**：`download.rs` 把带校验和的包按 64 KiB 分段，每段一个 `Range: bytes=start-end` 请求，最多 512 个连接同时写同一个文件；全部写完再从头核对 SHA-256 / MD5；服务端不认 Range 时退回单连接；停止/失败删除 `.part`。
2. **DNS 缓存**：`http.rs` 的自定义 `Lookup` 按 (host, port) 缓存 5 分钟，512 个连接不再各查一次 DNS。
3. **Skyward 自更新**：`github.rs` 的仓库地址由 `[update].skyward` 给出（默认上游仓库），优先取 release 里名为 `recovery.img` 的裸镜像（没有才取 `skyward-<tag>-<codename>-*.zip`），`Build.raw` 标出是裸镜像；`updates.rs` 新增 `UpdateSkywardFile`（本地 `/sdcard/Download/recovery.img`）与 `write_raw` / `write_image` 拆解。
4. **DNS 多服务器**：上游的「一个 DNS 服务器不答就试下一个」保留。

---

## 0005-onyx-ui.patch

**文件**：`crates/skyward-ui/**`（`app/*.rs`、`pages.rs`、`widgets.rs`、`settings.rs`、`canvas.rs` 等）、`crates/skyward-preview/src/main.rs`、`crates/skyward/src/ui.rs`

**行数**：约 2,100

v0.3.0-onyx.1 … onyx.5 的 UI 改动移植到上游 0.3.1 的页面状态机上：

- **锁屏**：`Screen::{Lock,LockSet}`，每次息屏再点亮（data 已解密）先显示锁屏；无密码为滑动解锁，设置 4–8 位 recovery 密码后改数字键盘；只存 salt + SHA-256；背景是上一页的模糊快照（1/10 采样 + 盒式模糊 + 拉伸），强度 0–1 可调；滑块拖动时重画所在行，避免「背后一块纯色」。
- **首页机型卡片读数**：当前槽位 / 数据分区 / 可用空间 / 电量，读不到的项省略；解密完成后补上可用空间。
- **解密页**：自动打开 `/data`；「记住密码」后下次自动解密 user 0；解密完成倒计时 3 秒回主界面；只等 user 0，不被 999 卡住。
- **下载页**：网址输入、`/sdcard/Download/link.txt`、二维码回传（内置 HTTP 页面，端口 8080–8089）、进度/暂停/继续/停止；按键盘「确定」打开纯文本网页页（标题/正文）。
- **更新页**：在线更新（优先裸 `recovery.img`）与「从本地 recovery.img 刷入」，进度卡与结果。
- **双击亮屏**、**AVB 2.0 禁用页**、**设置项**（锁屏、锁屏模糊、双击、记住密码、WLAN 自动连接）。
- **面板不 rest**：onyx 的面板从 rest/off 回来是黑屏，息屏只关背光、面板保持点亮。
- **`wpa-aidl-shim.so` 的打包**：`skyward-pack recovery --extra`（见 0001 之外的 `pack` 改动在本补丁的 `main.rs` 部分）。

---

## 0006-onyx-version.patch

**文件**：`Cargo.toml`、`Cargo.lock`

**行数**：约 250

把 workspace 版本改成 `0.3.1-onyx.1`，并更新 `Cargo.lock`（新增 `qrcodegen`、`sha2` 等依赖）。

---

## 应用

```sh
scripts/bootstrap.sh
```

手动：

```sh
git clone https://github.com/kirklin/skyward.git vendor/skyward
git -C vendor/skyward checkout bd34c05
for p in patches/*.patch; do
  git -C vendor/skyward apply --check "$p"
  git -C vendor/skyward apply "$p"
done
```

## 验证

在一个干净的上游工作树上（`bd34c05`）依次 apply 六个补丁，结果与 `vendor/skyward` 的当前树逐字一致（2026-11-14 用 `git write-tree` 比对：两边 tree 相同）。

## 修改 / 新增补丁

不要直接改 `vendor/skyward/` 后发版。流程：

1. 在 `vendor/skyward` 里改代码并验证；
2. `git -C vendor/skyward diff`（新文件先 `git add -N`）；
3. 把 diff 按路径/主题拆进 `patches/`；
4. 删掉 `vendor/skyward`，重新 `bootstrap.sh`，确认能干净应用；
5. 更新本文件、`docs/03-build.md`、`docs/07-changelog.md`。

## 上游升级

1. 改 `bootstrap.sh` 与 `patches/README.md` 里的 commit；
2. 用 `git diff <旧commit> <新commit>` 看上游改了什么，逐个重放补丁，冲突时优先看上游是否已经修了同一个问题；
3. 特别注意：上游若再次重排 UI 的 `app/` 模块或改服务发现，`0005` 与 `0003` 的库路径要重新对；
4. 重新构建 + 真机回归（触摸、`/data`、CE、WLAN、回滚）；
5. 更新 `NOTICE.md` 的版本号和 `docs/07-changelog.md`。
