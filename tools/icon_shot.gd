extends Node
## Captura del inventario con los iconos de materiales y objetos (revisión de iconos).
##   xvfb-run ... res://tools/icon_shot.tscn -- <dir>

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
	GS.slots.resize(32)
	for i in GS.slots.size():
		GS.slots[i] = null
	for id in ["madera", "piedra", "mineral_hierro", "chatarra", "tablon", "bloque_piedra", "lingote_hierro", "lingote_cobre",
			"tela", "cuero", "polvora", "componentes", "mineral_cobre", "azufre", "cuerda", "venda",
			"hacha_piedra", "pico_piedra", "lanza", "garrote", "mochila_excursion", "mochila_tactica"]:
		GS.add_item(id, 5 if DB.stack_size(id) > 1 else 1)
	GS.inventory_changed.emit()
	world.hud.inv_btn.pressed.emit()
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/inventario_iconos.png")
	world.hud.close_panels()
	# Panel de obra por fases y panel de recetas con materiales
	for id in ["lingote_hierro", "tablon", "componentes", "lingote_cobre", "chatarra", "carne_cruda", "carbon"]:
		GS.add_item(id, 12)
	var base: Node3D = world.base
	var pp := Vector3(30, 0, 30)
	var gen: Node3D = base.place("generador", Vector2i(2, 4), 0, 0, pp)
	gen.add_phase()
	world.hud.open_station(gen)
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/panel_obra.png")
	world.hud.close_panels()
	GS.add_item("cuerda", 4)
	var arm: Node3D = base.place("banco_armas", Vector2i(-2, 4), 0, 0, pp)
	arm.add_phase()
	world.hud.open_station(arm)
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/panel_banco_armas.png")
	get_tree().quit()
