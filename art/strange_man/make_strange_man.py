"""Art pass C: the Strange Man (brief: CLAUDE.md §Art pass C, Sean 2026-11-20).

Usage (from the repo root):
  python art/strange_man/make_strange_man.py compare [x ...]  -> art/strange_man/compare.png (compare_pro.png for Pro picks)
  python art/strange_man/make_strange_man.py <x>              -> final assets for raw_<x>.png

Source: 96x160 candidates in art/strange_man/raw_<x>.png (front view, transparent):
round 1 PixelLab Pixen a/b/c (Sean picked C); round 2 PixelLab Pro with C as the
reference, Resurrect 64 palette -> c_pro1..4. Sean picked Pro 3 as the still (final:
`python art/strange_man/make_strange_man.py c_pro3`); Pro 2's face is kept for an expression.
Each is re-quantised to Resurrect 64 (nearest OKLab colour, binary alpha).

Outputs (final):
  assets/strange_man/full_body.png   96x160, feet on the bottom rows of the figure
  assets/strange_man/light_pool.png  oval pool of light he stands on (game px)
  art/strange_man/mock_intro.png     1080x1920 intro mock (forest barely visible, pool,
                                     dialogue box) for Sean's OK on the still
"""
import os
import sys
import time

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "palette"))
sys.path.insert(0, os.path.join(HERE, "..", "ui"))
from resurrect64 import hexc, quantize  # noqa: E402
import make_ui_mocks as mocks  # noqa: E402

OUT_DIR = "assets/strange_man"
POOL_RINGS = ("2e222f", "3e3546", "625565")  # outer -> inner, same as the approved mock
POOL_CX, POOL_Y = 135, 300  # pool centre in game px; his feet stand on it
# Hand fixes after quantising: copy a box (src box -> dest top-left).
# c_pro3 = the approved still (Sean, 2026-11-20): no Goob patch; the coat block
# above it covers the patch.
EDITS = {"c_pro3": [((64, 54, 72, 62), (64, 68))]}


def save(img, path):
    """Save, retrying while Windows holds the file (an open viewer); if it stays locked,
    write <name>_new.png next to it instead."""
    for _ in range(6):
        try:
            img.save(path)
            return path
        except OSError:
            time.sleep(0.5)
    alt = path[:-4] + "_new.png"
    img.save(alt)
    return alt


def figure(pick):
    im = quantize(Image.open(os.path.join(HERE, f"raw_{pick}.png")))
    for (x0, y0, x1, y1), (dx, dy) in EDITS.get(pick, ()):
        im.paste(im.crop((x0, y0, x1, y1)), (dx, dy))
    return im


def light_pool():
    w, h = 141, 37
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, c in enumerate(POOL_RINGS):
        rx, ry = 70 - i * 16, 18 - i * 4
        d.ellipse((70 - rx, 18 - ry, 70 + rx, 18 + ry), fill=hexc(c))
    return im


def scene(fig, text="This is a land of Goobs."):
    s = mocks.Screen("forest")
    s.bg.alpha_composite(Image.new("RGBA", s.bg.size, (0, 0, 0, 225)))
    s.put(light_pool(), POOL_CX - 70, POOL_Y - 18)
    feet = fig.getbbox()[3]
    s.put(fig, POOL_CX - fig.width // 2, POOL_Y + 4 - feet)
    s.button("Skip", mocks.GW - 6 - 64, 10, 64)
    s.panel("dialogue", 6, 340, mocks.GW - 12, 96)
    s.text(text, 20, 356, mocks.kit.WHITE)
    s.put(mocks.UI["dialogue_arrow"], mocks.GW - 6 - 22, 340 + 96 - 18)
    return s


def render(s):
    out = mocks.apply_vignette(s.bg.copy())
    out.alpha_composite(s.px.resize((mocks.GW * mocks.S, mocks.GH * mocks.S), Image.NEAREST))
    return out.convert("RGB")


def compare(picks=None):
    picks = picks or [p for p in "abc" if os.path.exists(os.path.join(HERE, f"raw_{p}.png"))]
    crops = []
    for p in picks:
        s = scene(figure(p), f"Candidate {p.upper().replace('_PRO', ' Pro ')}")
        crops.append(render(s).crop((0, 440, 1080, 1760)))
    sheet = Image.new("RGB", (1080 * len(crops), 1320))
    for i, c in enumerate(crops):
        sheet.paste(c, (1080 * i, 0))
    sheet = sheet.resize((sheet.width // 2, sheet.height // 2), Image.NEAREST)
    name = "compare_pro.png" if any("_pro" in p for p in picks) else "compare.png"
    print("wrote", save(sheet, os.path.join(HERE, name)))


def final(pick):
    os.makedirs(OUT_DIR, exist_ok=True)
    fig = figure(pick)
    fig.save(os.path.join(OUT_DIR, "full_body.png"))
    light_pool().save(os.path.join(OUT_DIR, "light_pool.png"))
    print("wrote", OUT_DIR, "and", save(render(scene(fig)), os.path.join(HERE, "mock_intro.png")))


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "compare"
    compare(sys.argv[2:]) if arg == "compare" else final(arg)
