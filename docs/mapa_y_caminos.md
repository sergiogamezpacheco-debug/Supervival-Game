# Mapa del Valle y caminos entre zonas

Imágenes: `docs/mapa/` (`python3 tools/mapa/mapa.py`) y `docs/caminos/` (fotos de
`tools/route_shots.tscn` + `python3 tools/mapa/laminas_caminos.py /tmp/caminos docs/caminos`).

## Lugares y partes del mapa

| Parte | Cómo se consigue | Lugares |
|---|---|---|
| I | Al empezar (el círculo alrededor del refugio) | Refugio, **La Arboleda** (arbolitos a la izquierda) y **El Pedregal** (rocas a la derecha) |
| II | Trozo del superviviente muerto en La Arboleda | Pinar del Cuervo y Cantera del Tajo (más botín y más peligro), La Atalaya (poblado tipo Hilltop), Marismas del Guadal (traje de buzo, zombis del pantano), Base Centinela (5 militares + valla rota con infectados), casas sueltas y gasolinera |
| III | Trozo en la zona infectada de la Base Centinela (con ayuda de La Atalaya) | Villamuralla (arriba a la izquierda, tras la sierra), Puerto de la Caleta (playa y barco abandonado), Estación de tren, Central Nuclear, Valdecruces (pueblo abandonado) y la vía que los une |

Las piezas se cosen al mapa al encontrarlas. Queda sitio libre al norte de la sierra, al este de las marismas y
en la costa oeste para zonas futuras.

## Zonas de recolección

| Zona | Parte | Rocas y vetas | Árboles y madera | Botín |
|---|---|---|---|---|
| El Pedregal | I | de cada 10: 9 rocas, 1 veta de hierro | algún arbusto | 1 coche abandonado: chatarra, cuerda, tela, latas |
| La Arboleda | I | pocas piedras sueltas | ~30 árboles pequeños, madera básica y ramas | coche abandonado y el superviviente muerto (pieza II) |
| Cantera del Tajo | II | de cada 10: 3 rocas, 5 vetas básicas (hierro, carbón), 2 mejores (cobre, azufre) | pocos pinos | caseta y coches: herramientas, componentes, armas |
| Pinar del Cuervo | II | pocas rocas | ~110 pinos grandes (más madera por árbol) | cabaña, aserradero y coches: armas, ropa, medicinas |

Coches abandonados con suministros también por los caminos (2 en la parte I, más en la II y III).

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

1. ✅ `data/world_map.json` y la pantalla del mapa con el nuevo trazado: el HUD muestra el recorte
   `MAP_VIEWS` (igual que `VISTAS` en `mapa.py`) según `GS.map_pieces`.
2. ✅ Viaje rápido con energía (`GS.travel_energy_now()`, 20/h reales, máx. 100) o "Ir andando" (`world.walk_to`),
   que carga el tramo con `RouteBuilder` y llega al otro extremo. Falta la recarga viendo vídeos (SDK de anuncios).
3. Nuevas zonas: La Atalaya (confianza y puertas), Base Centinela, Marismas (traje de buzo), Puerto, Estación,
   Central y Villamuralla.

## Casas con interior

Las casas de los caminos (casa de labranza, casa de la playa, tienda de carretera, tienda de la gasolinera y
las cuatro casitas del pueblo abandonado) se pueden recorrer: al entrar se quitan el tejado y lo alto de
las paredes. Cada habitación tiene muebles que se registran:

| Casa | Habitaciones y muebles |
|---|---|
| Casa de labranza / de la playa | Cocina (alacena, nevera, cajones), salón-baño (aparador, mueble del baño), dormitorio (ropero, mesilla) |
| Tienda de carretera | Sala (2 estanterías de tienda, caja registradora) y almacén (cajas, bidón) |
| Tienda de la gasolinera | Máquina de bebidas, estantería de tienda, caja registradora |
| Pueblo abandonado | Cocina, dormitorio, baño y garaje (banco, bidón, cajas); una casa en ruinas |

Lo que dejas en un mueble se queda un día (reloj real); después se vuelve a llenar.
