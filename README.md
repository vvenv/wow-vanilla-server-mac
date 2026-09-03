# wow-vanilla-server-mac

*中文 · [English](README.en.md)*

在 macOS（Apple Silicon）上从零搭建一套本地 **World of Warcraft Vanilla 1.12.1** 私服 +
可玩客户端，全程本地运行，不依赖任何外部托管。

以 [Claude Code Skill](https://docs.claude.com/en/docs/claude-code/skills) 形式提供：
放进项目后说一句「帮我在本地搭一个 WoW 私服」即可触发；也可以完全当作人类阅读的
操作手册 + 脚本工具箱使用。

## 这个仓库解决什么

搭建过程本身不难，难的是散落各处、且大量过时的信息。这里记录的是**实际跑通一遍**
所付出的代价：

- **AzerothCore 不支持 Vanilla 1.12。** 它只有 WotLK 3.3.5a，没有 1.12 分支。这是最常见的
  方向性错误，`SKILL.md` 开头就把范围钉死在 VMaNGOS + 1.12.1，不再重开这个话题。
- **`StrictVersionCheck = 0` 是任何非原版客户端的硬性前提。** 默认值 `1` 会校验客户端
  二进制的完整性哈希，重实现客户端算不出来，表现为 `Login failed: Version mismatch`——
  但 SRP6 密码校验其实是通过的，极易误判成账号问题。
- **改 `realmlist.wtf` 不够**，`WTF/Config.wtf` 里缓存的 `SET realmList` 优先级更高。
- **Whisky 已于 2025-04 停止开发**，网上大量教程仍在推荐它。
- **5 GB 客户端包下载前可以先验货**：`scripts/peek-remote-zip.py` 用 HTTP Range 读远程
  ZIP 的中央目录，甚至能抽出里面的 `README`/`SHA256SUMS`。很多"客户端"其实是 Windows
  安装程序（`setup-N.bin`），macOS 上根本解不开。
- **`mmaps` 提取要几小时，但和登录无关**，可以拆开跑，先玩上再补。
- **独占全屏在 Wine 下会挂死，而它偏偏是默认值。** 客户端退出时重写 `Config.wtf` 会把
  `gxWindow` / `gxMaximize` 两行整个删掉，于是"什么都没改，下次开就全屏了"。
- **1.12 没有 `gxMonitor`，副屏和 Space 只能在 macOS 那侧解。** 一条 `strings` 就能定案；
  可行的两条路（辅助功能 API + 原生全屏 / 临时换主显示器）都只用公开 API，不需要关 SIP。

## 快速开始

```sh
# 作为 Claude Code Skill
mkdir -p .claude/skills
git clone https://github.com/vvenv/wow-vanilla-server-mac .claude/skills/vanilla-wow-local

# 或全局启用
git clone https://github.com/vvenv/wow-vanilla-server-mac ~/.claude/skills/vanilla-wow-local
```

然后对 Claude Code 说：**「帮我在本地搭一个 Vanilla WoW 私服」**。

手动使用则直接读 [`SKILL.md`](SKILL.md)，按 8 个步骤操作。

## 内容

| 文件 | 说明 |
|---|---|
| [`SKILL.md`](SKILL.md) | 主流程：环境勘察 → 下载 → 服务端 → 数据提取 → 客户端 → 建号 → 验证 → 上层玩法 |
| [`references/client-data.md`](references/client-data.md) | 客户端资源包来源实测、下载前验证方法、磁盘预算 |
| [`references/client-wine.md`](references/client-wine.md) | WoWSilicon 安装接入、realmlist 与打补丁的坑、窗口/全屏模式、让游戏开在副屏或独占一个 Space、`Config.wtf` 回写规则 |
| [`references/addons-and-mods.md`](references/addons-and-mods.md) | 1.12 插件兼容规则、`dlls.txt` 的 DLL 加载链、`patch-?.MPQ` 美术补丁 |

### 脚本

| 脚本 | 用途 |
|---|---|
| `scripts/peek-remote-zip.py` | 不下载整包，用 HTTP Range 读远程 ZIP 目录并抽取小文件 |
| `scripts/fetch-client.sh` | `aria2c -x16` 多线程下载（慢网络下比 curl 快一个数量级） |
| `scripts/02a-extract-maps-vmaps.sh` | 提取 maps/vmaps/dbc —— 几分钟，足够登录开玩 |
| `scripts/02b-extract-mmaps.sh` | 提取 mmaps 寻路网格 —— 数小时，可后台跑 |
| `scripts/04-mmaps-then-restart.sh` | 等 mmaps 完成，**校验产物后**才重启 mangosd |
| `scripts/mangos-console.py` | 用 pty 包装 `docker attach`，绕开 TTY 限制向服务端控制台发命令 |
| `scripts/auth-check.py` | 独立 SRP6 客户端，端到端验证认证链路（不依赖游戏客户端） |
| `scripts/wowsilicon-setup.sh` | 配置 WoWSilicon：realmlist 双处修改 + 补丁补齐 + 就绪检查 |
| `scripts/wowsilicon-launch.sh` | 绕开启动器 UI 直接拉起游戏（Play 按钮静默失败时兜底） |

## 上游项目

本仓库只是流程与工具，实际组件均来自这些项目：

- [VMaNGOS](https://github.com/vmangos/core) —— Vanilla 服务端核心
- [vmangos-deploy](https://github.com/mserajnik/vmangos-deploy) —— 提供 amd64/arm64 预编译镜像，免编译
- [WoWSilicon](https://github.com/WoWSilicon/WoWSilicon) —— Apple Silicon 上跑原版客户端
- [Wowee](https://github.com/Kelsidavis/WoWee) —— 从零重写的开源原生客户端（已评估并放弃，原因见 `references/client-wine.md`）
- [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) —— WotLK 3.3.5a 服务端（供版本路由参考）

## 关于游戏资源

本仓库**不包含也不分发任何暴雪的游戏资源、二进制或代码**。所有 MPQ、DBC、美术资源
都需要你自行提供一份合法取得的客户端；文档只说明如何验证与提取。

## License

MIT
