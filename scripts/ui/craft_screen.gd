extends "res://scripts/ui/station_screen.gd"
## Fabricación (botón Fabricar): todas las recetas en tarjetas, por pestañas. A mano solo se
## hace lo básico; lo demás muestra en qué banco se fabrica, para que se vea el camino de
## materia prima -> procesado -> componente -> herramienta. Mismo estilo que las estaciones.

const COLS := 5
const CARD := Vector2(132, 150)
const GAP := 10.0
const CTABS := ["Todo", "Herramientas", "Armas", "Ropa", "Recursos", "Curas y comida"]

var cards: Array = []            # [{"r": receta, "manual": bool}] de la pestaña actual
var ctab := "Todo"
var sel := 0
var craft_btn: Button
var _grid: Control
var _gscroll: ScrollContainer
var _ctab_btns: Array = []
var _big: TextureRect
var _bname: Label
var _stats: Label
var _bdesc: Label
var _where: Label
var _slots: Array = []           # [panel, icono, cantidad]


func _ready() -> void:
	_cond = FontVariation.new()
	_cond.base_font = get_theme_default_font()
	_cond.variation_transform = Transform2D(Vector2(0.88, 0), Vector2(0, 1), Vector2.ZERO)
	_cond.spacing_glyph = -2
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.02, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_content = Control.new()
	_content.anchor_left = 0.5
	_content.anchor_right = 0.5
	_content.offset_left = -W / 2.0
	_content.offset_right = W / 2.0
	_content.anchor_bottom = 1.0
	add_child(_content)
	# cabecera
	var ic := TextureRect.new()
	ic.texture = DB.ui_icon("fabricar")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(22, 14)
	ic.size = Vector2(60, 56)
	_content.add_child(ic)
	_lbl("FABRICACIÓN", 44, PAPER.darkened(0.06), Vector2(92, 12))
	_lbl("A mano lo básico; lo demás, en los bancos del refugio", 20, DESC, Vector2(384, 32))
	var close := _btn("X", Rect2(1186, 16, 64, 58), false, 30)
	close.add_theme_stylebox_override("normal", _box(Color(0.02, 0.02, 0.02, 0.95), Color("3a3a36"), 12, 2))
	close.pressed.connect(func(): visible = false)
	# izquierda: tarjetas
	_panel(Rect2(24, 90, 724, 614))
	_gscroll = ScrollContainer.new()
	_gscroll.position = Vector2(40, 104)
	_gscroll.size = Vector2(COLS * (CARD.x + GAP), 506)
	_gscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(_gscroll)
	_grid = Control.new()
	_gscroll.add_child(_grid)
	for i in CTABS.size():
		var b := _btn(CTABS[i], Rect2(40 + i * 117, 626, 111, 62), false, 17)
		var t: String = CTABS[i]
		b.pressed.connect(func(): ctab = t; sel = 0; refresh())
		_ctab_btns.append(b)
	# derecha: el plano elegido
	_panel(Rect2(764, 90, 492, 614))
	var plan := Panel.new()
	plan.position = Vector2(784, 106)
	plan.size = Vector2(452, 214)
	plan.add_theme_stylebox_override("panel", _box(Color("1c2b33"), Color("3d5866"), 12, 2))
	plan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plan.draw.connect(func():
		for x in range(0, 452, 22):
			plan.draw_line(Vector2(x, 0), Vector2(x, 214), Color(0.55, 0.75, 0.85, 0.12))
		for y in range(0, 214, 22):
			plan.draw_line(Vector2(0, y), Vector2(452, y), Color(0.55, 0.75, 0.85, 0.12)))
	_content.add_child(plan)
	_bname = _lbl("", 28, PAPER, Vector2(800, 110))
	_big = TextureRect.new()
	_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_big.position = Vector2(900, 146)
	_big.size = Vector2(220, 168)
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_big)
	_stats = _lbl("", 21, GOLD, Vector2(784, 328))
	_stats.size = Vector2(452, 28)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bdesc = _lbl("", 20, DESC, Vector2(784, 358))
	_bdesc.size = Vector2(452, 54)
	_bdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bdesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for k in 6:
		var p := Panel.new()
		p.position = Vector2(800 + (k % 3) * 142, 418 + (k / 3) * 92)
		p.size = Vector2(132, 84)
		p.add_theme_stylebox_override("panel", _box(ROW_BG, ROW_LINE, 10, 2))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(p)
		var ti := TextureRect.new()
		ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ti.position = Vector2(8, 6)
		ti.size = Vector2(70, 70)
		p.add_child(ti)
		var q := _lbl("", 22, PAPER, Vector2(66, 48), p)
		q.size = Vector2(60, 30)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_slots.append([p, ti, q])
	_where = _lbl("", 20, GOLD, Vector2(784, 604))
	_where.size = Vector2(452, 26)
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	craft_btn = _btn("FABRICAR", Rect2(800, 630, 420, 62), true, 30)
	craft_btn.pressed.connect(_on_craft)


func open_craft() -> void:
	sel = 0
	visible = true
	refresh()


## Una tarjeta por objeto: la receta a mano si la hay; si no, la del banco que antes se desbloquea.
static func blueprints() -> Array:
	var best := {}
	for r in DB.recipes:
		var res := str(r["result"])
		var st := str(r.get("station", ""))
		if st in ["huerto", "recicladora"]:
			continue   # cultivos y reciclaje: otras formas de sacar lo mismo
		var manual := st == ""
		var prev: Dictionary = best.get(res, {})
		if prev.is_empty() or (manual and not prev["manual"]) or (manual == prev["manual"] and DB.recipe_unlock(r) < DB.recipe_unlock(prev["r"])):
			best[res] = {"r": r, "manual": manual}
	var out: Array = best.values()
	out.sort_custom(func(a, b):
		if a["manual"] != b["manual"]:
			return a["manual"]
		return DB.recipe_unlock(a["r"]) < DB.recipe_unlock(b["r"]))
	return out


static func card_tab(r: Dictionary) -> String:
	var c := recipe_cat(r)
	match c:
		"Herramientas", "Armas", "Ropa":
			return c
		"Mochilas":
			return "Ropa"
		"Trampas", "Explosivos":
			return "Armas"
		"Medicinas", "Comida", "Platos", "Conservas", "Agua", "Medicamentos":
			return "Curas y comida"
	return "Recursos"


func refresh() -> void:
	cards = blueprints().filter(func(e): return ctab == "Todo" or card_tab(e["r"]) == ctab)
	sel = clampi(sel, 0, maxi(cards.size() - 1, 0))
	for i in _ctab_btns.size():
		var on: bool = CTABS[i] == ctab
		_ctab_btns[i].add_theme_stylebox_override("normal", _box(ORANGE if on else Color(0.1, 0.095, 0.075, 0.95), ORANGE.darkened(0.3) if on else ROW_LINE, 12, 2))
		_ctab_btns[i].add_theme_color_override("font_color", INK if on else PAPER)
	for c in _grid.get_children():
		c.queue_free()
	for i in cards.size():
		_grid.add_child(_card(i))
	_grid.custom_minimum_size = Vector2(COLS * (CARD.x + GAP), ceil(cards.size() / float(COLS)) * (CARD.y + GAP))
	_show(sel)


func _card(i: int) -> Control:
	var e: Dictionary = cards[i]
	var r: Dictionary = e["r"]
	var res := str(r["result"])
	var b := Button.new()
	b.position = Vector2((i % COLS) * (CARD.x + GAP), (i / COLS) * (CARD.y + GAP))
	b.size = CARD
	b.focus_mode = Control.FOCUS_NONE
	var on := i == sel
	var bg := Color(0.16, 0.2, 0.17, 0.95) if on else ROW_BG
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, _box(bg, ORANGE if on else ROW_LINE, 12, 3 if on else 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): _show(i))
	var locked := GS.level < DB.recipe_unlock(r)
	var ti := TextureRect.new()
	ti.texture = recipe_icon(res)
	ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ti.position = Vector2(14, 8)
	ti.size = Vector2(104, 92)
	ti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		ti.modulate = Color(0.35, 0.35, 0.35)
	b.add_child(ti)
	var n := _lbl("", 17, PAPER if not locked else Color(0.6, 0.56, 0.48), Vector2(4, 98), b)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(CARD.x - 8, 48)
	n.size = Vector2(CARD.x - 8, 48)
	n.text = DB.item_name(res)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.add_theme_constant_override("line_spacing", -6)
	if not e["manual"]:
		# en qué banco: su icono en la esquina
		var si := TextureRect.new()
		si.texture = _station_icon(str(r["station"]))
		si.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		si.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		si.position = Vector2(CARD.x - 42, 4)
		si.size = Vector2(38, 34)
		si.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(si)
	elif not locked and GS.can_craft(r):
		var dot := Panel.new()
		dot.position = Vector2(CARD.x - 22, 8)
		dot.size = Vector2(14, 14)
		dot.add_theme_stylebox_override("panel", _box(Color("7ccf6a"), Color("7ccf6a"), 7, 0))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dot)
	if locked:
		var lv := _lbl("NIVEL %d" % DB.recipe_unlock(r), 18, ORANGE, Vector2(0, 40), b)
		lv.size = Vector2(CARD.x, 24)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


func _show(i: int) -> void:
	if i != sel and i < _grid.get_child_count():
		var old := sel
		sel = i
		for k in [old, i]:
			if k < cards.size():
				var c := _grid.get_child(k)
				var on: bool = k == sel
				var bg := Color(0.16, 0.2, 0.17, 0.95) if on else ROW_BG
				for st in ["normal", "hover", "pressed"]:
					c.add_theme_stylebox_override(st, _box(bg, ORANGE if on else ROW_LINE, 12, 3 if on else 2))
	sel = i
	if cards.is_empty():
		_bname.text = ""
		_big.texture = null
		craft_btn.visible = false
		return
	var e: Dictionary = cards[sel]
	var r: Dictionary = e["r"]
	var res := str(r["result"])
	var d := DB.item(res)
	_bname.text = DB.item_name(res).to_upper() + ("" if int(r.get("qty", 1)) <= 1 else "  x%d" % int(r["qty"]))
	_big.texture = preview_tex(res)
	_stats.text = item_stats(res)
	_bdesc.text = str(d.get("desc", ""))
	var cost: Dictionary = r.get("cost", {})
	var ids := cost.keys()
	for k in _slots.size():
		var s: Array = _slots[k]
		if k < ids.size():
			var id := str(ids[k])
			var have := GS.count(id)
			var need := int(cost[id])
			s[1].texture = DB.item_icon(id)
			s[2].text = "%d/%d" % [have, need]
			s[2].add_theme_color_override("font_color", PAPER if have >= need else RED)
			s[0].tooltip_text = DB.item_name(id)
		else:
			s[1].texture = null
			s[2].text = ""
	craft_btn.visible = true
	var lv := DB.recipe_unlock(r)
	if GS.level < lv:
		_where.text = ""
		craft_btn.text = "NIVEL %d" % lv
		craft_btn.disabled = true
	elif e["manual"]:
		_where.text = "A mano"
		craft_btn.text = "FABRICAR"
		craft_btn.disabled = not GS.can_craft(r)
	else:
		_where.text = "Se fabrica en: " + DB.station_name(str(r["station"]))
		craft_btn.text = "EN EL BANCO"
		craft_btn.disabled = true


## Datos del objeto en una línea: daño, recolección, armadura, huecos y peso.
static func item_stats(id: String) -> String:
	var d := DB.item(id)
	var p := PackedStringArray()
	if d.has("damage"):
		p.append("Daño %d" % int(d["damage"]))
	if d.has("gather_mult"):
		p.append("Recoge x%s" % str(d["gather_mult"]))
	if d.has("armor"):
		p.append("Armadura %d" % int(d["armor"]))
	if d.has("bag_slots"):
		p.append("+%d huecos" % int(d["bag_slots"]))
	if d.has("heal"):
		p.append("Cura %d" % int(d["heal"]))
	if d.has("durability"):
		p.append("Aguante %d" % int(d["durability"]))
	if d.has("tier"):
		p.append({"bruto": "Materia prima", "procesado": "Procesado", "componente": "Componente"}.get(str(d["tier"]), ""))
	p.append("%s kg" % str(d.get("weight", 0)))
	return "  ·  ".join(p)


func _on_craft() -> void:
	if cards.is_empty():
		return
	var r: Dictionary = cards[sel]["r"]
	if GS.craft(str(r["id"])):
		var keep := sel
		refresh()
		_show(keep)


func _process(_delta: float) -> void:
	pass
