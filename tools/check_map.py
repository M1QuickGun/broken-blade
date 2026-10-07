"""Checks the map: no two rooms overlap where rooms.gd's MAP places them.

    python tools/check_map.py
"""
import re

SRC = open("scripts/rooms.gd", encoding="utf-8").read()
m = SRC[SRC.index("const MAP := {"):]
m = m[:m.index("}")]
pos = {k: (int(a), int(b)) for k, a, b in re.findall(r'"(\w+)": Vector2i\((-?\d+), (-?\d+)\)', m)}
lay = SRC[SRC.index("const LAYOUTS"):]
size = {}
for mm in re.finditer(r'\t"(\w+)": \[\n((?:\t\t".*",\n)+)', lay):
    rows = [r.strip()[1:-2] for r in mm.group(2).strip().split("\n")]
    size[mm.group(1)] = (len(rows[0]), len(rows))
rects = {k: (pos[k][0], pos[k][1], pos[k][0] + size[k][0], pos[k][1] + size[k][1]) for k in pos}
bad = 0
names = list(rects)
for i, a in enumerate(names):
    for b in names[i + 1:]:
        A, B = rects[a], rects[b]
        if A[0] < B[2] and B[0] < A[2] and A[1] < B[3] and B[1] < A[3]:
            print("overlap:", a, b)
            bad += 1
print("map clear" if bad == 0 else "%d overlaps" % bad)
