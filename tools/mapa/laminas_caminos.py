# Láminas con pie de foto de los tramos (fotos de tools/route_shots.tscn).
#   python3 tools/mapa/laminas_caminos.py /tmp/caminos docs/caminos
import sys
from PIL import Image, ImageDraw, ImageFont

F = "/usr/share/fonts/truetype/google-fonts/ofl/"
T = ImageFont.truetype(F + "crimsontext/CrimsonText-Bold.ttf", 40)
D = ImageFont.truetype(F + "crimsontext/CrimsonText-Regular.ttf", 28)
LAMINAS = [
    ("senda_cuervo_cabana", "Senda del Cuervo · Refugio → Pinar del Cuervo (parte 1)",
     "Pinar cerrado a la izquierda y arroyo a la derecha: no se puede salir del camino. Cabaña de cazador con botín y su grupito de infectados."),
    ("senda_cuervo_visita1", "Senda del Cuervo · misma curva, visita 1",
     "En los puntos de cambio del tramo esta vez hay un pino caído cruzando el camino."),
    ("senda_cuervo_visita2", "Senda del Cuervo · misma curva, visita 2",
     "Al volver, en ese mismo punto hay un derrumbe de rocas; los infectados y los recursos también están en otro sitio."),
    ("carretera_vieja_gasolinera", "Carretera Vieja · Refugio → Base Centinela (parte 2)",
     "Asfalto con terraplén y pinar a los lados. Gasolinera con tienda, coches abandonados y algún coche cruzado."),
    ("cuesta_tajo", "Cuesta del Tajo · Refugio → Cantera del Tajo (parte 1)",
     "Barranco a un lado y pared de peñas al otro. Caseta de peones, rocas y piedras sueltas por el camino."),
    ("camino_atalaya_avisos", "Camino de La Atalaya · Pinar → La Atalaya (parte 2)",
     "Pinar y vallado. Antes de las puertas, carteles de aviso y flechas clavadas en el suelo."),
    ("via_litoral_pueblo", "Vía del Litoral · Puerto → Estación (parte 3)",
     "Se camina junto a la vía. A mitad, Valdecruces, el pueblo abandonado con casas para registrar."),
    ("ribera_guadal_molino", "Ribera del Guadal · La Atalaya → Marismas (parte 2)",
     "El río hace de frontera a un lado y el cañaveral al otro. Molino viejo junto al agua."),
    ("plano_carretera_vieja", "Carretera Vieja vista desde arriba (tramo entero)",
     "Salida a la izquierda y llegada a la derecha: un pasillo con fronteras naturales a los dos lados."),
]


def main(src, dst):
    for name, title, desc in LAMINAS:
        im = Image.open(f"{src}/{name}.png").convert("RGB")
        if name.startswith("plano"):
            im = im.crop((0, 110, 1280, 610))
        band = 120
        out = Image.new("RGB", (im.width, im.height + band), (34, 28, 22))
        out.paste(im, (0, 0))
        d = ImageDraw.Draw(out)
        d.text((24, im.height + 14), title, font=T, fill=(240, 226, 196))
        d.text((24, im.height + 66), desc, font=D, fill=(214, 196, 160))
        out.save(f"{dst}/{name}.jpg", quality=86)
        print(name)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
