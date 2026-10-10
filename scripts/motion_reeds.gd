extends Control
## char-curtain -> fourteen independent wetland reeds, not a deforming text block.
const Physics = preload("res://scripts/motion_web.gd")
var stems: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 14:
		var rope := Physics.Rope.new()
		var base := Vector2(8.0 + i * 21.0, size.y - 2.0)
		rope.setup(base, base + Vector2(sin(i * 2.4) * 4.0, -18.0 - posmod(i * 7, 13)), 5)
		stems.append(rope)
	set_process(false)

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion or not is_visible_in_tree() or Physics.reduced(self) or Physics.paused(self): return
	var local: Vector2 = get_global_transform().affine_inverse() * event.position
	if not Rect2(Vector2(-25, -20), size + Vector2(50, 40)).has_point(local): return
	for stem in stems: stem.pluck(local, event.relative * 0.6, 32.0)
	set_process(true)

func _process(dt: float) -> void:
	if Physics.paused(self): return
	var still := true
	for stem in stems:
		if Physics.reduced(self) or not is_visible_in_tree(): stem.reset()
		else: stem.advance(dt)
		still = still and stem.at_rest()
	if still:
		for stem in stems: stem.reset()
		set_process(false)
	queue_redraw()

func _draw() -> void:
	for i in stems.size():
		var points: PackedVector2Array = stems[i].points
		draw_polyline(points, Color("91a397"), 1.5, false)
		var tip := points[-1]
		draw_line(tip - Vector2(0, 3), tip + Vector2(0, 3), Color("edc68a") if i % 4 == 0 else Color("c7dcae"), 3.0, false)
		draw_line(points[2], points[2] + Vector2(-4 if i % 2 == 0 else 4, -4), Color("91a397"), 1.5, false)
