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
| Joystick (mitad izquierda) | Moverse |
| Botón redondo (abajo derecha) | Acción contextual: Talar, Picar, Recoger, Atacar, Beber, Recuperar… Mantener para repetir |
| Mochila | Inventario: usar, equipar o tirar objetos |
| Fabricar | Recetas a mano (el resto, en las estaciones) |
| Mapa | Viajar a otras zonas (cuesta comida y agua) |
| Construir | Colocar cimientos, paredes, puertas, estaciones y cofres; mejorar o desmontar |

## Hoja de ruta

- [x] **Fase 0 – Montaje:** Godot 4.4, tests automáticos y APK automático en GitHub.
- [x] **Fase 1 – Base jugable:** recolección con herramientas y durabilidad, inventario por casillas,
      fabricación, hambre/sed/vida, infectados, botín, mochila al morir, guardado automático.
- [x] **Fase 2 – Construcción y base:** cuadrícula, cimientos/paredes/puertas (madera → piedra → metal),
      mejorar y desmontar, cofres, banco de trabajo por niveles, carpintería, cantería, hoguera, horno
      y mesa de costura con fabricación por tiempo real. Animales salvajes (conejo, jabalí, lobo).
- [~] **Fase 3 – Mapa global:** ✅ viaje entre zonas con coste de comida/agua, ✅ Bosque de Pino Negro,
      ✅ Cantera de Peñas Rojas, contenedores saqueables, veneno. Pendiente: resto de zonas
      (ver [docs/zonas.md](docs/zonas.md)), sigilo y ruido, mapa definitivo.
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

## Mapas

Cada zona es una entrada de `data/maps.json` (recursos, grupos de criaturas, zona de construcción).
Nuevas zonas = nuevas entradas + los recursos/criaturas que falten en sus JSON.
