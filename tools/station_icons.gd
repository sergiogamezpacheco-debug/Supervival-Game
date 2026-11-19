extends Node
## Iconos de cabecera de las estaciones sin icono en los diseños: se renderiza su modelo 3D.
##   xvfb-run ... res://tools/station_icons.tscn -- assets/icons/estaciones
## (las que tienen recorte en tools/iconos/estaciones.py no se tocan)

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.66, 0.75)
	env.environment.ambient_light_energy = 0.8
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	for id in DB.stations:
		if FileAccess.file_exists("res://assets/icons/estaciones/%s.png" % id) and id in ["carpinteria", "horno", "mesa_costura", "banco_armas"]:
			continue
		var m := Builder.station_mesh(id, 1)
		for l in m.find_children("*", "Light3D", true, false):
			l.queue_free()
		vp.add_child(m)
		var size: Vector3 = load("res://scripts/world/station.gd").SIZES.get(id, Vector3(1.4, 1.0, 1.0))
		var h := maxf(size.y, 0.8)
		cam.size = maxf(maxf(size.x, size.z), h) * 1.45
		cam.position = Vector3(2.2, 2.0 + h * 0.5, -2.6) * 3.0
		cam.look_at(Vector3(0, h * 0.42, 0), Vector3.UP)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		for i in 4:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [out, id])
		print("icono ", id)
		m.queue_free()
		await get_tree().process_frame
	get_tree().quit()
