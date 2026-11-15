extends Node
## Captura del juego sin interfaz (fondo para maquetas de HUD).
##   xvfb-run godot --rendering-driver opengl3 res://tools/clean_shot.tscn -- /tmp/out.png

func _ready() -> void:
	var out := "/tmp/clean.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	GS.save_path = "user://clean_save.json"
	GS.testing = true
	GS.forced_hour = 12.0
	GS.forced_rain = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	get_window().size = Vector2i(1280, 720)
	GS.new_game()
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	for i in 10: await get_tree().process_frame
	world.hud.visible = false
	var base: Node3D = world.base
	GS.slots.resize(80)
	for id in ["madera", "piedra", "tablon", "bloque_piedra", "fibra", "tela", "cuerda", "lingote_hierro"]:
		for k in 8: GS.add_item(id, 50)
	var pp := Vector3(-30, 0, -30)
	for x in range(-1, 3):
		for z in range(-2, 1):
			base.place("cimiento", Vector2i(x, z), 0, 0, pp)
	for x in range(-1, 3):
		base.place("pared", Vector2i(x, -2), 0, 0, pp)
	base.place("pared", Vector2i(-1, -2), 3, 0, pp)
	base.place("pared", Vector2i(-1, -1), 3, 0, pp)
	base.place("pared", Vector2i(2, -2), 1, 0, pp)
	base.place("puerta", Vector2i(2, -1), 1, 0, pp)
	base.place("pared", Vector2i(2, 0), 1, 0, pp)
	base.place("banco_trabajo", Vector2i(0, -2), 0, 0, pp)
	base.place("cofre", Vector2i(1, -2), 0, 0, pp)
	base.place("hoguera", Vector2i(3, 2), 0, 0, pp)
	base.place("carpinteria", Vector2i(-3, 1), 0, 1, pp)
	base.place("horno", Vector2i(-3, -1), 0, 0, pp)
	GS.hand = GS.make_item("lanza")
	GS.add_item("hacha_piedra", 1)
	GS.inventory_changed.emit()
	world.player.global_position = Vector3(4.5, 0, 3.5)
	world.player._face(Vector3(-1, 0, -0.4))
	world.camera.global_position = world.player.global_position + Vector3(0, 13.0, 8.5)
	for c in get_tree().get_nodes_in_group("creature"):
		c.process_mode = Node.PROCESS_MODE_DISABLED
	var kinds := ["infectado", "lobo"]
	var n := 0
	for c in get_tree().get_nodes_in_group("creature"):
		if c.kind in kinds and n < 2:
			c.global_position = Vector3(11 + n * 1.5, 0, 6 + n)
			n += 1
	for i in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("ok ", out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	get_tree().quit()
