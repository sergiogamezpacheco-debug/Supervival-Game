extends StaticBody3D
## Pieza de construcción: cimiento, pared o puerta (data/structures.json).
## Tiene niveles (madera → piedra → metal) y vida para los futuros asaltos.

var id := ""
var kind := ""          # foundation | wall | door
var tier := 0
var key := ""           # casilla "i,j" o borde "i,j,d"
var hp := 0.0
var is_open := false
var _visual: Node3D
var _shape: CollisionShape3D


func setup(p_id: String, p_tier: int, p_key: String) -> void:
	id = p_id
	kind = str(DB.structures[id]["kind"])
	tier = p_tier
	key = p_key
	add_to_group("structure")
	if kind == "door":
		add_to_group("interactable")
	if kind != "foundation":
		_shape = CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(2.0, 2.6, 0.3)
		_shape.shape = b
		_shape.position.y = 1.3
		add_child(_shape)
	_rebuild()


func tier_data() -> Dictionary:
	return DB.structure_tier(id, tier)


func display_name() -> String:
	return str(tier_data().get("name", id))


func max_tier() -> int:
	return (DB.structures[id]["tiers"] as Array).size() - 1


func set_tier(t: int) -> void:
	tier = t
	_rebuild()


func _rebuild() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Builder.merge(Builder.structure_mesh(kind, Color(str(tier_data().get("color", "888888")))))
	add_child(_visual)
	hp = float(tier_data().get("hp", 100))
	_apply_door()


# ------------------------------------------------------------------ puerta

func can_interact() -> bool:
	return kind == "door"


func action_label() -> String:
	return "Cerrar" if is_open else "Abrir"


func interact(_by: Node3D) -> void:
	if kind != "door":
		return
	is_open = not is_open
	_apply_door()


func _apply_door() -> void:
	if kind != "door":
		return
	var hinge := _visual.get_node_or_null("Hinge") as Node3D
	if hinge:
		hinge.rotation_degrees.y = 95.0 if is_open else 0.0
	if _shape:
		_shape.set_deferred("disabled", is_open)


func to_dict() -> Dictionary:
	return {"id": id, "key": key, "tier": tier, "open": is_open}
