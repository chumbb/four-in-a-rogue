"""Red intro Goob = the blue one, recoloured and tipped over (Sean 2026-11-20: same black
outline and rendering as the blue; no more PixelLab gens). No AI: pure pixel ops.

raw_blue_edit.png -> quantise -> wipe its face -> recolour the blue ramp to the red ramp ->
squash the rows to SQUASH (nearest) so the disc lies flat, face up; its rim, on the right in
the blue, stays on the right, so it lies at an angle -> grow the rim THICK px down under the
face (lit edge, mid, dark) -> fresh 1 px 2e222f outline round the whole thing -> ground
shadow like the blue's -> face on top, tilted, eyes gazing up at the sky, relaxed smile, blush.
Run: python art/strange_man/goobs/make_red_tipped.py -> raw_red_tipped.png"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "palette"))
from resurrect64 import hexc, quantize  # noqa: E402

SQUASH = 0.5
THICK = 4
INK = hexc("2e222f")
RED = {k: hexc(v) for k, v in {"face": "e83b3b", "lit": "f57d4a", "mid": "ae2334",
                                "dark": "6e2727", "shade": "b33831"}.items()}
# blue ramp -> red ramp (same roles)
RECOLOUR = {"4d9be6": "e83b3b", "4d65b4": "ae2334", "484a77": "6e2727", "8fd3ff": "f57d4a",
            "8ff8e2": "fca790", "323353": "45293f", "3e3546": "45293f", "c7dcd0": "fca790"}
FACE_JUNK = {"ffffff", "45293f", "323353", "3e3546", "c7dcd0", "4d65b4", "8fd3ff"}


def hx(p):
    return "%02x%02x%02x" % p[:3]


def outline(im, alpha):
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if alpha.getpixel((x, y)) and any(not (0 <= x + dx < w and 0 <= y + dy < h)
                                              or not alpha.getpixel((x + dx, y + dy))
                                              for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                im.putpixel((x, y), INK)


def build():
    blue = quantize(Image.open(os.path.join(HERE, "raw_blue_edit.png")))
    disc = blue.crop((0, 0, 48, 38))  # rows 38+ are its ground shadow; redrawn below
    px = disc.load()
    for y in range(38):
        for x in range(48):
            p = px[x, y]
            if not p[3]:
                continue
            h = hx(p)
            if 14 <= x <= 33 and 16 <= y <= 27 and h in FACE_JUNK:
                h = "4d9be6"  # wipe eyes, mouth, blush
            px[x, y] = hexc(RECOLOUR.get(h, h))
    disc = disc.crop(disc.getbbox())
    w, fh = disc.width, round(disc.height * SQUASH)
    h = fh + THICK
    flat = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(fh):
        sy = min(disc.height - 1, int((y + 0.5) / SQUASH))
        for x in range(w):
            flat.putpixel((x, y), disc.getpixel((x, sy)))
    # rim under the face: per column, below the face's lowest pixel
    for x in range(w):
        ys = [y for y in range(fh) if flat.getpixel((x, y))[3]]
        if not ys:
            continue
        yb = ys[-1]
        flat.putpixel((x, yb), RED["lit"])  # lit edge between face and rim
        for i in range(1, THICK + 1):
            flat.putpixel((x, yb + i), RED["dark"] if i == THICK else RED["mid"])
    out = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    ox, oy = (48 - w) // 2, 44 - h
    for y in range(48):  # ground shadow (ink oval, like under the blue one)
        for x in range(48):
            if ((x - 24) / (w / 2 + 3)) ** 2 + ((y - (oy + h - 1)) / 3) ** 2 <= 1:
                out.putpixel((x, y), INK)
    out.alpha_composite(flat, (ox, oy))
    a = Image.new("L", (48, 48), 0)
    a.paste(flat.getchannel("A"), (ox, oy))
    outline(out, a)
    face(out, ox, oy, w, fh)
    return out


def face(im, ox, oy, w, fh):
    W, D = (255, 255, 255, 255), INK
    cx, cy = ox + w // 2 - 2, oy + fh // 2  # centre of the top face (rim is on the right)

    def eye(x, y, left):
        rows = [[W, D, D, RED["shade"]] if left else [RED["shade"], D, D, W], [W] * 4, [W] * 4]
        for j, row in enumerate(rows):
            for i, c in enumerate(row):
                im.putpixel((x + i, y + j), c)
    eye(cx - 8, cy - 3, True)  # tilted: the right eye sits lower (lying at an angle)
    eye(cx + 3, cy - 2, False)
    for dx, dy in ((-3, 2), (-2, 3), (-1, 3), (0, 3), (1, 3), (2, 2)):
        im.putpixel((cx + dx, cy + dy), RED["dark"])
    for dx, dy in ((-10, 1), (-9, 1), (7, 2), (8, 2)):
        im.putpixel((cx + dx, cy + dy), RED["lit"])


if __name__ == "__main__":
    img = build()
    img.save(os.path.join(HERE, "raw_red_tipped.png"))
    print("wrote raw_red_tipped.png", img.getbbox())
