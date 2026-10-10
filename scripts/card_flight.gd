extends Node2D
## One owner for position, scale and rotation; the original card stays visible.
## A short analytic ribbon replaces particles, duplicate faces and screen blur.
const Physics = preload("res://scripts/motion_web.gd")
var panel: Control
var target_position := Vector2.ZERO
var target_scale := Vector2.ONE
var target_rotation := 0.0
var duration := 0.52
var delay := 0.0
var bend := 76.0
var elapsed := 0.0
var start_center := Vector2.ZERO
var start_scale := Vector2.ONE
var start_rotation := 0.0
var completed: Callable
var spine := PackedVector2Array()

static func stop(card: Control) -> void:
	var previous := card.get_node_or_null("CardFlight")
	if previous:
		previous.set_process(false)
		card.remove_child(previous)
		previous.queue_free()

static func play(card: Control, goal: Vector2, small_scale: Vector2, angle: float,
		seconds: float = 0.52, arc: float = 76.0, callback: Callable = Callable(), lag: float = 0.0) -> Node2D:
	stop(card)
	var flight := load("res://scripts/card_flight.gd").new() as Node2D
	flight.name = "CardFlight"
	flight.panel = card
	flight.target_position = goal
	flight.target_scale = small_scale
	flight.target_rotation = angle
	flight.duration = maxf(0.001, seconds)
	flight.delay = lag
	flight.bend = arc
	flight.completed = callback
	flight.start_center = card.get_transform() * (card.size * 0.5)
	flight.start_scale = card.scale
	flight.start_rotation = card.rotation
	flight.show_behind_parent = true
	flight.spine.resize(8)
	card.add_child(flight)
	if Physics.reduced(card): flight.finish()
	return flight

func end_center() -> Vector2:
	return target_position + panel.pivot_offset + ((panel.size * 0.5 - panel.pivot_offset) * target_scale).rotated(target_rotation)

func curve(u: float) -> Vector2:
	var end := end_center()
	var delta := end - start_center
	return start_center.bezier_interpolate(start_center + delta * 0.30 + Vector2(0, -bend),
		end - delta * 0.24 + Vector2(0, -bend * 0.55), end, u)

static func progress(t: float) -> float:
	# Smooth velocity at both ends, with a fast middle like a card entering a pile.
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

func _process(dt: float) -> void:
	if Physics.paused(panel): return
	if Physics.reduced(panel):
		finish()
		return
	if delay > 0.0:
		delay -= dt
		if delay > 0.0: return
		dt = -delay
	elapsed = minf(elapsed + dt, duration)
	var t := elapsed / duration
	var u := progress(t)
	panel.scale = start_scale.lerp(target_scale, u)
	panel.rotation = lerpf(start_rotation, target_rotation, u) + sin(t * PI) * signf(end_center().x - start_center.x) * 0.13
	panel.position = curve(u) - panel.pivot_offset - ((panel.size * 0.5 - panel.pivot_offset) * panel.scale).rotated(panel.rotation)
	queue_redraw()
	if elapsed >= duration: finish()

func finish() -> void:
	panel.position = target_position
	panel.scale = target_scale
	panel.rotation = target_rotation
	set_process(false)
	if completed.is_valid(): completed.call()
	queue_free()

func _draw() -> void:
	if delay > 0.0 or elapsed <= 0.0 or not is_processing(): return
	var t := elapsed / duration
	var strength := sin(t * PI)
	var inverse := panel.get_transform().affine_inverse()
	for i in 8:
		var s := float(i) / 7.0
		var sample_t := t - minf(t * 0.9, 0.13) * (1.0 - s)
		var u := progress(sample_t)
		spine[i] = inverse * curve(u)
	# Independent tapered segments tolerate zero-distance flights and tight turns;
	# a single self-intersecting ribbon would fail polygon triangulation.
	for i in range(1, 8):
		if spine[i].distance_squared_to(spine[i - 1]) < 0.001: continue
		var s := float(i) / 7.0
		draw_line(spine[i - 1], spine[i], Color(1.0, 0.89, 0.61, 0.28 * strength * s),
			maxf(0.5, 8.0 * s * strength / panel.scale.x), true)
