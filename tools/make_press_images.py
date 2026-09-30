import re
from PIL import Image, ImageDraw, ImageFont
R = "C:/Claude Projects/Broken Blade/"
OUT = R + "press/"
BG = (15, 17, 25, 255); PILLAR = (19, 22, 34, 255); TEXT = (200, 205, 220, 255); DIM = (120, 128, 150, 255)
font = lambda s: ImageFont.truetype("C:/Windows/Fonts/consola.ttf", s)

def frames(path, fw):
    im = Image.open(R + path).convert("RGBA")
    return [im.crop((i * fw, 0, (i + 1) * fw, im.height)) for i in range(im.width // fw)]

def up(im, k): return im.resize((im.width * k, im.height * k), Image.NEAREST)

def bottom(im):  # lowest opaque row
    return im.getbbox()[3]

# 1. Hero portrait: new Storm idle, big.
idle = frames("art/storm_new/full/idle.png", 96)
hero = Image.new("RGBA", (96, 96), BG); hero.alpha_composite(idle[0])
up(hero, 8).save(OUT + "storm_hero.png")
t = idle[0].crop(idle[0].getbbox()); up(t, 8).save(OUT + "storm_hero_transparent.png")

# 2. Animation sheet for the new sprites.
rows = [("IDLE", "idle"), ("RUN", "run"), ("ATTACK", "attack"), ("ATTACK 2", "attack2")]
K = 3; cell = 96 * K; label_w = 220; pad = 24
maxn = max(len(frames(f"art/storm_new/full/{f}.png", 96)) for _, f in rows)
sheet = Image.new("RGBA", (label_w + maxn * cell + pad, len(rows) * cell + 2 * pad + 60), BG)
d = ImageDraw.Draw(sheet)
d.text((pad, pad), "STORM — full blade", font=font(36), fill=TEXT)
for r, (name, f) in enumerate(rows):
    y = pad + 60 + r * cell
    d.text((pad, y + cell // 2 - 14), name, font=font(28), fill=DIM)
    for i, fr in enumerate(frames(f"art/storm_new/full/{f}.png", 96)):
        sheet.alpha_composite(up(fr, K), (label_w + i * cell, y))
sheet.save(OUT + "storm_animations.png")

# 3. Blade stages: Storm holding each stage of the broken blade.
stages = [("HILT", "storm_hilt"), ("ICE", "storm_ice"), ("ICE + FIRE", "storm_ice_fire"),
          ("ICE + LIGHTNING", "storm_ice_lightning"), ("FULL BLADE", "storm_full")]
K = 4; cw = 96 * K + 40
st = Image.new("RGBA", (len(stages) * cw + 40, 96 * K + 140), BG)
d = ImageDraw.Draw(st)
for i, (name, f) in enumerate(stages):
    im = Image.open(R + f"art/concepts/bases/{f}.png").convert("RGBA")
    im = up(im, K * 96 // im.width) if im.width != 96 else up(im, K)
    x = 40 + i * cw + (96 * K - im.width) // 2
    st.alpha_composite(im, (x, 40 + 96 * K - im.height))
    w = d.textlength(name, font=font(26))
    d.text((40 + i * cw + (96 * K - w) / 2, 96 * K + 70), name, font=font(26), fill=TEXT)
st.save(OUT + "blade_stages.png")

# HUD blade icons row.
blades = ["blade_0_hilt", "blade_1_ice", "blade_2_ice_fire", "blade_2_ice_lightning", "blade_3_full"]
bi = Image.new("RGBA", (len(blades) * 32 * 5 + 40, 96 * 4 + 40), BG)
for i, b in enumerate(blades):
    bi.alpha_composite(up(Image.open(R + f"art/blade/{b}.png").convert("RGBA"), 4), (20 + i * 160 + 16, 20))
bi.save(OUT + "blade_pieces.png")

# 4. In-game scene: the Ruins Entry room, drawn like room.gd does (2x art scale).
src = open(R + "scripts/rooms.gd", encoding="utf-8").read()
block = src.split('"ruins_entry": [', 1)[1].split("]", 1)[0]
grid = re.findall(r'"([^"]*)"', block)
W, H = len(grid[0]), len(grid); T = 32
cellc = lambda x, y: "#" if x < 0 or y < 0 or x >= W or y >= H else grid[y][x]
STONE = {0:(0,3),1:(1,3),2:(0,0),3:(3,0),4:(0,2),5:(1,0),6:(2,3),7:(1,1),8:(3,3),9:(0,1),10:(3,2),11:(2,0),12:(1,2),13:(2,2),14:(3,1),15:(2,1)}
sheet_t = Image.open(R + "art/world/ruins_tileset.png").convert("RGBA")
scene = Image.new("RGBA", (W * T, H * T), BG)
d = ImageDraw.Draw(scene)
for i in range(3, W, 9):
    d.rectangle((i * T, 0, i * T + 2 * T - 1, H * T), fill=PILLAR)
for vy in range(H + 1):
    for vx in range(W + 1):
        m = (cellc(vx-1,vy-1)=="#")*8 + (cellc(vx,vy-1)=="#")*4 + (cellc(vx-1,vy)=="#")*2 + (cellc(vx,vy)=="#")
        if m:
            sx, sy = STONE[m]
            scene.alpha_composite(sheet_t.crop((sx*T, sy*T, sx*T+T, sy*T+T)), (vx*T - T//2, vy*T - T//2))
spike = Image.open(R + "art/concepts/spikes_v1.png").convert("RGBA")
crawler = Image.open(R + "art/concepts/crawler_v1.png").convert("RGBA")
for y in range(H):
    for x in range(W):
        if grid[y][x] == "^": scene.alpha_composite(spike, (x*T, y*T))
floor = 15 * T
def place(fr, cx):
    scene.alpha_composite(fr, (int(cx - 37), floor - bottom(fr)))
atk = frames("art/storm_new/full/attack.png", 96)[5]
place(atk, 27 * T)
scene.alpha_composite(crawler, (29 * T + 8, floor - bottom(crawler)))
up(scene, 2).save(OUT + "scene_ruins_entry.png")

# Wide banner crop around the action, 3x.
ban = scene.crop((16 * T, 7 * T, 36 * T, 16 * T))
up(ban, 3).save(OUT + "banner.png")
print("ok")
