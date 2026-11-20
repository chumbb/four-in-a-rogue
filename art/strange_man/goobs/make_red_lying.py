"""Red intro Goob = the current blue intro Goob, lying on its back (Sean 2026-11-20:
"should just look like the current blue goob, but laying down on its back side").

No squash, no resampling, no AI: the blue's own pixels, turned a whole 90 degrees so its rim
(on the right in the blue) ends up underneath, a straight blue -> red ramp swap, a fresh 1 px
2e222f outline and an ink ground shadow like the blue's.

Options (Sean picks one):
  a  turned clockwise: rim underneath, face turned on its side with it
  b  a, mirrored (leans the other way)
  c  a, but the face kept upright on the lying disc
Run: python art/strange_man/goobs/make_red_lying.py -> raw_red_lying_<a|b|c>.png"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "palette"))
from resurrect64 import hexc, quantize  # noqa: E402

INK = hexc("2e222f")
# blue ramp -> red ramp (same roles as the game's red Goob)
RECOLOUR = {"4d9be6": "e83b3b", "4d65b4": "ae2334", "484a77": "6e2727", "8fd3ff": "f57d4a",
            "8ff8e2": "fca790", "323353": "45293f", "3e3546": "45293f", "c7dcd0": "fca790"}
DISC_ROWS = 38
FACE_BOX = (14, 14, 34, 28)  # eyes, mouth and blush on the blue (x0, y0, x1, y1)


def hx(p):
    return "%02x%02x%02x" % p[:3]


def disc_only(blue):
    """The blue without its outline and ground shadow (just the coloured disc)."""
    out = Image.new("RGBA", blue.size, (0, 0, 0, 0))
    for y in range(DISC_ROWS):  # rows below are the blue's ground shadow
        for x in range(blue.width):
            p = blue.getpixel((x, y))
            if p[3] and hx(p) != "2e222f":
                out.putpixel((x, y), hexc(RECOLOUR.get(hx(p), hx(p))))
    return out


def with_outline_and_shadow(disc):
    w, h = disc.size
    a = disc.getchannel("A")
    for y in range(h):  # drop stray single pixels sticking out of the edge
        for x in range(w):
            if a.getpixel((x, y)) and sum(
                    0 <= x + dx < w and 0 <= y + dy < h and a.getpixel((x + dx, y + dy)) > 0
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) <= 1:
                disc.putpixel((x, y), (0, 0, 0, 0))
    a = disc.getchannel("A")
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x0, y0, x1, y1 = disc.getbbox()
    cx, sy = (x0 + x1) / 2 - 0.5, y1 - 1  # shadow tucked under the disc, no gaps
    rx = (x1 - x0) / 2 + 2
    for y in range(h):
        for x in range(w):
            if ((x - cx) / rx) ** 2 + ((y - sy) / 3.2) ** 2 <= 1:
                out.putpixel((x, y), INK)
    for y in range(h):
        for x in range(w):
            if a.getpixel((x, y)):
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and a.getpixel((x + dx, y + dy))
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), INK)
    out.alpha_composite(disc)
    return out


def place(disc, size=48, floor=44):
    """Centre the disc horizontally, its shadow ending near the bottom like the blue."""
    x0, y0, x1, y1 = disc.getbbox()
    c = disc.crop((x0, y0, x1, y1))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(c, ((size - c.width) // 2, floor - 3 - c.height))
    return out


def build(option):
    blue = quantize(Image.open(os.path.join(HERE, "raw_blue_edit.png")))
    disc = disc_only(blue)
    if option == "c":
        face = disc.crop(FACE_BOX)
        body = disc.copy()
        fill = hexc("e83b3b")
        for y in range(FACE_BOX[1], FACE_BOX[3]):
            for x in range(FACE_BOX[0], FACE_BOX[2]):
                if body.getpixel((x, y))[3]:
                    body.putpixel((x, y), fill)
        turned = body.transpose(Image.Transpose.ROTATE_270)
        # face centre after the turn: (x, y) -> (H-1-y, x)
        fx = blue.height - 1 - (FACE_BOX[1] + FACE_BOX[3]) // 2
        fy = (FACE_BOX[0] + FACE_BOX[2]) // 2
        turned.alpha_composite(face, (fx - face.width // 2, fy - face.height // 2))
    else:
        turned = disc.transpose(Image.Transpose.ROTATE_270)
        if option == "b":
            turned = turned.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return with_outline_and_shadow(place(turned))


if __name__ == "__main__":
    for opt in "abc":
        img = build(opt)
        img.save(os.path.join(HERE, "raw_red_lying_%s.png" % opt))
        print("wrote raw_red_lying_%s.png" % opt, img.getbbox())
