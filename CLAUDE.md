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
- Hoja de ruta y estado: `README.md`.
