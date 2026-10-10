extends RefCounted

static func drop_on_board(game: Node, info: Dictionary) -> void:
	var panel: Control = info.panel
	var origin: Vector2 = panel.get_global_transform() * (panel.size * 0.5)
	game._card_press_panel = panel
	game._card_press_origin = origin
	game._start_card_drag()
	game._card_drag_grab_point = panel.size * 0.5
	var destination: Vector2 = game.staged_board.get_global_rect().get_center()
	game._update_card_drag_pose(destination, destination - origin)
	game._finish_card_pointer(destination)

static func retract(game: Node, info: Dictionary) -> void:
	var panel: Control = info.panel
	var origin: Vector2 = panel.get_global_transform() * (panel.size * 0.5)
	game._card_press_panel = panel
	game._card_press_origin = origin
	game._start_card_drag()
	game._card_drag_grab_point = panel.size * 0.5
	var destination := origin + Vector2(0, 100)
	game._update_card_drag_pose(destination, Vector2(0, 100))
	game._finish_card_pointer(destination)
