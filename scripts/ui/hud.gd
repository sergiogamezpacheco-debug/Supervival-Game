extends CanvasLayer
## Interfaz: barras de vida/comida/agua, joystick, botón de acción,
## mochila, fabricación a mano, construcción, estaciones y cofres.
## Todo creado por código.

signal build_selected(mode: String, id: String)   # mode: place | upgrade | demolish
signal build_action(action: String)               # rotate | confirm | exit
signal travel_requested(map_id: String)
signal edit_look_requested
signal new_game_requested

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
var level_badge: Button
var _xp_bar: ProgressBar
var _xp_label: Label
var _xp_pop: Label
var _levelup: PanelContainer
var _levelup_title: Label
var _levelup_text: Label
var _levels_panel: PanelContainer
var _levels_list: VBoxContainer
var minimap: Control
var _msg: Label
var _msg_timer := 0.0
var _pcts: Dictionary = {}
var _death: Label
var _inv_panel: Control
var inv_btn: Button
var crouch_button: Control
var dodge_button: Control
var settings_btn: Button
var _settings_panel: PanelContainer
var _newgame_btn: Button
var settings_controls: Dictionary = {}
var _clock_icon: TextureRect
var location_label: Label
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
var _map_panel: Control
var _map_area: TextureRect
var _map_route: Control
var _map_marks: Control
var _map_name: Label
var _map_level: Label
var map_buttons: Dictionary = {}
var _map_info: Label
var _map_travel: Button
var _map_selected := ""
var _status: Label
var build_btn: Button
var craft_btn: Button
var map_btn: Button
var action_icon := ""          # icono que muestra ahora el botón de acción
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
	_build_levels_panel()
	_build_levelup_banner()
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
	_root.move_child(_map_panel, -1)
	_root.move_child(_inv_panel, -1)
	_root.move_child(_levelup, -1)
	_root.move_child(_msg, -1)
	GS.stats_changed.connect(_refresh_stats)
	GS.inventory_changed.connect(_refresh_inventory)
	GS.message.connect(show_message)
	GS.xp_gained.connect(_on_xp)
	GS.leveled_up.connect(_on_level_up)
	_refresh_stats()
	_refresh_inventory()


# ------------------------------------------------------------------ barras

func _build_bars() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(20, 16)
	box.add_theme_constant_override("separation", 6)
	_root.add_child(box)
	# Nivel: insignia redonda con anillo de experiencia y barra fina con los puntos
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 8)
	level_badge = Button.new()
	level_badge.flat = true
	level_badge.custom_minimum_size = Vector2(56, 56)
	level_badge.focus_mode = Control.FOCUS_NONE
	level_badge.draw.connect(func():
		var c := level_badge.size / 2.0
		var r := minf(c.x, c.y) - 2.0
		level_badge.draw_circle(c, r, Color(0.055, 0.07, 0.047, 0.9))
		level_badge.draw_arc(c, r - 3.0, 0.0, TAU, 48, Color(0.91, 0.86, 0.72, 0.2), 5.0, true)
		level_badge.draw_arc(c, r - 3.0, -PI / 2.0, -PI / 2.0 + TAU * GS.xp_progress(), 48, Color("e8b84a"), 5.0, true)
		var f := level_badge.get_theme_default_font()
		var txt := str(GS.level)
		var fs := 24 if GS.level < 100 else 19
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		level_badge.draw_string(f, Vector2(c.x - w / 2.0, c.y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f3ead2")))
	level_badge.pressed.connect(open_levels)
	lrow.add_child(level_badge)
	var lcol := VBoxContainer.new()
	lcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lcol.add_theme_constant_override("separation", 2)
	_xp_label = Label.new()
	_xp_label.add_theme_font_size_override("font_size", 17)
	_xp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_xp_label.add_theme_constant_override("outline_size", 5)
	lcol.add_child(_xp_label)
	var xrow := HBoxContainer.new()
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(176, 10)
	_xp_bar.show_percentage = false
	var xf := StyleBoxFlat.new()
	xf.bg_color = Color("e8b84a")
	xf.set_corner_radius_all(4)
	var xb := StyleBoxFlat.new()
	xb.bg_color = Color(0, 0, 0, 0.5)
	xb.set_corner_radius_all(4)
	_xp_bar.add_theme_stylebox_override("fill", xf)
	_xp_bar.add_theme_stylebox_override("background", xb)
	xrow.add_child(_xp_bar)
	_xp_pop = Label.new()
	_xp_pop.add_theme_font_size_override("font_size", 17)
	_xp_pop.add_theme_color_override("font_color", Color("f6d27e"))
	_xp_pop.add_theme_color_override("font_outline_color", Color.BLACK)
	_xp_pop.add_theme_constant_override("outline_size", 5)
	_xp_pop.modulate.a = 0.0
	xrow.add_child(_xp_pop)
	lcol.add_child(xrow)
	lrow.add_child(lcol)
	box.add_child(lrow)
	for def in [["health", "vida", Color("d9443c")], ["food", "comida", Color("e09a3a")], ["water", "agua", Color("3a8fe0")], ["stamina", "energia", Color("d6c22e")]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var ic := TextureRect.new()
		ic.texture = DB.ui_icon(def[1])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.custom_minimum_size = Vector2(30, 30)
		row.add_child(ic)
		var bar := ProgressBar.new()
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(210, 22)
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = def[2]
		fill.set_corner_radius_all(6)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.5)
		bg.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bg)
		row.add_child(bar)
		var pct := Label.new()
		pct.custom_minimum_size = Vector2(44, 0)
		pct.add_theme_font_size_override("font_size", 19)
		pct.add_theme_color_override("font_outline_color", Color.BLACK)
		pct.add_theme_constant_override("outline_size", 5)
		row.add_child(pct)
		box.add_child(row)
		_bars[def[0]] = bar
		_pcts[def[0]] = pct
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Color("8fe36a"))
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 5)
	box.add_child(_status)


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
	for k in ["health", "food", "water"]:
		_pcts[k].text = "%d" % roundi(100.0 * _bars[k].value / maxf(_bars[k].max_value, 1.0))
	_refresh_stamina()
	_refresh_level()


## Minimapa redondo bajo las barras (necesita el mundo para la cámara cenital).
func add_minimap(world: Node3D) -> void:
	minimap = load("res://scripts/ui/minimap.gd").new()
	minimap.position = Vector2(18, 228)
	_root.add_child(minimap)
	_root.move_child(minimap, 1)
	minimap.setup(world)


func _refresh_level() -> void:
	if _xp_bar == null:
		return
	_xp_bar.value = GS.xp_progress() * 100.0
	if GS.level >= DB.max_level():
		_xp_label.text = "Nivel %d (máximo)" % GS.level
	else:
		_xp_label.text = "Nivel %d · %d/%d" % [GS.level, GS.xp, GS.xp_needed()]
	level_badge.queue_redraw()


var _xp_acc := 0
var _xp_tween: Tween
func _on_xp(amount: int) -> void:
	_xp_acc += amount
	_xp_pop.text = " +%d" % _xp_acc
	_xp_pop.modulate.a = 1.0
	if _xp_tween:
		_xp_tween.kill()
	_xp_tween = create_tween()
	_xp_tween.tween_interval(1.2)
	_xp_tween.tween_property(_xp_pop, "modulate:a", 0.0, 0.5)
	_xp_tween.tween_callback(func(): _xp_acc = 0)
	_refresh_level()


# ------------------------------------------------------------------ niveles

func _build_levelup_banner() -> void:
	_levelup = PanelContainer.new()
	_levelup.anchor_left = 0.5
	_levelup.anchor_right = 0.5
	_levelup.offset_left = -330
	_levelup.offset_right = 330
	_levelup.offset_top = 150
	_levelup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.03, 0.88)
	sb.border_color = Color("e8b84a")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(18)
	_levelup.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_levelup.add_child(v)
	_levelup_title = Label.new()
	_levelup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_levelup_title.add_theme_font_size_override("font_size", 46)
	_levelup_title.add_theme_color_override("font_color", Color("f6d27e"))
	v.add_child(_levelup_title)
	_levelup_text = Label.new()
	_levelup_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_levelup_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_levelup_text.add_theme_font_size_override("font_size", 21)
	_levelup_text.add_theme_color_override("font_color", Color("f3ead2"))
	v.add_child(_levelup_text)
	_levelup.visible = false
	_root.add_child(_levelup)


var _levelup_tween: Tween
func _on_level_up(lv: int, unlocks: Array, reward: Dictionary) -> void:
	_levelup_title.text = "¡NIVEL %d!" % lv
	var lines := PackedStringArray()
	if not unlocks.is_empty():
		lines.append("Desbloqueado: " + ", ".join(PackedStringArray(unlocks)))
	if not reward.is_empty():
		var parts := PackedStringArray()
		for id in reward:
			parts.append("%d %s" % [int(reward[id]), DB.item_name(str(id))])
		lines.append("Recompensa: " + ", ".join(parts))
	lines.append("Vida al máximo")
	var nx := DB.next_unlock_level(lv)
	if nx > 0 and unlocks.is_empty():
		lines.append("Próximo desbloqueo en el nivel %d" % nx)
	_levelup_text.text = "\n".join(lines)
	_levelup.visible = true
	_levelup.modulate.a = 1.0
	_levelup.scale = Vector2(0.85, 0.85)
	_levelup.pivot_offset = Vector2(330, 60)
	if _levelup_tween:
		_levelup_tween.kill()
	_levelup_tween = create_tween()
	_levelup_tween.tween_property(_levelup, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_levelup_tween.tween_interval(3.5)
	_levelup_tween.tween_property(_levelup, "modulate:a", 0.0, 0.6)
	_levelup_tween.tween_callback(func(): _levelup.visible = false)
	_refresh_level()
	if _levels_panel and _levels_panel.visible:
		_refresh_levels()


func _build_levels_panel() -> void:
	var parts := _panel("Niveles", Vector2(420, 300))
	_levels_panel = parts[0]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	_levels_list = VBoxContainer.new()
	_levels_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_levels_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_levels_list)


func open_levels() -> void:
	close_panels()
	_refresh_levels()
	_levels_panel.visible = true


## Nivel actual, cuánto falta y lo que se va desbloqueando (los próximos 6 hitos).
func _refresh_levels() -> void:
	for c in _levels_list.get_children():
		c.queue_free()
	var head := Label.new()
	head.add_theme_font_size_override("font_size", 22)
	if GS.level >= DB.max_level():
		head.text = "Nivel %d: has llegado al máximo." % GS.level
	else:
		head.text = "Nivel %d · te faltan %d de experiencia para el %d" % [GS.level, GS.xp_needed() - GS.xp, GS.level + 1]
	_levels_list.add_child(head)
	var how := Label.new()
	how.autowrap_mode = TextServer.AUTOWRAP_WORD
	how.custom_minimum_size.x = 740
	how.add_theme_font_size_override("font_size", 17)
	how.add_theme_color_override("font_color", Color(0.91, 0.86, 0.72, 0.7))
	how.text = "Ganas experiencia recogiendo materiales, abatiendo infectados y animales, fabricando, construyendo, registrando cajas y visitando zonas nuevas. Al subir de nivel recuperas toda la vida."
	_levels_list.add_child(how)
	var shown := 0
	var lv := GS.level
	while shown < 6:
		lv = DB.next_unlock_level(lv)
		if lv == 0:
			break
		shown += 1
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.custom_minimum_size.x = 740
		row.add_theme_font_size_override("font_size", 19)
		row.text = "Nivel %d — %s" % [lv, ", ".join(PackedStringArray(DB.unlocks_at(lv)))]
		row.add_theme_color_override("font_color", Color("f6d27e") if shown == 1 else Color("f3ead2"))
		_levels_list.add_child(row)
	if shown == 0:
		var more := Label.new()
		more.text = "Todo desbloqueado por ahora. Llegarán zonas y objetos nuevos."
		_levels_list.add_child(more)


func _refresh_stamina() -> void:
	var sb: ProgressBar = _bars["stamina"]
	sb.max_value = GS.max_stamina()
	sb.value = GS.stamina
	_pcts["stamina"].text = "%d" % roundi(100.0 * GS.stamina / maxf(GS.max_stamina(), 1.0))


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
	crouch_button.set_icon(DB.ui_icon("agachar"))
	crouch_button.pressed_changed.connect(func(on: bool):
		if on:
			toggle_crouch())
	_root.add_child(crouch_button)

	# Esquivar: salto rápido sin recibir golpes (gasta energía)
	dodge_button = TouchButtonScript.new()
	dodge_button.anchor_left = 1.0
	dodge_button.anchor_right = 1.0
	dodge_button.anchor_top = 1.0
	dodge_button.anchor_bottom = 1.0
	dodge_button.offset_left = -310
	dodge_button.offset_right = -210
	dodge_button.offset_top = -262
	dodge_button.offset_bottom = -162
	dodge_button.set_icon(DB.ui_icon("esquivar"))
	dodge_button.pressed_changed.connect(func(on: bool):
		if on:
			var p := get_tree().get_first_node_in_group("player")
			if p:
				p.dodge())
	_root.add_child(dodge_button)

	# Ajustes
	settings_btn = _big_button("ajustes", "Ajustes")
	settings_btn.custom_minimum_size = Vector2(56, 56)
	settings_btn.anchor_left = 0.5
	settings_btn.anchor_right = 0.5
	settings_btn.offset_left = 108
	settings_btn.offset_right = 164
	settings_btn.offset_top = 6
	settings_btn.offset_bottom = 62
	settings_btn.pressed.connect(func(): _toggle(_settings_panel))
	_root.add_child(settings_btn)
	_build_settings()

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
	# Zona en la que estás, debajo del reloj
	location_label = Label.new()
	location_label.anchor_left = 0.5
	location_label.anchor_right = 0.5
	location_label.offset_left = -160
	location_label.offset_right = 160
	location_label.offset_top = 62
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_label.add_theme_font_size_override("font_size", 22)
	location_label.add_theme_color_override("font_color", Color("f3ead2"))
	location_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	location_label.add_theme_constant_override("outline_size", 6)
	location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(location_label)

	var side := VBoxContainer.new()
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.offset_left = -200
	side.offset_right = -20
	side.offset_top = 14
	side.add_theme_constant_override("separation", 10)
	_root.add_child(side)
	inv_btn = _make_inv_button()
	side.add_child(inv_btn)
	craft_btn = _big_button("fabricar", "Fabricar")
	craft_btn.pressed.connect(func(): _toggle(_craft_panel))
	side.add_child(craft_btn)
	build_btn = _big_button("construir", "Construir")
	build_btn.pressed.connect(func(): _toggle(_build_panel))
	side.add_child(build_btn)
	map_btn = _big_button("mapa", "Mapa")
	map_btn.pressed.connect(func():
		_toggle(_map_panel)
		_refresh_map())
	side.add_child(map_btn)


## Botón redondo del lateral con un icono (sin texto).
func _big_button(icon_name: String, tip: String) -> Button:
	var b := Button.new()
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(84, 84)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.icon = DB.ui_icon(icon_name)   # lo dibuja el propio botón, centrado
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_constant_override("icon_max_width", 1)
	b.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 0))
	b.add_theme_color_override("icon_hover_color", Color(1, 1, 1, 0))
	b.add_theme_color_override("icon_pressed_color", Color(1, 1, 1, 0))
	b.add_theme_color_override("icon_focus_color", Color(1, 1, 1, 0))
	b.draw.connect(func():
		var c := b.size / 2.0
		var r := minf(c.x, c.y) - 2.0
		b.draw_circle(c, r, Color(0.055, 0.07, 0.047, 0.92 if b.button_pressed or b.is_pressed() else 0.78))
		b.draw_arc(c, r - 1.0, 0.0, TAU, 48, Color(0.91, 0.86, 0.72, 0.3), 2.0, true)
		var sz := r * 1.3
		b.draw_texture_rect(b.icon, Rect2(c - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false))
	return b


## Botón de acción: icono de lo que se va a usar y borde con su estado.
## info viene de player.action_info().
func set_action(label: String, info: Dictionary = {}) -> void:
	action_button.set_text(label if label != "" else "Acción")
	action_button.set_enabled(label != "")
	if info.is_empty():
		return
	action_icon = str(info["icon"])
	action_button.set_icon(DB.ui_icon(action_icon) if info["ui"] else DB.item_icon(action_icon))
	var it = info["item"]
	var ring := -1.0
	if it != null and it.has("dur"):
		ring = float(it["dur"]) / maxf(float(DB.item(str(it["id"])).get("durability", 1)), 1.0)
	action_button.set_ring(ring)


func _toggle(panel: Control) -> void:
	var opening := not panel.visible
	close_panels()
	panel.visible = opening
	if opening:
		_refresh_inventory()


func close_panels() -> void:
	for p in [_inv_panel, _craft_panel, _build_panel, _station_panel, _chest_panel, _map_panel, _gym_panel, _settings_panel, _levels_panel]:
		if p:
			p.visible = false
	station = null


func any_panel_open() -> bool:
	for p in [_inv_panel, _craft_panel, _build_panel, _station_panel, _chest_panel, _map_panel, _gym_panel, _settings_panel, _levels_panel]:
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
	inv_open = inv_open or (_map_panel != null and _map_panel.visible)
	joystick.visible = not inv_open
	action_button.visible = not inv_open
	crouch_button.visible = not inv_open
	dodge_button.visible = not inv_open
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


# ---------------------------------------------------------------- ajustes

func _build_settings() -> void:
	var parts := _panel("Ajustes", Vector2(330, 250))
	_settings_panel = parts[0]
	var v: VBoxContainer = parts[1]
	for d in [["music", "Música"], ["sfx", "Efectos"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var l := Label.new()
		l.text = d[1]
		l.custom_minimum_size = Vector2(130, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(SFX.settings[d[0]])
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.custom_minimum_size = Vector2(0, 44)
		var key: String = d[0]
		sl.value_changed.connect(func(val: float): SFX.set_setting(key, val))
		row.add_child(sl)
		v.add_child(row)
		settings_controls[key] = sl
	var vib := CheckButton.new()
	vib.text = "Vibración al recibir golpes"
	vib.button_pressed = bool(SFX.settings["vibration"])
	vib.toggled.connect(func(on: bool): SFX.set_setting("vibration", on))
	v.add_child(vib)
	settings_controls["vibration"] = vib
	var look := Button.new()
	look.text = "Cambiar aspecto del superviviente"
	look.custom_minimum_size = Vector2(0, 56)
	look.pressed.connect(func():
		close_panels()
		edit_look_requested.emit())
	v.add_child(look)
	_newgame_btn = Button.new()
	_newgame_btn.text = "Empezar partida nueva"
	_newgame_btn.custom_minimum_size = Vector2(0, 56)
	_newgame_btn.add_theme_color_override("font_color", Color("ff8a80"))
	_newgame_btn.pressed.connect(func():
		# Dos toques: el primero avisa
		if _newgame_btn.text.begins_with("¿Seguro"):
			new_game_requested.emit()
		else:
			_newgame_btn.text = "¿Seguro? Se borra todo. Toca otra vez")
	v.add_child(_newgame_btn)
	_settings_panel.visibility_changed.connect(func():
		_newgame_btn.text = "Empezar partida nueva")
	var ver := Label.new()
	ver.text = "Supervival · Lost Anarchy Games"
	ver.modulate = Color(1, 1, 1, 0.5)
	ver.add_theme_font_size_override("font_size", 15)
	v.add_child(ver)


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
	crouch_button.set_icon(DB.ui_icon("de_pie" if p.crouching else "agachar"))
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
		var f := minf(GS.load_ratio(), 1.0)
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
		if GS.level < DB.recipe_unlock(r):
			b.disabled = true
			b.text = "Nivel %d" % DB.recipe_unlock(r)
			row.modulate = Color(1, 1, 1, 0.55)
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
		var nph := DB.station_phases(str(id)).size()
		var extra := ("  (obra en %d fases)" % nph) if nph > 1 else ""
		_build_row(str(id), "%s%s — %s" % [d.get("name", id), extra, d.get("desc", "")], DB.station_build_cost(str(id)))


func _section(box: VBoxContainer, title: String) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	box.add_child(l)


func _build_row(id: String, title: String, cost: Dictionary) -> void:
	var row := HBoxContainer.new()
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size.x = 480
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.text = title
	col.add_child(lbl)
	col.add_child(_cost_chips(cost))
	row.add_child(col)
	var b := Button.new()
	b.text = "Colocar"
	b.custom_minimum_size = Vector2(140, 56)
	b.disabled = not GS.has_cost(cost)
	var need_lv := DB.tier_unlock(id, 0) if DB.structures.has(id) else DB.station_unlock(id)
	if GS.level < need_lv:
		b.disabled = true
		b.text = "Nivel %d" % need_lv
		row.modulate = Color(1, 1, 1, 0.55)
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
		if station == null:
			return
		if station.is_collector():
			station.drink()
			_refresh_station_job()
		elif station.collect():
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
	if not station.is_built():
		_refresh_phases()
		return
	if station.is_generator():
		_refresh_generator()
		return
	if station.needs_power():
		var gen: Node3D = station._generator()
		var info := Label.new()
		info.add_theme_font_size_override("font_size", 18)
		if gen == null:
			info.text = "⚠ Necesita un generador terminado en el refugio."
			info.add_theme_color_override("font_color", Color("e0705a"))
		else:
			var f := int(gen.fuel)
			info.text = "Energía del generador: %d:%02d" % [f / 60, f % 60]
			info.add_theme_color_override("font_color", Color("9fd36a") if f > 0 else Color("e0705a"))
		_station_list.add_child(info)
	if station.id == "huerto" and station._has_station("recolector_agua"):
		var w := Label.new()
		w.text = "Riego con el recolector de agua: crece el doble de rápido."
		w.add_theme_font_size_override("font_size", 18)
		w.add_theme_color_override("font_color", Color("7fc4e8"))
		_station_list.add_child(w)
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
		var qty := int(r.get("qty", 1))
		var head := "%s%s  (%s)" % [DB.item_name(str(r["result"])), (" ×%d" % qty) if qty > 1 else "", _time_text(station.recipe_time(r))]
		var rd := DB.item(str(r["result"]))
		if rd.has("armor"):
			head += "  · Defensa +%d%%" % int(rd["armor"])
		if rd.has("bag_slots"):
			head += "  · +%d huecos" % int(rd["bag_slots"])
		var need_lv := DB.recipe_unlock(r)
		var lv_ok := GS.level >= need_lv
		if not lv_ok:
			head = head + "  — se desbloquea en el nivel %d" % need_lv
			unlocked = false
		elif not unlocked:
			head += "  — requiere %s de nivel %d" % [DB.station_name(station.id).to_lower(), int(r.get("level", 1))]
		lbl.text = head
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		col.add_child(lbl)
		col.add_child(_cost_chips(r.get("cost", {})))
		if not unlocked:
			col.modulate = Color(1, 1, 1, 0.5)
		row.add_child(col)
		var b := Button.new()
		b.text = "Fabricar"
		b.custom_minimum_size = Vector2(150, 56)
		b.disabled = not unlocked or not station.job.is_empty() or not GS.can_craft(r)
		if not lv_ok:
			b.text = "Nivel %d" % need_lv
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
	_station_collect.text = "Recoger"
	_station_collect.visible = not station.is_generator() and station.is_built()
	if not station.is_built():
		var n: int = station.phases().size()
		_station_job.text = "En obra: fase %d de %d hecha" % [station.stage, n]
		_station_bar.value = float(station.stage) / float(n)
		_station_collect.disabled = true
		return
	if station.is_collector():
		var w: float = station.water_now()
		_station_job.text = "Agua: %d / %d%s" % [int(w), int(station.water_capacity()), "  · llueve: se llena más rápido" if GS.raining() else ""]
		_station_bar.value = w / station.water_capacity()
		_station_collect.text = "Beber"
		_station_collect.disabled = w < 1.0
		return
	if station.is_generator():
		var f := int(station.fuel)
		_station_job.text = "Energía: %d:%02d" % [f / 60, f % 60]
		_station_bar.value = station.fuel / float(DB.bal("generator_max", 3600))
		_station_collect.disabled = true
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


func _time_text(t: float) -> String:
	var s := int(round(t))
	if s < 60:
		return "%ds" % s
	return "%d:%02d min" % [s / 60, s % 60]


## Materiales con icono y "tengo/necesito" (verde si llega, rojo si falta).
func _cost_chips(cost: Dictionary) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	for id in cost:
		var need := int(cost[id])
		var have := GS.count(str(id))
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 3)
		chip.tooltip_text = DB.item_name(str(id))
		var ic := TextureRect.new()
		ic.texture = DB.item_icon(str(id))
		ic.custom_minimum_size = Vector2(30, 30)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chip.add_child(ic)
		var l := Label.new()
		l.text = "%d/%d" % [have, need]
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", Color("9fd36a") if have >= need else Color("e0705a"))
		chip.add_child(l)
		flow.add_child(chip)
	flow.set_meta("cost", cost)
	return flow


## Estación grande a medio construir: lista de fases y botón para la siguiente.
func _refresh_phases() -> void:
	_station_title.text = "%s — en obra" % DB.station_name(station.id)
	var ph: Array = station.phases()
	for i in ph.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 19)
		var done: bool = i < station.stage
		lbl.text = "%s Fase %d: %s" % ["✔" if done else ("▶" if i == station.stage else "·"), i + 1, ph[i].get("name", "")]
		col.add_child(lbl)
		if not done:
			col.add_child(_cost_chips(ph[i].get("cost", {})))
		else:
			lbl.add_theme_color_override("font_color", Color("9fd36a"))
		if i > station.stage:
			col.modulate = Color(1, 1, 1, 0.5)
		row.add_child(col)
		if i == station.stage:
			var b := Button.new()
			b.text = "Añadir"
			b.custom_minimum_size = Vector2(150, 56)
			b.disabled = not GS.has_cost(ph[i].get("cost", {}))
			b.pressed.connect(func():
				var why: String = station.add_phase()
				if why != "":
					show_message(why)
				_refresh_station())
			row.add_child(b)
		_station_list.add_child(row)
	_refresh_station_job()


func _refresh_generator() -> void:
	var info := Label.new()
	info.text = "Da energía a la recicladora. Cada fabricación gasta tantos segundos de energía como dura."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size.x = 680
	info.add_theme_font_size_override("font_size", 18)
	_station_list.add_child(info)
	var per: Dictionary = DB.bal("generator_fuel", {"carbon": 300, "madera": 90})
	for fid in per:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_row_icon(str(fid)))
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 19)
		lbl.text = "Echar %s  (+%s de energía)\n   Tienes %d" % [DB.item_name(str(fid)).to_lower(), _time_text(float(per[fid])), GS.count(str(fid))]
		row.add_child(lbl)
		var b := Button.new()
		b.text = "Echar"
		b.custom_minimum_size = Vector2(150, 56)
		b.disabled = GS.count(str(fid)) <= 0
		var item_id := str(fid)
		b.pressed.connect(func():
			var why: String = station.add_fuel(item_id)
			if why != "":
				show_message(why)
			_refresh_station())
		row.add_child(b)
		_station_list.add_child(row)
	_refresh_station_job()


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
	if location_label:
		location_label.text = str(DB.maps.get(id, {}).get("name", id))
	# Solo se construye en el refugio.
	if build_btn:
		build_btn.visible = DB.maps.get(id, {}).get("base_half", 0) > 0


const MAP_INK := Color("2b2418")
const MAP_COLORS := {
	"hogar": Color("a87c12"), "verde": Color("3f7d3a"), "amarilla": Color("b86a0c"),
	"roja": Color("b3261e"), "radiactiva": Color("6b3fa0"), "segura": Color("1f5f99"),
}
const MAP_SIZE := Vector2(962, 680)     # el papel (990x700) ajustado a la pantalla


## Mapa del Valle: papel antiguo a pantalla completa con un marcador por zona.
func _build_map_panel() -> void:
	_map_panel = Control.new()
	_map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_panel.visible = false
	_root.add_child(_map_panel)
	var bg := ColorRect.new()   # mesa de madera oscura
	bg.color = Color("2b1d13")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_panel.add_child(bg)
	_map_area = TextureRect.new()
	_map_area.texture = load("res://assets/ui/mapa_valle.png")
	_map_area.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_area.position = Vector2(14, 20)
	_map_area.size = MAP_SIZE
	_map_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_panel.add_child(_map_area)
	_map_route = Control.new()
	_map_route.size = MAP_SIZE
	_map_route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_route.draw.connect(_draw_map)
	_map_area.add_child(_map_route)
	_map_marks = Control.new()
	_map_marks.size = MAP_SIZE
	_map_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_area.add_child(_map_marks)

	# Ficha de la zona: una hoja de cuaderno a la derecha
	var note := PanelContainer.new()
	note.position = Vector2(992, 84)
	note.size = Vector2(272, 616)
	var ns := StyleBoxFlat.new()
	ns.bg_color = Color("e6d3a6")
	ns.border_color = Color("8a6f43")
	ns.set_border_width_all(2)
	ns.set_corner_radius_all(6)
	ns.set_content_margin_all(16)
	ns.shadow_color = Color(0, 0, 0, 0.5)
	ns.shadow_size = 8
	note.add_theme_stylebox_override("panel", ns)
	_map_panel.add_child(note)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	note.add_child(v)
	_map_name = Label.new()
	_map_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	_map_name.add_theme_font_size_override("font_size", 26)
	_map_name.add_theme_color_override("font_color", MAP_INK)
	v.add_child(_map_name)
	_map_level = Label.new()
	_map_level.add_theme_font_size_override("font_size", 18)
	v.add_child(_map_level)
	_map_info = Label.new()
	_map_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_map_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_info.add_theme_font_size_override("font_size", 19)
	_map_info.add_theme_color_override("font_color", Color("3d3222"))
	v.add_child(_map_info)
	_map_travel = Button.new()
	_map_travel.text = "Viajar"
	_map_travel.custom_minimum_size = Vector2(0, 62)
	_map_travel.add_theme_font_size_override("font_size", 24)
	for st in [["normal", Color("7a1d14")], ["hover", Color("8c2419")], ["pressed", Color("5e150e")], ["disabled", Color(0.35, 0.3, 0.24, 0.5)]]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = st[1]
		bs.set_corner_radius_all(8)
		_map_travel.add_theme_stylebox_override(st[0], bs)
	_map_travel.add_theme_color_override("font_color", Color("f1e2bc"))
	_map_travel.pressed.connect(func():
		if _map_selected != "":
			travel_requested.emit(_map_selected))
	v.add_child(_map_travel)
	var close := Button.new()
	close.text = "X"
	close.position = Vector2(1208, 16)
	close.size = Vector2(56, 52)
	close.pressed.connect(func(): _map_panel.visible = false)
	_map_panel.add_child(close)


func _map_pos(id: String) -> Vector2:
	var p: Array = DB.world_map[id]["pos"]
	return (Vector2(40.0, 30.0) + Vector2(float(p[0]) * 900.0, float(p[1]) * 620.0)) * (MAP_SIZE.x / 990.0)


## Ruta a lápiz rojo desde donde estás hasta la zona elegida.
func _draw_map() -> void:
	if _map_selected == "" or _map_selected == location or not DB.world_map.has(location):
		return
	var a := _map_pos(location)
	var b := _map_pos(_map_selected)
	var mid := (a + b) / 2.0 + (b - a).orthogonal().normalized() * 26.0
	var pts := PackedVector2Array()
	for k in 25:
		var t := float(k) / 24.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	for k in range(0, pts.size() - 1, 2):
		_map_route.draw_line(pts[k], pts[k + 1], Color("8c1c12"), 3.5, true)


func _refresh_map() -> void:
	if _map_area == null:
		return
	for c in _map_marks.get_children():
		c.queue_free()
	map_buttons = {}
	_map_route.queue_redraw()
	for id in DB.world_map:
		var d: Dictionary = DB.world_map[id]
		var playable := DB.maps.has(id)
		var here: bool = id == location
		var picked: bool = id == _map_selected
		var col: Color = MAP_COLORS.get(str(d.get("level", "verde")), MAP_INK)
		var r := 30.0 if picked else 25.0
		var b := Button.new()
		b.size = Vector2(r, r) * 2.0
		b.position = _map_pos(id) - Vector2(r, r)
		b.tooltip_text = str(d["name"])
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("ead9b0") if playable else Color("d2c39c")
		sb.border_color = Color("7a1d14") if picked else col
		sb.set_border_width_all(5 if picked else 3)
		sb.set_corner_radius_all(int(r))
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 4
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		var ic := TextureRect.new()
		ic.texture = _map_icon(id)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.size = Vector2(r, r) * 1.36
		ic.position = Vector2(r, r) * 0.32
		ic.modulate = Color(1, 1, 1, 1.0 if playable else 0.6)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		if not playable:   # zona aún sin explorar
			var q := Label.new()
			q.text = "?"
			q.position = Vector2(r * 2.0 - 18.0, -8.0)
			q.size = Vector2(22, 22)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.add_theme_font_size_override("font_size", 16)
			q.add_theme_color_override("font_color", MAP_INK)
			var qs := StyleBoxFlat.new()
			qs.bg_color = Color("e9dcb8")
			qs.border_color = MAP_INK
			qs.set_border_width_all(2)
			qs.set_corner_radius_all(11)
			q.add_theme_stylebox_override("normal", qs)
			q.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(q)
		var name_l := Label.new()
		name_l.text = str(d["name"])
		name_l.add_theme_font_size_override("font_size", 16 if picked else 14)
		name_l.add_theme_color_override("font_color", MAP_INK)
		name_l.add_theme_color_override("font_outline_color", Color("e6d3a6"))
		name_l.add_theme_constant_override("outline_size", 6)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.size = Vector2(220, 20)
		name_l.position = Vector2(clampf(r - 110.0, -b.position.x + 4.0, MAP_SIZE.x - b.position.x - 224.0), r * 2.0 + 1.0)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(name_l)
		if here:   # «tú»: marca roja encima
			var me := Label.new()
			me.text = "Estás aquí"
			me.add_theme_font_size_override("font_size", 15)
			me.add_theme_color_override("font_color", Color("f1e2bc"))
			var ms := StyleBoxFlat.new()
			ms.bg_color = Color("8c1c12")
			ms.set_corner_radius_all(8)
			ms.content_margin_left = 8
			ms.content_margin_right = 8
			me.add_theme_stylebox_override("normal", ms)
			me.position = Vector2(r - 42.0, -26.0)
			me.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(me)
		var mid := str(id)
		b.pressed.connect(func(): _select_map(mid))
		_map_marks.add_child(b)
		map_buttons[id] = b
	if _map_selected == "":
		_select_map(location)
	else:
		_update_map_info()


var _map_icons: Dictionary = {}
func _map_icon(id: String) -> Texture2D:
	if not _map_icons.has(id):
		var path := "res://assets/icons/map/%s.svg" % id
		_map_icons[id] = load(path) if ResourceLoader.exists(path) else null
	return _map_icons[id]


func _select_map(id: String) -> void:
	_map_selected = id
	_refresh_map()


func _update_map_info() -> void:
	var d: Dictionary = DB.world_map.get(_map_selected, {})
	var lvl := str(d.get("level", ""))
	_map_name.text = str(d.get("name", ""))
	_map_level.text = str(LEVEL_NAMES.get(lvl, ""))
	_map_level.add_theme_color_override("font_color", MAP_COLORS.get(lvl, MAP_INK))
	var txt := str(d.get("desc", ""))
	var can := false
	if _map_selected == location:
		txt += "\n\nEstás aquí."
	elif not DB.maps.has(_map_selected):
		txt += "\n\nAún no sabes llegar: te falta un trozo del mapa."
	else:
		var cost := DB.travel_cost(location, _map_selected)
		txt += "\n\nViaje: comida -%d, agua -%d" % [int(cost["food"]), int(cost["water"])]
		can = true
		var need_lv := DB.map_unlock(_map_selected)
		if GS.level < need_lv:
			txt += "\nBloqueado: necesitas nivel %d." % need_lv
			can = false
		var key := str(DB.maps[_map_selected].get("key_item", ""))
		if key != "":
			var has_key := false
			for alt in key.split("|"):
				if GS.count(alt) > 0:
					has_key = true
			txt += "\n%s %s." % ["Llevas" if has_key else "Bloqueado: tienes que llevar", str(DB.maps[_map_selected].get("key_text", key))]
			if not has_key:
				can = false
	_map_info.text = txt
	_map_travel.disabled = not can
