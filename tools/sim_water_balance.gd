extends SceneTree
## Full-game water balance audit. Run only in an isolated project/user directory.
## -- <games per difficulty/policy> <output JSON path> <first seed, default 70000>
var gs: Node
var talents: Node
var count := 100
var output_path := "res://.godot/water-balance.json"
var first_seed := 70000

func _initialize() -> void:
	call_deferred("audit")

func audit() -> void:
	gs = root.get_node("GameState")
	talents = root.get_node("Talents")
	talents.reset_all()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: count = int(args[0])
	if args.size() > 1: output_path = args[1]
	if args.size() > 2: first_seed = int(args[2])
	var report := {"games_per_group": count, "first_seed": first_seed, "rules": gs.WATER_SEASON_RULES,
		"year_shift": gs.HYDRO_YEAR_SHIFT, "difficulty_inset": gs.WATER_RANGE_INSET,
		"pressure_method": "mean exposure before/after nature", "groups": []}
	for difficulty in 4:
		for policy in ["quiet_water_cycle", "ecology_only", "water_aware"]:
			var group := simulate(difficulty, policy)
			report["groups"].append(group)
			var summary: Dictionary = group.duplicate()
			summary.erase("samples")
			print("WATER_GROUP ", JSON.stringify(summary))
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save balance report: " + output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	print("WATER_BALANCE: saved ", output_path)
	quit()

func simulate(difficulty: int, policy: String) -> Dictionary:
	var total_turns := 0
	var affected_turns := 0
	var low_turns := 0
	var high_turns := 0
	var affected_games := 0
	var survived := 0
	var controls := 0
	var loss_total := 0
	var loss_metrics := {}
	var seasonal := {}
	var traces: Array = []
	for season in gs.SEASONS: seasonal[season] = {"turns": 0, "affected": 0, "loss": 0}
	for i in count:
		gs.difficulty = difficulty
		gs.run_seed = first_seed + i
		gs.reset_game()
		var game_loss := 0
		var trace: Array = []
		while not gs.game_over and gs.turn <= gs.TOTAL_TURNS:
			var season: String = gs.current_season()
			var before_water: int = gs.metrics.water_level
			gs.clear_score_ledger()
			var actions: Array = []
			if policy == "quiet_water_cycle":
				# Control: water-only annual trajectory, no crises/actions/ecological death.
				for metric in gs.metrics:
					if metric != "water_level": gs.metrics[metric] = 100
				gs.used_action_ids = ["water_monitor", "patrol"]
				gs.natural_evolution()
			else:
				var hand: Array = gs.draw_cards(7 + int(talents.get_bonus("cards")), gs.is_season_opener())
				for slot in gs.action_slots():
					var choice := choose(hand, policy)
					if choice.is_empty(): break
					var card: Dictionary = choice["card"]
					hand.erase(card)
					if gs.execute_action(card["id"], choice["tier"]):
						actions.append(card["id"] + ":" + choice["tier"])
						if has_water_effect(card): controls += 1
					if gs.game_over: break
				if not gs.game_over: gs.end_turn()
			var routine_water := before_water
			var loss := 0
			var low := false
			for entry in gs.score_ledger:
				if entry["phase"] != "routine": continue
				if entry["metric"] == "water_level": routine_water = int(entry["after"])
				var label: String = entry["label"]
				if not ("干旱压力" in label or "淹水压力" in label): continue
				var amount := maxi(0, -int(entry["applied"]))
				loss += amount
				low = "干旱压力" in label
				loss_metrics[entry["metric"]] = int(loss_metrics.get(entry["metric"], 0)) + amount
			total_turns += 1
			seasonal[season]["turns"] += 1
			if loss > 0:
				affected_turns += 1
				seasonal[season]["affected"] += 1
				if low: low_turns += 1
				else: high_turns += 1
			seasonal[season]["loss"] += loss
			game_loss += loss
			if i < 2:
				trace.append({"turn": gs.turn, "season": season, "start": before_water,
					"after_nature": routine_water, "final_water": gs.metrics.water_level,
					"water_loss": loss, "actions": actions, "failure": gs.failure_metric if gs.is_failure else ""})
			if policy == "quiet_water_cycle":
				gs.turn += 1
			else:
				if gs.game_over: break
				gs.start_new_turn()
		if game_loss > 0: affected_games += 1
		loss_total += game_loss
		if not gs.is_failure: survived += 1
		if i < 2: traces.append(trace)
	var turns := float(maxi(1, total_turns))
	return {"difficulty": difficulty, "policy": policy, "games": count, "turns": total_turns,
		"affected_games_pct": snappedf(100.0 * affected_games / count, 0.1),
		"affected_turns_pct": snappedf(100.0 * affected_turns / turns, 0.1),
		"low_turns_pct": snappedf(100.0 * low_turns / turns, 0.1), "high_turns_pct": snappedf(100.0 * high_turns / turns, 0.1),
		"avg_water_loss_per_game": snappedf(float(loss_total) / count, 0.01),
		"avg_water_loss_per_turn": snappedf(loss_total / turns, 0.01),
		"avg_water_actions": snappedf(float(controls) / count, 0.01),
		"avg_turns": snappedf(turns / count, 0.01), "survival_pct": snappedf(100.0 * survived / count, 0.1),
		"loss_by_metric": loss_metrics, "seasonal": seasonal, "samples": traces}

func has_water_effect(card: Dictionary) -> bool:
	for tier in card["tiers"].values():
		for effect in tier["effects"]:
			if effect["metric"] == "water_level" and int(effect["delta"]) != 0: return true
	return false

## A reproducible hand-limited heuristic, not a human win-rate estimate.
## Ecology-only never plays water cards; water-aware values pressure relief and next-season fit.
func choose(hand: Array, policy: String) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 0.0
	var weights: Dictionary = {}
	for metric in gs.metrics:
		if metric == "water_level": continue
		var slack: int = int(gs.metrics[metric]) - gs.failure_threshold_for(metric)
		weights[metric] = 3.0 if slack < 12 else (1.8 if slack < 22 else 1.0)
	var baseline_pressure := future_pressure(int(gs.metrics.water_level), weights) if policy == "water_aware" else 0.0
	for card in hand:
		if policy == "ecology_only" and has_water_effect(card): continue
		for tier in ["basic", "effective", "deep"]:
			if not gs.can_execute(card["id"], tier): continue
			var util := 0.0
			var water: int = int(gs.metrics.water_level)
			var safe := true
			for effect in card["tiers"][tier]["effects"]:
				var metric: String = effect["metric"]
				var delta: int = int(effect["delta"])
				if metric == "water_level":
					water = clampi(water + delta, 0, 100)
					continue
				delta = gs._scaled_delta(delta)
				var applied: int = clampi(int(gs.metrics[metric]) + delta, 0, 100) - int(gs.metrics[metric])
				if int(effect["delay"]) == 0 and int(gs.metrics[metric]) + applied < gs.failure_threshold_for(metric) + 2:
					safe = false
				var timing := 1.0 if int(effect["delay"]) == 0 else 0.65
				util += applied * float(weights[metric]) * timing
			if not safe: continue
			if policy == "water_aware" and water != int(gs.metrics.water_level):
				util += baseline_pressure - future_pressure(water, weights)
			var cost: int = gs.tier_cost(card["id"], tier)
			var score: float = util / float(cost + 12)
			if score > best_score:
				best_score = score
				best = {"card": card, "tier": tier}
	return best

func future_pressure(level: int, weights: Dictionary) -> float:
	var value := 0.0
	var index: int = gs.SEASONS.find(gs.current_season())
	for offset in range(mini(3, gs.TOTAL_TURNS - gs.turn + 1)):
		var season: String = gs.SEASONS[(index + offset) % 4]
		var drift: Array = gs.water_drift_range(season, gs.turn + offset)
		var before := level
		level = clampi(level + roundi((int(drift[0]) + int(drift[1])) / 2.0), 0, 100)
		var pressure: Dictionary = gs.water_turn_pressure(before, level, season)
		for metric in pressure["effects"]:
			value += -int(pressure["effects"][metric]) * float(weights[metric]) * pow(0.7, offset)
	return value
