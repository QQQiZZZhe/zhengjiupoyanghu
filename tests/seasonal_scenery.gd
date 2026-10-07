extends Node
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
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
	await get_tree().create_timer(1.4).timeout
	var wetland: Control = game.wetland
	var state: Dictionary = wetland.capture_state()
	var before: Dictionary = GameState.metrics.duplicate()
	check(wetland.summer_flowers.size() > 30, "Summer must have many flower patches")
	check(wetland.snow_sites.size() > 100, "Winter must have scattered land snow")
	for uv in wetland.summer_flowers:
		check(wetland._is_exterior_land(uv), "Flowers must stay on exterior land")
	var winter_tree: Image = wetland.seasonal_trees[3].get_image()
	var snow_pixels := 0
	for y in winter_tree.get_height():
		for x in winter_tree.get_width():
			var col := winter_tree.get_pixel(x, y)
			if col.a > 0.5 and col.r > 0.9 and col.g > 0.9: snow_pixels += 1
	check(snow_pixels > 15, "Winter tree must have a visible white snow cap")
	print("TREE_SNOW_PIXELS: ", snow_pixels)
	winter_tree.save_png(OS.get_environment("POYANG_SCREENSHOT_DIR").path_join("winter-tree.png"))
	var images: Array[Image] = []
	for season in 4:
		state["season"] = season
		seed(321)
		var expected := randi()
		seed(321)
		wetland.sync_state(state, false)
		check(randi() == expected, "Season scenery must preserve gameplay RNG")
		check(int(wetland.ground_material.get_shader_parameter("season")) == season, "Ground must follow season")
		check(wetland.water_material.get_shader_parameter("season_tint") == Color.WHITE, "Water must have no seasonal tint")
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		images.append(wetland.terrain_viewport.get_texture().get_image())
		var folder := OS.get_environment("POYANG_SCREENSHOT_DIR")
		if not folder.is_empty(): get_viewport().get_texture().get_image().save_png(folder.path_join("season-%d.png" % season))
	check(GameState.metrics == before, "Scenery must not alter ecology")
	# Blue water pixels at a distance from boundaries must match in all four seasons.
	var count := 0
	for y in range(4, images[0].get_height() - 4, 12):
		for x in range(4, images[0].get_width() - 4, 12):
			var col := images[0].get_pixel(x, y)
			if col.b > col.g + 0.02 and col.g > col.r + 0.06:
				count += 1
				for i in range(1, 4): check(col.is_equal_approx(images[i].get_pixel(x, y)), "Lake water pixels must remain identical")
	check(count > 50, "Water comparison must cover lake")
	check(images[0].get_data() != images[2].get_data(), "Autumn ground must visibly change")
	check(images[0].get_data() != images[3].get_data(), "Winter ground must visibly change")
	# Exercise the actual return-to-menu path and sample ground beyond artwork.
	# This catches a seasonal center surrounded by the old fixed green background.
	wetland.creeper_mesh.hide()
	for season in 4:
		GameState.turn = season + 1
		wetland.sync_state({}, false)
		game._on_pause_exit()
		await get_tree().create_timer(1.3).timeout
		wetland.creeper_mesh.hide()
		check(wetland.season == season, "Returning to menu must retain the current season")
		for window_size in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1920, 720), Vector2i(960, 900)]:
			get_window().size = window_size
			await get_tree().create_timer(0.1).timeout
			for zoom in [wetland.GAME_CAMERA_ZOOM, game.MENU_CAM_ZOOM]:
				wetland._set_camera_zoom(zoom)
				await RenderingServer.frame_post_draw
				var terrain: Image = wetland.terrain_viewport.get_texture().get_image()
				var screen_to_map: Transform2D = wetland._screen_projection.affine_inverse()
				var half_extent: Vector2 = wetland.ground_plane.size * 0.5
				for corner in [Vector2.ZERO, Vector2(wetland.size.x, 0), wetland.size, Vector2(0, wetland.size.y)]:
					var uv: Vector2 = screen_to_map * corner
					var position: Vector3 = wetland._ground_position(uv)
					check(absf(position.x) < half_extent.x and absf(position.z) < half_extent.y, "Seasonal ground must cover every camera corner")
				var margins := 0
				for y in range(8, terrain.get_height() - 8, 37):
					for x in range(8, terrain.get_width() - 8, 37):
						var uv: Vector2 = screen_to_map * Vector2(x, y)
						if uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0: continue
						if not wetland._is_exterior_land(uv) or wetland._season_near_water(uv, 0.03): continue
						margins += 1
						check(_matches_season(terrain.get_pixel(x, y), season), "Visible outer meadow must match season %d" % season)
				if zoom == game.MENU_CAM_ZOOM:
					check(margins > 20, "Menu camera test must sample the outer meadow")
					# Isolate the artwork boundary palette from real slopes, whose
					# lighting can legitimately differ between nearby map positions.
					wetland.ground_material.set_shader_parameter("terrain_relief", false)
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
					var flat_terrain: Image = wetland.terrain_viewport.get_texture().get_image()
					for pair in [[Vector2(-0.005, 0.6), Vector2(0.005, 0.6)], [Vector2(0.995, 0.6), Vector2(1.005, 0.6)]]:
						var outside: Vector2 = (wetland._screen_projection * pair[0]).round()
						var inside: Vector2 = (wetland._screen_projection * pair[1]).round()
						var bounds := Rect2(Vector2.ZERO, Vector2(terrain.get_size()))
						if not bounds.has_point(outside) or not bounds.has_point(inside): continue
						var delta: Color = flat_terrain.get_pixelv(Vector2i(outside)) - flat_terrain.get_pixelv(Vector2i(inside))
						var tolerance := 0.12 if season == 3 else 0.015
						check(absf(delta.r) < tolerance and absf(delta.g) < tolerance and absf(delta.b) < tolerance, "Meadow palette must be continuous across the artwork boundary")
					wetland.ground_material.set_shader_parameter("terrain_relief", true)
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
				var clearing_point: Vector2 = wetland._point(wetland.CREEPER_ANCHOR + Vector2(-0.07, 0.05))
				if Rect2(Vector2.ZERO, Vector2(terrain.get_size())).has_point(clearing_point):
					check(_matches_season(terrain.get_pixelv(Vector2i(clearing_point)), season), "Easter egg clearing must also follow the season")
				if window_size == Vector2i(1280, 720) and zoom == game.MENU_CAM_ZOOM:
					wetland.creeper_mesh.show()
					await get_tree().create_timer(0.1).timeout
					await RenderingServer.frame_post_draw
					var with_creeper: Image = wetland.terrain_viewport.get_texture().get_image()
					var visible_pixels := 0
					for y in terrain.get_height():
						for x in terrain.get_width():
							if not terrain.get_pixel(x, y).is_equal_approx(with_creeper.get_pixel(x, y)): visible_pixels += 1
					check(visible_pixels > 100, "Seasonal ground must leave the easter egg visible")
					var folder := OS.get_environment("POYANG_SCREENSHOT_DIR")
					if not folder.is_empty(): get_viewport().get_texture().get_image().save_png(folder.path_join("menu-season-%d.png" % season))
					wetland.creeper_mesh.hide()
	check(GameState.metrics == before, "Menu scenery must preserve ecology")
	print("SEASONAL_SCENERY: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)

func _matches_season(color: Color, season: int) -> bool:
	if season == 2: return color.r > color.g and color.g > color.b
	if season == 3: return color.r > 0.85 and color.g > 0.85 and color.b > 0.85
	return color.g > color.r and color.r > color.b
