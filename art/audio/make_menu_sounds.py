"""Build the M6b sounds (pause menu, options, turn banners).

Usage (from the repo root):
  python art/audio/make_menu_sounds.py

All synthesised for this project (no packs needed). Outputs (Ogg Vorbis, 44.1 kHz, via
ffmpeg) in assets/audio/sfx/, all chiptune (C) per slice §2B Sound:
  pause_open.ogg     pause menu opens: two-note down-blip (G5 → C5)
  pause_close.ogg    pause menu closes / resume: two-note up-blip (C5 → G5, softer)
  slider_tick.ogg    volume slider step: tiny high tick
  turn_player.ogg    blue "Your turn" banner: bright rising arpeggio
  turn_opponent.ogg  red "Opponent's turn" banner: lower falling figure, thinner duty
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


def turn_player():
    notes = [(587.33, 0.06), (739.99, 0.06), (880.0, 0.06), (1174.66, 0.2)]
    return np.concatenate([square(hz, sec, duty=0.5, vol=0.17) for hz, sec in notes])


def turn_opponent():
    notes = [(440.0, 0.07), (349.23, 0.07), (293.66, 0.22)]
    return np.concatenate([square(hz, sec, duty=0.25, vol=0.17) for hz, sec in notes])


def main():
    write_ogg(pause_open(), "pause_open.ogg")
    write_ogg(pause_close(), "pause_close.ogg")
    write_ogg(slider_tick(), "slider_tick.ogg")
    write_ogg(turn_player(), "turn_player.ogg")
    write_ogg(turn_opponent(), "turn_opponent.ogg")
    print("wrote menu sounds to assets/audio/sfx")


if __name__ == "__main__":
    main()
