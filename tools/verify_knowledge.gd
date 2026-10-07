extends SceneTree
## 「知识卡收集」体检（0.1.2）—— 与 verify_prices / verify_talents 同类：
## 动过 scripts/knowledge.gd 或 GameState.KNOWLEDGE_CARDS 之后跑一遍。
## 用法：<godot> --headless --path . --script res://tools/verify_knowledge.gd
##
## ⚠ 会读/写 user://knowledge.json。测完把原文件**逐字节恢复**，绝不动玩家的收集进度。

const SAVE := "user://knowledge.json"

var fails := 0
var checks := 0
var backup := ""
var had_file := false


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("   ✗ " + msg)


func _initialize() -> void:
	var GS: Node = root.get_node_or_null("GameState")
	var K: Node = root.get_node_or_null("Knowledge")
	if GS == null or K == null:
		print("FAIL: autoload 缺失（GameState / Knowledge）")
		quit(1)
		return

	# --- 备份玩家存档 ---
	had_file = FileAccess.file_exists(SAVE)
	if had_file:
		var f := FileAccess.open(SAVE, FileAccess.READ)
		backup = f.get_as_text()
		f.close()

	# ① 数据源：40 张知识卡，字段齐全，旧卡顺序稳定
	var ids: Array = K.all_ids()
	_check(ids.size() == 40, "知识卡应为 40 张，实际 %d" % ids.size())
	var legacy := ["plant_kucao", "bird_baihe", "bird_xiaotiane", "bird_dongfang", "mech_water_quality", "mech_fushouluo", "cons_disease", "cons_compensate"]
	_check(ids.slice(0, 8) == legacy, "原有 8 张知识卡的 id 与顺序不变")
	var action_ids := {}
	var tags := {}
	for action in GS.ACTION_CARDS:
		action_ids[action["id"]] = true
		for tag in action.get("tags", []):
			tags[tag] = true
	_check(ids.size() == GS.KNOWLEDGE_CARDS.size(), "all_ids 与 KNOWLEDGE_CARDS 数量不一致")
	_check(K.total_count() == ids.size(), "total_count 不等于 id 数量")
	var required := ["name", "category", "short", "ecology", "threat", "management", "condition"]
	for kid in ids:
		for field in required:
			_check(GS.KNOWLEDGE_CARDS[kid].has(field), "知识卡 %s 缺字段 %s" % [kid, field])
		var card: Dictionary = GS.KNOWLEDGE_CARDS[kid]
		if kid in legacy:
			continue
		_check(not str(card.get("source_title", "")).is_empty(), "%s 应有来源标题" % kid)
		_check(str(card.get("source_url", "")).begins_with("https://"), "%s 应有 HTTPS 来源" % kid)
		for tag in card.get("tags", []):
			_check(tags.has(tag), "%s 的标签不存在：%s" % [kid, tag])
		for action_id in card.get("action_ids", []):
			_check(action_ids.has(action_id), "%s 的行动不存在：%s" % [kid, action_id])
			GS.turn = 0
			GS.used_action_ids = [action_id]
			_check(GS._knowledge_condition_met(card), "%s 应由行动 %s 触发" % [kid, action_id])
		GS.used_action_ids = []
		for season in card.get("seasons", []):
			var index := ["春", "夏", "秋", "冬"].find(season)
			_check(index >= 0, "%s 季节应有效" % kid)
			GS.turn = index + 1
			_check(GS._knowledge_condition_met(card), "%s 应由季节 %s 触发" % [kid, season])
	GS.turn = 0
	GS.used_action_ids = []
	GS._knowledge_rng.seed = 20261004
	_check(not GS._knowledge_condition_met({}), "没有条件的卡不应必然触发")
	GS.turn = 1
	_check(GS._knowledge_condition_met(GS.KNOWLEDGE_CARDS["geo_poyang"]), "首回合应触发认识鄱阳湖")
	GS.turn = 0
	print("① 数据源：%d 张知识卡，字段 %d 项齐全" % [ids.size(), required.size()])

	# ② 全新收集：默认一张都没有
	K.reset_all()
	_check(K.collected_count() == 0, "reset_all 后 collected_count 应为 0")
	for kid in ids:
		_check(not K.is_collected(str(kid)), "reset_all 后 %s 仍标记为已收集" % kid)
	print("② 初始状态：0 / %d" % K.total_count())

	# ③ 收集与幂等
	var first := str(ids[0])
	_check(K.unlock(first), "首次 unlock 应返回 true")
	_check(not K.unlock(first), "重复 unlock 应返回 false")
	_check(K.is_collected(first), "unlock 后 is_collected 应为 true")
	_check(K.collected_count() == 1, "收集 1 张后 collected_count 应为 1")
	print("③ 收集：%s → 1 / %d（重复调用被幂等拦下）" % [first, K.total_count()])

	# ④ 持久化：文件真的写出来了，而且是合法 JSON、能读回
	var f2 := FileAccess.open(SAVE, FileAccess.READ)
	_check(f2 != null, "收集后应写出 %s" % SAVE)
	if f2 != null:
		var text := f2.get_as_text()
		f2.close()
		var data = JSON.parse_string(text)
		_check(data is Dictionary, "存档应是 JSON 对象")
		if data is Dictionary:
			_check(bool(data.get(first, false)), "存档里应记下 %s" % first)
	print("④ 持久化：%s 已写盘且可解析" % SAVE)

	# ⑤ 非法 id 不该被记下
	_check(not K.unlock("no_such_card"), "unlock 不存在的 id 应返回 false")
	_check(K.collected_count() == 1, "非法 id 不该改变收集数")

	# ⑥ 全收集
	for kid in ids:
		K.unlock(str(kid))
	_check(K.collected_count() == ids.size(), "全收集后应为 %d" % ids.size())
	print("⑤⑥ 幂等 / 全收集：%d / %d" % [K.collected_count(), K.total_count()])
	K.reset_all()
	for kid in legacy:
		K.unlock(kid)
	K._load()
	_check(K.collected_count() == 8, "旧版收藏文件应保持 8 / 40")
	for kid in legacy:
		_check(K.is_collected(kid), "旧收藏应保留：%s" % kid)
	for i in 100:
		_check(not GS._pick_knowledge(ids, {}) in legacy, "仍有新卡时优先补齐未收藏卡")
	for kid in ids:
		K.unlock(kid)

	# ⑦ 回合末随机赠送：把所有 condition 都堵死（六项指标全 100 → 一条都不满足），
	#    于是剩下的命中只可能来自随机那条线，统计频率就该落在设定概率附近。
	var granted := 0
	var trials := 400
	var doubled := 0
	for i in trials:
		GS.knowledge_unlocked = []
		GS.pending_knowledge = []
		GS.knowledge_last_turn = -99    # 绕过节拍闸门，这一组只量「随机线本身的概率」
		for m in GS.metrics:
			GS.metrics[m] = 100
		GS._check_knowledge_triggers()
		if GS.pending_knowledge.size() > 1:
			doubled += 1
		granted += GS.pending_knowledge.size()
	var expect := float(trials) * float(GS.KNOWLEDGE_RANDOM_CHANCE)
	_check(granted > expect * 0.6 and granted < expect * 1.4,
		"随机赠送频率应接近设定概率：%d / %d（期望约 %d）" % [granted, trials, int(expect)])
	_check(doubled == 0, "一次检查最多赠送一张，实际有 %d 次是两张" % doubled)
	print("⑦ 回合末随机赠送：%d / %d 次命中（概率 %.2f，期望约 %d）" % [granted, trials, GS.KNOWLEDGE_RANDOM_CHANCE, int(expect)])

	# ⑧ 条件触发命中时不该再叠一张随机（否则一回合连弹两个弹窗）
	GS.knowledge_unlocked = []
	GS.pending_knowledge = []
	GS.knowledge_last_turn = -99
	for m in GS.metrics:
		GS.metrics[m] = 100
	GS.metrics["water_quality"] = 34      # 只满足 cons_disease 的 condition
	GS._check_knowledge_triggers()
	_check(GS.pending_knowledge == ["cons_disease"],
		"条件命中时应只弹条件那张、不叠随机，实际 %s" % str(GS.pending_knowledge))
	print("⑧ 条件命中不叠随机：%s" % str(GS.pending_knowledge))

	# ⑨ 节拍：一回合最多一张 + 出了卡的下一回合必定安静
	GS.knowledge_unlocked = []
	GS.pending_knowledge = []
	GS.knowledge_last_turn = -99
	for m in GS.metrics:
		GS.metrics[m] = 100
	GS.metrics["water_quality"] = 34        # cons_disease 条件命中 → 必出
	GS._check_knowledge_triggers()
	_check(GS.pending_knowledge.size() == 1,
		"条件命中时应正好出一张，实际 %d 张" % GS.pending_knowledge.size())
	var first_pick: String = str(GS.pending_knowledge[0]) if GS.pending_knowledge.size() > 0 else ""
	GS.pending_knowledge = []
	GS.turn += 1
	GS._check_knowledge_triggers()          # 紧接着的下一回合：必须安静
	_check(GS.pending_knowledge.is_empty(),
		"出过卡的下一回合必须安静，实际又出了 %s" % str(GS.pending_knowledge))
	print("⑨ 节拍：出了「%s」之后，下一回合不再出" % first_pick)
	GS.turn += 1
	GS._check_knowledge_triggers()
	_check(GS.pending_knowledge.size() == 1, "间隔一回合后应可以再次触发知识卡")

	# ⑩ 标签加权：命中标签的卡权重要更高
	var pool: Array = GS.KNOWLEDGE_CARDS.keys()
	var with_tags := {}
	var no_tags := {}
	for i in 600:
		var a: String = GS._pick_knowledge(pool, {"水体治理": true})
		with_tags[a] = int(with_tags.get(a, 0)) + 1
		var b: String = GS._pick_knowledge(pool, {})
		no_tags[b] = int(no_tags.get(b, 0)) + 1
	var hit_cards := 0
	var hit_plain := 0
	for kid in GS.KNOWLEDGE_CARDS:
		if "水体治理" in GS.KNOWLEDGE_CARDS[kid].get("tags", []):
			hit_cards += int(with_tags.get(kid, 0))
			hit_plain += int(no_tags.get(kid, 0))
	_check(hit_cards > hit_plain * 1.5,
		"带「水体治理」标签的卡在加权后应明显更容易出（%d vs %d）" % [hit_cards, hit_plain])
	print("⑩ 标签加权：600 次里带「水体治理」的卡被抽中 %d 次（无权重时应约 %d 次）" % [hit_cards, hit_plain])

	# --- 恢复玩家存档（逐字节）---
	K.reset_all()
	if had_file:
		var f3 := FileAccess.open(SAVE, FileAccess.WRITE)
		f3.store_string(backup)
		f3.close()
		print("已恢复原 %s" % SAVE)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
		print("原无 %s，已删除测试产物" % SAVE)

	print("")
	if fails == 0:
		print("✅ 全部通过：%d 项检查" % checks)
	else:
		print("❌ %d / %d 项失败" % [fails, checks])
	quit(0 if fails == 0 else 1)
