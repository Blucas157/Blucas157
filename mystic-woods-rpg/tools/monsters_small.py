"""32x32 monsters: mushroom, bat, ghost (same grid as the pack's slime)."""
from pixel import Frame, P, pal

GY = 24  # ground line on the 32 px grid (same as the slime)


# ---------------------------------------------------------------- Mushroom
def mushroom(anim, d, i, n):
    f = Frame(32)
    by = 0      # vertical offset of the whole body
    sq = 0      # squash: + flatter / wider, - taller
    lift = [0, 0]  # feet lift (left, right)
    face = "normal"
    spores = 0
    tilt = 0
    if anim == "idle":
        sq = [0, 0, 1, 1][i]
    elif anim == "move":
        by = [0, -2, -3, -3, -2, 0][i]
        sq = [1, -1, -1, 0, 0, 1][i]
        lift = [[0, 1], [1, 0], [0, 0], [0, 0], [0, 1], [1, 0]][i]
    elif anim == "attack":
        by = [0, 1, -3, -1, 0, 0][i]
        sq = [1, 2, -1, 2, 1, 0][i]
        face = ["normal", "squint", "open", "open", "normal", "normal"][i]
        spores = [0, 0, 0, 1, 2, 3][i]
    elif anim == "damaged":
        by = [0, -2, 0][i]
        sq = [2, -1, 1][i]
        tilt = [-1, -1, 0][i]
        face = ["hurt", "hurt", "normal"][i]
    elif anim == "death":
        return mushroom_death(i)

    f.shadow(16, GY - 1, 7 - (1 if by < -2 else 0), 2)
    ox = tilt
    if d == "right":
        ox -= tilt * 2
    # feet
    for k, fx in enumerate((13, 18)):
        fy = GY - 2 + by - lift[k]
        if by < -1:
            fy = GY - 2 + by + 1
        f.shape(Frame.rect_set(fx + ox, fy, fx + 1 + ox, fy + 1), pal("b1", "b2", "b3"))
    # stem
    scy = GY - 5 + by + sq * 0.5
    f.ellipse(16 + ox, scy, 4 + sq * 0.5, 4.2 - sq * 0.4, pal("k2", "b5", "s5"))
    # cap
    ccy = GY - 10 + by + sq
    rx, ry = 8.5 + sq * 0.6, 5.5 - sq * 0.5
    cap = {p for p in Frame.ellipse_set(16 + ox, ccy, rx, ry) if p[1] <= ccy + 1.5}
    f.shape(cap, pal("r0", "r1", "r2"), center=(16 + ox, ccy), radii=(rx, ry))
    # gills under the cap (visible from the front/side)
    if d != "up":
        for x in range(int(16 + ox - rx + 2), int(16 + ox + rx - 1)):
            if (x, int(ccy + 1.5)) in cap:
                f.put(x, ccy + 2, P["k2"] if x % 2 else P["b4"])
    # spots
    spots = {"down": [(-5, -2), (2, -3), (-1, 0), (5, -1)],
             "right": [(-6, -1), (-2, -3), (3, -2), (0, 0)],
             "up": [(-4, -1), (1, -3), (4, 0), (-1, 1)]}[d]
    for sx, sy in spots:
        x, y = 16 + ox + sx, ccy + sy
        blob = [(int(x), int(y)), (int(x) + 1, int(y)), (int(x), int(y) - 1), (int(x) + 1, int(y) - 1)]
        if all(q in cap for q in blob):
            for q in blob[1:]:
                f.put(q[0], q[1], P["s5"])
            f.put(blob[0][0], blob[0][1], P["k3"])
            f.put(blob[2][0], blob[2][1], P["white"])
    # face
    ey = int(scy) - 1
    if d != "up":
        ex = [14, 17] if d == "down" else [16, 19]
        for k, x in enumerate(ex):
            x += ox
            if face == "hurt":
                f.put(x, ey, P["black"]); f.put(x + (1 if k == 0 else -1), ey + 1, P["black"])
            elif face == "squint":
                f.put(x, ey + 1, P["black"]); f.put(x + 1, ey + 1, P["black"])
            else:
                f.put(x, ey, P["black"]); f.put(x, ey + 1, P["black"])
        mx = 15 + ox if d == "down" else 18 + ox
        if face == "open":
            f.put(mx, ey + 2, P["r0"]); f.put(mx + 1, ey + 2, P["r0"])
        else:
            f.put(mx, ey + 2, P["b2"]); f.put(mx + 1, ey + 2, P["b2"])
        if d == "down":
            f.put(13 + ox, ey + 2, P["r2"]); f.put(19 + ox, ey + 2, P["r2"])
        else:
            f.put(20 + ox, ey + 2, P["r2"])
    # spore cloud
    if spores:
        import math
        r = 8 + spores * 2.5
        for k in range(10):
            a = k * 0.628 + spores * 0.3
            x = int(16 + math.cos(a) * r)
            y = int(GY - 9 + math.sin(a) * r * 0.55)
            c = P["o2"] if k % 2 else P["gr3"]
            if spores == 3 and k % 2:
                continue
            puff = [(x, y)] if spores == 3 else [(x, y), (x + 1, y), (x, y - 1)]
            for q in puff:
                if q not in f.px:
                    f.put(q[0], q[1], c)
    return f


def mushroom_death(i):
    if i <= 1:
        f = mushroom("damaged", "down", 0, 3)
        f.shift(0, 1 + i)
        if i == 1:
            f.dissolve(0.12, seed=3, keep_outline=True)
        return f
    f = Frame(32)
    f.shadow(16, GY - 1, 7 - i, 2)
    if i == 2:
        cap = {p for p in Frame.ellipse_set(17, GY - 3, 7, 3.5) if p[1] <= GY - 2}
        f.shape(cap, pal("r0", "r1", "r2"))
        f.put(14, GY - 4, P["s5"]); f.put(15, GY - 4, P["s5"]); f.put(19, GY - 5, P["s5"])
        for k in range(6):
            f.put(10 + k * 2, GY - 9 - (k % 2) * 2, P["o2"] if k % 2 else P["gr3"])
    else:
        import math
        for k in range(8):
            a = k * 0.785
            r = 3 + (i - 2) * 3
            if i == 4 and k % 2:
                continue
            f.put(16 + math.cos(a) * r, GY - 5 + math.sin(a) * r * 0.6 - (i - 2), P["o2"] if k % 2 else P["gr3"])
    return f


# ---------------------------------------------------------------- Bat
WING = {
    # right wing polygons (left = mirrored), relative to body centre
    "up":   [(2, -1), (6, -7), (9, -8), (11, -5), (9, -4), (8, -1), (5, 0)],
    "mid":  [(2, -1), (7, -3), (12, -2), (11, 1), (9, 0), (7, 2), (4, 2)],
    "down": [(2, 0), (6, 2), (9, 6), (7, 6), (5, 5), (3, 4)],
}


def bat(anim, d, i, n):
    f = Frame(32)
    cx, cy = 16.0, 12.0
    phase = ["up", "mid", "down", "mid"]
    wing = phase[i % 4]
    bob = [0, 1, 2, 1][i % 4]
    mouth = False
    hurt = False
    dx = dy = 0
    if anim == "move":
        wing = ["up", "mid", "down", "up", "mid", "down"][i]
        bob = [0, 1, 1, 0, 1, 1][i]
    elif anim == "attack":
        wing = ["up", "up", "mid", "down", "down", "mid"][i]
        lunge = [0, -2, 2, 4, 3, 1][i]
        if d == "down":
            dy = lunge
        elif d == "up":
            dy = -lunge
        else:
            dx = lunge
        mouth = i in (2, 3, 4)
        bob = 0
    elif anim == "damaged":
        wing = ["down", "down", "mid"][i]
        hurt = i < 2
        back = [3, 2, 0][i]
        if d == "down":
            dy = -back
        elif d == "up":
            dy = back
        else:
            dx = -back
        bob = 0
    elif anim == "death":
        return bat_death(i)
    cx += dx
    cy += bob + dy
    f.shadow(16 + dx, GY - 1, 4, 1.5)
    wcol = pal("r0", "r1")
    if d in ("down", "up"):
        for side in (1, -1):
            pts = [(cx + side * px, cy + py) for px, py in WING[wing]]
            f.shape(Frame.poly_set(pts), wcol, light=(0, -1), th=(-0.2, 9, 9))
            # wing finger bones
            for (px, py) in WING[wing][1:3]:
                for p in Frame.line_set(cx + side * 2, cy - 1, cx + side * px * 0.9, cy + py * 0.9):
                    if f.get(*p) == P["r1"]:
                        f.put(p[0], p[1], P["r0"])
    else:
        # far wing (behind), smaller
        pts = [(cx - 1 - px * 0.6, cy + py * 0.8) for px, py in WING[wing]]
        f.shape(Frame.poly_set(pts), pal("r0"))
    # ears
    ear_off = [(-3, -1), (1, 1)] if d != "right" else [(-2, -1), (1, 1)]
    for ex, s in ear_off:
        f.shape(Frame.poly_set([(cx + ex, cy - 2), (cx + ex + 1 * s + 0.5, cy - 6.5), (cx + ex + 2.5, cy - 2)]),
                pal("s0", "s1"))
    # body
    f.ellipse(cx, cy, 4.5, 4, pal("s0", "s1", "s2"))
    # belly
    if d == "down":
        for p in Frame.ellipse_set(cx, cy + 1.5, 2, 2):
            if f.get(*p) in (P["s1"], P["s2"], P["s0"]):
                f.put(p[0], p[1], P["s2"])
    if d == "right":
        pts = [(cx - 1 + px * 0.7, cy + py * 0.9) for px, py in WING[wing]]
        pts = [(2 * cx - x - 2, y) for x, y in pts]  # near wing trails behind (to the left)
        f.shape(Frame.poly_set(pts), wcol, light=(0, -1), th=(-0.2, 9, 9))
    # face
    ey = int(cy) - 1
    if d != "up":
        eyes = [int(cx) - 2, int(cx) + 1] if d == "down" else [int(cx) + 1, int(cx) + 3]
        for x in eyes:
            if hurt:
                f.put(x, ey, P["black"]); f.put(x, ey + 1, P["black"])
            else:
                f.put(x, ey, P["r2"]); f.put(x, ey + 1, P["o2"])
        mx = int(cx) - 1 if d == "down" else int(cx) + 2
        if mouth:
            f.put(mx, ey + 3, P["r0"]); f.put(mx + 1, ey + 3, P["r0"])
            f.put(mx, ey + 2, P["white"]); f.put(mx + 1, ey + 4 if d == "down" else ey + 2, P["white"])
        else:
            f.put(mx, ey + 3, P["white"])
            if d == "down":
                f.put(mx + 1, ey + 3, P["white"])
    return f


def bat_death(i):
    if i < 3:
        f = bat("damaged", "down", 0, 3)
        f.shift(0, [0, 4, 8][i])
        if i == 2:
            f.dissolve(0.15, seed=7, keep_outline=True)
        return f
    f = Frame(32)
    f.shadow(16, GY - 1, 5, 1.5)
    s = Frame.ellipse_set(16, GY - 3, 4, 2.5)
    f.shape(s, pal("s0", "s1", "s2"))
    f.shape(Frame.poly_set([(12, GY - 3), (6, GY - 2), (9, GY - 1)]), pal("r0"))
    f.shape(Frame.poly_set([(20, GY - 3), (26, GY - 2), (23, GY - 1)]), pal("r0"))
    f.put(14, GY - 4, P["black"]); f.put(17, GY - 4, P["black"])
    if i == 4:
        f.dissolve(0.55, seed=9)
    return f


# ---------------------------------------------------------------- Ghost
def ghost(anim, d, i, n):
    f = Frame(32, outline=P["s0"])
    cx, cy = 16.0, 11.0
    bob = [0, -1, -1, 0][i % 4]
    wave = i % 4
    face = "normal"
    arms = 0  # 0 down, 1 raised
    dx = dy = 0
    grow = 0
    flame = False
    if anim == "move":
        bob = [0, -1, -1, 0, 1, 1][i]
        wave = i
        dx = 1 if d == "right" else 0
    elif anim == "attack":
        grow = [0, 1, 1, 2, 1, 0][i]
        face = ["normal", "boo", "boo", "boo", "boo", "normal"][i]
        arms = [0, 1, 1, 1, 1, 0][i]
        lunge = [0, -1, 2, 3, 2, 0][i]
        if d == "down":
            dy = lunge
        elif d == "up":
            dy = -lunge
        else:
            dx = lunge
        flame = i in (2, 3, 4)
    elif anim == "damaged":
        face = "hurt" if i < 2 else "normal"
        back = [2, 3, 0][i]
        dy = -back if d == "down" else (back if d == "up" else 0)
        dx = -back if d == "right" else 0
    elif anim == "death":
        return ghost_death(i)
    cx += dx
    cy += bob + dy
    f.shadow(16 + dx, GY - 1, 5, 1.5)
    cols = pal("s2", "s4", "s5", "white")
    rx = 6 + grow * 0.5
    head = Frame.ellipse_set(cx, cy, rx, 6 + grow * 0.5)
    body = Frame.rect_set(cx - rx, cy, cx + rx - 1, cy + 4)
    # wavy tail: three lobes that shift each frame
    tail = set()
    for k in range(4):
        tx = cx - rx + 1 + k * (rx * 2 - 2) / 3.0 + ((wave % 2) - 0.5)
        tail |= Frame.ellipse_set(tx, cy + 5 + ((k + wave) % 2), 1.8, 2.2)
    body_set = head | body | tail
    # trailing lean when moving sideways
    if d == "right" and anim == "move":
        body_set = {(x - (1 if y > cy + 3 else 0), y) for (x, y) in body_set}
    f.shape(body_set, cols, center=(cx, cy + 2), radii=(rx, 8), th=(-0.45, 0.25, 0.7))
    # arms
    if (d == "down") or arms:
        for s in ((-1, 1) if d != "right" else (1,)):
            ax = cx + s * (rx + 0.5) if d != "right" else cx - 1
            ay = cy + (2 if not arms else -2) + (1 if d == "right" else 0)
            f.shape(Frame.ellipse_set(ax, ay, 1.6, 1.6), pal("s4", "s5"))
    # face
    if d != "up":
        ex = [int(cx) - 4, int(cx) + 2] if d == "down" else [int(cx) + 1, int(cx) + 4]
        ey = int(cy) - 2
        for x in ex:
            if face == "hurt":
                f.put(x, ey + 1, P["s0"]); f.put(x + 1, ey + 2, P["s0"]); f.put(x + 1, ey, P["s0"]); f.put(x, ey + 1, P["s0"])
            else:
                w = 2 if d == "down" else 1
                f.fill(Frame.rect_set(x, ey, x + w - 1, ey + 2), P["black"])
                f.put(x, ey, P["white"])
        mx = int(cx) - 1 if d == "down" else int(cx) + 2
        if face == "boo":
            f.fill(Frame.rect_set(mx, ey + 4, mx + 1, ey + 5), P["s0"])
        elif face == "hurt":
            f.put(mx, ey + 4, P["s0"]); f.put(mx + 1, ey + 4, P["s0"])
        else:
            f.put(mx, ey + 4, P["s1"]); f.put(mx + 1, ey + 4, P["s1"]) if d == "down" else None
        if d == "down":
            f.put(int(cx) - 5, ey + 3, P["u4"]); f.put(int(cx) + 4, ey + 3, P["u4"])
    if flame:
        for k, (fx, fy) in enumerate(((-9, -2), (9, -3), (0, -10))):
            if d == "right" and fx < 0:
                continue
            x, y = cx + fx, cy + fy - (i % 2)
            f.put(x, y, P["u4"]); f.put(x, y - 1, P["u4"]); f.put(x, y + 1, P["u3"])
            f.put(x - 1, y + 1, P["u4"]); f.put(x + 1, y + 1, P["u4"])
    return f


def ghost_death(i):
    f = ghost("damaged", "down", 0, 3)
    f.shift(0, -2 * i)
    if i >= 1:
        f.dissolve(0.15 + i * 0.2, seed=11 + i)
    if i == 4:
        f.dissolve(0.6, seed=99)
    for k in range(i + 1):
        f.put(12 + k * 2, 22 - k * 3 - i, P["u4"])
    f.shadows = [(16, GY - 1, max(1, 5 - i), 1.5)]
    return f
