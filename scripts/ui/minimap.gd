extends Control
## Minimapa redondo (diseño docs/diseno_minimapa.jpg): vista cenital del mundo real con
## norte arriba, aro oscuro, rosa de los vientos, escala, la flecha del jugador e iconos de
## infectados (rojo), animales (marrón) y cajas. Los iconos salen recortados del diseño.

const RADIUS_M := 12.0          # metros del centro al borde
const TILT := 0.42              # inclinación de la cámara (rad): árboles y rocas se ven en 3D
const SIZE := 190.0             # diámetro en píxeles (lienzo 1280x720)
const EXTRA := 64.0             # sitio a la izquierda para el arco con tiempo, temperatura y hora
const TEX := 256                # resolución de la vista
const UPDATE_EVERY := 3         # se repinta 1 de cada 3 fotogramas (ahorra batería)
const VIEW_LAYER := 1           # capa que ve la cámara: sin criaturas ni jugador (van como iconos)
const HIDE_LAYER := 1 << 1

var world: Node3D
var _vp: SubViewport
var _cam: Camera3D
var _frame := 0
var _icons := {}
var _font: Font


func _init() -> void:
	custom_minimum_size = Vector2(SIZE + EXTRA, SIZE)
	size = Vector2(SIZE + EXTRA, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["infectado", "zorro", "ciervo", "caja", "jugador", "norte"]:
		_icons[k] = load("res://assets/icons/minimap/%s.png" % k)


func setup(w: Node3D) -> void:
	world = w
	_vp = SubViewport.new()
	_vp.size = Vector2i(TEX, TEX)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = RADIUS_M * 2.0
	_cam.far = 120.0
	_cam.cull_mask = VIEW_LAYER
	# Luz propia: sin niebla y clara también de noche, para que se lea bien
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("40542f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.72)
	env.ambient_light_energy = 0.6
	_cam.environment = env
	_vp.add_child(_cam)
	_font = get_theme_default_font()


func _process(_delta: float) -> void:
	if world == null or not is_instance_valid(world) or world.player == null:
		return
	_frame += 1
	if _frame % UPDATE_EVERY != 0:
		return
	var p: Vector3 = world.player.global_position
	_cam.global_position = p + Vector3(0.0, cos(TILT), sin(TILT)) * 60.0
	_cam.look_at(p, Vector3.FORWARD)   # norte (-Z) arriba
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	# Criaturas y jugador fuera de la vista (se dibujan como iconos); se repasa a menudo
	# porque los modelos cambian (ropa, heridas, recién aparecidos)
	if _frame % (UPDATE_EVERY * 10) == 0 or _frame <= UPDATE_EVERY:
		_set_layers(world.player)
		for c in get_tree().get_nodes_in_group("creature"):
			_set_layers(c)
	queue_redraw()


func _set_layers(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = HIDE_LAYER
	for c in n.get_children():
		_set_layers(c)


## Posición en el minimapa de un punto del mundo (o null si cae fuera del círculo).
func to_map(pos: Vector3) -> Variant:
	if _cam == null or not _cam.is_inside_tree():
		return null
	var uv := _cam.unproject_position(pos) / float(TEX)   # 0..1 en la vista
	var d := (uv - Vector2(0.5, 0.5)) * 2.0 * (SIZE / 2.0 - 7.0)
	if d.length() > SIZE / 2.0 - 17.0:
		return null
	return center() + d


## Centro del círculo del mapa dentro del control.
func center() -> Vector2:
	return Vector2(EXTRA + SIZE / 2.0, SIZE / 2.0)


func _icon_for(c: Node3D) -> String:
	if Infected.KINDS.has(str(c.kind)):
		return "infectado"
	if str(c.data.get("behavior", "")) == "passive":
		return "ciervo"
	return "zorro"


func _draw() -> void:
	var c := center()
	var r := SIZE / 2.0
	var inner := r - 7.0
	# Vista recortada en círculo
	if _vp:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 48:
			var a := TAU * float(i) / 48.0
			var v := Vector2(cos(a), sin(a))
			pts.append(c + v * inner)
			uvs.append(Vector2(0.5, 0.5) + v * 0.5)
		draw_colored_polygon(pts, Color.WHITE, uvs, _vp.get_texture())
	# Rosa de los vientos tenue
	var faint := Color(0.95, 0.92, 0.7, 0.13)
	draw_arc(c, inner * 0.5, 0.0, TAU, 48, faint, 2.0, true)
	draw_arc(c, inner * 0.82, 0.0, TAU, 48, faint, 1.5, true)
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI / 8.0
		draw_line(c, c + Vector2(cos(a), sin(a)) * inner, faint, 1.5, true)
	for i in 4:
		var a := TAU * float(i) / 4.0
		var tip := c + Vector2(cos(a), sin(a)) * inner * 0.62
		var side := Vector2(-sin(a), cos(a)) * 9.0
		draw_colored_polygon(PackedVector2Array([c + side, tip, c - side]), Color(0.95, 0.92, 0.7, 0.07))
	# Cajas, animales e infectados
	if world and is_instance_valid(world) and world.player:
		for b in get_tree().get_nodes_in_group("container"):
			if b.has_method("is_chest") and b.is_chest():
				continue
			var m: Variant = to_map(b.global_position)
			if m != null:
				_icon("caja", m, 20.0)
		for cr in get_tree().get_nodes_in_group("creature"):
			if cr.hp <= 0.0 or not cr.visible:
				continue
			if cr.get("_visual") and not cr._visual.visible:
				continue   # acechador escondido de noche
			var m: Variant = to_map(cr.global_position)
			if m != null:
				_icon(_icon_for(cr), m, 22.0)
		# Jugador: flecha que gira con él
		var f: Vector3 = world.player.facing()
		var ang := atan2(f.x, -f.z)
		draw_set_transform(c, ang, Vector2.ONE)
		_icon("jugador", Vector2.ZERO, 26.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Aro
	draw_arc(c, r - 3.5, 0.0, TAU, 64, Color("2b2b29"), 6.0, true)
	draw_arc(c, r - 0.5, 0.0, TAU, 64, Color("121211"), 1.5, true)
	draw_arc(c, inner, 0.0, TAU, 64, Color("161614"), 1.5, true)
	# Norte
	_icon("norte", Vector2(c.x, 26.0), 28.0)
	_draw_weather_arc(c, r)
	# Escala: 10 m
	var px := 5.0 / RADIUS_M * inner
	var y := SIZE - 22.0
	var x0 := c.x - px / 2.0
	var col := Color("e6d9a8")
	draw_line(Vector2(x0, y), Vector2(x0 + px, y), col, 2.0)
	draw_line(Vector2(x0, y - 4), Vector2(x0, y), col, 2.0)
	draw_line(Vector2(x0 + px, y - 4), Vector2(x0 + px, y), col, 2.0)
	if _font:
		var t := "5 m"
		var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string_outline(_font, Vector2(c.x - w / 2.0, y - 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.7))
		draw_string(_font, Vector2(c.x - w / 2.0, y - 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


## Arco pegado al lado izquierdo del aro: tiempo (sol, luna o lluvia), temperatura y hora.
func _draw_weather_arc(c: Vector2, r: float) -> void:
	var w := 40.0
	var rad := r + w / 2.0 + 1.0
	var span := 0.78
	# Banda del mismo color que el aro, con los extremos cortados en bisel
	var band := Color("2b2b29")
	var pts := PackedVector2Array()
	var n := 32
	for i in n + 1:
		var a := PI - span + 2.0 * span * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * (r - 1.0))
	for i in n + 1:
		var a := PI + span - 0.12 - 2.0 * (span - 0.12) * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * (r + w))
	draw_colored_polygon(pts, band)
	var edge := PackedVector2Array()
	for i in n + 1:
		var a := PI + span - 0.12 - 2.0 * (span - 0.12) * float(i) / float(n)
		edge.append(c + Vector2(cos(a), sin(a)) * (r + w))
	draw_polyline(edge, Color("121211"), 1.5, true)
	var col := Color("f3ead2")
	# Tiempo
	var weather := "lluvia" if GS.raining() else ("luna" if GS.is_night() else "sol")
	var tex: Texture2D = DB.ui_icon(weather)
	var pw := c + Vector2(cos(PI + 0.52), sin(PI + 0.52)) * rad
	if tex:
		draw_texture_rect(tex, Rect2(pw - Vector2(15, 15), Vector2(30, 30)), false)
	# Temperatura (con un termómetro pequeño)
	var pt := c + Vector2(-rad, 0.0)
	var temp := GS.temperature()
	var tcol := Color("7fc4e8") if temp <= 8 else (Color("f0a050") if temp >= 24 else col)
	_text_centered("%d°" % temp, pt + Vector2(4, 7), 19, tcol)
	draw_line(pt + Vector2(-15, -9), pt + Vector2(-15, 5), Color(0.9, 0.9, 0.9, 0.8), 3.0)
	draw_circle(pt + Vector2(-15, 7), 3.5, tcol)
	# Hora
	var ph := c + Vector2(cos(PI - 0.52), sin(PI - 0.52)) * rad
	_text_centered(GS.clock_text(), ph + Vector2(0, 6), 16, col)


func _text_centered(t: String, at: Vector2, fs: int, col: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(_font, Vector2(at.x - w / 2.0, at.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.75))
	draw_string(_font, Vector2(at.x - w / 2.0, at.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _icon(id: String, at: Vector2, s: float) -> void:
	var tex: Texture2D = _icons.get(id)
	if tex:
		draw_texture_rect(tex, Rect2(at - Vector2(s, s) / 2.0, Vector2(s, s)), false)
