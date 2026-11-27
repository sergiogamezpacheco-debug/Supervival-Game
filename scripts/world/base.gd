extends Node3D
## Refugio: cuadrícula de construcción.
##  - Cimientos y estaciones/cofres ocupan una casilla ("i,j").
##  - Paredes y puertas van en los bordes de las casillas ("i,j,d"):
##      d = 0 → borde horizontal (a lo largo de X) en z = j * celda
##      d = 1 → borde vertical (a lo largo de Z) en x = i * celda
##    y necesitan un cimiento al menos a un lado.

signal drop_items(pos: Vector3, items: Array)

const StructureScript := preload("res://scripts/world/structure.gd")
const StationScript := preload("res://scripts/world/station.gd")
const FOUNDATION_H := 0.12

var cell := 2.0
var half := 18.0
var foundations: Dictionary = {}   # "i,j" -> estructura
var edges: Dictionary = {}         # "i,j,d" -> estructura
var objects: Dictionary = {}       # "i,j" -> estación o cofre


func _init(p_half: float = 18.0) -> void:
	half = p_half
	cell = float(DB.bal("grid_cell", 2.0))


func _ready() -> void:
	add_child(Builder.base_border(half))


# ------------------------------------------------------------- geometría

func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.z / cell))


func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * cell, 0.0, (c.y + 0.5) * cell)


static func ckey(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


static func ekey(e: Vector3i) -> String:
	return "%d,%d,%d" % [e.x, e.y, e.z]


static func parse_key(k: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for p in k.split(","):
		out.append(int(p))
	return out


## Lado de una casilla → borde. 0 norte, 1 este, 2 sur, 3 oeste.
func edge_of(c: Vector2i, side: int) -> Vector3i:
	match posmod(side, 4):
		0: return Vector3i(c.x, c.y, 0)
		1: return Vector3i(c.x + 1, c.y, 1)
		2: return Vector3i(c.x, c.y + 1, 0)
		_: return Vector3i(c.x, c.y, 1)


func edge_center(e: Vector3i) -> Vector3:
	if e.z == 0:
		return Vector3((e.x + 0.5) * cell, 0.0, e.y * cell)
	return Vector3(e.x * cell, 0.0, (e.y + 0.5) * cell)


func edge_cells(e: Vector3i) -> Array:
	if e.z == 0:
		return [Vector2i(e.x, e.y - 1), Vector2i(e.x, e.y)]
	return [Vector2i(e.x - 1, e.y), Vector2i(e.x, e.y)]


## Lado de la casilla más cercano a un punto.
func nearest_side(c: Vector2i, p: Vector3) -> int:
	var best := 0
	var best_d := INF
	for s in 4:
		var d := edge_center(edge_of(c, s)).distance_to(Vector3(p.x, 0, p.z))
		if d < best_d:
			best_d = d
			best = s
	return best


func in_base(c: Vector2i) -> bool:
	return c.x * cell >= -half and (c.x + 1) * cell <= half and c.y * cell >= -half and (c.y + 1) * cell <= half


func has_foundation(c: Vector2i) -> bool:
	return foundations.has(ckey(c))


func floor_height(p: Vector3) -> float:
	return FOUNDATION_H if has_foundation(cell_of(p)) else 0.0


static func is_edge_piece(id: String) -> bool:
	var k := str(DB.structures.get(id, {}).get("kind", ""))
	return k == "wall" or k == "door"


static func place_cost(id: String) -> Dictionary:
	if DB.structures.has(id):
		return DB.structure_tier(id, 0).get("cost", {})
	return DB.station_build_cost(id)


static func piece_name(id: String) -> String:
	if DB.structures.has(id):
		return str(DB.structure_tier(id, 0).get("name", id))
	return DB.station_name(id)


# ------------------------------------------------------------ colocación

func _blocked_by_world(pos: Vector3, radius: float) -> bool:
	for r in get_tree().get_nodes_in_group("resource"):
		var rr := float(r.data.get("radius", 0.0))
		if rr > 0.0 and Vector2(r.global_position.x - pos.x, r.global_position.z - pos.z).length() < radius + rr:
			return true
	for o in get_tree().get_nodes_in_group("obstacle"):
		if Vector2(o.global_position.x - pos.x, o.global_position.z - pos.z).length() < radius + 1.0:
			return true
	return false


## Devuelve "" si se puede colocar o el motivo por el que no.
## Nivel que pide colocar esta pieza (0 si no hay bloqueo).
static func unlock_level(id: String) -> int:
	if DB.structures.has(id):
		return DB.tier_unlock(id, 0)
	return DB.station_unlock(id)


func check_place(id: String, c: Vector2i, side: int, player_pos: Vector3) -> String:
	if GS.level < unlock_level(id):
		return "Se desbloquea en el nivel %d" % unlock_level(id)
	if not in_base(c):
		return "Fuera de la zona del refugio"
	if is_edge_piece(id):
		var e := edge_of(c, side)
		if edges.has(ekey(e)):
			return "Ya hay algo en ese borde"
		var cells := edge_cells(e)
		if not (has_foundation(cells[0]) or has_foundation(cells[1])):
			return "Necesita un cimiento al lado"
		var ec := edge_center(e)
		var along := Vector2(player_pos.x - ec.x, player_pos.z - ec.z)
		var lateral := absf(along.x) if e.z == 0 else absf(along.y)
		var across := absf(along.y) if e.z == 0 else absf(along.x)
		if lateral < cell / 2.0 + 0.3 and across < 0.6:
			return "Apártate un poco"
		return ""
	if DB.structures.has(id):
		if has_foundation(c):
			return "Ya hay un cimiento"
		if objects.has(ckey(c)):
			return "Hay un objeto en esa casilla"
		if _blocked_by_world(cell_center(c), cell * 0.7):
			return "Hay árboles o rocas en medio"
		return ""
	if DB.stations.has(id):
		if objects.has(ckey(c)):
			return "Ya hay un objeto en esa casilla"
		if _blocked_by_world(cell_center(c), 0.8):
			return "Hay árboles o rocas en medio"
		if Vector2(player_pos.x - cell_center(c).x, player_pos.z - cell_center(c).z).length() < 1.0:
			return "Apártate un poco"
		return ""
	return "Pieza desconocida"


## Coloca pagando el coste. Devuelve la pieza o null.
func place(id: String, c: Vector2i, side: int, rot: int, player_pos: Vector3) -> Node3D:
	var why := check_place(id, c, side, player_pos)
	if why != "":
		GS.message.emit(why)
		return null
	if not GS.pay(place_cost(id)):
		GS.message.emit("Faltan materiales")
		return null
	var n: Node3D
	if is_edge_piece(id):
		n = _spawn_structure(id, 0, ekey(edge_of(c, side)))
	elif DB.structures.has(id):
		n = _spawn_structure(id, 0, ckey(c))
	else:
		n = _spawn_station(id, 1, ckey(c), rot, 1)
	if n.is_in_group("station") and not n.is_built():
		GS.message.emit("Obra empezada: %s (fase 1 de %d). Tócala para seguir." % [piece_name(id), n.phases().size()])
		GS.add_xp(int(DB.xp_value("build_phase", 10)))
	elif n.is_in_group("station"):
		GS.message.emit("Construido: %s" % piece_name(id))
		GS.add_xp(int(DB.xp_value("build_station", 20)))
	else:
		GS.message.emit("Construido: %s" % piece_name(id))
		GS.add_xp(int(DB.xp_value("build_piece", 2)))
	return n


func _spawn_structure(id: String, tier: int, key: String) -> Node3D:
	var s := StructureScript.new()
	s.setup(id, tier, key)
	var k := parse_key(key)
	if k.size() == 3:
		var e := Vector3i(k[0], k[1], k[2])
		s.position = edge_center(e) + Vector3(0, FOUNDATION_H, 0)
		s.rotation_degrees.y = 0.0 if e.z == 0 else 90.0
		edges[key] = s
	else:
		s.position = cell_center(Vector2i(k[0], k[1]))
		foundations[key] = s
	add_child(s)
	_refresh_heights()
	return s


func _spawn_station(id: String, level: int, key: String, rot: int, stage := -1) -> Node3D:
	var s := StationScript.new()
	s.stage = stage if stage >= 0 else DB.station_phases(id).size()
	s.setup(id, level, key, rot)
	var k := parse_key(key)
	s.position = cell_center(Vector2i(k[0], k[1]))
	objects[key] = s
	add_child(s)
	_refresh_heights()
	return s


func _refresh_heights() -> void:
	for k in objects:
		var o: Node3D = objects[k]
		o.position.y = FOUNDATION_H if foundations.has(k) else 0.0


# ------------------------------------------------- mejorar y desmontar

## Lo que hay en la casilla/borde apuntado: pared o puerta, objeto, cimiento.
func target_at(c: Vector2i, side: int) -> Node3D:
	var ek := ekey(edge_of(c, side))
	if edges.has(ek):
		return edges[ek]
	if objects.has(ckey(c)):
		return objects[ckey(c)]
	if foundations.has(ckey(c)):
		return foundations[ckey(c)]
	return null


func upgrade_cost(n: Node3D) -> Dictionary:
	if n == null:
		return {}
	if n.is_in_group("structure"):
		if n.tier >= n.max_tier():
			return {}
		return DB.structure_tier(n.id, n.tier + 1).get("cost", {})
	if n.level >= n.max_level():
		return {}
	return DB.station_level(n.id, n.level + 1).get("cost", {})


func upgrade_name(n: Node3D) -> String:
	if n.is_in_group("structure"):
		return str(DB.structure_tier(n.id, n.tier + 1).get("name", ""))
	return "%s nivel %d" % [DB.station_name(n.id), n.level + 1]


func upgrade(n: Node3D) -> bool:
	var cost := upgrade_cost(n)
	if cost.is_empty():
		GS.message.emit("Ya está al máximo")
		return false
	if n.is_in_group("structure") and GS.level < DB.tier_unlock(n.id, n.tier + 1):
		GS.message.emit("Se desbloquea en el nivel %d" % DB.tier_unlock(n.id, n.tier + 1))
		return false
	if not GS.pay(cost):
		GS.message.emit("Faltan materiales")
		return false
	if n.is_in_group("structure"):
		n.set_tier(n.tier + 1)
	else:
		n.set_level(n.level + 1)
	GS.message.emit("Mejorado: %s" % n.display_name())
	GS.add_xp(int(DB.xp_value("upgrade_piece", 4)))
	return true


func refund_of(n: Node3D) -> Dictionary:
	if n.is_in_group("station") and DB.stations.get(n.id, {}).has("item"):
		return {str(DB.stations[n.id]["item"]): 1}   # el mueble entero vuelve a la mochila
	var cost: Dictionary
	if n.is_in_group("structure"):
		cost = DB.structure_tier(n.id, n.tier).get("cost", {})
	elif not n.phases().is_empty():
		cost = {}
		for i in mini(n.stage, n.phases().size()):
			var pc: Dictionary = n.phases()[i].get("cost", {})
			for k in pc:
				cost[k] = int(cost.get(k, 0)) + int(pc[k])
	else:
		cost = DB.station_level(n.id, n.level).get("cost", {})
	var out := {}
	var f := float(DB.bal("demolish_refund", 0.5))
	for id in cost:
		var q := int(floor(int(cost[id]) * f))
		if q > 0:
			out[id] = q
	return out


func can_demolish(n: Node3D) -> String:
	if n == null:
		return "No hay nada que desmontar"
	if n.is_in_group("structure") and n.kind == "foundation":
		var c := cell_of(n.position)
		if objects.has(ckey(c)):
			return "Quita antes lo que hay encima"
		for s in 4:
			var e := edge_of(c, s)
			if edges.has(ekey(e)):
				var cells := edge_cells(e)
				var other: Vector2i = cells[0] if cells[1] == c else cells[1]
				if not has_foundation(other):
					return "Quita antes las paredes que sujeta"
	return ""


func demolish(n: Node3D) -> bool:
	var why := can_demolish(n)
	if why != "":
		GS.message.emit(why)
		return false
	var refund := refund_of(n)
	var drops: Array = []
	for id in refund:
		var left := GS.add_item(str(id), int(refund[id]))
		if left > 0:
			drops.append(GS.make_item(str(id), left))
	if n.is_in_group("station"):
		for it in n.storage:
			if it != null:
				drops.append(it)
		objects.erase(n.key)
	elif n.kind == "foundation":
		foundations.erase(n.key)
	else:
		edges.erase(n.key)
	if not drops.is_empty():
		drop_items.emit(n.global_position, drops)
	GS.message.emit("Desmontado: %s" % n.display_name())
	n.queue_free()
	_refresh_heights()
	return true


# ----------------------------------------------------------------- guardado

func to_list() -> Array:
	var out: Array = []
	for d in [foundations, edges, objects]:
		for k in d:
			var n = d[k]
			if is_instance_valid(n) and not n.is_queued_for_deletion():
				var entry: Dictionary = n.to_dict()
				entry["type"] = "station" if n.is_in_group("station") else "structure"
				out.append(entry)
	return out


func load_list(list: Array) -> void:
	for e in list:
		var id := str(e.get("id", ""))
		var key := str(e.get("key", ""))
		if str(e.get("type", "")) == "station" and DB.stations.has(id):
			var s := _spawn_station(id, int(e.get("level", 1)), key, int(e.get("rot", 0)), int(e.get("stage", DB.station_phases(id).size())))
			s.water = float(e.get("water", 0.0))
			s.water_t = float(e.get("water_t", GS.now()))
			s.fuel = float(e.get("fuel", 0.0))
			var job: Dictionary = e.get("job", {})
			if not job.is_empty():
				s.job = {"recipe": str(job["recipe"]), "end": float(job["end"]), "time": float(job.get("time", DB.recipe(str(job["recipe"])).get("time", 1))), "count": int(job.get("count", 1))}
			var st: Array = e.get("storage", [])
			for i in mini(st.size(), s.storage.size()):
				var it = st[i]
				if it != null and DB.items.has(str(it.get("id", ""))):
					it["qty"] = int(it["qty"])
					if it.has("dur"):
						it["dur"] = int(it["dur"])
					s.storage[i] = it
		elif DB.structures.has(id):
			var tiers: Array = DB.structures[id]["tiers"]
			var n := _spawn_structure(id, clampi(int(e.get("tier", 0)), 0, tiers.size() - 1), key)
			if bool(e.get("open", false)):
				n.interact(null)
