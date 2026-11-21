"""Art pass D2: Goob type production from the approved D1 sheets.

Usage: python art/goobs/make_goob_production.py   (all five types)

Per type and team (blue = player, red = opponent), into assets/goobs/<type>/:
  <team>_expressions.png   7 rows (EXPRS order) x 4 columns of 32x32 loop frames
  <team>_frames.tres       SpriteFrames: one looping animation per expression
  <team>_yaw/, <team>_pitch/   8 spin / flip frames (+ _strip.png); frame_00 of
                           yaw is the board + hand still (= the idle keyframe)
Vanilla keeps its existing yaw/pitch frames (PixelLab 8-dir Pro, M3.6).

Flips (Sean, 2026-11-21): only frames 0, 1 and 7 show the face, so every type
reuses Vanilla's back and edge frames. Yaw 1/7 (3/4 views) get the type's face
remapped onto Vanilla's 3/4 body; pitch 1/7 come from the same squash pipeline
that made Vanilla's (make_goob_flips.py reproduces them pixel for pixel).

Loops are built from the D1 keyframes (art/goobs/make_type_sheets.py) per the
expression table in vault Design/Goob type sheets.md. Review output:
art/goobs/production/review.gif + review.png.
"""
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "art", "palette"))
sys.path.insert(0, os.path.join(ROOT, "art", "tests", "rotation"))
import make_type_sheets as sh  # noqa: E402

GOOBS = os.path.join(ROOT, "assets", "goobs")
REVIEW = os.path.join(HERE, "production")
EXPRS = sh.EXPRS
COLS = 4
FPS = 10  # SpriteFrames base speed; frame durations are multiples of 100 ms

# ---------------------------------------------------------------- extra parts
# Loop in-betweens, in the same style as the D1 parts.
sh.EYE.update({
    "sideL":    [".WW.", "WWWW", "KKWW", "KKWW", ".WW."],          # eyes dart left
    "sparkle2": [".KK.", "KKWK", "KKKK", "KWKK", ".KK."],          # glints swap
    "star2":    [".Y.", "YYY", ".Y."],                              # star twinkle (small)
    "kindblink": ["....", "KKKK"],                                  # Plentiful gentle blink
})
sh.EYE_POS.update({"sideL": (11, 0, 0), "sparkle2": (11, 0, 0), "star2": (13, 1, 0),
                   "kindblink": (12, 1, 0)})
sh.MOUTH.update({
    "o_small":   ([".KK.", "KKKK", ".KK."], 14, 20),
    "wobbly2":   (["K.K.K.K.K", ".K.K.K.K."], 12, 20),
    "grimace2":  (["KKKKKKK", "KKWKWKK", "KKKKKKK"], 13, 19),
    "smirk2":    (["........K", "KKKKKKKK.", ".........."], 12, 20),
    # Fat: creases puff out a pixel as it hums
    "fat_puff":  (["K.............K", ".K...........K.", ".K.KK.....KK.K.", ".K...KKKKK...K.",
                   "K.............K"], 9, 18),
    "fat_o2":    (["K...........K", ".K...KKK...K.", ".K...KKK...K.", ".K...KKK...K.",
                   "K...........K"], 10, 18),
})
sh.EXTRA.update({
    "fatblush3": (["PPP", "PPP"], 6, 19, 23),                      # blush flares
})

# ---------------------------------------------------------------- loops
# Each frame: (ms, overrides). Overrides: eyes, brows, mouth, extras (replace),
# dy (whole face), add (extras appended), sweat (sweat drop dy).
BLINK = [(2600, {}), (60, {"eyes": "halflid"}), (100, {"eyes": "blink"}), (60, {"eyes": "halflid"})]
BOUNCE_FAST = [(150, {}), (150, {"dy": -1})]
BOUNCE = [(300, {}), (300, {"dy": -1})]
SAD = [(1400, {}), (140, {"eyes": "blink"})]
SURPRISED = [(400, {}), (400, {"mouth": "o_small"})]
WORRIED = [(300, {}), (300, {"mouth": "wobbly2", "sweat": 1}), (300, {"sweat": 2})]

LOOPS = {
    "vanilla": {
        "idle": BLINK, "giggle": BOUNCE_FAST, "happy": BOUNCE, "sad": SAD,
        "celebrating": BOUNCE_FAST, "surprised": SURPRISED, "worried": WORRIED,
    },
    "convincing": {
        # lazy blink: the half lid closes slowly
        "idle": [(3000, {}), (200, {"eyes": "blink"})],
        "giggle": [(150, {}), (150, {"dy": -1, "mouth": "smirk"})],      # sly snicker
        "happy": [(800, {}), (300, {"dy": -1})],
        "sad": [(900, {}), (900, {"eyes": "sideL"})],                    # eyes slide away
        "celebrating": BOUNCE_FAST,
        "surprised": SURPRISED,
        "worried": [(250, {}), (250, {"eyes": "sideL", "sweat": 1}), (250, {"sweat": 2})],  # eyes dart
    },
    "fat": {
        # creases puff gently as if humming, with a blink
        "idle": [(800, {}), (800, {"mouth": "fat_puff"}), (800, {}), (100, {"eyes": "blink"})],
        "giggle": [(140, {}), (140, {"dy": -1})],                        # belly laugh
        "happy": [(400, {}), (400, {"extras": ["fatblush3"]})],          # blush flares
        "sad": [(300, {}), (300, {"dy": 1})],                            # wobbling pout
        "celebrating": BOUNCE_FAST,
        "surprised": [(200, {}), (200, {"mouth": "fat_o2"})],            # jowl wobble
        "worried": [(250, {}), (250, {"mouth": "fat_smile", "sweat": 1}), (250, {"sweat": 2})],  # nervous gulp
    },
    "popular": {
        # blink with a sparkle
        "idle": [(1400, {}), (1400, {"eyes": "sparkle2"}), (100, {"eyes": "blink"}),
                 (200, {"add": ["twinkle"]})],
        "giggle": [(150, {}), (150, {"dy": -1, "extras": ["blush", "twinkle2"]})],
        "happy": [(300, {}), (300, {"eyes": "star2"})],                   # star eyes twinkle
        "sad": [(400, {}), (400, {"extras": []}), (400, {"mouth": "frown"})],   # tears fall, quivering
        "celebrating": [(150, {}), (150, {"dy": -1, "eyes": "star2",
                                          "extras": ["blush"]})],
        "surprised": SURPRISED,
        "worried": [(300, {}), (300, {"mouth": "grimace2", "sweat": 1}), (300, {"sweat": 2})],
    },
    "plentiful": {
        # long gentle blink
        "idle": [(2800, {}), (320, {"eyes": "kindblink", "extras": ["rosy", "lashes"]})],
        "giggle": [(180, {}), (180, {"dy": -1})],                        # chuckle, cheeks lift
        "happy": [(800, {}), (400, {"dy": -1})],
        "sad": [(1600, {}), (400, {"eyes": "blink", "extras": ["tired", "tired2"]})],
        "celebrating": [(300, {}), (300, {"dy": -1, "extras": ["rosy"]})],  # joy tear, beaming
        "surprised": SURPRISED,
        "worried": [(1200, {}), (200, {"eyes": "kindblink", "extras": ["lashes"]})],
    },
}


def compose(gtype, team, expr, ov):
    """One loop frame: the D1 keyframe with `ov` applied."""
    eyes, brows, mouth, extras = sh.TYPES[gtype]["faces"][expr]
    eyes = ov.get("eyes", eyes)
    brows = ov.get("brows", brows)
    mouth = ov.get("mouth", mouth)
    extras = list(ov.get("extras", extras)) + list(ov.get("add", []))
    dy = ov.get("dy", 0)
    sweat = ov.get("sweat", 0)
    im = sh.blank_body(team)
    sh.engrave(im, team, sh.TYPES[gtype]["rim"])
    face = Image.new("RGBA", im.size, (0, 0, 0, 0))  # face layer, shifted as one
    for e in extras:
        shape, x, y, mx = sh.EXTRA[e]
        yy = y + (sweat if e == "sweat" else 0)
        sh.stamp(face, team, shape, x, yy)
        if mx is not None:
            sh.stamp(face, team, shape, mx, yy, mirror=True)
    left, right = eyes if isinstance(eyes, tuple) else (eyes, eyes)
    for side, name in (("L", left), ("R", right)):
        y, mir, xs = sh.EYE_POS[name]
        x = 10 + xs if side == "L" else 19 + (0 if mir else xs)
        sh.stamp(face, team, sh.EYE[name], x, y, mirror=(side == "R" and mir))
    if brows:
        bl, br = brows if isinstance(brows, tuple) else (brows, brows)
        if bl:
            sh.stamp(face, team, sh.BROW[bl], 10, sh.BROW_Y[bl])
        if br:
            sh.stamp(face, team, sh.BROW[br], 19, sh.BROW_Y[br], mirror=True)
    shape, x, y = sh.MOUTH[mouth]
    sh.stamp(face, team, shape, x, y)
    # '_' parts erase to body colour; keep them only where they land on the body
    im.alpha_composite(face, (0, dy))
    return im


def loop_frames(gtype, team, expr):
    return [(ms, compose(gtype, team, expr, ov)) for ms, ov in LOOPS[gtype][expr]]


# ---------------------------------------------------------------- flips
def team_rgb(team, sym):
    return sh.rgb(sh.TEAM[team][sym])


def face_layer(still, team):
    """Face pixels of a still: whatever differs from the blank body inside the face disc."""
    blank = sh.blank_body(team)
    a, b = still.load(), blank.load()
    out = {}
    for y in range(32):
        for x in range(32):
            if a[x, y] != b[x, y] and math.hypot(x - 15.5, y - 16.0) < 10.5:
                out[(x, y)] = a[x, y]
    return out


def rim_layer(still, team):
    """Engraved rim pixels of a still (outside the face disc) as {(x, y): ramp step delta}."""
    blank = sh.blank_body(team)
    a, b = still.load(), blank.load()
    inv = {team_rgb(team, s): i for i, s in enumerate(sh.RAMP)}
    out = {}
    for y in range(32):
        for x in range(32):
            if a[x, y] != b[x, y] and math.hypot(x - 15.5, y - 16.0) >= 10.5:
                if a[x, y] in inv and b[x, y] in inv:
                    out[(x, y)] = inv[a[x, y]] - inv[b[x, y]]
    return out


def interior(im, team, seed):
    """Flood fill of the 3/4 face from `seed`, stopped by the face ring (R/S)."""
    px = im.load()
    stop = {team_rgb(team, "R"), team_rgb(team, "S")}
    seen, todo = set(), [seed]
    while todo:
        x, y = todo.pop()
        if (x, y) in seen or not (0 <= x < 32 and 0 <= y < 32):
            continue
        if px[x, y][3] == 0 or px[x, y] in stop:
            continue
        seen.add((x, y))
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return seen


# 3/4 face mapping, measured on Vanilla (eyes, blush and mouth corners of
# yaw frame 00 vs 01): x' = 12.5 + (x - 8.5) * 0.567; the far side sits 1 px lower.
KX = 0.567


def map_x(x, mirror):
    if not mirror:
        return 12.5 + (x - 8.5) * KX
    return 31 - (12.5 + ((31 - x) - 8.5) * KX)


def three_quarter(still, team, frame, mirror):
    """Yaw frame 1 (mirror=False) or 7 (mirror=True) for a type: Vanilla's 3/4 body,
    face cleared, the type's face squashed onto it column by column."""
    base = Image.open(os.path.join(GOOBS, "vanilla", "%s_yaw" % team, "frame_%02d.png" % frame)).convert("RGBA")
    px = base.load()
    seed = (17, 17) if not mirror else (14, 17)
    inside = interior(base, team, seed)
    body = team_rgb(team, "B")
    ramp = {team_rgb(team, s) for s in sh.RAMP} - {team_rgb(team, "K"), team_rgb(team, "W")}
    for x, y in inside:
        if px[x, y] not in ramp:
            px[x, y] = body
    face = face_layer(still, team)
    # target column -> best source column (most face pixels), like squash_rows
    cols = {}
    for sx in range(5, 27):
        tx = int(math.floor(map_x(sx + 0.5, mirror)))
        cols.setdefault(tx, []).append(sx)
    for tx, srcs in cols.items():
        best = max(srcs, key=lambda c: (sum(1 for (fx, _fy) in face if fx == c), -abs(c - 15.5)))
        far = (best < 15.5) if not mirror else (best > 15.5)
        for (fx, fy), c in face.items():
            if fx != best:
                continue
            ty = fy + (1 if far else 0)
            if (tx, ty) in inside:
                px[tx, ty] = c
    # rim engraving: same spots, on the inner ring of the 3/4 face
    rim = rim_layer(still, team)
    inv = {team_rgb(team, s): i for i, s in enumerate(sh.RAMP)}
    ring = {(x, y) for y in range(32) for x in range(32)
            if (x, y) not in inside and px[x, y] in inv and px[x, y] != team_rgb(team, "K")
            and any((x + dx, y + dy) in inside for dx in (-1, 0, 1) for dy in (-1, 0, 1))}
    cx = sum(x for x, _ in inside) / len(inside)
    rx = (max(x for x, _ in inside) - min(x for x, _ in inside)) / 2 + 1
    for (x, y), d in rim.items():
        a = math.atan2(y - 16.0, x - 15.5)
        gx, gy = cx + rx * math.cos(a), 16.0 + 12.0 * math.sin(a)
        if not ring:
            break
        tx, ty = min(ring, key=lambda p: (p[0] - gx) ** 2 + (p[1] - gy) ** 2)
        i = max(0, min(inv[px[tx, ty]] + d, sh.RAMP.index("H")))
        px[tx, ty] = team_rgb(team, sh.RAMP[i])
    return base


def pitch_frame(still, team, i):
    import make_goob_flips as fl
    cwd = os.getcwd()
    os.chdir(os.path.join(ROOT, "art", "tests", "rotation"))  # fl.load reads PixelLab 2b
    try:
        face = fl.content(still)
        if i == 0:
            f = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
            f.alpha_composite(face, ((32 - face.width) // 2, (32 - face.height) // 2))
            return f
        a = math.radians(i * 45)
        c, s = math.cos(a), math.sin(a)
        edge = fl.content(fl.load("east")).rotate(90, expand=True)
        # band = team outline + rim colours (what quantize gave Vanilla); every
        # still pixel is already in the palette, so no re-quantise (it washed blue out)
        outline, rim = team_rgb(team, "K"), team_rgb(team, "R")
        disc = fl.squash_rows(face, max(3, round(face.height * abs(c))))
        return fl.coin_frame(disc, max(1, round(min(edge.size[1], 4) * abs(s))), band_below=(s > 0),
                             outline=outline, rim=rim)
    finally:
        os.chdir(cwd)


def save_frames(frames, folder):
    os.makedirs(folder, exist_ok=True)
    strip = Image.new("RGBA", (32 * len(frames), 32), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        f.save(os.path.join(folder, "frame_%02d.png" % i))
        strip.paste(f, (i * 32, 0))
    strip.save(folder + "_strip.png")


def flips(gtype, team, still):
    van = os.path.join(GOOBS, "vanilla")
    yaw = [Image.open(os.path.join(van, "%s_yaw" % team, "frame_%02d.png" % i)).convert("RGBA") for i in range(8)]
    pitch = [Image.open(os.path.join(van, "%s_pitch" % team, "frame_%02d.png" % i)).convert("RGBA") for i in range(8)]
    yaw[0] = still
    yaw[1] = three_quarter(still, team, 1, False)
    yaw[7] = three_quarter(still, team, 7, True)
    for i in (0, 1, 7):
        pitch[i] = pitch_frame(still, team, i)
    return yaw, pitch


# ---------------------------------------------------------------- SpriteFrames
def write_tres(path, res_path, gtype, team):
    loops = LOOPS[gtype]
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' %
             (2 + sum(len(loops[e]) for e in EXPRS)), "",
             '[ext_resource type="Texture2D" path="%s" id="1"]' % res_path, ""]
    anims = []
    for r, e in enumerate(EXPRS):
        frames = []
        for c, (ms, _ov) in enumerate(loops[e]):
            sid = "%s_%d" % (e, c)
            lines += ['[sub_resource type="AtlasTexture" id="%s"]' % sid,
                      'atlas = ExtResource("1")',
                      "region = Rect2(%d, %d, 32, 32)" % (c * 32, r * 32), ""]
            frames.append('{\n"duration": %s,\n"texture": SubResource("%s")\n}' %
                          (repr(ms / (1000.0 / FPS)), sid))
        anims.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' %
                     (", ".join(frames), e, repr(float(FPS))))
    lines += ["[resource]", "animations = [%s]" % ", ".join(anims), ""]
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(lines))


# ---------------------------------------------------------------- review
BG = (40, 36, 46, 255)


def review(all_loops, all_flips):
    """GIF: rows = type x team, columns = 7 expressions + yaw spin + pitch flip, 4x."""
    S, cell = 4, 32 * 4 + 16
    rows = [(g, t) for g in sh.TYPES for t in sh.TEAM]
    W, H = 16 + cell * (len(EXPRS) + 2), 40 + cell * len(rows)
    step = 50  # ms per GIF frame
    total = 6000
    gif = []
    for t_ms in range(0, total, step):
        im = Image.new("RGBA", (W, H), BG)
        for i, e in enumerate(EXPRS + ["spin", "flip"]):
            sh.text(im, (16 + i * cell, 6), e, 2, sh.DIM)
        for r, (g, team) in enumerate(rows):
            y = 40 + r * cell
            for i, e in enumerate(EXPRS):
                frames = all_loops[(g, team, e)]
                length = sum(ms for ms, _ in frames)
                t = t_ms % length
                for ms, f in frames:
                    if t < ms:
                        break
                    t -= ms
                im.alpha_composite(sh.up(f, S), (16 + i * cell, y))
            yaw, pitch = all_flips[(g, team)]
            k = (t_ms // 100) % 12  # 8 spin frames then a 4-frame hold on the face
            im.alpha_composite(sh.up(yaw[k if k < 8 else 0], S), (16 + 7 * cell, y))
            im.alpha_composite(sh.up(pitch[k if k < 8 else 0], S), (16 + 8 * cell, y))
        gif.append(im.convert("RGB").convert("P", palette=Image.ADAPTIVE, colors=255))
    os.makedirs(REVIEW, exist_ok=True)
    gif[0].save(os.path.join(REVIEW, "review.gif"), save_all=True, append_images=gif[1:],
                duration=step, loop=0)
    # flips close-up: 3/4 frames for every type, 8x
    fl = Image.new("RGBA", (16 + 6 * 34 * 6, 16 + len(rows) * 34 * 6), BG)
    for r, (g, team) in enumerate(rows):
        yaw, pitch = all_flips[(g, team)]
        for i, f in enumerate([yaw[7], yaw[0], yaw[1], pitch[7], pitch[0], pitch[1]]):
            fl.alpha_composite(sh.up(f, 6), (16 + i * 34 * 6, 16 + r * 34 * 6))
    fl.save(os.path.join(REVIEW, "flips_6x.png"))
    print(os.path.join(REVIEW, "review.gif"))


def main():
    all_loops, all_flips = {}, {}
    for g in sh.TYPES:
        folder = os.path.join(GOOBS, g)
        os.makedirs(folder, exist_ok=True)
        for team in sh.TEAM:
            sheet = Image.new("RGBA", (32 * COLS, 32 * len(EXPRS)), (0, 0, 0, 0))
            for r, e in enumerate(EXPRS):
                frames = loop_frames(g, team, e)
                assert len(frames) <= COLS, (g, e)
                all_loops[(g, team, e)] = frames
                for c, (_ms, f) in enumerate(frames):
                    sheet.paste(f, (c * 32, r * 32))
            name = "%s_expressions.png" % team
            sheet.save(os.path.join(folder, name))
            write_tres(os.path.join(folder, "%s_frames.tres" % team),
                       "res://assets/goobs/%s/%s" % (g, name), g, team)
            still = sh.make_face(g, team, "idle")
            if g == "vanilla":
                van = os.path.join(GOOBS, "vanilla")
                yaw = [Image.open(os.path.join(van, "%s_yaw" % team, "frame_%02d.png" % i)).convert("RGBA") for i in range(8)]
                pitch = [Image.open(os.path.join(van, "%s_pitch" % team, "frame_%02d.png" % i)).convert("RGBA") for i in range(8)]
            else:
                yaw, pitch = flips(g, team, still)
                save_frames(yaw, os.path.join(folder, "%s_yaw" % team))
                save_frames(pitch, os.path.join(folder, "%s_pitch" % team))
            all_flips[(g, team)] = (yaw, pitch)
    review(all_loops, all_flips)


if __name__ == "__main__":
    main()
