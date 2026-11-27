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
	print("== Cocina, destilería, química, electrónica, molotov y trampas")
	await test_new_stations()
	print("== Recolectar con herramienta, comida que caduca, desplazar listas y ventanas")
	await test_fixes()
	print("== Caminos entre zonas (tramos)")
	await test_routes()
	print("== Fase 1 del mapa: Arboleda, Pedregal, piezas y caminos a pie")
	await test_phase1()
	print("== Niveles y peso")
	await test_levels_weight()
	await test_crafting_tree()
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

	# Recolectar de un árbol (en el refugio hay árboles pequeños: madera básica).
	var tree: Node3D = null
	for r in get_tree().get_nodes_in_group("resource"):
		if r.kind == "arbol":
			tree = r
			break
	player.global_position = tree.global_position + Vector3(1.2, 0, 0)
	await _frames(3)
	check(world.find_target() == tree, "detecta el pino como objetivo")
	# Sin hacha no se tala (el botón lo dice); las ramas del suelo sí se recogen a mano
	player.action_held = true
	await _frames(50)
	player.action_held = false
	check(GS.count("madera") == 0 and tree.action_label() == "Necesitas hacha", "sin hacha el pino no da madera")
	var twigs: Node3D = null
	for r in get_tree().get_nodes_in_group("resource"):
		if r.kind == "ramas" and twigs == null:
			twigs = r
	twigs.interact(player)
	check(GS.count("madera") > 0, "las ramas secas dan madera a mano")
	GS.remove_item("madera", GS.count("madera"))
	GS.add_item("hacha_piedra", 1)
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
	await _pframes(2)
	check(btn.held, "el botón de acción responde al toque")
	var up := InputEventScreenTouch.new()
	up.index = 3
	up.position = center
	up.pressed = false
	Input.parse_input_event(up)
	await _pframes(2)   # el evento se procesa en un fotograma de dibujo, no de física
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
	await _pframes(4)
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
	GS.add_item("mango", 3)
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
	GS.remove_item("mango", GS.count("mango"))
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
	var fmsg: String = fire.start("carne_asada") if fire else "sin hoguera"
	check(fmsg == "", "la hoguera cocina carne (%s)" % fmsg)
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
	await _pframes(2)
	var scr: Control = world.hud._station_panel
	var add_btn: Button = scr.action_btn
	check(scr.selected == 1 and add_btn.text == "AÑADIR" and add_btn.disabled, "el panel muestra la siguiente fase con su botón")
	check(scr._title.text == "GENERADOR" and scr._level_label.text == "En obra 1/3", "cabecera de la obra")
	_give(DB.station_phases("generador")[1]["cost"])
	world.hud._refresh_station()
	await _pframes(1)
	check(not add_btn.disabled, "con materiales se puede añadir")
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


func _slot_of(id: String) -> int:
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == id:
			return i
	return -1


func _build_full(base: Node3D, id: String, pp: Vector3) -> Node3D:
	for ph in DB.station_phases(id):
		_give(ph["cost"])
	if DB.station_phases(id).is_empty():
		_give(DB.station_build_cost(id))
	var st: Node3D = _place_any(base, id, pp)
	while st != null and not st.is_built():
		st.add_phase()
	return st


func _make(st: Node3D, rid: String, n := 1) -> bool:
	var r := DB.recipe(rid)
	_give(Dictionary(st.cost_times(r, n)))
	var why: String = st.start(rid, n)
	if why != "":
		printerr("    ", rid, ": ", why)
		return false
	GS.time_offset += st.recipe_time(r) * n + 1.0
	return st.collect()


func test_new_stations() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	GS.forced_rain = 0
	var world := await _new_world()
	var base: Node3D = world.base
	var pp := Vector3(30, 0, 30)
	world.player.global_position = pp
	GS.slots.resize(48)
	for i in GS.slots.size():
		GS.slots[i] = null

	# Datos, modelos e iconos
	for id in ["cocina", "destileria", "mesa_quimica", "banco_electronica"]:
		check(DB.stations.has(id) and DB.recipes_for(id).size() >= 3, "estación %s con recetas" % id)
		var m := StationModels.make(id, 1)
		check(m != null and m.get_child_count() >= 6, "modelo 3D de %s" % id)
		if m:
			m.free()
		check(ResourceLoader.exists("res://assets/icons/estaciones/%s.png" % id), "icono de cabecera de %s" % id)
	for id in ["plato_cocinado", "conserva_carne", "agua_hervida", "guiso_setas", "agua_purificada", "alcohol", "combustible", "agua_sucia", "estimulante", "vendas_avanzadas", "circuito_avanzado", "molotov", "cantimplora", "trampa_pinchos"]:
		check(DB.item_icon(id) != null and DB.item_icon(id).resource_path.ends_with(".png"), "icono de %s sacado del diseño" % id)
	for rid in ["molotov", "cantimplora", "trampa_pinchos"]:
		check(DB.recipe(rid).get("station", "") != "", "%s ya se fabrica en un banco (%s)" % [rid, DB.recipe(rid).get("station", "")])

	# Cocina de campo: necesita fuego
	var stove := _build_full(base, "cocina", pp)
	check(stove != null and stove.is_built() and stove.burns(), "cocina de campo colocada (arde con leña)")
	_give(DB.recipe("plato_cocinado")["cost"])
	check(stove.start("plato_cocinado").begins_with("Echa leña"), "sin fuego no cocina")
	GS.add_item("madera", 1)
	check(stove.add_fuel("madera") == "" and int(stove.fuel) == 60, "un tronco da un minuto de fuego")
	check(stove.add_fuel("piedra") == "Eso no sirve de combustible", "la piedra no arde")
	check(stove.start("plato_cocinado") == "" and int(stove.fuel) == 50, "cocinar gasta el fuego que dura")
	GS.time_offset += 11.0
	check(stove.collect() and GS.count("plato_cocinado") == 1, "plato cocinado listo")
	world.hud.open_station(stove)
	await _pframes(2)
	var scr: Control = world.hud._station_panel
	check(scr.tabs == ["Platos", "Conservas", "Agua", "Fuego"], "pestañas de la cocina como en el diseño %s" % str(scr.tabs))
	check(scr._energy_bar.visible and scr._energy_icon.texture.resource_path.ends_with("llama.png") and scr._energy_text.text == "%d/100" % roundi(100.0 * 50.0 / 1800.0), "barra de energía = fuego de la cocina")
	scr.tab = "Fuego"
	scr.refresh()
	GS.add_item("carbon", 2)
	scr._select(1)
	check(scr.entries[1]["id"] == "carbon" and scr.action_btn.text == "ECHAR", "pestaña Fuego: echar carbón")
	scr.set_qty(2)
	scr.action_btn.pressed.emit()
	check(int(stove.fuel) == 50 + 360 and GS.count("carbon") == 0, "echar 2 carbones de una vez")
	world.hud.close_panels()

	# Agua: botellas, beber sucia, hervir, cantimplora
	var col := _build_full(base, "recolector_agua", pp)
	col.water = 35.0
	col.water_t = GS.now()
	GS.add_item("botella_vacia", 5)
	check(col.fill_bottles(5) == "" and GS.count("agua_sucia") == 3 and GS.count("botella_vacia") == 2, "el recolector llena tantas botellas como agua tenga (3)")
	world.hud.open_station(col)
	await _pframes(1)
	check(scr.entries.size() == 2 and scr.entries[1]["kind"] == "fill", "el recolector tiene Llenar botellas")
	world.hud.close_panels()
	GS.water = 40.0
	GS.health = 100.0
	GS.use_slot(_slot_of("agua_sucia"))
	check(GS.water >= 54.0 and GS.health < 100.0 and GS.count("botella_vacia") == 3, "el agua sucia quita sed, sienta mal y deja la botella")
	check(_make(stove, "agua_hervida") and GS.count("agua_hervida") == 1, "hervir agua en la cocina")
	check(_make(stove, "cantimplora_vacia") and _make(stove, "cantimplora") and GS.count("cantimplora") == 1, "cantimplora hecha y llena en la cocina")
	GS.water = 20.0
	var empties := GS.count("cantimplora_vacia")
	GS.use_slot(_slot_of("cantimplora"))
	check(GS.water >= 79.0 and GS.count("cantimplora") == 0 and GS.count("cantimplora_vacia") == empties + 1, "beber de la cantimplora la deja vacía para rellenarla")

	# Destilería: agua purificada, alcohol; combustible en el nivel 2
	var still := _build_full(base, "destileria", pp)
	GS.add_item("madera", 20)
	for i in 20:
		still.add_fuel("madera")
	check(_make(still, "agua_purificada") and _make(still, "alcohol"), "destilería: agua purificada y alcohol")
	_give(DB.recipe("combustible")["cost"])
	check(still.start("combustible") == "Mejora la estación a nivel 2", "el combustible pide la destilería de nivel 2")
	still.set_level(2)
	check(_make(still, "combustible") and GS.count("combustible") == 1, "destilería nivel 2: combustible")

	# Mesa química y banco de electrónica: necesitan el generador
	var lab := _build_full(base, "mesa_quimica", pp)
	_give(DB.recipe("molotov")["cost"])
	check(lab.start("molotov") == "Necesita un generador terminado", "la mesa química necesita generador")
	var gen := _build_full(base, "generador", pp)
	GS.add_item("combustible", 1)
	check(gen.add_fuel("combustible") == "" and int(gen.fuel) == 1200, "el combustible da 20 minutos al generador")
	check(_make(lab, "molotov", 3) and GS.count("molotov") == 3, "tres cócteles molotov")
	check(_make(lab, "vendas_avanzadas") and _make(lab, "estimulante") and _make(lab, "acido"), "vendas avanzadas, estimulante y ácido")
	GS.stamina = 5.0
	GS.use_slot(_slot_of("estimulante"))
	check(is_equal_approx(GS.stamina, GS.max_stamina()), "el estimulante devuelve toda la energía")
	var elec := _build_full(base, "banco_electronica", pp)
	check(elec != null and elec.is_built() and elec.phases().size() == 3, "banco de electrónica en 3 fases")
	check(_make(elec, "cable_cobre") and GS.count("cable_cobre") == 4 and _make(elec, "circuito") and _make(elec, "bateria"), "cable, circuito y batería")
	world.hud.open_station(lab)
	await _pframes(1)
	check(scr.tabs == ["Medicamentos", "Explosivos", "Alquimia"] and scr._energy_icon.texture.resource_path.ends_with("bateria.png"), "pestañas de la mesa química y energía del generador")
	world.hud.close_panels()

	# Molotov: se equipa y se lanza al enemigo más cercano a tiro
	var player: Node3D = world.player
	player.global_position = Vector3(-30, 0, -30)
	player.floor_y = 0.0
	var z: Node3D = world.CreatureScript.new()
	z.setup("infectado")
	z.home = player.global_position + Vector3(7, 0, 0)
	z.position = z.home
	world.add_child(z)
	z.set_physics_process(false)
	await _frames(2)
	GS.equip_slot(_slot_of("molotov"))
	check(GS.hand_throws() and int(GS.hand["qty"]) == 3, "molotov en la mano (3)")
	check(world.find_target() == z and z.action_label() == "Lanzar", "a 7 m el botón apunta al infectado: Lanzar")
	var fire: Node3D = world.throw_at(z)
	check(fire != null and int(GS.hand["qty"]) == 2, "lanzar gasta un molotov")
	fire.ignite()
	var hp0: float = z.hp
	var hit: int = fire.burn(7.0)
	check(hit == 1 and z.hp < hp0, "el fuego quema al infectado (%d -> %d)" % [int(hp0), int(z.hp)])
	var ph := GS.health
	fire.burn(7.0)
	check(GS.health == ph, "el fuego no te quema a ti")
	z.hp = 1.0
	fire.burn(7.0)
	check(z.hp <= 0.0, "el fuego puede matar")
	fire.queue_free()
	GS.unequip()

	# Trampa de pinchos: se coloca, hiere y se recoge
	var carp := _build_full(base, "carpinteria", pp)
	check(_make(carp, "trampa_pinchos"), "trampa fabricada en la carpintería")
	player.global_position = Vector3(-30, 0, -30)
	check(world.place_trap(_slot_of("trampa_pinchos")) == "" and GS.count("trampa_pinchos") == 0, "Colocar: la trampa sale del inventario")
	var traps := get_tree().get_nodes_in_group("trap")
	check(traps.size() == 1, "la trampa está en el suelo")
	var trap: Node3D = traps[0]
	var z2: Node3D = world.CreatureScript.new()
	z2.setup("infectado")
	z2.home = trap.global_position
	z2.position = trap.global_position
	world.add_child(z2)
	z2.set_physics_process(false)
	await _frames(2)
	trap.check_creatures()
	check(is_equal_approx(z2.hp, float(DB.creature("infectado")["health"]) - 40.0) and trap.uses == 3, "pisarla hace 40 y gasta un golpe")
	trap.check_creatures()
	check(trap.uses == 3, "no pincha dos veces seguidas a la misma criatura")
	var saved: Array = world.world_dict().get("traps", [])
	check(saved.size() == 1 and int(saved[0]["uses"]) == 3, "las trampas se guardan con sus golpes")
	z2.queue_free()
	await _frames(1)
	trap.interact(player)
	check(GS.count("trampa_pinchos") == 1 and int(GS.slots[_slot_of("trampa_pinchos")]["dur"]) == 3, "recogerla devuelve la trampa con los golpes que le quedan")
	world.queue_free()
	await _frames(2)


func _touch(idx: int, canvas_pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = get_tree().root.get_final_transform() * canvas_pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(idx: int, canvas_pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = idx
	ev.position = get_tree().root.get_final_transform() * canvas_pos
	ev.relative = get_tree().root.get_final_transform().basis_xform(rel)
	Input.parse_input_event(ev)


func test_fixes() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	GS.forced_rain = 0
	var world := await _new_world()
	var player: Node3D = world.player
	GS.slots.resize(48)
	for i in GS.slots.size():
		GS.slots[i] = null
	GS.hand = null

	# Movimiento suave: interpolación de física en el jugador y las criaturas, la cámara sigue la posición dibujada
	check(bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)), "interpolación de física activada (sin tirones)")
	check(player.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON and world.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "se interpola el jugador; la cámara y la interfaz no")
	var some_creature: Node = get_tree().get_nodes_in_group("creature")[0]
	check(some_creature.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON, "las criaturas también se mueven suaves")

	# Recolectar: cada recurso con su herramienta (y su icono)
	var rock: Node3D = null
	var stones: Node3D = null
	for r in get_tree().get_nodes_in_group("resource"):
		if r.kind == "roca" and rock == null:
			rock = r
		if r.kind == "piedras" and stones == null:
			stones = r
	check(rock != null and stones != null, "hay rocas y piedras sueltas en el refugio")
	player.global_position = rock.global_position + Vector3(float(rock.data.get("radius", 0.0)) + 1.0, 0, 0)
	await _frames(3)
	player.target = rock
	var info: Dictionary = player.action_info()
	check(info["icon"] == "pico_piedra" and info.get("missing", false), "junto a una roca sin pico sale el pico en gris")
	rock.interact(player)
	check(GS.count("piedra") == 0 and rock.action_label() == "Necesitas pico", "sin pico la roca no da piedra")
	stones.interact(player)
	check(GS.count("piedra") > 0, "las piedras sueltas se recogen a mano")
	GS.add_item("pico_piedra", 1)
	info = player.action_info()
	check(info["icon"] == "pico_piedra" and not info.get("missing", false), "con pico: icono del pico")
	var p0 := GS.count("piedra")
	rock.interact(player)
	check(GS.count("piedra") > p0, "con pico la roca da piedra")
	var bush: Node3D = null
	for r in get_tree().get_nodes_in_group("resource"):
		if r.kind == "arbusto":
			bush = r
			break
	player.target = bush
	check(player.action_info()["icon"] == "mano", "en un arbusto se recoge con la mano")
	player.target = null

	# Comida que caduca; las conservas no
	GS.add_item("carne_cruda", 2)
	var meat: Dictionary = GS.slots[_slot_of("carne_cruda")]
	var life := float(DB.item("carne_cruda")["spoil"])
	check(meat.has("rot") and is_equal_approx(life, 48.0 * 3600.0) and absf(GS.spoil_left(meat) - life) < 5.0, "la carne cruda aguanta 48 h reales")
	var days := {"carne_asada": 72.0 / 24.0, "guiso_setas": 5.0, "plato_cocinado": 5.0, "baya": 5.0, "seta": 5.0, "carne_seca": 7.0}
	var bad_days := []
	for id in days:
		if not is_equal_approx(float(DB.item(id)["spoil"]), days[id] * 86400.0):
			bad_days.append(id)
	check(bad_days.is_empty(), "asada 72 h, guiso y plato 5 días, bayas y setas 5 días, carne seca 7 días %s" % str(bad_days))
	GS.time_offset += life / 2.0
	GS.add_item("carne_cruda", 1)
	check(GS.count("carne_cruda") == 3 and absf(GS.spoil_left(GS.slots[_slot_of("carne_cruda")]) - life / 2.0) < 5.0, "al juntarla se queda la fecha de la más vieja")
	GS.add_item("conserva_carne", 1)
	check(not GS.slots[_slot_of("conserva_carne")].has("rot"), "la conserva no caduca")
	GS.time_offset += life / 2.0 + 1.0
	GS._spoil_timer = 0.0
	GS.tick(0.01)
	check(GS.count("carne_cruda") == 0 and GS.count("comida_podrida") == 3 and GS.count("conserva_carne") == 1, "pasadas las 48 h, la carne se pudre; la conserva sigue")
	var hp := GS.health
	GS.use_slot(_slot_of("comida_podrida"))
	check(GS.health < hp, "comer comida podrida sienta mal")
	var chest := {"storage": [{"id": "baya", "qty": 3, "rot": GS.now() - 1.0}, {"id": "conserva_bayas", "qty": 1}, null]}
	GS.spoil(chest["storage"])
	check(chest["storage"][0]["id"] == "comida_podrida" and chest["storage"][1]["id"] == "conserva_bayas", "en los cofres también se estropea")

	# Conservas en la cocina: lata con sal o tarro esterilizado
	var base: Node3D = world.base
	var pp := Vector3(30, 0, 30)
	player.global_position = pp
	var stove := _build_full(base, "cocina", pp)
	stove.fuel = 1800.0
	check(_make(stove, "sal") and GS.count("sal") == 1, "la sal sale de hervir agua sucia")
	check(_make(stove, "tarro_esterilizado") and _make(stove, "conserva_carne_tarro") and GS.count("conserva_carne") >= 2, "conserva de carne en tarro esterilizado")
	check(DB.recipe("conserva_carne")["cost"].has("sal") and DB.recipe("conserva_bayas")["cost"].has("sal"), "las latas piden sal como conservante")
	world.hud.open_station(stove)
	await _pframes(1)
	var scr: Control = world.hud._station_panel
	scr.tab = "Conservas"
	scr.refresh()
	check(scr.entries.size() == 6, "pestaña Conservas: 2 latas, sal, tarro y 2 tarros (%d)" % scr.entries.size())
	world.hud.close_panels()

	# Ventanas: con cualquiera abierta no se ven los controles ni se puede usar la acción
	var box := _build_full(base, "cofre", pp)
	world.hud.open_station(box)
	world.hud.action_button.held = true
	await _pframes(2)
	check(not world.hud.action_button.visible and not world.hud.action_button.held and not player.action_held, "con el cofre abierto el botón de acción se oculta y se suelta")
	var cp: Control = world.hud._chest_panel
	# centrada en 1280x720 empieza en y = 60: cabe si no pasa de 660 de alto
	check(cp.size.y <= 660.0 and cp.size.x <= 1200.0, "la ventana del cofre (con 48 huecos) cabe en la pantalla (%s)" % str(cp.size))
	world._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not world.hud.any_panel_open(), "el botón Atrás de Android cierra la ventana")
	check(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)), "Atrás no cierra el juego de golpe")

	# Fabricación: la pestaña Todo se desplaza arrastrando con el dedo
	world.hud.craft_btn.pressed.emit()
	await _pframes(3)
	var cs: Control = world.hud._craft_panel
	cs.ctab = "Todo"
	cs.sel = 0
	cs.refresh()
	await _pframes(2)
	var sc: ScrollContainer = cs._gscroll
	check(sc.get_v_scroll_bar().max_value > sc.size.y + 100.0, "en Todo hay más tarjetas de las que caben")
	var at: Vector2 = sc.get_global_transform_with_canvas() * Vector2(200, 400)
	_touch(5, at, true)
	await _pframes(1)
	for k in 10:
		_drag(5, at + Vector2(0, -30 * (k + 1)), Vector2(0, -30))
		await _pframes(1)
	_touch(5, at + Vector2(0, -300), false)
	await _pframes(2)
	check(sc.scroll_vertical >= 250, "arrastrar hacia arriba baja la lista (%d)" % sc.scroll_vertical)
	check(cs.sel == 0 and cs.dragged, "arrastrar no cuenta como tocar una tarjeta")
	_touch(5, at, true)
	await _pframes(1)
	_drag(5, at + Vector2(0, 300), Vector2(0, 300))
	await _pframes(1)
	_touch(5, at + Vector2(0, 300), false)
	await _pframes(2)
	check(sc.scroll_vertical <= 5, "y hacia abajo vuelve arriba (%d)" % sc.scroll_vertical)
	world.hud.close_panels()

	# Compostadora (diseño docs/diseno_est_compostadora.jpg): comida podrida -> compost, abono, humus, tierra
	check(DB.stations.has("compostadora") and ResourceLoader.exists("res://assets/icons/estaciones/compostadora.png"), "compostadora con su icono")
	var cm := StationModels.make("compostadora", 1)
	check(cm != null and cm.get_child_count() >= 6, "modelo 3D de la compostadora")
	cm.free()
	for id in ["compost", "abono_organico", "humus"]:
		check(DB.item_icon(id) != null and DB.item_icon(id).resource_path.ends_with(".png"), "icono de %s sacado del diseño" % id)
	var comp := _build_full(base, "compostadora", pp)
	GS.remove_item("comida_podrida", GS.count("comida_podrida"))
	GS.add_item("comida_podrida", 3)
	GS.add_item("fibra", 2)
	check(comp.start("compost") == "" and GS.count("comida_podrida") == 0, "compost fértil: 3 de comida podrida y 2 de fibra")
	GS.time_offset += comp.recipe_time(DB.recipe("compost")) + 1.0
	check(comp.collect() and GS.count("compost") == 2, "sale compost fértil (2)")
	check(_make(comp, "tierra") and _make(comp, "abono_organico") and _make(comp, "humus"), "tierra, abono orgánico y humus rápido")
	var garden := _build_full(base, "huerto", pp)
	var plain := DB.recipe("cultivo_bayas")
	var rich := DB.recipe("cultivo_bayas_abono")
	check(int(rich["qty"]) == 2 * int(plain["qty"]) and float(rich["time"]) < float(plain["time"]) and rich["cost"].has("compost"), "con compost las bayas dan el doble y antes")
	check(float(DB.recipe("cultivo_bayas_humus")["time"]) < float(rich["time"]), "con humus aún antes")
	GS.add_item("baya", 2)
	var c0 := GS.count("compost")
	check(garden.start("cultivo_bayas_abono") == "" and GS.count("compost") == c0 - 1, "plantar bayas con compost")
	GS.time_offset += garden.recipe_time(rich) + 1.0
	check(garden.collect() and GS.count("baya") >= 12, "cosecha de 12 bayas")
	check(_make(garden, "cultivo_hortalizas") and GS.count("hortalizas") == 6 and DB.recipe("cultivo_hortalizas")["cost"].has("abono_organico"), "hortalizas con abono orgánico")
	world.hud.open_station(comp)
	await _pframes(1)
	check(scr.tabs == ["Compost", "Residuos", "Suelo"], "pestañas de la compostadora como en el diseño %s" % str(scr.tabs))
	world.hud.close_panels()
	world.queue_free()
	await _frames(2)


func test_routes() -> void:
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/routes.json"))
	check(routes.size() >= 9, "tramos de camino definidos (%d)" % routes.size())
	var bad := []
	for rid in routes:
		var r: Dictionary = routes[rid]
		for k in r.get("resources", {}):
			if not DB.resources.has(k):
				bad.append("%s:%s" % [rid, k])
		for c in r.get("creatures", []):
			if not DB.creatures.has(str(c["type"])):
				bad.append("%s:%s" % [rid, c["type"]])
		if int(r.get("part", 0)) < 1 or int(r.get("part", 0)) > 3:
			bad.append("%s:parte" % rid)
	check(bad.is_empty(), "recursos, criaturas y parte de cada tramo existen %s" % str(bad))
	var r0: Dictionary = routes["r_refugio_pinar"]
	var a := Node3D.new()
	add_child(a)
	var t0 := Time.get_ticks_msec()
	var ia := RouteBuilder.build(a, r0, 11)
	var ms := Time.get_ticks_msec() - t0
	check(ms < 3000, "un tramo se construye rápido (%d ms)" % ms)
	var walls := a.get_children().filter(func(n): return n is StaticBody3D and str(n.name).begins_with("Frontera"))
	check(walls.size() == 2 and walls[0].get_child_count() > 10, "paredes invisibles a los dos lados (%d)" % walls.size())
	check(a.find_children("*", "MultiMeshInstance3D", true, false).size() >= 3, "decorado repetido con MultiMesh")
	check(ia["spots"].size() >= 2 and ia["obstacles"].size() == ia["spots"].size(), "puntos de cambio en el tramo")
	check(ia["obstacles"].any(func(o): return o[0] != ""), "cada visita pone al menos un obstáculo")
	var seen := {}
	var spots0: Array = ia["spots"]
	for v in range(1, 30):
		var b := Node3D.new()
		var ib := RouteBuilder.build(b, r0, v * 7919)
		seen[str(ib["obstacles"].map(func(o): return o[0]))] = true
		check(ib["spots"] == spots0, "los puntos de cambio son siempre los mismos") if v == 1 else null
		b.free()
	check(seen.size() >= 4, "de una visita a otra cambian los obstáculos (%d combinaciones)" % seen.size())
	var a2 := Node3D.new()
	var ia2 := RouteBuilder.build(a2, r0, 12)
	check(ia2["creatures"][0][1] != ia["creatures"][0][1], "los infectados cambian de sitio en cada visita")
	a2.free()
	a.queue_free()
	await _frames(1)


func _ratio(map_id: String, kinds: Array) -> float:
	var res: Dictionary = DB.maps[map_id]["resources"]
	var rocks := 0.0
	var n := 0.0
	for k in res:
		if str(k) == "roca" or str(k).begins_with("veta_"):
			rocks += float(res[k])
			if str(k) in kinds:
				n += float(res[k])
	return n / rocks


func test_phase1() -> void:
	# Datos de las zonas
	check(DB.maps.has("arboleda") and DB.maps.has("pedregal"), "La Arboleda y El Pedregal existen")
	check(DB.map_piece("arboleda") == 1 and DB.map_piece("pedregal") == 1 and DB.map_piece("bosque") == 2 and DB.map_piece("cantera") == 2, "Arboleda y Pedregal en la pieza I; Pinar y Cantera en la II")
	check(is_equal_approx(_ratio("pedregal", ["veta_hierro"]), 0.1), "Pedregal: de cada 10 rocas, 1 de hierro")
	check(is_equal_approx(_ratio("cantera", ["veta_hierro", "veta_carbon"]), 0.5) and is_equal_approx(_ratio("cantera", ["veta_cobre", "veta_azufre"]), 0.2), "Cantera: 5 de cada 10 vetas básicas y 2 mejores")
	check(DB.resources["arbol"]["yield"] == "madera" and DB.resources["pino"]["yield"] == "madera_pino", "árbol pequeño: troncos; pino: troncos de pino")
	check(int(DB.maps["arboleda"]["resources"].get("arbol", 0)) > 20 and not DB.maps["arboleda"]["resources"].has("pino"), "La Arboleda: árboles pequeños, sin pinos")
	check(int(DB.maps["bosque"]["resources"]["pino"]) > int(DB.maps["arboleda"]["resources"]["arbol"]) * 2, "el Pinar tiene muchos más árboles")
	check(DB.recipe("viga")["cost"].has("madera_pino") and int(DB.recipe("tablon_pino")["qty"]) * 2 > int(DB.recipe("tablon")["qty"]) * int(DB.recipe("tablon_pino")["cost"]["madera_pino"]), "la madera de pino rinde más tablones y hace las vigas")
	for id in DB.world_map:
		check(DB.world_map[id].has("piece"), "%s tiene su pieza del mapa" % id) if not DB.world_map[id].has("piece") else null
	for n in [1, 2, 3]:
		check(ResourceLoader.exists("res://assets/ui/mapa_piezas_%d.jpg" % n), "mapa del juego con %d pieza(s)" % n)

	# Partida nueva de verdad: solo la pieza I
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.testing = false
	GS.new_game()
	GS.testing = true
	GS.level = 20
	GS.created = true
	check(GS.map_pieces == 1, "al empezar solo tienes la pieza I")
	var world := await _new_world()
	_creatures_away()
	check(world.travel_to("bosque") == "Te falta ese trozo del mapa", "sin la pieza II no se va al Pinar")
	var hud: CanvasLayer = world.hud
	hud.map_btn.pressed.emit()
	await _pframes(2)
	check(hud._map_area.texture.resource_path.ends_with("mapa_piezas_1.jpg") and hud.map_buttons.has("arboleda") and not hud.map_buttons.has("bosque"),
		"en el mapa solo se ve la pieza I (%s)" % str(hud.map_buttons.keys()))
	hud.map_buttons["arboleda"].pressed.emit()
	await _pframes(1)
	check(hud._map_walk.visible and not hud._map_travel.disabled, "a La Arboleda: viajar o ir andando")
	hud.close_panels()

	# Ir andando: el camino se carga como una zona más
	check(world.walk_to("arboleda") == "", "salir andando hacia La Arboleda")
	check(GS.current_map == "r_refugio_arboleda" and GS.route_from == "refugio", "vas por el Sendero de la Arboleda")
	world.queue_free()
	await _frames(3)
	var path := await _new_world()
	check(not path.route.is_empty() and path.base == null, "el camino es un pasillo, sin construcción")
	check(path.player.global_position.z > -6.0, "empiezas al principio del camino")
	check(get_tree().get_nodes_in_group("resource").size() > 10 and get_tree().get_nodes_in_group("creature").size() > 0, "en el camino hay recursos y bichos")
	path.hud.map_btn.pressed.emit()
	await _pframes(1)
	check(path.hud._map_selected == "refugio", "en el mapa sigues marcado en el refugio mientras andas")
	path.hud.close_panels()
	path.player.global_position = Vector3(RouteBuilder.center_x(path.route, -float(path.route["length"]) - 3.0), 0, -float(path.route["length"]) - 3.0)
	await _pframes(2)
	check(GS.current_map == "arboleda" and GS.route_from == "", "al final del camino entras en La Arboleda")
	path.queue_free()
	await _frames(3)

	# La Arboleda: el superviviente muerto lleva la pieza II
	var grove := await _new_world()
	check(grove.map_id == "arboleda", "carga La Arboleda")
	var body: Node3D = null
	var car: Node3D = null
	for b in get_tree().get_nodes_in_group("container"):
		if b.id == "cadaver":
			body = b
		elif b.id == "coche":
			car = b
	check(body != null and car != null, "en La Arboleda hay un superviviente muerto y un coche abandonado")
	var piece_slot := -1
	for i in body.storage.size():
		if body.storage[i] != null and body.storage[i]["id"] == "trozo_mapa_2":
			piece_slot = i
	check(piece_slot >= 0, "el muerto lleva el trozo de mapa II")
	body.chest_to_bag(piece_slot)
	check(GS.map_pieces == 2 and GS.count("trozo_mapa_2") == 0, "al cogerlo se cose al mapa (no ocupa la mochila)")
	_creatures_away()
	grove.hud.map_btn.pressed.emit()
	await _pframes(2)
	check(grove.hud._map_area.texture.resource_path.ends_with("mapa_piezas_2.jpg") and grove.hud.map_buttons.has("bosque"), "el mapa ya enseña la pieza II")
	grove.hud.close_panels()
	var arbs := get_tree().get_nodes_in_group("resource").filter(func(r): return r.kind == "arbol")
	check(arbs.size() > 20, "La Arboleda está llena de árboles pequeños (%d)" % arbs.size())
	grove.save()
	grove.queue_free()
	await _frames(3)
	var grove2 := await _new_world()
	var again := false
	for b in get_tree().get_nodes_in_group("container"):
		if b.id == "cadaver":
			for it in b.storage:
				if it != null and it["id"] == "trozo_mapa_2":
					again = true
	check(not again, "el trozo de mapa no vuelve a salir")

	# Viaje rápido: energía que se recarga con el tiempo
	_creatures_away()
	GS.travel_energy = 5.0
	GS.travel_energy_t = GS.now()
	check(grove2.travel_to("refugio").begins_with("Te falta energía de viaje"), "sin energía no hay viaje rápido")
	GS.time_offset += 3600.0
	check(int(GS.travel_energy_now()) == 25, "la energía se recarga con el tiempo (20 por hora)")
	check(grove2.travel_to("refugio") == "", "con energía sí")
	grove2.queue_free()
	await _frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()


func test_crafting_tree() -> void:
	print("== Fabricación: materias primas, procesados y bancos")
	# a mano solo lo básico
	var manual := DB.recipes_for("")
	var ids := manual.map(func(r): return str(r["result"]))
	check(manual.size() <= 6 and ids.has("hacha_piedra") and ids.has("cuerda") and not ids.has("garrote"), "a mano solo lo básico (%s)" % str(ids))
	# todo lo que piden las recetas existe y, si no es materia prima o botín, se fabrica en algún sitio
	var made := {}
	for r in DB.recipes:
		made[str(r["result"])] = true
	var loot := ["tela", "piel", "chatarra", "carne_cruda", "baya", "seta", "azufre", "mochila", "mochila_excursion"]
	var bad := []
	for r in DB.recipes:
		for id in r["cost"]:
			var d := DB.item(str(id))
			if d.is_empty() or (str(d.get("tier", "")) != "bruto" and not made.has(str(id)) and not loot.has(str(id))):
				bad.append("%s<-%s" % [r["id"], id])
	check(bad.is_empty(), "cada ingrediente existe y se puede conseguir %s" % str(bad))
	check(DB.recipe("garrote")["cost"].has("mango") and DB.recipe("mango")["station"] == "carpinteria" and DB.recipe("clavos")["station"] == "banco_trabajo", "el garrote pide mango (carpintería) y clavos (banco)")
	check(DB.recipe("hacha_hierro")["cost"].has("mango") and DB.recipe("acero")["station"] == "horno" and DB.recipe("machete")["cost"].has("acero"), "herramientas de metal con mango; el machete, con acero del horno")
	check(DB.recipe("camiseta")["cost"].has("tela_resistente") and DB.recipe("tela_resistente")["station"] == "mesa_costura", "la ropa se cose con tela resistente")
	check(bool(DB.item("antorcha").get("light", false)) and Builder.tool_mesh("antorcha").find_children("*", "OmniLight3D", true, false).size() == 1, "la antorcha alumbra")
	# pantalla de fabricación
	var world := await _new_world()
	world.hud.craft_btn.pressed.emit()
	await _pframes(2)
	var cs: Control = world.hud._craft_panel
	check(cs.visible and cs.cards.size() > 20 and cs.cards[0]["manual"], "la pantalla muestra todos los planos, primero los de a mano")
	var gi := -1
	for i in cs.cards.size():
		if cs.cards[i]["r"]["result"] == "garrote":
			gi = i
	cs._show(gi)
	check(not cs.cards[gi]["manual"] and cs.craft_btn.disabled and "Banco de trabajo" in cs._where.text, "el garrote dice en qué banco se hace")
	GS.clear_inventory() if GS.has_method("clear_inventory") else null
	cs.ctab = "Herramientas"
	cs.sel = 0
	cs.refresh()
	var hi := -1
	for i in cs.cards.size():
		if cs.cards[i]["r"]["result"] == "hacha_piedra":
			hi = i
	cs._show(hi)
	_give(DB.recipe("hacha_piedra")["cost"])
	cs._show(hi)
	var axes := GS.count("hacha_piedra")
	check(not cs.craft_btn.disabled and cs._slots[0][2].text.begins_with("%d/" % GS.count("madera")), "a mano: se ven los materiales y se puede fabricar")
	cs.craft_btn.pressed.emit()
	check(GS.count("hacha_piedra") == axes + 1, "FABRICAR hace el hacha")
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
	check(got.size() == 1 and "Cofre" in got[0][1] and "Clavos" in got[0][1], "al 2 se desbloquean el cofre y los clavos")
	GS.level = 4
	GS.xp = 0
	var cuerdas := GS.count("cuerda")
	GS.add_xp(DB.xp_to_next(4) + DB.xp_to_next(5) + 3)
	check(GS.level == 6 and GS.xp == 3, "mucha XP de golpe sube varios niveles")
	check(GS.count("cuerda") == cuerdas + 3, "el nivel 5 trae recompensa")
	GS.leveled_up.disconnect(on_up)
	check(DB.unlocks_at(3).has("Viaje: Pinar del Cuervo") and DB.unlocks_at(8).has("Viaje: Cantera del Tajo"), "los viajes se desbloquean por nivel")
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
	check(bench.start("garrote") == "Se desbloquea en el nivel 3", "el garrote pide nivel 3")
	GS.level = 3
	check(bench.start("garrote") == "", "en el nivel 3 ya se fabrica")
	GS.level = 2
	world.hud.open_station(bench)
	await _pframes(2)
	var bs: Control = world.hud._station_panel
	var locked_i := -1
	for i in bs.entries.size():
		if bs.entries[i]["kind"] == "recipe" and DB.recipe_unlock(bs.entries[i]["r"]) > GS.level:
			locked_i = i
	if locked_i < 0:
		for t in bs.tabs:
			if locked_i >= 0:
				break
			bs.tab = t
			bs.refresh()
			for i in bs.entries.size():
				if locked_i < 0 and bs.entries[i]["kind"] == "recipe" and DB.recipe_unlock(bs.entries[i]["r"]) > GS.level:
					locked_i = i
	bs._select(locked_i)
	bs.tick()
	check(locked_i >= 0 and bs.action_btn.text.begins_with("NIVEL ") and bs.action_btn.disabled, "las recetas bloqueadas dicen en qué nivel salen")
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

	# Minimapa
	var mm: Control = world.hud.minimap
	check(mm != null and mm.world == world, "hay minimapa en el HUD")
	var c0: Variant = mm.to_map(world.player.global_position)
	check(c0 != null and (c0 as Vector2).distance_to(mm.center()) < 3.0, "el jugador va en el centro del minimapa")
	GS.forced_hour = 15.0
	var t_day := GS.temperature()
	GS.forced_hour = 3.0
	var t_night := GS.temperature()
	GS.forced_rain = 1
	var t_rain := GS.temperature()
	GS.forced_rain = 0
	GS.forced_hour = 12.0
	check(t_day > t_night and t_rain < t_night, "temperatura: más calor de día, menos de noche y con lluvia (%d/%d/%d)" % [t_day, t_night, t_rain])
	var east: Variant = mm.to_map(world.player.global_position + Vector3(5, 0, 0))
	var north: Variant = mm.to_map(world.player.global_position + Vector3(0, 0, -5))
	check(east != null and (east as Vector2).x > (c0 as Vector2).x + 20.0, "el este sale a la derecha")
	check(north != null and (north as Vector2).y < (c0 as Vector2).y - 15.0, "el norte sale arriba")
	check(mm.to_map(world.player.global_position + Vector3(60, 0, 0)) == null, "lo lejano no sale")
	check(mm._icon_for(wolf) == "zorro" if is_instance_valid(wolf) else true, "los animales salen en marrón")
	var inf: Node3D = world.CreatureScript.new()
	inf.setup("infectado")
	inf.home = world.player.global_position + Vector3(3, 0, 0)
	inf.position = inf.home
	world.add_child(inf)
	await _pframes(35)
	check(mm._icon_for(inf) == "infectado", "los infectados salen en rojo")
	var hidden := true
	for n in inf.find_children("*", "VisualInstance3D", true, false):
		if (n as VisualInstance3D).layers != mm.HIDE_LAYER:
			hidden = false
	check(hidden, "las criaturas no se pintan en la vista del minimapa (van como icono)")
	for k in ["infectado", "zorro", "ciervo", "caja", "jugador", "norte"]:
		check(mm._icons[k] != null, "icono de minimapa: %s" % k)

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
	check(is_equal_approx(GS.carry_capacity(), 35.0) and GS.free_slots() >= 15, "la mochila da huecos, no aguante de peso")
	GS.add_item("piedra", 100)
	check(GS.overloaded(), "con 150 piedras vas sobrecargado")
	world.player.move_input = Vector2(1, 0)
	world.hud.joystick.value = Vector2(1, 0)
	GS.stamina = GS.max_stamina()
	await _pframes(3)
	check(world.player.running, "sobrecargado también puedes correr")
	var heavy := GS.stamina_drain()
	check(heavy > float(DB.bal("stamina_drain", 5.0)) * 2.2 * 1.5, "pero gastas mucha más energía (%.1f/s)" % heavy)
	check(GS.speed_factor() < 0.75, "y vas más lento")
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
	check(hud._map_area.texture.resource_path.ends_with("mapa_piezas_3.jpg"), "con las 3 piezas se ve el mapa entero")
	check(hud._map_selected == "refugio" and hud._map_travel.disabled, "empieza marcando dónde estás")
	hud.map_buttons["bosque"].pressed.emit()
	await _frames(2)
	check(hud._map_selected == "bosque" and not hud._map_travel.disabled and hud._map_name.text.contains("Pinar"), "tocar una zona abierta permite viajar")
	check(hud._map_walk.visible, "y también ir andando por su camino")
	hud.map_buttons["central"].pressed.emit()
	await _frames(2)
	check(hud._map_travel.disabled, "a una zona sin explorar no se puede viajar")
	hud.close_panels()
	check(world.travel_to("bosque") != "", "no se puede viajar con enemigos cerca")
	_creatures_away()
	var cost := DB.travel_energy_cost("refugio", "bosque")
	var e0 := GS.travel_energy_now()
	check(world.travel_to("bosque") == "", "viajar al bosque")
	check(absf(GS.travel_energy_now() - (e0 - cost)) < 0.5, "el viaje rápido gasta energía de viaje (%d)" % cost)
	check(GS.current_map == "bosque", "la partida queda en el bosque")
	world.queue_free()
	await _frames(3)

	var bosque := await _new_world()
	check(bosque.map_id == "bosque", "carga el Pinar del Cuervo")
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
	check(boxes.size() == 3 and boxes.any(func(b): return b.id == "coche_bueno"), "cabaña, aserradero y un coche con botín")
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
	check(cantera.map_id == "cantera", "carga la Cantera del Tajo")
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
	check(dressed.get_child_count() > 0 and _count_verts(dressed) > _count_verts(bare) + 300, "la ropa añade piezas al personaje")
	dressed.animate_walk(1.0, 1.0)
	check(absf(dressed.j["leg_l"].rotation.x) > 0.1, "las piernas se mueven al andar")
	# animaciones de captura (Universal Animation Library) en nuestras articulaciones
	check(CharacterModel.anims() != null and CharacterModel.anims().clips.has("Walk_Loop") and CharacterModel.clip_length("Sword_Attack") > 0.3, "están las animaciones de la librería")
	var ok_knees := true
	for k in 16:
		bare.animate_walk(k * TAU / 16.0, 1.0, float(k % 2))
		for sd in ["l", "r"]:
			if (bare.j["knee_" + sd].basis * Vector3.DOWN).z < -0.08 or (bare.j["elbow_" + sd].basis * Vector3.DOWN).z > 0.08:
				ok_knees = false
	check(ok_knees, "al andar y correr las rodillas y los codos se doblan hacia el lado natural")
	bare.animate_walk(1.0, 1.0, 1.0)
	check(((bare.j["hips"].basis * bare.j["spine"].basis) * Vector3.UP).z < -0.02, "al correr el tronco se inclina hacia delante")
	var skel: Skeleton3D = bare._skel
	check(skel != null and skel.get_bone_count() == bare.j.size() and _count_meshes(bare) <= 2, "el cuerpo es una sola malla con esqueleto (sin huecos en las articulaciones)")
	# relieve muscular: el anillo de los pectorales sale más por delante que por los lados
	check(CharacterModel._shape(["pec", 0.2], deg_to_rad(240.0)) > 1.1 and is_equal_approx(CharacterModel._shape(["pec", 0.2], 0.0), 1.0), "los pectorales abultan solo por delante")
	bare.animate_walk(0.0, 0.0)
	bare.animate_idle(0.0, 1.0)
	var sp0: Quaternion = bare.j["spine"].quaternion
	bare.animate_idle(1.3, 1.0)
	check(bare.j["spine"].quaternion.angle_to(sp0) > 0.005, "quieto respira (el pecho se mueve)")
	bare.animate_walk(0.5, 1.0)
	var arm0: Quaternion = bare.j["arm_r"].quaternion
	var leg0: Quaternion = bare.j["leg_l"].quaternion
	bare.animate_swing(0.45)
	check(bare.j["arm_r"].quaternion.angle_to(arm0) > 0.4 and bare.j["leg_l"].quaternion.angle_to(leg0) < 0.001, "andando, el golpe mueve brazos y tronco sin tocar las piernas")
	bare.animate_walk(0.0, 0.0)
	var legq: Quaternion = bare.j["leg_l"].quaternion
	bare.animate_swing(0.45)
	check(bare.j["leg_l"].quaternion.angle_to(legq) > 0.05, "parado, el golpe es de todo el cuerpo (paso adelante)")
	bare.animate_walk(0.5, 1.0)
	bare.animate_swing(1.0)
	check(bare.j["arm_r"].quaternion.angle_to(arm0) < 0.001, "al acabar el golpe vuelve a la pose normal")
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
	var meshes0 := _count_verts(player._visual)
	GS.add_item("chaqueta_piel", 1)
	for i in GS.slots.size():
		if GS.slots[i] != null and GS.slots[i]["id"] == "chaqueta_piel":
			GS.wear_slot(i)
	await _frames(2)
	check(_count_verts(player._visual) > meshes0 + 100, "la chaqueta aparece en el superviviente")
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
	world.hud.toggle_crouch()
	GS.stamina = GS.max_stamina()
	world.hud.joystick.value = Vector2(1, 0)
	await _pframes(3)
	var ran: bool = player.running
	world.hud.joystick.value = Vector2(0.86, 0)
	await _pframes(3)
	check(ran and player.running, "con el dedo un poco por debajo del límite se sigue corriendo (sin saltos)")
	world.hud.joystick.value = Vector2(0.7, 0)
	await _pframes(3)
	check(not player.running, "soltando más, se deja de correr")
	world.hud.joystick.value = Vector2.ZERO
	await _pframes(3)
	world.hud.toggle_crouch()
	z.aware = false
	z._lost = 0.0
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
	await _pframes(2)
	var ws: Control = world.hud._station_panel
	check(ws.tabs.has("Reparar"), "el panel del banco de trabajo tiene la pestaña «Reparar»")
	ws.tab = "Reparar"
	ws.refresh()
	for i in ws.entries.size():
		if ws.entries[i]["ref"]["where"] == "hand":
			ws._select(i)
	_give(ws.entries[ws.selected]["cost"])
	ws.tick()
	check(ws.action_btn.text == "REPARAR" and not ws.action_btn.disabled, "y su botón repara (%s)" % ws.action_btn.text)
	ws.action_btn.pressed.emit()
	check(GS.hand["dur"] == int(DB.item(str(GS.hand["id"]))["durability"]), "el arma queda como nueva")
	# Al abrir una estación con el botón pulsado, el botón se suelta (si no, se reabre al cerrar)
	world.hud.close_panels()
	await _pframes(2)
	world.hud.action_button._touch = 5
	world.hud.action_button._set_held(true)
	world.hud.open_station(bench)
	await _pframes(2)
	check(not world.hud.action_button.held, "abrir una ventana suelta el botón de acción")
	ws.visible = false
	await _pframes(3)
	check(not ws.visible, "al cerrar no se vuelve a abrir sola")
	world.hud.open_station(bench)
	await _pframes(2)
	# Iconos de las tarjetas y vistas grandes sacados de los diseños de estaciones
	check(ws.recipe_icon("lingote_hierro").resource_path.ends_with("recetas/lingote_hierro.png"), "icono de tarjeta del diseño (lingote de hierro)")
	check(ws.preview_tex("tablon").resource_path.ends_with("preview/tablon.png"), "vista grande del diseño (tablones)")
	check(ws.recipe_icon("garrote") == DB.item_icon("garrote"), "sin diseño de estación, el icono del objeto")
	# Pantalla nueva: categorías, cantidad y fabricar varias
	ws.tab = "Armas"
	ws.refresh()
	check(ws.tabs.size() >= 2 and ws._title.text == "BANCO DE TRABAJO", "pestañas por categoría (%s)" % str(ws.tabs))
	for i in ws.entries.size():
		if ws.entries[i]["kind"] == "recipe" and ws.entries[i]["r"]["id"] == "garrote":
			ws._select(i)
	_give(DB.recipe("garrote")["cost"])
	_give(DB.recipe("garrote")["cost"])
	ws.set_qty(2)
	check(ws.qty == 2 and ws._qty_label.text == "2", "se elige cuántas fabricar")
	var hachas := GS.count("garrote")
	ws.action_btn.pressed.emit()
	check(bench.job.get("count", 1) == 2, "fabrica 2 de una vez")
	GS.time_offset += float(bench.job["time"]) + 1.0
	ws.tick()
	check(ws.action_btn.text == "RECOGER", "cuando acaba, el botón recoge")
	ws.action_btn.pressed.emit()
	check(GS.count("garrote") == hachas + 2, "se recogen las 2")
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
	check(hud.action_icon == "hacha_piedra" and hud.action_button.ring < 0.0 and not hud.action_button.enabled, "junto al pino sin hacha: icono del hacha en gris y sin borde")
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
	GS.add_item("hacha_piedra", 1)
	for r in get_tree().get_nodes_in_group("resource"):
		if r.kind in ["pino", "arbol"] and not r.depleted:
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
	check(hud._settings_panel.dirty and not hud._settings_panel.save_btn.disabled, "con cambios se puede guardar")
	hud._settings_panel.save_btn.pressed.emit()
	check(not hud._settings_panel.dirty and hud._settings_panel.save_btn.text == "GUARDADO", "al guardar queda guardado")
	SFX.settings = {"music": 0.6, "sfx": 0.8, "vibration": true}
	SFX.load_settings()
	check(is_equal_approx(float(SFX.settings["sfx"]), 0.5) and SFX.settings["vibration"] == false, "los ajustes se guardan")
	SFX.set_setting("music", 0.6)
	SFX.set_setting("sfx", 0.8)
	SFX.set_setting("vibration", true)
	# Pantalla de ajustes del diseño: pestañas, sistema, gráficos y audio
	var st: Control = hud._settings_panel
	check(str(SFX.settings["player_id"]).begins_with("SUPERVIVIENTE#"), "hay ID de jugador (%s)" % SFX.settings["player_id"])
	check(st._sys_values["version"].text.begins_with("v") and st._sys_values["access"].text != "", "sistema: versión y último acceso")
	check(st.access_text(Time.get_unix_time_from_system() - 300.0) == "Hace 5 min" and st.access_text(0.0) == "Primera vez", "último acceso en texto")
	st._tab_buttons["graficos"].pressed.emit()
	await _pframes(2)
	check(st.tab == "graficos" and st._pill_label.text == "Gráficos" and st.controls.has("shadows"), "pestaña de gráficos")
	# Cámara: más cerca por defecto, con límites y pellizco con dos dedos
	check(is_equal_approx(world.zoom(), 0.85), "la cámara empieza más cerca que antes")
	world.set_zoom(5.0)
	check(is_equal_approx(world.zoom(), world.ZOOM_MAX), "no se aleja más del límite")
	world.set_zoom(0.0)
	check(is_equal_approx(world.zoom(), world.ZOOM_MIN), "ni se acerca más del límite")
	world.set_zoom(0.85)
	st.controls["zoom"].value = 1.1
	check(is_equal_approx(world.zoom(), 1.1), "la distancia se cambia en ajustes")
	st.close_screen()
	check(st.visible and st._close_btn.text == "?", "cerrar con cambios sin guardar avisa")
	st.close_screen()
	check(not st.visible and is_equal_approx(world.zoom(), 0.85), "cerrar otra vez los descarta")
	hud.settings_btn.pressed.emit()
	await _pframes(2)
	st.select_tab("graficos")
	await _pframes(2)
	hud.close_panels()
	await _pframes(1)
	var vpc := get_viewport().get_visible_rect().size
	var tr := get_tree().root.get_final_transform()
	for idx in [0, 1]:
		var t := InputEventScreenTouch.new()
		t.index = idx
		t.pressed = true
		t.position = tr * Vector2(vpc.x * 0.5 + (idx * 2 - 1) * 60.0, vpc.y * 0.45)
		Input.parse_input_event(t)
	await _pframes(2)
	for k in 6:
		var dr := InputEventScreenDrag.new()
		dr.index = 1
		dr.position = tr * Vector2(vpc.x * 0.5 + 60.0 + 20.0 * (k + 1), vpc.y * 0.45)
		Input.parse_input_event(dr)
		await _pframes(1)
	for idx in [0, 1]:
		var t := InputEventScreenTouch.new()
		t.index = idx
		t.pressed = false
		Input.parse_input_event(t)
	await _pframes(2)
	check(world.zoom() < 0.7, "separar dos dedos acerca la cámara (%.2f)" % world.zoom())
	world.set_zoom(0.85)
	hud.settings_btn.pressed.emit()
	await _pframes(2)
	st.select_tab("graficos")
	await _pframes(2)
	st.controls["shadows"].button_pressed = false
	check(SFX.settings["shadows"] == false and not world._sun.shadow_enabled, "quitar sombras se aplica")
	st.controls["quality"].item_selected.emit(0)
	check(SFX.settings["quality"] == "bajo" and world.hud.minimap.update_every == 5, "calidad baja: el minimapa se repinta menos")
	st.controls["fps"].item_selected.emit(0)
	check(Engine.max_fps == 30, "límite de 30 FPS")
	st.controls["minimap"].button_pressed = false
	check(not world.hud.minimap.visible, "se puede ocultar el minimapa")
	st.controls["damage_numbers"].button_pressed = false
	check(SFX.settings["damage_numbers"] == false, "se pueden quitar los números de daño")
	for k in ["quality", "shadows", "fps", "minimap", "damage_numbers", "zoom"]:
		SFX.set_setting(k, SFX.DEFAULTS[k])
	st.apply_graphics(world)
	st._tab_buttons["audio"].pressed.emit()
	await _pframes(2)
	st.controls["mute"].button_pressed = true
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "silenciar todo")
	st.controls["mute"].button_pressed = false
	st.controls["ambience"].value = 0.3
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambiente")) - linear_to_db(0.3)) < 0.1, "volumen de ambiente")
	SFX.set_setting("ambience", 0.7)
	st._tab_buttons["general"].pressed.emit()
	await _pframes(2)
	check(st.controls.has("music") and st.controls.has("copy_id") and st.controls.has("rrss_instagram"), "general: ID, volúmenes y redes")
	hud.settings_controls = st.controls
	for i in GS.slots.size():
		GS.slots[i] = null
	GS.add_item("madera", 7)
	GS.created = true
	var wipe: Button = hud._settings_panel.controls["wipe"]
	wipe.pressed.emit()
	check(GS.count("madera") == 7 and wipe.text.begins_with("¿SEGURO"), "borrar datos pide confirmación (%d, %s)" % [GS.count("madera"), wipe.text])
	wipe.pressed.emit()
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
		if res.kind in ["pino", "arbol"] or res.kind == "roca":
			meshes += _count_verts(res._visual)
			break
	check(meshes >= 60, "los pinos y rocas usan los modelos facetados")
	# Menos dibujos para el móvil: las piezas de cada árbol o roca van en una sola malla
	var one_tree := -1
	for res in get_tree().get_nodes_in_group("resource"):
		if res.kind in ["pino", "arbol"]:
			one_tree = _count_meshes(res._visual)
			break
	check(one_tree == 1 or one_tree == -1, "cada pino se dibuja de una vez (%d mallas)" % one_tree)
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


func _count_verts(n: Node) -> int:
	var v := 0
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh:
			for si in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(si)
				v += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return v


func _count_meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += _count_meshes(ch)
	return c
