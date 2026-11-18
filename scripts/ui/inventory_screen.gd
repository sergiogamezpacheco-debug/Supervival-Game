extends Control
## Pantalla de Inventario (diseño A): el superviviente de frente en 3D con sus
## 7 huecos de equipo a los lados y, a la derecha, 4 filas de 8 casillas: los
## bolsillos (siempre) y una fila más por cada nivel de mochila. Abajo, la ficha
## del objeto elegido con sus acciones.

const GOLD := Color("e8b84a")
const INK := Color("2b2418")
const TXT := Color("f1ead6")
const MUT := Color("c9c1a8")
const PAPER := Color("e9dcb8")

# hueco, nombre, posición dentro del panel izquierdo
const EQ_LAYOUT := [
	["cabeza", "Cabeza", Vector2(22, 40)], ["torso", "Torso", Vector2(22, 150)],
	["piernas", "Piernas", Vector2(22, 290)], ["pies", "Pies", Vector2(22, 410)],
	["espalda", "Mochila", Vector2(364, 40)], ["arma", "Mano", Vector2(364, 190)],
	["manos", "Manos", Vector2(364, 310)],
]
const TIERS := [
	["Bolsillos", "8 huecos", "siempre", ""],
	["Mochila de lona", "+8 huecos", "mesa de costura nv 1", "mochila"],
	["Mochila de excursión", "+8 huecos", "mesa de costura nv 2", "mochila_excursion"],
	["Mochila táctica", "+8 huecos", "mesa de costura nv 3", "mochila_tactica"],
]

var sel_kind := "inv"        # "inv" casilla, "eq" hueco de equipo
var sel_index := 0
var sel_slot := ""
var tiles: Array = []        # 32 botones de casilla
var eq_buttons: Dictionary = {}
var action_buttons: Array = []

var _chip: Label
var _tier_heads: Array = []
var _pivot: Node3D
var _model: CharacterModel
var _drag := false
var _stats: Dictionary = {}
var _d_icon: TextureRect
var _d_name: Label
var _d_qty: Label
var _d_desc: Label
var _d_weight: Label
var load_label: Label
var _load_bar: ProgressBar
var _d_stats: Label
var _d_actions: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Fondo opaco y, encima, el degradado detrás del personaje (el de la propuesta B)
	var base_bg := ColorRect.new()
	base_bg.color = Color("0b0e09")
	base_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base_bg)
	var bg := TextureRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color("38472c"), Color("192014"), Color("0b0e09")])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 256
	gt.height = 144
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.2, 0.58)
	gt.fill_to = Vector2(0.62, 0.58)
	bg.texture = gt
	add_child(bg)

	# Cabecera
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = DB.item_icon("mochila")
	icon.position = Vector2(28, 14)
	icon.size = Vector2(50, 50)
	add_child(icon)
	var title := Label.new()
	title.text = "Inventario"
	title.position = Vector2(88, 12)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", PAPER)
	add_child(title)
	_chip = Label.new()
	_chip.position = Vector2(308, 24)
	_chip.add_theme_font_size_override("font_size", 19)
	_chip.add_theme_color_override("font_color", INK)
	_chip.add_theme_stylebox_override("normal", _box(GOLD, GOLD, 14, 12, 3))
	add_child(_chip)
	var close := Button.new()
	close.text = "X"
	close.position = Vector2(1204, 14)
	close.size = Vector2(56, 52)
	close.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.5), Color(0.91, 0.86, 0.72, 0.3), 14, 6))
	close.pressed.connect(func(): visible = false)
	add_child(close)

	_build_left()
	_build_right()
	visibility_changed.connect(func():
		if visible:
			_rebuild_model()
			refresh())
	GS.look_changed.connect(func():
		if visible:
			_rebuild_model())


func _box(c: Color, border: Color, radius: int, margin: int, vmargin := -1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin if vmargin < 0 else vmargin
	sb.content_margin_bottom = margin if vmargin < 0 else vmargin
	return sb


# ------------------------------------------------------------ equipo

func _build_left() -> void:
	var left := Panel.new()
	left.position = Vector2(24, 84)
	left.size = Vector2(470, 612)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0.91, 0.86, 0.72, 0.14), 16, 0))
	add_child(left)
	var lbl := Label.new()
	lbl.text = "EQUIPO"
	lbl.position = Vector2(18, 8)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", MUT)
	left.add_child(lbl)

	# Superviviente en 3D (se gira deslizando)
	var svc := SubViewportContainer.new()
	svc.position = Vector2(118, 26)
	svc.size = Vector2(234, 500)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_on_view_input)
	left.add_child(svc)
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
	sun.rotation_degrees = Vector3(-35, 160, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, -30, 0)
	rim.light_energy = 0.4
	rim.light_color = Color("ffd9a0")
	vp.add_child(rim)
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.01
	disc.radial_segments = 16
	floor_mesh.mesh = disc
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0, 0, 0, 0.45)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material_override = fm
	vp.add_child(floor_mesh)
	_pivot = Node3D.new()
	_pivot.rotation.y = 0.18
	vp.add_child(_pivot)
	var cam := Camera3D.new()
	cam.fov = 26
	vp.add_child(cam)
	cam.transform = Transform3D(Basis(), Vector3(0, 1.0, -4.5)).looking_at(Vector3(0, 0.92, 0), Vector3.UP)

	for e in EQ_LAYOUT:
		var slot: String = e[0]
		var b := _make_tile(80, 58)
		b.position = e[2]
		b.pressed.connect(func(): select_eq(slot))
		left.add_child(b)
		eq_buttons[slot] = b
		var name_l := Label.new()
		name_l.text = e[1]
		name_l.position = e[2] + Vector2(0, 82)
		name_l.size = Vector2(80, 20)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_font_size_override("font_size", 15)
		name_l.add_theme_color_override("font_color", MUT)
		left.add_child(name_l)

	var stats := HBoxContainer.new()
	stats.position = Vector2(16, 536)
	stats.size = Vector2(438, 62)
	stats.add_theme_constant_override("separation", 8)
	left.add_child(stats)
	for d in [["defensa", "DEFENSA", Color("8fc6e8")], ["fuerza", "FUERZA", Color("e89a5a")], ["resistencia", "RESISTENCIA", Color("b5c43a")]]:
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 10, 4))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -4)
		p.add_child(v)
		var val := Label.new()
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override("font_size", 24)
		val.add_theme_color_override("font_color", d[2])
		v.add_child(val)
		var cap := Label.new()
		cap.text = d[1]
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_size_override("font_size", 14)
		cap.add_theme_color_override("font_color", MUT)
		v.add_child(cap)
		stats.add_child(p)
		_stats[d[0]] = val


func _rebuild_model() -> void:
	if _model:
		_model.queue_free()
	_model = CharacterModel.new(GS.look, GS.physique, GS.outfit)
	_pivot.add_child(_model)


func _on_view_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventMouseButton:
		_drag = ev.pressed
	elif _drag and (ev is InputEventScreenDrag or ev is InputEventMouseMotion):
		_pivot.rotation.y += ev.relative.x * 0.012


# ------------------------------------------------------------ casillas

func _build_right() -> void:
	var right := PanelContainer.new()
	right.position = Vector2(512, 84)
	right.size = Vector2(744, 612)
	right.add_theme_stylebox_override("panel", _box(Color(0.055, 0.07, 0.047, 0.86), Color(0.91, 0.86, 0.72, 0.22), 16, 18, 12))
	add_child(right)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	right.add_child(v)
	for t in TIERS.size():
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		var parts: Array = []
		for k in 3:
			var l := Label.new()
			l.add_theme_font_size_override("font_size", 18 if k == 0 else 16)
			l.add_theme_color_override("font_color", [PAPER, GOLD, MUT][k])
			head.add_child(l)
			parts.append(l)
		parts[0].text = TIERS[t][0]
		parts[1].text = TIERS[t][1]
		v.add_child(head)
		_tier_heads.append({"box": head, "how": parts[2]})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		for k in 8:
			var idx := t * 8 + k
			var b := _make_tile(74, 52)
			b.pressed.connect(func(): select_slot(idx))
			row.add_child(b)
			tiles.append(b)
		v.add_child(row)
		_tier_heads[t]["row"] = row
	var sep := ColorRect.new()
	sep.color = Color(0.91, 0.86, 0.72, 0.18)
	sep.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep)

	# Ficha del objeto
	var det := HBoxContainer.new()
	det.add_theme_constant_override("separation", 14)
	v.add_child(det)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(92, 92)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _box(Color(0.91, 0.72, 0.29, 0.14), Color(0.91, 0.86, 0.72, 0.25), 16, 10))
	det.add_child(frame)
	_d_icon = TextureRect.new()
	_d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_icon.custom_minimum_size = Vector2(72, 72)
	frame.add_child(_d_icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	det.add_child(info)
	var nrow := HBoxContainer.new()
	_d_name = Label.new()
	_d_name.add_theme_font_size_override("font_size", 26)
	_d_name.add_theme_color_override("font_color", TXT)
	nrow.add_child(_d_name)
	_d_qty = Label.new()
	_d_qty.add_theme_font_size_override("font_size", 20)
	_d_qty.add_theme_color_override("font_color", GOLD)
	nrow.add_child(_d_qty)
	_d_weight = Label.new()
	_d_weight.add_theme_font_size_override("font_size", 19)
	_d_weight.add_theme_color_override("font_color", MUT)
	nrow.add_child(_d_weight)
	info.add_child(nrow)
	_d_desc = Label.new()
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_d_desc.add_theme_font_size_override("font_size", 17)
	_d_desc.add_theme_color_override("font_color", MUT)
	info.add_child(_d_desc)
	_d_stats = Label.new()
	_d_stats.add_theme_font_size_override("font_size", 17)
	_d_stats.add_theme_color_override("font_color", Color("f6d27e"))
	info.add_child(_d_stats)
	# Carga total: peso que llevas / lo que aguantas
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	load_label = Label.new()
	load_label.add_theme_font_size_override("font_size", 18)
	lrow.add_child(load_label)
	_load_bar = ProgressBar.new()
	_load_bar.custom_minimum_size = Vector2(120, 10)
	_load_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_load_bar.show_percentage = false
	_load_bar.max_value = 1.0
	var lbg := StyleBoxFlat.new()
	lbg.bg_color = Color(0, 0, 0, 0.45)
	lbg.set_corner_radius_all(4)
	_load_bar.add_theme_stylebox_override("background", lbg)
	lrow.add_child(_load_bar)
	info.add_child(lrow)
	_d_actions = VBoxContainer.new()
	_d_actions.add_theme_constant_override("separation", 8)
	det.add_child(_d_actions)


## Casilla con icono, cantidad y barra de estado.
func _make_tile(size_: int, icon_: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size_, size_)
	b.size = Vector2(size_, size_)
	b.focus_mode = Control.FOCUS_NONE
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(icon_, icon_)
	ic.size = Vector2(icon_, icon_)
	ic.position = Vector2((size_ - icon_) / 2.0, (size_ - icon_) / 2.0 - 2.0)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var q := Label.new()
	q.position = Vector2(size_ - 42, size_ - 26)
	q.size = Vector2(36, 22)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	q.add_theme_font_size_override("font_size", 17)
	q.add_theme_color_override("font_color", TXT)
	q.add_theme_color_override("font_outline_color", Color.BLACK)
	q.add_theme_constant_override("outline_size", 4)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(q)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.6)
	bar_bg.position = Vector2(8, size_ - 10)
	bar_bg.size = Vector2(size_ - 16, 4)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bar_bg)
	var bar := ColorRect.new()
	bar.size = Vector2(size_ - 16, 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(bar)
	b.set_meta("icon", ic)
	b.set_meta("qty", q)
	b.set_meta("bar", bar)
	b.set_meta("w", size_ - 16)
	return b


func _set_tile(b: Button, it: Variant, selected: bool, locked: bool, empty_icon: Texture2D = null) -> void:
	var ic: TextureRect = b.get_meta("icon")
	var q: Label = b.get_meta("qty")
	var bar: ColorRect = b.get_meta("bar")
	var border := GOLD if selected else (Color(0.91, 0.86, 0.72, 0.08) if locked else Color(0.91, 0.86, 0.72, 0.2))
	var bgc := Color(0.91, 0.72, 0.29, 0.18) if selected else (Color(0, 0, 0, 0.25) if locked else Color(0, 0, 0, 0.42))
	var sb := _box(bgc, border, 12, 0)
	sb.set_border_width_all(2)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.modulate = Color(1, 1, 1, 0.55 if locked else 1.0)
	q.text = ""
	bar.get_parent().visible = false
	if locked:
		ic.texture = DB.ui_icon("candado")
		ic.modulate = Color(1, 1, 1, 0.8)
		ic.scale = Vector2(0.5, 0.5)
		ic.pivot_offset = ic.size / 2.0
		return
	ic.scale = Vector2.ONE
	if it == null:
		ic.texture = empty_icon
		ic.modulate = Color(1, 1, 1, 1)
		ic.scale = Vector2(0.7, 0.7) if empty_icon else Vector2.ONE
		ic.pivot_offset = ic.size / 2.0
		return
	var id := str(it["id"])
	ic.texture = DB.item_icon(id)
	ic.modulate = Color.WHITE
	if int(it.get("qty", 1)) > 1:
		q.text = str(int(it["qty"]))
	var mx := float(DB.item(id).get("durability", 0))
	if mx > 0.0 and it.has("dur"):
		var p := clampf(float(it["dur"]) / mx, 0.0, 1.0)
		bar.get_parent().visible = true
		bar.size.x = float(b.get_meta("w")) * p
		bar.color = Color("8fc65a") if p > 0.5 else (Color("e8b84a") if p > 0.25 else Color("d9534a"))
	if ic.texture == null:   # objeto sin icono: nombre corto
		q.text = DB.item_name(id).substr(0, 8)


# ------------------------------------------------------------ selección

func select_slot(i: int) -> void:
	sel_kind = "inv"
	sel_index = i
	refresh()


func select_eq(slot: String) -> void:
	sel_kind = "eq"
	sel_slot = slot
	refresh()


func _worn(slot: String) -> Variant:
	if slot == "arma":
		return GS.hand
	return GS.worn.get(slot)


func refresh() -> void:
	if not is_inside_tree():
		return
	var cap := GS.slots.size()
	var used := cap - GS.free_slots()
	var bag = GS.worn.get("espalda")
	_chip.text = "%s · %d/%d" % ["Sin mochila" if bag == null else DB.item_name(str(bag["id"])), used, cap]
	for t in TIERS.size():
		var open := t * 8 < cap
		var h: Dictionary = _tier_heads[t]
		(h["how"] as Label).text = ("· siempre" if t == 0 else "· equipada") if open else "· se cose en la " + str(TIERS[t][2])
		(h["box"] as Control).modulate = Color(1, 1, 1, 1.0 if open else 0.6)
	for i in tiles.size():
		var locked := i >= cap
		_set_tile(tiles[i], null if locked else GS.slots[i], sel_kind == "inv" and sel_index == i, locked)
	for e in EQ_LAYOUT:
		var slot: String = e[0]
		_set_tile(eq_buttons[slot], _worn(slot), sel_kind == "eq" and sel_slot == slot, false, DB.ui_icon("slot_" + slot))
	_stats["defensa"].text = "%d%%" % roundi(GS.armor())
	_stats["fuerza"].text = "%d%%" % roundi(float(GS.physique["fuerza"]) * 100.0)
	_stats["resistencia"].text = "%d%%" % roundi(float(GS.physique["resistencia"]) * 100.0)
	_refresh_detail()


func _kg(w: float) -> String:
	return ("%.1f kg" % w).replace(".", ",")


## Línea de carga total (siempre visible en la ficha).
func _refresh_load() -> void:
	var w := GS.carry_weight()
	var cap := GS.carry_capacity()
	var r := w / maxf(cap, 1.0)
	var col := Color("9fd36a") if r <= 0.5 else (Color("e8b84a") if r <= 1.0 else Color("e0705a"))
	load_label.text = "Carga total: %s / %s%s" % [_kg(w), _kg(cap), "" if r <= 1.0 else " · sobrecarga"]
	load_label.add_theme_color_override("font_color", col)
	_load_bar.value = minf(r, 1.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(4)
	_load_bar.add_theme_stylebox_override("fill", fill)


func _refresh_detail() -> void:
	_refresh_load()
	_d_weight.text = ""
	for c in _d_actions.get_children():
		c.queue_free()
	action_buttons = []
	var it: Variant = null
	if sel_kind == "inv":
		if sel_index >= GS.slots.size():
			var need := ""
			for t in TIERS.size():
				if sel_index < (t + 1) * 8:
					need = "Necesitas la %s (se cose en la %s)" % [str(TIERS[t][0]).to_lower(), TIERS[t][2]]
					break
			_show(null, "Hueco bloqueado", need, "")
			return
		it = GS.slots[sel_index]
	else:
		it = _worn(sel_slot)
	if it == null:
		_show(null, "Vacío", "Toca un objeto para ver qué hacer con él." if sel_kind == "inv" else "Ponte algo desde las casillas de la derecha.", "")
		return
	var id := str(it["id"])
	var data := DB.item(id)
	var stats := PackedStringArray()
	for k in [["damage", "Daño %d"], ["armor", "Defensa +%d%%"], ["bag_slots", "+%d huecos"], ["food", "Comida +%d"], ["water", "Agua +%d"], ["heal", "Vida %+d"]]:
		if data.has(k[0]):
			stats.append(k[1] % int(data[k[0]]))
	if data.has("durability") and it.has("dur"):
		stats.append("Estado %d/%d" % [int(it["dur"]), int(data["durability"])])
	if data.has("carry"):
		stats.append("Carga +%d kg" % int(data["carry"]))
	_show(DB.item_icon(id), DB.item_name(id), str(data.get("desc", "")), " · ".join(stats), "x%d" % int(it["qty"]) if int(it.get("qty", 1)) > 1 else "")
	var q := int(it.get("qty", 1))
	_d_weight.text = ("   %s" % _kg(DB.weight(id))) if q <= 1 else ("   %s c/u · %s" % [_kg(DB.weight(id)), _kg(DB.weight(id) * q)])
	var acts: Array = []
	if sel_kind == "eq":
		acts = [["Guardar" if sel_slot == "arma" else "Quitar", func():
			if sel_slot == "arma":
				GS.unequip()
			else:
				GS.take_off(sel_slot)]]
	else:
		var i := sel_index
		match str(data.get("type", "")):
			"consumable":
				acts.append(["Usar", func(): GS.use_slot(i)])
			"weapon":
				acts.append(["Equipar", func(): GS.equip_slot(i)])
			"wear":
				acts.append(["Ponerse", func(): GS.wear_slot(i)])
		acts.append(["Tirar", func(): GS.drop_slot(i)])
	for k in acts.size():
		var b := Button.new()
		b.text = acts[k][0]
		b.custom_minimum_size = Vector2(132, 46)
		b.add_theme_font_size_override("font_size", 20)
		var primary: bool = k == 0 and acts.size() > 1 or acts[k][0] in ["Quitar", "Guardar"]
		b.add_theme_stylebox_override("normal", _box(GOLD if primary else Color(0, 0, 0, 0.45), GOLD if primary else Color(0.91, 0.86, 0.72, 0.3), 12, 6))
		b.add_theme_color_override("font_color", INK if primary else TXT)
		b.pressed.connect(acts[k][1])
		_d_actions.add_child(b)
		action_buttons.append(b)


func _show(tex: Texture2D, name_: String, desc: String, stats: String, qty := "") -> void:
	_d_icon.texture = tex if tex else DB.ui_icon("candado")
	_d_icon.modulate = Color(1, 1, 1, 1.0 if tex else 0.5)
	_d_name.text = name_
	_d_qty.text = ("  " + qty) if qty != "" else ""
	_d_desc.text = desc
	_d_stats.text = stats
