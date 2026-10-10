extends Node
const Physics = preload("res://scripts/motion_web.gd")
const Spring = preload("res://scripts/motion_spring.gd")
var checks := 0
var failures := 0
var game: Node
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func wait(seconds: float = 0.1) -> void:
	await get_tree().create_timer(seconds).timeout

func move_pointer(point: Vector2, movement: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = movement
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame

func mouse(point: Vector2, button: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down and button == MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func capture(label: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	# Equal elapsed time must mean the same physical state, including velocity.
	var reference := Vector2.ZERO
	for fps in [30, 60, 120]:
		var state := Vector2.ZERO
		for i in fps: state = Physics.step(state.x, state.y, 1.0, 1.0 / fps)
		if fps == 30: reference = state
		check(state.distance_to(reference) < 0.0001, "Spring trajectory is independent of frame rate at %d Hz" % fps)
	var bounce := Vector2.ZERO
	var peak := 0.0
	for i in 360:
		bounce = Physics.step(bounce.x, bounce.y, 1.0, 1.0 / 120.0, 200.0, 10.0)
		peak = maxf(peak, bounce.x)
	check(peak > 1.05 and absf(bounce.x - 1.0) < 0.001, "A spring overshoots and then converges")
	var rope := Physics.Rope.new()
	rope.setup(Vector2.ZERO, Vector2(0, -30), 5)
	rope.pluck(Vector2(0, -20), Vector2(12, 2), 30)
	rope.advance(0.05)
	check(rope.points[-1].distance_to(rope.home[-1]) > 0.5, "A plucked independent stem actually moves")
	var worst := 0.0
	for i in 240:
		rope.advance(1.0 / 120.0)
		for j in range(rope.points.size() - 1):
			worst = maxf(worst, absf(rope.points[j].distance_to(rope.points[j + 1]) / rope.segment - 1.0))
	check(worst < 0.35 and rope.points[0] == rope.home[0], "Verlet links stay bounded and the root stays pinned")
	check(rope.at_rest(), "A reed settles instead of running forever")
	check(Physics.held_impact(0.01, 0.32, 9.0) == Physics.held_impact(0.02, 0.32, 9.0), "Held impact preserves a stop-motion frame")
	check(Physics.held_impact(0.4, 0.32, 9.0) == Vector2.ZERO, "Impact returns to exact rest")
	var velocity := Physics.steer(Vector2.RIGHT * 0.035, Vector2.UP, 1.0 / 60.0, 0.035, 0.12)
	check(velocity.distance_to(Vector2.RIGHT * 0.035) <= 0.12 / 60.0 + 0.000001, "Steering caps force instead of snapping heading")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await wait(0.3)
	if game._intro_playing: game._finish_intro()
	await wait(1.5)
	var subject := Control.new()
	scene.add_child(subject)
	Spring.to(subject, "position", Vector2(100, 0))
	await wait(0.08)
	var old_pose := subject.position
	var driver := subject.get_node("MotionSpring_position")
	var old_velocity: Vector2 = driver.velocity
	Spring.to(subject, "position", Vector2(20, 0))
	check(subject.position == old_pose and driver.velocity == old_velocity, "Retarget preserves pose and momentum")
	game._paused = true
	await wait(0.08)
	check(subject.position == old_pose, "Pause freezes a native motion spring")
	game._paused = false
	await wait(1.0)
	check(subject.position == Vector2(20, 0) and not driver.is_processing(), "Spring stops processing at an exact rest state")
	game.wetland.reduced_motion = true
	Spring.to(subject, "position", Vector2(40, 0))
	check(subject.position == Vector2(40, 0), "Reduced motion reaches the final pose immediately")
	game.wetland.reduced_motion = false
	subject.queue_free()
	# Real input dispatch, rather than calling a private hover or press callback.
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	scene.add_child(overlay)
	var presses := [0]
	var button: Button = game._make_button("动效检查", func(): presses[0] += 1, 16)
	button.position = Vector2(600, 80)
	button.size = Vector2(160, 46)
	overlay.add_child(button)
	await wait(0.1)
	var contact := button.get_global_rect().get_center()
	await move_pointer(contact)
	mouse(contact, MOUSE_BUTTON_LEFT, true)
	await wait(0.07)
	check(button.scale.y < 0.99, "Real mouse-down compresses a styled button")
	mouse(contact, MOUSE_BUTTON_LEFT, false)
	await wait(0.8)
	print("BUTTON_RELEASE: scale=", button.scale, " presses=", presses[0], " pressed=", button.is_pressed())
	check(button.scale == Vector2.ONE and presses[0] == 1, "Mouse-up restores the button and preserves its action")
	button.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await wait(0.07)
	check(button.scale.y < 0.99, "Keyboard activation gets the same physical contact feedback")
	key = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = false
	Input.parse_input_event(key)
	await wait(0.8)
	check(button.scale == Vector2.ONE and presses[0] == 2, "Keyboard release restores pose and fires exactly one action")
	game.wetland.reduced_motion = true
	await move_pointer(contact)
	mouse(contact, MOUSE_BUTTON_LEFT, true)
	await wait(0.07)
	check(button.scale == Vector2.ONE, "Reduced-motion button feedback leaves its geometry stable")
	mouse(contact, MOUSE_BUTTON_LEFT, false)
	await wait(0.1)
	check(presses[0] == 3, "Reduced motion preserves the button's actual action")
	game.wetland.reduced_motion = false
	button.disabled = true
	mouse(contact, MOUSE_BUTTON_LEFT, true)
	mouse(contact, MOUSE_BUTTON_LEFT, false)
	await wait(0.1)
	check(button.scale == Vector2.ONE and presses[0] == 3, "Disabled buttons do not emit motion or actions")
	overlay.queue_free()
	await wait(0.1)
	var reeds: Control = game.menu_root.get_node("MotionReeds")
	var far_before: PackedVector2Array = reeds.stems[13].points.duplicate()
	var near_before: PackedVector2Array = reeds.stems[2].points.duplicate()
	await move_pointer(reeds.get_global_transform() * Vector2(50, 20), Vector2(35, 0))
	await wait(0.06)
	check(reeds.stems[2].points[-1].distance_to(near_before[-1]) > 0.5, "A real pointer sweep parts the menu reeds")
	check(reeds.stems[13].points == far_before, "Distant stems remain independent, not a single sheet")
	await capture("motion-web-menu-active")
	await move_pointer(Vector2(1000, 100))
	await wait(3.0)
	check(not reeds.is_processing(), "The curtain simulation sleeps after settling")
	await move_pointer(Vector2(1000, 100))
	await wait(0.6)
	var small_depth := 0.0
	var large_depth := 0.0
	for depth_node in game.menu_root.find_children("MotionWebDepth", "", true, false):
		if is_equal_approx(depth_node.depth, 2.0): small_depth = depth_node.displacement.length()
		if is_equal_approx(depth_node.depth, 7.0): large_depth = depth_node.displacement.length()
	check(small_depth > 0.1 and large_depth > small_depth * 1.5, "A real pointer drives distinct depth gains, not a flat slide")
	game.wetland.reduced_motion = true
	await move_pointer(Vector2(900, 600))
	for depth_node in game.menu_root.find_children("MotionWebDepth", "", true, false):
		check(depth_node.displacement == Vector2.ZERO, "Reduced motion restores a parallax layer to its authored position")
	game.wetland.reduced_motion = false
	# Actual library scroll; the native scrollbar remains the source of truth.
	game._open_knowledge_viewer()
	await wait(0.8)
	var scroll := game.knowledge_grid.get_parent().get_parent() as ScrollContainer
	var bar := scroll.get_v_scroll_bar()
	check(scroll.has_node("MotionWebScroll") and bar.max_value > bar.page, "Knowledge catalogue has an inertial scroll driver")
	bar.value = 0.0
	var scroll_point := scroll.get_global_rect().get_center()
	await move_pointer(scroll_point)
	mouse(scroll_point, MOUSE_BUTTON_WHEEL_DOWN, true)
	await wait(0.06)
	print("SCROLL_INPUT: value=", bar.value, " target=", scroll.get_node("MotionWebScroll").target, " active=", scroll.get_node("MotionWebScroll").is_processing())
	check(bar.value > 0.0 and bar.value < 72.0, "A real wheel starts a gradual scroll rather than a jump")
	await wait(0.7)
	check(is_equal_approx(bar.value, 72.0), "Inertial scroll lands exactly at the accumulated target")
	var bottom := bar.max_value - bar.page
	bar.value = bottom - 20.0
	mouse(scroll_point, MOUSE_BUTTON_WHEEL_DOWN, true)
	await wait(0.04)
	mouse(scroll_point, MOUSE_BUTTON_WHEEL_DOWN, true)
	await wait(0.04)
	check(bar.value < bottom, "Repeated wheel input cannot make pending boundary travel jump")
	await wait(0.7)
	check(is_equal_approx(bar.value, bottom), "A saturated scroll target lands at the real list boundary")
	bar.value = 10.0
	await wait(0.1)
	check(is_equal_approx(bar.value, 10.0), "Native scrollbar changes cancel the old inertia")
	game._show_popup("动效检查", "弹窗期间，背景列表不响应滚轮。", "继续", Callable())
	await wait(0.3)
	mouse(scroll_point, MOUSE_BUTTON_WHEEL_DOWN, true)
	await wait(0.1)
	check(is_equal_approx(bar.value, 10.0), "An overlay cannot accidentally scroll the covered catalogue")
	game._on_popup_button()
	game._on_popup_button()
	game._close_knowledge_viewer()
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261008"
	game._on_start_pressed()
	await wait(0.7)
	for i in 12:
		if not game.popup_root.visible: break
		game._on_popup_button()
		await wait(0.1)
	game._fan_deck(true)
	await wait(0.05)
	check(game.deck_backs[0].position != Vector2(12, 4), "Deck layers respond to the fan gesture")
	game._fan_deck(false)
	await wait(1.0)
	check(game.deck_backs[0].position == Vector2(12, 4), "Interrupted deck spring returns to its own stack slot")
	game.season_dial.turn_to(2)
	await wait(1.2)
	check(is_equal_approx(game.season_dial._angle, PI * 0.5), "Season indicator endpoint lands on the exact season")
	var wetland = game.wetland
	wetland.interests.clear()
	wetland.interest_cooldown = 0.0
	var bird: Dictionary = {}
	for candidate in wetland.bird_agents:
		var visible_point: Vector2 = wetland._point(candidate.home)
		if candidate.slot < wetland._bird_count(candidate.sid) and Rect2(300, 150, 680, 280).has_point(visible_point):
			bird = candidate
			break
	check(not bird.is_empty(), "Ecology gesture is tested on an unobscured, populated lake point")
	if bird.is_empty(): bird = wetland.bird_agents[0]
	bird.state = 0
	bird.pos = bird.home
	var aim: Vector2 = bird.home + Vector2(0.015, 0.0)
	if not wetland._is_water(aim): aim = bird.home
	var rng_before: int = GameState._knowledge_rng.state
	seed(261008)
	var expected_random := randi()
	seed(261008)
	var funds_before: int = GameState.funds
	var metrics_before: Dictionary = GameState.metrics.duplicate(true)
	var lake_point: Vector2 = wetland.get_global_transform() * wetland._point(aim)
	await move_pointer(lake_point)
	print("LAKE_INPUT: point=", lake_point, " water=", wetland._is_water(aim), " hover=", get_viewport().gui_get_hovered_control())
	mouse(lake_point, MOUSE_BUTTON_LEFT, true)
	mouse(lake_point, MOUSE_BUTTON_LEFT, false)
	await wait(0.04)
	check(wetland.interests.size() > 0 or wetland.interest_captures > 0, "A real lake click emits a bounded scenery reaction")
	await wait(2.0)
	check(wetland.interest_captures > 0, "A waterbird closes the causal loop with a visible response")
	check(GameState._knowledge_rng.state == rng_before and GameState.funds == funds_before and GameState.metrics == metrics_before,
		"Scenery input never changes game RNG, funds or metrics")
	check(randi() == expected_random, "Scenery input also leaves the global gameplay random sequence untouched")
	for i in 20:
		wetland.interest_cooldown = 0.0
		wetland._emit_interest(bird.home)
	check(wetland.interests.size() <= wetland.MAX_INTERESTS, "Repeated emitters enforce the cap at insertion")
	# No new emitters during the lifetime assertion; the actual gesture was tested above.
	wetland.set_process_input(false)
	await wait(4.2)
	check(wetland.interests.is_empty(), "Uncaptured scenery effects expire unconditionally")
	wetland.set_process_input(true)
	game.wetland.reduced_motion = true
	check(not wetland._emit_interest(bird.home), "Reduced motion disables the ecology gesture")
	await capture("motion-web-reduced")
	game.wetland.reduced_motion = false
	await capture("motion-web-game")
	for window_size in [Vector2i(960, 540), Vector2i(1600, 900)]:
		get_window().size = window_size
		await wait(0.4)
		check(game.lever_handle.get_global_rect().size.x > 0.0, "Native motion preserves responsive layout at %s" % window_size)
	game.bgm_player.stop()
	game.bgm_player.stream = null
	scene.queue_free()
	await get_tree().process_frame
	print("MOTION_WEB: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
