"""Build the M6b sounds (pause menu, options, turn banners).

Usage (from the repo root):
  python art/audio/make_menu_sounds.py

All synthesised for this project (no packs needed). Outputs (Ogg Vorbis, 44.1 kHz, via
ffmpeg) in assets/audio/sfx/, all chiptune (C) per slice §2B Sound:
  pause_open.ogg     pause menu opens: two-note down-blip (G5 → C5)
  pause_close.ogg    pause menu closes / resume: two-note up-blip (C5 → G5, softer)
  slider_tick.ogg    volume slider step: tiny high tick
  turn_whoosh.ogg    turn banners: soft airy whoosh (filtered noise, slow swell), not a
                     beep (Sean, 2026-11-20); the opponent's plays ~10 % lower (Sfx)
Button taps reuse ui_tap.ogg (make_flow_sounds.py).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from make_effect_sounds import SR, square, write_ogg  # noqa: E402


def pause_open():
    return np.concatenate([square(783.99, 0.06, duty=0.5, vol=0.18), square(523.25, 0.12, duty=0.5, vol=0.18)])


def pause_close():
    return np.concatenate([square(523.25, 0.05, duty=0.5, vol=0.15), square(783.99, 0.1, duty=0.5, vol=0.15)])


def slider_tick():
    return square(1567.98, 0.018, duty=0.25, vol=0.1)


def turn_whoosh(sec=0.45, seed=11):
    """Soft whoosh: white noise through a gentle band-pass whose centre sweeps up
    then down, under a slow swell; no tone, no hard attack."""
    rng = np.random.default_rng(seed)
    n = int(SR * sec)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    out = np.empty(n)
    lo = hi = 0.0
    for i in range(n):
        x = t[i] / sec
        # Low-pass cutoff swells 0.03 → 0.12 → 0.04 (fraction per sample).
        a = 0.03 + 0.09 * np.sin(np.pi * x) ** 2
        lo += a * (noise[i] - lo)
        hi += 0.004 * (lo - hi)
        out[i] = lo - hi  # remove the rumble
    env = np.sin(np.pi * np.clip(t / sec, 0, 1)) ** 1.6
    out = out * env
    return out / np.max(np.abs(out)) * 0.16


def main():
    write_ogg(pause_open(), "pause_open.ogg")
    write_ogg(pause_close(), "pause_close.ogg")
    write_ogg(slider_tick(), "slider_tick.ogg")
    write_ogg(turn_whoosh(), "turn_whoosh.ogg")
    print("wrote menu sounds to assets/audio/sfx")


if __name__ == "__main__":
    main()
