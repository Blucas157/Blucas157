"""Generate the new monster sprite sheets.

Usage (from the project root):
    python3 tools/generate_monsters.py [preview_dir]

Writes assets/monsters/<name>.png plus assets/monsters/monsters.json (frame counts).
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel import build_sheet  # noqa: E402
import monsters_small as ms  # noqa: E402
import monsters_big as mb  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "monsters")

MONSTERS = {
    "mushroom": (ms.mushroom, 32, {"idle": 4, "move": 6, "attack": 6, "damaged": 3, "death": 5}),
    "bat": (ms.bat, 32, {"idle": 4, "move": 6, "attack": 6, "damaged": 3, "death": 5}),
    "ghost": (ms.ghost, 32, {"idle": 4, "move": 6, "attack": 6, "damaged": 3, "death": 5}),
    "goblin": (mb.goblin, 48, {"idle": 6, "move": 6, "attack": 6, "damaged": 3, "death": 5}),
    "golem": (mb.golem, 48, {"idle": 4, "move": 6, "attack": 7, "damaged": 3, "death": 6}),
    "treant": (mb.treant, 64, {"idle": 4, "move": 6, "attack": 7, "damaged": 3, "death": 6}),
}


def main():
    only = [a for a in sys.argv[1:] if not os.path.isdir(a) and a in MONSTERS]
    preview = next((a for a in sys.argv[1:] if os.path.isdir(a)), None)
    os.makedirs(OUT, exist_ok=True)
    meta = {}
    for name, (fn, size, counts) in MONSTERS.items():
        meta[name] = {"size": size, "frames": counts}
        if only and name not in only:
            continue
        sheet = build_sheet(fn, size, counts, os.path.join(OUT, name + ".png"))
        if preview:
            bg = Image.new("RGBA", sheet.size, (0x50, 0x9b, 0x66, 255))
            bg.alpha_composite(sheet)
            bg.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(os.path.join(preview, name + ".png"))
    with open(os.path.join(OUT, "monsters.json"), "w") as fh:
        json.dump(meta, fh, indent=2)


if __name__ == "__main__":
    main()
