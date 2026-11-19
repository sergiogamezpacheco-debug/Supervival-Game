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
var _model: CharacterModel = null
var _walk_phase := 0.0
var _walk_amount := 0.0
var _attack_t := 0.0
var _lunge := 0.0
var _lunge_cd := 0.0
var _called := 0.0               # le ha llamado una gritona: te busca aunque estés lejos
var _special := 0.0              # tiempo restante de grito, salto o pisotón
var _special_cd := 0.0
var _throw_cd := 0.0
var _pounce_hit := false
var _hidden := false              # acechador invisible de noche
var aware := false                # te ha visto u oído: te persigue
var _lost := 0.0                  # segundos sin tenerte a tiro (deja de perseguir)
var _bar: Node3D                  # barra de vida sobre la cabeza
var _bar_fill: MeshInstance3D
var _bar_time := 0.0
var _meshes: Array = []

static var _flash_mat: StandardMaterial3D
const HazardScript := preload("res://scripts/world/hazard.gd")


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
	cap.radius = (0.2 if small else 0.35) * stat("size", 1.0)
	cap.height = (0.5 if small else 1.6) * stat("size", 1.0)
	shape.shape = cap
	shape.position.y = cap.height / 2.0
	add_child(shape)
	if Infected.has(kind):   # infectados: el mismo cuerpo que el superviviente
		_visual = Node3D.new()
		_model = Infected.build(kind)
		_visual.add_child(_model)
	else:
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


func interact(by: Node3D) -> void:
	if hp <= 0.0:
		return
	var dmg := GS.hand_damage()
	# Golpe por sorpresa: agachado y sin que te haya visto
	var sneak: bool = by != null and by.get("crouching") == true and not aware and provoked <= 0.0
	if sneak:
		dmg *= stat("sneak_mult", float(DB.bal("sneak_mult", 3.0)))
	var blocked := false
	if data.has("front_armor") and by != null:
		var to_by := by.global_position - global_position
		to_by.y = 0.0
		if _in_front(to_by, to_by.length()):
			dmg *= 1.0 - stat("front_armor", 0.7)
			blocked = true
	hp -= dmg
	GS.wear_hand()
	provoked = 15.0
	aware = true
	_lost = 0.0
	_show_damage(dmg, sneak, blocked)
	SFX.play("picar" if blocked else "golpe")
	_flash()
	_bar_time = 4.0
	var tw := create_tween()
	_visual.scale = Vector3(1.2, 0.8, 1.2)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.15)
	if _player:
		var push := global_position - _player.global_position
		push.y = 0.0
		global_position += push.normalized() * 0.4
	if hp <= 0.0:
		_on_death()
		killed.emit(self)


## Al morir: el purulento revienta y deja una nube de veneno.
func _on_death() -> void:
	_special = 0.0
	if data.has("burst_radius") and get_parent():
		var h := HazardScript.new()
		h.mode = "cloud"
		h.radius = stat("burst_radius", 3.0)
		h.poison = stat("burst_poison", 12.0)
		h.duration = stat("burst_time", 5.0)
		get_parent().add_child(h)
		h.global_position = global_position
		SFX.play("reventar")


## Llamada de una gritona: viene a por ti aunque esté lejos.
func call_to(seconds: float) -> void:
	if hp <= 0.0 or not visible:
		return
	aware = true
	_lost = 0.0
	_called = maxf(_called, seconds)


func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	provoked = maxf(provoked - delta, 0.0)
	_called = maxf(_called - delta, 0.0)
	_special_move = Vector3.INF
	_special_cd = maxf(_special_cd - delta, 0.0)
	_throw_cd = maxf(_throw_cd - delta, 0.0)

	var to_player := Vector3.INF
	if _player and not GS.dead:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
	var dist := to_player.length() if to_player != Vector3.INF else INF
	var speed := stat("speed", 2.3)
	var move := Vector3.ZERO

	# ¿Te ve o te oye? Agachado y con lluvia te ve menos; correr y golpear hace ruido.
	var sight := stat("aggro_range", 9.0)
	var see := sight
	var heard := 0.0
	if _player and _player.has_method("sight_factor"):
		see = sight * _player.sight_factor()
		heard = _player.noise_radius()
	if not aware and dist < INF and ((dist < see and _in_front(to_player, dist)) or dist < heard):
		aware = true
		if behavior() == "aggressive":
			SFX.play("grunido", -8.0, 0.2)
			_alert_others()
	if aware:
		if dist > sight * float(DB.bal("lose_interest", 1.7)) and provoked <= 0.0 and _called <= 0.0:
			_lost += delta
			if _lost > 3.0:
				aware = false
		else:
			_lost = 0.0
	_update_bar(delta)

	# Acechador: de noche no se le ve hasta tenerlo muy cerca
	if data.get("night_stealth", false):
		var hide: bool = GS.is_night() and dist > 6.0 and _special <= 0.0
		if hide != _hidden:
			_hidden = hide
			_visual.visible = not hide

	var hostile := behavior() == "aggressive" or (behavior() == "neutral" and provoked > 0.0)
	var in_reach := dist < sight * float(DB.bal("lose_interest", 1.7)) or _called > 0.0
	if hostile and (aware or provoked > 0.0) and in_reach and _special_ai(delta, to_player, dist):
		pass   # gritona, salto del acechador o ataques del coloso: ya decidido
	elif hostile and (aware or provoked > 0.0) and in_reach:
		# Embestida (corredora): acelón corto al acercarse
		_lunge_cd = maxf(_lunge_cd - delta, 0.0)
		_lunge = maxf(_lunge - delta, 0.0)
		if data.has("lunge_speed") and _lunge_cd <= 0.0 and dist < 6.0 and dist > 2.5:
			_lunge = 0.6
			_lunge_cd = stat("lunge_cd", 4.0)
		if _lunge > 0.0:
			speed *= stat("lunge_speed", 1.5)
		if dist > stat("attack_range", 1.4):
			move = to_player.normalized() * speed
		elif _attack_cd <= 0.0:
			_attack()
		_face(to_player)
	elif behavior() == "passive" and (dist < stat("flee_range", 6.0) * (_player.sight_factor() if _player and _player.has_method("sight_factor") else 1.0) or dist < heard * 0.7 or (provoked > 0.0 and dist < 14.0)):
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
	if _special_move != Vector3.INF:
		move = _special_move
	velocity = move
	move_and_slide()
	position.y = 0.0
	if _model:
		var sp := move.length()
		_walk_amount = move_toward(_walk_amount, 1.0 if sp > 0.2 else 0.0, delta * 5.0)
		_walk_phase += delta * (3.0 + sp * 2.2)
		_attack_t = maxf(_attack_t - delta / 0.4, 0.0)
		if dist < 32.0 or _attack_t > 0.0:   # lejos de la cámara no hace falta animar
			Infected.pose(_model, _walk_phase, _walk_amount, 1.0 - _attack_t if _attack_t > 0.0 else 0.0, _special_pose())


func _attack(mult := 1.0) -> void:
	_attack_cd = stat("attack_interval", 1.2)
	_attack_t = 1.0
	if GS.invulnerable > 0.0:    # lo has esquivado
		return
	GS.hit(stat("attack_damage", 8) * mult)
	if data.has("poison"):
		GS.poison_for(stat("poison", 5.0))
	if _player and _player.has_method("hurt_flash"):
		_player.hurt_flash()
	if data.has("knockback") and _player and _player.has_method("push"):
		var away: Vector3 = _player.global_position - global_position
		away.y = 0.0
		_player.push(away.normalized() * stat("knockback", 6.0))
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3(1.1, 1.15, 1.1), 0.08)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.15)


var _special_move := Vector3.INF
var _special_total := 1.0


func _special_pose() -> float:
	if _special <= 0.0:
		return 0.0
	return clampf(1.0 - _special / _special_total, 0.0, 1.0) if kind == "coloso" else 1.0


func _start_special(seconds: float) -> void:
	_special = seconds
	_special_total = seconds


## Habilidades propias. Devuelve true si este fotograma ya está decidido.
func _special_ai(delta: float, to_player: Vector3, dist: float) -> bool:
	_special_move = Vector3.INF
	var dir := to_player.normalized()
	# --- Gritona: no ataca, mantiene la distancia y grita
	if data.has("scream_radius"):
		_face(to_player)
		if _special <= 0.0 and _special_cd <= 0.0:
			_start_special(1.3)
			_special_cd = stat("scream_cd", 9.0)
			_scream()
		_special = maxf(_special - delta, 0.0)
		if _special > 0.0:
			_special_move = Vector3.ZERO
		elif dist < stat("keep_away", 6.0):
			_special_move = -dir * stat("speed", 3.0)
			_face(-to_player)
		else:
			_special_move = Vector3.ZERO
		return true
	# --- Acechador: salto con daño doble
	if data.has("pounce_range"):
		if _special > 0.0:
			_special = maxf(_special - delta, 0.0)
			_special_move = dir * stat("speed", 3.6) * 3.4
			if not _pounce_hit and dist <= stat("attack_range", 1.3) + 0.4:
				_pounce_hit = true
				_special = 0.0
				_attack(stat("pounce_mult", 2.0))
			return true
		if _special_cd <= 0.0 and dist > 2.2 and dist < stat("pounce_range", 5.5):
			_start_special(0.5)
			_special_cd = stat("pounce_cd", 5.0)
			_pounce_hit = false
			_face(to_player)
			SFX.play("grunido", -2.0, 0.25)
			return true
		return false
	# --- Coloso: pisotón cerca y rocas a distancia
	if data.get("boss", false):
		_bar_time = maxf(_bar_time, 1.0)
		if _special > 0.0:
			_special = maxf(_special - delta, 0.0)
			_special_move = Vector3.ZERO
			if _special <= 0.0:
				if str(get_meta("doing", "")) == "stomp":
					_stomp_land(dist)
				else:
					_throw_rock()
			return true
		if _special_cd <= 0.0 and dist < stat("stomp_radius", 4.0):
			set_meta("doing", "stomp")
			_start_special(0.9)
			_special_cd = stat("stomp_cd", 7.0)
			var ring := HazardScript.new()
			ring.mode = "stomp"
			ring.radius = stat("stomp_radius", 4.0)
			ring.duration = 0.9
			get_parent().add_child(ring)
			ring.global_position = global_position
			return true
		if _throw_cd <= 0.0 and dist > stat("throw_min", 7.0) and dist < stat("throw_max", 16.0):
			set_meta("doing", "throw")
			_start_special(0.6)
			_throw_cd = stat("throw_cd", 6.0)
			_face(to_player)
			return true
		return false
	return false


func _scream() -> void:
	SFX.play("grito")
	var r := stat("scream_radius", 22.0)
	for c in get_tree().get_nodes_in_group("enemy"):
		if c != self and c.has_method("call_to") and c.global_position.distance_to(global_position) <= r:
			c.call_to(12.0)
	GS.message.emit("¡Una gritona está llamando a los infectados!")


func _stomp_land(dist: float) -> void:
	SFX.play("pisoton")
	if _player and _player.get("shake") != null:
		_player.shake = 0.5
	if dist <= stat("stomp_radius", 4.0) and GS.invulnerable <= 0.0:
		GS.hit(stat("stomp_damage", 25))
		if _player.has_method("hurt_flash"):
			_player.hurt_flash()
		if _player.has_method("push"):
			var away: Vector3 = _player.global_position - global_position
			away.y = 0.0
			_player.push(away.normalized() * 9.0)


func _throw_rock() -> void:
	if _player == null:
		return
	SFX.play("lanzar")
	var h := HazardScript.new()
	h.mode = "rock"
	h.damage = stat("throw_damage", 18)
	h.from = global_position + Vector3(0, 3.2, 0)
	h.to = Vector3(_player.global_position.x, 0.0, _player.global_position.z)
	get_parent().add_child(h)


## Solo ve lo que tiene delante (unos 140°); por detrás solo te oye.
func _in_front(to_player: Vector3, dist: float) -> bool:
	if dist < 1.0:
		return true
	var r := _visual.rotation.y
	var fwd := Vector3(-sin(r), 0.0, -cos(r))
	return fwd.dot(to_player / dist) > 0.3


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
	_special = 0.0
	_called = 0.0
	aware = false
	provoked = 0.0
	_bar_time = 0.0
	provoked = 0.0
	global_position = home
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


# ------------------------------------------------------------ sensación de golpe

## Número de daño que sube y se desvanece (dorado y más grande si es crítico).
func _show_damage(dmg: float, crit: bool, blocked := false) -> void:
	if not bool(SFX.settings.get("damage_numbers", true)):
		return
	var l := Label3D.new()
	l.text = "%d" % roundi(dmg)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 72 if crit else 52
	l.pixel_size = 0.01
	l.outline_size = 14
	l.modulate = Color("f6c94e") if crit else (Color("9aa3ab") if blocked else Color("fff4e2"))
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position = Vector3(randf_range(-0.2, 0.2), _top() + 0.3, 0.0)
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.0, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


## Destello blanco breve sobre todo el cuerpo.
func _flash() -> void:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color = Color(1, 1, 1, 0.55)
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if _meshes.is_empty():
		_collect_meshes(_visual)
	for m in _meshes:
		m.material_overlay = _flash_mat
	get_tree().create_timer(0.09).timeout.connect(func():
		for m in _meshes:
			if is_instance_valid(m):
				m.material_overlay = null)


func _collect_meshes(n: Node) -> void:
	if n is MeshInstance3D:
		_meshes.append(n)
	for c in n.get_children():
		_collect_meshes(c)


func _top() -> float:
	if Infected.has(kind):
		return Infected.top(kind)
	return 0.7 if behavior() == "passive" else 1.95


## Da la alarma: los infectados cercanos que la oigan también te buscan.
func _alert_others() -> void:
	var r := stat("alert_radius", 0.0)
	if r <= 0.0:
		return
	for c in get_tree().get_nodes_in_group("enemy"):
		if c != self and c.visible and not c.aware and c.global_position.distance_to(global_position) <= r:
			c.aware = true
			c._lost = 0.0


## Barra de vida sobre la cabeza: aparece unos segundos al recibir un golpe.
func _update_bar(delta: float) -> void:
	_bar_time = maxf(_bar_time - delta, 0.0)
	if _bar_time <= 0.0:
		if _bar:
			_bar.visible = false
		return
	if _bar == null:
		_bar = Node3D.new()
		add_child(_bar)
		var bg := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.12)
		bg.mesh = q
		bg.material_override = _bar_mat(Color(0, 0, 0, 0.7))
		_bar.add_child(bg)
		_bar_fill = MeshInstance3D.new()
		var q2 := QuadMesh.new()
		q2.size = Vector2(0.84, 0.07)
		_bar_fill.mesh = q2
		_bar_fill.material_override = _bar_mat(Color("d9443c"))
		_bar_fill.position.z = 0.002
		_bar.add_child(_bar_fill)
	_bar.visible = true
	_bar.position = Vector3(0, _top() + 0.35, 0)
	var cam := get_viewport().get_camera_3d()
	if cam:
		_bar.global_basis = cam.global_basis
	var f := clampf(hp / stat("health", 10), 0.0, 1.0)
	_bar_fill.scale.x = maxf(f, 0.001)
	_bar_fill.position.x = -0.42 * (1.0 - f)


func _bar_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 2
	return m
