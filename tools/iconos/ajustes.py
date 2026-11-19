# Iconos de la pantalla de ajustes recortados del diseño del usuario (docs/diseno_ajustes.jpg).
#   python3 ajustes.py docs/diseno_ajustes.jpg assets/icons/ajustes
# Se quita el color de fondo de cada recorte (el del borde) y se queda el dibujo.
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ICONOS = {  # id: (x, y, w, h, tolerancia)
    "sillon": (25, 20, 70, 70, 34),
    "engranaje": (296, 42, 30, 30, 70),
    "puerta": (636, 766, 56, 62, 70),
    "papelera": (976, 775, 46, 52, 40),
}


def cut(img, box, size=96):
    x, y, w, h, tol = box
    a = np.asarray(img.crop((x, y, x + w, y + h)).convert("RGB")).astype(float)
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(edge, axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    fg = dist > tol
    lab, n = ndimage.label(fg)
    if n:
        sizes = ndimage.sum(fg, lab, range(1, n + 1))
        fg = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 0.03 * sizes.max()])
    fg = ndimage.binary_fill_holes(fg) if box[4] < 50 else fg
    alpha = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
    im = Image.fromarray(a.astype(np.uint8)).convert("RGBA")
    im.putalpha(alpha)
    im = im.crop(im.getbbox())
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.size[0]) // 2, (side - im.size[1]) // 2), im)
    return sq.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    img = Image.open(sys.argv[1])
    for k, box in ICONOS.items():
        cut(img, box).save(f"{sys.argv[2]}/{k}.png")
        print(k)
