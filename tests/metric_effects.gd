extends Node
var checks := 0
var failures: Array[String] = []
var game: Node
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	Talents.reset_all()
	GameState.difficulty = GameState.Difficulty.EASY
	GameState.run_seed = 20261007
	GameState.reset_game()
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle(0.5)
	if game._intro_playing: game._finish_intro()
	game._playing = true
	game._hide_menu()
	game.popup_root.hide()
	game.crisis_root.hide()
	game._current_phase = "allocate"
	game._enter_allocate()
	game.right_panel.show()
	await settle(0.4)
	var before: Dictionary = GameState.metrics.duplicate()
	for metric in GameState.METRIC_NAMES:
		var info: Dictionary = game.metric_bars[metric]
		var icon: TextureRect = info["icon"]
		var ripple: ColorRect = info["ripple"]
		var origin := icon.position
		icon.mouse_entered.emit()
		await settle(0.18)
		check(icon.hover_scale > 1.25, "Each icon must enlarge on hover")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		seed(321)
		var expected_random := randi()
		seed(321)
		icon._gui_input(click)
		icon._process(0.035)
		check(randi() == expected_random, "Poke must not consume gameplay RNG")
		check(icon.poke_count == 1 and Vector2(icon.material.get_shader_parameter("shake")).length() > 0.1, "Each click must trigger visible poke shake")
		check(icon.position == origin and icon.scale == Vector2.ONE, "Effects must not move container layout or overwrite score transforms")
		icon._gui_input(click)
		check(icon.poke_count == 2 and icon.poke_age == 0, "Repeated click must restart poke cleanly")
		icon.mouse_exited.emit()
		await settle(0.35)
		check(icon.hover_scale < 1.01 and Vector2(icon.material.get_shader_parameter("shake")).is_zero_approx(), "Icon must return to normal after hover and poke")
		info["bar"].value = 42
		ripple._process(0.1)
		check(is_equal_approx(float(ripple.material.get_shader_parameter("fill_ratio")), 0.42), "Wave mask must follow actual displayed bar value")
		var clock: float = ripple.flow_clock
		game._paused = true
		ripple._process(0.2)
		check(ripple.flow_clock == clock, "Pause must freeze wave animation")
		game._paused = false
		ripple._process(0.2)
		check(ripple.flow_clock > clock, "Unpaused waves must advance")
		game.wetland.reduced_motion = true
		ripple._process(0.2)
		check(not bool(ripple.material.get_shader_parameter("enabled")), "Reduced motion must disable flowing waves")
		icon._gui_input(click)
		icon._process(0.02)
		check(Vector2(icon.material.get_shader_parameter("shake")).is_zero_approx(), "Reduced motion must suppress poke vibration")
		game.wetland.reduced_motion = false
	check(GameState.metrics == before, "UI effects must not alter ecological values")
	game._update_hud()
	var output := OS.get_environment("POYANG_SCREENSHOT_DIR")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		game.metric_bars["birds"]["icon"].hovered = true
		await settle(0.2)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("monitor-effects.png"))
	print("METRIC_EFFECTS: ", checks, " checks, ", failures.size(), " failures")
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
