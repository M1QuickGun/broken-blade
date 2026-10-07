"""Collects the game's text into translations/strings.csv for translators: one row per line,
keyed by the English (the game passes everything shown through tr(), so an untranslated line
shows as it is). Add a column per language (fr, de, ...), fill it in, and Godot imports the
CSV; then list translations/strings.*.translation under Project Settings > Localization.

    python tools/extract_strings.py
"""
import csv
import re

SOURCES = ["scripts/rooms.gd", "scripts/intro.gd", "scripts/shop.gd", "scripts/hud.gd", "scripts/game.gd",
           "scripts/credits.gd", "scripts/pause_menu.gd", "scripts/title.gd", "scripts/journal.gd",
           "scripts/travel.gd", "scripts/map_screen.gd", "scripts/main.gd"]
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')


def wanted(text):
    """Quoted text a player sees (words, a capital or a sentence), not code."""
    if len(text) < 3 or "res://" in text or "user://" in text:
        return False
    if re.fullmatch(r"[a-z_0-9]+", text):  # ids, actions, kinds
        return False
    if re.fullmatch(r"[a-z_]+:[\w,%]+", text):  # keys like "room:x,y"
        return False
    return bool(re.search(r"[A-Za-z]{2}", text)) and (" " in text or text[0].isupper())


def main():
    seen = []
    for path in SOURCES:
        lines = open(path, encoding="utf-8").read().split("\n")
        src = "\n".join(line for line in lines if not line.lstrip().startswith("#"))
        for m in STRING.finditer(src):
            text = m.group(1).replace('\\"', '"').replace("\\n", "\n")
            if wanted(text) and text not in seen:
                seen.append(text)
    with open("translations/strings.csv", "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["keys", "en"])
        for text in seen:
            w.writerow([text, text])
    print("wrote translations/strings.csv:", len(seen), "lines")


if __name__ == "__main__":
    main()
