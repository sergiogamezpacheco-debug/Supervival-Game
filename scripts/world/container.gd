extends StaticBody3D
## Contenedor saqueable de las zonas (cofre viejo, caja de herramientas,
## taquilla…). El botín se sortea al entrar en la zona según data/containers.json.
## Usa el mismo panel que el cofre del refugio.

var id := ""
var data: Dictionary = {}
var storage: Array = []
var _visual: Node3D


func setup(p_id: String, rng: RandomNumberGenerator) -> void:
	id = p_id
	data = DB.containers.get(id, {})
	add_to_group("interactable")
	add_to_group("container")
	storage.resize(int(data.get("slots", 6)))
	_roll_loot(rng)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.1, 0.9, 0.7)
	shape.shape = b
	shape.position.y = 0.45
	add_child(shape)
	_visual = Builder.container_mesh(id)
	add_child(_visual)


func _roll_loot(rng: RandomNumberGenerator) -> void:
	var table: Array = data.get("loot", [])
	if table.is_empty():
		return
	var total := 0.0
	for e in table:
		total += float(e.get("weight", 1))
	var rolls: Array = data.get("rolls", [1, 2])
	var n := rng.randi_range(int(rolls[0]), int(rolls[1]))
	var slot := 0
	for i in n:
		if slot >= storage.size():
			break
		var pick := rng.randf() * total
		for e in table:
			pick -= float(e.get("weight", 1))
			if pick <= 0.0:
				var q: Array = e.get("qty", [1, 1])
				storage[slot] = GS.make_item(str(e["id"]), rng.randi_range(int(q[0]), int(q[1])))
				slot += 1
				break


func is_chest() -> bool:
	return true


func is_empty() -> bool:
	for s in storage:
		if s != null:
			return false
	return true


func display_name() -> String:
	return str(data.get("name", id)) + (" (vacío)" if is_empty() else "")


func can_interact() -> bool:
	return true


func action_label() -> String:
	return "Registrar"


func interact(_by: Node3D) -> void:
	get_tree().call_group("hud", "open_station", self)


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


func bag_to_chest(_i: int) -> void:
	GS.message.emit("Aquí no puedes guardar cosas")
