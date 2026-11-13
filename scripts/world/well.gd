extends StaticBody3D
## Pozo: beber agua.


func _ready() -> void:
	add_to_group("interactable")
	add_child(Builder.well_mesh())
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.0
	cyl.height = 2.0
	shape.shape = cyl
	shape.position.y = 1.0
	add_child(shape)


func can_interact() -> bool:
	return true


func action_label() -> String:
	return "Beber"


func interact(_by: Node3D) -> void:
	GS.drink(float(DB.bal("well_water", 30)))
	GS.message.emit("Has bebido agua")
