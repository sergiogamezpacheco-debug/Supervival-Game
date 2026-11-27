# Mapa del Valle y caminos entre zonas

Imágenes: `docs/mapa/` (`python3 tools/mapa/mapa.py`) y `docs/caminos/` (fotos de
`tools/route_shots.tscn` + `python3 tools/mapa/laminas_caminos.py /tmp/caminos docs/caminos`).

## Lugares y partes del mapa

| Parte | Cómo se consigue | Lugares |
|---|---|---|
| I | Al empezar | Refugio, Pinar del Cuervo y Cantera del Tajo (zona fácil de cada uno), arbolitos a la izquierda del refugio, mini zona rocosa junto al pinar |
| II | Trozo del superviviente muerto en el Pinar del Cuervo | Zonas peligrosas del Pinar y la Cantera, La Atalaya (poblado tipo Hilltop), Marismas del Guadal (traje de buzo, zombis del pantano), Base Centinela (5 militares + valla rota con infectados), casas sueltas y gasolinera |
| III | Trozo en la zona infectada de la Base Centinela (con ayuda de La Atalaya) | Villamuralla (arriba a la izquierda, tras la sierra), Puerto de la Caleta (playa y barco abandonado), Estación de tren, Central Nuclear, Valdecruces (pueblo abandonado) y la vía que los une |

Las piezas se cosen al mapa al encontrarlas. Queda sitio libre al norte de la sierra, al este de las marismas y
en la costa oeste para zonas futuras.

## Moverse: zonas + caminos

- Cada lugar es una pantalla (como ahora). Entre lugares vecinos hay un **tramo de camino** (`data/routes.json`):
  un pasillo de 260–400 m con fronteras naturales a los lados (pinar cerrado, arroyo, río, cañaveral, barranco,
  peñas, vallado, terraplén, acantilado) y paredes invisibles detrás (`RouteBuilder`).
- **Viaje rápido** desde el mapa: gasta **energía de viaje**, que solo se recarga con el tiempo o viendo un vídeo.
  Sin energía se va andando por el camino (más largo, pero con botín y peligro).
- Cada tramo tiene fijos su trazado y sus sitios (gasolinera, casas, molino...); en cada visita cambian los
  **puntos de cambio** (árbol caído, coche cruzado, derrumbe, barricada, barro o nada), el sitio de los infectados
  (siempre hay un grupito rondando cada sitio con botín) y el de los recursos.

| Tramo | De → a | Parte | Fronteras | Sitios |
|---|---|---|---|---|
| Senda del Cuervo | Refugio → Pinar | I | pinar / arroyo | cabaña de cazador, troncos |
| Cuesta del Tajo | Refugio → Cantera | I | barranco / peñas | caseta de peones, vagoneta |
| Camino de La Atalaya | Pinar → La Atalaya | II | pinar / vallado | casa de labranza, control de coches, carteles de aviso |
| Ribera del Guadal | La Atalaya → Marismas | II | río / cañaveral | molino, barca |
| Carretera Vieja | Refugio → Base Centinela | II | terraplén / pinar | gasolinera, coches, tienda de carretera |
| Carretera de la Costa | Base Centinela → Puerto | III | acantilado / pinar | casa de playa, furgoneta |
| Paso de la Sierra | Cantera → Villamuralla | III | barranco / peñas | refugio de montaña, puente |
| Vía del Litoral | Puerto → Estación | III | terraplén / vallado | Valdecruces, vagón volcado |
| Vía de la Central | Estación → Central | III | vallado / terraplén | control militar, vagón volcado |

## Pendiente (siguiente paso)

1. Pasar `data/world_map.json` y la pantalla del mapa al nuevo trazado (piezas I, II, III).
2. Que el viaje entre zonas cargue el tramo (`world` con `RouteBuilder`) y energía de viaje con recarga por tiempo/vídeo.
3. Nuevas zonas: La Atalaya (confianza y puertas), Base Centinela, Marismas (traje de buzo), Puerto, Estación,
   Central y Villamuralla.
