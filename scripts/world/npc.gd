class_name Npc
extends Node3D
## Supervivientes de los poblados (La Atalaya): comerciantes detrás de su puesto y arqueros en las
## torres. Los arqueros disparan a los infectados que se acercan a la empalizada.

const LOOKS := {
	"mercader": {"look": {"sex": "m", "skin": 2, "hair": 3, "hair_color": 4, "mouth": 1},
		"outfit": {"torso": "chaqueta_piel", "piernas": "pantalon_tela", "pies": "botas", "cabeza": "gorra"}},
	"armero": {"look": {"sex": "m", "skin": 1, "hair": 0, "hair_color": 0, "mouth": 4},
		"outfit": {"torso": "chaleco", "piernas": "pantalon_cargo", "pies": "botas", "manos": "guantes"}},
	"arquero": {"look": {"sex": "f", "skin": 1, "hair": 2, "hair_color": 1, "mouth": 0},
		"outfit": {"torso": "chaqueta_piel", "piernas": "pantalon_cargo", "pies": "botas"}},
}

var role := "mercader"
var model: CharacterModel
var _t := 0.0
var _shot_cd := 0.0
var _arrow: Node3D = null
var _arrow_from := Vector3.ZERO
var _arrow_to: Node3D = null
var _arrow_t := 0.0


func _init(p_role := "mercader") -> void:
	role = p_role


func _ready() -> void:
	var d: Dictionary = LOOKS.get(role, LOOKS["mercader"])
	model = CharacterModel.new(d["look"], {}, d["outfit"])
	add_child(model)
	_t = randf() * 10.0
	if role == "arquero":
		add_to_group("archer")
		var bow := Node3D.new()
		var arc := Builder.part(Builder.cyl(0.025, 0.025, 1.2), Color("6b4a2c"), Vector3.ZERO)
		bow.add_child(arc)
		var string_ := Builder.part(Builder.cyl(0.006, 0.006, 1.15), Color("e8e2d2"), Vector3(0, 0, 0.12))
		bow.add_child(string_)
		bow.rotation_degrees = Vector3(0, 0, 10)
		model.hand.add_child(bow)


func _process(delta: float) -> void:
	_t += delta
	if model == null or model.j.is_empty():
		return
	model.animate_walk(0.0, 0.0)
	model.animate_idle(_t, 1.0)
	if role == "arquero":
		_archer(delta)


## Arquero: mira al infectado más cercano dentro del alcance y le dispara cada poco.
func _archer(delta: float) -> void:
	_shot_cd -= delta
	var rng_m := float(DB.bal("archer_range", 20.0))
	var best: Node3D = null
	var bd := rng_m
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.visible or e.get("hp") == null or float(e.hp) <= 0.0:
			continue
		var d: float = (e as Node3D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	if best:
		var to := best.global_position - global_position
		model.rotation.y = atan2(-to.x, -to.z)
		if _shot_cd <= 0.0:
			_shot_cd = float(DB.bal("archer_cooldown", 1.8))
			_shoot(best)
	if _arrow:
		_arrow_t += delta / 0.35
		if _arrow_to == null or not is_instance_valid(_arrow_to) or _arrow_t >= 1.0:
			_arrow.queue_free()
			_arrow = null
		else:
			var p := _arrow_from.lerp(_arrow_to.global_position + Vector3(0, 1.2, 0), _arrow_t)
			_arrow.global_position = p
			_arrow.look_at(_arrow_to.global_position + Vector3(0, 1.2, 0), Vector3.UP)


func _shoot(target: Node3D) -> void:
	if _arrow:
		_arrow.queue_free()
	_arrow = Node3D.new()
	var shaft := Builder.part(Builder.cyl(0.02, 0.02, 0.8), Color("6b4a2c"), Vector3.ZERO)
	shaft.rotation_degrees.x = 90   # la flecha va a lo largo de -Z (look_at)
	_arrow.add_child(shaft)
	var tip := Builder.part(Builder.cyl(0.0, 0.04, 0.12), Color("9aa0a4"), Vector3(0, 0, -0.45))
	tip.rotation_degrees.x = -90
	_arrow.add_child(tip)
	get_parent().add_child(_arrow)
	_arrow_from = global_position + Vector3(0, 1.4, 0)
	_arrow.global_position = _arrow_from
	_arrow_to = target
	_arrow_t = 0.0
	if target.has_method("take_damage"):
		target.take_damage(float(DB.bal("archer_damage", 40.0)), false, false, "golpe")
