"""Red intro Goob lying FLAT ON THE GROUND, face up (Sean 2026-11-20: "A is close, but none of
them show the goob lying flat on the ground. they should also be perfectly circular").

Drawn pixel by pixel from maths, no resampling: the top face is an exact ellipse (a perfect
circle seen from the front, lying flat), symmetric left/right, with the coin's rim showing
underneath. Shading copies the blue intro Goob's roles in the red ramp: face e83b3b, darker
inner edge on the shadow side, lit f57d4a edge where the face meets the rim, specular streak
upper left, rim ae2334 with a 6e2727 bottom and shadow side, 1 px 2e222f outline, ink ground
shadow. The face features are the blue's own pixels, turned clockwise like option A.

Options (Sean picks one): ry = how far you see onto the face (flatter -> rounder).
Run: python art/strange_man/goobs/make_red_flat.py -> raw_red_flat_<a|b>.png"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "palette"))
from resurrect64 import hexc, quantize  # noqa: E402

C = {k: hexc(v) for k, v in {"ink": "2e222f", "face": "e83b3b", "mid": "ae2334",
                              "dark": "6e2727", "lit": "f57d4a", "spec": "fca790"}.items()}
RECOLOUR = {"4d65b4": "ae2334", "484a77": "6e2727", "8fd3ff": "f57d4a", "323353": "45293f",
            "3e3546": "45293f", "c7dcd0": "c7dcd0", "45293f": "45293f", "ffffff": "ffffff"}
FEATURES = (16, 18, 28, 27)  # eyes + mouth on raw_blue_edit.png (x0, y0, x1, y1), centred
BLUSH = (12, 18, 30, 27)  # same plus the blush, when the face is tall enough for it
OPTIONS = {"a": 8.5, "b": 10.5}  # inner face ry; rx is fixed
RX = 16.5  # inner face half-width: 33 px face + outline = 35 px, like the blue's 34
THICK = 4  # rim rows under the face
SIZE = 48


def features(box_xy=FEATURES):
    blue = quantize(Image.open(os.path.join(HERE, "raw_blue_edit.png")))
    box = blue.crop(box_xy)
    out = Image.new("RGBA", box.size, (0, 0, 0, 0))
    for y in range(box.height):
        for x in range(box.width):
            p = box.getpixel((x, y))
            h = "%02x%02x%02x" % p[:3]
            if p[3] and h in RECOLOUR:
                out.putpixel((x, y), hexc(RECOLOUR[h]))
    return out.transpose(Image.Transpose.ROTATE_270)


def build(ry):
    cx = SIZE / 2  # pixel centres at x + 0.5 -> exact left/right symmetry
    cy = SIZE - 8 - THICK - ry  # face centre; rim + shadow below

    def in_face(x, y, dy=0):
        return ((x + 0.5 - cx) / RX) ** 2 + ((y + 0.5 - cy - dy) / ry) ** 2 <= 1

    im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    body = {(x, y) for x in range(SIZE) for y in range(SIZE)
            if any(in_face(x, y, t) for t in range(THICK + 1))}
    face = {(x, y) for (x, y) in body if in_face(x, y)}
    # ground shadow (ink oval), tucked under the rim
    by = max(y for _, y in body)
    for x in range(SIZE):
        for y in range(SIZE):
            if ((x + 0.5 - cx) / (RX + 3)) ** 2 + ((y + 0.5 - by) / 3.2) ** 2 <= 1:
                im.putpixel((x, y), C["ink"])
    for (x, y) in body:
        if (x, y) in face:
            c = C["face"]
            if (x, y + 1) not in face:  # face edge meeting the rim
                c = C["lit"]
            elif (x - 1, y) not in face or ((x, y - 1) not in face and x < cx):
                c = C["mid"]  # shadow-side inner edge (left, upper left)
        else:
            c = C["dark"] if (x, y + 1) not in body or x >= cx + RX * 0.45 else C["mid"]
        im.putpixel((x, y), c)
    for (x, y) in list(body):  # 1 px outline round the whole coin
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in body:
                im.putpixel((x + dx, y + dy), C["ink"])
    # specular streak, upper left of the face (like the blue's)
    x0 = round(cx - RX * 0.62)
    y0 = round(cy - ry * 0.45)
    for i in range(3):
        im.putpixel((x0 + i, y0 - i // 2), C["spec"])
    f = features(BLUSH if 2 * ry >= 20 else FEATURES)
    im.alpha_composite(f, (round(cx - f.width / 2), round(cy - f.height / 2)))
    return im


if __name__ == "__main__":
    for opt, ry in OPTIONS.items():
        img = build(ry)
        img.save(os.path.join(HERE, "raw_red_flat_%s.png" % opt))
        print("wrote raw_red_flat_%s.png" % opt, img.getbbox())
