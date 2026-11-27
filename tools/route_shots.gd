extends Node3D
## Fotos de los tramos de camino (data/routes.json) para revisarlos.
##   xvfb-run ... res://tools/route_shots.tscn -- /tmp/caminos
## Cada foto: tramo, visita (semilla de lo que cambia), punto del recorrido (0..1) y tipo de cámara.

const CreatureScript := preload("res://scripts/world/creature.gd")
const ResourceScript := preload("res://scripts/world/resource_node.gd")

# punto: fracción del recorrido, o "spotN" = punto de cambio N (para comparar visitas)
const SHOTS := [
	["r_refugio_pinar", 1, 0.35, "alta", "senda_cuervo_cabana"],
	["r_refugio_pinar", "A", "spot1", "juego", "senda_cuervo_visita1"],
	["r_refugio_pinar", "B", "spot1", "juego", "senda_cuervo_visita2"],
	["r_refugio_centinela", 1, 0.35, "alta", "carretera_vieja_gasolinera"],
	["r_refugio_cantera", 3, 0.45, "alta", "cuesta_tajo"],
	["r_pinar_atalaya", 1, 0.86, "alta", "camino_atalaya_avisos"],
	["r_via_puerto_estacion", 1, 0.5, "alta", "via_litoral_pueblo"],
	["r_atalaya_marismas", 1, 0.4, "alta", "ribera_guadal_molino"],
	["r_refugio_centinela", 1, -1.0, "plano", "plano_carretera_vieja"],
	["r_refugio_pinar", 1, -1.0, "plano", "plano_senda_cuervo"],
]


func _ready() -> void:
	GS.testing = true
	GS.forced_hour = 12.0
	GS.forced_rain = 0
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/caminos"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/routes.json"))
	for s in SHOTS:
		var stage := Node3D.new()
		add_child(stage)
		_light(stage)
		var r: Dictionary = routes[s[0]]
		r["name"] = str(r.get("name", s[0]))
		var t0 := Time.get_ticks_msec()
		var vs := _visit_seed(r, s[1])
		var info := RouteBuilder.build(stage, r, vs)
		print("tramo ", s[0], " ", Time.get_ticks_msec() - t0, " ms")
		for res in info["resources"]:
			var n := ResourceScript.new()
			n.setup(str(res[0]))
			n.position = res[1]
			n.rotation.y = randf() * TAU
			stage.add_child(n)
		for c in info["creatures"]:
			var cr := CreatureScript.new()
			cr.setup(str(c[0]))
			cr.position = c[1]
			cr.home = c[1]
			stage.add_child(cr)
			cr.set_physics_process(false)
		var L := float(r["length"])
		var cam := Camera3D.new()
		stage.add_child(cam)
		if s[3] == "plano":
			# el tramo entero visto desde arriba, de izquierda (salida) a derecha (llegada)
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = L * 0.57
			cam.position = Vector3(0, 200, -L * 0.5)
			cam.rotation = Vector3(-PI / 2.0, -PI / 2.0, 0)
			cam.far = 400
			get_window().size = Vector2i(1280, 720)
		else:
			var z := -L * float(s[2]) if not str(s[2]).begins_with("spot") else float(info["spots"][int(str(s[2]).substr(4))].z) + 4.0
			var target := Vector3(RouteBuilder.center_x(r, z), 0, z)
			var off := Vector3(0, 13.0, 8.5) if s[3] == "juego" else Vector3(-10.0, 24.0, 22.0)
			cam.fov = 50
			cam.far = 160
			cam.position = target + off
			cam.look_at(target + Vector3(0, 0, -4.0 if s[3] == "juego" else -10.0), Vector3.UP)
			if s[3] == "juego":
				var pl := CharacterModel.new(GS.look, GS.physique, GS.outfit)
				pl.position = target + Vector3(0.6, 0, 1.0)
				pl.rotation.y = 0.2
				stage.add_child(pl)
		cam.make_current()
		for k in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, s[4]])
		print("foto ", s[4], "  obstáculos: ", info["obstacles"].map(func(o): return o[0]))
		stage.queue_free()
		await get_tree().process_frame
	get_tree().quit()


## Semillas de visita: "A" = una visita con obstáculo en el punto 1, "B" = otra en la que ese
## punto tiene otra cosa (o nada), para ver que el camino cambia.
func _visit_seed(r: Dictionary, v) -> int:
	if v is int:
		return v * 7919
	var probe := Node3D.new()
	var first := ""
	for k in range(1, 200):
		var info := RouteBuilder.build(probe, r, k * 7919)
		var kind: String = info["obstacles"][1][0]
		for c in probe.get_children():
			c.free()
		if v == "A" and kind == "arbol_caido":
			probe.free()
			return k * 7919
		if v == "B" and kind != "" and kind != "arbol_caido":
			probe.free()
			return k * 7919
	probe.free()
	return 7919


func _light(stage: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2c3a2e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8c4b0")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	stage.add_child(sun)
