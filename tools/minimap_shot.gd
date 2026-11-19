extends Node
## Captura del minimapa en el bosque con infectados, animales y cajas cerca.
##   xvfb-run ... res://tools/minimap_shot.tscn -- <dir>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	GS.testing = true
	GS.forced_hour = 12.0
	GS.forced_rain = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	get_window().size = Vector2i(1280, 720)
	GS.new_game()
	GS.current_map = "bosque"
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	for i in 10:
		await get_tree().process_frame
	var p: Vector3 = world.player.global_position
	for e in [["infectado", Vector3(-5, 0, 6)], ["corredora", Vector3(7, 0, -3)], ["infectado", Vector3(3, 0, 8)], ["lobo", Vector3(-8, 0, 7)], ["ciervo", Vector3(-9, 0, 2)], ["gritona", Vector3(8, 0, 5)]]:
		var z: Node3D = world.CreatureScript.new()
		z.setup(e[0])
		z.home = p + e[1]
		z.position = z.home
		world.add_child(z)
		z.set_process(false)
		z.set_physics_process(false)
	for c in get_tree().get_nodes_in_group("creature"):
		c.set_physics_process(false)
	world.player._visual.rotation.y = -0.6
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/minimapa.png")
	var img := get_viewport().get_texture().get_image()
	img.get_region(Rect2i(0, 200, 280, 280)).resize(560, 560, Image.INTERPOLATE_LANCZOS)
	var crop := img.get_region(Rect2i(8, 218, 236, 236))
	crop.resize(472, 472, Image.INTERPOLATE_LANCZOS)
	crop.save_png(out + "/minimapa_zoom.png")
	get_tree().quit()
