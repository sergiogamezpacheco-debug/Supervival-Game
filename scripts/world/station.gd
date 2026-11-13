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
}

var id := ""
var level := 1
var key := ""
var rot := 0                 # giro en pasos de 90º
var job: Dictionary = {}     # {"recipe": id, "end": unix}
var storage: Array = []      # solo cofres
var _visual: Node3D


func setup(p_id: String, p_level: int, p_key: String, p_rot: int) -> void:
	id = p_id
	level = p_level
	key = p_key
	rot = p_rot
	add_to_group("interactable")
	add_to_group("station")
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
	_visual.rotation_degrees.y = rot * 90.0
	add_child(_visual)


# ------------------------------------------------------------ interacción

func can_interact() -> bool:
	return true


func action_label() -> String:
	if is_chest():
		return "Abrir"
	if is_done():
		return "Recoger"
	return "Usar"


func interact(_by: Node3D) -> void:
	if not is_chest() and is_done():
		collect()
		return
	get_tree().call_group("hud", "open_station", self)


# ------------------------------------------------------------ fabricación

func recipe_unlocked(r: Dictionary) -> bool:
	return int(r.get("level", 1)) <= level


func start(recipe_id: String) -> String:
	if is_chest():
		return "Esto es un cofre"
	if not job.is_empty():
		return "La estación está ocupada"
	var r := DB.recipe(recipe_id)
	if r.is_empty() or str(r.get("station", "")) != id:
		return "Receta no disponible aquí"
	if not recipe_unlocked(r):
		return "Mejora la estación a nivel %d" % int(r.get("level", 1))
	if not GS.pay(r.get("cost", {})):
		return "Faltan materiales"
	job = {"recipe": recipe_id, "end": GS.now() + float(r.get("time", 5))}
	return ""


func time_left() -> float:
	if job.is_empty():
		return 0.0
	return maxf(float(job["end"]) - GS.now(), 0.0)


func progress() -> float:
	if job.is_empty():
		return 0.0
	var total := float(DB.recipe(str(job["recipe"])).get("time", 1))
	return clampf(1.0 - time_left() / maxf(total, 0.01), 0.0, 1.0)


func is_done() -> bool:
	return not job.is_empty() and time_left() <= 0.0


func collect() -> bool:
	if not is_done():
		return false
	var r := DB.recipe(str(job["recipe"]))
	var result := str(r["result"])
	var qty := int(r.get("qty", 1))
	var left := GS.add_item(result, qty)
	if left == qty:
		GS.message.emit("Mochila llena")
		return false
	if left > 0:
		GS.message.emit("Mochila llena: parte se ha perdido")
	job = {}
	GS.message.emit("+%d %s" % [qty - left, DB.item_name(result)])
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
		GS.message.emit("Mochila llena")
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
	return {"id": id, "key": key, "level": level, "rot": rot, "job": job, "storage": storage}
