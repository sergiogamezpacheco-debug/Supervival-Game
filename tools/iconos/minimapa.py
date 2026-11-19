# Iconos del minimapa recortados del diseño del usuario (docs/diseno_minimapa.jpg).
#   python3 minimapa.py docs/diseno_minimapa.jpg assets/icons/minimap
# El fondo del diseño es verde: se quita todo lo que tira a verde y se queda la pieza más grande.
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ICONOS = {  # id: (x, y, w, h)
    "infectado": (562, 172, 60, 95),
    "zorro": (393, 593, 95, 60),
    "ciervo": (463, 622, 85, 95),
    "caja": (683, 402, 100, 90),
    "jugador": (572, 395, 56, 60),
    "norte": (575, 72, 50, 95),
}


def cut(img, box, size=96):
    x, y, w, h = box
    a = np.asarray(img.crop((x, y, x + w, y + h)).convert("RGB")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = (g > r + 2) & (g >= b - 2)
    fg = ndimage.binary_opening(~green, iterations=1)
    lab, n = ndimage.label(fg)
    if n:
        sizes = ndimage.sum(fg, lab, range(1, n + 1))
        if box == ICONOS["norte"]:   # flecha y letra: dos piezas
            keep = [i + 1 for i, s in enumerate(sizes) if s > 0.15 * sizes.max()]
        else:
            keep = [int(np.argmax(sizes)) + 1]
        fg = np.isin(lab, keep)
    fg = ndimage.binary_fill_holes(fg)
    alpha = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
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
        ic = cut(img, box)
        if k == "jugador":   # el borde oscuro de la flecha se va con el fondo: se repone
            al = np.asarray(ic)[..., 3] > 60
            ring = ndimage.binary_dilation(al, iterations=4) & ~al
            o = np.zeros((ic.size[1], ic.size[0], 4), np.uint8)
            o[ring] = (16, 28, 40, 255)
            base = Image.fromarray(o)
            base.alpha_composite(ic)
            ic = base
        ic.save(f"{sys.argv[2]}/{k}.png")
        print(k)
