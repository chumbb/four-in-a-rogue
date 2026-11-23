"""Build the M6d sounds (remaining slice §2B Sound events).

Usage (from the repo root):
  python art/audio/make_m6d_sounds.py

All synthesised for this project (no packs needed). Outputs (Ogg Vorbis, 44.1 kHz, via
ffmpeg) in assets/audio/sfx/; T = tactile, C = chiptune (slice §2B Sound):
  red_flash.ogg        C  opponent's column flashes red before his Goob: short low
                          two-note blip (falling)
  draw_sting.ogg       C  draw result: two even notes that settle on a neutral fifth
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from make_effect_sounds import SR, square, write_ogg  # noqa: E402


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


def main():
    write_ogg(red_flash(), "red_flash.ogg")
    write_ogg(draw_sting(), "draw_sting.ogg")


if __name__ == "__main__":
    main()
