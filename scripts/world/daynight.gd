extends Node
## Luz del día y de la noche, linterna del superviviente y lluvia.
## La hora la da GS.hour() (reloj real, como las estaciones); aquí solo se pinta.

const NIGHT_BG := Color("0b111d")
const NIGHT_FOG := Color("121a29")
const NIGHT_AMB := Color("5266a0")
const DUSK_SUN := Color("ffb878")
const DAY_SUN := Color("fff4e2")
const MOON := Color("9fb4e8")

var env: Environment
var sun: DirectionalLight3D
var player: Node3D
var lantern: OmniLight3D
var rain: CPUParticles3D
var light := 1.0           # luz efectiva (día y lluvia), 0..1
var rain_amount := 0.0
var _day_bg: Color
var _day_fog: Color
var _day_amb: Color
var _day_amb_energy := 0.55
var _day_fog_density := 0.012


func setup(p_env: Environment, p_sun: DirectionalLight3D, p_player: Node3D) -> void:
	env = p_env
	sun = p_sun
	player = p_player
	_day_bg = env.background_color
	_day_fog = env.fog_light_color
	_day_amb = env.ambient_light_color
	_day_amb_energy = env.ambient_light_energy
	_day_fog_density = env.fog_density

	lantern = OmniLight3D.new()
	lantern.light_color = Color("ffc98a")
	lantern.omni_range = 9.0
	lantern.omni_attenuation = 1.2
	lantern.position = Vector3(0.0, 2.4, 0.0)
	lantern.light_energy = 0.0
	player.add_child(lantern)

	rain = CPUParticles3D.new()
	rain.amount = 420
	rain.lifetime = 0.55
	rain.local_coords = false
	rain.emitting = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(17.0, 0.5, 13.0)
	rain.direction = Vector3(0.12, -1.0, 0.0)
	rain.spread = 2.0
	rain.gravity = Vector3.ZERO
	rain.initial_velocity_min = 24.0
	rain.initial_velocity_max = 28.0
	var drop := BoxMesh.new()
	drop.size = Vector3(0.025, 0.55, 0.025)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(0.75, 0.85, 1.0, 0.45)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = dm
	rain.mesh = drop
	add_child(rain)
	update(0.0, true)


func update(delta: float, instant := false) -> void:
	if env == null:
		return
	var day := GS.daylight()
	var wet := 1.0 if GS.raining() else 0.0
	rain_amount = wet if instant else move_toward(rain_amount, wet, delta * 0.25)
	light = day * (1.0 - 0.35 * rain_amount)
	var h := GS.hour()

	# Sol (o luna): sube y baja, cálido al amanecer y anochecer, azulado de noche
	sun.light_energy = lerpf(0.12, 1.1, light)
	var warm := 1.0 - smoothstep(0.35, 0.95, day)
	sun.light_color = MOON.lerp(DAY_SUN.lerp(DUSK_SUN, warm), smoothstep(0.05, 0.4, day))
	sun.rotation_degrees = Vector3(lerpf(-28.0, -60.0, day), -35.0 + (h - 13.0) * 7.0, 0.0)
	env.ambient_light_color = NIGHT_AMB.lerp(_day_amb, light)
	env.ambient_light_energy = lerpf(0.34, _day_amb_energy, light)
	env.background_color = NIGHT_BG.lerp(_day_bg, light)
	env.fog_light_color = NIGHT_FOG.lerp(_day_fog, light)
	env.fog_density = _day_fog_density * (1.0 + rain_amount * 0.8 + (1.0 - day) * 0.6)

	lantern.light_energy = (1.0 - smoothstep(0.15, 0.65, light)) * 2.2

	rain.emitting = rain_amount > 0.4
	if player:
		rain.global_position = player.global_position + Vector3(-1.5, 12.0, 0.0)
