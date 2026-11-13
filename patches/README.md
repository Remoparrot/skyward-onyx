# 补丁

相对上游 **Skyward v0.2.0** 的设备补丁，按编号顺序应用。

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
```

三个都过，且应用后 `crates/` 与发布镜像对应的源码一致。

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
