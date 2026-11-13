extends CharacterBody3D
## Criatura genérica definida en data/creatures.json.
##  - aggressive: te persigue si te ve (infectados, lobos).
##  - neutral: pasta tranquila, pero si le pegas se enfada (jabalí).
##  - passive: huye de ti (conejo).

signal killed(creature: Node3D)

var kind := ""
var data: Dictionary = {}
var home := Vector3.ZERO
var hp := 10.0
var provoked := 0.0               # segundos que sigue enfadado (neutral) o asustado (passive)
var _attack_cd := 0.0
var _wander_target := Vector3.ZERO
var _wander_timer := 0.0
var _visual: Node3D
var _player: Node3D


func setup(p_kind: String) -> void:
	kind = p_kind
	data = DB.creature(kind)


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("interactable")
	add_to_group("creature")
	if behavior() != "passive":
		add_to_group("enemy")
	hp = float(data.get("health", 10))
	var small := behavior() == "passive"
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.2 if small else 0.35
	cap.height = 0.5 if small else 1.6
	shape.shape = cap
	shape.position.y = cap.height / 2.0
	add_child(shape)
	_visual = Builder.creature_mesh(kind)
	add_child(_visual)
	_wander_target = home


func behavior() -> String:
	return str(data.get("behavior", "aggressive"))


func stat(key: String, fallback: float) -> float:
	return float(data.get(key, fallback))


func can_interact() -> bool:
	return hp > 0.0


func action_label() -> String:
	return "Cazar" if behavior() != "aggressive" else "Atacar"


func interact(_by: Node3D) -> void:
	if hp <= 0.0:
		return
	hp -= GS.hand_damage()
	GS.wear_hand()
	provoked = 15.0
	var tw := create_tween()
	_visual.scale = Vector3(1.2, 0.8, 1.2)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.15)
	if _player:
		var push := global_position - _player.global_position
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
	provoked = maxf(provoked - delta, 0.0)

	var to_player := Vector3.INF
	if _player and not GS.dead:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
	var dist := to_player.length() if to_player != Vector3.INF else INF
	var speed := stat("speed", 2.3)
	var move := Vector3.ZERO

	var hostile := behavior() == "aggressive" or (behavior() == "neutral" and provoked > 0.0)
	if hostile and dist < stat("aggro_range", 9.0):
		if dist > stat("attack_range", 1.4):
			move = to_player.normalized() * speed
		elif _attack_cd <= 0.0:
			_attack()
		_face(to_player)
	elif behavior() == "passive" and (dist < stat("flee_range", 6.0) or (provoked > 0.0 and dist < 14.0)):
		move = -to_player.normalized() * speed
		_face(move)
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(2.0, 5.0)
			_wander_target = home + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		var d := _wander_target - global_position
		d.y = 0.0
		if d.length() > 0.5:
			move = d.normalized() * speed * 0.35
			_face(d)
	velocity = move
	move_and_slide()
	position.y = 0.0


func _attack() -> void:
	_attack_cd = stat("attack_interval", 1.2)
	GS.damage(stat("attack_damage", 8))
	if _player and _player.has_method("hurt_flash"):
		_player.hurt_flash()
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3(1.1, 1.15, 1.1), 0.08)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.15)


func _face(dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	_visual.rotation.y = atan2(-dir.x, -dir.z)


func roll_loot(rng: RandomNumberGenerator) -> Array:
	var loot: Array = []
	var table: Dictionary = data.get("loot", {})
	for id in table:
		var r: Array = table[id]
		var q := rng.randi_range(int(r[0]), int(r[1]))
		if q > 0:
			loot.append(GS.make_item(str(id), q))
	return loot


func revive() -> void:
	hp = stat("health", 10)
	provoked = 0.0
	global_position = home
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
