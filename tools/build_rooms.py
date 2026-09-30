"""Builds the room layouts in scripts/rooms.gd from simple drawing commands.

Rooms are drawn here as rectangles of stone, spikes, doors and markers, then written out
as the ASCII maps rooms.gd uses. Run from the project root:  python tools/build_rooms.py
It checks that every row is the same width and that every door links to a door that
exists in the room it leads to, then rewrites the LAYOUTS block in scripts/rooms.gd.

Legend (see rooms.gd):  # stone  . air  ^ spikes  P start  E crawler  * shockline anchor
  I/F/L blade pieces  W wall jump  R rest shrine  H mask shard (max health)
  B boss  ? sign (text from SIGNS, in reading order)  a-z doors
"""
import re

ROOMS = {}


class Room:
    def __init__(self, name, w, h):
        self.name = name
        self.w, self.h = w, h
        self.g = [["." for _ in range(w)] for _ in range(h)]
        self.box(0, 0, w - 1, 0)
        self.box(0, h - 1, w - 1, h - 1)
        self.box(0, 0, 0, h - 1)
        self.box(w - 1, 0, w - 1, h - 1)
        ROOMS[name] = self

    def fill(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = ch

    def box(self, x0, y0, x1, y1):
        self.fill(x0, y0, x1, y1, "#")

    def air(self, x0, y0, x1, y1):
        self.fill(x0, y0, x1, y1, ".")

    def put(self, x, y, ch):
        self.g[y][x] = ch

    def open_sky(self):
        """No ceiling: the forest opens to the sky (room.gd keeps Storm from leaving the top)."""
        self.air(1, 0, self.w - 2, 0)

    def floor(self, top):
        """Solid ground from row `top` down to the bottom."""
        self.box(0, top, self.w - 1, self.h - 1)

    def rows(self):
        return ["".join(r) for r in self.g]


# ---------------------------------------------------------------- Foothills (tutorial)
# Movement limits the layouts respect: a jump clears about 3 tiles up or 5 tiles across.
# Anything taller needs the wall jump; one-tile-high gaps need the slide.

r = Room("landing", 40, 17)
r.open_sky()
r.floor(15)
r.put(2, 14, "P")
r.put(4, 14, "R")
r.put(7, 14, "?")
r.box(14, 14, 18, 14)
r.box(15, 13, 18, 13)
r.box(16, 12, 18, 12)
r.box(24, 10, 29, 10)
r.put(21, 14, "?")
r.box(33, 13, 35, 14)
r.fill(39, 12, 39, 14, "a")

r = Room("rockfall", 56, 17)
r.open_sky()
r.floor(15)
r.fill(0, 12, 0, 14, "a")
r.fill(55, 12, 55, 14, "b")
r.fill(10, 15, 13, 15, "^")
r.box(20, 13, 23, 14)
r.box(21, 12, 23, 12)
r.put(6, 14, "?")
r.put(25, 14, "?")
r.fill(28, 15, 32, 15, "^")
r.box(27, 11, 30, 11)
r.box(33, 8, 36, 8)
r.put(35, 7, "E")
r.put(34, 14, "E")
r.fill(41, 15, 44, 15, "^")
r.box(46, 14, 48, 14)
r.put(52, 14, "E")

# The stone ring. The golden hilt glints in the middle, but the ring's floor (=) is a thin
# lid over a pit: stepping onto it drops Storm into the Guardian Centipede's lair. The
# pit's own walls are the arena. Beaten, the centipede leaves the hilt (the wall jump),
# which is also the only way back up. A side tunnel the centipede dug hides a mask shard.
r = Room("ring", 46, 40)
r.open_sky()
r.floor(12)
r.fill(0, 9, 0, 11, "b")
r.put(4, 11, "R")
r.put(8, 11, "?")
r.fill(13, 12, 32, 12, "=")
r.air(13, 13, 32, 36)
r.put(22, 36, "B")
# A few footholds on the pit walls for catching a breath on the way up.
r.box(13, 27, 14, 27)
r.box(31, 21, 32, 21)
# The side tunnel, dug through the left pit wall.
r.air(5, 32, 12, 34)
r.put(6, 34, "H")
r.put(39, 11, "?")
r.fill(45, 9, 45, 11, "d")

# The cliff. A narrow chimney first, where the wall jump is easy to learn, then the left wall
# falls away and it's a single rock face with the forest open below. Notches cut into the
# face (nothing sticking out to bump into) give places to stand and rest.
r = Room("cliff", 30, 56)
r.open_sky()
r.air(0, 0, 0, 50)
r.floor(54)
r.fill(0, 51, 0, 53, "d")
r.put(4, 53, "?")
r.box(20, 8, 29, 53)
r.box(12, 36, 13, 50)
r.air(20, 42, 21, 44)
r.air(20, 28, 21, 30)
r.air(20, 16, 21, 18)
r.put(21, 7, "?")
r.put(25, 7, "R")
r.fill(29, 5, 29, 7, "f")

# The gate cavern. Across it, the frozen gate (G) seals the way to the village. The
# centipede's return turns its body into the arena's walls; its death shatters the gate.
r = Room("gate_cavern", 40, 18)
r.floor(16)
r.fill(0, 13, 0, 15, "f")
r.box(35, 1, 38, 9)
r.fill(35, 10, 36, 15, "G")
r.fill(39, 13, 39, 15, "g")
r.put(20, 15, "B")

# ---------------------------------------------------------------- Frozen village (ice)

r = Room("village_square", 60, 19)
r.floor(17)
r.fill(0, 14, 0, 16, "g")
r.fill(59, 14, 59, 16, "h")
r.put(30, 16, "R")
r.put(26, 16, "?")
r.box(17, 14, 20, 14)
r.box(22, 11, 26, 11)
r.put(24, 10, "?")
# The ice climb: up the stairs on the right, then a crawlspace only a slide fits through.
r.box(36, 14, 39, 14)
r.box(41, 11, 44, 11)
r.box(37, 8, 40, 8)
r.box(43, 6, 58, 6)
r.box(44, 1, 50, 4)
r.air(44, 5, 50, 5)
r.fill(59, 3, 59, 5, "j")
r.put(14, 16, "E")
r.put(48, 16, "E")

r = Room("ice_caverns", 50, 24)
r.floor(22)
r.fill(0, 3, 0, 5, "h")
r.box(1, 6, 8, 6)
r.box(11, 9, 16, 9)
r.put(14, 8, "E")
r.box(19, 12, 24, 12)
r.box(27, 15, 32, 15)
r.put(30, 14, "E")
r.box(35, 18, 40, 18)
r.box(43, 19, 46, 19)
# The floor under the drop is spikes: falling returns you to the last ledge. Past it, a
# covered alcove on the far left hides the frozen cellar, reached only by shockline.
r.fill(5, 22, 30, 22, "^")
r.box(1, 16, 6, 18)
r.fill(0, 19, 0, 21, "i")
r.put(23, 19, "*")
r.put(14, 19, "*")
r.put(7, 19, "*")
r.put(47, 21, "?")
r.fill(49, 19, 49, 21, "k")

r = Room("frost_arena", 44, 18)
r.floor(16)
r.fill(0, 13, 0, 15, "k")
r.fill(43, 13, 43, 15, "l")
r.box(7, 13, 10, 13)
r.box(33, 13, 36, 13)
r.put(30, 15, "B")

r = Room("frozen_depths", 64, 18)
r.floor(16)
r.fill(0, 13, 0, 15, "l")
r.fill(63, 13, 63, 15, "m")
r.put(5, 15, "?")
# Low gaps: a wall with a one-tile slot at the floor that only a slide fits under.
r.box(14, 1, 17, 14)
r.put(24, 15, "E")
r.fill(28, 16, 31, 16, "^")
r.box(36, 1, 41, 14)
r.put(46, 15, "E")
r.box(50, 13, 53, 13)
r.box(56, 1, 58, 14)

r = Room("frost_throne", 44, 18)
r.floor(16)
r.fill(0, 13, 0, 15, "m")
r.fill(43, 13, 43, 15, "n")
r.box(6, 13, 9, 13)
r.box(20, 10, 23, 10)
r.box(34, 13, 37, 13)
r.put(30, 15, "B")

# Up the mountain: ledges three tiles apart, then a crawlspace to the exit at the top.
r = Room("ice_climb", 28, 32)
r.floor(30)
r.fill(0, 27, 0, 29, "n")
r.fill(0, 21, 0, 23, "j")
r.box(8, 27, 12, 27)
r.box(1, 24, 5, 24)
r.box(9, 21, 13, 21)
r.box(17, 18, 21, 18)
r.put(19, 17, "E")
r.box(23, 15, 26, 15)
r.box(15, 12, 19, 12)
r.box(7, 9, 11, 9)
r.box(8, 6, 26, 6)
r.box(10, 1, 21, 4)
r.fill(27, 3, 27, 5, "o")
r.put(22, 29, "?")

r = Room("frozen_cellar", 24, 14)
r.floor(12)
r.fill(23, 8, 23, 10, "i")
r.box(15, 11, 22, 11)
r.put(4, 11, "H")
r.put(10, 11, "?")

r = Room("broken_bridge", 56, 17)
r.floor(15)
r.fill(0, 11, 0, 14, "o")
r.fill(9, 15, 13, 15, "^")
r.fill(31, 15, 51, 15, "^")
r.put(36, 12, "*")
r.put(43, 12, "*")
r.put(50, 12, "*")
r.put(26, 13, "L")

LINKS = {
    "landing": {"a": ("rockfall", "a")},
    "rockfall": {"a": ("landing", "a"), "b": ("ring", "b")},
    "ring": {"b": ("rockfall", "b"), "d": ("cliff", "d")},
    "cliff": {"d": ("ring", "d"), "f": ("gate_cavern", "f")},
    "gate_cavern": {"f": ("cliff", "f"), "g": ("village_square", "g")},
    "village_square": {"g": ("gate_cavern", "g"), "h": ("ice_caverns", "h"), "j": ("ice_climb", "j")},
    "ice_caverns": {"h": ("village_square", "h"), "k": ("frost_arena", "k"), "i": ("frozen_cellar", "i")},
    "frost_arena": {"k": ("ice_caverns", "k"), "l": ("frozen_depths", "l")},
    "frozen_depths": {"l": ("frost_arena", "l"), "m": ("frost_throne", "m")},
    "frost_throne": {"m": ("frozen_depths", "m"), "n": ("ice_climb", "n")},
    "ice_climb": {"n": ("frost_throne", "n"), "j": ("village_square", "j"), "o": ("broken_bridge", "o")},
    "frozen_cellar": {"i": ("ice_caverns", "i")},
    "broken_bridge": {"o": ("ice_climb", "o")},
}


def check():
    for name, room in ROOMS.items():
        rows = room.rows()
        assert all(len(row) == room.w for row in rows), name
        doors = {c for row in rows for c in row if "a" <= c <= "z"}
        linked = set(LINKS.get(name, {}))
        assert doors == linked, "%s: doors %s but links %s" % (name, sorted(doors), sorted(linked))
        for door, (dest, dest_door) in LINKS[name].items():
            assert dest in ROOMS, "%s links to missing room %s" % (name, dest)
            assert LINKS[dest].get(dest_door) == (name, door), \
                "%s.%s -> %s.%s doesn't link back" % (name, door, dest, dest_door)


def gd_block():
    out = ["const LINKS := {"]
    for name, doors in LINKS.items():
        parts = ", ".join('"%s": ["%s", "%s"]' % (d, dest, dd) for d, (dest, dd) in doors.items())
        out.append('\t"%s": {%s},' % (name, parts))
    out.append("}")
    out.append("")
    out.append("const LAYOUTS := {")
    for name, room in ROOMS.items():
        out.append('\t"%s": [' % name)
        for row in room.rows():
            out.append('\t\t"%s",' % row)
        out.append("\t],")
    out.append("}")
    return "\n".join(out) + "\n"


def main():
    check()
    path = "scripts/rooms.gd"
    src = open(path, encoding="utf-8").read()
    start = src.index("const LINKS := {")
    src = src[:start] + gd_block()
    open(path, "w", encoding="utf-8").write(src)
    for name, room in ROOMS.items():
        print("%-15s %dx%d" % (name, room.w, room.h))


if __name__ == "__main__":
    main()
