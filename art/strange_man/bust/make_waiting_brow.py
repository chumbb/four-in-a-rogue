"""Waiting face (M6c playtest, Sean 2026-11-22: "B but with a raised eyebrow").

Hand-pixel edit of bust/raw_waiting_b.png (quantised to Resurrect 64): the brow on
the viewer's right is lifted, the gap under it filled with lid skin.
  python art/strange_man/bust/make_waiting_brow.py   -> bust/raw_waiting_b1|b2|b3.png
                                                      + art/strange_man/compare_waiting_brow.png
b1 = up 1 px, b2 = up 2 px, b3 = arched (ends up 1 px, middle up 2 px).
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "palette"))
from resurrect64 import hexc, quantize  # noqa: E402

BROW_COLS = range(34, 41)  # viewer's right brow, game px in the 64 px bust
BROW_ROWS = range(18, 21)  # outline, light grey, shading
SKIN = tuple(hexc("fca790")[:3]) + (255,)
OPTIONS = {
    "b1": {c: 1 for c in BROW_COLS},
    "b2": {c: 2 for c in BROW_COLS},
    "b3": {c: (2 if 36 <= c <= 38 else 1) for c in BROW_COLS},
}


def lift(src, shifts):
    out = src.copy()
    for c, k in shifts.items():
        for r in BROW_ROWS:  # clear the old brow to skin first
            out.putpixel((c, r), SKIN)
        for r in BROW_ROWS:
            out.putpixel((c, r - k), src.getpixel((c, r)))
    return out


def main():
    base = quantize(Image.open(os.path.join(HERE, "raw_waiting_b.png")).convert("RGBA"))
    shown = [base]
    for name, shifts in OPTIONS.items():
        img = lift(base, shifts)
        img.save(os.path.join(HERE, f"raw_waiting_{name}.png"))
        shown.append(img)
    sheet = Image.new("RGBA", (len(shown) * 272, 288), tuple(hexc("3e3546")[:3]) + (255,))
    for i, img in enumerate(shown):
        sheet.alpha_composite(img.resize((256, 256), Image.NEAREST), (i * 272 + 8, 16))
    sheet.save(os.path.join(HERE, "..", "compare_waiting_brow.png"))


if __name__ == "__main__":
    main()
