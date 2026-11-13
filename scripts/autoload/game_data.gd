extends Node
## Datos del juego (autoload "DB"). Todo el contenido vive en data/*.json
## para poder añadir objetos, recetas y recursos sin tocar código.

var items: Dictionary = {}
var recipes: Array = []
var resources: Dictionary = {}
var balance: Dictionary = {}


func _init() -> void:
	reload()


func reload() -> void:
	items = _load_json("res://data/items.json", {})
	recipes = _load_json("res://data/recipes.json", [])
	resources = _load_json("res://data/resources.json", {})
	balance = _load_json("res://data/balance.json", {})


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


func zombie(key: String, fallback: Variant = 0) -> Variant:
	var z: Dictionary = balance.get("zombie", {})
	return z.get(key, fallback)


func recipe(id: String) -> Dictionary:
	for r in recipes:
		if str(r.get("id", "")) == id:
			return r
	return {}
