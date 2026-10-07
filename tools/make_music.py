"""Synthesizes the game's newer music tracks into audio/music/<name>.ogg (looping).

Placeholder-quality ambient and battle music made from simple voices (pads, an organ, a
choir-like pad, bells, a plucked string, bass and drums) through a small reverb. Each track
is a few bars of chords with a motif over them, written out below. Run from the project root:

    python tools/make_music.py [track ...]
"""
import sys

import numpy as np
import soundfile as sf

SR = 32000
OUT = "audio/music/%s.ogg"
NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
rng = np.random.default_rng(7)


def freq(name):
    """'A4' -> 440 Hz."""
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] + 12 * (octave - 4) - 9) / 12)


def env(n, attack, release, hold=1.0):
    e = np.ones(n) * hold
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    e[:a] = np.linspace(0, hold, a)
    if r < n:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def lowpass_fast(x, cutoff, passes=2):
    """A cheap lowpass: a moving average sized to the cutoff, run a couple of times."""
    k = max(1, int(SR / cutoff / 2))
    kernel = np.ones(k) / k
    for _ in range(passes):
        x = np.convolve(x, kernel, mode="same")
    return x


# --- voices: each returns a mono note of `dur` seconds ---

def pad(f, dur, bright=1.0):
    t = np.arange(int(dur * SR)) / SR
    x = np.zeros_like(t)
    for detune in (-0.006, 0.0, 0.007):
        ph = 2 * np.pi * f * (1 + detune) * t
        x += (2 * ((ph / (2 * np.pi)) % 1) - 1) * 0.33
    x = lowpass_fast(x, 900 * bright)
    return x * env(len(t), min(1.2, dur * 0.4), min(1.5, dur * 0.5))


def organ(f, dur):
    t = np.arange(int(dur * SR)) / SR
    x = sum(np.sin(2 * np.pi * f * h * t) * a for h, a in [(1, 1.0), (2, 0.5), (3, 0.25), (4, 0.18), (6, 0.08)])
    return x * 0.35 * env(len(t), 0.08, min(0.6, dur * 0.3))


def choir(f, dur):
    t = np.arange(int(dur * SR)) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t)
    x = np.zeros_like(t)
    for h, a in [(1, 1.0), (2, 0.45), (3, 0.3), (4, 0.12), (5, 0.08)]:
        x += np.sin(2 * np.pi * f * h * np.cumsum(vib) / SR) * a
    x += lowpass_fast(rng.standard_normal(len(t)) * 0.08, 1200)  # breath
    return x * 0.3 * env(len(t), min(0.9, dur * 0.4), min(1.2, dur * 0.5))


def bell(f, dur=3.0):
    t = np.arange(int(dur * SR)) / SR
    x = sum(np.sin(2 * np.pi * f * r * t) * a * np.exp(-t * d)
            for r, a, d in [(1, 1.0, 1.2), (2.0, 0.5, 2.0), (2.76, 0.35, 3.0), (5.4, 0.2, 5.0)])
    return x * 0.35


def pluck(f, dur=1.6, damp=0.996):
    """Karplus-Strong."""
    n = int(dur * SR)
    period = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, period)
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = damp * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out * 0.5


def bass(f, dur):
    t = np.arange(int(dur * SR)) / SR
    x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t)
    return x * 0.5 * env(len(t), 0.01, min(0.2, dur * 0.3))


def drum(kind, dur=0.6):
    t = np.arange(int(dur * SR)) / SR
    if kind == "low":  # a big war drum
        x = np.sin(2 * np.pi * (60 + 50 * np.exp(-t * 18)) * t) * np.exp(-t * 6)
        x += lowpass_fast(rng.standard_normal(len(t)), 600) * np.exp(-t * 20) * 0.5
        return x * 0.9
    if kind == "snare":
        x = rng.standard_normal(len(t)) * np.exp(-t * 22) * 0.4
        x += np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.4
        return x
    if kind == "tick":
        return rng.standard_normal(len(t)) * np.exp(-t * 80) * 0.15
    # timpani roll / thunder
    x = lowpass_fast(rng.standard_normal(len(t)), 300) * np.exp(-t * 1.5) * 1.2
    return x


# --- arranging ---

class Track:
    def __init__(self, bpm, bars, beats=4):
        self.beat = 60.0 / bpm
        self.length = bars * beats * self.beat
        self.n = int(self.length * SR)
        self.l = np.zeros(self.n + SR * 4)
        self.r = np.zeros(self.n + SR * 4)

    def add(self, beat, sound, gain=1.0, pan=0.0):
        start = int(beat * self.beat * SR)
        end = min(start + len(sound), len(self.l))
        sound = sound[:end - start] * gain
        self.l[start:end] += sound * (1 - max(0.0, pan))
        self.r[start:end] += sound * (1 + min(0.0, pan))

    def render(self, name, reverb=0.35):
        mix = np.stack([self.l, self.r], axis=1)
        mix = add_reverb(mix, reverb)
        # Fold the tail back onto the start so it loops without a seam.
        body = mix[:self.n].copy()
        tail = mix[self.n:]
        body[:len(tail)] += tail[:self.n]
        peak = np.max(np.abs(body)) or 1.0
        # Brought up to sit with the other tracks, a soft saturation keeping the peaks round.
        body = np.tanh(body / peak * 1.6) * 0.92
        # (Written in blocks: libsndfile's Vorbis encoder can fall over on one big write.)
        with sf.SoundFile(OUT % name, "w", SR, 2, format="OGG", subtype="VORBIS") as f:
            data = body.astype(np.float32)
            for i in range(0, len(data), 8192):
                f.write(data[i:i + 8192])
        print("wrote", OUT % name, "%.0f s" % self.length)


def add_reverb(mix, amount):
    out = mix.copy()
    for delay, gain in [(0.029, 0.5), (0.037, 0.45), (0.041, 0.42), (0.053, 0.38)]:
        d = int(delay * SR)
        for ch in range(2):
            comb = np.zeros(len(mix))
            src = mix[:, ch]
            # A feedback comb, done in blocks of the delay for speed.
            for start in range(0, len(mix), d):
                end = min(start + d, len(mix))
                prev = comb[start - d:end - d] if start >= d else np.zeros(end - start)
                comb[start:end] = src[start:end] + prev[:end - start] * gain * 1.6 if start >= d else src[start:end]
            out[:, ch] += lowpass_fast(comb, 3000, 1) * amount * 0.25
    return out


def chord_notes(root, kind, octave):
    steps = {"m": [0, 3, 7], "M": [0, 4, 7], "sus": [0, 5, 7], "dim": [0, 3, 6], "m7": [0, 3, 7, 10]}[kind]
    base = NOTE[root] + 12 * octave
    out = []
    for s_ in steps:
        v = base + s_
        out.append(440.0 * 2 ** ((v - 57) / 12))
    return out


def lay_chords(track, chords, beats_each, voice, octave=3, gain=0.5):
    for i, (root, kind) in enumerate(chords):
        for k, f in enumerate(chord_notes(root, kind, octave)):
            track.add(i * beats_each, voice(f, beats_each * track.beat * 1.05), gain, pan=(k - 1) * 0.3)


def lay_melody(track, notes, voice, gain=0.5, pan=0.0):
    """notes: [(beat, 'A4', beats)], or a rest as None."""
    for beat, name, length in notes:
        if name:
            track.add(beat, voice(freq(name), length * track.beat) if voice not in (bell, pluck) else voice(freq(name)),
                      gain, pan)


# --- the tracks ---

def fire_slopes():
    """Smoke and ash: a low drone, a plucked ostinato in D phrygian, war drums far off."""
    t = Track(bpm=70, bars=16)
    chords = [("D", "m"), ("Eb", "M"), ("D", "m"), ("C", "m"), ("D", "m"), ("Eb", "M"), ("Bb", "M"), ("A", "sus")]
    lay_chords(t, chords, 8, pad, octave=3, gain=0.4)
    for bar in range(16):
        t.add(bar * 4, bass(freq("D2"), 4 * t.beat), 0.5)
        for k, n in enumerate(["D4", "A3", "Eb4", "A3", "D4", "A3", "F4", "E4"]):
            if bar >= 2:
                t.add(bar * 4 + k * 0.5, pluck(freq(n), 1.2), 0.35, pan=0.25)
        if bar % 2 == 1:
            t.add(bar * 4 + 3, drum("low"), 0.5, pan=-0.2)
            t.add(bar * 4 + 3.5, drum("low"), 0.3, pan=-0.2)
    melody = [(32, "A4", 4), (36, "Bb4", 2), (38, "A4", 2), (40, "G4", 4), (44, "F4", 4),
              (48, "E4", 3), (51, "F4", 1), (52, "G4", 4), (56, "A4", 8)]
    lay_melody(t, melody, choir, 0.35, pan=-0.2)
    t.render("fire_slopes", 0.4)


def lightning_peaks():
    """Wind and wide air: high pads, bell motifs, thunder rolling at the ends of phrases."""
    t = Track(bpm=78, bars=16)
    chords = [("E", "m"), ("C", "M"), ("G", "M"), ("D", "M"), ("E", "m"), ("C", "M"), ("A", "m"), ("B", "sus")]
    lay_chords(t, chords, 8, lambda f, d: pad(f, d, 1.6), octave=4, gain=0.3)
    lay_chords(t, chords, 8, choir, octave=3, gain=0.25)
    for bar in range(16):
        t.add(bar * 4, bass(freq("E2") if bar % 4 < 2 else freq("C2"), 4 * t.beat), 0.35)
        if bar % 4 == 3:
            t.add(bar * 4 + 2, drum("roll", 3.5), 0.6, pan=0.3)
    motif = ["B5", "G5", "E5", "F#5", "G5", "D5", "E5", None]
    for phrase in range(4):
        for k, n in enumerate(motif):
            if n:
                t.add(phrase * 16 + k * 1.5, bell(freq(n), 3.0), 0.3, pan=(-0.4 if k % 2 else 0.4))
    t.render("lightning_peaks", 0.5)


def castle():
    """Cold halls: a slow organ, a choir under it, a bell tolling."""
    t = Track(bpm=58, bars=16)
    chords = [("C", "m"), ("Ab", "M"), ("Eb", "M"), ("Bb", "M"), ("C", "m"), ("F", "m"), ("G", "M"), ("G", "sus")]
    lay_chords(t, chords, 8, organ, octave=3, gain=0.35)
    lay_chords(t, chords, 8, choir, octave=4, gain=0.2)
    for bar in range(0, 16, 2):
        t.add(bar * 4, bell(freq("C4"), 4.0), 0.35, pan=0.3)
        t.add(bar * 4, bass(freq("C2"), 6 * t.beat), 0.4)
    melody = [(0, "G4", 4), (4, "Ab4", 2), (6, "G4", 2), (8, "Eb4", 6), (14, "D4", 2), (16, "C4", 8),
              (32, "Eb5", 4), (36, "D5", 2), (38, "C5", 2), (40, "Bb4", 4), (44, "Ab4", 4), (48, "G4", 8),
              (56, "B4", 8)]
    lay_melody(t, melody, organ, 0.3, pan=-0.15)
    t.render("castle", 0.6)


def refuge():
    """The campfire: a plucked lute walking through warm chords, a soft pad."""
    t = Track(bpm=72, bars=16)
    chords = [("F", "M"), ("C", "M"), ("D", "m"), ("Bb", "M"), ("F", "M"), ("C", "M"), ("Bb", "M"), ("C", "sus")]
    lay_chords(t, chords, 8, lambda f, d: pad(f, d, 0.7), octave=3, gain=0.3)
    for i, (root, kind) in enumerate(chords):
        notes = chord_notes(root, kind, 4)
        pattern = [notes[0], notes[1], notes[2], notes[1]] * 4
        for k, f in enumerate(pattern):
            t.add(i * 8 + k * 0.5, pluck(f, 1.4, 0.995), 0.3, pan=0.2)
        t.add(i * 8, bass(chord_notes(root, kind, 2)[0], 8 * t.beat), 0.35)
    t.render("refuge", 0.45)


def boss():
    """A fight: a driving bass in eighths, drums, staccato stabs, a horn-like line over it."""
    t = Track(bpm=132, bars=16)
    roots = ["A2", "A2", "F2", "G2", "A2", "A2", "D2", "E2"]
    for bar in range(16):
        r = freq(roots[(bar // 2) % len(roots)])
        for k in range(8):
            t.add(bar * 4 + k * 0.5, bass(r * (2 if k in (3, 7) else 1), 0.45 * t.beat), 0.5)
        t.add(bar * 4, drum("low"), 0.8)
        t.add(bar * 4 + 2, drum("snare"), 0.6)
        t.add(bar * 4 + 2.5, drum("low"), 0.4)
        t.add(bar * 4 + 3, drum("snare"), 0.4)
        for k in range(8):
            t.add(bar * 4 + k * 0.5, drum("tick"), 0.5, pan=0.4)
        if bar % 2 == 0:
            for f in chord_notes({"A2": "A", "F2": "F", "G2": "G", "D2": "D", "E2": "E"}[roots[(bar // 2) % 8]], "m", 4):
                t.add(bar * 4 + 1.5, pad(f, 0.4 * t.beat, 2.0), 0.4, pan=-0.3)
    horn = [(16, "E4", 2), (18, "A4", 2), (20, "C5", 3), (23, "B4", 1), (24, "A4", 4), (28, "G4", 2), (30, "E4", 2),
            (32, "F4", 4), (36, "E4", 2), (38, "D4", 2), (40, "E4", 8),
            (48, "A4", 2), (50, "C5", 2), (52, "E5", 3), (55, "D5", 1), (56, "C5", 4), (60, "B4", 4)]
    lay_melody(t, horn, lambda f, d: pad(f, d, 1.4), 0.45, pan=0.1)
    t.render("boss", 0.25)


def final_boss():
    """The end of it: choir and organ over the battle drums, in D minor."""
    t = Track(bpm=126, bars=16)
    chords = [("D", "m"), ("D", "m"), ("Bb", "M"), ("C", "M"), ("D", "m"), ("G", "m"), ("A", "M"), ("A", "sus")]
    lay_chords(t, chords, 8, choir, octave=4, gain=0.35)
    lay_chords(t, chords, 8, organ, octave=3, gain=0.25)
    for bar in range(16):
        root = chord_notes(chords[bar // 2][0], "m", 2)[0]
        for k in range(8):
            t.add(bar * 4 + k * 0.5, bass(root, 0.45 * t.beat), 0.45)
        for b in (0, 1.5, 2, 3):
            t.add(bar * 4 + b, drum("low"), 0.7 if b == 0 else 0.45)
        t.add(bar * 4 + 1, drum("snare"), 0.4)
        t.add(bar * 4 + 3, drum("snare"), 0.5)
        if bar % 4 == 3:
            t.add(bar * 4 + 2, drum("roll", 2.0), 0.5)
    line = [(0, "D5", 4), (4, "F5", 4), (8, "E5", 2), (10, "D5", 2), (12, "A4", 4), (16, "Bb4", 4), (20, "C5", 4),
            (24, "D5", 8), (32, "A5", 4), (36, "G5", 2), (38, "F5", 2), (40, "E5", 4), (44, "D5", 4),
            (48, "C#5", 4), (52, "E5", 4), (56, "D5", 8)]
    lay_melody(t, line, choir, 0.45, pan=-0.1)
    for phrase in range(4):
        t.add(phrase * 16, bell(freq("D4"), 4.0), 0.3, pan=0.35)
    t.render("final_boss", 0.3)


TRACKS = {"fire_slopes": fire_slopes, "lightning_peaks": lightning_peaks, "castle": castle,
          "refuge": refuge, "boss": boss, "final_boss": final_boss}

if __name__ == "__main__":
    for name in sys.argv[1:] or TRACKS:
        TRACKS[name]()
