extends SceneTree
## Pasa las animaciones de la Universal Animation Library (Quaternius, CC0; third_party/ual)
## al esqueleto de CharacterModel y las guarda en assets/characters/animaciones.res.
##   godot --headless -s res://tools/bake_anims.gd

const SRC := "res://third_party/ual/AnimationLibrary_Godot_Standard.gltf"
const OUT := "res://assets/characters/animaciones.res"
const FPS := 30.0
const MAP := {
	"hips": "DEF-hips", "spine": "DEF-spine.003", "head": "DEF-head",
	"leg_l": "DEF-thigh.L", "knee_l": "DEF-shin.L", "foot_l": "DEF-foot.L",
	"leg_r": "DEF-thigh.R", "knee_r": "DEF-shin.R", "foot_r": "DEF-foot.R",
	"arm_l": "DEF-upper_arm.L", "elbow_l": "DEF-forearm.L", "hand_l": "DEF-hand.L",
	"arm_r": "DEF-upper_arm.R", "elbow_r": "DEF-forearm.R", "hand_r": "DEF-hand.R",
}
# hueso que marca hacia dónde apunta cada miembro (origen -> hijo)
const AIM := {"leg": ["knee", "DEF-shin"], "knee": ["foot", "DEF-foot"], "arm": ["elbow", "DEF-forearm"], "elbow": ["hand", "DEF-hand"]}
const ORDER := ["hips", "spine", "head", "leg_l", "knee_l", "foot_l", "leg_r", "knee_r", "foot_r",
	"arm_l", "elbow_l", "hand_l", "arm_r", "elbow_r", "hand_r"]


func _init() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(SRC), st)
	if err != OK:
		push_error("no se pudo leer " + SRC)
		quit(1)
		return
	var scene: Node = doc.generate_scene(st)
	root.add_child(scene)
	var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var model := CharacterModel.new({"sex": "m"})
	root.add_child(model)
	await process_frame
	var to_scene := _xf_to(skel, scene)
	# el modelo de la librería mira a +Z; el nuestro a -Z
	var flip := Basis(Vector3.UP, PI)
	if (to_scene * skel.get_bone_global_rest(skel.find_bone("DEF-toe.L"))).origin.z < (to_scene * skel.get_bone_global_rest(skel.find_bone("DEF-foot.L"))).origin.z:
		flip = Basis.IDENTITY
	# pose de referencia de los brazos: primer fotograma de Idle_Loop
	var ref_pose := {}
	ap.play("Idle_Loop")
	ap.seek(0.0, true)
	for jn: String in ORDER:
		ref_pose[jn] = flip * (to_scene.basis * skel.get_bone_global_pose(skel.find_bone(MAP[jn])).basis).orthonormalized()
	# reposo de las dos partes y desfase de giro entre ellas
	var t_rest := {}
	var axis := {}
	var off := {}
	for jn: String in ORDER:
		t_rest[jn] = model._rest_global(model.j[jn]).basis.orthonormalized()
	for jn: String in ORDER:
		var kind: String = jn.get_slice("_", 0)
		if AIM.has(kind):
			var child: String = AIM[kind][0] + "_" + jn.get_slice("_", 1)
			var d: Vector3 = model._rest_global(model.j[child]).origin - model._rest_global(model.j[jn]).origin
			axis[jn] = (t_rest[jn] as Basis).inverse() * d.normalized()
		var sb := flip * (to_scene.basis * skel.get_bone_global_rest(skel.find_bone(MAP[jn])).basis).orthonormalized()
		if kind in ["arm", "elbow", "hand"]:
			sb = ref_pose[jn]   # brazos: se comparan con el reposo de pie (palmas hacia dentro), no con la T
		off[jn] = sb.inverse() * (t_rest[jn] as Basis)
	var hip_src := (to_scene * skel.get_bone_global_rest(skel.find_bone("DEF-hips"))).origin.y
	var hip_ours: float = model.j["hips"].position.y
	var set := AnimSet.new()
	for name in ap.get_animation_list():
		var anim := ap.get_animation(name)
		var n := maxi(2, int(ceil(anim.length * FPS)) + 1)
		var rot := {}
		for jn: String in ORDER:
			rot[jn] = PackedFloat32Array()
		var hy := PackedFloat32Array()
		ap.play(name)
		for f in n:
			ap.seek(minf(float(f) / FPS, anim.length), true)
			var g := {}
			for jn: String in ORDER:
				var sb := flip * (to_scene.basis * skel.get_bone_global_pose(skel.find_bone(MAP[jn])).basis).orthonormalized()
				var gb: Basis = (sb * (off[jn] as Basis)).orthonormalized()
				var kind: String = jn.get_slice("_", 0)
				if AIM.has(kind):
					var src_a := flip * (to_scene * skel.get_bone_global_pose(skel.find_bone(MAP[jn]))).origin
					var src_b := flip * (to_scene * skel.get_bone_global_pose(skel.find_bone(AIM[kind][1] + "." + jn.get_slice("_", 1).to_upper()))).origin
					var want := (src_b - src_a).normalized()
					var now: Vector3 = (gb * (axis[jn] as Vector3)).normalized()
					if now.dot(want) < 0.9999:
						gb = (Basis(Quaternion(now, want)) * gb).orthonormalized()
				g[jn] = gb
			for jn: String in ORDER:
				var par := String(model.j[jn].get_parent().name)
				var pb: Basis = g[par] if g.has(par) else Basis.IDENTITY
				var q := (pb.inverse() * (g[jn] as Basis)).orthonormalized().get_rotation_quaternion()
				rot[jn].append_array(PackedFloat32Array([q.x, q.y, q.z, q.w]))
			var hp := (to_scene * skel.get_bone_global_pose(skel.find_bone("DEF-hips"))).origin.y
			hy.append((hp - hip_src) * hip_ours / hip_src)
		set.clips[name] = {"fps": FPS, "frames": n, "rot": rot, "hy": hy}
	var e2 := ResourceSaver.save(set, OUT, ResourceSaver.FLAG_COMPRESS)
	print("clips: ", set.clips.size(), " guardado: ", e2 == OK)
	quit(0)


func _xf_to(n: Node3D, top: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != top:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
