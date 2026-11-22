"""Build a pixel-bold Monogram bitmap font for button text (Sean, M6c playtest:
button text "needs to be thicker and crisper").

Usage (from the repo root):
  python art/fonts/make_monogram_bold.py

Renders Monogram Extended at its native 16 px with no antialiasing, thickens every
glyph by one whole pixel to the right (classic pixel bold, so it stays two-colour
and grid-exact; a synthetic "embolden" would smear sub-pixels), and writes a BMFont:
  resources/fonts/monogram-bold.fnt + monogram-bold.png
Advance grows by 1 px so letters don't touch. Godot imports .fnt as a FontFile.
Monogram is CC0 (resources/fonts/CREDITS.md).
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "resources", "fonts", "monogram-extended.ttf")
OUT_DIR = os.path.join(ROOT, "resources", "fonts")
NAME = "monogram-bold"
SIZE = 16
CHARS = [c for c in range(32, 127)] + [c for c in range(160, 256)] + [0x2014, 0x2026]


def embolden(glyph):
    """Thicken each stroke one pixel to the right, but never close a one-pixel gap
    between two strokes (m, w, M, W, # … would turn into blobs): such a gap pixel
    stays empty."""
    src = lambda x, y: 0 <= x < glyph.width and glyph.getpixel((x, y)) > 127
    bold = Image.new("L", glyph.size, 0)
    for y in range(glyph.height):
        for x in range(glyph.width):
            if src(x, y):
                bold.putpixel((x, y), 255)
            elif src(x - 1, y) and not src(x + 1, y):
                bold.putpixel((x, y), 255)
    return bold


def main():
    font = ImageFont.truetype(SRC, SIZE)
    ascent, descent = font.getmetrics()
    line_h = ascent + descent
    cell_w = 10
    cell_h = line_h + 1
    cols = 16
    rows = (len(CHARS) + cols - 1) // cols
    atlas = Image.new("RGBA", (cols * cell_w, rows * cell_h), (0, 0, 0, 0))
    lines = []
    for i, code in enumerate(CHARS):
        ch = chr(code)
        glyph = Image.new("L", (cell_w, cell_h), 0)
        d = ImageDraw.Draw(glyph)
        d.fontmode = "1"
        d.text((0, 0), ch, font=font, fill=255)
        bold = embolden(glyph)
        advance = int(round(font.getlength(ch))) + 1
        width = max(advance, 1)
        cx, cy = (i % cols) * cell_w, (i // cols) * cell_h
        white = Image.new("RGBA", glyph.size, (255, 255, 255, 255))
        atlas.paste(white, (cx, cy), bold)
        lines.append(
            f"char id={code} x={cx} y={cy} width={width} height={line_h} "
            f"xoffset=0 yoffset=0 xadvance={advance} page=0 chnl=15"
        )
    atlas.save(os.path.join(OUT_DIR, NAME + ".png"))
    header = [
        f'info face="{NAME}" size={SIZE} bold=1 italic=0 charset="" unicode=1 stretchH=100 '
        "smooth=0 aa=1 padding=0,0,0,0 spacing=0,0",
        f"common lineHeight={line_h} base={ascent} scaleW={atlas.width} scaleH={atlas.height} "
        "pages=1 packed=0",
        f'page id=0 file="{NAME}.png"',
        f"chars count={len(lines)}",
    ]
    with open(os.path.join(OUT_DIR, NAME + ".fnt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(header + lines) + "\n")
    print("wrote", NAME, len(lines), "glyphs", atlas.size)


if __name__ == "__main__":
    main()
