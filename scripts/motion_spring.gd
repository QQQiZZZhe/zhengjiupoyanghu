extends Node
const Physics = preload("res://scripts/motion_web.gd")
var property := ""
var property_path: NodePath
var rest_value: Variant
var target: Variant
var velocity: Variant
var stiffness := 350.0
var damping := 28.0
var delay := 0.0

static func to(owner: Control, key: String, goal: Variant, k: float = 350.0, d: float = 28.0, lag: float = 0.0) -> Node:
	var node_name := "MotionSpring_" + key.replace(":", "_")
	var driver := owner.get_node_or_null(node_name)
	if driver == null:
		driver = load("res://scripts/motion_spring.gd").new()
		driver.name = node_name
		driver.property = key
		driver.property_path = NodePath(key)
		driver.velocity = Vector2.ZERO if goal is Vector2 else 0.0
		owner.add_child(driver)
	# A repeated hover target must not restart a spring that already settled.
	# Read the actual resting value (Control stores floats at native precision),
	# so an external animation moving the card still wakes the driver.
	if lag <= 0.0 and not driver.is_processing() and driver.delay <= 0.0 \
		and driver.target == goal and owner.get_indexed(driver.property_path) == driver.rest_value:
		return driver
	driver.target = goal
	driver.stiffness = k
	driver.damping = d
	driver.delay = lag
	# Retarget in place. Preserve the old velocity as well as the current pose.
	if Physics.reduced(owner) or not owner.is_visible_in_tree(): driver.finish()
	else: driver.set_process(true)
	return driver

static func stop(owner: Control, key: String) -> void:
	var driver := owner.get_node_or_null("MotionSpring_" + key.replace(":", "_"))
	if driver:
		driver.velocity = Vector2.ZERO if driver.target is Vector2 else 0.0
		driver.set_process(false)

func _ready() -> void:
	set_process(false)

func finish() -> void:
	get_parent().set_indexed(property_path, target)
	rest_value = get_parent().get_indexed(property_path)
	velocity = Vector2.ZERO if target is Vector2 else 0.0
	get_parent().queue_redraw()
	set_process(false)

func _process(dt: float) -> void:
	var owner := get_parent() as Control
	if Physics.paused(owner): return
	if Physics.reduced(owner) or not owner.is_visible_in_tree():
		finish()
		return
	if delay > 0.0:
		delay -= dt
		return
	var value: Variant = owner.get_indexed(property_path)
	var error := 0.0
	var speed := 0.0
	if value is Vector2:
		var sx := Physics.step(value.x, velocity.x, target.x, dt, stiffness, damping)
		var sy := Physics.step(value.y, velocity.y, target.y, dt, stiffness, damping)
		value = Vector2(sx.x, sy.x)
		velocity = Vector2(sx.y, sy.y)
		error = value.distance_to(target)
		speed = velocity.length()
	else:
		var state := Physics.step(float(value), float(velocity), float(target), dt, stiffness, damping)
		value = state.x
		velocity = state.y
		error = absf(value - target)
		speed = absf(velocity)
	owner.set_indexed(property_path, value)
	owner.queue_redraw()
	if error < 0.001 and speed < 0.01: finish()
