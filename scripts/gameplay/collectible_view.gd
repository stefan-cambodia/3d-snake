class_name CollectibleView
extends Node3D
## Visual nodes for collectibles, kept in sync with GameSession.items by id.

const GLOW_SHADER := preload("res://assets/shaders/glow_billboard.gdshader")
const BEAM_SHADER := preload("res://assets/shaders/beam.gdshader")

const FOOD_COLOR := Color(1.0, 0.62, 0.16)
const ENERGY_COLOR := Color(0.3, 0.95, 1.0)
const RARE_COLOR := Color(0.85, 0.5, 1.0)

var terrain: TerrainField
var _nodes: Dictionary = {} # id -> {node, kind, age, spawn}
var _meshes: Dictionary = {}
var _mats: Dictionary = {}
var _soft_tex: Texture2D
var _time: float = 0.0


func setup(p_terrain: TerrainField, soft_tex: Texture2D) -> void:
	terrain = p_terrain
	_soft_tex = soft_tex
	_build_resources()


func _build_resources() -> void:
	# Sunfruit: slightly pear-shaped glowing fruit with a leaf.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := FastNoiseLite.new()
	n.frequency = 2.0
	MeshKit.add_blob(st, Vector3(0, 0, 0), Vector3(0.3, 0.34, 0.3), 2, n, 0.04, Color(1, 1, 1))
	MeshKit.add_blob(st, Vector3(0, 0.26, 0), Vector3(0.17, 0.16, 0.17), 1, n, 0.04, Color(1, 1, 1))
	st.generate_normals()
	_meshes["fruit"] = st.commit()
	var lst := SurfaceTool.new()
	lst.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshKit.add_blob(lst, Vector3(0.1, 0.42, 0), Vector3(0.16, 0.025, 0.07), 1, null, 0.0, Color(1, 1, 1))
	MeshKit.add_tube(lst, PackedVector3Array([Vector3(0, 0.36, 0), Vector3(0.02, 0.48, 0)]), PackedFloat32Array([0.02, 0.015]), 5, Color(1, 1, 1), 1.0, false)
	lst.generate_normals()
	_meshes["leaf"] = lst.commit()

	# Energy crystal: elongated octahedron, faceted.
	var cst := SurfaceTool.new()
	cst.begin(Mesh.PRIMITIVE_TRIANGLES)
	cst.set_smooth_group(-1)
	var top := Vector3(0, 0.55, 0)
	var bot := Vector3(0, -0.45, 0)
	var ring: Array[Vector3] = []
	for i in 6:
		var a := TAU * float(i) / 6.0
		ring.append(Vector3(cos(a) * 0.22, 0.02 * float(i % 2), sin(a) * 0.22))
	for i in 6:
		var a := ring[i]
		var b := ring[(i + 1) % 6]
		# Ring goes CCW seen from above; (top, b, a) is CCW from outside.
		MeshKit.tri(cst, top, b, a)
		MeshKit.tri(cst, bot, a, b)
	cst.generate_normals()
	_meshes["crystal"] = cst.commit()

	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.44
	torus.rings = 24
	torus.ring_segments = 10
	_meshes["relic"] = torus
	var gem := SphereMesh.new()
	gem.radius = 0.17
	gem.height = 0.34
	gem.radial_segments = 12
	gem.rings = 6
	_meshes["gem"] = gem
	var beam := CylinderMesh.new()
	beam.top_radius = 0.55
	beam.bottom_radius = 0.55
	beam.height = 26.0
	beam.cap_top = false
	beam.cap_bottom = false
	beam.radial_segments = 12
	_meshes["beam"] = beam
	_meshes["quad"] = QuadMesh.new()
	var flat := QuadMesh.new()
	flat.orientation = PlaneMesh.FACE_Y
	_meshes["flat"] = flat

	var fruit := StandardMaterial3D.new()
	fruit.albedo_color = Color(1.0, 0.55, 0.12)
	fruit.emission_enabled = true
	fruit.emission = Color(1.0, 0.42, 0.08)
	fruit.emission_energy_multiplier = 1.2
	fruit.roughness = 0.28
	fruit.rim_enabled = true
	fruit.rim = 0.6
	fruit.rim_tint = 0.3
	_mats["fruit"] = fruit
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.3, 0.62, 0.2)
	leaf.roughness = 0.6
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["leaf"] = leaf
	var crystal := StandardMaterial3D.new()
	crystal.albedo_color = Color(0.45, 0.95, 1.0)
	crystal.emission_enabled = true
	crystal.emission = ENERGY_COLOR
	crystal.emission_energy_multiplier = 2.2
	crystal.roughness = 0.08
	crystal.metallic = 0.3
	crystal.rim_enabled = true
	crystal.rim = 1.0
	_mats["crystal"] = crystal
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.35)
	gold.metallic = 1.0
	gold.roughness = 0.22
	gold.emission_enabled = true
	gold.emission = Color(0.6, 0.35, 0.05)
	gold.emission_energy_multiplier = 0.6
	_mats["gold"] = gold
	var gemm := StandardMaterial3D.new()
	gemm.albedo_color = RARE_COLOR
	gemm.emission_enabled = true
	gemm.emission = RARE_COLOR
	gemm.emission_energy_multiplier = 3.0
	gemm.roughness = 0.05
	_mats["gem"] = gemm
	var bm := ShaderMaterial.new()
	bm.shader = BEAM_SHADER
	_mats["beam"] = bm
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.albedo_texture = _soft_tex
	ring_mat.vertex_color_use_as_albedo = false
	_mats["pool"] = ring_mat


func _glow(color: Color, size: float, intensity: float) -> MeshInstance3D:
	var g := MeshInstance3D.new()
	g.mesh = _meshes["quad"]
	var m := ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("intensity", intensity)
	g.material_override = m
	g.scale = Vector3.ONE * size
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g


func _pool(color: Color, size: float) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.mesh = _meshes["flat"]
	var m := (_mats["pool"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = color * 0.55
	p.material_override = m
	p.scale = Vector3.ONE * size
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func spawn(id: int, kind: int, pos: Vector3) -> void:
	if _nodes.has(id):
		return
	var root := Node3D.new()
	root.name = "Item%d" % id
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var pool_y := terrain.height(pos.x, pos.z) + 0.04 - pos.y
	match kind:
		Collectible.Kind.FOOD:
			var f := MeshInstance3D.new()
			f.mesh = _meshes["fruit"]
			f.material_override = _mats["fruit"]
			body.add_child(f)
			var l := MeshInstance3D.new()
			l.mesh = _meshes["leaf"]
			l.material_override = _mats["leaf"]
			body.add_child(l)
			root.add_child(_glow(FOOD_COLOR, 2.0, 0.7))
			var p := _pool(FOOD_COLOR, 2.2)
			p.position.y = pool_y
			root.add_child(p)
		Collectible.Kind.ENERGY:
			var c := MeshInstance3D.new()
			c.mesh = _meshes["crystal"]
			c.material_override = _mats["crystal"]
			body.add_child(c)
			root.add_child(_glow(ENERGY_COLOR, 2.6, 0.9))
			var p := _pool(ENERGY_COLOR, 2.8)
			p.position.y = pool_y
			root.add_child(p)
		Collectible.Kind.RARE:
			var t := MeshInstance3D.new()
			t.mesh = _meshes["relic"]
			t.material_override = _mats["gold"]
			t.rotation.x = PI * 0.5
			body.add_child(t)
			var g := MeshInstance3D.new()
			g.mesh = _meshes["gem"]
			g.material_override = _mats["gem"]
			body.add_child(g)
			root.add_child(_glow(RARE_COLOR, 3.2, 1.0))
			var b := MeshInstance3D.new()
			b.name = "Beam"
			b.mesh = _meshes["beam"]
			b.material_override = _mats["beam"]
			b.position.y = 13.0 + pool_y
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(b)
			var p := _pool(RARE_COLOR, 3.4)
			p.position.y = pool_y
			root.add_child(p)
	add_child(root)
	root.position = pos
	root.scale = Vector3.ONE * 0.01
	_nodes[id] = {"node": root, "kind": kind, "age": 0.0, "dying": -1.0, "phase": randf() * TAU}


func remove(id: int, animated: bool) -> void:
	if not _nodes.has(id):
		return
	var e: Dictionary = _nodes[id]
	if animated:
		e["dying"] = 0.0
	else:
		(e["node"] as Node).queue_free()
		_nodes.erase(id)


func clear() -> void:
	for id in _nodes:
		(_nodes[id]["node"] as Node).queue_free()
	_nodes.clear()


func node_position(id: int) -> Variant:
	if _nodes.has(id):
		return (_nodes[id]["node"] as Node3D).global_position
	return null


func update_view(delta: float, items: Array[Collectible]) -> void:
	_time += delta
	var by_id := {}
	for it in items:
		by_id[it.id] = it
	var dead: Array = []
	for id in _nodes:
		var e: Dictionary = _nodes[id]
		var node: Node3D = e["node"]
		e["age"] = float(e["age"]) + delta
		var age: float = e["age"]
		var ph: float = e["phase"]
		var body := node.get_node("Body") as Node3D
		var s := 1.0
		if float(e["dying"]) >= 0.0:
			e["dying"] = float(e["dying"]) + delta
			s = maxf(1.0 - float(e["dying"]) / 0.3, 0.0)
			if s <= 0.0:
				dead.append(id)
		else:
			# Pop-in with overshoot.
			var t := clampf(age / 0.45, 0.0, 1.0)
			s = 1.0 + sin(t * PI) * 0.35 * (1.0 - t) if t >= 1.0 else ease(t, 0.4) * (1.0 + sin(t * PI) * 0.3)
		if by_id.has(id):
			var it: Collectible = by_id[id]
			node.position = it.pos
			var left := it.time_left()
			if left < 3.0:
				# Blink when about to vanish.
				node.visible = fmod(left, 0.4) > 0.12 or left > 2.95
		node.scale = Vector3.ONE * maxf(s, 0.01)
		var kind: int = e["kind"]
		match kind:
			Collectible.Kind.FOOD:
				body.position.y = sin(_time * 2.4 + ph) * 0.08
				body.rotation.y = _time * 1.2 + ph
			Collectible.Kind.ENERGY:
				body.position.y = 0.15 + sin(_time * 3.0 + ph) * 0.12
				body.rotation.y = _time * 2.6
				body.rotation.z = sin(_time * 1.3) * 0.2
			Collectible.Kind.RARE:
				body.position.y = 0.25 + sin(_time * 1.8 + ph) * 0.1
				body.rotation.y = _time * 1.6
	for id in dead:
		(_nodes[id]["node"] as Node).queue_free()
		_nodes.erase(id)
