"""Forest painted background test (Art pass A, GDD §Art direction).

Usage (from the repo root, with local ComfyUI running on 127.0.0.1:8188):
    python art/backgrounds/make_forest.py generate [seed ...]   # raw paintings -> art/backgrounds/forest_raw_<seed>.png
    python art/backgrounds/make_forest.py grade <raw.png>       # -> assets/backgrounds/forest.png

generate: Z-Image Turbo (Apache 2.0, local, free) through ComfyUI's HTTP API.
grade:    palette-grades the painting to Resurrect 64 while keeping smooth
          blends: each pixel is pulled toward a soft blend of its nearest
          palette colours (not hard-quantised), saturation and contrast are
          lowered, and a calmer, darker band is laid behind the board so Goobs
          and empty holes stay readable. No blur (Sean, 2026-11-19 playtest:
          the soft-focus version looked too blurry).
Output is 1080x1920 (shown cover-fit behind the 720x1280 UI base).
"""
import json
import os
import random
import sys
import time
import urllib.request

from PIL import Image, ImageEnhance

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "palette"))
from resurrect64 import PALETTE, oklab  # noqa: E402

COMFY = "http://127.0.0.1:8188"
W, H = 1088, 1920
OUT_W, OUT_H = 1080, 1920
RAW_DIR = "art/backgrounds"
OUT = "assets/backgrounds/forest.png"

PROMPT = (
    "Painted fantasy forest background for a mobile game, vertical composition, "
    "soft painterly brushwork, gentle storybook illustration. Tall old trees frame the "
    "left and right edges, warm sunlight filtering through the canopy at the top, "
    "mossy roots, ferns and small mushrooms along the bottom. The middle of the image is "
    "a calm, open, softly blurred clearing in shadow with little detail. Muted greens, "
    "teal shadows, warm golden highlights, atmospheric haze, depth of field, no characters, "
    "no text, no frame"
)

# Board band in output pixels at 1080x1920: the board zone is vertically centred
# (CLAUDE.md layout); the pixel board is 240x216 game px at 4x = 960x864.
BAND_TOP, BAND_BOTTOM = 470, 1450


def workflow(seed):
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "z_image_turbo_bf16.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b.safetensors", "type": "lumina2", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": PROMPT, "clip": ["2", 0]}},
        "5": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["4", 0]}},
        "6": {"class_type": "EmptySD3LatentImage", "inputs": {"width": W, "height": H, "batch_size": 1}},
        "7": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["1", 0], "shift": 3.0}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["7", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["6", 0],
            "seed": seed, "steps": 8, "cfg": 1.0, "sampler_name": "res_multistep",
            "scheduler": "simple", "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "forest_%d" % seed}},
    }


def _post(path, data):
    req = urllib.request.Request(COMFY + path, json.dumps(data).encode(), {"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req))


def generate(seed):
    pid = _post("/prompt", {"prompt": workflow(seed)})["prompt_id"]
    while True:
        hist = json.load(urllib.request.urlopen("%s/history/%s" % (COMFY, pid)))
        if pid in hist:
            break
        time.sleep(2)
    img = hist[pid]["outputs"]["10"]["images"][0]
    url = "%s/view?filename=%s&subfolder=%s&type=%s" % (COMFY, img["filename"], img["subfolder"], img["type"])
    path = os.path.join(RAW_DIR, "forest_raw_%d.png" % seed)
    with open(path, "wb") as f:
        f.write(urllib.request.urlopen(url).read())
    print("wrote", path)


def _soft_palette(rgb, cache, _labs=[oklab(c) for c in PALETTE]):
    """Inverse-distance blend of the 3 nearest Resurrect 64 colours (smooth, palette hues only)."""
    key = (rgb[0] >> 2, rgb[1] >> 2, rgb[2] >> 2)
    if key in cache:
        return cache[key]
    L = oklab(rgb)
    d = sorted((sum((L[j] - lab[j]) ** 2 for j in range(3)), i) for i, lab in enumerate(_labs))[:3]
    w = [1.0 / (dist + 1e-4) for dist, _ in d]
    t = sum(w)
    out = tuple(round(sum(PALETTE[i][k] * wi for (_, i), wi in zip(d, w)) / t) for k in range(3))
    cache[key] = out
    return out


def grade(raw_path):
    src = Image.open(raw_path).convert("RGB")
    # Cover-fit to 1080x1920.
    s = max(OUT_W / src.width, OUT_H / src.height)
    src = src.resize((round(src.width * s), round(src.height * s)), Image.LANCZOS)
    x0, y0 = (src.width - OUT_W) // 2, (src.height - OUT_H) // 2
    img = src.crop((x0, y0, x0 + OUT_W, y0 + OUT_H))
    # Softer and calmer than the pixel layer.
    img = ImageEnhance.Color(img).enhance(0.75)
    img = ImageEnhance.Contrast(img).enhance(0.85)
    # Palette grade: pull 70 % toward the soft palette blend.
    cache = {}
    px = img.load()
    for y in range(OUT_H):
        for x in range(OUT_W):
            c = px[x, y]
            p = _soft_palette(c, cache)
            px[x, y] = tuple(round(c[k] * 0.3 + p[k] * 0.7) for k in range(3))
    # Calm, darker band behind the board: dark tint from the palette (313638), feathered.
    dark = Image.new("RGB", img.size, PALETTE[34])
    out = Image.new("RGB", img.size)
    opx, spx, dpx = out.load(), img.load(), dark.load()
    feather = 220
    for y in range(OUT_H):
        if y < BAND_TOP - feather or y > BAND_BOTTOM + feather:
            t = 0.0
        elif BAND_TOP <= y <= BAND_BOTTOM:
            t = 1.0
        else:
            edge = BAND_TOP - y if y < BAND_TOP else y - BAND_BOTTOM
            t = 1.0 - edge / feather
            t = t * t * (3 - 2 * t)
        for x in range(OUT_W):
            c, d = spx[x, y], dpx[x, y]
            opx[x, y] = tuple(round(c[k] + (d[k] - c[k]) * 0.45 * t) for k in range(3))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "generate":
        for sd in (sys.argv[2:] or [str(random.randrange(1 << 30))]):
            generate(int(sd))
    elif len(sys.argv) == 3 and sys.argv[1] == "grade":
        grade(sys.argv[2])
    else:
        print(__doc__)
