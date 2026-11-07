extends TestCase


func test_records_have_exact_spacing() -> void:
	var sp := Spine.new(0.2, 256)
	sp.reset(Vector3.ZERO, Vector3(0, 0, -1), 1.0)
	var p := Vector3.ZERO
	# Irregular step sizes, including steps larger than the spacing.
	var steps := [0.05, 0.13, 0.31, 0.02, 0.27, 0.2, 0.11, 0.45, 0.07]
	for i in 60:
		p += Vector3(0, 0, steps[i % steps.size()])
		sp.advance(p)
	for i in 30:
		check_near(sp.record(i).distance_to(sp.record(i + 1)), 0.2, 0.0005, "record %d spacing" % i)
	check_near(sp.point_at(0.0).z, p.z, 0.0001, "s=0 is the head")


func test_body_follows_head_path() -> void:
	# Drive along a circle: every sampled body point must lie on that circle.
	var sp := Spine.new(0.2, 1024)
	var radius := 5.0
	sp.reset(Vector3(radius, 0, 0), Vector3(0, 0, -1), 0.4)
	var ang := 0.0
	for i in 600:
		ang += 0.01
		sp.advance(Vector3(cos(ang) * radius, 0, sin(ang) * radius))
	var max_err := 0.0
	var s := 0.0
	while s < 25.0:
		var q := sp.point_at(s)
		max_err = maxf(max_err, absf(Vector2(q.x, q.z).length() - radius))
		s += 0.37
	check(max_err < 0.01, "body deviates from head path by %f" % max_err)
	# Arc length between samples must match their s difference (chord ≈ arc).
	var a := sp.point_at(3.0)
	var b := sp.point_at(4.0)
	var chord := 2.0 * radius * sin(1.0 / (2.0 * radius))
	check_near(a.distance_to(b), chord, 0.01, "arc-length parametrisation")


func test_sample_uniform_matches_point_at() -> void:
	var sp := Spine.new(0.2, 512)
	sp.reset(Vector3.ZERO, Vector3(0, 0, -1), 1.0)
	var h := 0.0
	var p := Vector3.ZERO
	for i in 300:
		h += 0.03 * sin(float(i) * 0.05)
		p += Vector3(sin(h), 0, cos(h)) * 0.13
		sp.advance(p)
	var out := PackedVector3Array()
	sp.sample_uniform(40, 0.33, out)
	for j in 40:
		check(out[j].distance_to(sp.point_at(0.33 * j)) < 0.0001, "sample %d" % j)


func test_ring_buffer_wraps() -> void:
	var sp := Spine.new(0.2, 64)
	sp.reset(Vector3.ZERO, Vector3(0, 0, -1), 1.0)
	for i in 1000:
		sp.advance(Vector3(0, 0, float(i + 1) * 0.1))
	check_eq(sp.count(), 64, "count capped at capacity")
	check_near(sp.stored_length(), sp.head_gap + 0.2 * 63, 0.0001, "stored length")
	check_near(sp.point_at(1000.0).z, sp.record(63).z, 0.0001, "beyond tail clamps to oldest record")


func test_clearance_matches_brute_force() -> void:
	var sp := Spine.new(0.2, 1024)
	sp.reset(Vector3.ZERO, Vector3(0, 0, -1), 1.0)
	var h := 0.0
	var p := Vector3.ZERO
	for i in 900:
		h += 0.045
		p += Vector3(sin(h), 0, cos(h)) * 0.15 * (1.0 + 0.002 * i)
		sp.advance(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for t in 200:
		var q := Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
		var fast := sp.clearance_xz(q, 1.0, 80.0, 2.0)
		var brute := 2.0
		for i in sp.count():
			var s := sp.head_gap + 0.2 * i
			if s < 1.0 - 0.0001 or s > 80.0:
				continue
			var r := sp.record(i)
			brute = minf(brute, Vector2(r.x - q.x, r.z - q.z).length())
		check_near(fast, brute, 0.0001, "clearance query #%d" % t)
