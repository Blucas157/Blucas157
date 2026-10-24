"""Small item sprites drawn in the pack's style: spinning coin and HUD icons.

Usage: python3 tools/generate_items.py   (writes assets/ui/coin.png and assets/ui/icons.png)
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel import Frame, P, pal  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOLD = pal("o1", "o2", "s5")


def coin(i):
    f = Frame(10)
    w = [3.5, 2.5, 1.2, 2.5][i]
    f.ellipse(5, 5, w, 3.5, GOLD, light=(-0.7, -0.7))
    if w > 2:
        f.put(5, 4, P["o1"]); f.put(5, 5, P["o1"])
    return f


def sword():
    f = Frame(16)
    f.shape(Frame.line_set(4, 12, 12, 4, 2), pal("s2", "s4", "s5"))
    f.shape(Frame.line_set(3, 9, 7, 13, 1), pal("o1"))
    f.shape(Frame.line_set(2, 14, 3, 13, 2), pal("b2", "b3"))
    return f


def shield():
    f = Frame(16)
    s = Frame.poly_set([(3, 3), (13, 3), (13, 8), (8, 14), (3, 8)])
    f.shape(s, pal("u1", "u2", "u3"))
    f.fill(Frame.line_set(8, 4, 8, 12), P["o2"])
    f.fill(Frame.line_set(4, 7, 12, 7), P["o2"])
    return f


def star():
    import math
    f = Frame(16)
    pts = []
    for k in range(10):
        r = 6.5 if k % 2 == 0 else 2.8
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((8 + math.cos(a) * r, 8.5 + math.sin(a) * r))
    f.shape(Frame.poly_set(pts), pal("u2", "u3", "u4"))
    return f


def main():
    out = os.path.join(ROOT, "assets", "ui")
    os.makedirs(out, exist_ok=True)
    sheet = Image.new("RGBA", (40, 10))
    for i in range(4):
        sheet.alpha_composite(coin(i).to_image(), (i * 10, 0))
    sheet.save(os.path.join(out, "coin.png"))
    icons = Image.new("RGBA", (64, 16))
    for k, fn in enumerate((sword, shield, star)):
        icons.alpha_composite(fn().to_image(), (k * 16, 0))
    icons.alpha_composite(coin(0).to_image().resize((10, 10)), (48 + 3, 3))
    icons.save(os.path.join(out, "icons.png"))


if __name__ == "__main__":
    main()
