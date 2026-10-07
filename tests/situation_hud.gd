extends Node
## 0.1.17 顶部态势横幅 + 指标悬停小窗「人鸟矛盾」的真窗口取证。
##
## 跑法（必须先造隔离副本，别在活工程里跑 —— 开局会 _clear_save()）：
##   python tests/prepare_visual_test.py situation_hud      → 打印副本目录
##   副本里先 <godot> --headless --path <副本> --import
##   再     POYANG_SCREENSHOT_DIR=<活工程>/docs/screenshots \
##          <godot> --path <副本> res://tests/situation_hud.tscn --resolution 1280x720
##
## 断言覆盖：横幅随水位实时变（同一局、只改水位）、候鸟进田/人鸟矛盾播报、
## 悬停小窗写明回合末扣多少与差值、水位小窗与横幅同一条线。

var game: Node
var failures: Array[String] = []
var checks: int = 0
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle(seconds: float = 0.4) -> void:
	await get_tree().create_timer(seconds).timeout


## 去掉 BBCode，只留玩家真正看到的字（断言写在「看得见的话」上，不写在标签上）
func plain_bb(s: String) -> String:
	var re := RegEx.new()
	re.compile("\\[/?[^\\]]+\\]")
	return re.sub(s, "", true)

func capture(label: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var p := output_dir.path_join(label + ".png")
	get_viewport().get_texture().get_image().save_png(p)
	print("SHOT " + p)

func _set_metrics(m: Dictionary) -> void:
	GameState.metrics = m.duplicate()
	game._update_hud()
	await settle(0.7)


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle(0.4)
	if game._intro_playing:
		game._finish_intro()
	await settle(1.4)
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.HARD)
	game.seed_input.text = "20261007"
	game._on_start_pressed()
	# 天赋弹窗 + 第 1 回合态势弹窗（弹窗正文有打字机，第一次点补全、第二次点关掉）
	for i in 24:
		if not game.popup_root.visible:
			break
		game._on_popup_button()
		await settle(0.15)
	check(game._current_phase == "allocate", "开局后应停在分配阶段，实际 " + str(game._current_phase))

	# ⓪ 第 1 回合：横幅必须是开场那句台词（玩测反馈：开头文字要出现在事件幅里，不能只在弹窗）
	print("BANNER_TURN1 " + game.event_label.text)
	check(game.event_label.text.contains("【开场】") and game.event_label.text.contains("开启你的第一个决策"),
		"第 1 回合横幅应是开场台词，实际「" + game.event_label.text + "」")
	check(not game.event_label.text.contains("枯水") and not game.event_label.text.contains("告急"),
		"开场不该断言当下生态（开局六项是按种子掷的），实际「" + game.event_label.text + "」")
	await capture("0.1.17-事件幅-开场")

	# 之后把回合推到 3（仍是春季，参考区间不变），让横幅回到「现场态势」而不是固定台词
	GameState.turn = 3
	game._update_hud()
	await settle(0.3)
	check(not game.event_label.text.contains("【开场】"),
		"非 1/15 回合横幅不该再顶着开场台词，实际「" + game.event_label.text + "」")

	# ① 候鸟 72 / 沉水植被 44 / 鱼类 38 → 差值 (72−44)+(72−38) = 62 ≥ 48，回合末各扣 2。
	#    ⚠ 这是暗线：横幅只给「候鸟进田」这条线索，**不许出现「人鸟矛盾」**。
	await _set_metrics({"water_level": 55, "vegetation": 44, "water_quality": 55, "fish": 38, "birds": 72, "community": 55})
	var st: Dictionary = GameState.bird_conflict_state()
	check(int(st["index"]) == 62 and bool(st["active"]) and int(st["penalty"]) == 2,
		"差值 62 应判激化且扣 2，实际 " + str(st))
	print("BANNER_CONFLICT " + game.event_label.text)
	check(game.event_label.text.contains("白鹤进入稻田") and game.event_label.text.contains("人鸟冲突"),
		"横幅应照原版口径描述情况（社区报告那条），实际「" + game.event_label.text + "」")
	check(not game.event_label.text.contains("人鸟矛盾"), "横幅不该点名「人鸟矛盾」（暗线），实际「" + game.event_label.text + "」")
	check(not game.event_label.text.contains("激化"), "横幅不该出现「激化」字样，实际「" + game.event_label.text + "」")
	check(not game.event_label.text.contains("62") and not game.event_label.text.contains("食源"),
		"横幅只描述情况、不报数字，实际「" + game.event_label.text + "」")
	await capture("0.1.17-顶部态势-人鸟矛盾")

	# ② 悬停「社区信任」：扣值必须并进「自然演化」那一栏，与其它自然扣值显示在一起
	game.set_process(false)   # 冻结每帧刷新，否则真实鼠标下一帧就把小窗收掉
	var row: Control = game.metric_bars["community"]["row"]
	game._update_metric_tip(row.get_global_rect().get_center())
	await settle(0.35)
	var cbody: String = plain_bb(game.metric_tip_body.text).replace("\n", " / ")
	print("TOOLTIP_COMMUNITY " + cbody)
	check(game.metric_tip.visible, "社区信任的悬停小窗应可见")
	check(cbody.contains("自然演化（含洪旱联动）   -2"),
		"自然演化那一栏应把这笔扣减算进去（显示在同一处），实际「" + cbody + "」")
	check(cbody.contains("· 其中人鸟矛盾 −2"), "小窗应有一行安静的来源小计，实际「" + cbody + "」")
	check(cbody.contains("回合末约   53"), "回合末约应把这一笔算进去（55−2=53），实际「" + cbody + "」")
	check(cbody.contains("回合末余量   3"), "回合末余量也要跟着变（53−红线50=3），实际「" + cbody + "」")
	check(not cbody.contains("⚠ 人鸟矛盾"), "小窗不该用人鸟矛盾做醒目告警，实际「" + cbody + "」")
	await capture("0.1.17-悬停详情-人鸟矛盾")

	# ③ 同一局、只改水位：横幅必须跟着水位走（这一版之前是「第 3 回合必报干旱」的念稿）
	game.set_process(true)
	await _set_metrics({"water_level": 88, "vegetation": 44, "water_quality": 55, "fish": 38, "birds": 72, "community": 55})
	print("BANNER_HIGH " + game.event_label.text)
	check(game.event_label.text.contains("洪水风险"), "水位 88 应描述成洪水风险，实际「" + game.event_label.text + "」")
	check(not game.event_label.text.contains("参考") and not game.event_label.text.contains("水位 8"),
		"横幅只描述情况、不报参考区间与数值，实际「" + game.event_label.text + "」")
	await capture("0.1.17-顶部态势-洪水")

	await _set_metrics({"water_level": 30, "vegetation": 44, "water_quality": 55, "fish": 38, "birds": 72, "community": 55})
	print("BANNER_LOW " + game.event_label.text)
	check(game.event_label.text.contains("干旱风险"), "水位 30 应描述成干旱风险，实际「" + game.event_label.text + "」")
	await capture("0.1.17-顶部态势-干旱")

	# ④ 水位悬停小窗与横幅同一条线（偏离 ≥ 4 点才叫预警）
	game.set_process(false)
	var wrow: Control = game.metric_bars["water_level"]["row"]
	game._update_metric_tip(wrow.get_global_rect().get_center())
	await settle(0.35)
	var wbody: String = game.metric_tip_body.text.replace("\n", " / ")
	print("TOOLTIP_WATER " + wbody)
	check(wbody.contains("干旱预警"), "水位小窗应给出干旱预警，实际「" + wbody + "」")
	await capture("0.1.17-悬停详情-干旱")

	# ⑤ 水位回到区间内：横幅回到「平稳」，小窗不再给预警
	#    ⚠ 第 1 回合是春季，参考区间 49–61（困难档内缩后），所以「平稳」要取区间内的值
	game.set_process(true)
	await _set_metrics({"water_level": 55, "vegetation": 60, "water_quality": 60, "fish": 55, "birds": 45, "community": 60})
	print("BANNER_SAFE " + game.event_label.text)
	check(game.event_label.text.contains("暂无异常"), "水位 55（春 49–61 区间内）应描述成暂无异常，实际「" + game.event_label.text + "」")
	await capture("0.1.17-顶部态势-平稳")

	# ⑥ 第 15 回合：横幅必须是收官那句（同样按反馈要求放在事件幅里）
	GameState.turn = 15    # 冬季，困难档参考 38–48
	await _set_metrics({"water_level": 43, "vegetation": 55, "water_quality": 55, "fish": 50, "birds": 45, "community": 60})
	print("BANNER_TURN15 " + game.event_label.text)
	check(game.event_label.text.contains("【收官】") and game.event_label.text.contains("准备验收最终成果"),
		"第 15 回合横幅应是收官台词，实际「" + game.event_label.text + "」")
	await capture("0.1.17-事件幅-收官")

	print("SITUATION_HUD checks=%d failures=%d" % [checks, failures.size()])
	for f in failures:
		print("FAIL " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)
