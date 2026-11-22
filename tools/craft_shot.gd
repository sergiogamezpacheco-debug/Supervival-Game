extends Node
## Capturas de la pantalla de fabricación.
##   xvfb-run ... res://tools/craft_shot.tscn -- <dir>

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
	GS.level = 9
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	for i in 10:
		await get_tree().process_frame
	for id in ["madera", "piedra", "fibra", "tela"]:
		GS.add_item(id, 6)
	world.hud.craft_btn.pressed.emit()
	await _shot(out + "/fabricar_todo.png")
	var cs: Control = world.hud._craft_panel
	for i in cs.cards.size():
		if cs.cards[i]["r"]["result"] == "garrote":
			cs._show(i)
	await _shot(out + "/fabricar_garrote.png")
	cs.ctab = "Ropa"
	cs.sel = 0
	cs.refresh()
	await _shot(out + "/fabricar_ropa.png")
	get_tree().quit()
