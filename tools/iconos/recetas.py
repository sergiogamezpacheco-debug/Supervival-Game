# Iconos de recetas y vistas grandes recortados de los diseños de estaciones (docs/diseno_est_*.jpg).
#   python3 recetas.py docs assets/icons
# - recetas/<id>.png: el icono de la tarjeta de la lista (dentro de su marco)
# - preview/<id>.png: la imagen grande de la izquierda
# - items/<id>.png: también para los objetos que no tenían icono de lámina propia
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

RECETAS = {  # id: (lámina, x, y) del marco de 96x96 de la tarjeta
    "lingote_hierro": ("horno", 718, 116),
    "lingote_cobre": ("horno", 718, 244),
    "tablon": ("carpinteria", 718, 116),
    "mango": ("carpinteria", 718, 244),
    "viga": ("carpinteria", 718, 372),
    "acero": ("horno", 718, 372),
    "pantalon_tela": ("costura", 718, 244),
    "gorra": ("costura", 718, 372),
    "camiseta": ("costura", 718, 500),
    "antidoto": ("quimica", 718, 116),
    "botiquin": ("quimica", 718, 244),
    "estimulante": ("quimica", 718, 372),
    "vendas_avanzadas": ("quimica", 718, 500),
    "circuito_avanzado": ("electronica", 718, 116),
    # cocina y destilería: láminas de 1200x896, marcos de 115 px
    "plato_cocinado": ("cocina", 637, 139, 115),
    "conserva_carne": ("cocina", 637, 294, 115),
    "agua_hervida": ("cocina", 637, 449, 115),
    "guiso_setas": ("cocina", 637, 604, 115),
    "agua_purificada": ("destileria", 637, 139, 115),
    "alcohol": ("destileria", 637, 294, 115),
    "combustible": ("destileria", 637, 449, 115),
    "agua_sucia": ("destileria", 637, 604, 115),
    "compost": ("compostadora", 718, 122, 96, "oscuro"),   # montón negro sobre fondo oscuro
    "abono_organico": ("compostadora", 718, 250),
    "humus": ("compostadora", 718, 378, 96, "oscuro"),
    # almacenamiento: baúles en marcos cuadrados; estanterías y armarios en círculos (centro x, y; radio)
    "baul_madera": ("almacen_baules", 718, 122, 94, "fino", "convexo"),
    "cofre_reforzado": ("almacen_baules", 718, 250, 94, "fino", "convexo"),
    "caja_suministros": ("almacen_baules", 718, 378, 94, "fino", "convexo"),
    "estanteria_madera": ("almacen_estanterias", 826, 146, 56, "circulo"),
    "estanteria_industrial": ("almacen_estanterias", 826, 299, 56, "circulo"),
    "estanteria_taller": ("almacen_estanterias", 826, 452, 56, "circulo"),
    "armario_madera": ("almacen_armarios", 826, 146, 56, "circulo", "convexo"),
    "armario_metal": ("almacen_armarios", 826, 299, 56, "circulo", "convexo"),
    "armario_reforzado": ("almacen_armarios", 826, 452, 56, "circulo", "convexo"),
}
ALMACEN = ["baul_madera", "cofre_reforzado", "caja_suministros", "estanteria_madera", "estanteria_industrial",
           "estanteria_taller", "armario_madera", "armario_metal", "armario_reforzado"]
TAMBIEN_ITEMS = ["mango", "viga", "acero", "pantalon_tela", "gorra", "camiseta", "antidoto", "botiquin",
                 "estimulante", "vendas_avanzadas", "circuito_avanzado", "plato_cocinado", "conserva_carne", "agua_hervida",
                 "guiso_setas", "agua_purificada", "alcohol", "combustible", "agua_sucia",
                 "compost", "abono_organico", "humus"] + ALMACEN
VISTAS = {  # id: (lámina, x, y, w, h)
    "lingote_hierro": ("horno", 180, 165, 330, 250),
    "tablon": ("carpinteria", 185, 200, 320, 230),
    "antidoto": ("quimica", 262, 128, 150, 158),
    "circuito_avanzado": ("electronica", 205, 145, 255, 192),
}
# Vistas sobre peana de piedra: por debajo de "suelo" (y en la lámina) solo se queda lo que tiene color
# (madera, cajas), así no sale la peana gris.
VISTAS_PEANA = {  # id: (lámina, x, y, w, h, suelo)
    "baul_madera": ("almacen_baules", 180, 130, 340, 290, 312),
    "estanteria_madera": ("almacen_estanterias", 220, 90, 300, 330, 312),
    "armario_madera": ("almacen_armarios", 220, 90, 300, 330, 325),
}


def sobre_peana(a, y0, tol=30):
    from skimage.color import rgb2hsv
    edge = np.concatenate([a[0], a[:, 0], a[:, -1]])
    bg = np.median(edge, axis=0)
    fg = np.sqrt(((a - bg) ** 2).sum(axis=2)) > tol
    hsv = rgb2hsv(a / 255.0)
    sat = (hsv[..., 1] > 0.28) & (hsv[..., 2] > 0.18)
    fg[y0:] = sat[y0:]
    fg = ndimage.binary_opening(fg, iterations=1)
    lab, n = ndimage.label(fg)
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    fg = ndimage.binary_fill_holes(ndimage.binary_closing(lab == int(np.argmax(sizes)) + 1, iterations=2))
    alpha = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    im = Image.fromarray(a.astype(np.uint8)).convert("RGBA")
    im.putalpha(alpha)
    im = im.crop(im.getbbox())
    side = int(max(im.size) * 1.04)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.size[0]) // 2, (side - im.size[1]) // 2), im)
    return sq.resize((384, 384), Image.LANCZOS)


def cut(a, tol, size, only_biggest=False, dark=False, convex=False):
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(edge, axis=0)
    if dark:
        # dibujo más oscuro que el fondo (compost): se separa por luminosidad
        fg = a.mean(axis=2) < bg.mean() * 0.88
        fg = ndimage.binary_closing(fg, iterations=3)
        lab, n = ndimage.label(fg)
        if n:   # el montón: la mancha más grande, rellena columna a columna (es un montículo)
            sizes = ndimage.sum(fg, lab, range(1, n + 1))
            fg = ndimage.binary_fill_holes(lab == int(np.argmax(sizes)) + 1)
            for c in range(fg.shape[1]):
                rows = np.nonzero(fg[:, c])[0]
                if rows.size:
                    fg[rows[0]:rows[-1] + 1, c] = True
    else:
        fg = np.sqrt(((a - bg) ** 2).sum(axis=2)) > tol
    fg = ndimage.binary_opening(fg, iterations=1)
    lab, n = ndimage.label(fg)
    if n:
        sizes = ndimage.sum(fg, lab, range(1, n + 1))
        keep = [int(np.argmax(sizes)) + 1] if only_biggest else [i + 1 for i, s in enumerate(sizes) if s > 0.04 * sizes.max()]
        fg = np.isin(lab, keep)
    fg = ndimage.binary_fill_holes(fg)
    if convex:   # cajas, baúles y armarios: su silueta es convexa (las partes oscuras se confunden con el fondo)
        from skimage.morphology import convex_hull_image
        fg = convex_hull_image(fg)
    alpha = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
    im = Image.fromarray(a.astype(np.uint8)).convert("RGBA")
    im.putalpha(alpha)
    im = im.crop(im.getbbox())
    side = int(max(im.size) * 1.06)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.size[0]) // 2, (side - im.size[1]) // 2), im)
    return sq.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    docs, out = sys.argv[1:3]
    solo = sys.argv[3:]   # opcional: solo estos ids
    for k, (sheet, x, y, *fr) in RECETAS.items():
        if solo and k not in solo:
            continue
        f = fr[0] if fr else 96
        dark = "oscuro" in fr
        img = Image.open(f"{docs}/diseno_est_{sheet}.jpg").convert("RGB")
        if "circulo" in fr:
            # marco redondo: (x, y) es el centro y f el radio de dentro; lo de fuera se pinta del fondo
            a = np.asarray(img.crop((x - f, y - f, x + f, y + f))).astype(float)
            yy, xx = np.mgrid[0:2 * f, 0:2 * f]
            d = np.hypot(xx - f + 0.5, yy - f + 0.5)
            inner = np.median(a[(d > f - 7) & (d < f - 2)], axis=0)
            a[d >= f] = inner
        else:
            m = 5 if "fino" in fr else round(f * 0.094)   # "fino": el dibujo llega casi al marco
            a = np.asarray(img.crop((x + m, y + m, x + f - m, y + f - m))).astype(float)
        ic = cut(a, 26, 128, "circulo" in fr, dark=dark, convex="convexo" in fr)
        ic.save(f"{out}/recetas/{k}.png")
        if k in TAMBIEN_ITEMS:
            ic.save(f"{out}/items/{k}.png")
        print("receta", k)
    for k, (sheet, x, y, w, h) in VISTAS.items():
        if solo and k not in solo:
            continue
        img = Image.open(f"{docs}/diseno_est_{sheet}.jpg").convert("RGB")
        a = np.asarray(img.crop((x, y, x + w, y + h))).astype(float)
        cut(a, 30, 384, k in ("antidoto", "circuito_avanzado")).save(f"{out}/preview/{k}.png")
        print("vista", k)
    for k, (sheet, x, y, w, h, y0) in VISTAS_PEANA.items():
        if solo and k not in solo:
            continue
        img = Image.open(f"{docs}/diseno_est_{sheet}.jpg").convert("RGB")
        a = np.asarray(img.crop((x, y, x + w, y + h))).astype(float)
        sobre_peana(a, y0 - y).save(f"{out}/preview/{k}.png")
        print("vista", k)
