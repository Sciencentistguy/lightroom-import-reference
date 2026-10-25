#!/usr/bin/env python3
# measure each case's effect relative to 01-baseline in each renderer
# (Lightroom, darktable before, darktable after), so renderers with
# different base looks can be compared:
#   python3 analyse.py
# needs numpy, pillow and scipy
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

HERE = Path(__file__).resolve().parent
RENDERERS = {
    'lightroom': HERE / 'cases',
    'before': HERE / 'out-before' / 'darktable',
    'after': HERE / 'out' / 'darktable',
}


def load(renderer, case):
    img = Image.open(RENDERERS[renderer] / f'{case}.jpg').convert('RGB')
    img = img.resize((1200, round(1200 * img.height / img.width)), Image.LANCZOS)
    return np.asarray(img, dtype=np.float64) / 255.0


def luma(rgb):
    return rgb @ np.array([0.2126, 0.7152, 0.0722])


def transfer(base, edit, bins=16):
    # median edited luma per baseline-luma bin, over bins with enough pixels
    b, e = luma(base).ravel(), luma(edit).ravel()
    edges = np.linspace(0, 1, bins + 1)
    idx = np.clip(np.digitize(b, edges) - 1, 0, bins - 1)
    curve = np.full(bins, np.nan)
    for k in range(bins):
        sel = e[idx == k]
        if sel.size > 500:
            curve[k] = np.median(sel) - (edges[k] + edges[k + 1]) / 2
    return curve


def local_contrast(rgb):
    l = luma(rgb)
    return np.std(l - gaussian_filter(l, 8))


def vignette(rgb):
    l = luma(rgb)
    h, w = l.shape
    ch, cw = h // 5, w // 5
    corners = np.concatenate([l[:ch, :cw].ravel(), l[:ch, -cw:].ravel(),
                              l[-ch:, :cw].ravel(), l[-ch:, -cw:].ravel()])
    centre = l[2 * ch:3 * ch, 2 * cw:3 * cw]
    return corners.mean() / centre.mean()


def chroma_shift(base, edit):
    # mean RGB shift (minus the luma shift) in shadows and highlights
    lb = luma(base)
    out = {}
    for name, sel in (('shadows', lb < 0.3), ('highlights', lb > 0.7)):
        d = (edit - base)[sel]
        d = d - d.mean(axis=1, keepdims=True)
        out[name] = d.mean(axis=0)
    return out


def curve_distance(a, b):
    ok = ~np.isnan(a) & ~np.isnan(b)
    return np.mean(np.abs(a[ok] - b[ok]))


base = {r: load(r, '01-baseline') for r in RENDERERS}

print('tone: mean |darktable - Lightroom| of the luma change vs baseline (lower is closer)')
for case in ['07-exposure-plus', '08-exposure-minus', '09-blacks', '11-curve-medium',
             '12-curve-strong', '13-curve-custom', '14-curve-parametric']:
    c = {r: transfer(base[r], load(r, case)) for r in RENDERERS}
    print(f'  {case:22s} before {curve_distance(c["before"], c["lightroom"]):.3f}'
          f'   after {curve_distance(c["after"], c["lightroom"]):.3f}')

print('\nclarity: local contrast relative to baseline (1.00 = unchanged)')
for case in ['15-clarity-plus', '16-clarity-minus']:
    v = {r: local_contrast(load(r, case)) / local_contrast(base[r]) for r in RENDERERS}
    print(f'  {case:22s} lightroom {v["lightroom"]:.3f}   before {v["before"]:.3f}   after {v["after"]:.3f}')

print('\nvignette: corner/centre brightness relative to baseline (1.00 = unchanged)')
v = {r: vignette(load(r, '19-vignette')) / vignette(base[r]) for r in RENDERERS}
print(f'  {"19-vignette":22s} lightroom {v["lightroom"]:.3f}   before {v["before"]:.3f}   after {v["after"]:.3f}')

print('\nsplit toning: mean RGB shift minus luma shift vs baseline (R, G, B)')
for r in RENDERERS:
    s = chroma_shift(base[r], load(r, '18-split-toning'))
    print(f'  {r:10s} shadows {np.round(s["shadows"], 3)}   highlights {np.round(s["highlights"], 3)}')
