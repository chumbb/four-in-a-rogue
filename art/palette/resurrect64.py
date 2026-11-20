"""Resurrect 64, the master palette for all pixel art (Sean, 2026-11-13).

Palette by Kerrie Lake (https://lospec.com/palette-list/resurrect-64).

    from resurrect64 import PALETTE, hexc, quantize
    hexc("e6904e")        -> (230, 144, 78, 255)
    quantize(img)         -> copy of an RGBA image with every opaque pixel moved to
                             the nearest palette colour (OKLab distance) and alpha
                             made binary (>= 128 opaque, else fully transparent).
    quantize(img, ramps)  -> same, but pixels inside a Ramp's hue range are banded by
                             OKLab lightness onto that ramp's colours (keeps outline /
                             shadow / base / highlight apart where nearest would merge them).

Run directly to write resurrect64.gpl (Aseprite / GIMP palette) next to this file.
"""
import colorsys
import os
from dataclasses import dataclass

HEX = (
    "2e222f 3e3546 625565 966c6c ab947a 694f62 7f708a 9babb2 c7dcd0 ffffff "
    "6e2727 b33831 ea4f36 f57d4a ae2334 e83b3b fb6b1d f79617 f9c22b 7a3045 "
    "9e4539 cd683d e6904e fbb954 4c3e24 676633 a2a947 d5e04b fbff86 165a4c "
    "239063 1ebc73 91db69 cddf6c 313638 374e4a 547e64 92a984 b2ba90 0b5e65 "
    "0b8a8f 0eaf9b 30e1b9 8ff8e2 323353 484a77 4d65b4 4d9be6 8fd3ff 45293f "
    "6b3e75 905ea9 a884f3 eaaded 753c54 a24b6f cf657f ed8099 831c5d c32454 "
    "f04f78 f68181 fca790 fdcbb0"
).split()


def hexc(h, a=255):
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a


PALETTE = [hexc(h)[:3] for h in HEX]
assert len(PALETTE) == 64


def _lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def oklab(rgb):
    r, g, b = (_lin(v) for v in rgb[:3])
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


_LAB = [oklab(c) for c in PALETTE]
_cache = {}


def nearest(rgb):
    key = tuple(rgb[:3])
    if key not in _cache:
        L = oklab(key)
        best = min(range(64), key=lambda i: sum((L[j] - _LAB[i][j]) ** 2 for j in range(3)))
        _cache[key] = PALETTE[best]
    return _cache[key]


@dataclass
class Ramp:
    """Hue range in degrees (hue_lo > hue_hi wraps through 0), minimum HSV saturation,
    OKLab lightness cut points (ascending) and len(cuts) + 1 palette hexes, dark -> light."""
    hue_lo: float
    hue_hi: float
    min_sat: float
    cuts: tuple
    colours: tuple

    def match(self, rgb):
        h, s, _ = colorsys.rgb_to_hsv(*(v / 255.0 for v in rgb))
        h *= 360.0
        if s < self.min_sat:
            return None
        inside = self.hue_lo <= h <= self.hue_hi if self.hue_lo <= self.hue_hi else (h >= self.hue_lo or h <= self.hue_hi)
        if not inside:
            return None
        L = oklab(rgb)[0]
        i = sum(1 for c in self.cuts if L >= c)
        return hexc(self.colours[i])[:3]


# Vanilla Goob team ramps (Art pass A, 2026-11-19): outline, deep shadow, shadow, base, highlight.
GOOB_CUTS = (0.30, 0.41, 0.49, 0.66)
BLUE_GOOB = (
    Ramp(195, 235, 0.3, GOOB_CUTS, ("323353", "484a77", "4d65b4", "4d9be6", "8fd3ff")),
    Ramp(236, 275, 0.3, (), ("905ea9",)),  # blush
)
RED_GOOB = (
    Ramp(335, 15, 0.3, GOOB_CUTS, ("45293f", "6e2727", "ae2334", "e83b3b", "f68181")),
)


def quantize(img, ramps=()):
    out = img.convert("RGBA").copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
                continue
            mapped = None
            for ramp in ramps:
                mapped = ramp.match((r, g, b))
                if mapped:
                    break
            px[x, y] = (mapped or nearest((r, g, b))) + (255,)
    return out


def write_gpl(path):
    with open(path, "w", encoding="utf-8") as f:
        f.write("GIMP Palette\nName: Resurrect 64\nColumns: 8\n#\n")
        for (r, g, b), h in zip(PALETTE, HEX):
            f.write("%3d %3d %3d\t%s\n" % (r, g, b, h))


if __name__ == "__main__":
    write_gpl(os.path.join(os.path.dirname(os.path.abspath(__file__)), "resurrect64.gpl"))
    print("wrote resurrect64.gpl")
