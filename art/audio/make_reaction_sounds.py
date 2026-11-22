"""Build the M6c sounds (play flips, low-time fuse, win/lose lead-ins).

Usage (from the repo root):
  python art/audio/make_reaction_sounds.py

All synthesised for this project (no packs needed). Outputs (Ogg Vorbis, 44.1 kHz, via
ffmpeg) in assets/audio/sfx/; T = tactile, C = chiptune (slice §2B Sound):
  goob_flip.ogg        T  a Goob flips out of the hand / up from behind the board: short
                          airy flick (filtered noise, fast swell) + a soft tick
  fuse_burn.ogg        T  low-time fuse: crackling hiss, seamless ~1 s loop
  win_sting.ogg        C  player win lead-in: rising major arpeggio, held top note
  lose_sting.ogg       C  opponent win lead-in: falling minor line
  portrait_crack.ogg   T  opponent portrait cracks: three dry snaps
  portrait_explode.ogg T  portrait bursts: noise burst over a low thump
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from make_effect_sounds import SR, square, write_ogg  # noqa: E402


def _lowpass(x, a):
    out = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        out[i] = acc
    return out


def _norm(x, vol):
    return x / np.max(np.abs(x)) * vol


def goob_flip(sec=0.16, seed=5):
    rng = np.random.default_rng(seed)
    n = int(SR * sec)
    t = np.arange(n) / SR
    air = _lowpass(rng.standard_normal(n), 0.18)
    air -= _lowpass(air, 0.01)
    env = np.minimum(1.0, t / 0.03) * np.exp(-np.maximum(0.0, t - 0.03) / 0.04)
    tick = np.zeros(n)
    tick_part = square(2093.0, 0.02, duty=0.25, vol=0.08)
    start = int(SR * 0.05)
    tick[start:start + len(tick_part)] += tick_part[: n - start]
    return _norm(air * env, 0.18) + tick


def fuse_burn(sec=1.0, seed=7):
    """Hiss with random crackle pops; the loop seam is crossfaded."""
    rng = np.random.default_rng(seed)
    n = int(SR * sec)
    hiss = _lowpass(rng.standard_normal(n + SR // 10), 0.35)
    hiss -= _lowpass(hiss, 0.02)
    hiss *= 0.25
    for _ in range(28):
        at = rng.integers(0, len(hiss) - 400)
        pop = rng.standard_normal(rng.integers(60, 300)) * np.exp(-np.arange(1) / 1.0)
        pop *= np.exp(-np.arange(len(pop)) / (len(pop) / 4))
        hiss[at:at + len(pop)] += pop * rng.uniform(0.4, 1.0)
    # Crossfade the tail into the head so the loop has no click.
    fade = SR // 10
    body = hiss[:n].copy()
    ramp = np.linspace(0.0, 1.0, fade)
    body[:fade] = body[:fade] * ramp + hiss[n:n + fade] * (1.0 - ramp)
    return _norm(body, 0.14)


def win_sting():
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = [square(f, 0.09, duty=0.5, vol=0.2) for f in notes[:-1]]
    parts.append(square(notes[-1], 0.5, duty=0.5, vol=0.2))
    return np.concatenate(parts)


def lose_sting():
    notes = [523.25, 466.16, 392.0, 311.13]
    parts = [square(f, 0.14, duty=0.5, vol=0.18) for f in notes[:-1]]
    parts.append(square(notes[-1], 0.55, duty=0.5, vol=0.18))
    return np.concatenate(parts)


def portrait_crack(seed=9):
    rng = np.random.default_rng(seed)
    out = np.zeros(int(SR * 0.5))
    for k, at in enumerate([0.0, 0.18, 0.36]):
        n = int(SR * 0.05)
        snap = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * 0.006))
        snap -= _lowpass(snap, 0.05)
        start = int(SR * at)
        out[start:start + n] += snap * (0.7 + 0.15 * k)
    return _norm(out, 0.3)


def portrait_explode(sec=0.6, seed=13):
    rng = np.random.default_rng(seed)
    n = int(SR * sec)
    t = np.arange(n) / SR
    burst = _lowpass(rng.standard_normal(n), 0.25) * np.exp(-t / 0.12)
    thump = np.sin(2 * np.pi * (90 - 50 * t) * t) * np.exp(-t / 0.15)
    return _norm(burst * 0.7 + thump, 0.32)


def main():
    write_ogg(goob_flip(), "goob_flip.ogg")
    write_ogg(fuse_burn(), "fuse_burn.ogg")
    write_ogg(win_sting(), "win_sting.ogg")
    write_ogg(lose_sting(), "lose_sting.ogg")
    write_ogg(portrait_crack(), "portrait_crack.ogg")
    write_ogg(portrait_explode(), "portrait_explode.ogg")


if __name__ == "__main__":
    main()
