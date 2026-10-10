extends RefCounted
## Native adaptation of motion-web mechanisms by feitangyuan (CC BY-NC 4.0).
## Changed for Godot, bounded interaction, pixel art and exact rest states.
## Source / license / mapping: docs/MOTION_WEB.md, licenses/motion-web.txt.

static func reduced(node: Node) -> bool:
	if not node.is_inside_tree(): return false
	var host := node.get_tree().get_first_node_in_group("motion_host")
	return host != null and host.wetland != null and host.wetland.reduced_motion

static func paused(node: Node) -> bool:
	if not node.is_inside_tree(): return false
	var host := node.get_tree().get_first_node_in_group("motion_host")
	if host == null or not host._paused: return false
	# Pause controls themselves continue to answer the player's input.
	return host.pause_root == null or not host.pause_root.is_ancestor_of(node)

## Exact solution of x'' + damping*x' + stiffness*(x-target) = 0.
## Unlike a per-frame multiplier this has the same trajectory at 30/60/120 Hz.
static func step(x: float, v: float, target: float, dt: float, stiffness: float = 350.0, damping: float = 28.0) -> Vector2:
	var a := damping * 0.5
	var y := x - target
	var discriminant := stiffness - a * a
	var decay := exp(-a * dt)
	if absf(discriminant) < 0.00001:
		var b := v + a * y
		return Vector2(target + (y + b * dt) * decay, (v - a * b * dt) * decay)
	if discriminant > 0.0:
		var w := sqrt(discriminant)
		var sine := sin(w * dt)
		var cosine := cos(w * dt)
		return Vector2(target + decay * (y * cosine + (v + a * y) / w * sine),
			decay * (v * cosine - (a * v + stiffness * y) / w * sine))
	var root := sqrt(-discriminant)
	var r1 := -a + root
	var r2 := -a - root
	var c1 := (v - r2 * y) / (r1 - r2)
	var c2 := y - c1
	return Vector2(target + c1 * exp(r1 * dt) + c2 * exp(r2 * dt),
		c1 * r1 * exp(r1 * dt) + c2 * r2 * exp(r2 * dt))

static func follow(value: float, target: float, dt: float, tightness: float = 6.2) -> float:
	return lerpf(value, target, 1.0 - exp(-tightness * dt))

## The turn has a radius: cap acceleration before integrating position.
static func steer(velocity: Vector2, offset: Vector2, dt: float, speed: float, force: float) -> Vector2:
	return (velocity + (offset.normalized() * speed - velocity).limit_length(force * dt)).limit_length(speed)

## A held 11 Hz impact, with no random generator or permanent idle noise.
static func held_impact(age: float, duration: float, amplitude: float) -> Vector2:
	if age >= duration: return Vector2.ZERO
	var tick := floori(age * 11.0)
	var decay := pow(1.0 - float(tick) / 11.0 / duration, 2.0)
	return Vector2((-1.0 if tick % 2 == 0 else 1.0) * amplitude * decay,
		sin(float(tick) * 2.17) * amplitude * 0.15 * decay).round()

## Independent Verlet strings: no links between neighbouring stems.
class Rope:
	var points := PackedVector2Array()
	var previous := PackedVector2Array()
	var home := PackedVector2Array()
	var segment := 1.0
	var accumulator := 0.0
	var tip_pinned := false
	var tip := Vector2.ZERO

	func setup(start: Vector2, end: Vector2, count: int = 6, both_ends: bool = false) -> void:
		tip_pinned = both_ends
		tip = end
		segment = start.distance_to(end) / float(count - 1)
		points.clear()
		for i in count: points.append(start.lerp(end, float(i) / float(count - 1)))
		previous = points.duplicate()
		home = points.duplicate()
		accumulator = 0.0

	func pluck(position: Vector2, movement: Vector2, radius: float) -> void:
		for i in range(1, points.size() - (1 if tip_pinned else 0)):
			var weight := maxf(0.0, 1.0 - points[i].distance_to(position) / radius)
			var push := movement.limit_length(10.0) * weight
			push.y *= 0.35
			points[i] += push

	func advance(dt: float) -> void:
		accumulator = minf(accumulator + dt, 0.1)
		while accumulator >= 1.0 / 120.0:
			accumulator -= 1.0 / 120.0
			for i in range(1, points.size() - (1 if tip_pinned else 0)):
				var current := points[i]
				points[i] += (current - previous[i]) * 0.94 + (home[i] - current) * 0.025
				previous[i] = current
			for iteration in 6:
				points[0] = home[0]
				if tip_pinned: points[-1] = tip
				for i in range(points.size() - 1):
					var d := points[i + 1] - points[i]
					var length := d.length()
					if length < 0.00001: continue
					var correction := d * (length - segment) / length
					var left_fixed := i == 0
					var right_fixed := tip_pinned and i + 1 == points.size() - 1
					if not left_fixed: points[i] += correction * (1.0 if right_fixed else 0.5)
					if not right_fixed: points[i + 1] -= correction * (1.0 if left_fixed else 0.5)
			points[0] = home[0]
			if tip_pinned: points[-1] = tip

	func at_rest() -> bool:
		for i in points.size():
			if points[i].distance_squared_to(home[i]) > 0.04 or points[i].distance_squared_to(previous[i]) > 0.0001: return false
		return true

	func reset() -> void:
		points = home.duplicate()
		previous = home.duplicate()
		accumulator = 0.0
