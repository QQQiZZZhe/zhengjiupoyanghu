extends SceneTree
## 顶部态势播报 + 人鸟矛盾（暗线）的定点自检（0.1.17）
##
## 跑法（工程根目录）：
##   <godot> --headless --path . --script res://tools/verify_situation.gd
## 输出：每行以 "PROBE " 开头的 JSON（人读；机器读就抓这个前缀再 JSON.parse）。
##
## 覆盖：
##  ① 十个定点局面的标签 / 差值 / 判定（水位洪旱、候鸟进田、人鸟矛盾三档）
##  ② 暗线：横幅与事件弹窗里**一个字都不提**人鸟矛盾
##  ③ 真的扣了吗：社区与候鸟各扣多少、流水账并进 routine 相位
##  ④ 难度不放大：同一局面在简单/困难/噩梦档扣的一样多（提示里写多少就扣多少）
##  ⑤ 弹窗规则：叙事节拍必弹；新冒出来的告急弹一次；同一告急持续时不重复弹；回到平稳不弹
##  ⑥ 抽牌偏袒：激化状态下「能抬沉水植被/鱼类的牌」出率明显抬升（对局里不做任何提示）

var fired: Array = []

func _on_ev(t: String) -> void:
	fired.append(str(t).split("\n")[0])


func _initialize() -> void:
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		print("PROBE {\"error\":\"autoload GameState missing\"}")
		quit(1)
		return
	gs.difficulty = 2
	gs.run_seed = 12345

	var cases := [
		{"name": "水位80·夏（洪水）", "turn": 6, "m": {"water_level": 80, "vegetation": 60, "water_quality": 60, "fish": 50, "birds": 45, "community": 60}},
		{"name": "水位41·春（干旱）", "turn": 1, "m": {"water_level": 41, "vegetation": 60, "water_quality": 60, "fish": 50, "birds": 45, "community": 60}},
		{"name": "水位50·春（区间内）", "turn": 1, "m": {"water_level": 50, "vegetation": 60, "water_quality": 60, "fish": 50, "birds": 45, "community": 60}},
		{"name": "水位46·春（小幅偏低·不报警）", "turn": 1, "m": {"water_level": 46, "vegetation": 60, "water_quality": 60, "fish": 50, "birds": 45, "community": 60}},
		{"name": "候鸟66/veg44/fish38（进田·未激化）", "turn": 1, "m": {"water_level": 55, "vegetation": 44, "water_quality": 55, "fish": 38, "birds": 66, "community": 55}},
		{"name": "候鸟62/veg55/fish45（只进田）", "turn": 1, "m": {"water_level": 55, "vegetation": 55, "water_quality": 55, "fish": 45, "birds": 62, "community": 55}},
		{"name": "候鸟50/veg40/fish30（候鸟不够多）", "turn": 1, "m": {"water_level": 55, "vegetation": 40, "water_quality": 55, "fish": 30, "birds": 50, "community": 55}},
		{"name": "候鸟72/veg44/fish38（激化各−2）", "turn": 1, "m": {"water_level": 55, "vegetation": 44, "water_quality": 55, "fish": 38, "birds": 72, "community": 55}},
		{"name": "候鸟75/veg30/fish25", "turn": 1, "m": {"water_level": 55, "vegetation": 30, "water_quality": 55, "fish": 25, "birds": 75, "community": 55}},
		{"name": "候鸟100/veg10/fish0（封顶）", "turn": 1, "m": {"water_level": 55, "vegetation": 10, "water_quality": 55, "fish": 0, "birds": 100, "community": 55}},
		{"name": "候鸟62/veg70/fish49（贴线）", "turn": 1, "m": {"water_level": 55, "vegetation": 70, "water_quality": 55, "fish": 49, "birds": 62, "community": 55}},
	]
	for c in cases:
		gs.turn = int(c["turn"])
		gs.metrics = c["m"].duplicate()
		gs.turn_bird_conflict = {}
		var st: Dictionary = gs.bird_conflict_state()
		var rep: Dictionary = gs.situation_report()
		print("PROBE " + JSON.stringify({
			"case": c["name"], "tags": rep["tags"], "short": rep["short"],
			"index": st["index"], "field": st["field"], "active": st["active"], "penalty": st["penalty"],
		}))

	# ② 暗线：横幅 / 正文里绝不能出现「人鸟矛盾」四个字
	gs.turn = 1
	gs.metrics = {"water_level": 40, "vegetation": 40, "water_quality": 55, "fish": 30, "birds": 80, "community": 55}
	var rep2: Dictionary = gs.situation_report()
	print("PROBE " + JSON.stringify({
		"case": "darkline", "active": bool(gs.bird_conflict_state()["active"]),
		"short": rep2["short"], "body": rep2["body"], "body_has_conflict_word": str(rep2["body"]).contains("人鸟矛盾"),
		"short_has_conflict_word": str(rep2["short"]).contains("人鸟矛盾"), "tags": rep2["tags"],
	}))

	# ③ 应用验证：真的扣了吗
	gs.difficulty = 2
	gs.turn = 6
	gs.metrics = {"water_level": 55, "vegetation": 44, "water_quality": 55, "fish": 38, "birds": 72, "community": 55}
	gs.conflict_history = []
	gs.score_ledger = []
	gs._maybe_bird_conflict()
	print("PROBE " + JSON.stringify({
		"case": "apply", "community": int(gs.metrics["community"]), "birds": int(gs.metrics["birds"]),
		"turn_bird_conflict": gs.turn_bird_conflict, "history": gs.conflict_history, "ledger": gs.score_ledger,
	}))

	# ④ 难度不放大
	for diff in [0, 2, 3]:
		gs.difficulty = diff
		gs.turn = 6
		gs.metrics = {"water_level": 55, "vegetation": 44, "water_quality": 55, "fish": 38, "birds": 72, "community": 55}
		gs._maybe_bird_conflict()
		print("PROBE " + JSON.stringify({
			"case": "difficulty_%d" % diff,
			"d_community": int(gs.metrics["community"]) - 55,
			"d_birds": int(gs.metrics["birds"]) - 72,
		}))
	gs.difficulty = 2

	# ⑤ 弹窗规则
	gs.event_triggered.connect(_on_ev)
	gs.run_seed = 12345
	gs.reset_game()
	var after_reset: int = fired.size()
	gs.metrics = {"water_level": 90, "vegetation": 44, "water_quality": 55, "fish": 38, "birds": 72, "community": 55}
	gs.start_new_turn()
	var after_new: int = fired.size()
	gs.start_new_turn()
	var after_same: int = fired.size()
	gs.metrics = {"water_level": 55, "vegetation": 60, "water_quality": 55, "fish": 60, "birds": 45, "community": 60}
	gs.start_new_turn()
	var after_calm: int = fired.size()
	print("PROBE " + JSON.stringify({
		"case": "popup_rule", "after_reset": after_reset, "after_new_alert": after_new,
		"after_same_alert": after_same, "after_calm": after_calm, "heads": fired,
	}))

	# ⑦ 横幅随状态变（同一回合、只改水位）
	gs.turn = 6
	gs.metrics = {"water_level": 55, "vegetation": 60, "water_quality": 60, "fish": 55, "birds": 45, "community": 60}
	var b_safe: String = gs.situation_banner()
	gs.metrics["water_level"] = 88
	var b_high: String = gs.situation_banner()
	gs.metrics["water_level"] = 30
	var b_low: String = gs.situation_banner()
	print("PROBE " + JSON.stringify({"case": "banner_follows_water", "safe": b_safe, "high": b_high, "low": b_low}))

	# ⑦ 开场 / 收官必须落在**横幅**上（1 与 15 回合），其它回合不能顶着固定台词
	var beats: Array = []
	for t in [1, 3, 11, 15, 16]:
		gs.turn = t
		gs.metrics = {"water_level": 55, "vegetation": 60, "water_quality": 60, "fish": 55, "birds": 45, "community": 60}
		beats.append({"turn": t, "banner": gs.situation_banner()})
	print("PROBE " + JSON.stringify({"case": "banner_beats", "rows": beats}))

	# ⑥ 抽牌偏袒：只让「人鸟矛盾」这一条通路生效（其余指标都不在救火集里），
	#    对比同一局面下有激化 / 无激化时「食源对策卡（生态修复 / 增殖放流）」的进手率。
	var feed_ids: Array = []
	for c in gs.ACTION_CARDS:
		for tag in c.get("tags", []):
			if str(tag) in gs.CONFLICT_FEED_TAGS:
				feed_ids.append(str(c["id"]))
				break
	var trials := 6000
	var neutral := {"water_level": 55, "vegetation": 55, "water_quality": 60, "fish": 50, "birds": 60, "community": 65}
	# 注意：vegetation 50 / fish 46 都刚好在「致死线 + RESCUE_MARGIN」之上，community 65 与 birds 72 同理，
	# 水位 55 在春季参考区间内 → 救火通路与危机对策通路都不参与，剩下的差异就是 CONFLICT_FEED_WEIGHT。
	var conflict := {"water_level": 55, "vegetation": 50, "water_quality": 60, "fish": 46, "birds": 72, "community": 65}
	for pair in [["neutral", neutral], ["conflict", conflict]]:
		gs.turn = 1
		gs.pending_crisis = {}
		gs.metrics = (pair[1] as Dictionary).duplicate()
		gs.used_action_ids = []
		var any := 0
		var slots := 0
		for _i in trials:
			var hand: Array = gs.draw_cards(7)
			var got := false
			for c in hand:
				if feed_ids.has(str(c["id"])):
					got = true
					slots += 1
			if got:
				any += 1
		print("PROBE " + JSON.stringify({
			"case": "feed_" + str(pair[0]), "hand_has_feed_pct": snappedf(float(any) * 100.0 / float(trials), 0.01),
			"feed_per_hand": snappedf(float(slots) / float(trials), 0.001),
			"feed_ids": feed_ids.size(), "spring_pool": gs.season_pool().size(), "all_cards": gs.ACTION_CARDS.size(),
			"trials": trials,
		}))

	quit(0)
