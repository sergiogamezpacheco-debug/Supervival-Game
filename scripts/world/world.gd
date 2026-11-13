extends Node3D
## Escena principal: carga un mapa de data/maps.json (de momento el Refugio),
## genera recursos, criaturas y la zona de construcción, y coordina el modo
## construir, la muerte, la reaparición y el guardado automático.

const PlayerScript := preload("res://scripts/world/player.gd")
const ResourceScript := preload("res://scripts/world/resource_node.gd")
const CreatureScript := preload("res://scripts/world/creature.gd")
const BagScript := preload("res://scripts/world/bag.gd")
const WellScript := preload("res://scripts/world/well.gd")
const BaseScript := preload("res://scripts/world/base.gd")
const HudScript := preload("res://scripts/ui/hud.gd")

const SPAWN := Vector3(1, 0, 1)

var map_id := "refugio"
var map: Dictionary = {}
var player: CharacterBody3D
var hud: CanvasLayer
var camera: Camera3D
var base: Node3D
var rng := RandomNumberGenerator.new()
var _placed: Array[Vector3] = []
var _respawns: Array = []   # [{ "c": criatura, "t": segundos }]
var _death_timer := 0.0
var _autosave := 0.0
var _half := 45.0

# Modo construir
var build_mode := ""        # "" | place | upgrade | demolish
var build_id := ""
var build_rot := 0
var _ghost: Node3D
var _ghost_key := ""
var _build_cell := Vector2i.ZERO
var _build_side := 0
var _build_ok := false


func _ready() -> void:
	randomize()
	map = DB.maps.get(map_id, {})
	rng.seed = int(map.get("seed", 1337))
	_half = float(map.get("size", 90)) / 2.0
	_build_environment()

	hud = HudScript.new()
	add_child(hud)
	hud.build_selected.connect(_on_build_selected)
	hud.build_action.connect(_on_build_action)

	player = PlayerScript.new()
	player.position = SPAWN
	add_child(player)

	var base_half := float(map.get("base_half", 0))
	if base_half > 0.0:
		base = BaseScript.new(base_half)
		add_child(base)
		base.drop_items.connect(func(pos: Vector3, items: Array): spawn_bag(pos, items, false))

	var well := WellScript.new()
	well.position = Vector3(-7, 0, -5)
	well.add_to_group("obstacle")
	add_child(well)
	_placed.append(well.position)

	_spawn_resources(base_half + 2.0)
	_spawn_creatures()

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


func _free_spot(min_dist: float, avoid_center: float, square := true) -> Vector3:
	for attempt in 60:
		var p := Vector3(rng.randf_range(-_half + 2, _half - 2), 0, rng.randf_range(-_half + 2, _half - 2))
		var inside := maxf(absf(p.x), absf(p.z)) < avoid_center if square else p.length() < avoid_center
		if inside:
			continue
		var ok := true
		for q in _placed:
			if p.distance_to(q) < min_dist:
				ok = false
				break
		if ok:
			_placed.append(p)
			return p
	var fallback := Vector3(_half - 3, 0, rng.randf_range(-_half + 3, _half - 3))
	_placed.append(fallback)
	return fallback


func _spawn_resources(avoid: float) -> void:
	var res: Dictionary = map.get("resources", {})
	for kind in res:
		if not DB.resources.has(kind):
			push_error("Recurso desconocido en el mapa: %s" % kind)
			continue
		for i in int(res[kind]):
			var node := ResourceScript.new()
			node.setup(str(kind))
			node.position = _free_spot(2.2, avoid)
			node.rotation.y = rng.randf_range(0, TAU)
			add_child(node)


func _spawn_creatures() -> void:
	for g in map.get("creatures", []):
		var kind := str(g["type"])
		if not DB.creatures.has(kind):
			push_error("Criatura desconocida en el mapa: %s" % kind)
			continue
		var size: Array = g.get("size", [1, 1])
		for i in int(g.get("groups", 1)):
			var center := _free_spot(3.0, float(g.get("min_dist", 20)), false)
			for j in rng.randi_range(int(size[0]), int(size[1])):
				var c := CreatureScript.new()
				c.setup(kind)
				c.home = center + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
				c.position = c.home
				c.killed.connect(_on_creature_killed)
				add_child(c)


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
		if base:
			player.floor_y = base.floor_height(player.global_position)
		var t := find_target()
		player.target = t
		hud.set_action("" if t == null else t.action_label())

	if build_mode != "":
		_update_build()

	for entry in _respawns.duplicate():
		entry["t"] = float(entry["t"]) - delta
		if float(entry["t"]) <= 0.0:
			_respawns.erase(entry)
			entry["c"].revive()

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


# --------------------------------------------------------------- construir

func _on_build_selected(mode: String, id: String) -> void:
	if base == null:
		GS.message.emit("Aquí no se puede construir")
		return
	build_mode = mode
	build_id = id
	build_rot = 0
	_ghost_key = ""


func _on_build_action(action: String) -> void:
	match action:
		"rotate":
			build_rot = (build_rot + 1) % 4
			_ghost_key = ""
		"confirm":
			confirm_build()
		"exit":
			exit_build()


func exit_build() -> void:
	build_mode = ""
	build_id = ""
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	hud.set_build_info(false, "", "", false)


## Casilla y lado apuntados: 1,6 m delante del jugador.
func build_target() -> Array:
	var front: Vector3 = player.global_position + player.facing() * 1.6
	var c: Vector2i = base.cell_of(front)
	var side: int = base.nearest_side(c, front)
	if build_mode == "place" and base.is_edge_piece(build_id):
		side = posmod(side + build_rot, 4)
	return [c, side]


func _update_build() -> void:
	var tgt := build_target()
	_build_cell = tgt[0]
	_build_side = tgt[1]
	var text := ""
	var pos := Vector3.ZERO
	var rot_y := 0.0
	var mesh_key := ""
	match build_mode:
		"place":
			var why: String = base.check_place(build_id, _build_cell, _build_side, player.global_position)
			var cost: Dictionary = base.place_cost(build_id)
			_build_ok = why == "" and GS.has_cost(cost)
			text = "%s — %s" % [base.piece_name(build_id), DB.cost_text(cost)]
			if why != "":
				text += "\n" + why
			if base.is_edge_piece(build_id):
				var e: Vector3i = base.edge_of(_build_cell, _build_side)
				pos = base.edge_center(e) + Vector3(0, 0.12, 0)
				rot_y = 0.0 if e.z == 0 else 90.0
			else:
				pos = base.cell_center(_build_cell)
				pos.y = base.floor_height(pos) if DB.stations.has(build_id) else 0.0
				rot_y = build_rot * 90.0 if DB.stations.has(build_id) else 0.0
			mesh_key = "%s|%s|%s" % [build_id, _build_ok, rot_y]
		"upgrade", "demolish":
			var n: Node3D = base.target_at(_build_cell, _build_side)
			if n == null:
				_build_ok = false
				text = "Acércate a lo que quieras %s" % ("mejorar" if build_mode == "upgrade" else "desmontar")
			elif build_mode == "upgrade":
				var cost: Dictionary = base.upgrade_cost(n)
				if cost.is_empty():
					_build_ok = false
					text = "%s ya está al máximo" % n.display_name()
				else:
					_build_ok = GS.has_cost(cost)
					text = "%s → %s\n%s" % [n.display_name(), base.upgrade_name(n), DB.cost_text(cost)]
			else:
				var why: String = base.can_demolish(n)
				_build_ok = why == ""
				var refund: Dictionary = base.refund_of(n)
				var parts := PackedStringArray()
				for id in refund:
					parts.append("%s %d" % [DB.item_name(str(id)), int(refund[id])])
				text = "Desmontar %s (recuperas %s)" % [n.display_name(), ", ".join(parts) if parts.size() > 0 else "nada"]
				if why != "":
					text += "\n" + why
			if n:
				pos = n.global_position
				rot_y = n.rotation_degrees.y
			mesh_key = "sel|%s|%s" % [build_mode, n.get_instance_id() if n else 0]
	hud.set_build_info(true, build_mode, text, _build_ok)
	_update_ghost(mesh_key, pos, rot_y)


func _update_ghost(mesh_key: String, pos: Vector3, rot_y: float) -> void:
	if mesh_key != _ghost_key:
		_ghost_key = mesh_key
		if _ghost:
			_ghost.queue_free()
			_ghost = null
		if build_mode == "place":
			if DB.structures.has(build_id):
				_ghost = Builder.structure_mesh(str(DB.structures[build_id]["kind"]), Color.WHITE)
			else:
				_ghost = Builder.station_mesh(build_id, 1)
			Builder.tint(_ghost, Builder.ghost_mat(_build_ok))
		elif not mesh_key.ends_with("|0"):
			_ghost = Node3D.new()
			var col := Color(1.0, 0.85, 0.2, 0.35) if build_mode == "upgrade" else Color(1.0, 0.25, 0.2, 0.35)
			_ghost.add_child(Builder.part(Builder.box(Vector3(2.2, 2.9, 2.2)), col, Vector3(0, 1.45, 0), 0.5))
		if _ghost:
			add_child(_ghost)
	if _ghost:
		_ghost.global_position = pos
		_ghost.rotation_degrees.y = rot_y


func confirm_build() -> bool:
	if build_mode == "" or base == null:
		return false
	var tgt := build_target()
	var c: Vector2i = tgt[0]
	var side: int = tgt[1]
	var done := false
	match build_mode:
		"place":
			done = base.place(build_id, c, side, build_rot, player.global_position) != null
		"upgrade":
			var n: Node3D = base.target_at(c, side)
			done = n != null and base.upgrade(n)
		"demolish":
			var n2: Node3D = base.target_at(c, side)
			done = n2 != null and base.demolish(n2)
	_ghost_key = ""
	if done:
		save()
	return done


# ------------------------------------------------------- muerte y botín

func _on_player_died() -> void:
	if build_mode != "":
		exit_build()
	hud.close_panels()
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


func _on_creature_killed(c: Node3D) -> void:
	var loot: Array = c.roll_loot(rng)
	if not loot.is_empty():
		spawn_bag(c.global_position, loot, false)
	c.visible = false
	c.process_mode = Node.PROCESS_MODE_DISABLED
	_respawns.append({"c": c, "t": float(c.data.get("respawn", 45))})
	GS.message.emit("%s abatido" % str(c.data.get("name", "Enemigo")))


# ---------------------------------------------------------------- guardado

func world_dict() -> Dictionary:
	var bags: Array = []
	for b in get_tree().get_nodes_in_group("bag"):
		if is_instance_valid(b) and not b.is_queued_for_deletion() and not b.items.is_empty():
			bags.append(b.to_dict())
	return {
		"map": map_id,
		"player": [player.global_position.x, player.global_position.z],
		"bags": bags,
		"base": base.to_list() if base else [],
	}


func _load_world(w: Dictionary) -> void:
	var p: Array = w.get("player", [SPAWN.x, SPAWN.z])
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
	if base:
		base.load_list(w.get("base", []))


func save() -> void:
	GS.save_game(world_dict())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if player != null:
			save()
