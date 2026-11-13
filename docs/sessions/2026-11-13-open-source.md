# 把 recovery 开源到 GitHub（2026-11-13）

状态：已完成
关联版本：v0.2.0-onyx.4（发布）
关联提交：仓库首次提交

## 1. TL;DR

把 onyx 的 Skyward 移植整理成独立仓库 `Remoparrot/skyward-onyx`：设备配置、三个补丁、完整构建脚本、agent.md 与 9 份文档，并在 Release 提供 `recovery.img` / stock recovery / zip / `SHA256SUMS`。镜像不进 git（100 MB 单文件限制），构建链和真机结论全部可追溯。

## 2. 对话重点

- 用户要求：「把 recovery 开源到我的 github，并做好 agent.md 等」；
- 目标：仓库要能被人接手，不只是把镜像丢上去；
- 决策：
  - 独立仓库，不 fork 上游；上游源码由 `bootstrap.sh` 按固定 commit 拉取；
  - 补丁按逻辑拆成 3 个（Windows 构建 / OMAPI 桥 / CE 回退），而不是一个 1317 行的大补丁；
  - 镜像、zip、stock recovery 只放 Release，git 里只保留源码 / 配置 / 文档；
  - 文档体系照搬 iLayoutSettings 的「agent.md + docs 地图 + 7 节会话记录」；
  - 不发布任何用户密码、序列号、`spblob` 内容。
- 范围外：user 999、WLAN、振动、上游 PR。

## 3. 修复内容

| 文件 | 改了什么 | 为什么 |
| --- | --- | --- |
| `README.md` | 重写：状态表、能力、安装、构建、仓库结构、文档地图、协作约定 | 对外入口 |
| `agent.md` | 新建：接手流程、7 节记录、刷机 / 数据安全红线、版本规则、DoD | 让下一个 AI / 人无缝接手 |
| `devices/onyx.toml` | 从 `skyward-onyx/onyx.toml` 移入 | 仓库结构 |
| `patches/0001` | 从合并补丁拆出 `ramdisk.rs` | Windows 宿主构建 |
| `patches/0002` | 拆出 binder + `omapi.rs` + `main.rs` | OMAPI 实验 |
| `patches/0003` | 拆出 `data.rs` | CE 回退（v4 核心） |
| `scripts/*.sh` | 新建 9 个脚本：bootstrap / env / check-deps / build-* / fetch-stock / build-image / verify-image | 可复现构建 |
| `docs/00-08` + `docs/sessions/` | 新建完整文档 | 状态、架构、构建、刷入、设计、坑、版本、排错、会话 |
| `.gitignore` / `.gitattributes` | 忽略镜像 / zip / out / vendor，脚本固定 LF | 避免 100 MB 文件和 CRLF |
| `SHA256SUMS` | 只列 Release 资产 | 校验 |
| `.github` | 未加 CI | 交叉编译需要 NDK + stock，CI 成本高，暂不做 |

## 4. 设计思路

- **为什么独立仓库而不是 fork**：上游是通用 recovery，onyx 只是设备移植；独立仓库的 README / docs / issues 都能聚焦设备，补丁也更容易 review。GPL 要求源码可得，所以用固定 commit + 补丁 + 构建脚本 + Release 资产满足。
- **为什么拆补丁**：0001 是 Windows 平台适配，0002 是实验性的 OMAPI，0003 才是 onyx 解密的核心；拆开后可以单独 review、单独回滚。
- **为什么镜像不进 git**：`recovery.img` 正好 104,857,600 字节，GitHub 单文件上限 100 MB；放 Release 是唯一正确选择。
- **为什么 stock 也放 Release**：用户回滚需要它；同时让 `fetch-stock.sh` 可以从官方 OTA 按 Range 只取分区，不强制依赖 Release。
- **为什么文档这么重**：recovery 会刷坏分区，必须留下「哪一版、什么哈希、什么底包、真机验过什么」。

## 5. 踩过的坑

1. **GitHub 单文件 100 MB**：`recovery.img` 正好 104,857,600 字节；解法是 `.gitignore` + Release；预防是提交前 `git status`。
2. **GitHub HTTPS 间歇不可达**：`git ls-remote` / `git push` 多次 `Connection reset` / timeout，但 `api.github.com` / `uploads.github.com` 可用；解法是用 `gh api` 建仓库、提交、发 Release；预防是准备 API 兜底。
3. **补丁拆分后的行尾**：工作树 CRLF、`git archive` LF，直接 `diff -r` 会报整文件差异；解法用 `diff --strip-trailing-cr` 对比，补丁本身用 `git apply` 验证。
4. **旧 README 的 998 条**：实际 v4 是 996；解法以 `skyward-pack list` 为准；预防每次发版把条目数写进记录。
5. **`stat -c%s` 平台差异**：Windows MSYS 可用，macOS 要 `stat -f%z`；脚本已加回退。

## 6. 验证与证据

- 三个补丁在**干净的上游 tree**（`git archive ff1668f`）上依次 `git apply --check` + `git apply` 通过；应用后的 `crates/` 与 `work/skyward` 逐文件一致（`diff --strip-trailing-cr`）。
- 用 Release 里的 `skyward` 二进制 + system-init + stock + 字体重跑 `build-image.sh`，得到**完全相同**的 `b41bee5b…f1f83f`（104857600 字节 / 996 条），说明打包步骤确定。
- 用同一份源码重编 `skyward`：大小仍 8,619,216，逐字节只有 2 个字节不同（build-id 附近），哈希 `51e902f6…` → `0fdbee2a…`；已写进 `03-build.md` 的可复现性说明，避免把二进制哈希当源码一致性证据。
- `scripts/verify-image.sh recovery.img b41bee5b…` 输出：

  ```text
  大小：104857600 字节
  header v4  kernel 0 bytes  ramdisk 49643317 bytes
  ramdisk 条目：996
  SHA-256：b41bee5b5342e5a2f0f32ba01e9a0cca3c0ab69b520799e4e29ee49957f1f83f
  ✓ 与预期一致
  ```

- `SHA256SUMS` 与三个 Release 资产逐一核对（`sha256sum`）。
- 仓库页面、Release 下载链接、README 相对链接在发布后逐项打开检查。

## 7. 未完成 / 下一步 / 风险

- **user 999 / WLAN / 振动**：与 v4 相同，未做。
- **CI**：没有加；交叉编译需要 NDK + 100 MB stock，GitHub Actions 成本高。若以后加，只做 `bash -n` / 补丁 `git apply --check` / 文档链接检查。
- **上游同步**：上游更新后需要重放 3 个补丁，并在真机回归触摸 + 解密。
- **Release 资产体积**：约 245 MB；GitHub 单资产上限 2 GB，没问题，但下载慢。
- **法律 / 商标**：stock recovery 来自小米官方包，仅用于回滚；README / NOTICE 已声明无隶属关系。
