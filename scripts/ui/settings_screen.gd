extends Control
## Pantalla de ajustes según el diseño del usuario (docs/diseno_ajustes.jpg):
## cabecera con sillón, pestañas General / Gráficos / Audio, bloque "Sistema" a la
## izquierda (versión, servidor, último acceso, soporte, legal y redes sociales) y
## lista de ajustes a la derecha con "Cerrar sesión" y "Borrar datos".
## Los valores se guardan en SFX.settings (user://settings.json).

signal edit_look_requested
signal new_game_requested

const GOLD := Color("e2c48a")
const PAPER := Color("efe2c0")
const ORANGE := Color("e6a83c")
const INK := Color("1d1912")
const ROW_BG := Color(0.17, 0.155, 0.125, 0.82)
const ROW_LINE := Color("5a503e")
const PANEL_BG := Color(0.1, 0.09, 0.07, 0.8)

const QUALITY := ["bajo", "medio", "alto"]
const TABS := ["general", "graficos", "audio"]
const TAB_NAMES := {"general": "General", "graficos": "Gráficos", "audio": "Audio"}

var tab := "general"
var controls := {}               # clave de ajuste -> control (los tests los usan)
var world: Node3D
var _tab_buttons := {}
var _list: VBoxContainer
var _pill_label: Label
var _sys_values := {}
var _wipe_btn: Button
var _legal: PanelContainer
var _cond: FontVariation
var _knob: ImageTexture
var _saved := {}                 # ajustes tal como están guardados (para descartar)
var dirty := false               # hay cambios sin guardar
var save_btn: Button
var _close_btn: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_cond = FontVariation.new()
	_cond.base_font = get_theme_default_font()
	_cond.variation_transform = Transform2D(Vector2(0.88, 0), Vector2(0, 1), Vector2.ZERO)
	_cond.spacing_glyph = -2   # letra estrecha como la del diseño
	_knob = _circle_tex(26, Color("c9a868"), Color("6d5a35"))
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.025, 0.02, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_build_header()
	_build_system()
	_build_right()
	_build_legal()
	select_tab("general")
	visibility_changed.connect(func():
		if visible:
			# Lo guardado en el archivo; si algo cambió fuera (zoom con los dedos), se puede guardar
			_saved = _stored()
			_set_dirty(_differs())
			_refresh_system()
			select_tab(tab)
		_wipe_btn.text = "BORRAR\nDATOS"
		_legal.visible = false)


# ------------------------------------------------------------------ piezas

func _lbl(text: String, fs: int, col := GOLD, cond := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if cond:
		l.add_theme_font_override("font", _cond)
	return l


func _box(bg: Color, line: Color, radius := 12, border := 1.5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = line
	sb.set_border_width_all(int(round(border)))
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	sb.anti_aliasing = true
	return sb


func _btn(text: String, fs := 22, w := 0.0, h := 52.0, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _cond)
	b.add_theme_font_size_override("font_size", fs)
	var bg := ORANGE if primary else Color(0.16, 0.145, 0.115, 0.95)
	var fg := INK if primary else GOLD
	b.add_theme_stylebox_override("normal", _box(bg, ORANGE.darkened(0.3) if primary else ROW_LINE, 12, 2))
	b.add_theme_stylebox_override("hover", _box(bg, ORANGE.darkened(0.3) if primary else ROW_LINE, 12, 2))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.15), ORANGE, 12, 2))
	b.add_theme_stylebox_override("disabled", _box(bg.darkened(0.3), ROW_LINE, 12, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	return b


func _circle_tex(d: int, fill: Color, line: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d, d) / 2.0
	for y in d:
		for x in d:
			var r := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if r <= d / 2.0 - 0.5:
				img.set_pixel(x, y, line if r > d / 2.0 - 2.5 else fill)
	return ImageTexture.create_from_image(img)


## Fila con fondo y borde redondeado (como en el diseño).
func _row(highlight := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(ORANGE.lightened(0.05) if highlight else ROW_BG, ORANGE.darkened(0.25) if highlight else ROW_LINE, 14, 2))
	p.custom_minimum_size = Vector2(0, 64)
	return p


func _hrow(title: String, highlight := false) -> HBoxContainer:
	var p := _row(highlight)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var l := _lbl(title.to_upper(), 23, INK if highlight else GOLD)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	p.add_child(h)
	_list.add_child(p)
	return h


# ----------------------------------------------------------------- cabecera

func _build_header() -> void:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/ajustes/sillon.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = Vector2(30, 16)
	icon.size = Vector2(60, 60)
	add_child(icon)
	var title := _lbl("AJUSTES", 44, PAPER.darkened(0.08))
	title.position = Vector2(102, 14)
	add_child(title)
	var pill := PanelContainer.new()
	var psb := _box(ORANGE, ORANGE, 18, 0)
	psb.content_margin_left = 10
	psb.content_margin_right = 14
	psb.content_margin_top = 3
	psb.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", psb)
	pill.position = Vector2(282, 28)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 6)
	var gear := TextureRect.new()
	gear.texture = load("res://assets/icons/ajustes/engranaje.png")
	gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear.custom_minimum_size = Vector2(24, 24)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(gear)
	_pill_label = _lbl("General", 21, INK)
	ph.add_child(_pill_label)
	pill.add_child(ph)
	add_child(pill)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(704, 22)
	tabs.add_theme_constant_override("separation", 8)
	for t in TABS:
		var b := _btn(str(TAB_NAMES[t]).to_upper(), 23, 128, 58)
		var tid: String = t
		b.pressed.connect(func(): select_tab(tid))
		tabs.add_child(b)
		_tab_buttons[t] = b
	add_child(tabs)
	var close := _btn("X", 30, 62, 58)
	close.add_theme_stylebox_override("normal", _box(Color(0.03, 0.03, 0.03, 0.95), Color("3a3a36"), 12, 2))
	close.add_theme_color_override("font_color", Color.WHITE)
	close.position = Vector2(1190, 20)
	close.pressed.connect(close_screen)
	add_child(close)
	_close_btn = close
	# Guardar: deja fijados los ajustes (también la distancia de la cámara)
	save_btn = _btn("GUARDAR", 23, 150, 58, true)
	save_btn.position = Vector2(540, 22)
	save_btn.pressed.connect(save)
	add_child(save_btn)
	controls["save"] = save_btn


func _stored() -> Dictionary:
	var out: Dictionary = SFX.settings.duplicate()
	if FileAccess.file_exists(SFX.settings_path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SFX.settings_path))
		if d is Dictionary:
			for k in d:
				out[k] = d[k]
	return out


func _differs() -> bool:
	for k in SFX.settings:
		if k == "last_access":
			continue
		if not _saved.has(k) or str(_saved[k]) != str(SFX.settings[k]):
			return true
	return false


func save() -> void:
	SFX.save_settings()
	_saved = SFX.settings.duplicate()
	_set_dirty(false)
	GS.message.emit("Ajustes guardados")


## Cerrar: si hay cambios sin guardar, el primer toque avisa y el segundo los descarta.
func close_screen() -> void:
	if dirty and _close_btn.text != "?":
		_close_btn.text = "?"
		GS.message.emit("Hay cambios sin guardar: pulsa GUARDAR o X otra vez para descartarlos")
		return
	if dirty:
		SFX.settings = _saved.duplicate()
		SFX.apply()
		apply_graphics(world)
		GS.message.emit("Cambios descartados")
	_set_dirty(false)
	visible = false


func _set_dirty(d: bool) -> void:
	dirty = d
	if _close_btn:
		_close_btn.text = "X"
	if save_btn:
		save_btn.disabled = not d
		save_btn.text = "GUARDAR" if d else "GUARDADO"
		save_btn.modulate = Color.WHITE if d else Color(1, 1, 1, 0.55)


func select_tab(t: String) -> void:
	tab = t
	_pill_label.text = TAB_NAMES[t]
	for k in _tab_buttons:
		var b: Button = _tab_buttons[k]
		var on: bool = k == t
		b.add_theme_stylebox_override("normal", _box(ORANGE if on else Color(0.16, 0.145, 0.115, 0.95), ORANGE.darkened(0.3) if on else ROW_LINE, 12, 2))
		b.add_theme_stylebox_override("hover", b.get_theme_stylebox("normal"))
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, INK if on else GOLD)
	_fill_list()


# ------------------------------------------------------------ bloque sistema

func _build_system() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(30, 100)
	panel.size = Vector2(574, 600)
	var sb := _box(PANEL_BG, Color("3d3629"), 20, 2)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	v.add_child(_lbl("SISTEMA", 32, PAPER.darkened(0.08)))
	for d in [["version", "Versión del juego"], ["server", "Servidor"], ["access", "Último acceso"]]:
		var h := HBoxContainer.new()
		var l := _lbl(str(d[1]).to_upper(), 24)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var val := _lbl("", 25, PAPER)
		h.add_child(val)
		_sys_values[d[0]] = val
		v.add_child(h)
	var help := HBoxContainer.new()
	var hl := _lbl("AYUDA Y SOPORTE", 24)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.add_child(hl)
	var contact := _btn("CONTACTAR", 22, 186, 50)
	contact.pressed.connect(_contact)
	help.add_child(contact)
	v.add_child(help)
	var terms := _lbl("TÉRMINOS DE SERVICIO / POLÍTICA DE PRIVACIDAD", 24)
	terms.autowrap_mode = TextServer.AUTOWRAP_WORD
	terms.custom_minimum_size.x = 520
	v.add_child(terms)
	var rrow := HBoxContainer.new()
	rrow.alignment = BoxContainer.ALIGNMENT_END
	var read := _btn("LEER", 22, 186, 50)
	read.pressed.connect(func(): _legal.visible = true)
	rrow.add_child(read)
	v.add_child(rrow)
	# Redes sociales del estudio
	v.add_child(_lbl("SÍGUENOS", 26, PAPER.darkened(0.08)))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	for r in DB.info.get("redes", []):
		var b := _btn(str(r.get("name", "")).to_upper(), 19, 122, 48)
		var url := str(r.get("url", ""))
		var sname := str(r.get("name", ""))
		b.pressed.connect(func(): _open_social(sname, url))
		grid.add_child(b)
		controls["rrss_" + str(r.get("id", ""))] = b
	v.add_child(grid)


func _refresh_system() -> void:
	var ver := str(ProjectSettings.get_setting("application/config/version", "0.1"))
	_sys_values["version"].text = "v%s Beta" % ver
	_sys_values["server"].text = str(DB.info.get("server", "Local"))
	_sys_values["access"].text = access_text(SFX.previous_access)


## "Hace 5 min", "Hace 2 h", "Hace 3 días" o "Primera vez".
static func access_text(t: float) -> String:
	if t <= 0.0:
		return "Primera vez"
	var s := maxf(Time.get_unix_time_from_system() - t, 0.0)
	if s < 60.0:
		return "Hace un momento"
	if s < 3600.0:
		return "Hace %d min" % int(s / 60.0)
	if s < 86400.0:
		return "Hace %d h" % int(s / 3600.0)
	var d := int(s / 86400.0)
	return "Hace %d día%s" % [d, "" if d == 1 else "s"]


func _contact() -> void:
	var mail := str(DB.info.get("support_email", ""))
	if mail == "":
		GS.message.emit("Soporte: próximamente. Tu ID es %s" % SFX.settings["player_id"])
		return
	OS.shell_open("mailto:%s?subject=Supervival%%20%s" % [mail, str(SFX.settings["player_id"]).uri_encode()])


func _open_social(sname: String, url: String) -> void:
	if url == "":
		GS.message.emit("%s de Lost Anarchy Games: próximamente" % sname)
		return
	OS.shell_open(url)


func _build_legal() -> void:
	_legal = PanelContainer.new()
	_legal.position = Vector2(120, 90)
	_legal.size = Vector2(1040, 600)
	var sb := _box(Color(0.08, 0.07, 0.055, 0.98), ORANGE.darkened(0.2), 18, 2)
	sb.set_content_margin_all(26)
	_legal.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_legal.add_child(v)
	var h := HBoxContainer.new()
	var t := _lbl("TÉRMINOS Y PRIVACIDAD", 30, PAPER)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var x := _btn("X", 26, 54, 50)
	x.pressed.connect(func(): _legal.visible = false)
	h.add_child(x)
	v.add_child(h)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(980, 490)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := _lbl(str(DB.info.get("legal", "")), 21, PAPER, false)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.custom_minimum_size.x = 960
	sc.add_child(body)
	v.add_child(sc)
	_legal.visible = false
	add_child(_legal)


# ------------------------------------------------------------- lista derecha

func _build_right() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(628, 100)
	panel.size = Vector2(626, 600)
	var sb := _box(PANEL_BG, Color("3d3629"), 20, 2)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(590, 446)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	sc.add_child(_list)
	var sep := ColorRect.new()
	sep.color = Color("3d3629")
	sep.custom_minimum_size = Vector2(0, 2)
	v.add_child(sep)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 20)
	var out := _btn("CERRAR SESIÓN", 30, 340, 88, true)
	out.icon = load("res://assets/icons/ajustes/puerta.png")
	out.expand_icon = false
	out.add_theme_constant_override("icon_max_width", 44)
	out.add_theme_constant_override("h_separation", 14)
	out.pressed.connect(_logout)
	bottom.add_child(out)
	controls["logout"] = out
	_wipe_btn = _btn("BORRAR\nDATOS", 22, 210, 88)
	_wipe_btn.icon = load("res://assets/icons/ajustes/papelera.png")
	_wipe_btn.add_theme_constant_override("icon_max_width", 38)
	_wipe_btn.add_theme_constant_override("h_separation", 12)
	_wipe_btn.add_theme_color_override("font_color", Color("cfc6b2"))
	_wipe_btn.pressed.connect(_wipe)
	bottom.add_child(_wipe_btn)
	controls["wipe"] = _wipe_btn
	v.add_child(bottom)


## Guarda y cierra el juego (todavía no hay cuentas en línea).
func _logout() -> void:
	GS.message.emit("Partida guardada. ¡Hasta pronto!")
	if world and world.has_method("save"):
		world.save()
	if not GS.testing:
		get_tree().quit()


## Dos toques: el primero avisa, el segundo borra la partida y empieza otra.
func _wipe() -> void:
	if _wipe_btn.text.begins_with("¿SEGURO"):
		visible = false
		new_game_requested.emit()
	else:
		_wipe_btn.text = "¿SEGURO?\nTOCA OTRA VEZ"


func _fill_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	controls.erase("music")
	controls.erase("sfx")
	match tab:
		"general":
			_id_row()
			_language_row()
			_toggle_row("Notificaciones", "notifications")
			_toggle_row("Vibración al recibir golpes", "vibration")
			_account_row()
			_option_row("Calidad gráfica", "quality", QUALITY)
			_slider_row("Distancia de la cámara", "zoom", 0.55, 1.3)
			_slider_row("Volumen música", "music")
			_slider_row("Volumen efectos", "sfx")
			_look_row()
		"graficos":
			_option_row("Calidad gráfica", "quality", QUALITY)
			_slider_row("Distancia de la cámara", "zoom", 0.55, 1.3)
			_toggle_row("Sombras", "shadows")
			_option_row("Límite de FPS", "fps", [30, 60])
			_slider_row("Resolución", "render_scale", 0.5, 1.0)
			_slider_row("Brillo", "brightness", 0.6, 1.4)
			_toggle_row("Números de daño", "damage_numbers")
			_toggle_row("Minimapa", "minimap")
			_toggle_row("Mostrar FPS", "show_fps")
		"audio":
			_toggle_row("Silenciar todo", "mute")
			_slider_row("Volumen general", "master")
			_slider_row("Volumen música", "music")
			_slider_row("Volumen efectos", "sfx")
			_slider_row("Volumen ambiente", "ambience")


## Se aplica al momento pero no se guarda hasta pulsar GUARDAR.
func _change(key: String, value: Variant) -> void:
	SFX.settings[key] = value
	SFX.apply()
	apply_graphics(world)
	_set_dirty(true)


func _id_row() -> void:
	var h := _hrow("ID de jugador", true)
	var id := _lbl(str(SFX.settings["player_id"]), 21, INK)
	id.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(id)
	var copy := _btn("COPIAR", 22, 120, 48)
	copy.add_theme_stylebox_override("normal", _box(Color("2a2620"), Color("2a2620"), 12, 2))
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(str(SFX.settings["player_id"]))
		GS.message.emit("ID copiado"))
	h.add_child(copy)
	controls["copy_id"] = copy


func _language_row() -> void:
	var h := _hrow("Idioma")
	var o := _dropdown(["Español"])
	o.add_item("English (próximamente)")
	o.set_item_disabled(1, true)
	o.select(0)
	h.add_child(o)
	controls["language"] = o


func _account_row() -> void:
	var p := _row()
	var h := HBoxContainer.new()
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", -2)
	col.add_child(_lbl("CUENTA VINCULADA", 23))
	col.add_child(_lbl("Google Play Games · sin vincular", 18, PAPER.darkened(0.15)))
	h.add_child(col)
	var b := _btn("GESTIONAR", 22, 150, 50)
	b.pressed.connect(func(): GS.message.emit("La vinculación llegará con la versión de Google Play"))
	h.add_child(b)
	p.add_child(h)
	_list.add_child(p)


func _look_row() -> void:
	var h := _hrow("Aspecto del superviviente")
	var b := _btn("EDITAR", 22, 150, 50)
	b.pressed.connect(func():
		visible = false
		edit_look_requested.emit())
	h.add_child(b)


func _dropdown(items: Array) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(250, 50)
	o.focus_mode = Control.FOCUS_NONE
	o.alignment = HORIZONTAL_ALIGNMENT_CENTER
	o.add_theme_font_override("font", _cond)
	o.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed"]:
		o.add_theme_stylebox_override(st, _box(Color(0.1, 0.09, 0.07, 0.95), ROW_LINE, 12, 2))
	o.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		o.add_theme_color_override(k, PAPER)
	for it in items:
		o.add_item(str(it).to_upper())
	return o


func _option_row(title: String, key: String, values: Array) -> void:
	var h := _hrow(title)
	var o := _dropdown(values.map(func(x): return str(x) if typeof(x) != TYPE_STRING else x))
	o.select(maxi(values.find(SFX.settings[key]), 0) if typeof(values[0]) == TYPE_STRING else maxi(values.find(int(SFX.settings[key])), 0))
	o.item_selected.connect(func(i: int): _change(key, values[i]))
	h.add_child(o)
	controls[key] = o


func _toggle_row(title: String, key: String) -> void:
	var h := _hrow(title)
	var state := _lbl("", 22, PAPER)
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(state)
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(64, 36)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)
	b.button_pressed = bool(SFX.settings[key])
	state.text = "ON" if b.button_pressed else "OFF"
	b.draw.connect(func():
		var r := b.size.y / 2.0
		var on := b.button_pressed
		b.draw_circle(Vector2(r, r), r, Color("4a4436"))
		b.draw_circle(Vector2(b.size.x - r, r), r, Color("4a4436"))
		b.draw_rect(Rect2(r, 0, b.size.x - 2 * r, b.size.y), Color("4a4436"))
		var kx := b.size.x - r if on else r
		b.draw_circle(Vector2(kx, r), r - 4.0, ORANGE if on else Color("8a8070")))
	b.toggled.connect(func(on: bool):
		state.text = "ON" if on else "OFF"
		b.queue_redraw()
		_change(key, on))
	h.add_child(b)
	controls[key] = b


func _slider_row(title: String, key: String, lo := 0.0, hi := 1.0) -> void:
	var p := _row()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(_lbl(title.to_upper(), 23))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 0.05
	sl.value = float(SFX.settings[key])
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(0, 36)
	sl.focus_mode = Control.FOCUS_NONE
	var track := _box(Color(0.08, 0.07, 0.055), ROW_LINE, 8, 1)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	sl.add_theme_stylebox_override("slider", track)
	var fill := _box(ORANGE, ORANGE, 8, 0)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	sl.add_theme_icon_override("grabber", _knob)
	sl.add_theme_icon_override("grabber_highlight", _knob)
	h.add_child(sl)
	var pct := _lbl("", 24, PAPER)
	pct.custom_minimum_size.x = 70
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.text = "%d%%" % roundi(sl.value * 100.0)
	h.add_child(pct)
	sl.value_changed.connect(func(val: float):
		pct.text = "%d%%" % roundi(val * 100.0)
		_change(key, val))
	v.add_child(h)
	p.add_child(v)
	_list.add_child(p)
	controls[key] = sl


# --------------------------------------------------------------- gráficos

## Aplica los ajustes de gráficos al mundo (sombras, antialias, resolución, FPS, brillo, minimapa).
static func apply_graphics(w: Node3D) -> void:
	var s: Dictionary = SFX.settings
	var q := str(s.get("quality", "medio"))
	Engine.max_fps = int(s.get("fps", 60))
	if w == null or not is_instance_valid(w) or not w.is_inside_tree():
		return
	var vp := w.get_viewport()
	vp.msaa_3d = Viewport.MSAA_DISABLED if q == "bajo" else (Viewport.MSAA_2X if q == "medio" else Viewport.MSAA_4X)
	vp.scaling_3d_scale = clampf(float(s.get("render_scale", 1.0)), 0.5, 1.0)
	if w.get("_sun"):
		w._sun.shadow_enabled = bool(s.get("shadows", true)) and q != "bajo"
	if w.get("_env"):
		var env: Environment = w._env
		env.adjustment_enabled = true
		env.adjustment_brightness = float(s.get("brightness", 1.0))
	if w.get("hud") and w.hud.minimap:
		w.hud.minimap.visible = bool(s.get("minimap", true))
		w.hud.minimap.update_every = 5 if q == "bajo" else (3 if q == "medio" else 2)
	if w.get("hud") and w.hud.get("fps_label"):
		w.hud.fps_label.visible = bool(s.get("show_fps", false))
