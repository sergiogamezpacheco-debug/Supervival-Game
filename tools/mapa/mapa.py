# Mapa del valle en papel, dibujado por código (estilo del mapa del juego: papel viejo, tinta, manchas).
#   python3 tools/mapa/mapa.py [salida_dir]
# Saca:
#   mapa_definitivo.jpg  -> las 3 partes cosidas (todo descubierto)
#   mapa_parte1.jpg      -> lo que tienes al empezar
#   mapa_parte2.jpg      -> parte 1 + trozo del muerto del bosque

# Lugares y caminos: data/routes.json (nombres de los tramos) + LUGARES de aquí abajo.
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H = 2000, 1380
INK = (66, 44, 26)
INK_SOFT = (96, 70, 44)
TREE = (74, 98, 58)
TREE_D = (48, 68, 40)
WATER = (122, 160, 168)
WATER_D = (70, 110, 120)
RED = (150, 40, 30)
FONTS = "/usr/share/fonts/truetype/google-fonts/ofl/"


def font(name, size):
    return ImageFont.truetype(FONTS + name, size)


F_TITLE = font("cardo/Cardo-Bold.ttf", 64)
F_SUB = font("cardo/Cardo-Italic.ttf", 28)
F_LABEL = font("crimsontext/CrimsonText-Bold.ttf", 34)
F_LABEL_S = font("crimsontext/CrimsonText-SemiBold.ttf", 25)
F_NOTE = font("crimsontext/CrimsonText-BoldItalic.ttf", 25)
F_ROUTE = font("crimsontext/CrimsonText-Italic.ttf", 22)
F_LEG = font("crimsontext/CrimsonText-SemiBold.ttf", 24)
F_GRID = font("cardo/Cardo-Regular.ttf", 26)
F_ROMAN = font("cardo/Cardo-Bold.ttf", 46)


def P(x, y):
    return (x * W, y * H)


# ------------------------------------------------------------------ lugares
# parte: 1 al empezar, 2 trozo del muerto de La Arboleda, 3 trozo de la Base Centinela
# Posición, nombre y pieza de cada lugar: data/world_map.json (lo mismo que usa el juego)
ICONOS = {"refugio": "refugio", "arboleda": "arbol", "pedregal": "rocas", "pinar": "pino", "cantera": "pico", "atalaya": "atalaya", "marismas": "juncos", "centinela": "tienda", "villamuralla": "muralla", "puerto": "ancla", "valdecruces": "ruinas", "estacion": "tren", "central": "radiacion"}


def _lugares():
    wm = json.load(open(os.path.join(RAIZ, "data", "world_map.json")))
    out = {}
    for k, v in wm.items():
        key = "pinar" if k == "bosque" else k
        out[key] = {"name": v["name"], "pos": tuple(v["pos"]), "part": int(v.get("piece", 1)), "icon": ICONOS.get(key, "pino")}
    return out


LUGARES = _lugares()

# Trazado de cada camino (puntos intermedios); nombre y parte salen de data/routes.json
TRAZADOS = {
    "r_refugio_arboleda": [(0.525, 0.53), (0.485, 0.515), (0.45, 0.485)],
    "r_refugio_pedregal": [(0.525, 0.53), (0.59, 0.54), (0.64, 0.525)],
    "r_refugio_pinar": [(0.525, 0.53), (0.575, 0.47), (0.615, 0.41)],
    "r_refugio_cantera": [(0.525, 0.53), (0.505, 0.44), (0.475, 0.335)],
    "r_pinar_atalaya": [(0.675, 0.30), (0.73, 0.27), (0.795, 0.25)],
    "r_atalaya_marismas": [(0.825, 0.27), (0.845, 0.36), (0.85, 0.45)],
    "r_refugio_centinela": [(0.525, 0.53), (0.45, 0.575), (0.37, 0.56), (0.31, 0.49), (0.255, 0.435)],
    "r_centinela_puerto": [(0.23, 0.445), (0.205, 0.56), (0.19, 0.68), (0.185, 0.8)],
    "r_cantera_villamuralla": [(0.455, 0.27), (0.39, 0.22), (0.31, 0.185), (0.255, 0.17)],
    "r_via_puerto_estacion": None,   # van por la vía
    "r_via_estacion_central": None,
}
VIA = [(0.0, 0.79), (0.1, 0.8), (0.2, 0.805), (0.28, 0.765), (0.36, 0.735), (0.45, 0.765), (0.535, 0.81),
       (0.62, 0.82), (0.7, 0.815), (0.8, 0.8), (1.0, 0.79)]
RIO = [(0.70, 0.0), (0.705, 0.1), (0.715, 0.2), (0.735, 0.32), (0.765, 0.42), (0.815, 0.5), (0.81, 0.6),
       (0.7, 0.645), (0.57, 0.665), (0.44, 0.665), (0.32, 0.7), (0.24, 0.76)]
# Piezas del mapa (se cosen al encontrarlas)
PIEZA1 = [(0.37, 0.42), (0.45, 0.38), (0.56, 0.405), (0.66, 0.43), (0.74, 0.48), (0.745, 0.58), (0.67, 0.625),
          (0.52, 0.64), (0.4, 0.62), (0.355, 0.54)]
PIEZA2 = [(0.135, 0.33), (0.355, 0.27), (0.395, 0.11), (0.6, 0.095), (0.985, 0.1), (0.985, 0.665), (0.7, 0.685),
          (0.45, 0.675), (0.3, 0.665), (0.135, 0.63)]
# Parte del papel que se ve en el juego según las piezas que tengas (x, y, ancho, alto)
VISTAS = {1: (0.32, 0.28, 0.46, 0.46), 2: (0.12, 0.0, 0.88, 0.88), 3: (0.0, 0.0, 1.0, 1.0)}
# Casas sueltas con provisiones por los caminos (parte 2 y 3)
CASAS = [(0.335, 0.45, 2), (0.71, 0.255, 2), (0.84, 0.405, 2), (0.29, 0.475, 2), (0.21, 0.6, 3), (0.33, 0.2, 3)]
GASOLINERA = (0.325, 0.545)
# Coches abandonados con suministros (x, y, parte, giro)
COCHES = [(0.47, 0.585, 1, 15), (0.595, 0.555, 1, -20), (0.295, 0.515, 2, 30), (0.53, 0.37, 2, 70),
          (0.745, 0.315, 2, -10), (0.2, 0.66, 3, 80), (0.43, 0.755, 3, 10)]


# ------------------------------------------------------------------ utilidades
def smooth(pts, n=10):
    """Curva suave (Catmull-Rom) por los puntos."""
    if len(pts) < 3:
        return pts
    out = []
    p = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
    out.append(pts[-1])
    return out


def px(pts):
    return [P(x, y) for x, y in pts]


def torn(poly, rng, amp=0.008, step=0.012):
    """Borde rasgado: subdivide y mueve cada punto un poco hacia dentro o fuera."""
    out = []
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        d = math.dist(a, b)
        n = max(2, int(d / step))
        nx, ny = (b[1] - a[1]) / d, -(b[0] - a[0]) / d
        for k in range(n):
            t = k / n
            j = rng.uniform(-amp, amp)
            out.append((a[0] + (b[0] - a[0]) * t + nx * j, a[1] + (b[1] - a[1]) * t + ny * j * 1.4))
    return out


def noise(shape, scale, rng):
    a = rng.random((shape[0] // scale + 2, shape[1] // scale + 2))
    img = Image.fromarray((a * 255).astype(np.uint8)).resize((shape[1], shape[0]), Image.BICUBIC)
    return np.asarray(img).astype(float) / 255.0


def text_halo(d, xy, txt, f, fill=INK, halo=(236, 220, 186), anchor="mm", sw=4):
    d.text(xy, txt, font=f, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=halo)


def dashed(d, pts, dash=14, gap=9, fill=INK, width=3):
    acc, on = 0.0, True
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        seg = math.dist(a, b)
        pos = 0.0
        while pos < seg:
            lim = dash if on else gap
            step = min(lim - acc, seg - pos)
            if on:
                t0, t1 = pos / seg, (pos + step) / seg
                d.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0),
                        (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)], fill=fill, width=width)
            pos += step
            acc += step
            if acc >= lim - 1e-6:
                acc, on = 0.0, not on


def point_at(pts, t):
    """Punto y dirección a una fracción t del recorrido."""
    L = [0.0]
    for i in range(len(pts) - 1):
        L.append(L[-1] + math.dist(pts[i], pts[i + 1]))
    goal = L[-1] * t
    for i in range(len(pts) - 1):
        if L[i + 1] >= goal:
            k = (goal - L[i]) / max(L[i + 1] - L[i], 1e-6)
            a, b = pts[i], pts[i + 1]
            return (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k), math.atan2(b[1] - a[1], b[0] - a[0])
    return pts[-1], 0.0


# ------------------------------------------------------------------ dibujos
def tree(d, x, y, s, rng, col=TREE):
    c = tuple(max(0, min(255, v + rng.randint(-10, 10))) for v in col)
    d.line([(x, y), (x, y + s * 0.35)], fill=INK_SOFT, width=max(1, int(s * 0.12)))
    for k in range(2):
        yy = y - k * s * 0.38
        w = s * (0.55 - k * 0.14)
        d.polygon([(x, yy - s * 0.65), (x - w, yy + s * 0.15), (x + w, yy + s * 0.15)], fill=c, outline=TREE_D)


def leafy(d, x, y, s, rng):
    c = (96 + rng.randint(-8, 8), 118 + rng.randint(-8, 8), 70)
    d.line([(x, y), (x, y + s * 0.5)], fill=INK_SOFT, width=max(1, int(s * 0.14)))
    d.ellipse([x - s * 0.45, y - s * 0.5, x + s * 0.45, y + s * 0.25], fill=c, outline=TREE_D)


def forest(d, cx, cy, rx, ry, n, rng, size=26, leaf=False):
    pts = []
    for _ in range(n * 6):
        a, r = rng.uniform(0, math.tau), math.sqrt(rng.random())
        x, y = cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r * (0.85 + 0.3 * math.sin(a * 3 + cx))
        if all(math.dist((x, y), q) > size * 0.75 for q in pts):
            pts.append((x, y))
        if len(pts) >= n:
            break
    for x, y in sorted(pts, key=lambda p: p[1]):
        (leafy if leaf else tree)(d, x, y, size * rng.uniform(0.8, 1.15), rng)


def mountain(d, x, y, s, rng):
    w = s * rng.uniform(0.8, 1.1)
    top = (x + rng.uniform(-s * 0.1, s * 0.1), y - s)
    d.polygon([(x - w, y), top, (x + w, y)], fill=(208, 186, 146), outline=INK)
    d.polygon([top, (x + w, y), (top[0] + w * 0.15, y)], fill=(170, 146, 110))
    d.polygon([top, (top[0] - w * 0.28, top[1] + s * 0.3), (top[0], top[1] + s * 0.22), (top[0] + w * 0.28, top[1] + s * 0.3)],
              fill=(246, 240, 228), outline=INK)
    for k in range(3):
        xx = x - w * 0.6 + k * w * 0.25
        d.line([(xx, y - s * 0.15 * (k + 1)), (xx + w * 0.12, y - s * 0.05)], fill=INK_SOFT, width=2)


def rock(d, x, y, s, rng):
    pts = []
    n = rng.randint(6, 8)
    for k in range(n):
        a = math.tau * k / n
        r = s * rng.uniform(0.7, 1.0)
        pts.append((x + math.cos(a) * r, y + math.sin(a) * r * 0.65))
    d.polygon(pts, fill=(160, 150, 132), outline=INK)
    d.line([(x - s * 0.3, y - s * 0.1), (x + s * 0.2, y + s * 0.2)], fill=INK_SOFT, width=2)


def house(d, x, y, s, col=(188, 120, 84), broken=False):
    d.rectangle([x - s, y - s * 0.6, x + s, y + s * 0.6], fill=(214, 194, 158), outline=INK, width=2)
    d.polygon([(x - s * 1.15, y - s * 0.55), (x, y - s * 1.35), (x + s * 1.15, y - s * 0.55)], fill=col, outline=INK)
    d.rectangle([x - s * 0.25, y, x + s * 0.25, y + s * 0.6], fill=INK_SOFT)
    if broken:
        d.line([(x - s, y - s * 0.6), (x + s, y + s * 0.6)], fill=RED, width=3)
        d.line([(x + s, y - s * 0.6), (x - s, y + s * 0.6)], fill=RED, width=3)


def hatch(d, poly, col=RED, step=14, width=2):
    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    lay = Image.new("L", (W, H), 0)
    ld = ImageDraw.Draw(lay)
    for k in range(int(min(xs) - (max(ys) - min(ys))), int(max(xs)), step):
        ld.line([(k, max(ys)), (k + (max(ys) - min(ys)), min(ys))], fill=255, width=width)
    lay = Image.fromarray(np.minimum(np.asarray(lay), np.asarray(mask)))
    return lay, col


def badge(d, x, y, kind, r=30):
    d.ellipse([x - r - 4, y - r - 4, x + r + 4, y + r + 4], fill=(236, 220, 186), outline=INK, width=3)
    ring = RED if kind == "refugio" else INK
    d.ellipse([x - r, y - r, x + r, y + r], fill=(122, 52, 40) if kind == "refugio" else (92, 72, 50), outline=ring, width=2)
    c = (240, 228, 204)
    s = r * 0.55
    if kind == "refugio":
        d.polygon([(x - s, y), (x, y - s), (x + s, y)], fill=c)
        d.rectangle([x - s * 0.7, y, x + s * 0.7, y + s * 0.8], fill=c)
        d.rectangle([x - s * 0.2, y + s * 0.25, x + s * 0.2, y + s * 0.8], fill=(122, 52, 40))
    elif kind == "pino":
        d.polygon([(x, y - s * 1.1), (x - s * 0.8, y + s * 0.5), (x + s * 0.8, y + s * 0.5)], fill=c)
        d.rectangle([x - s * 0.12, y + s * 0.5, x + s * 0.12, y + s], fill=c)
    elif kind == "pico":
        d.line([(x - s * 0.7, y + s * 0.8), (x + s * 0.5, y - s * 0.6)], fill=c, width=5)
        d.arc([x - s * 0.5, y - s * 1.2, x + s * 1.3, y + s * 0.2], 160, 320, fill=c, width=6)
    elif kind == "atalaya":
        for k in range(5):
            xx = x - s + k * s * 0.5
            d.polygon([(xx - s * 0.2, y + s * 0.8), (xx - s * 0.2, y - s * 0.4), (xx, y - s * 0.7), (xx + s * 0.2, y - s * 0.4), (xx + s * 0.2, y + s * 0.8)], fill=c)
    elif kind == "muralla":
        d.rectangle([x - s, y - s * 0.3, x + s, y + s * 0.8], fill=c)
        for k in range(4):
            xx = x - s + k * s * 0.6
            d.rectangle([xx, y - s * 0.65, xx + s * 0.32, y - s * 0.3], fill=c)
        d.rectangle([x - s * 0.25, y + s * 0.1, x + s * 0.25, y + s * 0.8], fill=(92, 72, 50))
    elif kind == "tienda":
        d.polygon([(x - s, y + s * 0.7), (x, y - s * 0.8), (x + s, y + s * 0.7)], fill=c)
        d.polygon([(x - s * 0.25, y + s * 0.7), (x, y + s * 0.05), (x + s * 0.25, y + s * 0.7)], fill=(92, 72, 50))
    elif kind == "juncos":
        for k in range(5):
            xx = x - s * 0.8 + k * s * 0.4
            d.line([(xx, y + s * 0.8), (xx + (k - 2) * s * 0.12, y - s * 0.6)], fill=c, width=3)
        d.line([(x - s, y + s * 0.8), (x + s, y + s * 0.8)], fill=c, width=3)
    elif kind == "ancla":
        d.line([(x, y - s * 0.9), (x, y + s * 0.8)], fill=c, width=4)
        d.ellipse([x - s * 0.22, y - s * 1.1, x + s * 0.22, y - s * 0.65], outline=c, width=3)
        d.line([(x - s * 0.5, y - s * 0.4), (x + s * 0.5, y - s * 0.4)], fill=c, width=4)
        d.arc([x - s * 0.85, y - s * 0.2, x + s * 0.85, y + s * 0.9], 20, 160, fill=c, width=4)
    elif kind == "tren":
        d.rounded_rectangle([x - s * 0.7, y - s * 0.9, x + s * 0.7, y + s * 0.5], radius=6, fill=c)
        d.rectangle([x - s * 0.45, y - s * 0.65, x + s * 0.45, y - s * 0.15], fill=(92, 72, 50))
        d.line([(x - s * 0.5, y + s * 0.6), (x - s * 0.9, y + s)], fill=c, width=4)
        d.line([(x + s * 0.5, y + s * 0.6), (x + s * 0.9, y + s)], fill=c, width=4)
    elif kind == "radiacion":
        d.ellipse([x - s, y - s, x + s, y + s], fill=(232, 196, 70))
        for k in range(3):
            a0 = -90 + k * 120
            d.pieslice([x - s * 0.85, y - s * 0.85, x + s * 0.85, y + s * 0.85], a0 - 30, a0 + 30, fill=(40, 30, 20))
        d.ellipse([x - s * 0.18, y - s * 0.18, x + s * 0.18, y + s * 0.18], fill=(40, 30, 20))
    elif kind == "arbol":
        d.line([(x, y + s * 0.2), (x, y + s * 0.95)], fill=c, width=4)
        d.ellipse([x - s * 0.75, y - s * 0.85, x + s * 0.75, y + s * 0.4], fill=c)
    elif kind == "rocas":
        d.polygon([(x - s * 0.95, y + s * 0.7), (x - s * 0.7, y - s * 0.2), (x - s * 0.1, y - s * 0.45), (x + s * 0.2, y + s * 0.7)], fill=c)
        d.polygon([(x + s * 0.05, y + s * 0.7), (x + s * 0.3, y - s * 0.05), (x + s * 0.8, y + s * 0.1), (x + s * 0.95, y + s * 0.7)], fill=c)
    elif kind == "ruinas":
        d.rectangle([x - s * 0.8, y - s * 0.2, x - s * 0.1, y + s * 0.8], fill=c)
        d.polygon([(x + s * 0.1, y + s * 0.8), (x + s * 0.1, y - s * 0.6), (x + s * 0.5, y - s * 0.2), (x + s * 0.8, y - s * 0.5), (x + s * 0.8, y + s * 0.8)], fill=c)


def car(img, x, y, rot, s=1.0):
    """Coche visto desde arriba (cuerpo, cristales y ruedas), girado."""
    t = Image.new("RGBA", (80, 80), (0, 0, 0, 0))
    d = ImageDraw.Draw(t)
    for wx in (22, 58):
        for wy in (27, 53):
            d.rectangle([wx - 5, wy - 3, wx + 5, wy + 3], fill=INK)
    d.rounded_rectangle([14, 26, 66, 54], radius=8, fill=(150, 84, 60), outline=INK, width=2)
    d.rectangle([28, 30, 36, 50], fill=(110, 150, 160), outline=INK)
    d.rectangle([48, 30, 54, 50], fill=(110, 150, 160), outline=INK)
    t = t.rotate(rot, resample=Image.BICUBIC)
    if s != 1.0:
        t = t.resize((int(80 * s), int(80 * s)), Image.LANCZOS)
    img.alpha_composite(t, (int(x - t.width / 2), int(y - t.height / 2)))


def label(d, x, y, txt, f=F_LABEL, dy=50):
    text_halo(d, (x, y + dy), txt, f, sw=5)


def roman(n):
    return ["", "I", "II", "III"][n]


# ------------------------------------------------------------------ mapa completo
def draw_full(routes):
    rng = random.Random(7)
    nrng = np.random.default_rng(7)
    # papel: color base + manchas suaves + grano
    base = np.zeros((H, W, 3))
    base[:] = (222, 199, 152)
    n1 = noise((H, W), 160, nrng)
    n2 = noise((H, W), 40, nrng)
    n3 = nrng.random((H, W))
    shade = (n1 - 0.5) * 34 + (n2 - 0.5) * 14 + (n3 - 0.5) * 10
    base += shade[..., None] * np.array([1.0, 0.92, 0.8])
    yy, xx = np.mgrid[0:H, 0:W]
    vign = ((xx / W - 0.5) ** 2 + (yy / H - 0.5) ** 2) ** 0.5
    base -= (np.clip(vign - 0.3, 0, 1) * 120)[..., None] * np.array([0.8, 0.85, 1.0])
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)

    # pliegues y cuadrícula de referencia
    for k in range(1, 4):
        d.line([(W * k / 4, 0), (W * k / 4, H)], fill=(196, 170, 124), width=3)
    d.line([(0, H / 2), (W, H / 2)], fill=(196, 170, 124), width=3)
    for k in range(8):
        text_halo(d, (W * (k + 0.5) / 8, 24), "ABCDEFGH"[k], F_GRID, fill=INK_SOFT, sw=0)
    for k in range(6):
        text_halo(d, (22, H * (k + 0.5) / 6), str(k + 1), F_GRID, fill=INK_SOFT, sw=0)

    # mar y playa (abajo a la izquierda)
    sea = smooth([(0.0, 0.7), (0.08, 0.72), (0.17, 0.75), (0.24, 0.775), (0.3, 0.83), (0.33, 0.9), (0.36, 1.0)], 12) + [(0.0, 1.0)]
    beach = smooth([(0.0, 0.68), (0.09, 0.7), (0.18, 0.73), (0.26, 0.755), (0.32, 0.81), (0.355, 0.9), (0.39, 1.0)], 12) + [(0.0, 1.0)]
    d.polygon(px(beach), fill=(230, 208, 150))
    d.polygon(px(sea), fill=WATER, outline=WATER_D)
    for k in range(40):
        x, y = rng.uniform(0.01, 0.3), rng.uniform(0.79, 0.98)
        if y > 0.77 + x * 0.25:
            X, Y = P(x, y)
            d.arc([X - 14, Y - 6, X + 14, Y + 6], 200, 340, fill=WATER_D, width=2)
    # marismas
    marsh = smooth([(0.75, 0.41), (0.83, 0.39), (0.93, 0.42), (0.965, 0.52), (0.93, 0.62), (0.84, 0.63), (0.77, 0.58), (0.745, 0.49), (0.75, 0.41)], 10)
    d.polygon(px(marsh), fill=(150, 170, 140), outline=WATER_D)
    for k in range(26):
        a, r = rng.uniform(0, math.tau), math.sqrt(rng.random())
        cx, cy = P(0.855 + math.cos(a) * 0.08 * r, 0.51 + math.sin(a) * 0.09 * r)
        d.ellipse([cx - 22, cy - 9, cx + 22, cy + 9], fill=WATER, outline=WATER_D)
    for k in range(70):
        x, y = P(rng.uniform(0.76, 0.95), rng.uniform(0.42, 0.61))
        for j in range(3):
            d.line([(x + j * 4, y), (x + j * 4 + (j - 1) * 3, y - 14)], fill=(84, 108, 66), width=2)
    # río
    rio = px(smooth(RIO, 12))
    d.line(rio, fill=WATER_D, width=16, joint="curve")
    d.line(rio, fill=WATER, width=10, joint="curve")

    # sierra norte
    for k in range(34):
        x = rng.uniform(0.36, 0.95)
        y = 0.07 + 0.11 * rng.random() - (0.03 if 0.55 < x < 0.8 else 0)
        mountain(d, *P(x, y + 0.04), rng.uniform(48, 80), rng)
    for k in range(10):   # protege Villamuralla por el norte y el oeste
        x = rng.uniform(0.06, 0.34)
        mountain(d, *P(x, 0.07 + 0.04 * rng.random()), rng.uniform(40, 60), rng)
    for k in range(5):
        mountain(d, *P(0.06 + 0.03 * rng.random(), 0.15 + k * 0.045), rng.uniform(36, 50), rng)
    text_halo(d, P(0.66, 0.035), "S I E R R A   N O R T E", F_LABEL_S, fill=INK_SOFT)

    # Pinar del Cuervo (bosque grande, a la derecha del refugio)
    forest(d, *P(0.655, 0.32), 0.07 * W, 0.15 * H, 120, rng, size=30)
    # La Arboleda: arbolitos a la izquierda del refugio (zona de madera de la parte I)
    forest(d, *P(0.43, 0.475), 0.05 * W, 0.065 * H, 30, rng, size=24, leaf=True)
    X, Y = P(0.405, 0.505)   # el superviviente muerto con la pieza II
    d.line([(X - 9, Y - 9), (X + 9, Y + 9)], fill=RED, width=4)
    d.line([(X + 9, Y - 9), (X - 9, Y + 9)], fill=RED, width=4)
    # mini zona rocosa junto al bosque
    for k in range(12):
        rock(d, *P(0.665 + rng.uniform(-0.035, 0.035), 0.515 + rng.uniform(-0.035, 0.035)), rng.uniform(12, 20), rng)
    X, Y = P(0.69, 0.545)
    d.ellipse([X - 9, Y - 6, X + 9, Y + 6], fill=(150, 84, 52), outline=INK)   # la veta de hierro del pedregal
    # cantera: vetas de colores alrededor del foso (hierro, cobre, azufre)
    for k in range(14):
        a = rng.uniform(0, math.tau)
        X, Y = P(0.465 + math.cos(a) * 0.06, 0.29 + math.sin(a) * 0.07)
        c = [(150, 84, 52), (150, 84, 52), (150, 84, 52), (60, 130, 110), (210, 190, 70)][k % 5]
        d.ellipse([X - 8, Y - 5, X + 8, Y + 5], fill=c, outline=INK)
    # bosquecillos y árboles sueltos por el resto (relleno de los caminos)
    for cx, cy, rx, ry, n in [(0.3, 0.3, 0.05, 0.06, 18), (0.12, 0.5, 0.05, 0.08, 20), (0.62, 0.72, 0.05, 0.035, 12),
                              (0.9, 0.3, 0.04, 0.05, 12), (0.42, 0.6, 0.03, 0.03, 8), (0.95, 0.7, 0.03, 0.05, 10)]:
        forest(d, *P(cx, cy), rx * W, ry * H, n, rng, size=24)
    for k in range(12):
        rock(d, *P(rng.uniform(0.3, 0.95), rng.uniform(0.25, 0.7)), rng.uniform(8, 13), rng)

    # cantera: foso escalonado
    cx, cy = P(0.465, 0.29)
    for k, col in enumerate([(176, 120, 86), (158, 104, 74), (140, 90, 64)]):
        rr = 70 - k * 20
        d.ellipse([cx - rr * 1.3, cy - rr, cx + rr * 1.3, cy + rr], fill=col, outline=INK, width=2)
    # Base Centinela: tiendas, contenedores y valla con un tramo roto
    cx, cy = P(0.235, 0.42)
    fence = [(cx + math.cos(a) * 95, cy + math.sin(a) * 62) for a in np.linspace(0.6, math.tau + 0.0, 60)]
    dashed(d, fence, dash=10, gap=6, width=3)
    for a in np.linspace(0.05, 0.55, 5):
        X, Y = cx + math.cos(a) * 95, cy + math.sin(a) * 62
        d.line([(X - 6, Y - 6), (X + 6, Y + 6)], fill=RED, width=3)
    for i, (ox, oy) in enumerate([(-45, -20), (-5, -30), (35, -15), (-30, 18)]):
        d.polygon([(cx + ox - 18, cy + oy + 10), (cx + ox, cy + oy - 12), (cx + ox + 18, cy + oy + 10)], fill=(120, 128, 84), outline=INK)
    for ox, oy, c in [(20, 22, (150, 84, 60)), (48, 12, (90, 110, 120))]:
        d.rectangle([cx + ox - 16, cy + oy - 7, cx + ox + 16, cy + oy + 7], fill=c, outline=INK)
    # La Atalaya: empalizada redonda con casas y puerta
    cx, cy = P(0.815, 0.235)
    d.ellipse([cx - 78, cy - 60, cx + 78, cy + 60], outline=INK, width=5)
    for a in np.linspace(0, math.tau, 40, endpoint=False):
        X, Y = cx + math.cos(a) * 78, cy + math.sin(a) * 60
        d.line([(X, Y - 7), (X, Y + 3)], fill=INK, width=3)
    for ox, oy in [(-30, -15), (10, -25), (35, 5), (-10, 15)]:
        house(d, cx + ox, cy + oy, 11, col=(176, 70, 52))
    d.rectangle([cx - 12, cy + 52, cx + 12, cy + 66], fill=INK)
    # Villamuralla: recinto amurallado cuadrado
    cx, cy = P(0.235, 0.165)
    d.rectangle([cx - 80, cy - 55, cx + 80, cy + 55], outline=INK, width=8)
    for ox, oy in [(-45, -20), (-10, -25), (30, -20), (-40, 18), (5, 15), (45, 20)]:
        house(d, cx + ox, cy + oy, 10, col=(150, 110, 80))
    # puerto: muelles y barcos
    cx, cy = P(0.185, 0.835)
    for k in range(3):
        d.rectangle([cx - 40 + k * 40, cy + 10, cx - 32 + k * 40, cy + 75], fill=(150, 112, 74), outline=INK)
    for ox, oy, s in [(-70, 70, 1.0), (40, 95, 1.3)]:
        X, Y = cx + ox, cy + oy
        d.polygon([(X - 40 * s, Y), (X + 40 * s, Y), (X + 28 * s, Y + 14 * s), (X - 34 * s, Y + 14 * s)], fill=(110, 100, 92), outline=INK)
        d.rectangle([X - 6 * s, Y - 20 * s, X + 12 * s, Y], fill=(220, 214, 200), outline=INK)
    # pueblo abandonado
    cx, cy = P(0.36, 0.735)
    for ox, oy in [(-30, -10), (5, -22), (30, -4), (-8, 14)]:
        house(d, cx + ox, cy + oy, 10, col=(150, 110, 80), broken=(ox == 5))
    # estación
    cx, cy = P(0.535, 0.81)
    d.rectangle([cx - 50, cy - 40, cx + 50, cy - 14], fill=(200, 176, 136), outline=INK, width=2)
    d.polygon([(cx - 56, cy - 40), (cx, cy - 62), (cx + 56, cy - 40)], fill=(150, 84, 60), outline=INK)
    # central nuclear: torres y zona radiactiva
    cx, cy = P(0.7, 0.815)
    rad = [(cx + math.cos(a) * 150, cy + math.sin(a) * 110) for a in np.linspace(0, math.tau, 70)]
    dashed(d, rad, dash=12, gap=8, fill=(110, 70, 140), width=3)
    for ox in (-40, 10):
        d.polygon([(cx + ox - 22, cy + 20), (cx + ox - 14, cy - 40), (cx + ox + 14, cy - 40), (cx + ox + 22, cy + 20)], fill=(200, 196, 186), outline=INK)
        d.ellipse([cx + ox - 14, cy - 46, cx + ox + 14, cy - 34], fill=(150, 146, 140), outline=INK)
    d.rectangle([cx + 40, cy - 12, cx + 80, cy + 20], fill=(170, 166, 156), outline=INK)

    # vía del tren
    via = px(smooth(VIA, 12))
    d.line(via, fill=INK, width=4)
    for i in range(0, len(via) - 1, 2):
        (x0, y0), (x1, y1) = via[i], via[i + 1]
        a = math.atan2(y1 - y0, x1 - x0) + math.pi / 2
        d.line([(x0 + math.cos(a) * 9, y0 + math.sin(a) * 9), (x0 - math.cos(a) * 9, y0 - math.sin(a) * 9)], fill=INK, width=3)

    # caminos (tramos que se recorren andando)
    for rid, pts in TRAZADOS.items():
        r = routes[rid]
        if pts is None:
            continue
        line = px(smooth(pts, 14))
        d.line(line, fill=(236, 220, 186), width=12, joint="curve")
        dashed(d, line, dash=16, gap=8, fill=(120, 80, 46), width=5)
        if rid in ("r_refugio_arboleda", "r_refugio_pedregal"):
            continue   # tramos cortos: sin nombre (no cabe)
        (mx, my), ang = point_at(line, 0.42 if rid != "r_refugio_arboleda" else 0.3)
        deg = -math.degrees(ang)
        if deg > 90:
            deg -= 180
        if deg < -90:
            deg += 180
        t = Image.new("RGBA", (420, 60), (0, 0, 0, 0))
        ImageDraw.Draw(t).text((210, 30), r["name"], font=F_ROUTE, fill=INK_SOFT, anchor="mm", stroke_width=3, stroke_fill=(236, 220, 186))
        t = t.rotate(deg, expand=True, resample=Image.BICUBIC)
        flip = -1 if rid == "r_refugio_arboleda" else 1   # tramo corto: el nombre al otro lado
        nx, ny = -math.sin(ang) * 26 * flip, math.cos(ang) * 26 * flip
        img.alpha_composite(t, (int(mx + nx - t.width / 2), int(my + ny - t.height / 2)))
    d = ImageDraw.Draw(img)
    for rid, pos in (("r_via_puerto_estacion", (0.275, 0.805)), ("r_via_estacion_central", (0.625, 0.79))):
        text_halo(d, P(*pos), routes[rid]["name"], F_ROUTE, fill=INK_SOFT, sw=3)

    # puentes donde un camino cruza el río
    for bx, by, ang in [(0.718, 0.283, -20)]:
        X, Y = P(bx, by)
        t = math.radians(ang)
        for side in (-1, 1):
            ox, oy = -math.sin(t) * 9 * side, math.cos(t) * 9 * side
            d.line([(X - math.cos(t) * 22 + ox, Y - math.sin(t) * 22 + oy), (X + math.cos(t) * 22 + ox, Y + math.sin(t) * 22 + oy)], fill=INK, width=4)

    # coches abandonados con suministros
    for x, y, _part, rot in COCHES:
        car(img, *P(x, y), rot)
    d = ImageDraw.Draw(img)
    # casas con provisiones y gasolinera
    for x, y, _part in CASAS:
        house(d, *P(x, y), 11)
    gx, gy = P(*GASOLINERA)
    d.rectangle([gx - 24, gy - 14, gx + 24, gy + 14], fill=(200, 176, 136), outline=INK, width=2)
    d.rectangle([gx - 30, gy - 22, gx + 30, gy - 14], fill=(176, 70, 52), outline=INK)
    for ox in (-10, 10):
        d.rectangle([gx + ox - 4, gy - 6, gx + ox + 4, gy + 10], fill=INK)
    text_halo(d, (gx, gy + 32), "gasolinera", F_ROUTE, fill=INK_SOFT, sw=3)

    # lugares
    for k, l in LUGARES.items():
        x, y = P(*l["pos"])
        badge(d, x, y, l["icon"], 30 if k != "refugio" else 36)
        label(d, x, y, l["name"], F_LABEL if k not in ("valdecruces",) else F_LABEL_S, dy=-56 if k == "arboleda" else (58 if k != "refugio" else 66))

    # notas a mano
    notas = [((0.665, 0.185), "más botín, más peligro", RED), ((0.465, 0.195), "más botín, más peligro", RED),
             ((0.465, 0.22), "de cada 10 rocas: 5 hierro, 2 mejores", INK_SOFT), ((0.665, 0.59), "1 de cada 10, hierro", INK_SOFT),
             ((0.445, 0.54), "superviviente muerto", RED),
             ((0.2, 0.36), "valla rota: infectados", RED), ((0.86, 0.582), "solo con traje de buzo", RED),
             ((0.83, 0.15), "flechas si te acercas", RED), ((0.7, 0.93), "radiación", (110, 70, 140)),
             ((0.17, 0.95), "barco abandonado", INK_SOFT), ((0.62, 0.6), "", INK_SOFT)]
    for (x, y), t, c in notas:
        if t:
            text_halo(d, P(x, y), t, F_NOTE, fill=c, sw=3)
    return img


def decorate(img, routes):
    """Título, rosa de los vientos y leyenda (encima de todo)."""
    d = ImageDraw.Draw(img)
    # cartela del título
    x0, y0 = W * 0.715, H * -0.015
    d.rectangle([x0, y0 + 50, x0 + 520, y0 + 175], fill=(232, 214, 176), outline=INK, width=4)
    d.rectangle([x0 + 8, y0 + 58, x0 + 512, y0 + 167], outline=INK, width=1)
    d.text((x0 + 260, y0 + 100), "Mapa del Valle", font=F_TITLE, fill=INK, anchor="mm")
    d.text((x0 + 260, y0 + 148), "levantado por un superviviente", font=F_SUB, fill=INK_SOFT, anchor="mm")
    # rosa de los vientos
    cx, cy, r = W * 0.945, H * 0.33, 58
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=INK, width=3)
    for a, L in [(0, 1.0), (90, 1.0), (180, 1.0), (270, 1.0), (45, 0.55), (135, 0.55), (225, 0.55), (315, 0.55)]:
        t = math.radians(a - 90)
        tip = (cx + math.cos(t) * r * 1.25 * L, cy + math.sin(t) * r * 1.25 * L)
        side = math.radians(a)
        w = 10 * L
        d.polygon([tip, (cx + math.cos(side) * w, cy + math.sin(side) * w), (cx, cy)], fill=INK)
        d.polygon([tip, (cx - math.cos(side) * w, cy - math.sin(side) * w), (cx, cy)], fill=(200, 176, 136), outline=INK)
    for a, t in [(0, "N"), (90, "E"), (180, "S"), (270, "O")]:
        rr = math.radians(a - 90)
        text_halo(d, (cx + math.cos(rr) * r * 1.6, cy + math.sin(rr) * r * 1.6), t, F_LABEL_S, sw=3)
    # leyenda
    lx, ly = W * 0.815, H * 0.638
    ly -= 44
    d.rectangle([lx, ly, lx + 340, ly + 514], fill=(232, 214, 176), outline=INK, width=3)
    d.text((lx + 170, ly + 28), "Leyenda", font=F_LABEL, fill=INK, anchor="mm")
    rows = [("refugio", "Refugio"), ("atalaya", "Poblado de supervivientes"), ("pino", "Zona de recolección"),
            ("rocas", "Zona de rocas y vetas"), ("camino", "Camino (tramo a pie)"), ("via", "Vía del tren"),
            ("rio", "Río / agua"), ("casa", "Casa con provisiones"), ("coche", "Coche con suministros"),
            ("pieza", "Pieza del mapa (I, II, III)")]
    for i, (k, t) in enumerate(rows):
        y = ly + 72 + i * 44
        x = lx + 34
        if k in ("refugio", "atalaya", "pino", "rocas"):
            badge(d, x, y, k, 14)
        elif k == "hatch":
            for j in range(4):
                d.line([(x - 14 + j * 8, y + 12), (x - 4 + j * 8, y - 12)], fill=RED, width=2)
        elif k == "camino":
            d.line([(x - 18, y), (x + 18, y)], fill=(236, 220, 186), width=10)
            dashed(d, [(x - 18, y), (x + 18, y)], dash=8, gap=4, fill=(120, 80, 46), width=4)
        elif k == "via":
            d.line([(x - 18, y), (x + 18, y)], fill=INK, width=3)
            for j in range(5):
                d.line([(x - 16 + j * 8, y - 7), (x - 16 + j * 8, y + 7)], fill=INK, width=2)
        elif k == "rio":
            d.line([(x - 18, y + 4), (x - 6, y - 4), (x + 6, y + 4), (x + 18, y - 4)], fill=WATER_D, width=8)
        elif k == "casa":
            house(d, x, y + 4, 10)
        elif k == "coche":
            car(img, x, y, 0, 0.7)
        elif k == "pieza":
            dashed(d, [(x - 18, y), (x + 18, y)], dash=5, gap=4, fill=RED, width=3)
        d.text((x + 34, y), t, font=F_LEG, fill=INK, anchor="lm")
    return img


# ------------------------------------------------------------------ piezas y costuras
def piece_masks():
    rng = random.Random(3)
    t1 = torn(PIEZA1, rng)
    t2 = torn(PIEZA2, rng)
    m1 = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m1).polygon(px(t1), fill=255)
    m2 = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m2).polygon(px(t2), fill=255)
    full = Image.new("L", (W, H), 0)
    outer = torn([(0.012, 0.015), (0.988, 0.012), (0.99, 0.985), (0.01, 0.988)], rng, amp=0.006)
    ImageDraw.Draw(full).polygon(px(outer), fill=255)
    m2 = Image.fromarray(np.minimum(np.asarray(m2), np.asarray(full)))
    return {"1": m1, "12": m2, "123": full}, {"1": px(t1), "2": px(t2), "outer": px(outer)}


def stitches(img, line, mask, col=(120, 40, 30)):
    """Costura: el borde rasgado de la pieza (con su sombra) y puntadas de hilo cruzándolo.
    Solo donde hay papel por los dos lados (mask = lo descubierto)."""
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    closed = line + [line[0]]
    d.line(closed, fill=(60, 40, 24, 110), width=7)
    d.line(closed, fill=(70, 46, 28, 255), width=2)
    acc = 0.0
    for i in range(len(closed) - 1):
        (x0, y0), (x1, y1) = closed[i], closed[i + 1]
        acc += math.dist((x0, y0), (x1, y1))
        if acc < 26:
            continue
        acc = 0.0
        a = math.atan2(y1 - y0, x1 - x0) + math.pi / 2
        for off in (0.45, -0.45):
            d.line([(x0 + math.cos(a + off) * 12, y0 + math.sin(a + off) * 12), (x0 - math.cos(a + off) * 12, y0 - math.sin(a + off) * 12)], fill=col + (255,), width=3)
    m = np.asarray(mask.filter(ImageFilter.MinFilter(15))).astype(float) / 255.0
    a = np.asarray(lay).astype(float)
    a[..., 3] *= m
    img.alpha_composite(Image.fromarray(a.astype(np.uint8)))


def table(size):
    rng = np.random.default_rng(11)
    h, w = size[1], size[0]
    yy, xx = np.mgrid[0:h, 0:w]
    grain = np.sin(yy / 9.0 + noise((h, w), 60, rng) * 8) * 10 + noise((h, w), 20, rng) * 18
    planks = ((yy // 170) % 2) * 8
    base = np.zeros((h, w, 3))
    base[:] = (70, 46, 30)
    base += (grain + planks)[..., None] * np.array([1.0, 0.75, 0.5])
    for k in range(1, h // 170 + 1):
        base[k * 170 - 2:k * 170 + 2] *= 0.6
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")


def compose(full_img, masks, lines, upto, routes):
    """Mapa sobre la mesa con las piezas encontradas cosidas."""
    m = masks[{1: "1", 2: "12", 3: "123"}[upto]]
    out = table((W, H))
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow.putalpha(m.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.6)))
    out.alpha_composite(shadow, (10, 14))
    paper = full_img.copy()
    paper.putalpha(m)
    out.alpha_composite(paper)
    if upto >= 2:
        stitches(out, lines["1"], m)
    if upto >= 3:
        stitches(out, lines["2"], m)
    d = ImageDraw.Draw(out)
    for part, pos in [(1, (0.385, 0.6)), (2, (0.955, 0.2)), (3, (0.05, 0.96))]:
        if part <= upto:
            text_halo(d, P(*pos), roman(part), F_ROMAN, fill=(120, 40, 30), sw=4)
    if upto >= 3:
        decorate(out, routes)   # título y leyenda encima de las costuras
    return out


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(RAIZ, "docs", "mapa")
    os.makedirs(out_dir, exist_ok=True)
    routes = json.load(open(os.path.join(RAIZ, "data", "routes.json")))
    full = draw_full(routes)
    masks, lines = piece_masks()
    # definitivo: las tres piezas cosidas, recortado al borde rasgado
    final = compose(full, masks, lines, 3, routes)
    final.convert("RGB").save(os.path.join(out_dir, "mapa_definitivo.jpg"), quality=90)
    for n in (1, 2):
        compose(full, masks, lines, n, routes).convert("RGB").save(os.path.join(out_dir, "mapa_parte%d.jpg" % n), quality=90)
    # para el juego: una imagen por número de piezas (assets/ui/mapa_piezas_N.jpg, 1400 px)
    # recortado a lo que tienes (hud.gd MAP_VIEWS usa los mismos rectángulos)
    game = os.path.join(RAIZ, "assets", "ui")
    for n in (1, 2, 3):
        im = final if n == 3 else compose(full, masks, lines, n, routes)
        x, y, w, h = VISTAS[n]
        im = im.crop((int(x * W), int(y * H), int((x + w) * W), int((y + h) * H)))
        im.convert("RGB").resize((1400, int(1400 * H / W)), Image.LANCZOS).save(os.path.join(game, "mapa_piezas_%d.jpg" % n), quality=85)
    print("mapa listo en", out_dir)


if __name__ == "__main__":
    main()
