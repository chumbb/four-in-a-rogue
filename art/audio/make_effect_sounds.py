"""Build the M5 Goob effect + scoring sounds.

Usage (from the repo root):
  python art/audio/make_effect_sounds.py <packs_dir>

<packs_dir> holds the unpacked Godot Asset Store packs (see assets/audio/CREDITS.md):
  starter-kit-3d-platformer/, starter-kit-city-builder/, starter-kit-match-3/, menu-sound-pack/

Outputs (Ogg Vorbis, 44.1 kHz, via ffmpeg) in assets/audio/sfx/:
  effect_flip.ogg     Convincing: spin swish + click (Kenney tile-swap + placement-a)
  effect_crunch.ogg   Fat: destroy crunch (Kenney break)
  effect_popular.ogg  Popular: the extra Vanilla pops out (Kenney tile-land)
  effect_fizzle.ogg   no target: water putting out a candle, a soft "tsst" (synthesised,
                      fizzle A1 in make_snes_coin_fizzle_options.py; Sean 2026-11-23)
  effect_resurrect.ogg  Occult / any "bring back" effect: a breathy swell that rises,
                      a faint ghostly hum, a soft hollow pop (synthesised, option A in
                      make_resurrect_options.py; Sean 2026-11-23)
  score_0..8.ogg      scoring ladder: chiptune square blips, one major-scale step each (C5 up)
  score_collapse.ogg  multipliers collapse into the sum: quick chiptune down-up sweep
  score_recognise.ogg the scored Goobs light up: bright chiptune up-arpeggio (G4 C5 E5 G5 C6)
Slice §2B Sound: effects are tactile, scoring is chiptune; ticks rise one note per Goob,
the sum lands on the top note (the scenario plays the next ladder note for it).
"""
import glob
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
FFMPEG = r"C:\Users\Sean\Apps\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe"
OUT_DIR = "assets/audio/sfx"
# C major from C5: C D E F G A B C D
LADDER_HZ = [523.25, 587.33, 659.25, 698.46, 783.99, 880.00, 987.77, 1046.50, 1174.66]


def find(packs, pattern):
    hits = glob.glob(os.path.join(packs, "**", pattern), recursive=True)
    if not hits:
        sys.exit(f"not found under {packs}: {pattern}")
    return hits[0]


def ffmpeg(*args):
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", *args], check=True)


def write_ogg(samples, name):
    samples = np.clip(samples, -1.0, 1.0)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((samples * 32767).astype(np.int16).tobytes())
        ffmpeg("-i", wav, "-c:a", "libvorbis", "-q:a", "6", os.path.join(OUT_DIR, name))


def square(freq, sec, duty=0.25, vol=0.28):
    t = np.arange(int(SR * sec)) / SR
    wave_ = np.where((t * freq) % 1.0 < duty, 1.0, -1.0)
    env = np.minimum(1.0, t / 0.004) * np.exp(-t / (sec * 0.45))
    return wave_ * env * vol


def write_fizzle():
    import make_snes_coin_fizzle_options as opt  # lazy: that module imports this one
    write_ogg(opt.fizzle_a1(), "effect_fizzle.ogg")


def write_resurrect():
    import make_resurrect_options as opt  # lazy: that module imports this one
    write_ogg(opt.option_a(), "effect_resurrect.ogg")


def main():
    packs = sys.argv[1]
    out = lambda n: os.path.join(OUT_DIR, n)
    swap = find(packs, "tile-swap.ogg")
    click = find(packs, "placement-a.ogg")
    # Flip: swish, then the click as it comes round (~0.18 s in).
    ffmpeg("-i", swap, "-i", click, "-filter_complex",
           "[0:a]volume=0.8[a];[1:a]adelay=180|180[b];[a][b]amix=inputs=2:normalize=0[m]",
           "-map", "[m]", "-ac", "1", "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "6", out("effect_flip.ogg"))
    ffmpeg("-i", find(packs, "break.ogg"), "-ac", "1", "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "6", out("effect_crunch.ogg"))
    ffmpeg("-i", find(packs, "tile-land.ogg"), "-ac", "1", "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "6", out("effect_popular.ogg"))
    write_fizzle()
    write_resurrect()
    for i, hz in enumerate(LADDER_HZ):
        write_ogg(square(hz, 0.16), f"score_{i}.ogg")
    sweep = np.concatenate([square(hz, 0.035, vol=0.2) for hz in [1046.5, 783.99, 659.25, 523.25, 659.25, 783.99]])
    write_ogg(sweep, "score_collapse.ogg")
    arp = np.concatenate([square(hz, 0.06, duty=0.5, vol=0.22) for hz in [392.0, 523.25, 659.25, 783.99]] + [square(1046.5, 0.3, duty=0.5, vol=0.22)])
    write_ogg(arp, "score_recognise.ogg")
    print("wrote effect + scoring sounds to", OUT_DIR)


if __name__ == "__main__":
    main()
