extends Node3D
## Efectos de los infectados especiales en el suelo:
##  - "cloud": nube de veneno (purulento al reventar).
##  - "rock": roca lanzada por el coloso; marca su sombra donde va a caer.
##  - "stomp": círculo rojo que avisa del pisotón del coloso.

var mode := "cloud"
var radius := 3.0
var duration := 5.0
var poison := 12.0
var damage := 18.0
var from := Vector3.ZERO
var to := Vector3.ZERO
var flight := 1.1
var _t := 0.0
var _tick := 0.0
var _rock: Node3D
var _disc: MeshInstance3D


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _disc_mesh(r: float, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = r
	cy.bottom_radius = r
	cy.height = 0.02
	cy.radial_segments = 24
	m.mesh = cy
	m.material_override = _mat(c)
	m.position.y = 0.04
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func _ready() -> void:
	add_to_group("hazard")
	match mode:
		"cloud":
			_disc = _disc_mesh(radius, Color(0.62, 0.72, 0.18, 0.35))
			var fog := CPUParticles3D.new()
			fog.amount = 26
			fog.lifetime = 1.6
			fog.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			fog.emission_sphere_radius = radius * 0.8
			fog.direction = Vector3.UP
			fog.spread = 30.0
			fog.gravity = Vector3(0, 0.5, 0)
			fog.initial_velocity_min = 0.2
			fog.initial_velocity_max = 0.6
			fog.scale_amount_min = 0.6
			fog.scale_amount_max = 1.3
			var puff := SphereMesh.new()
			puff.radius = 0.45
			puff.height = 0.7
			puff.radial_segments = 6
			puff.rings = 3
			puff.material = _mat(Color(0.7, 0.78, 0.25, 0.3))
			fog.mesh = puff
			fog.position.y = 0.6
			add_child(fog)
			_check_cloud()
		"rock":
			global_position = to
			_disc = _disc_mesh(1.4, Color(0, 0, 0, 0.35))
			_rock = Node3D.new()
			var m := MeshInstance3D.new()
			m.mesh = Nature.blob(9, 0.25, 6, 3, false)
			m.material_override = CharacterModel.mat(Color("8b8982"))
			m.scale = Vector3.ONE * 0.45
			_rock.add_child(m)
			add_child(_rock)
			_rock.global_position = from
		"stomp":
			_disc = _disc_mesh(radius, Color(0.85, 0.1, 0.05, 0.25))


func _physics_process(delta: float) -> void:
	_t += delta
	match mode:
		"cloud":
			_tick -= delta
			if _tick <= 0.0:
				_tick = 0.5
				_check_cloud()
			_disc.material_override.albedo_color.a = 0.35 * clampf((duration - _t) / 1.0, 0.0, 1.0)
			if _t >= duration:
				queue_free()
		"rock":
			var f := clampf(_t / flight, 0.0, 1.0)
			var p := from.lerp(to, f)
			p.y += sin(f * PI) * 5.0 + (from.y * (1.0 - f))
			_rock.global_position = p
			_rock.rotation += Vector3(4.0, 3.0, 0.0) * delta
			_disc.scale = Vector3.ONE * (0.4 + 0.6 * f)
			if f >= 1.0:
				_land()
		"stomp":
			_disc.material_override.albedo_color.a = 0.15 + 0.35 * clampf(_t / duration, 0.0, 1.0)
			if _t >= duration:
				queue_free()


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _check_cloud() -> void:
	var p := _player()
	if p and p.global_position.distance_to(global_position) <= radius:
		GS.poison_for(poison)


func _land() -> void:
	SFX.play("golpe", -2.0)
	var p := _player()
	if p and p.global_position.distance_to(global_position) <= 1.6 and GS.invulnerable <= 0.0:
		GS.hit(damage)
		if p.has_method("hurt_flash"):
			p.hurt_flash()
	queue_free()
