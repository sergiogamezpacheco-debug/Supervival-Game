"""Textura de detalle del superviviente sacada del diseño de frente/perfil del usuario.

  python3 tools/iconos/personaje.py docs/diseno_personaje.jpg assets/characters/superviviente.png

El modelo tiene la misma silueta que el dibujo (medida con las vistas ortogonales), así
que cada triángulo toma el color del dibujo en su posición: de frente (con la cara del
primer plano, a más resolución) o de perfil. Se guarda como "cuánto más claro u oscuro
que el color base" para cada material (piel, pelo, ropa interior); así el jugador puede
elegir otro tono de piel o de pelo y conserva sombras, músculos y cara del diseño.
Las constantes impresas van en CharacterModel (DESIGN_*).
"""
import sys
import numpy as np
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
H, W, _ = im.shape

def bil(x, y):
    x = np.clip(x, 0, W - 1.001); y = np.clip(y, 0, H - 1.001)
    x0 = np.floor(x).astype(int); y0 = np.floor(y).astype(int)
    fx = (x - x0)[..., None]; fy = (y - y0)[..., None]
    a = im[y0, x0]; b = im[y0, x0 + 1]; c = im[y0 + 1, x0]; d = im[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy

# zona útil del frente (columnas/filas del dibujo) y escala en la textura
FC0, FC1, R0, R1, FS = 130, 400, 30, 650, 2.0
SC0, SC1, SS = 680, 860, 1.5
# primer plano de la cara: ojo izq. del frente (250.25,105.5) = (1205,318) del primer plano, x5
def front_px(c, r):
    col = bil(c, r)
    cc = 1205 + (c - 250.25) * 5.0; cr = 318 + (r - 105.5) * 5.0
    use = (cc > 1022) & (cc < 1524) & (cr > 2) & (cr < H - 3) & (r < 168)
    if use.any():
        col[use] = bil(cc[use], cr[use])
    return col

fw = int((FC1 - FC0) * FS); fh = int((R1 - R0) * FS)
sw = int((SC1 - SC0) * SS); sh = int((R1 - R0) * SS)
u, v = np.meshgrid(np.arange(fw), np.arange(fh))
front = front_px(FC0 + u / FS, R0 + v / FS)
u, v = np.meshgrid(np.arange(sw), np.arange(sh))
side = bil(SC0 + u / SS, R0 + v / SS)

def is_bg(c):
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    return (np.abs(r - g) < 9) & (np.abs(g - b) < 9) & (r > 105) & (r < 178)

def med(c0, c1, r0, r1, cond=None):
    px = im[r0:r1, c0:c1].reshape(-1, 3)
    if cond is not None:
        px = px[cond(px)]
    return np.median(px, 0)

bases = [
    med(235, 300, 215, 290),                                   # piel (pecho)
    med(225, 305, 50, 90, lambda p: p.sum(1) < 330),           # pelo
    med(235, 300, 335, 380, lambda p: p.sum(1) > 520),         # bóxer
]
LW = fw + sw
AH = max(fh, sh)
atlas = np.full((AH, LW * 3, 3), 127.5, np.float32)
for k, base in enumerate(bases):
    for img, x0 in ((front, 0), (side, fw)):
        ratio = np.clip(img / base * 127.5, 0, 255)
        ratio[is_bg(img)] = 127.5
        atlas[: img.shape[0], k * LW + x0: k * LW + x0 + img.shape[1]] = ratio
atlas[-4:, -4:] = 127.5   # píxel neutro
Image.fromarray(atlas.astype(np.uint8)).save(dst, optimize=True)
print("bases", [b.round() for b in bases])
print(f"const DESIGN_ATLAS := Vector2({LW * 3}, {AH})")
print(f"const DESIGN_LAYER := {LW}")
print(f"const DESIGN_FRONT := [{FC0}, {R0}, {FS}]   # columna, fila, escala")
print(f"const DESIGN_SIDE := [{SC0}, {R0}, {SS}, {fw}]")
