"""Finished portfolio screenshots from the frames tools/capture.tscn saved in press/raw/.

Run from the project folder:  python tools/make_portfolio_shots.py
Each pick is a raw 960x540 frame, scaled 2x (pixels kept sharp) to 1920x1080 with a title
in the corner, written to press/portfolio/screenshots/. Change PICKS to choose other frames.
"""
import os

from PIL import Image, ImageDraw, ImageFont

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..") + "/"
RAW = R + "press/raw/"
OUT = R + "press/portfolio/screenshots/"
os.makedirs(OUT, exist_ok=True)

TEXT = (232, 236, 244)
SUB = (170, 178, 196)

# [output name, raw frame, title, subtitle]; no title for a clean shot.
PICKS = [
    ["01_title_screen", "title_00", None, None],
    ["02_foothills", "landing_03", "The Foothills", "Where Storm wakes, with only the hilt"],
    ["03_sunken_glade", "sunken_glade_03", "The Sunken glade", "The Foothills"],
    ["04_guardian_centipede", "gate_cavern_04", "The Guardian Centipede, Risen", "Boss of the Foothills"],
    ["05_frozen_village", "village_square_03", "The Frozen village", "Its people stand where the frost caught them"],
    ["06_frozen_street", "frozen_street_03", "The Frozen street", "The Frozen village"],
    ["07_icefall_hall", "icefall_hall_03", "The Icefall hall", "The Frozen village"],
    ["08_frost_colossus", "frost_arena_03", "The Frost Colossus", "Frozen into the arena wall, the ice piece in its chest"],
    ["09_frost_colossus_unbound", "frost_throne_07", "The Frost Colossus, Unbound", "Boss of the Frozen village"],
    ["10_refuge", "refuge_04", "The Refuge", "The survivors' camp under the Crossroads"],
    ["11_fire_slopes", "ashen_road_03", "The Fire slopes", "The burned village"],
    ["12_ashen_drake", "forge_08", "The Ashen Drake", "Asleep in the great forge, the fire piece through its wing"],
    ["13_ashen_drake_unbound", "drake_roost_09", "The Ashen Drake, Unbound", "Boss of the Fire slopes"],
    ["14_drake_roost", "drake_roost_04", "The Drake's roost", "The Fire slopes"],
    ["15_lightning_peaks", "storm_bridges_03", "The Lightning peaks", "Rain, wind and lightning"],
    ["16_rod_field", "rod_field_03", "The Rod field", "The Lightning peaks"],
    ["17_stormcaller_bound", "spire_06", "The Stormcaller, Bound", "Chained in the Spire by the lightning tip"],
    ["18_stormcaller", "thunder_eyrie_15", "The Stormcaller", "Boss of the Lightning peaks"],
    ["19_stormcaller_eyrie", "thunder_eyrie_12", "The Thunder eyrie", "The Lightning peaks"],
    ["20_last_stand", "high_pass_04", "The Last Stand", "The summit battlefield under the castle gate"],
]


def font(size, face):
    return ImageFont.truetype("C:/Windows/Fonts/" + face, size)


def caption(im, title, sub):
    band = Image.new("RGBA", im.size)
    d = ImageDraw.Draw(band)
    for i in range(170):
        d.line((0, im.height - i, im.width, im.height - i), fill=(5, 7, 12, int(200 * (1 - i / 170))))
    im.alpha_composite(band)
    d = ImageDraw.Draw(im)
    y = im.height - (118 if sub else 86)
    d.text((55, y + 3), title, font=font(52, "georgiab.ttf"), fill=(0, 0, 0, 190))
    d.text((52, y), title, font=font(52, "georgiab.ttf"), fill=TEXT)
    if sub:
        d.text((55, y + 66), sub, font=font(26, "georgiai.ttf"), fill=(0, 0, 0, 190))
        d.text((54, y + 64), sub, font=font(26, "georgiai.ttf"), fill=SUB)


for name, raw, title, sub in PICKS:
    path = RAW + raw + ".png"
    if not os.path.exists(path):
        print("missing", raw)
        continue
    im = Image.open(path).convert("RGBA").resize((1920, 1080), Image.NEAREST)
    im.convert("RGB").save(OUT + name + "_clean.png")
    if title:
        caption(im, title, sub)
        im.convert("RGB").save(OUT + name + ".png")
    print(name)

# A contact sheet of every pick, for a gallery overview.
files = [OUT + p[0] + ".png" if p[2] else OUT + p[0] + "_clean.png" for p in PICKS]
files = [f for f in files if os.path.exists(f)]
cols, w, h, gap = 4, 480, 270, 12
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * (w + gap) + gap, rows * (h + gap) + gap), (10, 12, 18))
for i, f in enumerate(files):
    sheet.paste(Image.open(f).resize((w, h), Image.LANCZOS), (gap + (i % cols) * (w + gap), gap + (i // cols) * (h + gap)))
sheet.save(OUT + "00_overview.png")
print("00_overview", sheet.size)
