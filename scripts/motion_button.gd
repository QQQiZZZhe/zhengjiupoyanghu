extends Control
const Physics = preload("res://scripts/motion_web.gd")
const Spring = preload("res://scripts/motion_spring.gd")
var age := 1.0
var contact := Vector2.ZERO
var rest_scale := Vector2.ONE

static func attach(button: Button) -> void:
	if button.has_node("MotionWebPress"): return
	var feedback: Control = load("res://scripts/motion_button.gd").new()
	feedback.name = "MotionWebPress"
	button.add_child(feedback)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	rest_scale = get_parent().scale
	get_parent().button_down.connect(_down)
	get_parent().button_up.connect(_up)
	get_parent().visibility_changed.connect(_visibility)
	set_process(false)

func _down() -> void:
	var button := get_parent() as Button
	if button.disabled: return
	button.pivot_offset = button.size * 0.5
	if Physics.reduced(self): return
	contact = get_local_mouse_position().clamp(Vector2.ZERO, size)
	if not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()): contact = size * 0.5
	age = 0.0
	Spring.to(button, "scale", rest_scale * Vector2(0.975, 0.95), 500.0, 32.0)
	set_process(true)
	queue_redraw()

func _up() -> void:
	Spring.to(get_parent(), "scale", rest_scale, 350.0, 22.0)

func _visibility() -> void:
	if not is_visible_in_tree():
		age = 1.0
		Spring.stop(get_parent(), "scale")
		get_parent().scale = rest_scale
		set_process(false)
		queue_redraw()

func _process(dt: float) -> void:
	if Physics.paused(self): return
	if Physics.reduced(self):
		age = 1.0
		_up()
	else: age += dt
	queue_redraw()
	if age >= 0.36: set_process(false)

func _draw() -> void:
	if age >= 0.36 or Physics.reduced(self): return
	var phase := age / 0.36
	draw_arc(contact, 3.0 + phase * minf(size.x, 70.0), 0.0, TAU, 24,
		Color(0.93, 0.78, 0.54, 0.24 * (1.0 - phase)), 1.5, false)
