# 客户端选型：重实现 vs 原版二进制

## 结论先行

**没有比 [Wowee](https://github.com/Kelsidavis/WoWee) 更成熟的开源"重实现"客户端**
（2026-02 上过 Hackaday，是这个赛道最靠前的）。但如果目标是"能正常玩"，更好的路子
不是换重实现，而是**跑原版 Blizzard 二进制**——它就是行为的参考实现，重实现的所有
协议/UI 缺口在它身上根本不存在。

| 方案 | 性质 | 取舍 |
|---|---|---|
| **WoWSilicon** | 自带 Wine 运行时跑原版 exe | 游戏行为 100% 正确；非原生，走翻译层 |
| **Wowee** | 从零重写的原生客户端 | 真 ARM64 + Vulkan，能效/帧数好；`classic` profile 有实打实的缺陷 |
| TurtleSilicon | 同类启动器 | **依赖 CrossOver ≥25.0.1（付费）**；WoWSilicon 自带运行时，一般没必要 |
| 原生 macOS 1.12.1 客户端 | — | ❌ 不可行。当年 Mac 版是 PPC + i386 通用二进制，32 位 Intel 自 Catalina 起无法运行 |

> ⚠️ **Whisky 已于 2025-04 停止开发。** 网上大量教程仍在推荐它，不要再照做。

## WoWSilicon 安装与接入本地服务器

[官网](https://wowsilicon.github.io/) · [GitHub](https://github.com/WoWSilicon/WoWSilicon) ·
GPLv3 · 要求 Apple Silicon + macOS 15+

内置 profile：`VanillaSilicon (1.12.1)` / `BurningSilicon (2.4.3)` / `WrathSilicon (3.3.5a)`；
图形后端可选 `d9vk`（Vulkan）或 `mtld3d`（Metal 原生，支持 HDR）。

```sh
# 取最新版本（发布页不一定列出版本号，用 API 更可靠）
curl -s https://api.github.com/repos/WoWSilicon/WoWSilicon/releases/latest \
  | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['tag_name']);\
[print(a['browser_download_url']) for a in d['assets']]"

hdiutil attach WoWSilicon-<ver>.dmg -nobrowse -quiet
cp -R /Volumes/WoWSilicon/WoWSilicon.app /Applications/
hdiutil detach /Volumes/WoWSilicon -quiet
```

**签名说明**：ad-hoc 签名（`TeamIdentifier=not set`），`spctl` 会报 rejected。但用
`aria2c`/`curl` 下载不会打 `com.apple.quarantine` 标记，因此可直接运行，**不需要绕过
Gatekeeper**。先 `xattr -l` 确认再决定。

### 配置文件可直接预填，不必手点

```
~/Library/Application Support/WoWSilicon/prefs.json      # 全局偏好
~/Library/Application Support/WoWSilicon/versions.json   # 各 profile 的 game_path 等
```

**编辑前先退出应用**，否则退出时会覆盖你的改动。

```python
import json, os
p = os.path.expanduser("~/Library/Application Support/WoWSilicon/versions.json")
d = json.load(open(p))
d["currentVersionID"] = "vanillasilicon"
d["versions"]["vanillasilicon"]["game_path"] = "/path/to/WoW-1.12.1"
json.dump(d, open(p, "w"), indent=2)
```

> `game_path` 用**符号链接是可以的**（实测 Wine 正常跑）。这样客户端可以和服务端的
> `storage/mangosd/client-data` 共用同一份 MPQ，省约 5 GB。

## ⚠️ 坑一：改 realmlist.wtf 不够，Config.wtf 会覆盖它

这是最常见的"改完还是连不上"。**两处都要改**：

```sh
echo "set realmlist 127.0.0.1" > "$GAME/realmlist.wtf"
sed -i '' 's|SET realmList ".*"|SET realmList "127.0.0.1"|' "$GAME/WTF/Config.wtf"
```

`WTF/Config.wtf` 里缓存的 `SET realmList` **优先级更高**。第三方整合包（如 Stonetavern）
两处都预设成了它们自己的服务器地址。

## ⚠️ 坑二：Play 按钮在补丁未应用前静默失败

应用**不写任何日志**，从终端启动也没有 stdout 输出，点 Play 毫无反应——很难定位。

补丁素材在应用包内：

```
/Applications/WoWSilicon.app/Contents/Resources/\
WoWSilicon-swift_WoWSiliconSwift.bundle/Patching/
├── winerosetta/{winerosetta.dll, libDllLdr.dll}
├── d9vk/d3d9.dll
├── rosettax87/{rosettax87, libRuntimeRosettax87}
├── x87sidecar/x87sidecar
├── libSiliconPatch/{vanilla,wotlk}/libSiliconPatch.dll
└── vanilla-tweaks/
```

**打好补丁的游戏目录应当满足**（可用来判断是否就绪）：

```sh
GAME=/path/to/WoW-1.12.1
test -f "$GAME/mods/winerosetta.dll"       # 必须
test -f "$GAME/mods/libDllLdr.dll"         # 必须
test -f "$GAME/d3d9.dll"                   # 根目录，D9VK
grep -q "mods/winerosetta.dll" "$GAME/dlls.txt"   # VanillaFixes 链式加载清单
```

`scripts/wowsilicon-setup.sh` 会检查并补齐这些。

> 应用自身也会做一部分补丁（例如备份并替换 `DivxDecoder.dll`）。优先在 UI 里完成
> 它提供的 patch 步骤；上面的手动补齐用于 UI 静默失败时兜底。

## 手动启动（UI 完全用不了时的兜底）

从实际运行的进程抓到的命令行，绕开启动器直接跑：

```sh
GAME=/path/to/WoW-1.12.1
APP=/Applications/WoWSilicon.app/Contents/Resources
cd "$GAME" && \
ROSETTA_X87_PATH="$APP/WoWSilicon-swift_WoWSiliconSwift.bundle/Patching/rosettax87/rosettax87" \
DYLD_LIBRARY_PATH="$APP/Wine/lib/external" \
WINE_LARGE_ADDRESS_AWARE=1 \
WINEDLLOVERRIDES="d3d9=n" \
MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS=1 \
DXVK_ASYNC=1 \
"$APP/Wine/bin/wine" "$GAME/WoW.exe"
```

## 验证跑通了

```sh
pgrep -fl "WoW.exe|wineserver"        # Wine 进程在
ls "$GAME/WoW.dxvk-cache"             # 已渲染过画面
docker compose logs realmd | grep -i authenticated   # 服务端收到登录
```
