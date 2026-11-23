"""Listening options for Sean (2026-11-23), not wired in until he picks:
  1. SNES-like (16-bit) UI sounds: press start + UI tap in three SPC700-style
     instruments (32 kHz, Gaussian-style low-pass, the SNES echo).
  2. Coin flip: a real metal coin flicked off a thumb (nail click + ringing disc
     whose shimmer comes from the spin), plus landing options.
  3. Effect fizzle: water putting out a candle (a short "tsss").

Usage (from the repo root):
  python art/audio/make_snes_coin_fizzle_options.py

Writes art/audio/compare_snes_coin_fizzle/*.ogg (see the README there).
"""
import os
import sys

import numpy as np
from scipy.signal import butter, resample_poly, sosfilt

sys.path.insert(0, os.path.dirname(__file__))
import make_effect_sounds as fx  # noqa: E402
from make_effect_sounds import SR, write_ogg  # noqa: E402

COMPARE_DIR = os.path.join(os.path.dirname(__file__), "compare_snes_coin_fizzle")


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def lp(x, hz, order=2):
    return sosfilt(butter(order, hz, "lowpass", fs=SR, output="sos"), x)


def hp(x, hz, order=2):
    return sosfilt(butter(order, hz, "highpass", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], "bandpass", fs=SR, output="sos"), x)


def norm(x, peak):
    return x / np.max(np.abs(x)) * peak


def pad(x, sec):
    return np.concatenate([x, np.zeros(int(SR * sec))])


# --- 1. SNES chain -----------------------------------------------------------

def snes(x, echo_ms=0, feedback=0.0, wet=0.0):
    """SPC700 flavour: run at 32 kHz, soft Gaussian-interpolation roll-off,
    optional echo (delay with a low-passed feedback loop, like the DSP's FIR)."""
    y = resample_poly(pad(x, 0.5 if echo_ms else 0.02), 320, 441)
    y = sosfilt(butter(2, 6500, "lowpass", fs=32000, output="sos"), y)
    if echo_ms:
        d = int(32000 * echo_ms / 1000)
        out = y.copy()
        buf = np.zeros(len(y))
        for i in range(d, len(y)):
            fb_in = 0.25 * (buf[i - d] + buf[i - d - 1] + buf[i - d - 2] + buf[i - d - 3])
            buf[i] = y[i - d] + feedback * fb_in
        out = y + wet * buf
        y = out
    y = resample_poly(y, 441, 320)
    # Trim the silent tail.
    keep = np.nonzero(np.abs(y) > 1e-4)[0]
    return y[: keep[-1] + 1] if len(keep) else y


def env_snes(n, attack, decay):
    """SNES ADSR feel: quick linear attack, exponential decay."""
    t = np.arange(n) / SR
    return np.minimum(1.0, t / attack) * np.exp(-t / decay)


def marimba(freq, sec=0.12, decay=0.035):
    """A: soft marimba / mallet: sine + a little 4th partial, mid register."""
    t = t_axis(sec)
    tone = np.sin(2 * np.pi * freq * t) + 0.18 * np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-t / 0.008)
    return tone * env_snes(len(t), 0.002, decay)


def woodblock(freq, sec=0.1, decay=0.025):
    """B: muted wood block / kalimba: two inharmonic partials, very short."""
    t = t_axis(sec)
    tone = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / 0.01)
    return lp(tone * env_snes(len(t), 0.0015, decay), 3000)


def pluck(freq, sec=0.16, damp=0.45):
    """C: soft pizzicato (Karplus-Strong, heavily damped, low-passed)."""
    n = int(SR * sec)
    p = int(SR / freq)
    rng = np.random.default_rng(7)
    buf = lp(rng.standard_normal(p), 2500)
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = damp * (buf[i % p] + buf[(i + 1) % p])
    return lp(out, 2800) * env_snes(n, 0.001, 0.06)


def build_snes():
    # Taps: mid register (not bassy), low-passed (not bright), no pitch movement (not wobbly).
    taps = {
        "A_marimba": marimba(880),
        "B_woodblock": woodblock(740),
        "C_pluck": pluck(587.33),
    }
    starts = {
        "A_marimba": np.concatenate([marimba(523.25, 0.09), marimba(783.99, 0.3, 0.09)]),
        "B_woodblock": np.concatenate([woodblock(523.25, 0.09), woodblock(783.99, 0.25, 0.06)]),
        "C_pluck": np.concatenate([pluck(523.25, 0.09), pluck(783.99, 0.35)]),
    }
    for name, x in taps.items():
        write_ogg(norm(snes(x), 0.22), f"1_snes_{name}_ui_tap.ogg")
        # Same tap with a light SNES echo (the classic 16-bit room).
        write_ogg(norm(snes(x, 70, 0.25, 0.18), 0.22), f"1_snes_{name}_ui_tap_echo.ogg")
    for name, x in starts.items():
        write_ogg(norm(snes(x, 90, 0.35, 0.25), 0.22), f"1_snes_{name}_press_start.ogg")


# --- 2. Coin -----------------------------------------------------------------

# Free thin-disc mode ratios (nickel-ish coin, base ~2.9 kHz).
COIN_MODES = [(1.0, 1.0, 0.55), (1.72, 0.7, 0.42), (2.33, 0.5, 0.33), (3.9, 0.25, 0.2), (4.6, 0.15, 0.15)]


def coin_ring(base, sec, decay_scale, spin_hz, spin_end_hz, seed):
    """Ringing disc; the spin gives the shimmer (radiation flips twice a turn)."""
    rng = np.random.default_rng(seed)
    t = t_axis(sec)
    ring = np.zeros(len(t))
    for ratio, amp, decay in COIN_MODES:
        f = base * ratio * (1 + rng.uniform(-0.004, 0.004))
        beat = 1 + 0.002 * np.sin(2 * np.pi * rng.uniform(3, 6) * t)  # degenerate-mode beating
        ring += amp * np.sin(2 * np.pi * f * np.cumsum(beat) / SR + rng.uniform(0, 6.28)) * np.exp(-t / (decay * decay_scale))
    spin = spin_hz + (spin_end_hz - spin_hz) * t / sec
    phase = 2 * np.pi * np.cumsum(spin) / SR
    shimmer = 0.35 + 0.65 * np.abs(np.cos(phase))
    return ring * shimmer


def nail_click(seed, sec=0.02):
    t = t_axis(sec)
    noise = np.random.default_rng(seed).standard_normal(len(t))
    return bp(noise, 1800, 6000) * np.exp(-t / 0.0025)


def coin_flick(base=2900, sec=0.65, decay_scale=1.0, spin=(26, 18), seed=11):
    """Thumb flick: nail click, then the coin rings and shimmers as it spins up."""
    ring = coin_ring(base, sec, decay_scale, spin[0], spin[1], seed)
    out = ring * 0.5
    click = nail_click(seed)
    out[: len(click)] += click * 0.9
    fade = np.minimum(1.0, (sec - t_axis(sec)) / 0.08)
    return norm(out * fade, 0.3)


def land_table(base=2900, seed=21):
    """Lands on wood: clack, short ring, then a quick settling rattle."""
    sec = 0.55
    t = t_axis(sec)
    out = np.zeros(len(t))
    hit = bp(np.random.default_rng(seed).standard_normal(len(t)), 600, 4000) * np.exp(-t / 0.004)
    out += hit * 0.8
    out += coin_ring(base, sec, 0.25, 9, 9, seed) * 0.35
    # Settle: bounces getting closer together and quieter.
    pos, gap, amp = 0.07, 0.06, 0.45
    while gap > 0.008 and pos < sec - 0.05:
        i = int(pos * SR)
        tick = nail_click(seed + i, 0.015) * amp
        ring = coin_ring(base, 0.05, 0.08, 0, 0, seed + i) * amp * 0.5
        out[i : i + len(tick)] += tick
        out[i : i + len(ring)] += ring
        pos += gap
        gap *= 0.7
        amp *= 0.78
    return norm(lp(out, 9000), 0.3)


def land_catch(seed=31):
    """Caught in the palm: soft fleshy slap, ring choked at once."""
    sec = 0.18
    t = t_axis(sec)
    slap = lp(np.random.default_rng(seed).standard_normal(len(t)), 1800) * np.exp(-t / 0.012)
    thump = np.sin(2 * np.pi * 240 * t) * np.exp(-t / 0.02)
    choke = coin_ring(2900, sec, 0.06, 0, 0, seed) * 0.25
    return norm(slap * 0.7 + thump * 0.3 + choke, 0.26)


def build_coin():
    flicks = {
        "A_bright": coin_flick(3400, decay_scale=1.2, spin=(30, 20), seed=11),
        "B_warm": coin_flick(2500, decay_scale=1.0, spin=(24, 16), seed=12),
        "C_big": coin_flick(1900, decay_scale=1.4, spin=(20, 13), seed=13),
    }
    lands = {
        "table": land_table(),
        "catch": land_catch(),
    }
    for name, x in flicks.items():
        write_ogg(x, f"2_coin_flick_{name}.ogg")
    for name, x in lands.items():
        write_ogg(x, f"2_coin_land_{name}.ogg")
    # Whole toss as in the game: flick, 0.6 s in the air, then the landing.
    for fname, f in flicks.items():
        for lname, land in lands.items():
            seq = np.zeros(int(SR * 0.6) + len(land))
            seq[: len(f)] += f
            seq[int(SR * 0.6) :] += land
            write_ogg(norm(seq, 0.3), f"2_coin_full_{fname}_{lname}.ogg")


# --- 3. Fizzle ---------------------------------------------------------------

def hiss(sec, lo, hi, seed, attack=0.004, decay=0.12):
    t = t_axis(sec)
    noise = np.random.default_rng(seed).standard_normal(len(t))
    return bp(noise, lo, hi) * np.minimum(1.0, t / attack) * np.exp(-t / decay)


def sputter(sec, count, seed, amp=0.6):
    """Tiny wet crackles (water boiling off the wick)."""
    rng = np.random.default_rng(seed)
    out = np.zeros(int(SR * sec))
    for _ in range(count):
        i = int(rng.uniform(0.0, sec * 0.6) * SR)
        n = int(SR * 0.004)
        pop = hp(rng.standard_normal(n), 2500) * np.exp(-np.arange(n) / (SR * 0.0008))
        out[i : i + n] += pop * amp * rng.uniform(0.3, 1.0)
    return out


def build_fizzle():
    sec = 0.6
    t = t_axis(sec)
    # A: short pinch "tsst": bright hiss, quick decay.
    a = hiss(sec, 3000, 9000, 41, decay=0.08) + sputter(sec, 4, 41, 0.4)
    # B: drop on the wick: a tiny wet tick, then a sizzle that falls in pitch.
    b = hiss(sec, 2500, 8000, 42, attack=0.01, decay=0.16)
    b = b * (1 - 0.5 * t / sec) + sputter(sec, 9, 42, 0.7)
    tick = np.sin(2 * np.pi * 1400 * t[: int(SR * 0.02)]) * np.exp(-t[: int(SR * 0.02)] / 0.004)
    b[: len(tick)] += tick * 0.5
    b = lp(b, 7000)  # the sizzle dulls as the flame dies
    # C: hiss + steam puff: a breathy low "ff" under the "tss", gentler.
    c = hiss(sec, 2000, 7000, 43, attack=0.015, decay=0.14) * 0.8 + hiss(sec, 300, 1200, 44, attack=0.03, decay=0.2) * 0.5
    c += sputter(sec, 5, 43, 0.35)
    for name, x in {"A_pinch": a, "B_drop_sizzle": b, "C_steam_puff": c}.items():
        write_ogg(norm(x, 0.25), f"3_fizzle_{name}.ogg")


def build_fizzle_soft():
    """Sean (2026-11-23): A, but softer and warmer. Lower band, slower onset,
    darker low-pass, gentler crackles, a little quieter."""
    sec = 0.6
    variants = {
        # A1: a touch softer: band down a bit, crackles halved.
        "A1_softer": (lp(hiss(sec, 2000, 6500, 41, attack=0.008, decay=0.09) + sputter(sec, 4, 41, 0.2), 5500), 0.21),
        # A2: warmer: mid band, slow onset, dark top.
        "A2_warmer": (lp(hiss(sec, 1300, 4500, 41, attack=0.012, decay=0.1) + sputter(sec, 3, 41, 0.15), 4000), 0.2),
        # A3: softest: low hiss with a breath under it, barely any crackle.
        "A3_softest": (lp(hiss(sec, 1000, 3500, 41, attack=0.018, decay=0.11)
                          + hiss(sec, 300, 900, 44, attack=0.02, decay=0.08) * 0.3
                          + sputter(sec, 2, 41, 0.1), 3200), 0.18),
    }
    for name, (x, peak) in variants.items():
        write_ogg(norm(x, peak), f"3_fizzle_{name}.ogg")


def main():
    fx.OUT_DIR = COMPARE_DIR
    os.makedirs(COMPARE_DIR, exist_ok=True)
    build_snes()
    build_coin()
    build_fizzle()
    build_fizzle_soft()
    print("wrote options to", fx.OUT_DIR)


if __name__ == "__main__":
    main()
