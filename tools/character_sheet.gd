extends Node
## Renders del superviviente para las propuestas de diseño (fondo transparente).
##   xvfb-run godot --rendering-driver opengl3 res://tools/character_sheet.tscn -- /carpeta

var out := "/tmp/chars"
var vp: SubViewport
var stage: Node3D
var cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9cfd6")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 150, 0)
	key.light_energy = 1.45
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -60, 0)
	fill.light_energy = 0.35
	vp.add_child(fill)
	cam = Camera3D.new()
	vp.add_child(cam)
	stage = Node3D.new()
	vp.add_child(stage)
	if OS.get_cmdline_user_args().size() > 1:
		await _quick()
	else:
		await _all()
	get_tree().quit()


func _clear() -> void:
	for c in stage.get_children():
		c.queue_free()


func _char(look: Dictionary, phys := {}, outfit := {}, pos := Vector3.ZERO, rot_y := 0.0, explode := 0.0) -> CharacterModel:
	var c := CharacterModel.new(look, phys, outfit)
	c.explode = explode
	c.position = pos
	c.rotation.y = rot_y
	stage.add_child(c)
	return c


func _shot(file: String, size: Vector2i, eye: Vector3, target: Vector3, fov := 30.0) -> void:
	vp.size = size
	cam.fov = fov
	cam.position = eye
	cam.look_at(target, Vector3.UP)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, file])
	print("render ", file)


func _all() -> void:
	var M := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 1}
	var F := {"sex": "f", "skin": 2, "hair": 2, "hair_color": 0, "eyes": 1, "eye_color": 2, "nose": 4, "mouth": 2}
	var body_eye := Vector3(1.6, 1.25, -4.2)
	var body_t := Vector3(0, 0.88, 0)

	# 1. Personaje principal (cuerpo entero, tres cuartos)
	for pair in [["hero_m", M], ["hero_f", F]]:
		_clear()
		_char(pair[1])
		await _shot(pair[0], Vector2i(600, 1000), body_eye, body_t, 28)

	# 2. Cabezas para las opciones (5 de cada)
	var head_eye := Vector3(0.18, 1.69, -0.95)
	var head_t := Vector3(0, 1.6, 0)
	for sex in ["m", "f"]:
		var base: Dictionary = (M if sex == "m" else F).duplicate()
		for i in 5:
			_clear()
			var l := base.duplicate()
			l["hair"] = i
			_char(l)
			await _shot("pelo_%s_%d" % [sex, i], Vector2i(260, 260), head_eye * Vector3(1, 1 if sex == "m" else 0.97, 1), head_t * Vector3(1, 1 if sex == "m" else 0.95, 1), 26)
		for i in 5:
			_clear()
			var l2 := base.duplicate()
			l2["hair_color"] = i
			_char(l2)
			await _shot("color_pelo_%s_%d" % [sex, i], Vector2i(260, 260), head_eye * Vector3(1, 1 if sex == "m" else 0.97, 1), head_t * Vector3(1, 1 if sex == "m" else 0.95, 1), 26)
		for i in 5:
			_clear()
			var l3 := base.duplicate()
			l3["skin"] = i
			_char(l3)
			await _shot("piel_%s_%d" % [sex, i], Vector2i(260, 260), head_eye * Vector3(1, 1 if sex == "m" else 0.97, 1), head_t * Vector3(1, 1 if sex == "m" else 0.95, 1), 26)
	var face_eye := Vector3(0.0, 1.64, -0.55)
	var face_t := Vector3(0, 1.6, 0)
	for feat in ["eyes", "nose", "mouth", "eye_color"]:
		for i in 5:
			_clear()
			var l4 := M.duplicate()
			l4[feat] = i
			_char(l4)
			var ty := 1.628 if feat == "eyes" or feat == "eye_color" else (1.595 if feat == "nose" else 1.55)
			await _shot("%s_%d" % [feat, i], Vector2i(260, 260), Vector3(0.0, ty + 0.02, -0.42), Vector3(0, ty, 0), 24)

	# 3. Despiece de partes
	_clear()
	_char(M, {}, {}, Vector3.ZERO, 0.35, 1.0)
	await _shot("despiece_m", Vector2i(700, 1100), Vector3(1.4, 1.35, -4.9), Vector3(0, 0.95, 0), 28)

	# 4. Ropa: llegada, primeros días, veterano
	var outfits := [
		{},
		{"torso": "camiseta", "piernas": "pantalon_tela", "pies": "zapatillas"},
		{"torso": "chaqueta_piel", "piernas": "pantalon_cargo", "pies": "botas", "cabeza": "casco_obra", "manos": "guantes", "espalda": "mochila"},
	]
	for sex in ["m", "f"]:
		for i in 3:
			_clear()
			_char(M if sex == "m" else F, {"fuerza": 0.2 * i, "resistencia": 0.2 * i}, outfits[i])
			await _shot("ropa_%s_%d" % [sex, i], Vector2i(420, 760), body_eye, body_t, 28)
	# mochila vista desde atrás
	_clear()
	_char(M, {"fuerza": 0.4, "resistencia": 0.4}, outfits[2], Vector3.ZERO, PI - 0.5)
	await _shot("ropa_m_2_espalda", Vector2i(420, 760), body_eye, body_t, 28)

	# 5. Físico: inicio, en forma, curtido
	for sex in ["m", "f"]:
		for i in 3:
			_clear()
			_char(M if sex == "m" else F, {"fuerza": [0.0, 0.5, 1.0][i], "resistencia": [0.0, 0.6, 1.0][i]})
			await _shot("fisico_%s_%d" % [sex, i], Vector2i(420, 760), Vector3(0.6, 1.2, -4.3), body_t, 28)

	# 6. Pareja para la portada
	_clear()
	_char(M, {}, {}, Vector3(-0.45, 0, 0), 0.25)
	_char(F, {}, {}, Vector3(0.45, 0, 0), -0.25)
	await _shot("pareja", Vector2i(900, 1000), Vector3(0.6, 1.3, -4.8), Vector3(0, 0.88, 0), 30)


func _quick() -> void:
	var M := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 1}
	var F := {"sex": "f", "skin": 2, "hair": 2, "hair_color": 0, "eyes": 1, "eye_color": 2, "nose": 4, "mouth": 2}
	_clear()
	_char(M, {}, {}, Vector3(-0.45, 0, 0), 0.25)
	_char(F, {}, {}, Vector3(0.45, 0, 0), -0.25)
	await _shot("quick", Vector2i(900, 1000), Vector3(0.6, 1.3, -4.8), Vector3(0, 0.88, 0), 30)
	_clear()
	_char(M, {"fuerza": 0.4, "resistencia": 0.4}, {"torso": "chaqueta_piel", "piernas": "pantalon_cargo", "pies": "botas", "cabeza": "casco_obra", "manos": "guantes", "espalda": "mochila"}, Vector3(-0.45, 0, 0), 0.25)
	_char(F, {"fuerza": 0.2}, {"torso": "camiseta", "piernas": "pantalon_tela", "pies": "zapatillas"}, Vector3(0.45, 0, 0), -0.25)
	await _shot("quick2", Vector2i(900, 1000), Vector3(0.6, 1.3, -4.8), Vector3(0, 0.88, 0), 30)
	_clear()
	_char(M)
	await _shot("quick3", Vector2i(400, 400), Vector3(0.12, 1.66, -0.75), Vector3(0, 1.6, 0), 28)
