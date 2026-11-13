extends Node
## Datos del juego (autoload "DB"). Todo el contenido vive en data/*.json
## para poder añadir objetos, recetas y recursos sin tocar código.

var items: Dictionary = {}
var recipes: Array = []
var resources: Dictionary = {}
var balance: Dictionary = {}
var structures: Dictionary = {}
var stations: Dictionary = {}
var creatures: Dictionary = {}
var maps: Dictionary = {}


func _init() -> void:
	reload()


func reload() -> void:
	items = _load_json("res://data/items.json", {})
	recipes = _load_json("res://data/recipes.json", [])
	resources = _load_json("res://data/resources.json", {})
	balance = _load_json("res://data/balance.json", {})
	structures = _load_json("res://data/structures.json", {})
	stations = _load_json("res://data/stations.json", {})
	creatures = _load_json("res://data/creatures.json", {})
	maps = _load_json("res://data/maps.json", {})


func _load_json(path: String, fallback: Variant) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir %s" % path)
		return fallback
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null or typeof(parsed) != typeof(fallback):
		push_error("JSON inválido en %s" % path)
		return fallback
	return parsed


func item(id: String) -> Dictionary:
	if items.has(id):
		return items[id]
	return {}


func item_name(id: String) -> String:
	return str(item(id).get("name", id))


func stack_size(id: String) -> int:
	return int(item(id).get("stack", 1))


func bal(key: String, fallback: Variant = 0) -> Variant:
	return balance.get(key, fallback)


func creature(id: String) -> Dictionary:
	if creatures.has(id):
		return creatures[id]
	return {}


## Recetas de una estación ("" = a mano), ordenadas por nivel.
func recipes_for(station: String) -> Array:
	var out: Array = []
	for r in recipes:
		if str(r.get("station", "")) == station:
			out.append(r)
	out.sort_custom(func(a, b): return int(a.get("level", 0)) < int(b.get("level", 0)))
	return out


func station_name(id: String) -> String:
	return str(stations.get(id, {}).get("name", id))


func structure_tier(id: String, tier: int) -> Dictionary:
	var tiers: Array = structures.get(id, {}).get("tiers", [])
	if tier >= 0 and tier < tiers.size():
		return tiers[tier]
	return {}


func station_level(id: String, level: int) -> Dictionary:
	var levels: Array = stations.get(id, {}).get("levels", [])
	if level >= 1 and level <= levels.size():
		return levels[level - 1]
	return {}


func cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in cost:
		parts.append("%s %d/%d" % [item_name(str(id)), GS.count(str(id)), int(cost[id])])
	return ", ".join(parts)


func recipe(id: String) -> Dictionary:
	for r in recipes:
		if str(r.get("id", "")) == id:
			return r
	return {}
