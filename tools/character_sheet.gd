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
	key.rotation_degrees = Vector3(-38, 128, 0)
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
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "protos":
		await _protos()
	elif OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "props":
		await _props()
	elif OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "inv":
		await _inventory()
	elif OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "clips":
		await _clips(OS.get_cmdline_user_args().slice(2))
	elif OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "pickup":
		await _pickup()
	elif OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "chop":
		await _chop()
	elif OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "ref":
		await _ref()
	elif OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "heads":
		await _all(true)
	elif OS.get_cmdline_user_args().size() > 1:
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


## Infectado en su postura (usa los mismos modelos que el juego).
func _zombie(kind: String, pos: Vector3, rot_y := 0.3, phase := 0.9, attack := 0.0, special := 0.0) -> CharacterModel:
	var k: String = {"a": "infectado", "b": "acorazado", "c": "corredora"}.get(kind, kind)
	var c := Infected.build(k)
	c.position = pos
	c.rotation.y = rot_y
	stage.add_child(c)
	await get_tree().process_frame
	Infected.pose(c, phase, 0.5, attack, special)
	return c


## Prototipos nuevos de infectados (aún no están en el juego).
func _protos() -> void:
	var ground := func():
		var g := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 9.0
		pm.bottom_radius = 9.0
		pm.height = 0.02
		g.mesh = pm
		g.material_override = CharacterModel.mat(Color("6f9a56"))
		g.position.y = -0.01
		stage.add_child(g)
	var rows := [["gritona", "acechador", "purulento"], ["blindado", "coloso"]]
	for r in 2:
		_clear()
		ground.call()
		for k in rows[r].size():
			var kind: String = rows[r][k]
			var x: float = (1.9 - k * 1.9) if r == 0 else (1.6 - k * 2.6)
			await _zombie(kind, Vector3(x, 0, 0), -0.35 if kind != "acechador" else -0.9, 0.9, 0.0, 1.0 if kind == "gritona" else 0.0)
		if r == 1:   # el superviviente junto al coloso, para la escala
			_char({"sex": "m", "hair": 4}, {}, {"torso": "camiseta", "piernas": "pantalon_cargo", "pies": "botas"}, Vector3(-2.6, 0, 0.3), 0.3)
		await _shot("proto_%d" % r, Vector2i(1400, 900), Vector3(-0.2 if r == 1 else 0.0, 1.6 if r == 1 else 1.2, -8.2 if r == 1 else -6.6), Vector3(-0.2 if r == 1 else 0.0, 1.35 if r == 1 else 0.9, 0), 30)
	# Detalle de cerca
	for kind in ["gritona", "acechador", "purulento", "blindado"]:
		_clear()
		await _zombie(kind, Vector3.ZERO, -0.35 if kind != "acechador" else -0.9, 0.9, 0.0, 1.0 if kind == "gritona" else 0.0)
		await _shot("det_" + kind, Vector2i(700, 900), Vector3(0, 1.1, -3.0), Vector3(0, 0.95 if kind != "acechador" else 0.6, 0), 30)


## Propuestas de modelos: pinos, rocas e infectados (A, B, C).
func _props() -> void:
	var ground := func():
		var g := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 9.0
		pm.bottom_radius = 9.0
		pm.height = 0.02
		g.mesh = pm
		g.material_override = CharacterModel.mat(Color("6f9a56"))
		g.position.y = -0.01
		stage.add_child(g)
	# Pinos (con el superviviente para la escala)
	_clear()
	ground.call()
	var makers := [Nature.pine_a, Nature.pine_b, Nature.pine_c]
	for k in 3:
		for v in 2:
			var t: Node3D = makers[k].call(k * 10 + v + 1)
			t.position = Vector3(4.2 - k * 4.2 - v * 1.7, 0, v * 1.6)
			t.scale = Vector3.ONE * (1.0 if v == 0 else 0.8)
			stage.add_child(t)
	_char({"sex": "m", "hair": 4}, {}, {"torso": "camiseta", "piernas": "pantalon_cargo", "pies": "botas"}, Vector3(6.0, 0, -0.6), 0.4)
	await _shot("prop_pinos", Vector2i(1400, 760), Vector3(0.4, 4.2, -12.5), Vector3(0.4, 1.7, 0), 32)
	# Rocas
	_clear()
	ground.call()
	var rocks := [Nature.rock_a, Nature.rock_b, Nature.rock_c]
	for k in 3:
		for v in 2:
			var r: Node3D = rocks[k].call(k * 10 + v + 1)
			r.position = Vector3(3.6 - k * 3.6 - v * 1.5, 0, v * 1.5 - 0.2)
			r.scale = Vector3.ONE * (1.0 if v == 0 else 0.7)
			r.rotation.y = v * 1.7
			stage.add_child(r)
	_char({"sex": "m", "hair": 4}, {}, {"torso": "camiseta", "piernas": "pantalon_cargo", "pies": "botas"}, Vector3(5.3, 0, -0.3), 0.4)
	await _shot("prop_rocas", Vector2i(1400, 620), Vector3(0.3, 3.0, -9.0), Vector3(0.3, 0.6, 0), 34)
	# Infectados
	_clear()
	ground.call()
	await _zombie("a", Vector3(1.7, 0, 0), -0.35)
	await _zombie("b", Vector3(0.1, 0, 0), 0.2)
	await _zombie("c", Vector3(-1.5, 0, 0), 0.45)
	await _shot("prop_infectados", Vector2i(1400, 900), Vector3(0.1, 1.3, -5.6), Vector3(0.1, 0.95, 0), 30)
	_clear()
	ground.call()
	await _zombie("a", Vector3(1.7, 0, 0), PI / 2.0)
	await _zombie("b", Vector3(0.1, 0, 0), PI / 2.0)
	await _zombie("c", Vector3(-1.5, 0, 0), PI / 2.0)
	await _shot("prop_infectados_lado", Vector2i(1400, 900), Vector3(0.1, 1.3, -5.6), Vector3(0.1, 0.95, 0), 30)


## Superviviente de frente para la pantalla de mochila.
func _inventory() -> void:
	var M := {"sex": "m", "skin": 1, "hair": 4, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 4}
	var F := {"sex": "f", "skin": 2, "hair": 1, "hair_color": 0, "eyes": 1, "eye_color": 2, "nose": 0, "mouth": 2}
	var sets := [
		["inv_m_ropa", M, {"fuerza": 0.35}, {"cabeza": "gorra", "torso": "chaqueta_piel", "piernas": "pantalon_cargo", "pies": "botas", "manos": "guantes", "espalda": "mochila"}, "hacha_hierro"],
		["inv_m_basico", M, {}, {"torso": "camiseta", "piernas": "pantalon_tela", "pies": "zapatillas"}, "hacha_piedra"],
		["inv_f_ropa", F, {"fuerza": 0.2}, {"cabeza": "casco_obra", "torso": "chaleco", "piernas": "pantalon_cargo", "pies": "botas", "espalda": "mochila"}, "machete"],
		["inv_m_interior", M, {}, {}, ""],
	]
	for st in sets:
		_clear()
		var c := _char(st[1], st[2], st[3], Vector3.ZERO, 0.18)
		if st[4] != "" and false:
			var t := Builder.tool_mesh(st[4])
			t.rotation_degrees.x = -80.0
			c.hand.add_child(t)
		await _shot(st[0], Vector2i(520, 1000), Vector3(0.0, 1.0, -4.7), Vector3(0, 0.92, 0), 26)
	# Agachado, de lado y de frente
	_clear()
	var cr := _char(M, {}, {"torso": "camiseta", "piernas": "pantalon_cargo", "pies": "botas", "espalda": "mochila"}, Vector3.ZERO, 0.0)
	cr.animate_walk(0.0, 0.0)
	cr.animate_crouch(1.0)
	await _shot("agachado_lado", Vector2i(700, 800), Vector3(-4.2, 0.9, 0.0), Vector3(0, 0.7, 0), 26)
	await _shot("agachado_frente", Vector2i(700, 800), Vector3(1.5, 1.4, -3.8), Vector3(0, 0.7, 0), 26)


## Hoja de un clip: 6 instantes de cada uno, vista de lado en 3/4.
func _clips(names: Array) -> void:
	var M := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1}
	_clear()
	var c := _char(M, {}, {}, Vector3.ZERO, 0.9)
	var tool := Builder.tool_mesh("hacha")
	tool.rotation_degrees.x = -80.0
	c.hand.add_child(tool)
	for nm in names:
		var ln := CharacterModel.clip_length(nm)
		for k in 6:
			c.pose(nm, ln * k / 5.0, 1.0, [], false)
			await _shot("clip_%s_%d" % [nm, k], Vector2i(300, 500), Vector3(-3.6, 1.1, -1.4), Vector3(0, 0.85, 0), 30)


## Picar y talar (animate_chop) con su herramienta, de lado y de frente.
func _chop() -> void:
	var M := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1}
	for kind in ["pickaxe", "axe"]:
		_clear()
		await get_tree().process_frame
		var c := _char(M, {}, {}, Vector3.ZERO, 0.0)
		var tool := Builder.tool_mesh("pico_piedra" if kind == "pickaxe" else "hacha_piedra")
		tool.rotation_degrees.x = -80.0
		c.hand.add_child(tool)
		for k in 5:
			var t: float = [0.0, 0.3, 0.45, 0.6, 0.75][k]
			c.animate_walk(0.0, 0.0)
			c.animate_idle(0.0, 1.0)
			c.animate_chop(t, kind)
			CharacterModel.grip_tool(tool, CharacterModel.chop_grip(t))
			c.rotation.y = PI / 2.0
			await _shot("chop_%s_%d_lado" % [kind, k], Vector2i(300, 450), Vector3(0.0, 1.1, -4.6), Vector3(0, 0.95, 0), 30)
			c.rotation.y = 0.5
			await _shot("chop_%s_%d_frente" % [kind, k], Vector2i(300, 450), Vector3(0.0, 1.1, -4.6), Vector3(0, 0.95, 0), 30)


## Recoger del suelo y de un arbusto (animate_pickup).
func _pickup() -> void:
	var M := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1}
	_clear()
	await get_tree().process_frame
	var c := _char(M, {}, {}, Vector3.ZERO, 0.0)
	for kind in ["ground", "waist"]:
		for k in 5:
			var t: float = [0.0, 0.3, 0.5, 0.7, 0.9][k]
			c.animate_walk(0.0, 0.0)
			c.animate_idle(0.0, 1.0)
			c.animate_pickup(t, kind)
			c.rotation.y = PI / 2.0
			await _shot("pick_%s_%d_lado" % [kind, k], Vector2i(300, 450), Vector3(0.0, 1.0, -4.6), Vector3(0, 0.8, 0), 30)
			c.rotation.y = 0.5
			await _shot("pick_%s_%d_frente" % [kind, k], Vector2i(300, 450), Vector3(0.0, 1.0, -4.6), Vector3(0, 0.8, 0), 30)


## Superviviente básico (como el diseño del inventario): cuerpo, cara, lado y poses.
func _ref() -> void:
	var M := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 1}
	_clear()
	var c := _char(M, {}, {}, Vector3.ZERO, 0.0)
	# vistas ortogonales a la escala del diseño (docs/diseno_personaje.jpg: ~0,003 m por píxel)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.95
	await _shot("orto_frente", Vector2i(500, 650), Vector3(0, 0.9, -5.0), Vector3(0, 0.9, 0))
	c.rotation.y = PI / 2.0
	await _shot("orto_lado", Vector2i(500, 650), Vector3(0, 0.9, -5.0), Vector3(0, 0.9, 0))
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	c.rotation.y = 0.32
	await _shot("ref_cuerpo", Vector2i(500, 900), Vector3(0.0, 1.05, -4.6), Vector3(0, 0.9, 0), 26)
	await _shot("ref_cara", Vector2i(400, 400), Vector3(0.0, 1.72, -1.1), Vector3(0, 1.63, 0), 24)
	var F := {"sex": "f", "skin": 2, "hair": 1, "hair_color": 0, "eyes": 1, "eye_color": 2, "nose": 0, "mouth": 2}
	var f := _char(F, {}, {"torso": "camiseta", "piernas": "pantalon_cargo", "pies": "botas"}, Vector3(-0.9, 0, 0), 0.32)
	var m2 := _char(M, {}, {"torso": "chaqueta_piel", "piernas": "pantalon_cargo", "pies": "botas", "espalda": "mochila"}, Vector3(0.9, 0, 0), 0.32)
	await _shot("ref_grupo", Vector2i(900, 900), Vector3(0.0, 1.05, -5.6), Vector3(0, 0.9, 0), 30)
	f.queue_free()
	m2.queue_free()
	c.rotation.y = PI / 2.0
	await _shot("ref_lado", Vector2i(500, 900), Vector3(0.0, 1.05, -4.6), Vector3(0, 0.9, 0), 26)
	c.rotation.y = 0.0
	for k in 4:
		c.animate_walk(k * PI / 2.0 + 0.4, 1.0, 1.0 if k >= 2 else 0.0)
		await _shot("ref_paso_%d" % k, Vector2i(400, 700), Vector3(-4.2, 1.1, -0.6), Vector3(0, 0.9, 0), 28)
	for k in 4:
		c.animate_walk(0.0, 0.0)
		c.animate_swing([0.2, 0.45, 0.6, 0.85][k])
		await _shot("ref_golpe_%d" % k, Vector2i(400, 700), Vector3(-4.2, 1.1, -0.6), Vector3(0, 0.9, 0), 28)


func _all(only_heads := false) -> void:
	var M := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 1}
	var F := {"sex": "f", "skin": 2, "hair": 2, "hair_color": 0, "eyes": 1, "eye_color": 2, "nose": 4, "mouth": 2}
	var body_eye := Vector3(1.6, 1.25, -4.2)
	var body_t := Vector3(0, 0.88, 0)

	# 1. Personaje principal (cuerpo entero, tres cuartos)
	for pair in ([] if only_heads else [["hero_m", M], ["hero_f", F]]):
		_clear()
		_char(pair[1])
		await _shot(pair[0], Vector2i(600, 1000), body_eye, body_t, 28)

	# 2. Cabezas para las opciones (5 de cada)
	var head_eye := Vector3(0.18, 1.76, -0.95)
	var head_t := Vector3(0, 1.67, 0)
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
			var ty := 1.698 if feat == "eyes" or feat == "eye_color" else (1.675 if feat == "nose" else 1.63)
			var side_x := 0.0 if feat == "eyes" or feat == "eye_color" else 0.2
			await _shot("%s_%d" % [feat, i], Vector2i(260, 260), Vector3(side_x, ty + 0.02, -0.42), Vector3(0, ty, 0), 24)

	if only_heads:
		return
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
	await _shot("quick3", Vector2i(400, 400), Vector3(0.25, 1.72, -0.8), Vector3(0, 1.67, 0), 28)
