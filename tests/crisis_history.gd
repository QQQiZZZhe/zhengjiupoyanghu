extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	var c: Dictionary = GameState.CRISES[0].duplicate(true)
	for difficulty in 4:
		var state = load("res://scripts/game_state.gd").new()
		state.reset_game()
		state.difficulty = difficulty
		state.turn = 4
		state.record_crisis_notice(c, 1)
		state.record_crisis_notice(c, 1)
		check(state.warn_history.size() == 1, "Repeated notices merge in every mode")
		state.turn = 5
		state.record_crisis_notice(c, 0)
		check(state.warn_history.size() == 1 and state.warn_history[0].hit_turn == 5, "Hit updates the original warning")
		state.warn_history.clear()
		state.pending_crisis = c.duplicate(true)
		state._resolve_pending_crisis()
		check(state.warn_history.size() == 1 and state.warn_history[0].hit_turn == 5, "Hit survives missing warning history")
		state.warn_history.clear()
		state.turn = 6
		state.forecast_crisis = c.duplicate(true)
		state.record_crisis_notice(c, 2)
		state.turn = 7
		state._promote_forecast_if_needed()
		state.record_crisis_notice(c, 1)
		check(state.warn_history.size() == 1 and state.warn_history[0].lead == 2, "Deep warning promotion never duplicates")
		state.turn = 8
		state.record_crisis_notice(c, 0)
		check(state.warn_history.size() == 1 and state.warn_history[0].hit_turn == 8, "Deep warning hit merges")
		state.record_crisis_notice(c, 1)
		check(state.warn_history.size() == 2, "Same crisis in a later turn remains a separate event")
		state.warn_history.clear()
		state.crisis_history.clear()
		state.pending_crisis = c.duplicate(true)
		state.forecast_crisis = GameState.CRISES[1].duplicate(true)
		state.restore_crisis_notices(8)
		state.restore_crisis_notices(8)
		check(state.warn_history.size() == 2, "Old allocation save backfills both notices once")
		var save: Dictionary = state.serialize().duplicate(true)
		state.load_state(save, false)
		state.restore_crisis_notices(8)
		check(state.warn_history == save.warn_history, "New save preserves review history")
		state.warn_history = [{"id": c.id, "turn": 7, "lead": 1, "hit_turn": -1, "value": 55}]
		state.record_crisis_notice(c, 0)
		check(state.warn_history.size() == 1 and state.warn_history[0].value == 55 and state.warn_history[0].hit_turn == 8, "Legacy warning retains its original metric")
		state.free()

	GameState.reset_game()
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(1.0).timeout
	var game: Node = scene.get_node("Game")
	if game._intro_playing: game._finish_intro()
	GameState.turn = 4
	GameState.forecast_crisis = GameState.CRISES[1].duplicate(true)
	game._score_animating = true
	game._on_crisis_warn(c)
	game._on_crisis_warn(c)
	check(GameState.warn_history.size() == 2, "Queued popup immediately records normal and deep warnings exactly once")
	check(game.warn_bar.visible, "Review button refreshes even while crisis popup is queued")
	GameState.turn = 5
	game._on_crisis_hit(c)
	check(GameState.warn_history.size() == 2 and GameState.warn_history[0].hit_turn == 5, "UI hit receipt merges into its warning")
	var row: Control = game._make_warn_row(GameState.warn_history[1])
	check(row.get_child(0).text.contains("待爆发"), "An active forecast is shown as pending rather than ended")
	row.free()
	GameState.warn_history.clear()
	GameState.game_over = true
	game._on_crisis_hit(c)
	check(GameState.warn_history.size() == 1 and GameState.warn_history[0].hit_turn == 5, "A final fatal crisis is recorded before popup suppression")
	print("CRISIS_HISTORY checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
