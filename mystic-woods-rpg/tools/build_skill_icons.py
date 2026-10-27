#!/usr/bin/env python3
"""Builds assets/ui/skills.png: one 24x24 round icon per archetype node (Archetypes.NODES order)
followed by the 7 archetype emblems. Each icon = wooden ring (touch kit colours), a disc in the
archetype colour and a glyph cut from the game's own sprites (items, UI icons, VFX)."""
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ITEMS = Image.open(os.path.join(ROOT, "assets/items/items.png")).convert("RGBA")
UI = Image.open(os.path.join(ROOT, "assets/ui/icons.png")).convert("RGBA")
VFX = os.path.join(ROOT, "assets/vfx")

COLORS = {"guerra": "#bc4952", "arqueria": "#53a03b", "magia": "#bc6924", "sagrado": "#e9ce7c",
          "escudo": "#4d8ab3", "bruxaria": "#8a4fb3", "espiritual": "#509b66", "mago": "#425b9e", "copista": "#65b1b8"}

def item(i):
    return ITEMS.crop(((i % 8) * 16, (i // 8) * 16, (i % 8) * 16 + 16, (i // 8) * 16 + 16))

def ui(i):
    return UI.crop((i * 16, 0, i * 16 + 16, 16))

def vfx(name, w, h, frame, size=16):
    im = Image.open(os.path.join(VFX, name + ".png")).convert("RGBA").crop((frame * w, 0, frame * w + w, h))
    bb = im.getbbox()
    im = im.crop(bb)
    im.thumbnail((size, size), Image.NEAREST)
    return im

def arrow(n=1):
    g = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(g)
    for k in range(n):
        o = (k - (n - 1) / 2) * 4
        d.line([(2, 13 + o), (12, 3 + o)], fill=(0, 0, 0, 255), width=3)
        d.line([(2, 13 + o), (12, 3 + o)], fill=(157, 118, 88, 255), width=1)
        d.polygon([(14, 1 + o), (10, 2 + o), (13, 5 + o)], fill=(182, 190, 200, 255))
    return g

def chevrons(base):
    g = base.copy()
    d = ImageDraw.Draw(g)
    for x in (2, 6):
        d.line([(x, 4), (x + 3, 8), (x, 12)], fill=(255, 255, 255, 255), width=1)
    return g

def pages(n=2, clip=False):
    """Ctrl+C / Ctrl+V glyphs: stacked sheets of paper (n), or a clipboard."""
    g = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(g)
    if clip:
        d.rectangle([3, 2, 12, 14], fill=(0, 0, 0, 255))
        d.rectangle([4, 3, 11, 13], fill=(157, 118, 88, 255))
        d.rectangle([5, 5, 10, 12], fill=(225, 221, 214, 255))
        d.rectangle([6, 1, 9, 3], fill=(182, 190, 200, 255))
        for y in (7, 9, 11):
            d.line([(6, y), (9, y)], fill=(101, 177, 184, 255))
        return g
    for k in range(n):
        o = k * 3
        d.rectangle([2 + o, 1 + o, 10 + o, 11 + o], fill=(0, 0, 0, 255))
        d.rectangle([3 + o, 2 + o, 9 + o, 10 + o], fill=(225, 221, 214, 255))
        for y in (4, 6, 8):
            d.line([(4 + o, y + o), (8 + o, y + o)], fill=(101, 177, 184, 255))
    return g


def tint(g, rgb, amt=0.6):
    out = g.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, gg, b, a = px[x, y]
            if a:
                px[x, y] = (int(r * (1 - amt) + rgb[0] * amt), int(gg * (1 - amt) + rgb[1] * amt), int(b * (1 - amt) + rgb[2] * amt), a)
    return out

# same order as Archetypes.NODES in scripts/Archetypes.gd
NODES = [
    ("guerra", vfx("slash", 32, 45, 2)), ("guerra", ui(0)), ("guerra", item(7)), ("guerra", vfx("flame", 16, 23, 2)), ("guerra", vfx("hit", 30, 33, 2)),
    ("arqueria", arrow(1)), ("arqueria", item(4)), ("arqueria", item(36)), ("arqueria", arrow(3)), ("arqueria", item(26)),
    ("magia", vfx("fireball", 24, 24, 0)), ("magia", item(5)), ("magia", item(33)), ("magia", tint(vfx("fireburst", 44, 45, 3), (170, 140, 255), 0.5)), ("magia", vfx("flame", 16, 23, 5)),
    ("sagrado", item(15)), ("sagrado", item(35)), ("sagrado", item(16)), ("sagrado", tint(vfx("hit", 30, 33, 2), (255, 240, 150), 0.6)), ("sagrado", item(34)),
    ("escudo", ui(1)), ("escudo", item(10)), ("escudo", ui(0).transpose(Image.FLIP_LEFT_RIGHT)), ("escudo", chevrons(ui(1))), ("escudo", item(24)),
    ("bruxaria", tint(item(19), (170, 90, 220), 0.5)), ("bruxaria", item(21)), ("bruxaria", item(22)), ("bruxaria", tint(vfx("fireball", 24, 24, 3), (170, 110, 255), 0.7)), ("bruxaria", item(20)),
    ("espiritual", item(12)), ("espiritual", item(36)), ("espiritual", item(17)), ("espiritual", item(4)), ("espiritual", item(15)),
    ("mago", tint(vfx("fireball", 24, 24, 0, 14), (120, 170, 255), 0.7)), ("mago", item(40)), ("mago", item(5)),
    ("mago", tint(vfx("puff", 26, 27, 2, 16), (140, 170, 255), 0.6)), ("mago", tint(item(40), (233, 206, 124), 0.6)),
    ("copista", pages(2)), ("copista", pages(clip=True)), ("copista", tint(pages(1), (170, 140, 255), 0.4)),
    ("copista", tint(ui(1), (120, 230, 240), 0.6)), ("copista", pages(3)), ("copista", tint(pages(3), (233, 206, 124), 0.5)),
]
EMBLEMS = [("guerra", ui(0)), ("arqueria", arrow(1)), ("magia", vfx("fireball", 24, 24, 0)), ("sagrado", item(15)),
           ("escudo", ui(1)), ("bruxaria", item(21)), ("espiritual", item(12)), ("mago", item(40)), ("copista", pages(2))]

def icon(arch, glyph, emblem=False):
    c = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(c)
    col = tuple(int(COLORS[arch][i:i + 2], 16) for i in (1, 3, 5))
    d.ellipse([0, 0, 23, 23], fill=(0, 0, 0, 255))
    d.ellipse([1, 1, 22, 22], fill=(117, 83, 56, 255) if not emblem else (233, 206, 124, 255))
    d.ellipse([2, 2, 21, 21], fill=(64, 39, 23, 255))
    d.ellipse([3, 3, 20, 20], fill=tuple(int(v * 0.55) for v in col) + (255,))
    d.ellipse([4, 4, 19, 15], fill=tuple(int(v * 0.8) for v in col) + (255,))
    g = glyph
    c.alpha_composite(g, ((24 - g.width) // 2, (24 - g.height) // 2))
    return c

cells = [icon(a, g) for a, g in NODES] + [icon(a, g, True) for a, g in EMBLEMS]
cols = 8
sheet = Image.new("RGBA", (cols * 24, ((len(cells) + cols - 1) // cols) * 24))
for i, c in enumerate(cells):
    sheet.alpha_composite(c, ((i % cols) * 24, (i // cols) * 24))
sheet.save(os.path.join(ROOT, "assets/ui/skills.png"))
print(len(cells), sheet.size)
