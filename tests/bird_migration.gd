extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fixture(state: Node, difficulty: int, at_turn: int, birds: int = 65) -> void:
	state.reset_game()
	state.difficulty = difficulty
	state.turn = at_turn
	state.run_seed = 20261010
	state.metrics = {"water_level": [52, 60, 58, 46][(at_turn - 1) % 4], "water_quality": 60, "vegetation": 60, "fish": 70, "birds": birds, "community": 70}
	state.used_action_ids = ["water_monitor", "patrol"]
	state._is_settlement_preview = true
func _ready() -> void:
	Talents.reset_all()
	var state = load("res://scripts/game_state.gd").new()
	var actual = load("res://scripts/game_state.gd").new()
	for difficulty in 4:
		for at_turn in range(1, 17):
			fixture(state, difficulty, at_turn)
			var delta: int = state.BIRD_MIGRATION_DELTA[state.current_season()]
			var snapshot: Dictionary = state.serialize().duplicate(true)
			seed(9182)
			var expected_rng := randi()
			seed(9182)
			var preview: Dictionary = state.preview_settlement([])
			check(randi() == expected_rng and state.serialize() == snapshot, "Migration preview is read-only and preserves RNG")
			var hover: Dictionary = state.metric_hover_preview("birds")
			check(hover.end_min == 65 + delta and hover.end_max == 65 + delta, "Hover includes the same seasonal migration")
			actual.load_state(snapshot, false)
			actual._is_settlement_preview = true
			actual.end_turn()
			check(preview == actual.metrics and actual.metrics.birds == 65 + delta, "Forecast and settlement agree in every season, year and difficulty")
			var ledger: Array = actual.score_ledger.filter(func(e): return e.metric == "birds" and e.label == state.BIRD_MIGRATION_REASON[state.current_season()])
			check(not ledger.is_empty(), "Seasonal migration is visible in settlement feedback")
		var population := 65
		var seasons: Array[int] = []
		for at_turn in range(1, 5):
			fixture(state, difficulty, at_turn, population)
			state.natural_evolution()
			population = state.metrics.birds
			seasons.append(population)
		check(seasons[3] > seasons[0] and seasons[0] > seasons[1] and seasons[2] > seasons[1] and seasons[3] > seasons[2], "Winter peaks, spring declines, summer bottoms, autumn recovers")
		check(population == 65, "Migration alone cannot cause annual population drift")
	for birds in [0, 100]:
		for at_turn in range(1, 5):
			fixture(state, 0, at_turn, birds)
			state.natural_evolution()
			check(state.metrics.birds >= 0 and state.metrics.birds <= 100, "Migration respects metric limits")
	fixture(state, 2, 3)
	var saved: Dictionary = state.serialize().duplicate(true)
	actual.load_state(saved, false)
	check(actual.preview_settlement([]) == state.preview_settlement([]), "Reloading preserves migration forecast")
	state.free()
	actual.free()
	print("BIRD_MIGRATION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
