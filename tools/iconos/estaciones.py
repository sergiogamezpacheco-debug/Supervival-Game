# Iconos de la pantalla de estaciones recortados de los diseños del usuario (docs/diseno_est_*.jpg).
#   python3 estaciones.py docs assets/icons/estaciones
# Se quita el color de fondo de cada recorte (el del borde) y se queda el dibujo.
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ICONOS = {  # id: (lámina, x, y, w, h, tolerancia)
    "carpinteria": ("carpinteria", 18, 16, 70, 60, 30),
    "horno": ("horno", 22, 16, 60, 60, 30),
    "mesa_costura": ("costura", 18, 16, 70, 60, 30),
    "banco_armas": ("armas", 18, 20, 60, 55, 30),
    "llama": ("destileria", 40, 795, 60, 60, 60),
    "progreso": ("destileria", 45, 680, 70, 55, 45),
    "bateria": ("horno", 44, 672, 50, 60, 60),
    "martillo": ("destileria", 890, 762, 70, 70, 80),
}


def cut(img, box, size=96):
    _, x, y, w, h, tol = box
    a = np.asarray(img.crop((x, y, x + w, y + h)).convert("RGB")).astype(float)
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(edge, axis=0)
    fg = np.sqrt(((a - bg) ** 2).sum(axis=2)) > tol
    fg = ndimage.binary_opening(fg, iterations=1)
    lab, n = ndimage.label(fg)
    if n:
        sizes = ndimage.sum(fg, lab, range(1, n + 1))
        fg = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 0.05 * sizes.max()])
    fg = ndimage.binary_fill_holes(fg)
    alpha = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
    im = Image.fromarray(a.astype(np.uint8)).convert("RGBA")
    im.putalpha(alpha)
    im = im.crop(im.getbbox())
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.size[0]) // 2, (side - im.size[1]) // 2), im)
    return sq.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    docs, out = sys.argv[1:3]
    for k, box in ICONOS.items():
        cut(Image.open(f"{docs}/diseno_est_{box[0]}.jpg"), box).save(f"{out}/{k}.png")
        print(k)
