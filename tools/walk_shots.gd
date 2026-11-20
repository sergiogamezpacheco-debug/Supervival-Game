extends Node3D
## Tira de fotogramas de la animación de andar y correr (vista de perfil).
##   xvfb-run ... res://tools/walk_shots.tscn -- <dir>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	get_window().size = Vector2i(1600, 560)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("3a4048")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.78)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -60, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.2
	cam.position = Vector3(5.6, 0.85, 8)
	add_child(cam)
	cam.look_at(Vector3(5.6, 0.85, 0), Vector3.UP)
	for row in 2:
		for k in 8:
			var m := CharacterModel.new({"sex": "m"}, {}, {"torso": "camiseta", "piernas": "pantalon_tela", "pies": "zapatillas"})
			add_child(m)
			m.position = Vector3(k * 1.6, -2.3 * row, 0)
			m.rotation.y = PI / 2.0
			m.animate_walk(TAU * k / 8.0, 1.0, float(row))
	cam.size = 5.0
	cam.position = Vector3(5.6, -0.3, 8)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/animacion_paso.png")
	get_tree().quit()
