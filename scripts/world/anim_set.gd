class_name AnimSet
extends Resource
## Animaciones del superviviente ya pasadas a nuestras articulaciones (tools/bake_anims.gd).
## clips[nombre] = {"fps": 30.0, "frames": n, "rot": {articulación: PackedFloat32Array (x,y,z,w por fotograma)},
##                  "hy": PackedFloat32Array (subida/bajada de la cadera por fotograma)}

@export var clips: Dictionary = {}
