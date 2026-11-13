# onyx.3：更新下载 512 并行、首页读数补齐、更新页反馈（2026-11-13）

状态：已完成
关联版本：v0.3.0-onyx.2 → v0.3.0-onyx.3
关联提交：`a053280`（代码与补丁）；本记录所在提交见 `git log`

## 1. TL;DR

把 Skyward 更新（和系统 OTA）的下载从单连接顺序改成最多 512 个 `Range` 连接并行：GitHub 上 45.85 MB 的包从约 17 分钟降到 **17.2 秒**。首页机型卡片的「可用空间」在 `/data` 解密完成后补齐；更新页对本地 `recovery.img` 刷入也显示进度与「更新成功」。onyx.3 镜像已刷入槽位 B 并在真机确认版本与读数。

## 2. 对话重点

- 用户要求（原话要点）：
  - 「给我的 skyward 0.3.0-onxy.1 的机型处加一个图中的数据显示（图 2 中框起来的地方），搞好后刷入目前正在使用的 skyward，把新版本同步到 GitHub 上，看看能不能使用 skyward 更新来更新 skyward」；
  - 「给更新的下载线程调到最大 512 线程」。
- 明确做出的决策：
  - 读数做在机型卡片内、机型名/底包下方：当前槽位 / 数据分区 / 可用空间 / 电量，读不到的项自动省略（`widgets::readings_of`）；
  - 更新下载 = 64 KiB 分段、每段一个 `Range` 请求、最多 512 个连接，全部写完再整文件核对 SHA-256/MD5；单段失败重试，服务端不认 `Range` 时退回单连接；
  - DNS 解析结果按 (host, port) 缓存 5 分钟——512 个连接各查一次会把路由器的 DNS 打到拒答；
  - 并行下载不续传：停止/失败删 `.part`，避免并行写入留下的空洞被当成可续传前缀；
  - 本地刷入路径固定 `/sdcard/Download/recovery.img`（onyx.2 已实现，本轮补上进度/结果反馈）；
  - 版本号：onyx.2 = 读数，onyx.3 = 512 并行下载。
- 范围外但被提到：无。

## 3. 修复内容

| 文件 | 改了什么 | 为什么 |
| --- | --- | --- |
| `crates/skyward-net/src/download.rs` | 新增 `runs()` / `fetch_ranges()` / `run()` / `one_run()` / `write_at()` / `stream()`；带校验和的包先并行分段取，写完整文件哈希校验；单段 4 次重试；失败/停止删 `.part` | 单连接从 GitHub 只有约 40 KB/s，分段并行才能把带宽用起来 |
| `crates/skyward-net/src/http.rs` | `Lookup` 增加 `known: Mutex<HashMap<(host, port), (Instant, Vec<SocketAddr>)>>`，5 分钟有效；解析时持锁做 single-flight | 512 个连接同时查 DNS 会被路由器拒绝（实测 `Query Refused`） |
| `crates/skyward-net/src/github.rs` | `Build` 新增 `raw`；release 里有名为 `recovery.img` 的 asset 时优先取，没有才退回 `skyward-<tag>-onyx-*.zip` | 在线更新直接写整镜像，少一次解压 |
| `crates/skyward/src/updates.rs` | 新增 `UpdateSkywardFile` 任务与 `write_raw` / `write_image` 拆解 | 本地 `recovery.img` 与在线下载共用写分区路径 |
| `crates/skyward/src/ui.rs` | 处理 `Effect::UpdateSkywardLocal`；`Decryptor` 报 `Opened(Ok)` / `Unlocked(Ok)` 后重新 `skyward_info::collect` | 「可用空间」只在 `/data` 挂载后可读，之前开机时读不到就永远缺一列 |
| `crates/skyward-ui/src/widgets.rs` | 新增 `Reading` / `readings_of`，`device_card` 画四列读数 | 图 2 的数据条 |
| `crates/skyward-ui/src/pages.rs` | `home()` 用现有读数拼四列；`skyward_update()` 中新增 `skyward_job()`，进度/成功/失败从 `skyward_online()` 独立出来；本地刷入行与在线行共用任务展示 | 本地刷入时页面没有进度/结果（检查结果是「已是最新」时会提前 return） |
| `crates/skyward-ui/src/app.rs` | 新增 `Action::UpdateSkywardLocal` / `Effect::UpdateSkywardLocal`；`SkywardJob` 新增 `local: bool` | 区分本地刷入与在线下载，文案不写本地镜像的版本 |
| `Cargo.toml` / `Cargo.lock` | 版本 `0.3.0-onyx.2` → `0.3.0-onyx.3` | 发版 |
| `patches/0006-onyx.3-fast-download.patch` | 上述代码改动（7 个文件、887 行） | 补丁化 |

## 4. 设计思路

- **问题本质**：更新慢不是 CPU/写盘慢，而是单条 TCP 到 GitHub 的吞吐被限在约 40 KB/s。提高吞吐的最直接办法是同时开多条连接，各自拿一段字节。
- **方案 A（采纳）**：按 64 KiB 分段 + `Range: bytes=start-end`，最多 512 个连接同时 `pwrite` 到同一个文件（按偏移写，不依赖共享文件偏移）；写完整文件后统一校验。连接数 = min(512, ⌈大小/64 KiB⌉)，小包不会开超过需要的连接。
- **方案 B（否决）**：单纯开 N 个线程各下载“第 i 部分”再拼文件——需要额外的临时文件和拼接 IO，且校验前多一步。
- **方案 C（否决）**：只开 8/16 个连接。在 GitHub 这种每条连接都被压到几十 KB/s 的链路里，连接数就是吞吐量，用户明确要求 512。
- **关键取舍**：
  - 并行写入让“续传”失去意义（无法确认前缀连续），因此停止/失败删 `.part`，用重试与本地刷入兜底；系统 OTA 的断点续传能力暂时放弃。
  - DNS 缓存是 512 并发的必要配套，否则请求还没发出就被 DNS 拒答。
  - 更新任务的展示与「检查结果」解耦，本地刷入才能看到反馈。

## 5. 踩过的坑

**5.1 执行 `/system/bin/recovery --help` 后 USB 掉线、adb 消失**

- 现象：命令返回 255，`adb devices` 变空，Windows 里也没有任何手机 USB 设备；屏幕停在最后一帧。
- 根因：`main.rs` 按 `argv[0]` 文件名判断入口，名字是 `recovery` 就直接跑 `recovery()`，命令行参数被忽略——等于起了第二份 recovery；它启动时 `usb::set("none")` 拆掉 adbd 与 USB 功能，又与第一份抢显示/分区，整机失去响应。
- 解法：长按电源键强制重启；misc 里 `boot-recovery` 仍在，重启后回到 Skyward，adb 恢复。
- 如何避免：真机上永远不要执行 `/system/bin/recovery`（带不带参数都一样）；要查命令行用同一二进制按 `argv[0]` 链接出的子命令名。

**5.2 512 连接第一次测试卡在 179 KB，报 `Query Refused`**

- 现象：下载几乎立刻停住，约 50 秒后 `ask for bytes …: io: the DNS server answered Query Refused for github.com`。
- 根因：每个连接都独立查一次 DNS（自定义 `Lookup` 没有缓存），512 个突发查询把路由器的 DNS 打到拒答；随后每段重试又各查一次。
- 解法：`Lookup` 按 (host, port) 缓存 5 分钟，并在解析期间持锁，避免并发查询。
- 如何避免：并发连接上量前，先确认解析器有缓存/连接复用。

**5.3 本地 100 MB 并行测试被 `Connection reset by peer` 直接判失败**

- 现象：跑到 47 MB 时整包失败，错误来自某个分段的第 4 次重试。
- 根因：Python `ThreadingHTTPServer` 的 listen backlog 默认只有 5，512 个连接被内核/服务器重置；下载器当时只重试连接错误，不重试“读到一半断开”。
- 解法：测试服务器 `request_queue_size = 1024`；下载器把整个分段（连接 + 读取 + 短读）统一重试 4 次，重试前把已计入的进度扣回。
- 如何避免：并发压测要区分“服务器不能接受”与“客户端不够健壮”，两边都要扛。

**5.4 开机后首页卡片只有 3 列，「可用空间」整列消失**

- 现象：onyx.2 首页显示 `B / 已解密 / 100%`，可用空间没有；解密完成后也不出现。
- 根因：`DeviceInfo::collect` 只在 UI 启动时读一次 `/data` 的 free，此时 `/data` 还没挂载 → `free = None`，之后没有刷新点。
- 解法：解密任务报 `Opened(Ok)` / `Unlocked(Ok)` 后重新 `skyward_info::collect`。
- 如何避免：任何依赖挂载状态的数据都要在状态变化时刷新，不能只在启动时采一次。

**5.5 本地 `recovery.img` 刷入成功但页面毫无反馈（onyx.2）**

- 现象：进度卡、成功行都不出现；dmesg 显示其实已写入。
- 根因：进度/成功的渲染写在 `skyward_online()` 里，而该函数在 `!newest.newer`（本次正好是「已是最新」）时提前 return；本地刷入又不经过在线检查。
- 解法：抽出 `skyward_job()`，把任务展示与检查结果解耦，在线/本地共用；`SkywardJob.local` 决定成功文案是否带版本号。
- 如何避免：任务状态的展示不要寄生在“入口条件”里。

## 6. 验证与证据

- 版本与产物：
  - 镜像 `out/skyward-v0.3.0-onyx.3-OS4.0.2.0.XOLCNXM.img`：104,857,600 字节，SHA-256 `d0a67128ee1fbc54033dadae2cf9c55b429733c4b163e1528dedbaca370360c5`；`header v4  kernel 0 bytes  ramdisk 50681746 bytes`；ramdisk 1062 条；
  - 内含 `system/bin/recovery`：8,753,632 字节，SHA-256 `bb75d7e4aef48a3a5f3b986e6b0974ad7daf531ed5e25d7fbb88611fc942ba44`（与 `build/phone/…/skyward` 一致）；
  - zip `skyward-v0.3.0-onyx.3-onyx-OS4.0.2.0.XOLCNXM.zip`：46,347,671 字节，SHA-256 `9f41916f651927de297222832a2f3295f2a445fdc87e44f16480957fdbbeb874`。
- 下载器（同一份 `skyward-net` 代码，example `fetch` 在 onyx 上运行）：
  - GitHub `v0.3.0-onyx.2` 的 45.85 MB zip：**17.2 s**，SHA-256 校验通过；此前单连接约 17 分钟；
  - 本地 range 服务器 100 MB：并行 5.9 s（≈17.8 MB/s）、单连接 3.7 s（≈28 MB/s）。
- 真机更新链路：
  - `0.3.0-onyx.1` 高级 → Skyward 更新：检查到 `0.3.0-onyx.2`、下载并写入槽位 B；重启 `dmesg`：`onyx 0.3.0-onyx.2 recovery up`；
  - `0.3.0-onyx.2` 用「从本地 recovery.img 刷入」写 `0.3.0-onyx.3`：`dmesg`：`updating Skyward from /sdcard/Download/recovery.img`、`Skyward's build written to [B]: Ok(())`；
  - 重启 `dmesg`：`onyx 0.3.0-onyx.3 recovery up`；`/system/bin/recovery` 的 sha256 与镜像内一致；
  - onyx.3 首页机型卡片：`B / 当前槽位`、`已解密 / 数据分区`、`175.1GB / 可用空间`、`100% / 未充电`（可用空间在解密完成后出现）；
  - onyx.3 再次本地刷入：页面出现进度卡，随后「更新成功 · 已将 Skyward 刷入槽位 B 的 recovery 分区。」与「重启到恢复模式」。
- 未验证：系统 OTA（几 GB）完整下载；服务端不认 `Range` 时的单连接回退未在真实服务器上触发过（逻辑有单测覆盖分段计算）。

## 7. 未完成 / 下一步 / 风险

- 系统 OTA 的并行下载未在真机完整跑过；建议下一个大版本用一次真实 OTA 验证。
- 512 连接对 GitHub 的长期影响未知（可能触发限流）；已有单段重试与本地刷入兜底，若频繁失败可下调上限。
- 并行下载不续传；如果以后要续传，需要为分段写进度（位图）或每段单独临时文件。
- 本次验证用的 example `fetch` 只存在于本地 vendor 树，没有进补丁；需要时可用 `cargo build --target aarch64-linux-android -p skyward-net --example fetch` 重新生成。
- 会话中误执行了第二份 recovery 导致整机失去响应，已强制重启恢复；这条已写进坑 5.1，后续会话不要再碰 `/system/bin/recovery`。
