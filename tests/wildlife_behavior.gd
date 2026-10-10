extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	GameState.reset_game()
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(1.0).timeout
	var game: Node = scene.get_node("Game")
	if game._intro_playing: game._finish_intro()
	game._playing = true
	game._hide_menu()
	game.popup_root.hide()
	game.crisis_root.hide()
	game._current_phase = "allocate"
	game._enter_allocate()
	await get_tree().create_timer(1.0).timeout
	game.set_process(false)
	var w: Control = game.wetland
	w.set_process(false)
	for bird in w.bird_agents:
		check(w._bird_boat_space(bird.pos).length_squared() >= 1.0, "Bird homes avoid the boat")
	var before: Dictionary = GameState.serialize().duplicate(true)
	for axis in [Vector2.RIGHT, Vector2.DOWN]:
		var a: Vector2 = w._bird_boat_uv(-axis * 1.4)
		var b: Vector2 = w._bird_boat_uv(axis * 1.4)
		check(w._is_water(a) and w._is_water(b), "Detour starts and ends on lake water")
		check(not w._bird_water_segment_clear(a, b), "Direct route across boat is blocked")
		var path: Array = w._bird_water_route(a, b)
		print("ROUTE ", axis, " points=", path.size())
		check(path.size() > 2, "A route goes around the boat")
		var previous := a
		for point in path:
			check(w._bird_water_segment_clear(previous, point), "Every detour segment stays on water outside the boat")
			previous = point
		var bird: Dictionary = w.bird_agents[0]
		bird.pos = a
		bird.target = b
		bird.state = 2
		bird.timer = 1000.0
		bird.erase("route_target")
		for i in 1200:
			w._process_birds(1.0 / 30.0)
			if w._bird_boat_space(bird.pos).length_squared() < 0.999:
				check(false, "Walking bird never penetrates boat")
				break
			if bird.pos.distance_to(b) < 0.001: break
		check(bird.pos.distance_to(b) < 0.001, "Walking detour reaches its destination")

	var hunter: Dictionary = w.bird_agents[0]
	hunter.pos = w._bird_boat_uv(Vector2.LEFT * 1.4)
	hunter.state = 0
	hunter.erase("route_target")
	var food: Vector2 = w._bird_boat_uv(Vector2.RIGHT * 1.4)
	w.interests.clear()
	w.interests.append({"pos": food, "age": 0.0, "caught": false})
	for i in 2400:
		w._follow_interest(hunter, 1.0 / 60.0)
		if w._bird_boat_space(hunter.pos).length_squared() < 0.999:
			check(false, "Following lake clicks never penetrates boat")
			break
		if w.interests[0].caught: break
	check(w.interests[0].caught, "Bird also detours around boat while following a lake click")
	w.interests.clear()
	var trees: Array = w.plant_sites.chishan
	for season in 4:
		w.season = season
		w.previous_season = season
		check(w._tree_perch_height(trees[0]) > 18.0, "Perch matches canopy height in every season")
		for sid in w.SPECIES_ART:
			var bird := {"sid": sid, "slot": 0, "pos": trees[0], "target": trees[0], "home": trees[0], "state": 4}
			check(w._bird_animation_frame(bird) == 13, "Resting bird does not show feet-down landing frame")
			check(is_equal_approx(w._bird_height(bird), w._tree_perch_height(trees[0])), "Resting body anchors on canopy")
	check(GameState.serialize() == before, "Wildlife motion cannot alter game state")
	w.season = 0
	w.previous_season = 0
	for i in 5:
		var bird: Dictionary = w.bird_agents[i * 10]
		bird.pos = trees[i]
		bird.target = trees[i]
		bird.state = 4
	w.get_node("Wildlife").queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("POYANG_SCREENSHOT_DIR").path_join("bird-canopy.png"))

	# Enlarge the exact runtime drawing to inspect canopy alignment and cropped legs.
	var detail_layer := CanvasLayer.new()
	detail_layer.layer = 50
	add_child(detail_layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color("354e45")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_layer.add_child(backdrop)
	var uv: Vector2 = trees[0]
	var point: Vector2 = w._wildlife_point(uv)
	var index := 0
	for sid in w.SPECIES_ART:
		var actor := {"sid": sid, "slot": 0, "pos": uv, "target": uv, "home": uv, "state": 4}
		var canvas := Control.new()
		canvas.size = Vector2(1280, 720)
		canvas.scale = Vector2.ONE * 4.0
		canvas.position = Vector2(150 + index * 230, 450) - point * 4.0
		detail_layer.add_child(canvas)
		canvas.draw.connect(func():
			w._draw_tree(canvas, point, 1.0, uv)
			w._draw_bird_actor(canvas, actor))
		index += 1
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("POYANG_SCREENSHOT_DIR").path_join("bird-canopy-detail.png"))
	print("WILDLIFE_BEHAVIOR checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
