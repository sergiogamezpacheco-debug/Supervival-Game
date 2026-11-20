extends Node
## Capturas de la pantalla de estaciones (diseños docs/diseno_est_*.jpg).
##   xvfb-run ... res://tools/station_screen_shot.tscn -- <dir>

func _shot(path: String) -> void:
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	GS.testing = true
	GS.forced_hour = 12.0
	GS.forced_rain = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	get_window().size = Vector2i(1280, 720)
	GS.new_game()
	GS.slots.resize(40)
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	for i in 10:
		await get_tree().process_frame
	for id in ["madera", "piedra", "tablon", "cuerda", "mineral_hierro", "carbon", "lingote_hierro", "tela", "piel", "fibra", "chatarra"]:
		GS.add_item(id, 12)
	var base: Node3D = world.base
	var pp := Vector3(30, 0, 30)
	var spots := [Vector2i(-6, 2), Vector2i(-2, 2), Vector2i(2, 2), Vector2i(6, 2), Vector2i(-6, 6), Vector2i(-2, 6), Vector2i(2, 6), Vector2i(6, 6), Vector2i(-6, -2)]
	var made := {}
	for id in ["carpinteria", "horno", "banco_trabajo", "mesa_costura", "generador", "recicladora", "mesa_medica"]:
		for c in spots:
			if not made.has(id) and base.check_place(id, c, 0, pp) == "":
				for ph in DB.station_phases(id):
					for k in ph["cost"]:
						GS.add_item(k, int(ph["cost"][k]))
				var cost := DB.station_build_cost(id)
				for k in cost:
					GS.add_item(k, int(cost[k]))
				made[id] = base.place(id, c, 0, 0, pp)
				spots.erase(c)
				break
	var carp: Node3D = made["carpinteria"]
	world.hud.open_station(carp)
	await _shot(out + "/estacion_carpinteria.png")
	world.hud.open_station(made["horno"])
	await _shot(out + "/estacion_horno.png")
	GS.hand = GS.make_item("lanza", 1)
	GS.hand["dur"] = 10
	world.hud.open_station(made["banco_trabajo"])
	await _shot(out + "/estacion_banco_trabajo.png")
	var sc: Control = world.hud._station_panel
	sc.tab = "Reparar"
	sc.refresh()
	await _shot(out + "/estacion_reparar.png")
	world.hud.open_station(made["mesa_costura"])
	sc.tab = "Ropa"
	sc.refresh()
	await _shot(out + "/estacion_costura.png")
	world.hud.open_station(made["mesa_medica"])
	await _shot(out + "/estacion_mesa_medica.png")
	for i in sc.entries.size():
		if sc.entries[i].get("icon", "") == "antidoto":
			sc._select(i)
	await _shot(out + "/estacion_antidoto.png")
	world.hud.open_station(made["generador"])
	await _shot(out + "/estacion_obra.png")
	var g: Node3D = made["generador"]
	while not g.is_built():
		g.add_phase()
	g.fuel = 1800.0
	var r: Node3D = made["recicladora"]
	while not r.is_built():
		r.add_phase()
	world.hud.open_station(r)
	await _shot(out + "/estacion_recicladora.png")
	get_tree().quit()
