"""Title screen painted background: a Goob kingdom vista (Sean, 2026-11-20 Art B review).

Usage (from the repo root, with local ComfyUI running on 127.0.0.1:8188):
    python art/backgrounds/make_title.py generate [seed ...]   # -> art/backgrounds/title_raw_<seed>.png
    python art/backgrounds/make_title.py grade <raw.png>       # -> assets/backgrounds/title.png

Same pipeline as make_forest.py (Z-Image Turbo, then a soft Resurrect 64 palette
grade), without the board band. Sean wants "realistic" painted Goobs scattered in the
scene (not the game-piece sprites, not in a row), and a calm sky at the top for the logo.
"""
import json
import os
import sys
import time
import urllib.request

from PIL import Image, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_forest as mf  # noqa: E402

RAW_DIR = "art/backgrounds"
OUT = "assets/backgrounds/title.png"

PROMPT = (
    "Painted fantasy landscape for a mobile game title screen, vertical composition, "
    "soft painterly storybook illustration. The top 40 percent of the image is an empty, "
    "calm warm dusk sky with a few soft clouds and nothing else. Below it, a vast kingdom "
    "vista: rolling green hills and meadows, a winding river, and small in the far distance, "
    "low on the horizon in the centre of the image, a faded, slightly crumbling castle with "
    "round towers half lost in golden haze. "
    "Scattered naturally across the meadow in the lower half, a few small round smooth "
    "creatures like plump living coins, glossy blue ones and red ones, with simple cute faces, "
    "no arms, no legs, resting in the grass at different distances, one peeking from behind "
    "a rock. Wildflowers and tall grass in the foreground. "
    "Muted greens, teal shadows, warm golden light, atmospheric depth, no people, "
    "no text, no frame"
)


def generate(seed):
    mf.PROMPT = PROMPT
    wf = mf.workflow(seed)
    wf["10"]["inputs"]["filename_prefix"] = "title_%d" % seed
    pid = mf._post("/prompt", {"prompt": wf})["prompt_id"]
    while True:
        hist = json.load(urllib.request.urlopen("%s/history/%s" % (mf.COMFY, pid)))
        if pid in hist:
            break
        time.sleep(2)
    img = hist[pid]["outputs"]["10"]["images"][0]
    url = "%s/view?filename=%s&subfolder=%s&type=%s" % (mf.COMFY, img["filename"], img["subfolder"], img["type"])
    path = os.path.join(RAW_DIR, "title_raw_%d.png" % seed)
    with open(path, "wb") as f:
        f.write(urllib.request.urlopen(url).read())
    print("wrote", path)


def grade(raw_path):
    src = Image.open(raw_path).convert("RGB")
    s = max(mf.OUT_W / src.width, mf.OUT_H / src.height)
    src = src.resize((round(src.width * s), round(src.height * s)), Image.LANCZOS)
    x0, y0 = (src.width - mf.OUT_W) // 2, (src.height - mf.OUT_H) // 2
    img = src.crop((x0, y0, x0 + mf.OUT_W, y0 + mf.OUT_H))
    img = ImageEnhance.Color(img).enhance(0.85)
    img = ImageEnhance.Contrast(img).enhance(0.9)
    cache = {}
    px = img.load()
    for y in range(mf.OUT_H):
        for x in range(mf.OUT_W):
            c = px[x, y]
            p = mf._soft_palette(c, cache)
            px[x, y] = tuple(round(c[k] * 0.3 + p[k] * 0.7) for k in range(3))
    img.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "generate":
        for a in sys.argv[2:] or ["1", "2", "3"]:
            generate(int(a))
    elif len(sys.argv) == 3 and sys.argv[1] == "grade":
        grade(sys.argv[2])
    else:
        print(__doc__)
