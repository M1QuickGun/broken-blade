"""Portfolio images for Broken Blade, composed from the game's own art and room data.

Run from the project folder:  python tools/make_portfolio_images.py
Writes into press/portfolio/. Scenes are built at the game's 960x540 art resolution
(sprites at native size, bosses at 2x their world size, as the game draws them) and
saved at 1920x1080.
"""
import math
import os
import random
import re

from PIL import Image, ImageDraw, ImageFont

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..") + "/"
OUT = R + "press/portfolio/"
os.makedirs(OUT, exist_ok=True)

W, H = 960, 540
T = 32  # one world tile (16 px) in art pixels
FLOOR = 15 * T
BG = (15, 17, 25, 255)
TEXT = (232, 236, 244, 255)
SUB = (154, 163, 181, 255)

STONE = {0: (0, 3), 1: (1, 3), 2: (0, 0), 3: (3, 0), 4: (0, 2), 5: (1, 0), 6: (2, 3), 7: (1, 1),
         8: (3, 3), 9: (0, 1), 10: (3, 2), 11: (2, 0), 12: (1, 2), 13: (2, 2), 14: (3, 1), 15: (2, 1)}


def font(size, face="georgia.ttf"):
    return ImageFont.truetype("C:/Windows/Fonts/" + face, size)


def img(path):
    return Image.open(R + path).convert("RGBA")


def frames(path, fw=96):
    im = img(path)
    return [im.crop((i * fw, 0, (i + 1) * fw, im.height)) for i in range(im.width // fw)]


def up(im, k):
    return im.resize((round(im.width * k), round(im.height * k)), Image.NEAREST)


def tint(im, k):
    r, g, b, a = im.split()
    if isinstance(k, (int, float)):
        k = (k, k, k)
    r, g, b = (ch.point(lambda v, m=m: min(255, int(v * m))) for ch, m in zip((r, g, b), k))
    return Image.merge("RGBA", (r, g, b, a))


def backdrop(path):
    """The painted backdrop, scaled to cover the screen."""
    bg = img(path)
    k = max(W / bg.width, H / bg.height)
    bg = up(bg, k)
    x, y = (bg.width - W) // 2, (bg.height - H) // 2
    return bg.crop((x, y, x + W, y + H))


def draw_tiles(canvas, sheet_path, solid):
    """Dual-grid tiles as room.gd draws them; `solid(x, y)` says which cells are rock."""
    sheet = img(sheet_path)
    cols, rows = W // T + 1, H // T + 1
    for vy in range(rows + 1):
        for vx in range(cols + 1):
            m = solid(vx - 1, vy - 1) * 8 + solid(vx, vy - 1) * 4 + solid(vx - 1, vy) * 2 + solid(vx, vy)
            if m:
                sx, sy = STONE[m]
                canvas.alpha_composite(sheet.crop((sx * T, sy * T, sx * T + T, sy * T + T)),
                                       (vx * T - T // 2, vy * T - T // 2))


def place(canvas, fr, foot_x, foot_y=FLOOR, flip=False):
    """A sprite frame standing with its lowest pixel on foot_y, centred on foot_x."""
    if flip:
        fr = fr.transpose(Image.FLIP_LEFT_RIGHT)
    box = fr.getbbox()
    canvas.alpha_composite(fr, (int(foot_x - (box[0] + box[2]) / 2), int(foot_y - box[3])))


def paste_xf(canvas, tex, pivot, at, angle=0.0, sx=1.0, sy=1.0):
    """Godot's draw_set_transform(at, angle, (sx, sy)) + draw_texture(tex, -pivot)."""
    c, s = math.cos(angle), math.sin(angle)
    ax, ay = at
    data = (c / sx, s / sx, pivot[0] - (c * ax + s * ay) / sx,
            -s / sy, c / sy, pivot[1] - (-s * ax + c * ay) / sy)
    canvas.alpha_composite(tex.transform(canvas.size, Image.AFFINE, data, Image.NEAREST))


def ellipse(canvas, cx, cy, rx, ry, color):
    layer = Image.new("RGBA", canvas.size)
    ImageDraw.Draw(layer).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=color)
    canvas.alpha_composite(layer)


def snow(canvas, n, seed):
    rng = random.Random(seed)
    layer = Image.new("RGBA", canvas.size)
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        x, y, r = rng.uniform(0, W), rng.uniform(0, H), rng.choice((1, 1, 2, 2, 3))
        d.ellipse((x - r, y - r, x + r, y + r), fill=(235, 242, 255, rng.randint(90, 200)))
    canvas.alpha_composite(layer)


def caption(canvas, title, sub=None):
    """A title in the bottom-left corner over a soft dark band."""
    band = Image.new("RGBA", canvas.size)
    d = ImageDraw.Draw(band)
    for i in range(140):
        d.line((0, canvas.height - i, canvas.width, canvas.height - i), fill=(5, 7, 12, int(190 * (1 - i / 140))))
    canvas.alpha_composite(band)
    d = ImageDraw.Draw(canvas)
    s = canvas.width / 1920
    y = canvas.height - (110 if sub else 80) * s
    d.text((52 * s + 3, y + 3), title, font=font(int(52 * s), "georgiab.ttf"), fill=(0, 0, 0, 180))
    d.text((52 * s, y), title, font=font(int(52 * s), "georgiab.ttf"), fill=TEXT)
    if sub:
        d.text((54 * s, y + 64 * s), sub, font=font(int(26 * s), "georgiai.ttf"), fill=SUB)


def save(canvas, name, k=2, title=None, sub=None):
    out = up(canvas, k) if k != 1 else canvas.copy()
    if title:
        caption(out, title, sub)
    out.convert("RGB").save(OUT + name)
    print(name, out.size)


def floor_solid(gaps=()):
    return lambda x, y: y >= 15 and not any(a <= x < b for a, b in gaps)


# --- Rooms data ------------------------------------------------------------------------------

src = open(R + "scripts/rooms.gd", encoding="utf-8").read()


def gd_block(name):
    start = src.index("const %s :=" % name)
    open_ch = src[src.index(":=", start) + 3]
    close_ch = {"{": "}", "[": "]"}[open_ch]
    i, depth = src.index(open_ch, start), 0
    for j in range(i, len(src)):
        depth += src[j] == open_ch
        depth -= src[j] == close_ch
        if depth == 0:
            return src[i:j + 1]


MAP = {m[0]: (int(m[1]), int(m[2]))
       for m in re.findall(r'"(\w+)":\s*Vector2i\((-?\d+),\s*(-?\d+)\)', gd_block("MAP"))}
LAYOUTS = {}
for name, body in re.findall(r'"(\w+)":\s*\[(.*?)\n\t\]', gd_block("LAYOUTS"), re.S):
    LAYOUTS[name] = re.findall(r'"([^"\n]*)"', body)
REGION_OF = {}
for key, region in [("FOREST_ROOMS", "foothills"), ("CAVE_ROOMS", "foothills"), ("ICE_ROOMS", "ice"),
                    ("FIRE_ROOMS", "fire"), ("STORM_ROOMS", "storm")]:
    for room in re.findall(r'"(\w+)"', gd_block(key)):
        REGION_OF[room] = region


# --- 1. Title card -----------------------------------------------------------------------------

def title_card():
    c = up(img("art/story/intro_1.png"), 1920 / 688).crop((0, 0, 1920, 1072)).resize((1920, 1080), Image.NEAREST)
    shade = Image.new("RGBA", c.size)
    d = ImageDraw.Draw(shade)
    for i in range(420):
        d.line((0, 1080 - i, 1920, 1080 - i), fill=(5, 7, 12, int(215 * (1 - i / 420))))
    c.alpha_composite(shade)
    d = ImageDraw.Draw(c)
    f = font(150, "georgiab.ttf")
    tw = d.textlength("BROKEN BLADE", font=f)
    d.text(((1920 - tw) / 2 + 5, 790 + 5), "BROKEN BLADE", font=f, fill=(0, 0, 0, 200))
    d.text(((1920 - tw) / 2, 790), "BROKEN BLADE", font=f, fill=(210, 222, 240))
    f2 = font(40, "georgiai.ttf")
    sub = "a shard, a hilt, and a mountain to climb"
    d.text(((1920 - d.textlength(sub, font=f2)) / 2, 975), sub, font=f2, fill=SUB)
    c.convert("RGB").save(OUT + "01_title.png")
    print("01_title.png", c.size)


# --- 2. Intro panels ---------------------------------------------------------------------------

INTRO = re.findall(r'\["res://art/story/(intro_\d)\.png",\s*"([^"]+)"\]',
                   open(R + "scripts/intro.gd", encoding="utf-8").read())


def wrap(d, text, f, width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if d.textlength(trial, font=f) > width and line:
            lines.append(line)
            line = word
        else:
            line = trial
    return lines + [line]


def intro_panels():
    panels = []
    for i, (name, text) in enumerate(INTRO, 1):
        p = up(img("art/story/%s.png" % name), 2)  # 1376x768
        band = Image.new("RGBA", p.size)
        d = ImageDraw.Draw(band)
        for k in range(200):
            d.line((0, p.height - k, p.width, p.height - k), fill=(5, 7, 12, int(220 * (1 - k / 200))))
        p.alpha_composite(band)
        d = ImageDraw.Draw(p)
        f = font(34, "georgiai.ttf")
        lines = wrap(d, text, f, p.width - 160)
        y = p.height - 50 - len(lines) * 46
        for line in lines:
            x = (p.width - d.textlength(line, font=f)) / 2
            d.text((x + 2, y + 2), line, font=f, fill=(0, 0, 0, 200))
            d.text((x, y), line, font=f, fill=TEXT)
            y += 46
        p.convert("RGB").save(OUT + "02_intro_%d.png" % i)
        print("02_intro_%d.png" % i, p.size)
        panels.append(p)
    # All four as one 2x2 board.
    gap = 16
    board = Image.new("RGBA", (1376 * 2 + gap * 3, 768 * 2 + gap * 3), BG)
    for i, p in enumerate(panels):
        board.alpha_composite(p, (gap + (i % 2) * (1376 + gap), gap + (i // 2) * (768 + gap)))
    board = board.resize((board.width // 2, board.height // 2), Image.LANCZOS)
    board.convert("RGB").save(OUT + "02_intro_board.png")
    print("02_intro_board.png", board.size)


# --- 3. World map ------------------------------------------------------------------------------

REGION_COLORS = {
    "foothills": ((28, 42, 32), (111, 154, 114)),
    "ice": ((27, 39, 52), (127, 179, 216)),
    "fire": ((46, 32, 25), (208, 135, 90)),
    "storm": ((38, 33, 58), (185, 164, 236)),
    "other": ((29, 35, 48), (111, 122, 144)),
}
REGION_NAMES = [("foothills", "Foothills"), ("ice", "Frozen village"), ("fire", "Fire slopes"),
                ("storm", "Lightning peaks")]


def world_map():
    rooms = [r for r in MAP if r in LAYOUTS]
    x0 = min(MAP[r][0] for r in rooms)
    y0 = min(MAP[r][1] for r in rooms)
    x1 = max(MAP[r][0] + len(LAYOUTS[r][0]) for r in rooms)
    y1 = max(MAP[r][1] + len(LAYOUTS[r]) for r in rooms)
    margin_top, margin = 230, 70
    z = (1920 - 2 * margin) / (x1 - x0)
    height = int(margin_top + (y1 - y0) * z + margin)
    ox = margin - x0 * z
    oy = margin_top - y0 * z
    c = Image.new("RGBA", (1920, height), (8, 10, 15, 255))
    d = ImageDraw.Draw(c)
    for room in rooms:
        fill, edge = REGION_COLORS[REGION_OF.get(room, "other")]
        rows = LAYOUTS[room]
        rx, ry = MAP[room]
        px, py = ox + rx * z, oy + ry * z
        d.rectangle((px, py, px + len(rows[0]) * z, py + len(rows) * z), fill=fill)
        rock = tuple(min(255, int(v * 0.55 + f * 0.45)) for v, f in zip(edge, fill))
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "#":
                    d.rectangle((px + x * z, py + y * z, px + (x + 1) * z - 1, py + (y + 1) * z - 1), fill=rock)
        d.rectangle((px, py, px + len(rows[0]) * z, py + len(rows) * z), outline=edge, width=2)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                cx, cy = px + (x + 0.5) * z, py + (y + 0.5) * z
                if ch == "R":
                    d.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), fill=(159, 230, 255))
                elif ch == "B":
                    d.regular_polygon((cx, cy - 2, 9), 4, rotation=45, fill=(240, 96, 96), outline=(255, 220, 220))
    d.text((70, 52), "World map", font=font(56, "georgiab.ttf"), fill=TEXT)
    for i, (key, label) in enumerate(REGION_NAMES):
        at = (72 + i * 260, 136)
        d.rectangle((at[0], at[1], at[0] + 24, at[1] + 20), fill=REGION_COLORS[key][0], outline=REGION_COLORS[key][1], width=2)
        d.text((at[0] + 36, at[1] - 4), label, font=font(26), fill=SUB)
    lx = 72 + 4 * 260
    d.ellipse((lx, 140, lx + 14, 154), fill=(159, 230, 255))
    d.text((lx + 26, 132), "Rest shrine", font=font(26), fill=SUB)
    d.regular_polygon((lx + 230, 147, 10), 4, rotation=45, fill=(240, 96, 96), outline=(255, 220, 220))
    d.text((lx + 250, 132), "Boss", font=font(26), fill=SUB)
    c.convert("RGB").save(OUT + "03_world_map.png")
    print("03_world_map.png", c.size, len(rooms), "rooms")


# --- 4. The Frost Colossus ---------------------------------------------------------------------

def colossus(canvas, x, floor_y, facing=1):
    """Phase 2 standing pose, as colossus.gd draws it; x and floor_y in art pixels."""
    torso, arm, arm_l, leg = (img("art/bosses/colossus_%s.png" % n) for n in ("torso", "arm", "arm_left", "leg"))
    k = 2.0  # world -> art pixels
    wx, wf = x / k, floor_y / k
    c = (wx, wf - 90 - 46)

    def on_torso(ax, ay):
        return (c[0] + (ax - 64) * facing, c[1] + (ay - 64))

    def P(p):
        return (p[0] * k, p[1] * k)

    hips = [(wx + facing * 18, wf - 90), (wx - facing * 18, wf - 90)]
    for hx, _ in hips:
        ellipse(canvas, hx * k, floor_y, 36, 6, (3, 12, 25, 140))
    flip = facing < 0
    paste_xf(canvas, tint(leg, 0.7), (30, 4), P(hips[1]), 0, k * facing, k)
    paste_xf(canvas, tint(arm_l, 0.7), (12, 28), P(on_torso(28, 52)), math.pi / 2 - facing * 0.2,
             0.95 * k, -0.95 * k if flip else 0.95 * k)
    paste_xf(canvas, torso, (64, 64), P(c), 0, k * facing, k)
    ex, ey = P(on_torso(100, 38))
    ellipse(canvas, ex, ey, 10, 10, (115, 242, 255, 90))
    ellipse(canvas, ex, ey, 5, 5, (170, 250, 255, 120))
    paste_xf(canvas, leg, (30, 4), P(hips[0]), 0, k * facing, k)
    paste_xf(canvas, arm, (12, 28), P(on_torso(102, 64)), math.pi / 2 - facing * 0.3,
             k, -k if flip else k)


def colossus_scene():
    c = backdrop("art/world/ice_cave_bg.png")
    c.alpha_composite(Image.new("RGBA", c.size, (10, 20, 35, 70)))
    draw_tiles(c, "art/world/ice_tileset.png", floor_solid())
    colossus(c, 330, FLOOR)
    place(c, frames("art/storm/full/attack2.png")[5], 690, flip=True)
    snow(c, 70, 3)
    save(c, "04_boss_frost_colossus.png", title="The Frost Colossus, Unbound", sub="Boss of the Frozen village")


# --- 5. The Guardian Centipede -----------------------------------------------------------------

def centipede_scene():
    c = backdrop("art/world/forest_bg.png")
    head = img("art/enemies/centipede_head.png")
    seg = img("art/enemies/centipede_segment_armored.png")
    k = 1.4  # risen: 0.7 world scale, in art pixels
    # The body bursts out of the floor on the left and arcs over toward Storm.
    def path(t):
        return (170 + 470 * t, FLOOR + 30 - 330 * math.sin(math.pi * t * 0.92))
    pts, t, last = [], 0.0, path(0.0)
    pts.append(last)
    while t < 0.84:
        t += 0.0005
        p = path(t)
        if math.dist(p, last) >= 14 * 2:
            pts.append(p)
            last = p
    dirt, dirt_light = (59, 53, 43, 255), (94, 84, 67, 255)
    for i in range(len(pts) - 1):
        a = math.atan2(pts[i + 1][1] - pts[i][1], pts[i + 1][0] - pts[i][0])
        paste_xf(c, seg, (24, 24), pts[i], a, k, k)
    a = math.atan2(pts[-1][1] - pts[-2][1], pts[-1][0] - pts[-2][0])
    paste_xf(c, head, (32, 32), pts[-1], a, k, k)
    draw_tiles(c, "art/world/forest_tileset.png", floor_solid())
    ellipse(c, 175, FLOOR + 2, 52, 13, dirt_light)
    ellipse(c, 175, FLOOR + 4, 46, 10, dirt)
    rng = random.Random(5)
    d = ImageDraw.Draw(c)
    for _ in range(14):
        x, y = 175 + rng.uniform(-60, 60), FLOOR - rng.uniform(8, 70)
        s = rng.uniform(3, 7)
        d.rectangle((x, y, x + s, y + s * 0.7), fill=dirt_light)
    place(c, frames("art/storm/full/jump.png")[6], 800, FLOOR - 70, flip=True)
    save(c, "05_boss_guardian_centipede.png", title="The Guardian Centipede, Risen", sub="Boss of the Foothills")


# --- 6. The Frozen village ---------------------------------------------------------------------

def village_scene():
    c = backdrop("art/world/ice_village_bg.png")
    draw_tiles(c, "art/world/ice_tileset.png", floor_solid())
    lit = (0.78, 0.82, 0.88)
    for name, x in [("house_gable", 120), ("frozen_villager", 300), ("house_drift", 560),
                    ("frozen_villager_c", 735), ("frozen_villager_b", 455), ("house", 880)]:
        place(c, tint(img("art/world/props/%s.png" % name), lit), x)
    place(c, frames("art/storm/full/run.png")[2], 380)
    snow(c, 160, 9)
    save(c, "06_frozen_village.png", title="The Frozen village", sub="Its people stand where the frost caught them")


# --- 7. Enemies --------------------------------------------------------------------------------

def enemies():
    entries = [("Mossy beetle", "art/enemies/beetle.png", 64), ("Frozen thrall", "art/enemies/thrall.png", 64),
               ("Hatchling", "art/enemies/hatchling.png", 32)]
    c = Image.new("RGBA", (1920, 1080), BG)
    d = ImageDraw.Draw(c)
    d.text((80, 60), "Enemies", font=font(56, "georgiab.ttf"), fill=TEXT)
    col = 1920 // 3
    for i, (label, path, fw) in enumerate(entries):
        fr = frames(path, fw)[0]
        big = up(fr.crop(fr.getbbox()), 6 if fw == 64 else 8)
        cx = col * i + col // 2
        c.alpha_composite(big, (cx - big.width // 2, 680 - big.height))
        ellipse(c, cx, 684, big.width * 0.4, 12, (0, 0, 0, 120))
        tw = d.textlength(label, font=font(38))
        d.text((cx - tw / 2, 740), label, font=font(38), fill=SUB)
    c.convert("RGB").save(OUT + "07_enemies.png")
    print("07_enemies.png", c.size)


title_card()
intro_panels()
world_map()
colossus_scene()
centipede_scene()
village_scene()
enemies()
