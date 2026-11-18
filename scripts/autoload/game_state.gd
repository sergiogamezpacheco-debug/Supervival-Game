extends Node
## Estado del jugador (autoload "GS"): inventario, mano, hambre/sed/vida y guardado.

signal inventory_changed
signal stats_changed
signal message(text: String)
signal died
signal look_changed            # ropa o físico: hay que rehacer el modelo
signal xp_gained(amount: int)
signal leveled_up(new_level: int, unlocks: Array, reward: Dictionary)

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
var _launched := false          # ya se cargó la partida una vez desde que se abrió el juego
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
var level := 1                 # nivel del superviviente (1-100)
var xp := 0                    # experiencia dentro del nivel actual
var visited: Dictionary = {}   # zonas ya visitadas (dan XP la primera vez)
var train_ready: Dictionary = {} # ejercicio -> hora (unix) en que se puede volver a entrenar
var testing := false           # los tests no muestran la pantalla de creación
var pending_drop: Array = []
var invulnerable := 0.0         # segundos sin recibir golpes (esquivando)
var forced_hour := -1.0        # >= 0: hora fija (tests y capturas)
var forced_rain := -1          # -1 según el reloj, 0 seco, 1 lloviendo   # objetos de partidas antiguas que ya no caben (se dejan en una bolsa)

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
	# En los tests todo está desbloqueado salvo que el test fije el nivel
	level = DB.max_level() if testing else 1
	xp = 0
	visited = {"refugio": true}
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
	invulnerable = maxf(invulnerable - delta, 0.0)
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
	if level < DB.recipe_unlock(r):
		message.emit("Se desbloquea en el nivel %d" % DB.recipe_unlock(r))
		return false
	if not can_craft(r):
		message.emit("Faltan materiales")
		return false
	var result := str(r["result"])
	var qty := int(r.get("qty", 1))
	if free_slots() == 0 and count(result) == 0:
		message.emit("Inventario lleno")
		return false
	SFX.play("fabricar", -4.0)
	var cost: Dictionary = r["cost"]
	for id in cost:
		remove_item(str(id), int(cost[id]))
	var left := add_item(result, qty)
	if left > 0:
		message.emit("Inventario lleno: se perdió parte del objeto")
	message.emit("Fabricado: %s" % DB.item_name(result))
	add_xp(craft_xp(r))
	return true


# ---------------------------------------------------------------- niveles

## XP por fabricar: según lo que tarda la receta (las manuales dan 1).
func craft_xp(r: Dictionary) -> int:
	var t := float(r.get("time", 0))
	return clampi(int(t / 10.0 * DB.xp_value("craft_per_10s", 1)), 1, int(DB.xp_value("craft_max", 15)))


func has_level(lv: int) -> bool:
	return level >= lv


func xp_needed() -> int:
	return DB.xp_to_next(level)


func xp_progress() -> float:
	if level >= DB.max_level():
		return 1.0
	return clampf(float(xp) / float(xp_needed()), 0.0, 1.0)


## Suma experiencia y sube de nivel las veces que haga falta.
func add_xp(amount: int) -> void:
	if amount <= 0 or level >= DB.max_level():
		return
	xp += amount
	xp_gained.emit(amount)
	while level < DB.max_level() and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		health = 100.0   # subir de nivel cura del todo
		var reward := level_reward(level)
		for id in reward:
			var left := add_item(str(id), int(reward[id]))
			if left > 0:
				pending_drop.append(make_item(str(id), left))
		SFX.play("nivel", 0.0, 0.0)
		leveled_up.emit(level, DB.unlocks_at(level), reward)
	if level >= DB.max_level():
		xp = 0
	stats_changed.emit()


## Recompensa al llegar a un nivel: las de levels.json; cada 5 niveles algo siempre.
func level_reward(lv: int) -> Dictionary:
	var r: Dictionary = DB.levels.get("rewards", {})
	if r.has(str(lv)):
		return r[str(lv)]
	if lv % 10 == 0:
		return DB.levels.get("reward_default_milestone", {})
	return {}


## Primera visita a una zona.
func visit(map_id: String) -> void:
	if not visited.has(map_id):
		visited[map_id] = true
		add_xp(int(DB.xp_value("zone_first", 40)))


# ------------------------------------------------------------------- peso

func carry_weight() -> float:
	var w := 0.0
	for it in slots:
		if it != null:
			w += DB.weight(str(it["id"])) * int(it["qty"])
	for k in worn:
		if worn[k] != null:
			w += DB.weight(str(worn[k]["id"]))
	if hand != null:
		w += DB.weight(str(hand["id"]))
	return w


## Lo que puedes llevar sin ir sobrecargado: base, fuerza y mochila.
func carry_capacity() -> float:
	var c := float(DB.bal("carry_base", 30.0)) + float(physique["fuerza"]) * float(DB.bal("carry_per_fuerza", 15.0))
	for k in worn:
		if worn[k] != null:
			c += float(DB.item(str(worn[k]["id"])).get("carry", 0))
	return c


func overloaded() -> bool:
	return load_ratio() > 1.0


## Cuántos huecos de la mochila están ocupados (anillo del botón de inventario).
func slot_fill() -> float:
	if slots.is_empty():
		return 0.0
	return 1.0 - float(free_slots()) / float(slots.size())


func use_slot(i: int) -> void:
	var s = slots[i]
	if s == null:
		return
	var data := DB.item(str(s["id"]))
	match str(data.get("type", "")):
		"consumable":
			SFX.play("beber" if data.has("water") and not data.has("food") else "comer")
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
	if t == "tool":
		message.emit("Las herramientas se usan solas desde el inventario")
		return
	if t != "weapon":
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
		message.emit("Inventario lleno")


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


## La mejor herramienta del inventario para un trabajo ("axe", "pickaxe"):
## la que más recoge y, a igualdad, la más gastada (para no dejarla a medias).
## Devuelve la casilla o -1.
func best_tool(kind: String) -> int:
	var best := -1
	var best_mult := 0
	var best_dur := 1 << 30
	for i in slots.size():
		var s = slots[i]
		if s == null:
			continue
		var d := DB.item(str(s["id"]))
		if str(d.get("type", "")) != "tool" or str(d.get("tool", "")) != kind:
			continue
		var m := int(d.get("gather_mult", 1))
		var dur := int(s.get("dur", 0))
		if m > best_mult or (m == best_mult and dur < best_dur):
			best = i
			best_mult = m
			best_dur = dur
	return best


## Gasta 1 de durabilidad del objeto de una casilla. Se rompe al llegar a 0.
func wear_slot_item(i: int) -> void:
	var s = slots[i]
	if s == null or not s.has("dur"):
		return
	s["dur"] = int(s["dur"]) - 1
	if int(s["dur"]) <= 0:
		message.emit("¡Se rompió %s!" % DB.item_name(str(s["id"])))
		slots[i] = null
	inventory_changed.emit()


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
		message.emit("Inventario lleno")
		return false
	worn[slot] = null
	_resize_bag()
	add_stack(it)
	_sync_outfit()
	message.emit("Te quitas: %s" % DB.item_name(str(it["id"])))
	inventory_changed.emit()
	return true


func _first_free() -> int:
	for i in slots.size():
		if slots[i] == null:
			return i
	return -1


## Nivel de la mochila puesta: 0 sin mochila, 1 lona, 2 excursión, 3 táctica.
func bag_level() -> int:
	var it = worn.get("espalda")
	if it == null:
		return 0
	return clampi(int(DB.item(str(it["id"])).get("bag_slots", 0)) / 8, 0, 3)


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
	if dead or invulnerable > 0.0:
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


# ------------------------------------------------------------ reparar

## Objetos gastados que se reparan en una estación: herramientas y armas en el
## banco de trabajo, ropa en la mesa de costura. Cada uno: {"where", "i"/"slot", "item"}.
func damaged_items(station_id: String) -> Array:
	var types := ["wear"] if station_id == "mesa_costura" else ["tool", "weapon"]
	var out: Array = []
	var check := func(it, ref: Dictionary):
		if it == null or not it.has("dur"):
			return
		var d := DB.item(str(it["id"]))
		if not types.has(str(d.get("type", ""))):
			return
		if int(it["dur"]) < int(d.get("durability", 0)):
			ref["item"] = it
			out.append(ref)
	check.call(hand, {"where": "hand"})
	for k in WEAR_SLOTS:
		check.call(worn.get(k), {"where": "worn", "slot": k})
	for i in slots.size():
		check.call(slots[i], {"where": "slot", "i": i})
	return out


## Coste de reparar: parte de la receta, según lo gastado que esté.
func repair_cost(it: Dictionary) -> Dictionary:
	var id := str(it["id"])
	var d := DB.item(id)
	var mx := float(d.get("durability", 1))
	var worn_frac := clampf(1.0 - float(it.get("dur", mx)) / mx, 0.0, 1.0)
	var frac := float(DB.bal("repair_fraction", 0.4)) * worn_frac
	var base: Dictionary = DB.recipe(id).get("cost", {})
	if base.is_empty():   # objetos que solo se encuentran
		base = {"tela": 5, "cuerda": 2} if str(d.get("type", "")) == "wear" else {"madera": 5, "piedra": 5}
	var cost := {}
	for k in base:
		var kd := DB.item(str(k))
		if str(kd.get("type", "")) in ["wear", "tool", "weapon"]:
			continue    # no se gasta otra prenda o herramienta para reparar
		cost[k] = maxi(1, ceili(float(base[k]) * frac))
	return cost


func repair(ref: Dictionary) -> String:
	var it: Dictionary = ref["item"]
	var cost := repair_cost(it)
	if not pay(cost):
		return "Faltan materiales: %s" % DB.cost_text(cost)
	it["dur"] = int(DB.item(str(it["id"])).get("durability", it["dur"]))
	message.emit("%s reparado" % DB.item_name(str(it["id"])))
	inventory_changed.emit()
	return ""


# ------------------------------------------------------- día, noche y tiempo

## Hora del día (0..24). El día dura "day_seconds" segundos reales y sigue el reloj
## aunque el juego esté cerrado (como las estaciones).
func hour() -> float:
	if forced_hour >= 0.0:
		return forced_hour
	var day := float(DB.bal("day_seconds", 1440))
	return fposmod(now() / day, 1.0) * 24.0


## 1 a pleno día, 0 de noche, con amanecer y anochecer de dos horas.
func daylight() -> float:
	var h := hour()
	var dawn := float(DB.bal("dawn_hour", 6.0))
	var dusk := float(DB.bal("dusk_hour", 21.0))
	return minf(smoothstep(dawn - 1.0, dawn + 1.0, h), 1.0 - smoothstep(dusk - 1.0, dusk + 1.0, h))


func is_night() -> bool:
	return daylight() < 0.5


## Lluvia: cada "weather_window" segundos se decide (igual para todos los mapas).
func raining() -> bool:
	if forced_rain >= 0:
		return forced_rain == 1
	var w := floori(now() / float(DB.bal("weather_window", 300)))
	var r := RandomNumberGenerator.new()
	r.seed = hash("lluvia%d" % w)
	return r.randf() < float(DB.bal("rain_chance", 0.22))


## Adelanta el reloj hasta la hora pedida (para pruebas y para dormir más adelante).
func set_hour(h: float) -> void:
	var day := float(DB.bal("day_seconds", 1440))
	time_offset += fposmod(h - hour(), 24.0) / 24.0 * day


func clock_text() -> String:
	var h := hour()
	return "%02d:%02d" % [floori(h), floori(fmod(h, 1.0) * 60.0)]


# ------------------------------------------------------- físico y aguante

## Fracción de la mochila ocupada (0..1).
## Peso que llevas respecto a lo que aguantas (1 = al límite).
func load_ratio() -> float:
	return carry_weight() / maxf(carry_capacity(), 1.0)


func max_stamina() -> float:
	return float(DB.bal("stamina_base", 100)) + float(physique["resistencia"]) * float(DB.bal("stamina_per_resistencia", 60))


## Aguante que se gasta por segundo corriendo: más cuanto más peso llevas.
func stamina_drain() -> float:
	return float(DB.bal("stamina_drain", 5.0)) * (1.0 + float(DB.bal("stamina_drain_load", 1.2)) * load_ratio()) * (1.0 - float(physique["resistencia"]) * 0.45)


## Velocidad relativa: a partir de media carga vas más lento, y mucho más con sobrecarga.
## La fuerza reduce el castigo; las zapatillas ayudan.
func speed_factor() -> float:
	var f := 1.0 + wear_bonus("speed")
	var r := load_ratio()
	var pen := 0.0
	if r > 0.5:
		pen += minf(r - 0.5, 0.5) / 0.5 * 0.25
	if r > 1.0:
		pen += minf(r - 1.0, 0.7) * 0.5
	pen *= 1.0 - float(physique["fuerza"]) * 0.5
	return maxf(f - pen, 0.35)


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
		"level": level,
		"xp": xp,
		"visited": visited,
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
	# Se colocan en orden; lo que ya no cabe (partidas de cuando había 20 huecos) va a una bolsa.
	pending_drop = []
	for i in saved.size():
		var s = saved[i]
		if s == null or not DB.items.has(str(s.get("id", ""))):
			continue
		s["qty"] = int(s["qty"])
		if s.has("dur"):
			s["dur"] = int(s["dur"])
		if i < slots.size() and slots[i] == null:
			slots[i] = s
		elif _first_free() >= 0:
			slots[_first_free()] = s
		else:
			pending_drop.append(s)
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
	# Antes las herramientas iban en la mano; ahora solo las armas.
	if hand != null and str(DB.item(str(hand["id"])).get("type", "")) == "tool":
		var t = hand
		hand = null
		if add_stack(t) > 0:
			pending_drop.append(t)
	player_name = str(d.get("name", player_name))
	for k in d.get("train_ready", {}):
		train_ready[k] = float(d["train_ready"][k])
	# Partidas de antes de los niveles: se empieza en el 12 para no perder lo que ya tenías
	level = clampi(int(d.get("level", 12)), 1, DB.max_level())
	xp = int(d.get("xp", 0))
	visited = d.get("visited", {"refugio": true})
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
	# Al abrir el juego siempre se empieza en el refugio (la zona en la que estabas se guarda)
	if not _launched:
		_launched = true
		if current_map != "refugio":
			var w: Dictionary = maps_state.get("refugio", {})
			w.erase("player")
			maps_state["refugio"] = w
			current_map = "refugio"
	return maps_state.get(current_map, {})
