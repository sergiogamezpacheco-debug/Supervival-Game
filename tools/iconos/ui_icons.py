# Iconos de interfaz (HUD) en el mismo estilo que los objetos: contorno oscuro y facetas.
from items2 import P, C, E, L, R, outlined, OUT


def vida():
    heart = '<path d="M32 56 L9 32 C2 24 5 11 16 9 C23 8 28 12 32 18 C36 12 41 8 48 9 C59 11 62 24 55 32 Z" fill="#c8362f"></path>'
    det = '<path d="M32 56 L9 32 C2 24 5 11 16 9 C23 8 28 12 32 18 Z" fill="#e0483f"></path>'
    det += P([(14, 16), (22, 13), (17, 22)], "#f59a8f")
    return outlined(heart, det)


def comida():
    meat = '<path d="M10 30 C8 18 20 8 32 10 C44 12 50 24 44 34 C40 41 30 44 22 42 C16 40 11 36 10 30 Z" fill="#9a5226"></path>'
    det = '<path d="M14 26 C16 16 26 11 34 13 C30 18 24 24 18 30 Z" fill="#b8693a"></path>'
    det += L("M18 34 C24 36 32 34 38 28", "#6e3818", 2)
    bone = P([(38, 36), (52, 50), (48, 54), (34, 40)], "#efe6d2") + C(53, 50, 4.5, "#f6efe0") + C(49, 55, 4.5, "#f6efe0")
    return outlined(meat + P([(38, 36), (52, 50), (48, 54), (34, 40)], "#888") + C(53, 50, 4.5, "#888") + C(49, 55, 4.5, "#888"), det + bone)


def agua():
    drop = '<path d="M32 5 C26 18 12 30 12 42 C12 53 21 60 32 60 C43 60 52 53 52 42 C52 30 38 18 32 5 Z" fill="#2f7fd0"></path>'
    det = '<path d="M32 5 C26 18 12 30 12 42 C12 53 21 60 32 60 Z" fill="#4a98e4"></path>'
    det += '<path d="M21 40 C21 33 25 28 28 24" fill="none" stroke="#bfe0ff" stroke-width="3.5" stroke-linecap="round"></path>'
    return outlined(drop, det)


def energia():
    bolt = P([(38, 4), (14, 36), (30, 36), (24, 60), (50, 26), (34, 26), (42, 4)], "#e8b62a")
    det = P([(38, 4), (14, 36), (30, 36), (34, 26), (42, 4)], "#f6d250") + P([(36, 10), (22, 32), (27, 32)], "#fff0a8")
    return outlined(bolt, det)


def fabricar():
    # Martillo y sierra cruzados
    saw = P([(10, 16), (16, 10), (50, 44), (44, 50)], "#b9c2c7")
    teeth = ""
    for k in range(6):
        x, y = 13 + k * 6, 19 + k * 6
        teeth += P([(x, y), (x + 4, y + 4), (x - 1, y + 5)], "#8f989e")
    saw_h = P([(44, 50), (50, 44), (58, 52), (52, 58)], "#7a4a28")
    handle = P([(12, 52), (46, 18), (50, 22), (16, 56)], "#a5713f")
    head = P([(38, 8), (52, 22), (46, 28), (32, 14)], "#5d656b")
    base = saw + teeth + saw_h + handle + head
    det = saw + P([(16, 10), (50, 44), (47, 47), (13, 13)], "#dfe5e8") + teeth + saw_h + handle + P([(12, 52), (46, 18), (48, 20), (14, 54)], "#c08a54") + head + P([(38, 8), (52, 22), (50, 24), (36, 10)], "#8f989e")
    return outlined(base, det)


def construir():
    # Muro de tablas con tejado
    roof = P([(6, 30), (32, 8), (58, 30), (52, 34), (32, 17), (12, 34)], "#8a5a30")
    wall = P([(14, 32), (32, 18), (50, 32), (50, 58), (14, 58)], "#b07a46")
    door = R(27, 42, 10, 16, "#5e3b1f", 1)
    base = roof + wall
    det = wall + P([(32, 18), (50, 32), (50, 58), (32, 58)], "#9a6a3c")
    for y in (38, 46, 54):
        det += L(f"M15 {y} L49 {y}", "#7a4f2b", 1.4)
    det += door + roof + P([(6, 30), (32, 8), (32, 17), (12, 34)], "#a5713f")
    return outlined(base, det)


def mapa():
    sheet = P([(6, 14), (22, 8), (42, 14), (58, 8), (58, 50), (42, 56), (22, 50), (6, 56)], "#e2cf9e")
    det = P([(22, 8), (42, 14), (42, 56), (22, 50)], "#d1bb86") + P([(6, 14), (22, 8), (22, 50), (6, 56)], "#ecdcb0")
    det += '<path d="M12 46 C18 38 22 40 28 32 C34 24 40 30 46 22" fill="none" stroke="#8a5a30" stroke-width="2.5" stroke-dasharray="3 3" stroke-linecap="round"></path>'
    det += L("M45 17 L53 25 M53 17 L45 25", "#c8362f", 3.2)
    det += '<path d="M10 22 C14 20 16 24 20 22" fill="none" stroke="#4a8fc8" stroke-width="2" stroke-linecap="round"></path>'
    return outlined(sheet, det)


def agachar():
    c = "#d8dcc8"
    head = C(38, 18, 6.5, c)
    torso = P([(28, 28), (38, 25), (36, 44), (22, 44)], c)        # espalda inclinada
    thigh_f = P([(30, 40), (36, 44), (44, 46), (42, 51), (30, 48)], c)  # muslo adelante
    shin_f = P([(38, 47), (44, 46), (46, 58), (40, 58)], c)
    thigh_b = P([(22, 40), (30, 42), (24, 54), (18, 52)], c)       # rodilla atrás casi en el suelo
    shin_b = P([(18, 50), (24, 54), (14, 58), (10, 56)], c)
    arm = P([(34, 27), (40, 28), (48, 38), (44, 41)], c)
    return outlined(head + torso + thigh_f + shin_f + thigh_b + shin_b + arm, "", 4)


def de_pie():
    s = C(32, 10, 6.5, "#d8dcc8") + P([(25, 19), (39, 19), (42, 38), (22, 38)], "#d8dcc8")
    s += P([(24, 36), (31, 36), (30, 60), (23, 60)], "#d8dcc8") + P([(33, 36), (40, 36), (41, 60), (34, 60)], "#d8dcc8")
    s += P([(25, 20), (19, 36), (16, 35), (21, 20)], "#d8dcc8") + P([(39, 20), (45, 36), (48, 35), (43, 20)], "#d8dcc8")
    return outlined(s, "", 4)


def puno():
    fist = '<path d="M14 26 C14 18 20 16 24 18 C25 13 31 12 34 15 C36 11 42 11 44 15 C48 13 54 16 53 22 L53 38 C53 48 46 56 36 56 L28 56 C19 56 14 48 14 40 Z" fill="#e0b48a"></path>'
    det = L("M24 18 L24 32 M34 15 L34 31 M44 15 L44 31", "#b9895e", 2.2)
    det += '<path d="M14 34 C20 30 28 32 30 38 C24 40 20 40 16 40" fill="#cf9f74"></path>'
    det += P([(16, 24), (22, 20), (20, 28)], "#f2d0aa")
    return outlined(fist, det)


def mano():
    hand = '<path d="M20 56 L14 36 C12 30 18 28 21 32 L24 38 L22 14 C22 9 29 9 29 14 L30 30 L31 8 C31 3 38 3 38 8 L38 30 L40 11 C40 6 47 6 47 11 L46 32 L49 19 C50 14 56 15 56 20 L52 44 C50 52 46 56 40 58 Z" fill="#e0b48a"></path>'
    det = L("M29 30 L30 36 M38 30 L38 36 M46 32 L45 37", "#b9895e", 1.8)
    det += P([(23, 16), (27, 13), (26, 22)], "#f2d0aa")
    return outlined(hand, det)


def ajustes():
    import math
    teeth = ""
    for k in range(8):
        a = k * math.pi / 4
        pts = [(32 + math.cos(a + d) * r, 32 + math.sin(a + d) * r) for d, r in [(-0.2, 17), (-0.14, 26), (0.14, 26), (0.2, 17)]]
        teeth += P(pts, "#aab3b8")
    base = teeth + C(32, 32, 19, "#aab3b8")
    det = teeth + C(32, 32, 19, "#aab3b8") + '<path d="M32 13 A19 19 0 0 0 13 32 L32 32 Z" fill="#cfd6da"></path>' + C(32, 32, 8, "#16110c")
    return outlined(base, det)


def esquivar():
    c = "#d8dcc8"
    body = C(40, 16, 6.5, c) + P([(30, 22), (40, 26), (34, 42), (24, 38)], c) + P([(24, 38), (34, 42), (44, 52), (40, 56), (26, 46)], c) + P([(24, 38), (28, 44), (14, 50), (12, 45)], c) + P([(36, 26), (40, 28), (50, 34), (48, 38), (36, 32)], c)
    lines = L("M6 22 L20 22 M4 32 L16 32 M8 12 L18 12", c, 3.5)
    return outlined(body, "", 4) + f'<g stroke="{OUT}">' + L("M6 22 L20 22 M4 32 L16 32 M8 12 L18 12", OUT, 7) + '</g>' + lines


UI = {"ajustes": ajustes(), "esquivar": esquivar(), "vida": vida(), "comida": comida(), "agua": agua(), "energia": energia(), "fabricar": fabricar(),
      "construir": construir(), "mapa": mapa(), "agachar": agachar(), "de_pie": de_pie(), "puno": puno(), "mano": mano()}
