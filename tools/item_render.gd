extends Node
## Iconos de objetos sin lámina propia: se modelan en 3D imitando los diseños del usuario
## (mismo low poly y luz) y se renderizan con fondo transparente.
##   xvfb-run ... res://tools/item_render.tscn -- <dir>
## Después: python3 tools/iconos/recortar.py --contorno <dir>/*.png  (añade el contorno)

const M := preload("res://scripts/world/station_models.gd")

var vp: SubViewport
var cam: Camera3D
var stage: Node3D


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	vp = SubViewport.new()
	vp.size = Vector2i(384, 384)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.66, 0.75)
	env.environment.ambient_light_energy = 0.75
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.95, 0.88)
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	stage = Node3D.new()
	vp.add_child(stage)
	for id in ["botiquin", "antidoto"]:
		for c in stage.get_children():
			c.queue_free()
		var size := call("_" + id) as float
		cam.size = size
		cam.position = Vector3(1.6, 1.5, -1.6) * 3.0
		cam.look_at(Vector3(0, 0.0, 0), Vector3.UP)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		for i in 4:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [out, id])
		print("icono ", id)
	get_tree().quit()


func _botiquin() -> float:
	var white := Color("f3f3ef")
	var red := Color("c8402e")
	M._p(stage, M._box(Vector3(1.1, 0.55, 0.8)), white, Vector3(0, -0.1, 0))
	M._p(stage, M._box(Vector3(1.14, 0.16, 0.84)), Color("e6e7e2"), Vector3(0, 0.25, 0))
	M._p(stage, M._box(Vector3(1.15, 0.12, 0.85)), red, Vector3(0, -0.12, 0))
	# cruz roja en la tapa
	M._p(stage, M._box(Vector3(0.42, 0.02, 0.13)), red, Vector3(0, 0.34, 0))
	M._p(stage, M._box(Vector3(0.13, 0.02, 0.42)), red, Vector3(0, 0.34, 0))
	# asa
	M._p(stage, M._box(Vector3(0.36, 0.06, 0.06)), Color("9aa0a4"), Vector3(0, 0.36, 0.3))
	return 1.9


func _antidoto() -> float:
	var glass := Color("6f8d82")
	M._p(stage, M._cyl(0.3, 0.3, 0.8, 8), glass, Vector3(0, -0.2, 0))
	M._p(stage, M._cyl(0.14, 0.3, 0.22, 8), glass.lightened(0.08), Vector3(0, 0.31, 0))
	M._p(stage, M._cyl(0.12, 0.12, 0.14, 8), glass, Vector3(0, 0.48, 0))
	M._p(stage, M._cyl(0.15, 0.15, 0.16, 8), Color("efeee8"), Vector3(0, 0.62, 0))
	M._p(stage, M._cyl(0.305, 0.305, 0.36, 8), Color("ecdcd6"), Vector3(0, -0.2, 0))
	M._p(stage, M._box(Vector3(0.16, 0.16, 0.02)), Color("c8402e"), Vector3(0.12, -0.2, -0.29), Vector3(0, -22, 0))
	M._p(stage, M._cyl(0.31, 0.31, 0.06, 8), Color("3f4a4f"), Vector3(0, -0.58, 0))
	return 1.75
