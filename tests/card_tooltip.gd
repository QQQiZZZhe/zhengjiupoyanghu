extends Node
## Uses an isolated player profile and a real GUI window.
var game: Node
var checks := 0
var failures := 0
var release_counts: Dictionary = {}
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func move_pointer(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(3, 2)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame
func button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
func info_for(id: String) -> Dictionary:
	for info in game.card_infos:
		if info.card_id == id: return info
	return {}
func displayed_labels(node: Node, output: Array[String]) -> void:
	if node is Label and node.is_visible_in_tree(): output.append(node.text)
	for child in node.get_children(true): displayed_labels(child, output)
func tooltip_for(id: String) -> void:
	var info := info_for(id)
	var point: Vector2 = game._card_gyro_center(info.panel)
	await move_pointer(point)
	# Card hover movement can restart the native tooltip timer. Wait for its
	# visible contents, with a deadline, rather than assuming an exact frame.
	var deadline := Time.get_ticks_msec() + 2500
	var labels: Array[String] = []
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
		labels.clear()
		displayed_labels(get_tree().root, labels)
		if labels.has(info.panel.tooltip_text): break
	var hovered := get_viewport().gui_get_hovered_control()
	check(hovered == info.panel, "GUI hover identifies " + id)
	check(labels.has(info.panel.tooltip_text), "Visible tooltip has this card's complete description, tier, price and effects: " + id)
	for other in game.card_infos:
		if other.panel != info.panel:
			check(not labels.has(other.panel.tooltip_text), "Previous card tooltip never leaks into " + id)
func press_card(id: String) -> Vector2:
	var info := info_for(id)
	var point: Vector2 = info.panel.get_global_transform() * Vector2(61, 65)
	await move_pointer(point)
	await button(point, true)
	check(game._card_press_panel == info.panel, "Mouse press identifies " + id)
	return point
func drag_card(id: String, drop: Vector2) -> void:
	await press_card(id)
	# Drive the presentation pose directly, since synthetic mouse motion does
	# not change the OS-polled cursor used by the drag threshold. Button events
	# still pass through the real input pipeline and native GUI capture.
	game._start_card_drag()
	game._update_card_drag_pose(drop, Vector2(0, -50))
	await move_pointer(drop)
	game._update_card_drag_pose(drop, Vector2.ZERO)
	await button(drop, false)
	check(game._card_press_panel == null and not game._card_dragging, "Release ends the game's drag gesture")
	check(int(release_counts.get(id, 0)) > 0, "Native GUI also receives release for " + id)
	await get_tree().create_timer(0.8).timeout
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) or DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await get_tree().create_timer(0.5).timeout
	if game._intro_playing: game._finish_intro()
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261009"
	game._on_start_pressed()
	for i in 16:
		if game.popup_root.visible: game._on_popup_button()
		await get_tree().create_timer(0.1).timeout
	GameState.funds = 1000
	game.current_hand = [GameState.card_by_id("water_comanage"), GameState.card_by_id("smart_patrol"), GameState.card_by_id("education"), GameState.card_by_id("research")]
	game._build_hand_panel()
	await get_tree().create_timer(0.8).timeout
	for info in game.card_infos:
		var id: String = info.card_id
		info.panel.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				release_counts[id] = int(release_counts.get(id, 0)) + 1)
	var point := await press_card("water_comanage")
	await button(point, false)
	check(int(release_counts.get("water_comanage", 0)) == 1, "Short click releases native mouse capture exactly once")
	await tooltip_for("smart_patrol")
	var drop := Vector2(game.card_box.global_position.x + game.card_box.size.x * 0.5, game.card_box.global_position.y - 110)
	await drag_card("water_comanage", drop)
	check(info_for("water_comanage").get("staged_by_drag", false), "Community card is staged before reproducing the report")
	await tooltip_for("smart_patrol")
	point = await press_card("smart_patrol")
	await button(point, false)
	check(not info_for("smart_patrol").selected, "Short click does not accidentally play the next card")
	await tooltip_for("education")
	await tooltip_for("water_comanage")
	var hand_drop: Vector2 = game.card_box.global_position + Vector2(game.card_box.size.x * 0.5, game.card_box.size.y * 0.6)
	await drag_card("water_comanage", hand_drop)
	check(not info_for("water_comanage").get("staged_by_drag", false), "Dragging back cancels the staged card")
	await tooltip_for("smart_patrol")
	await drag_card("education", drop)
	await drag_card("water_comanage", drop)
	await tooltip_for("smart_patrol")
	var other: Control = info_for("education").panel
	var reorder_drop: Vector2 = other.get_global_transform() * (other.size * 0.5)
	await drag_card("water_comanage", reorder_drop)
	check(game._ordered_staged_indices().size() == 2, "Reordering preserves the played queue")
	await tooltip_for("smart_patrol")
	await tooltip_for("education")
	print("CARD_TOOLTIP: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)
