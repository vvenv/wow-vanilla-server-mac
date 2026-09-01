# 客户端资源包来源与验证

Wowee 这类原生客户端**不自带美术资源**，必须从一份合法取得的原版客户端提取 MPQ。
Blizzard 不再分发旧版本，实际来源是第三方镜像。下面是实测结论。

## 先验证，再下载

5 GB 起步的下载，验错了就是几小时。两个高价值的前置检查：

### 1. ZIP 可以远程窥视

`scripts/peek-remote-zip.py <url>` 用 HTTP Range 读中央目录，列出全部文件；
`--get README.md VERSION SHA256SUMS` 还能把小文件直接抽出来读。**下载前就能验明正身。**

要找的是这 12 个 vanilla 1.12.1 MPQ：

```
dbc.MPQ  fonts.MPQ  interface.MPQ  misc.MPQ  model.MPQ  patch.MPQ
patch-2.MPQ  sound.MPQ  speech.MPQ  terrain.MPQ  texture.MPQ  wmo.MPQ
```

> enUS 的 1.12.1 客户端**没有** `Data/enUS/` 语言子目录，12 个 MPQ 全在 `Data/` 根下。
> 这是正常的，不要误判为缺文件。

### 2. RAR 要先看是不是安装程序

`lsar <file>` 即使对**部分下载**的文件也能读出开头的条目名。看到
`setup-1.bin` / `setup-N.bin` 就是 InstallShield 安装程序 —— macOS 上解不了，直接换源。

## 实测结论

| 来源 | 结果 |
|---|---|
| **Stonetavern** `downloads.stonetavern.app/clients/.../Stonetavern-Classic-1.12.1.zip` | ✅ **可用**。5.32 GB，解压即用。`VERSION` 标明 `WoW 1.12.1 (5875) enUS`，WoW.exe md5 `ccf83146dbb3d10ef826aa4de178a5be`（原版 Blizzard 文件），12 个 MPQ 与原版逐字节一致。包内 `SHA256SUMS` 16/16 校验通过。支持 Range 请求，`aria2c -x16` 可跑到 4~5 MB/s。改动全在 exe 层（VanillaFixes 等），**而原生客户端根本不用原版 exe**。 |
| archive.org `World_of_Warcraft_Client_and_Installation_Archive` → `ISO/WoW-1.12.1_install.rar` | ❌ **不可用**。5.34 GB，但内容是 `Wowinstall classic/setup-1.bin` —— Windows 安装程序。该 item 里 1.12.1 只有这一份。 |
| archive.org `WoWArchive-Part-1` | ❌ 146 GB，专有 `.bundle` 格式，不实用。 |
| dkpminus / wowdl 等站点 | 链接指向 Mega / Google Drive / sendspace，难以自动化，且有配额限制。 |

## 一份资源，两处使用

把客户端放进 `vmangos-deploy/storage/mangosd/client-data/`（内含 `Data/`），
然后让客户端的资源提取器**指向同一个 `Data` 目录**。服务端提取器和客户端提取器
读同一份 MPQ，省下约 5 GB 重复存储。

## 磁盘预算（Vanilla 1.12.1）

| 项 | 大小 |
|---|---|
| 客户端 zip（可在解压后删除） | 5.3 GB |
| 解压后的客户端 | 5.5 GB |
| 服务端 maps + vmaps + dbc | 0.9 GB |
| 服务端 mmaps | 1.9 GB |
| 客户端提取后的散文件资源 | 6.4 GB |
| **合计** | **约 20 GB**（下载过程峰值 25 GB）|
