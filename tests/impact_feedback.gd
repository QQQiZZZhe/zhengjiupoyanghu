extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func wait_for(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("POYANG_SCREENSHOT_DIR").path_join(name + ".png"))
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var game: Node = scene.get_node("Game")
	await wait_for(0.5)
	if game._intro_playing: game._finish_intro()
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261010"
	game._on_start_pressed()
	for i in 24:
		if game.popup_root.visible: game._on_popup_button()
		await wait_for(0.1)
	game.set_process(false)
	game.play_deal_anim = false
	game.current_hand = [GameState.card_by_id("patrol")]
	game._build_hand_panel()
	await get_tree().process_frame
	var card: Control = game.card_infos[0].panel
	var fx: Node2D = game.impact_feedback
	var home := card.position
	var scale_before := card.scale
	var funds_before: int = GameState.funds
	var metrics_before: Dictionary = GameState.metrics.duplicate(true)
	fx.pulse(card, Color("f3d584"), 1.4, true)
	check(card.scale.x > scale_before.x, "Contact punch starts immediately")
	check(card.material.get_shader_parameter("impact_flash") > 0.0, "Flash uses the existing card material")
	await wait_for(0.055)
	await shot("01-contact")
	check(fx.bursts.size() == 1, "One burst per card")
	fx.pulse(card, Color("f3d584"), 1.0, true)
	check(fx.bursts.size() == 1, "Repeated hit replaces card driver")
	check(fx.bursts[0].base.is_equal_approx(home), "Repeated hit retains rest position")
	game._paused = true
	var age: float = fx.bursts[0].age
	await wait_for(0.1)
	check(is_equal_approx(fx.bursts[0].age, age), "Pause holds contact effect")
	game._paused = false
	await wait_for(0.4)
	check(fx.bursts.is_empty() and not fx.is_processing(), "Idle feedback has no process ticks")
	check(card.position.is_equal_approx(home) and card.scale.is_equal_approx(scale_before), "Contact restores exact pose")
	check(card.material.get_shader_parameter("impact_flash") == 0.0, "Flash returns to neutral")
	check(GameState.funds == funds_before and GameState.metrics == metrics_before, "Presentation leaves payments and metrics untouched")
	check(Engine.time_scale == 1.0, "No global time scale changes")
	for i in 20:
		var target := Control.new()
		add_child(target)
		fx.pulse(target, Color.WHITE)
	check(fx.bursts.size() == fx.MAX_BURSTS, "Rapid input stays bounded")
	fx.clear()
	check(not fx.is_processing() and fx.bursts.is_empty(), "Clear removes all live effects")
	game.wetland.reduced_motion = true
	fx.pulse(card, Color.WHITE, 1.8, true)
	check(fx.bursts.is_empty() and card.position.is_equal_approx(home), "Reduced motion skips feedback")
	game.wetland.reduced_motion = false
	fx.pulse(card, Color.WHITE, 1.0, true)
	game._show_menu()
	check(fx.bursts.is_empty() and card.scale.is_equal_approx(scale_before), "Menu cancels pose and flash")
	game._hide_menu()
	game._playing = true
	game._current_phase = "allocate"
	GameState.funds = 1000
	for metric in GameState.metrics: GameState.metrics[metric] = 70
	var info: Dictionary = game.card_infos[0]
	var drop_point: Vector2 = game.card_box.global_position + Vector2(game.card_box.size.x * 0.5, -160.0)
	var before_drop: int = fx.emitted
	game._card_press_panel = card
	game._card_dragging = true
	game._card_drag_grab_offset = Vector2.ZERO
	game._card_drag_last_mouse = drop_point
	game._finish_card_pointer(drop_point)
	check(info.selected and info.staged_by_drag, "Actual drag queues the card")
	check(fx.emitted == before_drop + 1, "Successful drop emits exactly one contact burst")
	check(not fx.bursts[0].punch, "Drop flash leaves the landing spring in control")
	info.tier = "effective"
	check(GameState.dispatch_card("rescue"), "Dispatch payment succeeds")
	game._sync_dispatched_stage_cards()
	game._layout_fan()
	await wait_for(0.6)
	var start_emitted: int = fx.emitted
	game.score_speed = 1.0
	game._finish_turn()
	await wait_for(0.8)
	await shot("02-score-hit")
	for i in 90:
		if not game._score_animating: break
		await wait_for(0.1)
	check(not game._score_animating, "Real settlement finishes")
	check(fx.emitted >= start_emitted + 2, "Ordinary and dispatch cards receive score feedback")
	check(fx.bursts.is_empty() and not fx.is_processing(), "Settlement leaves no persistent effects")
	check(GameState.ever_played.get("patrol", 0) == 1 and GameState.ever_played.get("rescue", 0) == 1, "Feedback does not execute cards twice")
	await shot("03-settled")
	print("IMPACT FEEDBACK: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
