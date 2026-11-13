extends CanvasLayer
## Pantalla de creación del superviviente (primer arranque).
## Izquierda: categorías. Centro: el personaje en 3D (se gira deslizando).
## Derecha: hombre/mujer, las 5 opciones de la categoría, nombre y «Empezar».
## Al terminar guarda el aspecto en GS.look y emite "finished".

signal finished

const GOLD := Color("e8b84a")
const INK := Color("2b2418")
const TXT := Color("f1ead6")
const MUT := Color("c9c1a8")
const PANEL := Color(0.055, 0.07, 0.047, 0.86)

# id, nombre, clave en GS.look, encuadre de cámara
const CATS := [
	["piel", "Piel", "skin", "body"],
	["pelo", "Pelo", "hair", "bust"],
	["color_pelo", "Color de pelo", "hair_color", "bust"],
	["ojos", "Ojos", "eyes", "face"],
	["color_ojos", "Color de ojos", "eye_color", "face"],
	["nariz", "Nariz", "nose", "face"],
	["boca", "Boca", "mouth", "face"],
]

var look: Dictionary = {}
var cat := "pelo"
var model: CharacterModel
var name_edit: LineEdit
var start_button: Button
var _cat_buttons: Dictionary = {}
var _tiles: GridContainer
var _cat_title: Label
var _sel_title: Label
var _sex_buttons: Dictionary = {}
var _pivot: Node3D
var _cam: Camera3D
var _drag := false
var _cam_tween: Tween
var _thumbs: Array = []       # 5 × {"vp": SubViewport, "pivot": Node3D, "cam": Camera3D}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	look = GS.look.duplicate()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font_size = 22
	root.theme = th
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("161c13")
	root.add_child(bg)

	var title := Label.new()
	title.text = "Crea a tu superviviente"
	title.position = Vector2(28, 14)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("e9dcb8"))
	root.add_child(title)
	var sub := Label.new()
	sub.text = "Empiezas en ropa interior: la ropa se encuentra o se cose en tu refugio."
	sub.position = Vector2(30, 62)
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", MUT)
	root.add_child(sub)

	# --- categorías
	var cats := VBoxContainer.new()
	cats.position = Vector2(24, 100)
	cats.custom_minimum_size = Vector2(240, 0)
	cats.add_theme_constant_override("separation", 8)
	root.add_child(cats)
	for c in CATS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(240, 60)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 19)
		var id: String = c[0]
		b.pressed.connect(func(): select_cat(id))
		cats.add_child(b)
		_cat_buttons[id] = b
	var tip := Label.new()
	tip.text = "El físico cambia jugando: correr con\ncarga, golpear y el gimnasio."
	tip.add_theme_font_size_override("font_size", 15)
	tip.add_theme_color_override("font_color", MUT)
	cats.add_child(tip)

	# --- personaje en 3D
	var svc := SubViewportContainer.new()
	svc.position = Vector2(290, 80)
	svc.size = Vector2(520, 600)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_on_view_input)
	root.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8c0b0")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 150, 0)
	sun.light_energy = 1.25
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -30, 0)
	rim.light_energy = 0.45
	rim.light_color = Color("ffd9a0")
	vp.add_child(rim)
	_pivot = Node3D.new()
	_pivot.rotation.y = 0.35
	vp.add_child(_pivot)
	var floor_mesh := MeshInstance3D.new()   # tierra bajo los pies
	var disc := CylinderMesh.new()
	disc.top_radius = 0.75
	disc.bottom_radius = 0.8
	disc.height = 0.04
	disc.radial_segments = 9
	floor_mesh.mesh = disc
	floor_mesh.material_override = CharacterModel.mat(Color("4b3720"))
	floor_mesh.position.y = -0.02
	vp.add_child(floor_mesh)
	_cam = Camera3D.new()
	_cam.fov = 32
	vp.add_child(_cam)
	_rebuild_model()
	_frame(_cat_frame(), true)

	var turn := HBoxContainer.new()
	turn.position = Vector2(400, 668)
	turn.add_theme_constant_override("separation", 14)
	root.add_child(turn)
	for d in [[-1, "<"], [1, ">"]]:
		var tb := Button.new()
		tb.text = d[1]
		tb.custom_minimum_size = Vector2(56, 44)
		var dirv: int = d[0]
		tb.pressed.connect(func(): _pivot.rotation.y += dirv * 0.6)
		turn.add_child(tb)
		if d[0] == -1:
			var hint := Label.new()
			hint.text = "Desliza para girar"
			hint.add_theme_font_size_override("font_size", 16)
			hint.add_theme_color_override("font_color", MUT)
			hint.custom_minimum_size = Vector2(170, 44)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			turn.add_child(hint)

	# --- hombre / mujer
	var sex := HBoxContainer.new()
	sex.position = Vector2(836, 22)
	sex.add_theme_constant_override("separation", 0)
	root.add_child(sex)
	for d in [["m", "Hombre"], ["f", "Mujer"]]:
		var sb := Button.new()
		sb.text = d[1]
		sb.custom_minimum_size = Vector2(210, 56)
		sb.add_theme_font_size_override("font_size", 23)
		var sx: String = d[0]
		sb.pressed.connect(func(): set_sex(sx))
		sex.add_child(sb)
		_sex_buttons[sx] = sb

	# --- opciones de la categoría
	var panel := PanelContainer.new()
	panel.position = Vector2(836, 92)
	panel.custom_minimum_size = Vector2(420, 460)
	panel.add_theme_stylebox_override("panel", _box(PANEL, Color(0.91, 0.86, 0.72, 0.25), 14, 14))
	root.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	panel.add_child(pv)
	var head := HBoxContainer.new()
	_cat_title = Label.new()
	_cat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cat_title.add_theme_font_size_override("font_size", 28)
	_cat_title.add_theme_color_override("font_color", Color("e9dcb8"))
	head.add_child(_cat_title)
	_sel_title = Label.new()
	_sel_title.add_theme_font_size_override("font_size", 18)
	_sel_title.add_theme_color_override("font_color", GOLD)
	head.add_child(_sel_title)
	pv.add_child(head)
	for i in 5:
		_thumbs.append(_make_thumb())
	_update_thumbs()
	_tiles = GridContainer.new()
	_tiles.columns = 3
	_tiles.add_theme_constant_override("h_separation", 10)
	_tiles.add_theme_constant_override("v_separation", 10)
	pv.add_child(_tiles)

	# --- nombre, aleatorio y empezar
	var bottom := VBoxContainer.new()
	bottom.position = Vector2(836, 566)
	bottom.custom_minimum_size = Vector2(420, 0)
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bottom.add_child(row)
	name_edit = LineEdit.new()
	name_edit.text = GS.player_name
	name_edit.max_length = 18
	name_edit.placeholder_text = "Nombre"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(0, 50)
	row.add_child(name_edit)
	var rnd := Button.new()
	rnd.text = "Aleatorio"
	rnd.custom_minimum_size = Vector2(140, 50)
	rnd.pressed.connect(randomize_look)
	row.add_child(rnd)
	start_button = Button.new()
	start_button.text = "EMPEZAR A SOBREVIVIR"
	start_button.custom_minimum_size = Vector2(420, 62)
	start_button.add_theme_font_size_override("font_size", 25)
	start_button.add_theme_color_override("font_color", INK)
	start_button.add_theme_color_override("font_hover_color", INK)
	start_button.add_theme_color_override("font_pressed_color", INK)
	start_button.add_theme_stylebox_override("normal", _box(GOLD, GOLD, 14, 8))
	start_button.add_theme_stylebox_override("hover", _box(GOLD.lightened(0.1), GOLD, 14, 8))
	start_button.add_theme_stylebox_override("pressed", _box(GOLD.darkened(0.15), GOLD, 14, 8))
	start_button.pressed.connect(confirm)
	bottom.add_child(start_button)

	_refresh()


func _box(c: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


# ------------------------------------------------------------- acciones

func select_cat(id: String) -> void:
	cat = id
	_frame(_cat_frame())
	_update_thumbs()
	_refresh()


func set_sex(sx: String) -> void:
	if str(look["sex"]) == sx:
		return
	look["sex"] = sx
	_rebuild_model()
	_frame(_cat_frame(), true)
	_refresh()


func pick(i: int) -> void:
	look[_cat_key(cat)] = clampi(i, 0, 4)
	_rebuild_model()
	_refresh()


func randomize_look() -> void:
	for c in CATS:
		look[c[2]] = randi() % 5
	_rebuild_model()
	_refresh()


func confirm() -> void:
	for k in look:
		GS.look[k] = look[k]
	var n := name_edit.text.strip_edges()
	GS.player_name = n if n != "" else "Superviviente"
	GS.created = true
	GS.look_changed.emit()
	finished.emit()


# ---------------------------------------------------------- presentación

func _cat_key(id: String) -> String:
	for c in CATS:
		if c[0] == id:
			return c[2]
	return ""


func _names(id: String) -> Array:
	match id:
		"piel": return CharacterModel.SKIN_NAMES
		"pelo": return CharacterModel.HAIR_NAMES_M if str(look["sex"]) == "m" else CharacterModel.HAIR_NAMES_F
		"color_pelo": return CharacterModel.HAIR_COLOR_NAMES
		"ojos": return CharacterModel.EYE_NAMES
		"color_ojos": return CharacterModel.EYE_COLOR_NAMES
		"nariz": return CharacterModel.NOSE_NAMES
	return CharacterModel.MOUTH_NAMES


func _swatch(id: String, i: int) -> Variant:
	match id:
		"piel": return CharacterModel.SKINS[i]
		"color_pelo": return CharacterModel.HAIR_COLORS[i]
		"color_ojos": return CharacterModel.EYE_COLORS[i]
	return null


func _refresh() -> void:
	for c in CATS:
		var b: Button = _cat_buttons[c[0]]
		var active: bool = c[0] == cat
		b.text = "%s\n%s" % [c[1], _names(c[0])[int(look[c[2]])]]
		b.add_theme_stylebox_override("normal", _box(GOLD if active else PANEL, GOLD if active else Color(0.91, 0.86, 0.72, 0.22), 12, 8))
		b.add_theme_color_override("font_color", INK if active else TXT)
		b.add_theme_color_override("font_hover_color", INK if active else TXT)
	for sx in _sex_buttons:
		var sb: Button = _sex_buttons[sx]
		var on: bool = str(look["sex"]) == sx
		sb.add_theme_stylebox_override("normal", _box(GOLD if on else Color(0, 0, 0, 0.5), Color(0.91, 0.86, 0.72, 0.3), 12, 6))
		sb.add_theme_color_override("font_color", INK if on else TXT)
		sb.add_theme_color_override("font_hover_color", INK if on else TXT)
	var names := _names(cat)
	var sel := int(look[_cat_key(cat)])
	for c in CATS:
		if c[0] == cat:
			_cat_title.text = c[1]
	_sel_title.text = names[sel]
	for t in _tiles.get_children():
		t.queue_free()
	for i in 5:
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(124, 124)
		var on := i == sel
		tile.add_theme_stylebox_override("normal", _box(Color(0.91, 0.72, 0.29, 0.2) if on else Color(0, 0, 0, 0.35), GOLD if on else Color(0.91, 0.86, 0.72, 0.15), 14, 6))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(v)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(92, 92)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = _thumbs[i]["vp"].get_texture()
		var sw: Variant = _swatch(cat, i)
		if sw != null:   # punto de color en la esquina
			var dot := Panel.new()
			dot.size = Vector2(22, 22)
			dot.position = Vector2(68, 2)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ds := _box(sw, Color(0, 0, 0, 0.6), 11, 0)
			ds.set_border_width_all(2)
			dot.add_theme_stylebox_override("panel", ds)
			icon.add_child(dot)
		v.add_child(icon)
		var l := Label.new()
		l.text = names[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", Color("f6d27e") if on else TXT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		var idx := i
		tile.pressed.connect(func(): pick(idx))
		_tiles.add_child(tile)


func _rebuild_model() -> void:
	if model:
		model.queue_free()
	model = CharacterModel.new(look)
	_pivot.add_child(model)
	_update_thumbs()


## Miniatura 3D de una opción: un SubViewport pequeño que se pinta una vez.
func _make_thumb() -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8c0b0")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 155, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var pivot := Node3D.new()
	pivot.rotation.y = 0.45
	vp.add_child(pivot)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	return {"vp": vp, "pivot": pivot, "cam": cam}


func _update_thumbs() -> void:
	if _thumbs.is_empty():
		return
	var key := _cat_key(cat)
	var s := 1.0 if str(look["sex"]) == "m" else 0.94
	var kind := _cat_frame()
	var eye := Vector3(0.0, 1.68 * s, -0.62)
	var target := Vector3(0.0, 1.66 * s, 0.0)
	if kind == "bust":
		eye = Vector3(0.0, 1.7 * s, -0.85)
		target = Vector3(0.0, 1.66 * s, 0.0)
	elif kind == "body":
		eye = Vector3(0.0, 1.5 * s, -1.7)
		target = Vector3(0.0, 1.4 * s, 0.0)
	for i in 5:
		var t: Dictionary = _thumbs[i]
		for c in t["pivot"].get_children():
			c.queue_free()
		var l := look.duplicate()
		l[key] = i
		t["pivot"].add_child(CharacterModel.new(l))
		(t["pivot"] as Node3D).rotation.y = 0.15 if kind == "face" else 0.45
		(t["cam"] as Camera3D).transform = Transform3D(Basis(), eye).looking_at(target, Vector3.UP)
		(t["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE


## Encuadre de la cámara según la categoría: cuerpo, busto o cara.
func _cat_frame() -> String:
	for c in CATS:
		if c[0] == cat:
			return c[3]
	return "body"


func _frame(kind: String, instant := false) -> void:
	var s := 1.0 if str(look["sex"]) == "m" else 0.94
	var eye: Vector3
	var target: Vector3
	match kind:
		"face":
			eye = Vector3(0.0, 1.7 * s, -1.15)
			target = Vector3(0.0, 1.61 * s, 0.0)
		"bust":
			eye = Vector3(0.0, 1.62 * s, -2.3)
			target = Vector3(0.0, 1.45 * s, 0.0)
		_:
			eye = Vector3(0.0, 1.05, -4.1)
			target = Vector3(0.0, 0.9 * s, 0.0)
	var xf := Transform3D(Basis(), eye).looking_at(target, Vector3.UP)
	if _cam_tween:
		_cam_tween.kill()
	if instant or not is_inside_tree():
		_cam.transform = xf
		return
	_cam_tween = create_tween()
	_cam_tween.tween_property(_cam, "transform", xf, 0.35).set_trans(Tween.TRANS_SINE)


func _on_view_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventMouseButton:
		_drag = ev.pressed
	elif _drag and (ev is InputEventScreenDrag or ev is InputEventMouseMotion):
		_pivot.rotation.y += ev.relative.x * 0.012
