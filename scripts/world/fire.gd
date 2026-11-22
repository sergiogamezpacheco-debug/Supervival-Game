extends Node3D
## Cóctel molotov: vuela en arco hasta donde se lanza y deja el suelo ardiendo unos segundos.
## Quema a las criaturas que estén dentro (daño por segundo); al superviviente no le hace nada.

var from := Vector3.ZERO
var to := Vector3.ZERO
var flight := 0.55
var radius := 2.6
var duration := 5.0
var dps := 14.0
var burning := false
var _t := 0.0
var _tick := 0.0
var _bottle: Node3D
var _flames: Array = []
var _light: OmniLight3D


func _ready() -> void:
	add_to_group("fire")
	_bottle = Builder.tool_mesh("molotov")
	add_child(_bottle)
	global_position = from


func _process(delta: float) -> void:
	_t += delta
	if not burning:
		var k := clampf(_t / maxf(flight, 0.01), 0.0, 1.0)
		var p := from.lerp(to, k)
		p.y += sin(PI * k) * (1.0 + from.distance_to(to) * 0.12)
		global_position = p
		_bottle.rotation.x += delta * 14.0
		if k >= 1.0:
			ignite()
		return
	var left := duration - (_t - flight)
	var fade := clampf(left / 0.8, 0.0, 1.0)
	for i in _flames.size():
		var f: Node3D = _flames[i]
		var s := (0.75 + 0.3 * sin(_t * 11.0 + i * 1.7)) * fade
		f.scale = Vector3(s, s * (1.0 + 0.25 * sin(_t * 7.0 + i)), s)
	if _light:
		_light.light_energy = (1.8 + 0.5 * sin(_t * 17.0)) * fade
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		burn(dps * 0.5)
	if left <= 0.0:
		queue_free()


## Revienta la botella: charco de fuego en el suelo.
func ignite() -> void:
	if burning:
		return
	burning = true
	_t = flight
	global_position = to
	if _bottle:
		_bottle.queue_free()
		_bottle = null
	SFX.play("romper")
	var pool := Builder.part(Builder.cyl(radius, radius, 0.02), Color(0.95, 0.42, 0.08, 0.55), Vector3(0, 0.03, 0), 1.2)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(to.x * 31.0 + to.z * 17.0)
	for i in 11:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius * 0.85
		var h := rng.randf_range(0.5, 1.1)
		var f := Node3D.new()
		f.position = Vector3(cos(a) * d, 0.0, sin(a) * d)
		f.add_child(Builder.part(Builder.cyl(0.0, 0.22, h), Color(1.0, 0.5, 0.1), Vector3(0, h / 2.0, 0), 3.0))
		f.add_child(Builder.part(Builder.cyl(0.0, 0.12, h * 0.6), Color(1.0, 0.85, 0.3), Vector3(0, h * 0.3, 0), 3.5))
		add_child(f)
		_flames.append(f)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.omni_range = radius * 3.0
	_light.position = Vector3(0, 1.0, 0)
	add_child(_light)
	burn(dps * 0.5)


## Quema lo que haya dentro del fuego. Devuelve cuántas criaturas ha alcanzado.
func burn(dmg: float) -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group("creature"):
		var node := c as Node3D
		if node == null or not node.visible or float(node.get("hp")) <= 0.0:
			continue
		var d := Vector2(node.global_position.x - global_position.x, node.global_position.z - global_position.z).length()
		if d <= radius:
			node.take_damage(dmg, false, false, "")
			n += 1
	return n
