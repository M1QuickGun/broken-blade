"""Composes the Steam store and library images into press/steam/, from the game's own story
paintings, the reforged blade and the game's font. Pixel art is enlarged by whole numbers
(nearest neighbour) and cropped, so it stays crisp. Run from the project root:

    python tools/make_store_art.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

OUT = "press/steam"
FONT = "art/font/broken_blade.ttf"
BLADE = Image.open("art/blade/blade_3_full.png").convert("RGBA")
PAINTINGS = {
    "kingdom": "art/story/intro_1.png",
    "reforged": "art/story/ending_1.png",
    "keeper": "art/story/ending_2.png",
    "castle": "art/world/castle_bg.png",
}
SILVER = (232, 230, 236, 255)
GOLD = (196, 160, 112, 255)


def painting(name, size, focus=(0.5, 0.5)):
    """The painting enlarged by a whole number until it covers `size`, cropped around `focus`."""
    src = Image.open(PAINTINGS[name]).convert("RGBA")
    k = 1
    while src.width * k < size[0] or src.height * k < size[1]:
        k += 1
    big = src.resize((src.width * k, src.height * k), Image.NEAREST)
    x = int(min(max(big.width * focus[0] - size[0] / 2, 0), big.width - size[0]))
    y = int(min(max(big.height * focus[1] - size[1] / 2, 0), big.height - size[1]))
    return big.crop((x, y, x + size[0], y + size[1]))


def shade(img, top=0.0, bottom=0.55):
    """Darkens toward the bottom (and optionally the top), for the title to sit on."""
    w, h = img.size
    grad = Image.new("L", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        grad.putpixel((0, y), int(255 * (top * (1 - t) ** 2 + bottom * t ** 2)))
    veil = Image.new("RGBA", (w, h), (4, 5, 9, 255))
    veil.putalpha(grad.resize((w, h)))
    return Image.alpha_composite(img, veil)


def title(img, center_y, px, with_blade=True):
    """BROKEN BLADE, in the game's font with a dark outline, the reforged blade under it."""
    draw = ImageDraw.Draw(img)
    size = max(16, px // 16 * 16)
    font = ImageFont.truetype(FONT, size)
    text = "BROKEN BLADE"
    box = draw.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    x = (img.width - w) // 2 - box[0]
    y = int(center_y - h / 2) - box[1]
    if with_blade:
        k = max(1, size // 24)
        blade = BLADE.resize((BLADE.width * k, BLADE.height * k), Image.NEAREST).rotate(90, expand=True)
        img.alpha_composite(blade, ((img.width - blade.width) // 2, int(center_y + h / 2 + size * 0.15)))
    outline = max(2, size // 16)
    for dx in range(-outline, outline + 1, max(1, outline // 2)):
        for dy in range(-outline, outline + 1, max(1, outline // 2)):
            draw.text((x + dx, y + dy), text, font=font, fill=(6, 6, 10, 255))
    draw.text((x, y), text, font=font, fill=SILVER)
    return img


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.convert("RGB").save(os.path.join(OUT, name)) if not name.startswith("library_logo") else img.save(os.path.join(OUT, name))
    print("wrote", os.path.join(OUT, name), img.size)


def main():
    save(title(shade(painting("kingdom", (920, 430), (0.5, 0.4))), 300, 80), "header_capsule_920x430.png")
    save(title(shade(painting("kingdom", (462, 174), (0.5, 0.35)), 0.0, 0.7), 110, 48, False), "small_capsule_462x174.png")
    save(title(shade(painting("kingdom", (1232, 706), (0.5, 0.4))), 520, 112), "main_capsule_1232x706.png")
    save(title(shade(painting("reforged", (748, 896), (0.48, 0.45)), 0.2, 0.75), 720, 80), "vertical_capsule_748x896.png")
    save(title(shade(painting("reforged", (600, 900), (0.48, 0.45)), 0.2, 0.75), 740, 64), "library_capsule_600x900.png")
    save(shade(painting("castle", (3840, 1240), (0.5, 0.5)), 0.0, 0.25), "library_hero_3840x1240.png")
    save(shade(painting("keeper", (1438, 810), (0.5, 0.5)), 0.3, 0.6), "page_background_1438x810.png")
    logo = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    save(title(logo, 300, 160), "library_logo_1280x720.png")
    icon = Image.open("icon.png").convert("RGBA").resize((184, 184), Image.LANCZOS)
    save(icon, "library_logo_icon_184x184.png")


if __name__ == "__main__":
    main()
