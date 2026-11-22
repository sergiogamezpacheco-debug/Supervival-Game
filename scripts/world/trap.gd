extends Node3D
## Trampa de pinchos colocada en el suelo: hiere a las criaturas que la pisan (a ti no).
## Aguanta "durability" golpes (los que le quedan van con ella si la recoges) y luego se rompe.

var uses := 4
var _cd := {}     # criatura -> segundos hasta que puede volver a herirla
var _visual: Node3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("trap")
	_visual = StationModels.trap()
	add_child(_visual)


func damage() -> float:
	return float(DB.item("trampa_pinchos").get("damage", 40))


## Con enemigos cerca el botón no la recoge (para no quitarla en plena pelea).
func can_interact() -> bool:
	var w := get_tree().get_first_node_in_group("world")
	return w == null or not w.enemies_near(6.0)


func action_label() -> String:
	return "Recoger"


func interact(_by: Node3D) -> void:
	if GS.add_item("trampa_pinchos", 1, uses) > 0:
		GS.message.emit("Inventario lleno")
		return
	GS.message.emit("Trampa recogida")
	remove_from_group("interactable")
	queue_free()


func _physics_process(delta: float) -> void:
	for k in _cd.keys():
		_cd[k] = float(_cd[k]) - delta
		if float(_cd[k]) <= 0.0:
			_cd.erase(k)
	if uses > 0:
		check_creatures()


## Pincha a las criaturas que estén encima. Devuelve cuántas.
func check_creatures() -> int:
	var n := 0
	var r := float(DB.bal("trap_radius", 0.9))
	for c in get_tree().get_nodes_in_group("creature"):
		var node := c as Node3D
		if node == null or not node.visible or float(node.get("hp")) <= 0.0 or _cd.has(node.get_instance_id()):
			continue
		var d := Vector2(node.global_position.x - global_position.x, node.global_position.z - global_position.z).length()
		if d > r:
			continue
		_cd[node.get_instance_id()] = float(DB.bal("trap_cooldown", 1.2))
		node.take_damage(damage(), false, false, "picar")
		uses -= 1
		n += 1
		var tw := create_tween()
		_visual.scale = Vector3(1.15, 1.35, 1.15)
		tw.tween_property(_visual, "scale", Vector3.ONE, 0.2)
		if uses <= 0:
			GS.message.emit("Una trampa de pinchos se ha roto")
			remove_from_group("interactable")
			remove_from_group("trap")
			queue_free()
			break
	return n


func to_dict() -> Dictionary:
	return {"pos": [global_position.x, global_position.z], "uses": uses, "rot": rotation.y}
