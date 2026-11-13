extends CanvasLayer
## Interfaz: barras de vida/comida/agua, joystick, botón de acción,
## mochila, fabricación a mano, construcción, estaciones y cofres.
## Todo creado por código.

signal build_selected(mode: String, id: String)   # mode: place | upgrade | demolish
signal build_action(action: String)               # rotate | confirm | exit
signal travel_requested(map_id: String)

const LEVEL_COLORS := {
	"hogar": Color("e8d36a"), "verde": Color("5fbf4a"), "amarilla": Color("e6b83a"),
	"roja": Color("d9443c"), "radiactiva": Color("a35ee0"), "segura": Color("4aa3e0"),
}
const LEVEL_NAMES := {
	"hogar": "Tu refugio", "verde": "Peligro bajo", "amarilla": "Peligro medio",
	"roja": "Peligro alto", "radiactiva": "Radiación: solo en grupo", "segura": "Zona segura (supervivientes)",
}

const JoystickScript := preload("res://scripts/ui/joystick.gd")
const TouchButtonScript := preload("res://scripts/ui/touch_button.gd")
const InventoryScript := preload("res://scripts/ui/inventory_screen.gd")

var joystick: Control
var action_button: Control
var _bars: Dictionary = {}
var _msg: Label
var _msg_timer := 0.0
var _hand_label: Label
var _death: Label
var _inv_panel: Control
var inv_btn: Button
var crouch_button: Control
var _clock_icon: TextureRect
var _clock_label: Label
var _rain_icon: TextureRect
var _craft_panel: PanelContainer
var _craft_list: VBoxContainer
var _root: Control
var _build_panel: PanelContainer
var _build_list: VBoxContainer
var _build_bar: PanelContainer
var _build_info: Label
var _build_rotate: Button
var _build_confirm: Button
var _station_panel: PanelContainer
var _station_title: Label
var _station_job: Label
var _station_bar: ProgressBar
var _station_collect: Button
var _station_list: VBoxContainer
var _chest_panel: PanelContainer
var _chest_title: Label
var _chest_grid: GridContainer
var _chest_bag_grid: GridContainer
var station: Node3D = null       # estación o cofre abierto
var _station_refresh := 0.0
var location := "refugio"
var _map_panel: PanelContainer
var _map_area: Control
var _map_info: Label
var _map_travel: Button
var _map_selected := ""
var _status: Label
var build_btn: Button
var _gym_panel: PanelContainer
var _gym_info: Label
var _gym_rows: VBoxContainer


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 24
	_root.theme = th
	add_child(_root)

	_build_bars()
	_build_controls()
	_build_inventory()
	_build_crafting()
	_build_build_menu()
	_build_build_bar()
	_build_station_panel()
	_build_chest_panel()
	_build_map_panel()
	_build_gym_panel()
	add_to_group("hud")

	_msg = Label.new()
	_msg.anchor_left = 0.5
	_msg.anchor_right = 0.5
	_msg.offset_left = -320
	_msg.offset_right = 320
	_msg.offset_top = 110
	_msg.offset_bottom = 150
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_color_override("font_outline_color", Color.BLACK)
	_msg.add_theme_constant_override("outline_size", 6)
	_root.add_child(_msg)

	_death = Label.new()
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death.text = "HAS MUERTO\nTu mochila se ha quedado donde caíste"
	_death.add_theme_font_size_override("font_size", 40)
	_death.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_death.add_theme_color_override("font_outline_color", Color.BLACK)
	_death.add_theme_constant_override("outline_size", 10)
	_death.visible = false
	_root.add_child(_death)

	# El inventario ocupa toda la pantalla: va encima de todo (salvo los avisos).
	_root.move_child(_inv_panel, -1)
	_root.move_child(_msg, -1)
	GS.stats_changed.connect(_refresh_stats)
	GS.inventory_changed.connect(_refresh_inventory)
	GS.message.connect(show_message)
	_refresh_stats()
	_refresh_inventory()


# ------------------------------------------------------------------ barras

func _build_bars() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(20, 16)
	box.add_theme_constant_override("separation", 6)
	_root.add_child(box)
	for def in [["health", "Vida", Color("d9443c")], ["food", "Comida", Color("e09a3a")], ["water", "Agua", Color("3a8fe0")], ["stamina", "Aguante", Color("b5c43a")]]:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(260, 26)
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = def[2]
		fill.set_corner_radius_all(6)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.5)
		bg.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bg)
		var lbl := Label.new()
		lbl.text = def[1]
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.position = Vector2(8, 0)
		bar.add_child(lbl)
		box.add_child(bar)
		_bars[def[0]] = bar
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Color("8fe36a"))
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 5)
	box.add_child(_status)
	_hand_label = Label.new()
	_hand_label.add_theme_font_size_override("font_size", 20)
	_hand_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hand_label.add_theme_constant_override("outline_size", 5)
	box.add_child(_hand_label)


func _refresh_stats() -> void:
	var hb: ProgressBar = _bars["health"]
	var fb: ProgressBar = _bars["food"]
	var wb: ProgressBar = _bars["water"]
	hb.max_value = float(DB.bal("max_health", 100))
	fb.max_value = float(DB.bal("max_food", 100))
	wb.max_value = float(DB.bal("max_water", 100))
	hb.value = GS.health
	fb.value = GS.food
	wb.value = GS.water
	_refresh_stamina()


func _refresh_stamina() -> void:
	var sb: ProgressBar = _bars["stamina"]
	sb.max_value = GS.max_stamina()
	sb.value = GS.stamina


# --------------------------------------------------------------- controles

func _build_controls() -> void:
	joystick = JoystickScript.new()
	joystick.anchor_left = 0.0
	joystick.anchor_right = 0.45
	joystick.anchor_top = 0.35
	joystick.anchor_bottom = 1.0
	_root.add_child(joystick)

	action_button = TouchButtonScript.new()
	action_button.anchor_left = 1.0
	action_button.anchor_right = 1.0
	action_button.anchor_top = 1.0
	action_button.anchor_bottom = 1.0
	action_button.offset_left = -230
	action_button.offset_right = -40
	action_button.offset_top = -230
	action_button.offset_bottom = -40
	_root.add_child(action_button)

	# Agacharse: más lento y silencioso; golpe por sorpresa x3
	crouch_button = TouchButtonScript.new()
	crouch_button.anchor_left = 1.0
	crouch_button.anchor_right = 1.0
	crouch_button.anchor_top = 1.0
	crouch_button.anchor_bottom = 1.0
	crouch_button.offset_left = -360
	crouch_button.offset_right = -250
	crouch_button.offset_top = -140
	crouch_button.offset_bottom = -30
	crouch_button.base_color = Color(0.45, 0.5, 0.4)
	crouch_button.set_text("Agachar")
	crouch_button.pressed_changed.connect(func(on: bool):
		if on:
			toggle_crouch())
	_root.add_child(crouch_button)

	# Reloj: sol o luna, hora y lluvia
	var clock := PanelContainer.new()
	clock.anchor_left = 0.5
	clock.anchor_right = 0.5
	clock.offset_left = -95
	clock.offset_right = 95
	clock.offset_top = 10
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.055, 0.07, 0.047, 0.7)
	csb.set_corner_radius_all(22)
	csb.content_margin_left = 12
	csb.content_margin_right = 16
	csb.content_margin_top = 4
	csb.content_margin_bottom = 4
	clock.add_theme_stylebox_override("panel", csb)
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ch := HBoxContainer.new()
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_theme_constant_override("separation", 8)
	clock.add_child(ch)
	_clock_icon = TextureRect.new()
	_clock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clock_icon.custom_minimum_size = Vector2(36, 36)
	ch.add_child(_clock_icon)
	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 26)
	ch.add_child(_clock_label)
	_rain_icon = TextureRect.new()
	_rain_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rain_icon.custom_minimum_size = Vector2(34, 34)
	_rain_icon.texture = DB.ui_icon("lluvia")
	ch.add_child(_rain_icon)
	_root.add_child(clock)

	var side := VBoxContainer.new()
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.offset_left = -200
	side.offset_right = -20
	side.offset_top = 20
	side.add_theme_constant_override("separation", 10)
	_root.add_child(side)
	inv_btn = _make_inv_button()
	side.add_child(inv_btn)
	var craft_btn := _big_button("Fabricar")
	craft_btn.pressed.connect(func(): _toggle(_craft_panel))
	side.add_child(craft_btn)
	build_btn = _big_button("Construir")
	build_btn.pressed.connect(func(): _toggle(_build_panel))
	side.add_child(build_btn)
	var map_btn := _big_button("Mapa")
	map_btn.pressed.connect(func():
		_toggle(_map_panel)
		_refresh_map())
	side.add_child(map_btn)


func _big_button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(180, 64)
	return b


func set_action(label: String) -> void:
	if label == "":
		action_button.set_text("Acción")
		action_button.set_enabled(false)
	else:
		action_button.set_text(label)
		action_button.set_enabled(true)


func _toggle(panel: Control) -> void:
	var opening := not panel.visible
	close_panels()
	panel.visible = opening
	if opening:
		_refresh_inventory()


func close_panels() -> void:
	for p in [_inv_panel, _craft_panel, _build_panel, _station_panel, _chest_panel, _map_panel, _gym_panel]:
		if p:
			p.visible = false
	station = null


func any_panel_open() -> bool:
	for p in [_inv_panel, _craft_panel, _build_panel, _station_panel, _chest_panel, _map_panel, _gym_panel]:
		if p and p.visible:
			return true
	return false


func show_message(t: String) -> void:
	_msg.text = t
	_msg.modulate.a = 1.0
	_msg_timer = 2.0


func show_death(v: bool) -> void:
	_death.visible = v


func _process(delta: float) -> void:
	_refresh_stamina()
	var inv_open := _inv_panel != null and _inv_panel.visible
	joystick.visible = not inv_open
	action_button.visible = not inv_open
	crouch_button.visible = not inv_open
	if _gym_panel and _gym_panel.visible:
		_station_refresh -= delta
		if _station_refresh <= 0.0:
			_station_refresh = 0.5
			_refresh_gym()
	if _station_panel and _station_panel.visible:
		_station_refresh -= delta
		if _station_refresh <= 0.0:
			_station_refresh = 0.25
			_refresh_station_job()
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer < 0.5:
			_msg.modulate.a = maxf(_msg_timer / 0.5, 0.0)


# ---------------------------------------------------------------- mochila

func _panel(title: String, half := Vector2(390, 280)) -> Array:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -half.x
	panel.offset_right = half.x
	panel.offset_top = -half.y
	panel.offset_bottom = half.y
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.1, 0.94)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	var t := Label.new()
	t.text = title
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("font_size", 30)
	head.add_child(t)
	var close := Button.new()
	close.text = "  X  "
	close.pressed.connect(func():
		panel.visible = false
		if panel == _station_panel or panel == _chest_panel or panel == _gym_panel:
			station = null)
	head.add_child(close)
	v.add_child(head)
	_root.add_child(panel)
	return [panel, v]


func _build_inventory() -> void:
	_inv_panel = InventoryScript.new()
	_root.add_child(_inv_panel)


func _refresh_inventory() -> void:
	# Mano
	if GS.hand == null:
		_hand_label.text = "Mano: puños"
	else:
		var h: Dictionary = GS.hand
		var dur := ""
		if h.has("dur"):
			dur = " (%d/%d)" % [int(h["dur"]), int(DB.item(str(h["id"])).get("durability", 0))]
		_hand_label.text = "Mano: %s%s" % [DB.item_name(str(h["id"])), dur]
	if inv_btn:
		inv_btn.queue_redraw()
	if _inv_panel == null:
		return
	if _inv_panel.visible:
		_inv_panel.refresh()
	_refresh_crafting()
	_refresh_build_menu()
	if _chest_panel and _chest_panel.visible:
		_refresh_chest()
	if _station_panel and _station_panel.visible:
		_refresh_station()


func set_clock(text: String, night: bool, rain: bool) -> void:
	_clock_label.text = text
	_clock_icon.texture = DB.ui_icon("luna" if night else "sol")
	_rain_icon.visible = rain


func toggle_crouch() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	p.set_crouch(not p.crouching)
	crouch_button.base_color = Color(0.42, 0.62, 0.3) if p.crouching else Color(0.45, 0.5, 0.4)
	crouch_button.set_text("De pie" if p.crouching else "Agachar")
	crouch_button.queue_redraw()


## Elige una casilla del inventario (lo usan las herramientas de capturas).
func _select(i: int) -> void:
	_inv_panel.select_slot(i)


## Botón del HUD: icono de mochila con un anillo que se llena con la carga.
func _make_inv_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 96)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.tooltip_text = "Inventario"
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	var ic := TextureRect.new()
	ic.texture = DB.item_icon("mochila")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(19, 17)
	ic.size = Vector2(58, 58)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.draw.connect(func():
		var c := b.size / 2.0
		var r := minf(c.x, c.y) - 3.0
		b.draw_circle(c, r + 1.0, Color(0.055, 0.07, 0.047, 0.88))
		b.draw_arc(c, r - 3.0, 0.0, TAU, 64, Color(0.91, 0.86, 0.72, 0.2), 6.0, true)
		var f := GS.load_ratio()
		if f > 0.0:
			b.draw_arc(c, r - 3.0, -PI / 2.0, -PI / 2.0 + TAU * f, 64, Color("e8b84a") if f < 1.0 else Color("d9534a"), 6.0, true))
	b.pressed.connect(func(): _toggle(_inv_panel))
	return b


# ------------------------------------------------------------- fabricación

func _build_crafting() -> void:
	var parts := _panel("Fabricar")
	_craft_panel = parts[0]
	var v: VBoxContainer = parts[1]
	var hint := Label.new()
	hint.text = "A mano. Las demás recetas están en las estaciones del refugio."
	hint.add_theme_font_size_override("font_size", 18)
	v.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(720, 380)
	v.add_child(scroll)
	_craft_list = VBoxContainer.new()
	_craft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_craft_list)


func _refresh_crafting() -> void:
	if _craft_list == null:
		return
	for c in _craft_list.get_children():
		c.queue_free()
	for r in DB.recipes_for(""):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_row_icon(str(r["result"])))
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		lbl.custom_minimum_size.x = 100
		lbl.add_theme_font_size_override("font_size", 20)
		var cost: Dictionary = r.get("cost", {})
		var parts := PackedStringArray()
		for id in cost:
			parts.append("%s %d/%d" % [DB.item_name(str(id)), GS.count(str(id)), int(cost[id])])
		lbl.text = "%s\n   %s" % [DB.item_name(str(r["result"])), ", ".join(parts)]
		row.add_child(lbl)
		var b := Button.new()
		b.text = "Fabricar"
		b.custom_minimum_size = Vector2(150, 60)
		b.disabled = not GS.can_craft(r)
		var rid := str(r["id"])
		b.pressed.connect(func(): GS.craft(rid))
		row.add_child(b)
		_craft_list.add_child(row)


# ------------------------------------------------------------- construir

func _build_build_menu() -> void:
	var parts := _panel("Construir")
	_build_panel = parts[0]
	var v: VBoxContainer = parts[1]
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	var up := Button.new()
	up.text = "Mejorar estructura"
	up.pressed.connect(func(): _pick_build("upgrade", ""))
	tools.add_child(up)
	var dem := Button.new()
	dem.text = "Desmontar"
	dem.pressed.connect(func(): _pick_build("demolish", ""))
	tools.add_child(dem)
	v.add_child(tools)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(720, 380)
	v.add_child(scroll)
	_build_list = VBoxContainer.new()
	_build_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_build_list)


func _refresh_build_menu() -> void:
	if _build_list == null:
		return
	for c in _build_list.get_children():
		c.queue_free()
	_section(_build_list, "Estructuras")
	for id in DB.structures:
		_build_row(str(id), str(DB.structure_tier(str(id), 0).get("name", id)), DB.structure_tier(str(id), 0).get("cost", {}))
	_section(_build_list, "Estaciones y almacenaje")
	for id in DB.stations:
		var d: Dictionary = DB.stations[id]
		_build_row(str(id), "%s — %s" % [d.get("name", id), d.get("desc", "")], DB.station_level(str(id), 1).get("cost", {}))


func _section(box: VBoxContainer, title: String) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	box.add_child(l)


func _build_row(id: String, title: String, cost: Dictionary) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.text = "%s\n   %s" % [title, DB.cost_text(cost)]
	row.add_child(lbl)
	var b := Button.new()
	b.text = "Colocar"
	b.custom_minimum_size = Vector2(140, 56)
	b.disabled = not GS.has_cost(cost)
	b.pressed.connect(func(): _pick_build("place", id))
	row.add_child(b)
	_build_list.add_child(row)


func _pick_build(mode: String, id: String) -> void:
	close_panels()
	build_selected.emit(mode, id)


func _build_build_bar() -> void:
	_build_bar = PanelContainer.new()
	_build_bar.anchor_left = 0.5
	_build_bar.anchor_right = 0.5
	_build_bar.anchor_top = 1.0
	_build_bar.anchor_bottom = 1.0
	_build_bar.offset_left = -330
	_build_bar.offset_right = 330
	_build_bar.offset_top = -150
	_build_bar.offset_bottom = -12
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.08, 0.85)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	_build_bar.add_theme_stylebox_override("panel", style)
	_build_bar.visible = false
	var v := VBoxContainer.new()
	_build_bar.add_child(v)
	_build_info = Label.new()
	_build_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_build_info.add_theme_font_size_override("font_size", 19)
	v.add_child(_build_info)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	_build_rotate = Button.new()
	_build_rotate.text = "Girar"
	_build_rotate.custom_minimum_size = Vector2(140, 56)
	_build_rotate.pressed.connect(func(): build_action.emit("rotate"))
	h.add_child(_build_rotate)
	_build_confirm = Button.new()
	_build_confirm.text = "Colocar"
	_build_confirm.custom_minimum_size = Vector2(170, 56)
	_build_confirm.pressed.connect(func(): build_action.emit("confirm"))
	h.add_child(_build_confirm)
	var ex := Button.new()
	ex.text = "Salir"
	ex.custom_minimum_size = Vector2(140, 56)
	ex.pressed.connect(func(): build_action.emit("exit"))
	h.add_child(ex)
	_root.add_child(_build_bar)


## La llama el mundo cada frame mientras se está construyendo.
func set_build_info(visible_bar: bool, mode: String, text: String, ok: bool) -> void:
	_build_bar.visible = visible_bar
	if not visible_bar:
		return
	_build_info.text = text
	_build_info.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75) if ok else Color(1.0, 0.6, 0.55))
	_build_rotate.visible = mode == "place"
	_build_confirm.disabled = not ok
	match mode:
		"place": _build_confirm.text = "Colocar"
		"upgrade": _build_confirm.text = "Mejorar"
		"demolish": _build_confirm.text = "Desmontar"


# -------------------------------------------------------------- estaciones

func open_station(s: Node3D) -> void:
	close_panels()
	station = s
	if s.is_gym():
		_gym_panel.visible = true
		_refresh_gym()
	elif s.is_chest():
		_chest_panel.visible = true
		_refresh_chest()
	else:
		_station_panel.visible = true
		_refresh_station()


func _build_station_panel() -> void:
	var parts := _panel("Estación")
	_station_panel = parts[0]
	var v: VBoxContainer = parts[1]
	_station_title = (v.get_child(0) as HBoxContainer).get_child(0) as Label
	_station_job = Label.new()
	_station_job.add_theme_font_size_override("font_size", 20)
	v.add_child(_station_job)
	var h := HBoxContainer.new()
	_station_bar = ProgressBar.new()
	_station_bar.custom_minimum_size = Vector2(520, 30)
	_station_bar.max_value = 1.0
	_station_bar.show_percentage = false
	_station_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("6fbf4a")
	fill.set_corner_radius_all(6)
	_station_bar.add_theme_stylebox_override("fill", fill)
	h.add_child(_station_bar)
	_station_collect = Button.new()
	_station_collect.text = "Recoger"
	_station_collect.custom_minimum_size = Vector2(160, 52)
	_station_collect.pressed.connect(func():
		if station and station.collect():
			_refresh_station())
	h.add_child(_station_collect)
	v.add_child(h)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(720, 330)
	v.add_child(scroll)
	_station_list = VBoxContainer.new()
	_station_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_station_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_station_list)


func _refresh_station() -> void:
	if station == null or not is_instance_valid(station) or station.is_chest():
		return
	_station_title.text = station.display_name()
	for c in _station_list.get_children():
		c.queue_free()
	for r in DB.recipes_for(station.id):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_row_icon(str(r["result"])))
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		lbl.custom_minimum_size.x = 100
		lbl.add_theme_font_size_override("font_size", 19)
		var unlocked: bool = station.recipe_unlocked(r)
		var head := "%s  (%ds)" % [DB.item_name(str(r["result"])), int(r.get("time", 0))]
		var rd := DB.item(str(r["result"]))
		if rd.has("armor"):
			head += "  · Defensa +%d%%" % int(rd["armor"])
		if rd.has("bag_slots"):
			head += "  · +%d huecos" % int(rd["bag_slots"])
		if not unlocked:
			head += "  — requiere nivel %d" % int(r.get("level", 1))
		lbl.text = "%s\n   %s" % [head, DB.cost_text(r.get("cost", {}))]
		if not unlocked:
			lbl.modulate = Color(1, 1, 1, 0.5)
		row.add_child(lbl)
		var b := Button.new()
		b.text = "Fabricar"
		b.custom_minimum_size = Vector2(150, 56)
		b.disabled = not unlocked or not station.job.is_empty() or not GS.can_craft(r)
		var rid := str(r["id"])
		b.pressed.connect(func():
			var why: String = station.start(rid)
			if why != "":
				show_message(why)
			_refresh_station())
		row.add_child(b)
		_station_list.add_child(row)
	_add_repair_rows()
	_refresh_station_job()


## Banco de trabajo y mesa de costura: reparar lo gastado.
func _add_repair_rows() -> void:
	if station.id != "banco_trabajo" and station.id != "mesa_costura":
		return
	var head := Label.new()
	head.text = "Reparar" + ("  (herramientas y armas)" if station.id == "banco_trabajo" else "  (ropa)")
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Color("e8b84a"))
	_station_list.add_child(head)
	var items: Array = GS.damaged_items(station.id)
	if items.is_empty():
		var none := Label.new()
		none.text = "   No hay nada gastado."
		none.add_theme_font_size_override("font_size", 18)
		none.modulate = Color(1, 1, 1, 0.6)
		_station_list.add_child(none)
		return
	for ref in items:
		var it: Dictionary = ref["item"]
		var id := str(it["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_row_icon(id))
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		lbl.custom_minimum_size.x = 100
		lbl.add_theme_font_size_override("font_size", 19)
		var mx := int(DB.item(id).get("durability", 1))
		var where := " (en la mano)" if ref["where"] == "hand" else (" (puesto)" if ref["where"] == "worn" else "")
		var cost := GS.repair_cost(it)
		lbl.text = "%s%s  · %d%%\n   %s" % [DB.item_name(id), where, roundi(100.0 * float(it["dur"]) / mx), DB.cost_text(cost)]
		row.add_child(lbl)
		var b := Button.new()
		b.text = "Reparar"
		b.custom_minimum_size = Vector2(150, 56)
		b.disabled = not GS.can_craft({"cost": cost})
		var r: Dictionary = ref
		b.pressed.connect(func():
			var why := GS.repair(r)
			if why != "":
				show_message(why)
			_refresh_station())
		row.add_child(b)
		_station_list.add_child(row)


func _refresh_station_job() -> void:
	if station == null or not is_instance_valid(station) or station.is_chest():
		return
	if station.job.is_empty():
		_station_job.text = "Libre. Elige qué fabricar."
		_station_bar.value = 0.0
		_station_collect.disabled = true
		return
	var nm := DB.item_name(str(DB.recipe(str(station.job["recipe"]))["result"]))
	if station.is_done():
		_station_job.text = "¡%s listo!" % nm
		_station_collect.disabled = false
	else:
		var t := int(ceil(station.time_left()))
		_station_job.text = "Fabricando %s — %d:%02d" % [nm, t / 60, t % 60]
		_station_collect.disabled = true
	_station_bar.value = station.progress()


# ---------------------------------------------------------------- gimnasio

func _build_gym_panel() -> void:
	var parts := _panel("Gimnasio")
	_gym_panel = parts[0]
	var v: VBoxContainer = parts[1]
	_gym_info = Label.new()
	_gym_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_gym_info.custom_minimum_size = Vector2(720, 0)
	_gym_info.add_theme_font_size_override("font_size", 19)
	v.add_child(_gym_info)
	_gym_rows = VBoxContainer.new()
	_gym_rows.add_theme_constant_override("separation", 14)
	v.add_child(_gym_rows)


func _refresh_gym() -> void:
	if station == null or not is_instance_valid(station) or not station.is_gym():
		return
	var title := (_gym_panel.get_child(0).get_child(0) as HBoxContainer).get_child(0) as Label
	title.text = station.display_name()
	var lv := DB.station_level("gimnasio", station.level)
	_gym_info.text = "Cada sesión cuesta %d de comida y %d de agua. Fuera del gimnasio también mejoras: golpear y talar da fuerza; correr con la mochila cargada da resistencia." % [int(DB.bal("train_food", 8)), int(DB.bal("train_water", 10))]
	for c in _gym_rows.get_children():
		c.queue_free()
	for def in [["fuerza", "Fuerza", "Pesas: más daño y cargas más sin ir lento."], ["resistencia", "Resistencia", "Saco de boxeo: más aguante y lo recuperas antes."]]:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		lbl.custom_minimum_size.x = 100
		lbl.add_theme_font_size_override("font_size", 20)
		var val := float(GS.physique[def[0]])
		lbl.text = "%s  %d%%\n   %s" % [def[1], roundi(val * 100.0), def[2]]
		row.add_child(lbl)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(160, 22)
		bar.max_value = 1.0
		bar.value = val
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("e8b84a")
		fill.set_corner_radius_all(6)
		var bgs := StyleBoxFlat.new()
		bgs.bg_color = Color(0, 0, 0, 0.45)
		bgs.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bgs)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 60)
		var wait := float(GS.train_ready.get(def[0], 0.0)) - GS.now()
		if wait > 0.0:
			b.text = "Descanso %ds" % ceili(wait)
			b.disabled = true
		else:
			b.text = "Entrenar +%d%%" % roundi(float(lv.get("gain", 0.03)) * (1.0 - val * 0.5) * 100.0)
			b.disabled = val >= 1.0
		var stat: String = def[0]
		b.pressed.connect(func(): train(stat))
		row.add_child(b)
		_gym_rows.add_child(row)


## Entrena en el gimnasio abierto. Devuelve "" si se pudo.
func train(stat: String) -> String:
	if station == null or not is_instance_valid(station) or not station.is_gym():
		return "No hay gimnasio"
	var why := GS.train(stat, station.level)
	if why != "":
		show_message(why)
		return why
	close_panels()
	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.start_training(float(DB.bal("train_seconds", 3.0)))
	return ""


# ------------------------------------------------------------------- cofre

func _build_chest_panel() -> void:
	var parts := _panel("Cofre", Vector2(560, 300))
	_chest_panel = parts[0]
	var v: VBoxContainer = parts[1]
	_chest_title = (v.get_child(0) as HBoxContainer).get_child(0) as Label
	var hint := Label.new()
	hint.text = "Toca un objeto para pasarlo de un lado a otro."
	hint.add_theme_font_size_override("font_size", 18)
	v.add_child(hint)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	v.add_child(h)
	var left := VBoxContainer.new()
	var lt := Label.new()
	lt.text = "Cofre"
	left.add_child(lt)
	_chest_grid = GridContainer.new()
	_chest_grid.columns = 7
	left.add_child(_chest_grid)
	h.add_child(left)
	var right := VBoxContainer.new()
	var rt := Label.new()
	rt.text = "Inventario"
	right.add_child(rt)
	_chest_bag_grid = GridContainer.new()
	_chest_bag_grid.columns = 7
	right.add_child(_chest_bag_grid)
	h.add_child(right)


func _slot_button(s: Variant) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	b.add_theme_font_size_override("font_size", 15)
	b.clip_text = true
	if s != null:
		var tex := DB.item_icon(str(s["id"]))
		if tex:
			b.icon = tex
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("icon_max_width", 46)
			b.tooltip_text = DB.item_name(str(s["id"]))
			if int(s["qty"]) > 1:
				var q := Label.new()
				q.text = str(int(s["qty"]))
				q.position = Vector2(30, 40)
				q.size = Vector2(30, 20)
				q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				q.add_theme_font_size_override("font_size", 15)
				q.add_theme_color_override("font_outline_color", Color.BLACK)
				q.add_theme_constant_override("outline_size", 4)
				q.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(q)
		else:
			b.text = DB.item_name(str(s["id"]))
	return b


## Icono pequeño para las filas de recetas.
func _row_icon(id: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = DB.item_icon(id)
	t.custom_minimum_size = Vector2(52, 52)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


func _refresh_chest() -> void:
	if station == null or not is_instance_valid(station) or not station.is_chest():
		return
	_chest_title.text = station.display_name()
	for c in _chest_grid.get_children():
		c.queue_free()
	for c in _chest_bag_grid.get_children():
		c.queue_free()
	for i in station.storage.size():
		var b := _slot_button(station.storage[i])
		b.pressed.connect(func(): station.chest_to_bag(i))
		_chest_grid.add_child(b)
	for i in GS.slots.size():
		var b := _slot_button(GS.slots[i])
		b.pressed.connect(func(): station.bag_to_chest(i))
		_chest_bag_grid.add_child(b)


# ------------------------------------------------------------------ estado

func set_status(t: String) -> void:
	if _status.text != t:
		_status.text = t


# ------------------------------------------------------------------- mapa
# Versión funcional: el diseño definitivo se elegirá entre las 3 propuestas.

func set_location(id: String) -> void:
	location = id
	# Solo se construye en el refugio.
	if build_btn:
		build_btn.visible = DB.maps.get(id, {}).get("base_half", 0) > 0


func _build_map_panel() -> void:
	var parts := _panel("Mapa del Valle", Vector2(600, 330))
	_map_panel = parts[0]
	var v: VBoxContainer = parts[1]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	_map_area = Control.new()
	_map_area.custom_minimum_size = Vector2(760, 540)
	_map_area.draw.connect(_draw_map)
	h.add_child(_map_area)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(380, 0)
	side.add_theme_constant_override("separation", 12)
	h.add_child(side)
	_map_info = Label.new()
	_map_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_map_info.custom_minimum_size = Vector2(380, 400)
	_map_info.add_theme_font_size_override("font_size", 20)
	side.add_child(_map_info)
	_map_travel = Button.new()
	_map_travel.text = "Viajar"
	_map_travel.custom_minimum_size = Vector2(200, 64)
	_map_travel.pressed.connect(func():
		if _map_selected != "":
			travel_requested.emit(_map_selected))
	side.add_child(_map_travel)


func _draw_map() -> void:
	var sz := _map_area.size
	_map_area.draw_rect(Rect2(Vector2.ZERO, sz), Color("2a3326"))
	# río y caminos de adorno
	var river := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		river.append(Vector2(t * sz.x, sz.y * (0.72 + 0.08 * sin(t * 7.0))))
	_map_area.draw_polyline(river, Color("3b6c8f"), 10.0, true)
	var home: Array = DB.world_map.get("refugio", {}).get("pos", [0.5, 0.5])
	var hp := Vector2(float(home[0]), float(home[1])) * sz
	for id in DB.world_map:
		var p: Array = DB.world_map[id]["pos"]
		_map_area.draw_dashed_line(hp, Vector2(float(p[0]), float(p[1])) * sz, Color(0.8, 0.75, 0.6, 0.25), 2.0, 8.0)


func _refresh_map() -> void:
	if _map_area == null:
		return
	for c in _map_area.get_children():
		c.queue_free()
	_map_area.queue_redraw()
	for id in DB.world_map:
		var d: Dictionary = DB.world_map[id]
		var p: Array = d["pos"]
		var b := Button.new()
		var playable := DB.maps.has(id)
		b.text = ("● " if id == location else "") + str(d["name"])
		b.add_theme_font_size_override("font_size", 15)
		var col: Color = LEVEL_COLORS.get(str(d.get("level", "verde")), Color.WHITE)
		var st := StyleBoxFlat.new()
		st.bg_color = col.darkened(0.45) if playable else Color(0.2, 0.2, 0.2, 0.85)
		st.border_color = col
		st.set_border_width_all(3 if id == _map_selected else 1)
		st.set_corner_radius_all(8)
		st.set_content_margin_all(6)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
		if not playable:
			b.modulate = Color(1, 1, 1, 0.6)
		var area := _map_area.custom_minimum_size
		var est_w := b.text.length() * 8.5 + 24.0
		var bp := Vector2(float(p[0]), float(p[1])) * area - Vector2(est_w / 2.0, 18)
		b.position = Vector2(clampf(bp.x, 4.0, area.x - est_w - 4.0), clampf(bp.y, 4.0, area.y - 44.0))
		var mid := str(id)
		b.pressed.connect(func(): _select_map(mid))
		_map_area.add_child(b)
	if _map_selected == "":
		_select_map(location)
	else:
		_update_map_info()


func _select_map(id: String) -> void:
	_map_selected = id
	_refresh_map()


func _update_map_info() -> void:
	var d: Dictionary = DB.world_map.get(_map_selected, {})
	var lvl := str(d.get("level", ""))
	var txt := "%s\n%s\n\n%s" % [d.get("name", ""), LEVEL_NAMES.get(lvl, ""), d.get("desc", "")]
	var can := false
	if _map_selected == location:
		txt += "\n\nEstás aquí."
	elif not DB.maps.has(_map_selected):
		txt += "\n\nPróximamente."
	else:
		var cost := DB.travel_cost(location, _map_selected)
		txt += "\n\nViaje: comida -%d, agua -%d" % [int(cost["food"]), int(cost["water"])]
		can = true
	_map_info.text = txt
	_map_travel.disabled = not can
