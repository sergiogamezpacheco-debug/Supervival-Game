extends Node
## Iconos de objetos sin lámina propia: se modelan en 3D imitando los diseños del usuario
## (low poly facetado, luz suave, vista 3/4) y se renderizan con fondo transparente.
##   xvfb-run ... res://tools/item_render.tscn -- <dir> [id ...]
## Después: python3 tools/iconos/recortar.py --contorno <dir>/*.png  (recorta y pone el contorno)

const M := preload("res://scripts/world/station_models.gd")
const IDS := ["hacha_hierro", "pico_hierro", "machete", "casco_obra", "chaqueta_piel", "chaleco",
	"pantalon_cargo", "zapatillas", "botas", "guantes", "fibra", "piel", "baya", "carne_cruda",
	"carne_asada", "seta", "carbon", "clavos", "tela_resistente", "botella_vacia", "lata_vacia", "cantimplora_vacia",
	"conserva_bayas", "acido", "cable_cobre", "circuito", "bateria", "sal", "tarro_cristal", "tarro_esterilizado", "comida_podrida", "hortalizas", "tierra", "madera_pino", "trozo_mapa_2", "trozo_mapa_3"]

var vp: SubViewport
var cam: Camera3D
var stage: Node3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp"
	var ids: Array = args.slice(1) if args.size() > 1 else IDS
	vp = SubViewport.new()
	vp.size = Vector2i(384, 384)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.66, 0.75)
	env.environment.ambient_light_energy = 0.8
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -40, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.95, 0.88)
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.75, 0.82, 1.0)
	vp.add_child(fill)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	stage = Node3D.new()
	vp.add_child(stage)
	for id in ids:
		for c in stage.get_children():
			c.queue_free()
		await get_tree().process_frame
		if not has_method("_" + id):
			continue
		var size := call("_" + id) as float
		cam.size = size
		cam.position = Vector3(1.6, 1.7, 1.9) * 3.0
		cam.look_at(Vector3.ZERO, Vector3.UP)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		for i in 4:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [out, id])
		print("icono ", id)
	get_tree().quit()


# ------------------------------------------------------------------ piezas

func _p(mesh: Mesh, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	return M._p(parent if parent else stage, mesh, color, pos, rot, scl)


func _box(s: Vector3) -> Mesh:
	return M._box(s)


func _cyl(t: float, b: float, h: float, seg := 8) -> Mesh:
	return M._cyl(t, b, h, seg)


func _blob(seed_: int, color: Color, pos: Vector3, scl: Vector3, rough := 0.18, parent: Node3D = null) -> MeshInstance3D:
	return _p(Nature.blob(seed_, rough, 7, 4), color, pos, Vector3(0, seed_ * 41 % 360, 0), scl, parent)


func _group(pos := Vector3.ZERO, rot := Vector3.ZERO) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees = rot
	stage.add_child(g)
	return g


const WOOD := Color("8a5a32")
const WOOD_D := Color("5e3b1f")
const STEEL := Color("b7bfc4")
const STEEL_D := Color("6f777c")


# ------------------------------------------------------------ herramientas

func _hacha_hierro() -> float:
	var g := _group(Vector3.ZERO, Vector3(0, 0, -35))
	_p(_cyl(0.07, 0.085, 1.9, 7), WOOD, Vector3(0, -0.1, 0), Vector3.ZERO, Vector3.ONE, g)
	_p(_cyl(0.095, 0.095, 0.3, 7), WOOD_D, Vector3(0, -0.85, 0), Vector3.ZERO, Vector3.ONE, g)
	# cabeza de acero: cuerpo, cuña y filo claro
	_p(_box(Vector3(0.24, 0.3, 0.16)), STEEL_D, Vector3(0, 0.66, 0), Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.52, 0.36, 0.1)), STEEL, Vector3(-0.34, 0.66, 0), Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.1, 0.58, 0.07)), Color("e3e8ea"), Vector3(-0.62, 0.66, 0), Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.16, 0.2, 0.12)), STEEL_D, Vector3(0.19, 0.66, 0), Vector3.ZERO, Vector3.ONE, g)
	return 2.4


func _pico_hierro() -> float:
	var g := _group(Vector3.ZERO, Vector3(0, 0, -35))
	_p(_cyl(0.07, 0.085, 1.9, 7), WOOD, Vector3(0, -0.1, 0), Vector3.ZERO, Vector3.ONE, g)
	_p(_cyl(0.095, 0.095, 0.3, 7), WOOD_D, Vector3(0, -0.85, 0), Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.22, 0.24, 0.18)), STEEL_D, Vector3(0, 0.78, 0), Vector3.ZERO, Vector3.ONE, g)
	for side in [-1.0, 1.0]:
		# brazos del pico, curvados y en punta
		_p(_cyl(0.07, 0.11, 0.42, 5), STEEL, Vector3(side * 0.3, 0.74, 0), Vector3(0, 0, side * -78), Vector3.ONE, g)
		_p(_cyl(0.0, 0.07, 0.36, 5), Color("dfe5e8"), Vector3(side * 0.66, 0.62, 0), Vector3(0, 0, side * -112), Vector3.ONE, g)
	return 2.3


func _machete() -> float:
	var g := _group(Vector3.ZERO, Vector3(0, 0, -40))
	_p(_box(Vector3(0.16, 0.5, 0.12)), Color("2e2a26"), Vector3(0, -0.75, 0), Vector3.ZERO, Vector3.ONE, g)
	for i in 4:
		_p(_box(Vector3(0.17, 0.03, 0.13)), Color("5a4a3a"), Vector3(0, -0.92 + i * 0.12, 0), Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.3, 0.07, 0.15)), STEEL_D, Vector3(0, -0.47, 0), Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.24, 1.25, 0.03)), STEEL, Vector3(0.02, 0.18, 0), Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.05, 1.25, 0.032)), Color("e7ecee"), Vector3(-0.1, 0.18, 0), Vector3.ZERO, Vector3.ONE, g)
	_p(_cyl(0.0, 0.17, 0.32, 4), STEEL, Vector3(0.02, 0.95, 0), Vector3(0, 45, 0), Vector3(1, 1, 0.12), g)
	return 2.4


# ---------------------------------------------------------------- ropa

func _casco_obra() -> float:
	var y := Color("e8b52f")
	var hemi := SphereMesh.new()
	hemi.radius = 0.62
	hemi.height = 0.62
	hemi.is_hemisphere = true
	hemi.radial_segments = 12
	hemi.rings = 5
	_p(hemi, y, Vector3(0, 0.0, 0))
	_p(_cyl(0.78, 0.8, 0.06, 14), y.darkened(0.1), Vector3(0, 0.02, 0.1), Vector3.ZERO, Vector3(1, 1, 1.12))
	_p(_box(Vector3(0.14, 0.12, 1.1)), y.lightened(0.08), Vector3(0, 0.58, 0))
	_p(_cyl(0.6, 0.6, 0.05, 12), Color("3a3a36"), Vector3(0, 0.06, 0))
	return 1.9


func _chaqueta_piel() -> float:
	var c := Color("7a4b2c")
	var g := _group()
	_p(_box(Vector3(0.95, 1.05, 0.42)), c, Vector3(0, 0, 0), Vector3.ZERO, Vector3.ONE, g)
	for side in [-1.0, 1.0]:
		_p(_cyl(0.15, 0.13, 0.95, 7), c.darkened(0.05), Vector3(side * 0.62, -0.08, 0), Vector3(0, 0, side * 14), Vector3.ONE, g)
		_p(_cyl(0.14, 0.14, 0.1, 7), c.darkened(0.3), Vector3(side * 0.73, -0.55, 0), Vector3(0, 0, side * 14), Vector3.ONE, g)
		_p(_box(Vector3(0.3, 0.22, 0.04)), c.lightened(0.08), Vector3(side * 0.22, 0.48, 0.21), Vector3(0, 0, side * 28), Vector3.ONE, g)
		_p(_box(Vector3(0.24, 0.16, 0.03)), c.darkened(0.12), Vector3(side * 0.24, -0.25, 0.22), Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.03, 1.0, 0.03)), Color("c9b48a"), Vector3(0, -0.02, 0.22), Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.97, 0.1, 0.44)), c.darkened(0.25), Vector3(0, -0.5, 0), Vector3.ZERO, Vector3.ONE, g)
	return 2.1


func _chaleco() -> float:
	var c := Color("56603d")
	_p(_box(Vector3(0.9, 1.0, 0.45)), c, Vector3.ZERO)
	for side in [-1.0, 1.0]:
		_p(_box(Vector3(0.22, 0.24, 0.06)), c.lightened(0.1), Vector3(side * 0.22, -0.18, 0.24))
		_p(_box(Vector3(0.18, 0.18, 0.06)), c.lightened(0.06), Vector3(side * 0.24, 0.16, 0.24))
		_p(_box(Vector3(0.12, 0.3, 0.44)), c.darkened(0.15), Vector3(side * 0.38, 0.52, 0))
	_p(_box(Vector3(0.92, 0.08, 0.47)), Color("2c2f24"), Vector3(0, -0.36, 0))
	_p(_box(Vector3(0.92, 0.08, 0.47)), Color("2c2f24"), Vector3(0, 0.0, 0))
	return 1.8


func _pantalon_cargo() -> float:
	var c := Color("8a7a55")
	_p(_box(Vector3(0.8, 0.22, 0.38)), c.darkened(0.15), Vector3(0, 0.62, 0))
	for side in [-1.0, 1.0]:
		_p(_box(Vector3(0.36, 1.25, 0.34)), c, Vector3(side * 0.2, -0.1, 0), Vector3(0, 0, side * 4))
		_p(_box(Vector3(0.08, 0.3, 0.26)), c.lightened(0.08), Vector3(side * 0.41, 0.0, 0.0), Vector3(0, 0, side * 4))
		_p(_box(Vector3(0.38, 0.08, 0.36)), c.darkened(0.25), Vector3(side * 0.24, -0.7, 0), Vector3(0, 0, side * 4))
	return 2.1


func _shoe(pos: Vector3, upper: Color, sole: Color, tall := 0.0, yaw := 0.0) -> void:
	var g := _group(pos, Vector3(0, yaw, 0))
	_p(_box(Vector3(0.32, 0.08, 0.78)), sole, Vector3(0, 0.04, 0), Vector3.ZERO, Vector3.ONE, g)
	_blob(5, upper, Vector3(0, 0.17, 0.08), Vector3(0.3, 0.17, 0.42), 0.08, g)
	_p(_box(Vector3(0.28, 0.26 + tall, 0.32)), upper.darkened(0.06), Vector3(0, 0.22 + tall / 2.0, -0.2), Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.2, 0.03, 0.28)), sole.lightened(0.2) if tall == 0.0 else upper.lightened(0.2), Vector3(0, 0.3 + tall * 0.6, 0.12), Vector3(-25, 0, 0), Vector3.ONE, g)


func _zapatillas() -> float:
	_shoe(Vector3(-0.22, 0, 0.05), Color("4f6f9a"), Color("eeeeea"), 0.0, -8)
	_shoe(Vector3(0.22, 0, -0.08), Color("4f6f9a"), Color("eeeeea"), 0.0, 6)
	return 1.6


func _botas() -> float:
	_shoe(Vector3(-0.22, 0, 0.05), Color("5a3b24"), Color("2a2522"), 0.45, -8)
	_shoe(Vector3(0.22, 0, -0.08), Color("5a3b24"), Color("2a2522"), 0.45, 6)
	return 1.8


func _glove(pos: Vector3, yaw: float) -> void:
	var c := Color("6b4a32")
	var g := _group(pos, Vector3(-60, yaw, 0))
	_p(_box(Vector3(0.36, 0.42, 0.13)), c, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.4, 0.14, 0.15)), c.darkened(0.3), Vector3(0, -0.27, 0), Vector3.ZERO, Vector3.ONE, g)
	for i in 4:
		_p(_box(Vector3(0.075, 0.3, 0.1)), c.lightened(0.05), Vector3(-0.13 + i * 0.087, 0.34, 0), Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.08, 0.24, 0.1)), c.lightened(0.05), Vector3(0.24, 0.02, 0), Vector3(0, 0, -40), Vector3.ONE, g)


func _guantes() -> float:
	_glove(Vector3(-0.25, 0, 0), 10)
	_glove(Vector3(0.25, 0.05, -0.1), -14)
	return 1.6


# --------------------------------------------------------- comida y materiales

func _fibra() -> float:
	var g := _group(Vector3.ZERO, Vector3(0, 0, -30))
	for i in 9:
		var a := float(i) * 0.7
		var col := Color("9bb54a").lerp(Color("d8c66a"), float(i % 3) / 2.0)
		_p(_box(Vector3(0.04, 1.6, 0.04)), col, Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), Vector3(sin(a) * 6, 0, cos(a) * 6), Vector3.ONE, g)
	_p(_cyl(0.16, 0.16, 0.14, 8), Color("8a6a3a"), Vector3(0, -0.15, 0), Vector3.ZERO, Vector3.ONE, g)
	return 1.9


func _piel() -> float:
	_blob(11, Color("8a5f3c"), Vector3(0, 0, 0), Vector3(0.9, 0.08, 0.7), 0.3)
	_blob(12, Color("c9a27a"), Vector3(0.05, 0.05, 0.05), Vector3(0.6, 0.05, 0.45), 0.25)
	for k in 4:
		var a := float(k) * TAU / 4.0 + 0.6
		_blob(20 + k, Color("7a5234"), Vector3(cos(a) * 0.82, -0.02, sin(a) * 0.62), Vector3(0.22, 0.05, 0.16), 0.2)
	return 2.0


func _baya() -> float:
	var pts := [Vector3(0, 0.18, 0), Vector3(0.22, 0.12, 0.08), Vector3(-0.2, 0.1, 0.1), Vector3(0.05, 0.1, 0.25), Vector3(-0.08, 0.05, -0.2), Vector3(0.2, 0.05, -0.15), Vector3(-0.25, 0.0, -0.05)]
	for i in pts.size():
		var col := Color("6a2a5a") if i % 2 == 0 else Color("8a2f4a")
		_blob(30 + i, col, pts[i], Vector3(0.17, 0.17, 0.17), 0.05)
		_p(_box(Vector3(0.05, 0.05, 0.05)), Color("e9a6c9"), pts[i] + Vector3(0.05, 0.12, 0.08))
	for k in 3:
		_p(_box(Vector3(0.36, 0.02, 0.16)), Color("4f7a35"), Vector3(-0.1 + k * 0.12, 0.28, -0.12), Vector3(0, k * 50, 20))
	return 1.2


func _carne_cruda() -> float:
	_blob(41, Color("f0e2d2"), Vector3(0, -0.02, 0), Vector3(0.82, 0.16, 0.6), 0.12)
	_blob(42, Color("b8333a"), Vector3(0, 0.03, 0), Vector3(0.74, 0.18, 0.52), 0.12)
	_blob(43, Color("d8545a"), Vector3(-0.15, 0.1, 0.05), Vector3(0.35, 0.08, 0.25), 0.15)
	_p(_cyl(0.08, 0.08, 0.3, 6), Color("efe8da"), Vector3(0.62, 0.0, 0.1), Vector3(0, 0, 90))
	return 1.9


func _carne_asada() -> float:
	_blob(51, Color("7a3e1e"), Vector3(-0.1, 0.0, 0), Vector3(0.55, 0.4, 0.45), 0.12)
	_blob(52, Color("a8592a"), Vector3(-0.2, 0.15, 0.12), Vector3(0.28, 0.14, 0.2), 0.2)
	_p(_cyl(0.07, 0.07, 0.6, 6), Color("efe8da"), Vector3(0.45, 0.0, 0), Vector3(0, 0, 90))
	_blob(53, Color("f3ecdf"), Vector3(0.78, 0.0, 0), Vector3(0.13, 0.16, 0.16), 0.1)
	for k in 3:
		_p(_box(Vector3(0.35, 0.02, 0.04)), Color("3a1a0c"), Vector3(-0.2, 0.36, -0.1 + k * 0.12), Vector3(0, 20, 0))
	return 1.9


func _seta() -> float:
	var cap := SphereMesh.new()
	cap.radius = 0.5
	cap.height = 0.5
	cap.is_hemisphere = true
	cap.radial_segments = 10
	cap.rings = 4
	_p(_cyl(0.14, 0.18, 0.55, 8), Color("efe6d2"), Vector3(0, -0.25, 0))
	_p(cap, Color("c43a2e"), Vector3(0, 0.02, 0))
	_p(_cyl(0.5, 0.5, 0.03, 10), Color("e8d9bd"), Vector3(0, 0.02, 0))
	for k in 6:
		var a := float(k) * TAU / 6.0
		_p(_box(Vector3(0.09, 0.05, 0.09)), Color("f6efe2"), Vector3(cos(a) * 0.3, 0.3, sin(a) * 0.3), Vector3(0, k * 20, 0))
	_p(_box(Vector3(0.1, 0.05, 0.1)), Color("f6efe2"), Vector3(0, 0.5, 0))
	return 1.4


func _carbon() -> float:
	var pts := [Vector3(0, 0, 0), Vector3(0.38, -0.05, 0.12), Vector3(-0.32, -0.06, 0.15), Vector3(0.05, -0.06, -0.33), Vector3(0.1, 0.25, 0.05)]
	for i in pts.size():
		_blob(60 + i, Color("2b2b2d").lightened(0.05 * (i % 2)), pts[i], Vector3(0.3, 0.24, 0.27), 0.3)
	return 1.5


func _clavos() -> float:
	# puñado de clavos tirados, cabeza plana y punta
	for k in 9:
		var a := float(k) * 2.4
		var g := _group(Vector3(cos(a) * 0.32 * (0.4 + 0.07 * k), 0, sin(a) * 0.3 * (0.4 + 0.07 * k)), Vector3(84 + k * 3, k * 47, 0))
		_p(_cyl(0.035, 0.035, 0.9, 6), STEEL, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, g)
		_p(_cyl(0.09, 0.09, 0.04, 8), STEEL_D, Vector3(0, 0.46, 0), Vector3.ZERO, Vector3.ONE, g)
		_p(_cyl(0.0, 0.035, 0.12, 6), Color("dfe5e8"), Vector3(0, -0.51, 0), Vector3(180, 0, 0), Vector3.ONE, g)
	return 1.9


func _tela_resistente() -> float:
	# lona doblada en capas, color caqui, con costura
	for k in 3:
		var c := Color("8c8a5e").lerp(Color("6f7048"), float(k) / 2.0)
		_p(_box(Vector3(1.5, 0.1, 1.0)), c, Vector3(k * 0.03, k * 0.11, -k * 0.02), Vector3(0, k * 4, 0))
		_p(_box(Vector3(1.52, 0.012, 0.03)), Color("d9cfa2"), Vector3(k * 0.03, k * 0.11 + 0.056, 0.42 - k * 0.02), Vector3(0, k * 4, 0))
	_p(_box(Vector3(0.2, 0.36, 1.04)), Color("7d7b52"), Vector3(0.74, 0.12, 0), Vector3(0, 0, 8))
	return 2.1


# ------------------------------------------------- cocina, destilería, química y electrónica

func _clear(mesh: Mesh, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var m := M._clear(parent if parent else stage, mesh, color, pos, rot)
	return m


func _botella_vacia() -> float:
	# botella de plástico vacía, tumbada, con tapón azul (como las de la destilería)
	var g := _group(Vector3.ZERO, Vector3(0, 0, -60))
	_clear(_cyl(0.24, 0.24, 0.9, 10), Color(0.78, 0.88, 0.95, 0.55), Vector3(0, -0.1, 0), Vector3.ZERO, g)
	for k in 3:
		_p(_cyl(0.245, 0.245, 0.04, 10), Color("b9d3e2"), Vector3(0, -0.4 + k * 0.22, 0), Vector3.ZERO, Vector3.ONE, g)
	_clear(_cyl(0.1, 0.24, 0.3, 10), Color(0.78, 0.88, 0.95, 0.55), Vector3(0, 0.5, 0), Vector3.ZERO, g)
	_p(_cyl(0.11, 0.11, 0.12, 10), Color("3f7fb5"), Vector3(0, 0.7, 0), Vector3.ZERO, Vector3.ONE, g)
	return 1.6


func _lata_vacia() -> float:
	# lata abierta: cuerpo con aros, tapa doblada hacia atrás
	_p(_cyl(0.42, 0.42, 0.95, 12), Color("b9bfc3"), Vector3(0, -0.05, 0))
	for y in [-0.42, 0.0, 0.32]:
		_p(_cyl(0.43, 0.43, 0.05, 12), Color("9aa1a6"), Vector3(0, y, 0))
	_p(_cyl(0.38, 0.38, 0.02, 12), Color("4d5257"), Vector3(0, 0.43, 0))
	_p(_cyl(0.4, 0.4, 0.02, 12), Color("cfd4d7"), Vector3(0, 0.62, 0.32), Vector3(-70, 0, 0))
	return 1.6


func _cantimplora_vacia() -> float:
	# la cantimplora del diseño (cerámica clara con cinchas), destapada y con el tapón al lado
	_blob(71, Color("d8dbd8"), Vector3(0, -0.05, 0), Vector3(0.62, 0.7, 0.5), 0.1)
	_p(_cyl(0.6, 0.6, 0.2, 9), Color("b9a37f"), Vector3(0, -0.1, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.82))
	_p(_cyl(0.16, 0.22, 0.28, 8), Color("c9ccc9"), Vector3(0, 0.55, 0))
	_p(_cyl(0.14, 0.14, 0.04, 8), Color("2a2a2a"), Vector3(0, 0.7, 0))
	_p(_cyl(0.13, 0.15, 0.2, 8), Color("b98a56"), Vector3(0.5, -0.6, -0.3), Vector3(0, 0, 80))
	return 1.9


func _conserva_bayas() -> float:
	# lata con etiqueta morada y bayas pintadas
	_p(_cyl(0.42, 0.42, 0.95, 12), Color("b9bfc3"), Vector3(0, -0.05, 0))
	_p(_cyl(0.43, 0.43, 0.6, 12), Color("6a2a5a"), Vector3(0, -0.05, 0))
	_p(_cyl(0.435, 0.435, 0.08, 12), Color("e7d8b8"), Vector3(0, 0.18, 0))
	for k in 3:
		_blob(30 + k, Color("8a2f4a"), Vector3(-0.12 + k * 0.12, -0.12 + (k % 2) * 0.08, -0.4), Vector3(0.1, 0.1, 0.05), 0.05)
	_p(_cyl(0.4, 0.4, 0.04, 12), Color("cfd4d7"), Vector3(0, 0.44, 0))
	return 1.6


func _acido() -> float:
	# frasco de cristal grueso con líquido amarillo verdoso y calavera simple en la etiqueta
	_clear(_cyl(0.32, 0.36, 0.8, 8), Color(0.82, 0.9, 0.9, 0.45), Vector3(0, -0.1, 0))
	_p(_cyl(0.3, 0.34, 0.5, 8), Color("c8d44a"), Vector3(0, -0.24, 0))
	_p(_cyl(0.33, 0.35, 0.22, 8), Color("efe6d2"), Vector3(0, -0.12, 0))
	_p(_box(Vector3(0.14, 0.1, 0.02)), Color("2a2a2a"), Vector3(0, -0.08, -0.35))
	_p(_cyl(0.16, 0.2, 0.16, 8), Color(0.82, 0.9, 0.9), Vector3(0, 0.38, 0))
	_p(_cyl(0.19, 0.19, 0.14, 8), Color("2d2d2d"), Vector3(0, 0.52, 0))
	return 1.5


func _cable_cobre() -> float:
	# rollo de cable de cobre
	for k in 5:
		var t := TorusMesh.new()
		t.inner_radius = 0.38
		t.outer_radius = 0.46
		t.rings = 14
		t.ring_segments = 5
		_p(t, Color("c57a45").lightened(0.06 * (k % 2)), Vector3(0, -0.12 + k * 0.06, 0), Vector3(4 * (k % 2), 0, 0))
	_p(_cyl(0.025, 0.025, 0.6, 5), Color("d88b52"), Vector3(0.45, 0.1, -0.2), Vector3(70, 30, 0))
	return 1.4


func _circuito() -> float:
	# placa verde sencilla con chips y pistas
	_p(_box(Vector3(1.3, 0.06, 0.9)), Color("2f6b45"), Vector3.ZERO, Vector3(0, 20, 0))
	var g := _group(Vector3.ZERO, Vector3(0, 20, 0))
	for k in 4:
		_p(_box(Vector3(0.22, 0.08, 0.16)), Color("1e2420"), Vector3(-0.4 + k * 0.27, 0.07, -0.18), Vector3.ZERO, Vector3.ONE, g)
	_p(_box(Vector3(0.3, 0.1, 0.3)), Color("2a2a2a"), Vector3(-0.1, 0.08, 0.2), Vector3.ZERO, Vector3.ONE, g)
	for k in 3:
		_p(_cyl(0.06, 0.06, 0.14, 8), Color("c6a248"), Vector3(0.35 + k * 0.1, 0.1, 0.25), Vector3.ZERO, Vector3.ONE, g)
	for k in 5:
		_p(_box(Vector3(1.0, 0.012, 0.025)), Color("d1b25a"), Vector3(0, 0.035, -0.38 + k * 0.05), Vector3.ZERO, Vector3.ONE, g)
	return 1.7


func _bateria() -> float:
	# pila de laboratorio: tapas metálicas y núcleo verde que brilla (como en el banco de electrónica)
	_p(_cyl(0.36, 0.36, 0.14, 8), Color("6a6560"), Vector3(0, -0.45, 0))
	_p(_cyl(0.3, 0.3, 0.75, 8), Color("47d56a"), Vector3(0, 0.0, 0))
	_clear(_cyl(0.34, 0.34, 0.78, 8), Color(0.8, 0.95, 0.85, 0.35), Vector3(0, 0.0, 0))
	_p(_cyl(0.36, 0.36, 0.14, 8), Color("6a6560"), Vector3(0, 0.45, 0))
	_p(_cyl(0.12, 0.12, 0.1, 8), Color("8a8580"), Vector3(0, 0.56, 0))
	return 1.5


# ----------------------------------------------------------- conservas y comida podrida

func _sal() -> float:
	# salero de cristal con sal y tapa metálica agujereada
	_p(_cyl(0.3, 0.34, 0.8, 8), Color("dfe9ee"))
	_p(_cyl(0.305, 0.345, 0.55, 8), Color("f7f7f3"), Vector3(0, -0.12, 0))
	_p(_cyl(0.31, 0.31, 0.2, 10), Color("c9ced2"), Vector3(0, 0.5, 0))
	_p(_cyl(0.2, 0.31, 0.12, 10), Color("b3b9bd"), Vector3(0, 0.66, 0))
	for k in 5:
		var a := float(k) * TAU / 5.0
		_p(_cyl(0.025, 0.025, 0.02, 6), Color("4d5257"), Vector3(cos(a) * 0.1, 0.73, sin(a) * 0.1))
	return 1.6


func _tarro(lid: Color, steam: bool) -> float:
	_p(_cyl(0.42, 0.42, 0.85, 10), Color("bcd6d6"), Vector3(0, -0.08, 0))
	for k in 2:
		_p(_box(Vector3(0.06, 0.6, 0.02)), Color("eef7f7"), Vector3(-0.05 + k * 0.1, -0.05, 0.41))
	_p(_cyl(0.34, 0.36, 0.06, 10), Color(0.75, 0.85, 0.85), Vector3(0, -0.5, 0))
	_p(_cyl(0.33, 0.37, 0.12, 10), Color(0.8, 0.9, 0.9), Vector3(0, 0.4, 0))
	_p(_cyl(0.36, 0.36, 0.14, 10), lid, Vector3(0, 0.5, 0))
	_p(_cyl(0.3, 0.3, 0.02, 10), lid.lightened(0.15), Vector3(0, 0.58, 0))
	if steam:
		# etiqueta azul de "esterilizado"
		_p(_box(Vector3(0.5, 0.3, 0.02)), Color("3f7fb5"), Vector3(0.1, -0.1, 0.42))
		_p(_box(Vector3(0.3, 0.05, 0.021)), Color("eef2f5"), Vector3(0.1, -0.08, 0.43))
	return 1.7


func _tarro_cristal() -> float:
	return _tarro(Color("b98a3a"), false)


func _tarro_esterilizado() -> float:
	return _tarro(Color("c9ced2"), true)


func _comida_podrida() -> float:
	# filete verdoso con manchas y moscas
	_blob(41, Color("c8c6a0"), Vector3(0, -0.02, 0), Vector3(0.82, 0.16, 0.6), 0.12)
	_blob(42, Color("6f7a3a"), Vector3(0, 0.03, 0), Vector3(0.74, 0.18, 0.52), 0.12)
	for k in 5:
		_blob(50 + k, Color("3f4a22") if k % 2 == 0 else Color("8a8a3a"), Vector3(-0.3 + k * 0.15, 0.13, -0.15 + (k % 3) * 0.12), Vector3(0.12, 0.05, 0.1), 0.2)
	for k in 3:
		_p(_box(Vector3(0.07, 0.05, 0.09)), Color("1c1c1c"), Vector3(-0.2 + k * 0.22, 0.45 + (k % 2) * 0.15, 0.1))
	return 1.9


# ----------------------------------------------------------- compostadora y huerto

func _abono() -> float:
	# saco de arpillera abierto con compost oscuro asomando
	_blob(91, Color("a88a5a"), Vector3(0, -0.1, 0), Vector3(0.6, 0.62, 0.48), 0.1)
	_p(_cyl(0.42, 0.5, 0.2, 9), Color("b89a66"), Vector3(0, 0.42, 0))
	_blob(92, Color("3b2a1e"), Vector3(0, 0.55, 0), Vector3(0.42, 0.14, 0.36), 0.15)
	for k in 4:
		_blob(93 + k, [Color("6d8a3a"), Color("a8763a"), Color("5f7a30"), Color("4a3424")][k], Vector3(-0.18 + k * 0.12, 0.64, -0.05 + (k % 2) * 0.1), Vector3(0.08, 0.03, 0.06), 0.2)
	_p(_box(Vector3(0.5, 0.05, 0.02)), Color("7a6040"), Vector3(0, 0.0, 0.47))
	return 1.8


func _hortalizas() -> float:
	# dos zanahorias con hojas y tres patatas
	for k in 2:
		var g := _group(Vector3(-0.25 + k * 0.35, 0.05, -0.05 * k), Vector3(0, 30 * k, 70 + 10 * k))
		_p(_cyl(0.13, 0.02, 0.75, 8), Color("e8822e"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, g)
		for j in 3:
			_p(_cyl(0.04, 0.0, 0.35, 5), Color("5f9a35"), Vector3(-0.04 + j * 0.04, 0.52, 0), Vector3(0, 0, -20 + j * 20), Vector3.ONE, g)
	for k in 3:
		_blob(70 + k, Color("b88a52"), Vector3(-0.35 + k * 0.32, -0.3, 0.25 - (k % 2) * 0.12), Vector3(0.2, 0.15, 0.17), 0.12)
	return 1.8


func _tierra() -> float:
	# montón de tierra marrón clara con piedrecitas
	_blob(101, Color("8a6440"), Vector3(0, -0.15, 0), Vector3(0.8, 0.42, 0.7), 0.12)
	_blob(102, Color("9c7449"), Vector3(0.1, 0.05, 0.05), Vector3(0.45, 0.3, 0.4), 0.12)
	for k in 5:
		var a := float(k) * 1.3
		_blob(110 + k, Color("9a9a92"), Vector3(cos(a) * 0.45, -0.3 + float(k % 2) * 0.15, sin(a) * 0.4), Vector3(0.08, 0.06, 0.07), 0.2)
	return 1.8


# ----------------------------------------------------------- madera de pino y trozos de mapa

func _madera_pino() -> float:
	# tres troncos de pino más gruesos y rojizos, con gotas de resina
	for k in 3:
		var g := _group(Vector3(-0.28 + k * 0.28, -0.2 + (1 if k == 1 else 0) * 0.4, 0.0 if k != 1 else -0.05), Vector3(0, 0, 90))
		_p(_cyl(0.24, 0.24, 1.5, 9), Color("7a4a2c"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, g)
		_p(_cyl(0.2, 0.2, 0.02, 9), Color("d8b07a"), Vector3(0, 0.76, 0), Vector3.ZERO, Vector3.ONE, g)
		_p(_cyl(0.11, 0.11, 0.025, 9), Color("b88a52"), Vector3(0, 0.77, 0), Vector3.ZERO, Vector3.ONE, g)
	for k in 3:
		_blob(60 + k, Color("e0a83a"), Vector3(-0.3 + k * 0.3, 0.15 + (k % 2) * 0.2, -0.22), Vector3(0.05, 0.07, 0.04), 0.1)
	return 1.9


func _trozo_mapa() -> float:
	# trozo de papel viejo rasgado con caminos y una cruz roja
	var g := _group(Vector3.ZERO, Vector3(10, 25, 0))
	_p(_box(Vector3(1.3, 0.02, 1.0)), Color("e0c896"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, g)
	for k in 6:
		_p(_box(Vector3(0.12, 0.022, 0.14)), Color("2c2620"), Vector3(-0.66 + 0.01, 0, -0.45 + k * 0.18), Vector3(0, 30 * (k % 2), 0), Vector3.ONE, g)
	for k in 5:
		_p(_box(Vector3(0.18, 0.025, 0.03)), Color("8a5a32"), Vector3(-0.4 + k * 0.2, 0.01, 0.1 * sin(k)), Vector3(0, 20 * k, 0), Vector3.ONE, g)
	_p(_box(Vector3(0.9, 0.025, 0.05)), Color("6e9aa6"), Vector3(0.1, 0.01, -0.3), Vector3(0, -15, 0), Vector3.ONE, g)
	_p(_box(Vector3(0.22, 0.03, 0.05)), Color("a8281e"), Vector3(0.35, 0.02, 0.25), Vector3(0, 45, 0), Vector3.ONE, g)
	_p(_box(Vector3(0.22, 0.03, 0.05)), Color("a8281e"), Vector3(0.35, 0.02, 0.25), Vector3(0, -45, 0), Vector3.ONE, g)
	return 1.8


func _trozo_mapa_2() -> float:
	return _trozo_mapa()


func _trozo_mapa_3() -> float:
	return _trozo_mapa()
