extends Node3D
## Escena principal: genera la zona inicial, el jugador, los infectados y la
## interfaz, y coordina muerte, reaparición y guardado automático.

const PlayerScript := preload("res://scripts/world/player.gd")
const ResourceScript := preload("res://scripts/world/resource_node.gd")
const ZombieScript := preload("res://scripts/world/zombie.gd")
const BagScript := preload("res://scripts/world/bag.gd")
const WellScript := preload("res://scripts/world/well.gd")
const HudScript := preload("res://scripts/ui/hud.gd")

const SPAWN := Vector3(0, 0, 0)

var player: CharacterBody3D
var hud: CanvasLayer
var camera: Camera3D
var rng := RandomNumberGenerator.new()
var _placed: Array[Vector3] = []
var _zombie_respawns: Array = []   # [{ "z": zombie, "t": segundos }]
var _death_timer := 0.0
var _autosave := 0.0
var _half := 45.0


func _ready() -> void:
	randomize()
	rng.seed = int(DB.bal("world_seed", 1337))
	_half = float(DB.bal("world_size", 90)) / 2.0
	_build_environment()

	hud = HudScript.new()
	add_child(hud)

	player = PlayerScript.new()
	player.position = SPAWN
	add_child(player)
	_placed.append(SPAWN)

	var well := WellScript.new()
	well.position = SPAWN + Vector3(5, 0, -3)
	add_child(well)
	_placed.append(well.position)

	_spawn_resources()
	_spawn_zombies()

	GS.died.connect(_on_player_died)
	var world := GS.load_game()
	if not world.is_empty():
		_load_world(world)
	_update_camera(1.0)


# ------------------------------------------------------------ construcción

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2c3a2e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8c4b0")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color("3b4a3c")
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_half * 2.0 + 30.0, _half * 2.0 + 30.0)
	ground.mesh = plane
	ground.material_override = Builder.mat(Color("4f6b3a"))
	add_child(ground)
	# Manchas de tierra para que el suelo no sea plano del todo.
	for i in 40:
		var patch := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		var s := rng.randf_range(2.0, 6.0)
		pm.size = Vector2(s, s * rng.randf_range(0.6, 1.4))
		patch.mesh = pm
		patch.material_override = Builder.mat(Color("5d5a3a") if i % 2 == 0 else Color("445e33"))
		patch.position = Vector3(rng.randf_range(-_half, _half), 0.01, rng.randf_range(-_half, _half))
		patch.rotation.y = rng.randf_range(0, TAU)
		add_child(patch)

	camera = Camera3D.new()
	camera.fov = 50
	camera.far = 120
	add_child(camera)


func _free_spot(min_dist: float, avoid_spawn: float) -> Vector3:
	for attempt in 40:
		var p := Vector3(rng.randf_range(-_half + 2, _half - 2), 0, rng.randf_range(-_half + 2, _half - 2))
		if p.distance_to(SPAWN) < avoid_spawn:
			continue
		var ok := true
		for q in _placed:
			if p.distance_to(q) < min_dist:
				ok = false
				break
		if ok:
			_placed.append(p)
			return p
	var fallback := Vector3(rng.randf_range(-_half, _half), 0, rng.randf_range(-_half, _half))
	_placed.append(fallback)
	return fallback


func _spawn_resources() -> void:
	for kind in DB.resources:
		var n := int(DB.resources[kind].get("count", 10))
		for i in n:
			var node := ResourceScript.new()
			node.setup(str(kind))
			node.position = _free_spot(2.2, 4.0)
			node.rotation.y = rng.randf_range(0, TAU)
			add_child(node)


func _spawn_zombies() -> void:
	var n := int(DB.zombie("count", 8))
	for i in n:
		var z := ZombieScript.new()
		z.home = _free_spot(2.0, float(DB.zombie("min_distance_from_spawn", 16)))
		z.position = z.home
		z.killed.connect(_on_zombie_killed)
		add_child(z)


func spawn_bag(pos: Vector3, items: Array, is_player: bool) -> Node3D:
	var bag := BagScript.new()
	bag.setup(items, is_player)
	bag.position = Vector3(pos.x, 0, pos.z)
	add_child(bag)
	return bag


# ------------------------------------------------------------------- bucle

func _process(delta: float) -> void:
	GS.tick(delta)

	if GS.dead:
		_death_timer -= delta
		if _death_timer <= 0.0:
			_respawn_player()
	else:
		player.move_input = hud.joystick.value
		player.action_held = hud.action_button.held
		player.position.x = clampf(player.position.x, -_half, _half)
		player.position.z = clampf(player.position.z, -_half, _half)
		var t := find_target()
		player.target = t
		hud.set_action("" if t == null else t.action_label())

	for entry in _zombie_respawns.duplicate():
		entry["t"] = float(entry["t"]) - delta
		if float(entry["t"]) <= 0.0:
			_zombie_respawns.erase(entry)
			entry["z"].revive()

	_autosave += delta
	if _autosave >= float(DB.bal("autosave_seconds", 15)):
		_autosave = 0.0
		save()

	_update_camera(delta)


func find_target() -> Node3D:
	var reach := float(DB.bal("interact_range", 2.2))
	var best: Node3D = null
	var best_d := INF
	var best_enemy: Node3D = null
	var best_enemy_d := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node3D
		if node == null or not node.is_inside_tree() or not node.visible:
			continue
		if not node.can_interact():
			continue
		var d := Vector2(node.global_position.x - player.global_position.x,
			node.global_position.z - player.global_position.z).length()
		var extra := 0.0
		if node.is_in_group("resource"):
			extra = float(node.data.get("radius", 0.0))
		elif node is StaticBody3D:
			extra = 0.8
		if d > reach + extra:
			continue
		if node.is_in_group("enemy"):
			if d < best_enemy_d:
				best_enemy_d = d
				best_enemy = node
		elif d < best_d:
			best_d = d
			best = node
	return best_enemy if best_enemy != null else best


func _update_camera(delta: float) -> void:
	var want := player.global_position + Vector3(0, 13.0, 8.5)
	camera.global_position = camera.global_position.lerp(want, clampf(delta * 6.0, 0.0, 1.0))
	camera.look_at(camera.global_position + Vector3(0, -13.0, -8.5), Vector3.UP)


# ------------------------------------------------------- muerte y botín

func _on_player_died() -> void:
	var items := GS.take_all_items()
	if not items.is_empty():
		spawn_bag(player.global_position, items, true)
	hud.show_death(true)
	_death_timer = 2.5
	save()


func _respawn_player() -> void:
	hud.show_death(false)
	GS.reset_stats()
	player.global_position = SPAWN
	camera.global_position = SPAWN + Vector3(0, 13.0, 8.5)


func _on_zombie_killed(z: Node3D) -> void:
	var loot: Array = []
	var table: Dictionary = DB.zombie("loot", {})
	for id in table:
		var r: Array = table[id]
		var q := rng.randi_range(int(r[0]), int(r[1]))
		if q > 0:
			loot.append(GS.make_item(str(id), q))
	if not loot.is_empty():
		spawn_bag(z.global_position, loot, false)
	z.visible = false
	z.process_mode = Node.PROCESS_MODE_DISABLED
	_zombie_respawns.append({"z": z, "t": float(DB.zombie("respawn", 45))})
	GS.message.emit("Infectado abatido")


# ---------------------------------------------------------------- guardado

func world_dict() -> Dictionary:
	var bags: Array = []
	for b in get_tree().get_nodes_in_group("bag"):
		if is_instance_valid(b) and not b.is_queued_for_deletion() and not b.items.is_empty():
			bags.append(b.to_dict())
	return {
		"player": [player.global_position.x, player.global_position.z],
		"bags": bags,
	}


func _load_world(w: Dictionary) -> void:
	var p: Array = w.get("player", [0, 0])
	if not GS.dead:
		player.position = Vector3(float(p[0]), 0, float(p[1]))
	for b in w.get("bags", []):
		var pos: Array = b.get("pos", [0, 0])
		var items: Array = b.get("items", [])
		for it in items:
			it["qty"] = int(it["qty"])
			if it.has("dur"):
				it["dur"] = int(it["dur"])
		spawn_bag(Vector3(float(pos[0]), 0, float(pos[1])), items, bool(b.get("player", false)))


func save() -> void:
	GS.save_game(world_dict())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if player != null:
			save()
