extends Node
## Sonido: efectos, ambiente (viento, grillos, lluvia) y música. También guarda
## todos los ajustes del jugador (sonido, gráficos, cuenta…) en user://settings.json.

const PATH := "res://assets/audio/%s.wav"
const LOOPS := ["viento", "grillos", "lluvia", "musica"]

const DEFAULTS := {
	"master": 1.0, "music": 0.6, "sfx": 0.8, "ambience": 0.7, "mute": false, "vibration": true,
	"language": "es", "notifications": true,
	"quality": "medio", "shadows": true, "fps": 60, "render_scale": 1.0, "brightness": 1.0,
	"damage_numbers": true, "show_fps": false, "minimap": true,
	"player_id": "", "last_access": 0.0,
}
var settings := DEFAULTS.duplicate()
var previous_access := 0.0     # último acceso anterior a esta sesión (unix)
var settings_path := "user://settings.json"
var played: Array = []          # últimos efectos (para los tests)
var _streams: Dictionary = {}
var _pool: Array = []
var _next := 0
var _loops: Dictionary = {}
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Musica", "Efectos", "Ambiente"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	load_settings()
	# Último acceso (el ID de jugador lo crea load_settings)
	previous_access = float(settings.get("last_access", 0.0))
	settings["last_access"] = Time.get_unix_time_from_system()
	save_settings()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Efectos"
		add_child(p)
		_pool.append(p)
	for id in LOOPS:
		var st := _stream(id)
		if st == null:
			continue
		var lp: AudioStreamWAV = st.duplicate()
		lp.loop_mode = AudioStreamWAV.LOOP_FORWARD
		lp.loop_end = int(lp.get_length() * lp.mix_rate)
		var p := AudioStreamPlayer.new()
		p.stream = lp
		p.bus = "Musica" if id == "musica" else "Ambiente"
		p.volume_db = -60.0
		add_child(p)
		_loops[id] = p
	# Todos los botones hacen clic
	get_tree().node_added.connect(func(n: Node):
		if n is Button:
			n.pressed.connect(func(): play("clic", -8.0)))
	GS.message.connect(func(text: String):
		if text.begins_with("¡Se rompió"):
			play("romper")
		elif text.begins_with("Faltan") or text.ends_with("lleno"):
			play("error", -6.0))
	GS.died.connect(func(): play("muerte"))
	apply()


func _stream(id: String) -> AudioStream:
	if not _streams.has(id):
		var path := PATH % id
		_streams[id] = load(path) if ResourceLoader.exists(path) else null
	return _streams[id]


## Reproduce un efecto. pitch_var: variación aleatoria del tono.
func play(id: String, db := 0.0, pitch_var := 0.08) -> void:
	played.append(id)
	if played.size() > 40:
		played.pop_front()
	var st := _stream(id)
	if st == null or _pool.is_empty():
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func vibrate(ms: int) -> void:
	if bool(settings["vibration"]) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## Ambiente según la hora y el tiempo.
func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var day := GS.daylight()
	var rain := GS.raining()
	_fade("viento", -22.0 if day > 0.5 else -30.0)
	_fade("grillos", -60.0 if day > 0.5 or rain else -20.0)
	_fade("lluvia", -12.0 if rain else -60.0)
	_fade("musica", -16.0)


func _fade(id: String, db: float) -> void:
	if not _loops.has(id):
		return
	var p: AudioStreamPlayer = _loops[id]
	p.volume_db = move_toward(p.volume_db, db, 6.0)
	if p.volume_db > -55.0 and not p.playing:
		p.play()
	elif p.volume_db <= -55.0 and p.playing:
		p.stop()


# ------------------------------------------------------------- ajustes

func apply() -> void:
	for d in [["Master", "master"], ["Musica", "music"], ["Efectos", "sfx"], ["Ambiente", "ambience"]]:
		var i := AudioServer.get_bus_index(d[0])
		if i < 0:
			continue
		var v := clampf(float(settings[d[1]]), 0.0, 1.0)
		var off: bool = v <= 0.01 or (d[0] == "Master" and bool(settings["mute"]))
		AudioServer.set_bus_mute(i, off)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.01)))


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply()
	save_settings()


func save_settings() -> void:
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		for k in DEFAULTS:
			if not settings.has(k):
				settings[k] = DEFAULTS[k]
		if str(settings.get("player_id", "")) == "":
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			settings["player_id"] = "SUPERVIVIENTE#%06d" % rng.randi_range(0, 999999)
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
	if d is Dictionary:
		for k in settings:
			if d.has(k):
				settings[k] = d[k]
	for k in DEFAULTS:
		if not settings.has(k):
			settings[k] = DEFAULTS[k]
	# ID de jugador: se crea una vez y se guarda
	if str(settings.get("player_id", "")) == "":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		settings["player_id"] = "SUPERVIVIENTE#%06d" % rng.randi_range(0, 999999)
		save_settings()
