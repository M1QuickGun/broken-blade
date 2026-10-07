"""Synthesizes the game's sound effects into audio/sfx/*.wav (mono, 22050 Hz, 16-bit).

Every sound is built from noise, tones and sweeps, shaped by envelopes and simple filters,
so they can be regenerated or tweaked here. Run from the project root:
    python tools/make_sfx.py
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = "audio/sfx"
rng = np.random.default_rng(7)


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def noise(seconds):
    return rng.uniform(-1.0, 1.0, int(RATE * seconds))


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be a number or an array (a sweep)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, low, high):
    return lowpass(highpass(x, low), high)


def env(seconds, attack, decay_power=2.0):
    """Quick attack, then a fall to silence over the rest."""
    t = t_axis(seconds)
    rise = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    fall = np.clip(1.0 - (t - attack) / max(seconds - attack, 1e-4), 0.0, 1.0) ** decay_power
    return rise * np.where(t < attack, 1.0, fall)


def tone(freq, seconds, shape="sine"):
    """A tone whose frequency may sweep (freq can be an array)."""
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (int(RATE * seconds),))
    phase = np.cumsum(2.0 * np.pi * freq / RATE)
    if shape == "square":
        return np.sign(np.sin(phase)) * 0.6
    if shape == "saw":
        return 2.0 * (phase / (2 * np.pi) % 1.0) - 1.0
    if shape == "tri":
        return 2.0 * np.abs(2.0 * (phase / (2 * np.pi) % 1.0) - 1.0) - 1.0
    return np.sin(phase)


def sweep(a, b, seconds, curve=1.0):
    t = np.linspace(0.0, 1.0, int(RATE * seconds)) ** curve
    return a + (b - a) * t


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def pad(x, before=0.0):
    return np.concatenate([np.zeros(int(RATE * before)), x])


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=float)
    peak = np.max(np.abs(x)) or 1.0
    x = np.clip(x / peak * gain, -1.0, 1.0)
    # Fade the last few ms so nothing clicks.
    fade = min(len(x), int(RATE * 0.01))
    x[-fade:] *= np.linspace(1.0, 0.0, fade)
    data = (x * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(name, round(len(x) / RATE, 2), "s")


def chime(freqs, step, seconds, shape="sine"):
    parts = []
    for i, f in enumerate(freqs):
        n = tone(f, seconds) if shape == "sine" else tone(f, seconds, shape)
        n = n + 0.3 * tone(f * 2.0, seconds)
        parts.append(pad(n * env(seconds, 0.005, 3.0), i * step))
    return mix(*parts)


def main():
    # Blade swing: a short swoosh of noise swept up then down.
    d = 0.2
    save("swing", bandpass(noise(d), sweep(400, 1800, d, 0.5), sweep(1500, 5000, d, 0.5)) * env(d, 0.04, 1.5), 0.6)

    # Hitting an enemy: a thump with a sharp crack on top.
    d = 0.14
    thump = tone(sweep(180, 60, d), d) * env(d, 0.002, 2.5)
    crack = highpass(noise(d), 2500) * env(d, 0.001, 6.0)
    save("hit", mix(thump, crack * 0.7), 0.8)

    # Hitting a boss: heavier, with a ring of struck stone or ice.
    d = 0.3
    thump = tone(sweep(120, 40, d), d) * env(d, 0.002, 2.0)
    ring = (tone(620, d) + 0.5 * tone(1310, d)) * env(d, 0.002, 4.0) * 0.4
    crack = highpass(noise(d), 2000) * env(d, 0.001, 8.0)
    save("hit_boss", mix(thump, ring, crack * 0.6), 0.85)

    # Storm hurt: a low dull blow and a short grunt-like buzz.
    d = 0.3
    blow = lowpass(noise(d), 500) * env(d, 0.003, 2.0)
    buzz = lowpass(tone(sweep(150, 90, d), d, "saw"), 900) * env(d, 0.01, 3.0) * 0.6
    save("hurt", mix(blow, buzz), 0.85)

    # Jump and land.
    d = 0.16
    save("jump", bandpass(noise(d), 300, sweep(1200, 3000, d)) * env(d, 0.02, 2.0), 0.35)
    d = 0.12
    save("land", lowpass(noise(d), 400) * env(d, 0.002, 3.0), 0.45)

    # Slide: a gritty scrape of ice.
    d = 0.4
    scrape = bandpass(noise(d), 1500, 6000) * (0.7 + 0.3 * np.sin(t_axis(d) * 2 * np.pi * 31))
    save("slide", scrape * env(d, 0.02, 1.2), 0.45)

    # Double jump spin: a whoosh of fire.
    d = 0.45
    roar = bandpass(noise(d), sweep(200, 600, d), sweep(1500, 4000, d)) * env(d, 0.05, 1.5)
    save("spin", roar, 0.6)

    # Shockline: a rising charge, then a crackling zap.
    d = 0.18
    charge = tone(sweep(300, 1400, d, 1.5), d, "square") * env(d, 0.15, 0.5) * 0.4
    save("shock_charge", lowpass(charge, 3000), 0.4)
    d = 0.35
    buzz = tone(sweep(900, 300, d), d, "saw") * (rng.uniform(0, 1, int(RATE * d)) > 0.6)
    crackle = highpass(noise(d), 3000) * (rng.uniform(0, 1, int(RATE * d)) > 0.85)
    save("shock_fire", mix(buzz * 0.6, crackle) * env(d, 0.002, 1.5), 0.55)

    # Flask: a couple of gulps, then a soft chime as it heals.
    d = 0.7
    gulps = mix(*[pad(lowpass(tone(sweep(260, 140, 0.09), 0.09), 800) * env(0.09, 0.01, 2.0), 0.08 + i * 0.13)
                  for i in range(3)])
    heal = pad(chime([880, 1320], 0.06, 0.5), 0.35)
    save("flask", mix(gulps * 0.7, heal * 0.5), 0.6)

    # Rest at a shrine: a slow rising chime.
    save("rest", chime([523, 659, 784, 1047], 0.12, 1.2), 0.55)

    # Pickups: a blade piece (grand), a mask shard (bright).
    piece = chime([392, 523, 659, 784, 1047], 0.09, 1.4, "tri")
    shimmer = highpass(noise(1.8), 5000) * env(1.8, 0.3, 2.0) * 0.15
    save("pickup", mix(piece, shimmer), 0.6)
    save("mask", chime([784, 988, 1175], 0.07, 0.8), 0.5)

    # An enemy dying: a crunch and a puff.
    d = 0.3
    crunch = bandpass(noise(d), 300, 2500) * env(d, 0.002, 3.0)
    save("enemy_die", mix(crunch, tone(sweep(200, 50, d), d) * env(d, 0.002, 3.0) * 0.6), 0.6)

    # The ground rumbling: something big moving underneath.
    d = 0.9
    rumble = lowpass(noise(d), 120) * (0.6 + 0.4 * np.sin(t_axis(d) * 2 * np.pi * 7))
    save("rumble", rumble * env(d, 0.15, 1.0), 0.8)

    # A boss roar: a growl of filtered noise and a falling saw.
    d = 1.2
    growl = bandpass(noise(d), 80, sweep(1400, 500, d)) * (0.7 + 0.3 * np.sin(t_axis(d) * 2 * np.pi * 23))
    voice = lowpass(tone(sweep(95, 60, d), d, "saw"), 700) * 0.6
    save("roar", mix(growl, voice) * env(d, 0.12, 1.3), 0.85)

    # A heavy slam: a boom with debris.
    d = 0.6
    boom = tone(sweep(90, 30, d, 0.6), d) * env(d, 0.003, 2.0)
    debris = lowpass(noise(d), 1500) * env(d, 0.005, 3.0) * 0.5
    save("slam", mix(boom, debris), 0.9)

    # Ice shattering: a crack and a spray of glassy tinkles.
    d = 0.9
    crack = highpass(noise(d), 1500) * env(d, 0.001, 6.0)
    tinkles = mix(*[pad(tone(rng.uniform(2500, 6000), 0.12) * env(0.12, 0.002, 4.0), rng.uniform(0.02, 0.6))
                    for _ in range(18)])
    save("shatter", mix(crack, tinkles * 0.35), 0.75)

    # Bursting out of the earth.
    d = 0.5
    burst = lowpass(noise(d), sweep(2500, 300, d)) * env(d, 0.005, 2.0)
    save("burst", mix(burst, tone(sweep(110, 45, d), d) * env(d, 0.005, 2.0) * 0.7), 0.8)

    # Menus: a soft tick to move, a brighter one to pick.
    save("menu_move", tone(1200, 0.04, "tri") * env(0.04, 0.002, 2.0), 0.3)
    save("menu_pick", chime([880, 1320], 0.04, 0.2, "tri"), 0.4)

    # The Ash bat's screech before it dives: a thin wavering shriek.
    d = 0.4
    shriek = tone(sweep(2600, 3400, d, 0.5) + 180 * np.sin(t_axis(d) * 2 * np.pi * 38), d, "saw")
    save("screech", bandpass(shriek, 1800, 6000) * env(d, 0.03, 1.6), 0.4)

    # Fire breath: a long roaring rush of flame.
    d = 1.4
    rush = bandpass(noise(d), 150, sweep(2500, 1200, d)) * (0.75 + 0.25 * np.sin(t_axis(d) * 2 * np.pi * 11))
    crackle = highpass(noise(d), 3500) * (rng.uniform(0, 1, int(RATE * d)) > 0.93)
    save("fire_breath", mix(rush, crackle * 0.5) * env(d, 0.15, 0.8), 0.8)

    # A great wingbeat: a deep whump of air.
    d = 0.5
    whump = lowpass(noise(d), sweep(900, 150, d)) * env(d, 0.06, 2.0)
    save("wing", mix(whump, tone(sweep(70, 40, d), d) * env(d, 0.05, 2.0) * 0.5), 0.75)

    # Thunder: a sharp crack, then a long low roll.
    d = 2.6
    crack = highpass(noise(d), 1200) * env(d, 0.002, 18.0)
    roll = lowpass(noise(d), sweep(400, 90, d)) * (0.6 + 0.4 * np.sin(t_axis(d) * 2 * np.pi * 3.0))
    save("thunder", mix(crack * 0.7, roll * env(d, 0.08, 1.4)), 0.85)

    # A lightning zap: a hard buzzing snap.
    d = 0.3
    buzz = tone(sweep(1400, 500, d), d, "square") * (rng.uniform(0, 1, int(RATE * d)) > 0.4)
    save("zap", mix(lowpass(buzz, 5000) * 0.6, highpass(noise(d), 4000) * 0.5) * env(d, 0.002, 2.0), 0.6)

    # Static crackling: scattered ticks.
    d = 0.35
    ticks = highpass(noise(d), 3000) * (rng.uniform(0, 1, int(RATE * d)) > 0.92)
    save("crackle", ticks * env(d, 0.01, 1.0), 0.5)

    # Footsteps, one for each kind of ground.
    d = 0.07
    save("step_stone", mix(highpass(noise(d), 2500) * env(d, 0.001, 6.0) * 0.6,
                           tone(sweep(220, 120, d), d) * env(d, 0.001, 4.0) * 0.5), 0.35)
    d = 0.13
    grains = bandpass(noise(d), 1500, 6000) * (rng.uniform(0, 1, int(RATE * d)) > 0.55)
    save("step_snow", grains * env(d, 0.01, 1.5), 0.32)
    d = 0.09
    save("step_grass", bandpass(noise(d), 800, 4000) * env(d, 0.01, 2.0), 0.25)
    d = 0.1
    save("step_wood", mix(tone(sweep(190, 130, d), d) * env(d, 0.001, 3.0),
                          bandpass(noise(d), 600, 2500) * env(d, 0.001, 5.0) * 0.4), 0.35)


if __name__ == "__main__":
    main()
