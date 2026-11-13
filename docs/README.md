# 文档地图

> 先读 [`agent.md`](../agent.md) 和 [`00-status.md`](00-status.md)。本文件只负责告诉你「东西在哪」。

## 按任务找

| 你想做什么 | 先读 | 再读 |
| --- | --- | --- |
| 第一次接手这个项目 | [`../agent.md`](../agent.md) | [`00-status.md`](00-status.md) → 最近一份 [`sessions/`](sessions/) |
| 弄清 Skyward 是什么、onyx 上能做什么 | [`01-overview.md`](01-overview.md) | [`00-status.md`](00-status.md) |
| 改代码 / 看镜像里有什么 | [`02-architecture.md`](02-architecture.md) | [`05-design-notes.md`](05-design-notes.md) + [`06-pitfalls.md`](06-pitfalls.md) |
| 自己构建 | [`03-build.md`](03-build.md) | [`02-architecture.md`](02-architecture.md) |
| 刷机 / 回滚 / 第一次进 recovery | [`04-install.md`](04-install.md) | [`08-troubleshooting.md`](08-troubleshooting.md) |
| 解密相关的原理 | [`05-design-notes.md`](05-design-notes.md) | [`06-pitfalls.md`](06-pitfalls.md) |
| 出问题了 | [`08-troubleshooting.md`](08-troubleshooting.md) | [`06-pitfalls.md`](06-pitfalls.md) |
| 看历史版本 | [`07-changelog.md`](07-changelog.md) | [`sessions/`](sessions/) |
| 知道每个文件是干什么的 | [`../agent.md`](../agent.md) 第 9 节 | 本页 |

## 文件

| 文件 | 内容 | 什么时候会改 |
| --- | --- | --- |
| [`00-status.md`](00-status.md) | 当前版本、发布物哈希、已验证 / 未验证、已知问题、下一步 | 每次会话结束、每次发版 |
| [`01-overview.md`](01-overview.md) | 项目是什么、为什么移植、能力边界、设备信息 | 能力变化 |
| [`02-architecture.md`](02-architecture.md) | 镜像结构、ramdisk 布局、启动流程、服务图、补丁文件级说明 | 改服务 / 改补丁 / 改打包 |
| [`03-build.md`](03-build.md) | 工具链、命令、校验、可复现性、Windows 坑 | 构建脚本 / 依赖变化 |
| [`04-install.md`](04-install.md) | 刷入、首次进入、解密、回滚、风险 | 刷机流程变化 |
| [`05-design-notes.md`](05-design-notes.md) | 为什么是 gatekeeper 回退、为什么不要 OMAPI、触摸 / 密度取舍 | 设计变化 |
| [`06-pitfalls.md`](06-pitfalls.md) | 踩过的坑：现象 → 根因 → 解法 → 预防 | 每次遇到新坑 |
| [`07-changelog.md`](07-changelog.md) | v1 → v4 的版本记录与哈希 | 每次发版 |
| [`08-troubleshooting.md`](08-troubleshooting.md) | 症状 → 检查 → 处置 | 新排错经验 |
| [`sessions/`](sessions/) | 每次会话的 7 节记录 + 索引 | 每次会话结束 |

## 约定

- 本目录所有文档以**中文**为主，命令、路径、日志保持原文；
- 版本号格式 `v0.2.0-onyx.<n>`，设备固定 `onyx`；
- 镜像哈希一律写完整 64 位十六进制；二进制哈希若只能从镜像内取得，写前后各 6 位并标「partial」；
- 没上机验证的内容必须显式写「未验证」，不要用「应该」「理论上」糊过去；
- 新增文档必须登记到本页的表格里，否则等于不存在。
