"""Forest hand prop: the oak stump the hand Goobs rest on (Sean, 2026-11-19).

Usage: python art/hand/make_stump.py   (from the repo root)

Input : art/hand/forest_stump_pixellab.png  (PixelLab Pro, 200x144, Resurrect 64 palette)
Output: assets/hand/forest_stump.png        320x240: quantised to Resurrect 64; the crack
        wedge on the lower left repainted; the lower trunk stretched down so it always runs off
        the screen bottom; the sides widened so the bark slopes outward
        and runs off both screen edges (Sean, 2026-11-19 playtest: no hard side cut).
Shown at the hand Goobs' pixel scale (5x at 1080 wide). Seat row and top width are
STUMP_SEAT_Y / STUMP_TOP_WIDTH in scripts/scenario/scenario_placeholder.gd.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "palette"))
from resurrect64 import quantize  # noqa: E402

SRC = "art/hand/forest_stump_pixellab.png"
OUT = "assets/hand/forest_stump.png"
OUT_H = 240
BAND = (100, 144)  # lower trunk rows stretched down to OUT_H

SIDE = 60  # px added each side; the screen shows ~108 game px either side of centre
FLARE_Y0 = 30  # first row below the top rim where the sides start to slope out
FLARE_K = 0.004  # edge moves out FLARE_K * (y - FLARE_Y0)^2 px
EDGE_BAND = 40  # outer px of each row stretched outward
CRACK_BOX = (28, 28, 62, 62)  # where the crack runs off the top onto the bark
CRACK = (0x96, 0x6C, 0x6C)
OUTLINE = (0x2E, 0x22, 0x2F, 255)


def fix_crack(img):
    """Replace the crack's flat mauve fill with the nearest pixel left/right in its row."""
    px = img.load()
    x0, y0, x1, y1 = CRACK_BOX
    bad = {(x, y) for x in range(x0, x1) for y in range(y0, y1) if px[x, y][:3] == CRACK}
    for x, y in sorted(bad):
        for d in range(1, 12):
            for nx in (x - d, x + d):
                if (nx, y) not in bad and px[nx, y][3]:
                    px[x, y] = px[nx, y]
                    break
            else:
                continue
            break


def extend_down(img):
    """Stretch the lower trunk (rows BAND) down to OUT_H: vertical grooves just get longer."""
    out = Image.new("RGBA", (img.width, OUT_H), (0, 0, 0, 0))
    out.paste(img.crop((0, 0, img.width, BAND[0])), (0, 0))
    band = img.crop((0, BAND[0], img.width, BAND[1]))
    out.paste(band.resize((img.width, OUT_H - BAND[0]), Image.NEAREST), (0, BAND[0]))
    return out


def widen(img):
    """Slope the sides outward: each row's outer EDGE_BAND px are stretched out to the
    flare edge (grooves fan out like a trunk widening at its base), with an outline."""
    w = img.width
    out = Image.new("RGBA", (w + 2 * SIDE, img.height), (0, 0, 0, 0))
    out.paste(img, (SIDE, 0))
    src, px = img.load(), out.load()
    for y in range(FLARE_Y0, img.height):
        reach = min(SIDE, round(FLARE_K * (y - FLARE_Y0) ** 2))
        if reach == 0:
            continue
        span = EDGE_BAND + reach
        for i in range(span):  # i = 0 at the new outer edge
            sx = min(EDGE_BAND - 1, i * EDGE_BAND // span)
            px[SIDE - reach + i, y] = src[sx, y]
            px[SIDE + w - 1 + reach - i, y] = src[w - 1 - sx, y]
    return out


def outline_sides(img):
    """Unbroken side outline: each row's outermost pixels, joined to the row above's edge
    by horizontal runs wherever the slope steps out more than 1 px."""
    px = img.load()
    prev = None
    for y in range(img.height):
        xs = [x for x in range(img.width) if px[x, y][3]]
        if not xs:
            prev = None
            continue
        left, right = xs[0], xs[-1]
        if left > 0:
            px[left, y] = OUTLINE
        if right < img.width - 1:
            px[right, y] = OUTLINE
        if prev:
            for x in range(left, min(prev[0], right)):
                if x > 0:
                    px[x, y] = OUTLINE
            for x in range(max(prev[1] + 1, left), right + 1):
                if x < img.width - 1:
                    px[x, y] = OUTLINE
        prev = (left, right)


src = quantize(Image.open(SRC))
fix_crack(src)
out = widen(extend_down(src))
outline_sides(out)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
out.save(OUT)
print("wrote", OUT, out.size)
