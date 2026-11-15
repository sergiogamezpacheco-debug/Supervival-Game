extends Node
## Capturas de la creación de personaje, la ropa y el gimnasio (no va en el APK):
##   xvfb-run godot --rendering-driver opengl3 res://tools/survivor_shots.tscn -- <carpeta>

var out := "/tmp/survivor"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GS.save_path = "user://shots_save.json"
	GS.forced_hour = 12.0
	GS.forced_rain = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	get_window().size = Vector2i(1280, 720)
	GS.new_game()
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	await _wait(20)
	var cr: CanvasLayer = world.creator
	await _shot("creador_pelo")
	cr.select_cat("piel")
	await _wait(25)
	await _shot("creador_cuerpo")
	cr.set_sex("f")
	cr.select_cat("ojos")
	cr.pick(1)
	await _wait(25)
	await _shot("creador_cara_f")
	cr.select_cat("pelo")
	cr.pick(2)
	await _wait(25)
	await _shot("creador_pelo_f")
	cr.set_sex("m")
	cr.select_cat("pelo")
	cr.pick(4)
	cr.confirm()
	await _wait(10)

	for c in get_tree().get_nodes_in_group("creature"):
		c.process_mode = Node.PROCESS_MODE_DISABLED
		c.global_position = Vector3(40, 0, 40)
	var base: Node3D = world.base
	var p: Node3D = world.player
	GS.slots.resize(80)
	for id in ["madera", "piedra", "tablon", "fibra", "tela", "cuerda", "lingote_hierro", "piel", "chatarra"]:
		for k in 4: GS.add_item(id, 50)
	var pp := Vector3(-30, 0, -30)
	var gym: Node3D = base.place("gimnasio", Vector2i(1, -1), 0, 0, pp)
	var sew: Node3D = base.place("mesa_costura", Vector2i(-1, -1), 0, 0, pp)
	base.upgrade(sew)
	GS.slots.resize(20)
	for i in GS.slots.size():
		GS.slots[i] = null
	for id in ["chaqueta_piel", "pantalon_cargo", "botas", "mochila", "guantes"]:
		GS.add_item(id, 1)
		for i in GS.slots.size():
			if GS.slots[i] != null and GS.slots[i]["id"] == id:
				GS.wear_slot(i)
				break
	for it in [["madera", 34], ["piedra", 12], ["tela", 6], ["carne_asada", 3], ["venda", 2], ["camiseta", 1], ["casco_obra", 1]]:
		GS.add_item(it[0], it[1])
	GS.hand = GS.make_item("lanza")
	GS.add_item("hacha_piedra", 1)
	GS.physique["fuerza"] = 0.32
	GS.physique["resistencia"] = 0.45
	GS.inventory_changed.emit()
	GS.look_changed.emit()
	p.global_position = Vector3(0.5, 0, 1.2)
	p._face(Vector3(0.3, 0, 1))
	world.camera.global_position = p.global_position + Vector3(0, 13.0, 8.5)
	await _wait(30)
	await _shot("mundo")
	world.hud._toggle(world.hud._inv_panel)
	world.hud._select(3)
	await _wait(10)
	await _shot("mochila")
	world.hud.close_panels()
	world.hud.open_station(gym)
	await _wait(10)
	await _shot("gimnasio")
	world.hud.open_station(sew)
	await _wait(10)
	await _shot("costura")
	world.hud.close_panels()
	world.hud.open_station(gym)
	world.hud.train("fuerza")
	await _wait(12)
	await _shot("entrenando")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name_])
	print("ok ", name_)
