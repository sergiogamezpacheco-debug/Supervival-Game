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
  El usuario quiere los iconos IGUALES a sus diseños: recortarlos, no redibujarlos. Los objetos sin lámina se
  modelan en 3D con el mismo estilo (`tools/item_render.tscn` + `recortar.py --contorno`), nunca dibujos planos.
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
- Ajustes: `scripts/ui/settings_screen.gd` (diseño `docs/diseno_ajustes.jpg`); valores en `SFX.settings`
  (`SFX.DEFAULTS`), gráficos con `apply_graphics(world)`. Los cambios se aplican al momento pero solo se guardan con
  GUARDAR (`save()`). Zoom de cámara: `world.zoom()`/`set_zoom()` (ajuste `zoom`, pellizco con dos dedos).
  Redes, soporte y textos legales en `data/info.json`.
- Estaciones: `scripts/ui/station_screen.gd` (diseños `docs/diseno_est_*.jpg`): pestañas por categoría
  (`"cat"` en la receta o según el tipo), cantidad (`station.start(id, n)`), obras por fases, generador,
  recolector y reparar. Posiciones fijas: no usar HFlowContainer (sospechoso de colgar el móvil).
  Iconos de tarjeta y vistas grandes de los diseños de estaciones: `assets/icons/recetas/` y
  `assets/icons/preview/` (`tools/iconos/recetas.py`). Iconos de cabecera en `assets/icons/estaciones/` (recortes `tools/iconos/estaciones.py` o render
  `tools/station_icons.tscn`).
- Personaje (`character_model.gd`): piezas por articulación que `merge_parts()` convierte en UNA malla con
  `Skeleton3D` (piel continua); las animaciones mueven los Node3D de `j` y `_sync_pose()` los copia al esqueleto.
  Signos (frente = -Z): muslo/brazo `+x` = hacia delante, rodilla siempre `<= 0`, codo siempre `>= 0`,
  tronco `-x` = inclinarse hacia delante, cabeza `+x` = mirar arriba, pie `+x` = punta arriba.
  Capturas de revisión: `tools/character_sheet.tscn -- <dir> ref` (y `clips <nombre...>` para ver animaciones).
  Medidas del hombre sacadas de `docs/diseno_personaje.jpg` (frente/perfil); su piel, pelo y bóxer llevan la
  textura `assets/characters/superviviente.png` (`tools/iconos/personaje.py`: sombras y cara del dibujo como
  factor sobre el color elegido). Los infectados no la usan (`design = false`).
- Animaciones: captura de la Universal Animation Library (Quaternius, CC0, `third_party/ual/`) pasada a nuestras
  articulaciones con `godot --headless -s res://tools/bake_anims.gd` -> `assets/characters/animaciones.res`
  (46 clips). `CharacterModel.pose(clip, t, peso, solo_estas)`; andar/correr/agacharse/golpe/reposo las mezclan.
- Fabricación: `docs/fabricacion.md` (tablas generadas de `data/recipes.json` con `python3 tools/fabricacion.py`). A mano solo lo básico (≤6 recetas, hay
  test); lo demás en bancos. Pantalla `scripts/ui/craft_screen.gd` (hereda estilos de `station_screen.gd`).
- Hoja de ruta y estado: `README.md`.
- Fuego y energía de estaciones: `"burns": true` (cocina, destilería) = fuego propio en `station.fuel` (`DB.bal("stove_fuel")`);
  `"power": true` = gasta el del generador. Consumibles con `"empty"` devuelven el envase; `"throw": true` (molotov)
  se lanza con `world.throw_at()` (`scripts/world/fire.gd`); `type: trap` se coloca con `world.place_trap(i)` (`trap.gd`).
- Movimiento: `physics/common/physics_interpolation` activada; el mundo va con interpolación OFF y el jugador,
  criaturas y rocas lanzadas ON. La cámara y el minimapa siguen `player.get_global_transform_interpolated()`.
  Tras teletransportar al jugador: `reset_physics_interpolation()`.
- Caducidad: `"spoil"` (segundos) en la comida -> `"rot"` (unix) en cada montón; `GS.spoil(array)` la pudre (mochila en
  `GS.tick`, cofres en `world`). Recursos con `"hand_ok": false` piden su herramienta (`resource_node.missing_tool()`).
- Listas con dedo: `station_screen._input` desplaza `_scroll_box()` arrastrando (los ScrollContainer van con
  `MOUSE_FILTER_IGNORE`; los botones miran `dragged` para no contar el arrastre como toque).
- Con cualquier ventana abierta (`hud.any_panel_open()`) se ocultan joystick y botones y no hay acción; Atrás cierra.
- Mapa y caminos (`docs/mapa_y_caminos.md`): mapa en papel por código `tools/mapa/mapa.py` (piezas I-III cosidas);
  tramos entre zonas en `data/routes.json` construidos por `RouteBuilder.build(root, tramo, semilla_visita)`
  (pasillo con fronteras naturales + paredes invisibles, decorado repetido en MultiMesh, puntos de cambio por visita).
  Fotos: `tools/route_shots.tscn -- /tmp/caminos` y láminas con `tools/mapa/laminas_caminos.py`.
- Viaje: trozos de mapa (`GS.map_pieces`, objetos `type: map_piece` que no entran en la mochila) desbloquean zonas
  (`"piece"` en `world_map.json`/`maps.json`). Viaje rápido gasta `GS.travel_energy` (`DB.travel_energy_cost`);
  "Ir andando" pone `GS.current_map` = id del tramo y `GS.route_from`. El HUD recorta el mapa con `MAP_VIEWS`
  (mismos rectángulos que `VISTAS` en `mapa.py`). Capturas de la fase 1: `tools/fase1_shots.tscn -- /tmp/fase1`.
- Picar y talar: `CharacterModel.animate_chop(t, "pickaxe"|"axe")` (claves `CHOP_KEYS`, la librería no trae ese gesto) y
  `grip_tool(herramienta, peso)` para cogerla por el mango; revisar con `tools/character_sheet.tscn -- <dir> chop`.
  Sin la herramienta no se saca a la mano ni hay gesto: solo el aviso. Recoger a mano: `animate_pickup(t, "ground"|"waist")`
  (`"pick": "waist"` en el recurso para cogerlo a la altura de la cintura, como el arbusto); `character_sheet ... pickup`.
- Registro: `GS.trace("...")` apunta en `user://logs/godot.log` (file logging + flush activados); el usuario lo ve en
  Ajustes > REGISTRO DE ERRORES (partida actual y anterior) y nos manda captura. Los cambios de zona pasan por
  `world._change_zone()` (pantalla «Cargando…» y apunte en el registro). Vigilante de cuelgues: `GS.mark(GS.STEP_*)` en cada
  parte del bucle; un paso de ≥0,7 s apunta «tirón de N ms en: …» y un hilo aparte apunta «CUELGUE: … parado en: …» si no
  avanza un fotograma en 4 s (y «vuelve a moverse tras N s»). Mientras carga una zona `GS.loading` (lo cierra `GS.loaded()`).
- Casas de los caminos (`RouteBuilder.house(..., layout)`, `LAYOUTS`): se entra por la puerta; dentro, `world._update_houses()`
  esconde "Tejado" y "Alto" (van aparte del `Builder.merge`, meta `no_merge`). Muebles = Marker3D con meta "tipo"
  (contenedores de `containers.json`); su contenido se recuerda en `GS.route_loot` un día (`house_refill_seconds`).
- Zonas de la parte II (`maps.json`): `"settlement"` (La Atalaya: empalizada, torres con `Npc` arquero, casas sin saqueo;
  `scripts/world/settlement.gd`), `"camp"` (Base Centinela: valla con tramo caído; `Settlement.build_camp`), `"houses"`
  ([distribución, x, z, giro, pared, tejado] con muebles registrables), `"stations"` (puestos de comerciante: estaciones con
  `"trader": true`, recetas con `time 0`, `"trust"` y `"trust_gain"`; `GS.trust`), `"water"` (círculos de agua honda/poco
  honda e islotes; `world.water_depth`, `GS.can_dive()` = ropa con `"dive"`). Fotos: `tools/zone_shots.tscn -- <dir> <mapa> [x,z…]`.
- Borde de zona: `world._check_zone_edge` abre el mapa (`hud.open_map`) y aparta al jugador un paso.
- Almacenaje: cofre en el menú de construir; el resto (baúles, estanterías, armarios) se fabrica en la estación
  `almacenamiento` (diseños `docs/diseno_est_almacen_*.jpg`) como objeto `type: storage` con `"place"`, y se coloca desde
  la mochila (`world.place_furniture`, modo construir pagando el mueble). En `stations.json` llevan `"item"` (no salen en
  el menú; al desmontar vuelve el mueble entero) y `"storage"` (huecos). `station.is_chest()` = tiene `storage`.
- Guardado: cada cambio en la mochila se guarda en <3 s (`world._dirty`) y también al perder el foco (Android cierra
  la app sin dar tiempo a PAUSED).
- Reaparición lenta: `"respawn": [mín, máx]` (segundos reales) en un grupo de criaturas de `maps.json`; se guarda en
  `GS.dead_until[mapa]` y sigue contando con el juego cerrado. El refugio la usa para que casi no haya infectados;
  su noche lleva `"chance"` (probabilidad de que lleguen).
