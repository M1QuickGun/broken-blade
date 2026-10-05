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
r.put(34, 14, "U")
r.fill(41, 15, 44, 15, "^")
r.box(46, 14, 48, 14)
r.put(47, 13, "E")

# The stone ring. The golden hilt glints in the middle of solid ground; pulling at it wakes the
# Guardian Centipede it's stuck in, and the earth under the ring (=) caves in: Storm drops into
# the pit with it. The pit's own walls are the arena. Beaten, the centipede flees and leaves
# the hilt (the wall jump), which is also the only way back up.
r = Room("ring", 46, 40)
r.open_sky()
r.floor(12)
r.fill(0, 9, 0, 11, "b")
r.put(4, 11, "R")
r.put(8, 11, "?")
r.fill(13, 12, 32, 36, "=")
r.put(22, 36, "B")
# Notches cut into the pit walls for catching a breath on the way up (nothing sticks out).
r.air(11, 25, 12, 27)
r.air(33, 19, 34, 21)
# (the notches stay earth, like the rest of the pit, until it caves in)
r.fill(11, 25, 12, 27, "=")
r.fill(33, 19, 34, 21, "=")
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
# The gate sits right at the cavern's end, against the way out, with rock above it.
r.box(35, 1, 38, 9)
r.fill(37, 10, 38, 15, "G")
r.fill(39, 13, 39, 15, "g")
r.put(20, 15, "B")

# ---------------------------------------------------------------- Frozen village (ice)

r = Room("village_square", 60, 19)
r.open_sky()
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
r.box(44, 0, 50, 4)
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

# The Frost Colossus is frozen into the ice wall at the cavern's end. The way on is a passage
# high in that wall, above its head: wall jump up the face once it's beaten.
r = Room("frost_arena", 30, 18)
r.floor(16)
r.fill(0, 13, 0, 15, "k")
r.box(20, 0, 29, 15)
r.air(20, 2, 28, 4)
r.fill(29, 2, 29, 4, "l")
r.box(2, 11, 4, 11)
# The ice it's frozen into runs down to the floor under it: a pedestal it rests on.
r.box(15, 13, 19, 15)
r.put(13, 15, "B")

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

# The frozen bridge: what's left of the stone bridge to the high mountain, over a chasm.
# Jump the gaps (frozen spikes below); slide under the fallen ice walls.
r = Room("frozen_bridge", 64, 18)
r.open_sky()
r.floor(15)
r.fill(0, 12, 0, 14, "o")
r.put(6, 14, "?")
r.air(14, 15, 17, 16)
r.fill(14, 17, 17, 17, "^")
r.box(24, 0, 30, 13)
r.put(33, 14, "E")
r.air(37, 15, 41, 16)
r.fill(37, 17, 41, 17, "^")
r.put(46, 14, "E")
r.box(50, 0, 54, 13)
r.put(55, 14, "E")
r.fill(63, 12, 63, 14, "p")

# The crossroads: a rest shrine where the mountain road splits. West (up the ledges) is the
# road to the fire slopes; east, the cliff road to the lightning peaks. High above the shrine
# a hidden ledge holds a mask shard: the double jump or the shockline reaches it.
r = Room("crossroads", 56, 24)
r.open_sky()
r.floor(23)
r.fill(0, 20, 0, 22, "p")
r.put(28, 22, "R")
r.put(24, 22, "?")
r.box(8, 20, 11, 20)
r.box(1, 17, 6, 17)
r.fill(0, 14, 0, 16, "q")
r.box(14, 20, 17, 20)
r.put(19, 16, "*")
r.box(21, 14, 27, 14)
r.put(24, 13, "H")
r.box(40, 20, 44, 20)
r.fill(55, 20, 55, 22, "r")

# ---------------------------------------------------------------- Fire slopes (west)
# The west face of the mountain, where the fire evil burned the homes and took the forge.
# Road in (slide) -> Burning homes (rest; a secret only the shockline reaches) -> the Forge
# (the Ashen Drake, first fight: the fire piece) -> Cinder steps (double jump tutorial) ->
# the Drake's roost (the rematch) -> the Fire shaft, climbed with the double jump, out onto
# the High pass. The climbs' walls are lined with spikes so the wall jump can't skip them.

r = Room("ashen_road", 60, 18)
r.open_sky()
r.floor(15)
r.fill(59, 12, 59, 14, "q")
r.fill(0, 12, 0, 14, "s")
r.put(54, 14, "?")
# A burnt beam fallen across the road: slide under it.
r.box(44, 0, 47, 13)
r.put(35, 14, "E")
r.air(26, 15, 29, 16)
r.fill(26, 17, 29, 17, "^")
r.box(18, 12, 21, 12)
r.put(10, 14, "E")

r = Room("burning_homes", 64, 22)
r.open_sky()
r.floor(19)
r.fill(63, 16, 63, 18, "s")
r.fill(0, 16, 0, 18, "t")
r.put(32, 18, "R")
r.put(28, 18, "?")
r.box(10, 16, 16, 18)
r.box(44, 16, 52, 18)
r.put(48, 15, "E")
# The secret: two rings from the first roof lead up to a ledge with a mask shard. Only the
# shockline gets there (too high for the double jump, too far from the walls to climb).
r.put(24, 12, "*")
r.put(32, 8, "*")
r.box(35, 7, 41, 7)
r.put(38, 6, "H")

r = Room("forge", 44, 18)
r.floor(16)
r.fill(43, 13, 43, 15, "t")
r.fill(0, 13, 0, 15, "v")
r.put(36, 15, "?")
# The Ashen Drake sleeps in the ashes at the forge's west end, the fire piece pinning its
# wing. Beaten, the piece comes loose (the double jump). A ledge high on each wall to perch on.
r.put(12, 15, "B")
r.box(1, 9, 3, 9)
r.box(40, 9, 42, 9)

r = Room("cinder_steps", 44, 40)
r.floor(37)
r.fill(43, 33, 43, 35, "v")
r.box(37, 36, 42, 36)
r.put(39, 35, "?")
r.fill(2, 36, 36, 36, "^")
r.fill(1, 6, 1, 35, "^")
r.fill(42, 2, 42, 32, "^")
r.box(29, 31, 32, 31)
r.box(21, 26, 24, 26)
r.box(13, 21, 16, 21)
r.box(21, 16, 24, 16)
r.box(13, 11, 16, 11)
r.box(8, 8, 11, 8)
r.box(1, 5, 5, 5)
r.fill(0, 2, 0, 4, "w")

r = Room("drake_roost", 44, 18)
r.floor(16)
r.fill(43, 13, 43, 15, "w")
r.fill(0, 13, 0, 15, "x")
r.put(30, 15, "?")
# Until the rematch is built, its reward waits here.
r.box(20, 14, 23, 15)
r.put(21, 13, "H")

r = Room("fire_shaft", 24, 56)
r.floor(54)
r.fill(23, 51, 23, 53, "x")
r.put(19, 53, "?")
r.fill(1, 2, 1, 53, "^")
r.fill(22, 6, 22, 50, "^")
for i, y in enumerate(range(49, 8, -5)):
    x = 14 if i % 2 == 0 else 6
    r.box(x, y, x + 3, y)
r.box(18, 5, 22, 5)
r.fill(23, 2, 23, 4, "y")

# ---------------------------------------------------------------- Lightning peaks (east)
# The east face, under the storm. Road in (slide) -> Storm bridges (rest; a secret only the
# double jump reaches) -> the Spire (the bound thing, first fight: the lightning tip) ->
# Anchor gorge (shockline tutorial) -> the Thunderbird's eyrie (the rematch) -> the Storm
# tower, climbed ring to ring with the shockline, out onto the High pass.

r = Room("cliff_road", 60, 18)
r.open_sky()
r.floor(15)
r.fill(0, 12, 0, 14, "r")
r.fill(59, 12, 59, 14, "s")
r.put(5, 14, "?")
# Rockfall across the road: slide under it.
r.box(14, 0, 17, 13)
r.put(24, 14, "E")
r.air(30, 15, 33, 16)
r.fill(30, 17, 33, 17, "^")
r.box(38, 12, 41, 12)
r.put(46, 14, "E")

r = Room("storm_bridges", 64, 22)
r.open_sky()
r.floor(19)
r.fill(0, 16, 0, 18, "s")
r.fill(63, 16, 63, 18, "t")
r.put(32, 18, "R")
r.put(36, 18, "?")
# A rope bridge over a chasm, with a gap torn in it.
r.air(20, 19, 27, 21)
r.box(20, 19, 23, 19)
r.box(26, 19, 27, 19)
r.fill(20, 21, 27, 21, "^")
r.put(12, 18, "E")
r.put(54, 18, "E")
# The secret: a ledge only the double jump reaches, from the rock beside it.
r.box(40, 16, 43, 18)
r.box(46, 11, 50, 11)
r.put(48, 10, "H")

r = Room("spire", 44, 18)
r.floor(16)
r.fill(0, 13, 0, 15, "t")
r.fill(43, 13, 43, 15, "u")
r.put(12, 15, "?")
# Until the Spire's fight is built, the lightning tip waits on its plinth.
r.box(20, 14, 23, 15)
r.put(21, 13, "L")

r = Room("anchor_gorge", 64, 20)
r.open_sky()
r.box(0, 13, 7, 19)
r.box(56, 13, 63, 19)
r.fill(8, 19, 55, 19, "^")
r.fill(0, 10, 0, 12, "u")
r.fill(63, 10, 63, 12, "v")
r.put(3, 12, "?")
for x in range(12, 56, 8):
    r.put(x, 9, "*")

r = Room("thunder_eyrie", 44, 18)
r.open_sky()
r.floor(16)
r.fill(0, 13, 0, 15, "v")
r.fill(43, 13, 43, 15, "w")
r.put(12, 15, "?")
# Until the rematch is built, its reward waits here.
r.box(20, 14, 23, 15)
r.put(21, 13, "H")

r = Room("storm_tower", 26, 56)
r.floor(54)
r.fill(0, 51, 0, 53, "w")
r.put(4, 53, "?")
r.fill(1, 10, 1, 50, "^")
r.fill(24, 2, 24, 53, "^")
for i, y in enumerate(range(48, 7, -4)):
    r.put(8 if i % 2 == 0 else 16, y, "*")
r.box(1, 9, 5, 9)
r.fill(0, 6, 0, 8, "z")

# ---------------------------------------------------------------- High pass
# The pass joining the tops of both faces. The castle gate above it needs the double jump
# and the shockline together (still to come).

r = Room("high_pass", 80, 20)
r.open_sky()
r.floor(17)
r.fill(0, 14, 0, 16, "y")
r.fill(79, 14, 79, 16, "z")
r.put(40, 16, "?")
r.box(18, 15, 22, 16)
r.box(57, 15, 61, 16)
r.put(28, 16, "E")
r.put(52, 16, "E")

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
    "ice_climb": {"n": ("frost_throne", "n"), "j": ("village_square", "j"), "o": ("frozen_bridge", "o")},
    "frozen_cellar": {"i": ("ice_caverns", "i")},
    "frozen_bridge": {"o": ("ice_climb", "o"), "p": ("crossroads", "p")},
    "crossroads": {"p": ("frozen_bridge", "p"), "q": ("ashen_road", "q"), "r": ("cliff_road", "r")},
    "ashen_road": {"q": ("crossroads", "q"), "s": ("burning_homes", "s")},
    "burning_homes": {"s": ("ashen_road", "s"), "t": ("forge", "t")},
    "forge": {"t": ("burning_homes", "t"), "v": ("cinder_steps", "v")},
    "cinder_steps": {"v": ("forge", "v"), "w": ("drake_roost", "w")},
    "drake_roost": {"w": ("cinder_steps", "w"), "x": ("fire_shaft", "x")},
    "fire_shaft": {"x": ("drake_roost", "x"), "y": ("high_pass", "y")},
    "cliff_road": {"r": ("crossroads", "r"), "s": ("storm_bridges", "s")},
    "storm_bridges": {"s": ("cliff_road", "s"), "t": ("spire", "t")},
    "spire": {"t": ("storm_bridges", "t"), "u": ("anchor_gorge", "u")},
    "anchor_gorge": {"u": ("spire", "u"), "v": ("thunder_eyrie", "v")},
    "thunder_eyrie": {"v": ("anchor_gorge", "v"), "w": ("storm_tower", "w")},
    "storm_tower": {"w": ("thunder_eyrie", "w"), "z": ("high_pass", "z")},
    "high_pass": {"y": ("fire_shaft", "y"), "z": ("storm_tower", "z")},
}


def check():
    for name, room in ROOMS.items():
        rows = room.rows()
        doors = [(x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if "a" <= c <= "z"]
        for y, row in enumerate(rows):
            for x, c in enumerate(row):
                if c in "EU":
                    for dx, dy in doors:
                        assert not (abs(dx - x) < 8 and abs(dy - y) < 6),                             "%s: enemy at %d,%d is right by a door" % (name, x, y)
        assert all(len(row) == room.w for row in rows), name
        doors = {c for row in rows for c in row if "a" <= c <= "z"}
        linked = set(LINKS.get(name, {}))
        assert doors == linked, "%s: doors %s but links %s" % (name, sorted(doors), sorted(linked))
        for door, (dest, dest_door) in LINKS[name].items():
            assert dest in ROOMS, "%s links to missing room %s" % (name, dest)
            assert LINKS[dest].get(dest_door) == (name, door), \
                "%s.%s -> %s.%s doesn't link back" % (name, door, dest, dest_door)


def door_cells(room, letter):
    rows = room.rows()
    return [(x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if c == letter]


def door_side(room, cells):
    xs = [c[0] for c in cells]
    ys = [c[1] for c in cells]
    if min(xs) == 0:
        return "left"
    if max(xs) == room.w - 1:
        return "right"
    if min(ys) == 0:
        return "top"
    return "bottom"


# Rooms nudged on the map from where their door would put them (in tiles), where the
# mountain's shape matters more than the doors lining up: the fire road climbs up the west
# face, above the ice.
MAP_NUDGE = {"ashen_road": (0, -26)}


def map_layout():
    """Where each room sits on the world map (top-left, in tiles): laid out from the start by
    following the doors, each room placed so its door meets the door it links to. The
    mountain loops back on itself in places, so a spot that would overlap a room already
    placed is skipped in favour of reaching that room another way (or, failing that, the
    room is nudged clear)."""
    def candidate(name, pos, door, dest, dest_door):
        room = ROOMS[name]
        ax, ay = pos[name]
        a_cells = door_cells(room, door)
        b_room = ROOMS[dest]
        b_cells = door_cells(b_room, dest_door)
        side = door_side(room, a_cells)
        a_x, a_y = min(c[0] for c in a_cells), min(c[1] for c in a_cells)
        b_x, b_y = min(c[0] for c in b_cells), min(c[1] for c in b_cells)
        if side == "right":
            return (ax + room.w, ay + a_y - b_y)
        if side == "left":
            return (ax - b_room.w, ay + a_y - b_y)
        if side == "top":
            return (ax + a_x - b_x, ay - b_room.h)
        return (ax + a_x - b_x, ay + room.h)

    def overlaps(name, at, pos):
        w, h = ROOMS[name].w, ROOMS[name].h
        for other, (ox, oy) in pos.items():
            ow, oh = ROOMS[other].w, ROOMS[other].h
            if at[0] < ox + ow and ox < at[0] + w and at[1] < oy + oh and oy < at[1] + h:
                return True
        return False

    pos = {"landing": (0, 0)}
    fallback = {}
    queue = ["landing"]
    while queue:
        name = queue.pop(0)
        for door, (dest, dest_door) in LINKS[name].items():
            if dest in pos:
                continue
            at = candidate(name, pos, door, dest, dest_door)
            nudge = MAP_NUDGE.get(dest, (0, 0))
            at = (at[0] + nudge[0], at[1] + nudge[1])
            if overlaps(dest, at, pos):
                fallback.setdefault(dest, at)
                continue
            pos[dest] = at
            queue.append(dest)
        if not queue:
            for dest, at in list(fallback.items()):
                if dest in pos:
                    continue
                while overlaps(dest, at, pos):
                    at = (at[0], at[1] + 2)
                pos[dest] = at
                queue.append(dest)
                break
    return pos


def gd_block():
    out = ["const LINKS := {"]
    for name, doors in LINKS.items():
        parts = ", ".join('"%s": ["%s", "%s"]' % (d, dest, dd) for d, (dest, dd) in doors.items())
        out.append('\t"%s": {%s},' % (name, parts))
    out.append("}")
    out.append("")
    out.append("## Each room's place on the world map (its top-left corner, in tiles).")
    out.append("const MAP := {")
    for name, (x, y) in map_layout().items():
        out.append('	"%s": Vector2i(%d, %d),' % (name, x, y))
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
