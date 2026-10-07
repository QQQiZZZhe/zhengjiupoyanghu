extends Node

var failures := 0
var checks := 0
var wetland: Control
var showcase: Control

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func leaf_count(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var col := image.get_pixel(x, y)
			if col.a > 0.5 and col.g > col.r + 0.05 and col.g > col.b + 0.05: count += 1
	return count

func gold_count(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var col := image.get_pixel(x, y)
			if col.a > 0.5 and col.r > 0.5 and col.r > col.g + 0.04 and col.g > col.b + 0.08: count += 1
	return count

func snow_count(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var col := image.get_pixel(x, y)
			if col.a > 0.5 and col.r > 0.9 and col.g > 0.9: count += 1
	return count

func draw_showcase() -> void:
	showcase.draw_rect(Rect2(0, 0, 660, 170), Color("44565c"))
	var uv := Vector2(0.5, 0.5)
	wetland._draw_tree(showcase, Vector2(95, 150), 3.0, uv)
	wetland._draw_plant(showcase, Vector2(310, 150), "chishan", 3.0, uv)
	var amount: float = wetland._tree_season_blend(uv)
	var rect := Rect2(510, 42, 77, 98)
	showcase.draw_texture_rect(wetland.pine_seasons[wetland.previous_season], rect, false)
	showcase.draw_texture_rect(wetland.pine_seasons[wetland.season], rect, false, Color(1, 1, 1, amount))

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	GameState.reset_game()
	var original: Dictionary = GameState.serialize()
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(0.5).timeout
	var game: Node = scene.get_node("Game")
	if game._intro_playing: game._finish_intro()
	game.set_process(false)
	wetland = game.wetland
	wetland.set_process(false)
	if wetland.camera_tween: wetland.camera_tween.kill()
	wetland._set_camera_zoom(game.MENU_CAM_ZOOM)
	showcase = Control.new()
	showcase.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	showcase.position = Vector2(600, 400)
	showcase.draw.connect(draw_showcase)
	add_child(showcase)
	var last := -1
	for stage in 17:
		var count := leaf_count(wetland.tree_frames[0][stage].get_image())
		check(count >= last, "Spring leaf clusters must grow monotonically")
		last = count
	var gold := gold_count(wetland.seasonal_trees[2].get_image())
	check(gold > 700, "Autumn crown must become golden")
	for stage in 17:
		var count := gold_count(wetland.tree_frames[3][stage].get_image())
		check(count <= gold, "Winter gold leaf clusters must shed monotonically")
		gold = count
	check(gold == 0, "Winter must shed all autumn leaves")
	check(last > 700, "Summer-sized spring crown must retain original leaves")
	check(leaf_count(wetland.seasonal_trees[3].get_image()) == 0, "Winter deciduous trees must have no green leaves")
	check(snow_count(wetland.seasonal_trees[3].get_image()) > 15, "Bare winter branches must collect snow")
	check(snow_count(wetland.pine_seasons[3].get_image()) > 15, "Evergreen needles must collect snow")
	check(leaf_count(wetland.pine_seasons[3].get_image()) > 10, "Pines must retain winter needles")
	var folder := OS.get_environment("POYANG_SCREENSHOT_DIR")
	var state: Dictionary = wetland.capture_state()
	for target in [2, 3, 0, 1]:
		wetland.sync_state(state, false)
		state["season"] = target
		wetland.sync_state(state, true)
		for frame in 25:
			wetland._advance_season(0.14)
			wetland._redraw_scenery()
			showcase.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(folder.path_join("trees-%d-%02d.png" % [target, frame]))
		check(is_equal_approx(wetland._tree_season_blend(Vector2(0.5, 0.5)), 1.0), "Tree transition must finish")
	check(GameState.serialize() == original, "Tree presentation must preserve gameplay")
	wetland.reduced_motion = true
	wetland.tree_season_age = 0.0
	check(wetland._tree_season_blend(Vector2(0.5, 0.5)) == 1.0, "Reduced motion must immediately show final trees")
	game.bgm_player.stop()
	game.bgm_player.stream = null
	scene.queue_free()
	await get_tree().process_frame
	print("TREE_SEASONS: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
