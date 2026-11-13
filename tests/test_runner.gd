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
