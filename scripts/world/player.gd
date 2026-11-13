extends CharacterBody3D
## Jugador: se mueve con el joystick (o WASD en PC) y ejecuta la acción
## contextual mientras se mantiene pulsado el botón de acción.

var move_input := Vector2.ZERO   # lo rellena el HUD (joystick)
var action_held := false          # lo rellena el HUD (botón de acción)
var target: Node3D = null         # objetivo más cercano (lo calcula el mundo)
var floor_y := 0.0                # altura del suelo (sube sobre los cimientos)

var _action_cd := 0.0
var _visual: CharacterModel
var _hand: Node3D
var _walk_phase := 0.0
var _walk_amount := 0.0
var _swing_t := -1.0
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
	_visual = CharacterModel.new(GS.look, GS.physique, GS.outfit)
	add_child(_visual)
	_hand = _visual.hand
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
	position.y = floor_y
	if dir.length() > 0.1:
		_face(Vector3(dir.x, 0.0, dir.y))

	# Animación de andar y golpe
	var moving := dir.length() > 0.1
	_walk_amount = move_toward(_walk_amount, 1.0 if moving else 0.0, delta * 6.0)
	if moving:
		_walk_phase += delta * 9.0 * dir.length()
	_visual.animate_walk(_walk_phase, _walk_amount)
	if _swing_t >= 0.0:
		_swing_t += delta / 0.3
		if _swing_t >= 1.0:
			_swing_t = -1.0
		else:
			_visual.animate_swing(_swing_t)

	_action_cd = maxf(_action_cd - delta, 0.0)
	var acting := action_held or Input.is_key_pressed(KEY_SPACE)
	if acting and target != null and is_instance_valid(target) and _action_cd <= 0.0:
		_face(target.global_position - global_position)
		target.interact(self)
		_swing()
		_action_cd = float(DB.bal("action_interval", 0.6))


## Dirección hacia la que mira el jugador.
func facing() -> Vector3:
	var r := _visual.rotation.y
	return Vector3(-sin(r), 0.0, -cos(r))


func _face(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	_visual.rotation.y = atan2(-dir.x, -dir.z)


func _swing() -> void:
	_swing_t = 0.0


func _refresh_hand() -> void:
	var id := "" if GS.hand == null else str(GS.hand["id"])
	if id == _hand_item:
		return
	_hand_item = id
	for c in _hand.get_children():
		c.queue_free()
	var tool := Builder.tool_mesh(id)
	tool.rotation_degrees.x = -80.0
	_hand.add_child(tool)


## El aspecto ha cambiado (creación de personaje, ropa nueva, físico).
func refresh_look() -> void:
	_visual.look = GS.look.duplicate()
	_visual.physique = GS.physique.duplicate()
	_visual.outfit = GS.outfit.duplicate()
	_visual.rebuild()
	_hand = _visual.hand
	_hand_item = "-"
	_refresh_hand()


func hurt_flash() -> void:
	var tw := create_tween()
	_visual.scale = Vector3(1.15, 0.85, 1.15)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.2)
