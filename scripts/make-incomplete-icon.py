#!/usr/bin/env python3
"""由 ActiveQuestIcon.blp 生成 vanilla 1.12.1 缺失的 IncompleteQuestIcon.blp。

原版 1.12.1 客户端没有这个文件（后续资料片才加入），但 Wowee 会去请求它，
找不到就退回 ActiveQuestIcon，导致"任务进行中"和"任务可交付"的 NPC 头顶
标记完全一样。

做法：BLP2/DXT3 里每 16 字节块的第 8-11 字节是两个 RGB565 颜色端点。
只把端点转成灰度并压暗，保留 2-bit 颜色索引与 8 字节 alpha 块 —— 形状、
边缘、透明度完全不变，只有色相变灰。
"""
import struct, sys, shutil

SRC = sys.argv[1]
DST = sys.argv[2]
LUMA_SCALE = 0.55          # 压暗，和黄色版本拉开区分度

def rgb565_to_grey(v):
    r = ((v >> 11) & 0x1F) / 31.0
    g = ((v >>  5) & 0x3F) / 63.0
    b = ( v        & 0x1F) / 31.0
    y = (0.299 * r + 0.587 * g + 0.114 * b) * LUMA_SCALE
    y = max(0.0, min(1.0, y))
    return (int(round(y * 31)) << 11) | (int(round(y * 63)) << 5) | int(round(y * 31))

data = bytearray(open(SRC, "rb").read())
assert data[:4] == b"BLP2", "不是 BLP2"
encoding, alpha_depth, alpha_enc, has_mips = data[8], data[9], data[10], data[11]
w, h = struct.unpack("<II", data[12:20])
offs = struct.unpack("<16I", data[20:84])
sizes = struct.unpack("<16I", data[84:148])
print(f"BLP2 {w}x{h} encoding={encoding} alphaDepth={alpha_depth} alphaEnc={alpha_enc} mips={has_mips}")
assert encoding == 2, f"只支持 DXT (encoding=2)，实际 {encoding}"
block = 16 if alpha_enc in (1, 7) else 8      # DXT3/DXT5 = 16B, DXT1 = 8B
coff = 8 if block == 16 else 0                # DXT1 颜色在块首，DXT3/5 在 alpha 之后

blocks = 0
for o, s in zip(offs, sizes):
    if o == 0 or s == 0:
        continue
    for b in range(o, o + s, block):
        p = b + coff
        c0, c1 = struct.unpack_from("<HH", data, p)
        struct.pack_into("<HH", data, p, rgb565_to_grey(c0), rgb565_to_grey(c1))
        blocks += 1

open(DST, "wb").write(data)
print(f"改写 {blocks} 个 DXT 块 -> {DST} ({len(data)} bytes)")
