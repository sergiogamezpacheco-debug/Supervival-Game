extends StaticBody3D
## Recurso recolectable (pino, roca, arbusto, hierba). Se agota y reaparece.

var kind := ""
var data: Dictionary = {}
var hits_left := 0
var depleted := false
var _respawn_timer := 0.0
var _visual: Node3D
var _shape: CollisionShape3D


func setup(p_kind: String) -> void:
	kind = p_kind
	data = DB.resources[kind]
	hits_left = int(data["hits"])
	add_to_group("interactable")
	add_to_group("resource")
	_visual = Builder.resource_mesh(kind)
	add_child(_visual)
	var r := float(data.get("radius", 0.0))
	if r > 0.0:
		_shape = CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = 2.0
		_shape.shape = cyl
		_shape.position.y = 1.0
		add_child(_shape)


func can_interact() -> bool:
	return not depleted


func action_label() -> String:
	return str(data.get("action", "Usar"))


func interact(_player: Node3D) -> void:
	if depleted:
		return
	var needed := str(data.get("tool", ""))
	var tool_slot := GS.best_tool(needed) if needed != "" else -1
	var has_tool := tool_slot >= 0
	if needed != "" and not has_tool and not bool(data.get("hand_ok", true)):
		GS.message.emit("Necesitas: %s" % ("hacha" if needed == "axe" else "pico"))
		return
	var amount_range: Array = data.get("amount", [1, 1])
	var amount := randi_range(int(amount_range[0]), int(amount_range[1]))
	if has_tool:
		amount *= int(DB.item(str(GS.slots[tool_slot]["id"])).get("gather_mult", 1))
	amount += int(GS.wear_bonus("gather"))
	var yield_id := str(data["yield"])
	var left := GS.add_item(yield_id, amount)
	if left == amount:
		GS.message.emit("Inventario lleno")
		return
	GS.message.emit("+%d %s" % [amount - left, DB.item_name(yield_id)])
	if has_tool:
		GS.wear_slot_item(tool_slot)
	_punch()
	hits_left -= 1
	if hits_left <= 0:
		_deplete()


func _punch() -> void:
	var tw := create_tween()
	_visual.scale = Vector3.ONE
	tw.tween_property(_visual, "scale", Vector3(1.12, 0.9, 1.12), 0.06)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.12)


func _deplete() -> void:
	depleted = true
	_visual.visible = false
	if _shape:
		_shape.set_deferred("disabled", true)
	_respawn_timer = float(data.get("respawn", 60))


func _process(delta: float) -> void:
	if not depleted:
		return
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		depleted = false
		hits_left = int(data["hits"])
		_visual.visible = true
		if _shape:
			_shape.set_deferred("disabled", false)
