# 构建

> 状态：**现行**
> 对应版本：`v0.3.0-onyx.1`
> 参考环境：Windows 10/11 + MSYS2 bash；Linux 理论可行但未实测。

---

## 1. 需要什么

| 组件 | 版本 / 位置 | 用途 |
| --- | --- | --- |
| Rust | 1.99.1，宿主 `x86_64-pc-windows-gnu`，target `aarch64-linux-android` | 编手机侧二进制 + 宿主打包器 |
| Android NDK | r29（29.0.14206865） | 交叉编译手机侧 |
| MinGW-w64 | gcc 16.2.0 + binutils 2.47 | Windows 上链接宿主 `skyward-pack` |
| lz4 | 1.10.0，在 `PATH` 上 | 打包 ramdisk |
| git | 任意较新版本 | 取上游、打补丁 |
| bash | Git for Windows 或 MSYS2 | 跑脚本 |
| 磁盘 | ≥ 2 GB（上游源码 + 三个 target + 镜像） | |

不需要：AOSP 源码树、Gradle、Soong、Android Studio。

### 安装要点（Windows）

```powershell
# Rust（gnu 宿主 + Android target）
rustup toolchain install stable-x86_64-pc-windows-gnu --profile minimal
rustup target add aarch64-linux-android --toolchain stable-x86_64-pc-windows-gnu

# Rust 的 bin 目录进 PATH
$env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
```

- **NDK r29**：解压到任意目录，`export ANDROID_NDK=<ndk 根>`；目录下应有 `toolchains/llvm/prebuilt/windows-x86_64/bin/clang.exe`。
- **MinGW-w64**：MSYS2 的 `mingw-w64-x86_64-gcc` + `mingw-w64-x86_64-binutils`；如果不在默认路径，`export MINGW_BIN=/d/msys2/mingw64/bin`。
- **lz4**：官方 Windows 版解压后把 `lz4.exe` 放进 `PATH`（或仓库的 `tools/` 并 `export PATH="$PWD/tools:$PATH"`）。

脚本会自检：

```sh
export ANDROID_NDK=/path/to/android-ndk-r29
scripts/check-deps.sh
```

---

## 2. 取源码与补丁

```sh
git clone https://github.com/Remoparrot/skyward-onyx.git
cd skyward-onyx

scripts/bootstrap.sh
```

它做三件事：

1. `git clone https://github.com/kirklin/skyward.git vendor/skyward`；
2. 检出固定 commit `ff1668fdb72a46f22152a6540f49728c42081aba`（v0.2.0）；
3. 按顺序应用 `patches/0001`–`0004`，并写 `vendor/skyward/.onyx-patched` 标记。

重来一遍：

```sh
rm -rf vendor/skyward
scripts/bootstrap.sh
```

> 不要直接改 `vendor/skyward/` 后发版：下次 bootstrap 会覆盖。要改代码，改 `patches/`，并在上游源码里验证后再生成新补丁。

---

## 3. 编译三件套

```sh
export ANDROID_NDK=/path/to/android-ndk-r29

scripts/build-pack.sh          # 宿主：build/host/release/skyward-pack[.exe]
scripts/build-phone.sh         # 手机：build/phone/aarch64-linux-android/release/skyward
                               # 同时编出 build/phone/wpa-aidl-shim.so（WLAN 的 LD_PRELOAD 小库）
scripts/build-system-init.sh   # 手机：build/system-init/aarch64-linux-android/release/system-init
```

三个 `target` 目录分开，互不污染。第一次会从 crates.io 拉依赖，时间取决于网络。

产物自检：

```sh
NDK_BIN="$ANDROID_NDK/toolchains/llvm/prebuilt/windows-x86_64/bin"

# skyward 是 aarch64 PIE，解释器 /system/bin/linker64
"$NDK_BIN/llvm-readelf" -h build/phone/aarch64-linux-android/release/skyward | grep 'Type:'
"$NDK_BIN/llvm-readelf" -l build/phone/aarch64-linux-android/release/skyward | grep -i interpreter

# system-init 静态链接，不能依赖 recovery 里没有的 .so
file build/system-init/aarch64-linux-android/release/system-init
```

---

## 4. 取原厂 recovery

```sh
scripts/fetch-stock.sh
```

`skyward-pack stock` 会读 `devices/onyx.toml` 的 `[stock]` 段，按 HTTP Range **只下载 recovery 分区那一段**（约 25 MB），下载完核对配置里的 `recovery` SHA-256，写到 `stock/recovery.img`。

- 官方全量包：`onyx-ota_full-OS4.0.2.0.XOLCNXM-user-17.0-dbe344d29d.zip`
- 期望 SHA-256：`99047b63a1b72e049617f9a2615778c0833899759ede92a7ec32454b722549a2`

网络取不到时，直接从 Release 下载 `recovery-stock-OS4.0.2.0.XOLCNXM.img`，重命名成 `stock/recovery.img` 即可（哈希一致）。

> 不要用别的底包的 recovery。换底包等于换服务路径、VINTF 和 AVB footer，本仓库的配置不保证适用。

---

## 5. 打镜像

```sh
scripts/build-image.sh
```

默认输入：

| 输入 | 默认路径 |
| --- | --- |
| stock | `stock/recovery.img` |
| skyward | `build/phone/aarch64-linux-android/release/skyward` |
| system-init | `build/system-init/aarch64-linux-android/release/system-init` |
| packer | `build/host/release/skyward-pack[.exe]` |
| config | `devices/onyx.toml` |
| 字体 | `vendor/skyward/resources/fonts/…` |

输出：

```
out/skyward-v0.3.0-onyx.1-OS4.0.2.0.XOLCNXM.img
```

脚本会检查大小必须正好 `104857600`，并打印 SHA-256。

校验：

```sh
scripts/verify-image.sh out/skyward-v0.3.0-onyx.1-OS4.0.2.0.XOLCNXM.img
```

它会检查：

- 大小 104,857,600；
- 头部 `header v4  kernel 0 bytes  ramdisk …`；
- `system/bin/recovery`、`skyward/system-init`、`skyward/device.toml`、`skyward/wpa-aidl-shim.so`、`skyward/MiSansVF.ttf` 存在；
- 打印 ramdisk 条目数与 SHA-256；给第二个参数时与预期哈希比对。

参考构建的输出：

```
大小：104857600 字节
header v4  kernel 0 bytes  ramdisk 50625278 bytes  OsVersionPatch(0.0.0, 2000-00)
ramdisk 条目：1062
SHA-256：14c5311aa2e70c8d419da0fafcbb7b0670ece1dc4d586cb0f7454b96068efb5a
```

---

## 6. 打包器到底做了什么

`skyward-pack recovery` 的步骤：

1. 读 stock recovery 的 boot header v4，解出 LZ4 ramdisk 与 cpio；
2. 保留原厂的 init、adbd、SELinux policy、库、`res/`；
3. 把 `system/bin/recovery` 换成传入的 skyward；
4. 加 `system/bin/{7za,avbctl,resetprop,zstd}` 符号链接（都指向 recovery，按 argv[0] 分派）；
5. 加 `skyward/{device.toml,system-init,字体,字体许可}`；
6. 改 `prop.default`：`ro.secure=0`、`ro.adb.secure=0`、`ro.debuggable=1`、`ro.ota.allow_downgrade=true`；
7. `--extra RAMDISK_PATH=HOST_PATH` 额外加文件（本仓库用它把 `skyward/wpa-aidl-shim.so` 放进 ramdisk）；
8. 重压 ramdisk（LZ4 legacy 帧），按原分区大小补齐，写未签名 AVB footer，`OriginalImageSize` 指向真正内容大小。

对应源码（上游）：

| crate | 作用 |
| --- | --- |
| `skyward-bootimg` | boot header / ramdisk / cpio / AVB footer |
| `skyward-pack` | `recovery` / `stock` / `list` / `repack` 子命令 |
| `skyward-crypto` | data 解密、gatekeeper、weaver、keystore2 |
| `skyward-binder` | binder 客户端（+ 本仓库补的服务端） |
| `skyward-ui` | miuix 风格 UI |
| `skyward-system-init` | 第二系统的 init（静态） |

---

## 7. Windows 上踩过的三个坑

### 7.1 默认工具链是 msvc，`link.exe` 还是 MSYS 的

现象：

```
error: linker `link.exe` not found
# 或
link: extra operand '...'
```

根因：rustup 默认宿主是 `x86_64-pc-windows-msvc`，而 PATH 里的 `link.exe` 可能先命中 MSYS coreutils 的 `link`。

解法：`scripts/env.sh` 已强制：

```sh
export RUSTUP_TOOLCHAIN=stable-x86_64-pc-windows-gnu
```

### 7.2 `dlltool` 在 `%TEMP%` 建不了临时文件

现象：

```
error: dlltool could not create import library ...
Cannot create temporary file in C:\Users\...\AppData\Local\Temp\: Permission denied
```

根因：这台机器的系统临时目录对当前账号不可写，`dlltool` 在链接 `getrandom` / `windows-sys` 时失败。

解法：`env.sh` 把 `TMPDIR` / `TEMP` / `TMP` 指到仓库内 `tmp/`。

### 7.3 上游 `ramdisk.rs` 有 Unix-only 代码

现象：Windows 上编 `skyward-pack` 时，`Ramdisk::unpack` / `c_path` / `set_time` 报未使用或平台 API 不存在。

根因：这些函数只在 Unix 上成立，宿主打包器走的是内存里的 cpio，用不到。

解法：`patches/0001` 用 `#[cfg(unix)]` 围起来，测试模块改成 `#[cfg(all(test, unix))]`。

---

## 8. 可复现性

- **镜像哈希**只对「同一份 stock + 同一份 skyward 二进制 + 同一份 system-init + 同一份字体」成立。打包步骤本身是确定的；
- 实测：用发布镜像里的 `skyward`（`a39596f8…cd70`）重新跑 `build-image.sh`，得到**完全相同**的 `baf93862…78b0`；
- 但**重新编译二进制**不一定逐字节一致：同一份源码在本机重编，`skyward` 大小仍是 8,619,216，逐字节比较只有 2 个字节不同（位于 build-id 附近），哈希变成 `0fdbee2a…`；整镜像哈希随之改变。这是 Rust / 链接器的正常现象，不是源码不同；
- 因此「可复现」以**结构 + 行为**为准：大小、头部、ramdisk 条目、二进制大小、真机触摸 / 解密；不要拿整镜像哈希当唯一标准；
- 字体、stock recovery 的字节必须与配置一致，否则镜像内容会变；
- 不要把 `out/` 里的镜像直接当 Release 发布，除非你确认它来自当前 `patches/` 和 `devices/onyx.toml`。

---

## 9. Linux / macOS

脚本本身按 POSIX 写，`env.sh` 会按 `uname -s` 选 NDK 的 `linux-x86_64` / `darwin-x86_64`。未实测的点：

- `stat -c%s` / `sha256sum` 在 macOS 上不同（脚本已对大小做 `stat -f%z` 回退，哈希命令未做 `shasum` 回退）；
- 宿主 `skyward-pack` 原生编译，不需要 MinGW；
- 上游 `ramdisk.rs` 的 `#[cfg(unix)]` 在 Linux/macOS 上不会裁剪任何东西，行为与上游一致。

欢迎提交 Linux 实测的 PR。

---

## 10. 常见错误

| 错误 | 原因 | 处理 |
| --- | --- | --- |
| `cargo: not found` | `~/.cargo/bin` 不在 PATH | `export PATH="$HOME/.cargo/bin:$PATH"` |
| `error calling dlltool` | MinGW binutils 不在 PATH | 设 `MINGW_BIN` |
| `Cannot create temporary file` | `%TEMP%` 不可写 | 用 `scripts/env.sh`，或手动设 `TMPDIR` |
| `link: extra operand` | msvc / MSYS `link.exe` 冲突 | 强制 gnu 工具链 |
| `lz4: command not found` | 打包器找不到 lz4 | 把 lz4 放进 PATH |
| `rusqlite` / `cc` 报错 | 缺 `CC_aarch64_linux_android` | 用 `scripts/env.sh` |
| `aarch64-linux-android30-clang not found` | NDK 路径 / API 不对 | 检查 `ANDROID_NDK`，`ANDROID_API` 默认 30 |
| `skyward-pack stock` 网络失败 | 官方 OTA 服务器不可达 | 用 Release 里的 stock 镜像改名 |
| 镜像大小 ≠ 104857600 | 拿错 stock / 分区表不对 | 换回配置里的 OS4.0.2.0 stock |
| `verify-image.sh` 找不到条目 | 打包中断 / 二进制路径错 | 重跑 `build-image.sh`，看打包器输出 |

---

## 11. 构建产物一览

| 产物 | 路径 | 是否进仓库 |
| --- | --- | --- |
| skyward（手机） | `build/phone/aarch64-linux-android/release/skyward` | ❌ |
| system-init（手机） | `build/system-init/aarch64-linux-android/release/system-init` | ❌ |
| skyward-pack（宿主） | `build/host/release/skyward-pack[.exe]` | ❌ |
| 原厂 recovery | `stock/recovery.img` | ❌（Release 提供） |
| 整分区镜像 | `out/skyward-v0.3.0-onyx.1-OS4.0.2.0.XOLCNXM.img` | ❌（Release 提供） |
| zip | `out/*.zip`（可选，手动打） | ❌ |

仓库只保留源码、补丁、配置、脚本、文档和 `SHA256SUMS`。
