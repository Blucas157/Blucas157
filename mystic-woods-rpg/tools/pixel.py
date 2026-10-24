"""Small pixel-art toolkit used to draw new monsters in the Mystic Woods style.

Style rules taken from the original pack:
- 1 px outline around every part (black, or a dark tint for soft creatures)
- 2-4 tone shading lit from the top / top-left
- flat translucent shadow ellipse (#171c31, alpha 128) on the ground
- chibi proportions, right-facing side view (left = flipped in engine)
"""
import math
import random

from PIL import Image


def h(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


# Master palette extracted from the pack
P = {
    "black": h("000000"),
    "white": h("ffffff"),
    "shadow": h("171c31", 128),
    # greens (trees / grass)
    "g0": h("082b0c"), "g1": h("114517"), "g2": h("347b2c"), "g3": h("53a03b"), "g4": h("6fb151"),
    "gr0": h("163c2b"), "gr1": h("296640"), "gr2": h("509b66"), "gr3": h("69b57f"),
    # browns (wood / dirt)
    "b0": h("21110d"), "b1": h("342319"), "b2": h("503625"), "b3": h("755338"), "b4": h("9d7658"), "b5": h("c8b3a2"),
    # stone
    "s0": h("242a3d"), "s1": h("414b66"), "s2": h("677598"), "s3": h("8f9ab0"), "s4": h("b6bec8"), "s5": h("e1ddd6"),
    # reds / oranges
    "r0": h("71193c"), "r1": h("9e2e46"), "r2": h("bc4952"), "o1": h("bc6924"), "o2": h("d99945"),
    # blues
    "u0": h("1d235d"), "u1": h("33418a"), "u2": h("425b9e"), "u3": h("4d8ab3"), "u4": h("65b1b8"),
    # bone
    "k1": h("6e5649"), "k2": h("947b6b"), "k3": h("c6bbb9"),
}


def pal(*names):
    return [P[n] for n in names]


class Frame:
    def __init__(self, size, outline=None):
        self.size = size
        self.px = {}
        self.outline_col = outline or P["black"]
        self.shadows = []

    # ---- primitives -------------------------------------------------
    def inside(self, x, y):
        return 0 <= x < self.size and 0 <= y < self.size

    def put(self, x, y, c):
        x, y = int(math.floor(x)), int(math.floor(y))
        if self.inside(x, y):
            if c is None:
                self.px.pop((x, y), None)
            else:
                self.px[(x, y)] = c

    def get(self, x, y):
        return self.px.get((x, y))

    @staticmethod
    def ellipse_set(cx, cy, rx, ry):
        s = set()
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx = (x + 0.5 - cx) / rx
                ny = (y + 0.5 - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    s.add((x, y))
        return s

    @staticmethod
    def rect_set(x0, y0, x1, y1):
        return {(x, y) for y in range(int(y0), int(y1) + 1) for x in range(int(x0), int(x1) + 1)}

    @staticmethod
    def poly_set(pts):
        s = set()
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        n = len(pts)
        for y in range(int(min(ys)) - 1, int(max(ys)) + 2):
            for x in range(int(min(xs)) - 1, int(max(xs)) + 2):
                px, py = x + 0.5, y + 0.5
                ins = False
                j = n - 1
                for i in range(n):
                    xi, yi = pts[i]
                    xj, yj = pts[j]
                    if (yi > py) != (yj > py):
                        if px < (xj - xi) * (py - yi) / (yj - yi + 1e-9) + xi:
                            ins = not ins
                    j = i
                if ins:
                    s.add((x, y))
        return s

    @staticmethod
    def line_set(x0, y0, x1, y1, w=1):
        s = set()
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        r = (w - 1) / 2.0
        for i in range(steps + 1):
            t = i / steps
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            if w <= 1:
                s.add((int(math.floor(x)), int(math.floor(y))))
            else:
                for yy in range(int(math.floor(y - r)), int(math.floor(y + r)) + 1):
                    for xx in range(int(math.floor(x - r)), int(math.floor(x + r)) + 1):
                        if (xx + 0.5 - x) ** 2 + (yy + 0.5 - y) ** 2 <= (r + 0.5) ** 2:
                            s.add((xx, yy))
        return s

    def ring(self, s):
        r = set()
        for (x, y) in s:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in s:
                    r.add(q)
        return r

    # ---- painting ---------------------------------------------------
    def shape(self, s, cols, center=None, radii=None, outline=True, light=(-0.35, -0.95),
              th=(-0.35, 0.45, 0.85), ocol=None):
        """Fill pixel set `s` with shaded colours.

        cols: [dark, base, light, (highlight)] or a single colour.
        Shading uses the normalised position inside the bounding box (or given centre/radii).
        """
        if not s:
            return s
        if outline:
            oc = ocol or self.outline_col
            for p in self.ring(s):
                self.put(p[0], p[1], oc)
        if not isinstance(cols, list):
            cols = [cols]
        if center is None:
            xs = [p[0] for p in s]
            ys = [p[1] for p in s]
            center = ((min(xs) + max(xs) + 1) / 2.0, (min(ys) + max(ys) + 1) / 2.0)
            radii = (max(1.0, (max(xs) - min(xs) + 1) / 2.0), max(1.0, (max(ys) - min(ys) + 1) / 2.0))
        cx, cy = center
        rx, ry = radii
        for (x, y) in s:
            if len(cols) == 1:
                c = cols[0]
            else:
                nx = (x + 0.5 - cx) / rx
                ny = (y + 0.5 - cy) / ry
                v = light[0] * nx + light[1] * ny
                if v < th[0]:
                    c = cols[0]
                elif len(cols) >= 4 and v > th[2]:
                    c = cols[3]
                elif v > th[1] and len(cols) >= 3:
                    c = cols[2]
                else:
                    c = cols[1]
            self.put(x, y, c)
        return s

    def ellipse(self, cx, cy, rx, ry, cols, **kw):
        s = self.ellipse_set(cx, cy, rx, ry)
        return self.shape(s, cols, center=(cx, cy), radii=(rx, ry), **kw)

    def fill(self, s, c):
        for (x, y) in s:
            self.put(x, y, c)

    def shadow(self, cx, cy, rx, ry=None):
        self.shadows.append((cx, cy, rx, ry if ry is not None else max(1, rx / 3.0)))

    def dissolve(self, amount, seed=0, keep_outline=False):
        rnd = random.Random(seed)
        for k in sorted(self.px.keys()):
            if rnd.random() < amount:
                if keep_outline and self.px[k] == self.outline_col:
                    continue
                del self.px[k]

    def recolor(self, fn):
        for k, c in list(self.px.items()):
            self.px[k] = fn(c)

    def shift(self, dx, dy):
        self.px = {(x + dx, y + dy): c for (x, y), c in self.px.items() if self.inside(x + dx, y + dy)}

    def to_image(self):
        im = Image.new("RGBA", (self.size, self.size), (0, 0, 0, 0))
        pix = im.load()
        for (cx, cy, rx, ry) in self.shadows:
            for p in self.ellipse_set(cx, cy, rx, ry):
                if self.inside(*p) and p not in self.px:
                    pix[p[0], p[1]] = P["shadow"]
        for (x, y), c in self.px.items():
            pix[x, y] = c
        return im


# Row layout identical to the pack's enemies:
# [0-2] idle, [3-5] move, [6-8] attack, [9-11] damaged, [12] death
# directions per animation: down, right (side), up
ANIMS = ["idle", "move", "attack", "damaged"]
DIRS = ["down", "right", "up"]


def build_sheet(draw, size, counts, path):
    """draw(anim, dir, i, n) -> Frame. counts: dict anim -> frame count (incl. 'death')."""
    cols = max(counts.values())
    rows = len(ANIMS) * 3 + 1
    sheet = Image.new("RGBA", (cols * size, rows * size), (0, 0, 0, 0))
    r = 0
    for a in ANIMS:
        for d in DIRS:
            n = counts[a]
            for i in range(n):
                sheet.alpha_composite(draw(a, d, i, n).to_image(), (i * size, r * size))
            r += 1
    n = counts["death"]
    for i in range(n):
        sheet.alpha_composite(draw("death", "down", i, n).to_image(), (i * size, r * size))
    sheet.save(path)
    return sheet
