class_name WorldView
extends Node3D
## Builds and animates the 3D sanctuary: environment, lighting, terrain, water,
## landmarks, vegetation, arena boundary, obstacles and rising-obstacle effects.

const TERRAIN_SHADER := preload("res://assets/shaders/terrain.gdshader")
const WATER_SHADER := preload("res://assets/shaders/water.gdshader")
const SKY_SHADER := preload("res://assets/shaders/sky.gdshader")
const GRASS_SHADER := preload("res://assets/shaders/grass.gdshader")
const FOLIAGE_SHADER := preload("res://assets/shaders/foliage.gdshader")
const STONE_SHADER := preload("res://assets/shaders/stone.gdshader")
const GLOW_SHADER := preload("res://assets/shaders/glow_billboard.gdshader")
const RUNE_DISC_SHADER := preload("res://assets/shaders/rune_disc.gdshader")
const BARRIER_SHADER := preload("res://assets/shaders/barrier.gdshader")
const EMISSIVE_SHADER := preload("res://assets/shaders/emissive.gdshader")
const SHAFT_SHADER := preload("res://assets/shaders/shaft.gdshader")

const TEX_DETAIL := preload("res://assets/textures/ground_detail.png")
const TEX_DETAIL_N := preload("res://assets/textures/ground_normal.png")
const TEX_STONE := preload("res://assets/textures/stone_albedo.png")
const TEX_STONE_N := preload("res://assets/textures/stone_normal.png")
const TEX_WATER_N := preload("res://assets/textures/water_normal.png")
const TEX_CLOUDS := preload("res://assets/textures/clouds.png")

const CORE_EXTENT := 38.0 ## Fine grid: covers every terrace wall (TerrainField.TERRACE_MAX_EXTENT + wall).
const INNER_EXTENT := 56.0
const OUTER_EXTENT := 184.0
const HEIGHTMAP_RES := 128
const HEIGHTMAP_EXTENT := 256.0
const GRASS_CHUNKS := 4

var terrain: TerrainField
var theme: Dictionary
## The sanctuary's architectural style (SanctuaryStyles), chosen by the theme.
var style: Dictionary
## Where the architecture stands (SanctuaryBuilder.plan) and what it costs.
var architecture_plan: Array[Dictionary] = []
var architecture_triangles: int = 0
var quality: int = 2

var environment: Environment
var sun: DirectionalLight3D
var fill_light: DirectionalLight3D

var _sky_mat: ShaderMaterial
var _terrain_mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _stone_mat: ShaderMaterial
var _grass_mat: ShaderMaterial
var _foliage_mat: ShaderMaterial
var _barrier_mat: ShaderMaterial
var _glow_mat: ShaderMaterial
var _accent_mat: StandardMaterial3D
var _emissive_mat: ShaderMaterial
var _flora_mat: ShaderMaterial
var _weather: GPUParticles3D
var _weather_kind: String = ""
var _lantern_glow: MultiMeshInstance3D
var _night_lanterns: Node3D
var _motes: GPUParticles3D
var _grass_chunks: Array[MultiMeshInstance3D] = []
var _grass_mesh: ArrayMesh
var _soft_tex: GradientTexture2D

## Everything built from the terrain (ground, water, shore, vegetation, ring,
## landmarks): rebuilt as a whole when the sanctuary, and so the island, changes.
var _terrain_root: Node3D
var _obstacle_root: Node3D
var _obstacle_nodes: Dictionary = {}
var _rising: Dictionary = {}
var _fires: Array[Node3D] = []
var _mesh_cache: Dictionary = {}
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
## Fine terrain grid kept after building the mesh (grass placement reads it).
var _core_heights := PackedFloat32Array()
var _core_paved := PackedFloat32Array()
var _core_from := 0.0
var _core_step := 1.0
var _core_n := 0


func build(p_terrain: TerrainField, p_theme: Dictionary, p_quality: int) -> void:
	terrain = p_terrain
	theme = p_theme
	style = SanctuaryStyles.get_style(theme["id"])
	quality = p_quality
	_rng.seed = terrain.seed_value * 31 + 5
	_soft_tex = _make_soft_texture()
	_make_materials()
	_build_environment()
	_build_island()
	_build_motes()
	_build_weather()
	_obstacle_root = Node3D.new()
	_obstacle_root.name = "Obstacles"
	add_child(_obstacle_root)
	_build_mesh_cache()
	apply_theme(theme)
	set_quality(quality)


## The island's ground, water, shore, vegetation, ring and landmarks, under one
## node. Seeded from the terrain only, so an island looks the same whether the
## game starts on it or switches to it.
func _build_island() -> void:
	_rng.seed = terrain.seed_value * 31 + 5
	_terrain_root = Node3D.new()
	_terrain_root.name = "Island"
	add_child(_terrain_root)
	_build_terrain()
	_build_water()
	_build_backdrop()
	_build_arena_ring()
	_build_architecture()
	_build_vegetation()
	_build_flora()
	_build_landmarks()
	_build_shafts()


## Rebuild the island after the terrain was regenerated (another sanctuary).
## Lights, sky and materials stay; obstacles are replaced by the next layout.
func rebuild_island() -> void:
	if _terrain_root:
		remove_child(_terrain_root)
		_terrain_root.free()
	_grass_chunks.clear()
	_lantern_glow = null
	_night_lanterns = null
	_build_island()
	_build_mesh_cache() # the pillars follow the sanctuary's column order
	apply_theme(theme)
	set_quality(quality)


# --- Materials ------------------------------------------------------------------

func _make_soft_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func soft_texture() -> Texture2D:
	return _soft_tex


func _make_materials() -> void:
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = TERRAIN_SHADER
	_terrain_mat.set_shader_parameter("detail_tex", TEX_DETAIL)
	_terrain_mat.set_shader_parameter("detail_normal", TEX_DETAIL_N)
	_terrain_mat.set_shader_parameter("stone_tex", TEX_STONE)
	_terrain_mat.set_shader_parameter("stone_normal", TEX_STONE_N)
	_terrain_mat.set_shader_parameter("water_level", GameConfig.WATER_LEVEL)
	_terrain_mat.set_shader_parameter("plaza_radius", TerrainField.PLAZA_RADIUS)

	_water_mat = ShaderMaterial.new()
	_water_mat.shader = WATER_SHADER
	_water_mat.set_shader_parameter("normal_tex", TEX_WATER_N)
	_water_mat.set_shader_parameter("water_level", GameConfig.WATER_LEVEL)
	_water_mat.set_shader_parameter("map_extent", HEIGHTMAP_EXTENT)

	_stone_mat = ShaderMaterial.new()
	_stone_mat.shader = STONE_SHADER
	_stone_mat.set_shader_parameter("albedo_tex", TEX_STONE)
	_stone_mat.set_shader_parameter("normal_tex", TEX_STONE_N)
	_stone_mat.set_shader_parameter("detail_tex", TEX_DETAIL)

	_grass_mat = ShaderMaterial.new()
	_grass_mat.shader = GRASS_SHADER

	_foliage_mat = ShaderMaterial.new()
	_foliage_mat.shader = FOLIAGE_SHADER

	_barrier_mat = ShaderMaterial.new()
	_barrier_mat.shader = BARRIER_SHADER

	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = GLOW_SHADER

	# Bronze, ceramic, timber: vertex-coloured, a little glossy.
	_accent_mat = StandardMaterial3D.new()
	_accent_mat.vertex_color_use_as_albedo = true
	_accent_mat.roughness = 0.5
	_accent_mat.metallic = 0.2
	_accent_mat.metallic_specular = 0.6

	_emissive_mat = ShaderMaterial.new()
	_emissive_mat.shader = EMISSIVE_SHADER

	# Ferns and flowers: the foliage shader, but never recoloured by a sanctuary.
	_flora_mat = ShaderMaterial.new()
	_flora_mat.shader = FOLIAGE_SHADER
	_flora_mat.set_shader_parameter("wind_strength", 0.35)


func stone_material() -> ShaderMaterial:
	return _stone_mat


func glow_material() -> ShaderMaterial:
	return _glow_mat


# --- Environment ------------------------------------------------------------------

func _build_environment() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	_sky_mat.set_shader_parameter("clouds", TEX_CLOUDS)
	_sky_mat.set_shader_parameter("cloud_offset", Vector2(_rng.randf(), _rng.randf()))
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 0.9
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.35
	environment.fog_aerial_perspective = 0.25
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.1
	environment.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 48.0
	sun.directional_shadow_split_1 = 0.22
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.4
	sun.light_angular_distance = 0.6
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	add_child(sun)

	fill_light = DirectionalLight3D.new()
	fill_light.name = "Fill"
	fill_light.shadow_enabled = false
	fill_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	fill_light.light_specular = 0.2
	add_child(fill_light)


func apply_theme(p_theme: Dictionary) -> void:
	theme = p_theme
	style = SanctuaryStyles.get_style(theme["id"])
	var night: bool = theme["night"]
	_sky_mat.set_shader_parameter("aurora", float(style.get("aurora", 0.0)))
	_water_mat.set_shader_parameter("sky_col", (theme["sky_horizon"] as Color).lerp(theme["sky_top"], 0.35))
	# The sanctuary's own stone, paving and terrace walls.
	_stone_mat.set_shader_parameter("tint_a", style["stone_a"])
	_stone_mat.set_shader_parameter("tint_b", style["stone_b"])
	_stone_mat.set_shader_parameter("moss_amount", float(style["moss"]))
	_stone_mat.set_shader_parameter("rune_col", style.get("rune_col", Color(1.0, 0.62, 0.25)))
	_terrain_mat.set_shader_parameter("plaza_col", style["paving"])
	_terrain_mat.set_shader_parameter("sandstone_col", style["wall_a"])
	_terrain_mat.set_shader_parameter("laterite_col", style["wall_b"])
	_emissive_mat.set_shader_parameter("intensity", 2.6 if night else 1.7)
	_flora_mat.set_shader_parameter("tint", Color(0.6, 0.7, 0.85) if night else Color.WHITE)
	_apply_weather(str(style.get("weather", "")))
	_sky_mat.set_shader_parameter("sky_top", theme["sky_top"])
	_sky_mat.set_shader_parameter("sky_horizon", theme["sky_horizon"])
	_sky_mat.set_shader_parameter("sky_ground", theme["sky_ground"])
	_sky_mat.set_shader_parameter("cloud_tint", theme["cloud_tint"])
	_sky_mat.set_shader_parameter("night", 1.0 if night else 0.0)
	_sky_mat.set_shader_parameter("cloud_cover", 0.45 if night else (0.9 if theme["id"] == "mist" else 0.72))
	_sky_mat.set_shader_parameter("sun_size", 0.9992 if night else 0.99955)
	environment.ambient_light_energy = theme["ambient_energy"]
	environment.fog_light_color = theme["fog_color"]
	environment.fog_density = theme["fog_density"]
	environment.tonemap_exposure = theme["exposure"]
	environment.glow_intensity = 0.8 if night else 0.55
	sun.light_color = theme["sun_color"]
	sun.light_energy = theme["sun_energy"]
	sun.rotation_degrees = Vector3(theme["sun_pitch"], theme["sun_yaw"], 0.0)
	fill_light.light_color = (theme["sky_top"] as Color).lerp(Color.WHITE, 0.4)
	fill_light.light_energy = 0.22 if not night else 0.18
	fill_light.rotation_degrees = Vector3(-35.0, float(theme["sun_yaw"]) + 160.0, 0.0)
	_water_mat.set_shader_parameter("deep_col", theme["water_deep"])
	_water_mat.set_shader_parameter("shallow_col", theme["water_shallow"])
	_terrain_mat.set_shader_parameter("grass_a", theme["grass_a"])
	_terrain_mat.set_shader_parameter("grass_b", theme["grass_b"])
	_terrain_mat.set_shader_parameter("moss_col", (theme["grass_a"] as Color).darkened(0.3))
	var boost: float = theme["emissive_boost"]
	_terrain_mat.set_shader_parameter("rune_glow", 0.35 * boost)
	_stone_mat.set_shader_parameter("rune_base", 0.25 * boost)
	_stone_mat.set_shader_parameter("moss_col", style.get("moss_col", (theme["grass_a"] as Color).darkened(0.25)))
	_grass_mat.set_shader_parameter("base_col", (theme["grass_a"] as Color).darkened(0.35))
	_grass_mat.set_shader_parameter("tip_col", (theme["grass_b"] as Color).lightened(0.05))
	_foliage_mat.set_shader_parameter("tint", Color(0.55, 0.65, 0.8) if night else Color.WHITE)
	# Optional leaf colours of the sanctuary (frosted, autumn...); green otherwise.
	_foliage_mat.set_shader_parameter("leaf_mix", 1.0 if theme.has("leaf_a") else 0.0)
	if theme.has("leaf_a"):
		_foliage_mat.set_shader_parameter("leaf_col", theme["leaf_a"])
		_foliage_mat.set_shader_parameter("leaf_col_b", theme["leaf_b"])
	_barrier_mat.set_shader_parameter("base_alpha", 0.1 if night else 0.05)
	if _lantern_glow:
		(_lantern_glow.material_override as ShaderMaterial).set_shader_parameter("fade", 1.0 if night else 0.35)
	if _night_lanterns:
		_night_lanterns.visible = night
	if _motes:
		var pm: ParticleProcessMaterial = _motes.process_material
		pm.color = theme["motes"]
		(_motes.draw_pass_1.surface_get_material(0) as StandardMaterial3D).emission_energy_multiplier = 3.0 if night else 1.2
	for f in _fires:
		f.visible = true


func set_quality(q: int) -> void:
	quality = q
	sun.shadow_enabled = q > 0
	RenderingServer.directional_shadow_atlas_set_size(2048 if q >= 2 else 1024, true)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q >= 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 48.0 if q >= 2 else 32.0
	environment.glow_enabled = q > 0
	environment.fog_aerial_perspective = 0.25 if q > 0 else 0.0
	environment.sky.radiance_size = Sky.RADIANCE_SIZE_256 if q >= 2 else Sky.RADIANCE_SIZE_64
	if _motes:
		_motes.amount = [30, 60, 110][q]
	if _weather:
		_apply_weather(_weather_kind)
	for f in _fires:
		var l := f.get_node_or_null("Light") as OmniLight3D
		if l:
			l.visible = q >= 2
	_update_grass_density()


# --- Terrain & water ----------------------------------------------------------------

func _build_terrain() -> void:
	# Fine 0.5 m grid over the arena (crisp terrace walls), 1 m around the shore,
	# 4 m out to the far shore. Each grid skips the square the finer one covers
	# and its border is bent onto the coarser grid's edges, so they join without
	# cracks.
	var core := _terrain_grid(-CORE_EXTENT, CORE_EXTENT, 0.5, 0.0, 2, true)
	var inner := _terrain_grid(-INNER_EXTENT, INNER_EXTENT, 1.0, CORE_EXTENT, 4, true)
	var outer := _terrain_grid(-OUTER_EXTENT, OUTER_EXTENT, 4.0, INNER_EXTENT, 1, false)
	for m in [core, inner, outer]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = _terrain_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Terrain"
		_terrain_root.add_child(mi)
	_build_wall_shadows()


## Grid of terrain from `from` to `to`. `hole` > 0 leaves out the centre square
## [-hole, hole] (drawn by a finer grid); border vertices are snapped onto a
## grid `stitch` times coarser. Vertex colour: r = grass, g = sand, b = paved
## stone, a = ambient occlusion. Built from packed arrays (SurfaceTool is several
## times slower for grids this size).
func _terrain_grid(from: float, to: float, step: float, hole: float, stitch: int, detailed: bool) -> ArrayMesh:
	var n := int(round((to - from) / step)) + 1
	var count := n * n
	var heights := PackedFloat32Array()
	heights.resize(count)
	var paved := PackedFloat32Array()
	paved.resize(count)
	var pave_r2 := pow(TerrainField.TERRACE_MAX_EXTENT + 10.0, 2.0)
	# Vertices well inside the hole are never drawn (only the hole's border and
	# its neighbours feed normals and shading), so skip their heights.
	var skip := hole - step * 4.0
	for iz in n:
		var z := from + float(iz) * step
		for ix in n:
			var x := from + float(ix) * step
			var i := iz * n + ix
			if hole > 0.0 and absf(x) < skip and absf(z) < skip:
				continue
			if detailed and x * x + z * z < pave_r2:
				var hp := terrain.sample(x, z)
				heights[i] = hp.x
				paved[i] = hp.y
			else:
				heights[i] = terrain.height(x, z)
	if stitch > 1:
		_stitch_border(heights, n, stitch)
	if hole <= 0.0:
		_core_heights = heights
		_core_paved = paved
		_core_from = from
		_core_step = step
		_core_n = n
	var verts := PackedVector3Array()
	verts.resize(count)
	var norms := PackedVector3Array()
	norms.resize(count)
	var tans := PackedFloat32Array()
	tans.resize(count * 4)
	var cols := PackedColorArray()
	cols.resize(count)
	var uvs := PackedVector2Array()
	uvs.resize(count)
	var near := maxi(int(round(1.0 / step)), 1)
	var far := maxi(int(round(2.5 / step)), 2)
	var ao_r2 := pow(GameConfig.ARENA_RADIUS + 4.0, 2.0)
	for iz in n:
		var z := from + float(iz) * step
		for ix in n:
			var x := from + float(ix) * step
			var i := iz * n + ix
			var h := heights[i]
			var hl := heights[iz * n + maxi(ix - 1, 0)]
			var hr := heights[iz * n + mini(ix + 1, n - 1)]
			var hd := heights[maxi(iz - 1, 0) * n + ix]
			var hu := heights[mini(iz + 1, n - 1) * n + ix]
			if hole > 0.0 and absf(x) < skip and absf(z) < skip:
				continue
			var nrm := Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
			var r := sqrt(x * x + z * z)
			var grass := 1.0
			var sand := 0.0
			if r > 50.0:
				grass = TerrainField._ss(0.0, 0.5, h + 0.2)
				sand = TerrainField._ss(0.6, -0.2, h)
			elif r > GameConfig.ARENA_RADIUS - 2.0:
				grass = 1.0 - TerrainField._ss(GameConfig.ARENA_RADIUS - 2.0, GameConfig.ARENA_RADIUS + 3.5, r)
				sand = TerrainField._ss(GameConfig.ARENA_RADIUS - 1.0, GameConfig.ARENA_RADIUS + 3.0, r)
			grass *= 0.75 + 0.5 * terrain.variation(x, z)
			if r < TerrainField.PLAZA_RADIUS + 2.5:
				grass *= TerrainField._ss(TerrainField.PLAZA_RADIUS + 0.2, TerrainField.PLAZA_RADIUS + 2.5, r)
			if h < -0.1:
				sand = maxf(sand, TerrainField._ss(-0.1, -0.6, h))
			var ao := 1.0
			if detailed and x * x + z * z < ao_r2:
				ao = _vertex_ao(heights, n, ix, iz, step, near, far)
			verts[i] = Vector3(x, h, z)
			norms[i] = nrm
			var tan := (Vector3.RIGHT - nrm * nrm.x).normalized()
			tans[i * 4] = tan.x
			tans[i * 4 + 1] = tan.y
			tans[i * 4 + 2] = tan.z
			tans[i * 4 + 3] = 1.0
			cols[i] = Color(grass, sand, paved[i], ao)
			uvs[i] = Vector2(x, z) * 0.16
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var k := 0
	var eps := step * 0.01
	for iz in n - 1:
		for ix in n - 1:
			if hole > 0.0:
				var x0 := from + float(ix) * step
				var z0 := from + float(iz) * step
				if x0 >= -hole - eps and x0 + step <= hole + eps and z0 >= -hole - eps and z0 + step <= hole + eps:
					continue
			var i00 := iz * n + ix
			idx[k] = i00
			idx[k + 1] = i00 + 1
			idx[k + 2] = i00 + n + 1
			idx[k + 3] = i00
			idx[k + 4] = i00 + n + 1
			idx[k + 5] = i00 + n
			k += 6
	idx.resize(k)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TANGENT] = tans
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Ground under (x, z) from the fine terrain grid: x = height (bilinear),
## y = slope, z = paved. Falls back to the terrain function outside the grid.
func ground_info(x: float, z: float) -> Vector3:
	var fx := (x - _core_from) / _core_step
	var fz := (z - _core_from) / _core_step
	var ix := int(floor(fx))
	var iz := int(floor(fz))
	if _core_n == 0 or ix < 1 or iz < 1 or ix >= _core_n - 2 or iz >= _core_n - 2:
		return Vector3(terrain.height(x, z), terrain.slope(x, z), terrain.paved(x, z))
	var n := _core_n
	var tx := fx - float(ix)
	var tz := fz - float(iz)
	var i := iz * n + ix
	var h := lerpf(lerpf(_core_heights[i], _core_heights[i + 1], tx), lerpf(_core_heights[i + n], _core_heights[i + n + 1], tx), tz)
	var gx := (_core_heights[i + 1] - _core_heights[i - 1]) / (2.0 * _core_step)
	var gz := (_core_heights[i + n] - _core_heights[i - n]) / (2.0 * _core_step)
	return Vector3(h, sqrt(gx * gx + gz * gz), _core_paved[i])


## Make the outer border follow straight lines between every `m`-th vertex, as
## the next coarser grid draws it.
func _stitch_border(h: PackedFloat32Array, n: int, m: int) -> void:
	for i in n:
		if i % m == 0:
			continue
		var i0 := (i / m) * m
		var i1 := mini(i0 + m, n - 1)
		var k := float(i - i0) / float(maxi(i1 - i0, 1))
		for e in 4:
			var a: int
			var b: int
			var c: int
			match e:
				0:
					a = i0; b = i1; c = i # bottom row
				1:
					a = (n - 1) * n + i0; b = (n - 1) * n + i1; c = (n - 1) * n + i
				2:
					a = i0 * n; b = i1 * n; c = i * n # left column
				_:
					a = i0 * n + n - 1; b = i1 * n + n - 1; c = i * n + n - 1
			h[c] = lerpf(h[a], h[b], k)


## Darkening where the ground is hemmed in by higher ground (foot of walls and
## slopes), from the height grid: 8 directions at two distances.
const _AO_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]


func _vertex_ao(h: PackedFloat32Array, n: int, ix: int, iz: int, step: float, near: int, far: int) -> float:
	var h0 := h[iz * n + ix]
	# Quick out: nothing noticeably higher a few metres away along the axes.
	var lim := h0 + 0.3
	if h[iz * n + mini(ix + far, n - 1)] < lim and h[iz * n + maxi(ix - far, 0)] < lim \
			and h[mini(iz + far, n - 1) * n + ix] < lim and h[maxi(iz - far, 0) * n + ix] < lim:
		return 1.0
	var occ := 0.0
	var inv_near := 1.0 / (float(near) * step)
	var inv_far := 1.0 / (float(far) * step)
	for d in _AO_DIRS:
		var inv_diag := 0.7071 if d.x != 0 and d.y != 0 else 1.0
		var jx := clampi(ix + d.x * near, 0, n - 1)
		var jz := clampi(iz + d.y * near, 0, n - 1)
		occ += maxf((h[jz * n + jx] - h0) * inv_near * inv_diag - 0.12, 0.0)
		jx = clampi(ix + d.x * far, 0, n - 1)
		jz = clampi(iz + d.y * far, 0, n - 1)
		occ += maxf((h[jz * n + jx] - h0) * inv_far * inv_diag - 0.12, 0.0)
	return 1.0 - clampf(occ * 0.09, 0.0, 0.55)


## Terrace walls are drawn by the terrain mesh, which casts no shadow (it would
## shadow itself everywhere). These invisible strips along each wall cast the
## walls' shadows on the ground below.
func _build_wall_shadows() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for t in terrain.terraces:
		var segs := 96
		var prev_top := Vector3.ZERO
		var prev_bot := Vector3.ZERO
		for i in segs + 1:
			var a := TAU * float(i) / float(segs)
			var d := Vector2(cos(a), sin(a))
			var rim := t.rim(a)
			var pt := t.center + d * (rim - TerrainField.CLIFF_IN - 0.15)
			var pb := t.center + d * (rim + TerrainField.CLIFF_OUT + 0.1)
			var top := Vector3(pt.x, terrain.height(pt.x, pt.y) - 0.08, pt.y)
			var bot := Vector3(pb.x, terrain.height(pb.x, pb.y) - 0.3, pb.y)
			if i > 0 and top.y - bot.y > 0.6 and prev_top.y - prev_bot.y > 0.6:
				any = true
				for v in [prev_top, prev_bot, bot, prev_top, bot, top]:
					st.add_vertex(v)
			prev_top = top
			prev_bot = bot
	if not any:
		return
	var mi := MeshInstance3D.new()
	mi.name = "WallShadows"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_terrain_root.add_child(mi)


func _build_water() -> void:
	var img := Image.create(HEIGHTMAP_RES, HEIGHTMAP_RES, false, Image.FORMAT_RF)
	for iz in HEIGHTMAP_RES:
		for ix in HEIGHTMAP_RES:
			var x := (float(ix) + 0.5) / HEIGHTMAP_RES * HEIGHTMAP_EXTENT - HEIGHTMAP_EXTENT * 0.5
			var z := (float(iz) + 0.5) / HEIGHTMAP_RES * HEIGHTMAP_EXTENT - HEIGHTMAP_EXTENT * 0.5
			img.set_pixel(ix, iz, Color(terrain.height(x, z), 0, 0))
	_water_mat.set_shader_parameter("height_map", ImageTexture.create_from_image(img))
	var plane := PlaneMesh.new()
	plane.size = Vector2(700, 700)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.position.y = GameConfig.WATER_LEVEL
	water.material_override = _water_mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(water)


func _build_backdrop() -> void:
	var m := MeshInstance3D.new()
	m.name = "Mountains"
	m.mesh = WorldMeshes.mountains(terrain.seed_value + 9, 165.0, 330.0)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(m)


# --- Arena ring -----------------------------------------------------------------

func _build_arena_ring() -> void:
	var curtain := MeshKit.lathe(PackedVector2Array([Vector2(GameConfig.ARENA_RADIUS, -0.2), Vector2(GameConfig.ARENA_RADIUS, 2.6)]), 160, Callable(), Color.WHITE, Vector2(1.0, 1.0 / 2.8))
	var b := MeshInstance3D.new()
	b.name = "Barrier"
	b.mesh = curtain
	b.material_override = _barrier_mat
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(b)
	# Lantern posts.
	var count := 30
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = WorldMeshes.lantern_post()
	mm.instance_count = count
	var glow := MultiMesh.new()
	glow.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	glow.mesh = q
	glow.instance_count = count
	var flame := MultiMesh.new()
	flame.transform_format = MultiMesh.TRANSFORM_3D
	var fm := SphereMesh.new()
	fm.radius = 0.11
	fm.height = 0.22
	fm.radial_segments = 8
	fm.rings = 4
	flame.mesh = fm
	flame.instance_count = count
	for i in count:
		var a := TAU * float(i) / float(count)
		var p := Vector2(cos(a), sin(a)) * (GameConfig.ARENA_RADIUS + 0.9)
		var y := terrain.height(p.x, p.y)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -a), Vector3(p.x, y, p.y)))
		glow.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 1.6), Vector3(p.x, y + 1.5, p.y)))
		flame.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, y + 1.5, p.y)))
	var posts := MultiMeshInstance3D.new()
	posts.multimesh = mm
	posts.material_override = _stone_mat
	_terrain_root.add_child(posts)
	_lantern_glow = MultiMeshInstance3D.new()
	_lantern_glow.multimesh = glow
	var gm := _glow_mat.duplicate() as ShaderMaterial
	gm.set_shader_parameter("color", Color(1.0, 0.7, 0.35))
	gm.set_shader_parameter("intensity", 1.3)
	_lantern_glow.material_override = gm
	_lantern_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(_lantern_glow)
	var flames := MultiMeshInstance3D.new()
	flames.multimesh = flame
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.75, 0.4)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.6, 0.25)
	fmat.emission_energy_multiplier = 3.0
	flames.material_override = fmat
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(flames)


# --- Architecture -----------------------------------------------------------------

## The sanctuary's monument, shrines, ruins and props (SanctuaryBuilder), merged
## into a few meshes per zone so the camera culls whole zones.
func _build_architecture() -> void:
	var result := SanctuaryBuilder.build(terrain, style)
	architecture_plan = result["plan"]
	architecture_triangles = result["triangles"]
	var root := Node3D.new()
	root.name = "Architecture"
	_terrain_root.add_child(root)
	for g: Dictionary in result["groups"]:
		for key: String in ["stone", "accent", "glow"]:
			var m: ArrayMesh = g[key]
			if m == null:
				continue
			var mi := MeshInstance3D.new()
			mi.name = "%s_%s" % [g["name"], key]
			mi.mesh = m
			match key:
				"stone":
					mi.material_override = _stone_mat
				"accent":
					mi.material_override = _accent_mat
				_:
					mi.material_override = _emissive_mat
			var shadows: bool = g["shadows"] and key != "glow"
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)


## True if `p` lies within `margin` of a piece of architecture.
func in_architecture(p: Vector2, margin: float = 0.0) -> bool:
	for pl in architecture_plan:
		if p.distance_to(pl["pos"]) < float(pl["radius"]) + margin:
			return true
	return false


func _tree_mesh(kind: String, seed_value: int) -> ArrayMesh:
	var leaf_a := Color(0.24, 0.42, 0.16)
	match kind:
		"broadleaf_b":
			return WorldMeshes.broadleaf_tree(seed_value, Color(0.36, 0.46, 0.14))
		"cypress":
			return WorldMeshes.cypress_tree(seed_value, Color(0.16, 0.32, 0.18))
		"bush":
			return WorldMeshes.bush(seed_value, leaf_a)
		"palm":
			return WorldMeshes.palm_tree(seed_value, Color(0.22, 0.46, 0.16))
		"pine":
			return WorldMeshes.pine_tree(seed_value, Color(0.14, 0.32, 0.2))
		"dead":
			return WorldMeshes.dead_tree(seed_value)
	return WorldMeshes.broadleaf_tree(seed_value, leaf_a)


## Shafts of sunlight slanting down behind the great monument (day only).
func _build_shafts() -> void:
	if not bool(style.get("shafts", false)) or bool(theme["night"]):
		return
	var mat := ShaderMaterial.new()
	mat.shader = SHAFT_SHADER
	mat.set_shader_parameter("color", (theme["sun_color"] as Color).lerp(theme["fog_color"], 0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain.seed_value * 53 + 7
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = 7
	var yaw := SanctuaryBuilder.facing_centre(SanctuaryBuilder.FOCAL_POS)
	for i in 7:
		var x := (float(i) - 3.0) * 4.2 + rng.randf_range(-1.2, 1.2)
		var w := rng.randf_range(2.6, 5.5)
		var h := rng.randf_range(26.0, 36.0)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), rng.randf_range(0.28, 0.4))
		mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3(w, h, 1.0)), Vector3(SanctuaryBuilder.FOCAL_POS.x + x, h * 0.42, SanctuaryBuilder.FOCAL_POS.y + rng.randf_range(-5.0, 3.0))))
	var mi := MultiMeshInstance3D.new()
	mi.name = "SunShafts"
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(mi)


# --- Ground cover -------------------------------------------------------------------

## Spots on open ground inside the playfield, in loose clusters: no paving, no
## terrace walls, not under water. Purely visual: the serpent passes through.
func _flora_spots(rng: RandomNumberGenerator, clusters: int, per_cluster: int, spread: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var tries := 0
	var made := 0
	while made < clusters and tries < clusters * 6:
		tries += 1
		var r := sqrt(rng.randf()) * (GameConfig.ARENA_RADIUS + 3.5)
		var a := rng.randf() * TAU
		var c := Vector2(cos(a), sin(a)) * r
		if r < TerrainField.PLAZA_RADIUS + 1.5:
			continue
		made += 1
		for i in per_cluster:
			var p := c + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
			var g := ground_info(p.x, p.y)
			if g.x < GameConfig.WATER_LEVEL + 0.2 or g.y > 0.5 or g.z > 0.15:
				continue
			if in_architecture(p, 0.3):
				continue
			var s := rng.randf_range(0.75, 1.35)
			out.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, g.x, p.y)))
	return out


func _add_flora(node_name: String, mesh: ArrayMesh, spots: Array[Transform3D], mat: Material) -> void:
	if spots.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 70.0
	_terrain_root.add_child(mi)


## Ferns, flowers, pebbles and the sanctuary's own ground detail (fallen leaves,
## ice, glowing mushrooms...).
func _build_flora() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain.seed_value * 71 + 9
	var k: float = [0.45, 0.75, 1.0][quality]
	var ferns := float(style.get("ferns", 0.5))
	if ferns > 0.0:
		_add_flora("Ferns", WorldMeshes.fern(11), _flora_spots(rng, int(70.0 * ferns * k), 4, 1.3), _flora_mat)
	var cols: Array = style.get("flowers", [])
	for i in cols.size():
		_add_flora("Flowers%d" % i, WorldMeshes.flowers(20 + i, cols[i]), _flora_spots(rng, int(60.0 * k / float(cols.size())), 6, 1.5), _flora_mat)
	_add_flora("Pebbles", WorldMeshes.pebbles(31), _flora_spots(rng, int(60.0 * k), 3, 1.0), _stone_mat)
	match str(style.get("special", "")):
		"leaves":
			_add_flora("LeafLitter", WorldMeshes.leaf_litter(41), _flora_spots(rng, int(110.0 * k), 5, 2.0), _flora_mat)
		"ice":
			_add_flora("Ice", WorldMeshes.shards(51, Color(0.78, 0.92, 1.0)), _flora_spots(rng, int(70.0 * k), 3, 1.0), _accent_mat)
		"shells":
			_add_flora("Shells", WorldMeshes.shards(52, Color(1.0, 0.9, 0.82)), _flora_spots(rng, int(40.0 * k), 3, 0.8), _accent_mat)
		"mushrooms":
			_add_flora("Mushrooms", WorldMeshes.mushrooms(61, style["light"]), _flora_spots(rng, int(70.0 * k), 4, 0.9), _emissive_mat)


# --- Weather ----------------------------------------------------------------------

## One particle system, re-dressed for each sanctuary: rain, snow, falling leaves,
## rising embers, drifting mist or pollen. It follows the camera.
func _build_weather() -> void:
	_weather = GPUParticles3D.new()
	_weather.name = "Weather"
	_weather.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weather.visible = false
	add_child(_weather)


func _apply_weather(kind: String) -> void:
	_weather_kind = kind
	if _weather == null:
		return
	# amount, lifetime, quad size, colour, gravity, speed, emitter height, box half height, additive, upright streak
	var cfg := {
		"rain": [420, 1.1, Vector2(0.025, 0.7), Color(0.75, 0.86, 0.9, 0.34), -22.0, 4.0, 11.0, 1.0, false, true],
		"snow": [260, 7.0, Vector2(0.07, 0.07), Color(1.0, 1.0, 1.0, 0.9), -1.1, 0.5, 8.0, 3.0, false, false],
		"leaves": [70, 8.0, Vector2(0.16, 0.11), Color(0.92, 0.46, 0.1, 1.0), -0.9, 0.7, 8.0, 3.0, false, false],
		"embers": [70, 5.0, Vector2(0.06, 0.06), Color(1.0, 0.5, 0.16, 1.0), 0.7, 0.4, 0.6, 1.0, true, false],
		"pollen": [60, 9.0, Vector2(0.05, 0.05), Color(1.0, 0.94, 0.6, 0.8), 0.03, 0.2, 2.0, 2.0, true, false],
		"mist": [10, 14.0, Vector2(11.0, 5.0), Color(0.86, 0.9, 0.9, 0.1), 0.0, 0.35, 1.2, 0.8, false, false],
	}
	if not cfg.has(kind) or quality == 0:
		_weather.visible = false
		_weather.emitting = false
		return
	var c: Array = cfg[kind]
	var share: float = [0.0, 0.55, 1.0][quality]
	_weather.amount = maxi(int(float(c[0]) * share), 4)
	_weather.lifetime = c[1]
	_weather.preprocess = c[1]
	_weather.visibility_aabb = AABB(Vector3(-30, -6, -30), Vector3(60, 24, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, float(c[7]), 24)
	pm.emission_shape_offset = Vector3(0, float(c[6]), 0)
	pm.gravity = Vector3(0.6 if kind == "rain" else 0.15, float(c[4]), 0.0)
	pm.direction = Vector3(0.3, -1.0 if float(c[4]) < 0.0 else 1.0, 0.1)
	pm.spread = 12.0 if kind == "rain" else 60.0
	pm.initial_velocity_min = float(c[5]) * 0.5
	pm.initial_velocity_max = float(c[5])
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	if kind == "leaves" or kind == "snow":
		pm.angle_min = 0.0
		pm.angle_max = 360.0
		pm.angular_velocity_min = -90.0
		pm.angular_velocity_max = 90.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.12, 0.85, 1.0])
	var col: Color = c[3]
	fade.colors = PackedColorArray([Color(col.r, col.g, col.b, 0.0), col, col, Color(col.r, col.g, col.b, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	_weather.process_material = pm
	var quad := QuadMesh.new()
	quad.size = c[2]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if c[8] else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if c[9] else BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	if kind != "rain" and kind != "leaves":
		mat.albedo_texture = _soft_tex
	quad.material = mat
	_weather.draw_pass_1 = quad
	_weather.visible = true
	_weather.emitting = true


# --- Vegetation -----------------------------------------------------------------

func _build_vegetation() -> void:
	# Four kinds of tree and shrub, chosen by the sanctuary (the last is the low
	# one that grows nearest the shore).
	var kinds: Array = style.get("trees", ["broadleaf", "broadleaf_b", "cypress", "bush"])
	var variants: Array[ArrayMesh] = []
	for i in 4:
		variants.append(_tree_mesh(str(kinds[i]), i + 1))
	var lists: Array = [[], [], [], []]
	# Shore band just outside the arena ring, islets and the far shore.
	for i in 900:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(GameConfig.ARENA_RADIUS + 2.6, 170.0)
		if r > 62.0 and r < 128.0 and _rng.randf() < 0.55:
			continue
		var p := Vector2(cos(a), sin(a)) * r
		var h := terrain.height(p.x, p.y)
		if h < GameConfig.WATER_LEVEL + 0.25:
			continue
		# Keep landmark islets clear around their monument.
		if p.distance_to(Vector2(0, -64)) < 9.0 or p.distance_to(Vector2(74, 10)) < 7.5:
			continue
		# Nothing grows through the architecture.
		if in_architecture(p, 1.2):
			continue
		var kind := _rng.randi_range(0, 3)
		if r < 52.0 and kind != 3 and _rng.randf() < 0.35:
			kind = 3
		var s := _rng.randf_range(0.8, 1.25) * (1.4 if r > 128.0 else 1.0)
		var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, h - 0.1, p.y))
		lists[kind].append(xf)
	for k in variants.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = variants[k]
		mm.instance_count = lists[k].size()
		for i in lists[k].size():
			mm.set_instance_transform(i, lists[k][i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Trees%d" % k
		mi.multimesh = mm
		mi.material_override = _foliage_mat
		_terrain_root.add_child(mi)

	# Lily pads on shallow water.
	var pads := MultiMesh.new()
	pads.transform_format = MultiMesh.TRANSFORM_3D
	pads.use_colors = true
	pads.mesh = WorldMeshes.lily_pad()
	var pad_xf: Array[Transform3D] = []
	for i in 600:
		if pad_xf.size() >= 90:
			break
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(47.0, 75.0)
		var p := Vector2(cos(a), sin(a)) * r
		var depth := GameConfig.WATER_LEVEL - terrain.height(p.x, p.y)
		if depth < 0.25 or depth > 1.6:
			continue
		var cl := _rng.randi_range(1, 4)
		for c in cl:
			var o := p + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2))
			pad_xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.6, 1.3)), Vector3(o.x, GameConfig.WATER_LEVEL + 0.015, o.y)))
	pads.instance_count = pad_xf.size()
	for i in pad_xf.size():
		pads.set_instance_transform(i, pad_xf[i])
		pads.set_instance_color(i, Color(1, 1, 1) if _rng.randf() > 0.15 else Color(1.0, 0.75, 0.85))
	var pad_mi := MultiMeshInstance3D.new()
	pad_mi.multimesh = pads
	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.albedo_color = Color(0.85, 1.0, 0.8)
	pm.roughness = 0.45
	pad_mi.material_override = pm
	pad_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(pad_mi)

	# Grass clumps, chunked so the camera frustum culls most of them.
	_grass_mesh = WorldMeshes.grass_clump(7, 3)
	for i in GRASS_CHUNKS * GRASS_CHUNKS:
		var mi := MultiMeshInstance3D.new()
		mi.name = "Grass%d" % i
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _grass_mesh
		mi.multimesh = mm
		mi.material_override = _grass_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 60.0
		_terrain_root.add_child(mi)
		_grass_chunks.append(mi)


var _grass_blockers: Array[Obstacle] = []


func _update_grass_density() -> void:
	if _grass_chunks.is_empty():
		return
	var target: int = [1100, 2600, 4600][quality]
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain.seed_value * 13 + 1
	var per_chunk: Array = []
	for i in _grass_chunks.size():
		per_chunk.append([])
	var size := (GameConfig.ARENA_RADIUS + 6.0) * 2.0 / float(GRASS_CHUNKS)
	var tries := 0
	var placed := 0
	while placed < target and tries < target * 4:
		tries += 1
		var r := sqrt(rng.randf()) * (GameConfig.ARENA_RADIUS + 5.0)
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * r
		if r < TerrainField.PLAZA_RADIUS + 0.8:
			continue
		var v := terrain.variation(p.x, p.y)
		if rng.randf() > 0.25 + v * 0.9:
			continue
		var g := ground_info(p.x, p.y)
		var h := g.x
		if h < GameConfig.WATER_LEVEL + 0.25:
			continue
		# No grass on terrace walls or paving.
		if g.y > 0.55 or g.z > 0.2:
			continue
		var blocked := false
		for ob in _grass_blockers:
			if ob.edge_distance_within(p, 0.15) < 0.15:
				blocked = true
				break
		if blocked:
			continue
		var cx := clampi(int((p.x + GameConfig.ARENA_RADIUS + 6.0) / size), 0, GRASS_CHUNKS - 1)
		var cz := clampi(int((p.y + GameConfig.ARENA_RADIUS + 6.0) / size), 0, GRASS_CHUNKS - 1)
		var s := rng.randf_range(0.7, 1.35) * (0.7 if r > GameConfig.ARENA_RADIUS else 1.0)
		per_chunk[cz * GRASS_CHUNKS + cx].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(p.x, h, p.y)))
		placed += 1
	for i in _grass_chunks.size():
		var mm := _grass_chunks[i].multimesh
		var list: Array = per_chunk[i]
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k])


# --- Landmarks -------------------------------------------------------------------

func _build_landmarks() -> void:
	# Floating lanterns on the lake (night theme only).
	_night_lanterns = Node3D.new()
	_night_lanterns.name = "LakeLanterns"
	_terrain_root.add_child(_night_lanterns)
	var lm := MultiMesh.new()
	lm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.4, 0.35)
	lm.mesh = box
	var gl := MultiMesh.new()
	gl.transform_format = MultiMesh.TRANSFORM_3D
	gl.mesh = QuadMesh.new()
	var xs: Array[Transform3D] = []
	for i in 400:
		if xs.size() >= 40:
			break
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(54.0, 120.0)
		var p := Vector2(cos(a), sin(a)) * r
		if terrain.height(p.x, p.y) > GameConfig.WATER_LEVEL - 0.5:
			continue
		xs.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(p.x, GameConfig.WATER_LEVEL + 0.2, p.y)))
	lm.instance_count = xs.size()
	gl.instance_count = xs.size()
	for i in xs.size():
		lm.set_instance_transform(i, xs[i])
		gl.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 2.2), xs[i].origin + Vector3(0, 0.25, 0)))
	var lmi := MultiMeshInstance3D.new()
	lmi.multimesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(1.0, 0.6, 0.3)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.55, 0.2)
	lmat.emission_energy_multiplier = 2.5
	lmi.material_override = lmat
	_night_lanterns.add_child(lmi)
	var gmi := MultiMeshInstance3D.new()
	gmi.multimesh = gl
	var gmat := _glow_mat.duplicate() as ShaderMaterial
	gmat.set_shader_parameter("color", Color(1.0, 0.6, 0.25))
	gmat.set_shader_parameter("intensity", 1.2)
	gmi.material_override = gmat
	_night_lanterns.add_child(gmi)


func _build_motes() -> void:
	_motes = GPUParticles3D.new()
	_motes.name = "Motes"
	_motes.amount = 90
	_motes.lifetime = 7.0
	_motes.preprocess = 7.0
	_motes.visibility_aabb = AABB(Vector3(-25, -4, -25), Vector3(50, 12, 50))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 2.5, 22)
	pm.gravity = Vector3(0, 0.05, 0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.35
	pm.turbulence_enabled = false
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	_motes.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_tex
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	mat.emission_energy_multiplier = 1.2
	quad.material = mat
	_motes.draw_pass_1 = quad
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_motes)


# --- Obstacles -------------------------------------------------------------------

func _build_mesh_cache() -> void:
	_mesh_cache.clear()
	var order := str(style.get("order", "classic"))
	for v in 4:
		_mesh_cache["%s:%d" % [Obstacle.KIND_PILLAR, v]] = SanctuaryKit.column_mesh(order, 5.5, 0.55, false, 10 + v, 16 if quality > 0 else 12)
		_mesh_cache["%s:%d" % [Obstacle.KIND_BROKEN_PILLAR, v]] = SanctuaryKit.column_mesh(order, 2.5, 0.55, true, 20 + v, 16 if quality > 0 else 12)
		_mesh_cache["%s:%d" % [Obstacle.KIND_ROCKS, v]] = WorldMeshes.rocks(1.25, 1.5, 30 + v)
		_mesh_cache["%s:%d" % [Obstacle.KIND_MONOLITH, v]] = WorldMeshes.monolith(3.2, 40 + v)
		_mesh_cache["%s:%d" % [Obstacle.KIND_WALL, v]] = WorldMeshes.wall(1.8, 50 + v)
	_mesh_cache["%s:0" % Obstacle.KIND_BRAZIER] = WorldMeshes.brazier()
	_mesh_cache["%s:0" % Obstacle.KIND_FALLEN_COLUMN] = WorldMeshes.fallen_column(60)
	_mesh_cache["%s:1" % Obstacle.KIND_FALLEN_COLUMN] = WorldMeshes.fallen_column(61)


func _mesh_for(ob: Obstacle) -> ArrayMesh:
	var kind := ob.kind
	if kind == Obstacle.KIND_RISING:
		kind = Obstacle.KIND_MONOLITH
	var key := "%s:%d" % [kind, ob.variant]
	if not _mesh_cache.has(key):
		key = "%s:0" % kind
	return _mesh_cache[key]


func _obstacle_scale(ob: Obstacle) -> Vector3:
	match ob.kind:
		Obstacle.KIND_PILLAR:
			return Vector3(1, ob.height / 5.5, 1)
		Obstacle.KIND_BROKEN_PILLAR:
			return Vector3(1, ob.height / 2.5, 1)
		Obstacle.KIND_ROCKS:
			var k := ob.circles[0].z / 1.25
			return Vector3(k, ob.height / 1.5, k)
		Obstacle.KIND_MONOLITH, Obstacle.KIND_RISING:
			return Vector3(1, ob.height / 3.2, 1)
		Obstacle.KIND_WALL:
			return Vector3(1, ob.height / 1.8, 1)
	return Vector3.ONE


func _make_obstacle_node(ob: Obstacle) -> Node3D:
	var root := Node3D.new()
	root.name = "Ob%d" % ob.id
	var ground := INF
	for c in ob.circles:
		ground = minf(ground, terrain.height(c.x, c.y))
	root.position = Vector3(ob.position.x, ground - 0.05, ob.position.y)
	root.rotation.y = -ob.rotation
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _mesh_for(ob)
	mi.material_override = _stone_mat
	mi.scale = _obstacle_scale(ob)
	root.add_child(mi)
	if ob.kind == Obstacle.KIND_BRAZIER:
		var fire := _make_fire()
		fire.position = Vector3(0, 1.45, 0)
		root.add_child(fire)
	return root


func _make_fire() -> Node3D:
	var root := Node3D.new()
	root.name = "Fire"
	var p := GPUParticles3D.new()
	p.amount = 22
	p.lifetime = 0.8
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.28
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 1.6, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	g.set_color(1, Color(0.8, 0.12, 0.02, 0.0))
	g.add_point(0.4, Color(1.0, 0.45, 0.1, 0.9))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_tex
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	var halo := MeshInstance3D.new()
	halo.mesh = QuadMesh.new()
	var hm := _glow_mat.duplicate() as ShaderMaterial
	hm.set_shader_parameter("color", Color(1.0, 0.55, 0.2))
	hm.set_shader_parameter("intensity", 1.1)
	halo.material_override = hm
	halo.scale = Vector3.ONE * 3.2
	halo.position = Vector3(0, 0.35, 0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.6, 0)
	light.visible = quality >= 2
	root.add_child(light)
	_fires.append(root)
	return root


## Replace the static obstacle instances for a new layout.
func set_obstacles(list: Array[Obstacle]) -> void:
	for n in _obstacle_root.get_children():
		n.queue_free()
	_obstacle_nodes.clear()
	_fires.clear()
	for id in _rising:
		var e: Dictionary = _rising[id]
		if is_instance_valid(e["disc"]):
			e["disc"].queue_free()
	_rising.clear()
	for ob in list:
		if ob.kind == Obstacle.KIND_CLIFF:
			continue # terrace walls are part of the terrain mesh
		var node := _make_obstacle_node(ob)
		_obstacle_root.add_child(node)
		_obstacle_nodes[ob.id] = node


func on_rise_warning(ob: Obstacle) -> void:
	var disc := MeshInstance3D.new()
	disc.name = "RiseWarn%d" % ob.id
	disc.mesh = MeshKit.draped_disc(terrain, ob.position, ob.bounding_radius() + 1.0, 10, 0.06)
	disc.position = Vector3(ob.position.x, 0, ob.position.y)
	var mat := ShaderMaterial.new()
	mat.shader = RUNE_DISC_SHADER
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_obstacle_root.add_child(disc)
	_rising[ob.id] = {"ob": ob, "disc": disc, "mat": mat, "node": null, "fade": 1.0}


func on_rise_start(ob: Obstacle) -> void:
	if not _rising.has(ob.id):
		on_rise_warning(ob)
	var e: Dictionary = _rising[ob.id]
	var node := _make_obstacle_node(ob)
	_obstacle_root.add_child(node)
	_obstacle_nodes[ob.id] = node
	e["node"] = node
	# Its own material while it rises (glowing runes), the shared one afterwards.
	var mi := node.get_node("Mesh") as MeshInstance3D
	mi.material_override = _stone_mat.duplicate()


func obstacle_node(id: int) -> Node3D:
	return _obstacle_nodes.get(id)


func update_view(delta: float, head_pos: Vector3, camera_pos: Vector3) -> void:
	_time += delta
	_barrier_mat.set_shader_parameter("head_pos", head_pos)
	_grass_mat.set_shader_parameter("player_pos", head_pos)
	if _motes:
		_motes.global_position = Vector3(camera_pos.x, 0.5, camera_pos.z).lerp(Vector3(head_pos.x, 0.5, head_pos.z), 0.6)
	if _weather and _weather.visible:
		_weather.global_position = Vector3(camera_pos.x, 0.0, camera_pos.z).lerp(Vector3(head_pos.x, 0.0, head_pos.z), 0.5)
	var done: Array = []
	for id in _rising:
		var e: Dictionary = _rising[id]
		var ob: Obstacle = e["ob"]
		var mat: ShaderMaterial = e["mat"]
		if ob.state == Obstacle.State.WARNING:
			mat.set_shader_parameter("progress", 1.0 - ob.timer / GameConfig.RISE_WARNING_TIME)
			mat.set_shader_parameter("intensity", 1.6)
		else:
			var node: Node3D = e["node"]
			if node:
				var mi := node.get_node("Mesh") as MeshInstance3D
				var sink := (1.0 - ease(ob.rise, 0.4)) * (ob.height + 0.7)
				var shake := 0.04 * (1.0 - ob.rise) * sin(_time * 70.0)
				mi.position = Vector3(shake, -sink, shake * 0.6)
				if ob.state == Obstacle.State.RISING:
					(mi.material_override as ShaderMaterial).set_shader_parameter("rune_glow", 0.4 + 2.2 * (1.0 - ob.rise))
				elif mi.material_override != _stone_mat:
					mi.material_override = _stone_mat
			if ob.state == Obstacle.State.ACTIVE:
				e["fade"] = float(e["fade"]) - delta * 1.2
			mat.set_shader_parameter("progress", 1.0)
			mat.set_shader_parameter("intensity", maxf(float(e["fade"]), 0.0) * 1.6)
			if float(e["fade"]) <= 0.0:
				done.append(id)
	for id in done:
		var e: Dictionary = _rising[id]
		(e["disc"] as Node).queue_free()
		_rising.erase(id)
