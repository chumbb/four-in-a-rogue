"""Listening options for Sean (2026-11-23). Sean picked A (ghost rise): it
ships as effect_resurrect.ogg via make_effect_sounds.write_resurrect().
the resurrect sound (Occult, and any later "bring back" effect). It plays as the
destroyed Goob rises out of the Occult Goob and arcs over the board (~0.7 s),
before its normal drop + land. Effects are tactile (slice §2B Sound), no SNES
treatment; the opponent's plays ~10 % lower automatically.

  A_ghost_rise    a soft breathy swell that rises and opens up, then a gentle
                  hollow "pop" as the Goob is back (airy, a bit spooky)
  B_unearthed     a low earthy rumble and scrape, like it's dug up out of the
                  ground, rising into a dull wooden "thunk" (heavier, physical)
  C_reverse_bell  a bell played backwards: a glassy shimmer swells up and
                  stops dead on a soft pluck (eerie, magical)

Usage (from the repo root):
  python art/audio/make_resurrect_options.py

Writes art/audio/compare_resurrect/*.ogg.
"""
import os
import sys

import numpy as np
from scipy.signal import butter, sosfilt

sys.path.insert(0, os.path.dirname(__file__))
import make_effect_sounds as fx  # noqa: E402
from make_effect_sounds import SR, write_ogg  # noqa: E402

COMPARE_DIR = os.path.join(os.path.dirname(__file__), "compare_resurrect")
rng = np.random.default_rng(23)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def lp(x, hz, order=2):
    return sosfilt(butter(order, hz, "lowpass", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], "bandpass", fs=SR, output="sos"), x)


def norm(x, peak):
    return x / np.max(np.abs(x)) * peak


def sweep_bp(noise, f_from, f_to, width=0.6, blocks=48):
    """Band-pass noise whose centre glides from f_from to f_to (block-wise)."""
    out = np.zeros_like(noise)
    n = len(noise)
    edges = np.linspace(0, n, blocks + 1).astype(int)
    filtered = {}
    for i in range(blocks):
        f = f_from * (f_to / f_from) ** (i / (blocks - 1))
        key = round(f, 1)
        if key not in filtered:
            filtered[key] = bp(noise, f * (1 - width / 2), f * (1 + width / 2))
        a, b = edges[i], edges[i + 1]
        out[a:b] = filtered[key][a:b]
    return lp(out, 6000)


def hollow_pop(sec=0.12, f=330.0):
    """A soft, round 'pop': a quick downward pitch blip with a little air."""
    t = t_axis(sec)
    freq = f * (1.6 - 0.6 * np.minimum(t / 0.03, 1.0))
    tone = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 38)
    air = lp(rng.standard_normal(len(t)), 2500) * np.exp(-t * 90) * 0.25
    return tone + air


def option_a():
    sec = 0.62
    t = t_axis(sec)
    noise = rng.standard_normal(len(t))
    breath = sweep_bp(noise, 350, 2400, width=0.7)
    env = (t / sec) ** 1.8 * (1 - np.exp(-(sec - t) * 60))
    # A faint rising fifth underneath gives it a ghostly voice.
    f = 220 * (1.5 ** (t / sec))
    hum = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.18 * (t / sec) ** 2
    swell = norm(breath * env, 0.55) + hum
    out = np.concatenate([swell, hollow_pop(0.14, 360) * 0.8, np.zeros(int(SR * 0.08))])
    return norm(out, 0.8)


def option_b():
    sec = 0.6
    t = t_axis(sec)
    noise = rng.standard_normal(len(t))
    rumble = lp(noise, 180, 4) * (0.4 + 0.6 * t / sec)
    # Gritty scrape: sparse clicks through a rising band.
    grit = (rng.random(len(t)) < 0.02 + 0.08 * t / sec) * rng.standard_normal(len(t))
    scrape = sweep_bp(grit + noise * 0.15, 500, 1800, width=0.8)
    env = np.minimum(t / 0.08, 1.0) * (1 - np.exp(-(sec - t) * 50))
    body = norm(rumble, 0.5) + norm(scrape, 0.35)
    # Dull wooden thunk as it pops free.
    tt = t_axis(0.22)
    thunk = (np.sin(2 * np.pi * 150 * tt) * 0.9 + np.sin(2 * np.pi * 410 * tt) * 0.35) * np.exp(-tt * 28)
    thunk += lp(rng.standard_normal(len(tt)), 1200) * np.exp(-tt * 70) * 0.4
    out = np.concatenate([body * env, thunk, np.zeros(int(SR * 0.06))])
    return norm(out, 0.8)


def option_c():
    # A bell (inharmonic partials) with a long ring, then reversed: it swells
    # up and stops dead; a soft pluck lands on the stop.
    ring = 0.65
    t = t_axis(ring)
    partials = [(1.0, 1.0), (2.76, 0.5), (5.4, 0.28), (8.93, 0.14)]
    base = 660.0
    bell = np.zeros(len(t))
    for ratio, amp in partials:
        bell += amp * np.sin(2 * np.pi * base * ratio * t) * np.exp(-t * (3.5 + ratio * 1.2))
    shimmer = bp(rng.standard_normal(len(t)), 3000, 7000) * np.exp(-t * 6) * 0.08
    rev = (bell + shimmer)[::-1]
    tt = t_axis(0.25)
    pluck = np.sin(2 * np.pi * base * tt) * np.exp(-tt * 22) * 0.6
    pluck += np.sin(2 * np.pi * base * 2 * tt) * np.exp(-tt * 40) * 0.2
    out = np.concatenate([norm(rev, 0.6), pluck, np.zeros(int(SR * 0.05))])
    return norm(lp(out, 7000), 0.75)


def main():
    os.makedirs(COMPARE_DIR, exist_ok=True)
    fx.OUT_DIR = COMPARE_DIR
    write_ogg(option_a(), "A_ghost_rise.ogg")
    write_ogg(option_b(), "B_unearthed.ogg")
    write_ogg(option_c(), "C_reverse_bell.ogg")
    print("wrote", COMPARE_DIR)


if __name__ == "__main__":
    main()
