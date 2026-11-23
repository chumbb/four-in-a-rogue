"""Build the M6a flow sounds (title, Strange Man, coin flip).

Usage (from the repo root):
  python art/audio/make_flow_sounds.py

All synthesised for this project (no packs needed). Outputs (Ogg Vorbis, 44.1 kHz, via
ffmpeg) in assets/audio/sfx/:
  press_start.ogg  title Press Start: soft triangle two-note up-blip (C5 → G5)  (C)
  ui_tap.ogg       button tap: short sine "bubble" bending up                   (C)
  (Sean, 2026-11-23: the old square blips were too harsh; Sean picked option A for
  press start and option C for the tap.)
  page_click.ogg   Strange Man page advance: tiny high square click             (C)
  first_sting.ogg  coin result flash + "goes first" banner: chiptune fanfare     (C)
  coin_whirr.ogg   coin spinning in the air (~0.6 s): fluttering filtered noise  (T)
  coin_clink.ogg   coin lands: short wooden clink (two damped partials + tick)   (T)
Reused, not built here: swipe whoosh = fly_swish.ogg, intro Goobs pop = draw_pop.ogg.
Slice §2B Sound: UI/banners chiptune (C), physical things tactile (T).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from make_effect_sounds import SR, square, write_ogg  # noqa: E402


def silence(sec):
    return np.zeros(int(SR * sec))


def _env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(1.0, t / attack) * np.exp(-t / decay)


def tri(freq, sec, vol, attack=0.012):
    n = int(SR * sec)
    t = np.arange(n) / SR
    wave = 2.0 * np.abs(2.0 * ((t * freq) % 1.0) - 1.0) - 1.0
    return wave * _env(n, attack, sec * 0.45) * vol


def bubble(f0, f1, sec, vol):
    n = int(SR * sec)
    t = np.arange(n) / SR
    freq = f0 + (f1 - f0) * np.minimum(1.0, t / (sec * 0.6))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(phase) * _env(n, 0.006, sec * 0.35) * vol


def press_start():
    return np.concatenate([tri(523.25, 0.08, 0.2), tri(783.99, 0.18, 0.2)])


def ui_tap():
    return bubble(520, 780, 0.06, 0.2)


def page_click():
    return square(1318.5, 0.025, duty=0.5, vol=0.12)


def first_sting():
    notes = [523.25, 659.25, 783.99]
    parts = [square(hz, 0.07, duty=0.5, vol=0.2) for hz in notes]
    parts.append(square(1046.5, 0.38, duty=0.5, vol=0.2))
    return np.concatenate(parts)


def coin_whirr(sec=0.6, seed=3):
    rng = np.random.default_rng(seed)
    n = int(SR * sec)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # One-pole low-pass, then a flutter at a rising spin rate.
    out = np.empty(n)
    a, y = 0.08, 0.0
    for i in range(n):
        y += a * (noise[i] - y)
        out[i] = y
    rate = 14.0 + 10.0 * t / sec
    flutter = 0.55 + 0.45 * np.sin(2 * np.pi * np.cumsum(rate) / SR) ** 2
    env = np.minimum(1.0, t / 0.05) * np.minimum(1.0, (sec - t) / 0.12)
    out = out * flutter * env
    return out / np.max(np.abs(out)) * 0.22


def coin_clink(sec=0.22):
    t = np.arange(int(SR * sec)) / SR
    body = 0.6 * np.sin(2 * np.pi * 820 * t) * np.exp(-t / 0.035)
    ring = 0.3 * np.sin(2 * np.pi * 2140 * t) * np.exp(-t / 0.02)
    tick = np.random.default_rng(5).standard_normal(len(t)) * np.exp(-t / 0.003) * 0.4
    return (body + ring + tick) * 0.45


def main():
    write_ogg(press_start(), "press_start.ogg")
    write_ogg(ui_tap(), "ui_tap.ogg")
    write_ogg(page_click(), "page_click.ogg")
    write_ogg(first_sting(), "first_sting.ogg")
    write_ogg(coin_whirr(), "coin_whirr.ogg")
    write_ogg(coin_clink(), "coin_clink.ogg")
    print("wrote flow sounds to assets/audio/sfx")


if __name__ == "__main__":
    main()
