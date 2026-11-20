"""Art pass B approval mocks (Sean approves one mock set before the final kit; 2026-11-20).

Usage: python art/ui/make_ui_kit.py && python art/ui/make_ui_mocks.py   (from the repo root)

Writes art/ui/mocks/mock_<screen>.png at 1080x1920 (Sean's monitor): the painted
background at full resolution, every pixel piece (board, Goobs, UI kit, text) on the
270x480 game-pixel grid at 4x. Layout is approximate; the code milestones (M6a/M6b)
place the real Controls. The Strange Man figure is a placeholder silhouette (Art pass C).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "palette"))
import make_ui_kit as kit  # noqa: E402
from resurrect64 import hexc  # noqa: E402

OUT = "art/ui/mocks"
GW, GH, S = 270, 480, 4
FONT = ImageFont.truetype(kit.FONT_PATH, 16)
FONT_I = ImageFont.truetype("resources/fonts/monogram-extended-italic.ttf", 16)
UI = {name: Image.open(f"assets/ui/{name}.png").convert("RGBA") for name in (
    "panel", "window", "dialogue", "dialogue_arrow", "button_normal", "button_pressed",
    "button_disabled", "toast", "banner", "slider_track", "slider_fill", "slider_knob",
    "toggle_on", "toggle_off", "segment_normal", "segment_selected", "icon_pause",
    "icon_speaker", "icon_speaker_muted", "logo", "fuse_rope", "fuse_burnt", "fuse_spark")}
SCRIM = (*kit.INK0[:3], 178)


def nine(name, w, h):
    """Stretch a 9-slice piece to w x h game px (edges tiled, centre flat)."""
    src = UI[name]
    l, t, r, b = kit.MARGINS[name]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sw, sh = src.size
    cols = [(0, l, 0, l), (l, sw - r, l, w - r), (sw - r, sw, w - r, w)]
    rows = [(0, t, 0, t), (t, sh - b, t, h - b), (sh - b, sh, h - b, h)]
    for sx0, sx1, dx0, dx1 in cols:
        for sy0, sy1, dy0, dy1 in rows:
            if dx1 <= dx0 or dy1 <= dy0:
                continue
            piece = src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST)
            out.alpha_composite(piece, (dx0, dy0))
    return out


def text_img(s, colour, mult=1, italic=False):
    font = FONT_I if italic else FONT
    w = max(1, int(font.getlength(s)) + 2)
    im = Image.new("L", (w, 16), 0)
    ImageDraw.Draw(im).text((0, 0), s, font=font, fill=255)
    im = im.point(lambda v: 255 if v > 127 else 0)
    out = Image.new("RGBA", (w, 16), (*colour[:3], 255))
    out.putalpha(im)
    if mult > 1:
        out = out.resize((w * mult, 16 * mult), Image.NEAREST)
    return out


class Screen:
    def __init__(self, bg=None):
        self.px = Image.new("RGBA", (GW, GH), (0, 0, 0, 0))
        if bg == "forest":
            self.bg = Image.open("assets/backgrounds/forest.png").convert("RGBA")
        else:
            self.bg = Image.new("RGBA", (GW * S, GH * S), kit.INK0 if bg is None else bg)

    def put(self, img, x, y):
        self.px.alpha_composite(img, (int(x), int(y)))

    def text(self, s, x, y, colour=kit.CREAM, mult=1, centre=False, italic=False, shadow=True):
        im = text_img(s, colour, mult, italic)
        if centre:
            x = x - (int(FONT.getlength(s)) * mult) // 2
        if shadow:
            self.put(text_img(s, kit.INK0, mult, italic), x, y + mult)
        self.put(im, x, y)

    def panel(self, name, x, y, w, h):
        self.put(nine(name, w, h), x, y)

    def button(self, label, x, y, w, h=36, state="normal"):
        self.panel("button_" + state, x, y, w, h)
        dy = 2 if state == "pressed" else 0
        colour = kit.INK1 if state == "disabled" else kit.INK0
        self.text(label, x + w // 2, y + (h - 2) // 2 - 9 + dy, colour, 1, centre=True, shadow=False)

    def scrim(self):
        self.px.alpha_composite(Image.new("RGBA", (GW, GH), SCRIM))

    def save(self, name, vignette=True):
        out = self.bg.copy()
        if vignette:
            out = apply_vignette(out)
        out.alpha_composite(self.px.resize((GW * S, GH * S), Image.NEAREST))
        out.convert("RGB").save(os.path.join(OUT, f"mock_{name}.png"))


def apply_vignette(img, strength=0.55):
    """Subtle radial darkening toward ink (same maths as shaders/vignette.gdshader)."""
    a = np.asarray(img).astype(np.float32)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    u = (xx + 0.5) / w - 0.5
    v = ((yy + 0.5) / h - 0.5) * (h / w) * 0.6
    r = np.sqrt(u * u + v * v) / 0.62
    t = np.clip((r - 0.55) / 0.6, 0, 1)
    t = t * t * (3 - 2 * t) * strength
    ink = np.array(kit.INK0[:3], np.float32)
    a[..., :3] = a[..., :3] * (1 - t[..., None]) + ink * t[..., None]
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def goob(colour, frame=0):
    return Image.open(f"assets/goobs/vanilla/{colour}_yaw/frame_{frame:02d}.png").convert("RGBA")


def board_scene(s, cells, hand=3, fuse=True):
    """Scenario layout in game px: HUD at the top, board centred, fuse strip, stump + hand."""
    back = Image.open("assets/board/board_back.png").convert("RGBA")
    front = Image.open("assets/board/board_front.png").convert("RGBA")
    bx, by = 15, 150
    s.put(back, bx, by)
    for (c, r), col in cells.items():
        s.put(goob(col), bx + 8 + 32 * c, by + 8 + 32 * (5 - r) - 1)
    s.put(front, bx, by)
    # Stump + hand are at the hand scale (5x phys), drawn straight onto the background.
    stump = Image.open("assets/hand/forest_stump.png").convert("RGBA")
    big = stump.resize((stump.width * 5, stump.height * 5), Image.NEAREST)
    seat = 1700
    s.bg.alpha_composite(big, ((GW * S - big.width) // 2, seat - 34 * 5))
    xs = [540 + (i - (hand - 1) / 2) * 190 for i in range(hand)]
    for i, x in enumerate(xs):
        g = goob("blue").resize((160, 160), Image.NEAREST).rotate((i - (hand - 1) / 2) * -6, Image.NEAREST)
        s.bg.alpha_composite(g, (int(x - g.width / 2), seat - 165))
    if fuse:
        draw_fuse(s, 6, by + 216 + 4, GW - 12, burnt=0.45)


def draw_fuse(s, x, y, w, burnt):
    """24 px strip (9 game px): rope from the left, burning end at `burnt` of the way."""
    end = x + int(w * burnt)
    for tx in range(x, x + w, 8):
        tile = UI["fuse_burnt"] if tx < end else UI["fuse_rope"]
        s.put(tile.crop((0, 0, min(8, x + w - tx), 5)), tx, y + 2)
    s.put(UI["fuse_spark"].crop((11, 0, 22, 11)), end - 5, y - 1)


def hud(s, top=8, turn="Your turn", timer="24", timer_red=False):
    x0, w = 6, GW - 12
    # Portrait frame (Strange Man head crop comes in Art pass C).
    s.panel("window", x0, top, 40, 40)
    s.put(Image.new("RGBA", (28, 28), hexc("45293f")), x0 + 6, top + 6)
    s.text("?", x0 + 20, top + 12, kit.INK2, 2, centre=True, shadow=False)
    # Objective panel.
    s.panel("panel", x0 + 44, top, w - 44 - 44, 40)
    s.text("Objective", x0 + 52, top + 5, kit.GOLD_HI)
    s.text("Get four in a row", x0 + 52, top + 19, kit.CREAM)
    # Pause button (36x36 = 96 px at the 720 base).
    s.panel("button_normal", GW - 6 - 40, top + 2, 40, 38)
    s.put(UI["icon_pause"], GW - 6 - 24, top + 2 + 13)
    # Status row: run details, turn, timer.
    y = top + 46
    s.panel("panel", x0, y, w, 22)
    s.text("Scenario 1/1", x0 + 8, y + 3, kit.INK3 if False else hexc("9babb2"))
    s.text(turn, GW // 2, y + 3, hexc("8fd3ff") if turn == "Your turn" else hexc("f68181"), centre=True)
    s.text(timer, GW - 6 - 10 - int(FONT.getlength(timer)), y + 3, hexc("e83b3b") if timer_red else kit.CREAM, 1)


CELLS = {(0, 0): "red", (1, 0): "blue", (2, 0): "blue", (3, 0): "red", (3, 1): "blue",
         (2, 1): "red", (4, 0): "blue", (3, 2): "red"}


def mock_title():
    s = Screen("forest")
    logo = UI["logo"]
    s.put(logo, (GW - logo.width) // 2, 70)
    for i, (x, col) in enumerate(((50, "blue"), (110, "red"), (170, "blue"), (220, "red"))):
        g = goob(col)
        s.put(g, x - 16, 300 - (6 if i % 2 else 0))
    s.text("Tap to start", GW // 2, 236, kit.WHITE, 2, centre=True)
    s.button("Options", 75, 380, 120)
    s.button("Quit", 95, 422, 80)
    s.text("desktop only", GW // 2, 460, hexc("9babb2"), centre=True)
    s.save("1_title")


def mock_hud():
    s = Screen("forest")
    board_scene(s, CELLS)
    hud(s, timer="7", timer_red=True)
    # Aim lane: a toast above it.
    s.panel("toast", 85, 100, 100, 18)
    s.text("Column full", GW // 2, 100, kit.CREAM, centre=True)
    s.save("2_hud_toast_fuse")


def mock_dialogue():
    s = Screen(kit.INK0)
    bg = Image.new("RGBA", (GW * S, GH * S), (0, 0, 0, 255))
    d = ImageDraw.Draw(bg)
    # Oval light pool (pixel steps): concentric ellipses on the game grid.
    pool = Image.new("RGBA", (GW, GH), (0, 0, 0, 255))
    pd = ImageDraw.Draw(pool)
    for i, c in enumerate(("2e222f", "3e3546", "625565")):
        rx, ry = 70 - i * 16, 18 - i * 4
        pd.ellipse((135 - rx, 300 - ry, 135 + rx, 300 + ry), fill=hexc(c))
    s.bg = pool.resize((GW * S, GH * S), Image.NEAREST)
    # Placeholder figure (Art pass C): ~96x160 silhouette.
    fig = Image.new("RGBA", (96, 160), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fig)
    fd.ellipse((30, 6, 66, 44), fill=hexc("484a77"))
    fd.rounded_rectangle((18, 40, 78, 150), 12, fill=hexc("484a77"))
    s.put(fig, 135 - 48, 300 - 152)
    s.text("placeholder: Strange Man comes in Art pass C", GW // 2, 120, kit.INK2, centre=True, shadow=False)
    b = goob("blue")
    s.put(b, 60, 300 - 30)
    r = goob("red", 0)
    s.put(Image.open("assets/goobs/vanilla/red_pitch/frame_02.png").convert("RGBA"), 178, 300 - 22)
    # Skip button, top right (>= 96 px).
    s.button("Skip", GW - 6 - 64, 10, 64)
    # Dialogue box at the bottom of the safe area.
    s.panel("dialogue", 6, 340, GW - 12, 96)
    s.text("This is a land of Goobs.", 20, 356, kit.WHITE)
    s.put(UI["dialogue_arrow"], GW - 6 - 22, 340 + 96 - 18)
    s.save("3_strange_man_dialogue")


def mock_pause():
    s = Screen("forest")
    board_scene(s, CELLS)
    hud(s)
    s.scrim()
    w, h = 180, 172
    x, y = (GW - w) // 2, 130
    s.panel("window", x, y, w, h)
    s.text("Paused", GW // 2, y + 10, kit.GOLD_HI, 2, centre=True)
    for i, (label, st) in enumerate((("Resume", "normal"), ("Options", "pressed"), ("Quit", "normal"))):
        s.button(label, x + 20, y + 46 + i * 40, w - 40, 36, st)
    s.save("4_pause")


def mock_options():
    s = Screen("forest")
    board_scene(s, CELLS)
    hud(s)
    s.scrim()
    x, y, w = 8, 40, GW - 16
    rows = 7
    h = 40 + rows * 38 + 52
    s.panel("window", x, y, w, h)
    s.text("Options", GW // 2, y + 8, kit.GOLD_HI, 2, centre=True)
    ry = y + 40
    lx = x + 12

    def row_label(label, yy):
        s.text(label, lx, yy + 10, kit.CREAM)
    # Animation speed: segmented Normal / Fast / Skip.
    row_label("Speed", ry)
    sx = x + 84
    for i, (lab, sel) in enumerate((("Normal", True), ("Fast", False), ("Skip", False))):
        sw = 54 if i == 0 else 46
        s.panel("segment_selected" if sel else "segment_normal", sx, ry + 2, sw, 32)
        s.text(lab, sx + sw // 2, ry + 9, kit.INK0 if sel else kit.CREAM, centre=True, shadow=not sel)
        sx += sw - 1
    ry += 38
    for label, on in (("Haptics", True), ("Screen shake", True), ("Auto-flip coin", False)):
        row_label(label, ry)
        tog = UI["toggle_on" if on else "toggle_off"]
        s.put(tog.resize((tog.width, tog.height)), x + w - 12 - 30 - 26, ry + 11)
        s.text("On" if on else "Off", x + w - 12 - 20, ry + 10, kit.CREAM if on else hexc("9babb2"))
        ry += 38
    for label, val, muted in (("Master", 0.8, False), ("Music", 0.7, True), ("SFX", 0.8, False)):
        row_label(label, ry)
        tx, tw = x + 70, w - 70 - 46
        s.panel("slider_track", tx, ry + 14, tw, 7)
        fw = int(tw * val)
        s.panel("slider_fill", tx, ry + 14, fw, 7)
        s.put(UI["slider_knob"], tx + fw - 5, ry + 11)
        s.panel("segment_normal", x + w - 12 - 26, ry + 3, 26, 30)
        icon = UI["icon_speaker_muted" if muted else "icon_speaker"]
        s.put(icon, x + w - 12 - 26 + 8, ry + 13)
        ry += 38
    s.button("Back", GW // 2 - 50, ry + 4, 100)
    s.save("5_options")


def main():
    os.makedirs(OUT, exist_ok=True)
    mock_title()
    mock_hud()
    mock_dialogue()
    mock_pause()
    mock_options()
    print("wrote mocks to", OUT)


if __name__ == "__main__":
    main()
