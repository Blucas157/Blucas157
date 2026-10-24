"""32x32 mushroom monster drawn by code (same grid as the pack's slime)."""
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
        # squash down before the cap drops (no random holes: they read as broken pixels)
        f = mushroom("attack", "down", 1, 6) if i == 1 else mushroom("damaged", "down", 0, 3)
        f.shift(0, 1)
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
