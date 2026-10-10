extends Node

const Motion = preload("res://scripts/motion.gd")
## Presentation only: no changes to cards, tiers, selection or game saves.
var game: Node
var hand_layer: Control
var hud_layer: Control
var hud_tween: Tween
var view_button: Button
var collapsed := false
var hand_tween: Tween
var _last_layout: Array = []
var _paused_tweens: Array[Tween] = []
var _was_paused := false
var _rest_offsets: Dictionary = {}
var board_cards_attached := false
var _board_cards: Array[Control] = []

func _attach_board_cards() -> void:
	if board_cards_attached: return
	board_cards_attached = true
	for info in game.card_infos:
		if info.get("stage_zone", "") != "board": continue
		var panel: Control = info["panel"]
		game.CardFlight.stop(panel)
		game._finish_queue_flight(info, panel)
		for key in ["position", "scale", "rotation"]: game.MotionSpring.stop(panel, key)
		panel.reparent(game.staged_board, true)
		_board_cards.append(panel)

func _detach_board_cards() -> void:
	if not board_cards_attached: return
	for panel in _board_cards:
		if is_instance_valid(panel): panel.reparent(game.card_box, true)
	_board_cards.clear()
	board_cards_attached = false
	var staged: Array = []
	for index in game._ordered_staged_indices(): staged.append(game.card_infos[index])
	game._layout_staged_cards(staged)

func configure(owner_game: Node, canvas: CanvasLayer) -> void:
	game = owner_game
	for control in [game.hand_panel, game.tier_lever, game.left_panel, game.event_label]:
		_rest_offsets[control] = Vector2(control.offset_left, control.offset_top)
	# Animate a wrapper, leaving the hand panel's offsets and card-local
	# coordinates untouched for deck transitions, hovering and flying cards.
	hand_layer = Control.new()
	hand_layer.name = "HandVisibility"
	hand_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hand_layer)
	canvas.move_child(hand_layer, game.hand_panel.get_index())
	game.hand_panel.reparent(hand_layer, false)
	# 常驻 HUD 放进独立包裹层，保留原锚点和卡牌/牌库动画的局部坐标。
	hud_layer = Control.new()
	hud_layer.name = "HudVisibility"
	hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud_layer)
	canvas.move_child(hud_layer, 0)
	var hud_controls: Array = [game.left_panel, game.right_panel, game.staged_board, game.event_label,
		game.bottom_right, game.tier_lever, game.deck_root]
	for child in canvas.get_children():
		if child is ColorRect: hud_controls.append(child)
	for control in hud_controls:
		if control != null:
			control.reparent(hud_layer, false)
			if control is ColorRect: hud_layer.move_child(control, 0)
	view_button = game._make_button("查看沙盘", toggle_view, 14)
	view_button.name = "SandpanViewButton"
	view_button.custom_minimum_size = Vector2(136, 36)
	view_button.size = Vector2(136, 36)
	view_button.tooltip_text = "收起手牌与其他界面查看沙盘；再次点击恢复，保留已选卡牌与投入档位。"
	canvas.add_child(view_button)
	# Keep popups and metric tips above the new entry point.
	canvas.move_child(view_button, game.popup_root.get_index())
	view_button.hide()

func _blocked() -> bool:
	return game._cards_waiting_for_board() or game._deck_open or game.popup_root.visible or game.crisis_root.visible or (game.dispatch_panel != null and game.dispatch_panel.visible)

func invalidate_layout() -> void:
	_last_layout.clear()

func _in_allocate() -> bool:
	return game._playing and game._current_phase == "allocate" and game.hand_panel.visible and not game._score_animating

func _process(_delta: float) -> void:
	if not game: return
	set_paused(game._paused)
	if game._paused: return
	if not _in_allocate() and collapsed:
		_restore_hand_immediately()
	var viewport_size := get_viewport().get_visible_rect().size
	var key: Array = [viewport_size, get_window().size, game._fan_layout_size, game.card_infos.size(),
		_in_allocate(), _blocked(), collapsed, game.get_node("UICanvas").visible]
	if key == _last_layout: return
	_last_layout = key
	var active: bool = _in_allocate() and not _blocked() and game.get_node("UICanvas").visible
	view_button.visible = active
	view_button.text = "展开手牌" if collapsed else "查看沙盘"
	_place_button(viewport_size)
	var focus := 0.0
	var zoom := 1.0
	if active and not collapsed:
		# Reserve a stable hand footprint; playing/retracting cards must not move the map.
		var hand_top := _rest_position(game.hand_panel).y + 55.0
		var clearance := viewport_size.y - hand_top
		focus = minf(clampf(clearance * 0.34, 48.0, 100.0), viewport_size.y * 0.12) / viewport_size.y
		if get_window().size.y <= 600: zoom = 1.08
	game.wetland.set_hand_view(focus, zoom)
	# Finish an interrupted slide at the correct distance after a window resize.
	if collapsed: _animate_hand(true)

func _hand_top() -> float:
	var rest := _rest_position(game.hand_panel)
	var slide_delta: Vector2 = game.hand_panel.global_position - hand_layer.position - rest
	var top := rest.y + 55.0
	if game.card_infos.is_empty(): return top
	top = INF
	for info in game.card_infos:
		if info.get("staged_by_drag", false): continue
		var panel: Control = info["panel"]
		for corner in [Vector2.ZERO, Vector2(panel.size.x, 0), panel.size, Vector2(0, panel.size.y)]:
			var point: Vector2 = game.card_box.global_position - hand_layer.position - slide_delta + info["base_pos"] + panel.pivot_offset
			point += ((corner - panel.pivot_offset) * 1.06).rotated(float(info["theta"]))
			top = minf(top, point.y - game.CARD_RAISE)
	return top if is_finite(top) else rest.y + 55.0

func _rest_position(control: Control) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	return viewport_size * Vector2(control.anchor_left, control.anchor_top) + (_rest_offsets[control] as Vector2)

func _place_button(viewport_size: Vector2) -> void:
	if collapsed:
		view_button.position = Vector2(18, viewport_size.y - 54)
		return
	var lever: Control = game.tier_lever
	var status: Control = game.left_panel
	var lever_position := _rest_position(lever)
	var y := lever_position.y - 44.0
	if y >= _rest_position(status).y + status.size.y + 8.0:
		view_button.position = Vector2(lever_position.x + (lever.size.x - 136.0) * 0.5, y)
	else:
		var event: Control = game.event_label
		view_button.position = Vector2((viewport_size.x - 136.0) * 0.5, _rest_position(event).y + event.size.y + 8.0)

func set_paused(paused: bool) -> void:
	if paused == _was_paused: return
	_was_paused = paused
	if paused:
		for tween in [hand_tween, hud_tween, game.wetland.hand_view_tween]:
			if tween and tween.is_valid() and tween.is_running():
				tween.pause()
				_paused_tweens.append(tween)
	else:
		for tween in _paused_tweens:
			if tween and tween.is_valid(): tween.play()
		_paused_tweens.clear()

func toggle_view() -> void:
	if not _in_allocate() or _blocked() or game._paused or game._sort_animating: return
	collapsed = not collapsed
	_animate_hand(collapsed)
	_last_layout.clear()

func _animate_hand(hide_hand: bool) -> void:
	_animate_hud(hide_hand)
	if hand_tween and hand_tween.is_valid(): hand_tween.kill()
	hand_layer.show()
	var distance: float = get_viewport().get_visible_rect().size.y - _hand_top() + 32.0
	var target := Vector2(0, distance if hide_hand else 0.0)
	if game.wetland.reduced_motion:
		hand_layer.position = target
		if hide_hand: hand_layer.hide()
		else: _detach_board_cards()
		return
	hand_tween = Motion.tween(self, "focus", "hand")
	hand_tween.tween_property(hand_layer, "position", target, 0.26)
	if hide_hand: hand_tween.tween_callback(hand_layer.hide)
	else: hand_tween.tween_callback(_detach_board_cards)

func _animate_hud(hide_hud: bool) -> void:
	if hud_tween and hud_tween.is_valid(): hud_tween.kill()
	_attach_board_cards()
	hud_layer.show()
	if hide_hud and game.metric_tip: game.metric_tip.hide()
	var target := Vector2(get_viewport().get_visible_rect().size.x + 64.0 if hide_hud else 0.0, 0)
	if game.wetland.reduced_motion:
		hud_layer.position = target
		if hide_hud: hud_layer.hide()
		return
	hud_tween = Motion.tween(self, "focus", "hud")
	hud_tween.tween_property(hud_layer, "position", target, 0.26)
	if hide_hud: hud_tween.tween_callback(hud_layer.hide)

func _restore_hand_immediately() -> void:
	if hand_tween and hand_tween.is_valid(): hand_tween.kill()
	if hud_tween and hud_tween.is_valid(): hud_tween.kill()
	hud_layer.position = Vector2.ZERO
	hud_layer.show()
	collapsed = false
	hand_layer.position = Vector2.ZERO
	hand_layer.show()
	_detach_board_cards()
	game._update_sort_cooldown()
	_last_layout.clear()

func prepare_settlement() -> void:
	_restore_hand_immediately()
	view_button.hide()
	game.wetland.set_hand_view(0.0, 1.0)
