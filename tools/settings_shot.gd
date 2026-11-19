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
	# La cámara a distintas distancias
	for z in [[1.0, "camara_antes"], [0.85, "camara_ahora"], [0.55, "camara_cerca"], [1.3, "camara_lejos"]]:
		world.set_zoom(z[0])
		world.camera.global_position = world.player.global_position + world.CAM_OFF * world.zoom()
		await _shot(out + "/%s.png" % z[1])
	world.set_zoom(0.85)
	world.hud.settings_btn.pressed.emit()
	var st: Control = world.hud._settings_panel
	var sc: ScrollContainer = st._list.get_parent()
	for t in ["general", "graficos", "audio"]:
		st.select_tab(t)
		sc.scroll_vertical = 0
		await _shot(out + "/ajustes_%s_1.png" % t)
		sc.scroll_vertical = 10000
		await _shot(out + "/ajustes_%s_2.png" % t)
	sc.scroll_vertical = 0
	st.select_tab("graficos")
	st.controls["zoom"].value = 1.0
	await _shot(out + "/ajustes_sin_guardar.png")
	st._legal.visible = true
	await _shot(out + "/ajustes_legal.png")
	get_tree().quit()
