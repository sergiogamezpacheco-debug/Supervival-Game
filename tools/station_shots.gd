extends Node3D
## Capturas de las estructuras del refugio (comparar con docs/diseno_estructuras.jpg)
## y del panel de obra por fases.
##   xvfb-run ... res://tools/station_shots.tscn -- <dir>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	get_window().size = Vector2i(1280, 960)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2b3038")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.64, 0.72)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	ground.material_override = Builder.mat(Color("3a3f48"))
	add_child(ground)
	var ids: Array = ["carpinteria", "horno", "banco_armas", "recolector_agua", "hoguera", "secadero", "huerto", "mesa_medica", "generador", "recicladora"]
	if OS.get_cmdline_user_args().size() > 1:
		ids = OS.get_cmdline_user_args().slice(1)   # solo las que se pidan
	for i in ids.size():
		var m := Builder.station_mesh(ids[i], 1)
		var col := i % 4 if i < 8 else (i - 8) + 1
		var row := i / 4
		m.position = Vector3(col * 3.0 - 4.5 + (1.5 if i >= 8 else 0.0) - (0.0 if i < 8 else 1.5), 0, row * 3.2 - 3.2)
		add_child(m)
		var l := Label3D.new()
		l.text = DB.station_name(ids[i])
		l.font_size = 64
		l.pixel_size = 0.004
		l.position = m.position + Vector3(0, 0.05, -1.2)
		l.rotation_degrees = Vector3(-90, 180, 0)
		l.modulate = Color(0.95, 0.92, 0.85)
		add_child(l)
	var cam := Camera3D.new()
	cam.fov = 38
	add_child(cam)
	cam.position = Vector3(0, 10.5, -9.5)
	cam.look_at(Vector3(0, 0, 0.6), Vector3.UP)
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/estructuras.png")
	# de cerca, en obra (fase 1 y 2 de 3)
	for c in get_children():
		if c is Label3D or (c is Node3D and c != cam and c != sun and c != ground and not (c is WorldEnvironment)):
			c.queue_free()
	await get_tree().process_frame
	for k in 3:
		var full := Builder.station_mesh("recicladora", 1)
		var m: Node3D = full if k == 2 else StationModels.under_construction(full, k + 1, 3, Vector3(1.6, 1.8, 1.4))
		m.position = Vector3(3.0 - k * 3.0, 0, 0)
		add_child(m)
	cam.position = Vector3(0, 4.5, -7.5)
	cam.look_at(Vector3(0, 0.8, 0), Vector3.UP)
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/recicladora_fases.png")
	get_tree().quit()
