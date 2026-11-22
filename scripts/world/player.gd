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
var _run_amount := 0.0
var _vel := Vector3.ZERO
var _swing_t := -1.0
var _idle_t := 0.0
var _hand_item := ""
var running := false
var crouching := false            # agachado: lento, silencioso y con golpe crítico por sorpresa
var shake := 0.0                  # sacudida de cámara al recibir un golpe (la lee el mundo)
var _crouch_amount := 0.0
var dodging := 0.0                # segundos que quedan de esquiva
var _dodge_dir := Vector3.ZERO
var _dodge_cd := 0.0
var _step_phase := 0.0
var _push := Vector3.ZERO          # empujón recibido (golpe del hinchado)
var _noise_pulse := 0.0           # ruido puntual (golpear, talar) que se apaga en un segundo
var training := 0.0               # segundos de entrenamiento en el gimnasio (animación)
var _exhausted := false
var _rest := 0.0


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
	GS.look_changed.connect(refresh_look)
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
	if training > 0.0:
		dir = Vector2.ZERO
		training = maxf(training - delta, 0.0)
	_update_stamina(dir, delta)
	_refresh_hand()
	_noise_pulse = maxf(_noise_pulse - delta * 9.0, 0.0)
	shake = maxf(shake - delta, 0.0)
	var speed := float(DB.bal("player_speed", 4.5)) * GS.speed_factor()
	if running:
		speed *= float(DB.bal("run_mult", 1.5))
	if crouching:
		speed *= float(DB.bal("crouch_speed", 0.55))
	# Acelera y frena con suavidad (sin tirones aunque el dedo tiemble en el joystick)
	var want := Vector3(dir.x, 0.0, dir.y) * speed
	var acc := float(DB.bal("player_accel", 14.0)) * maxf(speed, 1.0) * 0.35
	if want.length() < 0.01:
		acc *= 3.0   # al soltar el joystick frena enseguida
	_vel = _vel.move_toward(want, acc * delta)
	velocity = _vel
	velocity += _push
	_push = _push.move_toward(Vector3.ZERO, delta * 22.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	if dodging > 0.0:
		dodging = maxf(dodging - delta, 0.0)
		velocity = _dodge_dir * float(DB.bal("player_speed", 4.5)) * float(DB.bal("dodge_speed", 3.2))
		_visual.rotation.x = -0.5 * sin(PI * dodging / float(DB.bal("dodge_time", 0.32)))
	else:
		_visual.rotation.x = 0.0
	move_and_slide()
	position.y = floor_y
	if dir.length() > 0.1:
		_face(Vector3(dir.x, 0.0, dir.y))

	# Animación de andar y correr: el paso avanza según la velocidad real (sin patinar)
	var hspeed := Vector2(_vel.x, _vel.z).length()
	var moving := hspeed > 0.25
	_walk_amount = move_toward(_walk_amount, clampf(hspeed / 2.0, 0.0, 1.0) if moving else 0.0, delta * 5.0)
	_run_amount = move_toward(_run_amount, 1.0 if running and moving else 0.0, delta * 4.0)
	if moving and floori(_walk_phase / PI) != floori(_step_phase / PI) and not crouching:
		SFX.play("paso", -14.0 if not running else -9.0, 0.15)
	_step_phase = _walk_phase
	if moving:
		# zancada de ~1,3 m andando y ~1,8 m corriendo por medio ciclo
		_walk_phase += delta * hspeed / lerpf(1.3, 1.8, _run_amount) * PI
	_visual.animate_walk(_walk_phase, _walk_amount, _run_amount)
	_crouch_amount = move_toward(_crouch_amount, 1.0 if crouching else 0.0, delta * 6.0)
	_visual.animate_crouch(_crouch_amount)
	_idle_t += delta
	_visual.animate_idle(_idle_t, (1.0 - _walk_amount) * (1.0 - _crouch_amount))
	if training > 0.0:
		_visual.animate_swing(fmod(training, 0.75) / 0.75)
	if _swing_t >= 0.0:
		_swing_t += delta / 0.45   # lo que dura el gesto del golpe (solo visual)
		if _swing_t >= 1.0:
			_swing_t = -1.0
		else:
			_visual.animate_swing(_swing_t)

	_action_cd = maxf(_action_cd - delta, 0.0)
	var acting := action_held or Input.is_key_pressed(KEY_SPACE)
	if acting and target != null and is_instance_valid(target) and _action_cd <= 0.0:
		_face(target.global_position - global_position)
		var w := get_tree().get_first_node_in_group("world")
		if GS.hand_throws() and target.is_in_group("creature") and w != null:
			w.throw_at(target)   # molotov: se lanza, no se golpea
		else:
			target.interact(self)
		if target.is_in_group("resource") or target.is_in_group("creature"):
			GS.exercise("fuerza", float(DB.bal("fitness_hit_gain", 0.0006)))
			make_noise(float(DB.bal("noise_hit", 9.0)) * (0.6 if crouching else 1.0))
		_swing()
		_action_cd = float(DB.bal("action_interval", 0.6))


## Correr: joystick a fondo (o Shift). Gasta aguante; la resistencia lo alarga
## y correr con la mochila cargada es lo que más la entrena.
func _update_stamina(dir: Vector2, delta: float) -> void:
	# Para empezar a correr hay que llevar el joystick casi a fondo; para dejar de correr,
	# soltarlo algo más (así no salta entre andar y correr con el dedo en el límite)
	var limit := float(DB.bal("run_release", 0.8)) if running else float(DB.bal("run_threshold", 0.92))
	var wants := not crouching and (dir.length() >= limit or (dir.length() > 0.1 and Input.is_key_pressed(KEY_SHIFT)))
	var mx := GS.max_stamina()
	if GS.stamina <= 0.0:
		_exhausted = true
	elif _exhausted and GS.stamina >= mx * 0.25:
		_exhausted = false
	# Con sobrecarga se puede correr (más lento y gastando mucha más energía) y andar también cansa
	var over := GS.overloaded()
	running = wants and not _exhausted
	if running:
		GS.stamina = maxf(GS.stamina - GS.stamina_drain() * delta, 0.0)
		GS.exercise("resistencia", float(DB.bal("fitness_run_gain", 0.00025)) * delta * (0.4 + minf(GS.load_ratio(), 1.0)))
		_rest = 0.0
	elif over and dir.length() > 0.1:
		var extra := minf(GS.load_ratio() - 1.0, 1.0) + 0.3
		GS.stamina = maxf(GS.stamina - float(DB.bal("overload_walk_drain", 3.0)) * extra * delta, 0.0)
		_rest = 0.0
	else:
		_rest += delta
		if _rest >= float(DB.bal("stamina_regen_delay", 0.8)):
			GS.stamina = minf(GS.stamina + float(DB.bal("stamina_regen", 18.0)) * (1.0 + float(GS.physique["resistencia"]) * 0.5) * delta, mx)


## Esquivar: un salto rápido hacia donde te mueves (o hacia donde miras) durante
## el que no recibes golpes. Gasta energía.
func dodge() -> bool:
	var cost := float(DB.bal("dodge_cost", 22))
	if GS.dead or dodging > 0.0 or _dodge_cd > 0.0 or training > 0.0:
		return false
	if GS.stamina < cost:
		GS.message.emit("Sin energía para esquivar")
		SFX.play("error", -6.0)
		return false
	GS.stamina -= cost
	_rest = 0.0
	var d := Vector3(move_input.x, 0.0, move_input.y)
	_dodge_dir = d.normalized() if d.length() > 0.2 else facing()
	dodging = float(DB.bal("dodge_time", 0.32))
	_dodge_cd = float(DB.bal("dodge_cooldown", 0.9))
	GS.invulnerable = dodging + 0.08
	set_crouch(false)
	make_noise(float(DB.bal("noise_walk", 7.0)))
	SFX.play("esquivar")
	return true


## Empujón (m/s) que se apaga en un instante.
func push(v: Vector3) -> void:
	_push = v


# ------------------------------------------------------------ sigilo

func set_crouch(on: bool) -> void:
	crouching = on
	if on:
		running = false


## Radio (m) en el que las criaturas oyen al superviviente.
func noise_radius() -> float:
	var moving := velocity.length() > 0.3
	var r: float
	if crouching:
		r = float(DB.bal("noise_crouch_move", 2.5)) if moving else float(DB.bal("noise_crouch", 1.5))
	elif running:
		r = float(DB.bal("noise_run", 13.0))
	elif moving:
		r = float(DB.bal("noise_walk", 7.0))
	else:
		r = float(DB.bal("noise_idle", 3.0))
	return maxf(r, _noise_pulse)


func make_noise(radius: float) -> void:
	_noise_pulse = maxf(_noise_pulse, radius)


## Cuánto ven las criaturas: agachado y con lluvia se te ve menos.
func sight_factor() -> float:
	var f := 1.0
	if crouching:
		f *= float(DB.bal("crouch_sight", 0.45))
	if GS.raining():
		f *= float(DB.bal("rain_sight", 0.75))
	return f


## Animación de entrenar en el gimnasio.
func start_training(seconds: float) -> void:
	training = seconds


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


## Qué usa el botón de acción ahora mismo:
## {"icon": id de objeto o icono de interfaz, "item": objeto (para su estado) o null}.
## Junto a un pino o una roca, el hacha o el pico del inventario (si no lo llevas, su icono
## en gris: sin herramienta no se puede); con un cofre o una estación, la mano; si no, el
## arma equipada o el puño.
func action_info() -> Dictionary:
	var t := target
	if t != null and is_instance_valid(t) and t.is_in_group("resource"):
		var need := str(t.data.get("tool", ""))
		if need != "":
			var i := GS.best_tool(need)
			if i >= 0:
				return {"icon": str(GS.slots[i]["id"]), "item": GS.slots[i], "ui": false}
			return {"icon": "hacha_piedra" if need == "axe" else "pico_piedra", "item": null, "ui": false, "missing": true}
		return {"icon": "mano", "item": null, "ui": true}
	elif t != null and is_instance_valid(t) and not t.is_in_group("creature"):
		return {"icon": "mano", "item": null, "ui": true}
	if GS.hand != null:
		return {"icon": str(GS.hand["id"]), "item": GS.hand, "ui": false}
	return {"icon": "puno", "item": null, "ui": true}


func _refresh_hand() -> void:
	var info := action_info()
	var id := str(info["icon"])
	if info["ui"]:   # sin herramienta que usar: se ve el arma equipada (o nada)
		id = "" if GS.hand == null else str(GS.hand["id"])
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
	shake = 0.25
	SFX.vibrate(60)
	SFX.play("dano")
	var tw := create_tween()
	_visual.scale = Vector3(1.15, 0.85, 1.15)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.2)
