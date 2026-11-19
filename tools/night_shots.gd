extends Node
## Capturas de día/noche, lluvia, sigilo y reparar (no va en el APK):
##   xvfb-run godot --rendering-driver opengl3 res://tools/night_shots.tscn -- <carpeta>

var out := "/tmp/night"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GS.save_path = "user://night_save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.testing = true
	GS.forced_rain = 0
	GS.forced_hour = 12.0
	get_window().size = Vector2i(1280, 720)
	GS.new_game()
	GS.created = true
	for it in [["gorra", 0], ["chaqueta_piel", 0], ["pantalon_cargo", 0], ["botas", 0], ["mochila", 0]]:
		GS.add_item(it[0], 1)
		for i in GS.slots.size():
			if GS.slots[i] != null and GS.slots[i]["id"] == it[0]:
				GS.wear_slot(i)
				break
	GS.hand = GS.make_item("lanza")
	GS.add_item("hacha_piedra", 1)
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	await _wait(10)
	var p: Node3D = world.player
	for c in get_tree().get_nodes_in_group("creature"):
		c.process_mode = Node.PROCESS_MODE_DISABLED
		c.visible = false
	p.global_position = Vector3(2, 0, 3)
	world.camera.global_position = p.global_position + Vector3(0, 13.0, 8.5)

	if out.ends_with("_cantera"):
		GS.food = 100.0
		GS.water = 100.0
		world.travel_to("cantera")
		await _wait(10)
		p = world.player
		for c in get_tree().get_nodes_in_group("creature"):
			c.process_mode = Node.PROCESS_MODE_DISABLED
			c.visible = false
		p.global_position = Vector3(0, 0, 6)
		var k2 := 0
		for d in [["coloso", Vector3(-3.8, 0, 1.2)], ["blindado", Vector3(2.4, 0, 2.6)], ["gritona", Vector3(5.0, 0, 4.0)], ["purulento", Vector3(-4.8, 0, 6.5)], ["acechador", Vector3(3.6, 0, 7.4)]]:
			var z: Node3D = world.CreatureScript.new()
			z.setup(d[0])
			z.home = p.global_position + d[1] - Vector3(0, 0, 6)
			z.position = z.home
			world.add_child(z)
			z.process_mode = Node.PROCESS_MODE_DISABLED
			await _wait(1)
			z._face(p.global_position - z.position)
			Infected.pose(z._model, 0.9, 0.5, 0.0, 1.0 if d[0] == "gritona" else 0.0)
			k2 += 1
		world.camera.global_position = p.global_position + Vector3(0, 11.0, 7.5)
		world.camera.look_at(p.global_position + Vector3(0, 0, -1.0), Vector3.UP)
		await _wait(14)
		await _shot("cantera_infectados")
		get_tree().quit()
		return
	if out.ends_with("_bosque"):
		GS.food = 100.0
		GS.water = 100.0
		world.travel_to("bosque")
		await _wait(10)
		p = world.player
		for c in get_tree().get_nodes_in_group("creature"):
			c.process_mode = Node.PROCESS_MODE_DISABLED
			c.visible = false
		var best := Vector3.ZERO
		var best_n := 0
		for r in get_tree().get_nodes_in_group("resource"):
			var n := 0
			for r2 in get_tree().get_nodes_in_group("resource"):
				if r2.global_position.distance_to(r.global_position) < 9.0:
					n += 1
			if n > best_n:
				best_n = n
				best = r.global_position
		p.global_position = best + Vector3(0.5, 0, 1.5)
		var k := 0
		for kind in ["infectado", "corredora", "acorazado", "infectado"]:
			var z: Node3D = world.CreatureScript.new()
			z.setup(kind)
			z.home = p.global_position + Vector3(-4.5 + k * 2.6, 0, -3.2 + (k % 2) * 1.2)
			z.position = z.home
			world.add_child(z)
			z._face(p.global_position - z.position)
			k += 1
		world.camera.global_position = p.global_position + Vector3(0, 13.0, 8.5)
		await _wait(14)
		await _shot("bosque")
		get_tree().quit()
		return
	world.hud.settings_btn.pressed.emit()
	await _wait(6)
	await _shot("ajustes")
	world.hud.close_panels()
	world.hud.map_btn.pressed.emit()
	world.hud._select_map("cantera")
	await _wait(8)
	await _shot("mapa")
	world.hud.close_panels()
	await _wait(3)
	# HUD: junto a un pino con el hacha a medio gastar
	for r in get_tree().get_nodes_in_group("resource"):
		if r.kind == "pino":
			p.global_position = r.global_position + Vector3(1.2, 0, 0.4)
			break
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "hacha_piedra":
			GS.slots[i]["dur"] = 26
	GS.food = 72.0
	GS.water = 58.0
	GS.stats_changed.emit()
	world.camera.global_position = p.global_position + Vector3(0, 13.0, 8.5)
	await _wait(10)
	await _shot("hud_talar")
	p.global_position = Vector3(2, 0, 3)
	world.camera.global_position = p.global_position + Vector3(0, 13.0, 8.5)
	await _wait(10)
	await _shot("hud_arma")
	if out.ends_with("_solo_mapa"):
		get_tree().quit()
		return
	for h in [[19.9, "atardecer"], [23.0, "noche"]]:
		GS.forced_hour = h[0]
		world.daynight.update(0.0, true)
		world._update_clock()
		await _wait(8)
		await _shot(h[1])
	GS.forced_hour = 11.0
	GS.forced_rain = 1
	world.daynight.update(0.0, true)
	world._update_clock()
	await _wait(25)
	await _shot("lluvia")
	GS.forced_rain = 0
	world.daynight.update(0.0, true)
	world._update_clock()

	# Sigilo: agachado detrás de un infectado y golpe por sorpresa
	var z: Node3D = world.CreatureScript.new()
	z.setup("acorazado")
	z.home = p.global_position + Vector3(1.6, 0, 0)
	z.position = z.home
	world.add_child(z)
	z._face(Vector3(1, 0, 0))
	z.process_mode = Node.PROCESS_MODE_DISABLED
	world.hud.toggle_crouch()
	p._face(Vector3(1, 0, 0))
	await _wait(12)
	z.process_mode = Node.PROCESS_MODE_INHERIT
	z.interact(p)
	await _wait(4)
	await _shot("sigilo")
	world.hud.toggle_crouch()
	z.queue_free()

	# Reparar en el banco de trabajo
	GS.hand["dur"] = 18
	GS.worn["torso"]["dur"] = 40
	for k in ["madera", "piedra"]:
		GS.add_item(k, 30)
	var bench: Node3D = world.base.place("banco_trabajo", Vector2i(2, -2), 0, 0, Vector3(-30, 0, -30))
	world.hud.open_station(bench)
	await _wait(6)
	world.hud._station_panel._scroll.scroll_vertical = 2000
	await _wait(4)
	await _shot("reparar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name_])
	print("ok ", name_)
