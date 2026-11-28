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
const ContainerScript := preload("res://scripts/world/container.gd")
const CreatorScript := preload("res://scripts/ui/character_creator.gd")
const DayNightScript := preload("res://scripts/world/daynight.gd")
const StationScript := preload("res://scripts/world/station.gd")

signal travelled(to_map: String)

var SPAWN := Vector3(1, 0, 1)

var map_id := "refugio"
var map: Dictionary = {}
var route: Dictionary = {}     # andando por un camino (data/routes.json); vacío en las zonas
var _arriving := false
var player: CharacterBody3D
var hud: CanvasLayer
var camera: Camera3D
var base: Node3D
var rng := RandomNumberGenerator.new()
var _placed: Array[Vector3] = []
var _keepout: Array = []    # [Vector3 centro, radio] zonas sin recursos (edificios)
var _respawns: Array = []   # [{ "c": criatura, "t": segundos }]
var _death_timer := 0.0
var _autosave := 0.0
var _houses: Array = []      # casas de los caminos (para esconder el tejado al entrar)
var _dirty := -1.0   # segundos desde que cambió la mochila sin guardar (-1 = nada pendiente)
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
var creator: CanvasLayer = null
var daynight: Node
var _env: Environment
var _sun: DirectionalLight3D
var _was_night := false
var _night_check := 0.0
var _clock_t := 0.0


const FireScript := preload("res://scripts/world/fire.gd")
const TrapScript := preload("res://scripts/world/trap.gd")


func _ready() -> void:
	add_to_group("world")
	# Movimiento suave aunque la pantalla vaya a más (o menos) de 60 fps: el jugador y las
	# criaturas se dibujan interpolados entre pasos de física; lo que se mueve en _process
	# (cámara, interfaz, efectos) no se interpola.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	randomize()
	var t0 := Time.get_ticks_msec()
	var world := GS.load_game()
	map_id = GS.current_map
	GS.trace("cargando zona %s" % map_id)
	route = DB.routes.get(map_id, {})
	if route.is_empty():
		map = DB.maps.get(map_id, {})
	else:
		# andando por un camino entre dos zonas (cada vez cambia: no se guarda)
		map = {"name": route.get("name", map_id), "size": float(route["length"]) * 2.0 + 80.0, "seed": hash(map_id),
			"spawn": [0, -4], "night": {"type": "infectado", "count": 2}}
	var sp: Array = map.get("spawn", [1, 1])
	SPAWN = Vector3(float(sp[0]), 0, float(sp[1]))
	rng.seed = int(map.get("seed", 1337))
	_half = float(map.get("size", 90)) / 2.0
	_build_environment()

	hud = HudScript.new()
	add_child(hud)
	hud.build_selected.connect(_on_build_selected)
	hud.build_action.connect(_on_build_action)
	hud.travel_requested.connect(travel_to)
	hud.walk_requested.connect(walk_to)
	hud.edit_look_requested.connect(open_creator)
	hud.new_game_requested.connect(new_game)
	hud.set_location(map_id)

	player = PlayerScript.new()
	player.position = SPAWN
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_child(player)
	hud.add_minimap(self)

	var base_half := float(map.get("base_half", 0))
	if base_half > 0.0:
		base = BaseScript.new(base_half)
		add_child(base)
		base.drop_items.connect(func(pos: Vector3, items: Array): spawn_bag(pos, items, false))

	if route.is_empty():
		_spawn_prefabs()
		GS.trace("  edificios y cajas")
		_spawn_resources(base_half + 2.0 if base_half > 0.0 else 5.0)
		GS.trace("  recursos")
		_spawn_creatures()
		GS.trace("  criaturas")
		_houses = get_tree().get_nodes_in_group("casa")
	else:
		_build_route()
		GS.trace("  camino montado")

	GS.died.connect(_on_player_died)
	GS.inventory_changed.connect(func(): _dirty = maxf(_dirty, 0.0))
	if not world.is_empty() and route.is_empty():
		_load_world(world)
	daynight = DayNightScript.new()
	add_child(daynight)
	daynight.setup(_env, _sun, player)
	_update_clock()
	if not GS.pending_drop.is_empty():
		spawn_bag(player.global_position + Vector3(1.2, 0, 0.6), GS.pending_drop, true)
		GS.pending_drop = []
		GS.message.emit("Ahora llevas 8 bolsillos: lo que no cabía está en una bolsa a tu lado")
	camera.global_position = player.global_position + CAM_OFF * zoom()
	_update_camera(1.0)
	GS.message.emit(str(map.get("name", "")))
	GS.visit(map_id)
	GS.trace("zona %s lista en %d ms" % [map_id, Time.get_ticks_msec() - t0])
	if not GS.created and not GS.testing:
		open_creator()


## Primer arranque: pantalla de creación del superviviente (el juego espera).
func open_creator() -> void:
	creator = CreatorScript.new()
	add_child(creator)
	get_tree().paused = true
	creator.finished.connect(func():
		get_tree().paused = false
		creator.queue_free()
		creator = null
		save()
		GS.message.emit("Bienvenido, %s" % GS.player_name))


## Borra la partida y empieza de cero (ajustes).
func new_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
	GS.new_game()
	get_tree().paused = false
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


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
	_env = env

	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	if not route.is_empty():
		camera = Camera3D.new()
		camera.fov = 50
		camera.far = 120
		add_child(camera)
		return   # el camino trae su propio suelo (RouteBuilder)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_half * 2.0 + 30.0, _half * 2.0 + 30.0)
	ground.mesh = plane
	var gcol := Color(str(map.get("ground", "4f6b3a")))
	env.fog_density = float(map.get("fog", 0.012))
	ground.material_override = Builder.mat(gcol)
	add_child(ground)
	for i in 40:
		var patch := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		var s := rng.randf_range(2.0, 6.0)
		pm.size = Vector2(s, s * rng.randf_range(0.6, 1.4))
		patch.mesh = pm
		patch.material_override = Builder.mat(gcol.lightened(0.08) if i % 2 == 0 else gcol.darkened(0.12))
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
		var rel := p - SPAWN
		var inside := maxf(absf(rel.x), absf(rel.z)) < avoid_center if square else rel.length() < avoid_center
		if inside:
			continue
		var ok := true
		for k in _keepout:
			if p.distance_to(k[0]) < float(k[1]):
				ok = false
				break
		if not ok:
			continue
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


## Agua de las marismas (maps.json "water"): círculos [x, z, radio] de agua honda y poco honda,
## islotes secos dentro y una pasarela de tablas. 0 = seco, 1 = poco honda, 2 = honda.
func water_depth(p: Vector3) -> int:
	var w: Dictionary = map.get("water", {})
	if w.is_empty():
		return 0
	for c in w.get("islands", []):
		if Vector2(p.x - float(c[0]), p.z - float(c[1])).length() < float(c[2]):
			return 0
	var bw: Array = w.get("boardwalk", [])
	if bw.size() == 2 and _on_segment(p, bw[0], bw[1], 1.0):
		return 0
	for c in w.get("deep", []):
		if Vector2(p.x - float(c[0]), p.z - float(c[1])).length() < float(c[2]):
			return 2
	for c in w.get("shallow", []):
		if Vector2(p.x - float(c[0]), p.z - float(c[1])).length() < float(c[2]):
			return 1
	return 0


static func _on_segment(p: Vector3, a: Array, b: Array, half_w: float) -> bool:
	var pa := Vector2(p.x - float(a[0]), p.z - float(a[1]))
	var ab := Vector2(float(b[0]) - float(a[0]), float(b[1]) - float(a[1]))
	var t := clampf(pa.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return (pa - ab * t).length() < half_w


static func _disc(r: float, h: float) -> CylinderMesh:
	var c := Builder.cyl(r, r, h)
	c.radial_segments = 40
	return c


func _build_water() -> void:
	var w: Dictionary = map.get("water", {})
	if w.is_empty():
		return
	var node := Node3D.new()
	node.name = "Agua"
	add_child(node)
	var shallow := Color("5a8476")
	var deep := Color("2f5a62")
	for c in w.get("shallow", []):
		node.add_child(Builder.part(_disc(float(c[2]), 0.04), shallow, Vector3(float(c[0]), 0.03, float(c[1]))))
		node.add_child(Builder.part(_disc(float(c[2]) + 0.6, 0.02), Color("4a4630"), Vector3(float(c[0]), 0.015, float(c[1]))))
	for c in w.get("deep", []):
		node.add_child(Builder.part(_disc(float(c[2]), 0.04), deep, Vector3(float(c[0]), 0.05, float(c[1]))))
	for c in w.get("islands", []):
		node.add_child(Builder.part(_disc(float(c[2]) + 0.2, 0.2), Color("5a5a3a"), Vector3(float(c[0]), 0.08, float(c[1]))))
	# juncos y eneas en las orillas
	var rr := RandomNumberGenerator.new()
	rr.seed = int(map.get("seed", 1))
	for c in w.get("shallow", []):
		var rad := float(c[2])
		for k in int(rad * 1.6):
			var a := rr.randf() * TAU
			var d := rad + rr.randf_range(-1.2, 0.8)
			var base := Vector3(float(c[0]) + cos(a) * d, 0, float(c[1]) + sin(a) * d)
			for i in 4:
				var h := rr.randf_range(0.7, 1.4)
				var reed := Builder.part(Builder.box(Vector3(0.04, h, 0.04)), Color("7a8a4a").darkened(rr.randf() * 0.2), base + Vector3(rr.randf_range(-0.3, 0.3), h / 2.0, rr.randf_range(-0.3, 0.3)))
				reed.rotation.z = rr.randf_range(-0.2, 0.2)
				node.add_child(reed)
				if i == 0:
					node.add_child(Builder.part(Builder.box(Vector3(0.07, 0.2, 0.07)), Color("5a3e26"), reed.position + Vector3(0, h / 2.0 - 0.1, 0)))
	# pasarela de tablas (llega hasta el agua honda; el islote queda al otro lado)
	var bw: Array = w.get("boardwalk", [])
	if bw.size() == 2:
		var a := Vector3(float(bw[0][0]), 0, float(bw[0][1]))
		var b := Vector3(float(bw[1][0]), 0, float(bw[1][1]))
		var n := int(a.distance_to(b) / 0.45)
		var dir := (b - a).normalized()
		for k in n:
			var pl := Builder.part(Builder.box(Vector3(1.6, 0.06, 0.38)), Color("7a5a3a").darkened(0.08 * (k % 3)), a + dir * (k * 0.45) + Vector3(0, 0.22, 0))
			pl.rotation.y = atan2(dir.x, dir.z)
			node.add_child(pl)
		for k in int(n / 4) + 1:
			for sd in [-0.75, 0.75]:
				var post_p: Vector3 = a + dir * (k * 1.8) + dir.cross(Vector3.UP) * sd
				node.add_child(Builder.part(Builder.cyl(0.06, 0.06, 0.6), Color("4a3a26"), post_p + Vector3(0, 0.2, 0)))
	Builder.merge(node)
	_keepout.append_array(w.get("deep", []).map(func(c): return [Vector3(float(c[0]), 0, float(c[1])), float(c[2]) + 1.0]))


## Lo recogido sale volando del suelo a la mochila (icono del objeto y cantidad).
func fly_icon(item_id: String, from: Vector3, qty := 1) -> void:
	var tex := DB.item_icon(item_id)
	if tex == null or player == null:
		return
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.no_depth_test = true
	sp.pixel_size = 0.55 / float(maxi(tex.get_width(), 1))
	sp.render_priority = 10
	add_child(sp)
	sp.global_position = from + Vector3(0, 0.4, 0)
	if qty > 1:
		var l := Label3D.new()
		l.text = "+%d" % qty
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 48
		l.pixel_size = 0.006
		l.outline_size = 10
		l.position = Vector3(0.3, -0.2, 0)
		sp.add_child(l)
	var tw := sp.create_tween()
	tw.tween_property(sp, "global_position", from + Vector3(0, 1.4, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(k: float):
		if is_instance_valid(player):
			sp.global_position = (from + Vector3(0, 1.4, 0)).lerp(player.global_position + Vector3(0, 1.2, 0), k)
			sp.scale = Vector3.ONE * lerpf(1.0, 0.4, k), 0.0, 1.0, 0.35)
	tw.tween_callback(sp.queue_free)


var _edge_cd := 0.0


## Al llegar andando al borde de la zona se abre el mapa (para ir a otro sitio, andando o viajando);
## el jugador vuelve un paso atrás para que no se abra otra vez sin querer.
func _check_zone_edge(delta: float) -> void:
	_edge_cd = maxf(_edge_cd - delta, 0.0)
	var p: Vector3 = player.global_position
	var lim := _half - 1.2
	if _edge_cd > 0.0 or hud.any_panel_open() or build_mode != "":
		return
	if absf(p.x) < lim and absf(p.z) < lim:
		return
	_edge_cd = 2.5
	var back := Vector3(-signf(p.x) if absf(p.x) >= lim else 0.0, 0, -signf(p.z) if absf(p.z) >= lim else 0.0)
	player.global_position = p + back * 2.0
	player.reset_physics_interpolation()
	GS.trace("borde de la zona %s: se abre el mapa" % map_id)
	hud.open_map()


var _last_dry := Vector3.ZERO
var _water_msg := 0.0


## Cada fotograma: el agua frena y en la honda no se entra sin traje de buzo.
func _update_water(delta: float) -> void:
	var d := water_depth(player.global_position)
	_water_msg = maxf(_water_msg - delta, 0.0)
	if d == 2 and not GS.can_dive():
		player.global_position = _last_dry
		player.velocity = Vector3.ZERO
		if _water_msg <= 0.0:
			_water_msg = 3.0
			GS.message.emit("El agua cubre demasiado: necesitas un traje de buzo")
		d = 1
	elif d < 2:
		_last_dry = player.global_position
	player.terrain_mult = 1.0 if d == 0 else float(DB.bal("water_deep_speed" if d == 2 else "water_shallow_speed", 0.7))


func _spawn_prefabs() -> void:
	_build_water()
	# poblado amurallado (La Atalaya): empalizada, torres con arqueros, casas, huertos
	if map.has("settlement"):
		_keepout.append_array(Settlement.build(self, map["settlement"]))
	if map.has("camp"):   # Base Centinela: valla con un tramo caído, puerta cerrada y torres
		Settlement.build_camp(self, map["camp"])
	# casas por dentro con sus muebles registrables (barracones, puesto de mando...)
	for h in map.get("houses", []):
		var lay := str(h[0])
		var hn := Node3D.new()
		hn.position = Vector3(float(h[1]), 0, float(h[2]))
		hn.rotation_degrees.y = float(h[3]) * 90.0
		add_child(hn)
		var hs := RouteBuilder.layout_size(lay)
		var casa := RouteBuilder.house(hn, hs.x, hs.y, Color(str(h[4])) if h.size() > 4 else Color("b9a684"),
			Color(str(h[5])) if h.size() > 5 else Color("7a3a2a"), false, lay)
		_keepout.append([hn.position, maxf(hs.x, hs.y) * 0.75])
		for m in casa.find_children("*", "Marker3D", true, false):
			if m.has_meta("tipo") and DB.containers.has(str(m.get_meta("tipo"))):
				var box := ContainerScript.new()
				box.setup(str(m.get_meta("tipo")), rng)
				add_child(box)
				box.global_transform = (m as Node3D).global_transform
			m.queue_free()
	# puestos de los comerciantes (estaciones de cambio, fuera de la construcción)
	for st in map.get("stations", []):
		var sp: Array = st.get("pos", [0, 0])
		var node := StationScript.new()
		node.stage = DB.station_phases(str(st["id"])).size()
		node.setup(str(st["id"]), 1, "z|%s" % st["id"], int(st.get("rot", 0)))
		node.position = Vector3(float(sp[0]), 0, float(sp[1]))
		add_child(node)
		_keepout.append([node.position, 3.0])
	for pf in map.get("prefabs", []):
		var pos_a: Array = pf.get("pos", [0, 0])
		var pos := Vector3(float(pos_a[0]), 0, float(pos_a[1]))
		var rot := int(pf.get("rot", 0))
		var kind := str(pf.get("type", ""))
		var node: Node3D
		if kind == "pozo":
			node = WellScript.new()
			node.add_to_group("obstacle")
		elif kind != "":   # "" = solo contenedores sueltos (coche abandonado, superviviente muerto)
			node = Builder.prefab(kind)
		if node:
			node.position = pos
			node.rotation_degrees.y = rot * 90.0
			add_child(node)
		_keepout.append([pos, 2.5 if kind == "pozo" else (6.5 if kind != "" else 4.0)])
		for c in pf.get("containers", []):
			var off: Array = c.get("offset", [0, 0])
			var local := Vector3(float(off[0]), 0, float(off[1])).rotated(Vector3.UP, deg_to_rad(rot * 90.0))
			var box := ContainerScript.new()
			box.setup(str(c["type"]), rng)
			box.position = pos + local
			box.rotation_degrees.y = rot * 90.0
			add_child(box)


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
	var gi := -1
	for g in map.get("creatures", []):
		gi += 1
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
				if g.has("respawn"):
					# vuelve con el reloj real (también con el juego cerrado): ver _on_creature_killed
					c.set_meta("respawn_key", "%d_%d" % [gi, j])
					c.set_meta("respawn_range", g["respawn"])
					var left := float(GS.dead_until.get(GS.current_map, {}).get("%d_%d" % [gi, j], 0.0)) - GS.now()
					if left > 0.0:
						c.visible = false
						c.process_mode = Node.PROCESS_MODE_DISABLED
						_respawns.append({"c": c, "t": left})


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
		player.action_held = hud.action_button.held and not hud.any_panel_open()
		player.position.x = clampf(player.position.x, -_half, _half)
		player.position.z = clampf(player.position.z, -_half, _half)
		if not route.is_empty():
			_check_route_exit()
		if not _houses.is_empty():
			_update_houses()
		if map.has("water"):
			_update_water(delta)
		if route.is_empty():
			_check_zone_edge(delta)
		if base:
			player.floor_y = base.floor_height(player.global_position)
		var t := find_target()
		player.target = t
		hud.set_action("" if t == null else t.action_label(), player.action_info())
		hud.set_status("Envenenado" if GS.poison > 0.0 else "")

	if build_mode != "":
		_update_build()

	daynight.update(delta)
	_night_check -= delta
	if _night_check <= 0.0:
		_night_check = 1.0
		_update_night()
		# La comida de los cofres también se estropea (las conservas no)
		for st in get_tree().get_nodes_in_group("station"):
			if st.is_chest():
				GS.spoil(st.storage)
	_clock_t -= delta
	if _clock_t <= 0.0:
		_clock_t = 0.5
		_update_clock()

	for entry in _respawns.duplicate():
		entry["t"] = float(entry["t"]) - delta
		if float(entry["t"]) <= 0.0:
			_respawns.erase(entry)
			entry["c"].revive()

	_autosave += delta
	# Lo que entra o sale de la mochila se guarda enseguida (al pararte, o a los 3 s como mucho):
	# si el móvil cierra el juego de golpe no se pierde lo recogido.
	if _dirty >= 0.0:
		_dirty += delta
		if (_dirty >= 0.5 and player.move_input.length() < 0.1) or _dirty >= 3.0:
			_dirty = -1.0
			_autosave = 0.0
			save()
	# Se guarda con el jugador parado (guardar a mitad de carrera da un tirón); si no para, igualmente al rato
	var every := float(DB.bal("autosave_seconds", 15))
	if _autosave >= every and (player.move_input.length() < 0.1 or _autosave >= every * 4.0):
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
	if best_enemy == null and GS.hand_throws():
		# Con un molotov en la mano se apunta al enemigo más cercano a tiro
		var rng := float(DB.bal("throw_range", 11.0))
		for n in get_tree().get_nodes_in_group("enemy"):
			var node := n as Node3D
			if node == null or not node.is_inside_tree() or not node.visible or not node.can_interact():
				continue
			var d := Vector2(node.global_position.x - player.global_position.x,
				node.global_position.z - player.global_position.z).length()
			if d <= rng and d < best_enemy_d:
				best_enemy_d = d
				best_enemy = node
	return best_enemy if best_enemy != null else best


# ------------------------------------------------------- molotov y trampas

## Lanza lo que llevas en la mano (molotov) hacia una criatura.
func throw_at(t: Node3D) -> Node3D:
	if not GS.hand_throws() or t == null:
		return null
	var d := DB.item(str(GS.hand["id"]))
	var f := FireScript.new()
	f.from = player.global_position + Vector3(0, 1.4, 0)
	f.to = Vector3(t.global_position.x, player.floor_y, t.global_position.z)
	f.radius = float(d.get("fire_radius", 2.6))
	f.duration = float(d.get("fire_time", 5.0))
	f.dps = float(d.get("damage", 14))
	add_child(f)
	GS.spend_hand()
	SFX.play("lanzar")
	player.make_noise(float(DB.bal("noise_hit", 9.0)))
	return f


func spawn_trap(pos: Vector3, uses: int, rot_y := 0.0) -> Node3D:
	var t := TrapScript.new()
	t.uses = uses
	add_child(t)
	t.global_position = pos
	t.rotation.y = rot_y
	return t


## Coloca en el suelo, delante de ti, la trampa de la casilla i del inventario.
## Baúles, estanterías y armarios: se colocan desde la mochila con el modo construir (gastan el mueble).
func place_furniture(station_id: String) -> String:
	hud.close_panels()
	if base == null:
		GS.message.emit("Solo se puede colocar en el refugio")
		return "Solo se puede colocar en el refugio"
	_on_build_selected("place", station_id)
	GS.message.emit("Elige dónde poner %s y confirma" % DB.station_name(station_id).to_lower())
	return ""


func place_trap(i: int) -> String:
	var s = GS.slots[i] if i >= 0 and i < GS.slots.size() else null
	var why := ""
	if s == null or str(DB.item(str(s["id"])).get("type", "")) != "trap":
		why = "Eso no es una trampa"
	var pos: Vector3 = player.global_position + player.facing() * 1.3
	pos.y = base.floor_height(pos) if base else 0.0
	for t in get_tree().get_nodes_in_group("trap"):
		if why == "" and (t as Node3D).global_position.distance_to(pos) < 1.4:
			why = "Ya hay una trampa ahí"
	if why != "":
		GS.message.emit(why)
		return why
	var max_uses := int(DB.item(str(s["id"])).get("durability", 4))
	spawn_trap(pos, int(s.get("dur", max_uses)), player._visual.rotation.y)
	s["qty"] = int(s["qty"]) - 1
	if int(s["qty"]) <= 0:
		GS.slots[i] = null
	GS.inventory_changed.emit()
	GS.message.emit("Trampa colocada")
	hud.close_panels()
	return ""


## Distancia de la cámara (1 = la de antes). Se cambia pellizcando con dos dedos o en Ajustes.
const CAM_OFF := Vector3(0, 13.0, 8.5)
const ZOOM_MIN := 0.55
const ZOOM_MAX := 1.3
var _pinch := {}       # dedo -> posición (solo los que no llevan el joystick)
var _pinch_d := 0.0


func zoom() -> float:
	return clampf(float(SFX.settings.get("zoom", 0.85)), ZOOM_MIN, ZOOM_MAX)


func set_zoom(z: float) -> void:
	SFX.settings["zoom"] = clampf(z, ZOOM_MIN, ZOOM_MAX)


func _unhandled_input(ev: InputEvent) -> void:
	if hud == null or hud.any_panel_open():
		_pinch.clear()
		return
	if ev is InputEventScreenTouch:
		if ev.pressed and ev.index != hud.joystick._touch:
			_pinch[ev.index] = ev.position
		else:
			_pinch.erase(ev.index)
		_pinch_d = 0.0
	elif ev is InputEventScreenDrag and _pinch.has(ev.index):
		_pinch[ev.index] = ev.position
		if _pinch.size() == 2:
			var p: Array = _pinch.values()
			var d: float = (p[0] as Vector2).distance_to(p[1])
			if _pinch_d > 0.0 and d > 1.0:
				set_zoom(zoom() * _pinch_d / d)   # separar los dedos acerca
			_pinch_d = d
	elif ev is InputEventMagnifyGesture:
		set_zoom(zoom() / ev.factor)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom() * 0.92)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom() * 1.08)


func _update_camera(delta: float) -> void:
	var off := CAM_OFF * zoom()
	var want: Vector3 = player.get_global_transform_interpolated().origin + off
	camera.global_position = camera.global_position.lerp(want, clampf(delta * 6.0, 0.0, 1.0))
	camera.look_at(camera.global_position - off, Vector3.UP)
	if player.shake > 0.0:
		var k: float = player.shake * 0.6
		camera.global_position += Vector3(randf_range(-k, k), randf_range(-k, k) * 0.5, randf_range(-k, k))


# ------------------------------------------------------------- noche

func _update_clock() -> void:
	hud.set_clock(GS.clock_text(), GS.is_night(), GS.raining())


## Al caer la noche aparecen infectados alrededor; al amanecer se van los lejanos.
func _update_night() -> void:
	var night := GS.is_night()
	if night and not _was_night:
		spawn_night()
	elif not night and _was_night:
		for c in get_tree().get_nodes_in_group("night_spawn"):
			if not c.visible or c.global_position.distance_to(player.global_position) > 10.0:
				c.queue_free()
	_was_night = night


func spawn_night() -> void:
	var cfg: Dictionary = map.get("night", {})
	var kinds: Array = cfg.get("types", [cfg.get("type", "infectado")])
	var count := int(cfg.get("count", DB.bal("night_extra", 3)))
	if count <= 0 or rng.randf() > float(cfg.get("chance", 1.0)):
		return
	for i in count:
		var kind := str(kinds[i % kinds.size()])
		if not DB.creatures.has(kind):
			continue
		var ang := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(14.0, 22.0)
		var pos := player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
		pos.x = clampf(pos.x, -_half + 1.0, _half - 1.0)
		pos.z = clampf(pos.z, -_half + 1.0, _half - 1.0)
		if not route.is_empty():   # dentro del pasillo
			var cx := RouteBuilder.center_x(route, pos.z)
			pos.x = clampf(pos.x, cx - RouteBuilder.HALF + 1.5, cx + RouteBuilder.HALF - 1.5)
			pos.z = clampf(pos.z, -float(route["length"]) + 6.0, -6.0)
		var c := CreatureScript.new()
		c.setup(kind)
		c.home = player.global_position.lerp(pos, 0.4)
		c.position = pos
		c.add_to_group("night_spawn")
		c.killed.connect(_on_creature_killed)
		add_child(c)
	GS.message.emit("Cae la noche: se oyen pasos entre los árboles…")


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


# ------------------------------------------------------------------- viajar

func enemies_near(radius: float) -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.visible and e.hp > 0.0 and e.global_position.distance_to(player.global_position) < radius:
			return true
	return false


## Viaja a otra zona. Devuelve "" si sale bien o el motivo si no.
## Objeto clave que hay que llevar para viajar a una zona ("a|b" = cualquiera de ellos).
func has_key_item(id: String) -> bool:
	var k := str(DB.maps.get(id, {}).get("key_item", ""))
	if k == "":
		return true
	for alt in k.split("|"):
		if GS.count(alt) > 0:
			return true
	return false


## Zona de la que "estás" a efectos del mapa (en un camino, la de salida).
func here_id() -> String:
	return map_id if route.is_empty() else (GS.route_from if GS.route_from != "" else str(route["from"]))


## Lo que impide ir a una zona (vale para el viaje rápido y para ir andando), o "".
func _travel_block(id: String) -> String:
	if id == map_id:
		return "Ya estás aquí"
	if not DB.maps.has(id):
		return "Aún no se puede ir a ese lugar"
	if GS.dead:
		return "Estás muerto"
	if DB.map_piece(id) > GS.map_pieces:
		return "Te falta ese trozo del mapa"
	if GS.level < DB.map_unlock(id):
		return "Necesitas nivel %d para ir allí" % DB.map_unlock(id)
	if not has_key_item(id):
		return "Para ir allí necesitas %s" % str(DB.maps[id].get("key_text", DB.maps[id].get("key_item", "")))
	if enemies_near(10.0):
		return "Hay enemigos cerca: aléjate antes de viajar"
	return ""


## Ir andando a una zona vecina por su camino (sin gastar energía).
func walk_to(id: String) -> String:
	var why := _travel_block(id)
	var rid := DB.route_between(here_id(), id)
	if why == "" and rid == "":
		why = "No hay camino directo hasta allí"
	if why == "" and not route.is_empty():
		why = "Ya vas por un camino"
	if why != "":
		GS.message.emit(why)
		return why
	if build_mode != "":
		exit_build()
	save()
	GS.route_from = map_id
	GS.current_map = rid
	GS.save_game({})
	travelled.emit(rid)
	if get_tree().current_scene == self:
		_change_zone()
	return ""


func _build_route() -> void:
	var root := Node3D.new()
	root.name = "Camino"
	add_child(root)
	var info := RouteBuilder.build(root, route, randi())
	# si vienes del final del camino, apareces allí
	SPAWN = info["exit"] if GS.route_from == str(route["to"]) else info["spawn"]
	player.position = SPAWN
	player.reset_physics_interpolation()
	for r in info["resources"]:
		if not DB.resources.has(str(r[0])):
			continue
		var node := ResourceScript.new()
		node.setup(str(r[0]))
		node.position = r[1]
		node.rotation.y = rng.randf_range(0, TAU)
		add_child(node)
	# muebles de las casas: lo que se dejó dentro se recuerda un día (reloj real); luego se rellenan
	var refill := float(DB.bal("house_refill_seconds", 86400))
	for f in info.get("containers", []):
		if not DB.containers.has(str(f[0])):
			continue
		var key := "%s|%s" % [map_id, f[2]]
		var saved: Dictionary = GS.route_loot.get(key, {})
		var fresh := not saved.is_empty() and GS.now() - float(saved.get("t", 0.0)) < refill
		var box := ContainerScript.new()
		box.setup(str(f[0]), rng, saved.get("items") if fresh else null)
		box.loot_key = key
		box.opened_t = float(saved.get("t", 0.0)) if fresh else 0.0
		add_child(box)
		box.global_transform = f[1]
	_houses = get_tree().get_nodes_in_group("casa")
	for c in info["creatures"]:
		if not DB.creatures.has(str(c[0])):
			continue
		var cr := CreatureScript.new()
		cr.setup(str(c[0]))
		cr.home = c[1]
		cr.position = c[1]
		cr.killed.connect(_on_creature_killed)
		add_child(cr)


## Al llegar a un extremo del camino entras en esa zona.
## Cambio de zona: aviso de «Cargando…» (se dibuja antes de que el móvil se ponga a montar la
## zona nueva) y queda apuntado en el registro.
func _change_zone() -> void:
	GS.trace("cambio de zona -> %s" % GS.current_map)
	set_process(false)
	set_physics_process(false)
	if hud:
		hud.show_loading(DB.maps.get(GS.current_map, DB.routes.get(GS.current_map, {})).get("name", ""))
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _check_route_exit() -> void:
	var L := float(route["length"])
	if player.position.z > 1.5:
		_route_arrive(str(route["from"]))
	elif player.position.z < -L - 1.5:
		_route_arrive(str(route["to"]))


func _route_arrive(dest: String) -> void:
	if _arriving:
		return
	_arriving = true
	GS.trace("final del camino %s: entras en %s (z=%.1f)" % [map_id, dest, player.position.z])
	var st: Dictionary = GS.maps_state.get(dest, {})
	st.erase("player")   # apareces en la entrada de la zona
	GS.route_from = ""
	GS.current_map = dest
	GS.save_game(st)
	travelled.emit(dest)
	if get_tree().current_scene == self:
		_change_zone()


## Viaje rápido desde el mapa: gasta energía de viaje (se recarga con el tiempo).
func travel_to(id: String) -> String:
	var why := _travel_block(id)
	if why != "":
		GS.message.emit(why)
		return why
	var cost := DB.travel_energy_cost(here_id(), id)
	if not GS.spend_travel_energy(cost):
		why = "Te falta energía de viaje (%d de %d): ve andando por el camino o espera a que se recargue" % [int(GS.travel_energy_now()), cost]
		GS.message.emit(why)
		return why
	if build_mode != "":
		exit_build()
	if route.is_empty():
		save()
	GS.route_from = ""
	var dest: Dictionary = GS.maps_state.get(id, {})
	dest.erase("player")   # al llegar apareces en la entrada de la zona
	GS.current_map = id
	GS.save_game(dest)
	travelled.emit(id)
	if get_tree().current_scene == self:
		_change_zone()
	return ""


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
	if map_id != "refugio":
		# Se reaparece siempre en el refugio. La mochila se queda en la zona.
		save()
		var dest: Dictionary = GS.maps_state.get("refugio", {})
		dest.erase("player")
		GS.current_map = "refugio"
		GS.save_game(dest)
		travelled.emit("refugio")
		if get_tree().current_scene == self:
			_change_zone()
		return
	player.global_position = SPAWN
	player.reset_physics_interpolation()
	camera.global_position = SPAWN + CAM_OFF * zoom()


func _on_creature_killed(c: Node3D) -> void:
	var loot: Array = c.roll_loot(rng)
	if not loot.is_empty():
		spawn_bag(c.global_position, loot, false)
	c.visible = false
	c.process_mode = Node.PROCESS_MODE_DISABLED
	if c.is_in_group("night_spawn"):
		c.queue_free()    # los de la noche no vuelven
	elif c.has_meta("respawn_key"):
		# grupos con "respawn": [mín, máx] s de reloj real (el refugio: casi no vuelven)
		var r: Array = c.get_meta("respawn_range")
		var secs := rng.randf_range(float(r[0]), float(r[1]))
		if not GS.dead_until.has(GS.current_map):
			GS.dead_until[GS.current_map] = {}
		GS.dead_until[GS.current_map][str(c.get_meta("respawn_key"))] = GS.now() + secs
		_respawns.append({"c": c, "t": secs})
	else:
		_respawns.append({"c": c, "t": float(c.data.get("respawn", 45))})
	GS.message.emit("%s abatido" % str(c.data.get("name", "Enemigo")))
	var xp_kill: int = int(c.data.get("xp", round(float(c.data.get("health", 20)) * DB.xp_value("kill_default_per_hp", 0.25))))
	GS.add_xp(maxi(1, xp_kill))


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
		"traps": get_tree().get_nodes_in_group("trap").filter(func(t): return not t.is_queued_for_deletion()).map(func(t): return t.to_dict()),
	}


func _load_world(w: Dictionary) -> void:
	var p: Array = w.get("player", [SPAWN.x, SPAWN.z])
	if not GS.dead:
		player.position = Vector3(float(p[0]), 0, float(p[1]))
		player.reset_physics_interpolation()
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
	for t in w.get("traps", []):
		var tp: Array = t.get("pos", [0, 0])
		var tpos := Vector3(float(tp[0]), 0, float(tp[1]))
		tpos.y = base.floor_height(tpos) if base else 0.0
		spawn_trap(tpos, int(t.get("uses", 4)), float(t.get("rot", 0.0)))


func save() -> void:
	if not route.is_empty():
		_save_route_loot()
	GS.save_game(world_dict() if route.is_empty() else {})


## Camino: lo que queda en los muebles ya registrados (y se olvida lo que lleva más de un día).
func _save_route_loot() -> void:
	var refill := float(DB.bal("house_refill_seconds", 86400))
	for k in GS.route_loot.keys():
		if GS.now() - float(GS.route_loot[k].get("t", 0.0)) >= refill:
			GS.route_loot.erase(k)
	for c in get_tree().get_nodes_in_group("container"):
		if c.get("loot_key") != null and c.loot_key != "" and c.opened_t > 0.0:
			GS.route_loot[c.loot_key] = {"t": c.opened_t, "items": c.storage.duplicate(true)}


## Dentro de una casa se esconden el tejado y lo alto de las paredes para ver las habitaciones.
func _update_houses() -> void:
	var p: Vector3 = player.global_position
	for h in _houses:
		if not is_instance_valid(h):
			continue
		var lp: Vector3 = h.to_local(p)
		var half: Vector2 = h.get_meta("half")
		var inside := absf(lp.x) < half.x + 0.2 and absf(lp.z) < half.y + 0.2
		if h.get_node("Tejado").visible == inside:
			h.get_node("Tejado").visible = not inside
			h.get_node("Alto").visible = not inside


func _notification(what: int) -> void:
	# Android: al salir del juego (inicio, apps recientes) llega antes FOCUS_OUT que PAUSED, y PAUSED
	# a veces ya no da tiempo: se guarda con cualquiera de los dos.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if player != null:
			save()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Botón Atrás de Android: cierra la ventana abierta (nunca sale del juego de golpe)
		if hud != null and hud.any_panel_open():
			hud.close_panels()
		elif build_mode != "":
			exit_build()
