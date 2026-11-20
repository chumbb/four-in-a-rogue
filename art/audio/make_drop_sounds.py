"""Synthesise the Goob drop sounds (made for this project, no licence needed).

Usage: python art/audio/make_drop_sounds.py   (from the repo root)

Outputs (Ogg Vorbis, 44.1 kHz mono, via ffmpeg):
  assets/audio/sfx/fall.ogg  airy whoosh while the Goob drops through the column (~0.28 s)
  assets/audio/sfx/land.ogg  a soft, warm thunk into the wooden board (~0.3 s)
Sean (2026-11-19 Art pass A playtest): "it should sound like it's dropping through air and
clinking against the wood board." Re-check: the clink was a high clang; it should be "a
soft, warm thunk into the board".
"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
FFMPEG = r"C:\Users\Sean\Apps\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe"
OUT_DIR = "assets/audio/sfx"
rng = np.random.default_rng(7)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def bandpass_sweep(noise, f_start, f_end, q=1.2, blocks=48):
    """Band-pass noise whose centre glides from f_start to f_end (block-wise)."""
    out = np.zeros_like(noise)
    n = len(noise)
    edges = np.linspace(0, n, blocks + 1).astype(int)
    for i in range(blocks):
        f = f_start * (f_end / f_start) ** (i / (blocks - 1))
        lo, hi = f / (1 + 0.5 / q), f * (1 + 0.5 / q)
        sos = butter(2, [lo, hi], btype="band", fs=SR, output="sos")
        a, b = max(0, edges[i] - 2048), edges[i + 1]
        out[edges[i]:b] = sosfilt(sos, noise[a:b])[edges[i] - a:]
    return out


def fall():
    t = t_axis(0.28)
    x = bandpass_sweep(rng.standard_normal(len(t)), 2600, 900)
    env = np.minimum(1, t / 0.07) * np.clip((0.28 - t) / 0.12, 0, 1) ** 1.5
    return x * env, 0.18


def partials(t, freqs_amps_decays):
    return sum(a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / d)
               for f, a, d in freqs_amps_decays)


def land():
    """Soft, warm thunk into the wooden board (Sean, 2026-11-19 re-check: no clang)."""
    t = t_axis(0.3)
    # Warm wood body: low resonances, short-ish decay, slight downward pitch settle.
    body = sum(a * np.sin(2 * np.pi * f * (t - 0.08 * t * t) + ph) * np.exp(-t / d)
               for f, a, d, ph in [(115, 1.0, 0.06, 0.0), (175, 0.7, 0.045, 1.1), (260, 0.45, 0.03, 2.3),
                                     (430, 0.4, 0.02, 0.7), (610, 0.2, 0.014, 1.9)])  # mids: audible on phone speakers
    # Muffled thump: low-passed noise burst.
    thump = sosfilt(butter(2, 500, fs=SR, output="sos"), rng.standard_normal(len(t))) * np.exp(-t / 0.018)
    attack = np.minimum(1, t / 0.004)
    x = (body + 0.6 * thump) * attack
    # Keep it soft: roll off everything above ~1.8 kHz.
    x = sosfilt(butter(4, 1800, fs=SR, output="sos"), x)
    return x, 0.85


def write_ogg(x, peak, name):
    x = x / np.max(np.abs(x)) * peak
    pcm = (x * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "s.wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        out = os.path.join(OUT_DIR, name)
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "6", out], check=True)
    print("wrote", out)


if __name__ == "__main__":
    write_ogg(*fall(), "fall.ogg")
    write_ogg(*land(), "land.ogg")
