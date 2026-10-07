"""Synthesizes looping ambient beds into audio/ambience/<name>.ogg: what each region sounds
like under the music (wind over the peaks, the fire's crackle and roar, rain, a cave's drips
and hum, the forest's breeze and birds, the castle's draughts and low drone). Each loop is
made seamless by crossfading its end into its start. Run from the project root:

    python tools/make_ambience.py
"""
import os

import numpy as np
import soundfile as sf

SR = 22050
LENGTH = 14.0
XFADE = 2.0
OUT = "audio/ambience/%s.ogg"
rng = np.random.default_rng(11)


def smooth(x, k):
    kernel = np.ones(k) / k
    return np.convolve(x, kernel, mode="same")


def noise(seconds):
    return rng.standard_normal(int(seconds * SR))


def slow(seconds, rate, depth=0.5):
    """A slow wandering swell, 0..1."""
    n = int(seconds * SR)
    points = rng.uniform(1 - depth, 1, int(seconds * rate) + 3)
    return np.interp(np.linspace(0, len(points) - 2, n), np.arange(len(points)), points)


def wind(seconds):
    x = smooth(noise(seconds), 40) * 3.0
    x = x - smooth(x, 400)  # take out the rumble
    return x * slow(seconds, 0.4, 0.8)


def crackle(seconds, density):
    x = np.zeros(int(seconds * SR))
    for _ in range(int(seconds * density)):
        at = rng.integers(0, len(x) - 400)
        length = rng.integers(40, 300)
        x[at:at + length] += rng.standard_normal(length) * np.exp(-np.arange(length) / (length / 4)) * rng.uniform(0.2, 1)
    return x


def drips(seconds, count, pitch=1400):
    x = np.zeros(int(seconds * SR))
    for _ in range(count):
        at = rng.integers(0, len(x) - 3000)
        f = pitch * rng.uniform(0.7, 1.3)
        t = np.arange(3000) / SR
        x[at:at + 3000] += np.sin(2 * np.pi * (f + 800 * np.exp(-t * 60)) * t) * np.exp(-t * 25) * rng.uniform(0.3, 1)
    return x


def drone(seconds, f, wobble=0.3):
    t = np.arange(int(seconds * SR)) / SR
    return (np.sin(2 * np.pi * f * t + wobble * np.sin(2 * np.pi * 0.1 * t))
            + 0.5 * np.sin(2 * np.pi * f * 1.5 * t)) * 0.3


def birds(seconds, count):
    x = np.zeros(int(seconds * SR))
    for _ in range(count):
        at = rng.integers(0, len(x) - 6000)
        t = np.arange(int(0.12 * SR)) / SR
        f0 = rng.uniform(2500, 4200)
        for k in range(rng.integers(2, 5)):
            start = at + k * int(0.16 * SR)
            chirp = np.sin(2 * np.pi * (f0 + 1500 * t / t[-1]) * t) * np.sin(np.pi * t / t[-1])
            x[start:start + len(chirp)] += chirp * 0.25
    return x


def rain(seconds):
    hiss = smooth(noise(seconds), 3) * 0.6
    return hiss + crackle(seconds, 400) * 0.25


def write(name, x):
    n = int(LENGTH * SR)
    fade = int(XFADE * SR)
    x = x[:n + fade]
    # The loop's end crossfades into its start, so it can play round forever.
    ramp = np.linspace(0, 1, fade)
    loop = x[:n].copy()
    loop[:fade] = x[:fade] * ramp + x[n:n + fade] * (1 - ramp)
    loop = loop / (np.max(np.abs(loop)) or 1) * 0.7
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with sf.SoundFile(OUT % name, "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        data = loop.astype(np.float32)
        for i in range(0, len(data), 8192):
            f.write(data[i:i + 8192])
    print("wrote", OUT % name)


def main():
    s = LENGTH + XFADE
    write("forest", wind(s) * 0.5 + birds(s, 5))
    write("cave", drone(s, 55) * 0.6 + drips(s, 14) * 0.5 + wind(s) * 0.15)
    write("snow", wind(s) * 1.0)
    write("fire", crackle(s, 120) * 0.6 + smooth(noise(s), 200) * 2.0 * slow(s, 0.6) + drone(s, 40) * 0.3)
    write("rain", rain(s) + wind(s) * 0.3)
    write("castle", drone(s, 49, 0.5) * 0.7 + wind(s) * 0.35 + drips(s, 4, 900) * 0.3)
    write("battlefield", wind(s) * 0.9 + drone(s, 36) * 0.25)


if __name__ == "__main__":
    main()
