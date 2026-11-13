# 补丁

相对上游 **Skyward v0.2.0** 的设备补丁，按编号顺序应用；0004 起是 v0.3.0 的 OS4 / WLAN / UI 改动。

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
```

四个都过，且应用后 `crates/` 与发布镜像对应的源码一致。

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
