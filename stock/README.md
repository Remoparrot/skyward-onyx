# 原厂 recovery

构建需要 onyx 在 `OS3.0.306.0.WOLCNXM` 下的**原厂 recovery 整分区镜像**：

| 项 | 值 |
| --- | --- |
| 路径 | `stock/recovery.img`（不进 git） |
| 大小 | 104,857,600 字节 |
| SHA-256 | `99047b63a1b72e049617f9a2615778c0833899759ede92a7ec32454b722549a2` |
| 来源 | `onyx-ota_full-OS3.0.306.0.WOLCNXM-user-16.0-17ed95af98.zip` |

## 方式 A：脚本按需取（推荐）

```sh
scripts/build-pack.sh    # 先有打包器
scripts/fetch-stock.sh
```

`skyward-pack stock` 读 `devices/onyx.toml` 的 `[stock]`，按 HTTP Range 只下载 recovery 分区那一段（约 25 MB），核对 SHA-256 后写到 `stock/recovery.img`。

## 方式 B：从 Release 下载

从 [Releases](https://github.com/Remoparrot/skyward-onyx/releases) 下载 `recovery-stock-OS3.0.306.0.WOLCNXM.img`，重命名：

```sh
mv recovery-stock-OS3.0.306.0.WOLCNXM.img stock/recovery.img
sha256sum stock/recovery.img
```

## 方式 C：自己从官方全量包抽

不推荐——payload 的 extent 是块号，自己写脚本容易错。如果一定要做：

1. 下载官方全量包；
2. 解析 `payload.bin` 的 manifest，找到 `recovery` 分区；
3. 按 `offset = block * block_size`、`length = num_blocks * block_size` 读取；
4. 核对 SHA-256 必须等于上表。

## 注意

- 不要用别的底包（OS3.0.307 / OS4）的 recovery；服务路径、VINTF、AVB footer 都可能不同；
- 不要把 `stock/recovery.img` 提交到 git（`.gitignore` 已覆盖 `/stock/*.img`）；
- 回滚时刷的就是这个文件：

  ```sh
  fastboot flash recovery stock/recovery.img
  ```
