extends Node
## Fotos de una zona para enseñar al usuario cómo queda.
##   xvfb-run ... res://tools/zone_shots.tscn -- <dir> <mapa> [x,z ...]
## Saca: vista desde lo alto, la llegada (cámara del juego) y el jugador en cada punto x,z pedido.
## Si la zona tiene puestos de comerciante, también la ventana del primero.

func _shot(path: String) -> void:
	for i in 14:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("foto ", path)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var map_id: String = args[1]
	GS.save_path = "user://zone_shots.json"
	GS.testing = true
	GS.forced_hour = 12.0
	GS.forced_rain = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	get_window().size = Vector2i(1280, 720)
	GS.new_game()
	GS.current_map = map_id
	var w: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(w)
	for i in 10:
		await get_tree().process_frame
	for c in get_tree().get_nodes_in_group("creature"):
		c.process_mode = Node.PROCESS_MODE_DISABLED
	w.hud.visible = false
	# desde lo alto
	var cam := Camera3D.new()
	cam.fov = 50
	cam.far = 400
	add_child(cam)
	var half: float = float(DB.maps[map_id].get("size", 90)) / 2.0
	cam.position = Vector3(0, half * 1.15, half * 1.05)
	cam.look_at(Vector3(0, 0, -half * 0.05), Vector3.UP)
	cam.make_current()
	await _shot("%s/%s_vista.png" % [out, map_id])
	var sp: Array = DB.maps[map_id].get("spawn", [0, 44])
	var spv := Vector3(float(sp[0]), 0, float(sp[1]))
	var inward := -spv.normalized() if spv.length() > 1.0 else Vector3(0, 0, -1)
	cam.position = spv + Vector3(0, 22, 0) - inward * 4.0
	cam.look_at(spv + inward * 32.0, Vector3.UP)
	await _shot("%s/%s_llegada.png" % [out, map_id])
	cam.clear_current()
	w.camera.make_current()
	w.hud.visible = true
	var k := 0
	for a in args.slice(2):
		var xz: PackedStringArray = str(a).split(",")
		w.player.global_position = Vector3(float(xz[0]), 0, float(xz[1]))
		w.player.reset_physics_interpolation()
		await _shot("%s/%s_%d.png" % [out, map_id, k])
		k += 1
	for s in get_tree().get_nodes_in_group("station"):
		if s.has_method("is_trader") and s.is_trader():
			GS.add_item("madera", 40)
			GS.add_item("vale_atalaya", 12)
			w.hud.open_station(s)
			await _shot("%s/%s_puesto_%s.png" % [out, map_id, s.id])
			w.hud.close_panels()
	get_tree().quit()
