"""Art pass B: pixel UI kit, logo and fuse (Sean, 2026-11-20 roadmap; GDD §Art direction UI).

Usage: python art/ui/make_ui_kit.py   (from the repo root)

One look across biomes: dark-ink panels with a warm honey accent, Resurrect 64 only,
drawn on the board's game-pixel unit (shown at the same whole-number scale as the board,
4x at 1080 wide). Light from the top left, like the board.

Outputs in assets/ui/ (9-slice margins = the `MARGINS` table below, in game px):
  panel.png            HUD panels, pause menu, options, inspect body
  window.png           pause / options / inspect window (panel + gold corner studs)
  dialogue.png         Strange Man dialogue box (chunky 2 px gold border)
  dialogue_arrow.png   blinking "next page" triangle
  button_normal.png    honey button with a 2 px lip; _pressed sinks 2 px; _disabled greyed
  toast.png            toast pill
  banner.png           end-overlay frame (double border, gold studs)
  slider_track.png     slider groove; slider_fill.png the filled part; slider_knob.png
  toggle_on.png / toggle_off.png
  segment_normal.png / segment_selected.png / segment_pressed.png  (Normal / Fast / Skip)
  icon_pause.png  icon_speaker.png  icon_speaker_muted.png
  logo.png             "Four in a Rogue" (blue + red Vanilla Goobs as the O's)
  fuse_rope.png        tileable rope (8 px wide) for the 24 px timer strip; fuse_burnt.png
  fuse_spark.png       4-frame strip of the burning end (11x11 frames)
Also art/ui/ui_kit_sheet4x.png: every piece at 4x for review.

The scrim colour and text colours live in scripts/ui/ui_theme.gd (no texture needed).
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "palette"))
from resurrect64 import hexc  # noqa: E402

OUT_DIR = "assets/ui"
SHEET = "art/ui/ui_kit_sheet4x.png"
FONT_PATH = "resources/fonts/monogram-extended.ttf"

CLEAR = (0, 0, 0, 0)
# Dark ink (panels) and warm honey accent (borders, buttons), all Resurrect 64.
INK0 = hexc("2e222f")   # outlines, deepest fill
INK1 = hexc("3e3546")   # panel fill
INK2 = hexc("625565")   # grooves' lit lip, disabled fill
INK3 = hexc("7f708a")   # disabled highlight
GOLD_HI = hexc("fbb954")
GOLD = hexc("e6904e")
GOLD_LO = hexc("cd683d")
GOLD_SH = hexc("9e4539")
CREAM = hexc("fdcbb0")  # body text, icons
WHITE = hexc("ffffff")
RED = hexc("e83b3b")
RED_LO = hexc("ae2334")

# 9-slice margins (left, top, right, bottom) in game px, mirrored in scripts/ui/ui_kit.gd.
MARGINS = {
    "panel": (4, 4, 4, 4),
    "window": (6, 6, 6, 6),
    "dialogue": (6, 6, 6, 6),
    "button_normal": (4, 4, 4, 6),
    "button_pressed": (4, 6, 4, 4),
    "button_disabled": (4, 4, 4, 6),
    "toast": (5, 5, 5, 5),
    "banner": (8, 8, 8, 8),
    "slider_track": (3, 3, 3, 3),
    "slider_fill": (3, 3, 3, 3),
    "segment_normal": (3, 3, 3, 5),
    "segment_selected": (3, 3, 3, 5),
    "segment_pressed": (3, 5, 3, 3),
}


# --- drawing helpers -------------------------------------------------------------

def rounded_mask(w, h, radius):
    """True where a pixel is inside a w x h rect with stepped pixel corners."""
    cut = {0: 0, 1: 1, 2: 2, 3: 3}[radius]
    steps = [[], [1], [2, 1], [3, 1, 1]][cut]

    def inside(x, y):
        for i, s in enumerate(steps):
            for yy, xx in ((y, x), (y, w - 1 - x), (h - 1 - y, x), (h - 1 - y, w - 1 - x)):
                if yy == i and xx < s:
                    return False
        return True
    return inside


def frame(w, h, rings, fill, radius=1):
    """A rounded rect: rings from the outside in, each a colour or (lit, shade) pair
    (lit = top/left, shade = bottom/right), then a flat fill."""
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    inside = rounded_mask(w, h, radius)
    n = len(rings)
    for y in range(h):
        for x in range(w):
            if not inside(x, y):
                continue
            d = min(x, y, w - 1 - x, h - 1 - y)
            # Pixels hugging a rounded corner belong to the outline ring.
            if radius and not inside(x - 1, y) or radius and not inside(x, y - 1) \
                    or radius and not inside(x + 1, y) or radius and not inside(x, y + 1):
                d = 0
            if d >= n:
                px[x, y] = fill
                continue
            ring = rings[d]
            if isinstance(ring[0], tuple):
                lit, shade = ring
                upper_left = x == d or y == d
                px[x, y] = lit if upper_left else shade
            else:
                px[x, y] = ring
    return img


def stud(img, cx, cy, colour=GOLD_HI, edge=INK0):
    """A 3x3 diamond stud centred on (cx, cy)."""
    px = img.load()
    for dx, dy in ((0, -2), (-1, -1), (1, -1), (-2, 0), (2, 0), (-1, 1), (1, 1), (0, 2)):
        px[cx + dx, cy + dy] = edge
    for dx, dy in ((0, -1), (-1, 0), (0, 0), (1, 0), (0, 1)):
        px[cx + dx, cy + dy] = colour
    px[cx - 1, cy] = WHITE if colour == GOLD_HI else colour


# --- 9-slice pieces --------------------------------------------------------------

def panel(w=12, h=12):
    return frame(w, h, [INK0, (GOLD_HI, GOLD_LO), INK0], INK1, radius=2)


def window(w=16, h=16):
    img = frame(w, h, [INK0, (GOLD_HI, GOLD_LO), GOLD_SH, INK0], INK1, radius=2)
    for cx, cy in ((2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)):
        stud(img, cx, cy)
    return img


def dialogue(w=16, h=16):
    img = frame(w, h, [INK0, (GOLD_HI, GOLD_SH), (GOLD, GOLD_LO), INK0, INK0], INK1, radius=2)
    for cx, cy in ((2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)):
        stud(img, cx, cy, GOLD_HI, INK0)
    return img


def dialogue_arrow():
    img = Image.new("RGBA", (9, 6), CLEAR)
    px = img.load()
    rows = ["#########", "#ooooooo#", ".#ooooo#.", "..#ooo#..", "...#o#...", "....#...."]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                px[x, y] = INK0
            elif ch == "o":
                px[x, y] = GOLD_HI if y < 2 else GOLD
    return img


def button(state, w=12, h=16):
    """Honey button; normal has a 2 px lip under it, pressed sinks onto the lip."""
    img = Image.new("RGBA", (w, h), CLEAR)
    if state == "pressed":
        body = frame(w, h - 2, [INK0, (GOLD, GOLD_LO)], GOLD_LO, radius=2)
        img.alpha_composite(body, (0, 2))
        return img
    fill, hi, lip = (GOLD, GOLD_HI, GOLD_SH) if state == "normal" else (INK2, INK3, INK1)
    base = frame(w, h, [INK0], lip, radius=2)
    img.alpha_composite(base)
    top = frame(w, h - 2, [INK0, (hi, fill)], fill, radius=2)
    img.alpha_composite(top)
    return img


def toast(w=14, h=12):
    return frame(w, h, [INK0, (GOLD, GOLD_LO), INK0], INK0, radius=3)


def banner(w=20, h=20):
    img = frame(w, h, [INK0, (GOLD_HI, GOLD_LO), INK0, INK1, (GOLD_LO, GOLD_SH), INK0], INK1, radius=3)
    for cx, cy in ((3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)):
        stud(img, cx, cy)
    return img


def slider_track(w=8, h=7):
    return frame(w, h, [INK0, (INK0, INK2)], INK0, radius=1)


def slider_fill(w=8, h=7):
    return frame(w, h, [INK0, (GOLD_HI, GOLD_LO)], GOLD, radius=1)


def slider_knob(pressed=False):
    """A honey coin knob, 11x13 (2 px rim below = thickness)."""
    w, h = 11, 13
    img = Image.new("RGBA", (w, h), CLEAR)
    edge = frame(w, h, [INK0], GOLD_SH, radius=3)
    img.alpha_composite(edge)
    face = frame(w, h - 2, [INK0, (WHITE if pressed else GOLD_HI, GOLD_LO)], GOLD, radius=3)
    img.alpha_composite(face)
    px = img.load()
    for y in (3, 4, 5, 6):  # grip line
        px[5, y] = GOLD_LO
    return img


def toggle(on):
    """30x14 switch: honey track + cream knob on the right when on, dark groove + grey knob left when off."""
    w, h = 30, 14
    img = Image.new("RGBA", (w, h), CLEAR)
    if on:
        track = frame(w, h, [INK0, (GOLD_LO, GOLD_HI)], GOLD, radius=3)
    else:
        track = frame(w, h, [INK0, (INK0, INK2)], INK0, radius=3)
    img.alpha_composite(track)
    kw, kh = 14, 12
    knob = Image.new("RGBA", (kw, kh), CLEAR)
    knob.alpha_composite(frame(kw, kh, [INK0], GOLD_SH if on else INK1, radius=2))
    knob.alpha_composite(frame(kw, kh - 2, [INK0, (WHITE, CREAM) if on else (INK3, INK2)],
                               CREAM if on else INK2, radius=2))
    img.alpha_composite(knob, (w - kw - 1 if on else 1, 1))
    return img


def segment(state, w=10, h=16):
    img = Image.new("RGBA", (w, h), CLEAR)
    if state == "pressed":
        img.alpha_composite(frame(w, h - 2, [INK0, (GOLD, GOLD_LO)], GOLD_LO, radius=1), (0, 2))
        return img
    if state == "selected":
        fill, hi, lip = GOLD, GOLD_HI, GOLD_SH
    else:
        fill, hi, lip = INK1, INK2, INK0
    img.alpha_composite(frame(w, h, [INK0], lip, radius=1))
    img.alpha_composite(frame(w, h - 2, [INK0, (hi, fill)], fill, radius=1))
    return img


# --- icons -----------------------------------------------------------------------

def bitmap(rows, colours):
    h, w = len(rows), len(rows[0])
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in colours:
                px[x, y] = colours[ch]
    return img


def icon_pause():
    return bitmap(["###..###"] * 9, {"#": INK0})


SPEAKER = [
    "....#......",
    "...##......",
    "####o......",
    "#ooo#......",
    "#ooo#......",
    "#ooo#......",
    "####o......",
    "...##......",
    "....#......",
]


def icon_speaker(muted):
    rows = [list(r) for r in SPEAKER]
    # Fill the cone.
    for y, x in ((2, 4), (6, 4)):
        rows[y][x] = "#"
    for y in range(1, 8):
        for x in range(1, 5):
            if rows[y][x] == "." and x <= 4 and abs(y - 4) <= x - 1:
                rows[y][x] = "o"
    if muted:
        for i in range(5):
            rows[2 + i][6 + i] = "x"
            rows[6 - i][6 + i] = "x"
    else:
        for y in (3, 4, 5):
            rows[y][6] = "o"
        for y in (1, 2, 3, 4, 5, 6, 7):
            rows[y][8] = "o" if 2 <= y <= 6 else "."
        rows[1][7] = rows[7][7] = "o"
    rows = ["".join(r) for r in rows]
    return bitmap(rows, {"#": CREAM, "o": CREAM, "x": RED})


# --- logo ------------------------------------------------------------------------

def glyph_mask(text, scale, bold=1):
    """Monogram text as a 0/255 mask, each font pixel scaled to `scale` game px, then
    grown by `bold` px so the strokes read as chunky logo letters. Letters are spaced
    one font pixel + 2 px apart."""
    font = ImageFont.truetype(FONT_PATH, 16)
    masks = []
    for ch in text:
        if ch == " ":
            masks.append(None)
            continue
        im = Image.new("L", (12, 16), 0)
        ImageDraw.Draw(im).text((0, 0), ch, font=font, fill=255)
        im = im.crop((0, 4, 12, 13)).point(lambda v: 255 if v > 127 else 0)
        bbox = im.getbbox()
        im = im.crop((bbox[0], 0, bbox[2], 9)).resize(((bbox[2] - bbox[0]) * scale, 9 * scale), Image.NEAREST)
        grown = Image.new("L", (im.width + 2 * bold, im.height + 2 * bold), 0)
        for dx in range(2 * bold + 1):
            for dy in range(2 * bold + 1):
                grown.paste(255, (dx, dy), im)
        masks.append(grown)
    space = 3 * scale
    w = sum(m.width if m else space for m in masks) + 2 * (len(masks) - 1)
    out = Image.new("L", (w, 9 * scale + 2 * bold), 0)
    x = 0
    for m in masks:
        if m:
            out.paste(m, (x, 0))
        x += (m.width if m else space) + 2
    return out


def shade_letters(mask, ramp, edge_hi=WHITE, edge_lo=GOLD_SH):
    """Fill a letter mask with a top-down ramp, lit top edges, shaded bottom edges,
    a dark outline and a 2 px drop shadow."""
    w, h = mask.width + 4, mask.height + 6
    out = Image.new("RGBA", (w, h), CLEAR)
    m = Image.new("L", (w, h), 0)
    m.paste(mask, (2, 1))
    mp = m.load()
    px = out.load()

    def on(x, y):
        return 0 <= x < w and 0 <= y < h and mp[x, y]
    for y in range(h):
        for x in range(w):
            if not on(x, y) and (on(x, y - 2) or on(x, y - 3) or on(x - 1, y - 3)):
                px[x, y] = hexc("45293f")
    for y in range(h):
        for x in range(w):
            if not on(x, y) and any(on(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                px[x, y] = INK0
    top, bottom = 1, mask.getbbox()[3] + 1
    for y in range(h):
        for x in range(w):
            if on(x, y):
                t = (y - top) / max(1, bottom - top)
                c = ramp[min(len(ramp) - 1, int(t * len(ramp)))]
                if not on(x, y - 1):
                    c = edge_hi
                elif not on(x, y + 1) or not on(x, y + 2):
                    c = edge_lo
                px[x, y] = c
    return out


def goob(colour):
    return Image.open(f"assets/goobs/vanilla/{colour}_yaw/frame_00.png").convert("RGBA")


def logo():
    """"FOUR" / "in a" / "ROGUE": the O's are a blue and a red Vanilla Goob."""
    ramp = [GOLD_HI, GOLD_HI, GOLD, GOLD, GOLD_LO]
    f_ = shade_letters(glyph_mask("F", 4), ramp)
    ur = shade_letters(glyph_mask("UR", 4), ramp)
    r_ = shade_letters(glyph_mask("R", 4), ramp)
    gue = shade_letters(glyph_mask("GUE", 4), ramp)
    small = shade_letters(glyph_mask("in a", 3, 0), [CREAM, CREAM, hexc("fca790")], WHITE, hexc("cf657f"))
    lh = f_.height
    lines = [[f_, goob("blue"), ur], [r_, goob("red"), gue]]
    gap = 1
    w = max(sum(p.width for p in ps) + gap * 2 for ps in lines) + 2
    h = 2 * lh + small.height - 6
    img = Image.new("RGBA", (w, h), CLEAR)

    def line(y, parts):
        x = (w - sum(p.width for p in parts) - gap * (len(parts) - 1)) // 2
        for p in parts:
            # Goobs (32 px) sit centred on the letters' cap height.
            img.alpha_composite(p, (x, y + (lh - 6 - p.height) // 2 + 1 if p.height == 32 else y))
            x += p.width + gap
    line(0, lines[0])
    img.alpha_composite(small, ((w - small.width) // 2, lh - 4))
    line(lh + small.height - 8, lines[1])
    return img.crop(img.getbbox())


# --- fuse ------------------------------------------------------------------------

ROPE_LIGHT = hexc("ab947a")
ROPE_DARK = hexc("966c6c")
ROPE_EDGE = hexc("4c3e24")


def fuse_rope():
    """8x5 twisted rope tile, centred on a 9 px (24 px at 720 base) strip by the code."""
    img = Image.new("RGBA", (8, 5), CLEAR)
    px = img.load()
    for x in range(8):
        px[x, 0] = ROPE_EDGE
        px[x, 4] = ROPE_EDGE
        for y in (1, 2, 3):
            # Diagonal twist bands every 4 px.
            px[x, y] = ROPE_LIGHT if (x + y) % 4 < 2 else ROPE_DARK
        px[x, 1] = hexc("c7dcd0") if (x + 1) % 4 == 0 else px[x, 1]
    return img


def fuse_burnt():
    img = Image.new("RGBA", (8, 5), CLEAR)
    px = img.load()
    for x in range(8):
        px[x, 3] = INK0
        if x % 3 == 0:
            px[x, 2] = INK2
    return img


def fuse_spark():
    """4 frames, 11x11 each: glowing ember with spitting sparks."""
    rng = random.Random(7)
    frames = []
    hot = [WHITE, hexc("fbff86"), hexc("f9c22b"), hexc("fb6b1d"), hexc("ea4f36")]
    for f in range(4):
        img = Image.new("RGBA", (11, 11), CLEAR)
        px = img.load()
        c = 5
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                px[c + dx, c + dy] = hot[3] if dx or dy else hot[0]
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            px[c + dx, c + dy] = hot[1 + (f + dx + dy) % 2]
        for _ in range(6):
            dist = rng.randint(3, 5)
            ang = rng.uniform(-3.0, 0.2)  # mostly upward / backward
            import math
            x = c + round(math.cos(ang) * dist)
            y = c + round(math.sin(ang) * dist)
            if 0 <= x < 11 and 0 <= y < 11:
                px[x, y] = hot[rng.randint(1, 4)]
        frames.append(img)
    strip = Image.new("RGBA", (44, 11), CLEAR)
    for i, fr in enumerate(frames):
        strip.alpha_composite(fr, (i * 11, 0))
    return strip


# --- build -----------------------------------------------------------------------

def build():
    pieces = {
        "panel": panel(),
        "window": window(),
        "dialogue": dialogue(),
        "dialogue_arrow": dialogue_arrow(),
        "button_normal": button("normal"),
        "button_pressed": button("pressed"),
        "button_disabled": button("disabled"),
        "toast": toast(),
        "banner": banner(),
        "slider_track": slider_track(),
        "slider_fill": slider_fill(),
        "slider_knob": slider_knob(),
        "slider_knob_pressed": slider_knob(True),
        "toggle_on": toggle(True),
        "toggle_off": toggle(False),
        "segment_normal": segment("normal"),
        "segment_selected": segment("selected"),
        "segment_pressed": segment("pressed"),
        "icon_pause": icon_pause(),
        "icon_speaker": icon_speaker(False),
        "icon_speaker_muted": icon_speaker(True),
        "logo": logo(),
        "fuse_rope": fuse_rope(),
        "fuse_burnt": fuse_burnt(),
        "fuse_spark": fuse_spark(),
    }
    return pieces


def write_sheet(pieces):
    pad = 4
    x = y = pad
    row_h = 0
    width = 250
    placed = []
    for name, img in pieces.items():
        if x + img.width > width:
            x, y = pad, y + row_h + pad
            row_h = 0
        placed.append((img, x, y))
        x += img.width + pad
        row_h = max(row_h, img.height)
    sheet = Image.new("RGBA", (width, y + row_h + pad), hexc("547e64"))
    for img, px_, py in placed:
        sheet.alpha_composite(img, (px_, py))
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(SHEET)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    pieces = build()
    for name, img in pieces.items():
        img.save(os.path.join(OUT_DIR, name + ".png"))
    write_sheet(pieces)
    print(f"wrote {len(pieces)} pieces to {OUT_DIR}/ and {SHEET}")


if __name__ == "__main__":
    main()
