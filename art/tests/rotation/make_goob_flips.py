"""Build Goob spin (yaw) and flip (pitch) frames from PixelLab 2b output.

Usage: python make_goob_flips.py   (run from art/tests/rotation/)

Inputs : pixellab_2b_8dir_pro/rotations/*.png (34x34, PixelLab 8-directional Pro)
Outputs: out_<color>_<axis>/frame_0N.png (32x32), out_<color>_<axis>_strip.png,
         out_<color>_<axis>_4x.gif   for color in blue/red, axis in yaw/pitch

Yaw   = 2b's 8 views as-is (back is plain colour, which matches the v0.1 rule).
Pitch = end-over-end flip built from 2b's south (face), north (back) and east
        (edge) views: vertical squash by |cos(angle)|, a rim band for coin
        thickness, and the edge view turned on its side at 90/270 degrees.
Red   = hue shift of the blue frames (enemy red, player blue).
"""
import colorsys
import math
import os

from PIL import Image

SRC = "pixellab_2b_8dir_pro/rotations"
SIZE = 32
FPS = 12
YAW_ORDER = ["south", "south-east", "east", "north-east",
             "north", "north-west", "west", "south-west"]
BG = (40, 40, 48, 255)


def load(name):
    # 2b frames are 34x34 with content inside 3..31; crop 1 px each side.
    return Image.open(os.path.join(SRC, name + ".png")).convert("RGBA").crop((1, 1, 33, 33))


def content(im):
    return im.crop(im.getbbox())


def _feature_score(im, y):
    """How much face detail a row carries: very dark or very light pixels inside the disc."""
    px = im.load()
    opaque = [x for x in range(im.width) if px[x, y][3] > 0]
    if len(opaque) < 3:
        return 0
    inner = opaque[2:-2]
    return sum(1 for x in inner if sum(px[x, y][:3]) < 200 or min(px[x, y][:3]) > 200)


def squash_rows(im, new_h):
    """Vertical squash that keeps the outline rows and, inside each band of source
    rows that collapses to one output row, keeps the row with the most face detail
    (so eyes and mouth survive)."""
    w, h = im.size
    out = Image.new("RGBA", (w, new_h), (0, 0, 0, 0))
    for y in range(new_h):
        if y == 0:
            sy = 0
        elif y == new_h - 1:
            sy = h - 1
        else:
            lo = int(y * h / new_h)
            hi = max(lo + 1, int((y + 1) * h / new_h))
            sy = max(range(lo, hi), key=lambda r: (_feature_score(im, r), -abs(r - (lo + hi) / 2)))
        out.paste(im.crop((0, sy, w, sy + 1)), (0, y))
    return out


def darkest_and_rim(im):
    """Pick outline (darkest) and rim (mid-dark) colours from a sprite."""
    px = [p for p in im.getdata() if p[3] > 0]
    by_v = sorted(set(p[:3] for p in px), key=lambda c: sum(c))
    outline = by_v[0]
    rim = by_v[len(by_v) // 4]
    return outline + (255,), rim + (255,)


def coin_frame(disc, thickness, band_below, outline, rim):
    """Place a squashed disc with a rim band (coin thickness) on a 32x32 canvas."""
    w, h = disc.size
    total_h = h + thickness
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ox = (SIZE - w) // 2
    oy = (SIZE - total_h) // 2
    mask = disc.split()[3]
    band = Image.new("RGBA", disc.size, rim)
    disc_y = oy if band_below else oy + thickness
    for t in range(1, thickness + 1):
        dy = disc_y + t if band_below else disc_y - t
        canvas.paste(band, (ox, dy), mask)
    # Outline around the whole silhouette (disc + band).
    sil = Image.new("L", (SIZE, SIZE), 0)
    sil.paste(canvas.split()[3], (0, 0))
    sil.paste(mask, (ox, disc_y), mask)
    pix = sil.load()
    out = canvas.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if pix[x, y] == 0:
                continue
            edge = any(
                not (0 <= x + dx < SIZE and 0 <= y + dy < SIZE) or pix[x + dx, y + dy] == 0
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            )
            if edge and out[x, y][3] > 0:
                out[x, y] = outline
    canvas.alpha_composite(disc, (ox, disc_y))
    return canvas


def pitch_frames():
    face = content(load("south"))
    back = content(load("north"))
    edge = content(load("east")).rotate(90, expand=True)
    outline, rim = darkest_and_rim(face)
    max_t = min(edge.size[1], 4)
    frames = []
    for i in range(8):
        a = math.radians(i * 45)
        c, s = math.cos(a), math.sin(a)
        if abs(c) < 1e-6:
            f = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
            f.alpha_composite(edge, ((SIZE - edge.width) // 2, (SIZE - edge.height) // 2))
            frames.append(f)
            continue
        src = face if c > 0 else back
        if abs(c) > 0.999:
            f = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
            f.alpha_composite(src, ((SIZE - src.width) // 2, (SIZE - src.height) // 2))
            frames.append(f)
            continue
        disc = squash_rows(src, max(3, round(src.height * abs(c))))
        thickness = max(1, round(max_t * abs(s)))
        frames.append(coin_frame(disc, thickness, band_below=(s > 0), outline=outline, rim=rim))
    return frames


def to_red(im):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s < 0.15:  # whites / greys (eyes) stay as they are
                continue
            h = (h - 220 / 360) % 1.0  # blue ~215 deg -> red ~355 deg
            nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return out


def save_set(frames, name):
    os.makedirs(name, exist_ok=True)
    for i, f in enumerate(frames):
        f.save(os.path.join(name, "frame_%02d.png" % i))
    strip = Image.new("RGBA", (SIZE * len(frames), SIZE), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * SIZE, 0))
    strip.save(name + "_strip.png")
    gif = []
    for f in frames:
        c = Image.new("RGBA", f.size, BG)
        c.alpha_composite(f)
        gif.append(c.resize((SIZE * 4, SIZE * 4), Image.NEAREST).convert("P", palette=Image.ADAPTIVE))
    gif[0].save(name + "_4x.gif", save_all=True, append_images=gif[1:],
                duration=round(1000 / FPS), loop=0)
    return strip


def main():
    yaw = [load(d) for d in YAW_ORDER]
    pitch = pitch_frames()
    strips = []
    for color, conv in (("blue", lambda f: f), ("red", to_red)):
        strips.append(save_set([conv(f) for f in yaw], "out_%s_yaw" % color))
        strips.append(save_set([conv(f) for f in pitch], "out_%s_pitch" % color))
    sheet = Image.new("RGBA", (SIZE * 8, SIZE * len(strips)), BG)
    for r, s in enumerate(strips):
        sheet.alpha_composite(s, (0, r * SIZE))
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save("out_all_preview4x.png")
    print("rows: blue yaw, blue pitch, red yaw, red pitch")


if __name__ == "__main__":
    main()
