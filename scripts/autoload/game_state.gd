extends Node
## Estado del jugador (autoload "GS"): inventario, mano, hambre/sed/vida y guardado.

signal inventory_changed
signal stats_changed
signal message(text: String)
signal died

var save_path := "user://save.json"

var slots: Array = []          # cada casilla: null o {"id", "qty", "dur"}
var hand: Variant = null       # objeto equipado (herramienta/arma) o null
var health := 100.0
var food := 100.0
var water := 100.0
var dead := false
var time_offset := 0.0         # solo para tests: adelanta el reloj

var _food_timer := 0.0
var _water_timer := 0.0


## Reloj real (sigue corriendo con el juego cerrado: las estaciones fabrican igual).
func now() -> float:
	return Time.get_unix_time_from_system() + time_offset


func _ready() -> void:
	new_game()


func new_game() -> void:
	slots.clear()
	slots.resize(int(DB.bal("inventory_slots", 20)))
	hand = null
	reset_stats()
	inventory_changed.emit()


func reset_stats() -> void:
	health = float(DB.bal("max_health", 100))
	food = float(DB.bal("max_food", 100))
	water = float(DB.bal("max_water", 100))
	dead = false
	_food_timer = 0.0
	_water_timer = 0.0
	stats_changed.emit()


# ---------------------------------------------------------------- stats

func tick(delta: float) -> void:
	if dead:
		return
	_food_timer += delta
	_water_timer += delta
	var food_step := float(DB.bal("food_decay_seconds", 7.0))
	var water_step := float(DB.bal("water_decay_seconds", 5.0))
	var changed := false
	while _food_timer >= food_step:
		_food_timer -= food_step
		food = maxf(food - 1.0, 0.0)
		changed = true
	while _water_timer >= water_step:
		_water_timer -= water_step
		water = maxf(water - 1.0, 0.0)
		changed = true
	if food <= 0.0 or water <= 0.0:
		damage(float(DB.bal("starving_damage_per_second", 1.0)) * delta)
	elif changed:
		stats_changed.emit()


func damage(amount: float) -> void:
	if dead:
		return
	health = maxf(health - amount, 0.0)
	stats_changed.emit()
	if health <= 0.0:
		dead = true
		died.emit()


func heal(amount: float) -> void:
	health = minf(health + amount, float(DB.bal("max_health", 100)))
	stats_changed.emit()


func drink(amount: float) -> void:
	water = minf(water + amount, float(DB.bal("max_water", 100)))
	stats_changed.emit()


func eat(amount: float) -> void:
	food = minf(food + amount, float(DB.bal("max_food", 100)))
	stats_changed.emit()


# ------------------------------------------------------------ inventario

func make_item(id: String, qty: int = 1) -> Dictionary:
	var it := {"id": id, "qty": qty}
	var data := DB.item(id)
	if data.has("durability"):
		it["dur"] = int(data["durability"])
	return it


## Añade objetos. Devuelve lo que NO cupo.
func add_item(id: String, qty: int, dur: int = -1) -> int:
	var max_stack := DB.stack_size(id)
	var left := qty
	if max_stack > 1:
		for s in slots:
			if left <= 0:
				break
			if s != null and s["id"] == id and int(s["qty"]) < max_stack:
				var add := mini(max_stack - int(s["qty"]), left)
				s["qty"] = int(s["qty"]) + add
				left -= add
	for i in slots.size():
		if left <= 0:
			break
		if slots[i] == null:
			var add := mini(max_stack, left)
			var it := make_item(id, add)
			if dur >= 0 and it.has("dur"):
				it["dur"] = dur
			slots[i] = it
			left -= add
	if left != qty:
		inventory_changed.emit()
	return left


func add_stack(it: Dictionary) -> int:
	return add_item(str(it["id"]), int(it["qty"]), int(it.get("dur", -1)))


func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s["id"] == id:
			n += int(s["qty"])
	return n


func remove_item(id: String, qty: int) -> bool:
	if count(id) < qty:
		return false
	var left := qty
	for i in range(slots.size() - 1, -1, -1):
		var s = slots[i]
		if left <= 0:
			break
		if s != null and s["id"] == id:
			var take := mini(int(s["qty"]), left)
			s["qty"] = int(s["qty"]) - take
			left -= take
			if int(s["qty"]) <= 0:
				slots[i] = null
	inventory_changed.emit()
	return true


func free_slots() -> int:
	var n := 0
	for s in slots:
		if s == null:
			n += 1
	return n


func can_craft(r: Dictionary) -> bool:
	return has_cost(r.get("cost", {}))


func has_cost(cost: Dictionary) -> bool:
	for id in cost:
		if count(str(id)) < int(cost[id]):
			return false
	return true


## Cobra un coste. Devuelve false (sin cobrar nada) si falta algo.
func pay(cost: Dictionary) -> bool:
	if not has_cost(cost):
		return false
	for id in cost:
		remove_item(str(id), int(cost[id]))
	return true


func craft(recipe_id: String) -> bool:
	var r := DB.recipe(recipe_id)
	if r.is_empty() or str(r.get("station", "")) != "":
		return false
	if not can_craft(r):
		message.emit("Faltan materiales")
		return false
	var result := str(r["result"])
	var qty := int(r.get("qty", 1))
	if free_slots() == 0 and count(result) == 0:
		message.emit("Mochila llena")
		return false
	var cost: Dictionary = r["cost"]
	for id in cost:
		remove_item(str(id), int(cost[id]))
	var left := add_item(result, qty)
	if left > 0:
		message.emit("Mochila llena: se perdió parte del objeto")
	message.emit("Fabricado: %s" % DB.item_name(result))
	return true


func use_slot(i: int) -> void:
	var s = slots[i]
	if s == null:
		return
	var data := DB.item(str(s["id"]))
	match str(data.get("type", "")):
		"consumable":
			if data.has("food"):
				eat(float(data["food"]))
			if data.has("water"):
				drink(float(data["water"]))
			if data.has("heal"):
				var h := float(data["heal"])
				if h >= 0.0:
					heal(h)
				else:
					damage(-h)
			s["qty"] = int(s["qty"]) - 1
			if int(s["qty"]) <= 0:
				slots[i] = null
			message.emit("Usado: %s" % DB.item_name(str(s["id"])))
			inventory_changed.emit()
		"tool", "weapon":
			equip_slot(i)


func equip_slot(i: int) -> void:
	var s = slots[i]
	if s == null:
		return
	var t := str(DB.item(str(s["id"])).get("type", ""))
	if t != "tool" and t != "weapon":
		return
	slots[i] = hand  # intercambia con lo que llevabas en la mano
	hand = s
	message.emit("Equipado: %s" % DB.item_name(str(s["id"])))
	inventory_changed.emit()


func unequip() -> void:
	if hand == null:
		return
	if add_stack(hand) == 0:
		hand = null
		inventory_changed.emit()
	else:
		message.emit("Mochila llena")


func drop_slot(i: int) -> Variant:
	var s = slots[i]
	slots[i] = null
	inventory_changed.emit()
	return s


func hand_data() -> Dictionary:
	if hand == null:
		return {}
	return DB.item(str(hand["id"]))


func hand_tool() -> String:
	return str(hand_data().get("tool", ""))


func hand_damage() -> float:
	var d := hand_data()
	if d.is_empty():
		return float(DB.bal("fist_damage", 6))
	return float(d.get("damage", DB.bal("fist_damage", 6)))


## Gasta 1 de durabilidad del objeto en la mano. Se rompe al llegar a 0.
func wear_hand() -> void:
	if hand == null or not hand.has("dur"):
		return
	hand["dur"] = int(hand["dur"]) - 1
	if int(hand["dur"]) <= 0:
		message.emit("¡Se rompió %s!" % DB.item_name(str(hand["id"])))
		hand = null
	inventory_changed.emit()


## Vacía mochila y mano (al morir). Devuelve la lista de objetos.
func take_all_items() -> Array:
	var out: Array = []
	for i in slots.size():
		if slots[i] != null:
			out.append(slots[i])
			slots[i] = null
	if hand != null:
		out.append(hand)
		hand = null
	inventory_changed.emit()
	return out


# --------------------------------------------------------------- guardado

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"slots": slots,
		"hand": hand,
		"health": health,
		"food": food,
		"water": water,
	}


func from_dict(d: Dictionary) -> void:
	new_game()
	var saved: Array = d.get("slots", [])
	for i in mini(saved.size(), slots.size()):
		var s = saved[i]
		if s != null and DB.items.has(str(s.get("id", ""))):
			s["qty"] = int(s["qty"])
			if s.has("dur"):
				s["dur"] = int(s["dur"])
			slots[i] = s
	var h = d.get("hand", null)
	if h != null and DB.items.has(str(h.get("id", ""))):
		h["qty"] = int(h["qty"])
		if h.has("dur"):
			h["dur"] = int(h["dur"])
		hand = h
	health = float(d.get("health", health))
	food = float(d.get("food", food))
	water = float(d.get("water", water))
	if health <= 0.0:
		reset_stats()
	inventory_changed.emit()
	stats_changed.emit()


func save_game(world: Dictionary) -> void:
	var d := to_dict()
	d["world"] = world
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo guardar en %s" % save_path)
		return
	f.store_string(JSON.stringify(d))


## Carga la partida. Devuelve el bloque "world" (o {} si no había partida).
func load_game() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	from_dict(parsed)
	return parsed.get("world", {})
