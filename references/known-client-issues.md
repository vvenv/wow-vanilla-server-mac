# Wowee `classic` profile 已知缺陷与本地修复

以下均为 Wowee 3.1.16 `classic`（Vanilla 1.12.1）实测结果。
**这些都不是服务端或资源包的问题** —— 提取出的 79733 个文件、154 个 DBC、2684 个图标
全部完整且正确，已逐项核对。

**如果这些缺陷不可接受，最佳解法是换客户端而不是换资料片**：用
[WoWSilicon](https://wowsilicon.github.io/) 跑原版 Blizzard 1.12.1 二进制，下列问题
全部不存在（它就是行为的参考实现）。见 `references/native-clients.md`。

两个客户端可以共存，连同一个服务器、同一个角色，方便直接对比。

---

## ❌ 登录报 "Version mismatch"（必须处理，否则进不去）

realmd 日志：`[AuthChallenge] Account X tried to login with modified client!`

`StrictVersionCheck = 1`（默认）会校验客户端二进制的 integrity hash
（1.12.1 enUS 为 `95EDB27C7823B363CBDDAB56A392E7CB73FCCA20`）。任何重新实现的客户端
都算不出来。

**修复**：`config/realmd.conf` 设 `StrictVersionCheck = 0`，重启 realmd。

SRP6 密码校验不受影响 —— 只有版本证明这一步失败，所以很容易误判成密码或账号问题。
用 `scripts/auth-check.py` 可以把两者区分开。

---

## ✅ 任务进行中 / 可交付的 NPC 标记分不清（可本地修复）

客户端日志：
```
Texture not found: interface\gossipframe\incompletequesticon.blp
Quest marker: ... is not in this client's data - drawing ActiveQuestIcon.blp instead
```

`IncompleteQuestIcon.blp` 在 vanilla 1.12.1 里**本就不存在**（后续资料片才加入）。
Wowee 请求它，找不到便退回 `ActiveQuestIcon`，于是两种状态图标相同。

**修复**：由 `ActiveQuestIcon.blp` 生成灰度版本。

```sh
D="$HOME/Library/Application Support/Wowee/Data/expansions/classic"
scripts/make-incomplete-icon.py "$D/interface/gossipframe/activequesticon.blp" \
                                "$D/interface/gossipframe/incompletequesticon.blp"
scripts/manifest-add.py interface/gossipframe/incompletequesticon.blp
```

原理：BLP2/DXT3 每 16 字节块中，第 8-11 字节是两个 RGB565 颜色端点。只改端点、
保留 2-bit 颜色索引与 8 字节 alpha 块 —— 形状、边缘、透明度完全不变，仅色相变灰。
不需要完整的 DXT 重编码。

---

## ✅ 技能书混入大量内部法术（可本地修复；并非"图标缺失"）

表象是"技能书里很多图标缺失"，实际上**图标解析 100% 正确**。

真正原因：Wowee 未过滤带 `SPELL_ATTR_HIDDEN_CLIENTSIDE`（`0x80`）的法术。
Spell.dbc 共 22357 条，其中 **4951 条（22%）** 带此标志，原版客户端全部隐藏。
这些内部法术（`Attacking` / `Closing` / `Detect` / `Defensive State (DND)` 等）
的图标本就是占位图 `Interface\Icons\Temp`（一张笑脸），看起来像缺失。

> 连玩家真正的 `Attack`（id 6603）在原版里图标也是那张笑脸，属正常。

**修复**：addon `WoweeSpellbookFilter` 在 Lua 层重建"可见索引 → 原始索引"映射，
并重定向所有按索引取值的 API：`GetSpellName` / `GetSpellTexture` /
`GetSpellCooldown` / `IsSpellPassive` / `CastSpell` / `PickupSpell` /
`GetSpellTabInfo` / `GetSpellLink` / `GetSpellDescription` / `GetSpellAutocast`。

```sh
scripts/gen-spellbook-filter.py     # 从 Spell.dbc 生成数据表
scripts/manifest-add.py interface/AddOns/WoweeSpellbookFilter/...
```

**过滤采用双策略，避免误伤**：

1. 优先用 `GetSpellLink` 解出的 **spellId** 精确匹配（4951 个隐藏 ID）
2. 拿不到 ID 才按名字匹配，且**只用 2250 个与可见法术无重名冲突的名字**

第 2 条至关重要：隐藏法术名共 2695 个，其中 **445 个与可见法术重名**
（如 `Adrenaline Rush` 既有隐藏版，也有真实的盗贼技能）。这 445 个一律不过滤 ——
宁可少滤，不可误杀。

---

## ❌ 训练师列表显示 "Spell 0"（无法本地修复）

Wowee 的 vanilla `SMSG_TRAINER_LIST` 解析器字段错位。**在编译好的 native 代码里，
Lua 层无法修复。**

证据链：

- VMaNGOS 的 `SendTrainerSpellHelper` 写入 `maxcount * 38` 字节/条，字段顺序与
  MaNGOS / 原版客户端一致 —— **服务端正确**
- 客户端日志 `Trainer: Loaded 22357 spell names from Spell.dbc` —— DBC 加载正常
- 客户端 `dbc_layouts.json` 的 Spell 布局（`Name=120 / Rank=129 / IconID=117 /
  Description=138`）与 vanilla 逐字段吻合 —— **布局定义正确**
- 第一条解析正确，其后全部 `spellId = 0`
- 技能需求读出 `1677787136 = 0x64010000`，拆开为
  `[00 00] spellId 高位 + [01] state + [64] cost 低字节` —— 证明读取指针落在条目偏移 `+2`

**解法**：换用 WoWSilicon 跑原版二进制即可，该问题不存在。

`WoweeTrainerFix` addon 只能兜住由此引发的 Lua 崩溃
（`bad argument #2 to 'rawformat' (string expected, got nil)`，位于
`Blizzard_TrainerUI.lua` 的 `ClassTrainer_SetSelection`），把 nil 兜成 `?`。
治标不治本，但避免整个技能详情面板渲染中断。

---

## 移除全部本地修复

三处彼此独立，直接删除即可：

```sh
D="$HOME/Library/Application Support/Wowee/Data/expansions/classic"
rm -rf "$D/interface/AddOns/WoweeSpellbookFilter" "$D/interface/AddOns/WoweeTrainerFix"
rm -f  "$D/interface/gossipframe/incompletequesticon.blp"
mv     "$D/manifest.json.bak" "$D/manifest.json"     # 恢复原始清单
```

---

## 诊断技巧

- **日志位置取决于启动方式**：从 `.app` bundle 启动写入
  `<App>/Contents/Resources/logs/wowee.log`；命令行启动写入
  `~/Library/Logs/Wowee/wowee.log`。找不到就用
  `lsof -p $(pgrep -x wowee_bin) | grep '\.log'`。
- **`WOWEE_TEXTURE_MISS_LOG_KEYS` 是键数量上限，不是布尔开关。** 设成 `1` 只会记录
  1 条就抑制后续全部。要诊断请设成 `20000`。
- 其余可用开关见 `strings <App>/Contents/MacOS/wowee_bin | grep -E "^WOWEE_[A-Z_]+$"`。
