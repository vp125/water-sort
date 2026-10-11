#!/usr/bin/env python3
"""Procedurally generates every sound effect and the background music loop for Water Sort.

Pure standard-library Python (no numpy). Deterministic: seeded RNGs, so reruns give identical files.

    python tools/generate_audio.py            # everything
    python tools/generate_audio.py sfx        # only effects (fast)
    python tools/generate_audio.py music      # only the music loop (takes a minute or two)

Output goes to assets/audio/{sfx,music}. Replace any file with a hand-made one of the same name
and the game will use it unchanged. The music is compressed to .ogg when ffmpeg is on PATH.
"""
import math
import random
import shutil
import struct
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
MUSIC_DIR = ROOT / "assets" / "audio" / "music"
SR = 44100
MUSIC_SR = 32000
TWO_PI = 2.0 * math.pi
WATER_LEVEL = 0.0  # steady water wash; 0.25 sits only 8 dB under the pads and sounds like the sea. 0 = off
AIR_LEVEL = 0.005  # airy hiss; 0.12 is still only 14 dB under the pads. 0 = off


# --- Core helpers -----------------------------------------------------------

class Buf:
    def __init__(self, seconds, sr=SR):
        self.sr = sr
        self.n = int(seconds * sr)
        self.d = [0.0] * self.n


def midi(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def add_tone(buf, t0, freq, dur, amp, partials=((1, 1.0),), attack=0.004, tau=0.2,
             release=0.02, glide_to=None, wrap=False):
    """Additive tone. partials = (ratio, amp[, decay_multiplier]). Exponential decay with
    time-constant `tau`; optional exponential pitch glide; `wrap` makes tails wrap around the
    buffer end (for seamless loops)."""
    sr, d, big_n = buf.sr, buf.d, buf.n
    n = int(dur * sr)
    i0 = int(t0 * sr)
    ps = []
    for p in partials:
        ratio, a = p[0], p[1]
        mult = p[2] if len(p) > 2 else 1.0
        ps.append([ratio, a, math.exp(-1.0 / (sr * tau * mult)), 1.0, 0.0])
    att_n = max(1, int(attack * sr))
    rel_n = max(1, int(release * sr))
    sin = math.sin
    for k in range(n):
        idx = i0 + k
        if idx >= big_n:
            if not wrap:
                break
            idx %= big_n
        f = freq if glide_to is None else freq * (glide_to / freq) ** (k / n)
        inc = TWO_PI * f / sr
        s = 0.0
        for p in ps:
            p[4] += inc * p[0]
            s += p[1] * p[3] * sin(p[4])
            p[3] *= p[2]
        e = k / att_n if k < att_n else 1.0
        if k > n - rel_n:
            e *= (n - k) / rel_n
        d[idx] += amp * s * e


def lowpass(x, fc, sr, passes=1, circular=False):
    a = 1.0 - math.exp(-TWO_PI * fc / sr)
    out = x
    for _ in range(passes):
        y = 0.0
        res = [0.0] * len(out)
        loops = 2 if circular else 1  # run twice around so the loop seam has no transient
        for lp in range(loops):
            for i, v in enumerate(out):
                y += a * (v - y)
                if lp == loops - 1:
                    res[i] = y
        out = res
    return out


def band_noise(n, lo, hi, sr, rng, circular=False):
    white = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    hi_l = lowpass(white, hi, sr, 1, circular)
    lo_l = lowpass(white, lo, sr, 1, circular)
    return [a - b for a, b in zip(hi_l, lo_l)]


def add_signal(buf, t0, sig, amp=1.0):
    i0 = int(t0 * buf.sr)
    d = buf.d
    for k, v in enumerate(sig):
        if i0 + k >= buf.n:
            break
        d[i0 + k] += amp * v


def fade_edges(buf, fade_in=0.002, fade_out=0.02):
    fi, fo = int(fade_in * buf.sr), int(fade_out * buf.sr)
    for i in range(min(fi, buf.n)):
        buf.d[i] *= i / fi
    for i in range(min(fo, buf.n)):
        buf.d[buf.n - 1 - i] *= i / fo


def write_wav(path, buf, peak=0.7, normalize=True):
    path.parent.mkdir(parents=True, exist_ok=True)
    m = max(max(abs(v) for v in buf.d), 1e-9)
    gain = peak / m if normalize else 1.0
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * gain)) * 32767)) for v in buf.d)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(buf.sr)
        w.writeframes(frames)
    shown = path.relative_to(ROOT) if ROOT in path.parents else path
    print(f"  {shown}  ({buf.n / buf.sr:.2f}s)")


GLASS = ((1, 1.0, 1.0), (2.32, 0.35, 0.5), (4.25, 0.15, 0.3))  # glassy, slightly inharmonic
BELL = ((1, 1.0, 1.0), (2.0, 0.4, 0.6), (3.01, 0.2, 0.4), (4.2, 0.08, 0.25))


# --- Sound effects ----------------------------------------------------------

def sfx_select():
    b = Buf(0.18)
    add_tone(b, 0.0, 1760, 0.18, 0.8, GLASS, attack=0.002, tau=0.05)
    add_tone(b, 0.018, 3520, 0.10, 0.25, ((1, 1.0),), attack=0.002, tau=0.03)  # sparkle
    fade_edges(b)
    return b, 0.55


def sfx_pour(n):
    """Signature sound: trickle + 'blu-lu-lu' bubbles + final 'plip'. Length matches the
    pour animation (0.2 + 0.15 * units seconds)."""
    rng = random.Random(100 + n)
    dur = 0.2 + 0.15 * n
    b = Buf(dur + 0.04)
    trickle = band_noise(int((dur + 0.04) * SR), 900, 4200, SR, rng)
    for i in range(len(trickle)):
        t = i / SR
        env = min(1.0, t / 0.04) * min(1.0, max(0.0, (dur - t) / 0.12))
        trickle[i] *= env * (0.7 + 0.3 * math.sin(TWO_PI * 21 * t))
    add_signal(b, 0.0, trickle, 0.5)
    count = 2 + n
    for k in range(count):
        t = 0.03 + (dur - 0.17) * (k / max(1, count - 1)) + rng.uniform(-0.012, 0.012)
        f0 = rng.uniform(360, 640)
        add_tone(b, max(0.0, t), f0, 0.075, rng.uniform(0.28, 0.4), ((1, 1.0), (2, 0.2)),
                 attack=0.004, tau=0.03, release=0.015, glide_to=f0 * 1.55)
    add_tone(b, dur - 0.08, 1050, 0.11, 0.5, ((1, 1.0), (2, 0.15)), attack=0.003, tau=0.035,
             release=0.02, glide_to=1900)  # plip
    fade_edges(b, 0.004, 0.03)
    return b, 0.6


def sfx_progress():
    b = Buf(0.30)
    add_tone(b, 0.0, 950, 0.07, 0.8, ((1, 1.0),), attack=0.002, tau=0.02, release=0.01, glide_to=300)  # pop
    add_tone(b, 0.075, 1318.5, 0.22, 0.6, BELL, attack=0.002, tau=0.09)  # ting
    fade_edges(b)
    return b, 0.55


def sfx_tube_complete():
    b = Buf(0.9)
    for k, note in enumerate((84, 88, 91)):  # C6 E6 G6, ascending
        add_tone(b, k * 0.12, midi(note), 0.6, 0.7, BELL, attack=0.003, tau=0.22)
    # shimmering tail: a high note with fast tremolo, fading out
    shimmer = Buf(0.9)
    add_tone(shimmer, 0.3, midi(103), 0.55, 0.5, ((1, 1.0), (2.01, 0.3)), attack=0.02, tau=0.25)
    for i in range(shimmer.n):
        shimmer.d[i] *= 0.6 + 0.4 * math.sin(TWO_PI * 13 * i / SR)
        b.d[i] += shimmer.d[i] * 0.35
    fade_edges(b, 0.002, 0.15)
    return b, 0.65


def sfx_level_complete():
    b = Buf(2.4)
    melody = ((79, 0.0, 0.22), (84, 0.19, 0.22), (88, 0.38, 0.22), (91, 0.60, 0.5))  # G5 C6 E6 G6
    for note, t, dur in melody:
        add_tone(b, t, midi(note), dur + 0.4, 0.7, BELL, attack=0.003, tau=0.2)
    # sparkle cascade
    rng = random.Random(7)
    scale = [84, 86, 88, 91, 93, 96, 98, 100, 103]
    for k in range(14):
        add_tone(b, 0.95 + k * 0.055, midi(scale[(k * 2 + rng.randint(0, 1)) % len(scale)]), 0.25,
                 0.28 * (1.0 - k / 18.0), ((1, 1.0), (2.0, 0.2)), attack=0.002, tau=0.07)
    # warm finishing chord (Cadd9)
    for note in (60, 64, 67, 74):
        add_tone(b, 1.05, midi(note), 1.3, 0.22, ((1, 1.0), (2, 0.25), (3, 0.08)), attack=0.04, tau=0.7,
                 release=0.4)
        add_tone(b, 1.05, midi(note) * 1.004, 1.3, 0.12, ((1, 1.0),), attack=0.05, tau=0.7, release=0.4)
    fade_edges(b, 0.002, 0.3)
    return b, 0.7


def sfx_undo():
    b = Buf(0.30)
    add_tone(b, 0.0, 820, 0.28, 0.8, ((1, 1.0), (2, 0.2)), attack=0.03, tau=0.12, release=0.06, glide_to=360)
    fade_edges(b, 0.01, 0.06)
    return b, 0.5


def sfx_restart():
    rng = random.Random(5)
    dur = 0.4
    b = Buf(0.62)
    n = int(dur * SR)
    white = [rng.uniform(-1, 1) for _ in range(n)]
    y1 = y2 = 0.0
    sweep = []
    for i, v in enumerate(white):
        t = i / n
        fc = 400 * (4200 / 400) ** t  # swept low-pass = airy whoosh
        a = 1.0 - math.exp(-TWO_PI * fc / SR)
        y1 += a * (v - y1)
        y2 += a * (y1 - y2)
        sweep.append(y2 * math.sin(math.pi * t) ** 2)
    add_signal(b, 0.0, sweep, 1.0)
    add_tone(b, 0.38, 2093, 0.22, 0.35, GLASS, attack=0.002, tau=0.07)  # gentle glass tap
    fade_edges(b, 0.01, 0.05)
    return b, 0.55


def sfx_hint():
    b = Buf(0.55)
    add_tone(b, 0.0, midi(88), 0.4, 0.6, BELL, attack=0.003, tau=0.14)
    add_tone(b, 0.07, midi(95), 0.45, 0.5, BELL, attack=0.003, tau=0.16)
    add_tone(b, 0.14, midi(100), 0.35, 0.25, ((1, 1.0), (2.0, 0.3)), attack=0.003, tau=0.1)
    fade_edges(b, 0.002, 0.1)
    return b, 0.5


def sfx_add_tube():
    rng = random.Random(9)
    b = Buf(0.42)
    add_tone(b, 0.0, 620, 0.1, 0.8, ((1, 1.0), (2, 0.2)), attack=0.003, tau=0.03, release=0.02, glide_to=240)
    puff = lowpass([rng.uniform(-1, 1) for _ in range(int(0.12 * SR))], 1800, SR, 2)
    for i in range(len(puff)):
        puff[i] *= math.exp(-i / (0.03 * SR))
    add_signal(b, 0.0, puff, 0.5)
    for k, note in enumerate((84, 88, 91)):
        add_tone(b, 0.1 + k * 0.07, midi(note), 0.25, 0.3, ((1, 1.0), (2.0, 0.25)), attack=0.002, tau=0.08)
    fade_edges(b, 0.002, 0.08)
    return b, 0.55


def build_sfx():
    print("Sound effects:")
    jobs = {
        "select": sfx_select, "progress": sfx_progress, "tube_complete": sfx_tube_complete,
        "level_complete": sfx_level_complete, "undo": sfx_undo, "restart": sfx_restart,
        "hint": sfx_hint, "add_tube": sfx_add_tube,
    }
    for n in range(1, 5):
        jobs[f"pour_{n}"] = lambda n=n: sfx_pour(n)
    for name, fn in jobs.items():
        buf, peak = fn()
        write_wav(SFX_DIR / f"{name}.wav", buf, peak)


# --- Music ------------------------------------------------------------------

def _layer_stats(layer, window_s=0.25):
    """(overall RMS, swell) where swell = std/mean of the RMS measured in short windows."""
    w = int(window_s * layer.sr)
    rmss = []
    for i in range(0, layer.n - w + 1, w):
        chunk = layer.d[i:i + w]
        rmss.append(math.sqrt(sum(v * v for v in chunk) / w))
    overall = math.sqrt(sum(r * r for r in rmss) / len(rmss))
    mean = sum(rmss) / len(rmss)
    std = math.sqrt(sum((r - mean) ** 2 for r in rmss) / len(rmss))
    return overall, (std / mean if mean > 0 else 0.0)


def build_music():
    """~80 s seamless loop at 72 BPM: warm pads, sparse felt-piano, tiny music-box bells,
    quiet water ambience and air. Tails wrap around the end so the loop has no seam."""
    print("Music loop (this takes a minute or two)...")
    bpm = 72.0
    beat = 60.0 / bpm
    bars = 24
    total = bars * 4 * beat  # 80 s
    buf = Buf(total, MUSIC_SR)  # final mix
    pads, keys, bells, water_buf, drops, air_buf = (Buf(total, MUSIC_SR) for _ in range(6))
    rng = random.Random(2024)

    # Two bars per chord; one 8-bar cycle repeated three times.
    chords = [  # (pad voicing, melody chord tones)
        ([48, 55, 64, 71], [60, 64, 67, 72, 76, 79]),  # Cmaj7
        ([45, 52, 60, 67], [69, 72, 76, 81, 64, 60]),  # Am7
        ([41, 48, 57, 64], [69, 72, 76, 60, 81, 64]),  # Fmaj7
        ([43, 50, 57, 62], [62, 67, 74, 79, 69, 71]),  # G6sus
    ]
    scale = [60, 62, 64, 67, 69, 72, 74, 76, 79, 81]
    chord_len = 8 * beat

    # Pads: slow swell, overlapping into the next chord (and wrapping at the loop end).
    for c in range(12):
        voicing = chords[c % 4][0]
        t0 = c * chord_len
        for note in voicing:
            f = midi(note)
            add_tone(pads, t0, f, chord_len + 2.2, 0.050, ((1, 1.0), (2, 0.18)), attack=1.9, tau=1e6,
                     release=2.2, wrap=True)
            add_tone(pads, t0, f * 1.0035, chord_len + 2.2, 0.035, ((1, 1.0),), attack=2.1, tau=1e6,
                     release=2.2, wrap=True)

    # Felt piano: sparse pentatonic phrases following the chords.
    piano = ((1, 1.0, 1.0), (2, 0.42, 0.6), (3, 0.16, 0.4), (4, 0.07, 0.3))
    onset_p = [0.85, 0.12, 0.4, 0.18, 0.55, 0.12, 0.35, 0.1]
    cycle_density = [0.75, 1.0, 0.85]
    prev = 72
    for c in range(12):
        tones = chords[c % 4][1]
        for step in range(8):
            if rng.random() > onset_p[step] * cycle_density[c // 4]:
                continue
            pool = tones if rng.random() < 0.75 else scale
            near = sorted(pool, key=lambda m: abs(m - prev) + rng.uniform(0, 4))
            note = near[0]
            prev = note
            t = c * chord_len + step * beat + rng.uniform(-0.02, 0.02)
            if rng.random() < 0.2:
                t += 0.5 * beat  # occasional off-beat for a human feel
            add_tone(keys, t, midi(note), 4.5, 0.10 * rng.uniform(0.7, 1.1), piano, attack=0.007,
                     tau=1.5, release=0.5, wrap=True)

    # Music-box accents and tiny bells.
    box = ((1, 1.0, 1.0), (3.0, 0.3, 0.5), (5.0, 0.12, 0.3))
    for c in range(12):
        tones = chords[c % 4][1]
        if c % 2 == 0 and rng.random() < 0.8:
            note = rng.choice(tones) + 12
            t = c * chord_len + 0.5 * beat
            add_tone(bells, t, midi(note), 3.0, 0.055, box, attack=0.003, tau=0.9, release=0.4, wrap=True)
            add_tone(bells, t + 0.75 * beat, midi(note), 3.0, 0.028, box, attack=0.003, tau=0.9, release=0.4, wrap=True)
        if rng.random() < 0.45:
            t = c * chord_len + (4 + rng.choice([0.0, 0.5, 2.0, 2.5])) * beat
            add_tone(bells, t, midi(rng.choice(tones) + 24), 2.0, 0.03, BELL, attack=0.002, tau=0.5, release=0.3, wrap=True)

    # Very quiet water ambience (slow swells with a whole number of cycles per loop) + droplets.
    n = buf.n
    water = band_noise(n, 350, 1800, MUSIC_SR, rng, circular=True)
    for i in range(n):
        t = i / n
        swell = 0.75 + 0.15 * math.sin(TWO_PI * 7 * t) + 0.10 * math.sin(TWO_PI * 11 * t + 1.3)
        water_buf.d[i] = water[i] * WATER_LEVEL * swell
    for _ in range(int(total * 0.22)):
        f0 = rng.uniform(700, 1500)
        add_tone(drops, rng.uniform(0, total), f0, 0.09, 0.012, ((1, 1.0),), attack=0.004, tau=0.03,
                 release=0.02, glide_to=f0 * 1.5, wrap=True)
    air = band_noise(n, 3500, 7500, MUSIC_SR, rng, circular=True)
    for i in range(n):
        t = i / n
        air_buf.d[i] = air[i] * AIR_LEVEL * (0.8 + 0.2 * math.sin(TWO_PI * 5 * t + 0.7))

    # Mix the layers and report how loud each one is (RMS, in dB below the loudest layer) and how
    # much it swells (slow loudness variation). Use this to see what dominates the mix.
    layers = {"pads": pads, "piano": keys, "bells": bells, "water": water_buf, "droplets": drops, "air": air_buf}
    stats = {name: _layer_stats(layer) for name, layer in layers.items()}
    loudest = max(r for r, _ in stats.values())
    print("  layer       level (dB re loudest)   swell")
    for name, (r, swell) in stats.items():
        db = 20 * math.log10(r / loudest) if r > 0 else float("-inf")
        print(f"  {name:<10}  {db:8.1f}              {swell:5.2f}")
    for layer in layers.values():
        for i, v in enumerate(layer.d):
            buf.d[i] += v
    if STEMS_DIR is not None:
        for name, layer in layers.items():
            write_wav(STEMS_DIR / f"{name}.wav", layer, peak=0.5)

    m = max(abs(v) for v in buf.d)
    print(f"  loop seam gap: {abs(buf.d[0] - buf.d[-1]) / m:.4f} (relative to peak)")
    wav_path = MUSIC_DIR / "ambient_loop.wav"
    write_wav(wav_path, buf, peak=0.5)
    if shutil.which("ffmpeg"):
        ogg = MUSIC_DIR / "ambient_loop.ogg"
        r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path),
                            "-c:a", "libvorbis", "-q:a", "4", str(ogg)])
        if r.returncode == 0:
            wav_path.unlink()
            print(f"  compressed -> {ogg.relative_to(ROOT)}")
        else:
            print("  ffmpeg failed; keeping the .wav")


STEMS_DIR = None  # set with --stems DIR to also write each music layer as its own wav

if __name__ == "__main__":
    if "--stems" in sys.argv:
        STEMS_DIR = Path(sys.argv[sys.argv.index("--stems") + 1])
    what = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "all"
    if what in ("all", "sfx"):
        build_sfx()
    if what in ("all", "music"):
        build_music()
