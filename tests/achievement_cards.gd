extends Node
var game: Node
var checks := 0
var failures: Array[String] = []
var notifications: Array[String] = []
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle(seconds: float = 0.3) -> void:
	await get_tree().create_timer(seconds).timeout

func row_for(id: String) -> Control:
	for row in game.ach_rows_col.get_children():
		if row.get_meta("achievement_id", "") == id:
			return row
	return null

func capture(name: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(name + ".png"))

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	await settle(0.1)
	Knowledge.reset_all()
	Achievements.reset_all()
	Achievements.achievement_unlocked.connect(func(id: String): notifications.append(id))
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle(0.4)
	if game._intro_playing:
		game._finish_intro()
	await settle(1.0)
	game._show_achievements_panel()
	await settle(0.4)
	check(Achievements.LIST.size() == 5, "Five achievements are defined")
	check(row_for("rigged") == null, "Locked hidden achievement has no row")
	check(game.ach_rows_col.get_child_count() == 4, "Only four achievements are initially visible")
	check(game.ach_count_label.text == "已解锁 0 / 4", "Hidden achievement does not leak through the total")
	check(row_for("ecology_expert") != null, "Ecology expert is visible before unlocking")
	await capture("achievements-hidden-locked")
	Achievements.try_unlock("rigged")
	await settle(0.3)
	var rigged := row_for("rigged")
	check(rigged != null, "Hidden achievement appears immediately after unlocking")
	check(game.ach_rows_col.get_child_count() == 5, "Unlocking reveals one extra row")
	check(game.ach_count_label.text == "已解锁 1 / 5", "Unlocked hidden achievement joins the total")
	if rigged != null:
		var title: Label = rigged.get_child(1).get_child(0)
		check(title.get_theme_color("font_color").is_equal_approx(Color(1, 0.88, 0.55)), "Unlocked hidden achievement title is gold")
		if DisplayServer.get_name() != "headless":
			var icon: TextureRect = rigged.get_child(0)
			var image: Image = icon.texture.get_image()
			var gold := false
			for y in image.get_height():
				for x in image.get_width():
					var color := image.get_pixel(x, y)
					gold = gold or (color.a > 0.5 and color.r > color.b + 0.2 and color.g > color.b + 0.1)
			check(gold, "Unlocked hidden achievement icon is gold")
	var ids := Knowledge.all_ids()
	for i in range(ids.size() - 1):
		Knowledge.unlock(ids[i])
		check(not Achievements.is_unlocked("ecology_expert"), "Partial collection must not unlock ecology expert")
	check(Knowledge.collected_count() == 39, "Boundary test reaches 39 / 40")
	game._show_knowledge(ids.back())
	check(Achievements.is_unlocked("ecology_expert"), "The final gameplay knowledge popup unlocks ecology expert")
	check(notifications.count("ecology_expert") == 1, "Ecology expert announces exactly once")
	game.popup_root.hide()
	Achievements.check_knowledge_completion()
	Knowledge.unlock(ids.back())
	check(notifications.count("ecology_expert") == 1, "Repeated checks and cards do not repeat the achievement")
	Achievements._load()
	check(Achievements.is_unlocked("rigged") and Achievements.is_unlocked("ecology_expert"), "Both achievements survive save reload")
	Achievements.reset_all()
	check(not Achievements.is_unlocked("ecology_expert"), "Reset clears the achievement")
	Knowledge._load()
	Achievements._watch_knowledge()
	check(Achievements.is_unlocked("ecology_expert"), "Startup reconciliation rewards an existing complete collection")
	check(not Achievements.is_unlocked("rigged"), "Collection completion must not unlock rigged")
	Achievements.try_unlock("rigged")
	game._ach_queue.clear()
	game.ach_popup.visible = false
	game._show_achievements_panel()
	await settle(0.5)
	await capture("achievements-new-unlocked")
	get_window().size = Vector2i(960, 540)
	await settle(0.5)
	check(get_viewport().get_visible_rect().encloses(game.menu_achievements_panel.get_global_rect()), "Achievement menu fits a small window")
	await capture("achievements-small")
	print("ACHIEVEMENT_CARDS: %d checks, %d failures" % [checks, failures.size()])
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
