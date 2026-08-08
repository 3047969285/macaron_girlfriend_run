import math
import os
import random
import struct
import wave

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
SR = 44100


def clamp(v: float) -> int:
    return max(-32767, min(32767, int(v)))


def sine(freq: float, t: float, vol: float = 0.35) -> float:
    return vol * math.sin(2 * math.pi * freq * t)


def env(t: float, atk: float = 0.01, dec: float = 0.08, dur: float = 0.12) -> float:
    if t < 0:
        return 0
    if t < atk:
        return t / atk
    if t < dur:
        return max(0, 1 - (t - atk) / dec)
    return 0


def save(name: str, samples: list[float]) -> None:
    os.makedirs(ROOT, exist_ok=True)
    path = os.path.join(ROOT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsamplewidth(2)
        w.setframerate(SR)
        for s in samples:
            w.writeframesraw(struct.pack("<h", clamp(s)))


def tone(freq: float, dur: float, vol: float = 0.35, bend: float = 0) -> list[float]:
    n = int(SR * dur)
    out: list[float] = []
    for i in range(n):
        t = i / SR
        f = freq + bend * t
        out.append(sine(f, t, vol) * env(t, 0.005, dur * 0.7, dur))
    return out


def noise(dur: float, vol: float = 0.15) -> list[float]:
    n = int(SR * dur)
    out: list[float] = []
    for i in range(n):
        t = i / SR
        out.append((random.random() * 2 - 1) * vol * env(t, 0.001, dur * 0.5, dur))
    return out


def mix(*tracks: list[float]) -> list[float]:
    m = max(len(t) for t in tracks)
    out = [0.0] * m
    for tr in tracks:
        for i, v in enumerate(tr):
            out[i] += v
    return out


def main() -> None:
    save("sfx_click.wav", tone(880, 0.05, 0.25))
    save("sfx_jump.wav", mix(tone(520, 0.08, 0.28, 420), tone(780, 0.1, 0.18, 300)))
    save("sfx_coin.wav", mix(tone(988, 0.06, 0.3), tone(1318, 0.09, 0.22)))
    save(
        "sfx_stomp.wav",
        mix(tone(180, 0.07, 0.45, -80), tone(120, 0.12, 0.35, -40), noise(0.08, 0.25)),
    )
    save("sfx_hurt.wav", mix(tone(220, 0.15, 0.35, -120), tone(160, 0.2, 0.25, -60)))
    save(
        "sfx_powerup.wav",
        mix(tone(440, 0.08, 0.25, 180), tone(660, 0.12, 0.25, 220), tone(880, 0.16, 0.2, 260)),
    )
    win: list[float] = []
    for f, d in [(523, 0.12), (659, 0.12), (784, 0.18), (1046, 0.25)]:
        win += tone(f, d, 0.28)
    save("sfx_win.wav", win)
    notes = [
        (523, 0.18),
        (659, 0.18),
        (784, 0.18),
        (659, 0.18),
        (587, 0.18),
        (740, 0.18),
        (880, 0.18),
        (740, 0.18),
        (659, 0.18),
        (784, 0.18),
        (988, 0.22),
        (784, 0.18),
        (698, 0.18),
        (880, 0.18),
        (1046, 0.24),
        (880, 0.18),
    ]
    bgm: list[float] = []
    for freq, dur in notes * 2:
        bgm += tone(freq, dur, 0.16)
        bgm += [0.0] * int(SR * 0.02)
    save("bgm_loop.wav", bgm)
    print("generated", len(os.listdir(ROOT)), "files")


if __name__ == "__main__":
    main()
