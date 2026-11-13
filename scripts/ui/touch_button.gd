extends Control
## Botón redondo multitáctil (se puede mantener pulsado mientras mueves el joystick).

signal pressed_changed(is_pressed: bool)

var text := ""
var enabled := true
var held := false
var base_color := Color(0.95, 0.75, 0.25)
var _touch := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_text(t: String) -> void:
	if t != text:
		text = t
		queue_redraw()


func set_enabled(e: bool) -> void:
	if e != enabled:
		enabled = e
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var c := size / 2.0
		if event.pressed and _touch == -1 and p.distance_to(c) <= minf(size.x, size.y) / 2.0:
			_touch = event.index
			_set_held(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch:
			_touch = -1
			_set_held(false)


func _set_held(h: bool) -> void:
	held = h
	pressed_changed.emit(h)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	var col := base_color if enabled else Color(0.5, 0.5, 0.5)
	col.a = 0.9 if held else 0.65
	draw_circle(c, r, col)
	draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.8), 4.0, true)
	var font := get_theme_default_font()
	var fs := 26
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(font, Vector2(c.x - tw / 2.0, c.y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
