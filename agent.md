# agent.md — 协作与记录规范（强制）

> 状态：**现行**
> 适用对象：所有进入本仓库的 AI 会话（Claude / GPT / DeepSeek…）与人类协作者。
> 性质：**强制**。不按本文件写记录 = 本次任务未完成（见第 11 节 DoD）。

---

## 0. 为什么有这个文件

这个项目的状态不在任何人的记忆里，而在仓库里。

- `docs/sessions/` 记录**发生了什么、为什么**；
- `docs/00-status.md` 记录**现在在哪**；
- `docs/README.md` 记录**东西在哪**。

recovery 是**会刷坏分区、会让手机起不来**的东西，比普通 App 更需要留下「哪一版、什么哈希、在什么底包上、真机验过什么、没验过什么」。下次开新对话时，任何人（或 AI）只读三份文件就能接手，不用重新摸索、不用问「上次改到哪了」。

**你这次会话的价值，一半在代码，一半在你留下的记录。**

---

## 1. 会话开始（5 分钟，不许跳）

按顺序读，读完再动手：

1. `agent.md`（本文件）
2. `docs/00-status.md` —— 当前版本、发布物哈希、已知问题
3. `docs/README.md` —— 文档地图，按任务挑专题
4. `docs/sessions/README.md` 的索引表 → 最近 1~2 份会话记录
5. 与任务相关的专题：改代码看 `docs/02-architecture.md` + `docs/05-design-notes.md` + `docs/06-pitfalls.md`；构建看 `docs/03-build.md`；排错 / 刷机看 `docs/04-install.md` + `docs/08-troubleshooting.md`

然后先回复一段**接手确认**，再开始改：

```
接手确认
- 当前版本：v0.3.0-onyx.5（recovery.img ac9be2c5…）
- 设备与底包：onyx / OS4.0.2.0.XOLCNXM
- 本次目标：<一句话>
- 是否需要真机 / 是否会刷机：<是 / 否>
- 主要风险：<例如：改 data.rs 的回退顺序可能影响 user 0 解密>
- 我打算先看哪些文件：<...>
```

### 给用户：新对话开场白（直接复制）

> 读 `agent.md`、`docs/00-status.md`、`docs/README.md` 和 `docs/sessions/` 里最新的一份记录，
> 先用 5 行给我接手确认（当前版本、已知问题、本次建议、风险、你打算先看哪些文件），
> 在我确认之前不要改代码、不要刷机。

> **禁止凭记忆改代码。** 尤其是 `devices/onyx.toml` 里的服务路径、`data.rs` 的回退条件、OMAPI 的方法编号——这些都有真机实测依据，凭训练记忆「重写」一遍通常会把已经验证过的东西改坏。

---

## 2. 会话结束（强制，缺一不可）

新开一个文件：`docs/sessions/YYYY-MM-DD-<slug>.md`（日期用本机时区，slug 小写连字符），
**必须包含且只按顺序包含以下 7 节**：

```markdown
# <标题>（YYYY-MM-DD）

状态：已完成 / 部分完成 / 阻塞
关联版本：v0.2.0-onyx.3 → v0.2.0-onyx.4
关联提交：<commit sha，可后补>

## 1. TL;DR
三句话以内：做了什么、结果如何、还差什么。

## 2. 对话重点
- 用户要求（尽量保留原话要点）
- 明确做出的决策 / 否决的方案
- 范围外但被提到的事（记下来，别做）

## 3. 修复内容
| 文件 | 改了什么 | 为什么 |
| --- | --- | --- |
没有代码改动的会话写「无代码改动」，并说明原因。

## 4. 设计思路
- 问题本质是什么
- 考虑过哪些方案（A/B），为什么不选另一个
- 关键取舍（兼容性 / 数据安全 / 可维护性）

## 5. 踩过的坑
每条固定四段：**现象 → 根因 → 解法 → 如何避免**。
没有坑就写「本次无新坑」，不要编。

## 6. 验证与证据
- 执行过的命令（原样）
- 结果（关键输出、镜像大小、sha256、日志行、真机现象）
- 没验证的部分要明确写「未验证」

## 7. 未完成 / 下一步 / 风险
- 明确未做的事
- 建议的下一步顺序
- 可能翻车的点
```

写完必须做三件同步（见第 4 节）：登记索引、更新 `00-status.md`、更新受影响专题文档。

---

## 3. 记录质量线（写之前自查）

| 小节 | 必须回答 | 不合格示例 |
| --- | --- | --- |
| TL;DR | 一句话能看懂结论 | 「做了一些优化」 |
| 对话重点 | 用户到底要什么、否掉了什么 | 只抄需求标题 |
| 修复内容 | 文件 + 行为变化（before/after） | 「修复了 bug」 |
| 设计思路 | 为什么不是另一种做法 | 只写「按需求实现」 |
| 踩坑 | 现象→根因→解法→预防 | 「有个坑，解决了」 |
| 验证 | 命令 + 输出 + 哈希 / 真机现象 | 「测试通过」 |
| 下一步 | 可执行的具体动作 | 「继续优化」 |

**判断标准**：三个月后一个陌生人（或新 AI）只看这份记录，能不能复现你的结论、能不能判断这个镜像敢不敢刷？

---

## 4. 必须同步更新的文件

| 触发 | 必须更新 |
| --- | --- |
| **每次会话结束** | 新建 `docs/sessions/<日期>-<slug>.md` + `docs/sessions/README.md` 索引 + `docs/00-status.md` |
| 新镜像 / 版本号变化 | `docs/07-changelog.md` **顶部**新增一节 + `00-status.md` + `README.md` 的版本 / 哈希表 + `SHA256SUMS` |
| 新增/修改服务、Hook、设备配置 | `docs/02-architecture.md` + `devices/onyx.toml` |
| 新坑、或推翻旧结论 | `docs/06-pitfalls.md`（旧结论标「已过时」，说明为什么） |
| 新增/改名/删除文档 | `docs/README.md`（文档地图） |
| 构建脚本 / 依赖升级 | `docs/03-build.md` + `scripts/` |
| 上游版本变化 | `patches/README.md` + `docs/03-build.md` + `NOTICE.md` 里的 commit |

---

## 5. 命名、格式与勘误

- 会话文件名：`2026-11-12-ce-unlock-v4.md`（日期-英文短标题）；
- 同一天多次会话：`2026-11-12-<slug>-2.md`，不要覆盖已有文件；
- **只能追加，不能改写历史**。发现旧记录有错，在文件末尾追加：

```markdown
## 勘误 YYYY-MM-DD
- 原文「……」有误，实际为「……」，依据：<命令/日志>
```

- 索引表列固定：`日期 | 标题 | 一句话结论 | 状态`。

---

## 6. 版本与发布规则

1. 版本号格式 `v<上游版本>-onyx.<n>`，例如 `v0.2.0-onyx.4`；`n` 是 onyx 移植的迭代号，不复用；
2. 每次发版必须一次做齐：打镜像 → 记 sha256 / 大小 / ramdisk 条目 → 更新 `SHA256SUMS` → `docs/07-changelog.md` 顶部 → `docs/00-status.md` → README 的版本表；
3. Release 资产固定为：
   - `recovery.img`（整分区，100 MB）
   - `recovery-stock-OS3.0.306.0.WOLCNXM.img`（回滚）
   - `skyward-v0.2.0-onyx-OS3.0.306.0.WOLCNXM.zip`（官方格式 zip）
   - `SHA256SUMS`
   - （可选）源码 tarball
4. **镜像不进 git**（单个 100 MB，超过 GitHub 单文件上限）；`dist/` / `out/` / `*.img` 都在 `.gitignore`；
5. Release 说明必须写：底包版本、镜像哈希、已验证能力、已知限制、回滚命令；
6. 换底包（不是 OS3.0.306.0.WOLCNXM）时，版本号要体现，且必须重新真机验证服务路径与 VINTF。

---

## 7. 构建与验证（复制即用）

完整说明见 `docs/03-build.md`。最短路径：

```sh
export ANDROID_NDK=/path/to/android-ndk-r29
scripts/bootstrap.sh          # 只在第一次
scripts/build-pack.sh
scripts/fetch-stock.sh
scripts/build-phone.sh
scripts/build-system-init.sh
scripts/build-image.sh
scripts/verify-image.sh out/skyward-v0.2.0-onyx-OS3.0.306.0.WOLCNXM.img
```

构建成功的判定（缺一不可）：

- `recovery.img` 正好 **104857600** 字节；
- `skyward-pack list` 头部是 `header v4  kernel 0 bytes`，ramdisk 非空；
- `system/bin/recovery` 是 8 MB 级的 aarch64 PIE；`skyward/system-init` 是静态可执行；
- `skyward/device.toml` 与 `devices/onyx.toml` 内容一致；
- 镜像内 `system/bin/recovery` 的 sha256 与刚编译出的 `skyward` **一致**（打包器会嵌入同一个文件）；
- `verify-image.sh` 的四项条目检查全过。

**没有设备实测的改动，必须在记录第 6 节写「未上机验证」。**

---

## 8. 刷机与数据安全（最高优先级）

recovery 出问题最多让手机进不了 recovery，但**误操作 /data 会丢数据**。以下规则没有例外：

1. **只写 recovery 分区**。不要 `fastboot flash boot` / `system` / `super`，除非任务明确要求且已确认回滚方案；
2. 任何测试先 **adb push 到 `/tmp` 跑二进制**，验证通过再打包、再刷机；
3. **不要**在 recovery 里执行 `setprop ctl.stop recovery`（本机实测会整机重启，原因未查清）；
4. **不要**在未确认的情况下 `mount -o rw /data`、`mkfs`、`wipe`、`rm -rf /data`；解密验证只读挂载即可；
5. 刷机前先确认回滚镜像在手上，并记下当前 `recovery.img` 的 sha256；
6. 不要在文档、脚本、commit、日志里写入用户的**锁屏密码、账号、设备序列号、adb token**；测试密码只在命令行用，不落盘；
7. 需要用户配合的操作（输密码、按键、进 fastboot）要一次说清，不要让用户猜；
8. 改动 `data.rs` / `crypto` 相关代码时，先在 `/tmp` 二进制上验证，再刷镜像。

---

## 9. 仓库地图

```
README.md                     对外说明：是什么 / 怎么装 / 去哪下载
agent.md                      本文件：强制工作流
LICENSE                       GPL-3.0
NOTICE.md                     上游、字体、固件与 Android 接口声明
SHA256SUMS                    发布产物校验和
devices/onyx.toml             设备配置（屏幕、触摸、安全世界服务、底包）
patches/
  README.md                   补丁说明 + 上游 commit
  0001-windows-host-build.patch
  0002-omapi-se-bridge.patch
  0003-onyx-ce-fallback.patch
scripts/
  bootstrap.sh                取上游 + 打补丁
  env.sh                      公共环境（NDK / 工具链 / 临时目录）
  check-deps.sh               依赖自检
  build-pack.sh               宿主侧打包器
  build-phone.sh              手机侧 skyward
  build-system-init.sh        手机侧 system-init（静态）
  fetch-stock.sh              从官方全量包取原厂 recovery
  build-image.sh              打整分区镜像
  verify-image.sh             大小 / 头部 / 条目 / SHA-256 校验
docs/                         文档（入口 docs/README.md）
  sessions/                   每次会话的 7 节记录
stock/                        原厂 recovery 的获取说明（镜像 ignored）
out/                          本地构建输出（ignored）
vendor/skyward/               上游源码（bootstrap 生成，ignored）
```

---

## 10. 禁止事项

- ❌ 提交 `recovery.img`、zip、`vendor/`、`build/`、`out/`、`stock/*.img`；
- ❌ 把 token、密钥、账号凭据、锁屏密码、设备序列号写进仓库或文档；
- ❌ 删除或重写历史会话记录、changelog 旧条目；
- ❌ 未验证就声称「已修复」「已上机」；
- ❌ 改了行为却不写会话记录（本文件存在的原因）；
- ❌ 在没搞清「发布包和源码是否一致」前，直接改版本号发版；
- ❌ 用 `git push --force` 覆盖已发布的 tag / Release；
- ❌ 绕过 `patches/` 直接改 `vendor/skyward/` 后发版（下次 bootstrap 就丢了）。

---

## 11. Definition of Done（每次任务收尾逐项勾）

```markdown
- [ ] 改动可构建（scripts/build-*.sh 退出码 0）
- [ ] 镜像大小 / 头部 / 关键条目 / SHA-256 校验通过
- [ ] 涉及解密的改动已在真机（或至少 /tmp 二进制）验证，并写清验证到哪一步
- [ ] docs/sessions/<本次>.md 已写，7 节齐全
- [ ] sessions/README.md 索引已登记
- [ ] docs/00-status.md 已更新
- [ ] 受影响的专题文档已更新（架构 / 坑 / 构建 / 刷机 / 地图）
- [ ] README 的版本 / 哈希表已更新（若发版）
- [ ] commit message 符合规范
```

---

## 12. 提交信息规范

```
<type>(<scope>): <中文摘要，不超过 50 字>

<可选正文：为什么改、影响范围、验证到哪一步>

<可选 footer：Refs #issue / BREAKING CHANGE: ...>
```

| type | 用途 |
| --- | --- |
| feat | 新能力（新服务、新解密路径） |
| fix | 修缺陷（触摸、解密、构建） |
| docs | 只改文档 |
| build | 构建脚本 / 依赖 / 工具链 |
| refactor | 不改行为的重构 |
| chore | 杂项（版本号、格式、索引） |

示例：

```
fix(crypto): weaver 不可用时回退到 gatekeeper 绑定的 protector
build(win): 固定 gnu 宿主工具链并把 dlltool 临时目录移进仓库
docs(sessions): 记录 v4 在真机上解开 user 0 CE 的全过程
```

---

**记住了：你写的不只是记录，是下一个人的起点；你刷的不只是镜像，是别人手机里的数据。**
