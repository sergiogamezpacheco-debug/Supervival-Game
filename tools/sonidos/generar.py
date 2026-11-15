# Sonidos del juego sintetizados (propios, sin bancos externos). Requiere numpy.
#   cd tools/sonidos && python3 generar.py
import numpy as np, wave
SR = 22050
rng = np.random.default_rng(7)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, decay=6.0):
    x = np.arange(n) / SR
    return np.minimum(x / a, 1.0) * np.exp(-x * decay)
def noise(n): return rng.uniform(-1, 1, n)
def lp(x, k):   # paso bajo simple (media móvil exponencial)
    y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += (v - acc) * k; y[i] = acc
    return y
def hp(x, k): return x - lp(x, k)
def save(name, x, vol=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    with wave.open(f'../../assets/audio/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
def loopable(x, fade=0.4):   # funde el final con el principio
    n = int(SR * fade); r = np.linspace(0, 1, n)
    out = x[:-n].copy(); out[:n] = x[:n] * r + x[-n:] * (1 - r)
    return out

# Golpes
x = t(0.22); save('golpe', lp(noise(len(x)), 0.25) * env(len(x), decay=22) + 0.8 * np.sin(2 * np.pi * (140 - 300 * x) * x) * env(len(x), decay=18))
x = t(0.3); save('talar', lp(noise(len(x)), 0.5) * env(len(x), decay=30) + 0.7 * np.sin(2 * np.pi * 210 * x) * env(len(x), decay=20) + 0.3 * np.sin(2 * np.pi * 520 * x) * env(len(x), decay=35))
x = t(0.28); save('picar', hp(noise(len(x)), 0.3) * env(len(x), decay=40) * 0.6 + 0.6 * np.sin(2 * np.pi * 1850 * x) * env(len(x), decay=28) + 0.4 * np.sin(2 * np.pi * 2730 * x) * env(len(x), decay=34))
x = t(0.18); save('recoger', lp(noise(len(x)), 0.6) * env(len(x), a=0.03, decay=22), 0.5)
x = t(0.35); save('dano', (np.sin(2 * np.pi * (190 - 220 * x) * x) + 0.5 * lp(noise(len(x)), 0.15)) * env(len(x), decay=10))
x = t(0.5); save('romper', hp(noise(len(x)), 0.2) * env(len(x), decay=9) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 37 * x))))
x = t(0.25); save('esquivar', lp(noise(len(x)), 0.3) * np.sin(np.pi * x / 0.25) ** 2, 0.5)
# Infectados especiales
x = t(1.3); save('grito', (np.sin(2 * np.pi * (620 + 160 * np.sin(2 * np.pi * 7 * x) + 260 * x) * x) * 0.6 + hp(noise(len(x)), 0.4) * 0.5) * np.minimum(x / 0.08, 1) * np.exp(-np.maximum(x - 0.9, 0) * 8), 0.85)
x = t(0.7); save('reventar', lp(noise(len(x)), 0.2) * env(len(x), a=0.004, decay=7) + 0.7 * np.sin(2 * np.pi * (90 - 60 * x) * x) * env(len(x), decay=9) + 0.3 * lp(noise(len(x)), 0.05) * np.exp(-((x - 0.25) * 9) ** 2), 0.8)
x = t(0.9); save('pisoton', lp(noise(len(x)), 0.06) * env(len(x), a=0.003, decay=5) + np.sin(2 * np.pi * (55 - 25 * x) * x) * env(len(x), decay=4.5), 0.95)
x = t(0.4); save('lanzar', lp(noise(len(x)), 0.3) * np.sin(np.pi * x / 0.4) ** 2, 0.6)
# Interfaz
x = t(0.06); save('clic', np.sin(2 * np.pi * 900 * x) * env(len(x), decay=60), 0.4)
x = t(0.5); save('fabricar', sum(np.sin(2 * np.pi * f * x) * env(len(x), decay=7) * (x > d) for f, d in [(523, 0), (659, 0.09), (784, 0.18)]), 0.5)
x = t(0.3); save('error', np.sign(np.sin(2 * np.pi * 150 * x)) * env(len(x), decay=9) * 0.5, 0.3)
x = t(0.45); save('comer', sum(lp(noise(len(x)), 0.4) * np.exp(-((x - c) * 38) ** 2) for c in (0.07, 0.22, 0.36)), 0.6)
x = t(0.5); save('beber', sum(np.sin(2 * np.pi * (300 + 500 * (x - c)) * x) * np.exp(-((x - c) * 30) ** 2) for c in (0.1, 0.25, 0.4)), 0.5)
x = t(0.14); save('paso', lp(noise(len(x)), 0.18) * env(len(x), a=0.01, decay=38), 0.45)
x = t(0.9); save('grunido', lp(np.sign(np.sin(2 * np.pi * (70 + 18 * np.sin(2 * np.pi * 5 * x)) * x)) + 0.5 * noise(len(x)), 0.12) * np.sin(np.pi * x / 0.9) ** 1.5, 0.7)
x = t(1.6); save('muerte', (np.sin(2 * np.pi * (220 * np.exp(-x * 1.4)) * x) + 0.4 * np.sin(2 * np.pi * (330 * np.exp(-x * 1.4)) * x)) * env(len(x), a=0.02, decay=2.2), 0.6)
# Ambiente (bucles)
x = t(8.4); g = lp(noise(len(x)), 0.02) * 6; save('viento', loopable(lp(noise(len(x)), 0.06) * (0.55 + 0.45 * np.clip(g, -1, 1))), 0.5)
x = t(6.4); c = sum(np.sin(2 * np.pi * f * x) * (np.sin(2 * np.pi * r * x + p) > 0.55) * (0.5 + 0.5 * np.sin(2 * np.pi * 38 * x)) for f, r, p in [(4200, 1.25, 0), (3900, 0.9375, 1.3), (4600, 0.625, 2.1)]); save('grillos', loopable(c * 0.5 + lp(noise(len(x)), 0.03) * 0.8), 0.35)
x = t(5.4); save('lluvia', loopable(hp(lp(noise(len(x)), 0.55), 0.08)), 0.5)
# Música: colchón lento en la menor (bucle de 16 s)
x = t(16.7); m = np.zeros(len(x))
for k, chord in enumerate([(110, 164.8, 220, 261.6), (87.3, 174.6, 220, 261.6), (130.8, 196, 261.6, 329.6), (98, 196, 246.9, 293.7)]):
    seg = (x >= k * 4) & (x < k * 4 + 4.6); xs = x[seg] - k * 4
    e = np.minimum(xs / 1.2, 1) * np.minimum((4.6 - xs) / 1.2, 1)
    m[seg] += sum(np.sin(2 * np.pi * f * xs) + 0.3 * np.sin(2 * np.pi * f * 2.003 * xs) for f in chord) * e
m[: int(SR * 0.6)] += m[int(SR * 16):int(SR * 16) + int(SR * 0.6)]
save('musica', lp(m[: int(SR * 16)], 0.25), 0.5)
print('ok')
