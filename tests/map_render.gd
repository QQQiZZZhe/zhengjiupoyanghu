extends Node
var failures: Array[String] = []
var checks := 0
var game: Node
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")
var baseline := OS.get_environment("POYANG_MAP_BASELINE") == "1"

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle(seconds: float = 0.2) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(name: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(name + ".png"))

func verify_river_water_and_relief() -> void:
	var wetland: Control = game.wetland
	var mesh_nodes: Array[MeshInstance3D] = []
	for node in wetland.terrain_viewport.get_child(0).get_children():
		if node is MeshInstance3D and node.material_override in wetland.river_water_materials:
			mesh_nodes.append(node)
	await RenderingServer.frame_post_draw
	var joined: Image = wetland.terrain_viewport.get_texture().get_image()
	for node in mesh_nodes: node.hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var lake_only: Image = wetland.terrain_viewport.get_texture().get_image()
	var samples := 0
	for y in 96:
		for x in 96:
			var uv := Vector2(x + 0.5, y + 0.5) / 96.0
			var color: Color = wetland._terrain_color(uv)
			if not (color.b > color.g and color.g > color.r): continue
			var rivers: Vector2 = wetland._river_distances_squared(uv)
			if rivers.x > pow(wetland.YANGTZE_HALF_WIDTH - 0.006, 2) and rivers.y > pow(wetland.GAN_HALF_WIDTH - 0.003, 2): continue
			var pixel := Vector2i(wetland._point(uv))
			if pixel.x < 0 or pixel.y < 0 or pixel.x >= joined.get_width() or pixel.y >= joined.get_height(): continue
			var a := joined.get_pixelv(pixel)
			var b := lake_only.get_pixelv(pixel)
			# Screen rounding can select a neighboring sand texel at jagged banks.
			if not (b.b > b.g and b.g > b.r): continue
			check(maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) < 0.015, "Confluence river surfaces must match the underlying lake water palette")
			samples += 1
	for node in mesh_nodes: node.show()
	check(samples > 20, "Confluence test must sample both river and lake coverage")
	for offset in [Vector2.ZERO, Vector2(0.04, 0), Vector2(-0.04, 0), Vector2(0, 0.04)]:
		check(wetland._relief_at(wetland.CREEPER_ANCHOR + offset) < 0.001, "Easter egg clearing must remain flat")
	var highest := 0.0
	for y in 20:
		for x in 20:
			var height: float = wetland._relief_at(Vector2(x, y) / 20.0)
			highest = maxf(highest, height)
			check(height >= 0.0 and height < 2.1, "Land relief must remain gentle")
	check(highest > 1.0, "Outer land must have visible relief")
	# WGS84 locations projected with the checked hydrography bounds: Lushan
	# southwest of Hukou must rise above the Nanchang alluvial plain.
	check(wetland._relief_at(Vector2(0.289735, 0.248175)) > 1.0, "Lushan's real mountain location must have relief")
	check(wetland._relief_at(Vector2(0.239410, 0.868613)) < 0.3, "Nanchang's alluvial plain must stay low")
	var dem: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/geography/poyang-elevation.json"))
	check(dem["units"] == "meters" and dem["tile_urls"].size() > 0, "Relief must use the recorded public DEM")
	# Sample both the former shallow stripes and their neighboring river core.
	var reference := Color.TRANSPARENT
	for route in [wetland.yangtze_route, wetland.gan_route]:
		for i in range(2, route.size() - 2, 3):
			var tangent: Vector2 = (route[i + 1] - route[i - 1]).normalized()
			for side in [-0.004, 0.0, 0.004]:
				var uv: Vector2 = route[i] + Vector2(-tangent.y, tangent.x) * side
				var point := Vector2i(wetland._point(uv))
				if not Rect2i(Vector2i.ZERO, joined.get_size()).has_point(point): continue
				var pixel := joined.get_pixelv(point)
				if reference.a == 0.0: reference = pixel
				check(pixel.is_equal_approx(reference), "River surface must contain no pale-blue shallow stripes")
	print("RIVER_LAKE_MATCH: %d water samples" % samples)

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle()
	if game._intro_playing: game._finish_intro()
	GameState.run_seed = 20261004
	GameState.difficulty = 0
	GameState.reset_game()
	game._hide_menu()
	game.popup_root.hide()
	game._set_hud_visible(false)
	game.wetland.camera_tween.kill()
	game.wetland.reduced_motion = true
	for metric in GameState.metrics: GameState.metrics[metric] = 65
	GameState.metrics.water_level = 50
	GameState.settlement = 60
	for pid in GameState.plant_pop: GameState.plant_pop[pid] = 60
	game.wetland.sync_state({}, false)
	await settle()
	for i in game.wetland.house_progress.size(): game.wetland.house_progress[i] = 1.0 if i < game.wetland.house_target_count else 0.0
	game.wetland._set_camera_zoom(0.9)
	await settle()
	await capture("01-normal-map")
	if not baseline: await verify_river_water_and_relief()
	var saved: Dictionary = GameState.serialize()
	if not baseline:
		for ship in 10:
			for time in range(0, 240, 12):
				var sample: Dictionary = game.wetland._yangtze_boat_sample(ship, float(time))
				var next: Dictionary = game.wetland._yangtze_boat_sample(ship, float(time + 1))
				check(game.wetland._near_route(sample["pos"], game.wetland.yangtze_route, game.wetland.YANGTZE_HALF_WIDTH - 0.008), "River boats must leave room between their lane and the shore")
				var movement: float = game.wetland._point(sample["pos"]).distance_to(game.wetland._point(next["pos"]))
				check(movement < 5.0, "River boats must move gently without sudden jumps")
				var direction: Vector2 = (game.wetland._point(sample["pos"] + sample["direction"] * 0.01) - game.wetland._point(sample["pos"])).normalized()
				var mirror: float = -sample["heading"]
				var forward := Vector2(game.wetland.FISHING_BOAT_FORWARD.x * mirror, game.wetland.FISHING_BOAT_FORWARD.y).rotated(game.wetland._river_boat_rotation(direction, mirror)).normalized()
				check(forward.dot(direction) > 0.999, "Boat bow must face along its projected sailing direction")
				check(sample["heading"] == (1.0 if ship % 2 == 0 else -1.0), "Opposite river lanes must retain their travel direction")
		check(game.wetland.get_node_or_null("GroundShadows") != null, "Contact shadows must be on an independent ground layer")
		var units: Array = game.wetland._scenery_draw_order()
		var last_y := -INF
		for unit in units:
			var y: float = game.wetland._shadow_point(unit["uv"]).y
			check(y >= last_y - 0.001, "Scenery draw order does not follow camera depth")
			last_y = y
		seed(773)
		var expected := randi()
		seed(773)
		game.wetland._scenery_draw_order()
		game.wetland._contact_shadow_specs()
		check(randi() == expected, "Render planning consumed gameplay RNG")
	for window_size in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1600,900)]:
		get_window().size = window_size
		await settle()
		for zoom in [0.9, 1.0, 1.3]:
			game.wetland._set_camera_zoom(zoom)
			await settle(0.1)
			var layer: Control = game.wetland.get_node("Wildlife")
			for uv in [Vector2(0.3,0.4), Vector2(0.55,0.6), Vector2(0.7,0.8)]:
				check((layer.get_transform() * game.wetland._wildlife_point(uv)).distance_to(game.wetland._point(uv)) <= 1.5, "Billboard drifted from 3D ground anchor")
			if not baseline:
				var radius := 30.0
				var polygon: PackedVector2Array = game.wetland._shadow_polygon(Vector2(0.5,0.5), game.wetland._px_to_uv(radius))
				check(absf((polygon[0] - polygon[20]).length() - radius * 2.0) < 0.02, "Shadow width changed due to rounded projection")
				check(game.wetland.get_node("GroundShadows").get_transform().is_equal_approx(layer.get_transform()), "Shadow and scenery zoom transforms differ")
	await capture("02-wide-map")
	get_window().size = Vector2i(1280,720)
	game.wetland._set_camera_zoom(0.9)
	for water_level in [20, 85]:
		GameState.metrics.water_level = water_level
		game.wetland.sync_state({}, false)
		await settle()
		await capture("03-dry-map" if water_level == 20 else "04-high-water-map")
	if not baseline:
		# Pixel sampling around both rivers checks CPU habitat classification against GPU.
		GameState.metrics.water_level = 50
		game.wetland.sync_state({}, false)
		await settle()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var terrain: Image = game.wetland.terrain_viewport.get_texture().get_image()
			for uv in [Vector2(0.4184458,0.1112966), Vector2(0.326131,0.4793997), Vector2(0.3412264,0.4328778)]:
				var point: Vector2 = game.wetland._point(uv)
				var color := terrain.get_pixelv(Vector2i(point))
				check(game.wetland._is_water(uv) and color.b > color.g and color.g > color.r, "CPU water mask disagrees with rendered river junction")
			# Suppress scenery to test shadow clipping directly against the same terrain texture.
			game.wetland.get_node("Wildlife").hide()
			# Airborne seasonal particles move independently of contact shadows.
			var weather: Control = game.wetland.get_node_or_null("SeasonWeather")
			if weather: weather.hide()
			await settle()
			await RenderingServer.frame_post_draw
			var with_shadows: Image = get_viewport().get_texture().get_image()
			game.wetland.get_node("GroundShadows").hide()
			await settle()
			await RenderingServer.frame_post_draw
			var without_shadows: Image = get_viewport().get_texture().get_image()
			var water_samples := 0
			var polluted := 0
			for y in range(0,terrain.get_height(),3):
				for x in range(0,terrain.get_width(),3):
					var color := terrain.get_pixel(x,y)
					if color.b > color.g + 0.02 and color.g > color.r + 0.02:
						water_samples += 1
						if with_shadows.get_pixel(x,y) != without_shadows.get_pixel(x,y): polluted += 1
			check(water_samples > 100 and polluted == 0, "Contact shadows darkened river/lake pixels")
			print("WATER_SHADOW_CLIP: ", water_samples, " water samples, ", polluted, " altered")
			game.wetland.get_node("GroundShadows").show()
			game.wetland.get_node("Wildlife").show()
			if weather: weather.show()
	check(GameState.metrics.water_level in [50,85], "Rendering mutated gameplay state")
	GameState.load_state(saved)
	print("MAP_RENDER: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks, ", failures.size(), " failures)")
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
