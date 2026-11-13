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
	print("== Animales")
	await test_animals()
	print("== Viajes y zonas")
	await test_travel()
	print("== Personaje")
	await test_character()
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
	check(left == 5, "las herramientas no se apilan (sobran 5 con 20 casillas)")
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
	check(GS.hand != null and GS.hand_tool() == "axe", "equipa el hacha")
	var dur := int(GS.hand["dur"])
	GS.wear_hand()
	check(int(GS.hand["dur"]) == dur - 1, "el uso gasta durabilidad")
	GS.hand["dur"] = 1
	GS.wear_hand()
	check(GS.hand == null, "la herramienta se rompe a 0")
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
	check(bench.start("machete") != "", "el machete pide banco de nivel 2")
	GS.add_item("bloque_piedra", 10)
	check(base.upgrade(bench) and bench.level == 2, "banco mejorado a nivel 2")
	check(bench.start("machete") == "", "con nivel 2 ya fabrica el machete")

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
	GS.outfit["torso"] = "camiseta"
	GS.save_game({})
	GS.new_game()
	GS.load_game()
	check(GS.look["sex"] == "f" and int(GS.look["hair"]) == 3 and GS.outfit["torso"] == "camiseta", "el aspecto y la ropa se guardan")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	await _frames(2)


func _count_meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += _count_meshes(ch)
	return c
