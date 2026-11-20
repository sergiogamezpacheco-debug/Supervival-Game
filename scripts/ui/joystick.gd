extends Control
## Joystick virtual multitáctil. Se activa tocando en cualquier punto de su
## zona (mitad inferior izquierda) y la base aparece bajo el dedo.

signal changed(value: Vector2)

var value := Vector2.ZERO
var radius := 90.0
var _touch := -1
var _base := Vector2.ZERO
var _knob := Vector2.ZERO
var _rest := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rest = Vector2(radius + 40.0, size.y - radius - 40.0)
	_base = _rest
	_knob = _rest
	resized.connect(_on_resized)
	# Si se oculta con el dedo encima (se abre una ventana), se suelta
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			_touch = -1
			value = Vector2.ZERO
			_base = _rest
			_knob = _rest
			queue_redraw())


func _on_resized() -> void:
	_rest = Vector2(radius + 40.0, size.y - radius - 40.0)
	if _touch == -1:
		_base = _rest
		_knob = _rest
	queue_redraw()


func _to_local(p: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * p


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var p := _to_local(event.position)
		if event.pressed and _touch == -1 and Rect2(Vector2.ZERO, size).has_point(p):
			_touch = event.index
			_base = p
			_knob = p
			_update(p)
		elif not event.pressed and event.index == _touch:
			_touch = -1
			_base = _rest
			_knob = _rest
			_set_value(Vector2.ZERO)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch:
		_update(_to_local(event.position))


func _update(p: Vector2) -> void:
	var off := (p - _base).limit_length(radius)
	_knob = _base + off
	_set_value(off / radius)
	queue_redraw()


func _set_value(v: Vector2) -> void:
	value = v if v.length() > 0.15 else Vector2.ZERO
	changed.emit(value)


func _draw() -> void:
	draw_circle(_base, radius, Color(1, 1, 1, 0.12))
	draw_arc(_base, radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(_knob, radius * 0.42, Color(1, 1, 1, 0.45))
