#!/usr/bin/env python3
"""Cleans the fine dithering noise that AI-generated pixel art leaves behind.

1. Palette: the whole sheet is reduced to at most --colors colours (k-means in CIE Lab), so every
   frame of an animation shares one palette. The outline colour (darkest), the brightest
   highlights and small vivid accents (eyes, gems, berries) are kept as fixed entries.
2. Stray pixels: a 1-2 px island of one colour inside an area of a *similar* colour (Lab
   distance <= --dist) is absorbed into the most common similar neighbour colour. Pixels are
   updated in reading order, so checkerboard dithering collapses into flat tones instead of
   flipping. Untouched: the outline (pixels touching transparency and anything as dark as the
   darkest colour), highlights much brighter than their surroundings, colours clearly different
   from their neighbours, and half-transparent pixels (drop shadows).

Usage: python3 tools/pixel_cleanup.py <in.png> [out.png] [--colors 28] [--dist 14] [--passes 2]
       python3 tools/pixel_cleanup.py --stats <png>...
"""
import argparse
import sys

import numpy as np
from PIL import Image

N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
N8 = N4 + ((1, 1), (1, -1), (-1, 1), (-1, -1))


def to_lab(rgb):
    c = np.asarray(rgb, dtype=np.float64) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    xyz = c @ np.array([[0.4124, 0.2126, 0.0193], [0.3576, 0.7152, 0.1192], [0.1805, 0.0722, 0.9505]])
    xyz /= np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def reduce_palette(rgb, colors, fixed):
    """k-means over the unique colours (weighted by count); `fixed` centroids never move.
    Every final colour is a real colour of the sheet (the most used one of its cluster)."""
    uniq, inv, counts = np.unique(rgb, axis=0, return_inverse=True, return_counts=True)
    if len(uniq) <= colors:
        return rgb
    P = to_lab(uniq)
    F = [to_lab(np.array(f)) for f in fixed]
    order = np.argsort(-counts)
    seeds = []
    for i in order:
        if len(F) + len(seeds) >= colors:
            break
        if all(np.linalg.norm(P[i] - q) > 6 for q in F + [P[j] for j in seeds]):
            seeds.append(i)
    C = np.array(F + [P[j] for j in seeds])
    nf = len(F)
    for _ in range(30):
        a = ((P[:, None, :] - C[None, :, :]) ** 2).sum(-1).argmin(1)
        moved = 0.0
        for k in range(nf, len(C)):
            m = a == k
            if m.any():
                new = (P[m] * counts[m, None]).sum(0) / counts[m].sum()
                moved += np.abs(new - C[k]).sum()
                C[k] = new
        if moved < 0.05:
            break
    pal = np.zeros((len(C), 3), dtype=rgb.dtype)
    for k in range(len(C)):
        m = np.where(a == k)[0]
        pal[k] = fixed[k] if k < nf else (uniq[m[np.argmax(counts[m])]] if len(m) else uniq[order[0]])
    return pal[a][inv.reshape(-1)].reshape(rgb.shape)


def fixed_colours(rgb):
    """Outline, two brightest highlights and up to 6 small vivid accent colours."""
    uniq, counts = np.unique(rgb, axis=0, return_counts=True)
    lab = to_lab(uniq)
    fixed = [tuple(uniq[lab[:, 0].argmin()])]
    for i in np.argsort(-lab[:, 0]):
        if len(fixed) >= 3:
            break
        if counts[i] >= 4 and tuple(uniq[i]) not in fixed:
            fixed.append(tuple(uniq[i]))
    chroma = np.hypot(lab[:, 1], lab[:, 2])
    total = counts.sum()
    accents = 0
    for i in np.argsort(-chroma):
        if accents >= 6 or chroma[i] < 35:
            break
        # vivid, used a little (a detail, not a big area), and unlike what is already kept
        if 3 <= counts[i] <= total * 0.03 and all(np.linalg.norm(lab[i] - to_lab(np.array(f))) > 20 for f in fixed):
            fixed.append(tuple(uniq[i]))
            accents += 1
    return fixed


def absorb_strays(img, dist, highlight):
    a = img[..., 3] == 255
    H, W = a.shape
    out = img[..., :3].astype(np.int32).copy()
    lab_cache = {}

    def lab(c):
        k = (int(c[0]), int(c[1]), int(c[2]))
        if k not in lab_cache:
            lab_cache[k] = to_lab(np.array(k))
        return lab_cache[k]

    darkest = min(lab(out[y, x])[0] for y, x in zip(*np.nonzero(a))) if a.any() else 0.0
    changed = 0
    for y in range(H):
        for x in range(W):
            if not a[y, x]:
                continue
            col = out[y, x]
            lc = lab(col)
            if lc[0] <= darkest + 6:
                continue            # outline / black details
            # island of this exact colour (4-connected), only care if it is 1-2 px
            comp = [(y, x)]
            for dx, dy in N4:
                ny, nx = y + dy, x + dx
                if 0 <= ny < H and 0 <= nx < W and a[ny, nx] and (out[ny, nx] == col).all():
                    comp.append((ny, nx))
            if len(comp) > 2:
                continue
            if len(comp) == 2:
                # the partner must not continue into a bigger blob
                py, px = comp[1]
                for dx, dy in N4:
                    ny, nx = py + dy, px + dx
                    if (ny, nx) != (y, x) and 0 <= ny < H and 0 <= nx < W and a[ny, nx] and (out[ny, nx] == col).all():
                        comp = None
                        break
                if comp is None:
                    continue
            neigh = []
            border = False
            for cy, cx in comp:
                for dx, dy in N8:
                    ny, nx = cy + dy, cx + dx
                    if not (0 <= ny < H and 0 <= nx < W) or not a[ny, nx]:
                        border = True
                    elif (ny, nx) not in comp:
                        neigh.append((int(out[ny, nx][0]), int(out[ny, nx][1]), int(out[ny, nx][2])))
            if border:
                continue            # next to transparency: part of the outline band
            # most common neighbour colour that is similar enough
            tally = {}
            for c in neigh:
                if np.linalg.norm(lab(c) - lc) <= dist:
                    tally[c] = tally.get(c, 0) + 1
            if not tally:
                continue            # nothing similar around: a real detail (eye, gem, button)
            best, n = max(tally.items(), key=lambda kv: kv[1])
            if n < 3:
                continue
            if lc[0] - lab(best)[0] > highlight:
                continue            # deliberate highlight
            for cy, cx in comp:
                out[cy, cx] = best
                changed += 1
    img = img.copy()
    img[..., :3] = out
    return img, changed


def stats(img):
    a = img[..., 3] == 255
    rgb = img[..., :3]
    H, W = a.shape
    iso = 0
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if not a[y, x]:
                continue
            n = same = 0
            for dx, dy in N4:
                if a[y + dy, x + dx]:
                    n += 1
                    same += (rgb[y + dy, x + dx] == rgb[y, x]).all()
            iso += n >= 3 and same == 0
    return len(np.unique(rgb[a], axis=0)), int(a.sum()), iso


def clean(img, colors, dist, passes, highlight=18.0):
    img = img.copy()
    a = img[..., 3] == 255
    if not a.any():
        return img, 0
    rgb = img[..., :3][a]
    img[..., :3][a] = reduce_palette(rgb, colors, fixed_colours(rgb))
    total = 0
    for _ in range(passes):
        img, n = absorb_strays(img, dist, highlight)
        total += n
        if n == 0:
            break
    return img, total


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--colors", type=int, default=28)
    ap.add_argument("--dist", type=float, default=14.0, help="Lab distance a stray may be absorbed across")
    ap.add_argument("--passes", type=int, default=2)
    ap.add_argument("--stats", action="store_true")
    o = ap.parse_args()
    if o.stats:
        for p in o.files:
            c, op, iso = stats(np.array(Image.open(p).convert("RGBA")))
            print(f"{p}: colours={c} opaque={op} isolated={iso} ({100 * iso / max(op, 1):.1f}%)")
        return
    src = o.files[0]
    dst = o.files[1] if len(o.files) > 1 else src
    img = np.array(Image.open(src).convert("RGBA"))
    before = stats(img)
    out, n = clean(img, o.colors, o.dist, o.passes)
    after = stats(out)
    Image.fromarray(out.astype(np.uint8), "RGBA").save(dst)
    print(f"{src}: colours {before[0]} -> {after[0]}, isolated {before[2]} -> {after[2]}, absorbed {n} px")


if __name__ == "__main__":
    sys.exit(main())
