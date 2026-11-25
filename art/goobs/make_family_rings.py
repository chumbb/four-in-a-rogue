"""M6f: family rings, special tints and ongoing-effect sparkles (options for Sean).

Usage: python art/goobs/make_family_rings.py

Specials get a darker tint (legendary = Uniquely powerful, darker still) and a
ring per effect family that repaints the Goob's rim band (the 2-3 px band just
inside the dark outline: it stays visible through the 28 px board hole).
Goobs with an ongoing effect on the board sparkle: calm for passives, menacing
for armed (Spiteful / Smouldering). Sean, 2026-11-24.

Outputs (art/goobs/rings/):
  mock_rings.png      ring options A / B / C per family, on the board, blue + red
  mock_tints.png      tint levels for special and legendary, on the board
  mock_sparkles.gif   sparkle options, passive P1 / P2 and armed A1 / A2
  ring_<family>_<option>.png   32x32 ring overlays (transparent elsewhere)
"""
import math
import os
import random
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from make_type_sheets import BG, DIM, INK, TEAM, RAMP, rgb, rim_pixels, text, up  # noqa: E402

OUT = os.path.join(HERE, "rings")
S = 4  # board scale at 1080 wide
CX, CY = 15.5, 16.0
LIGHT_ANGLE = -3 * math.pi / 4  # light from the top left, like the baked Goobs

FAMILIES = ["move", "destroy", "discard", "draw", "tech"]
LABEL = {"move": "Move", "destroy": "Destroy", "discard": "Discard", "draw": "Draw", "tech": "Tech"}
# Family band colours (Resurrect 64), dark -> mid -> light.
COLOUR = {
    "move": ("0b5e65", "0eaf9b", "30e1b9"),     # teal
    "destroy": ("2e222f", "3e3546", "625565"),  # charcoal
    "discard": ("45293f", "905ea9", "a884f3"),  # purple
    "draw": ("165a4c", "1ebc73", "91db69"),     # green
    "tech": ("625565", "9babb2", "c7dcd0"),     # steel
}
OPTIONS = {
    "A": "A: family colour band",
    "B": "B: thick band (3 px) + motif",
    "C": "C: colour band + motif",
}
# Tint levels (multiply on every pixel except pure white, i.e. eye shines).
TINTS = {"plain": 1.0, "special 85%": 0.85, "special 75%": 0.75, "legendary 65%": 0.65, "legendary 55%": 0.55}


def still(team):
    return Image.open(os.path.join(ROOT, "assets", "goobs", "vanilla", team + "_yaw", "frame_00.png")).convert("RGBA")


def band(team, thick=False):
    """Rim band pixels as {(x, y): (angle, radius)}; `thick` adds one px inward."""
    out = {(x, y): (a, math.hypot(x - CX, y - CY)) for x, y, a, _o in rim_pixels(still(team), team)}
    if thick:
        # Everything inside the dark outline from radius 9.5 out: a solid 3-4 px band.
        im = still(team)
        px = im.load()
        ink = rgb(TEAM[team]["K"])
        for y in range(32):
            for x in range(32):
                d = math.hypot(x - CX, y - CY)
                if (x, y) not in out and px[x, y][3] and px[x, y] != ink and d >= 9.5:
                    out[(x, y)] = (math.atan2(y - CY, x - CX), d)
    return out


def shade(angle):
    """-1 (shadow) .. 1 (lit) for a band pixel at `angle`."""
    return math.cos(angle - LIGHT_ANGLE)


def arc_px(angle):
    """Clockwise arc length (px along the rim at r 12) from the top."""
    return ((angle + math.pi / 2) % (2 * math.pi)) * 12.0


# Motifs: which band pixels are "marked" (drawn light / a symbol), per family.
def motif(family, angle, r, r_in, r_out):
    s = arc_px(angle)
    depth = (r - r_in) / max(0.01, r_out - r_in)  # 0 inner edge .. 1 outer
    if family == "move":
        # Chevrons pointing clockwise (the way it pushes).
        k = s % (75.4 / 8)
        return abs(k - 3.0 - abs(depth - 0.5) * 3.0) < 0.9
    if family == "destroy":
        # Teeth biting inward: wide at the outer edge, a point at the inner.
        k = (s % (75.4 / 8)) / (75.4 / 8)  # 8 teeth
        return abs(k - 0.5) < 0.12 + 0.3 * depth
    if family == "discard":
        # Broken band: 6 pieces with gaps (gap = left as body colour).
        return (s % (75.4 / 6)) > 3.0
    if family == "draw":
        # 8 beads.
        return (s % (75.4 / 8)) < 2.6 and depth > 0.15
    if family == "tech":
        # 4 bolts on a plain band.
        return (s % (75.4 / 4)) < 3.2
    return False


def ring(family, option, team):
    """32x32 overlay: band pixels only, transparent elsewhere.
    A = thin colour band, B = thick band + motif, C = thin band + motif."""
    px_band = band(team, thick=(option == "B"))
    radii = [r for _a, r in px_band.values()]
    r_in, r_out = min(radii), max(radii)
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    px = im.load()
    t = TEAM[team]
    dark, mid, light = (rgb(h) for h in COLOUR[family])
    for (x, y), (a, r) in px_band.items():
        sh = shade(a)
        if option == "A":
            px[x, y] = light if sh > 0.55 else dark if sh < -0.55 else mid
            continue
        mark = motif(family, a, r, r_in, r_out)
        if family == "discard" and not mark:
            continue  # the gap: the Goob's own rim shows
        if mark and family == "destroy":
            c = rgb("f57d4a") if sh > -0.2 else rgb("ea4f36")  # ember teeth
        elif mark:
            c = rgb("ffffff") if sh > 0.3 else light
            if family == "discard":
                c = light if sh > 0.0 else mid
        else:
            c = mid if sh > 0.0 else dark
        px[x, y] = c
    return im


def tinted(im, k):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            c = px[x, y]
            if c[3] and c[:3] != (255, 255, 255):
                px[x, y] = (int(c[0] * k), int(c[1] * k), int(c[2] * k), c[3])
    return out


def outline(im):
    """The runtime outline shader: one px of dark ink around opaque pixels."""
    ink = (20, 13, 26, 255)
    big = Image.new("RGBA", (im.width + 2, im.height + 2), (0, 0, 0, 0))
    big.alpha_composite(im, (1, 1))
    src = big.load()
    out = big.copy()
    px = out.load()
    for y in range(big.height):
        for x in range(big.width):
            if src[x, y][3] >= 128:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < big.width and 0 <= ny < big.height and src[nx, ny][3] >= 128:
                    px[x, y] = ink
                    break
    return out


def goob(team, family=None, option=None, k=1.0):
    im = tinted(still(team), k)
    if family:
        im.alpha_composite(ring(family, option, team))
    return im


def board_strip(goobs, rows=1, extra_top=0):
    """A strip of board cells (bottom row) holding `goobs` (32x32 each)."""
    back = Image.open(os.path.join(ROOT, "assets", "board", "board_back.png")).convert("RGBA")
    front = Image.open(os.path.join(ROOT, "assets", "board", "board_front.png")).convert("RGBA")
    bg = Image.open(os.path.join(ROOT, "assets", "backgrounds", "forest.png")).convert("RGBA")
    W, H = back.size
    canvas = bg.resize((W, int(bg.height * W / bg.width)), Image.NEAREST).crop((0, 200, W, 200 + H))
    canvas.alpha_composite(back)
    for i, g in enumerate(goobs):
        o = outline(g)
        canvas.alpha_composite(o, (8 + 32 * i - 1, 8 + 32 * 5 - 1 - 1))
    canvas.alpha_composite(front)
    n = len(goobs)
    return canvas.crop((0, 8 + 32 * (6 - rows) - 6 - extra_top, 8 + 32 * n + 2, H - 8))


def mock_rings():
    cols = list(OPTIONS)
    strip_w = (16 + 32 * 4) * S
    strip_h = (32 + 6 + 8) * S
    label_w = 150
    sheet = Image.new("RGBA", (label_w + len(cols) * (strip_w + 24) + 24, 90 + len(FAMILIES) * (strip_h + 50)), BG)
    text(sheet, (24, 14), "M6f family rings: plain Goob, then the ring on blue + red specials (85% tint)", 2)
    for j, o in enumerate(cols):
        text(sheet, (label_w + j * (strip_w + 24), 54), OPTIONS[o], 2, INK)
    for i, fam in enumerate(FAMILIES):
        y = 90 + i * (strip_h + 50)
        text(sheet, (24, y + strip_h // 2 - 16), LABEL[fam], 3)
        for j, o in enumerate(cols):
            goobs = [goob("blue"), goob("blue", fam, o, 0.85), goob("red", fam, o, 0.85), goob("red")]
            strip = up(board_strip(goobs), S)
            sheet.alpha_composite(strip, (label_w + j * (strip_w + 24), y))
            for team in ("blue", "red"):
                ring(fam, o, team).save(os.path.join(OUT, "ring_%s_%s_%s.png" % (fam, o, team)))
    sheet.save(os.path.join(OUT, "mock_rings.png"))


def mock_tints():
    names = list(TINTS)
    goobs = []
    for n in names:
        goobs.append(goob("blue", "move" if n != "plain" else None, "C", TINTS[n]))
    reds = [goob("red", "move" if n != "plain" else None, "C", TINTS[n]) for n in names]
    strip_b = up(board_strip(goobs), S)
    strip_r = up(board_strip(reds), S)
    plain_b = up(board_strip([tinted(still("blue"), TINTS[n]) for n in names]), S)
    plain_r = up(board_strip([tinted(still("red"), TINTS[n]) for n in names]), S)
    w = strip_b.width + 260
    sheet = Image.new("RGBA", (w, 110 + 4 * (strip_b.height + 20)), BG)
    text(sheet, (24, 14), "M6f tints (eye shines stay white). Rows: no ring, Move ring C", 2)
    for i, n in enumerate(names):
        text(sheet, (236 + 8 * S + i * 32 * S, 60), n.replace("special ", "spc ").replace("legendary ", "leg "), 2, INK if i else DIM)
    for r, (lab, st) in enumerate((("blue", plain_b), ("red", plain_r), ("blue+ring", strip_b), ("red+ring", strip_r))):
        y = 100 + r * (st.height + 20)
        text(sheet, (24, y + st.height // 2 - 16), lab, 2)
        sheet.alpha_composite(st, (236, y))
    sheet.save(os.path.join(OUT, "mock_tints.png"))


# ---------------------------------------------------------------- sparkles
FPS = 12
SEC = 3.0
PASSIVE = [rgb("fbff86"), rgb("f9c22b"), rgb("fbb954")]
EMBER = [rgb("f9c22b"), rgb("fb6b1d"), rgb("e83b3b"), rgb("b33831"), rgb("6e2727")]


def sparkle_frames(kind, n_frames, cx, cy, seed):
    """Per frame, a list of (x, y, colour) pixels for one Goob centred at (cx, cy)."""
    rnd = random.Random(seed)
    frames = [[] for _ in range(n_frames)]
    dt = 1.0 / FPS

    def put(f, x, y, c):
        if 0 <= f < n_frames:
            frames[f].append((int(round(x)), int(round(y)), c))

    if kind == "P1":  # gold motes drifting up, then twinkling out
        t = 0.0
        while t < SEC + 1.5:
            x0, y0 = cx + rnd.uniform(-10, 10), cy + rnd.uniform(-2, 9)
            life = 1.4
            for k in range(int(life * FPS)):
                f = int((t + k * dt) * FPS) % n_frames
                u = k / (life * FPS)
                if u > 0.75 and k % 2:
                    continue  # twinkle as it fades
                put(f, x0 + math.sin(u * 5 + x0) * 1.2, y0 - 12 * u, PASSIVE[min(2, int(u * 3))])
            t += 0.38
    elif kind == "P2":  # twinkling stars at the rim
        t = 0.0
        while t < SEC:
            a = rnd.uniform(0, 2 * math.pi)
            x0, y0 = cx + 13 * math.cos(a), cy + 13 * math.sin(a)
            shape = ["dot", "plus", "big", "plus", "dot"]
            for k, sh in enumerate(shape):
                f = int((t + k * dt) * FPS) % n_frames
                c = rgb("ffffff") if sh == "big" else PASSIVE[0]
                put(f, x0, y0, c)
                if sh in ("plus", "big"):
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        put(f, x0 + dx, y0 + dy, PASSIVE[1])
                if sh == "big":
                    for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
                        put(f, x0 + dx, y0 + dy, PASSIVE[2])
            t += 0.5
    elif kind == "A1":  # embers rising fast, flickering
        t = 0.0
        while t < SEC + 1.0:
            x0, y0 = cx + rnd.uniform(-11, 11), cy + rnd.uniform(4, 12)
            life = rnd.uniform(0.45, 0.7)
            drift = rnd.uniform(-4, 4)
            for k in range(int(life * FPS)):
                f = int((t + k * dt) * FPS) % n_frames
                u = k / (life * FPS)
                if rnd.random() < 0.2:
                    continue  # flicker
                put(f, x0 + drift * u, y0 - 22 * u, EMBER[min(4, int(u * 5))])
            t += 0.13
    elif kind == "A2":  # crackling sparks racing round the rim
        sparks = [(rnd.uniform(0, 2 * math.pi), rnd.choice((-1, 1))) for _ in range(3)]
        for f in range(n_frames):
            tt = f * dt
            for a0, d in sparks:
                for trail in range(3):
                    a = a0 + d * (tt - trail * 0.03) * 2 * math.pi / SEC * 3
                    if trail == 0 and rnd.random() < 0.15:
                        continue
                    put(f, cx + 14 * math.cos(a), cy + 14 * math.sin(a), EMBER[trail * 2] if trail else EMBER[0])
            if rnd.random() < 0.25:  # a stray crackle
                a = rnd.uniform(0, 2 * math.pi)
                put(f, cx + 15 * math.cos(a), cy + 15 * math.sin(a), rgb("ffffff"))
    return frames


def mock_sparkles():
    kinds = ["P1", "P2", "A1", "A2"]
    titles = ["P1 motes", "P2 stars", "A1 embers", "A2 crackle"]
    n_frames = int(SEC * FPS)
    rows_up = 14  # room above the bottom row for rising particles
    base = board_strip([goob("blue", "move", "C", 0.85), goob("red", "destroy", "C", 0.85),
                        goob("blue", "destroy", "C", 0.85), goob("red", "move", "C", 0.85)], extra_top=rows_up)
    gy = base.height - 8 - 32 + 16 - 1  # Goob centre y within the strip
    per = [sparkle_frames(k, n_frames, 8 + 32 * i + 15.5, gy, 7 + i) for i, k in enumerate(kinds)]
    head = 48
    out = []
    for f in range(n_frames):
        fr = base.copy()
        px = fr.load()
        for i in range(4):
            for x, y, c in per[i][f]:
                if 0 <= x < fr.width and 0 <= y < fr.height:
                    px[x, y] = c
        big = up(fr, S)
        canvas = Image.new("RGBA", (big.width, big.height + head), BG)
        for i, t in enumerate(titles):
            text(canvas, (8 * S + i * 32 * S, 10), t, 2)
        canvas.alpha_composite(big, (0, head))
        out.append(canvas.convert("RGB"))
    # Exact palette (median cut drops the rare sparkle colours).
    base_pal = out[0].quantize(colors=240, method=Image.MEDIANCUT, dither=Image.NONE).getpalette()[:240 * 3]
    colours = [tuple(base_pal[i:i + 3]) for i in range(0, len(base_pal), 3)]
    colours += [c[:3] for c in PASSIVE + EMBER + [rgb("ffffff")] if c[:3] not in colours]
    pal = Image.new("P", (1, 1))
    pal.putpalette([v for c in colours for v in c] + [0] * 3 * (256 - len(colours)))
    out = [f.quantize(palette=pal, dither=Image.NONE) for f in out]
    out[0].save(os.path.join(OUT, "mock_sparkles.gif"), save_all=True, append_images=out[1:],
                duration=int(1000 / FPS), loop=0, disposal=1)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    mock_rings()
    mock_tints()
    mock_sparkles()
    print("wrote", OUT)
