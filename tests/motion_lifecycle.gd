extends Node
const Motion = preload("res://scripts/motion.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	var target := Node2D.new()
	add_child(target)
	var old := Motion.tween(target, "carry", "position")
	old.pause()
	old.tween_property(target, "position", Vector2(100, 0), 1.0)
	old.custom_step(0.25)
	var interrupted := target.position
	check(interrupted.x > 0.0 and interrupted.x < 100.0, "Carry has an intermediate pose")
	var replacement := Motion.tween(target, "response", "position")
	replacement.pause()
	check(not old.is_valid(), "Replacing a channel kills its previous timeline")
	check(target.position == interrupted, "Retargeting never snaps to a stale start pose")
	replacement.tween_property(target, "position", Vector2(200, 0), 1.0)
	replacement.custom_step(0.2)
	check(target.position.x > interrupted.x, "Replacement starts from the current pose")
	var scale := Motion.tween(target, "arrival", "scale")
	scale.pause()
	scale.tween_property(target, "scale", Vector2(2, 2), 0.2)
	Motion.cancel(target, "position")
	check(scale.is_valid(), "Cancelling movement preserves independent scale animation")
	scale.custom_step(0.3)
	check(target.scale.is_equal_approx(Vector2(2, 2)), "Arrival settles at an exact final value")
	check(not target.has_meta("motion_scale"), "Finished timelines release channel metadata")
	var callbacks := [0]
	var delayed := Motion.tween(target, "linear", "delayed")
	delayed.pause()
	delayed.tween_interval(0.1)
	delayed.tween_callback(func(): callbacks[0] += 1)
	Motion.cancel(target, "delayed")
	await get_tree().create_timer(0.15).timeout
	check(callbacks[0] == 0, "Cancelled timelines cannot run obsolete callbacks")
	var paused := Motion.tween(target, "response", "pause")
	paused.tween_property(target, "position", Vector2(300, 0), 0.3)
	paused.pause()
	var before_pause := target.position
	await get_tree().create_timer(0.05).timeout
	check(target.position == before_pause, "Native pause leaves the pose unchanged")
	paused.play()
	await get_tree().create_timer(0.4).timeout
	check(target.position.is_equal_approx(Vector2(300, 0)), "Native resume reaches the exact endpoint")
	var source := Control.new()
	var proxy := Control.new()
	add_child(source)
	add_child(proxy)
	source.modulate.a = 0.7
	source.scale = Vector2(1.12, 1.12)
	source.rotation = 0.08
	Motion.borrow_face(proxy, source)
	check(proxy.scale == source.scale and proxy.rotation == source.rotation, "A carried face starts in the source's current pose")
	check(is_zero_approx(source.modulate.a), "Carry renders only one card face")
	Motion.release_face(proxy)
	check(is_equal_approx(source.modulate.a, 0.7), "Explicit close restores the source opacity")
	Motion.borrow_face(proxy, source)
	proxy.queue_free()
	await get_tree().process_frame
	check(is_equal_approx(source.modulate.a, 0.7), "Removing a detail proxy restores its source")
	var early_proxy := Control.new()
	add_child(early_proxy)
	var entry := Motion.tween(source, "enter", "arrival")
	entry.pause()
	entry.tween_property(source, "modulate:a", 1.0, 0.2)
	Motion.borrow_face(early_proxy, source)
	check(not entry.is_valid(), "Borrowing during entrance stops the competing opacity tween")
	Motion.release_face(early_proxy)
	check(is_equal_approx(source.modulate.a, 1.0), "Interrupted entrance returns a fully visible source")
	Motion.borrow_face(early_proxy, source)
	source.queue_free()
	await get_tree().process_frame
	Motion.release_face(early_proxy)
	check(not early_proxy.has_meta("motion_source"), "Viewer rebuild tolerates a freed source")
	var orphan := Motion.tween(target, "camera", "orphan")
	orphan.tween_interval(10.0)
	target.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not orphan.is_valid(), "Removing a node releases its bound timelines")
	print("MOTION_LIFECYCLE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
