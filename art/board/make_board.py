"""Build the 2D pixel board layers (placeholder art for M3.6).

Usage: python art/board/make_board.py   (from the repo root)

Outputs (game pixels, shown at whole-number scale on the 270x480 pixel layer):
  assets/board/board_back.png   240x216  back panel, drawn behind the Goobs
  assets/board/board_front.png  240x216  front panel with 7x6 holes, drawn over the Goobs
  art/board/board_preview4x.png          both layers + a few Goobs, 4x, for review

Layout: 7x6 grid of 32 px cells starting at GRID_ORIGIN (8, 8); hole centre of cell
(c, r) = (8 + 32c + 16, 8 + 32r + 16); hole diameter 28 px. The panel is 240x208,
plus 8 px feet below it that stand on the table. Light comes from the top left.
Honey wood colours (Sean, 2026-11-11).
"""
import math
import os
import random

from PIL import Image

COLS, ROWS, CELL = 7, 6, 32
BORDER = 8
GRID_ORIGIN = (BORDER, BORDER)
PANEL_W = COLS * CELL + 2 * BORDER  # 240
PANEL_H = ROWS * CELL + 2 * BORDER  # 208
FOOT_H = 8
W, H = PANEL_W, PANEL_H + FOOT_H  # 240 x 216
HOLE_R = 14.0

# Honey wood ramp, dark -> light (hue shifts warmer/redder in shadow).
OUTLINE = (74, 38, 30, 255)
SHADOW = (138, 78, 42, 255)
MID = (186, 116, 52, 255)
BASE = (222, 156, 70, 255)
LIGHT = (240, 192, 100, 255)
HIGHLIGHT = (252, 226, 152, 255)
# Back panel: the inside of the board, seen through the holes behind the Goobs.
BACK_DEEP = (58, 30, 26, 255)
BACK_DARK = (92, 50, 34, 255)
BACK_MID = (120, 68, 40, 255)

OUT_DIR = "assets/board"
PREVIEW = "art/board/board_preview4x.png"


def hole_centre(c, r):
    return GRID_ORIGIN[0] + c * CELL + CELL / 2, GRID_ORIGIN[1] + r * CELL + CELL / 2


def nearest_hole(x, y):
    """Distance from pixel centre (x, y) to the nearest hole centre, and the angle to it."""
    c = min(COLS - 1, max(0, (x - GRID_ORIGIN[0]) // CELL))
    r = min(ROWS - 1, max(0, (y - GRID_ORIGIN[1]) // CELL))
    cx, cy = hole_centre(c, r)
    dx, dy = x + 0.5 - cx, y + 0.5 - cy
    return math.hypot(dx, dy), math.atan2(dy, dx)


def lit_side(angle):
    """+1 for the lower-right half of a hole rim (faces the top-left light), -1 for the upper-left."""
    # Direction pointing to the bottom right is 45 degrees in screen space (y down).
    return 1 if math.cos(angle - math.pi / 4) > 0 else -1


def wood_grain(img, rng, x0, y0, x1, y1, colour, streaks):
    """Sparse horizontal grain streaks on BASE pixels."""
    px = img.load()
    for _ in range(streaks):
        y = rng.randrange(y0, y1)
        x = rng.randrange(x0, x1)
        length = rng.randrange(4, 14)
        for i in range(length):
            if x + i < x1 and px[x + i, y] == BASE:
                px[x + i, y] = colour


def make_front():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    rng = random.Random(4)
    # Panel body with bevelled edges.
    for y in range(PANEL_H):
        for x in range(PANEL_W):
            if x == 0 or y == 0 or x == PANEL_W - 1 or y == PANEL_H - 1:
                px[x, y] = OUTLINE
            elif x == 1 or y == 1:
                px[x, y] = HIGHLIGHT
            elif x == 2 or y == 2:
                px[x, y] = LIGHT
            elif x == PANEL_W - 2 or y == PANEL_H - 2:
                px[x, y] = SHADOW
            elif x == PANEL_W - 3 or y == PANEL_H - 3:
                px[x, y] = MID
            else:
                px[x, y] = BASE
    wood_grain(img, rng, 3, 3, PANEL_W - 3, PANEL_H - 3, LIGHT, 70)
    wood_grain(img, rng, 3, 3, PANEL_W - 3, PANEL_H - 3, MID, 50)
    # Holes: transparent inside, a two-pixel rim lit on the lower right and shaded on the upper left.
    for y in range(BORDER - 2, PANEL_H - BORDER + 2):
        for x in range(BORDER - 2, PANEL_W - BORDER + 2):
            d, a = nearest_hole(x, y)
            if d < HOLE_R:
                px[x, y] = (0, 0, 0, 0)
            elif d < HOLE_R + 1:
                px[x, y] = HIGHLIGHT if lit_side(a) > 0 else OUTLINE
            elif d < HOLE_R + 2:
                px[x, y] = LIGHT if lit_side(a) > 0 else SHADOW
    # Feet: two short blocks under the panel, standing on the table.
    for fx0 in (12, PANEL_W - 12 - 28):
        for y in range(PANEL_H, H):
            for x in range(fx0, fx0 + 28):
                if x in (fx0, fx0 + 27) or y == H - 1:
                    px[x, y] = OUTLINE
                elif y == H - 2 or x == fx0 + 26:
                    px[x, y] = SHADOW
                elif x == fx0 + 1:
                    px[x, y] = LIGHT
                else:
                    px[x, y] = MID
    return img


def make_back():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    rng = random.Random(9)
    for y in range(1, PANEL_H - 1):
        for x in range(1, PANEL_W - 1):
            px[x, y] = BACK_MID if (x * 7 + y * 3) % 23 == 0 else BACK_DARK
    # Grain on the back wall, darker.
    for _ in range(90):
        y, x, n = rng.randrange(2, PANEL_H - 2), rng.randrange(2, PANEL_W - 2), rng.randrange(4, 12)
        for i in range(n):
            if x + i < PANEL_W - 1:
                px[x + i, y] = BACK_MID if rng.random() < 0.5 else BACK_DEEP
    # The front lip casts a crescent shadow on the back wall inside each hole (upper left).
    for r in range(ROWS):
        for c in range(COLS):
            cx, cy = hole_centre(c, r)
            for y in range(int(cy - HOLE_R), int(cy + HOLE_R) + 1):
                for x in range(int(cx - HOLE_R), int(cx + HOLE_R) + 1):
                    dx, dy = x + 0.5 - cx, y + 0.5 - cy
                    if math.hypot(dx, dy) >= HOLE_R:
                        continue
                    # Inside the hole but outside the same circle shifted 3 px down-right = crescent.
                    if math.hypot(dx - 3, dy - 3) >= HOLE_R:
                        px[x, y] = BACK_DEEP
    return img


def preview(back, front):
    goobs = {
        "b": Image.open("assets/goobs/vanilla/blue_yaw/frame_00.png").convert("RGBA"),
        "r": Image.open("assets/goobs/vanilla/red_yaw/frame_00.png").convert("RGBA"),
    }
    # (col, row from bottom, side)
    placed = [(0, 0, "b"), (1, 0, "r"), (2, 0, "b"), (3, 0, "r"), (3, 1, "b"), (2, 1, "r"),
              (3, 2, "b"), (4, 0, "b"), (3, 3, "r"), (6, 0, "r")]
    bg = (92, 140, 120, 255)
    canvas = Image.new("RGBA", (W + 16, H + 40 + 16), bg)
    ox, oy = 8, 8 + 40
    canvas.alpha_composite(back, (ox, oy))
    for c, rb, side in placed:
        r = ROWS - 1 - rb
        canvas.alpha_composite(goobs[side], (ox + GRID_ORIGIN[0] + c * CELL, oy + GRID_ORIGIN[1] + r * CELL - 1))
    # A Goob falling into column 5, half behind the top rail.
    canvas.alpha_composite(goobs["b"], (ox + GRID_ORIGIN[0] + 5 * CELL, oy - 14))
    canvas.alpha_composite(front, (ox, oy))
    return canvas.resize((canvas.width * 4, canvas.height * 4), Image.NEAREST)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    back, front = make_back(), make_front()
    back.save(os.path.join(OUT_DIR, "board_back.png"))
    front.save(os.path.join(OUT_DIR, "board_front.png"))
    preview(back, front).save(PREVIEW)
    print("board %dx%d, grid origin %s, cell %d, hole diameter %d" % (W, H, GRID_ORIGIN, CELL, HOLE_R * 2))


if __name__ == "__main__":
    main()
