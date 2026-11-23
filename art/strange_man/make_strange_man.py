"""Art pass C: the Strange Man (brief: CLAUDE.md §Art pass C, Sean 2026-11-20).

Usage (from the repo root):
  python art/strange_man/make_strange_man.py compare [x ...]  -> art/strange_man/compare.png (compare_pro.png for Pro picks)
  python art/strange_man/make_strange_man.py <x>              -> final assets for raw_<x>.png

Source: 96x160 candidates in art/strange_man/raw_<x>.png (front view, transparent):
round 1 PixelLab Pixen a/b/c (Sean picked C); round 2 PixelLab Pro with C as the
reference, Resurrect 64 palette -> c_pro1..4. Sean picked Pro 3 as the still (final:
`python art/strange_man/make_strange_man.py c_pro3`); Pro 2's face is kept for an expression.
Each is re-quantised to Resurrect 64 (nearest OKLab colour, binary alpha).

Bust portrait (HUD; drawn separately, Sean 2026-11-20): PixelLab create_portrait_character
(character -> portrait, low top-down, 64 px, Resurrect 64) from the still -> bust/raw_idle.png;
the other expressions are PixelLab edit_image text edits of it -> bust/raw_<expression>.png
(well played = bust/raw_well_played2.png, the serious slight bow; Sean 2026-11-20).

Intro Goobs (painted, in his world; Sean 2026-11-20): the blue one is a PixelLab edit_image
of a create_image_pro 48x48 Goob (his still as the style reference), stood on its edge ->
goobs/raw_blue_edit.png. The red one is that blue sprite recoloured and tipped over in code
(lying flat at an angle, face up, gazing at the sky; Sean 2026-11-20) ->
goobs/make_red_tipped.py -> goobs/raw_red_tipped.png.

Outputs (final):
  assets/strange_man/full_body.png          96x160, feet on the bottom rows of the figure
  assets/strange_man/light_pool.png         oval pool of light he stands on (game px)
  assets/strange_man/portrait_<expr>.png    64x64 bust: idle, thinking, happy, angry,
                                            surprised, celebrating, well_played, waiting, greeting
  assets/strange_man/portrait_crack.png     strip of 3 64x64 frames (well played, cracking)
  assets/strange_man/portrait_explode.png   strip of 6 128x128 frames (shards fly apart;
                                            the bust sits centred in each frame)
  assets/strange_man/intro_goob_blue.png    48x48, upright; intro_goob_red.png, flat face up
  art/strange_man/mock_intro.png            1080x1920 intro mock (forest barely visible,
                                            pool, his two Goobs, dialogue box)
  art/strange_man/sheet_portraits.png       review sheet: expressions + crack + explode
"""
import math
import os
import random
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
EXPRESSIONS = {  # asset name -> bust/raw_<source>.png
    "idle": "idle", "thinking": "thinking", "happy": "happy", "angry": "angry",
    "surprised": "surprised", "celebrating": "celebrating", "well_played": "well_played2",
    # Waiting on the player (M6c playtest, Sean 2026-11-22): edit_image of idle, options
    # bust/raw_waiting_a|b|c.png (compare_waiting.png); Sean picked B "with a raised
    # eyebrow" -> hand-pixelled bust/make_waiting_brow.py b1|b2|b3; Sean picked b2.
    "waiting": "waiting_b2",
    # Game-start greeting (M6c playtest, Sean 2026-11-22: "new wave face"): edit_image of
    # idle, options bust/raw_greeting_a|b|c.png (compare_greeting.png); a = open-hand wave.
    "greeting": "greeting_a",
}
GOOB_X = {"blue": 72, "red": 198}  # centre x in game px, either side of him on the pool
CRACK_DARK, CRACK_LIT = hexc("2e222f"), hexc("c7dcd0")


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


def bust(name):
    return quantize(Image.open(os.path.join(HERE, "bust", f"raw_{EXPRESSIONS[name]}.png")))


RED_SRC = "raw_red_flat_b.png"  # Sean 2026-11-20: flat B (goobs/make_red_flat.py)


def intro_goob(colour):
    src = {"blue": "raw_blue_edit.png", "red": RED_SRC}[colour]
    return quantize(Image.open(os.path.join(HERE, "goobs", src)))


def _crack_paths(rng, n):
    """Jagged cracks from an impact point a little above the bust's centre."""
    paths = []
    for i in range(n):
        x, y = 32 + rng.randint(-2, 2), 26 + rng.randint(-2, 2)
        a = (i / n) * 2 * math.pi + rng.uniform(-0.4, 0.4)
        pts = [(x, y)]
        for _ in range(rng.randint(4, 7)):
            a += rng.uniform(-0.6, 0.6)
            step = rng.uniform(3, 6)
            x, y = x + math.cos(a) * step, y + math.sin(a) * step
            pts.append((x, y))
        paths.append(pts)
    return paths


def crack_frames():
    """3 frames: a few short cracks, more and longer, then cracked all over."""
    base = bust("well_played")
    alpha = base.getchannel("A")
    clear = Image.new("RGBA", base.size, (0, 0, 0, 0))
    paths = _crack_paths(random.Random(7), 7)
    frames = []
    for count, frac in ((3, 0.45), (5, 0.75), (7, 1.0)):
        im = base.copy()
        d = ImageDraw.Draw(im)
        for pts in paths[:count]:
            k = max(2, round(len(pts) * frac))
            seg = [(round(x), round(y)) for x, y in pts[:k]]
            d.line([(x + 1, y + 1) for x, y in seg], fill=CRACK_LIT, width=1)
            d.line(seg, fill=CRACK_DARK, width=1)
        frames.append(Image.composite(im, clear, alpha))  # cracks never draw outside him
    return frames


def explode_frames(n=6, size=128):
    """Shards (Voronoi cells of the fully cracked bust) fly out from the impact point,
    fall and drop out one by one; 128x128 frames with the bust centred."""
    src = crack_frames()[-1]
    rng = random.Random(11)
    seeds = [(rng.randint(4, 60), rng.randint(4, 60)) for _ in range(16)]
    owner = {}
    for y in range(64):
        for x in range(64):
            if src.getpixel((x, y))[3]:
                owner[(x, y)] = min(range(len(seeds)),
                                    key=lambda i: (seeds[i][0] - x) ** 2 + (seeds[i][1] - y) ** 2)
    off = (size - 64) // 2
    vel = []
    for sx, sy in seeds:
        a = math.atan2(sy - 26, sx - 32) + rng.uniform(-0.3, 0.3)
        sp = rng.uniform(5, 9)
        vel.append((math.cos(a) * sp, math.sin(a) * sp - 3, rng.randint(2, n)))  # vx, vy, life
    frames = []
    for t in range(n):
        im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        for (x, y), i in owner.items():
            vx, vy, life = vel[i]
            if t >= life:
                continue
            nx = round(x + off + vx * t)
            ny = round(y + off + vy * t + 0.8 * t * t)
            if 0 <= nx < size and 0 <= ny < size:
                im.putpixel((nx, ny), src.getpixel((x, y)))
        frames.append(im)
    return frames


def strip(frames):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * w, 0))
    return out


def scene(fig, text="This is a land of Goobs.", goobs=False):
    s = mocks.Screen("forest")
    s.bg.alpha_composite(Image.new("RGBA", s.bg.size, (0, 0, 0, 225)))
    s.put(light_pool(), POOL_CX - 70, POOL_Y - 18)
    feet = fig.getbbox()[3]
    s.put(fig, POOL_CX - fig.width // 2, POOL_Y + 4 - feet)
    if goobs:
        for colour, cx in GOOB_X.items():
            g = intro_goob(colour)
            x0, _, x1, y1 = g.getbbox()
            s.put(g, cx - (x0 + x1) // 2, POOL_Y + 6 - y1)
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
    for name in EXPRESSIONS:
        bust(name).save(os.path.join(OUT_DIR, f"portrait_{name}.png"))
    cracks, boom = crack_frames(), explode_frames()
    strip(cracks).save(os.path.join(OUT_DIR, "portrait_crack.png"))
    strip(boom).save(os.path.join(OUT_DIR, "portrait_explode.png"))
    for colour in GOOB_X:
        intro_goob(colour).save(os.path.join(OUT_DIR, f"intro_goob_{colour}.png"))
    print("wrote", save(render(scene(fig, goobs=True)), os.path.join(HERE, "mock_intro.png")))
    # Review sheet at 4x on dark ink: 7 expressions, then crack frames, then explode frames.
    row1 = strip([bust(n) for n in EXPRESSIONS])
    sheet = Image.new("RGBA", (max(row1.width, 6 * 128), 64 + 8 + 64 + 8 + 128), mocks.kit.INK0)
    sheet.alpha_composite(row1, (0, 0))
    sheet.alpha_composite(strip(cracks), (0, 72))
    sheet.alpha_composite(strip(boom), (0, 144))
    sheet = sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)
    print("wrote", OUT_DIR, "and", save(sheet, os.path.join(HERE, "sheet_portraits.png")))


def compare_red(fig_pick="c_pro3", opts=("flat_a", "flat_b")):
    """Review sheet: the intro scene once per red Goob option, cropped round the pool."""
    global RED_SRC
    crops = []
    for o in opts:
        RED_SRC = f"raw_red_{o}.png"
        crops.append(render(scene(figure(fig_pick), f"Option {o}", goobs=True))
                     .crop((0, 600, 1080, 1440)))
    sheet = Image.new("RGB", (1080 * len(crops), 840))
    for i, c in enumerate(crops):
        sheet.paste(c, (1080 * i, 0))
    print("wrote", save(sheet, os.path.join(HERE, "compare_red.png")))


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "compare"
    if arg == "compare_red":
        compare_red()
    else:
        compare(sys.argv[2:]) if arg == "compare" else final(arg)
