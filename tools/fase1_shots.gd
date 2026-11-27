extends Node
## Capturas de la fase 1 del mapa (no se exporta en el APK):
##   xvfb-run ... res://tools/fase1_shots.tscn -- <carpeta>
## Mapa con 1 y 2 piezas, La Arboleda, El Pedregal y el camino a pie.

var out := "/tmp/fase1"
var world: Node3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GS.save_path = "user://fase1_save.json"
	GS.testing = true
	GS.forced_hour = 12.0
	GS.forced_rain = 0
	get_window().size = Vector2i(1280, 720)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	GS.map_pieces = 1
	GS.save_game({})
	await _load("refugio")
	world.hud.map_btn.pressed.emit()
	await _wait(6)
	world.hud.map_buttons["arboleda"].pressed.emit()
	await _wait(4)
	await _shot("mapa_pieza1")
	world.hud.close_panels()
	await _load("r_refugio_arboleda", "refugio")
	await _wait(10)
	await _shot("camino_arboleda")
	await _load("arboleda")
	for b in get_tree().get_nodes_in_group("container"):
		if b.id == "cadaver":
			world.player.global_position = b.global_position + Vector3(2.0, 0, 2.5)
	await _wait(12)
	await _shot("arboleda_muerto")
	GS.map_pieces = 2
	world.hud.map_btn.pressed.emit()
	await _wait(6)
	world.hud.map_buttons["bosque"].pressed.emit()
	await _wait(4)
	await _shot("mapa_pieza2")
	world.hud.close_panels()
	await _load("pedregal")
	for b in get_tree().get_nodes_in_group("container"):
		if b.id == "coche":
			world.player.global_position = b.global_position + Vector3(3.0, 0, 4.0)
	await _wait(12)
	await _shot("pedregal_coche")
	get_tree().quit()


func _load(id: String, from := "") -> void:
	if world:
		world.queue_free()
		await _wait(3)
	GS.current_map = id
	GS.route_from = from
	GS.save_game(GS.maps_state.get(id, {}) if not DB.routes.has(id) else {})
	world = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	await _wait(8)


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("captura ", name)
