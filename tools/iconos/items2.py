# Iconos v2: low poly facetado con contorno oscuro, luz desde arriba a la izquierda.
import math
from items import ICONS as OLD

OUT = "#16110c"

def P(pts, c, extra=""):
    if not isinstance(pts, str):
        pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    return f'<polygon points="{pts}" fill="{c}"{extra}></polygon>'

def C(x, y, r, c, extra=""):
    return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{c}"{extra}></circle>'

def E(x, y, rx, ry, c, rot=0, extra=""):
    return f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{c}" transform="rotate({rot} {x:.1f} {y:.1f})"{extra}></ellipse>'

def L(d, c, w=2.0, extra=""):
    return f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"{extra}></path>'

def R(x, y, w, h, c, rx=0, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{c}"{extra}></rect>'

def outlined(base, details="", w=4.5):
    """base: formas que forman la silueta (se contornean); details: encima sin contorno."""
    return f'<g stroke="{OUT}" stroke-width="{w}" stroke-linejoin="round">{base}</g>{base}{details}'


# ------------------------------------------------------------------ madera
def log(cx, cy, r, back=(15, -9)):
    bx, by = back
    ang = math.atan2(by, bx) + math.pi / 2
    px, py = math.cos(ang) * r, math.sin(ang) * r
    body_top = P([(cx - px, cy - py), (cx - px + bx, cy - py + by), (cx + bx, cy + by), (cx, cy)], "#8a5a30")
    body_bot = P([(cx, cy), (cx + bx, cy + by), (cx + px + bx, cy + py + by), (cx + px, cy + py)], "#5e3b1f")
    return body_top + body_bot, (cx, cy, r)

def log_end(cx, cy, r):
    return (C(cx, cy, r, "#4a2f19") + C(cx, cy, r - 1.8, "#e2bd85") +
            f'<circle cx="{cx}" cy="{cy}" r="{r*0.62:.1f}" fill="none" stroke="#bf9058" stroke-width="1.2"></circle>' +
            f'<circle cx="{cx}" cy="{cy}" r="{r*0.3:.1f}" fill="none" stroke="#bf9058" stroke-width="1.1"></circle>' +
            C(cx, cy, 1.3, "#8a5a30") + P([(cx - r * 0.55, cy - r * 0.5), (cx - r * 0.1, cy - r * 0.75), (cx - r * 0.45, cy - r * 0.15)], "#f3d7a6"))

def madera():
    logs = [(18, 48, 9.5), (37, 51, 9.5), (27, 33, 9.5)]
    bodies = ""; ends = ""
    for cx, cy, r in sorted(logs, key=lambda l: l[1]):
        b, _ = log(cx, cy, r)
        bodies += b
    for cx, cy, r in logs:
        ends += log_end(cx, cy, r)
    base = bodies + "".join(C(cx, cy, r, "#4a2f19") for cx, cy, r in logs)
    grain = L("M30 26 L42 19 M40 44 L52 37 M21 41 L33 34", "#4a2f19", 1.2, ' opacity="0.6"')
    return outlined(base, bodies + grain + ends)

# ------------------------------------------------------------------ piedra
def rock(pts, center, cols):
    """Roca facetada: abanico de triángulos desde un punto interior."""
    out = ""
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        out += P([a, b, center], cols[i % len(cols)])
    return out

def piedra():
    pts = [(8, 44), (14, 26), (28, 14), (44, 15), (56, 30), (57, 46), (44, 56), (20, 56)]
    cols = ["#7d7a72", "#a8a59c", "#c4c1b8", "#a19e95", "#76736c", "#5e5b55", "#6b6862", "#87847c"]
    base = P(pts, "#888")
    small = [(44, 50), (50, 44), (60, 50), (56, 58), (46, 58)]
    det = rock(pts, (32, 34), cols) + rock(small, (52, 52), ["#9a978e", "#7a776f", "#5c5a54", "#6c6963", "#8a877f"])
    det += P([(22, 22), (28, 16), (30, 24)], "#d8d5cc", ' opacity="0.7"')
    return outlined(base + P(small, "#888"), det)

def bloque_piedra():
    top = [(10, 22), (32, 11), (54, 22), (32, 33)]
    left = [(10, 22), (32, 33), (32, 56), (10, 45)]
    right = [(32, 33), (54, 22), (54, 45), (32, 56)]
    base = P(top + [(54, 45), (32, 56), (10, 45)], "#888")
    det = P(top, "#c9c6bd") + P(left, "#9b988f") + P(right, "#6f6c66")
    det += P([(46, 26), (54, 22), (54, 30)], "#5a5853")  # esquina mellada
    det += L("M15 30 L20 32 M22 40 L27 42 M14 38 L18 40", "#7b7870", 1.4)
    det += L("M38 36 L44 33 M40 46 L47 42", "#5a5853", 1.4)
    det += L("M18 22 L32 15 L46 22", "#e2dfd6", 1.2, ' opacity="0.8"')
    return outlined(base, det)

# ------------------------------------------------------------------ fibra
def fibra():
    blades = ""
    tips = [(10, 8), (18, 4), (27, 6), (34, 3), (42, 6), (50, 4), (56, 10)]
    cols = ["#9aa84a", "#b8c25e", "#8a9a3c", "#c9cf6c", "#a3b14e", "#b4be58", "#8f9e40"]
    for (tx, ty), c in zip(tips, cols):
        blades += P([(29, 38), (35, 38), (tx + 2, ty), (tx - 1, ty + 2)], c)
    lower = ""
    for i, (bx, c) in enumerate(zip([22, 27, 32, 37, 42], ["#b8a85a", "#a89850", "#c4b466", "#a89850", "#b8a85a"])):
        lower += P([(29 + i * 1.5 - 1, 44), (30 + i * 1.5 + 1, 44), (bx + 1.5, 60), (bx - 1.5, 60)], c)
    band = P([(25, 37), (39, 37), (40, 45), (24, 45)], "#7a5a34") + L("M25 41 L39 41", "#a57d4b", 1.3)
    base = blades + lower + band
    return outlined(base, "", 3.5)

# ------------------------------------------------------------------ tela
def tela():
    layers = ""
    for i, (y, c1, c2) in enumerate([(40, "#5d6340", "#4a4f33"), (30, "#8a7f6a", "#6e6553"), (20, "#b5a88c", "#958a70")]):
        layers += P([(8, y + 4), (36, y - 6), (58, y + 2), (30, y + 12)], c1)
        layers += P([(8, y + 4), (30, y + 12), (30, y + 18), (8, y + 10)], c2)
        layers += P([(30, y + 12), (58, y + 2), (58, y + 8), (30, y + 18)], c2.replace("#", "#") )
    det = L("M16 22 L40 16 M14 32 L38 26", "#d2c6a8", 1.2, ' opacity="0.8"') + L("M32 21 L50 18", "#7d735c", 1.2)
    return outlined(layers, det)

# ------------------------------------------------------------------ tablón
def plank(x, y, length, dx, dy, cols):
    top = [(x, y), (x + dx * length, y + dy * length), (x + dx * length + 6, y + dy * length + 3.5), (x + 6, y + 3.5)]
    front = [(x + 6, y + 3.5), (x + dx * length + 6, y + dy * length + 3.5), (x + dx * length + 6, y + dy * length + 8.5), (x + 6, y + 8.5)]
    end = [(x, y), (x + 6, y + 3.5), (x + 6, y + 8.5), (x, y + 5)]
    return top, front, end, cols

def tablon():
    out_base = ""; det = ""
    for i, (x, y) in enumerate([(8, 46), (8, 35), (8, 24)]):
        top, front, end, _ = plank(x, y, 1, 44, -22, None)
        out_base += P(top + front[1:3] + [front[3]] + end[2:], "#888")
        cA, cB, cC = [("#c99a62", "#9a6a3c", "#e0c08e"), ("#b8874f", "#8a5c33", "#d8b27c"), ("#d3a76f", "#a07040", "#ebcb98")][i]
        det += P(top, cA) + P(front, cB) + P(end, cC)
        det += L(f"M{x+12} {y+1} L{x+36} {y-11}", cB, 1.0) + L(f"M{x+20} {y+2.6} L{x+42} {y-8.4}", cB, 1.0, ' opacity="0.7"')
        det += C(x + 30, y - 6.5, 1.1, cB)
    return outlined(out_base, det, 4)

# ------------------------------------------------------------------ cuerda
def cuerda():
    base = E(30, 36, 23, 17, "#9a7c45")
    det = E(30, 36, 23, 17, "#b6975c") + E(30, 36, 17, 12, "#9a7c45") + E(30, 36, 11, 7.5, "#b6975c") + E(30, 36, 5.5, 3.5, "#5e4a28")
    for rx, ry in [(20, 14.5), (14, 9.8), (8, 5.6)]:
        det += f'<ellipse cx="30" cy="36" rx="{rx}" ry="{ry}" fill="none" stroke="#7a6136" stroke-width="1.3" stroke-dasharray="2.2 2.6"></ellipse>'
    det += L("M30 21 C34 21 40 22 44 24", "#e1c78d", 1.4, ' opacity="0.8"')
    tail = L("M50 44 C54 48 56 54 60 58", OUT, 7) + L("M50 44 C54 48 56 54 60 58", "#b6975c", 4) + L("M52 47 L54 49 M55 52 L57 54", "#7a6136", 1.2)
    return outlined(base, det) + tail

# ------------------------------------------------------------------ piel
def piel():
    pts = [(14, 10), (24, 14), (40, 14), (50, 10), (52, 20), (58, 30), (52, 36), (56, 50), (46, 56), (40, 50), (24, 50), (18, 56), (8, 50), (12, 36), (6, 30), (12, 20)]
    inner = [(20, 20), (44, 20), (48, 32), (44, 44), (20, 44), (16, 32)]
    det = P(inner, "#c4935f") + P([(20, 20), (44, 20), (32, 30)], "#d6a978") + L("M24 26 L28 24 M36 36 L40 34 M26 38 L29 36 M38 25 L41 24", "#9a6b45", 1.3)
    return outlined(P(pts, "#9a6b45"), det)

# ------------------------------------------------------------------ minerales
def mineral_hierro():
    pts = [(8, 44), (14, 24), (30, 13), (48, 18), (57, 36), (50, 52), (30, 57), (14, 54)]
    det = rock(pts, (32, 36), ["#6a635c", "#857d74", "#9a9188", "#6e6760", "#4f4944", "#3f3a36", "#4a4540", "#5c5650"])
    for (x, y, s, c) in [(22, 32, 5, "#d06a34"), (38, 26, 4, "#e8843f"), (40, 42, 5, "#b85a2c"), (26, 46, 3.5, "#d97a3a")]:
        det += P([(x, y - s), (x + s * 0.9, y), (x, y + s * 0.8), (x - s * 0.9, y)], c) + P([(x, y - s), (x + s * 0.9, y), (x, y)], "#f2a865")
    return outlined(P(pts, "#666"), det)

def lingote(x, y):
    top = [(x, y), (x + 8, y - 6), (x + 34, y - 6), (x + 28, y)]
    front = [(x - 4, y + 9), (x, y), (x + 28, y), (x + 32, y + 9)]
    side = [(x + 28, y), (x + 34, y - 6), (x + 38, y + 2), (x + 32, y + 9)]
    return top, front, side

def lingote_hierro():
    base = ""; det = ""
    for (x, y) in [(10, 46), (18, 34)]:
        t, f, s = lingote(x, y)
        base += P(t + [s[2], f[3], f[0]], "#888")
        det += P(t, "#d6dde1") + P(f, "#97a1a8") + P(s, "#6b747a")
        det += L(f"M{x+4} {y-2} L{x+26} {y-2}", "#f2f6f8", 1.2, ' opacity="0.8"')
    return outlined(base, det)

def carbon():
    lumps = [([(8, 46), (14, 34), (26, 30), (32, 40), (28, 52), (14, 54)], (20, 43)),
             ([(28, 40), (36, 26), (50, 24), (58, 36), (52, 50), (34, 52)], (44, 38)),
             ([(18, 30), (24, 16), (38, 12), (44, 24), (34, 30), (24, 32)], (31, 22))]
    base = "".join(P(p, "#222") for p, _ in lumps)
    det = ""
    for p, c in lumps:
        det += rock(p, c, ["#2b2a2c", "#4a4a52", "#3a3a40", "#1d1c1e", "#151416", "#26252a"])
    det += P([(26, 16), (34, 13), (30, 20)], "#7d8290", ' opacity="0.7"') + P([(40, 27), (48, 25), (44, 31)], "#6d7280", ' opacity="0.7"')
    return outlined(base, det)

def chatarra():
    sheet = [(6, 50), (20, 38), (36, 44), (30, 58), (12, 58)]
    pipe_body = [(28, 30), (52, 16), (58, 24), (34, 38)]
    gear = ""
    for k in range(8):
        a = k * math.pi / 4
        gear += P([(20 + math.cos(a - 0.2) * 9, 22 + math.sin(a - 0.2) * 9), (20 + math.cos(a - 0.2) * 13, 22 + math.sin(a - 0.2) * 13),
                   (20 + math.cos(a + 0.2) * 13, 22 + math.sin(a + 0.2) * 13), (20 + math.cos(a + 0.2) * 9, 22 + math.sin(a + 0.2) * 9)], "#8c7a62")
    base = P(sheet, "#888") + P(pipe_body, "#888") + E(55, 20, 4, 5.5, "#888", -30) + gear + C(20, 22, 10, "#888")
    det = P(sheet, "#8e9aa0") + P([(20, 38), (36, 44), (24, 48)], "#b7c2c7") + L("M14 52 L26 54", "#b5652f", 2.2)
    det += P(pipe_body, "#6f7a80") + P([(28, 30), (52, 16), (54, 19), (30, 33)], "#a9b4ba") + E(55, 20, 4, 5.5, "#3c4246", -30)
    det += gear + C(20, 22, 10, "#a08b6c") + C(20, 22, 4, "#4a3f30") + P([(13, 17), (19, 13), (17, 19)], "#cdb894")
    det += C(44, 46, 2.2, "#c46b34") + C(40, 50, 1.6, "#a85a2c")
    return outlined(base, det)

# ------------------------------------------------------------------ herramientas
def handle(x1, y1, x2, y2, w, c, cd):
    a = math.atan2(y2 - y1, x2 - x1) + math.pi / 2
    px, py = math.cos(a) * w / 2, math.sin(a) * w / 2
    full = P([(x1 - px, y1 - py), (x2 - px, y2 - py), (x2 + px, y2 + py), (x1 + px, y1 + py)], c)
    shade = P([(x1, y1), (x2, y2), (x2 + px, y2 + py), (x1 + px, y1 + py)], cd)
    return full, shade

def lashing(x, y, ang, n=3):
    out = ""
    for k in range(n):
        dx, dy = math.cos(ang) * k * 3.2, math.sin(ang) * k * 3.2
        out += L(f"M{x+dx-4:.1f} {y+dy-3:.1f} L{x+dx+4:.1f} {y+dy+3:.1f}", "#c9a96a", 2.2)
    return out

def hacha_piedra():
    hf, hs = handle(16, 58, 42, 10, 6, "#a5713f", "#7a5029")
    head = [(36, 6), (50, 8), (58, 22), (52, 34), (40, 28), (36, 16)]
    base = hf + P(head, "#888")
    det = hf + hs + rock(head, (46, 18), ["#b9b5ab", "#d0ccc2", "#9a968d", "#77746d", "#8a877f", "#a5a199"])
    det += L("M50 8 L58 22 L52 34", "#ece8de", 1.3, ' opacity="0.9"') + lashing(36, 18, math.radians(-62))
    det += L("M20 50 L24 52 M23 45 L27 47", "#7a5029", 1.2)
    return outlined(base, det)

def hacha_hierro():
    hf, hs = handle(14, 58, 42, 8, 6, "#6e4826", "#4f331a")
    head = [(34, 10), (44, 12), (58, 6), (60, 32), (46, 28), (36, 24)]
    base = hf + P(head, "#888")
    det = hf + hs + P(head, "#8f989e") + P([(44, 12), (58, 6), (60, 32), (52, 28)], "#c3cbd0") + P([(56, 7), (58, 6), (60, 32), (58, 31)], "#eef3f5")
    det += P([(34, 10), (44, 12), (46, 28), (36, 24)], "#5d656b") + C(40, 18, 1.6, "#2f3438")
    det += L("M18 50 L22 52 M21 44 L25 46", "#4f331a", 1.2) + P([(16, 54), (22, 57), (20, 61), (14, 58)], "#3a2a1c")
    return outlined(base, det)

def pico(stone):
    hf, hs = handle(30, 60, 32, 18, 6, "#a5713f" if stone else "#6e4826", "#7a5029" if stone else "#4f331a")
    head = [(4, 30), (14, 18), (32, 12), (50, 18), (60, 30), (50, 24), (32, 20), (14, 24)]
    base = hf + P(head, "#888")
    if stone:
        det = hf + hs + P(head, "#a19e95") + P([(14, 18), (32, 12), (50, 18), (32, 16)], "#cfcbc1") + P([(4, 30), (14, 24), (14, 18)], "#77746d") + P([(60, 30), (50, 24), (50, 18)], "#6b6862")
        det += lashing(28, 16, 0, 3)
    else:
        det = hf + hs + P(head, "#8f989e") + P([(14, 18), (32, 12), (50, 18), (32, 16)], "#d6dde1") + P([(4, 30), (14, 24), (14, 18)], "#5d656b") + P([(60, 30), (50, 24), (50, 18)], "#5d656b")
        det += L("M6 29 L14 19 M58 29 L50 19", "#eef3f5", 1.1) + R(28, 13, 8, 9, "#5d656b", 1)
    return outlined(base, det)

def lanza():
    hf, hs = handle(8, 60, 46, 16, 5, "#a5713f", "#7a5029")
    tip = [(44, 18), (48, 8), (58, 4), (56, 14), (48, 20)]
    base = hf + P(tip, "#888")
    det = hf + hs + P(tip, "#a19e95") + P([(48, 8), (58, 4), (52, 12)], "#d3cfc5") + P([(56, 14), (48, 20), (52, 12)], "#6b6862")
    det += lashing(42, 21, math.radians(-49), 3) + L("M14 52 L17 54", "#7a5029", 1.2)
    return outlined(base, det)

def garrote():
    hf, hs = handle(12, 60, 32, 30, 6, "#8a5a30", "#5e3b1f")
    head = [(22, 22), (26, 8), (40, 4), (54, 12), (56, 28), (44, 38), (30, 34)]
    base = hf + P(head, "#888")
    det = hf + hs + rock(head, (40, 21), ["#b07a46", "#c99460", "#a06a3a", "#7a4f2b", "#6a4425", "#8a5a30", "#9a6a3c"])
    for (x, y, a) in [(32, 12, -2.4), (48, 10, -0.8), (54, 24, 0.2), (40, 34, 1.6), (26, 26, 3.0)]:
        det += L(f"M{x} {y} L{x + math.cos(a) * 6:.1f} {y + math.sin(a) * 6:.1f}", "#c3cbd0", 2.2)
    det += P([(12, 54), (20, 56), (17, 62), (9, 60)], "#3c2f24")
    return outlined(base, det)

def machete():
    blade = [(18, 44), (52, 6), (58, 6), (58, 14), (26, 50)]
    grip = [(8, 54), (16, 46), (22, 52), (14, 60)]
    guard = [(14, 42), (22, 52), (26, 50), (18, 40)]
    base = P(blade, "#888") + P(grip, "#888") + P(guard, "#888")
    det = P(blade, "#8f989e") + P([(18, 44), (52, 6), (58, 6), (24, 46)], "#c3cbd0") + P([(58, 6), (58, 14), (26, 50), (24, 48)], "#eef3f5")
    det += P(grip, "#3c3530") + L("M11 52 L17 58 M14 49 L20 55", "#6a5f52", 1.5) + P(guard, "#7a6a50") + C(36, 30, 1.4, "#5d656b")
    return outlined(base, det)

# ------------------------------------------------------------------ mochila
def mochila(pal=None):
    pal = pal or {}
    body = [(12, 24), (16, 19), (48, 19), (52, 24), (52, 56), (48, 60), (16, 60), (12, 56)]
    side_l = [(6, 32), (12, 30), (12, 54), (6, 52)]
    side_r = [(52, 30), (58, 32), (58, 52), (52, 54)]
    roll = R(8, 4, 48, 14, "#888", 7)
    base = P(side_l, "#888") + P(side_r, "#888") + P(body, "#888") + roll
    det = P(side_l, pal.get("side_l", "#4f4830")) + P(side_r, pal.get("side_r", "#433d28")) + L("M6 40 L12 40 M52 40 L58 40", "#3d3626", 1.4)
    det += P(body, pal.get("body", "#6b6243")) + P([(32, 19), (48, 19), (52, 24), (52, 56), (48, 60), (32, 60)], pal.get("body_d", "#5f5739"))
    # tapa con borde curvo
    det += f'<path d="M13 22 L51 22 L52 31 Q32 40 12 31 Z" fill="{pal.get('flap', '#81774f')}"></path><path d="M13 22 L51 22 L51.5 26 L12.5 26 Z" fill="{pal.get('flap_l', '#958a5f')}"></path>'
    det += '<path d="M12 31 Q32 40 52 31" fill="none" stroke="#4a4430" stroke-width="1.4"></path>'
    # bolsillo delantero
    det += R(16, 42, 32, 14, pal.get("pocket", "#565036"), 2) + R(16, 42, 32, 4, "#4a4430", 2) + L("M18 52 L46 52", "#c9b27a", 1.0, ' stroke-dasharray="2 2"')
    # correas con hebilla
    det += R(20, 24, 4.5, 21, "#3d3626", 1) + R(39.5, 24, 4.5, 21, "#3d3626", 1)
    det += R(19, 41, 6.5, 5, "#b39a5e", 1) + R(38.5, 41, 6.5, 5, "#b39a5e", 1) + R(21, 42.5, 2.5, 2, "#3d3626") + R(40.5, 42.5, 2.5, 2, "#3d3626")
    # saco de dormir enrollado
    det += R(8, 4, 48, 14, "#a4966a", 7) + R(12, 5.5, 40, 4, "#c0b285", 2)
    det += E(10.5, 11, 3, 6.5, "#8a7d55") + '<path d="M10.5 8 Q12 11 10.5 14" fill="none" stroke="#6b6043" stroke-width="1.1"></path>'
    det += R(19.5, 3.5, 5, 15, "#3d3626", 1) + R(39.5, 3.5, 5, 15, "#3d3626", 1)
    return outlined(base, det)


# ------------------------------------------------------------------ materiales nuevos (cobre, cuero, azufre, pólvora, componentes)
def mineral_cobre():
    pts = [(8, 44), (14, 24), (30, 13), (48, 18), (57, 36), (50, 52), (30, 57), (14, 54)]
    det = rock(pts, (32, 36), ["#6a635c", "#857d74", "#9a9188", "#6e6760", "#4f4944", "#3f3a36", "#4a4540", "#5c5650"])
    for (x, y, s, c, l) in [(22, 32, 5, "#2f8f78", "#6fd0b4"), (38, 26, 4, "#d9803f", "#f5b77a"), (40, 42, 5, "#3aa88c", "#86e0c6"), (26, 46, 3.5, "#c9733f", "#f0a874")]:
        det += P([(x, y - s), (x + s * 0.9, y), (x, y + s * 0.8), (x - s * 0.9, y)], c) + P([(x, y - s), (x + s * 0.9, y), (x, y)], l)
    return outlined(P(pts, "#666"), det)

def lingote_cobre():
    base = ""; det = ""
    for (x, y) in [(10, 46), (18, 34)]:
        t, f, s_ = lingote(x, y)
        base += P(t + [s_[2], f[3], f[0]], "#888")
        det += P(t, "#f0b48a") + P(f, "#cf7a4c") + P(s_, "#9a4f2d")
        det += L(f"M{x+4} {y-2} L{x+26} {y-2}", "#ffe2c8", 1.2, ' opacity="0.8"')
    return outlined(base, det)

def cuero():
    def roll(x, y, w, r, c1, c2, ce):
        body = P([(x, y - r), (x + w, y - r - 6), (x + w, y + r - 6), (x, y + r)], c1) + P([(x, y), (x + w, y - 6), (x + w, y + r - 6), (x, y + r)], c2)
        end = E(x, y, r * 0.55, r, ce)
        spiral = f'<path d="M{x} {y} m-1 -3 a3 3 0 1 1 -3 3 a6 6 0 0 1 6 -6" fill="none" stroke="#5a2f1c" stroke-width="1.3"></path>'
        return body, end + spiral
    b1, e1 = roll(12, 42, 30, 9, "#b4623a", "#8f4528", "#d38457")
    b2, e2 = roll(24, 24, 30, 9, "#c26d42", "#9a4d2c", "#e29566")
    base = b1 + b2 + E(12, 42, 5, 9, "#888") + E(24, 24, 5, 9, "#888")
    return outlined(base, b1 + e1 + b2 + e2 + L("M30 18 L50 12 M18 38 L38 32", "#e7a77c", 1.2, ' opacity="0.7"'))

def azufre():
    lumps = [([(8, 48), (14, 36), (26, 32), (32, 42), (28, 54), (14, 56)], (20, 45)),
             ([(28, 42), (34, 26), (48, 22), (58, 34), (54, 50), (36, 54)], (44, 38)),
             ([(16, 32), (22, 16), (36, 12), (42, 24), (32, 30), (22, 34)], (30, 22))]
    base = "".join(P(p_, "#888") for p_, _ in lumps)
    det = ""
    for p_, c in lumps:
        det += rock(p_, c, ["#e9d74a", "#f6ea7a", "#cdb92f", "#b9a526", "#f2e25a", "#d8c63a", "#a8951f", "#e2cf40"])
    det += P([(24, 17), (32, 14), (29, 21)], "#fffbd0", ' opacity="0.8"') + P([(42, 28), (50, 26), (46, 32)], "#fffbd0", ' opacity="0.7"')
    return outlined(base, det)

def polvora():
    bag = [(14, 14), (34, 10), (46, 16), (44, 44), (40, 54), (18, 54), (12, 44)]
    det = P(bag, "#cfb98a") + P([(14, 14), (34, 10), (32, 26), (16, 28)], "#e0cd9f") + P([(32, 26), (46, 16), (44, 44), (40, 54), (34, 50)], "#a89468")
    det += P([(16, 28), (32, 26), (34, 50), (40, 54), (18, 54), (12, 44)], "#bba87a")
    det += P([(14, 14), (34, 10), (46, 16), (36, 20), (20, 20)], "#8a7850")
    det += R(19, 32, 20, 10, "#4a3a22", 2) + L("M22 37 L36 37", "#d9c79a", 1.6)
    pile = [(36, 54), (44, 46), (54, 48), (60, 56), (52, 60), (40, 60)]
    pile_det = P(pile, "#e6e6e0") + P([(44, 46), (54, 48), (50, 54)], "#ffffff") + P([(40, 60), (50, 54), (60, 56), (52, 60)], "#b9b9b2")
    return outlined(P(bag, "#888") + P(pile, "#888"), det + pile_det)

def componentes():
    box = [(8, 30), (50, 30), (50, 56), (8, 56)]
    lid = [(8, 30), (14, 12), (56, 12), (50, 30)]
    det = P(lid, "#9a7c58") + P([(8, 30), (14, 12), (22, 12), (16, 30)], "#b8946a")
    det += P(box, "#bba07a") + P([(8, 30), (50, 30), (50, 38), (8, 38)], "#8f7650") + R(26, 38, 8, 6, "#6a5a3a", 1)
    gear = ""
    for k in range(8):
        a = k * math.pi / 4
        gear += P([(26 + math.cos(a - 0.22) * 9, 26 + math.sin(a - 0.22) * 9), (26 + math.cos(a - 0.22) * 13, 26 + math.sin(a - 0.22) * 13),
                   (26 + math.cos(a + 0.22) * 13, 26 + math.sin(a + 0.22) * 13), (26 + math.cos(a + 0.22) * 9, 26 + math.sin(a + 0.22) * 9)], "#8a9298")
    gear += C(26, 26, 10, "#a9b2b8") + C(26, 26, 4, "#3a4046")
    spring = L("M40 30 l6 -3 l-6 -3 l6 -3 l-6 -3 l6 -3", "#c7ccd0", 2.4)
    wires = L("M12 44 C18 40 24 52 30 48", "#c0392b", 2) + L("M32 50 C38 46 44 54 48 48", "#2f7fb8", 2)
    return outlined(P(box, "#888") + P(lid, "#888") + gear + C(26, 26, 10, "#888"), det + gear + spring + wires)

NEW = {
    "madera": madera(), "piedra": piedra(), "bloque_piedra": bloque_piedra(), "fibra": fibra(), "tela": tela(),
    "tablon": tablon(), "cuerda": cuerda(), "piel": piel(), "mineral_hierro": mineral_hierro(),
    "lingote_hierro": lingote_hierro(), "carbon": carbon(), "chatarra": chatarra(),
    "hacha_piedra": hacha_piedra(), "hacha_hierro": hacha_hierro(), "pico_piedra": pico(True), "pico_hierro": pico(False),
    "lanza": lanza(), "garrote": garrote(), "machete": machete(), "mochila": mochila(),
    "mochila_excursion": mochila({"body": "#3f5f73", "body_d": "#355062", "flap": "#4d7088", "flap_l": "#5f84a0", "pocket": "#30495a", "side_l": "#2c4352", "side_r": "#253947"}),
    "mochila_tactica": mochila({"body": "#4b4d3f", "body_d": "#404236", "flap": "#585a4a", "flap_l": "#686a58", "pocket": "#3a3c31", "side_l": "#34362c", "side_r": "#2c2e25"}),
}
NEW.update({"mineral_cobre": mineral_cobre(), "lingote_cobre": lingote_cobre(), "cuero": cuero(), "azufre": azufre(), "polvora": polvora(), "componentes": componentes()})
# El resto (comida y ropa): mismo contorno para que todo el juego tenga el mismo trazo
ICONS = {}
for k, v in OLD.items():
    ICONS[k] = NEW.get(k) or outlined(v, "", 4)
for k, v in NEW.items():
    ICONS.setdefault(k, v)
