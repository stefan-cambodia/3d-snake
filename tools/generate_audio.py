#!/usr/bin/env python3
"""Synthesise every sound effect, ambience and music track of the game.

All audio is generated from scratch (additive synthesis, filtered noise and
FFT convolution reverb), so the game ships no third-party audio assets.

    python3 tools/generate_audio.py

Requires numpy and ffmpeg (libvorbis). Writes assets/audio/{sfx,music}/*.ogg
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
rng = np.random.default_rng(1234)


# ----------------------------------------------------------------------------- primitives

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def adsr(n, a=0.005, d=0.1, s=0.6, r=0.2, total=None):
    total = n if total is None else total
    env = np.zeros(n)
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    ai = max(ai, 1)
    env[:ai] = np.linspace(0, 1, ai)
    end_d = min(ai + di, n)
    env[ai:end_d] = np.linspace(1, s, end_d - ai)
    env[end_d:] = s
    if ri > 0 and n > ri:
        env[n - ri:] *= np.linspace(1, 0, ri)
    return env


def fft_filter(x, lo=0.0, hi=SR / 2, soft=0.15):
    """Smooth band-pass in the frequency domain."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if lo > 0:
        g *= 1 / (1 + np.exp(-(f - lo) / max(lo * soft, 1)))
    if hi < SR / 2:
        g *= 1 / (1 + np.exp((f - hi) / max(hi * soft, 1)))
    return np.fft.irfft(X * g, n)


def additive(freq, dur, partials, decays, amps, phase_rand=True, vib=0.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for p, d, a in zip(partials, decays, amps):
        f = freq * p
        if f >= SR / 2:
            continue
        ph = rng.random() * 2 * np.pi if phase_rand else 0
        mod = 1 + vib * np.sin(2 * np.pi * 5.0 * t)
        out += a * np.exp(-t * d) * np.sin(2 * np.pi * f * t * mod + ph)
    return out


def pluck(freq, dur=1.2, bright=1.0):
    k = np.arange(1, 14)
    amps = (1 / k ** 1.1) * np.exp(-(k - 1) * 0.18 / bright)
    decays = 2.2 + k * 1.6 / bright
    x = additive(freq, dur, k * (1 + 0.0006 * k ** 2), decays, amps)
    x[: int(0.003 * SR)] *= np.linspace(0, 1, int(0.003 * SR))
    return x


def kalimba(freq, dur=1.4):
    x = additive(freq, dur, [1, 2.01, 5.9, 8.1], [3.0, 6, 14, 22], [1, 0.25, 0.18, 0.06])
    x[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    return x


def bell(freq, dur=2.0, decay=1.0):
    parts = [0.56, 0.92, 1.0, 1.19, 1.71, 2.0, 2.74, 3.0, 3.76, 4.07]
    amps = [0.5, 0.3, 1.0, 0.4, 0.5, 0.3, 0.25, 0.2, 0.12, 0.1]
    decays = [d * decay for d in [0.9, 1.4, 1.2, 1.8, 2.2, 2.6, 3.1, 3.8, 4.5, 5.0]]
    return additive(freq, dur, parts, decays, amps)


def saw_pad(freqs, dur, detune=0.006, harmonics=10, attack=0.6, release=1.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f0 in freqs:
        for dt in (-detune, 0, detune):
            f = f0 * (1 + dt)
            ph = rng.random() * 2 * np.pi
            for k in range(1, harmonics + 1):
                if f * k >= SR / 2:
                    break
                out += (1 / k) * np.sin(2 * np.pi * f * k * t + ph * k) * 0.33
    env = adsr(len(t), attack, 0.3, 0.85, release)
    lfo = 1 + 0.06 * np.sin(2 * np.pi * 0.23 * t)
    return out * env * lfo / max(len(freqs), 1)


def noise(dur):
    return rng.standard_normal(int(dur * SR))


def reverb(x, t60=1.8, mix=0.25, pre=0.012, stereo=True):
    n_ir = int(t60 * SR)
    t = np.arange(n_ir) / SR
    chans = []
    for c in range(2 if stereo else 1):
        ir = rng.standard_normal(n_ir) * np.exp(-6.9 * t / t60)
        ir = fft_filter(ir, 120, 7000)
        ir[: int(pre * SR)] = 0
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        n = len(x) + n_ir
        nfft = 1 << (n - 1).bit_length()
        y = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[:n]
        dry = np.concatenate([x, np.zeros(n_ir)])
        chans.append(dry * (1 - mix) + y * mix * 1.6)
    return np.stack(chans, axis=-1) if stereo else chans[0]


def place(buf, x, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    end = min(i + len(x), len(buf))
    buf[i:end] += x[: end - i]


def place_wrap(buf, x, at):
    """Place with wrap-around (for seamless loops)."""
    i = int(at * SR) % len(buf)
    n = len(x)
    first = min(n, len(buf) - i)
    buf[i:i + first] += x[:first]
    if n > first:
        place_wrap(buf, x[first:], 0)


def normalize(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade(x, fin=0.002, fout=0.02):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)[:, None] if x.ndim == 2 else np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)[:, None] if x.ndim == 2 else np.linspace(1, 0, b)
    return x


def write_ogg(path, x, quality=4):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.clip(x, -1, 1)
    chans = 1 if x.ndim == 1 else x.shape[1]
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_name = tmp.name
    with wave.open(tmp_name, "wb") as w:
        w.setnchannels(chans)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp_name, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.remove(tmp_name)
    print(f"  {os.path.relpath(path, ROOT)}  {os.path.getsize(path) / 1024:.0f} KB")


def sfx(name, x, quality=4, rev=None):
    if rev:
        x = reverb(x, *rev)
    write_ogg(os.path.join(OUT, "sfx", name + ".ogg"), fade(normalize(x, 0.85)), quality)


# ----------------------------------------------------------------------------- sound effects

def make_sfx():
    # Food pickup: bright two-note pluck + sparkle.
    x = np.zeros(int(0.6 * SR))
    place(x, pluck(midi(81), 0.5, 1.6) * 0.8, 0)
    place(x, pluck(midi(88), 0.45, 1.8) * 0.6, 0.045)
    sp = fft_filter(noise(0.25), 5000, 12000) * np.exp(-t_axis(0.25) * 18) * 0.15
    place(x, sp, 0.0)
    sfx("pickup_food", x, rev=(0.6, 0.18))

    # Energy crystal: rising shimmer arpeggio over a whoosh.
    x = np.zeros(int(1.2 * SR))
    for i, n in enumerate([76, 79, 83, 86, 91]):
        place(x, bell(midi(n), 0.8, 2.0) * 0.4, i * 0.05)
    w = fft_filter(noise(0.7), 800, 6000) * np.sin(np.linspace(0, np.pi, int(0.7 * SR))) ** 2 * 0.25
    place(x, w, 0)
    sfx("pickup_energy", x, rev=(1.2, 0.25))

    # Rare relic: magical bell cascade (pentatonic).
    x = np.zeros(int(2.4 * SR))
    for i, n in enumerate([74, 79, 81, 86, 88, 93]):
        place(x, bell(midi(n), 1.6, 0.9) * (0.55 - i * 0.04), i * 0.085)
    place(x, saw_pad([midi(62), midi(69), midi(74)], 1.8, attack=0.05, release=1.2) * 0.25, 0)
    sfx("pickup_rare", x, rev=(2.2, 0.35))

    # Boost whoosh.
    d = 0.7
    n = noise(d)
    lo = fft_filter(n, 200, 1400)
    hi = fft_filter(n, 1500, 7000)
    k = np.linspace(0, 1, len(n))
    x = (lo * (1 - k) + hi * k) * np.sin(np.pi * k) ** 1.5
    sfx("boost", x)

    # Surge end: descending shimmer.
    x = np.zeros(int(0.7 * SR))
    for i, nn in enumerate([88, 84, 79, 76]):
        place(x, bell(midi(nn), 0.5, 2.5) * 0.35, i * 0.06)
    sfx("surge_end", x, rev=(0.8, 0.2))

    # Stage up: warm swelling chord + bell.
    x = np.zeros(int(2.2 * SR))
    place(x, saw_pad([midi(62), midi(66), midi(69), midi(74)], 1.9, attack=0.08, release=1.0) * 0.6, 0)
    for i, nn in enumerate([74, 78, 81, 86]):
        place(x, kalimba(midi(nn), 1.2) * 0.5, 0.05 + i * 0.07)
    sfx("stage_up", x, rev=(1.8, 0.3))

    # Near miss: quick air swish.
    d = 0.32
    k = np.linspace(0, 1, int(d * SR))
    x = fft_filter(noise(d), 1200, 9000) * (np.sin(np.pi * k) ** 3) * 0.8
    sfx("near_miss", x)

    # Rise warning: low rumble with rising tension.
    d = 1.4
    t = t_axis(d)
    rum = fft_filter(noise(d), 30, 180) * (0.3 + 0.7 * t / d)
    tone = np.sin(2 * np.pi * (55 + 25 * t / d) * t) * 0.4 * (t / d)
    x = rum + tone
    sfx("rise_warning", x)

    # Stone grinding rise.
    d = 1.2
    t = t_axis(d)
    crackle = fft_filter(noise(d) * (rng.random(len(t)) > 0.97) * 4, 300, 3000)
    grind = fft_filter(noise(d), 60, 600) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t))
    x = (grind + crackle * 0.5) * adsr(len(t), 0.05, 0.2, 0.8, 0.4)
    thud = np.sin(2 * np.pi * 50 * t) * np.exp(-t * 6) * (t > 1.0)
    sfx("rise_stone", x + thud * 0.6)

    # Death impact.
    d = 1.0
    t = t_axis(d)
    body = np.sin(2 * np.pi * (90 * np.exp(-t * 6) + 40) * t) * np.exp(-t * 4)
    crunch = fft_filter(noise(d), 200, 4000) * np.exp(-t * 12)
    x = body * 0.9 + crunch * 0.6
    sfx("death", x, rev=(1.4, 0.25))

    # Game over: gentle descending phrase.
    x = np.zeros(int(3.0 * SR))
    for i, nn in enumerate([69, 65, 62, 57]):
        place(x, kalimba(midi(nn), 1.6) * 0.5 + pluck(midi(nn - 12), 1.6, 0.7) * 0.3, i * 0.32)
    place(x, saw_pad([midi(50), midi(57), midi(62)], 2.6, attack=0.4, release=1.4) * 0.3, 0.2)
    sfx("game_over", x, rev=(2.4, 0.35))

    # New best / unlock.
    x = np.zeros(int(2.0 * SR))
    for i, nn in enumerate([74, 78, 81, 86, 90]):
        place(x, bell(midi(nn), 1.2, 1.2) * 0.45, i * 0.09)
    place(x, saw_pad([midi(62), midi(69), midi(78)], 1.6, attack=0.05, release=0.8) * 0.3, 0.3)
    sfx("new_best", x, rev=(2.0, 0.3))
    x = np.zeros(int(1.6 * SR))
    for i, nn in enumerate([86, 93, 98]):
        place(x, bell(midi(nn), 1.2, 1.5) * 0.4, i * 0.06)
    sfx("unlock", x, rev=(1.6, 0.3))

    # Start gong.
    d = 3.0
    t = t_axis(d)
    g = additive(110, d, [1, 1.47, 2.09, 2.56, 3.18, 4.2], [0.9, 1.2, 1.6, 2.0, 2.6, 3.4], [1, 0.6, 0.5, 0.35, 0.25, 0.15], vib=0.002)
    g += fft_filter(noise(d), 300, 3000) * np.exp(-t * 18) * 0.3
    sfx("start", g, rev=(2.5, 0.25))

    # UI.
    t = t_axis(0.09)
    click = np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 90) + fft_filter(noise(0.09), 2000, 8000) * np.exp(-t * 160) * 0.3
    sfx("ui_click", click)
    t = t_axis(0.12)
    back = np.sin(2 * np.pi * 900 * t) * np.exp(-t * 60)
    sfx("ui_back", back)
    x = np.zeros(int(0.2 * SR))
    place(x, np.sin(2 * np.pi * 1200 * t_axis(0.07)) * np.exp(-t_axis(0.07) * 50), 0)
    place(x, np.sin(2 * np.pi * 1600 * t_axis(0.09)) * np.exp(-t_axis(0.09) * 50), 0.06)
    sfx("ui_toggle", x)

    # Slither loop (2 s, seamless): rustle of scales on grass.
    d = 2.0
    t = t_axis(d)
    n = fft_filter(noise(d), 1800, 7500)
    mod = 0.55 + 0.45 * np.sin(2 * np.pi * 4.0 * t) ** 2  # 4 Hz divides 2 s
    x = n * mod
    x = _make_seamless(x)
    write_ogg(os.path.join(OUT, "sfx", "slither_loop.ogg"), normalize(x, 0.6), 3)


def _make_seamless(x, xf=0.15):
    """Crossfade the tail into the head so the buffer loops without a click."""
    n = int(xf * SR)
    head = x[:n].copy()
    tail = x[-n:].copy()
    k = np.linspace(0, 1, n)
    if x.ndim == 2:
        k = k[:, None]
    x = x[:-n].copy()
    x[:n] = tail * (1 - k) + head * k
    return x


# ----------------------------------------------------------------------------- ambience

def make_ambient():
    d = 32.0
    n = int(d * SR)
    out = np.zeros((n, 2))
    t = np.arange(n) / SR
    # Wind: low-passed noise with slow swells (periods divide the loop length).
    for c in range(2):
        w = fft_filter(rng.standard_normal(n), 80, 900)
        swell = 0.5 + 0.3 * np.sin(2 * np.pi * t / 16.0 + c) + 0.2 * np.sin(2 * np.pi * t / 8.0 + 2 * c)
        out[:, c] += w * swell * 0.25
    # Water lapping: soft band-passed bursts at irregular intervals.
    mono = np.zeros(n)
    tt = 0.3
    while tt < d:
        dur = rng.uniform(0.5, 1.1)
        k = np.linspace(0, 1, int(dur * SR))
        lap = fft_filter(rng.standard_normal(len(k)), 250, 2200) * np.sin(np.pi * k) ** 2 * rng.uniform(0.15, 0.32)
        place_wrap(mono, lap, tt)
        tt += rng.uniform(0.6, 1.6)
    pan = 0.5 + 0.2 * np.sin(2 * np.pi * t / 32.0)
    out[:, 0] += mono * pan
    out[:, 1] += mono * (1 - pan)
    # Birds: sparse FM chirps.
    tt = 1.5
    while tt < d - 1:
        f0 = rng.uniform(2400, 4200)
        notes = rng.integers(2, 5)
        side = rng.uniform(0.2, 0.8)
        for i in range(notes):
            cd = rng.uniform(0.06, 0.14)
            ct = t_axis(cd)
            sweep = f0 * (1 + rng.uniform(-0.25, 0.35) * ct / cd)
            chirp = np.sin(2 * np.pi * np.cumsum(sweep) / SR) * np.sin(np.pi * ct / cd) ** 2 * 0.08
            place_wrap(out[:, 0], chirp * side, tt + i * (cd + 0.03))
            place_wrap(out[:, 1], chirp * (1 - side), tt + i * (cd + 0.03))
        tt += rng.uniform(2.5, 6.0)
    out = _make_seamless(out, 0.5)
    write_ogg(os.path.join(OUT, "sfx", "ambient_lake.ogg"), normalize(out, 0.7), 3)


# ----------------------------------------------------------------------------- music

SCALE_D_MINOR_PENTA = [62, 65, 67, 69, 72, 74, 77, 79, 81, 84]


def render_loop(builder, length):
    """Render two passes and keep the second so reverb tails wrap seamlessly."""
    n = int(length * SR)
    dry = np.zeros(n * 2)
    builder(dry, length, 0.0)
    builder(dry, length, length)
    wet = reverb(dry, 2.6, 0.3)
    return wet[n:2 * n]


def menu_builder(buf, L, off):
    bpm = 72
    beat = 60 / bpm
    bar = beat * 4
    chords = [[50, 57, 62, 65, 69], [46, 53, 58, 62, 69], [41, 48, 57, 60, 65], [48, 55, 60, 64, 67]]
    local = np.random.default_rng(7)
    for b in range(16):
        ch = chords[(b // 2) % 4]
        if b % 2 == 0:
            place(buf, saw_pad([midi(n) for n in ch[1:]], bar * 2 + 1.0, attack=1.2, release=1.4) * 0.16, off + b * bar)
            place(buf, pluck(midi(ch[0] - 12), bar * 2, 0.5) * 0.35, off + b * bar)
        # Melody: gentle kalimba on the pentatonic scale.
        pos = 0.0
        idx = local.integers(2, 7)
        while pos < 4:
            step = local.choice([1.0, 1.0, 0.5, 1.5, 2.0])
            if local.random() < 0.8:
                idx = int(np.clip(idx + local.choice([-2, -1, 1, 2]), 0, len(SCALE_D_MINOR_PENTA) - 1))
                vel = 0.32 if pos == 0 else 0.22
                place(buf, kalimba(midi(SCALE_D_MINOR_PENTA[idx]), 1.8) * vel, off + b * bar + pos * beat)
            pos += step


def game_builder(buf, L, off):
    bpm = 100
    beat = 60 / bpm
    bar = beat * 4
    roots = [50, 46, 48, 45]  # Dm Bb C Am
    chord_tones = [[62, 65, 69, 74], [58, 62, 65, 70], [60, 64, 67, 72], [57, 60, 64, 69]]
    local = np.random.default_rng(11)
    motif = [(0, 2), (0.75, 4), (1.5, 3), (2.5, 5), (3.0, 4)]
    for b in range(16):
        ci = (b // 2) % 4
        t0 = off + b * bar
        # Frame drum: low boom on 1 and the "and" of 2, slap on 3.
        for bt, kind in [(0, "boom"), (1.5, "boom"), (2, "slap"), (3.5, "ghost")]:
            d = 0.5
            tt = t_axis(d)
            if kind == "boom":
                x = np.sin(2 * np.pi * (75 * np.exp(-tt * 9) + 52) * tt) * np.exp(-tt * 7) * 0.7
            elif kind == "slap":
                x = fft_filter(noise(d), 300, 3500) * np.exp(-tt * 28) * 0.45 + np.sin(2 * np.pi * 190 * tt) * np.exp(-tt * 20) * 0.3
            else:
                x = fft_filter(noise(d), 500, 4000) * np.exp(-tt * 35) * 0.18
            place(buf, x, t0 + bt * beat)
        # Shaker 8ths with swing-free accents.
        for s in range(8):
            d = 0.12
            tt = t_axis(d)
            acc = 0.13 if s % 2 == 0 else 0.07
            place(buf, fft_filter(noise(d), 4000, 11000) * np.exp(-tt * 45) * acc, t0 + s * beat * 0.5)
        # Bass.
        for bt in [0, 1.5, 2.5]:
            place(buf, pluck(midi(roots[ci] - 12), 0.9, 0.45) * 0.55, t0 + bt * beat)
        # Pad every two bars.
        if b % 2 == 0:
            place(buf, saw_pad([midi(n) for n in chord_tones[ci][:3]], bar * 2, attack=0.3, release=0.8, harmonics=6) * 0.1, t0)
        # Melody: motif with variation on even bars, answer on odd bars.
        if b >= 2:
            tones = chord_tones[ci] + [n + 12 for n in chord_tones[ci]]
            pattern = motif if b % 2 == 0 else [(0.5, 3), (1.0, 2), (2.0, 4), (3.25, 6)]
            for bt, deg in pattern:
                deg = int(np.clip(deg + (local.integers(-1, 2) if b % 4 == 3 else 0), 0, len(tones) - 1))
                place(buf, kalimba(midi(tones[deg]), 1.0) * 0.28, t0 + bt * beat)
                place(buf, pluck(midi(tones[deg]), 0.6, 1.4) * 0.12, t0 + bt * beat)


def make_music():
    menu = render_loop(menu_builder, 16 * 4 * 60 / 72)
    write_ogg(os.path.join(OUT, "music", "menu_theme.ogg"), normalize(menu, 0.8), 4)
    game = render_loop(game_builder, 16 * 4 * 60 / 100)
    write_ogg(os.path.join(OUT, "music", "game_theme.ogg"), normalize(game, 0.82), 4)


if __name__ == "__main__":
    which = sys.argv[1:] or ["sfx", "ambient", "music"]
    if "sfx" in which:
        make_sfx()
    if "ambient" in which:
        make_ambient()
    if "music" in which:
        make_music()
    print("audio generated")
