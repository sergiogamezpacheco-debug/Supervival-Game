extends Node
## Capturas del sistema de niveles y del peso.
##   xvfb-run ... res://tools/level_shots.tscn -- <dir>

func _shot(path: String) -> void:
	for i in 8:
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
	GS.level = 4
	GS.xp = 60
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	for i in 10:
		await get_tree().process_frame
	world.hud._refresh_level()
	GS.add_xp(DB.xp_to_next(4))
	await _shot(out + "/nivel_subida.png")
	await get_tree().create_timer(4.5).timeout
	world.hud.open_levels()
	await _shot(out + "/nivel_panel.png")
	world.hud.close_panels()
	GS.add_item("piedra", 30)
	GS.add_item("madera", 20)
	GS.add_item("hacha_piedra", 1)
	world.hud._toggle(world.hud._inv_panel)
	world.hud._inv_panel.select_slot(0)
	await _shot(out + "/inventario_peso.png")
	get_tree().quit()
