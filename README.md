# Supervival

Juego de supervivencia para Android inspirado en las mecánicas de *Last Day on Earth*,
con diseño, nombres y arte propios. Estudio: **Lost Anarchy Games**.

## Descargar el APK (desde el móvil)

Cada cambio que llega a `main` se prueba y se compila solo.
Abre **[Releases → latest](https://github.com/sergiogamezpacheco-debug/Supervival-Game/releases/latest)**,
descarga `Supervival.apk` e instálalo (Android pedirá permitir "instalar apps desconocidas").

> Las compilaciones de prueba van firmadas con una clave de pruebas (`android/testing.keystore`).
> Para Google Play se usará una clave propia y privada.

## Controles

| Control | Qué hace |
|---|---|
| Joystick (mitad izquierda) | Moverse. A fondo: **correr** (gasta aguante y hace ruido) |
| Botón de acción (icono) | Usa lo que toque: junto a un árbol o roca, el hacha o pico del inventario; si no, el arma equipada o el puño. El borde marca su estado (verde, amarillo <50 %, rojo <25 %) |
| Botón de esquivar | Salto rápido hacia donde te mueves: no recibes golpes un instante, gasta energía |
| Engranaje (arriba) | Ajustes: música, efectos, vibración, cambiar aspecto, partida nueva |
| Botón de agachar (icono) | Lento y silencioso; por la espalda y sin que te vean, el golpe hace x3 |
| Botón redondo (abajo derecha) | Acción contextual: Talar, Picar, Recoger, Atacar, Beber, Recuperar… Mantener para repetir |
| Botón de mochila (anillo = carga) | **Inventario**: el superviviente con sus 7 huecos de equipo y las casillas (8 bolsillos + 8 por nivel de mochila); toca un objeto para usarlo, equiparlo, ponértelo o tirarlo |
| Fabricar | Recetas a mano (el resto, en las estaciones) |
| Mapa | Viajar a otras zonas (cuesta comida y agua) |
| Construir | Colocar cimientos, paredes, puertas, estaciones y cofres; mejorar o desmontar |

## Hoja de ruta

Plan completo por fases (offline primero, online preparado): **[docs/hoja-de-ruta.md](docs/hoja-de-ruta.md)**.

- [x] **Fase 0 – Montaje:** Godot 4.4, tests automáticos y APK automático en GitHub.
- [x] **Fase 1 – Base jugable:** recolección con herramientas y durabilidad, inventario por casillas,
      fabricación, hambre/sed/vida, infectados, botín, mochila al morir, guardado automático.
- [x] **Fase 2 – Construcción y base:** cuadrícula, cimientos/paredes/puertas (madera → piedra → metal),
      mejorar y desmontar, cofres, banco de trabajo por niveles, carpintería, cantería, hoguera, horno
      y mesa de costura con fabricación por tiempo real. Animales salvajes (conejo, jabalí, lobo).
- [x] **Superviviente:** creación de personaje en el primer arranque, ropa con defensa y desgaste
      (mesa de costura nivel 1, 2 y 3, también en cofres), 8 bolsillos y mochilas de lona, excursión y
      táctica (16/24/32 huecos), iconos propios para todos los objetos, aguante para correr,
      fuerza y resistencia que suben jugando y gimnasio para acelerarlas.
- [x] **Mundo vivo:** día y noche de 24 minutos (reloj real; de noche aparecen infectados y se
      enciende la linterna), lluvia, sigilo y ruido, reparar en el banco y en la costura,
      barra de vida y números de daño en los enemigos.
- [x] **Cocina, destilería, química y electrónica:** fuego propio con leña/carbón/combustible, agua sucia →
      hervida/purificada, cantimplora rellenable, conservas, alcohol y combustible, medicinas, cóctel molotov
      (se lanza y deja fuego), trampa de pinchos colocable, cables, circuitos y baterías ([docs/fabricacion.md](docs/fabricacion.md)).
- [~] **Fase 3 – Mapa global:** ✅ mapa definitivo en papel que crece con los trozos (I, II, III),
      ✅ parte I: Refugio, La Arboleda (madera básica, superviviente muerto con el trozo II) y El Pedregal
      (1 de cada 10 rocas es hierro), coches abandonados con suministros, ✅ viaje rápido con energía
      (se recarga 20/h reales) o ir andando por el camino, ✅ parte II jugable: Pinar del Cuervo (troncos de pino)
      y Cantera del Tajo (mitad minerales), ✅ La Atalaya (empalizada, arqueros, mercader y armero con
      confianza), ✅ Base Centinela (campamento militar), ✅ Marismas (agua honda y traje de buzo),
      ✅ al llegar al borde de una zona se abre el mapa. Pendiente: parte III,
      recarga de energía viendo vídeos ([docs/mapa_y_caminos.md](docs/mapa_y_caminos.md)).
- [ ] **Fase 4 – Combate y equipo:** armas a distancia, munición, armaduras, más enemigos, tablas de botín.
- [ ] **Fase 5 – Contenido grande:** búnker, granja, vehículos, mascota, eventos.
- [ ] **Fase 6 – Online (Firebase):** cuentas, nube, asaltos a otras bases, clanes, chat.
- [ ] **Fase 7 – Monetización:** moneda premium, aceleradores, pase de temporada, AdMob, compras.
- [ ] **Fase 8 – Publicación** en Google Play.

## Cómo está organizado

- `data/*.json` — **todo el contenido** (objetos, recetas, recursos, equilibrio). Añadir un objeto o
  receta nueva no requiere tocar código.
- `scripts/autoload/` — `DB` (datos) y `GS` (estado del jugador y guardado).
- `scripts/world/` — mundo, jugador, recursos, infectados, bolsas, pozo, modelos provisionales.
- `scripts/ui/` — HUD, joystick y botón táctil multitoque.
- `tests/` — tests que se ejecutan antes de cada compilación.
- `tools/screens.tscn` — genera capturas de pantalla para revisar la interfaz sin móvil.
- `tools/survivor_shots.tscn` — capturas de la creación de personaje, el inventario y el gimnasio.
- `tools/night_shots.tscn` — capturas de atardecer, noche, lluvia, sigilo y reparar.
- `assets/audio/` — sonidos sintetizados con `tools/sonidos/generar.py` (numpy).
- `assets/ui/mapa_piezas_{1,2,3}.jpg` — mapa en papel según los trozos que tengas (`tools/mapa/mapa.py`).
- `assets/icons/` — iconos SVG de objetos y huecos; se generan con `tools/iconos/generar.py`.

## Mapas

Cada zona es una entrada de `data/maps.json` (recursos, grupos de criaturas, zona de construcción).
Nuevas zonas = nuevas entradas + los recursos/criaturas que falten en sus JSON.
