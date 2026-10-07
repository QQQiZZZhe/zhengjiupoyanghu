extends SceneTree
## 指标价值诊断台：直接驱动真实引擎代码跑完整对局，量化「某几项指标是不是没用」
##
## 用法（在工程根目录）：
##   <godot> --headless --path . --script res://tools/sim_metrics.gd
## 输出：
##   stdout 以 "SIMJSON " 开头的一行 = 机器可读结果
##
## 设计要点
## 1) 每个策略都用**同一批种子**（1000+i），所以开局六项指标逐局一致 → 策略间可对照。
## 2) 策略 = 「每回合从哪个卡池里随机挑牌」，用来做反事实：
##      baseline      全卡池随机（基准）
##      force_X       只从「能抬升 X 的牌」里挑 → 量化「把钱投在 X 上的边际收益」
##      force_weakest 每回合改救「离致死线最近的那一项」（会玩的玩家参照系）
## 3) 纯只读的额外统计：自然演化每回合净漂移、危机伤害按指标分布、各项终值。

const N_GAMES := 400
const DIFF := 2                     # 默认难度 0=简单 1=普通 2=困难（可被命令行覆盖）
const TIER_ROLL := {"basic": 0.45, "effective": 0.40, "deep": 0.15}

var GS: Node
var Tal: Node
var METRICS_ORDER: Array = []
var N := N_GAMES
var DIFFICULTY := DIFF
## 本次允许出的档位。默认三档全开（= 引擎数据层的能力）；
## 传 "effective" 则模拟**当前真实对局**（出牌界面把档位写死成 effective，见 main.gd）。
var TIERS_ALLOWED: Array = ["basic", "effective", "deep"]

func _initialize() -> void:
	# 命令行：-- <难度 0/1/2> <局数>
	var uargs := OS.get_cmdline_user_args()
	if uargs.size() >= 1 and str(uargs[0]).is_valid_int():
		DIFFICULTY = int(uargs[0])
	if uargs.size() >= 2 and str(uargs[1]).is_valid_int():
		N = int(uargs[1])
	if uargs.size() >= 3:
		# 第三参数 = 允许的档位，"all" / 空 / 缺省都表示三档全开。
		# ⚠ 曾经把字面量 "all" 直接 split 成档位名 → tier_cost(id,"all") 全线报错、机器人一张牌都打不出。
		var ta := str(uargs[2]).strip_edges()
		if ta != "" and ta != "all":
			TIERS_ALLOWED = ta.split(",")
	var t0 := Time.get_ticks_msec()
	GS = root.get_node_or_null("GameState")
	Tal = root.get_node_or_null("Talents")
	if GS == null or Tal == null:
		print("SIMJSON " + JSON.stringify({"error": "autoload missing: GameState=%s Talents=%s" % [str(GS), str(Tal)]}))
		quit(1); return

	Tal.reset_all()                 # 新玩家状态：不引入跨局天赋加成
	GS.difficulty = DIFFICULTY
	METRICS_ORDER = GS.metrics.keys() if not GS.metrics.is_empty() else ["water_level", "water_quality", "vegetation", "fish", "birds", "community"]

	var out := {
		"n_games": N, "difficulty": DIFFICULTY,
		# 名字表按 GameState.Difficulty 的顺序排；加档位时要同步加，否则下标越界
		"difficulty_name": ["简单", "普通", "困难", "噩梦"][DIFFICULTY],
		"turns": GS.TOTAL_TURNS, "action_slots": GS.action_slots(),
		"tiers_allowed": TIERS_ALLOWED,
		"funding_per_turn": GS.BASE_FUNDING - int(GS.FUNDING_PENALTY[DIFFICULTY]) - GS.OPERATION_COST,
		"thresholds": {},
		"metrics": METRICS_ORDER,
		"strategies": {},
	}
	for m in METRICS_ORDER:
		out["thresholds"][str(m)] = GS.failure_threshold_for(str(m))

	var pools := _build_pools()
	out["pool_sizes"] = {}
	for k in pools:
		out["pool_sizes"][str(k)] = int(pools[k].size())

	# 先跑基准，作为对照锚
	for name in ["baseline", "force_water_level", "force_water_quality", "force_vegetation", "force_fish", "force_birds", "force_community", "force_weakest", "greedy", "greedy_abs", "income", "ban_birds", "ban_community"]:
		out["strategies"][name] = _run(name, pools.get(name, []))
	out["funding_steps"] = GS.FUNDING_STEPS

	out["elapsed_ms"] = Time.get_ticks_msec() - t0
	print("SIMJSON " + JSON.stringify(out))
	quit(0)


## 卡池：按「这张牌能不能抬升某项指标（任一档有正向 delta 即算）」分类
func _build_pools() -> Dictionary:
	var pools := {"baseline": [], "force_weakest": [], "greedy": [], "greedy_abs": [], "income": []}
	for m in METRICS_ORDER:
		pools["force_" + str(m)] = []
	pools["ban_birds"] = []
	pools["ban_community"] = []
	for c in GS.ACTION_CARDS:
		var cid := str(c["id"])
		pools["baseline"].append(cid)
		pools["force_weakest"].append(cid)
		pools["greedy"].append(cid)
		pools["greedy_abs"].append(cid)
		pools["income"].append(cid)
		if not _raises(c, "birds"):
			pools["ban_birds"].append(cid)
		if not _raises(c, "community"):
			pools["ban_community"].append(cid)
		for m in METRICS_ORDER:
			if _raises(c, str(m)):
				pools["force_" + str(m)].append(cid)
	return pools


func _raises(card: Dictionary, metric: String) -> bool:
	for tier in card["tiers"].values():
		for e in tier["effects"]:
			if str(e["metric"]) == metric and int(e["delta"]) > 0:
				return true
	return false


func _pick_for(strategy: String, pool: Array) -> String:
	if pool.is_empty():
		return ""
	if strategy == "force_weakest":
		# 找离致死线最近（相对缓冲最小）的一项，只从这个池子里挑
		var worst := ""
		var worst_slack := 9999
		for m in METRICS_ORDER:
			var slack: int = int(GS.metrics.get(m, 0)) - GS.failure_threshold_for(str(m))
			if slack < worst_slack:
				worst_slack = slack
				worst = str(m)
		var sub: Array = []
		for c in GS.ACTION_CARDS:
			if _raises(c, worst):
				sub.append(str(c["id"]))
		if not sub.is_empty():
			return str(sub[randi() % sub.size()])
	return str(pool[randi() % pool.size()])


## 统一的选牌入口。返回 {"id":..., "tier":...} 或 {}（本次不出牌）。
## greedy = 专家策略代理：把「每个可行 (卡,档)」的价值都算一遍再挑最高的那个。
func _choose(strategy: String, pool: Array) -> Dictionary:
	if strategy == "greedy" or strategy == "greedy_abs" or strategy == "income":
		return _greedy_choice(strategy == "greedy_abs", strategy == "income")
	# 随机策略：最多试 8 次，直到抽到一张钱够的（与改动前行为一致）
	for attempt in 8:
		var cid := _pick_for(strategy, pool)
		if cid == "":
			return {}
		for tier in [_roll_tier()] + TIERS_ALLOWED:
			if GS.can_execute(cid, tier):
				return {"id": cid, "tier": tier}
	return {}


## 专家代理（严格版）：在 greedy_abs 之上加「不许自伤」——
## 任何一条副作用会把某指标压到「致死线 + 3」以内的牌，直接不出。
## 理由：乱打副作用牌在困难档会被 ×2.0 放大，是「钱越多反而死越快」的假象来源。
## income=true 时额外给「跨过拨款阶梯」的牌加分 —— 这是「懂规则、会去投资指标换钱」的代理。
func _greedy_choice(absolute: bool = false, income: bool = false) -> Dictionary:
	var counter: Array = GS.counter_card_ids()
	var best := {}
	var best_score := -1e18
	for c in GS.ACTION_CARDS:
		var cid := str(c["id"])
		var is_counter: bool = cid in counter
		for tier in TIERS_ALLOWED:
			if not GS.can_execute(cid, tier):
				continue
			var cost: int = int(GS.tier_cost(cid, tier))
			var util := 0.0
			var self_harm := false
			var per_metric := {}
			for e in c["tiers"][tier]["effects"]:
				var m := str(e["metric"])
				var d := float(e["delta"])
				if int(e["delay"]) <= 0:
					per_metric[m] = float(per_metric.get(m, 0.0)) + d
				if d < 0:
					d *= 2.0          # 困难档负向翻倍，与引擎口径一致
					if float(GS.metrics.get(m, 0)) + d < float(GS.failure_threshold_for(m)) + 3.0:
						self_harm = true
				if int(e["delay"]) > 0:
					d *= 0.5          # 延迟到手的打折
				var slack: int = int(GS.metrics.get(m, 0)) - GS.failure_threshold_for(m)
				var w := 1.0
				if slack < 12:
					w = 3.0
				elif slack < 20:
					w = 1.5
				util += d * w
			if self_harm:
				continue
			if income:
				# 跨档奖励：这一步正好把某项从阈值下推到阈值上 → 一次性记 15 点效用
				# （≈ 一档拨款 10 万 = 约 1/3 张卡的价钱，别高估。）
				for metric in GS.FUNDING_STEPS:
					var cur_m: float = float(GS.metrics.get(metric, 0))
					var after_m: float = cur_m + float(per_metric.get(metric, 0.0))
					for step in GS.FUNDING_STEPS[metric]:
						var thr: int = int(step[0])
						if thr > 0 and int(step[1]) > 0 and cur_m < float(thr) and after_m >= float(thr):
							util += 15.0
							break
			if is_counter:
				util *= 1.3
			if util <= 0.0:
				continue
			var sc: float = util + util / float(maxi(1, cost)) * 60.0 if absolute else util / float(maxi(1, cost)) * 100.0 + util * 0.05
			if sc > best_score:
				best_score = sc
				best = {"id": cid, "tier": tier}
	if best.is_empty():
		# 没有正收益的牌：挑最便宜的一张先垫着（保留资金）
		var cheapest := {}
		var c_min := 99999
		for c in GS.ACTION_CARDS:
			var cid2 := str(c["id"])
			if GS.can_execute(cid2, "basic"):
				var cc: int = int(GS.tier_cost(cid2, "basic"))
				if cc < c_min:
					c_min = cc
					cheapest = {"id": cid2, "tier": "basic"}
		return cheapest
	return best


func _run(strategy: String, pool: Array) -> Dictionary:
	var deaths := {}
	var crisis_count := {}
	var drift := {}          # 每项：自然演化累计净漂移
	var drift_turns := 0
	var crisis_dmg := {}     # 每项：危机造成的累计负伤害
	var final_sum := {}
	var final_min := {}
	var final_arr := {}
	for m in METRICS_ORDER:
		drift[str(m)] = 0
		crisis_dmg[str(m)] = 0
		final_sum[str(m)] = 0
		final_min[str(m)] = 999
		final_arr[str(m)] = []
	var survived := 0
	var turns_sum := 0
	# 0.1.17 人鸟矛盾：触发率 / 触发回合数 / 累计扣减，用来判「会不会随便就激化」
	var conflict_games := 0
	var conflict_hits := 0
	var conflict_pen := 0
	var field_turns := 0
	# 差值直方图（桶宽 4）：阈值该怎么定，直接看这张分布表 ——
	# 记的是**回合末判定那一刻**的差值（出牌后、自然涨落前），也就是真正拿去比阈值的那一个数。
	var index_hist := {}
	var field_index_hist := {}
	var pen_hist := {}
	var spent_sum := 0
	var cards_sum := 0
	var plays_sum := 0
	var money_sum := 0
	var metric_fund_sum := 0
	var score_sum := {"eco": 0.0, "social": 0.0, "manage": 0.0, "avg": 0.0}

	for i in N:
		seed(1000 + i)                 # 全局 RNG：开局指标与整局随机都与 i 绑定
		GS.run_seed = 1000 + i
		GS.reset_game()
		seed(1000 + i)
		var guard := 0
		while not GS.game_over and guard < 40:
			guard += 1
			# 本回合开局（= 玩家看到顶部横幅与悬停小窗的那一刻）的候鸟食源态势
			if bool(GS.bird_conflict_state()["field"]):
				field_turns += 1
			money_sum += int(GS.funds)                 # 本回合开局可支配资金
			metric_fund_sum += int(GS.last_metric_funding)
			# 自然演化净漂移（只读推演，不改状态）
			for e in GS.natural_evolution_plan(false):
				var mm := str(e["metric"])
				if drift.has(mm):
					drift[mm] = int(drift[mm]) + int(e["delta"])
			drift_turns += 1
			# 用满行动位
			var acts: int = int(GS.action_slots())
			if GS.turn == 1:
				acts += int(Tal.get_bonus("first_turn_actions"))
			for a in acts:
				var choice: Dictionary = _choose(strategy, pool)
				if choice.is_empty():
					break
				if GS.execute_action(str(choice["id"]), str(choice["tier"])):
					plays_sum += 1
				if GS.game_over:
					break
			if GS.game_over:
				break
			# 差值分布（桶宽 4）：判定用的就是这一刻的值（这一手打完、自然涨落之前）
			var idx: int = int(GS.bird_conflict_state()["index"])
			var bucket: int = (idx / 4) * 4
			index_hist[bucket] = int(index_hist.get(bucket, 0)) + 1
			if bool(GS.bird_conflict_state()["field"]):
				field_index_hist[bucket] = int(field_index_hist.get(bucket, 0)) + 1
			GS.end_turn()
			# 危机统计：本回合末爆发的危机（crisis_history 最后一条）
			if not GS.crisis_history.is_empty():
				var last: Dictionary = GS.crisis_history[GS.crisis_history.size() - 1]
				if int(last["turn"]) == GS.turn:
					var cid2 := str(last["id"])
					crisis_count[cid2] = int(crisis_count.get(cid2, 0)) + 1
					var cdef: Dictionary = GS.crisis_by_id(cid2)
					for e2 in cdef.get("effects", []):
						var mm2 := str(e2["metric"])
						if int(e2["delta"]) < 0 and crisis_dmg.has(mm2):
							# 困难档负向倍率不作用于危机伤害（见 _apply_delta），原值即可
							crisis_dmg[mm2] = int(crisis_dmg[mm2]) + int(e2["delta"])
			if GS.game_over:
				break
			GS.start_new_turn()

		var ch: Array = GS.conflict_history
		if not ch.is_empty():
			conflict_games += 1
			conflict_hits += ch.size()
			for ce in ch:
				conflict_pen += int(ce["penalty"])
				var pk: int = int(ce["penalty"])
				pen_hist[pk] = int(pen_hist.get(pk, 0)) + 1

		if GS.is_failure:
			var fm := str(GS.failure_metric)
			deaths[fm] = int(deaths.get(fm, 0)) + 1
		else:
			survived += 1
		turns_sum += GS.turn
		spent_sum += GS.total_spent
		cards_sum += GS.used_action_ids.size()   # 仅最后一回合，另附按局统计见下
		for m in METRICS_ORDER:
			var v: int = int(GS.metrics.get(str(m), 0))
			final_sum[m] = int(final_sum[m]) + v
			if v < int(final_min[m]):
				final_min[m] = v
			final_arr[m].append(v)
		var rep: Dictionary = GS.generate_report()
		score_sum["eco"] += float(rep["eco"]["score"])
		score_sum["social"] += float(rep["social"]["score"])
		score_sum["manage"] += float(rep["manage"]["score"])
		score_sum["avg"] += (float(rep["eco"]["score"]) + float(rep["social"]["score"]) + float(rep["manage"]["score"])) / 3.0

	var n := float(N)
	var res := {
		"survival_rate": snappedf(float(survived) / n, 0.0001),
		"deaths": deaths,
		"avg_turns": snappedf(float(turns_sum) / n, 0.01),
		"avg_spent_wan": snappedf(float(spent_sum) / n, 0.1),
		"avg_plays_per_game": snappedf(float(plays_sum) / n, 0.01),
		"avg_plays_per_turn": snappedf(float(plays_sum) / maxf(1.0, float(turns_sum)), 0.01),
		"avg_cards_last_turn": snappedf(float(cards_sum) / n, 0.01),
		"avg_money_per_turn": snappedf(float(money_sum) / maxf(1.0, float(drift_turns)), 0.01),
		"avg_metric_funding": snappedf(float(metric_fund_sum) / maxf(1.0, float(drift_turns)), 0.01),
		"avg_final": {}, "median_final": {}, "p10_final": {},
		"avg_natural_drift_per_turn": {},
		"crisis_hits": crisis_count, "crisis_dmg_by_metric": crisis_dmg,
		"conflict": {
			"games_with_conflict": conflict_games,
			"rate_of_games": snappedf(float(conflict_games) / n, 0.0001),
			"hits_per_game": snappedf(float(conflict_hits) / n, 0.01),
			"penalty_per_game": snappedf(float(conflict_pen) / n, 0.01),
			"penalty_per_hit": snappedf(float(conflict_pen) / maxf(1.0, float(conflict_hits)), 0.01),
			"field_turns_per_game": snappedf(float(field_turns) / n, 0.01),
			"index_hist_bin4": index_hist, "field_index_hist_bin4": field_index_hist, "pen_hist": pen_hist,
			"threshold": GS.CONFLICT_THRESHOLD, "bird_min": GS.BIRD_SURPLUS_MIN, "food_line": GS.FOOD_SHORT_LINE,
		},
		"avg_score": {"eco": snappedf(score_sum["eco"] / n, 0.01), "social": snappedf(score_sum["social"] / n, 0.01), "manage": snappedf(score_sum["manage"] / n, 0.01), "avg": snappedf(score_sum["avg"] / n, 0.01)},
	}
	for m in METRICS_ORDER:
		var arr: Array = final_arr[m]
		arr.sort()
		res["avg_final"][str(m)] = snappedf(float(final_sum[m]) / n, 0.01)
		res["median_final"][str(m)] = int(arr[int(arr.size() * 0.5)])
		res["p10_final"][str(m)] = int(arr[int(arr.size() * 0.1)])
		res["avg_natural_drift_per_turn"][str(m)] = snappedf(float(drift[str(m)]) / maxf(1.0, float(drift_turns)), 0.001)
	return res



func _roll_tier() -> String:
	if TIERS_ALLOWED.size() == 1:
		return str(TIERS_ALLOWED[0])
	var r := randf()
	var acc := 0.0
	for t in TIERS_ALLOWED:
		acc += float(TIER_ROLL[t])
		if r <= acc:
			return t
	return str(TIERS_ALLOWED[0])
