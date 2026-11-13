extends CharacterBody3D
## Jugador: se mueve con el joystick (o WASD en PC) y ejecuta la acción
## contextual mientras se mantiene pulsado el botón de acción.

var move_input := Vector2.ZERO   # lo rellena el HUD (joystick)
var action_held := false          # lo rellena el HUD (botón de acción)
var target: Node3D = null         # objetivo más cercano (lo calcula el mundo)

var _action_cd := 0.0
var _visual: Node3D
var _hand: Node3D
var _hand_item := ""


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("player")
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	shape.shape = cap
	shape.position.y = 0.8
	add_child(shape)
	_visual = Builder.player_mesh()
	add_child(_visual)
	_hand = _visual.get_node("Hand")
	GS.inventory_changed.connect(_refresh_hand)
	_refresh_hand()


func _physics_process(delta: float) -> void:
	if GS.dead:
		velocity = Vector3.ZERO
		return
	var dir := move_input
	var kb := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	if kb != Vector2.ZERO:
		dir = kb.normalized()
	var speed := float(DB.bal("player_speed", 4.5))
	velocity = Vector3(dir.x, 0.0, dir.y) * speed
	move_and_slide()
	position.y = 0.0
	if dir.length() > 0.1:
		_face(Vector3(dir.x, 0.0, dir.y))

	_action_cd = maxf(_action_cd - delta, 0.0)
	var acting := action_held or Input.is_key_pressed(KEY_SPACE)
	if acting and target != null and is_instance_valid(target) and _action_cd <= 0.0:
		_face(target.global_position - global_position)
		target.interact(self)
		_swing()
		_action_cd = float(DB.bal("action_interval", 0.6))


func _face(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	_visual.rotation.y = atan2(-dir.x, -dir.z)


func _swing() -> void:
	var tw := create_tween()
	tw.tween_property(_hand, "rotation_degrees:x", -70.0, 0.08)
	tw.tween_property(_hand, "rotation_degrees:x", 0.0, 0.15)


func _refresh_hand() -> void:
	var id := "" if GS.hand == null else str(GS.hand["id"])
	if id == _hand_item:
		return
	_hand_item = id
	for c in _hand.get_children():
		c.queue_free()
	_hand.add_child(Builder.tool_mesh(id))


func hurt_flash() -> void:
	var tw := create_tween()
	_visual.scale = Vector3(1.15, 0.85, 1.15)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.2)
