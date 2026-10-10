extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var gs: Node = root.get_node("GameState")
	var game: Node = load("res://tests/fixtures/bgm_probe.gd").new()
	root.add_child(game)
	game._setup_bgm()
	gs.difficulty = gs.Difficulty.NORMAL
	gs.turn = 3
	gs.run_seed = 12345
	gs.game_over = false
	gs.used_action_ids = []
	gs.pending_crisis = {}
	gs.music_crisis_recovery = {}
	gs.metrics = {"water_level": 55, "vegetation": 80, "water_quality": 80, "fish": 80, "birds": 80, "community": 80}
	game._playing = true
	game._current_phase = "allocate"
	game._update_bgm_state()
	check(game.bgm_index == 0 and game.bgm_player.pitch_scale == 1.0, "Safe game must use theme at normal speed")
	check(game._bgm_streams[0].loop and game._bgm_streams[1].loop, "Both tracks must loop")
	check(game._bgm_streams[0].get_length() > 0 and game._bgm_streams[1].get_length() > 0, "Both MP3 assets must decode")
	var crisis: Dictionary = gs.CRISES[2].duplicate(true)
	gs.pending_crisis = crisis
	game._update_bgm_state()
	check(game.bgm_index == 1 and game.bgm_player.pitch_scale == 1.0, "Crisis must switch immediately at normal speed")
	gs._resolve_pending_crisis()
	for effect in crisis["effects"]:
		if int(effect["delta"]) < 0:
			var metric: String = str(effect["metric"])
			var expected := int(gs.metrics[metric]) + ceili(absf(float(effect["delta"])) * 0.5)
			check(int(gs.music_crisis_recovery[metric]) == expected, "Recovery must require only half the crisis damage")
	game._update_bgm_state()
	check(game.bgm_index == 1 and not gs.music_crisis_recovery.is_empty(), "Crisis damage must keep danger music after warning disappears")
	var saved: Dictionary = gs.serialize()
	gs.music_crisis_recovery = {}
	gs.load_state(saved)
	check(gs.has_unresolved_music_crisis(), "Unresolved crisis must survive save/load")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("music_crisis_recovery_ratio")
	legacy["music_crisis_recovery"] = {"fish": 80}
	gs.load_state(legacy)
	check(int(gs.music_crisis_recovery["fish"]) == int(gs.metrics["fish"]) + ceili((80 - int(gs.metrics["fish"])) * 0.5), "Old saves must lower remaining recovery effort by half")
	gs.load_state(saved)
	for metric in gs.music_crisis_recovery:
		gs.metrics[metric] = int(gs.music_crisis_recovery[metric]) - 1
	game._update_bgm_state()
	check(game.bgm_index == 1, "One point below recovery threshold must still keep danger music")
	for metric in gs.music_crisis_recovery:
		gs.metrics[metric] = int(gs.music_crisis_recovery[metric])
	game._update_bgm_state()
	check(game.bgm_index == 0 and is_equal_approx(game.bgm_player.pitch_scale, 0.75), "Repair must start slow theme transition")
	await create_timer(1.0).timeout
	check(game.bgm_player.pitch_scale > 0.75 and game.bgm_player.pitch_scale < 1.0, "Theme must accelerate gradually")
	gs.pending_crisis = crisis
	game._update_bgm_state()
	check(game.bgm_index == 1 and game.bgm_player.pitch_scale == 1.0, "New crisis must interrupt recovery and reset speed")
	gs.pending_crisis = {}
	game._update_bgm_state()
	await create_timer(3.2).timeout
	check(is_equal_approx(game.bgm_player.pitch_scale, 1.0), "Recovery must finish at normal speed")
	gs.metrics["water_quality"] = gs.failure_threshold_for("water_quality")
	check(gs.metric_hover_preview("water_quality")["break_total"], "Fixture must predict imminent failure")
	game._update_bgm_state()
	check(game.bgm_index == 1, "Imminent failure without a crisis must trigger danger")
	game._current_phase = "popup_settlement"
	game._update_bgm_state()
	check(game.bgm_index == 1, "Settlement popup must not prematurely clear danger")
	game._current_phase = "allocate"
	gs.metrics["water_quality"] = gs.failure_threshold_for("water_quality") - gs._scaled_delta(-2)
	check(not gs.metric_hover_preview("water_quality")["break_total"], "Ending exactly on the threshold must be safe")
	game._update_bgm_state()
	check(game.bgm_index == 0, "Safe threshold boundary must return to theme")
	gs.metrics["water_quality"] = 80
	game._update_bgm_state()
	check(game.bgm_index == 0, "Repairing imminent failure must return to theme")
	# Water has no direct failure threshold; extreme water alone is not fatal.
	gs.metrics["water_level"] = 0
	gs.metrics["vegetation"] = 100
	game._update_bgm_state()
	check(game.bgm_index == 0, "Water must not be compared with an invented failure threshold")
	gs.game_over = true
	gs.is_failure = true
	game._update_bgm_state()
	check(game.bgm_index == 1, "Failure report must retain danger music")
	game._playing = false
	game._update_bgm_state()
	check(game.bgm_index == 0 and game.bgm_player.pitch_scale == 1.0, "Main menu must restore normal theme")
	game.free()
	# Allow killed/bound tweens and audio resources to finish tree cleanup.
	await process_frame
	await process_frame
	print("BGM_CHECKS %d FAILURES %d" % [checks, failures])
	quit(1 if failures else 0)
