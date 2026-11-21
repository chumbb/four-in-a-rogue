"""Art pass D1: Goob type sheets (faces, 7 expressions, rim pattern, mocks).

Usage: python art/goobs/make_type_sheets.py [type ...]   (default: all types)

Faces are hand-pixelled on the existing Vanilla coin body
(assets/goobs/vanilla/<team>_yaw/frame_00.png): the old face is cleared,
then each expression is stamped from small pixel parts. Rules: vault
Design/Goob type sheets.md (Sean, 2026-11-21).

Outputs (art/goobs/sheets/):
  <type>_sheet.png               the sheet Sean reviews (final pixels, 4x Goobs)
  <type>/<team>_<expr>.png       32x32 keyframes (D2 animates from these)
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "sheets")
EXPRS = ["idle", "giggle", "happy", "sad", "celebrating", "surprised", "worried"]

# Symbol colours per team (Resurrect 64). Body ramp K<S<R<B<H<W is also the rim ramp.
TEAM = {
    "blue": dict(K="323353", S="484a77", R="4d65b4", B="4d9be6", H="8fd3ff", W="ffffff",
                 P="905ea9", Q="cf657f", T="8fd3ff", Y="f9c22b"),
    "red": dict(K="45293f", S="6e2727", R="ae2334", B="e83b3b", H="f68181", W="ffffff",
                P="e6904e", Q="fca790", T="8fd3ff", Y="f9c22b"),
}
RAMP = "KSRBHW"


def rgb(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


# ---------------------------------------------------------------- pixel parts
# '.' = leave as is, '_' = body colour (erase). Others = TEAM symbols.
EYE = {
    "open":    [".WW.", "WWWW", "WKKW", "WKKW", ".WW."],          # Vanilla, at y11
    "blink":   ["KKKK"],                                          # at y13
    "arc":     [".KK.", "K..K"],                                  # ^ closed, at y12
    "u":       ["K..K", ".KK."],                                  # content closed, at y13
    "wide":    [".WWW.", "WWWWW", "WWKWW", "WWWWW", ".WWW."],     # 5 wide, x-1
    "down":    [".WW.", "WWWW", "WWWW", "WKKW", ".WW."],
    "side":    [".WW.", "WWWW", "WWKK", "WWKK", ".WW."],          # not mirrored
    "halflid": ["KKKK", "WKKW", ".WW."],                          # at y13
    "squint":  ["KKKK", "_KK_"],                                  # at y13
    "puffed":  [".KK.", "K..K"],                                  # ^ pushed up by cheeks, at y13
    "small":   [".WW.", "WKKW", "WKKW"],                          # Fat: cheeks squeeze the eyes, y12
    "smalldown": [".WW.", "WWWW", "WKKW"],
    "smallside": [".WW.", "WWKK", "WWKK"],                        # not mirrored
    "sparkle": [".WW.", "WWKW", "WKKW", "WKKW", ".WW."],          # not mirrored (light top-left)
    "star":    ["..Y..", "YYYYY", ".YYY.", ".Y.Y."],              # 5 wide, x-1, y12
    "kind":    [".WW.", "WKKW", "KKKK"],                          # at y12
}
# (shape, y, mirror_right, x_shift)
EYE_POS = {"open": (11, 1, 0), "blink": (13, 1, 0), "arc": (12, 1, 0), "u": (13, 1, 0),
           "wide": (11, 1, -1), "down": (11, 1, 0), "side": (11, 0, 0), "halflid": (13, 1, 0),
           "squint": (13, 1, 0), "puffed": (13, 1, 0),
           "small": (12, 1, 0), "smalldown": (12, 1, 0), "smallside": (12, 0, 0), "sparkle": (11, 0, 0), "star": (12, 1, -1), "kind": (12, 1, 0)}

BROW = {  # left brow; right is mirrored
    "sad":    ["..KK", "KK.."],       # inner end up, at y9
    "raised": [".KK.", "K..K"],       # arch, at y8
    "flat":   ["KKKK"],               # at y10
    "low":    ["KKKK"],               # at y11 (just over a half lid)
}
BROW_Y = {"sad": 9, "raised": 8, "flat": 10, "low": 11}

MOUTH = {  # (shape, x, y)
    "smile":     (["K.......K", ".K.....K.", "..KKKKK.."], 12, 19),
    "opensmile": (["KKKKKKKKK", ".KKKKKKK.", "..KPPPK.."], 12, 19),
    "laugh":     (["KKKKKKK", ".KPPPK.", "..KKK.."], 13, 19),
    "bigopen":   (["KKKKKKKKK", "KKKKKKKKK", ".KKPPPKK.", "..KKKKK.."], 12, 19),
    "frown":     (["..KKKKK..", ".K.....K.", "K.......K"], 12, 20),
    "o":         ([".KK.", "KKKK", "KKKK", ".KK."], 14, 19),
    "wobbly":    ([".K.K.K.K.", "K.K.K.K.K"], 12, 20),
    "smirk":     (["........K", ".......K.", "KKKKKKK.."], 12, 19),
    "snicker":   (["........K", ".KKKKKKK.", "..KPPPK.."], 12, 19),
    "pout":      (["..KKK..", ".K...K."], 13, 20),
    "tight":     (["KKKKK"], 14, 20),
    "fatsmile":  (["K.........K", ".K.......K.", "..KKKKKKK.."], 11, 19),
    "fatgrin":   (["K.........K", ".KKKKKKKKK.", "..KKPPPKK.."], 11, 19),
    "fatroar":   (["KKKKKKKKKKK", "KKKKKKKKKKK", ".KKKPPPKKK.", "..KKKKKKK.."], 11, 19),
    "grimace":   (["KKKKKKK", "KWKWKWK", "KKKKKKK"], 13, 19),
    "warm":      (["K.....K", ".KKKKK."], 13, 20),
    "tiny":      (["K...K", ".KKK."], 14, 20),                     # Fat: squished between the cheeks
    "warmlaugh": (["KKKKK", ".KPK."], 14, 20),
}

EXTRA = {  # (shape, x, y, mirrored copy x or None)
    "blush":     (["PP"], 8, 18, 23),
    "rosy":      (["PP", "PP"], 8, 17, 23),
    "fatblush":  (["PPP.", "PQQP", ".PP."], 8, 16, 21),
    "fatnose":   (["PQP"], 15, 16, None),
    "fatcheek":  (["H"], 9, 15, 23),
    "cheeks":    (["..HH..", ".HPPP.", "PPQQPP", "PPPPPP", "SPPPPS", ".SSSS."], 6, 14, 20),  # chubby drunk-blush cheeks
    "jowl":      (["S...............S", ".S.............S.", "..SS.........SS..", "....SSSSSSSSS...."], 8, 20, None),
    "scar":      (["S.", "S.", ".S"], 9, 10, None),
    "sweat":     ([".W.", "TTT", ".T."], 23, 9, None),
    "tears":     (["T", "T"], 11, 16, 21),
    "joytear":   (["T", "T"], 23, 15, None),
    "twinkle":   ([".W.", "WWW", ".W."], 23, 8, None),
    "twinkle2":  ([".W.", "WWW", ".W."], 7, 8, None),
    "tired":     ([".SS."], 10, 16, 19),
    "tired2":    (["S..S"], 10, 17, 19),
}

# ---------------------------------------------------------------- face design
# Each expression: eyes, brows (or None), mouth, extras.
FAT = ["cheeks"]  # chubby drunk-blush cheeks (Sean: no double chin, less busy; scar read as a brow)
TYPES = {
    "vanilla": {
        "title": "Vanilla Goob", "tag": "ordinary, content - the plain baseline", "rim": None,
        "faces": {
            "idle":        ("open", None, "smile", ["blush"]),
            "giggle":      ("arc", None, "laugh", ["blush"]),
            "happy":       ("open", None, "opensmile", ["blush"]),
            "sad":         ("down", "sad", "frown", []),
            "celebrating": ("arc", None, "bigopen", ["blush"]),
            "surprised":   ("wide", "raised", "o", []),
            "worried":     ("side", "sad", "wobbly", ["sweat"]),
        },
    },
    "convincing": {
        "title": "Convincing Goob", "tag": "smug Gooberius persuader", "rim": "eyes",
        "faces": {
            "idle":        ("halflid", ("low", "raised"), "smirk", []),
            "giggle":      ("arc", None, "snicker", []),
            "happy":       ("halflid", "raised", "smirk", []),
            "sad":         ("side", "sad", "pout", []),
            "celebrating": ("arc", None, "opensmile", []),
            "surprised":   ("wide", "raised", "o", []),
            "worried":     ("side", "sad", "tight", ["sweat"]),
        },
    },
    "fat": {
        "title": "Fat Goob", "tag": "Falstaff - jolly red-faced braggart", "rim": "shields",
        "faces": {
            "idle":        ("small", None, "tiny", FAT),
            "giggle":      ("blink", None, "laugh", FAT),
            "happy":       ("arc", None, "opensmile", FAT),
            "sad":         ("smalldown", "sad", "frown", FAT),
            "celebrating": ("arc", None, "fatroar", FAT),
            "surprised":   ("wide", "raised", "o", FAT),
            "worried":     ("smallside", "sad", "wobbly", FAT + ["sweat"]),
        },
    },
}


def stamp(img, team, shape, x, y, mirror=False):
    px = img.load()
    for dy, row in enumerate(shape):
        if mirror:
            row = row[::-1]
        for dx, ch in enumerate(row):
            if ch == ".":
                continue
            sym = "B" if ch == "_" else ch
            px[x + dx, y + dy] = rgb(TEAM[team][sym])


def blank_body(team):
    """Vanilla frame_00 with the face pixels (eyes, mouth, blush) painted body colour."""
    im = Image.open(os.path.join(ROOT, "assets", "goobs", "vanilla", team + "_yaw", "frame_00.png")).convert("RGBA")
    px = im.load()
    face = {rgb(TEAM[team][s]) for s in "KWP"}
    # the old red blush came from a hue shift; treat any non-ramp colour as face too
    ramp = {rgb(TEAM[team][s]) for s in RAMP}
    for y in range(10, 24):
        for x in range(7, 25):
            c = px[x, y]
            if c[3] and (c in face or c not in ramp):
                px[x, y] = rgb(TEAM[team]["B"])
    return im


def rim_pixels(im, team):
    """Rim pixels as (x, y, angle, outer) from the body ramp ring around the face."""
    px = im.load()
    cx, cy = 15.5, 16.0
    out = []
    ring = {rgb(TEAM[team][s]): s for s in "SRH"}
    for y in range(32):
        for x in range(32):
            c = px[x, y]
            if c in ring:
                d = math.hypot(x - cx, y - cy)
                if d >= 10.5:
                    out.append((x, y, math.atan2(y - cy, x - cx), d >= 12.5))
    return out


# Rim motifs: a small glyph stamped at n even spots around the rim, laid along
# the rim's tangent (a 2 px rim can't hold a drawn emblem; an angle-tiled
# pattern read as speckle). 'L' = two ramp steps lighter, 'D' = two darker.
# (glyph, count, radius, start angle)
RIM = {
    "eyes": ("LDL", 8, 13.0, 0.0),
    "shields": ("DDD", 8, 13.0, math.pi / 8),
}


def engrave(im, team, motif):
    if not motif:
        return
    glyph, n, r, off = RIM[motif]
    px = im.load()
    inv = {rgb(TEAM[team][s]): s for s in RAMP}
    rim = {(x, y) for x, y, _a, _o in rim_pixels(im, team)}
    half = len(glyph) // 2
    for k in range(n):
        a = off + 2 * math.pi * k / n
        cx, cy = 15.5 + r * math.cos(a), 16.0 + r * math.sin(a)
        tx, ty = -math.sin(a), math.cos(a)
        for j, ch in enumerate(glyph):
            x, y = int(round(cx + (j - half) * tx - 0.5)), int(round(cy + (j - half) * ty))
            if ch == "." or (x, y) not in rim or px[x, y] not in inv:
                continue
            i = RAMP.index(inv[px[x, y]])
            i = min(i + 2, RAMP.index("H")) if ch == "L" else max(i - 2, 0)
            px[x, y] = rgb(TEAM[team][RAMP[i]])


def make_face(gtype, team, expr):
    spec = TYPES[gtype]
    eyes, brows, mouth, extras = spec["faces"][expr]
    im = blank_body(team)
    engrave(im, team, spec["rim"])
    for e in extras:  # extras first so eyes/mouth sit on top
        shape, x, y, mx = EXTRA[e]
        stamp(im, team, shape, x, y)
        if mx is not None:
            stamp(im, team, shape, mx, y, mirror=True)
    if isinstance(eyes, tuple):  # (left, right) for winks
        left, right = eyes
    else:
        left = right = eyes
    for side, name in (("L", left), ("R", right)):
        y, mir, xs = EYE_POS[name]
        x = 10 + xs if side == "L" else 19 + (0 if mir else xs)
        stamp(im, team, EYE[name], x, y, mirror=(side == "R" and mir))
    if brows:
        bl, br = brows if isinstance(brows, tuple) else (brows, brows)
        if bl:
            stamp(im, team, BROW[bl], 10, BROW_Y[bl])
        if br:
            stamp(im, team, BROW[br], 19, BROW_Y[br], mirror=True)
    shape, x, y = MOUTH[mouth]
    stamp(im, team, shape, x, y)
    return im


# ---------------------------------------------------------------- sheet
BG = (40, 36, 46, 255)
INK = (199, 220, 208, 255)
DIM = (127, 112, 138, 255)
S = 4  # board Goob scale (1080-wide screen)
HS = 5  # hand Goob scale


def font():
    return ImageFont.truetype(os.path.join(ROOT, "resources", "fonts", "monogram-extended.ttf"), 16)


def text(sheet, xy, s, scale=2, fill=INK):
    f = font()
    w = int(f.getlength(s)) + 2
    t = Image.new("RGBA", (w, 16), (0, 0, 0, 0))
    ImageDraw.Draw(t).text((0, 0), s, font=f, fill=fill)
    sheet.alpha_composite(t.resize((w * scale, 16 * scale), Image.NEAREST), xy)


def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def board_mock(faces, vanilla):
    """Bottom-left 4x3 cells of the honey-wood board with the type next to Vanilla."""
    back = Image.open(os.path.join(ROOT, "assets", "board", "board_back.png")).convert("RGBA")
    front = Image.open(os.path.join(ROOT, "assets", "board", "board_front.png")).convert("RGBA")
    bg = Image.open(os.path.join(ROOT, "assets", "backgrounds", "forest.png")).convert("RGBA")
    W, H = back.size
    canvas = bg.resize((W, int(bg.height * W / bg.width)), Image.NEAREST).crop((0, 200, W, 200 + H))
    canvas.alpha_composite(back)
    layout = {  # (col, row) -> goob   (row 5 = bottom)
        (0, 5): faces["blue"], (1, 5): vanilla["red"], (2, 5): vanilla["blue"], (3, 5): faces["red"],
        (0, 4): vanilla["blue"], (1, 4): faces["red"], (2, 4): faces["blue"],
        (1, 3): vanilla["red"],
    }
    for (c, r), g in layout.items():
        canvas.alpha_composite(g, (8 + 32 * c, 8 + 32 * r - 1))
    canvas.alpha_composite(front)
    return up(canvas.crop((0, 8 + 32 * 3 - 8, 8 + 32 * 4 + 8, H)), S)


def hand_mock(faces, vanilla):
    stump = Image.open(os.path.join(ROOT, "assets", "hand", "forest_stump.png")).convert("RGBA")
    bg = Image.open(os.path.join(ROOT, "assets", "backgrounds", "forest.png")).convert("RGBA")
    W = 150
    canvas = bg.resize((stump.width, int(bg.height * stump.width / bg.width)), Image.NEAREST)
    canvas = canvas.crop((0, canvas.height - 120, stump.width, canvas.height))
    seat = 34
    canvas.alpha_composite(stump.crop((0, 0, stump.width, 120 - 40)), (0, 40))
    goobs = [vanilla["blue"], faces["blue"], vanilla["blue"]]
    x0 = (stump.width - (len(goobs) * 32 + 2 * 4)) // 2
    for i, g in enumerate(goobs):
        canvas.alpha_composite(g, (x0 + i * 36, 40 + seat - 32))
    cx = stump.width // 2
    return up(canvas.crop((cx - W // 2, 0, cx + W // 2, 120)), HS)


def build(gtype):
    spec = TYPES[gtype]
    faces = {t: {e: make_face(gtype, t, e) for e in EXPRS} for t in TEAM}
    van = {t: make_face("vanilla", t, "idle") for t in TEAM}
    os.makedirs(os.path.join(OUT, gtype), exist_ok=True)
    for t in TEAM:
        for e in EXPRS:
            faces[t][e].save(os.path.join(OUT, gtype, "%s_%s.png" % (t, e)))

    cell = 32 * S + 24
    board = board_mock({t: faces[t]["idle"] for t in TEAM}, van)
    hand = hand_mock({t: faces[t]["idle"] for t in TEAM}, van)
    width = max(24 + 64 + cell * len(EXPRS), 24 + 100 + 32 * 8 + 32 + board.width + 32 + hand.width + 24)
    height = 24 + 60 + 2 * (32 * S + 48) + 40 + max(board.height, hand.height, 32 * 8) + 60
    sheet = Image.new("RGBA", (width, height), BG)
    text(sheet, (24, 16), spec["title"], 3)
    text(sheet, (24 + int(font().getlength(spec["title"])) * 3 + 24, 30), spec["tag"], 2, DIM)

    y = 84
    for t in TEAM:
        text(sheet, (24, y + 32 * S // 2 - 16), t, 2, DIM)
        for i, e in enumerate(EXPRS):
            x = 24 + 64 + i * cell
            sheet.alpha_composite(up(faces[t][e], S), (x, y))
            if t == "red":
                text(sheet, (x, y + 32 * S + 6), e, 2, DIM)
        y += 32 * S + (48 if t == "red" else 16)
    y += 24

    # neutral at 1x and the rim close-up at 8x
    x = 24
    text(sheet, (x, y), "1x", 2, DIM)
    for i, t in enumerate(TEAM):
        sheet.alpha_composite(faces[t]["idle"], (x + i * 40, y + 40))
    x += 100
    text(sheet, (x, y), "rim: " + (spec["rim"] or "plain"), 2, DIM)
    sheet.alpha_composite(up(faces["blue"]["idle"], 8), (x, y + 40))
    x += 32 * 8 + 32
    text(sheet, (x, y), "board (4x)", 2, DIM)
    sheet.alpha_composite(board, (x, y + 40))
    x += board.width + 32
    text(sheet, (x, y), "hand on stump (5x)", 2, DIM)
    sheet.alpha_composite(hand, (x, y + 40))
    path = os.path.join(OUT, gtype + "_sheet.png")
    try:
        sheet.convert("RGB").save(path)
    except OSError:  # open in an image viewer on Windows
        n = 2
        while os.path.exists(path.replace("_sheet.png", "_sheet_v%d.png" % n)):
            n += 1
        path = path.replace("_sheet.png", "_sheet_v%d.png" % n)
        sheet.convert("RGB").save(path)
    print(path)


if __name__ == "__main__":
    for g in sys.argv[1:] or list(TYPES):
        build(g)
