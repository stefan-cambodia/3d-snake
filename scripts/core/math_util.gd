class_name MathUtil
extends RefCounted
## Small, allocation-free helpers for frame-rate independent smoothing.


## Blend factor for exponential smoothing with time constant `tau` over `dt`.
## Identical results regardless of how a time span is split into frames.
static func damp_factor(tau: float, dt: float) -> float:
	if tau <= 0.0:
		return 1.0
	return 1.0 - exp(-dt / tau)


static func damp(current: float, target: float, tau: float, dt: float) -> float:
	return lerpf(current, target, damp_factor(tau, dt))


static func damp_v3(current: Vector3, target: Vector3, tau: float, dt: float) -> Vector3:
	return current.lerp(target, damp_factor(tau, dt))


static func damp_angle(current: float, target: float, tau: float, dt: float) -> float:
	return current + wrapf(target - current, -PI, PI) * damp_factor(tau, dt)


## Unit heading vector on the ground plane. heading = 0 points to +Z,
## increasing heading turns left (counter-clockwise seen from above).
static func heading_dir(heading: float) -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading))


static func heading_dir2(heading: float) -> Vector2:
	return Vector2(sin(heading), cos(heading))


## Right-hand vector for a heading (snake's right side).
static func heading_right(heading: float) -> Vector3:
	return Vector3(-cos(heading), 0.0, sin(heading))


static func heading_of(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)


static func xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Smoothstep without clamping surprises.
static func smooth01(e0: float, e1: float, x: float) -> float:
	if e1 == e0:
		return 1.0 if x >= e1 else 0.0
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Deterministic 1D hash in [0, 1).
static func hash01(n: int) -> float:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x & 0xffffff) / 16777216.0
