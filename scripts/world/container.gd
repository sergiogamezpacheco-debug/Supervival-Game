extends StaticBody3D
## Contenedor saqueable de las zonas (cofre viejo, caja de herramientas,
## taquilla…). El botín se sortea al entrar en la zona según data/containers.json.
## Usa el mismo panel que el cofre del refugio.

var id := ""
var data: Dictionary = {}
var storage: Array = []
var _visual: Node3D
var loot_key := ""      # muebles de las casas de los caminos: con qué nombre se recuerda su contenido
var opened_t := 0.0     # cuándo se registró por primera vez (unix); 0 = sin tocar


func setup(p_id: String, rng: RandomNumberGenerator, saved: Variant = null) -> void:
	id = p_id
	data = DB.containers.get(id, {})
	add_to_group("interactable")
	add_to_group("container")
	storage.resize(int(data.get("slots", 6)))
	if saved is Array:
		# ya se registró hace poco: está como se dejó
		for i in mini(saved.size(), storage.size()):
			storage[i] = saved[i]
	else:
		_roll_loot(rng)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.1, 0.9, 0.7)
	if data.has("size"):   # muebles: su tamaño en containers.json ("y" = altura si va colgado)
		var sz: Array = data["size"]
		b.size = Vector3(float(sz[0]), float(sz[1]), float(sz[2]))
	elif id.begins_with("coche"):
		b.size = Vector3(1.9, 1.4, 4.3)
	elif id == "cadaver":
		b.size = Vector3(0.9, 0.4, 1.8)
	shape.shape = b
	shape.position.y = b.size.y / 2.0 + float(data.get("y", 0.0))
	add_child(shape)
	_visual = Builder.container_mesh(id)
	add_child(_visual)
	if data.has("fixed"):
		_build_flare()
	else:
		set_process(false)


# Bengala roja encendida junto al superviviente muerto mientras lleva un trozo de mapa: se ve de lejos.
var _flare: Node3D = null
var _flare_t := 0.0


func _build_flare() -> void:
	_flare = Node3D.new()
	_flare.position = Vector3(0.7, 0, -0.5)
	add_child(_flare)
	var stick := Builder.part(Builder.cyl(0.035, 0.035, 0.35), Color("b8322a"), Vector3(0, 0.12, 0))
	stick.rotation.z = 0.4
	_flare.add_child(stick)
	var glow := Builder.part(Builder.cyl(0.0, 0.09, 0.22), Color(1.0, 0.25, 0.15), Vector3(0.09, 0.32, 0), 4.0)
	_flare.add_child(glow)
	var smoke := Builder.part(Builder.cyl(0.25, 0.08, 2.2), Color(0.85, 0.35, 0.3, 0.35), Vector3(0.15, 1.5, 0))
	_flare.add_child(smoke)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.3, 0.2)
	l.omni_range = 5.0
	l.light_energy = 1.6
	l.position = Vector3(0.1, 0.5, 0)
	_flare.add_child(l)
	_update_flare()


func _update_flare() -> void:
	if _flare == null:
		return
	var has_piece := false
	for it in storage:
		if it != null and str(DB.item(str(it["id"])).get("type", "")) == "map_piece":
			has_piece = true
	_flare.visible = has_piece


func _process(delta: float) -> void:
	_flare_t += delta
	if _flare_t >= 0.5:
		_flare_t = 0.0
		_update_flare()


func _roll_loot(rng: RandomNumberGenerator) -> void:
	var slot := 0
	# lo que siempre está (p. ej. el trozo de mapa del superviviente muerto, si aún no lo tienes)
	for f in data.get("fixed", []):
		var fd := DB.item(str(f["id"]))
		if str(fd.get("type", "")) == "map_piece" and int(fd.get("piece", 2)) <= GS.map_pieces:
			continue
		if slot < storage.size():
			storage[slot] = GS.make_item(str(f["id"]), int(f.get("qty", 1)))
			slot += 1
	var table: Array = data.get("loot", [])
	if table.is_empty():
		return
	var total := 0.0
	for e in table:
		total += float(e.get("weight", 1))
	var rolls: Array = data.get("rolls", [1, 2])
	var n := rng.randi_range(int(rolls[0]), int(rolls[1]))
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


var _xp_given := false


func interact(_by: Node3D) -> void:
	if opened_t <= 0.0:
		opened_t = GS.now()
	if not _xp_given and not is_chest() and not is_empty():
		_xp_given = true
		GS.add_xp(int(DB.xp_value("container_first", 3)))
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
