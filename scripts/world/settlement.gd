class_name Settlement
## Poblados de supervivientes (La Atalaya): empalizada de troncos con puerta, torres con arqueros,
## casas por dentro (sin saqueo: es gente viva) y adornos. Se describe en maps.json con "settlement":
##   {"rect": [x0, z0, x1, z1], "gate": [desde, hasta] (en x, en el lado sur z1), "houses": [[distribución, x, z, giro]],
##    "fields": [[x, z, ancho, largo]], "name": "LA ATALAYA"}

const LOG := Color("7a5634")
const LOG_D := Color("5a3e26")
const ROOF := Color("6b4a2c")


static func build(root: Node3D, cfg: Dictionary) -> Array:
	var keep: Array = []   # [centro, radio] donde no salen recursos ni bichos
	var r: Array = cfg.get("rect", [-24, -28, 24, 20])
	var x0 := float(r[0])
	var z0 := float(r[1])
	var x1 := float(r[2])
	var z1 := float(r[3])
	var gate: Array = cfg.get("gate", [-3, 3])
	var deco := Node3D.new()
	deco.name = "Poblado"
	root.add_child(deco)
	var body := StaticBody3D.new()
	body.name = "Empalizada"
	body.add_to_group("obstacle")
	root.add_child(body)
	# empalizada: troncos con punta, con hueco para la puerta en el lado sur
	_palisade(deco, body, Vector2(x0, z0), Vector2(x1, z0), [])
	_palisade(deco, body, Vector2(x0, z0), Vector2(x0, z1), [])
	_palisade(deco, body, Vector2(x1, z0), Vector2(x1, z1), [])
	_palisade(deco, body, Vector2(x0, z1), Vector2(x1, z1), [gate])
	# torres: esquinas y a los lados de la puerta, con un arquero arriba
	var gx0 := float(gate[0])
	var gx1 := float(gate[1])
	for p in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1), Vector2(gx0 - 1.6, z1), Vector2(gx1 + 1.6, z1)]:
		_tower(root, body, Vector3(p.x, 0, p.y))
	# hojas de la puerta abiertas y cartel
	for k in [-1.0, 1.0]:
		var leaf := Builder.part(Builder.box(Vector3((gx1 - gx0) / 2.0, 2.6, 0.18)), LOG_D, Vector3.ZERO)
		var hinge := Node3D.new()
		hinge.position = Vector3(gx0 if k < 0 else gx1, 1.3, z1 + 0.1)
		hinge.rotation.y = k * 1.9
		leaf.position = Vector3(-k * (gx1 - gx0) / 4.0, 0, 0)
		hinge.add_child(leaf)
		deco.add_child(hinge)
	deco.add_child(Builder.part(Builder.box(Vector3(gx1 - gx0 + 3.2, 0.5, 0.2)), LOG_D, Vector3((gx0 + gx1) / 2.0, 3.6, z1)))
	var sign_ := Label3D.new()
	sign_.text = str(cfg.get("name", ""))
	sign_.font_size = 96
	sign_.pixel_size = 0.008
	sign_.modulate = Color("f3ead2")
	sign_.outline_size = 10
	sign_.position = Vector3((gx0 + gx1) / 2.0, 3.6, z1 + 0.15)   # se lee desde fuera (sur)
	deco.add_child(sign_)
	# casas (por dentro, sin muebles que saquear)
	for h in cfg.get("houses", []):
		var hn := Node3D.new()
		hn.position = Vector3(float(h[1]), 0, float(h[2]))
		hn.rotation_degrees.y = float(h[3]) * 90.0
		root.add_child(hn)
		var lay := str(h[0])
		var big := lay == "casa" or lay == "tienda"
		var casa := RouteBuilder.house(hn, 8.0 if big else 5.5, 6.0 if big else 4.5, Color("b9a07a"), ROOF, false, lay)
		for m in casa.find_children("*", "Marker3D", true, false):
			m.queue_free()   # aquí vive gente: no hay nada que registrar
	# huertos con surcos
	for f in cfg.get("fields", []):
		var c := Vector3(float(f[0]), 0, float(f[1]))
		var w := float(f[2])
		var l := float(f[3])
		deco.add_child(Builder.part(Builder.box(Vector3(w, 0.06, l)), Color("5a4630"), c + Vector3(0, 0.03, 0)))
		var rows := int(w / 0.9)
		for i in rows:
			var x := -w / 2.0 + 0.45 + i * 0.9
			deco.add_child(Builder.part(Builder.box(Vector3(0.35, 0.12, l - 0.4)), Color("4a3a26"), c + Vector3(x, 0.08, 0)))
			for k in int(l / 0.8):
				deco.add_child(Builder.part(Builder.box(Vector3(0.28, 0.25, 0.28)), Color("5f8a3a"), c + Vector3(x, 0.25, -l / 2.0 + 0.5 + k * 0.8)))
	# hoguera de la plaza con troncos para sentarse
	var fire: Array = cfg.get("fire", [])
	if fire.size() == 2:
		var fp := Vector3(float(fire[0]), 0, float(fire[1]))
		for k in 6:
			var a := k * TAU / 6.0
			deco.add_child(Builder.part(Builder.box(Vector3(0.35, 0.22, 0.35)), Color("6b6964"), fp + Vector3(cos(a), 0.11, sin(a)) * Vector3(0.55, 1, 0.55)))
		var flame := Builder.part(Builder.cyl(0.0, 0.32, 0.7), Color(1.0, 0.55, 0.12), fp + Vector3(0, 0.4, 0), 3.0)
		deco.add_child(flame)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.3)
		l.omni_range = 7.0
		l.light_energy = 1.4
		l.position = fp + Vector3(0, 1.2, 0)
		deco.add_child(l)
		for k in 3:
			var a := k * TAU / 3.0 + 0.4
			var seat := Builder.part(Builder.cyl(0.18, 0.18, 1.4), LOG, fp + Vector3(cos(a), 0.18, sin(a)) * Vector3(2.2, 1, 2.2))
			seat.rotation = Vector3(0, -a, PI / 2.0)
			deco.add_child(seat)
	Builder.merge(deco)
	keep.append([Vector3((x0 + x1) / 2.0, 0, (z0 + z1) / 2.0), maxf(x1 - x0, z1 - z0) * 0.72])
	return keep


static func _palisade(deco: Node3D, body: StaticBody3D, a: Vector2, b: Vector2, gaps: Array) -> void:
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var s0 := minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var s1 := maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var fixed := a.y if along_x else a.x
	var s := s0
	var k := 0
	var seg_start := s0
	while s <= s1 + 0.01:
		var in_gap := false
		for g in gaps:
			if s > float(g[0]) - 0.2 and s < float(g[1]) + 0.2:
				in_gap = true
		if not in_gap:
			var h := 3.0 + float((k * 7) % 5) * 0.12
			var p := Vector3(s, 0, fixed) if along_x else Vector3(fixed, 0, s)
			deco.add_child(Builder.part(Builder.cyl(0.19, 0.21, h), LOG if k % 3 else LOG_D, p + Vector3(0, h / 2.0, 0)))
			deco.add_child(Builder.part(Builder.cyl(0.0, 0.19, 0.35), LOG_D, p + Vector3(0, h + 0.17, 0)))
		k += 1
		s += 0.4
	# travesaño y colisión (por tramos entre huecos)
	var cuts: Array = [s0]
	for g in gaps:
		cuts.append(float(g[0]))
		cuts.append(float(g[1]))
	cuts.append(s1)
	for i in range(0, cuts.size(), 2):
		var c0 := float(cuts[i])
		var c1 := float(cuts[i + 1])
		var ln := c1 - c0
		if ln <= 0.1:
			continue
		var mid := (c0 + c1) / 2.0
		var sz := Vector3(ln, 3.0, 0.5) if along_x else Vector3(0.5, 3.0, ln)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = sz
		cs.shape = bx
		cs.position = (Vector3(mid, 1.5, fixed) if along_x else Vector3(fixed, 1.5, mid))
		body.add_child(cs)
		var beam := Vector3(ln, 0.16, 0.16) if along_x else Vector3(0.16, 0.16, ln)
		deco.add_child(Builder.part(Builder.box(beam), LOG_D, (Vector3(mid, 1.9, fixed) if along_x else Vector3(fixed, 1.9, mid)) + (Vector3(0, 0, 0.22) if along_x else Vector3(0.22, 0, 0))))


## Torre de vigía: cuatro postes, plataforma con barandilla y tejadillo; arriba un arquero.
static func _tower(root: Node3D, body: StaticBody3D, p: Vector3) -> void:
	var t := Node3D.new()
	t.position = p
	root.add_child(t)
	var h := 4.2
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			t.add_child(Builder.part(Builder.cyl(0.14, 0.16, h + 2.2), LOG_D, Vector3(x, (h + 2.2) / 2.0, z)))
	t.add_child(Builder.part(Builder.box(Vector3(2.6, 0.16, 2.6)), LOG, Vector3(0, h, 0)))
	for k in 4:
		var rail := Builder.part(Builder.box(Vector3(2.6, 0.7, 0.1)), LOG, Vector3(0, h + 0.4, 1.25))
		var pivot := Node3D.new()
		pivot.rotation.y = k * PI / 2.0
		pivot.add_child(rail)
		t.add_child(pivot)
	var roof := Builder.part(Builder.cyl(0.0, 2.0, 0.9), ROOF, Vector3(0, h + 2.6, 0))
	t.add_child(roof)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.4, 3.0, 2.4)
	cs.shape = bx
	cs.position = p + Vector3(0, 1.5, 0)
	body.add_child(cs)
	var archer := Npc.new("arquero")
	archer.position = Vector3(0, h + 0.08, 0)
	t.add_child(archer)
