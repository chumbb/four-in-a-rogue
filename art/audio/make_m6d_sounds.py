"""Build the M6d sounds (remaining slice §2B Sound events + forest ambience).

Usage (from the repo root):
  python art/audio/make_m6d_sounds.py

All synthesised for this project (no packs needed). Outputs (Ogg Vorbis, 44.1 kHz, via
ffmpeg) in assets/audio/sfx/; T = tactile, C = chiptune (slice §2B Sound):
  red_flash.ogg        C  opponent's column flashes red before his Goob: short low
                          two-note blip (falling)
  draw_sting.ogg       C  draw result: two even notes that settle on a neutral fifth
  forest_ambience.ogg  T  quiet forest loop for the coin flip + scenario: soft wind
                          and leaf rustle with a few distant bird chirps; ~16 s,
                          seamless (tail crossfaded into the head)
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from make_effect_sounds import SR, square, write_ogg  # noqa: E402
from make_reaction_sounds import _lowpass, _norm  # noqa: E402


def red_flash():
    a = square(659.25, 0.05, duty=0.5, vol=0.14)
    b = square(493.88, 0.08, duty=0.5, vol=0.14)
    return np.concatenate([a, b])


def draw_sting():
    notes = [392.0, 392.0, 523.25]
    parts = [square(notes[0], 0.12, duty=0.5, vol=0.16), np.zeros(int(SR * 0.04)),
             square(notes[1], 0.12, duty=0.5, vol=0.16), np.zeros(int(SR * 0.04))]
    top = square(notes[2], 0.45, duty=0.5, vol=0.12) + square(783.99, 0.45, duty=0.5, vol=0.08)
    parts.append(top)
    return np.concatenate(parts)


def _chirp(rng):
    """One distant bird call: 2-4 quick sine sweeps."""
    out = []
    base = rng.uniform(2600, 4200)
    for _ in range(rng.integers(2, 5)):
        sec = rng.uniform(0.05, 0.11)
        n = int(SR * sec)
        t = np.arange(n) / SR
        sweep = base * (1.0 + rng.uniform(-0.25, 0.35) * t / sec)
        phase = 2 * np.pi * np.cumsum(sweep) / SR
        env = np.sin(np.pi * t / sec) ** 2
        out.append(np.sin(phase) * env)
        out.append(np.zeros(int(SR * rng.uniform(0.03, 0.08))))
    return np.concatenate(out)


def forest_ambience(sec=16.0, seed=23):
    rng = np.random.default_rng(seed)
    fade = SR * 2
    n = int(SR * sec) + fade
    t = np.arange(n) / SR
    # Wind: low-passed noise, slowly swelling.
    wind = _lowpass(rng.standard_normal(n), 0.02)
    wind -= _lowpass(wind, 0.002)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * t / 7.3) * np.sin(2 * np.pi * t / 3.1 + 1.0)
    wind = _norm(wind * swell, 1.0)
    # Leaves: brighter noise in soft gusts.
    leaves = _lowpass(rng.standard_normal(n), 0.3)
    leaves -= _lowpass(leaves, 0.08)
    gust = np.clip(np.sin(2 * np.pi * t / 5.7 + 0.4), 0.0, None) ** 3
    leaves = _norm(leaves * (0.15 + gust), 1.0)
    out = wind * 0.55 + leaves * 0.25
    # A few distant birds (kept clear of the crossfade tail).
    for at in rng.uniform(0.5, sec - 1.5, 5):
        call = _chirp(rng) * rng.uniform(0.12, 0.22)
        start = int(SR * at)
        out[start:start + len(call)] += call
    body = out[: n - fade].copy()
    ramp = np.linspace(0.0, 1.0, fade)
    body[:fade] = body[:fade] * ramp + out[n - fade:] * (1.0 - ramp)
    return _norm(body, 0.2)


def main():
    write_ogg(red_flash(), "red_flash.ogg")
    write_ogg(draw_sting(), "draw_sting.ogg")
    write_ogg(forest_ambience(), "forest_ambience.ogg")


if __name__ == "__main__":
    main()
