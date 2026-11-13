extends Node
## Capturas para revisar la interfaz sin móvil (no se exporta en el APK):
##   xvfb-run godot --rendering-driver opengl3 res://tools/screens.tscn -- <carpeta>

var out := "/tmp/screens"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GS.save_path = "user://screens_save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	get_window().size = Vector2i(1280, 720)
	GS.new_game()
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	await _wait(10)
	var base: Node3D = world.base
	var p: Node3D = world.player
	GS.slots.resize(60)
	for id in ["madera", "piedra", "tablon", "bloque_piedra", "fibra", "tela"]:
		for k in 6: GS.add_item(id, 50)
	GS.add_item("carne_cruda", 3)
	GS.add_item("hacha_piedra", 1)
	var pp := Vector3(-30, 0, -30)
	for x in range(0, 4):
		for z in range(0, 3):
			base.place("cimiento", Vector2i(x, z), 0, 0, pp)
	for x in range(0, 4):
		base.place("pared", Vector2i(x, 0), 0, 0, pp)
		base.place("pared", Vector2i(x, 2), 2, 0, pp)
	base.place("pared", Vector2i(0, 0), 3, 0, pp)
	base.place("pared", Vector2i(0, 1), 3, 0, pp)
	base.place("puerta", Vector2i(0, 2), 3, 0, pp)
	base.place("pared", Vector2i(3, 0), 1, 0, pp)
	base.place("pared", Vector2i(3, 2), 1, 0, pp)
	var w: Node3D = base.edges.values()[1]
	base.upgrade(w)
	base.place("banco_trabajo", Vector2i(1, 0), 0, 0, pp)
	base.place("cofre", Vector2i(2, 0), 0, 0, pp)
	var fire: Node3D = base.place("hoguera", Vector2i(-2, 3), 0, 0, pp)
	var carp: Node3D = base.place("carpinteria", Vector2i(-3, 0), 0, 1, pp)
	base.place("horno", Vector2i(-3, 2), 0, 0, pp)
	carp.start("tablon")
	p.global_position = Vector3(-1.5, 0, 6.5)
	p._face(Vector3(1, 0, 0))
	world._on_build_selected("place", "pared")
	await _wait(30)
	await _shot("1_refugio_construir")
	world.exit_build()
	world.hud.open_station(carp)
	await _wait(10)
	await _shot("2_estacion")
	world.hud.close_panels()
	world.hud.open_station(base.objects["2,0"])
	await _wait(10)
	await _shot("3_cofre")
	world.hud.close_panels()
	world.hud._toggle(world.hud._build_panel)
	await _wait(10)
	await _shot("4_menu_construir")
	world.hud.close_panels()
	# Animales
	p.global_position = Vector3(25, 0, 25)
	var kinds := {}
	var i := 0
	for c in get_tree().get_nodes_in_group("creature"):
		if not kinds.has(c.kind):
			kinds[c.kind] = true
			c.process_mode = Node.PROCESS_MODE_DISABLED
			c.global_position = Vector3(22 + i * 2.2, 0, 23)
			i += 1
	await _wait(30)
	await _shot("5_criaturas")
	world.hud._toggle(world.hud._map_panel)
	world.hud._select_map("cantera")
	await _wait(10)
	await _shot("6_mapa")
	world.hud.close_panels()
	for zone in ["bosque", "cantera"]:
		for c in get_tree().get_nodes_in_group("creature"):
			c.global_position = Vector3(500, 0, 500)
			c.home = c.global_position
		GS.food = 100.0
		GS.water = 100.0
		world.travel_to(zone)
		world.queue_free()
		await _wait(3)
		world = load("res://scenes/main.tscn").instantiate()
		add_child(world)
		await _wait(5)
		var pf: Array = DB.maps[zone]["prefabs"][0]["pos"]
		world.player.global_position = Vector3(float(pf[0]) + 4.0, 0, float(pf[1]) + 6.0)
		var n := 0
		for c in get_tree().get_nodes_in_group("creature"):
			if n < 4:
				c.process_mode = Node.PROCESS_MODE_DISABLED
				c.global_position = world.player.global_position + Vector3(-4 + n * 2.2, 0, 3)
			n += 1
		await _wait(30)
		await _shot("7_" + zone)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	get_tree().quit()


func _wait(n: int) -> void:
	for k in n:
		await get_tree().process_frame


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name_])
	print("captura ", name_)
