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
var running := false
var crouching := false            # agachado: lento, silencioso y con golpe crítico por sorpresa
var shake := 0.0                  # sacudida de cámara al recibir un golpe (la lee el mundo)
var _crouch_amount := 0.0
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
	_noise_pulse = maxf(_noise_pulse - delta * 9.0, 0.0)
	shake = maxf(shake - delta, 0.0)
	var speed := float(DB.bal("player_speed", 4.5)) * GS.speed_factor()
	if running:
		speed *= float(DB.bal("run_mult", 1.5))
	if crouching:
		speed *= float(DB.bal("crouch_speed", 0.55))
	velocity = Vector3(dir.x, 0.0, dir.y) * speed
	move_and_slide()
	position.y = floor_y
	if dir.length() > 0.1:
		_face(Vector3(dir.x, 0.0, dir.y))

	# Animación de andar y golpe
	var moving := dir.length() > 0.1
	_walk_amount = move_toward(_walk_amount, 1.0 if moving else 0.0, delta * 6.0)
	if moving:
		_walk_phase += delta * 9.0 * dir.length() * (1.35 if running else 1.0)
	_visual.animate_walk(_walk_phase, _walk_amount)
	_crouch_amount = move_toward(_crouch_amount, 1.0 if crouching else 0.0, delta * 6.0)
	_visual.animate_crouch(_crouch_amount)
	if training > 0.0:
		_visual.animate_swing(fmod(training, 0.75) / 0.75)
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
		if target.is_in_group("resource") or target.is_in_group("creature"):
			GS.exercise("fuerza", float(DB.bal("fitness_hit_gain", 0.0006)))
			make_noise(float(DB.bal("noise_hit", 9.0)) * (0.6 if crouching else 1.0))
		_swing()
		_action_cd = float(DB.bal("action_interval", 0.6))


## Correr: joystick a fondo (o Shift). Gasta aguante; la resistencia lo alarga
## y correr con la mochila cargada es lo que más la entrena.
func _update_stamina(dir: Vector2, delta: float) -> void:
	var wants := not crouching and (dir.length() >= float(DB.bal("run_threshold", 0.85)) or (dir.length() > 0.1 and Input.is_key_pressed(KEY_SHIFT)))
	var mx := GS.max_stamina()
	if GS.stamina <= 0.0:
		_exhausted = true
	elif _exhausted and GS.stamina >= mx * 0.25:
		_exhausted = false
	running = wants and not _exhausted
	if running:
		GS.stamina = maxf(GS.stamina - GS.stamina_drain() * delta, 0.0)
		GS.exercise("resistencia", float(DB.bal("fitness_run_gain", 0.00025)) * delta * (0.4 + GS.load_ratio()))
		_rest = 0.0
	else:
		_rest += delta
		if _rest >= float(DB.bal("stamina_regen_delay", 0.8)):
			GS.stamina = minf(GS.stamina + float(DB.bal("stamina_regen", 18.0)) * (1.0 + float(GS.physique["resistencia"]) * 0.5) * delta, mx)


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
	shake = 0.25
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(60)
	var tw := create_tween()
	_visual.scale = Vector3(1.15, 0.85, 1.15)
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.2)
