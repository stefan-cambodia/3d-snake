class_name Spine
extends RefCounted
## Movement history of the snake head.
##
## The head path is recorded as a ring buffer of points placed at an exact,
## constant arc-length spacing along the path actually travelled. The body is
## then sampled by arc length *from the head*, so every body point follows the
## exact trajectory of the head (no "rotate toward previous segment" chains).
##
## Record 0 is the newest record, `head_gap` is the arc length between the live
## head position and record 0.

var spacing: float
var capacity: int
var head: Vector3 = Vector3.ZERO
var head_gap: float = 0.0

var _pts: PackedVector3Array = PackedVector3Array()
var _newest: int = -1
var _count: int = 0


func _init(p_spacing: float = GameConfig.SPINE_SPACING, p_capacity: int = GameConfig.SPINE_CAPACITY) -> void:
	spacing = p_spacing
	capacity = p_capacity
	_pts.resize(capacity)


## Reset to a straight body lying behind `head_pos` along `back_dir`.
func reset(head_pos: Vector3, back_dir: Vector3, prefill_length: float, height_fn: Callable = Callable()) -> void:
	_count = 0
	_newest = -1
	head = head_pos
	head_gap = 0.0
	var dir := Vector3(back_dir.x, 0.0, back_dir.z).normalized()
	var n := mini(int(ceil(prefill_length / spacing)) + 3, capacity)
	# Push oldest first so record 0 ends up at the head.
	for i in range(n - 1, -1, -1):
		var p := head_pos + dir * (spacing * float(i))
		if height_fn.is_valid():
			p.y = height_fn.call(p.x, p.z)
		_push(p)


func count() -> int:
	return _count


## Total arc length currently stored behind the head.
func stored_length() -> float:
	if _count == 0:
		return 0.0
	return head_gap + spacing * float(_count - 1)


func record(i: int) -> Vector3:
	return _pts[posmod(_newest - i, capacity)]


## Move the head to `new_head`, emitting records at exact arc-length spacing.
func advance(new_head: Vector3) -> void:
	var p0 := head
	var seg := new_head - p0
	var d := seg.length()
	if d <= 0.000001:
		head = new_head
		return
	var travelled := 0.0
	while head_gap + (d - travelled) >= spacing:
		travelled += spacing - head_gap
		_push(p0 + seg * (travelled / d))
		head_gap = 0.0
	head_gap += d - travelled
	head = new_head


## Position on the path at arc length `s` behind the head (linear between records).
func point_at(s: float) -> Vector3:
	if _count == 0:
		return head
	if s <= head_gap:
		if head_gap <= 0.000001:
			return head
		return head.lerp(_pts[_newest], s / head_gap)
	var k := (s - head_gap) / spacing
	var i := int(k)
	if i >= _count - 1:
		return _pts[posmod(_newest - (_count - 1), capacity)]
	var f := k - float(i)
	return _pts[posmod(_newest - i, capacity)].lerp(_pts[posmod(_newest - i - 1, capacity)], f)


## Fill `out` with `n` points sampled uniformly from s=0 to s=(n-1)*step.
## Walks the ring buffer once: O(n + records), no per-sample search.
func sample_uniform(n: int, step: float, out: PackedVector3Array) -> void:
	if out.size() < n:
		out.resize(n)
	if _count == 0:
		for j in n:
			out[j] = head
		return
	var last := _count - 1
	for j in n:
		var s := step * float(j)
		if s <= head_gap:
			out[j] = head if head_gap <= 0.000001 else head.lerp(_pts[_newest], s / head_gap)
			continue
		var k := (s - head_gap) / spacing
		var i := int(k)
		if i >= last:
			out[j] = _pts[posmod(_newest - last, capacity)]
		else:
			out[j] = _pts[posmod(_newest - i, capacity)].lerp(_pts[posmod(_newest - i - 1, capacity)], k - float(i))


## Smallest ground-plane (XZ) distance from `p` to recorded body points whose arc
## length lies in [s_from, s_to]. Distances above `cap` are not resolved exactly
## (returns `cap`). Uses a skip-ahead bound: consecutive records are at most
## `spacing` apart, so a record at distance d means the next `(d - cap) / spacing`
## records cannot be closer than `cap`. This makes the query ~O(length / distance).
func clearance_xz(p: Vector3, s_from: float, s_to: float, cap: float) -> float:
	if _count == 0:
		return cap
	var i0 := maxi(int(ceil((s_from - head_gap) / spacing)), 0)
	var i1 := mini(int(floor((s_to - head_gap) / spacing)), _count - 1)
	var best := cap
	var i := i0
	while i <= i1:
		var q := _pts[posmod(_newest - i, capacity)]
		var dx := q.x - p.x
		var dz := q.z - p.z
		var d := sqrt(dx * dx + dz * dz)
		if d < best:
			best = d
		if d > cap:
			i += maxi(1, int((d - cap) / spacing))
		else:
			i += 1
	return best


func _push(p: Vector3) -> void:
	_newest = (_newest + 1) % capacity
	_pts[_newest] = p
	_count = mini(_count + 1, capacity)
