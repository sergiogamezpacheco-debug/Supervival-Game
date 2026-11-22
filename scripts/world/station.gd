extends StaticBody3D
## Estación de trabajo o cofre (data/stations.json).
## Las estaciones fabrican de una en una y con tiempo real: siguen trabajando
## aunque cierres el juego. El cofre guarda objetos.

const SIZES := {
	"banco_trabajo": Vector3(1.7, 1.0, 0.9),
	"carpinteria": Vector3(1.8, 1.0, 0.8),
	"cantero": Vector3(1.6, 1.0, 1.0),
	"hoguera": Vector3(1.2, 0.5, 1.2),
	"horno": Vector3(1.4, 1.4, 1.2),
	"mesa_costura": Vector3(1.4, 1.0, 0.8),
	"cofre": Vector3(1.2, 0.8, 0.7),
	"gimnasio": Vector3(2.2, 1.9, 1.0),
	"banco_armas": Vector3(1.8, 1.0, 0.9),
	"recolector_agua": Vector3(1.1, 1.4, 1.1),
	"secadero": Vector3(1.8, 1.7, 0.6),
	"huerto": Vector3(1.8, 0.4, 1.2),
	"compostadora": Vector3(1.3, 1.0, 1.3),
	"mesa_medica": Vector3(1.6, 1.0, 0.9),
	"generador": Vector3(1.2, 1.0, 0.8),
	"recicladora": Vector3(1.6, 1.8, 1.4),
	"cocina": Vector3(1.3, 1.2, 0.8),
	"destileria": Vector3(1.5, 1.7, 1.0),
	"mesa_quimica": Vector3(1.6, 1.1, 0.9),
	"banco_electronica": Vector3(1.7, 1.2, 0.9),
}

var id := ""
var level := 1
var key := ""
var rot := 0                 # giro en pasos de 90º
var job: Dictionary = {}     # {"recipe": id, "end": unix}
var storage: Array = []      # solo cofres
var stage := 0               # fases de obra hechas (estaciones grandes); completa si == phases().size()
var water := 0.0             # recolector de agua: litros guardados…
var water_t := 0.0           # …hasta este momento (unix)
var fuel := 0.0              # generador: segundos de energía; cocina y destilería: segundos de fuego
var _visual: Node3D


func setup(p_id: String, p_level: int, p_key: String, p_rot: int) -> void:
	id = p_id
	level = p_level
	key = p_key
	rot = p_rot
	add_to_group("interactable")
	add_to_group("station")
	water_t = GS.now()
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = SIZES.get(id, Vector3(1.4, 1.0, 1.0))
	shape.shape = b
	shape.position.y = b.size.y / 2.0
	shape.rotation_degrees.y = rot * 90.0
	add_child(shape)
	_resize_storage()
	_rebuild()


func is_chest() -> bool:
	return id == "cofre"


func is_gym() -> bool:
	return id == "gimnasio"


func is_collector() -> bool:
	return id == "recolector_agua"


func is_generator() -> bool:
	return id == "generador"


## Cocina y destilería: tienen su propio fuego (leña, carbón o combustible).
func burns() -> bool:
	return bool(DB.stations.get(id, {}).get("burns", false))


# ----------------------------------------------------------- obra por fases

func phases() -> Array:
	return DB.station_phases(id)


func is_built() -> bool:
	return stage >= phases().size()


func next_phase() -> Dictionary:
	if is_built():
		return {}
	return phases()[stage]


## Paga la siguiente fase de la obra. Devuelve "" o el motivo.
func add_phase() -> String:
	if is_built():
		return "Ya está terminada"
	if not GS.pay(next_phase().get("cost", {})):
		return "Faltan materiales"
	stage += 1
	_rebuild()
	SFX.play("fabricar")
	GS.add_xp(int(DB.xp_value("build_phase", 10)))
	if is_built():
		GS.message.emit("¡%s terminado!" % DB.station_name(id))
		GS.add_xp(int(DB.xp_value("build_station", 20)))
	else:
		GS.message.emit("Fase %d de %d hecha" % [stage, phases().size()])
	return ""


# -------------------------------------------------------- recolector de agua

func water_now() -> float:
	var lv := DB.station_level(id, level)
	var cap := float(lv.get("capacity", 100))
	var mult: float = float(DB.bal("collector_rain_mult", 4.0)) if GS.raining() else 1.0
	var dt := maxf(GS.now() - water_t, 0.0)
	return minf(cap, water + float(lv.get("rate", 20)) * mult * dt / 3600.0)


func water_capacity() -> float:
	return float(DB.station_level(id, level).get("capacity", 100))


## Llena botellas vacías con el agua guardada (agua sucia). Devuelve "" o el motivo.
func fill_bottles(n: int) -> String:
	var per := float(DB.bal("bottle_water", 10))
	water = water_now()
	water_t = GS.now()
	n = mini(n, mini(GS.count("botella_vacia"), int(water / per)))
	if GS.count("botella_vacia") <= 0:
		return "No tienes botellas vacías"
	if n <= 0:
		return "No hay agua suficiente"
	GS.remove_item("botella_vacia", n)
	var left := GS.add_item("agua_sucia", n)
	if left > 0:
		GS.add_item("botella_vacia", left)
	water -= per * float(n - left)
	GS.message.emit("+%d %s" % [n - left, DB.item_name("agua_sucia")])
	return "" if left == 0 else "Inventario lleno"


## Bebe lo que haga falta (y haya). Devuelve lo bebido.
func drink() -> float:
	water = water_now()
	water_t = GS.now()
	var take := minf(water, 100.0 - GS.water)
	if take < 1.0:
		GS.message.emit("No hay agua" if water < 1.0 else "No tienes sed")
		return 0.0
	water -= take
	GS.drink(take)
	GS.message.emit("Has bebido agua (%d)" % roundi(take))
	return take


# ---------------------------------------------------------------- generador

## Qué se puede echar y cuántos segundos de energía o de fuego da cada unidad.
func fuel_table() -> Dictionary:
	if burns():
		return DB.bal("stove_fuel", {"madera": 60, "carbon": 180})
	return DB.bal("generator_fuel", {"carbon": 300, "madera": 90})


func fuel_max() -> float:
	return float(DB.bal("stove_max", 1800)) if burns() else float(DB.bal("generator_max", 3600))


## Echa combustible (troncos, carbón o bidón) al generador o al fuego de la estación.
func add_fuel(item_id: String) -> String:
	var per := fuel_table()
	if not per.has(item_id):
		return "Eso no sirve de combustible"
	if fuel >= fuel_max():
		return "El depósito está lleno" if not burns() else "El fuego ya está al máximo"
	if not GS.remove_item(item_id, 1):
		return "No tienes %s" % DB.item_name(item_id)
	fuel = minf(fuel + float(per[item_id]), fuel_max())
	return ""


## Generador terminado del refugio (o null).
func _generator() -> Node3D:
	for s in get_tree().get_nodes_in_group("station"):
		if s.id == "generador" and s.is_built():
			return s
	return null


func needs_power() -> bool:
	return bool(DB.stations.get(id, {}).get("power", false))


func _has_station(sid: String) -> bool:
	for s in get_tree().get_nodes_in_group("station"):
		if s.id == sid and s.is_built():
			return true
	return false


## Tiempo real que tardará una receta aquí (el huerto va más rápido con agua).
func recipe_time(r: Dictionary) -> float:
	var t := float(r.get("time", 5))
	if id == "huerto" and _has_station("recolector_agua"):
		t *= float(DB.bal("garden_water_mult", 0.5))
	return t


func display_name() -> String:
	var n := DB.station_name(id)
	if max_level() > 1:
		n += " (Nv %d)" % level
	return n


func max_level() -> int:
	return (DB.stations[id]["levels"] as Array).size()


func set_level(l: int) -> void:
	level = l
	_resize_storage()
	_rebuild()


func _resize_storage() -> void:
	if not is_chest():
		return
	var n := int(DB.station_level(id, level).get("storage", 12))
	while storage.size() < n:
		storage.append(null)


func _rebuild() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Builder.station_mesh(id, level)
	if not is_built():
		_visual = StationModels.under_construction(_visual, stage, phases().size(), SIZES.get(id, Vector3(1.4, 1.0, 1.0)))
	_visual = Builder.merge(_visual)
	_visual.rotation_degrees.y = rot * 90.0
	add_child(_visual)


# ------------------------------------------------------------ interacción

func can_interact() -> bool:
	return true


func action_label() -> String:
	if not is_built():
		return "Construir"
	if is_chest():
		return "Abrir"
	if is_gym():
		return "Entrenar"
	if is_done():
		return "Recoger"
	return "Usar"


func interact(_by: Node3D) -> void:
	if is_built() and not is_chest() and is_done():
		collect()
		return
	get_tree().call_group("hud", "open_station", self)


# ------------------------------------------------------------ fabricación

func recipe_unlocked(r: Dictionary) -> bool:
	return int(r.get("level", 1)) <= level


## Coste de fabricar "count" veces una receta.
static func cost_times(r: Dictionary, count: int) -> Dictionary:
	var out := {}
	var c: Dictionary = r.get("cost", {})
	for k in c:
		out[k] = int(c[k]) * maxi(count, 1)
	return out


## Cuántas veces se puede fabricar con lo que llevas (máx. 10).
static func max_times(r: Dictionary) -> int:
	var n := 10
	var c: Dictionary = r.get("cost", {})
	for k in c:
		n = mini(n, GS.count(str(k)) / maxi(int(c[k]), 1))
	return n


func start(recipe_id: String, count := 1) -> String:
	count = maxi(count, 1)
	if is_chest():
		return "Esto es un cofre"
	if not is_built():
		return "Termina antes la obra"
	if GS.level < DB.recipe_unlock(DB.recipe(recipe_id)):
		return "Se desbloquea en el nivel %d" % DB.recipe_unlock(DB.recipe(recipe_id))
	if not job.is_empty():
		return "La estación está ocupada"
	var r := DB.recipe(recipe_id)
	if r.is_empty() or str(r.get("station", "")) != id:
		return "Receta no disponible aquí"
	if not recipe_unlocked(r):
		return "Mejora la estación a nivel %d" % int(r.get("level", 1))
	var t := recipe_time(r) * count
	var gen: Node3D = null
	if needs_power():
		gen = _generator()
		if gen == null:
			return "Necesita un generador terminado"
		if gen.fuel < t:
			return "Al generador le falta combustible"
	if burns() and fuel < t:
		return "Echa leña: al fuego le falta para esto"
	if not GS.pay(cost_times(r, count)):
		return "Faltan materiales"
	if gen:
		gen.fuel -= t
	if burns():
		fuel -= t
	job = {"recipe": recipe_id, "end": GS.now() + t, "time": t, "count": count}
	return ""


func time_left() -> float:
	if job.is_empty():
		return 0.0
	return maxf(float(job["end"]) - GS.now(), 0.0)


func progress() -> float:
	if job.is_empty():
		return 0.0
	var total := float(job.get("time", DB.recipe(str(job["recipe"])).get("time", 1)))
	return clampf(1.0 - time_left() / maxf(total, 0.01), 0.0, 1.0)


func is_done() -> bool:
	return not job.is_empty() and time_left() <= 0.0


func collect() -> bool:
	if not is_done():
		return false
	var r := DB.recipe(str(job["recipe"]))
	var result := str(r["result"])
	var times := int(job.get("count", 1))
	var qty := int(r.get("qty", 1)) * times
	var left := GS.add_item(result, qty)
	if left == qty:
		GS.message.emit("Inventario lleno")
		return false
	if left > 0:
		GS.message.emit("Inventario lleno: parte se ha perdido")
	job = {}
	GS.message.emit("+%d %s" % [qty - left, DB.item_name(result)])
	GS.add_xp(GS.craft_xp(r) * times)
	return true


# ------------------------------------------------------------------ cofre

func chest_to_bag(i: int) -> void:
	var s = storage[i]
	if s == null:
		return
	var left := GS.add_stack(s)
	if left == 0:
		storage[i] = null
	else:
		s["qty"] = left
		GS.message.emit("Inventario lleno")
	GS.inventory_changed.emit()


func bag_to_chest(i: int) -> void:
	var s = GS.slots[i]
	if s == null:
		return
	var left := _store(s)
	if left == 0:
		GS.slots[i] = null
	else:
		s["qty"] = left
		GS.message.emit("Cofre lleno")
	GS.inventory_changed.emit()


func _store(it: Dictionary) -> int:
	var id_ := str(it["id"])
	var max_stack := DB.stack_size(id_)
	var left := int(it["qty"])
	if max_stack > 1:
		for s in storage:
			if left <= 0:
				break
			if s != null and s["id"] == id_ and int(s["qty"]) < max_stack:
				var add := mini(max_stack - int(s["qty"]), left)
				s["qty"] = int(s["qty"]) + add
				GS.merge_rot(s, float(it.get("rot", -1.0)))
				left -= add
	for i in storage.size():
		if left <= 0:
			break
		if storage[i] == null:
			var copy: Dictionary = it.duplicate()
			copy["qty"] = mini(max_stack, left)
			left -= int(copy["qty"])
			storage[i] = copy
	return left


func to_dict() -> Dictionary:
	return {"id": id, "key": key, "level": level, "rot": rot, "job": job, "storage": storage, "stage": stage, "water": water, "water_t": water_t, "fuel": fuel}
