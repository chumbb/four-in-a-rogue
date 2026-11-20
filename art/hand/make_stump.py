"""Forest hand prop: the oak stump the hand Goobs rest on (Sean, 2026-11-19).

Usage: python art/hand/make_stump.py   (from the repo root)

Input : art/hand/forest_stump_pixellab.png  (PixelLab Pro, 200x144, Resurrect 64 palette)
Output: assets/hand/forest_stump.png        200x240: quantised to Resurrect 64, the trunk
        extended down by repeating its lower band so it always runs off the screen bottom.
Shown at the hand Goobs' pixel scale (5x at 1080 wide). Seat row and top width are
STUMP_SEAT_Y / STUMP_TOP_WIDTH in scripts/scenario/scenario_placeholder.gd.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "palette"))
from resurrect64 import quantize  # noqa: E402

SRC = "art/hand/forest_stump_pixellab.png"
OUT = "assets/hand/forest_stump.png"
OUT_H = 240
BAND = (96, 144)  # trunk rows repeated below the source

src = quantize(Image.open(SRC))
out = Image.new("RGBA", (src.width, OUT_H), (0, 0, 0, 0))
out.paste(src, (0, 0))
band = src.crop((0, BAND[0], src.width, BAND[1]))
y = src.height
while y < OUT_H:
    out.paste(band, (0, y))
    y += band.height
os.makedirs(os.path.dirname(OUT), exist_ok=True)
out.save(OUT)
print("wrote", OUT, out.size)
