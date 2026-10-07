"""A rough reachability check for the room layouts in scripts/rooms.gd.

Moves a stand-in for Storm around each room on the tile grid with his abilities' limits
(jump about 3 tiles up / 5 across, the double jump about 6 up, wall climbing on any wall
face that isn't spiked, the shockline 10 tiles out at up to ~34 degrees, the slide through
one-tile gaps) and reports which doors and pickups can be reached from each door. It's an
approximation (it ignores ceilings mid-jump, for one), meant to catch layouts that are
impossible, or that an ability meant to gate them doesn't actually gate.

    python tools/check_reach.py
"""
import math
import re

SRC = open("scripts/rooms.gd", encoding="utf-8").read()
START = SRC.index("const LAYOUTS := {")
ROOMS = {}
for m in re.finditer(r'\t"(\w+)": \[\n((?:\t\t".*",\n)+)', SRC[START:]):
    ROOMS[m.group(1)] = [line.strip()[1:-2] for line in m.group(2).strip().split("\n")]

JUMP = (3, 5)
DOUBLE = (6, 7)
SHOCK_RANGE = 10.0
SHOCK_ANGLE = math.radians(34)


class Room:
    def __init__(self, rows):
        self.rows = rows
        self.h = len(rows)
        self.w = len(rows[0])

    def cell(self, x, y):
        if x < 0 or x >= self.w:
            return "#"
        if y < 0:
            return "."
        if y >= self.h:
            return "#"
        return self.rows[y][x]

    def solid(self, x, y):
        return self.cell(x, y) in "#=G"

    def open(self, x, y):
        return not self.solid(x, y) and self.cell(x, y) != "^"

    def stand(self, x, y, small=False):
        """Storm's feet in cell (x, y): open there (and above, unless sliding), solid below."""
        if not self.open(x, y) or not self.solid(x, y + 1):
            return False
        return small or self.open(x, y - 1)


def reach(room, start, abilities):
    """Every standing spot (and ring) reachable from a starting standing spot."""
    stands = [(x, y) for y in range(room.h) for x in range(room.w) if room.stand(x, y)]
    crawl = [(x, y) for y in range(room.h) for x in range(room.w)
             if room.stand(x, y, small=True) and not room.stand(x, y)]
    rings = [(x, y) for y in range(room.h) for x in range(room.w) if room.cell(x, y) == "*"]
    seen = {start}
    todo = [start]

    def visit(p):
        if p not in seen:
            seen.add(p)
            todo.append(p)

    while todo:
        x, y = todo.pop()
        hanging = room.cell(x, y) == "*"
        # (Hanging, his feet are about 19 px below the ring's centre: 0.7 of a standing row.)
        feet_y = y + 0.7 if hanging else y
        # Walking (and sliding through crawlspaces, with the dash).
        if not hanging:
            for dx in (-1, 1):
                if room.stand(x + dx, y) or (abilities["dash"] and room.stand(x + dx, y, small=True)):
                    visit((x + dx, y))
        # Jumping (from the ground, a ring, or a wall), falling.
        up, across = DOUBLE if abilities["double_jump"] else JUMP
        for (sx, sy) in stands + (crawl if abilities["dash"] else []):
            rise = feet_y - sy
            if rise > up:
                continue
            drift = across + max(0.0, -rise) / 2.0
            if abs(sx - x) <= drift:
                visit((sx, sy))
        # Climbing a wall face (the sword catcher), unless it's spiked.
        if abilities["wall_jump"] and not hanging:
            for side in (-1, 1):
                cy = y
                while room.solid(x + side, cy - 1) and room.open(x, cy - 1) and room.open(x, cy - 2):
                    cy -= 1
                    for (sx, sy) in stands:
                        if cy - sy <= JUMP[0] and abs(sx - x) <= JUMP[1]:
                            visit((sx, sy))
        # The shockline: out to a ring roughly level ahead.
        if abilities["shockline"]:
            for (rx, ry) in rings:
                dx, dy = rx - x, (feet_y - 1.0) - ry
                dist = math.hypot(dx, dy)
                if 0 < dist <= SHOCK_RANGE and abs(dx) > 0 and math.atan2(abs(dy), abs(dx)) <= SHOCK_ANGLE:
                    visit((rx, ry))
    return seen


def door_spots(room, letter):
    cells = [(x, y) for y in range(room.h) for x in range(room.w) if room.cell(x, y) == letter]
    spots = set()
    for (x, y) in cells:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if room.stand(x + dx, y + dy) or room.stand(x + dx, y + dy, small=True):
                    spots.add((x + dx, y + dy))
    return spots


def marks(room, chars):
    return {(x, y) for y in range(room.h) for x in range(room.w) if room.cell(x, y) in chars}


def can_reach(name, frm, to, abilities):
    room = Room(ROOMS[name])
    starts = door_spots(room, frm)
    goals = door_spots(room, to) if len(to) == 1 and to.islower() else set()
    top = [(x, y) for (x, y) in marks(room, to) if y == 0] if to.islower() else []
    if top:
        # A door in the roof (or the sky): jumped up into from a spot close enough below it.
        up, across = DOUBLE if abilities["double_jump"] else JUMP
        for s in starts:
            for (x, y) in reach(room, s, abilities):
                feet = y + 0.7 if room.cell(x, y) == "*" else y
                if feet <= up and min(abs(x - dx) for dx, _ in top) <= across:
                    return True
        return False
    if not goals:  # a pickup: stand on or by it
        for (x, y) in marks(room, to):
            for dy in range(0, 3):
                for dx in (-1, 0, 1):
                    if room.stand(x + dx, y + dy):
                        goals.add((x + dx, y + dy))
    for s in starts:
        if reach(room, s, abilities) & goals:
            return True
    return False


SETS = {
    "none": {"wall_jump": False, "dash": False, "double_jump": False, "shockline": False},
    "hilt": {"wall_jump": True, "dash": False, "double_jump": False, "shockline": False},
    "base": {"wall_jump": True, "dash": True, "double_jump": False, "shockline": False},
    "fire": {"wall_jump": True, "dash": True, "double_jump": True, "shockline": False},
    "storm": {"wall_jump": True, "dash": True, "double_jump": False, "shockline": True},
    "all": {"wall_jump": True, "dash": True, "double_jump": True, "shockline": True},
}

# (room, from, to, abilities that should make it, abilities that shouldn't)
EXPECT = [
    ("thicket", "a", "b", ["none"], []),
    ("sunken_glade", "a", "b", ["none"], []),
    ("fern_gully", "f", "e", ["hilt"], ["none"]),
    ("frozen_street", "g", "h", ["hilt"], []),
    ("icefall_hall", "h", "i", ["hilt"], []),
    ("glacier_run", "l", "m", ["base"], []),
    ("smoke_hollow", "s", "t", ["base"], []),
    ("smoke_hollow", "t", "s", ["base"], []),
    ("slag_works", "t", "u", ["base"], []),
    ("bellows_hall", "w", "x", ["base"], []),
    ("bellows_hall", "x", "w", ["fire"], []),
    ("lookout", "s", "t", ["base"], []),
    ("lookout", "t", "s", ["base"], []),
    ("rod_field", "t", "u", ["base"], []),
    ("chain_ravine", "v", "w", ["storm"], ["base", "fire"]),
    ("ember_span", "a", "b", ["base"], []),
    ("cinder_ridge", "a", "b", ["fire"], ["base"]),
    ("cinder_ridge", "b", "a", ["base"], []),
    ("gale_ledges", "a", "b", ["storm"], ["base"]),
    ("aqueduct", "a", "b", ["base"], []),
    ("aqueduct", "b", "a", ["base"], []),
    ("ashen_road", "q", "s", ["base"], []),
    ("burning_homes", "s", "t", ["base"], []),
    ("burning_homes", "s", "H", ["storm"], ["base", "fire"]),
    ("forge", "t", "v", ["base"], []),
    ("cinder_steps", "v", "w", ["fire"], ["base", "storm"]),
    ("drake_roost", "w", "x", ["base"], []),
    ("fire_shaft", "x", "y", ["fire"], ["base", "storm"]),
    ("cliff_road", "r", "s", ["base"], []),
    ("storm_bridges", "s", "t", ["base"], []),
    ("storm_bridges", "s", "H", ["fire"], ["base", "storm"]),
    ("spire", "t", "u", ["base"], []),
    ("anchor_gorge", "u", "v", ["storm"], ["base", "fire"]),
    ("thunder_eyrie", "v", "w", ["base"], []),
    ("storm_tower", "w", "z", ["storm"], ["base", "fire"]),
    ("high_pass", "y", "z", ["base"], []),
    ("refuge", "f", "g", ["base"], []),
    ("old_barracks", "f", "H", ["hilt"], []),
    ("storehouse", "g", "H", ["base"], ["hilt"]),
    ("windward_pass", "z", "y", ["base"], []),
    ("windward_pass", "y", "z", ["base"], []),
    ("summit_ledge", "z", "y", ["base"], []),
    ("summit_ledge", "y", "z", ["base"], []),
    ("high_pass", "y", "c", ["all"], ["fire", "storm"]),
    ("high_pass", "z", "c", ["all"], ["fire", "storm"]),
    ("castle_gate", "c", "d", ["all"], []),
    ("castle_gate", "d", "c", ["base"], []),
    ("ramparts", "d", "e", ["base"], []),
    ("ramparts", "e", "d", ["base"], []),
    ("great_hall", "e", "g", ["base"], []),
    ("great_hall", "g", "e", ["base"], []),
    ("great_hall", "e", "f", ["all"], []),
    ("chapel", "f", "H", ["all"], []),
    ("library", "g", "h", ["all"], []),
    ("bell_tower", "h", "i", ["all"], ["fire"]),
    ("throne_approach", "i", "j", ["base"], []),
    ("rockfall", "a", "m", ["storm"], ["base", "fire"]),
    ("frozen_street", "g", "n", ["fire"], ["base", "storm"]),
    ("smoke_hollow", "t", "u", ["storm"], ["base", "fire"]),
    ("lookout", "s", "u", ["fire"], ["base", "storm"]),
    ("windward_pass", "z", "w", ["all"], ["fire", "storm"]),
    ("hollow_oak", "m", "H", ["base"], []),
    ("snowed_loft", "n", "K", ["base"], []),
    ("charcoal_loft", "u", "H", ["base"], []),
    ("bell_hut", "u", "K", ["base"], []),
    ("watch_post", "w", "H", ["base"], []),
]


def main():
    bad = 0
    for name, frm, to, yes, no in EXPECT:
        for key in yes:
            if not can_reach(name, frm, to, SETS[key]):
                print("FAIL %s: %s -> %s should be reachable with %s" % (name, frm, to, key))
                bad += 1
        for key in no:
            if can_reach(name, frm, to, SETS[key]):
                print("FAIL %s: %s -> %s shouldn't be reachable with only %s" % (name, frm, to, key))
                bad += 1
    print("all good" if bad == 0 else "%d problems" % bad)


if __name__ == "__main__":
    main()
