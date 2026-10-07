extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(0.3).timeout
	var game: Node = scene.get_node("Game")
	if game._intro_playing: game._finish_intro()
	game.wetland.camera_tween.kill()
	game.wetland.reduced_motion = true
	GameState.run_seed = 20261004
	GameState.reset_game()
	game._hide_menu()
	game.popup_root.hide()
	game._set_hud_visible(false)
	game.wetland.sync_state({}, false)
	await get_tree().create_timer(0.3).timeout
	var wetland: Control = game.wetland
	var prepared := false
	for property in wetland.get_property_list():
		if property["name"] == "_render_shadow_specs": prepared = true
	for x in 20:
		for y in 20:
			var uv := Vector2(float(x) / 19.0, float(y) / 19.0)
			for radius in [0.01, 0.017, 0.025, 0.04]:
				var expected: bool = wetland._near_route(uv, wetland.yangtze_route, radius) or wetland._near_route(uv, wetland.gan_route, radius)
				check(wetland._in_river_corridor(uv, radius) == expected, "Cached river geometry changed")
	for window_size in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().size = window_size
		await get_tree().process_frame
		for zoom in [0.9, 1.0, 1.3]:
			wetland._set_camera_zoom(zoom)
			var inverse: Transform2D = wetland.get_node("Wildlife").get_transform().affine_inverse()
			for uv in [Vector2.ZERO, Vector2.ONE, Vector2(0.31, 0.47), Vector2(0.71, 0.83)]:
				var screen: Vector2 = wetland.map_camera.unproject_position(wetland._ground_position(uv) + Vector3(0, wetland._relief_at(uv), 0))
				check(wetland._point(uv).distance_to(screen.round()) <= 1.0, "Rounded projection changed")
				check(wetland._shadow_point(uv).distance_to(inverse * screen) < 0.002, "Continuous projection changed")
				var polygon: PackedVector2Array = wetland._shadow_polygon(uv, 0.013)
				for k in polygon.size():
					var angle := TAU * float(k) / float(polygon.size())
					var point: Vector2 = uv + Vector2(cos(angle), sin(angle) * wetland.SHADOW_FLATTEN) * 0.013
					var expected: Vector2 = inverse * wetland.map_camera.unproject_position(wetland._ground_position(point) + Vector3(0, wetland._relief_at(uv), 0))
					check(polygon[k].distance_to(expected) < 0.002, "Shadow outline changed")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var reserved_ground: Vector2 = wetland.ground_plane.size
	var started := Time.get_ticks_usec()
	var vertices := 0
	for step in 80:
		wetland._set_camera_zoom(lerpf(0.9, 1.3, float(step % 40) / 39.0))
		check(wetland.ground_plane.size.is_equal_approx(reserved_ground), "Zoom rebuilt the reserved terrain mesh")
		var specs: Array
		if prepared:
			specs = wetland.get("_render_shadow_specs")
		else:
			wetland._scenery_draw_order()
			specs = wetland._contact_shadow_specs()
		for spec in specs:
			var radius: float = wetland._px_to_uv(float(spec["radius"]))
			for band in [1.05, 0.90, 0.70]:
				vertices += wetland._shadow_polygon(spec["uv"], radius * band).size()
	print("ZOOM_CPU: ", Time.get_ticks_usec() - started, " us, 80 steps, ", vertices, " vertices")
	wetland.reduced_motion = false
	wetland._set_camera_zoom(1.12)
	var interrupted_pose: float = wetland.camera_zoom_factor
	wetland.set_menu_camera(true)
	check(is_equal_approx(wetland.camera_zoom_factor, interrupted_pose), "Menu retarget jumped to the base camera")
	await get_tree().create_timer(0.15).timeout
	var reverse_pose: float = wetland.camera_zoom_factor
	wetland.set_menu_camera(false)
	check(is_equal_approx(wetland.camera_zoom_factor, reverse_pose), "Interrupted camera reversal jumped")
	await wetland.camera_tween.finished
	# Exercise both real tween directions without changing their duration/easing.
	for far in [true, false]:
		wetland.set_menu_camera(far)
		await wetland.camera_tween.finished
		check(is_equal_approx(wetland.camera_zoom_factor, 1.3 if far else wetland.GAME_CAMERA_ZOOM), "Zoom endpoint changed")
	print("ZOOM_PERFORMANCE: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)
