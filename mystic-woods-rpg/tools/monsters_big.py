"""48x48 monsters (goblin, stone golem, same grid as the skeleton) and the 64x64 treant boss."""
import math

from pixel import Frame, P, pal

GY = 40  # ground line on the 48 px grid (same as the skeleton)


def _dir_sign(d):
    return 1 if d == "right" else 0


def smear(f, hx, hy, a0, a1, r, col=None):
    """Motion arc (no outline) between two angles, like the pack's sword trails."""
    col = col or P["s5"]
    steps = 10
    for k in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * k / steps)
        for rr in (r, r - 1):
            x, y = hx + math.cos(a) * rr, hy + math.sin(a) * rr
            if (int(x), int(y)) not in f.px:
                f.put(x, y, col if rr == r else P["white"])


# ---------------------------------------------------------------- Goblin
def club(f, hx, hy, ang, length=8):
    a = math.radians(ang)
    ex, ey = hx + math.cos(a) * length, hy + math.sin(a) * length
    f.shape(Frame.line_set(hx, hy, ex, ey, 2), pal("b2", "b3"))
    f.ellipse(hx + math.cos(a) * (length + 1), hy + math.sin(a) * (length + 1), 2.6, 2.6, pal("b2", "b3", "b4"))
    # nails
    nx, ny = hx + math.cos(a) * (length + 1.5), hy + math.sin(a) * (length + 1.5)
    f.put(nx + math.cos(a + 1.6) * 2.2, ny + math.sin(a + 1.6) * 2.2, P["s4"])


def goblin(anim, d, i, n):
    f = Frame(48)
    bob = 0
    lift = [0, 0]
    ang = -60
    face = "normal"
    lean = 0
    prev = None
    if anim == "idle":
        bob = [0, 0, 1, 1, 1, 0][i]
        ang = -40 + [0, 0, 4, 6, 4, 0][i]
    elif anim == "move":
        bob = [0, -1, 0, 0, -1, 0][i]
        lift = [[1, 0], [1, 0], [0, 0], [0, 1], [0, 1], [0, 0]][i]
        ang = -40 + [0, 5, 0, -5, 0, 5][i]
    elif anim == "attack":
        seq = [-80, -120, -140, 10, 60, -40]
        ang = seq[i]
        prev = seq[i - 1] if i in (3, 4) else None
        lean = [0, -1, -1, 1, 1, 0][i]
        face = ["normal", "angry", "angry", "yell", "yell", "normal"][i]
        bob = [0, 0, -1, 0, 1, 0][i]
    elif anim == "damaged":
        lean = [-2, -1, 0][i]
        face = ["hurt", "hurt", "normal"][i]
        ang = [-100, -80, -60][i]
        bob = [0, 1, 0][i]
    elif anim == "death":
        return goblin_death(i)

    side = d == "right"
    f.shadow(24, GY - 1, 7, 2)
    lx = lean if side else 0
    ly = -lean if d == "down" else (lean if d == "up" else 0)
    cx = 24 + lx + (1 if side else 0)
    # hand position for the club
    hx = cx + (5 if not side else 4)
    hy = 34 + bob + ly
    club_behind = d == "up" or ang < -90
    if club_behind:
        club(f, hx, hy, ang)
    # feet
    for k, fx in enumerate((cx - 4, cx + 1) if not side else (cx - 3, cx + 1)):
        fy = GY - 2 - lift[k]
        f.shape(Frame.rect_set(fx, fy, fx + 2, fy + 1), pal("b0", "b1"))
    # tunic body
    by = 34.5 + bob + ly
    f.ellipse(cx, by, 5, 4, pal("b2", "b3", "b4"))
    for x in range(int(cx - 4), int(cx + 4)):
        if f.get(x, int(by) + 1) in (P["b2"], P["b3"], P["b4"]):
            f.put(x, int(by) + 1, P["b1"])
    if d != "up":
        f.put(cx + (0 if not side else 2), int(by) + 1, P["o2"])
    # arms
    arm_pos = [(cx - 5.5, by - 0.5), (cx + 5.5, by - 0.5)] if not side else [(cx + 3, by)]
    for ax, ay in arm_pos:
        f.ellipse(ax, ay, 1.7, 1.7, pal("g2", "g3"))
    # ears
    hcy = 27 + bob + ly
    hcx = cx
    ears = []
    if not side:
        ears = [[(hcx - 5, hcy - 1), (hcx - 11, hcy - 4), (hcx - 5, hcy + 2)],
                [(hcx + 5, hcy - 1), (hcx + 11, hcy - 4), (hcx + 5, hcy + 2)]]
    else:
        ears = [[(hcx - 3, hcy - 1), (hcx - 9, hcy - 4), (hcx - 3, hcy + 2)]]
    for e in ears:
        f.shape(Frame.poly_set(e), pal("g2", "g3"), light=(0, -1))
        # inner ear
        mx = (e[0][0] + e[1][0] + e[2][0]) / 3.0
        my = (e[0][1] + e[1][1] + e[2][1]) / 3.0
        f.put(mx, my, P["r1"])
    # head
    f.ellipse(hcx, hcy, 6.5, 5.5, pal("g2", "g3", "g4"))
    # face
    if d != "up":
        ex = [hcx - 3, hcx + 2] if not side else [hcx + 1, hcx + 4]
        ey = int(hcy)
        for k, x in enumerate(ex):
            x = int(x)
            if face == "hurt":
                f.put(x, ey, P["black"]); f.put(x + 1, ey + 1, P["black"]); f.put(x + 1, ey - 1, P["black"])
            else:
                w = 2 if not side else 1
                f.fill(Frame.rect_set(x, ey, x + w - 1, ey + 1), P["black"])
                outer = x if (k == 0 or side) else x + w - 1
                f.put(outer if not side else x, ey, P["o2"])
                if face in ("angry", "yell"):
                    f.put(x + (1 if k == 0 else 0), ey - 1, P["g1"])
                    f.put(x + (0 if k == 0 else 1), ey - 2, P["g1"])
        # nose and mouth
        if side:
            f.put(hcx + 6, ey + 1, P["g3"]); f.put(hcx + 7, ey + 1, P["black"]); f.put(hcx + 6, ey + 2, P["black"])
            mx = int(hcx) + 3
        else:
            f.put(hcx, ey + 1, P["g1"])
            mx = int(hcx) - 2
        my = ey + 3
        w = 4 if not side else 3
        if face == "yell":
            f.fill(Frame.rect_set(mx, my, mx + w - 1, my + 1), P["r0"])
            f.put(mx, my, P["white"]); f.put(mx + w - 1, my, P["white"])
        else:
            f.fill(Frame.rect_set(mx, my, mx + w - 1, my), P["black"])
            f.put(mx + (1 if side else 0), my - 1 if False else my, P["black"])
            f.put(mx + w - 1, my - 1, P["white"])
    else:
        # back of the head: darker patch
        for p in Frame.ellipse_set(hcx, hcy + 2, 4, 2):
            if f.get(*p) in (P["g3"], P["g4"]):
                f.put(p[0], p[1], P["g2"])
    if not club_behind:
        club(f, hx, hy, ang)
        if not side:
            f.ellipse(hx, hy, 1.6, 1.6, pal("g2", "g3"))
    if prev is not None:
        smear(f, hx, hy, prev, ang, 11)
    return f


def goblin_death(i):
    if i == 0:
        return goblin("damaged", "down", 0, 3)
    f = Frame(48)
    if i == 1:
        f = goblin("damaged", "down", 0, 3)
        f.shift(0, 3)
        return f
    f.shadow(24, GY - 1, 9, 2)
    # lying on the ground: club dropped, body and head sideways
    club(f, 33, GY - 3, -10, 6)
    f.ellipse(27, GY - 4, 4, 3, pal("b2", "b3", "b4"))
    f.shape(Frame.poly_set([(16, GY - 6), (12, GY - 11), (18, GY - 4)]), pal("g2", "g3"))
    f.ellipse(19, GY - 5, 5, 4.5, pal("g2", "g3", "g4"))
    f.put(18, GY - 6, P["black"]); f.put(19, GY - 5, P["black"]); f.put(19, GY - 7, P["black"]); f.put(18, GY - 4, P["black"])
    f.put(21, GY - 6, P["black"]); f.put(22, GY - 5, P["black"]); f.put(22, GY - 7, P["black"]); f.put(21, GY - 4, P["black"])
    return f


# ---------------------------------------------------------------- Stone golem
def golem(anim, d, i, n):
    f = Frame(48)
    bob = 0
    sway = 0
    lift = [0, 0]
    fist_y = 0
    fist_x = 0
    glow = P["u4"]
    dust = 0
    chips = 0
    hurt = False
    if anim == "idle":
        bob = [0, 0, 1, 1][i]
        fist_y = [0, 1, 1, 0][i]
        glow = [P["u4"], P["u4"], P["u3"], P["u4"]][i]
    elif anim == "move":
        sway = [0, 1, 1, 0, -1, -1][i]
        lift = [[2, 0], [1, 0], [0, 0], [0, 2], [0, 1], [0, 0]][i]
        bob = [-1, 0, 1, -1, 0, 1][i]
        fist_y = [1, 0, -1, 1, 0, -1][i]
    elif anim == "attack":
        fist_y = [0, -6, -10, -11, 4, 4, 1][i]
        fist_x = [0, -1, -2, -2, 2, 2, 1][i]
        bob = [0, -1, -2, -2, 2, 2, 1][i]
        dust = [0, 0, 0, 0, 1, 2, 3][i]
        glow = P["white"] if i in (2, 3) else P["u4"]
    elif anim == "damaged":
        chips = [1, 2, 0][i]
        sway = [-2, -1, 0][i]
        hurt = i < 2
        glow = P["r2"] if i < 2 else P["u4"]
    elif anim == "death":
        return golem_death(i)
    side = d == "right"
    f.shadow(24, GY - 1, 10, 2.5)
    cx = 24 + sway
    by = 31 + bob
    slam_fwd = fist_y > 2 and anim == "attack"
    # far fist (behind body) in side view
    if side:
        f.ellipse(cx - 6 - fist_x, by + 2 + fist_y, 3, 3, pal("s1", "s2", "s3"))
    elif d == "up" and fist_y < -4:
        for s in (-1, 1):
            f.ellipse(cx + s * (8 - fist_x), by + 2 + fist_y, 3.2, 3.2, pal("s1", "s2", "s3"))
    # legs
    legs = (cx - 6, cx + 2) if not side else (cx - 4, cx + 1)
    for k, lx in enumerate(legs):
        ly = GY - 4 - lift[k]
        f.shape(Frame.rect_set(lx, ly, lx + 3, ly + 3), pal("s1", "s2", "s3"))
    # body boulder
    body = f.ellipse(cx, by, 9, 7, pal("s1", "s2", "s3", "s4"), th=(-0.4, 0.3, 0.75))
    # cracks
    for (x, y) in ((-4, 2), (-3, 3), (-3, 4), (5, -1), (6, 0), (2, 4), (3, 4)):
        if (int(cx + x), int(by + y)) in body:
            f.put(cx + x, by + y, P["s1"])
    # moss on the shoulders
    for (mx, my, r) in ((-5, -5, 2.5), (-2, -6, 2), (4, -5, 2.5), (7, -3, 1.6)):
        for p in Frame.ellipse_set(cx + mx, by + my, r, r * 0.7):
            if p in body:
                f.put(p[0], p[1], P["g2"] if (p[1] - by - my) > 0 else P["g3"])
    # head
    hx = cx + (2 if side else 0)
    hy = by - 7
    f.ellipse(hx, hy, 4.5, 3.6, pal("s2", "s3", "s4"))
    if d != "up":
        eyes = [hx - 2, hx + 1] if not side else [hx + 1, hx + 3]
        for x in eyes:
            if hurt:
                f.put(x, hy, P["black"]); f.put(x + 1, hy, P["black"])
                f.put(x, hy - 1, glow) if False else None
            else:
                f.put(x, hy, glow)
                f.put(x + (1 if not side else 0), hy, glow)
        # brow ridge
        for x in range(int(hx - 3), int(hx + 3)):
            if f.get(x, int(hy) - 1) in (P["s3"], P["s4"]):
                f.put(x, int(hy) - 1, P["s2"])
    else:
        for (mx, my) in ((-1, -2), (0, -2), (1, -2), (0, -3)):
            f.put(hx + mx, hy + my, P["g3"])
    # front fists
    if side:
        fx = cx + 7 + fist_x
        f.ellipse(fx, by + 2 + fist_y, 3.2, 3.2, pal("s1", "s2", "s3", "s4"))
    elif not (d == "up" and fist_y < -4):
        for s in (-1, 1):
            fx = cx + s * (10 - fist_x)
            if slam_fwd:
                fx = cx + s * 5
            f.ellipse(fx, by + 2 + fist_y, 3.2, 3.2, pal("s1", "s2", "s3", "s4"))
            f.put(fx - 1, by + 2 + fist_y, P["s0"])
    # dust ring on slam
    if dust:
        r = 8 + dust * 4
        for k in range(14):
            a = k * (2 * math.pi / 14)
            x = 24 + math.cos(a) * r
            y = GY - 1 + math.sin(a) * r * 0.35
            if dust == 3 and k % 2:
                continue
            if (int(x), int(y)) not in f.px:
                f.put(x, y, P["b5"])
                if dust < 3:
                    f.put(x + 1, y, P["s4"])
    if chips:
        for k, (x, y) in enumerate(((-12, -6), (12, -8), (-9, -12), (10, -2))):
            f.put(cx + x - chips, by + y - chips, P["s2"])
            f.put(cx + x - chips + 1, by + y - chips, P["s1"])
    return f


def golem_death(i):
    if i < 2:
        f = golem("damaged", "down", i, 3)
        f.shift(0, i * 2)
        return f
    f = Frame(48)
    f.shadow(24, GY - 1, 11, 2.5)
    rocks = [(24, GY - 5, 7, 5), (15, GY - 3, 4, 3), (33, GY - 3, 4, 3), (20, GY - 9, 4, 3), (29, GY - 8, 3.5, 3)]
    keep = len(rocks) if i < 4 else len(rocks) - (i - 3)
    for k, (x, y, rx, ry) in enumerate(rocks[:keep]):
        sink = max(0, i - 3)
        f.ellipse(x, y + sink, rx, ry, pal("s1", "s2", "s3", "s4"))
    if i == 2:
        f.put(22, GY - 6, P["u3"]); f.put(25, GY - 6, P["u3"])
    for (mx, my) in ((22, GY - 10), (23, GY - 10), (30, GY - 9)):
        if f.get(mx, my) is not None:
            f.put(mx, my, P["g3"])
    if i >= 4:
        f.dissolve(0.15 * (i - 3), seed=40 + i, keep_outline=False)
    return f


# ---------------------------------------------------------------- Treant (boss, 64 px)
TGY = 56


def leafy(f, cx, cy, blobs, sway=0, berries=True):
    s = set()
    for (x, y, rx, ry) in blobs:
        s |= Frame.ellipse_set(cx + x + sway * (1 if y < 0 else 0.5), cy + y, rx, ry)
    xs = [p[0] for p in s]
    ys = [p[1] for p in s]
    ccx = (min(xs) + max(xs)) / 2.0
    ccy = (min(ys) + max(ys)) / 2.0
    f.shape(s, pal("g1", "g2", "g3", "g4"), center=(ccx, ccy),
            radii=((max(xs) - min(xs)) / 2.0, (max(ys) - min(ys)) / 2.0), th=(-0.3, 0.35, 0.8), ocol=P["g0"])
    # leaf tufts (small dark arcs like the pack's trees)
    for (x, y) in ((-8, -3), (6, -6), (-2, 2), (9, 2), (-11, 4), (2, -9), (-5, 7), (5, 6)):
        px, py = int(ccx + x), int(ccy + y)
        if (px, py) in s and (px + 2, py) in s and (px + 1, py - 1) in s:
            f.put(px, py, P["g1"]); f.put(px + 1, py - 1, P["g1"]); f.put(px + 2, py, P["g1"])
    if berries:
        for (x, y) in ((-10, -1), (8, -3), (-3, 5), (11, 5), (0, -7), (-7, 7)):
            px, py = int(ccx + x), int(ccy + y)
            if (px, py) in s:
                f.put(px, py, P["r2"]); f.put(px, py + 1, P["r0"])
    return s


def treant(anim, d, i, n):
    f = Frame(64, outline=P["b0"])
    sway = 0
    bob = 0
    lift = [0, 0]
    arm = 0  # 0 rest, 1 raised, 2 slammed forward
    face = "normal"
    leaves = 0
    if anim == "idle":
        sway = [0, 1, 0, -1][i]
        bob = [0, 0, 1, 0][i]
    elif anim == "move":
        bob = [0, -1, 0, 0, -1, 0][i]
        lift = [[2, 0], [1, 0], [0, 0], [0, 2], [0, 1], [0, 0]][i]
        sway = [1, 1, 0, -1, -1, 0][i]
    elif anim == "attack":
        arm = [0, 1, 1, 2, 2, 2, 0][i]
        bob = [0, -1, -2, 2, 2, 1, 0][i]
        face = ["normal", "angry", "angry", "roar", "roar", "angry", "normal"][i]
        leaves = [0, 0, 0, 1, 2, 3, 0][i]
        sway = [0, -1, -2, 2, 1, 0, 0][i]
    elif anim == "damaged":
        face = "hurt" if i < 2 else "normal"
        sway = [-2, -1, 0][i]
        leaves = [1, 2, 0][i]
    elif anim == "death":
        return treant_death(i)
    side = d == "right"
    f.shadow(32, TGY - 1, 14, 3)
    cx = 32
    ty = 45 + bob
    # roots / feet
    roots = [(-7, -1), (-2, 1), (3, 1), (7, -1)] if not side else [(-5, 0), (0, 1), (5, 0)]
    for k, (rx, s) in enumerate(roots):
        lf = lift[k % 2]
        pts = [(cx + rx - 2, TGY - 6 - lf), (cx + rx + 2, TGY - 6 - lf), (cx + rx + 2 + s * 2, TGY - lf), (cx + rx - 2 + s * 2, TGY - lf)]
        f.shape(Frame.poly_set(pts), pal("b1", "b2", "b3"))
    # arms (branches) behind trunk when raised
    def branch(sgn, front):
        if arm == 0:
            a0, a1 = (cx + sgn * 6, ty - 2), (cx + sgn * 14, ty + 4)
        elif arm == 1:
            a0, a1 = (cx + sgn * 6, ty - 4), (cx + sgn * 12, ty - 16)
        else:
            a0, a1 = (cx + sgn * 6, ty - 2), (cx + sgn * 8, ty + 10)
        if side:
            a0 = (cx + 2, a0[1])
            a1 = (cx + 2 + (a1[0] - cx) * (0.8 if front else -0.5), a1[1])
        f.shape(Frame.line_set(a0[0], a0[1], a1[0], a1[1], 3), pal("b1", "b2", "b3"))
        # twigs
        tx, ty2 = a1
        f.shape(Frame.line_set(tx, ty2, tx + sgn * 2, ty2 - 3, 1), pal("b2"))
        leafy(f, tx, ty2, [(0, 0, 3.2, 2.6)], berries=False)
    if side:
        branch(-1, False)
    trunk = Frame.ellipse_set(cx, ty, 9, 10) | Frame.rect_set(cx - 8, ty, cx + 7, TGY - 5)
    f.shape(trunk, pal("b1", "b2", "b3", "b4"), center=(cx, ty), radii=(9, 11), th=(-0.45, 0.25, 0.75))
    # bark lines
    for bx in (-5, -1, 4):
        for y in range(int(ty - 6), int(TGY - 5)):
            if (y + bx) % 5 != 0 and (cx + bx, y) in trunk:
                f.put(cx + bx + (1 if y > ty + 3 else 0), y, P["b2"])
    # face carved in the trunk
    if d != "up":
        fx = cx + (2 if side else 0)
        eyes = [fx - 4, fx + 2] if not side else [fx + 1, fx + 5]
        for k, ex in enumerate(eyes):
            ey = int(ty - 2)
            hole = Frame.rect_set(ex, ey, ex + 2, ey + 1) if not side else Frame.rect_set(ex, ey, ex + 1, ey + 1)
            f.fill(hole, P["black"])
            if face == "hurt":
                f.put(ex + 1, ey, P["b0"])
            else:
                f.put(ex + 1 if not side else ex + 1, ey + 1, P["o2"])
                f.put(ex + (1 if not side else 0), ey, P["o1"] if face != "normal" else P["black"])
            # brows
            by2 = ey - 1 - (1 if face in ("angry", "roar") and k == 0 else 0)
            f.put(ex, ey - 1, P["b1"]); f.put(ex + 1, by2 if face in ("angry", "roar") else ey - 1, P["b1"])
        my = int(ty + 3)
        mx0 = int(fx - 3) if not side else int(fx + 2)
        mw = 6 if not side else 4
        if face == "roar":
            f.fill(Frame.rect_set(mx0, my, mx0 + mw - 1, my + 3), P["black"])
            for x in range(mx0, mx0 + mw, 2):
                f.put(x, my, P["b5"])
        else:
            for k in range(mw):
                f.put(mx0 + k, my + (k % 2), P["black"])
    else:
        # knot hole on the back
        f.fill(Frame.rect_set(cx - 1, ty, cx + 1, ty + 2), P["b1"])
        f.put(cx, ty + 1, P["black"])
    # canopy (crown)
    crown = [(0, 0, 13, 8), (-9, 3, 7, 6), (9, 3, 7, 6), (-5, -6, 7, 5.5), (5, -6, 7, 5.5), (0, -9, 6, 4)]
    leafy(f, cx + (1 if side else 0), ty - 15 + (1 if arm == 2 else 0), crown, sway=sway)
    if side:
        branch(1, True)
    else:
        branch(-1, True)
        branch(1, True)
    # falling leaves
    if leaves:
        for k, (x, y) in enumerate(((-16, -8), (16, -12), (-12, 4), (18, 2), (-4, -24), (8, -22))):
            if leaves == 3 and k % 2:
                continue
            px, py = cx + x * (0.8 + leaves * 0.15), ty + y + leaves * 3
            f.put(px, py, P["g3"]); f.put(px + 1, py, P["g4"]); f.put(px, py + 1, P["g2"])
    return f


def treant_death(i):
    if i < 2:
        f = treant("damaged", "down", i, 3)
        f.shift(0, i * 2)
        return f
    f = Frame(64, outline=P["b0"])
    f.shadow(32, TGY - 1, 14, 3)
    h = [0, 0, 12, 9, 7, 6][i]
    # stump
    stump = Frame.rect_set(25, TGY - h, 38, TGY - 2)
    f.shape(stump, pal("b1", "b2", "b3"), light=(-1, 0))
    top = Frame.ellipse_set(31.5, TGY - h, 7, 2)
    f.shape(top, pal("b3", "b4", "b5"))
    f.put(31, TGY - h, P["b2"]); f.put(32, TGY - h, P["b2"])
    for (x, s) in ((22, -1), (40, 1)):
        f.shape(Frame.poly_set([(x - 1, TGY - 4), (x + 2, TGY - 4), (x + 2 + s * 2, TGY), (x - 1 + s * 2, TGY)]), pal("b1", "b2"))
    # fallen crown pieces
    pieces = [(16, TGY - 5, 6, 4), (47, TGY - 4, 6, 3.5), (30, TGY - h - 4, 7, 4)]
    if i <= 3:
        for (x, y, rx, ry) in pieces[: 3 if i == 2 else 2]:
            leafy(f, x, y, [(0, 0, rx, ry)], berries=True)
    if i >= 4:
        for k in range(10 - (i - 4) * 4):
            f.put(12 + k * 4, TGY - 2 - (k % 3), P["g3"] if k % 2 else P["g2"])
    if i == 5:
        f.dissolve(0.1, seed=77)
    return f
