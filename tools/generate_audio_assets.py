#!/usr/bin/env python3
"""Generate the original procedural prototype audio shipped with Toy Racers."""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22_050
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "audio"


def write(name, duration, sample):
    frames = bytearray()
    count = int(duration * RATE)
    for index in range(count):
        value = max(-1.0, min(1.0, sample(index / RATE, index, count)))
        frames.extend(struct.pack("<h", int(value * 32767)))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT / name), "wb") as output:
        output.setparams((1, 2, RATE, count, "NONE", "not compressed"))
        output.writeframes(frames)


def envelope(index, count, attack=0.02, release=0.08):
    attack_samples = max(1, int(RATE * attack))
    release_samples = max(1, int(RATE * release))
    return min(1.0, index / attack_samples, (count - index - 1) / release_samples)


def tone(frequency, volume=0.5):
    return lambda time, index, count: (
        math.sin(2 * math.pi * frequency * time) * volume * envelope(index, count)
    )


random_source = random.Random(19)
noise = [random_source.uniform(-1, 1) for _ in range(RATE)]

write(
    "engine-loop.wav",
    1.0,
    lambda time, _index, _count: 0.22 * math.sin(2 * math.pi * 55 * time)
    + 0.10 * math.sin(2 * math.pi * 110 * time)
    + 0.04 * math.sin(2 * math.pi * 165 * time),
)
write(
    "skid-loop.wav",
    1.0,
    lambda _time, index, _count: 0.19
    * (noise[index] - 0.65 * noise[(index - 1) % RATE]),
)
write(
    "collision.wav",
    0.32,
    lambda time, index, count: (
        noise[index % RATE] * 0.55 + math.sin(2 * math.pi * 82 * time) * 0.4
    )
    * envelope(index, count, 0.005, 0.28),
)
write("countdown-beep.wav", 0.16, tone(660, 0.55))
write("go.wav", 0.35, lambda time, index, count: tone(880 + time * 500, 0.58)(time, index, count))
write("checkpoint.wav", 0.22, lambda time, index, count: tone(740 + time * 900, 0.48)(time, index, count))
write(
    "finish.wav",
    1.0,
    lambda time, index, count: (
        math.sin(2 * math.pi * (523 if time < 0.32 else 659 if time < 0.64 else 784) * time)
        * 0.48
        * envelope(index, count, 0.01, 0.22)
    ),
)
write("button-click.wav", 0.07, tone(980, 0.35))

notes = (130.81, 164.81, 196.0, 164.81, 146.83, 174.61, 220.0, 174.61)
write(
    "background-music.wav",
    8.0,
    lambda time, _index, _count: 0.16
    * math.sin(2 * math.pi * notes[int(time) % len(notes)] * time)
    + 0.07 * math.sin(2 * math.pi * notes[int(time) % len(notes)] * 2 * time),
)
