extends "res://scripts/impact_feedback.gd"
var draw_us: Array = []
var process_us: Array = []
func _draw() -> void:
	var start := Time.get_ticks_usec()
	super._draw()
	draw_us.append(Time.get_ticks_usec() - start)
func _process(dt: float) -> void:
	var start := Time.get_ticks_usec()
	super._process(dt)
	process_us.append(Time.get_ticks_usec() - start)
