"""Turn PixelLab character exports into sprite sheets with the Mystic Woods layout.

Usage:
    python3 tools/pixellab_import.py <name> <export_dir> <grid> [--recolor-grass] [--no-snap]
    python3 tools/pixellab_import.py prop <png> <out.png> [size]     (NPCs and props)

<export_dir> is an unzipped PixelLab character download (metadata.json + folders).
Animations must be named idle, move, attack, damaged and death (south/east/north;
death only needs south). The result goes to assets/monsters/<name>.png and the
frame counts are merged into assets/monsters/monsters.json.

Post-processing so the sprites sit with the pack:
- every colour snapped to the pack palette (and grass-green bodies moved to the
  leaf greens so creatures don't vanish on the grass)
- half-transparent pixels and PixelLab's own ground shadows removed
- feet placed on the pack's ground line (y=24 on 32 px, y=40 on 48 px)
- the pack's translucent shadow ellipse added under the feet
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel import P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GROUND = {32: 24, 48: 40, 64: 56, 80: 72}
ANIMS = ["idle", "move", "attack", "damaged"]
DIRS = [("down", "south"), ("right", "east"), ("up", "north")]
# pack palette plus the hero's colours (skin, hair, clothes), also from the pack
PALETTE = [v for v in P.values() if v[3] == 255] + [
    (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)
    for h in ["573a23", "402717", "ac7b5d", "c1ac8f", "2c65b5", "1d438a", "a4a8b5", "787e97", "dbd2c7", "9a5c42"]]
GRASS_SWAP = {P["gr0"][:3]: P["g1"], P["gr1"][:3]: P["g2"], P["gr2"][:3]: P["g3"], P["gr3"][:3]: P["g4"]}


def nearest(c):
    r, g, b = c[:3]
    best = None
    bd = 1e9
    for p in PALETTE:
        # weighted RGB distance (green matters most to the eye)
        d = 2 * (r - p[0]) ** 2 + 4 * (g - p[1]) ** 2 + 3 * (b - p[2]) ** 2
        if d < bd:
            bd = d
            best = p
    return best


def clean(im, recolor_grass, snap=True):
    im = im.convert("RGBA")
    px = im.load()
    cache = {}
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] < 160:
                px[x, y] = (0, 0, 0, 0)
                continue
            if not snap:
                px[x, y] = c[:3] + (255,)
                continue
            if c not in cache:
                n = nearest(c)
                if recolor_grass and n[:3] in GRASS_SWAP:
                    n = GRASS_SWAP[n[:3]]
                cache[c] = n
            px[x, y] = cache[c]
    # drop isolated specks (PixelLab sometimes leaves single stray pixels)
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] == 0:
                continue
            n = 0
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < im.width and 0 <= yy < im.height and px[xx, yy][3] > 0:
                    n += 1
            if n == 0:
                px[x, y] = (0, 0, 0, 0)
    return im


def feet_of(im):
    """Bottom row of the sprite and the horizontal centre of its lowest rows."""
    bbox = im.getbbox()
    if not bbox:
        return im.width // 2, im.height // 2
    px = im.load()
    bottom = bbox[3] - 1
    xs = [x for y in range(max(bbox[1], bottom - 3), bottom + 1) for x in range(im.width) if px[x, y][3] > 0]
    return (min(xs) + max(xs)) / 2.0, bottom


def shadow(cell, cx, ground, rx):
    ry = max(1.5, rx / 3.2)
    px = cell.load()
    for y in range(cell.height):
        for x in range(cell.width):
            nx = (x + 0.5 - cx) / rx
            ny = (y + 0.5 - (ground - 1)) / ry
            if nx * nx + ny * ny <= 1.0 and px[x, y][3] == 0:
                px[x, y] = P["shadow"]


def _golem_fix(im, anim, direction):
    """Stone golem: remove the pale ground puddle PixelLab drew under it, drop the stray cyan orbs
    its walk cycle grows from the side and back, and lift the near-black navy to a stone grey that
    reads on the grass and at night."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            if r > 125 and g > 120 and b > 150 and abs(r - g) < 20:
                px[x, y] = (0, 0, 0, 0)
                continue
            if anim == "move" and direction != "south" and b > 120 and b > r + 30 and g > r:
                px[x, y] = (0, 0, 0, 0)
                continue
            if b > r + 40 and g > r + 20:
                continue  # crystal core and runes keep their glow
            lum = (r + g + b) / 3.0
            r, g, b = [int(min(255, (c * 0.6 + lum * 0.4) * 1.45 + 14)) for c in (r, g, b)]
            px[x, y] = (r, g, b, 255)
    return im


def _bat_fix(im, anim, direction):
    """Seen from behind the bat must not show the white mouth or red eyes some attack frames paint on its back."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and direction == "north" and ((r > 190 and g > 190 and b > 190) or (r > 150 and g < 80 and b < 80)):
                px[x, y] = (72, 66, 92, 255)
    return im


def _ghost_fix(im, anim, direction):
    """From behind the ghost must not show the gaping black mouth its scream attack paints."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and direction == "north" and anim == "attack" and r + g + b < 240:
                # outline pixels border the transparent outside; mouth pixels sit inside the body
                inside = all(0 <= x + dx < im.width and 0 <= y + dy < im.height and px[x + dx, y + dy][3]
                             for dx, dy in ((4, 0), (-4, 0), (0, 4), (0, -4)))
                if inside:
                    px[x, y] = (178, 208, 204, 255)
    return im


def _spider_fix(im, anim, direction):
    """Drop the white impact sparks the spider's hurt clip scatters around the cell."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and anim == "damaged" and r > 215 and g > 215 and b > 215:
                px[x, y] = (0, 0, 0, 0)
    return im


# per-monster clean-ups applied to every frame after palette handling
FIXES = {"spider": _spider_fix, "golem": _golem_fix, "bat": _bat_fix, "ghost": _ghost_fix}
# frames picked out of a generated clip (e.g. a hurt clip that ends with the monster lying down
# would read as a death, so only the flinch is kept and it returns to its feet)
FRAME_PICK = {"goblin": {"damaged": [0, 1, 2, 1, 0], "attack:east": [0, 1, 2, 3, 4, 6, 8]}, "golem": {"damaged": [0, 1, 2, 0], "move:north": [0, 1, 2, 1]},
              "treant": {"attack:south": [0, 1, 2, 3, 4, 4, 6]},
              "spider": {"attack:north": [0, 1, 2, 4, 5, 6, 8]}}


def load_export(export_dir):
    meta = json.load(open(os.path.join(export_dir, "metadata.json")))
    state = meta["states"][0]
    anims = {}
    for key, dirs in state["frames"]["animations"].items():
        name = key.split("-")[0].split("_")[0].lower()
        for d, frames in dirs.items():
            anims.setdefault(name, {})[d] = [os.path.join(export_dir, f) for f in frames]
    rot = {d: os.path.join(export_dir, f) for d, f in state["frames"]["rotations"].items()}
    return anims, rot


def write_frames_gd(meta):
    """Frame counts as a GDScript constant, so exported games don't need the JSON file."""
    lines = ["class_name MonsterFrames", "## Generated by tools/pixellab_import.py - do not edit.", "", "const FRAMES := {"]
    for k, v in sorted(meta.items()):
        if v.get("source") == "pixellab":
            f = v["frames"]
            lines.append('\t"%s": {%s},' % (k, ", ".join('"%s": %d' % (a, f[a]) for a in ["idle", "move", "attack", "damaged", "death"])))
    lines.append("}")
    open(os.path.join(ROOT, "scripts", "MonsterFrames.gd"), "w").write("\n".join(lines) + "\n")


def build(name, export_dir, grid, recolor_grass=False, flying=False, snap=True):
    anims, rot = load_export(export_dir)
    ground = GROUND[grid]
    # per direction: offset from the idle reference so feet sit on the ground line
    anchor = {}
    fix = FIXES.get(name)
    for _d, pl in DIRS:
        ref = clean(Image.open(rot[pl]), recolor_grass, snap)
        if fix:
            ref = fix(ref, "idle", pl)
        fx, fy = feet_of(ref)
        lift = 6 if flying else 0
        rb = ref.getbbox() or (0, 0, ref.width, ref.height)
        oy = ground - 1 - lift - fy
        # vertical centre of the reference pose inside the cell (flyers keep every frame there)
        anchor[pl] = (grid / 2.0 - fx, oy, ref.width, ref.height, oy + (rb[1] + rb[3]) / 2.0)
    body_w = (clean(Image.open(rot["south"]), recolor_grass, snap).getbbox() or (0, 0, 16, 0))
    rx = max(4.0, (body_w[2] - body_w[0]) / 3.2)

    rows = []
    for a in ANIMS:
        for _d, pl in DIRS:
            # flying creatures can reuse their hovering loop as the move cycle
            frames = anims.get(a, {}).get(pl) or anims.get("idle", {}).get(pl) or [rot[pl]]
            picks = FRAME_PICK.get(name, {})
            pick = picks.get(a + ":" + pl) or picks.get(a)
            if pick and a in anims:
                frames = [frames[i] for i in pick]
            rows.append((pl, frames))
        # the game reads one frame count per animation (from the south row), so a direction
        # with fewer frames loops its own frames instead of showing empty cells
        n = len(rows[-3][1])
        for k in (-2, -1):
            pl_k, fr = rows[k]
            if len(fr) != n:
                rows[k] = (pl_k, [fr[i % len(fr)] for i in range(n)])
    rows.append(("south", anims.get("death", {}).get("south") or [rot["south"]]))
    cols = max(len(f) for _p, f in rows)
    sheet = Image.new("RGBA", (cols * grid, len(rows) * grid))
    counts = {}
    for r, (pl, frames) in enumerate(rows):
        ox, oy, rw, rh, ref_cy = anchor[pl]
        for i, f in enumerate(frames):
            im = clean(Image.open(f), recolor_grass, snap)
            if fix:
                im = fix(im, ANIMS[r // 3] if r < 12 else "death", pl)
            # animation canvases are bigger than the rotation canvas; both are centred on the character
            dx = int(round(ox - (im.width - rw) / 2.0))
            dy = int(round(oy - (im.height - rh) / 2.0))
            bb = im.getbbox()
            if bb and flying and r < 12:
                # hover clips drift up and down inside a canvas bigger than the 32 px cell:
                # hold the body where the reference pose floats so it never leaves the cell
                dy = int(round(ref_cy - (bb[1] + bb[3]) / 2.0))
            if bb and dy + bb[1] < 0:
                dy = -bb[1]  # never cut the top of the sprite off
            cell = Image.new("RGBA", (grid, grid))
            shadow(cell, grid / 2.0, ground, rx * (0.8 if flying else 1.0))
            cell.alpha_composite(im, dest=(max(dx, 0), max(dy, 0)), source=(max(-dx, 0), max(-dy, 0)))
            sheet.alpha_composite(cell, (i * grid, r * grid))
    for k, a in enumerate(ANIMS):
        counts[a] = len(rows[k * 3][1])
    counts["death"] = len(rows[-1][1])
    out = os.path.join(ROOT, "assets", "monsters", name + ".png")
    sheet.save(out)
    meta_path = os.path.join(ROOT, "assets", "monsters", "monsters.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    meta[name] = {"size": grid, "frames": counts, "source": "pixellab"}
    json.dump(meta, open(meta_path, "w"), indent=2)
    write_frames_gd(meta)
    print(name, counts, sheet.size)
    return sheet


def prop(src, out, size=32, snap=False, shadow_rx=None):
    """Single image (NPC or prop): put its base on the bottom of a size x size cell with the pack shadow.
    Colours are kept as PixelLab drew them unless snap=True (skin tones suffer when snapped)."""
    im = clean(Image.open(src), False, snap)
    bbox = im.getbbox()
    im = im.crop(bbox)
    cell = Image.new("RGBA", (size, size))
    fx = size / 2.0
    rx = shadow_rx or max(4.0, im.width / 3.0)
    shadow(cell, fx, size - 1, rx)
    cell.alpha_composite(im, (int(round(fx - im.width / 2.0)), size - 2 - im.height))
    cell.save(out)


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "prop":
    prop(sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 32)
elif __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    build(args[0], args[1], int(args[2]), "--recolor-grass" in sys.argv, "--flying" in sys.argv,
          "--no-snap" not in sys.argv)
