"""Softer press start + UI tap options for Sean to compare (2026-11-23: the current
ones are too harsh). Not wired into the game; nothing changes until Sean picks.

Usage (from the repo root):
  python art/audio/make_soft_ui_options.py

Writes art/audio/compare_soft_ui/<option>_press_start.ogg and <option>_ui_tap.ogg:
  A  triangle wave (mellow chiptune), same notes, soft attack, quieter
  B  square run through a low-pass, one octave lower, rounded attack
  C  sine "bubble": short pitch bend up, very soft (more tactile than chiptune)
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import make_effect_sounds as fx  # noqa: E402
from make_effect_sounds import SR, square, write_ogg  # noqa: E402
from make_reaction_sounds import _lowpass  # noqa: E402

fx.OUT_DIR = os.path.join(os.path.dirname(__file__), "compare_soft_ui")


def _env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(1.0, t / attack) * np.exp(-t / decay)


def tri(freq, sec, vol, attack=0.012):
    n = int(SR * sec)
    t = np.arange(n) / SR
    wave = 2.0 * np.abs(2.0 * ((t * freq) % 1.0) - 1.0) - 1.0
    return wave * _env(n, attack, sec * 0.45) * vol


def soft_square(freq, sec, vol, attack=0.01):
    raw = square(freq, sec, duty=0.5, vol=1.0)
    smooth = _lowpass(raw, 0.08)
    n = len(smooth)
    return smooth * _env(n, attack, sec * 0.5) * vol


def bubble(f0, f1, sec, vol):
    n = int(SR * sec)
    t = np.arange(n) / SR
    freq = f0 + (f1 - f0) * np.minimum(1.0, t / (sec * 0.6))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(phase) * _env(n, 0.006, sec * 0.35) * vol


OPTIONS = {
    "A": (
        lambda: np.concatenate([tri(523.25, 0.08, 0.2), tri(783.99, 0.18, 0.2)]),
        lambda: tri(659.25, 0.06, 0.16),
    ),
    "B": (
        lambda: np.concatenate([soft_square(261.63, 0.08, 0.2), soft_square(392.0, 0.18, 0.2)]),
        lambda: soft_square(329.63, 0.06, 0.18),
    ),
    "C": (
        lambda: np.concatenate([bubble(440, 660, 0.09, 0.22), bubble(660, 990, 0.16, 0.2)]),
        lambda: bubble(520, 780, 0.06, 0.2),
    ),
}


def main():
    os.makedirs(fx.OUT_DIR, exist_ok=True)
    for name, (press, tap) in OPTIONS.items():
        write_ogg(press(), "%s_press_start.ogg" % name)
        write_ogg(tap(), "%s_ui_tap.ogg" % name)
    print("wrote options to", fx.OUT_DIR)


if __name__ == "__main__":
    main()
