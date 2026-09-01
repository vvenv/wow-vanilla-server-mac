#!/usr/bin/env python3
"""从 Spell.dbc 生成 WoweeSpellbookFilter addon 的数据表。

原版客户端会把带 SPELL_ATTR_HIDDEN_CLIENTSIDE (0x80) 的法术排除在技能书之外，
Wowee 没做这个过滤。这里导出两张表：
  HIDDEN_ID   —— 全部隐藏法术的 ID（精确，优先使用）
  HIDDEN_NAME —— 仅包含"不与任何可见法术重名"的隐藏法术名（保守回退）
"""
import struct, os

D = os.environ.get("WOW_DATA_PATH_EXP") or os.path.expanduser(
    "~/Library/Application Support/Wowee/Data/expansions/classic")
OUT = f"{D}/interface/AddOns/WoweeSpellbookFilter/SpellbookFilterData.lua"
HIDDEN = 0x80

b = open(f"{D}/dbfilesclient/spell.dbc", "rb").read()
rec, fld, rsz, ssz = struct.unpack("<IIII", b[4:20])
body, strs = b[20:20 + rec * rsz], b[20 + rec * rsz:]

def s(o):
    return "" if o == 0 else strs[o:strs.index(b"\0", o)].decode("utf-8", "replace")

hidden_ids, hidden_names, visible_names = [], set(), set()
for i in range(rec):
    r = body[i * rsz:(i + 1) * rsz]
    sid = struct.unpack("<I", r[0:4])[0]
    attr = struct.unpack("<I", r[24:28])[0]          # field 6  = Attributes
    nm = s(struct.unpack("<I", r[480:484])[0])       # field 120 = Name
    if attr & HIDDEN:
        hidden_ids.append(sid)
        if nm: hidden_names.add(nm)
    elif nm:
        visible_names.add(nm)

safe_names = sorted(hidden_names - visible_names)

def q(x):
    return '"' + x.replace("\\", "\\\\").replace('"', '\\"') + '"'

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8") as f:
    f.write("-- 由 bin/gen-spellbook-filter.py 从 Spell.dbc 自动生成，请勿手改\n")
    f.write(f"-- 隐藏法术 {len(hidden_ids)} 个；无重名冲突、可安全按名过滤的 {len(safe_names)} 个\n\n")
    f.write("WoweeSpellbookFilterData = {}\n\nWoweeSpellbookFilterData.byId = {\n")
    for i in range(0, len(hidden_ids), 20):
        f.write("".join(f"[{x}]=1," for x in hidden_ids[i:i + 20]) + "\n")
    f.write("}\n\nWoweeSpellbookFilterData.byName = {\n")
    for i in range(0, len(safe_names), 8):
        f.write("".join(f"[{q(x)}]=1," for x in safe_names[i:i + 8]) + "\n")
    f.write("}\n")

print(f"隐藏法术 ID {len(hidden_ids)} 个，安全名字 {len(safe_names)} 个")
print(f"写入 {OUT} ({os.path.getsize(OUT)} bytes)")
