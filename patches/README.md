# 补丁

相对上游 **Skyward v0.2.0** 的设备补丁，按编号顺序应用；0004 起是 v0.3.0 的 OS4 / WLAN / UI / 更新下载改动。

| 项 | 值 |
| --- | --- |
| 上游 | https://github.com/kirklin/skyward |
| 版本 | v0.2.0 |
| commit | `ff1668fdb72a46f22152a6540f49728c42081aba` |
| 基线 | 该 commit 的干净工作树 |
| 应用方式 | `git apply`（`scripts/bootstrap.sh` 自动按顺序执行） |

---

## 0001-windows-host-build.patch

**文件**：`crates/skyward-bootimg/src/ramdisk.rs`
**行数**：57

给只在 Unix 上成立的 `Ramdisk::unpack`、`c_path`、`set_time` 及其 imports 加 `#[cfg(unix)]`，测试模块改成 `#[cfg(all(test, unix))]`。

**为什么**：宿主侧 `skyward-pack` 只走内存里的 cpio，用不到这些函数；不加就无法在 Windows 上编打包器。手机侧二进制不受影响。

---

## 0002-omapi-se-bridge.patch

**文件**：

- `crates/skyward-binder/src/driver.rs`
- `crates/skyward-binder/src/parcel.rs`
- `crates/skyward-binder/src/service.rs`
- `crates/skyward/src/main.rs`
- `crates/skyward/src/omapi.rs`（新文件）

**行数**：1129

给 `skyward-binder` 补服务端能力（收 `BR_TRANSACTION`、回 `BC_REPLY`、等待期间处理回调、传 binder 对象），并在 `omapi.rs` 里实现 `android.se.omapi.ISecureElementService/default` 的最小子集，转发到 `android.hardware.secure_element.ISecureElement/eSE1`。

新增两个子命令：

```sh
skyward omapi   # 起桥接服务
skyward se      # 只探 SE HAL
```

**状态：实验性，不自动启动，不是 v4 解密主路径。** 卡在 SE HAL `init()` 等待 eSE TA；保留给 user 999 / 排错。详见 [`docs/05-design-notes.md`](../docs/05-design-notes.md)。

**硬约束**（改这个补丁前必读）：

- 服务 stability 必须是 `3`；
- AIDL 方法编号从 `1` 开始；
- 裸回包（`_NTF` / 版本 / 哈希 / pid / ping）前面不能有 status 字；
- 回调对象也要带 stability 3。

---

## 0003-onyx-ce-fallback.patch

**文件**：`crates/skyward-crypto/src/data.rs`
**行数**：131

- `protector()` 拆成 `protector_ids()` / `protector_named()`；
- `open_user_files()` 在 `WeaverUnusable` 时，遍历同用户其他 `Bound::Secdiscardable` + 有 `.pwd` 的 protector，用同一个 credential 走 gatekeeper 重试；
- 抽出 `open_with_protector()`；
- 新增 `WeaverUnusable` 错误类型。

**为什么**：onyx 的 user 0 有两份 protector，第二份绑 gatekeeper；weaver 在 recovery 里不可用时，用锁屏密码就能拿到同一个 SP，解开 CE。**这是 v4 能在真机上读相册 / 微信的原因。**

**边界**：

- 只在 `WeaverUnusable` 时回退，不把「密码错误」当成环境问题；
- 只挑 `Secdiscardable + lock.is_some()` 的 protector；
- user 999 只有 weaver 绑定，回退不适用。

---

## 0004-onyx-v0.3.0-wifi-ui.patch

**文件**：16 个（`Cargo.toml` / `Cargo.lock` / `skyward-config` / `skyward-net` / `skyward-pack` / `skyward-ui` / `skyward`）

**内容**：v0.3.0-onyx.1 的全部代码改动，按主题分四组：

1. **OS4 底包**：`[stock]` 换成 OS4.0.2.0；`Path::is_absolute` 改成 `has_root`，让宿主（Windows）也能校验手机侧绝对路径；版本号 `0.3.0-onyx.1`。
2. **WLAN + 自动连接**：`[wlan]` 的 `preload`、`wlan.rs` 的 `LD_PRELOAD` 与 `EBUSY` 重试、启动时自动开 WLAN / 加入上次网络、UI 的「自动连接」开关与保存网络（密码只写 `/metadata/skyward/settings.json`，0600）。
3. **Skyward 更新**：`[update].skyward = "Remoparrot/skyward-onyx"`，`github.rs` 的仓库地址由配置给出，版本对比用 `0.3.0-onyx.N`。
4. **UI**：锁屏 / 设置锁屏、控制中心、双击亮屏、AVB 2.0 禁用页、`skyward-pack --extra`（把 AIDL shim 装进 ramdisk）。

**WLAN shim**：vendor 的 `wpa_supplicant` 带 AIDL，recovery 的 servicemanager 不认它的注册（`AServiceManager_addService` 返回 `-129`，`EX_TRANSACTION_FAILED`），supplicant 在打开 per-interface socket 前就退出。`shim/wpa-aidl-shim.c` 把这次注册应答成 0；Skyward 只用 supplicant 的 per-interface control socket，不需要 AIDL 真的可用。shim 由 `scripts/build-phone.sh` 用 NDK 编译，`build-image.sh` 通过 `--extra` 放进 `skyward/wpa-aidl-shim.so`。

**注意**：AVB 页只实现、未在真机点过（用户明确要求不测试）。WLAN 密码在 `/metadata` 明文保存，文件权限 0600；recovery 内 adb 本来就是 root，这一点没有额外提高攻击面，但换机/共享镜像前应清掉。

---

## 0005-onyx-readings.patch

**文件**：8 个（`Cargo.toml` / `Cargo.lock` / `skyward-net/github.rs` / `skyward-ui/{app,pages,widgets}.rs` / `skyward/{ui,updates}.rs`）

**内容**：v0.3.0-onyx.2 的全部改动，两组：

1. **主界面机型卡片的数据条**（本次需求）：`skyward-ui/widgets.rs` 新增 `Reading` / `readings_of`，`device_card` 在机型名与副标题下、提示行上画四列读数（当前槽位 / 数据分区 / 可用空间 / 电量，第二行是说明）；`pages.rs` 的 `home()` 按现有读数拼出这四列，读不到的项（无 A/B、data 未挂载没 free、无电量计）自动省略，列数随之收缩；`Cargo.toml` 版本号 `0.3.0-onyx.2`。
2. **在线更新接受裸 `recovery.img` + 本地刷入**（上一轮未进补丁的工作）：`github.rs` 优先取 release 里名为 `recovery.img` 的 asset（没有才退回 `skyward-<tag>-onyx-*.zip`），`Build.raw` 标出是裸镜像；`updates.rs` 新增 `UpdateSkywardFile` 与 `write_raw` / `write_image` 拆解；`ui.rs` 处理 `Effect::UpdateSkywardLocal`；`app.rs` 新增 `Action::UpdateSkywardLocal` 与 `Effect::UpdateSkywardLocal`，把 `/sdcard/Download/recovery.img` 交给同一个写分区路径（本地刷入**不检查网络**）；`pages.rs` 的「Skyward 更新」页加「从本地 recovery.img 刷入」一行，在线那一行改名为「从 GitHub 下载 recovery.img 并更新」。

**为什么**：主界面只靠状态栏显示槽位 / data / 电量，太小且分散；机型卡片下的四列读数是按用户给的截图做的（截图来自别的机型构建，本仓库用自己的主题与 512 dpi 的 onyx 面板重画，尺寸按 `m.account_title_px` / `m.sub_px` 与卡片宽度四等分）。裸镜像与本地刷入则是「GitHub 直连不通时也能更新」的退路。

**边界**：本地刷入的路径写死 `/sdcard/Download/recovery.img`；`upgrade::check` 仍会核对镜像内 `device.toml` 的 codename，刷错机型的镜像会被拒绝，且什么都没写。

---

## 0006-onyx.3-fast-download.patch

**文件**：7 个（`Cargo.toml` / `Cargo.lock` / `skyward-net/{download,http}.rs` / `skyward-ui/{app,pages}.rs` / `skyward/src/ui.rs`）

**行数**：887

**内容**：v0.3.0-onyx.3 的全部改动，四组：

1. **并行下载**：`download.rs` 把带校验和的包（Skyward 更新、系统 OTA）按 64 KiB 分段，每段一个 `Range: bytes=start-end` 请求，最多 512 个连接同时写同一个文件（`write_at` 按偏移写，共享一个句柄）；全部写完再从头读一遍核对 SHA-256 / MD5。单段失败重试 4 次（200 ms×n 退避），服务端回 200（不认 Range）时整包退回单连接，停止/失败删除 `.part`。
2. **DNS 缓存**：`http.rs` 的自定义 `Lookup` 按 (host, port) 缓存 5 分钟，并在解析期间持锁避免并发查询；512 个连接不再各查一次 DNS（路由器的 DNS 会拒答突发查询）。
3. **可用空间读数**：`skyward/src/ui.rs` 在 `Decryptor` 报 `Opened(Ok)` / `Unlocked(Ok)` 后重新 `skyward_info::collect`，机型卡片「可用空间」不再因开机时 `/data` 未挂载而消失。
4. **更新页反馈**：`pages.rs` 新增 `skyward_job()`，进度/成功/失败从 `skyward_online()` 中独立出来，本地 `recovery.img` 刷入也显示进度卡与「更新成功 · 已将 Skyward 刷入槽位 B 的 recovery 分区」；`app.rs` 的 `SkywardJob` 新增 `local: bool`，本地刷入的版本未知，文案不写版本号。

**为什么**：Skyward 更新此前是单连接顺序下载，GitHub 直连实测约 40 KB/s，45.85 MB 要 17 分钟；分段并行后同样一个包 17.2 秒。DNS 缓存与 `.part` 清理是 512 连接的必然配套：前者避免 DNS 拒答，后者避免并行写入留下的空洞被当成可续传的前缀。

**边界**：并行下载不续传（停止/失败删 `.part`）；512 是上限，实际连接数 = min(512, ⌈包大小/64 KiB⌉)；系统 OTA 同走这条路但未真机完整下载过。

---

## 应用

```sh
scripts/bootstrap.sh
```

手动：

```sh
git clone https://github.com/kirklin/skyward.git vendor/skyward
git -C vendor/skyward checkout ff1668fdb72a46f22152a6540f49728c42081aba
for p in patches/*.patch; do
  git -C vendor/skyward apply --check "$p"
  git -C vendor/skyward apply "$p"
done
```

## 验证

在一个干净的上游工作树上：

```sh
git -C vendor/skyward apply --check patches/0001-windows-host-build.patch
git -C vendor/skyward apply --check patches/0002-omapi-se-bridge.patch
git -C vendor/skyward apply --check patches/0003-onyx-ce-fallback.patch
git -C vendor/skyward apply --check patches/0004-onyx-v0.3.0-wifi-ui.patch
git -C vendor/skyward apply --check patches/0005-onyx-readings.patch
git -C vendor/skyward apply --check patches/0006-onyx.3-fast-download.patch
```

六个都过，且应用后 `crates/` 与发布镜像对应的源码一致（v0.3.0-onyx.3 用 `diff -r --strip-trailing-cr` 对过，除 `.git` / `target` / `.onyx-patched` 外完全一致）。

## 修改 / 新增补丁

不要直接改 `vendor/skyward/` 后发版。流程：

1. 在 `vendor/skyward` 里改代码并验证；
2. `git -C vendor/skyward diff > /tmp/new.patch`（新文件先 `git add -N`）；
3. 把 diff 按逻辑拆进 `patches/`，或新增 `0004-*.patch`；
4. 删掉 `vendor/skyward`，重新 `bootstrap.sh`，确认能干净应用；
5. 更新本文件、`docs/03-build.md`、`docs/07-changelog.md`。

## 上游升级

1. 改 `bootstrap.sh` 与 `patches/README.md` 里的 commit；
2. 逐个重放补丁，冲突时优先看上游是否已经修了同一个问题；
3. 重新构建 + 真机回归（触摸、`/data`、CE、回滚）；
4. 更新 `NOTICE.md` 的版本号和 `docs/07-changelog.md`。
