extends Node
## Run only with an isolated user directory.
var game: Node
var checks := 0
var failures: Array[String] = []
var shader_code := ""
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")
const RigidShader = preload("res://scripts/card_rigid.gdshader")
const AffineShader = preload("res://tests/fixtures/teammate_card_gyro.gdshader")

func projection_errors(shader: Shader) -> Vector2i:
	var pattern := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = [Color8(220, 40, 60), Color8(30, 190, 80), Color8(40, 80, 220)]
	for y in 256:
		for x in 256:
			pattern.set_pixel(x, y, colors[(int(x / 16.0) + int(y / 16.0)) % 3])
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(pattern)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var center := get_viewport().get_visible_rect().size * 0.5
	sprite.position = center
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tilt_x", 0.32)
	material.set_shader_parameter("tilt_y", -0.32)
	material.set_shader_parameter("card_center", center)
	sprite.material = material
	layer.add_child(sprite)
	await settle(0.2)
	RenderingServer.force_draw()
	var rendered := get_viewport().get_texture().get_image()
	var samples := 0
	var errors := 0
	var cx := cos(0.32)
	var sx := sin(0.32)
	var cy := cos(-0.32)
	var sy := sin(-0.32)
	for y in range(int(center.y) - 110, int(center.y) + 110, 4):
		for x in range(int(center.x) - 110, int(center.x) + 110, 4):
			# Invert the analytic planar camera projection at this pixel center.
			var screen := Vector2(x + 0.5, y + 0.5) - center
			var a := cy + screen.x * cx * sy / 520.0
			var b := -screen.x * sx / 520.0
			var c := sx * sy + screen.y * cx * sy / 520.0
			var d := cx - screen.y * sx / 520.0
			var det := a * d - b * c
			var source := Vector2((screen.x * d - b * screen.y) / det,
				(a * screen.y - screen.x * c) / det) + Vector2(128, 128)
			if not Rect2(4, 4, 248, 248).has_point(source):
				continue
			# Ignore grid boundaries, where nearest-pixel sampling can alias.
			if fmod(source.x, 16.0) < 2.0 or fmod(source.x, 16.0) > 14.0 or fmod(source.y, 16.0) < 2.0 or fmod(source.y, 16.0) > 14.0:
				continue
			var expected := pattern.get_pixel(int(source.x), int(source.y))
			var actual := rendered.get_pixel(x, y)
			samples += 1
			if absf(actual.r - expected.r) + absf(actual.g - expected.g) + absf(actual.b - expected.b) > 0.02:
				errors += 1
	layer.queue_free()
	await get_tree().process_frame
	return Vector2i(samples, errors)

func verify_rigid_projection() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var old_errors := await projection_errors(AffineShader)
	var rigid_errors := await projection_errors(RigidShader)
	check(rigid_errors.x > 500, "Rigid projection sampled enough interior pixels")
	check(rigid_errors.y < rigid_errors.x * 0.01, "Rigid-plane texture agrees with analytical projection")
	check(old_errors.y > rigid_errors.y + rigid_errors.x * 0.02, "Projection test detects the previous affine texture deformation")
	print("RIGID_PROJECTION: samples=%d old_errors=%d rigid_errors=%d" % [rigid_errors.x, old_errors.y, rigid_errors.y])

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle(seconds: float = 0.3) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(label: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))

func card_pixels(card: Control) -> int:
	if DisplayServer.get_name() == "headless":
		return -1
	RenderingServer.force_draw()
	var img := get_viewport().get_texture().get_image()
	var colors := {}
	var bounds := card.get_global_rect().intersection(get_viewport().get_visible_rect())
	var pixels := 0
	var scale: Vector2 = Vector2(img.get_size()) / get_viewport().get_visible_rect().size
	for y in range(int(bounds.position.y * scale.y), int(bounds.end.y * scale.y), 4):
		for x in range(int(bounds.position.x * scale.x), int(bounds.end.x * scale.x), 4):
			var color := img.get_pixel(x, y)
			colors[color.to_rgba32()] = true
			if color.a > 0.5:
				pixels += 1
	check(colors.size() > 8, "Rendered card contains artwork and text colors")
	return pixels

func check_material_tree(node: Node) -> void:
	for child in node.get_children():
		if child.get_meta("card_projected_shadow", false):
			check(not child.use_parent_material and child.material == null, "Projected shadow must be independent of card shader")
			continue
		check(not child is SubViewport, "No flattened card viewport remains")
		if child is CanvasItem:
			check(child.use_parent_material, "Each card primitive uses the reference parent material")
		check_material_tree(child)

func check_tilt(card: Control, label: String) -> void:
	var material := card.material as ShaderMaterial
	check(material != null, label + " uses a gyro material")
	if material == null:
		return
	if shader_code.is_empty():
		shader_code = material.shader.code
	check(material.shader.code == shader_code, label + " uses the shared projection")
	check(material.shader == RigidShader, label + " uses the shared rigid-plane shader")
	check_material_tree(card)
	var geometry = preload("res://scripts/card_geometry.gd")
	var face: TextureRect = geometry.face_of(card)
	var rect: Rect2 = geometry.face_rect(face)
	for uv in [Vector2(0.5, 0.5), Vector2(0.03, 0.5), Vector2(0.97, 0.5)]:
		var point: Vector2 = geometry.project(card, face.get_global_transform() * (rect.position + uv * rect.size))
		check(geometry.contains(card, point), label + " visible artwork must be clickable through perspective")
	for uv in [Vector2(-0.01, 0.5), Vector2(1.01, 0.5), Vector2(0, 0)]:
		var point: Vector2 = geometry.project(card, face.get_global_transform() * (rect.position + uv * rect.size))
		check(not geometry.contains(card, point), label + " letterbox and transparent corners must not be clickable")
	var shadow: Node2D = card.get_meta("projected_shadow")
	check(shadow.show_behind_parent, label + " projects behind the card")
	shadow.update_projection(card, Vector2(0.25, 0.25))
	var right: PackedVector2Array = shadow.points.duplicate()
	shadow.update_projection(card, Vector2(-0.25, -0.25))
	var left: PackedVector2Array = shadow.points.duplicate()
	check(right.size() == 4 and left.size() == 4, label + " shadow projects four card corners")
	check(right[0].distance_to(left[0]) > 2.0, label + " opposite gyro directions change shadow projection")
	shadow.update_projection(card, Vector2(float(card.get_meta("gyro_x")), float(card.get_meta("gyro_y"))))
	check(absf(float(material.get_shader_parameter("tilt_x"))) > 0.02, label + " tilts vertically")
	check(absf(float(material.get_shader_parameter("tilt_y"))) > 0.02, label + " tilts horizontally")
	check(Vector2(material.get_shader_parameter("card_center")).distance_to(game._card_gyro_center(card)) < 0.1, label + " follows the transformed center")
	for i in 24:
		game._step_card_gyro(card, Vector2.ZERO, 0.05)
	check(absf(float(material.get_shader_parameter("tilt_x"))) < 0.001 and absf(float(material.get_shader_parameter("tilt_y"))) < 0.001, label + " returns flat")

func probe_grid(grid: HFlowContainer, label: String) -> Control:
	var card: Control = grid.get_child(0)
	var gesture := InputEventMouseMotion.new()
	gesture.position = game._card_gyro_center(card)
	gesture.global_position = gesture.position
	Input.parse_input_event(gesture)
	Input.flush_buffered_events()
	await settle(0.4)
	game._kill_card_tweens(card)
	var mouse: Vector2 = game._card_gyro_center(card) + Vector2(40, -30)
	gesture = InputEventMouseMotion.new()
	gesture.position = mouse
	gesture.global_position = mouse
	Input.parse_input_event(gesture)
	Input.flush_buffered_events()
	await get_tree().process_frame
	check(game._deck_gyro_view == card, label + " responds to a real pointer over its rendered face")
	for i in 24:
		game._process_deck_gyro(0.05, mouse)
	await capture(label)
	check_tilt(card, label)
	check(card.get_meta("panel") is PanelContainer, label + " uses original card primitives")
	check(await card_pixels(card) > 100 or DisplayServer.get_name() == "headless", label + " has a rendered card face")
	await settle(0.8) # Let pointer-hover springs reach rest before measuring idle drift.
	var position_before: Vector2 = card.position
	await settle(0.7)
	check(card.position.is_equal_approx(position_before), label + " has no idle floating loop")
	game._on_viewer_card_unhover(card)
	return card

func probe_detail(card: Control, label: String) -> void:
	check(card is PanelContainer, label + " uses teammate's original panel implementation")
	var mouse: Vector2 = game._card_gyro_center(card) + Vector2(40, -30)
	for i in 24:
		game._process_detail_gyro(0.05, mouse)
	await capture(label)
	check_tilt(card, label)
	check(get_viewport().get_visible_rect().encloses(card.get_global_rect()), label + " fits the window")
	if label == "gyro-action-detail":
		for direction in [Vector2(-0.30, -0.30), Vector2(0.30, 0.30)]:
			for i in 24: game._step_card_gyro(card, direction, 0.05)
			await capture("shadow-upper-left" if direction.x < 0 else "shadow-lower-right")
		for i in 24: game._step_card_gyro(card, Vector2.ZERO, 0.05)

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle(0.4)
	await verify_rigid_projection()
	if game._intro_playing:
		game._finish_intro()
	await settle(1.0)
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261004"
	game._on_start_pressed()
	for i in 12:
		if not game.popup_root.visible:
			break
		game._on_popup_button()
		await settle(0.1)
	await settle(1.5)
	GameState.funds = 1000
	game.set_process(false)
	for action in GameState.ACTION_CARDS:
		var made: Dictionary = game._make_card(action)
		game._bind_card_gyro(made.panel)
		add_child(made.panel)
		await get_tree().process_frame
		await get_tree().process_frame
		var face: PanelContainer = made.panel
		check(face.size.x <= 122.1 and face.size.y <= 165.1, "%s keeps its fixed card dimensions" % action.id)
		check(face.is_ancestor_of(made.cost_label) and not made.cost_label.visible, "%s price state belongs to its panel without drawing text" % action.id)
		var bitmap: TextureRect = face.get_meta("pixel_face")
		check(bitmap.texture == game.PixelCardArt.texture(action.name, str(GameState.tier_cost(action.id, game.play_tier))), "%s price is written into the pixel face" % action.id)
		made.panel.queue_free()
	for info in game.card_infos:
		var panel: PanelContainer = info.panel
		check(panel.get_meta("pixel_face") is TextureRect, "Hand card uses the shared pixel face")
		check(panel.get_theme_stylebox("panel") is StyleBoxFlat, "Hand card preserves the selection frame")
		check(panel.size.is_equal_approx(Vector2(122, 165)), "Hand card keeps its fixed footprint")
		check_material_tree(panel)
	var info: Dictionary = game.card_infos.back()
	var hand: PanelContainer = info.panel
	verify_hand_edge_stability(info)
	var center: Vector2 = game._card_gyro_center(hand)
	for i in 24:
		game._update_card_hover(0.05, center + Vector2(35, -25))
	await capture("gyro-hand")
	check_tilt(hand, "Hand")
	check(await card_pixels(hand) > 100 or DisplayServer.get_name() == "headless", "Hand rendering is nonblank")
	game._set_play_tier("basic", false)
	var basic_cost: String = info.cost_label.text
	var table_drop: Vector2 = Vector2(game.card_box.global_position.x + game.card_box.size.x * 0.5,
		game.card_box.global_position.y - 110.0)
	game._card_press_panel = hand
	game._start_card_drag()
	game._update_card_drag_pose(table_drop, Vector2(0, -48))
	game._finish_card_pointer(table_drop)
	check(info.selected and info.get("staged_by_drag", false) and info.tier == "basic",
		"Dragging a card onto the upper table stages it at the current tier")
	check(not game._score_animating, "Staging never executes or settles the card")
	check(hand.get_theme_stylebox("panel").border_color.is_equal_approx(game.VisualTheme.GOLD), "Staged card keeps the table-ready frame")
	await settle(2.1)
	game._set_play_tier("deep", false)
	check(game.play_tier == "deep", "Lever switches after its real cooldown")
	check(info.tier == "basic", "A staged card preserves its locked price tier")
	var hand_drop: Vector2 = game.card_box.global_position + Vector2(game.card_box.size.x * 0.5, game.card_box.size.y * 0.6)
	game._card_press_panel = hand
	game._start_card_drag()
	game._update_card_drag_pose(hand_drop, Vector2(0, 80))
	game._finish_card_pointer(hand_drop)
	check(not info.selected and not info.get("staged_by_drag", false), "Dragging a staged card back to the fan cancels it")
	check(info.cost_label.text != basic_cost, "An unstaged hand card follows the new lever tier")
	var click_panel: PanelContainer = game.card_infos[0].panel
	var click_info: Dictionary = game.card_infos[0]
	var click_press := InputEventMouseButton.new()
	click_press.button_index = MOUSE_BUTTON_LEFT
	click_press.pressed = true
	game._on_card_gui_input(click_press, click_panel)
	check(game._card_press_panel == click_panel, "Hand press begins a click-or-drag gesture")
	game._finish_card_pointer(Vector2(-1000, -1000))
	check(not click_info.selected, "Releasing outside the card does not stage it")
	game._on_card_gui_input(click_press, click_panel)
	game._finish_card_pointer(game._card_gyro_center(click_panel))
	check(not click_info.selected, "A short left click no longer stages a card")
	var drag_index: int = int(game.card_infos.size() / 2)
	var drag_info: Dictionary = game.card_infos[drag_index]
	var drag_panel: PanelContainer = drag_info.panel
	var original_drag_pos: Vector2 = drag_panel.position
	game._card_press_panel = drag_panel
	game._start_card_drag()
	check(game._card_dragging and drag_info.get("dragging", false), "Held hand card enters a dedicated drag state")
	var drag_point: Vector2 = game.card_box.global_position + original_drag_pos + drag_panel.pivot_offset + Vector2(24, -18)
	game._update_card_drag_pose(drag_point, Vector2(18, 0))
	check(drag_panel.position.distance_to(original_drag_pos) > 5.0, "Dragged card follows the pointer with its grab point preserved")
	var neighbor: Dictionary = game.card_infos[drag_index - 1]
	check(game._card_drag_neighbor_offset(neighbor).x < -0.5, "Nearby cards yield away from the dragged card")
	var inside_point: Vector2 = game._card_drag_mouse
	for outside_point in [Vector2(inside_point.x, game.card_box.global_position.y - 1.0),
		Vector2(game.card_box.global_position.x - 1.0, inside_point.y),
		Vector2(inside_point.x, game.card_box.get_global_rect().end.y + 1.0)]:
		game._update_card_drag_pose(outside_point, Vector2.ZERO)
		check(game._card_drag_neighbor_offset(neighbor).is_zero_approx(),
			"Hand cards do not yield when the drag pointer leaves the hand boundary")
	game._update_card_drag_pose(inside_point, Vector2.ZERO)
	check(game._card_drag_neighbor_offset(neighbor).x < -0.5,
		"Hand avoidance resumes when the drag re-enters the hand")
	game._finish_card_pointer(drag_point)
	check(not game._card_dragging and not drag_info.get("dragging", false), "Releasing the pointer exits drag state")
	game._update_card_hover(1.0 / 60.0, Vector2(-1000, -1000))
	var return_spring: Node = drag_panel.get_node_or_null("MotionSpring_position")
	check(return_spring != null and return_spring.target.is_equal_approx(drag_info.base_pos), "Dragged card springs back to its fan anchor")
	var neighbor_spring: Node = neighbor.panel.get_node_or_null("MotionSpring_position")
	check(neighbor_spring != null and neighbor_spring.target.is_equal_approx(neighbor.base_pos), "Neighbour spring target returns to the original fan")
	var before_reorder: int = game.card_infos.find(drag_info)
	game._card_press_panel = drag_panel
	game._start_card_drag()
	var far_right: Vector2 = game.card_box.global_position + Vector2(game.card_box.size.x - 8.0, game.card_box.size.y * 0.55)
	game._update_card_drag_pose(far_right, Vector2(45, 0))
	game._finish_card_pointer(far_right)
	check(game.card_infos.back().panel == drag_panel and game.card_infos.find(drag_info) > before_reorder,
		"Dropping a card over a new hand slot changes its position in the hand")
	game._update_card_hover(1.0 / 60.0, Vector2(-1000, -1000))
	return_spring = drag_panel.get_node_or_null("MotionSpring_position")
	check(return_spring != null and return_spring.target.is_equal_approx(drag_info.base_pos), "Reordered card springs toward its new fan slot")
	var queue_a: Dictionary = game.card_infos[0]
	var queue_b: Dictionary = game.card_infos[1]
	var queue_drop: Vector2 = Vector2(game.card_box.global_position.x + game.card_box.size.x * 0.5,
		game.card_box.global_position.y - 110.0)
	for queued in [queue_a, queue_b]:
		var queued_panel: PanelContainer = queued.panel
		game._card_press_panel = queued_panel
		game._start_card_drag()
		game._update_card_drag_pose(queue_drop, Vector2(0, -40))
		var poses_before_drop: Dictionary = {}
		for remaining in game.card_infos:
			if remaining.panel != queued_panel and not remaining.get("staged_by_drag", false):
				var moving_spring = remaining.panel.get_node_or_null("MotionSpring_position")
				poses_before_drop[remaining.panel] = {"position": remaining.panel.position,
					"rotation": remaining.panel.rotation,
					"velocity": moving_spring.velocity if moving_spring != null else Vector2.ZERO}
		game._finish_card_pointer(queue_drop)
		var reflow_probe: Dictionary = {}
		var largest_reflow := 0.0
		for remaining in game.card_infos:
			if not poses_before_drop.has(remaining.panel):
				continue
			var old_pose: Dictionary = poses_before_drop[remaining.panel]
			check(remaining.panel.position.is_equal_approx(old_pose.position)
				and is_equal_approx(remaining.panel.rotation, old_pose.rotation),
				"Playing a card preserves remaining hand poses on the release frame")
			var reflow_spring = remaining.panel.get_node_or_null("MotionSpring_position")
			check(reflow_spring != null and reflow_spring.velocity.is_equal_approx(old_pose.velocity),
				"Consecutive card plays preserve the current hand reflow momentum")
			var gap: float = remaining.panel.position.distance_to(remaining.base_pos)
			if gap > largest_reflow:
				largest_reflow = gap
				reflow_probe = remaining
		check(largest_reflow > 5.0, "Hand reflow starts away from its destination instead of snapping there")
		await settle(0.08)
		var intermediate_gap: float = reflow_probe.panel.position.distance_to(reflow_probe.base_pos)
		check(intermediate_gap > 0.5 and intermediate_gap < largest_reflow,
			"Hand cards visibly travel through intermediate positions while gathering")
	var queued_order: Array = game._ordered_staged_indices()
	check(queued_order.size() == 2 and game.card_infos[queued_order[0]] == queue_a
		and game.card_infos[queued_order[1]] == queue_b, "Settlement queue follows the order cards were dropped onto the table")
	check(not game._score_animating, "Queued cards wait for the existing execute action button")
	# Fast consecutive releases retain real spring momentum. Wait for the
	# bounded convergence rather than treating a fixed 450 ms as exact rest.
	var reflow_deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < reflow_deadline:
		var converged := true
		for remaining in game.card_infos:
			if not remaining.get("staged_by_drag", false) and remaining.panel.position.distance_to(remaining.base_pos) >= 1.0:
				converged = false
		if converged: break
		await get_tree().process_frame
	for remaining in game.card_infos:
		if not remaining.get("staged_by_drag", false):
			check(remaining.panel.position.distance_to(remaining.base_pos) < 1.0,
				"Hand reflow settles into the new fan without persistent drift")
	check(is_zero_approx(queue_a.panel.rotation) and is_zero_approx(queue_b.panel.rotation),
		"Staged table cards settle parallel instead of keeping fan angles")
	check(queue_a.panel.scale.is_equal_approx(Vector2.ONE)
		and queue_b.panel.scale.is_equal_approx(Vector2.ONE),
		"Staged table cards keep the normal hand-card size")
	check(queue_a.panel.z_index == 100 + int(queue_a.stage_order)
		and queue_b.panel.z_index == 100 + int(queue_b.stage_order),
		"Newly staged cards render above earlier queue slots")
	var staged_slot: Vector2 = queue_a.base_pos
	var other_slot: Vector2 = queue_b.base_pos
	game._card_press_panel = queue_a.panel
	game._start_card_drag()
	var reorder_point: Vector2 = queue_drop + Vector2(150.0, 0.0)
	game._update_card_drag_pose(reorder_point, Vector2(30.0, 0.0))
	for hand_entry in game.card_infos:
		if not hand_entry.get("staged_by_drag", false):
			check(game._card_drag_neighbor_offset(hand_entry).is_zero_approx(),
				"Reordering staged cards does not activate hand avoidance")
	check(is_equal_approx(queue_b.base_pos.y, -198.0),
		"The staged row is raised above the hand boundary")
	var avoid_spring = queue_b.panel.get_node_or_null("MotionSpring_position")
	check(avoid_spring != null and avoid_spring.target.is_equal_approx(staged_slot),
		"Table neighbours spring into the vacated slot during a drag")
	check(int(queue_a.stage_order) == 0 and int(queue_b.stage_order) == 1,
		"Drag preview keeps committed table order until release")
	check(queue_a.panel.z_index > queue_b.panel.z_index,
		"Dragged table card renders above its avoiding neighbours")
	game._update_card_drag_pose(game.card_box.global_position + Vector2(0.0, 300.0), Vector2.ZERO)
	check(avoid_spring.target.is_equal_approx(other_slot),
		"Leaving the table restores neighbours to their committed slots")
	game._update_card_drag_pose(reorder_point, Vector2.ZERO)
	game._finish_card_pointer(reorder_point)
	check(int(queue_a.stage_order) == 1 and int(queue_b.stage_order) == 0,
		"Releasing commits the insertion order shown by the preview")
	await settle(0.45)
	staged_slot = queue_a.base_pos
	var staged_order_before_sort: int = int(queue_a.stage_order)
	await probe_hand_sort()
	check(queue_a.stage_order == staged_order_before_sort and queue_a.base_pos.is_equal_approx(staged_slot),
		"Hand sorting leaves staged cards in their table slots")
	var staged_mouse: Vector2 = game._card_gyro_center(queue_a.panel) + Vector2(28.0, -20.0)
	for frame in 16:
		game._update_card_hover(0.05, staged_mouse)
	var staged_material := queue_a.panel.material as ShaderMaterial
	var pressure_hand: Control
	for entry in game.card_infos:
		if not entry.get("staged_by_drag", false):
			pressure_hand = entry.panel
			break
	var hand_pressure_point: Vector2 = pressure_hand.get_global_transform() * (pressure_hand.size * Vector2(0.75, 0.25))
	var staged_pressure_point: Vector2 = queue_a.panel.get_global_transform() * (queue_a.panel.size * Vector2(0.75, 0.25))
	var hand_pressure: Vector2 = game._card_gyro_target(pressure_hand, hand_pressure_point, true, true)
	var staged_pressure: Vector2 = game._card_gyro_target(queue_a.panel, staged_pressure_point, true, true)
	check(hand_pressure.is_equal_approx(staged_pressure) and staged_pressure.is_equal_approx(Vector2(-0.16, 0.16)),
		"Hand and staged card faces apply equal gyro pressure despite fan rotation and hover size")
	check(game._card_gyro_target(queue_a.panel, staged_pressure_point, false, true).is_zero_approx(),
		"Staged gyro pressure returns to level outside its face")
	check(absf(float(staged_material.get_shader_parameter("tilt_x"))) > 0.02
		and absf(float(staged_material.get_shader_parameter("tilt_y"))) > 0.02,
		"Staged cards keep pointer-driven gyro tilt")
	game._update_card_hover(1.0 / 60.0, Vector2(-1000.0, -1000.0))
	await settle(0.4)
	for queued in [queue_a, queue_b]:
		var queued_panel: PanelContainer = queued.panel
		var return_point: Vector2 = game.card_box.global_position + Vector2(game.card_box.size.x * 0.5, game.card_box.size.y * 0.6)
		game._card_press_panel = queued_panel
		game._start_card_drag()
		game._update_card_drag_pose(return_point, Vector2(0, 50))
		game._finish_card_pointer(return_point)
	var duplicate_id: String = str(game.current_hand[0].id)
	var metrics_before_dispatch: Dictionary = GameState.metrics.duplicate(true)
	GameState.dispatched_cards = [{"card_id": duplicate_id, "tier": "effective"}]
	game._sync_dispatched_stage_cards()
	var dispatched_entry: Dictionary = {}
	for entry in game.card_infos:
		if entry.get("dispatched", false) and str(entry.card_id) == duplicate_id:
			dispatched_entry = entry
			break
	check(not dispatched_entry.is_empty() and dispatched_entry.get("staged_by_drag", false),
		"Urgent dispatch immediately appears in the pending table row")
	await get_tree().process_frame
	check(dispatched_entry.panel.size.is_equal_approx(Vector2(122.0, 165.0)),
		"Urgent dispatch uses the same card footprint as a hand card")
	game._card_press_panel = dispatched_entry.panel
	game._start_card_drag()
	check(game._card_dragging, "Urgent dispatch cards can enter the normal drag state")
	game._update_card_drag_pose(queue_drop, Vector2(0.0, -24.0))
	game._finish_card_pointer(queue_drop)
	check(dispatched_entry.get("staged_by_drag", false),
		"Dragging an urgent dispatch keeps it in the ordered table queue")
	check(GameState.metrics == metrics_before_dispatch, "Dispatch staging does not apply its card before settlement")
	game.save_game()
	var save_file := FileAccess.open("user://savegame.json", FileAccess.READ)
	var saved: Dictionary = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	var saved_hand_occurrences := 0
	for saved_id in saved.hand_ids:
		if str(saved_id) == duplicate_id:
			saved_hand_occurrences += 1
	check(saved_hand_occurrences == 1 and saved.staged_queue.size() == 1
		and bool(saved.staged_queue[0].dispatched), "Save keeps the dispatched copy separate from the hand and preserves its queue marker")
	GameState.dispatched_cards = []
	if not dispatched_entry.is_empty():
		game.card_infos.erase(dispatched_entry)
		dispatched_entry.panel.queue_free()
		game._layout_fan()
	game._clear_save()
	await settle(0.5)
	var shake_base: Vector2 = click_panel.position
	var shake_rotation: float = click_panel.rotation
	game._reject_card(click_panel, "测试拒绝反馈")
	var previous_shake_pos: Vector2 = click_panel.position
	var shake_max_step := 0.0
	var shake_max_travel := 0.0
	for frame in 18:
		await get_tree().process_frame
		shake_max_step = maxf(shake_max_step, click_panel.position.distance_to(previous_shake_pos))
		shake_max_travel = maxf(shake_max_travel, click_panel.position.distance_to(shake_base))
		previous_shake_pos = click_panel.position
	check(shake_max_travel > 3.0 and shake_max_step < 8.0, "Rejected-card feedback moves continuously without abrupt shake steps")
	await settle(0.55)
	check(click_panel.position.is_equal_approx(shake_base) and is_equal_approx(click_panel.rotation, shake_rotation),
		"Rejected card settles exactly back to its original pose")
	game._open_deck_viewer()
	await settle(1.8)
	var action_view := await probe_grid(game.deck_viewer_grid, "gyro-deck")
	game._show_card_detail(action_view, action_view.get_meta("card"))
	check(is_zero_approx(action_view.modulate.a), "Detail carry leaves only one visible action-card face")
	check(game._detail_big_card.scale.is_equal_approx(action_view.scale), "Detail starts from the source's current hover scale")
	await settle(0.6)
	await probe_detail(game._detail_big_card, "gyro-action-detail")
	await verify_detail_clicks(game.card_detail, game._detail_big_card, game._on_card_detail_dim_input)
	game._close_card_detail()
	check(is_equal_approx(action_view.modulate.a, 1.0), "Closing action detail restores its source")
	game.wetland.reduced_motion = true
	game._show_card_detail(action_view, action_view.get_meta("card"))
	check(game._detail_big_card.scale.is_equal_approx(Vector2(1.8, 1.8)), "Reduced motion opens the detail at its final scale immediately")
	check(game.card_detail_body.visible_characters == -1, "Reduced motion reveals readable detail text immediately")
	game._close_card_detail()
	check(is_equal_approx(action_view.modulate.a, 1.0), "Reduced-motion close restores its source")
	game.wetland.reduced_motion = false
	game._close_deck_viewer()
	await settle(0.5)
	game._open_dispatch_panel()
	await settle(1.8)
	await probe_grid(game.dispatch_grid, "gyro-dispatch")
	game._close_dispatch_panel()
	Knowledge.reset_all()
	Knowledge.unlock("geo_poyang")
	game._open_knowledge_viewer()
	await settle(1.8)
	await probe_grid(game.knowledge_grid, "gyro-knowledge-locked")
	var knowledge_view: Control = game.knowledge_grid.get_child(8)
	game._show_knowledge_detail(knowledge_view, "geo_poyang")
	check(is_zero_approx(knowledge_view.modulate.a), "Knowledge detail carries a single card face")
	await settle(0.6)
	await probe_detail(game._knowledge_big_card, "gyro-knowledge-detail")
	get_window().size = Vector2i(960, 540)
	game._close_knowledge_detail()
	check(is_equal_approx(knowledge_view.modulate.a, 1.0), "Knowledge detail restores its source across a resize")
	await settle(0.5)
	game._show_knowledge_detail(knowledge_view, "geo_poyang")
	await settle(0.6)
	await probe_detail(game._knowledge_big_card, "gyro-knowledge-small")
	await verify_detail_clicks(game.knowledge_detail, game._knowledge_big_card, game._on_knowledge_detail_dim_input)
	var hud_home := Vector4(game.bottom_right.offset_left, game.bottom_right.offset_top,
		game.bottom_right.offset_right, game.bottom_right.offset_bottom)
	for cycle in 2:
		game._slide_main_ui(true)
		await settle(0.4)
		game._slide_main_ui(false)
		await settle(0.4)
	check(Vector4(game.bottom_right.offset_left, game.bottom_right.offset_top,
		game.bottom_right.offset_right, game.bottom_right.offset_bottom).is_equal_approx(hud_home),
		"Repeated HUD slide cycles restore the bottom-right controls to their fixed anchor")
	await probe_bottom_right_bounds()
	var locked_info: Dictionary = game.card_infos[0]
	locked_info["staged_by_drag"] = true
	locked_info["selected"] = true
	locked_info["stage_order"] = 0
	var locked_panel: PanelContainer = locked_info.panel
	game._layout_fan()
	await settle(0.9)
	var locked_position: Vector2 = locked_panel.position
	var locked_alpha: float = locked_panel.modulate.a
	game.current_hand = GameState.draw_cards(3)
	game.play_deal_anim = true
	game._build_hand_panel(true)
	check(game.card_infos.has(locked_info) and is_instance_valid(locked_panel)
		and locked_info.get("staged_by_drag", false),
		"Refreshing the hand preserves already-staged cards on the table")
	var max_locked_alpha_change := 0.0
	var max_locked_motion := 0.0
	var refresh_end := Time.get_ticks_msec() + 600
	while Time.get_ticks_msec() < refresh_end:
		await get_tree().process_frame
		max_locked_alpha_change = maxf(max_locked_alpha_change, absf(locked_panel.modulate.a - locked_alpha))
		max_locked_motion = maxf(max_locked_motion, locked_panel.position.distance_to(locked_position))
	check(max_locked_alpha_change < 0.001 and max_locked_motion < 0.1,
		"Refreshing animates only new hand cards; staged cards never flash or redeal")
	print("CARD_GYRO: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func probe_bottom_right_bounds() -> void:
	var old_window: Vector2i = get_window().size
	var old_label: String = game.selected_label.text
	var old_dispatch: String = game.dispatch_btn.text
	for window_size in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(960, 720), Vector2i(1600, 720)]:
		get_window().size = window_size
		for long_text in [true, false]:
			game.selected_label.text = "桌面待打出：12 张\n行动位 12/12 · 预算 12345/10000 万\n资金不足，请调整待打出卡牌的顺序和投入档位" if long_text else "拖牌到上方桌面待打出"
			game.dispatch_btn.text = "紧急调度 · 400 万（含待打出预算不足）" if long_text else "紧急调度 · 40 万"
			await settle(0.12)
			check_bottom_right_bounds("Content change")
			game._slide_main_ui(true)
			await settle(0.1)
			game._slide_main_ui(false)
			await settle(0.45)
			check_bottom_right_bounds("Interrupted HUD return")
	get_window().size = old_window
	game.selected_label.text = old_label
	game.dispatch_btn.text = old_dispatch
	await settle(0.2)

func check_bottom_right_bounds(context: String) -> void:
	var screen: Rect2 = get_viewport().get_visible_rect()
	var rect: Rect2 = game.bottom_right.get_global_rect()
	check(rect.position.x >= screen.position.x and rect.position.y >= screen.position.y
		and rect.end.x <= screen.end.x - 17.0 and rect.end.y <= screen.end.y - 13.0,
		context + " keeps the growing action container inside its screen margins")
	for button in [game.hand_sort_btn, game.dispatch_btn, game.refresh_btn, game.end_turn_btn]:
		var button_rect: Rect2 = button.get_global_rect()
		check(screen.encloses(button_rect), context + " keeps every bottom-right button fully on screen")

func probe_hand_sort() -> void:
	await settle(0.5)
	var hand: Array = []
	var staged: Array = []
	for info in game.card_infos:
		if info.get("staged_by_drag", false):
			staged.append({"panel": info.panel, "position": info.panel.position, "alpha": info.panel.modulate.a})
		else:
			hand.append({"panel": info.panel, "z": info.panel.z_index})
	var back: Control = game.deck_backs.back()
	var deck_center: Vector2 = back.get_global_transform() * (back.size * 0.5)
	var expected_scale: Vector2 = back.size / Vector2(122.0, 165.0)
	game._sort_animating = true
	game._sort_hand_cards(false)
	await settle(game.Motion.seconds("gather") + float(hand.size() - 1) * game.Motion.stagger("gather", 1) + 0.03)
	for entry in hand:
		var panel: Control = entry.panel
		var center: Vector2 = panel.get_global_transform() * (panel.size * 0.5)
		check(center.distance_to(deck_center) < float(hand.size()) + 2.0,
			"Sorting gathers cards at the right-side deck UI instead of above the table")
		check(panel.scale.distance_to(expected_scale) < 0.01,
			"Sorting shrinks hand cards to the deck back size before redealing")
		check(panel.z_index >= 1000, "Sorting cards stay above staged cards during their carry")
	await settle(0.08 + game.Motion.seconds("deal") + float(hand.size() - 1) * game.Motion.stagger("deal", 1) + 0.1)
	game._sort_animating = false
	for entry in hand:
		check(entry.panel.scale.is_equal_approx(Vector2.ONE) and entry.panel.z_index == entry.z,
			"Sorted cards return to full hand size and their original draw layer")
	for entry in staged:
		check(entry.panel.position.distance_to(entry.position) < 0.1 and is_equal_approx(entry.panel.modulate.a, entry.alpha),
			"Deck-based hand sorting leaves staged card poses and opacity untouched")

func verify_detail_clicks(detail: Control, big: Control, handler: Callable) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var inverse := detail.get_global_transform().affine_inverse()
	click.position = inverse * game._card_gyro_center(big)
	var previous: int = big.get_meta("poke_count", 0)
	handler.call(click)
	check(detail.visible and not detail.get_meta("closing", false), "Clicking enlarged artwork must keep detail open")
	check(int(big.get_meta("poke_count", 0)) == previous + 1, "Clicking enlarged artwork must poke the card")
	game._step_card_gyro(big, Vector2.ZERO, 0.05)
	check(float(big.get_meta("poke_scale")) < 1.0, "Poke must visibly compress the card")
	for i in 24: game._step_card_gyro(big, Vector2.ZERO, 0.05)
	check(is_equal_approx(float(big.get_meta("poke_scale")), 1.0), "Poke must return to normal size")
	var actual := click.duplicate() as InputEventMouseButton
	actual.position = game._card_gyro_center(big)
	actual.global_position = actual.position
	previous = int(big.get_meta("poke_count", 0))
	get_viewport().push_input(actual, true)
	await settle(0.05)
	actual.pressed = false
	get_viewport().push_input(actual, true)
	check(detail.visible and int(big.get_meta("poke_count", 0)) == previous + 1, "Real GUI card click must poke without falling through to close")
	var info: Control = detail.get_meta("info")
	for point in [info.get_global_rect().get_center(), info.get_global_rect().position + Vector2(4, 4)]:
		click.position = inverse * point
		handler.call(click)
		check(detail.visible and not detail.get_meta("closing", false), "Explanation and its padding must never close detail")
	actual.position = info.get_global_rect().get_center()
	actual.global_position = actual.position
	actual.pressed = true
	get_viewport().push_input(actual, true)
	await settle(0.05)
	actual.pressed = false
	get_viewport().push_input(actual, true)
	check(detail.visible and not detail.get_meta("closing", false), "Real GUI explanation click must stay in detail")
	click.position = Vector2(10, 10)
	handler.call(click)
	check(detail.visible and detail.get_meta("closing", false), "Outside click must start shrink-back animation")
	handler.call(click)
	await settle(0.3)
	check(not detail.visible, "Outside click must return to the parent grid after shrinking")

func verify_hand_edge_stability(info: Dictionary) -> void:
	var panel: PanelContainer = info.panel
	var geometry = preload("res://scripts/card_geometry.gd")
	var face: TextureRect = geometry.face_of(panel)
	var rect: Rect2 = geometry.face_rect(face)
	var relative := panel.get_global_transform().affine_inverse() * face.get_global_transform()
	var theta: float = info.theta
	var origin: Vector2 = info.base_pos + panel.pivot_offset - panel.pivot_offset.rotated(theta)
	var stable: Transform2D = game.card_box.get_global_transform() * Transform2D(theta, Vector2.ONE, 0.0, origin)
	for uv in [Vector2(0.5, 0.985), Vector2(0.5, 0.015), Vector2(0.015, 0.5), Vector2(0.985, 0.5)]:
		for i in 90: game._update_card_hover(1.0 / 60.0, Vector2(-1000, -1000))
		var mouse: Vector2 = stable * relative * (rect.position + uv * rect.size)
		var previous := -1
		var switches := 0
		var last_positions: Dictionary = {}
		var max_movement := 0.0
		for frame in 120:
			game._update_card_hover(1.0 / 60.0, mouse)
			var hovered := -1
			for index in game.card_infos.size():
				var entry: Dictionary = game.card_infos[index]
				if entry.get("hovered", false): hovered = index
				if frame >= 90 and last_positions.has(index):
					max_movement = maxf(max_movement, entry.panel.position.distance_to(last_positions[index]))
				last_positions[index] = entry.panel.position
			if hovered != previous: switches += 1
			previous = hovered
		check(previous >= 0 and switches == 1, "Stationary edge mouse must keep exactly one hover activation")
		check(max_movement < 0.1, "Hand edge position must converge without bouncing")
	for i in 120: game._update_card_hover(1.0 / 60.0, Vector2(-1000, -1000))
	check(game.card_infos.all(func(entry): return not entry.get("hovered", false)), "Mouse outside both regions must release hover")
	check(panel.position.distance_to(info.base_pos) < 0.01, "Card must settle to base position after mouse leaves")
