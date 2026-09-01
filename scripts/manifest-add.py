#!/usr/bin/env python3
"""把本地新增/修改的资源文件登记进 Wowee 的 manifest.json。
用法: manifest-add.py <相对于 expansions/classic 的 posix 路径> [...]
"""
import json, zlib, os, sys, shutil

D = os.environ.get("WOW_DATA_PATH_EXP") or os.path.expanduser(
    "~/Library/Application Support/Wowee/Data/expansions/classic")
MF = f"{D}/manifest.json"
m = json.load(open(MF))
e = m["entries"]
changed = 0
for rel in sys.argv[1:]:
    rel = rel.replace("\\", "/").lstrip("./")
    full = os.path.join(D, rel)
    if not os.path.isfile(full):
        print(f"跳过（文件不存在）: {rel}"); continue
    b = open(full, "rb").read()
    key = rel.replace("/", "\\")
    e[key] = {"p": rel, "s": len(b), "h": format(zlib.crc32(b) & 0xffffffff, "08x")}
    print(f"登记 {key} -> size={len(b)} crc={e[key]['h']}")
    changed += 1
if changed:
    m["fileCount"] = len(e)
    if not os.path.exists(MF + ".bak"):
        shutil.copy2(MF, MF + ".bak")
    json.dump(m, open(MF, "w"), separators=(",", ":"))
    print(f"清单已更新，条目总数 {m['fileCount']}")
