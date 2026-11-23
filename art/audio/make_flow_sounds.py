"""Build the M6a flow sounds (title, Strange Man, coin flip).

Usage (from the repo root):
  python art/audio/make_flow_sounds.py

All synthesised for this project (no packs needed). Outputs (Ogg Vorbis, 44.1 kHz, via
ffmpeg) in assets/audio/sfx/:
  press_start.ogg  title Press Start: SNES wood block two-note up (C5 → G5) + echo  (C)
  ui_tap.ogg       every UI press: SNES wood block tap, dry (740 Hz, low-passed)  (C)
  (Sean, 2026-11-23: UI is SNES-like / 16-bit; he picked the wood block, option B in
  make_snes_coin_fizzle_options.py, after the felt tap and bubble were rejected.)
  first_sting.ogg  coin result flash + "goes first" banner: chiptune fanfare     (C)
  coin_whirr.ogg   thumb flick: nail click + ringing metal coin, shimmering as it spins (~0.65 s)  (T)
  coin_clink.ogg   coin lands on wood: clack, short ring, settling rattle         (T)
  (Sean, 2026-11-23: a real metal coin flicked by a thumb; picked flick B "warm" + the table landing.)
Reused, not built here: Strange Man page advance = ui_tap.ogg (Sean, 2026-11-23), swipe whoosh = fly_swish.ogg, intro Goobs pop = draw_pop.ogg.
Slice §2B Sound: UI/banners chiptune (C), physical things tactile (T).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from make_effect_sounds import SR, square, write_ogg  # noqa: E402
import make_snes_coin_fizzle_options as opt  # noqa: E402


def silence(sec):
    return np.zeros(int(SR * sec))


def press_start():
    """SNES wood block C5 → G5 with the SNES echo (Sean's pick, 2026-11-23)."""
    x = np.concatenate([opt.woodblock(523.25, 0.09), opt.woodblock(783.99, 0.25, 0.06)])
    return opt.norm(opt.snes(x, 90, 0.35, 0.25), 0.22)


def ui_tap():
    """SNES wood block tap, dry: mid register, low-passed, no pitch movement."""
    return opt.norm(opt.snes(opt.woodblock(740)), 0.22)


def first_sting():
    notes = [523.25, 659.25, 783.99]
    parts = [square(hz, 0.07, duty=0.5, vol=0.2) for hz in notes]
    parts.append(square(1046.5, 0.38, duty=0.5, vol=0.2))
    return np.concatenate(parts)


def coin_whirr():
    """Thumb flick of a warm metal coin (flick B, Sean's pick 2026-11-23)."""
    return opt.coin_flick(2500, decay_scale=1.0, spin=(24, 16), seed=12)


def coin_clink():
    """Coin lands on wood and settles (Sean's pick 2026-11-23)."""
    return opt.land_table()


def main():
    write_ogg(press_start(), "press_start.ogg")
    write_ogg(ui_tap(), "ui_tap.ogg")
    write_ogg(first_sting(), "first_sting.ogg")
    write_ogg(coin_whirr(), "coin_whirr.ogg")
    write_ogg(coin_clink(), "coin_clink.ogg")
    print("wrote flow sounds to assets/audio/sfx")


if __name__ == "__main__":
    main()
