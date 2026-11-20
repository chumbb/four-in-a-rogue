"""Build the Goob drop sounds.

Usage: python art/audio/make_drop_sounds.py   (from the repo root)

Outputs (Ogg Vorbis, 44.1 kHz, via ffmpeg):
  assets/audio/sfx/fall.ogg  airy whoosh while the Goob drops through the column (~0.28 s)
  assets/audio/sfx/land.ogg  the column hover click (column_tick.ogg) pitched down ~5 semitones
Sean (2026-11-19 Art pass A playtest): "it should sound like it's dropping through air and
clinking against the wood board." Re-check: the clink was a high clang; it should be "a
soft, warm thunk into the board". Re-checks 2-3: mostly a plastic click
(like the real game's discs), thunk underneath, never metal. Re-check 4: none of the
synthesised landings worked; use a lower version of the column hover click.
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


# Land = the column hover click (column_tick.ogg) pitched down ~5 semitones (Sean,
# 2026-11-19 re-check 4, after synthesised thunk/click versions didn't work).
LAND_PITCH = 0.75


def make_land():
    src = os.path.join(OUT_DIR, "column_tick.ogg")
    out = os.path.join(OUT_DIR, "land.ogg")
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", src, "-af",
                    "asetrate=%d,aresample=%d" % (round(44100 * LAND_PITCH), SR),
                    "-c:a", "libvorbis", "-q:a", "6", out], check=True)
    print("wrote", out)


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
    make_land()
