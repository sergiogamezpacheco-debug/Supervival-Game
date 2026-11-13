extends Node
## Estado del jugador (autoload "GS"): inventario, mano, hambre/sed/vida y guardado.

signal inventory_changed
signal stats_changed
signal message(text: String)
signal died
signal look_changed            # ropa o físico: hay que rehacer el modelo

var save_path := "user://save.json"

var slots: Array = []          # cada casilla: null o {"id", "qty", "dur"}
var hand: Variant = null       # objeto equipado (herramienta/arma) o null
var health := 100.0
var food := 100.0
var water := 100.0
var dead := false
var time_offset := 0.0         # solo para tests: adelanta el reloj
var poison := 0.0              # segundos de veneno que quedan
var current_map := "refugio"   # zona en la que está el jugador
var maps_state: Dictionary = {} # estado guardado de cada zona (refugio, bolsas…)
# Aspecto del superviviente (se elige al crear el personaje)
var look := {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 1}
var physique := {"fuerza": 0.0, "resistencia": 0.0}
var outfit := {"cabeza": "", "torso": "", "piernas": "", "pies": "", "manos": "", "espalda": ""}
const WEAR_SLOTS := ["cabeza", "torso", "piernas", "pies", "manos", "espalda"]
const WEAR_NAMES := {"cabeza": "Cabeza", "torso": "Torso", "piernas": "Piernas", "pies": "Pies", "manos": "Manos", "espalda": "Espalda"}
var worn: Dictionary = {}      # ranura -> objeto puesto ({"id","qty","dur"}) o null
var created := false           # ya se ha creado el personaje (primer arranque)
var player_name := "Superviviente"
var stamina := 100.0           # aguante para correr
var train_ready: Dictionary = {} # ejercicio -> hora (unix) en que se puede volver a entrenar
var testing := false           # los tests no muestran la pantalla de creación

var _food_timer := 0.0
var _water_timer := 0.0


## Reloj real (sigue corriendo con el juego cerrado: las estaciones fabrican igual).
func now() -> float:
	return Time.get_unix_time_from_system() + time_offset


func _ready() -> void:
	new_game()


func new_game() -> void:
	current_map = "refugio"
	maps_state = {}
	look = {"sex": "m", "skin": 1, "hair": 1, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 1}
	physique = {"fuerza": 0.0, "resistencia": 0.0}
	outfit = {"cabeza": "", "torso": "", "piernas": "", "pies": "", "manos": "", "espalda": ""}
	worn = {}
	for k in WEAR_SLOTS:
		worn[k] = null
	created = false
	player_name = "Superviviente"
	train_ready = {}
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
	poison = 0.0
	stamina = max_stamina()
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
	if poison > 0.0:
		poison = maxf(poison - delta, 0.0)
		damage(float(DB.bal("poison_damage_per_second", 1.5)) * delta)
		if dead:
			return
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


func poison_for(seconds: float) -> void:
	if dead:
		return
	if poison <= 0.0:
		message.emit("¡Te han envenenado! Una venda lo cura")
	poison = maxf(poison, seconds)
	stats_changed.emit()


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
			if bool(data.get("cure_poison", false)) and poison > 0.0:
				poison = 0.0
				message.emit("Veneno curado")
			s["qty"] = int(s["qty"]) - 1
			if int(s["qty"]) <= 0:
				slots[i] = null
			message.emit("Usado: %s" % DB.item_name(str(s["id"])))
			inventory_changed.emit()
		"tool", "weapon":
			equip_slot(i)
		"wear":
			wear_slot(i)


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
	var base := float(DB.bal("fist_damage", 6))
	if not d.is_empty():
		base = float(d.get("damage", base))
	return base * (1.0 + float(physique["fuerza"]) * float(DB.bal("strength_damage_bonus", 0.4)))


## Gasta 1 de durabilidad del objeto en la mano. Se rompe al llegar a 0.
func wear_hand() -> void:
	if hand == null or not hand.has("dur"):
		return
	hand["dur"] = int(hand["dur"]) - 1
	if int(hand["dur"]) <= 0:
		message.emit("¡Se rompió %s!" % DB.item_name(str(hand["id"])))
		hand = null
	inventory_changed.emit()


## Vacía mochila, mano y ropa (al morir). Devuelve la lista de objetos.
func take_all_items() -> Array:
	var out: Array = []
	for i in slots.size():
		if slots[i] != null:
			out.append(slots[i])
			slots[i] = null
	if hand != null:
		out.append(hand)
		hand = null
	var had_clothes := false
	for k in WEAR_SLOTS:
		if worn[k] != null:
			out.append(worn[k])
			worn[k] = null
			had_clothes = true
	_resize_bag()
	if had_clothes:
		_sync_outfit()
	inventory_changed.emit()
	return out


# ----------------------------------------------------------------- ropa

## Se pone la prenda de la casilla i (la que llevaba vuelve a la mochila).
func wear_slot(i: int) -> bool:
	var s = slots[i]
	if s == null:
		return false
	var data := DB.item(str(s["id"]))
	if str(data.get("type", "")) != "wear":
		return false
	var slot := str(data.get("slot", ""))
	if not worn.has(slot):
		return false
	var old = worn[slot]
	if old != null and int(DB.item(str(old["id"])).get("bag_slots", 0)) > 0 and not _bag_extra_empty(int(DB.item(str(old["id"])).get("bag_slots", 0)) - int(data.get("bag_slots", 0))):
		message.emit("Vacía primero los huecos de la mochila")
		return false
	slots[i] = old
	worn[slot] = s
	_resize_bag()
	_sync_outfit()
	message.emit("Te pones: %s" % DB.item_name(str(s["id"])))
	inventory_changed.emit()
	return true


## Se quita la prenda de una ranura y la guarda en la mochila.
func take_off(slot: String) -> bool:
	var it = worn.get(slot, null)
	if it == null:
		return false
	var extra := int(DB.item(str(it["id"])).get("bag_slots", 0))
	if extra > 0 and not _bag_extra_empty(extra):
		message.emit("Vacía primero los huecos de la mochila")
		return false
	if free_slots() - extra < 1:
		message.emit("Mochila llena")
		return false
	worn[slot] = null
	_resize_bag()
	add_stack(it)
	_sync_outfit()
	message.emit("Te quitas: %s" % DB.item_name(str(it["id"])))
	inventory_changed.emit()
	return true


func bag_size() -> int:
	var n := int(DB.bal("inventory_slots", 20))
	for k in WEAR_SLOTS:
		if worn.get(k) != null:
			n += int(DB.item(str(worn[k]["id"])).get("bag_slots", 0))
	return n


## Los últimos "extra" huecos están vacíos (se pueden quitar con la mochila).
func _bag_extra_empty(extra: int) -> bool:
	for i in range(maxi(slots.size() - extra, 0), slots.size()):
		if slots[i] != null:
			return false
	return true


func _resize_bag() -> void:
	var n := bag_size()
	if slots.size() > n:
		# lo que quede en los huecos que desaparecen se recoloca si cabe
		var spill: Array = []
		for i in range(n, slots.size()):
			if slots[i] != null:
				spill.append(slots[i])
		slots.resize(n)
		for it in spill:
			add_stack(it)
	elif slots.size() < n:
		slots.resize(n)


func _sync_outfit() -> void:
	for k in WEAR_SLOTS:
		outfit[k] = "" if worn.get(k) == null else str(DB.item(str(worn[k]["id"])).get("model", worn[k]["id"]))
	look_changed.emit()


## Defensa total (% de daño que se evita).
func armor() -> float:
	var a := 0.0
	for k in WEAR_SLOTS:
		if worn.get(k) != null:
			a += float(DB.item(str(worn[k]["id"])).get("armor", 0))
	return minf(a, float(DB.bal("max_armor", 60)))


func wear_bonus(key: String) -> float:
	var v := 0.0
	for k in WEAR_SLOTS:
		if worn.get(k) != null:
			v += float(DB.item(str(worn[k]["id"])).get(key, 0))
	return v


## Golpe de un enemigo: la ropa reduce el daño y se desgasta.
func hit(amount: float) -> void:
	if dead:
		return
	var reduced := amount * (1.0 - armor() / 100.0)
	var broke := false
	for k in WEAR_SLOTS:
		var it = worn.get(k)
		if it != null and it.has("dur"):
			it["dur"] = int(it["dur"]) - 1
			if int(it["dur"]) <= 0:
				message.emit("¡Se rompió %s!" % DB.item_name(str(it["id"])))
				worn[k] = null
				broke = true
	if broke:
		_resize_bag()
		_sync_outfit()
		inventory_changed.emit()
	damage(reduced)


# ------------------------------------------------------- físico y aguante

## Fracción de la mochila ocupada (0..1).
func load_ratio() -> float:
	if slots.is_empty():
		return 0.0
	return 1.0 - float(free_slots()) / float(slots.size())


func max_stamina() -> float:
	return float(DB.bal("stamina_base", 100)) + float(physique["resistencia"]) * float(DB.bal("stamina_per_resistencia", 60))


## Aguante que se gasta por segundo corriendo (más con la mochila llena).
func stamina_drain() -> float:
	return float(DB.bal("stamina_drain", 14.0)) * (1.0 + load_ratio() * 0.8) * (1.0 - float(physique["resistencia"]) * 0.45)


## Velocidad relativa: la carga frena salvo que tengas fuerza; las zapatillas ayudan.
func speed_factor() -> float:
	var f := 1.0 + wear_bonus("speed")
	var l := load_ratio()
	if l > 0.75:
		f -= 0.2 * (l - 0.75) / 0.25 * (1.0 - float(physique["fuerza"]) * 0.7)
	return f


## Sube un poco una capacidad (cuanto más alta, más cuesta).
func exercise(stat: String, amount: float) -> void:
	if not physique.has(stat):
		return
	var before := float(physique[stat])
	var v := minf(before + amount * (1.0 - before * 0.8), 1.0)
	physique[stat] = v
	# El cuerpo se rehace por escalones para no reconstruir el modelo cada golpe.
	if floori(v * 20.0) != floori(before * 20.0):
		message.emit("%s +%d%%" % ["Fuerza" if stat == "fuerza" else "Resistencia", roundi(v * 100.0)])
		look_changed.emit()


## Entrena en el gimnasio. Devuelve "" si se pudo o el motivo si no.
func train(stat: String, gym_level: int) -> String:
	if not physique.has(stat):
		return "Ejercicio desconocido"
	var lv := DB.station_level("gimnasio", gym_level)
	var wait := float(train_ready.get(stat, 0.0)) - now()
	if wait > 0.0:
		return "Descansa %d s antes de volver a entrenar" % ceili(wait)
	var fc := float(DB.bal("train_food", 8))
	var wc := float(DB.bal("train_water", 10))
	if food < fc or water < wc:
		return "Necesitas comer y beber para entrenar"
	if float(physique[stat]) >= 1.0:
		return "Ya estás al máximo"
	food -= fc
	water -= wc
	train_ready[stat] = now() + float(lv.get("cooldown", 90))
	var before := float(physique[stat])
	physique[stat] = minf(before + float(lv.get("gain", 0.03)) * (1.0 - before * 0.5), 1.0)
	stats_changed.emit()
	message.emit("%s %d%% → %d%%" % ["Fuerza" if stat == "fuerza" else "Resistencia", roundi(before * 100.0), roundi(float(physique[stat]) * 100.0)])
	look_changed.emit()
	return ""


# --------------------------------------------------------------- guardado

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"slots": slots,
		"hand": hand,
		"health": health,
		"food": food,
		"water": water,
		"look": look,
		"physique": physique,
		"worn": worn,
		"created": created,
		"name": player_name,
		"train_ready": train_ready,
	}


func from_dict(d: Dictionary) -> void:
	new_game()
	var saved: Array = d.get("slots", [])
	var extra := 0
	for k in d.get("worn", {}):
		var it2 = d["worn"][k]
		if it2 != null:
			extra += int(DB.item(str(it2.get("id", ""))).get("bag_slots", 0))
	slots.resize(slots.size() + extra)
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
	for k in d.get("look", {}):
		look[k] = d["look"][k] if typeof(d["look"][k]) == TYPE_STRING else int(d["look"][k])
	for k in d.get("physique", {}):
		physique[k] = float(d["physique"][k])
	var w: Dictionary = d.get("worn", {})
	for k in WEAR_SLOTS:
		var it = w.get(k, null)
		if it != null and DB.items.has(str(it.get("id", ""))):
			it["qty"] = 1
			if it.has("dur"):
				it["dur"] = int(it["dur"])
			worn[k] = it
	created = bool(d.get("created", false))
	player_name = str(d.get("name", player_name))
	for k in d.get("train_ready", {}):
		train_ready[k] = float(d["train_ready"][k])
	_resize_bag()
	_sync_outfit()
	health = float(d.get("health", health))
	food = float(d.get("food", food))
	water = float(d.get("water", water))
	if health <= 0.0:
		reset_stats()
	inventory_changed.emit()
	stats_changed.emit()


## Guarda la partida. "world" es el estado de la zona actual.
func save_game(world: Dictionary) -> void:
	maps_state[current_map] = world
	var d := to_dict()
	d["maps"] = maps_state
	d["current_map"] = current_map
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
	maps_state = parsed.get("maps", {})
	if maps_state.is_empty() and parsed.has("world"):
		maps_state = {"refugio": parsed["world"]}   # partidas de la versión 0.1.1
	current_map = str(parsed.get("current_map", "refugio"))
	if not DB.maps.has(current_map):
		current_map = "refugio"
	return maps_state.get(current_map, {})
