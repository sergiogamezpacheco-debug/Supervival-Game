extends Node
## Capturas de la pantalla de ajustes (pestañas General, Gráficos y Audio).
##   xvfb-run ... res://tools/settings_shot.tscn -- <dir>

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
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	for i in 10:
		await get_tree().process_frame
	SFX.previous_access = Time.get_unix_time_from_system() - 300.0
	world.hud.settings_btn.pressed.emit()
	await _shot(out + "/ajustes_general.png")
	var st: Control = world.hud._settings_panel
	st.select_tab("graficos")
	await _shot(out + "/ajustes_graficos.png")
	st.select_tab("audio")
	await _shot(out + "/ajustes_audio.png")
	get_tree().quit()
