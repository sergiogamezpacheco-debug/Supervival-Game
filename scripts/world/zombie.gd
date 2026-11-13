extends CharacterBody3D
## Infectado básico: deambula, persigue al jugador si lo ve cerca y ataca.

signal killed(zombie: Node3D)

var home := Vector3.ZERO
var hp := 40.0
var _attack_cd := 0.0
var _wander_target := Vector3.ZERO
var _wander_timer := 0.0
var _visual: Node3D
var _player: Node3D


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("interactable")
	add_to_group("enemy")
	hp = float(DB.zombie("health", 40))
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	add_child(shape)
	_visual = Builder.zombie_mesh()
	add_child(_visual)
	_wander_target = home


func can_interact() -> bool:
	return hp > 0.0


func action_label() -> String:
	return "Atacar"


func interact(_by: Node3D) -> void:
	if hp <= 0.0:
		return
	hp -= GS.hand_damage()
	GS.wear_hand()
	var tw := create_tween()
	_visual.scale = Vector3(1.2, 0.8, 1.2)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.15)
	# retroceso
	if _player:
		var push := (global_position - _player.global_position)
		push.y = 0.0
		global_position += push.normalized() * 0.4
	if hp <= 0.0:
		killed.emit(self)


func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	var speed := float(DB.zombie("speed", 2.3))
	var to_player := Vector3.INF
	if _player and not GS.dead:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
	var aggro := float(DB.zombie("aggro_range", 9.0))
	var reach := float(DB.zombie("attack_range", 1.4))
	var move := Vector3.ZERO
	if to_player != Vector3.INF and to_player.length() < aggro:
		if to_player.length() > reach:
			move = to_player.normalized() * speed
		elif _attack_cd <= 0.0:
			_attack()
		_face(to_player)
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(2.0, 5.0)
			_wander_target = home + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		var d := _wander_target - global_position
		d.y = 0.0
		if d.length() > 0.5:
			move = d.normalized() * speed * 0.4
			_face(d)
	velocity = move
	move_and_slide()
	position.y = 0.0


func _attack() -> void:
	_attack_cd = float(DB.zombie("attack_interval", 1.2))
	GS.damage(float(DB.zombie("attack_damage", 8)))
	if _player and _player.has_method("hurt_flash"):
		_player.hurt_flash()
	var tw := create_tween()
	tw.tween_property(_visual, "position:z", -0.3, 0.08)
	tw.tween_property(_visual, "position:z", 0.0, 0.15)


func _face(dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	_visual.rotation.y = atan2(-dir.x, -dir.z)


func revive() -> void:
	hp = float(DB.zombie("health", 40))
	global_position = home
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
