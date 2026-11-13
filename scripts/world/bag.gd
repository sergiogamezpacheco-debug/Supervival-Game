extends Node3D
## Bolsa en el suelo: la mochila que dejas al morir o el botín de un infectado.

var items: Array = []
var is_player_bag := false


func setup(p_items: Array, p_player_bag: bool) -> void:
	items = p_items
	is_player_bag = p_player_bag
	add_to_group("interactable")
	add_to_group("bag")
	add_child(Builder.bag_mesh(is_player_bag))


func can_interact() -> bool:
	return not items.is_empty()


func action_label() -> String:
	return "Recuperar" if is_player_bag else "Saquear"


func interact(_by: Node3D) -> void:
	var remaining: Array = []
	var got := 0
	for it in items:
		var left := GS.add_stack(it)
		if left > 0:
			var rest: Dictionary = it.duplicate()
			rest["qty"] = left
			remaining.append(rest)
		if left < int(it["qty"]):
			got += 1
	items = remaining
	if items.is_empty():
		GS.message.emit("Mochila recuperada" if is_player_bag else "Botín recogido")
		queue_free()
	elif got == 0:
		GS.message.emit("Mochila llena")


func to_dict() -> Dictionary:
	return {"pos": [position.x, position.z], "items": items, "player": is_player_bag}
