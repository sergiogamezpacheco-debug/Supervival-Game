extends Control
## Pantalla de una estación según los diseños del usuario (docs/diseno_est_*.jpg):
## cabecera (icono, nombre, nivel, pestañas, cerrar); a la izquierda, el objeto elegido
## girando en un pedestal 3D, su descripción, la barra de progreso y la de energía; a la
## derecha, la lista (materiales en rojo si faltan), cantidad − 1 + y FABRICAR.
## Sirve también para obras por fases, el generador, el recolector y las reparaciones.
## Todo va con posiciones fijas (sin contenedores que se reajusten solos).

const GOLD := Color("e2c48a")
const PAPER := Color("efe2c0")
const ORANGE := Color("e6a83c")
const INK := Color("1d1912")
const RED := Color("e0705a")
const DESC := Color("e8a95a")
const ROW_BG := Color(0.13, 0.12, 0.095, 0.92)
const ROW_LINE := Color("4d4536")
const PANEL_BG := Color(0.07, 0.065, 0.05, 0.9)
const W := 1280.0
const TAB_ORDER := ["Obra", "Herramientas", "Armas", "Ropa", "Mochilas", "Comida", "Medicinas", "Recursos", "Combustible", "Agua", "Reparar"]

var station: Node3D
var entries: Array = []          # lo que se puede hacer aquí (pestaña actual)
var selected := 0
var qty := 1
var tab := ""
var tabs: Array = []
var action_btn: Button           # FABRICAR / AÑADIR / ECHAR / REPARAR / BEBER / RECOGER

var _content: Control
var _cond: FontVariation
var _icon: TextureRect
var _title: Label
var _level_pill: PanelContainer
var _level_label: Label
var _tabs_box: HBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _rows: Array = []
var _name: Label
var _time: Label
var _desc: Label
var _prog_label: Label
var _prog_time: Label
var _prog_bar: ProgressBar
var _prog_text: Label
var _energy_nodes: Array = []
var _energy_label: Label
var _energy_time: Label
var _energy_bar: ProgressBar
var _energy_text: Label
var _energy_icon: TextureRect
var _minus: Button
var _plus: Button
var _qty_label: Label
# Vista 3D
var _vp: SubViewport
var _pedestal: Node3D
var _item: Sprite3D
var _model_holder: Node3D
var _t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_cond = FontVariation.new()
	_cond.base_font = get_theme_default_font()
	_cond.variation_transform = Transform2D(Vector2(0.88, 0), Vector2(0, 1), Vector2.ZERO)
	_cond.spacing_glyph = -2
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.02, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_content = Control.new()
	_content.anchor_left = 0.5
	_content.anchor_right = 0.5
	_content.offset_left = -W / 2.0
	_content.offset_right = W / 2.0
	_content.anchor_bottom = 1.0
	add_child(_content)
	_build_header()
	_build_left()
	_build_right()


# ------------------------------------------------------------------ piezas

func _lbl(text: String, fs: int, col := GOLD, pos := Vector2.ZERO, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", _cond)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else _content).add_child(l)
	return l


func _box(bg: Color, line: Color, radius := 14, border := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = line
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


func _panel(rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", _box(PANEL_BG, Color("3a3428"), 20, 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(p)
	return p


func _btn(text: String, rect: Rect2, primary := false, fs := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _cond)
	b.add_theme_font_size_override("font_size", fs)
	var bg := ORANGE if primary else Color(0.1, 0.095, 0.075, 0.95)
	b.add_theme_stylebox_override("normal", _box(bg, ORANGE.darkened(0.3) if primary else ROW_LINE, 14, 2))
	b.add_theme_stylebox_override("hover", _box(bg, ORANGE.darkened(0.3) if primary else ROW_LINE, 14, 2))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.15), ORANGE, 14, 2))
	b.add_theme_stylebox_override("disabled", _box(bg.darkened(0.45) if primary else bg, ROW_LINE, 14, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var fg := INK if primary else PAPER
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", fg.darkened(0.2) if primary else Color(0.6, 0.55, 0.45))
	_content.add_child(b)
	return b


func _bar(pos: Vector2, w: float, fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = Vector2(w, 36)
	b.max_value = 1.0
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", _box(Color(0.05, 0.05, 0.04), Color("57503f"), 10, 2))
	var f := _box(fill, fill, 9, 0)
	b.add_theme_stylebox_override("fill", f)
	_content.add_child(b)
	return b


func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


# ----------------------------------------------------------------- cabecera

func _build_header() -> void:
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(22, 12)
	_icon.size = Vector2(66, 62)
	_content.add_child(_icon)
	_title = _lbl("", 44, PAPER.darkened(0.06), Vector2(98, 12))
	_level_pill = PanelContainer.new()
	var psb := _box(ORANGE, ORANGE, 16, 0)
	psb.content_margin_left = 14
	psb.content_margin_right = 14
	psb.content_margin_top = 2
	psb.content_margin_bottom = 2
	_level_pill.add_theme_stylebox_override("panel", psb)
	_level_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_label = Label.new()
	_level_label.add_theme_font_override("font", _cond)
	_level_label.add_theme_font_size_override("font_size", 22)
	_level_label.add_theme_color_override("font_color", INK)
	_level_pill.add_child(_level_label)
	_content.add_child(_level_pill)
	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 6)
	_content.add_child(_tabs_box)
	var close := _btn("X", Rect2(1186, 16, 64, 58), false, 30)
	close.add_theme_stylebox_override("normal", _box(Color(0.02, 0.02, 0.02, 0.95), Color("3a3a36"), 12, 2))
	close.pressed.connect(func(): visible = false)


# --------------------------------------------------------------- izquierda

func _build_left() -> void:
	_panel(Rect2(24, 90, 592, 614))
	# Vista 3D: pedestal girando con el objeto encima
	var view := SubViewportContainer.new()
	view.position = Vector2(54, 98)
	view.size = Vector2(532, 262)
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(view)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	view.add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.68)
	env.environment.ambient_light_energy = 0.75
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.15
	_vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 32
	cam.position = Vector3(0, 2.1, 4.6)
	_vp.add_child(cam)
	cam.look_at(Vector3(0, 0.7, 0), Vector3.UP)
	_pedestal = Node3D.new()
	_vp.add_child(_pedestal)
	var stone := Color("6d655c")
	StationModels._p(_pedestal, StationModels._cyl(1.25, 1.35, 0.18, 12), stone.darkened(0.15), Vector3(0, 0.09, 0))
	StationModels._p(_pedestal, StationModels._cyl(1.0, 1.08, 0.16, 12), stone, Vector3(0, 0.26, 0))
	var arrow := MeshInstance3D.new()
	var am := PrismMesh.new()
	am.size = Vector3(0.28, 0.2, 0.03)
	arrow.mesh = am
	arrow.material_override = Builder.mat(Color("d9cdb0"))
	arrow.position = Vector3(-0.95, 0.19, 0.75)
	arrow.rotation_degrees = Vector3(-90, 0, 55)
	_pedestal.add_child(arrow)
	_item = Sprite3D.new()
	_item.pixel_size = 0.0125
	_item.position = Vector3(0, 1.05, 0)
	_item.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_item.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_item.shaded = false
	_vp.add_child(_item)
	_model_holder = Node3D.new()
	_model_holder.position = Vector3(0, 0.34, 0)
	_vp.add_child(_model_holder)
	# Nombre, tiempo y descripción
	_name = _lbl("", 30, PAPER, Vector2(48, 370))
	_time = _lbl("", 24, GOLD, Vector2(420, 374))
	_time.size = Vector2(176, 30)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_desc = _lbl("", 21, DESC, Vector2(48, 410))
	_desc.size = Vector2(548, 80)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	var sep := ColorRect.new()
	sep.color = Color("3a3428")
	sep.position = Vector2(44, 500)
	sep.size = Vector2(552, 2)
	_content.add_child(sep)
	# Progreso
	_prog_label = _lbl("PROGRESO", 24, GOLD, Vector2(104, 512))
	_prog_time = _lbl("", 24, GOLD, Vector2(380, 512))
	_prog_time.size = Vector2(216, 30)
	_prog_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var pi := TextureRect.new()
	pi.texture = _tex("res://assets/icons/estaciones/progreso.png")
	pi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pi.position = Vector2(44, 544)
	pi.size = Vector2(48, 48)
	_content.add_child(pi)
	_prog_bar = _bar(Vector2(104, 550), 492, Color("8a7a5c"))
	_prog_text = _lbl("", 22, PAPER, Vector2(104, 552))
	_prog_text.size = Vector2(492, 30)
	_prog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Energía
	_energy_label = _lbl("ENERGÍA", 24, GOLD, Vector2(104, 604))
	_energy_time = _lbl("", 24, GOLD, Vector2(380, 604))
	_energy_time.size = Vector2(216, 30)
	_energy_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_energy_icon = TextureRect.new()
	_energy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_energy_icon.position = Vector2(46, 636)
	_energy_icon.size = Vector2(44, 48)
	_content.add_child(_energy_icon)
	_energy_bar = _bar(Vector2(104, 642), 492, Color("f0c43a"))
	_energy_text = _lbl("", 22, PAPER, Vector2(104, 644))
	_energy_text.size = Vector2(492, 30)
	_energy_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_nodes = [_energy_label, _energy_time, _energy_icon, _energy_bar, _energy_text]


# ----------------------------------------------------------------- derecha

func _build_right() -> void:
	_panel(Rect2(640, 90, 616, 614))
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(656, 104)
	_scroll.size = Vector2(590, 486)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(570, 0)
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)
	var sep := ColorRect.new()
	sep.color = Color("3a3428")
	sep.position = Vector2(656, 600)
	sep.size = Vector2(584, 2)
	_content.add_child(sep)
	_minus = _btn("−", Rect2(660, 614, 76, 76), false, 40)
	_minus.pressed.connect(func(): set_qty(qty - 1))
	var qbox := Panel.new()
	qbox.position = Vector2(746, 614)
	qbox.size = Vector2(76, 76)
	qbox.add_theme_stylebox_override("panel", _box(Color(0.1, 0.095, 0.075, 0.95), ROW_LINE, 14, 2))
	qbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(qbox)
	_qty_label = _lbl("1", 32, PAPER, Vector2(746, 630))
	_qty_label.size = Vector2(76, 40)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus = _btn("+", Rect2(832, 614, 76, 76), false, 40)
	_plus.pressed.connect(func(): set_qty(qty + 1))
	action_btn = _btn("FABRICAR", Rect2(930, 614, 314, 80), true, 34)
	action_btn.icon = _tex("res://assets/icons/estaciones/martillo.png")
	action_btn.add_theme_constant_override("icon_max_width", 46)
	action_btn.add_theme_constant_override("h_separation", 14)
	action_btn.pressed.connect(_on_action)


# ---------------------------------------------------------------- abrir

func open(s: Node3D) -> void:
	station = s
	qty = 1
	selected = 0
	tab = ""
	visible = true
	refresh()


## Icono de la tarjeta: el de los diseños de estaciones si lo hay, si no el del objeto.
func recipe_icon(id: String) -> Texture2D:
	var t := _tex("res://assets/icons/recetas/%s.png" % id)
	return t if t else DB.item_icon(id)


## Imagen grande de la izquierda: la del diseño si la hay, si no el icono de la tarjeta.
func preview_tex(id: String) -> Texture2D:
	var t := _tex("res://assets/icons/preview/%s.png" % id)
	return t if t else recipe_icon(id)


func _station_icon(id: String) -> Texture2D:
	return _tex("res://assets/icons/estaciones/%s.png" % id)


## Categoría de una receta: "cat" en recipes.json o según el tipo del resultado.
static func recipe_cat(r: Dictionary) -> String:
	if r.has("cat"):
		return str(r["cat"])
	var d := DB.item(str(r["result"]))
	match str(d.get("type", "")):
		"weapon":
			return "Armas"
		"tool":
			return "Herramientas"
		"wear":
			return "Mochilas" if str(d.get("slot", "")) == "espalda" else "Ropa"
		"consumable":
			return "Medicinas" if d.has("heal") else "Comida"
	return "Recursos"


## Todo lo que se puede hacer en la estación, agrupado por pestaña.
func _all_entries() -> Array:
	var out: Array = []
	if not station.is_built():
		var ph: Array = station.phases()
		for i in ph.size():
			out.append({"kind": "phase", "i": i, "tab": "Obra", "name": "Fase %d: %s" % [i + 1, ph[i].get("name", "")],
				"cost": ph[i].get("cost", {}), "desc": DB.stations[station.id].get("desc", ""), "done": i < station.stage})
		return out
	if station.is_generator():
		var per: Dictionary = DB.bal("generator_fuel", {"carbon": 300, "madera": 90})
		for fid in per:
			out.append({"kind": "fuel", "id": str(fid), "tab": "Combustible", "name": "Echar %s" % DB.item_name(str(fid)).to_lower(),
				"cost": {str(fid): 1}, "desc": "Cada unidad da %s de energía a la recicladora." % _clock(float(per[fid])), "icon": str(fid)})
		return out
	if station.is_collector():
		out.append({"kind": "water", "tab": "Agua", "name": "Beber agua", "cost": {},
			"desc": "Junta agua sola; con lluvia, cuatro veces más rápido. Bebe hasta quitarte la sed.", "icon": ""})
		return out
	for r in DB.recipes_for(station.id):
		out.append({"kind": "recipe", "r": r, "tab": recipe_cat(r), "name": DB.item_name(str(r["result"])),
			"cost": r.get("cost", {}), "desc": str(DB.item(str(r["result"])).get("desc", "")), "icon": str(r["result"])})
	if station.id == "banco_trabajo" or station.id == "mesa_costura":
		for ref in GS.damaged_items(station.id):
			var it: Dictionary = ref["item"]
			var mx := maxi(int(DB.item(str(it["id"])).get("durability", 1)), 1)
			out.append({"kind": "repair", "ref": ref, "tab": "Reparar", "icon": str(it["id"]),
				"name": "Reparar %s (%d%%)" % [DB.item_name(str(it["id"])), roundi(100.0 * float(it["dur"]) / mx)],
				"cost": GS.repair_cost(it), "desc": "Vuelve a dejarlo como nuevo."})
	return out


func refresh() -> void:
	if station == null or not is_instance_valid(station):
		visible = false
		return
	var all := _all_entries()
	tabs = []
	for e in all:
		if not tabs.has(e["tab"]):
			tabs.append(e["tab"])
	tabs.sort_custom(func(a, b): return TAB_ORDER.find(a) < TAB_ORDER.find(b))
	if not tabs.has(tab):
		tab = tabs[0] if not tabs.is_empty() else ""
	entries = all.filter(func(e): return e["tab"] == tab)
	if not station.is_built():
		selected = clampi(station.stage, 0, maxi(entries.size() - 1, 0))
	selected = clampi(selected, 0, maxi(entries.size() - 1, 0))
	# Cabecera
	_icon.texture = _station_icon(station.id)
	_title.text = DB.station_name(station.id).to_upper()
	var tw := _cond.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	_level_label.text = "Nivel %d" % station.level if station.is_built() else "En obra %d/%d" % [station.stage, station.phases().size()]
	_level_pill.position = Vector2(98 + tw + 24, 28)
	_level_pill.size = Vector2.ZERO   # que se ajuste al texto nuevo
	_build_tabs()
	_build_rows()
	_select(selected)


func _build_tabs() -> void:
	for c in _tabs_box.get_children():
		c.queue_free()
	_tabs_box.visible = tabs.size() > 1
	var widths := 0.0
	for t in tabs:
		var b := Button.new()
		b.text = str(t).to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_override("font", _cond)
		b.add_theme_font_size_override("font_size", 21)
		var on: bool = t == tab
		var bg := ORANGE if on else Color(0.1, 0.095, 0.075, 0.95)
		for st in ["normal", "hover", "pressed"]:
			var sb := _box(bg, ORANGE.darkened(0.3) if on else ROW_LINE, 14, 2)
			sb.content_margin_left = 14
			sb.content_margin_right = 14
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, INK if on else GOLD)
		var tid: String = t
		b.pressed.connect(func():
			tab = tid
			selected = 0
			qty = 1
			refresh())
		_tabs_box.add_child(b)
		widths += _cond.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 34.0
	widths += 6.0 * maxf(tabs.size() - 1, 0)
	var pill_end := _level_pill.position.x + _level_pill.get_combined_minimum_size().x + 16.0
	if 1172.0 - widths >= pill_end:
		_tabs_box.position = Vector2(1172 - widths, 18)
		_scroll.position = Vector2(656, 104)
		_scroll.size = Vector2(590, 486)
	else:
		# No caben junto al nombre: dentro del panel derecho, encima de la lista
		_tabs_box.position = Vector2(656, 100)
		_scroll.position = Vector2(656, 166)
		_scroll.size = Vector2(590, 424)


func _locked_text(e: Dictionary) -> String:
	if e["kind"] != "recipe":
		return ""
	var r: Dictionary = e["r"]
	if GS.level < DB.recipe_unlock(r):
		return "Se desbloquea en el nivel %d" % DB.recipe_unlock(r)
	if not station.recipe_unlocked(r):
		return "Requiere %s de nivel %d" % [DB.station_name(station.id).to_lower(), int(r.get("level", 1))]
	return ""


func _build_rows() -> void:
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	for i in entries.size():
		var e: Dictionary = entries[i]
		var row := Button.new()
		row.custom_minimum_size = Vector2(570, 112)
		row.focus_mode = Control.FOCUS_NONE
		row.toggle_mode = false
		var idx := i
		row.pressed.connect(func(): _select(idx))
		# Icono en su caja
		var ib := Panel.new()
		ib.position = Vector2(12, 12)
		ib.size = Vector2(88, 88)
		ib.add_theme_stylebox_override("panel", _box(Color(0.09, 0.085, 0.07), ROW_LINE, 14, 2))
		ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ib)
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(20, 20)
		ic.size = Vector2(72, 72)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_id := str(e.get("icon", ""))
		ic.texture = recipe_icon(icon_id) if icon_id != "" else (_station_icon(station.id) if e["kind"] != "water" else DB.ui_icon("agua"))
		row.add_child(ic)
		var ok := GS.has_cost(e["cost"]) and _locked_text(e) == ""
		var name_col := PAPER if ok or e.get("done", false) else RED
		var nm := _lbl(str(e["name"]).to_upper(), 27, name_col, Vector2(114, 10), row)
		nm.size = Vector2(440, 34)
		nm.clip_text = true
		var lock := _locked_text(e)
		if e.get("done", false):
			_lbl("Hecha", 21, Color("9fd36a"), Vector2(116, 56), row)
		elif lock != "":
			_lbl(lock, 21, RED, Vector2(116, 56), row)
		else:
			_cost_line(row, e["cost"], Vector2(116, 52))
		_rows.append(row)
		_list.add_child(row)
	if entries.is_empty():
		var l := Label.new()
		l.text = "Nada que hacer aquí todavía."
		l.add_theme_color_override("font_color", GOLD)
		_list.add_child(l)


## Materiales en una o dos líneas: icono pequeño + "Nombre xN" (en rojo si no llega).
func _cost_line(row: Control, cost: Dictionary, at: Vector2) -> void:
	var x := at.x
	var y := at.y
	for id in cost:
		var need := int(cost[id])
		var have := GS.count(str(id))
		var txt := "%s x%d" % [DB.item_name(str(id)), need]
		var w := _cond.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 34.0
		if x + w > 560.0 and x > at.x:
			x = at.x
			y += 28.0
		var ic := TextureRect.new()
		ic.texture = DB.item_icon(str(id))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(x, y + 1)
		ic.size = Vector2(24, 24)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
		_lbl(txt, 20, PAPER if have >= need else RED, Vector2(x + 28, y), row)
		x += w + 10.0


func _select(i: int) -> void:
	selected = clampi(i, 0, maxi(entries.size() - 1, 0))
	for j in _rows.size():
		var on := j == selected
		var bg := Color(0.2, 0.17, 0.11, 0.95) if on else ROW_BG
		var line := Color("c9a15a") if on else ROW_LINE
		for st in ["normal", "hover", "pressed"]:
			(_rows[j] as Button).add_theme_stylebox_override(st, _box(bg, line, 16, 2))
	if entries.is_empty():
		_name.text = ""
		_desc.text = ""
		_item.texture = null
		return
	var e: Dictionary = entries[selected]
	_name.text = str(e["name"]).to_upper()
	_desc.text = str(e["desc"])
	if e["kind"] == "recipe":
		_time.text = "Tiempo: %s" % _clock(station.recipe_time(e["r"]))
	else:
		_time.text = ""
	_show_preview(e)
	qty = clampi(qty, 1, _max_qty())
	tick()


func _show_preview(e: Dictionary) -> void:
	for c in _model_holder.get_children():
		c.queue_free()
	var icon_id := str(e.get("icon", ""))
	if e["kind"] == "phase" or e["kind"] == "water" or icon_id == "":
		_item.texture = null
		var m := Builder.station_mesh(station.id, station.level)
		for l in m.find_children("*", "Light3D", true, false):
			l.queue_free()
		var size: Vector3 = StationScript().SIZES.get(station.id, Vector3(1.4, 1.0, 1.0))
		var k := 1.5 / maxf(maxf(size.x, size.z), size.y * 1.1)
		m.scale = Vector3.ONE * k
		_model_holder.add_child(m)
	else:
		_item.texture = preview_tex(icon_id)
		var tw := float(_item.texture.get_width()) if _item.texture else 128.0
		var big := ResourceLoader.exists("res://assets/icons/preview/%s.png" % icon_id)
		_item.pixel_size = (1.75 if big else 1.45) / maxf(tw, 1.0)


func _max_qty() -> int:
	if entries.is_empty():
		return 1
	var e: Dictionary = entries[selected]
	if e["kind"] == "recipe":
		return maxi(1, StationScript().max_times(e["r"]))
	if e["kind"] == "fuel":
		return clampi(GS.count(str(e["id"])), 1, 20)
	return 1


static func StationScript() -> GDScript:
	return load("res://scripts/world/station.gd")


func set_qty(n: int) -> void:
	qty = clampi(n, 1, _max_qty())
	tick()


func _clock(t: float) -> String:
	var s := maxi(int(ceil(t)), 0)
	return "%02d:%02ds" % [s / 60, s % 60]


## Barras, textos y botón (se llama cada fotograma con la pantalla abierta).
func tick() -> void:
	if not visible or station == null or not is_instance_valid(station):
		return
	_qty_label.text = str(qty)
	var e: Dictionary = entries[selected] if not entries.is_empty() else {}
	var kind := str(e.get("kind", ""))
	var uses_qty := kind == "recipe" or kind == "fuel"
	_minus.disabled = not uses_qty or qty <= 1
	_plus.disabled = not uses_qty or qty >= _max_qty()
	# Progreso
	_prog_label.text = "PROGRESO"
	if not station.is_built():
		var n: int = station.phases().size()
		_prog_bar.value = float(station.stage) / float(n)
		_prog_text.text = "Obra: %d de %d fases" % [station.stage, n]
		_prog_time.text = ""
	elif station.is_collector():
		var w: float = station.water_now()
		_prog_label.text = "AGUA"
		_prog_bar.value = w / station.water_capacity()
		_prog_text.text = "%d/%d" % [int(w), int(station.water_capacity())]
		_prog_time.text = "Lloviendo" if GS.raining() else ""
	elif station.is_generator():
		_prog_bar.value = 0.0
		_prog_text.text = ""
		_prog_time.text = ""
	elif station.job.is_empty():
		_prog_bar.value = 0.0
		_prog_text.text = "0%"
		_prog_time.text = "Libre"
	else:
		_prog_bar.value = station.progress()
		_prog_text.text = "%d%%" % int(floor(station.progress() * 100.0))
		var nm := DB.item_name(str(DB.recipe(str(station.job["recipe"])).get("result", "")))
		_prog_time.text = ("%s listo" % nm) if station.is_done() else ("Tiempo: %s" % _clock(station.time_left()))
	# Energía: el generador (y lo que gasta energía); el resto no la necesita
	var gen: Node3D = station if station.is_generator() and station.is_built() else (station._generator() if station.is_built() and station.needs_power() else null)
	var show_energy: bool = station.is_built() and (station.is_generator() or station.needs_power())
	for n in _energy_nodes:
		n.visible = show_energy
	if show_energy:
		_energy_icon.texture = _tex("res://assets/icons/estaciones/bateria.png")
		var mx := float(DB.bal("generator_max", 3600))
		var f: float = gen.fuel if gen else 0.0
		_energy_bar.value = f / mx
		_energy_text.text = "%d/100" % roundi(100.0 * f / mx) if gen else "Sin generador"
		_energy_time.text = "TIEMPO: %s" % _clock(f)
	# Botón
	action_btn.disabled = false
	action_btn.icon = _tex("res://assets/icons/estaciones/martillo.png")
	match kind:
		"recipe":
			var lock := _locked_text(e)
			if station.is_done():
				action_btn.text = "RECOGER"
			elif lock != "":
				action_btn.text = ("NIVEL %d" % DB.recipe_unlock(e["r"])) if GS.level < DB.recipe_unlock(e["r"]) else "MEJORAR"
				action_btn.disabled = true
			elif not station.job.is_empty():
				action_btn.text = "OCUPADO"
				action_btn.disabled = true
			else:
				action_btn.text = "FABRICAR"
				action_btn.disabled = not GS.has_cost(StationScript().cost_times(e["r"], qty))
		"phase":
			action_btn.text = "AÑADIR"
			action_btn.disabled = e.get("done", false) or int(e["i"]) != station.stage or not GS.has_cost(e["cost"])
		"fuel":
			action_btn.text = "ECHAR"
			action_btn.disabled = GS.count(str(e["id"])) <= 0
		"repair":
			action_btn.text = "REPARAR"
			action_btn.disabled = not GS.has_cost(e["cost"])
		"water":
			action_btn.text = "BEBER"
			action_btn.disabled = station.water_now() < 1.0
		_:
			action_btn.text = "FABRICAR"
			action_btn.disabled = true


func _on_action() -> void:
	if entries.is_empty():
		return
	var e: Dictionary = entries[selected]
	var why := ""
	match str(e["kind"]):
		"recipe":
			if station.is_done():
				station.collect()
			else:
				why = station.start(str(e["r"]["id"]), qty)
		"phase":
			why = station.add_phase()
		"fuel":
			for i in qty:
				why = station.add_fuel(str(e["id"]))
				if why != "":
					break
		"repair":
			why = GS.repair(e["ref"])
		"water":
			station.drink()
	if why != "":
		GS.message.emit(why)
	var keep := selected
	refresh()
	_select(keep)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_pedestal.rotation.y = _t * 0.5
	_model_holder.rotation.y = _t * 0.5
	_item.rotation.y = sin(_t * 0.8) * 0.45
	_item.position.y = 1.05 + sin(_t * 1.6) * 0.04
	tick()
