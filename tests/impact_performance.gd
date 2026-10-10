extends Node
func p95(values: Array) -> int:
	if values.is_empty(): return 0
	values.sort()
	return int(values[mini(values.size() - 1, floori(values.size() * 0.95))])
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var game: Node = scene.get_node("Game")
	await get_tree().create_timer(0.5).timeout
	if game._intro_playing: game._finish_intro()
	game.set_process(false)
	game.wetland.set_process(false)
	game._hide_menu()
	var fx: Node2D = load("res://tests/fixtures/impact_perf_probe.gd").new()
	add_child(fx)
	var targets: Array[Control] = []
	for i in 6:
		var made: Dictionary = game._make_card(GameState.card_by_id("patrol"), "effective", false)
		var card: Control = made.panel
		add_child(card)
		card.position = Vector2(200 + i * 150, 250)
		game._bind_card_gyro(card)
		targets.append(card)
	var idle_calls: Array = []
	for i in 30:
		await RenderingServer.frame_post_draw
		idle_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var active_calls: Array = []
	var frame_us: Array = []
	for i in 180:
		if i % 12 == 0:
			for card in targets: fx.pulse(card, Color.GOLD, 1.0, true)
		var start := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		frame_us.append(Time.get_ticks_usec() - start)
		active_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("IMPACT_PERF process_p95_us=%d draw_p95_us=%d idle_calls_p95=%d active_calls_p95=%d frame_p95_us=%d" %
		[p95(fx.process_us), p95(fx.draw_us), p95(idle_calls), p95(active_calls), p95(frame_us)])
	fx.clear()
	var outline_script: GDScript = load("res://scripts/card_outline.gd")
	outline_script.contour.clear()
	var target: Control = targets[0]
	target.get_theme_stylebox("panel").set_meta("card_outline", true)
	for child in target.get_children():
		if child.get_script() == outline_script:
			var start := Time.get_ticks_usec()
			child._process(0.0)
			print("IMPACT_PERF first_outline_us=", Time.get_ticks_usec() - start)
	get_tree().quit()
