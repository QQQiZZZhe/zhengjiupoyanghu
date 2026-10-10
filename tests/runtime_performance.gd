extends Node
const Spring = preload("res://scripts/motion_spring.gd")
const Geometry = preload("res://scripts/card_geometry.gd")
var checks := 0
var failures := 0
var outline_draws := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(0.4).timeout
	var game = scene.get_node("Game")
	if game._intro_playing: game._finish_intro()
	game.set_process(false)
	var wetland = game.wetland
	wetland.set_process(false)
	var started := Time.get_ticks_usec()
	for i in 1200: wetland._redraw_scenery()
	print("RUNTIME_CPU scenery1200_us=", Time.get_ticks_usec() - started)
	# Compare the entire render list with a fresh, fully sorted reference,
	# including membership, depth ties, birds and vegetation during transitions.
	for season in 4:
		wetland.season = season
		wetland.previous_season = (season + 3) % 4
		wetland.season_progress = 0.0
		GameState.run_seed = 20261009 + season
		wetland._reset_scenery()
		for frame in 15:
			wetland.displayed_plants["chishan"] = float(frame * 4)
			wetland._process(1.0 / 60.0)
			var reference: Array[Dictionary] = wetland._build_static_scenery()
			var static_count := reference.size()
			var moving: Array[Dictionary] = []
			for bird in wetland.bird_agents:
				if int(bird["slot"]) < wetland._bird_count(str(bird["sid"])) and not int(bird["state"]) in [3, 5]:
					moving.append({"kind": "bird", "uv": bird["pos"], "bird": bird})
			moving.append({"kind": "boat", "uv": wetland.BOAT_ANCHOR})
			for i in moving.size():
				moving[i]["depth"] = wetland._scenery_depth(moving[i]["uv"])
				moving[i]["order"] = static_count + i
			reference.append_array(moving)
			reference.sort_custom(wetland._scenery_before)
			check(wetland._render_items == reference, "Optimized scenery list matches complete reference sort")
	var panel := PanelContainer.new()
	panel.size = Vector2(122, 165)
	var style := StyleBoxFlat.new()
	style.set_meta("card_outline", true)
	style.border_color = Color.GOLD
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var face := TextureRect.new()
	face.texture = preload("res://assets/art/artist-test-card-blank.png")
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(face)
	panel.set_meta("pixel_face", face)
	var outline := Node2D.new()
	outline.set_script(preload("res://scripts/card_outline.gd"))
	panel.add_child(outline)
	outline.draw.connect(func(): outline_draws += 1)
	await get_tree().process_frame
	await get_tree().process_frame
	outline_draws = 0
	for i in 30: await get_tree().process_frame
	print("RUNTIME_IDLE outline_draws30=", outline_draws)
	check(outline_draws <= 1, "Unchanged outline retains its draw commands")
	# An unchanged target must not resurrect a sleeping spring. External writers
	# and new targets still wake it, preserving interrupted interactions.
	var spring = Spring.to(panel, "rotation", panel.rotation)
	spring.finish()
	started = Time.get_ticks_usec()
	var awake := 0
	for i in 10000:
		Spring.to(panel, "rotation", 0.0)
		if spring.is_processing():
			awake += 1
			spring._process(1.0 / 60.0)
	print("RUNTIME_CPU spring10000_us=", Time.get_ticks_usec() - started, " idle_wakeups=", awake)
	check(awake == 0, "Repeated resting targets never wake springs")
	panel.rotation = 0.1
	Spring.to(panel, "rotation", 0.0)
	check(spring.is_processing(), "External pose changes wake an unchanged target")
	spring.finish()
	Spring.to(panel, "rotation", 0.2)
	check(spring.is_processing(), "New targets wake settled springs")
	for i in 200: spring._process(1.0 / 60.0)
	check(is_equal_approx(panel.rotation, 0.2) and not spring.is_processing(), "Animation reaches the same exact resting pose")
	Spring.to(panel, "rotation", 0.4)
	spring._process(1.0 / 60.0)
	var velocity: float = spring.velocity
	var pose := panel.rotation
	Spring.to(panel, "rotation", -0.2)
	check(spring.velocity == velocity and panel.rotation == pose, "Retarget retains momentum and pose")
	spring.finish()
	style.border_color = Color.WHITE
	await get_tree().process_frame
	await get_tree().process_frame
	check(outline_draws > 0, "Outline recoloring invalidates the cached commands")
	var before := outline_draws
	face.size += Vector2(3, 2)
	outline._process(0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(outline_draws > before, "Face resize invalidates the contour")
	# Match the former world-to-local contour exactly while the card travels
	# through arbitrary rotation, scale and parent transforms.
	for angle in [-0.3, 0.0, 0.4]:
		panel.rotation = angle
		panel.scale = Vector2(1.08, 0.93)
		panel.position = Vector2(80, 110)
		outline._process(0.0)
		var face_rect := Geometry.face_rect(face)
		var max_error := 0.0
		for i in outline.contour.size():
			var expected: Vector2 = outline.to_local(face.get_global_transform() * (face_rect.position + outline.contour[i] * face_rect.size))
			max_error = maxf(max_error, expected.distance_to(outline._points[i]))
		check(max_error < 0.001, "Cached contour exactly matches transformed original geometry")
	var builds: int = outline.geometry_builds
	for i in 60:
		panel.position += Vector2(2, 1)
		panel.rotation += 0.01
		outline._process(0.0)
	check(outline.geometry_builds == builds, "Card movement does not rebuild local contour geometry")
	style.set_meta("card_outline", false)
	outline._process(0.0)
	check(not outline._enabled, "Deselection removes the cached outline immediately")
	style.set_meta("card_outline", true)
	outline._process(0.0)
	check(outline._enabled, "Reselection restores the cached outline immediately")
	# Verify cached forecasts against the original computation across every
	# difficulty, season, water extreme, used-action change and warning change.
	for difficulty in 4:
		GameState.difficulty = difficulty
		for turn in [1, 2, 3, 4, 5, 16]:
			GameState.turn = turn
			GameState.run_seed = 20261009 + turn
			for value in [0, 41, 44, 71, 100]:
				for metric in GameState.metrics: GameState.metrics[metric] = value
				GameState.used_action_ids = ["research", "patrol"] if value % 2 else []
				GameState.pending_crisis = {"name": "cache probe", "effects": [{"metric": "birds", "delta": -8}]} if value < 50 else {}
				for metric in GameState.METRIC_NAMES:
					var expected: Dictionary = GameState._compute_metric_hover_preview(metric)
					check(GameState.metric_hover_preview(metric) == expected, "Forecast cache matches all simulation inputs")
	var forecast: Dictionary = GameState.metric_hover_preview("birds")
	forecast["conflict"]["penalty"] = 999
	check(GameState.metric_hover_preview("birds") == GameState._compute_metric_hover_preview("birds"), "Callers cannot corrupt nested cached results")
	seed(321)
	var expected_random := randi()
	seed(321)
	GameState.metric_hover_preview("birds")
	check(randi() == expected_random, "Cached forecast does not consume gameplay RNG")
	started = Time.get_ticks_usec()
	for i in 1000: GameState._compute_metric_hover_preview("birds")
	var uncached_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for i in 1000: GameState.metric_hover_preview("birds")
	print("RUNTIME_CPU preview1000_uncached_us=", uncached_us, " cached_us=", Time.get_ticks_usec() - started)
	print("RUNTIME_PERFORMANCE: %d checks, %d failures" % [checks, failures])
	panel.queue_free()
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)
