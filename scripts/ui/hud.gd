extends CanvasLayer
## Interfaz: barras de vida/comida/agua, joystick, botón de acción,
## mochila (inventario) y fabricación. Todo creado por código.

const JoystickScript := preload("res://scripts/ui/joystick.gd")
const TouchButtonScript := preload("res://scripts/ui/touch_button.gd")

var joystick: Control
var action_button: Control
var _bars: Dictionary = {}
var _msg: Label
var _msg_timer := 0.0
var _hand_label: Label
var _death: Label
var _inv_panel: PanelContainer
var _inv_grid: GridContainer
var _inv_detail: Label
var _inv_buttons: HBoxContainer
var _selected := -1
var _craft_panel: PanelContainer
var _craft_list: VBoxContainer
var _root: Control


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
	for def in [["health", "Vida", Color("d9443c")], ["food", "Comida", Color("e09a3a")], ["water", "Agua", Color("3a8fe0")]]:
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

	var side := VBoxContainer.new()
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.offset_left = -200
	side.offset_right = -20
	side.offset_top = 20
	side.add_theme_constant_override("separation", 10)
	_root.add_child(side)
	var inv_btn := _big_button("Mochila")
	inv_btn.pressed.connect(func(): _toggle(_inv_panel))
	side.add_child(inv_btn)
	var craft_btn := _big_button("Fabricar")
	craft_btn.pressed.connect(func(): _toggle(_craft_panel))
	side.add_child(craft_btn)


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
	_inv_panel.visible = false
	_craft_panel.visible = false
	panel.visible = opening
	if opening:
		_refresh_inventory()


func show_message(t: String) -> void:
	_msg.text = t
	_msg.modulate.a = 1.0
	_msg_timer = 2.0


func show_death(v: bool) -> void:
	_death.visible = v


func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer < 0.5:
			_msg.modulate.a = maxf(_msg_timer / 0.5, 0.0)


# ---------------------------------------------------------------- mochila

func _panel(title: String) -> Array:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -390
	panel.offset_right = 390
	panel.offset_top = -280
	panel.offset_bottom = 280
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
	close.pressed.connect(func(): panel.visible = false)
	head.add_child(close)
	v.add_child(head)
	_root.add_child(panel)
	return [panel, v]


func _build_inventory() -> void:
	var parts := _panel("Mochila")
	_inv_panel = parts[0]
	var v: VBoxContainer = parts[1]
	_inv_grid = GridContainer.new()
	_inv_grid.columns = 5
	_inv_grid.add_theme_constant_override("h_separation", 8)
	_inv_grid.add_theme_constant_override("v_separation", 8)
	v.add_child(_inv_grid)
	_inv_detail = Label.new()
	_inv_detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	_inv_detail.custom_minimum_size = Vector2(700, 56)
	_inv_detail.add_theme_font_size_override("font_size", 20)
	v.add_child(_inv_detail)
	_inv_buttons = HBoxContainer.new()
	_inv_buttons.add_theme_constant_override("separation", 12)
	v.add_child(_inv_buttons)


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
	if _inv_panel == null:
		return
	# Casillas
	for c in _inv_grid.get_children():
		c.queue_free()
	for i in GS.slots.size():
		var s = GS.slots[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(136, 64)
		b.add_theme_font_size_override("font_size", 17)
		b.clip_text = true
		if s == null:
			b.text = ""
		else:
			var label := DB.item_name(str(s["id"]))
			if int(s["qty"]) > 1:
				label += " x%d" % int(s["qty"])
			elif s.has("dur"):
				label += " %d" % int(s["dur"])
			b.text = label
		if i == _selected:
			b.modulate = Color(1.0, 0.85, 0.4)
		b.pressed.connect(_select.bind(i))
		_inv_grid.add_child(b)
	_refresh_detail()
	_refresh_crafting()


func _select(i: int) -> void:
	_selected = i
	_refresh_inventory()


func _refresh_detail() -> void:
	for c in _inv_buttons.get_children():
		c.queue_free()
	if GS.hand != null:
		var ub := Button.new()
		ub.text = "Guardar lo de la mano"
		ub.pressed.connect(func(): GS.unequip())
		_inv_buttons.add_child(ub)
	if _selected < 0 or _selected >= GS.slots.size() or GS.slots[_selected] == null:
		_inv_detail.text = "Toca una casilla para ver el objeto. Casillas libres: %d" % GS.free_slots()
		return
	var s: Dictionary = GS.slots[_selected]
	var data := DB.item(str(s["id"]))
	_inv_detail.text = "%s — %s" % [DB.item_name(str(s["id"])), str(data.get("desc", ""))]
	var idx := _selected
	match str(data.get("type", "")):
		"consumable":
			var b := Button.new()
			b.text = "Usar"
			b.pressed.connect(func(): GS.use_slot(idx))
			_inv_buttons.add_child(b)
		"tool", "weapon":
			var b2 := Button.new()
			b2.text = "Equipar"
			b2.pressed.connect(func(): GS.equip_slot(idx))
			_inv_buttons.add_child(b2)
	var drop := Button.new()
	drop.text = "Tirar"
	drop.pressed.connect(func():
		GS.drop_slot(idx)
		_selected = -1
		_refresh_inventory())
	_inv_buttons.add_child(drop)


# ------------------------------------------------------------- fabricación

func _build_crafting() -> void:
	var parts := _panel("Fabricar")
	_craft_panel = parts[0]
	var v: VBoxContainer = parts[1]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 420)
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
	for r in DB.recipes:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
