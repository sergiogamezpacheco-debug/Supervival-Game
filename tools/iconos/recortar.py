# Recorta los iconos de los diseños del usuario (láminas "low poly pack") y quita el fondo.
#   python3 recortar.py <lamina_materiales.jpg> <lamina_objetos.jpg> <salida_dir>
# Fondo: píxeles oscuros y azulados conectados al borde del recorte. Se guarda PNG 128x128.
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

MATERIALES = {  # id: (x, y, w, h)
    "madera": (40, 180, 200, 170), "piedra": (270, 195, 180, 140), "mineral_hierro": (470, 195, 180, 140),
    "chatarra": (660, 200, 210, 150), "tablon": (40, 440, 210, 150), "bloque_piedra": (270, 440, 170, 150),
    "lingote_hierro": (470, 470, 180, 120), "lingote_cobre": (675, 470, 180, 120), "tela": (30, 780, 220, 130),
    "cuero": (255, 775, 210, 150), "polvora": (490, 750, 140, 180), "componentes": (675, 735, 200, 200),
}
OBJETOS = {
    "hacha_piedra": (40, 180, 200, 170), "pico_piedra": (255, 180, 200, 170), "lanza": (460, 180, 200, 180),
    "garrote": (670, 180, 200, 180), "mochila": (50, 450, 170, 200), "antorcha": (280, 450, 140, 200),
    "venda": (485, 485, 170, 140), "cuerda": (695, 500, 180, 130), "trampa_pinchos": (40, 760, 220, 200),
    "cantimplora": (300, 770, 140, 200), "ropa_basica": (470, 780, 210, 180), "molotov": (700, 760, 140, 220),
}


def cut(img, box):
    x, y, w, h = box
    a = np.asarray(img.crop((x, y, x + w, y + h)).convert("RGB")).astype(float)
    hh, ww = a.shape[:2]
    # Modelo del fondo: plano (degradado) ajustado con los píxeles del borde
    yy, xx = np.mgrid[0:hh, 0:ww]
    edge = np.zeros((hh, ww), bool)
    edge[:4] = edge[-4:] = True
    edge[:, :4] = edge[:, -4:] = True
    A = np.c_[xx[edge], yy[edge], np.ones(edge.sum())]
    model = np.zeros_like(a)
    for ch in range(3):
        coef, *_ = np.linalg.lstsq(A, a[..., ch][edge], rcond=None)
        model[..., ch] = coef[0] * xx + coef[1] * yy + coef[2]
    d = a - model
    dist = np.sqrt((d ** 2).sum(axis=2))
    sat = a.max(axis=2) - a.min(axis=2)
    darker = d.mean(axis=2)
    # fondo: parecido al degradado, o sombra (más oscuro y poco saturado)
    bgish = (dist < 22) | ((darker < 0) & (sat < 30) & (np.abs(d[..., 2] - d[..., 0]) < 14))
    lab, _ = ndimage.label(bgish)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    fg = ~bg
    fg = ndimage.binary_opening(fg, iterations=1)
    lab2, n = ndimage.label(fg)
    if n:
        sizes = ndimage.sum(fg, lab2, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s > 0.02 * sizes.max()]
        fg = np.isin(lab2, keep)
    fg = ndimage.binary_fill_holes(fg)
    alpha = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    rgba = Image.fromarray(a.astype(np.uint8)).convert("RGBA")
    rgba.putalpha(alpha)
    bb = rgba.getbbox()
    rgba = rgba.crop(bb)
    # cuadrado 128 con margen y contorno oscuro suave (como el resto de iconos)
    side = int(max(rgba.size) * 1.12)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(rgba, ((side - rgba.size[0]) // 2, (side - rgba.size[1]) // 2), rgba)
    sq = sq.resize((128, 128), Image.LANCZOS)
    al = np.asarray(sq)[..., 3]
    ring = ndimage.binary_dilation(al > 40, iterations=2) & ~(al > 40)
    out = np.zeros((128, 128, 4), np.uint8)
    out[ring] = (22, 17, 12, 200)
    o = Image.fromarray(out)
    o.alpha_composite(sq)
    return o


def variantes(outdir):
    """Objetos sin diseño propio: se tiñen a partir de los diseños del usuario."""
    def ld(n): return np.asarray(Image.open(f"{outdir}/{n}.png").convert("RGBA")).astype(float)
    def sv(a, n): Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(f"{outdir}/{n}.png")
    # mena de cobre: las zonas azuladas de la mena de hierro pasan a verde malaquita
    a = ld("mineral_hierro"); r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    blu = np.clip((b - r) / 40, 0, 1)[..., None] * 0.85
    a[..., :3] = a[..., :3] * (1 - blu) + np.stack([lum * 0.55, lum * 1.25, lum], -1) * blu
    sv(a, "mineral_cobre")
    # azufre: piedra bruta en amarillo conservando el sombreado
    a = ld("piedra"); lum = (0.3 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2]) / 255
    col = np.stack([255 * np.clip(lum * 1.45, 0, 1), 235 * np.clip(lum * 1.4, 0, 1), 70 * np.clip(lum * 1.2, 0, 1)], -1)
    a[..., :3] = col * 0.85 + a[..., :3] * 0.15
    sv(a, "azufre")
    # mochilas de excursión (azul) y táctica (oliva): se tiñe la lona clara
    for n, tc in [("mochila_excursion", (70, 112, 145)), ("mochila_tactica", (96, 102, 70))]:
        a = ld("mochila"); lum = 0.3 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2]
        lona = (np.clip((lum - 95) / 30, 0, 1) * 0.9)[..., None]
        a[..., :3] = a[..., :3] * (1 - lona) + np.stack([lum / 150 * c for c in tc], -1) * lona
        sv(a, n)


if __name__ == "__main__":
    mat, obj, outdir = sys.argv[1:4]
    for src, table in [(mat, MATERIALES), (obj, OBJETOS)]:
        img = Image.open(src)
        for k, box in table.items():
            cut(img, box).save(f"{outdir}/{k}.png")
            print(k)
    variantes(outdir)
