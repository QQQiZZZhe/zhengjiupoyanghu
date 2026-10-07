extends Node
var checks := 0
var failures := 0
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func rendered(wetland: Control) -> Image:
	wetland._redraw_scenery()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return wetland.terrain_viewport.get_texture().get_image()

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	GameState.turn = 0
	check(GameState.current_season() == "spring", "Unstarted game must default to spring")
	for turn in range(1, 17):
		GameState.turn = turn
		check(GameState.current_season() == GameState.SEASONS[(turn - 1) % 4], "Playable turns must retain the four-season order")
	GameState.turn = 0
	var startup_scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(startup_scene)
	var startup_game: Node = startup_scene.get_node("Game")
	check(startup_game.wetland.season == 0, "Fresh launch title scenery must be spring")
	startup_game.bgm_player.stop()
	startup_game.bgm_player.stream = null
	startup_scene.queue_free()
	await get_tree().process_frame
	GameState.reset_game()
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(0.3).timeout
	var game: Node = scene.get_node("Game")
	if game._intro_playing: game._finish_intro()
	var wetland: Control = game.wetland
	# Main normally restores wetland processing from its pause state every frame.
	# Freeze both here so each captured frame advances by an exact visual step.
	game.set_process(false)
	if wetland.camera_tween: wetland.camera_tween.kill()
	wetland._set_camera_zoom(game.MENU_CAM_ZOOM)
	wetland.set_process(false)
	wetland.reduced_motion = false
	wetland.creeper_mesh.show()
	var state: Dictionary = wetland.capture_state()
	var original: Dictionary = GameState.serialize()
	var frame_index := 0
	var old_season := 3
	for next_season in [0, 1, 2, 3]:
		state["season"] = next_season
		wetland.sync_state(state, false)
		var target_image: Image = await rendered(wetland)
		state["season"] = old_season
		wetland.sync_state(state, false)
		var old_image: Image = await rendered(wetland)
		state["season"] = next_season
		seed(91234)
		var expected := randi()
		seed(91234)
		wetland.sync_state(state, true)
		check(randi() == expected, "Season animation must preserve gameplay RNG")
		check(wetland.previous_season == old_season and wetland.season_progress == 0.0, "Season change must start from the previous scenery")
		for step in 13:
			if step > 0:
				wetland._advance_season(wetland.SEASON_CHANGE_DURATION / 12.0)
				wetland.elapsed += wetland.SEASON_CHANGE_DURATION / 12.0
			var current: Image = await rendered(wetland)
			if step == 0: check(current.get_data() == old_image.get_data(), "First frame must retain the previous ground")
			if step == 6:
				var top := Vector2i(wetland.size * Vector2(0.90, 0.18))
				var bottom := Vector2i(wetland.size * Vector2(0.90, 0.84))
				check(current.get_pixelv(top).is_equal_approx(target_image.get_pixelv(top)), "Sweep must recolor the top first")
				check(current.get_pixelv(bottom).is_equal_approx(old_image.get_pixelv(bottom)), "Sweep must leave the bottom in the old season until it arrives")
				var progress: float = wetland.season_progress
				wetland.sync_state(state, true)
				check(wetland.season_progress == progress, "Repeated state updates must not restart the sweep")
			if step == 12: check(current.get_data() == target_image.get_data(), "Completed sweep must match the final seasonal ground")
			seed(76543)
			var expected_particle_rng := randi()
			seed(76543)
			var particles: Array = wetland._season_particle_specs()
			check(randi() == expected_particle_rng, "Weather must preserve gameplay RNG")
			check(particles.size() <= wetland.MAX_WEATHER_PARTICLES, "Weather particle budget must remain bounded")
			var exclusion: Rect2 = wetland._creeper_weather_exclusion()
			for particle in particles: check(not exclusion.has_point(particle["point"]), "Weather must not cover the easter egg")
			if not output_dir.is_empty():
				get_viewport().get_texture().get_image().save_png(output_dir.path_join("cycle-%02d.png" % frame_index))
			frame_index += 1
		check(wetland.season_progress > 0.999, "Season transition must finish")
		var expected_weather := "snow" if next_season == 3 else ("leaf" if next_season == 2 else "petal")
		var weather_count := 0
		for particle in wetland._season_particle_specs():
			if particle["kind"] == expected_weather: weather_count += 1
		check(weather_count > 15, "Season must have visible matching weather")
		if next_season == 1:
			var flower: Vector2 = wetland.summer_flowers[0]
			check(wetland._flower_amount_at(flower) == 1.0, "Summer flowers must finish blooming")
		if next_season in [2, 3]:
			for flower in wetland.summer_flowers: check(wetland._flower_amount_at(flower) == 0.0, "Autumn and winter must close summer flowers")
		old_season = next_season
	state["season"] = 0
	wetland.sync_state(state, true)
	wetland._advance_season(0.25)
	var halfway: float = wetland.season_progress
	game._show_menu()
	check(wetland.season_progress == halfway, "Returning to menu must preserve the ongoing sweep")
	if wetland.camera_tween: wetland.camera_tween.kill()
	get_window().size = Vector2i(960, 900)
	await get_tree().create_timer(0.1).timeout
	check(wetland.season_progress == halfway, "Resizing must preserve the ongoing sweep")
	wetland.reduced_motion = true
	wetland._advance_season(0.01)
	check(wetland.season_progress == 1.0, "Reducing motion mid-sweep must finish immediately")
	check(wetland._season_particle_specs().is_empty(), "Reduced motion must suppress weather particles")
	state["season"] = 1
	wetland.sync_state(state, true)
	check(wetland.season_progress == 1.0, "Reduced motion must skip new sweeps")
	check(wetland._flower_amount_at(wetland.summer_flowers[0]) == 1.0, "Reduced motion must retain static flowers")
	check(GameState.serialize() == original, "Season animations must not change gameplay state")
	print("SEASONAL_ANIMATION: %d checks, %d failures" % [checks, failures])
	game.bgm_player.stop()
	game.bgm_player.stream = null
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)
