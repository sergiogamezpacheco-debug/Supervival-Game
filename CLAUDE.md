# Supervival — notas para Claude

- Motor: Godot 4.4.1, GDScript, renderer GL Compatibility. Todo se construye por código
  (no editar escenas a mano salvo `scenes/main.tscn`, que solo carga `world.gd`).
- El usuario trabaja **solo desde Android**: no tiene editor. Cada cambio debe poder probarse
  con el APK que genera `.github/workflows/android.yml` y se publica en Releases.
- Contenido en `data/*.json`. Antes de añadir código para un objeto/receta, mira si basta con datos.
- Idioma del juego y del código comentado: español. Nombres, arte y textos propios: no copiar
  nombres, iconos ni UI de Last Day on Earth (solo mecánicas).
- Antes de hacer push, ejecutar en local:
  ```
  godot --headless --import
  godot --headless res://tests/test_runner.tscn   # debe salir con código 0
  ```
  y añadir tests en `tests/test_runner.gd` para cada mecánica nueva.
- Los toques en tests se envían en coordenadas de ventana:
  `get_tree().root.get_final_transform() * posicion_en_canvas`.
- Capturas para revisar la interfaz (la máquina tiene Xvfb + llvmpipe, ~5 fps):
  `xvfb-run -s "-screen 0 1280x720x24" godot --audio-driver Dummy --rendering-driver opengl3 res://tools/screens.tscn -- /tmp/screens`
- Ropa: objetos `type: wear` en `data/items.json` (`slot`, `model` = clave de `CharacterModel.CLOTH`).
  `GS.testing = true` en tests y herramientas para no abrir la pantalla de creación de personaje.
- Hora y lluvia salen del reloj real (`GS.hour()`, `GS.raining()`); tests y capturas fijan
  `GS.forced_hour = 12.0` y `GS.forced_rain = 0` para no depender de la hora a la que se ejecutan.
- Iconos: `assets/icons/items/<id>.png` recortados de los diseños del usuario (`docs/diseno_*.jpg`) con
  `tools/iconos/recortar.py`; si no hay PNG, `<id>.svg` de `tools/iconos/generar.py`. `DB.item_icon(id)` prefiere PNG.
  El usuario quiere los iconos IGUALES a sus diseños: recortarlos, no redibujarlos.
- En tests, tras un fotograma lento (modelos 3D, miniaturas) esperar `process_frame` y no solo
  `physics_frame` antes de comprobar un toque: si no, el evento aún no se ha procesado.
- Herramientas (`type: tool`) no se equipan: se usan desde el inventario (`GS.best_tool`); en la
  mano solo van armas. Iconos de interfaz en `assets/icons/ui/` (`DB.ui_icon`).
- Sonido: autoload `SFX` (`SFX.play("golpe")`, ajustes en `SFX.settings`); WAV en `assets/audio/`.
  En tests, `world._process` copia el joystick a `player.move_input`: usar `process_frame` o fijarlo a mano.
- Mapas en `data/maps.json`; criaturas genéricas en `scripts/world/creature.gd` (aggressive/neutral/passive).
- Construcción: `scripts/world/base.gd` (cuadrícula 2 m; claves "i,j" casillas, "i,j,d" bordes).
- Niveles: `data/levels.json` + `"unlock"` en recetas, estaciones, estructuras y mapas (`docs/niveles.md`).
  `GS.add_xp(n)`; con `GS.testing` se empieza en el nivel 100 (los tests de bloqueos fijan `GS.level`).
- Peso: `"weight"` en cada objeto (un test lo exige); `GS.carry_weight()`, `GS.carry_capacity()`, `GS.load_ratio()`.
- Minimapa: `scripts/ui/minimap.gd` (cámara cenital propia; criaturas y jugador en la capa 2 para que
  salgan como iconos de `assets/icons/minimap/`, recortados con `tools/iconos/minimapa.py`).
- Hoja de ruta y estado: `README.md`.
