extends Node
## Tests automáticos. Se ejecutan en GitHub Actions antes de compilar el APK:
##   godot --headless res://tests/test_runner.tscn
## Si algo falla, el proceso sale con código 1 y no se publica el APK.

var failures := 0
var passed := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
		print("  OK   ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func _ready() -> void:
	GS.save_path = "user://test_save.json"
	GS.testing = true
	SFX.settings_path = "user://test_settings.json"
	GS.forced_hour = 12.0
	GS.forced_rain = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	print("== Datos")
	test_data()
	print("== Inventario")
	test_inventory()
	print("== Fabricación y equipo")
	test_crafting()
	print("== Guardado")
	test_save()
	print("== Mundo")
	await test_world()
	print("== Construcción y estaciones")
	await test_base()
	print("== Estructuras del refugio (obra por fases)")
	await test_shelter_structures()
	print("== Niveles y peso")
	await test_levels_weight()
	print("== Animales")
	await test_animals()
	print("== Viajes y zonas")
	await test_travel()
	print("== Personaje")
	await test_character()
	print("== Ropa, físico y gimnasio")
	await test_survivor()
	print("== Inventario y mochilas")
	await test_inventory_screen()
	print("== Día, noche, sigilo y reparar")
	await test_night_stealth()
	print("== Esquivar, sonido y ajustes")
	await test_dodge_audio()
	print("== Infectados: tipos y habilidades")
	await test_infected()
	print("== Creación de personaje")
	await test_creator()
	print("\nResultado: %d OK, %d fallos" % [passed, failures])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	get_tree().quit(1 if failures > 0 else 0)


func test_data() -> void:
	check(DB.items.size() > 0, "items.json cargado")
	check(DB.recipes.size() > 0, "recipes.json cargado")
	check(DB.resources.size() > 0, "resources.json cargado")
	for r in DB.recipes:
		check(DB.items.has(str(r["result"])), "receta %s produce un objeto que existe" % r["id"])
		for id in r["cost"]:
			check(DB.items.has(str(id)), "receta %s usa %s, que existe" % [r["id"], id])
	for k in DB.resources:
		check(DB.items.has(str(DB.resources[k]["yield"])), "recurso %s da un objeto que existe" % k)
	for r in DB.recipes:
		var st := str(r.get("station", ""))
		check(st == "" or DB.stations.has(st), "receta %s usa una estación que existe" % r["id"])
	for m in DB.maps:
		for k in DB.maps[m].get("resources", {}):
			check(DB.resources.has(k), "mapa %s: recurso %s existe" % [m, k])
		for g in DB.maps[m].get("creatures", []):
			check(DB.creatures.has(str(g["type"])), "mapa %s: criatura %s existe" % [m, g["type"]])
	for c in DB.creatures:
		for id in DB.creatures[c].get("loot", {}):
			check(DB.items.has(str(id)), "criatura %s suelta %s, que existe" % [c, id])
	for m in DB.maps:
		check(DB.world_map.has(m), "el mapa %s aparece en el mapa del mundo" % m)
		for pf in DB.maps[m].get("prefabs", []):
			for c in pf.get("containers", []):
				check(DB.containers.has(str(c["type"])), "contenedor %s existe" % c["type"])
	for c in DB.containers:
		for e in DB.containers[c]["loot"]:
			check(DB.items.has(str(e["id"])), "el contenedor %s da %s, que existe" % [c, e["id"]])
	var all_costs: Array = []
	for id in DB.structures:
		for t in DB.structures[id]["tiers"]:
			all_costs.append(t["cost"])
	for id in DB.stations:
		for l in DB.stations[id]["levels"]:
			all_costs.append(l["cost"])
	var bad := 0
	for cost in all_costs:
		for id in cost:
			if not DB.items.has(str(id)):
				bad += 1
	check(bad == 0, "todos los costes de construcción usan objetos que existen")


func test_inventory() -> void:
	GS.new_game()
	check(GS.add_item("madera", 30) == 0, "añadir 30 madera")
	check(GS.add_item("madera", 30) == 0, "añadir otras 30 (apila hasta 50)")
	check(GS.count("madera") == 60, "cuenta 60 madera")
	check(GS.slots.size() - GS.free_slots() == 2, "60 madera ocupan 2 casillas")
	check(GS.remove_item("madera", 55), "quitar 55")
	check(GS.count("madera") == 5, "quedan 5")
	check(not GS.remove_item("madera", 6), "no deja quitar más de lo que hay")
	GS.new_game()
	var left := GS.add_item("hacha_piedra", 25)
	check(left == 25 - GS.slots.size(), "las herramientas no se apilan (sobran %d con %d casillas)" % [left, GS.slots.size()])
	GS.new_game()


func test_crafting() -> void:
	GS.new_game()
	check(not GS.craft("hacha_piedra"), "no fabrica sin materiales")
	GS.add_item("madera", 5)
	GS.add_item("piedra", 3)
	check(GS.craft("hacha_piedra"), "fabrica hacha")
	check(GS.count("hacha_piedra") == 1 and GS.count("madera") == 0, "consume materiales")
	var idx := -1
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "hacha_piedra":
			idx = i
	GS.equip_slot(idx)
	check(GS.hand == null and GS.best_tool("axe") == idx, "el hacha no se equipa como arma: se usa desde el inventario")
	var d0 := int(GS.slots[idx]["dur"])
	GS.wear_slot_item(idx)
	check(int(GS.slots[idx]["dur"]) == d0 - 1, "usar la herramienta la gasta")
	GS.slots[idx]["dur"] = 1
	GS.wear_slot_item(idx)
	check(GS.slots[idx] == null and GS.best_tool("axe") == -1, "la herramienta se rompe a 0")
	GS.add_item("hacha_piedra", 1)
	GS.add_item("hacha_hierro", 1)
	check(GS.slots[GS.best_tool("axe")]["id"] == "hacha_hierro", "se usa la mejor hacha del inventario")
	for i in GS.slots.size():
		GS.slots[i] = null
	GS.add_item("lanza", 1)
	GS.equip_slot(0)
	check(GS.hand != null and GS.hand["id"] == "lanza" and GS.hand_damage() > float(DB.bal("fist_damage", 6)), "la lanza sí se equipa y pega más que el puño")
	var dur := int(GS.hand["dur"])
	GS.wear_hand()
	check(int(GS.hand["dur"]) == dur - 1, "el uso gasta durabilidad")
	GS.hand["dur"] = 1
	GS.wear_hand()
	check(GS.hand == null, "el arma se rompe a 0")
	GS.add_item("baya", 2)
	GS.food = 50.0
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "baya":
			GS.use_slot(i)
			break
	check(GS.food > 50.0 and GS.count("baya") == 1, "comer bayas quita hambre")
	GS.new_game()


func test_save() -> void:
	GS.new_game()
	GS.add_item("piedra", 7)
	GS.add_item("lanza", 1)
	GS.water = 42.0
	GS.save_game({"player": [3.0, 4.0], "bags": []})
	GS.new_game()
	var w := GS.load_game()
	check(GS.count("piedra") == 7 and GS.count("lanza") == 1, "carga el inventario")
	check(is_equal_approx(GS.water, 42.0), "carga el agua")
	check(w.get("player", [])[0] == 3.0, "carga la posición")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()


## Fotogramas de proceso (el HUD se actualiza en _process; tras un fotograma lento
## pueden pasar varios de física sin ninguno de proceso).
func _pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_world() -> void:
	GS.new_game()
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	await _frames(5)
	var player: Node3D = world.player
	check(player != null, "aparece el jugador")
	check(player._visual is CharacterModel and player._visual.hand != null, "el jugador es el superviviente con mano para herramientas")
	check(player._visual.j.has("leg_l") and player._visual.j.has("arm_r"), "el superviviente tiene articulaciones para animar")
	check(get_tree().get_nodes_in_group("resource").size() > 50, "se generan recursos")
	check(get_tree().get_nodes_in_group("enemy").size() > 0, "se generan infectados")

	# Alejar a los infectados para que no interfieran.
	for z in get_tree().get_nodes_in_group("enemy"):
		z.home = Vector3(40, 0, 40)
		z.global_position = Vector3(40, 0, 40)

	# Recolectar de un pino.
	var tree: Node3D = null
	for r in get_tree().get_nodes_in_group("resource"):
		if r.kind == "pino":
			tree = r
			break
	player.global_position = tree.global_position + Vector3(1.2, 0, 0)
	await _frames(3)
	check(world.find_target() == tree, "detecta el pino como objetivo")
	player.action_held = true
	world.hud.action_button.held = true
	await _frames(150)
	world.hud.action_button.held = false
	player.action_held = false
	check(GS.count("madera") > 0, "talar da madera (%d)" % GS.count("madera"))
	await test_action_hud(world, player, tree)

	# Botón táctil: un toque dentro del botón de acción lo marca como pulsado.
	var btn: Control = world.hud.action_button
	# Los toques llegan en píxeles de pantalla: convertimos desde coordenadas del juego.
	var center: Vector2 = get_tree().root.get_final_transform() * (btn.get_global_transform_with_canvas() * (btn.size / 2.0))
	var ev := InputEventScreenTouch.new()
	ev.index = 3
	ev.position = center
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	check(btn.held, "el botón de acción responde al toque")
	var up := InputEventScreenTouch.new()
	up.index = 3
	up.position = center
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)
	check(not btn.held, "el botón se suelta")

	# Matar un infectado deja botín.
	var z: Node3D = get_tree().get_nodes_in_group("enemy")[0]
	z.global_position = player.global_position + Vector3(1.0, 0, 0)
	z.home = z.global_position
	await _frames(2)
	check(world.find_target() == z, "prioriza al infectado como objetivo")
	var bags_before := get_tree().get_nodes_in_group("bag").size()
	z.hp = 1.0
	z.interact(player)
	await _frames(2)
	check(not z.visible, "el infectado muere")
	check(get_tree().get_nodes_in_group("bag").size() == bags_before + 1, "deja una bolsa de botín")

	# Morir deja la mochila en el suelo y reapareces sin nada.
	GS.add_item("piedra", 4)
	var death_pos := player.global_position
	GS.damage(1000)
	await _frames(2)
	check(GS.count("piedra") == 0, "al morir pierdes lo que llevabas")
	var found := false
	for b in get_tree().get_nodes_in_group("bag"):
		if b.is_player_bag and b.global_position.distance_to(Vector3(death_pos.x, 0, death_pos.z)) < 0.1:
			found = true
	check(found, "tu mochila queda donde caíste")
	world._death_timer = 0.0
	await _frames(3)
	check(not GS.dead and is_equal_approx(GS.health, 100.0), "reapareces con la vida llena")

	# Guardado del mundo (mochila incluida).
	world.save()
	var w := GS.load_game()
	var has_player_bag := false
	for b in w.get("bags", []):
		if b.get("player", false):
			has_player_bag = true
	check(has_player_bag, "la mochila tirada se guarda en la partida")
	world.queue_free()
	await _frames(2)


func _new_world() -> Node3D:
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	await _frames(5)
	for c in get_tree().get_nodes_in_group("creature"):
		c.home = Vector3(42, 0, 42)
		c.global_position = Vector3(42, 0, 42)
	return world


func test_base() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	var world := await _new_world()
	var base: Node3D = world.base
	var player: Node3D = world.player
	check(base != null, "el refugio tiene zona de construcción")
	player.global_position = Vector3(1, 0, 1)
	var pp := player.global_position
	var c := Vector2i(4, 2)

	check(base.check_place("pared", c, 0, pp) != "", "una pared necesita cimiento")
	check(base.place("cimiento", c, 0, 0, pp) == null, "sin materiales no se construye")
	GS.add_item("madera", 100)
	GS.add_item("piedra", 100)
	GS.add_item("tablon", 40)
	var f: Node3D = base.place("cimiento", c, 0, 0, pp)
	check(f != null and GS.count("madera") == 92, "cimiento colocado y cobrado")
	check(base.place("cimiento", c, 0, 0, pp) == null, "no se pueden apilar cimientos")
	check(base.place("cimiento", Vector2i(20, 0), 0, 0, pp) == null, "fuera del refugio no se construye")
	var wall: Node3D = base.place("pared", c, 0, 0, pp)
	check(wall != null and GS.count("tablon") == 35, "pared colocada en el borde norte")
	check(base.place("pared", c, 0, 0, pp) == null, "no se repite pared en el mismo borde")
	check(base.place("pared", Vector2i(c.x, c.y - 1), 2, 0, pp) == null, "el borde compartido cuenta como el mismo")
	var door: Node3D = base.place("puerta", c, 1, 0, pp)
	check(door != null, "puerta colocada")
	door.interact(player)
	check(door.is_open, "la puerta se abre")
	door.interact(player)
	check(not door.is_open, "la puerta se cierra")

	# Mejorar pared de madera -> piedra
	check(not base.upgrade(wall), "mejorar sin bloques de piedra falla")
	GS.add_item("bloque_piedra", 6)
	check(base.upgrade(wall) and wall.tier == 1, "pared mejorada a piedra")

	# Desmontar
	check(base.can_demolish(f) != "", "no deja quitar un cimiento que sujeta paredes")
	var tab := GS.count("tablon")
	check(base.demolish(door) and GS.count("tablon") == tab + 3, "desmontar devuelve la mitad")

	# Construir desde el modo construir (como lo hace el jugador)
	player.global_position = Vector3(-3, 0, -3)
	player._face(Vector3(1, 0, 0))
	world._on_build_selected("place", "cimiento")
	await _frames(2)
	var tgt: Array = world.build_target()
	check(world.confirm_build(), "el modo construir coloca delante del jugador")
	check(base.has_foundation(tgt[0]), "el cimiento está en la casilla apuntada")
	world.exit_build()

	# Estación con tiempo
	pp = player.global_position
	var carp: Node3D = base.place("carpinteria", Vector2i(-4, 4), 0, 0, pp)
	check(carp != null, "banco de carpintería colocado")
	check(carp.start("tablon") == "", "empieza a fabricar un tablón")
	check(carp.start("tablon") != "", "una estación fabrica de una en una")
	check(not carp.is_done(), "aún no está listo")
	world.hud.open_station(carp)
	await _frames(2)
	check(world.hud._station_panel.visible, "se abre el panel de la estación")
	world.hud.close_panels()
	GS.time_offset += 9.0
	check(carp.is_done(), "terminado al pasar el tiempo")
	var t0 := GS.count("tablon")
	check(carp.collect() and GS.count("tablon") == t0 + 1, "recoger el tablón")

	var bench: Node3D = base.place("banco_trabajo", Vector2i(-6, 4), 0, 0, pp)
	check(bench != null, "banco de trabajo colocado")
	GS.add_item("lingote_hierro", 10)
	GS.add_item("cuerda", 5)
	check(bench.start("hacha_hierro") != "", "el hacha de hierro pide banco de nivel 2")
	GS.add_item("bloque_piedra", 10)
	check(base.upgrade(bench) and bench.level == 2, "banco mejorado a nivel 2")
	check(bench.start("hacha_hierro") == "", "con nivel 2 ya fabrica el hacha de hierro")
	check(bench.start("machete") != "" and DB.recipe("machete")["station"] == "banco_armas", "el machete ahora sale del banco de armas")

	# Materiales nuevos: pólvora, componentes (banco nv2), lingote de cobre (horno), cuero (costura)
	check(DB.item_name("madera") == "Troncos" and DB.item_name("mineral_hierro") == "Mena de hierro", "nombres de los materiales como en el diseño")
	for rid in ["lingote_cobre", "cuero", "polvora", "componentes"]:
		check(not DB.recipe(rid).is_empty(), "existe la receta %s" % rid)
	# Hueco en la mochila (8 bolsillos) para recoger el hacha y probar las recetas nuevas
	var tablones := GS.count("tablon")
	var bloques := GS.count("bloque_piedra")
	GS.remove_item("tablon", tablones)
	GS.remove_item("bloque_piedra", bloques)
	GS.time_offset += 60.0
	bench.collect()
	check(GS.count("hacha_hierro") == 1, "hacha de hierro recogida")
	GS.remove_item("hacha_hierro", 1)
	GS.add_item("chatarra", 4)
	var why_c: String = bench.start("componentes")
	check(why_c == "", "el banco nv2 saca componentes de la chatarra")
	GS.time_offset += 16.0
	bench.collect()
	check(GS.count("componentes") == 1, "componentes recogidos")
	GS.remove_item("componentes", 1)
	GS.add_item("tablon", tablones)
	GS.add_item("bloque_piedra", bloques)
	check(DB.recipe("lingote_cobre")["station"] == "horno" and DB.recipe("cuero")["station"] == "mesa_costura", "cobre en el horno y cuero en la costura")
	for kind in ["veta_cobre", "veta_azufre"]:
		check(Builder.resource_mesh(kind).get_child_count() > 3, "modelo 3D de %s" % kind)
	check(DB.maps["cantera"]["resources"].has("veta_cobre") and DB.maps["cantera"]["resources"].has("veta_azufre"), "cobre y azufre en la cantera")
	check(DB.item_icon("lingote_cobre") != DB.item_icon("lingote_hierro"), "el cobre tiene su propio icono")

	var fire: Node3D = base.place("hoguera", Vector2i(-2, 6), 0, 0, pp)
	GS.add_item("carne_cruda", 1)
	check(fire != null and fire.start("carne_asada") == "", "la hoguera cocina carne")
	GS.time_offset += 11.0
	fire.collect()
	check(GS.count("carne_asada") == 1, "carne asada recogida")

	# Cofre
	var chest: Node3D = base.place("cofre", Vector2i(-8, 6), 0, 0, pp)
	check(chest != null and chest.storage.size() == 12, "cofre con 12 huecos")
	var slot := -1
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "piedra":
			slot = i
	var stones := GS.count("piedra")
	chest.bag_to_chest(slot)
	check(GS.count("piedra") < stones and chest.storage[0] != null, "guardar en el cofre")
	chest.chest_to_bag(0)
	check(GS.count("piedra") == stones, "sacar del cofre")
	chest.bag_to_chest(slot if GS.slots[slot] != null else 0)

	# Guardar y volver a cargar el refugio entero
	carp.start("tablon")
	var n_found: int = base.foundations.size()
	world.save()
	world.queue_free()
	await _frames(3)
	var world2 := await _new_world()
	var base2: Node3D = world2.base
	check(base2.foundations.size() == n_found, "se cargan los cimientos")
	check(base2.edges.size() == 1, "se carga la pared")
	var wall2: Node3D = base2.edges.values()[0]
	check(wall2.tier == 1, "se carga el nivel de la pared")
	var loaded_carp: Node3D = base2.objects.get(Base_key(-4, 4))
	check(loaded_carp != null and not loaded_carp.job.is_empty(), "la estación sigue fabricando tras cargar")
	var loaded_chest: Node3D = base2.objects.get(Base_key(-8, 6))
	check(loaded_chest != null and loaded_chest.storage[0] != null, "se carga el contenido del cofre")
	var loaded_bench: Node3D = base2.objects.get(Base_key(-6, 4))
	check(loaded_bench != null and loaded_bench.level == 2, "se carga el nivel del banco")
	world2.queue_free()
	GS.time_offset = 0.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	await _frames(2)


func Base_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func _place_any(base: Node3D, id: String, pp: Vector3) -> Node3D:
	for j in range(-8, 8, 2):
		for i in range(-8, 8, 2):
			if base.check_place(id, Vector2i(i, j), 0, pp) == "":
				return base.place(id, Vector2i(i, j), 0, 0, pp)
	return null


func _give(cost: Dictionary) -> void:
	for id in cost:
		GS.add_item(str(id), int(cost[id]))


func test_shelter_structures() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	GS.forced_rain = 0
	var world := await _new_world()
	var base: Node3D = world.base
	world.player.global_position = Vector3(30, 0, 30)
	var pp := Vector3(30, 0, 30)
	GS.slots.resize(48)
	for i in GS.slots.size():
		GS.slots[i] = null

	# Modelos según la lámina
	for id in ["carpinteria", "horno", "hoguera", "banco_armas", "recolector_agua", "secadero", "huerto", "mesa_medica", "generador", "recicladora"]:
		var m := StationModels.make(id, 1)
		check(m != null and m.get_child_count() >= 6, "modelo 3D de %s" % id)
		if m:
			m.free()
	for id in ["carne_seca", "botiquin", "antidoto", "polvora", "componentes"]:
		check(DB.item_icon(id) != null and DB.item_icon(id).resource_path.ends_with(".png"), "icono de %s sacado del diseño" % id)

	# Obra por fases: generador
	check(base.place_cost("generador") == DB.station_phases("generador")[0]["cost"], "colocar paga solo la primera fase")
	_give(DB.station_phases("generador")[0]["cost"])
	var gen: Node3D = _place_any(base, "generador", pp)
	check(gen != null and gen.stage == 1 and not gen.is_built(), "el generador queda en obra (fase 1 de 3)")
	check(gen.action_label() == "Construir", "tocarlo sirve para seguir la obra")
	check(gen._visual.has_meta("en_obra"), "se ve con andamio mientras está en obra")
	check(gen.add_phase() == "Faltan materiales", "sin materiales no avanza")
	world.hud.open_station(gen)
	await _frames(2)
	var add_btn: Button = null
	for row in world.hud._station_list.get_children():
		for c in row.get_children():
			if c is Button and c.text == "Añadir":
				add_btn = c
	check(add_btn != null and add_btn.disabled, "el panel muestra la siguiente fase con su botón")
	_give(DB.station_phases("generador")[1]["cost"])
	world.hud._refresh_station()
	await _frames(1)
	for row in world.hud._station_list.get_children():
		for c in row.get_children():
			if c is Button and c.text == "Añadir":
				add_btn = c
	add_btn.pressed.emit()
	check(gen.stage == 2, "Añadir paga la fase 2")
	_give(DB.station_phases("generador")[2]["cost"])
	check(gen.add_phase() == "" and gen.is_built(), "fase 3: generador terminado")
	check(not gen._visual.has_meta("en_obra"), "ya sin andamio")
	world.hud.close_panels()

	# Recicladora: necesita energía
	var rec: Node3D = null
	for ph in DB.station_phases("recicladora"):
		_give(ph["cost"])
	rec = _place_any(base, "recicladora", pp)
	while rec != null and not rec.is_built():
		rec.add_phase()
	check(rec != null and rec.is_built(), "recicladora construida en 3 fases")
	GS.add_item("chatarra", 4)
	check(rec.start("reciclar_componentes") == "Al generador le falta combustible", "sin combustible no recicla")
	GS.add_item("carbon", 1)
	check(gen.add_fuel("carbon") == "" and int(gen.fuel) == 300, "un carbón da 5 minutos de energía")
	check(rec.start("reciclar_componentes") == "" and int(gen.fuel) == 270, "reciclar gasta la energía que dura")
	GS.time_offset += 31.0
	check(rec.collect() and GS.count("componentes") == 2, "la recicladora da 2 componentes por 4 de chatarra")

	# Recolector de agua: se llena solo, más con lluvia
	_give(DB.station_build_cost("recolector_agua"))
	var col: Node3D = _place_any(base, "recolector_agua", pp)
	check(col != null and col.is_built(), "recolector colocado de una vez")
	col.water = 0.0
	col.water_t = GS.now() - 3600.0
	check(absf(col.water_now() - 20.0) < 0.5, "junta 20 de agua por hora")
	GS.forced_rain = 1
	check(absf(col.water_now() - 80.0) < 0.5, "con lluvia, cuatro veces más")
	GS.forced_rain = 0
	GS.water = 50.0
	col.drink()
	check(GS.water >= 69.0 and col.water < 1.0, "beber del recolector")

	# Huerto: obra en 2 fases y riego
	for ph in DB.station_phases("huerto"):
		_give(ph["cost"])
	var garden: Node3D = _place_any(base, "huerto", pp)
	garden.add_phase()
	check(garden.is_built(), "huerto terminado")
	check(is_equal_approx(garden.recipe_time(DB.recipe("cultivo_bayas")), 300.0), "con recolector crece el doble de rápido")
	GS.add_item("baya", 2)
	check(garden.start("cultivo_bayas") == "", "plantar bayas")
	GS.time_offset += 301.0
	check(garden.collect() and GS.count("baya") == 6, "cosecha de 6 bayas")

	# Secadero, banco de armas y mesa médica
	for id in ["secadero", "banco_armas", "mesa_medica"]:
		var all_cost := DB.station_build_cost(id)
		for ph in DB.station_phases(id):
			_give(ph["cost"])
		if DB.station_phases(id).is_empty():
			_give(all_cost)
		var st: Node3D = _place_any(base, id, pp)
		while st != null and not st.is_built():
			st.add_phase()
		check(st != null and st.is_built(), "%s construido" % id)
		var rid: String = {"secadero": "carne_seca", "banco_armas": "polvora", "mesa_medica": "botiquin"}[id]
		var r := DB.recipe(rid)
		_give(r["cost"])
		check(st.start(rid) == "", "%s fabrica %s" % [id, rid])
		GS.time_offset += float(r["time"]) + 1.0
		var before := GS.count(str(r["result"]))
		check(st.collect() and GS.count(str(r["result"])) == before + int(r.get("qty", 1)), "%s recogido" % rid)
	GS.add_item("botiquin", 1)
	GS.health = 20.0
	GS.poison = 5.0
	var bslot := -1
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "botiquin":
			bslot = i
	GS.use_slot(bslot)
	check(GS.health >= 79.0 and GS.poison == 0.0, "el botiquín cura 60 y quita el veneno")

	# Desmontar una obra a medias devuelve la mitad de lo pagado
	_give(DB.station_phases("generador")[0]["cost"])
	var half_gen: Node3D = _place_any(base, "generador", pp)
	var iron := GS.count("lingote_hierro")
	base.demolish(half_gen)
	check(GS.count("lingote_hierro") == iron + 2, "desmontar la obra devuelve la mitad de la fase pagada")

	# Guardar y cargar conserva fases, agua y combustible
	_give(DB.station_phases("generador")[0]["cost"])
	var g2: Node3D = _place_any(base, "generador", pp)
	var list: Array = base.to_list()
	var saved_stage := -1
	var saved_fuel := -1.0
	for e in list:
		if e.get("id", "") == "generador" and e.get("key", "") == g2.key:
			saved_stage = int(e["stage"])
		if e.get("id", "") == "generador" and e.get("key", "") == gen.key:
			saved_fuel = float(e["fuel"])
	check(saved_stage == 1 and int(saved_fuel) == 270, "se guardan la fase y el combustible")
	check(world.hud.location_label.text == "Refugio", "en pantalla pone en qué zona estás")

	# Al abrir el juego se empieza siempre en el refugio
	GS.current_map = "bosque"
	GS.save_game({"map": "bosque", "player": [5, 5]})
	GS._launched = false
	GS.load_game()
	check(GS.current_map == "refugio", "al abrir el juego apareces en el refugio")
	GS.current_map = "bosque"
	GS.save_game({"map": "bosque", "player": [5, 5]})
	GS.load_game()
	check(GS.current_map == "bosque", "al viajar sí se carga la zona de destino")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()

	# El APK pide permiso de vibración (sin él, Android cierra el juego al vibrar)
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(presets.contains("permissions/vibrate=true"), "el APK tiene permiso de vibración")
	world.queue_free()
	await _frames(2)


func test_levels_weight() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	GS.forced_rain = 0

	# Curva: rápida al principio, cada vez más cara, hasta el 100
	check(DB.max_level() == 100 and DB.xp_to_next(1) == 30, "del 1 al 2 bastan 30 de experiencia")
	var total := 0
	var to5 := 0
	var rising := true
	for lv in range(1, 100):
		total += DB.xp_to_next(lv)
		if lv == 4:
			to5 = total
		if lv > 1 and (lv + 1) % 10 != 0 and lv % 10 != 0 and DB.xp_to_next(lv) <= DB.xp_to_next(lv - 1):
			rising = false
	check(to5 <= 300, "llegar al nivel 5 cuesta poco (%d XP)" % to5)
	check(rising and total > 1500000, "cada nivel cuesta más y el 100 es muy largo (%d XP)" % total)
	check(DB.xp_to_next(9) < (DB.xp_to_next(8) + DB.xp_to_next(10)) / 2, "los niveles redondos cuestan algo menos")

	# Subir de nivel: cura, desbloquea y da recompensa
	GS.level = 1
	GS.xp = 0
	GS.health = 40.0
	var got: Array = []
	var on_up := func(lv: int, unl: Array, _rw: Dictionary): got.append([lv, unl])
	GS.leveled_up.connect(on_up)
	GS.add_xp(30)
	check(GS.level == 2 and GS.xp == 0 and GS.health == 100.0, "con 30 XP subes al 2 y recuperas la vida")
	check(got.size() == 1 and "Cofre" in got[0][1] and "Garrote" in got[0][1], "al 2 se desbloquean el cofre y el garrote")
	GS.level = 4
	GS.xp = 0
	var cuerdas := GS.count("cuerda")
	GS.add_xp(DB.xp_to_next(4) + DB.xp_to_next(5) + 3)
	check(GS.level == 6 and GS.xp == 3, "mucha XP de golpe sube varios niveles")
	check(GS.count("cuerda") == cuerdas + 3, "el nivel 5 trae recompensa")
	GS.leveled_up.disconnect(on_up)
	check(DB.unlocks_at(3).has("Viaje: Bosque de Pino Negro") and DB.unlocks_at(8).has("Viaje: Cantera de Peñas Rojas"), "los viajes se desbloquean por nivel")
	check(DB.next_unlock_level(25) == 0 or DB.next_unlock_level(25) > 25, "se sabe cuál es el próximo desbloqueo")

	# Bloqueos
	GS.level = 1
	GS.add_item("pico_piedra", 1)
	var world := await _new_world()
	var base: Node3D = world.base
	world.player.global_position = Vector3(30, 0, 30)
	var pp := Vector3(30, 0, 30)
	check(base.check_place("carpinteria", Vector2i(2, 2), 0, pp) == "Se desbloquea en el nivel 3", "la carpintería pide nivel 3")
	_give(DB.station_build_cost("banco_trabajo"))
	var bench: Node3D = _place_any(base, "banco_trabajo", pp)
	check(bench != null, "el banco de trabajo está desde el nivel 1")
	_give(DB.recipe("garrote")["cost"])
	check(bench.start("garrote") == "Se desbloquea en el nivel 2", "el garrote pide nivel 2")
	GS.level = 2
	check(bench.start("garrote") == "", "en el nivel 2 ya se fabrica")
	world.hud.open_station(bench)
	await _pframes(2)
	var locked_btn := false
	for row in world.hud._station_list.get_children():
		for c in row.get_children():
			if c is Button and str(c.text).begins_with("Nivel "):
				locked_btn = true
	check(locked_btn, "las recetas bloqueadas dicen en qué nivel salen")
	world.hud.close_panels()
	_creatures_away()
	check(world.travel_to("bosque") == "Necesitas nivel 3 para ir allí", "al bosque desde el nivel 3")
	GS.level = 8
	GS.remove_item("pico_piedra", GS.count("pico_piedra"))
	check(world.travel_to("cantera").begins_with("Para ir allí necesitas"), "a la cantera hay que llevar un pico")

	# Experiencia por jugar
	GS.level = 10
	GS.xp = 0
	var tree: Node3D = null
	for r in get_tree().get_nodes_in_group("resource"):
		if r.kind.begins_with("pino") or r.kind == "arbol":
			tree = r
			break
	if tree == null:
		tree = get_tree().get_nodes_in_group("resource")[0]
	GS.add_item("hacha_piedra", 1)
	GS.add_item("pico_piedra", 1)
	tree.interact(world.player)
	check(GS.xp > 0, "recoger materiales da experiencia")
	var x0 := GS.xp
	var wolf: Node3D = world.CreatureScript.new()
	wolf.setup("lobo")
	wolf.home = Vector3(40, 0, 40)
	wolf.position = wolf.home
	world.add_child(wolf)
	world._on_creature_killed(wolf)
	check(GS.xp == x0 + 10, "abatir un lobo da 10 de experiencia")
	var x1 := GS.xp
	GS.visit("bosque")
	GS.visit("bosque")
	check(GS.xp == x1 + 40, "la primera visita a una zona da 40 (solo una vez)")
	await _pframes(2)
	check(world.hud._xp_label.text.begins_with("Nivel 10"), "el HUD enseña el nivel y la experiencia")
	world.hud.open_levels()
	await _pframes(2)
	var lines := 0
	for c in world.hud._levels_list.get_children():
		if c is Label and str(c.text).begins_with("Nivel 12"):
			lines += 1
	check(world.hud._levels_panel.visible and lines == 1, "tocando el nivel se ven los próximos desbloqueos")
	world.hud.close_panels()
	GS.add_xp(GS.xp_needed())
	await _pframes(2)
	check(world.hud._levelup.visible and world.hud._levelup_title.text == "¡NIVEL 11!", "aviso grande al subir de nivel")

	# Partidas antiguas sin nivel empiezan en el 12
	var old := GS.to_dict()
	old.erase("level")
	old.erase("xp")
	GS.from_dict(old)
	check(GS.level == 12, "las partidas de antes empiezan en el nivel 12")

	# Peso
	var no_weight := 0
	for id in DB.items:
		if not DB.items[id].has("weight") or float(DB.items[id]["weight"]) <= 0.0:
			no_weight += 1
	check(no_weight == 0, "todos los objetos tienen peso")
	GS.new_game()
	check(is_equal_approx(GS.carry_capacity(), 35.0) and GS.carry_weight() == 0.0, "sin nada encima aguantas 35 kg")
	check(is_equal_approx(GS.speed_factor(), 1.0), "sin carga vas a velocidad normal")
	var light := GS.stamina_drain()
	GS.add_item("piedra", 50)   # 20 kg
	check(is_equal_approx(GS.carry_weight(), 20.0), "50 piedras pesan 20 kg")
	check(GS.speed_factor() < 1.0 and GS.stamina_drain() > light, "con más de media carga vas más lento y te cansas antes")
	GS.add_item("mochila", 1)
	var mi := -1
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "mochila":
			mi = i
	GS.wear_slot(mi)
	check(is_equal_approx(GS.carry_capacity(), 45.0), "la mochila deja llevar 10 kg más")
	GS.add_item("piedra", 100)
	check(GS.overloaded(), "con 150 piedras vas sobrecargado")
	world.player.move_input = Vector2(1, 0)
	world.hud.joystick.value = Vector2(1, 0)
	GS.stamina = GS.max_stamina()
	await _frames(3)
	check(not world.player.running, "sobrecargado no puedes correr")
	world.hud.joystick.value = Vector2.ZERO
	world.player.move_input = Vector2.ZERO
	# Ficha del inventario: peso del objeto y carga total
	world.hud.close_panels()
	world.hud._toggle(world.hud._inv_panel)
	var pi := -1
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "piedra":
			pi = i
			break
	world.hud._inv_panel.select_slot(pi)
	await _pframes(2)
	var inv: Control = world.hud._inv_panel
	check(inv._d_weight.text.contains("0,4 kg"), "junto al nombre sale el peso (%s)" % inv._d_weight.text)
	check(inv.load_label.text.begins_with("Carga total:") and inv.load_label.text.contains("sobrecarga"), "abajo sale la carga total")
	world.hud.close_panels()
	world.queue_free()
	await _frames(2)
	GS.new_game()


func test_animals() -> void:
	GS.new_game()
	var world := await _new_world()
	var player: Node3D = world.player
	player.global_position = Vector3(30, 0, -30)
	var rabbit: Node3D = null
	var boar: Node3D = null
	for c in get_tree().get_nodes_in_group("creature"):
		if c.kind == "conejo" and rabbit == null:
			rabbit = c
		if c.kind == "jabali" and boar == null:
			boar = c
	check(rabbit != null and boar != null, "hay conejos y jabalíes en el mapa")

	rabbit.home = player.global_position + Vector3(3, 0, 0)
	rabbit.global_position = rabbit.home
	await _frames(40)
	var d := rabbit.global_position.distance_to(player.global_position)
	check(d > 4.0, "el conejo huye (%.1f m)" % d)

	rabbit.global_position = player.global_position + Vector3(1, 0, 0)
	rabbit.hp = 1.0
	rabbit.interact(player)
	await _frames(2)
	var meat_bag := false
	for b in get_tree().get_nodes_in_group("bag"):
		for it in b.items:
			if it["id"] == "carne_cruda":
				meat_bag = true
	check(meat_bag, "el conejo deja carne")

	boar.home = player.global_position + Vector3(1.2, 0, 0)
	boar.global_position = boar.home
	var hp0 := GS.health
	await _frames(100)
	check(is_equal_approx(GS.health, hp0), "el jabalí no ataca si no le molestas")
	boar.interact(player)
	await _frames(120)
	check(GS.health < hp0, "el jabalí ataca si le pegas")
	world.queue_free()
	await _frames(2)


func _creatures_away() -> void:
	for c in get_tree().get_nodes_in_group("creature"):
		c.home = Vector3(500, 0, 500)
		c.global_position = Vector3(500, 0, 500)


func test_travel() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	var world := await _new_world()
	_creatures_away()
	GS.add_item("madera", 20)
	var f: Node3D = world.base.place("cimiento", Vector2i(3, 3), 0, 0, Vector3(-5, 0, -5))
	check(f != null, "cimiento antes de viajar")
	check(world.travel_to("marisma") != "", "no se puede ir a zonas que aún no existen")
	var z: Node3D = get_tree().get_nodes_in_group("enemy")[0]
	z.global_position = world.player.global_position + Vector3(3, 0, 0)
	# Mapa antiguo
	var hud: CanvasLayer = world.hud
	hud.map_btn.pressed.emit()
	await _frames(2)
	check(hud._map_panel.visible and hud.map_buttons.size() == DB.world_map.size(), "el mapa muestra un marcador por zona (%d)" % hud.map_buttons.size())
	check(hud._map_area.texture != null, "el mapa usa el papel antiguo")
	for id in DB.world_map:
		check(hud._map_icon(id) != null, "icono de mapa para %s" % id)
	check(hud._map_selected == "refugio" and hud._map_travel.disabled, "empieza marcando dónde estás")
	hud.map_buttons["bosque"].pressed.emit()
	await _frames(2)
	check(hud._map_selected == "bosque" and not hud._map_travel.disabled and hud._map_name.text.contains("Bosque"), "tocar una zona abierta permite viajar")
	hud.map_buttons["central"].pressed.emit()
	await _frames(2)
	check(hud._map_travel.disabled, "a una zona sin explorar no se puede viajar")
	hud.close_panels()
	check(world.travel_to("bosque") != "", "no se puede viajar con enemigos cerca")
	_creatures_away()
	var cost := DB.travel_cost("refugio", "bosque")
	check(world.travel_to("bosque") == "", "viajar al bosque")
	check(is_equal_approx(GS.food, 100.0 - cost["food"]) and is_equal_approx(GS.water, 100.0 - cost["water"]), "el viaje gasta comida y agua")
	check(GS.current_map == "bosque", "la partida queda en el bosque")
	world.queue_free()
	await _frames(3)

	var bosque := await _new_world()
	check(bosque.map_id == "bosque", "carga el Bosque de Pino Negro")
	check(bosque.base == null, "en el bosque no se construye")
	check(bosque.player.global_position.distance_to(bosque.SPAWN) < 0.5, "apareces en la entrada de la zona")
	var kinds := {}
	for c in get_tree().get_nodes_in_group("creature"):
		kinds[c.kind] = true
	check(kinds.has("ciervo") and kinds.has("lobo"), "hay ciervos y lobos en el bosque")
	var setas := 0
	for r in get_tree().get_nodes_in_group("resource"):
		if r.kind == "seta":
			setas += 1
	check(setas > 0, "hay setas en el bosque")
	var boxes := get_tree().get_nodes_in_group("container")
	check(boxes.size() == 2, "cabaña y aserradero tienen contenedores")
	var box: Node3D = boxes[0]
	var full := -1
	for i in box.storage.size():
		if box.storage[i] != null:
			full = i
	check(full >= 0, "el contenedor tiene botín")
	var before := GS.slots.size() - GS.free_slots()
	box.chest_to_bag(full)
	check(GS.slots.size() - GS.free_slots() > before or box.storage[full] == null, "saquear el contenedor")
	bosque.player.global_position = box.global_position + Vector3(1.4, 0, 0)
	await _frames(2)
	check(bosque.find_target() == box, "el contenedor se puede registrar")

	# Morir en una zona: vuelves al refugio y la mochila se queda allí.
	_creatures_away()
	GS.add_item("piedra", 3)
	GS.damage(1000)
	await _frames(2)
	bosque._death_timer = 0.0
	for i in 60:
		if GS.current_map == "refugio":
			break
		await _frames(1)
	check(GS.current_map == "refugio", "al morir fuera reapareces en el refugio")
	var bags: Array = GS.maps_state.get("bosque", {}).get("bags", [])
	var has_pbag := false
	for b in bags:
		if b.get("player", false):
			has_pbag = true
	check(has_pbag, "tu mochila se queda en el bosque")
	bosque.queue_free()
	await _frames(3)

	var home := await _new_world()
	check(home.map_id == "refugio" and home.base.foundations.size() == 1, "el refugio conserva lo construido")
	_creatures_away()
	GS.food = 100.0
	GS.water = 100.0
	GS.add_item("pico_piedra", 1)   # objeto clave para ir a la cantera
	check(home.travel_to("cantera") == "", "viajar a la cantera")
	home.queue_free()
	await _frames(3)

	var cantera := await _new_world()
	check(cantera.map_id == "cantera", "carga la Cantera de Peñas Rojas")
	kinds = {}
	for c in get_tree().get_nodes_in_group("creature"):
		kinds[c.kind] = true
	check(kinds.has("minero") and kinds.has("acorazado") and kinds.has("vibora"), "mineros, acorazados y víboras en la cantera")
	var res := {}
	for r in get_tree().get_nodes_in_group("resource"):
		res[r.kind] = true
	check(res.has("veta_carbon") and res.has("chatarra") and res.has("veta_hierro"), "carbón, chatarra y hierro en la cantera")
	var snake: Node3D = null
	for c in get_tree().get_nodes_in_group("creature"):
		if c.kind == "vibora":
			snake = c
		else:
			c.home = Vector3(500, 0, 500)
			c.global_position = Vector3(500, 0, 500)
	snake.home = cantera.player.global_position + Vector3(0.8, 0, 0)
	snake.global_position = snake.home
	await _frames(40)
	check(GS.poison > 0.0, "la víbora envenena")
	var hp_before := GS.health
	await _frames(30)
	check(GS.health < hp_before, "el veneno quita vida")
	snake.global_position = Vector3(500, 0, 500)
	snake.home = snake.global_position
	GS.add_item("venda", 1)
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "venda":
			GS.use_slot(i)
			break
	check(GS.poison == 0.0, "la venda cura el veneno")

	# Horno con chatarra y carbón
	check(not DB.recipe("lingote_carbon").is_empty() and not DB.recipe("lingote_chatarra").is_empty(), "recetas de horno con carbón y chatarra")
	cantera.queue_free()
	GS.new_game()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	await _frames(2)


func test_character() -> void:
	GS.new_game()
	var looks := 0
	for sex in ["m", "f"]:
		for i in 5:
			var c := CharacterModel.new({"sex": sex, "hair": i, "skin": i, "eyes": i, "nose": i, "mouth": i, "eye_color": i, "hair_color": i})
			add_child(c)
			if c.hand != null and c.get_child_count() > 0:
				looks += 1
			c.queue_free()
	check(looks == 10, "se construyen las 5 variantes de cada rasgo en hombre y mujer")
	var thin := CharacterModel.new({}, {"fuerza": 0.0})
	var strong := CharacterModel.new({}, {"fuerza": 1.0})
	check(strong.dims()["arm"] > thin.dims()["arm"] * 1.3, "la fuerza ensancha los brazos")
	var dressed := CharacterModel.new({"sex": "f"}, {}, {"torso": "chaqueta_piel", "piernas": "pantalon_cargo", "pies": "botas", "cabeza": "gorra", "manos": "guantes", "espalda": "mochila"})
	add_child(dressed)
	var bare := CharacterModel.new({"sex": "f"})
	add_child(bare)
	await _frames(1)
	check(dressed.get_child_count() > 0 and _count_meshes(dressed) > _count_meshes(bare) + 10, "la ropa añade piezas al personaje")
	dressed.animate_walk(1.0, 1.0)
	check(absf(dressed.j["leg_l"].rotation.x) > 0.1, "las piernas se mueven al andar")
	dressed.queue_free()
	bare.queue_free()
	GS.look["sex"] = "f"
	GS.look["hair"] = 3
	GS.add_item("camiseta", 1)
	GS.wear_slot(0)
	GS.created = true
	GS.save_game({})
	GS.new_game()
	check(not GS.created and GS.outfit["torso"] == "", "partida nueva: sin crear y en ropa interior")
	GS.load_game()
	check(GS.look["sex"] == "f" and int(GS.look["hair"]) == 3 and GS.outfit["torso"] == "camiseta", "el aspecto y la ropa se guardan")
	check(GS.created and GS.worn["torso"] != null and GS.worn["torso"].has("dur"), "la prenda puesta se guarda con su estado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	await _frames(2)


func test_survivor() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	# Ropa
	for id in GS.WEAR_SLOTS:
		check(GS.outfit[id] == "", "empieza sin ropa en %s" % id)
	for id in DB.items:
		var it := DB.item(id)
		if str(it.get("type", "")) == "wear":
			check(GS.WEAR_SLOTS.has(str(it.get("slot", ""))), "la prenda %s va en una ranura válida" % id)
			check(CharacterModel.CLOTH.has(str(it.get("model", ""))), "la prenda %s tiene modelo 3D" % id)
	GS.add_item("camiseta", 1)
	GS.add_item("chaleco", 1)
	check(GS.wear_slot(0) and GS.outfit["torso"] == "camiseta" and GS.slots[0] == null, "ponerse la camiseta")
	var i_vest := -1
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "chaleco":
			i_vest = i
	check(GS.wear_slot(i_vest) and GS.outfit["torso"] == "chaleco" and GS.count("camiseta") == 1, "cambiar de prenda devuelve la anterior a la mochila")
	check(is_equal_approx(GS.armor(), 15.0), "el chaleco da defensa (%d%%)" % GS.armor())
	var dur0 := int(GS.worn["torso"]["dur"])
	GS.hit(20.0)
	check(is_equal_approx(GS.health, 83.0), "la defensa reduce el daño (vida %.1f)" % GS.health)
	check(int(GS.worn["torso"]["dur"]) == dur0 - 1, "los golpes desgastan la ropa")
	GS.worn["torso"]["dur"] = 1
	GS.hit(1.0)
	check(GS.worn["torso"] == null and GS.outfit["torso"] == "", "la prenda se rompe al gastarse")
	# Mochila: más huecos
	var base_n := GS.slots.size()
	GS.add_item("mochila", 1)
	var i_bag := -1
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "mochila":
			i_bag = i
	check(GS.wear_slot(i_bag) and GS.slots.size() == base_n + 8, "la mochila da 8 huecos más")
	GS.slots[GS.slots.size() - 1] = GS.make_item("piedra", 5)
	check(not GS.take_off("espalda") and GS.worn["espalda"] != null, "no deja quitarse la mochila con cosas en los huecos extra")
	GS.slots[GS.slots.size() - 1] = null
	check(GS.take_off("espalda") and GS.slots.size() == base_n and GS.count("mochila") == 1, "quitarse la mochila la guarda")
	# Al morir se pierde también la ropa
	GS.add_item("botas", 1)
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "botas":
			GS.wear_slot(i)
	var lost := GS.take_all_items()
	var lost_boots := false
	for it in lost:
		if it["id"] == "botas":
			lost_boots = true
	check(lost_boots and GS.outfit["pies"] == "", "al morir la ropa va a la bolsa y vuelves en ropa interior")

	# Mesa de costura
	check(DB.recipe("chaqueta_piel").get("station", "") == "mesa_costura" and int(DB.recipe("chaqueta_piel")["level"]) == 2, "la chaqueta de piel pide mesa de costura nivel 2")
	var sew_n := 0
	for r in DB.recipes_for("mesa_costura"):
		if str(DB.item(str(r["result"])).get("type", "")) == "wear":
			sew_n += 1
	check(sew_n >= 8, "la mesa de costura cose ropa (%d prendas)" % sew_n)

	# Físico
	GS.new_game()
	var d0 := GS.hand_damage()
	GS.physique["fuerza"] = 1.0
	check(is_equal_approx(GS.hand_damage(), d0 * 1.4), "la fuerza aumenta el daño")
	GS.physique["fuerza"] = 0.0
	var drain_empty := GS.stamina_drain()
	for i in GS.slots.size():
		GS.slots[i] = GS.make_item("piedra", 15)   # 8 x 15 piedras = 48 kg (aguantas 35)
	check(GS.stamina_drain() > drain_empty * 1.6, "correr con la mochila llena cansa más")
	check(GS.speed_factor() < 1.0, "la mochila llena frena")
	var drain_full := GS.stamina_drain()
	GS.physique["resistencia"] = 1.0
	check(GS.stamina_drain() < drain_full * 0.6 and GS.max_stamina() > 150.0, "la resistencia da más aguante")
	GS.new_game()
	GS.exercise("fuerza", 0.1)
	check(float(GS.physique["fuerza"]) > 0.09, "el ejercicio sube la fuerza")
	GS.physique["fuerza"] = 0.0

	# Gimnasio y carrera en el mundo
	var world := await _new_world()
	var player: Node3D = world.player
	GS.add_item("madera", 20)
	GS.add_item("piedra", 12)
	GS.add_item("cuerda", 4)
	var gym: Node3D = world.base.place("gimnasio", Vector2i(-5, -5), 0, 0, player.global_position)
	check(gym != null and gym.is_gym() and gym.action_label() == "Entrenar", "se construye el gimnasio")
	world.hud.open_station(gym)
	await _frames(2)
	check(world.hud._gym_panel.visible, "se abre el panel del gimnasio")
	var food0 := GS.food
	check(world.hud.train("fuerza") == "", "entrenar fuerza")
	check(float(GS.physique["fuerza"]) >= 0.029 and GS.food < food0, "entrenar sube la fuerza y gasta comida")
	check(player.training > 0.0, "el superviviente hace el ejercicio")
	check(GS.train("fuerza", 1) != "", "hay que descansar entre sesiones")
	GS.time_offset += 100.0
	check(GS.train("fuerza", 1) == "", "tras descansar se puede volver a entrenar")
	GS.food = 2.0
	GS.time_offset += 100.0
	check(GS.train("resistencia", 1) != "", "sin comida no se puede entrenar")
	GS.food = 100.0
	await _frames(int(DB.bal("train_seconds", 3.0) * 60.0) + 10)
	player.global_position = Vector3(0, 0, 4)
	var st0 := GS.stamina
	var res0 := float(GS.physique["resistencia"])
	world.hud.joystick.value = Vector2(1, 0)
	await _frames(40)
	check(player.running and GS.stamina < st0, "con el joystick a fondo corre y gasta aguante")
	check(float(GS.physique["resistencia"]) > res0, "correr entrena la resistencia")
	world.hud.joystick.value = Vector2(0.5, 0)
	await _frames(5)
	check(not player.running, "con el joystick a medias anda")
	GS.stamina = 0.0
	world.hud.joystick.value = Vector2(1, 0)
	await _frames(3)
	check(not player.running, "agotado no puede correr")
	world.hud.joystick.value = Vector2.ZERO
	await _frames(60)
	check(GS.stamina > 0.0, "el aguante se recupera descansando")
	# La ropa se ve en el modelo del jugador
	var meshes0 := _count_meshes(player._visual)
	GS.add_item("chaqueta_piel", 1)
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "chaqueta_piel":
			GS.wear_slot(i)
	await _frames(2)
	check(_count_meshes(player._visual) > meshes0 + 3, "la chaqueta aparece en el superviviente")
	world.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()


func test_inventory_screen() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	# Iconos para todo
	var sin_icono := PackedStringArray()
	for id in DB.items:
		if DB.item_icon(id) == null:
			sin_icono.append(id)
	check(sin_icono.is_empty(), "todos los objetos tienen icono %s" % str(sin_icono))
	for sl in ["cabeza", "torso", "piernas", "pies", "manos", "espalda", "arma"]:
		check(DB.ui_icon("slot_" + sl) != null, "silueta del hueco %s" % sl)
	# Bolsillos y niveles de mochila
	check(GS.slots.size() == 8 and GS.bag_level() == 0, "sin mochila hay 8 bolsillos")
	var sizes := []
	for bid in ["mochila", "mochila_excursion", "mochila_tactica"]:
		GS.add_item(bid, 1)
		for i in GS.slots.size():
			if GS.slots[i] != null and GS.slots[i]["id"] == bid:
				GS.wear_slot(i)
				break
		sizes.append([GS.slots.size(), GS.bag_level()])
	check(sizes == [[16, 1], [24, 2], [32, 3]], "lona 16, excursión 24, táctica 32 huecos (%s)" % str(sizes))
	check(int(DB.recipe("mochila_excursion")["cost"].get("mochila", 0)) == 1 and int(DB.recipe("mochila_excursion")["level"]) == 2, "la mochila de excursión se cose con la de lona (costura nv 2)")
	check(int(DB.recipe("mochila_tactica")["level"]) == 3 and DB.station_level("mesa_costura", 3).size() > 0, "la táctica pide mesa de costura nivel 3")

	# Partida antigua con 20 casillas llenas: lo que no cabe queda en una bolsa
	GS.new_game()
	var old_slots: Array = []
	for i in 20:
		old_slots.append({"id": "piedra", "qty": 10 + i})
	var f := FileAccess.open(GS.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "slots": old_slots, "created": true, "maps": {}, "current_map": "refugio"}))
	f = null
	var world := await _new_world()
	check(GS.slots.size() == 8 and GS.free_slots() == 0, "la partida antigua carga 8 objetos en los bolsillos")
	var spill := 0
	for b in get_tree().get_nodes_in_group("bag"):
		if b.is_player_bag and b.global_position.distance_to(world.player.global_position) < 3.0:
			spill += b.items.size()
	check(spill == 12, "los otros 12 quedan en una bolsa al lado (%d)" % spill)

	# Pantalla de inventario
	var hud: CanvasLayer = world.hud
	for i in GS.slots.size():
		GS.slots[i] = null
	GS.add_item("camiseta", 1)
	GS.add_item("madera", 12)
	hud.inv_btn.pressed.emit()
	await _frames(3)
	var inv: Control = hud._inv_panel
	check(inv.visible and inv.tiles.size() == 32, "el botón de la mochila abre el inventario con 32 casillas")
	for k in 3:
		await get_tree().process_frame
	check(not hud.joystick.visible, "con el inventario abierto se oculta el joystick")
	var locked := 0
	for t in inv.tiles:
		if t.modulate.a < 0.9:
			locked += 1
	check(locked == 24, "sin mochila hay 24 casillas bloqueadas (%d)" % locked)
	check(inv.tiles[0].get_meta("icon").texture == DB.item_icon("camiseta"), "las casillas muestran el icono del objeto")
	inv.select_slot(0)
	await _frames(1)
	check(inv.action_buttons.size() == 2 and inv.action_buttons[0].text == "Ponerse", "la ficha ofrece «Ponerse» y «Tirar»")
	inv.action_buttons[0].pressed.emit()
	await _frames(2)
	check(GS.outfit["torso"] == "camiseta", "ponerse la camiseta desde la ficha")
	check(inv.eq_buttons["torso"].get_meta("icon").texture == DB.item_icon("camiseta"), "la camiseta aparece en el hueco del torso")
	inv.select_eq("torso")
	await _frames(1)
	check(inv.action_buttons.size() == 1 and inv.action_buttons[0].text == "Quitar", "en el equipo la ficha ofrece «Quitar»")
	inv.select_slot(20)
	await _frames(1)
	check(inv._d_desc.text.contains("excursión"), "una casilla bloqueada dice qué mochila hace falta")
	check(hud.inv_btn.get_child(0).texture == DB.item_icon("mochila"), "el botón del HUD es el icono de la mochila")
	hud.close_panels()
	for k in 3:
		await get_tree().process_frame
	check(not inv.visible and hud.joystick.visible, "al cerrar vuelve el joystick")
	world.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()


func test_night_stealth() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	# Reloj
	GS.forced_hour = -1.0
	GS.set_hour(3.0)
	check(GS.is_night() and absf(GS.hour() - 3.0) < 0.05, "a las 3 es de noche")
	GS.set_hour(13.0)
	check(not GS.is_night() and is_equal_approx(GS.daylight(), 1.0), "a las 13 es pleno día")
	check(GS.clock_text().length() == 5 and GS.clock_text().begins_with("13:"), "el reloj marca la hora (%s)" % GS.clock_text())
	GS.time_offset = 0.0

	# Noche en el mundo
	GS.forced_hour = 23.0
	var world := await _new_world()
	var player: Node3D = world.player
	world._update_night()
	await _frames(2)
	var night_n := get_tree().get_nodes_in_group("night_spawn").size()
	check(night_n == int(world.map["night"]["count"]), "al caer la noche aparecen infectados (%d)" % night_n)
	world._update_clock()
	check(world.hud._clock_icon.texture == DB.ui_icon("luna"), "de noche el reloj muestra la luna")
	world.daynight.update(0.0, true)
	check(world.daynight.lantern.light_energy > 1.5 and world.daynight.sun.light_energy < 0.3, "de noche el sol se apaga y se enciende la linterna")
	var ns: Node3D = get_tree().get_nodes_in_group("night_spawn")[0]
	ns.global_position = player.global_position + Vector3(1.0, 0, 0)
	world._on_creature_killed(ns)
	await _frames(2)
	check(not is_instance_valid(ns), "los infectados de la noche no reaparecen al morir")
	GS.forced_hour = 12.0
	world._update_night()
	await _frames(2)
	check(get_tree().get_nodes_in_group("night_spawn").is_empty(), "al amanecer se van los infectados lejanos")
	world.daynight.update(0.0, true)
	check(world.daynight.lantern.light_energy < 0.1 and world.daynight.sun.light_energy > 1.0, "de día no hace falta linterna")
	# Lluvia
	GS.forced_rain = 1
	world.daynight.update(0.0, true)
	check(world.daynight.rain.emitting and player.sight_factor() < 1.0, "con lluvia llueve y te ven menos")
	GS.forced_rain = 0
	world.daynight.update(0.0, true)

	# Sigilo
	for c in get_tree().get_nodes_in_group("creature"):
		c.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(0, 0, 0)
	var z: Node3D = world.CreatureScript.new()
	z.setup("infectado")
	z.home = Vector3(6, 0, 0)
	z.position = z.home
	world.add_child(z)
	world.hud.toggle_crouch()
	check(player.crouching and world.hud.crouch_button.text == "De pie", "el botón agacha al superviviente")
	await _frames(10)
	check(not z.aware, "agachado y quieto, el infectado a 6 m no te ve")
	world.hud.joystick.value = Vector2(1, 0)
	await _frames(5)
	check(not player.running, "agachado no se puede correr")
	world.hud.joystick.value = Vector2.ZERO
	await _frames(3)
	player.global_position = Vector3(0, 0, 0)
	z.process_mode = Node.PROCESS_MODE_DISABLED
	z.global_position = Vector3(3.0, 0, 0)
	z._face(Vector3(-1, 0, 0))     # mirándote
	check(z._in_front(player.global_position - z.global_position, 3.0), "de frente, a 3 m agachado te ve")
	z._face(Vector3(1, 0, 0))      # de espaldas
	check(not z._in_front(player.global_position - z.global_position, 3.0), "de espaldas no te ve")
	z.global_position = Vector3(1.6, 0, 0)
	z.process_mode = Node.PROCESS_MODE_INHERIT
	z._wander_timer = 99.0
	z._wander_target = z.global_position
	await _frames(2)
	check(not z.aware, "puedes acercarte por detrás agachado")
	var hp0: float = z.hp
	z.interact(player)
	check(is_equal_approx(hp0 - z.hp, GS.hand_damage() * float(DB.bal("sneak_mult", 3.0))), "golpe por sorpresa agachado: daño x3")
	check(z.aware, "tras el golpe ya sabe dónde estás")
	var hp1: float = z.hp
	z.interact(player)
	check(is_equal_approx(hp1 - z.hp, GS.hand_damage()), "el segundo golpe es normal")
	await _frames(2)
	check(z._bar != null and z._bar.visible, "aparece la barra de vida del enemigo")
	var nums := 0
	for c in z.get_children():
		if c is Label3D:
			nums += 1
	check(nums >= 1, "salen números de daño")
	world.hud.toggle_crouch()
	check(not player.crouching, "el botón vuelve a poner de pie")
	player.make_noise(13.0)
	check(player.noise_radius() >= 13.0, "golpear hace ruido")
	z.queue_free()
	var z2: Node3D = world.CreatureScript.new()
	z2.setup("infectado")
	z2.home = Vector3(11, 0, 0)
	z2.position = z2.home
	world.add_child(z2)
	player.make_noise(13.0)
	await _frames(2)
	check(z2.aware, "a 11 m te oye si haces mucho ruido")
	z2.queue_free()

	# Reparar
	GS.hand = GS.make_item("lanza")
	GS.hand["dur"] = 5
	GS.add_item("chaleco", 1)
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "chaleco":
			GS.wear_slot(i)
	GS.worn["torso"]["dur"] = 20
	GS.add_item("casco_obra", 1)
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "casco_obra":
			GS.slots[i]["dur"] = 40
	var tools: Array = GS.damaged_items("banco_trabajo")
	var cloth: Array = GS.damaged_items("mesa_costura")
	check(tools.size() == 1 and tools[0]["where"] == "hand", "el banco repara el arma de la mano")
	check(cloth.size() == 2, "la mesa de costura repara la ropa puesta y la guardada (%d)" % cloth.size())
	var cost: Dictionary = GS.repair_cost(GS.hand)
	check(not cost.is_empty() and GS.repair(tools[0]) != "", "sin materiales no se repara (%s)" % DB.cost_text(cost))
	for k in cost:
		GS.add_item(str(k), int(cost[k]))
	check(GS.repair(tools[0]) == "" and int(GS.hand["dur"]) == int(DB.item("lanza")["durability"]), "reparar deja el arma como nueva")
	var helmet_ref: Dictionary = {}
	for r in cloth:
		if r["item"]["id"] == "casco_obra":
			helmet_ref = r
	check(not GS.repair_cost(helmet_ref["item"]).is_empty(), "lo que solo se encuentra también tiene coste de reparación")
	GS.hand["dur"] = 3
	for k in {"madera": 15, "piedra": 10, "fibra": 10}:
		GS.add_item(k, 15)
	var bench: Node3D = world.base.place("banco_trabajo", Vector2i(-4, -4), 0, 0, player.global_position)
	world.hud.open_station(bench)
	await _frames(2)
	var rep_btn := false
	for row in world.hud._station_list.get_children():
		for c in row.get_children():
			if c is Button and c.text == "Reparar":
				rep_btn = true
	check(rep_btn, "el panel del banco de trabajo tiene «Reparar»")
	world.hud.close_panels()
	world.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()


## Botón de acción con icono y borde de estado; barras con icono y porcentaje.
func test_action_hud(world: Node3D, player: Node3D, tree: Node3D) -> void:
	var hud: CanvasLayer = world.hud
	var keep: Array = GS.slots.duplicate()
	var keep_hand = GS.hand
	for i in GS.slots.size():
		GS.slots[i] = null
	GS.hand = null
	tree._respawn_timer = 0.0      # por si se agotó al talarlo
	await _pframes(3)
	tree.hits_left = 50
	await _pframes(3)
	check(hud.action_icon == "puno" and hud.action_button.ring < 0.0, "junto al pino sin hacha: puño y sin borde")
	GS.add_item("hacha_piedra", 1)
	GS.add_item("lanza", 1)
	GS.equip_slot(1)
	await _pframes(3)
	check(hud.action_icon == "hacha_piedra" and is_equal_approx(hud.action_button.ring, 1.0), "junto al pino con hacha en el inventario: icono del hacha, borde al 100 %")
	var hits0: int = tree.hits_left
	var lance0 := int(GS.hand["dur"])
	var wood0 := GS.count("madera")
	tree.interact(player)
	check(int(GS.slots[0]["dur"]) == 59 and int(GS.hand["dur"]) == lance0 and GS.count("madera") > wood0, "talar gasta el hacha, no el arma")
	GS.slots[0]["dur"] = 24
	await _pframes(3)
	check(hud.action_button.ring < 0.5 and hud.action_button.ring_color(hud.action_button.ring) == Color("f2c230"), "por debajo del 50 % el borde es amarillo")
	check(hud.action_button.ring_color(0.2) == Color("e0463c") and hud.action_button.ring_color(0.8) == Color("6fd24a"), "rojo por debajo del 25 % y verde por encima del 50 %")
	check(player._hand_item == "hacha_piedra", "el superviviente saca el hacha para talar")
	var pos: Vector3 = player.global_position
	player.global_position = Vector3(0.5, 0, 9.5)
	await _pframes(3)
	if world.find_target() == null:
		check(hud.action_icon == "lanza" and hud.action_button.ring > 0.9, "lejos de todo: icono del arma equipada con su borde")
		check(player._hand_item == "lanza", "y lleva la lanza en la mano")
	GS.unequip()
	await _pframes(3)
	if world.find_target() == null:
		check(hud.action_icon == "puno", "sin arma: puño")
	check(hud.action_button.icon != null and hud.crouch_button.icon == DB.ui_icon("agachar"), "acción y agachar son iconos")
	check(hud.craft_btn.text == "" and hud.craft_btn.icon == DB.ui_icon("fabricar") and hud.map_btn.icon == DB.ui_icon("mapa") and hud.build_btn.icon == DB.ui_icon("construir"), "fabricar, construir y mapa son iconos")
	check(hud.build_btn.visible, "en el refugio se ve el botón de construir")
	GS.food = 50.0
	GS.stats_changed.emit()
	check(hud._pcts["food"].text == "50" and hud._pcts.has("stamina"), "las barras muestran el porcentaje")
	for r in DB.recipes_for(""):
		check(int(r.get("level", 0)) <= 1 and r["cost"].size() <= 2, "a mano solo lo básico: %s" % r["id"])
	player.global_position = pos
	for i in GS.slots.size():
		GS.slots[i] = keep[i]
	GS.hand = keep_hand
	GS.inventory_changed.emit()
	await _pframes(2)


func test_dodge_audio() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	var world := await _new_world()
	var player: Node3D = world.player
	var hud: CanvasLayer = world.hud
	for c in get_tree().get_nodes_in_group("creature"):
		c.process_mode = Node.PROCESS_MODE_DISABLED
	# Esquivar
	player.global_position = Vector3(-6, 0, 13)
	await _frames(3)
	var st0 := GS.stamina
	var x0: float = player.global_position.x
	hud.joystick.value = Vector2(1, 0)
	player.move_input = Vector2(1, 0)
	check(player.dodge(), "esquivar con energía")
	check(GS.stamina < st0 and GS.invulnerable > 0.0, "esquivar gasta energía y te hace intocable un instante")
	var hp0 := GS.health
	GS.hit(30.0)
	check(is_equal_approx(GS.health, hp0), "durante la esquiva no recibes golpes")
	check(not player.dodge(), "no se puede encadenar otra esquiva al momento")
	await _frames(30)
	hud.joystick.value = Vector2.ZERO
	check(player.global_position.x - x0 > 3.0, "la esquiva te desplaza rápido (%.1f m)" % (player.global_position.x - x0))
	check(GS.invulnerable <= 0.0, "tras la esquiva vuelves a ser vulnerable")
	GS.hit(10.0)
	check(GS.health < hp0, "y los golpes vuelven a doler")
	await _frames(40)
	GS.stamina = 5.0
	check(not player.dodge(), "sin energía no se esquiva")
	check(hud.dodge_button.icon == DB.ui_icon("esquivar"), "hay botón de esquivar con icono")
	# Sonido
	for id in ["golpe", "talar", "picar", "recoger", "dano", "romper", "esquivar", "clic", "fabricar", "error", "comer", "beber", "paso", "grunido", "muerte", "viento", "grillos", "lluvia", "musica"]:
		check(SFX._stream(id) != null, "existe el sonido %s" % id)
	check(SFX.played.has("esquivar") and SFX.played.has("dano"), "esquivar y recibir daño suenan")
	SFX.played.clear()
	for r in get_tree().get_nodes_in_group("resource"):
		if r.kind == "pino":
			r.interact(player)
			break
	check(SFX.played.has("talar"), "talar suena")
	hud.settings_btn.pressed.emit()
	await _frames(2)
	check(SFX.played.has("clic") and hud._settings_panel.visible, "los botones hacen clic y se abren los ajustes")
	# Ajustes
	hud.settings_controls["music"].value = 0.0
	hud.settings_controls["sfx"].value = 0.5
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Musica")), "música a 0 la silencia")
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Efectos")) - linear_to_db(0.5)) < 0.1, "el volumen de efectos se aplica")
	hud.settings_controls["vibration"].button_pressed = false
	SFX.settings = {"music": 0.6, "sfx": 0.8, "vibration": true}
	SFX.load_settings()
	check(is_equal_approx(float(SFX.settings["sfx"]), 0.5) and SFX.settings["vibration"] == false, "los ajustes se guardan")
	SFX.set_setting("music", 0.6)
	SFX.set_setting("sfx", 0.8)
	SFX.set_setting("vibration", true)
	for i in GS.slots.size():
		GS.slots[i] = null
	GS.add_item("madera", 7)
	GS.created = true
	hud._newgame_btn.pressed.emit()
	check(GS.count("madera") == 7 and hud._newgame_btn.text.begins_with("¿Seguro"), "partida nueva pide confirmación (%d, %s)" % [GS.count("madera"), hud._newgame_btn.text])
	hud._newgame_btn.pressed.emit()
	check(GS.count("madera") == 0 and not GS.created, "al confirmar se borra la partida")
	world.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SFX.settings_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()


func test_infected() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	var world := await _new_world()
	var player: Node3D = world.player
	for c in get_tree().get_nodes_in_group("creature"):
		c.process_mode = Node.PROCESS_MODE_DISABLED
		c.global_position = Vector3(60, 0, 60)
	var spawn := func(kind: String, pos: Vector3) -> Node3D:
		var z: Node3D = world.CreatureScript.new()
		z.setup(kind)
		z.home = pos
		z.position = pos
		world.add_child(z)
		return z
	for kind in ["infectado", "corredora", "acorazado", "minero"]:
		check(Infected.has(kind) and DB.creatures[kind].has("ability"), "%s tiene modelo y habilidad descrita" % kind)
	check(float(DB.creatures["acorazado"]["health"]) > 3.0 * float(DB.creatures["infectado"]["health"]) and float(DB.creatures["corredora"]["health"]) < float(DB.creatures["infectado"]["health"]), "el hinchado aguanta mucho y la corredora poco")
	check(float(DB.creatures["corredora"]["speed"]) > float(DB.bal("player_speed", 4.5)) and float(DB.creatures["corredora"]["speed"]) < float(DB.bal("player_speed", 4.5)) * float(DB.bal("run_mult", 1.5)), "la corredora te alcanza andando pero no corriendo")
	# Modelo con el cuerpo del superviviente, animado
	player.global_position = Vector3(0, 0, 10)
	var z1: Node3D = spawn.call("infectado", Vector3(3, 0, 10))
	var z2: Node3D = spawn.call("infectado", Vector3(6, 0, 13))
	var far: Node3D = spawn.call("infectado", Vector3(3, 0, 30))
	z2._face(Vector3(1, 0, 0))    # de espaldas: no te ve
	z1._face(Vector3(-1, 0, 0))
	await _frames(6)
	check(z1._model != null and not z1._model.j.is_empty() and z1._model.j["spine"].has_meta("dressed"), "el infectado usa el cuerpo facetado con sus manchas")
	check(absf(z1._model.j["arm_l"].rotation.x) > 1.0, "anda con los brazos al frente")
	check(z1.aware and z2.aware and not far.aware, "da la alarma a los que tiene cerca, no a los lejanos")
	for z in [z1, z2, far]:
		z.queue_free()
	# Hinchado: empujón y sorpresa reducida
	await _frames(2)
	player.global_position = Vector3(0, 0, 10)
	GS.health = 100.0
	var h: Node3D = spawn.call("acorazado", Vector3(1.2, 0, 10))
	h.process_mode = Node.PROCESS_MODE_DISABLED
	world.hud.toggle_crouch()
	var hp0: float = h.hp
	h.interact(player)
	check(is_equal_approx(hp0 - h.hp, GS.hand_damage() * 1.5), "al hinchado el golpe por sorpresa solo le hace x1,5")
	world.hud.toggle_crouch()
	h._player = player
	h._attack()
	check(GS.health <= 80.5, "el hinchado pega fuerte (vida %d)" % GS.health)
	var x0: float = player.global_position.x
	await _frames(12)
	check(player.global_position.x < x0 - 0.8, "y te lanza hacia atrás (%.1f m)" % (x0 - player.global_position.x))
	# Esquivar su golpe
	GS.health = 100.0
	GS.invulnerable = 0.3
	h._attack()
	check(is_equal_approx(GS.health, 100.0), "si esquivas, el golpe no te alcanza")
	GS.invulnerable = 0.0
	h.queue_free()
	# Corredora: embiste
	player.global_position = Vector3(0, 0, 10)
	var r: Node3D = spawn.call("corredora", Vector3(5, 0, 10))
	r._face(Vector3(-1, 0, 0))
	await _frames(8)
	check(r.aware and r._lunge_cd > 0.0 and r.velocity.length() > float(DB.creatures["corredora"]["speed"]) * 1.2, "la corredora embiste al acercarse (%.1f m/s)" % r.velocity.length())
	r.queue_free()
	# --- Gritona: llama a los infectados lejanos y no ataca
	player.global_position = Vector3(0, 0, 10)
	GS.health = 100.0
	var g: Node3D = spawn.call("gritona", Vector3(8, 0, 10))
	g._face(Vector3(-1, 0, 0))
	var lejos: Node3D = spawn.call("infectado", Vector3(24, 0, 10))
	lejos._face(Vector3(1, 0, 0))
	await _frames(6)
	check(g.aware and SFX.played.has("grito"), "la gritona te ve y grita")
	check(lejos.aware and lejos._called > 0.0, "su grito llama a un infectado a 16 m que no te veía")
	lejos.process_mode = Node.PROCESS_MODE_DISABLED
	g.global_position = Vector3(3, 0, 10)
	for k in 110:
		await get_tree().physics_frame
	check(g.global_position.distance_to(player.global_position) > 3.2, "si te acercas, la gritona se aleja")
	check(is_equal_approx(GS.health, 100.0), "la gritona no hace daño")
	for z in [g, lejos]:
		z.queue_free()
	# --- Acechador: invisible de noche y salto con daño doble
	GS.forced_hour = 23.0
	var a: Node3D = spawn.call("acechador", Vector3(14, 0, 10))
	a.process_mode = Node.PROCESS_MODE_DISABLED
	a.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(3)
	check(not a._visual.visible and a.visible, "de noche el acechador no se ve de lejos")
	a.global_position = Vector3(4.5, 0, 10)
	a.aware = true
	a._face(Vector3(-1, 0, 0))
	GS.health = 100.0
	for k in 30:
		await get_tree().physics_frame
		if GS.health < 100.0:
			break
	check(a._visual.visible, "cerca sí se le ve")
	check(absf(GS.health - (100.0 - 2.0 * float(DB.creatures["acechador"]["attack_damage"]))) < 0.6, "su salto hace daño doble (vida %d)" % GS.health)
	a.queue_free()
	GS.forced_hour = 12.0
	# --- Purulento: revienta en una nube de veneno
	GS.poison = 0.0
	var pu: Node3D = spawn.call("purulento", Vector3(1.5, 0, 10))
	pu.process_mode = Node.PROCESS_MODE_DISABLED
	pu.hp = 1.0
	pu.interact(player)
	await _frames(2)
	check(get_tree().get_nodes_in_group("hazard").size() == 1 and GS.poison > 0.0, "el purulento revienta y te envenena si estás cerca")
	for hz in get_tree().get_nodes_in_group("hazard"):
		hz.queue_free()
	pu.queue_free()
	GS.poison = 0.0
	# --- Blindado: de frente casi no le haces nada, por la espalda sí
	var b: Node3D = spawn.call("blindado", Vector3(1.5, 0, 10))
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.aware = true
	b._face(Vector3(-1, 0, 0))
	var bh: float = b.hp
	b.interact(player)
	check(is_equal_approx(bh - b.hp, GS.hand_damage() * 0.3), "de frente el blindado recibe un 70 % menos")
	b._face(Vector3(1, 0, 0))
	bh = b.hp
	b.interact(player)
	check(is_equal_approx(bh - b.hp, GS.hand_damage()), "por la espalda recibe el daño completo")
	b.queue_free()
	# --- Coloso: pisotón con aviso y rocas a distancia
	await _frames(2)
	GS.health = 100.0
	var co: Node3D = spawn.call("coloso", Vector3(3.0, 0, 10))
	co.aware = true
	co._face(Vector3(-1, 0, 0))
	await _frames(3)
	var rings := 0
	for hz in get_tree().get_nodes_in_group("hazard"):
		if hz.mode == "stomp":
			rings += 1
	check(rings == 1, "el pisotón avisa con un círculo rojo")
	GS.invulnerable = 0.0
	for k in 70:
		await get_tree().physics_frame
		if GS.health < 100.0:
			break
	check(GS.health <= 75.5 and SFX.played.has("pisoton"), "el pisotón hace daño en área (vida %d)" % GS.health)
	co._special_cd = 99.0
	co._attack_cd = 99.0
	co.global_position = Vector3(12, 0, 10)
	co._throw_cd = 0.0
	GS.health = 100.0
	var thrown := false
	for k in 40:
		await get_tree().physics_frame
		for hz in get_tree().get_nodes_in_group("hazard"):
			if hz.mode == "rock":
				thrown = true
		if thrown:
			break
	check(thrown, "a distancia lanza rocas")
	for k in 90:
		await get_tree().physics_frame
		if GS.health < 100.0:
			break
	check(is_equal_approx(GS.health, 100.0 - float(DB.creatures["coloso"]["throw_damage"])), "si no te apartas, la roca te da (vida %d)" % GS.health)
	check(co._bar != null and co._bar.visible, "el jefe muestra su barra de vida")
	co.queue_free()
	for hz in get_tree().get_nodes_in_group("hazard"):
		hz.queue_free()
	# Reparto por zonas
	var where := {}
	for m in DB.maps:
		for gr in DB.maps[m].get("creatures", []):
			where[str(gr["type"])] = true
	for kind in ["gritona", "acechador", "purulento", "blindado", "coloso"]:
		check(where.has(kind) and Infected.has(kind), "%s aparece en alguna zona y tiene modelo" % kind)
	check(not DB.creatures.has("escupidor"), "no hay escupidor")
	# Árboles y rocas nuevos
	var meshes := 0
	for res in get_tree().get_nodes_in_group("resource"):
		if res.kind == "pino" or res.kind == "roca":
			meshes += _count_meshes(res._visual)
			break
	check(meshes >= 3, "los pinos y rocas usan los modelos facetados")
	world.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()


func test_creator() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	GS.testing = false
	var world := await _new_world()
	check(world.creator != null and get_tree().paused, "el primer arranque abre la creación de personaje y pausa el juego")
	var cr: CanvasLayer = world.creator
	cr.set_sex("f")
	cr.select_cat("pelo")
	cr.pick(3)
	cr.select_cat("nariz")
	cr.pick(2)
	await _frames(2)
	check(cr._tiles.get_child_count() >= 5, "se muestran las 5 opciones")
	check(cr.model != null and str(cr.model.look["sex"]) == "f" and int(cr.model.look["hair"]) == 3, "la vista previa cambia al elegir")
	cr.name_edit.text = "Lucía"
	# Pulsar «Empezar» con un toque real
	var b: Button = cr.start_button
	var center: Vector2 = get_tree().root.get_final_transform() * (b.get_global_transform_with_canvas() * (b.size / 2.0))
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = center
		ev.global_position = center
		ev.pressed = pressed
		Input.parse_input_event(ev)
		# fotogramas de proceso: tras uno lento, varios de física pasan antes de leer la entrada
		for k in 3:
			await get_tree().process_frame
	check(GS.created and str(GS.look["sex"]) == "f" and int(GS.look["nose"]) == 2 and GS.player_name == "Lucía", "«Empezar» guarda el personaje")
	check(not get_tree().paused and world.creator == null, "el juego arranca tras crear el personaje")
	check(str(world.player._visual.look["sex"]) == "f", "el jugador tiene el aspecto elegido")
	world.queue_free()
	await _frames(2)
	GS.load_game()
	check(GS.created and GS.player_name == "Lucía", "el personaje creado queda guardado")
	world = await _new_world()
	check(world.creator == null, "la segunda vez no vuelve a pedir crear personaje")
	world.queue_free()
	await _frames(2)
	GS.testing = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()


func _count_meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += _count_meshes(ch)
	return c
