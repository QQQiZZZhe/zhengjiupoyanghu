extends Node
## 《拯救鄱阳湖》—— 回合制生态管理模拟
## GameState 单例：数据 + 核心结算逻辑。UI/3D 表现由 main.gd 驱动。

# ==================== 常量 ====================
const TOTAL_TURNS := 16          # 一局 16 回合 = 4 年 × 4 季

# ==================== 季节 ====================
# 季节由回合号推导：第 1~4 回合 = 春/夏/秋/冬，第 5 回合又是春（第 2 年）。
# ⚠ 全工程唯一的推导处 —— 界面上的季节 Label 也调 current_season()，别各写一套 %4。
# 卡池分季的依据是鄱阳湖的水文节律：春涨水、夏高水、秋落水、冬枯水。
const SEASONS := ["spring", "summer", "autumn", "winter"]
const SEASON_NAMES := {"spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬"}
# 迁徙改变在湖候鸟数量，四季合计为零；自然迁出不按难度放大。
const BIRD_MIGRATION_DELTA := {"spring": -4, "summer": -3, "autumn": 3, "winter": 4}
const BIRD_MIGRATION_REASON := {
	"spring": "春季迁出（越冬候鸟北迁）",
	"summer": "夏季低谷（候鸟在北方繁殖）",
	"autumn": "秋季迁入（越冬候鸟陆续抵达）",
	"winter": "冬季越冬（在湖候鸟达到高峰）",
}
# 每季一句旁白：抽牌界面顶部用，把季节分类变成沉浸式科普
const SEASON_TAGLINE := {
	"spring": "五河来水，鱼群启程回家",
	"summer": "高水漫滩，以守为攻",
	"autumn": "水落洲出，黄金筹备季",
	"winter": "碟形湖登场，人鸟面对面",
}

# 0–100 水文指数，非实测米数。区间端点包含在内，各季重叠以留出调度空间。
const WATER_SEASON_RULES := {
	"spring": {"low": 48, "high": 62, "drift": [3, 6], "theme": "涨水育苗、鱼类繁殖",
		"low_loss": {"vegetation": 2, "water_quality": 1, "fish": 2},
		"high_loss": {"vegetation": 3, "fish": 1}},
	"summer": {"low": 58, "high": 74, "drift": [5, 9], "theme": "丰水连通、预留防洪空间",
		"low_loss": {"vegetation": 3, "water_quality": 2, "fish": 3},
		"high_loss": {"vegetation": 3, "water_quality": 1, "community": 1}},
	"autumn": {"low": 44, "high": 60, "drift": [-8, -4], "theme": "渐次退水、露滩备食",
		"low_loss": {"vegetation": 2, "water_quality": 1, "fish": 2, "birds": 1},
		"high_loss": {"vegetation": 2, "birds": 2}},
	"winter": {"low": 36, "high": 50, "drift": [-6, -3], "theme": "保留浅水、守护越冬觅食地",
		"low_loss": {"vegetation": 2, "water_quality": 1, "fish": 1, "birds": 2},
		"high_loss": {"vegetation": 2, "birds": 3}},
}
const WATER_PRESSURE_SPAN := 10.0
const WATER_PRESSURE_CAP := 3.0
const HYDRO_YEAR_SHIFT := 1
# 高难度收窄管理窗口；洪旱损失仍独立按难度倍率计算。
const WATER_RANGE_INSET := [0, 0, 1, 2]

## 年内来水偏差保持四季连续，独立随机流；可从种子重建，预览/读档不掷新天气。
func year_hydrology(at_turn: int = -1) -> Dictionary:
	var t: int = turn if at_turn < 0 else at_turn
	var year: int = int((maxi(1, t) - 1) / 4) + 1
	var weather_rng := RandomNumberGenerator.new()
	weather_rng.seed = run_seed + year * 104729 + 0x57415445
	var roll := weather_rng.randi_range(0, 99)
	var shift := -HYDRO_YEAR_SHIFT if roll < 30 else (HYDRO_YEAR_SHIFT if roll >= 70 else 0)
	return {"year": year, "shift": shift, "name": "偏旱年" if shift < 0 else ("偏湿年" if shift > 0 else "平水年")}

func water_drift_range(season: String = "", at_turn: int = -1) -> Array:
	var base: Array = water_reference(season)["drift"]
	var shift: int = int(year_hydrology(at_turn)["shift"])
	return [int(base[0]) + shift, int(base[1]) + shift]

func water_reference(season: String = "") -> Dictionary:
	var rule: Dictionary = WATER_SEASON_RULES.get(current_season() if season.is_empty() else season, WATER_SEASON_RULES["spring"]).duplicate(true)
	var inset: int = WATER_RANGE_INSET[difficulty]
	rule["low"] = int(rule["low"]) + inset
	rule["high"] = int(rule["high"]) - inset
	return rule

## 每偏离 10 点为 1 倍，连续增加，最多 3 倍；难度只放大生态损失，不放大退水。
func water_pressure(level: int, season: String = "") -> Dictionary:
	var rule := water_reference(season)
	var low: int = int(rule["low"])
	var high: int = int(rule["high"])
	var side := "low" if level < low else ("high" if level > high else "safe")
	var deviation: int = maxi(low - level, level - high) if side != "safe" else 0
	var multiplier: float = minf(WATER_PRESSURE_CAP, deviation / WATER_PRESSURE_SPAN)
	var effects: Dictionary = {}
	if side != "safe":
		for metric in rule[side + "_loss"]:
			var loss: int = roundi(float(rule[side + "_loss"][metric]) * multiplier * float(PENALTY_MULT[difficulty]))
			# 刚越界时至少损失 1 点植被；其他影响按整数精度渐次出现。
			if metric == "vegetation": loss = maxi(1, loss)
			if loss > 0: effects[metric] = -loss
	return {"low": low, "high": high, "side": side, "deviation": deviation,
		"multiplier": multiplier, "effects": effects}

## 洪旱损害取行动后与自然涨落后两端的平均暴露；自然恢复减轻压力，不能追溯抹去损害。
func water_turn_pressure(before: int, after: int, season: String = "") -> Dictionary:
	var start := water_pressure(before, season)
	var finish := water_pressure(after, season)
	var rule := water_reference(season)
	var low_mult: float = ((float(start["multiplier"]) if start["side"] == "low" else 0.0) + (float(finish["multiplier"]) if finish["side"] == "low" else 0.0)) * 0.5
	var high_mult: float = ((float(start["multiplier"]) if start["side"] == "high" else 0.0) + (float(finish["multiplier"]) if finish["side"] == "high" else 0.0)) * 0.5
	var effects: Dictionary = {}
	for metric in METRIC_NAMES:
		var base_loss: float = float(rule["low_loss"].get(metric, 0)) * low_mult + float(rule["high_loss"].get(metric, 0)) * high_mult
		var loss: int = roundi(base_loss * float(PENALTY_MULT[difficulty]))
		if metric == "vegetation" and low_mult + high_mult > 0.0: loss = maxi(1, loss)
		if loss > 0: effects[metric] = -loss
	return {"low": rule["low"], "high": rule["high"], "effects": effects,
		"side": "low" if low_mult > high_mult else ("high" if high_mult > 0.0 else "safe"),
		"multiplier": low_mult + high_mult, "before": before, "after": after}

# ==================== 紧急调度 / 刷新手牌 ====================
# 紧急调度：花固定一笔钱，直接从**当季卡池**里点名一张牌当场使用 ——
# 解决「眼看着要崩、手上偏偏没有那张救命的牌」。定位是容错阀而不是主力：
# 价格固定且偏高、一次只能调一张、**不占行动位**，但结算与常规出牌合并在同一段算分动画里播。
# 每局首次可直接用，之后每用一次要空 DISPATCH_COOLDOWN_TURNS 个回合。
const DISPATCH_COST := 40                # **首次**使用的价格（万）
const DISPATCH_PRICE_STEP := 10          # 本局每再用一次，价格 +10 万（40 → 50 → 60 …）
const DISPATCH_COOLDOWN_TURNS := 3       # 两次使用之间要空出的回合数
const DISPATCH_TIER := "effective"       # 一律按**有效投入**档结算：调度费买不到深度档的双倍效果

# 刷新手牌：抽得不满意，花小钱把整手重抽一遍。每回合限一次。
const REFRESH_HAND_COST := 5             # （万）

const BASE_FUNDING := 100        # 每回合基础拨款（万）
const OPERATION_COST := 20       # 固定运营支出（万）
const MAX_CARRY := 60            # 结转上限（万）
const INTEREST_RATE := 0.05      # 结转利息（每回合，利滚利，利率从低）

# 难度档位：简单 / 普通 / 困难 / 噩梦
enum Difficulty { EASY, NORMAL, HARD, NIGHTMARE }

# 各难度参数（简单 / 普通 / 困难 / 噩梦）
#
# ★ 噩梦档 = 本项目**刚分出三档难度时（提交 995f784）那个困难档的原样照搬**：
#   六项指标共用一条 45 的红线、开局下限 48、负向 ×2.0、拨款削减 35、危机概率 0.68/0.28，
#   而且当时**既没有每指标红线偏移、也没有开局保护**（见 failure_threshold_for 与
#   _guard_starting_metrics 里对 NIGHTMARE 的特判）。
#   于是开局只离死 3~5 点，一回合水位最坏 -9 就直接出局 ——
#   反馈原话「大概率活不过第二回合」说的就是这套参数。
#   ⚠ 动这几个数字之前先想清楚：它的"乐趣"完全来自"几乎必死"，
#     别顺手把它调平衡了（平衡版的困难档已经存在，就是上面的 HARD）。
const FAILURE_THRESHOLD := { Difficulty.EASY: 20, Difficulty.NORMAL: 30, Difficulty.HARD: 40, Difficulty.NIGHTMARE: 45 }   # 判负阈值
const PENALTY_MULT := { Difficulty.EASY: 1.0, Difficulty.NORMAL: 1.5, Difficulty.HARD: 2.0, Difficulty.NIGHTMARE: 2.0 }     # 扣分惩罚倍率

# 0.1.3：水位退出致死判定；难度倍率只放大生态损失，水文涨落不放大。
const FUNDING_PENALTY := { Difficulty.EASY: 0, Difficulty.NORMAL: 20, Difficulty.HARD: 35, Difficulty.NIGHTMARE: 35 }       # 每回合拨款削减（万）

# ==================== 指标 → 每回合拨款（2026-09-28 第二条玩测反馈）====================
# 反馈原话：「在困难模式里有几个数值，比如社会信任和候鸟，感觉没啥用」。
#
# 量化诊断（tools/sim_metrics.gd，困难档 400 局）：这两项原本**只进结算报告的分数**，
# 涨也好、掉也好，都不会改变牌桌上的收益，于是玩家没有任何理由为它们出牌 ——
#   候鸟：死因占比 0.3%、危机伤害占比 5.6%，且只在「植被 < 42」时才会自然衰减；
#   社区信任：自然衰减的门槛（< 45）**比困难档自己的致死线（50）还低**，
#             也就是说，只要你还活着，它就永远不会自然掉 —— 需要维护的理由根本不存在。
#
# 修法：把「钱从哪来」接到这两项上 —— 它们从"只读的分数"变成"经济引擎"。
#   · 社区信任高 → 地方配套与群众配合到位，拨款更多
#   · 候鸟种群旺 → 观鸟 / 生态旅游能拉到的社会资金更多
# 表格格式：指标 → [[阈值, 金额(万)], ...]，**从上往下取第一个满足的**（写的时候按强度递减）。
# 阈值正数 = 指标 ≥ 阈值 时生效；负数 = 指标 ≤ |阈值| 时生效。
# ⚠ 玩家可见文案不解释因果（只给结果）—— 结算里只多一行「额外拨款：+N 万」，
#   "为什么多"要玩家自己从数字里总结。
const FUNDING_STEPS := {
	"community": [[70, 15], [60, 8], [-30, -15]],
	"birds":     [[70, 10], [-25, -5]],
}
const CRISIS_CHANCE := { Difficulty.EASY: 0.38, Difficulty.NORMAL: 0.55, Difficulty.HARD: 0.68, Difficulty.NIGHTMARE: 0.68 }  # 危机概率基数
const CRISIS_SLOPE := { Difficulty.EASY: 0.22, Difficulty.NORMAL: 0.25, Difficulty.HARD: 0.28, Difficulty.NIGHTMARE: 0.28 }   # 危机概率随回合增幅
const START_FLOOR := { Difficulty.EASY: 48, Difficulty.NORMAL: 48, Difficulty.HARD: 48, Difficulty.NIGHTMARE: 48 }          # 开局指标下限（各难度统一，难度只体现在阈值）
const START_BOOST := { Difficulty.EASY: 6, Difficulty.NORMAL: 6, Difficulty.HARD: 6, Difficulty.NIGHTMARE: 6 }             # 开局指标加成（各难度统一）
# 每回合行动位（行动位 = 一回合最多能打几张牌）
# 简单档多给一个位：新手还没建立起「先补水再护鸟」这类联动的直觉，
# 三个位常常只够救火、铺不出组合，体验偏挫败。普通/困难/噩梦维持 3。
const MAX_ACTIONS_BY_DIFFICULTY := { Difficulty.EASY: 4, Difficulty.NORMAL: 3, Difficulty.HARD: 3, Difficulty.NIGHTMARE: 3 }

## 难度中文名（界面与报告共用一处，免得四个按钮各写一份字面量、早晚漂移）。
func difficulty_name() -> String:
	match difficulty:
		Difficulty.EASY: return "简单"
		Difficulty.NORMAL: return "普通"
		Difficulty.HARD: return "困难"
		Difficulty.NIGHTMARE: return "噩梦"
	return "未知"

# 每项指标相对「难度致死线」的偏移（正数 = 线更高更严格，负数 = 更宽容）
# 留空 = 六项都用难度线（与旧版行为完全一致）。想调平衡只改这张表，不用动卡牌数值。
# 实测依据（见 版本更新0.0.3.md 第六节）：六项指标的「体质」差 2~3 倍 ——
#   水质 无监测每回合 -2~-4、开局离致死线只有 9.3；社区信任 平时不衰减、缓冲 19.4。
# 共用一条线时死因会高度集中（简单档 89% 死在水质+植被，社区信任只占 1%）。
# 2026-09-28 起**已启用**（按玩测可再调；调完重跑 版本更新0.0.3.md 第五节的验证）：
#   "water_quality":   -5,   # 无条件衰减 + 缓冲最小，最宽容，避免「忘监测就必死」
#   "vegetation":      +3,   # 候鸟与鱼类的上游，略严
#   "fish":            -5,   # 同样无条件衰减（无巡护 -1~-2/回合）
#   "birds":            0,   # 恢复最慢、条件触发，维持原线
#   "community":      +10,   # 平时不衰减（缓冲 19.4），抬线让「牺牲社区」真的会输
# 生效后的五条致死线（顺序：水质/植被/鱼类/候鸟/社区；水位无致死线）：
#   简单 15/23/15/20/30
#   普通 25/28/25/30/40
#   困难 35/38/35/40/50
const FAILURE_THRESHOLD_OFFSET := {"water_quality": -5, "vegetation": 3, "fish": -5, "birds": 0, "community": 10}

# 在 FAILURE_THRESHOLD_OFFSET 之上、**只对特定难度**再叠加的调整。
# 用来做「普通/困难太严、简单档不动」这类微调 —— 直接改 FAILURE_THRESHOLD_OFFSET
# 会连简单档一起动，而简单档是给新手的，不该跟着变。
# 2026-09-28 玩测反馈：沉水植被在普通/困难太难保住，两条线各降 5。
const FAILURE_THRESHOLD_EXTRA := {
	Difficulty.NORMAL: {"vegetation": -5},
	Difficulty.HARD:   {"vegetation": -5},
}

# 六项指标的中文名与量纲说明
const METRIC_NAMES := {
	"water_level": "水位",
	"vegetation": "沉水植被",
	"water_quality": "水质",
	"fish": "鱼类资源",
	"birds": "候鸟种群",
	"community": "社区信任",
}

# 死因 → 下一局优先补强的方向（失败报告用来交代「输在哪、下次怎么打」）
# ⚠ 只给「打什么」，不给「为什么」：指标之间的因果链（水质→植被→候鸟…）是隐性参数，
#   要玩家自己从数字里总结。这里写解释就等于把机制白送。
const METRIC_REMEDY := {
	"water_level": "优先补水、蓄水保水，把闸坝联合调度打出来",
	"water_quality": "尽早安排水质监测与清淤",
	"vegetation": "及时补种沉水植物、修复湿地",
	"fish": "持续维持巡护执法，别断",
	"birds": "保住栖息地，给候鸟留出恢复的时间",
	"community": "补偿与转产别断",
}

# 卡牌档位 → 成本倍率
const TIER_COST_MULT := {"basic": 0.5, "effective": 1.0, "deep": 2.0}
const TIER_NAMES := {"basic": "基础投入", "effective": "有效投入", "deep": "深度投入"}

# ==================== 物种数据 ====================
# 每个物种有生态角色；物种指数受相关指标与行动联动。沙盘鸟类总数由候鸟总值决定。
const SPECIES := {
	"baihe": {
		"name": "白鹤", "color": Color(0.97, 0.97, 0.95),
		"role": "旗舰物种：取食苦草块茎，是人鸟冲突的核心。",
		"drivers": ["birds", "vegetation"],
	},
	"dongfangbaihuan": {
		"name": "东方白鹳", "color": Color(0.40, 0.40, 0.47),
		"role": "鱼类取食者：湿地健康的指示物种。",
		"drivers": ["birds", "fish"],
	},
	"xiaotiane": {
		"name": "小天鹅", "color": Color(0.93, 0.93, 0.89),
		"role": "浅水滤食者：对碟形湖水位变化最敏感。",
		"drivers": ["birds", "water_level"],
	},
	"baizhenhe": {
		"name": "白枕鹤", "color": Color(0.86, 0.86, 0.80),
		"role": "杂食性：喜在农田与草洲交界处觅食稻谷。",
		"drivers": ["birds", "community"],
	},
	"yanlei": {
		"name": "雁类", "color": Color(0.72, 0.68, 0.60),
		"role": "草洲取食者：数量庞大，是食物链的基础。",
		"drivers": ["birds", "vegetation"],
	},
}

# 行动卡 → 直接提升的物种（体现「某种选项导致物种增多」）
const ACTION_SPECIES_BONUS := {
	"veg_restore": {"baihe": 8, "yanlei": 8},
	"water_control": {"xiaotiane": 8},
	"bird_canteen": {"baihe": 6, "baizhenhe": 6},
	"patrol": {"dongfangbaihuan": 6},
	"water_replenish": {"xiaotiane": 8},
	"water_storage": {"xiaotiane": 7},
	"water_schedule": {"xiaotiane": 6},
	"habitat_protect": {"baihe": 8, "xiaotiane": 6},
}

# ==================== 植物数据 ====================
# 不同湿地植物，各有生态角色；数量随指标联动，地图上显示会生长的个体。
# kind: submerged 沉水 / emergent 挺水 / floating 浮叶 / marsh 草洲
const PLANTS := {
	"kucao": {
		"name": "苦草", "color": Color(0.42, 0.66, 0.46), "kind": "submerged",
		"role": "沉水植物，白鹤越冬主食。",
		"drivers": ["vegetation", "water_quality"],
	},
	"luwei": {
		"name": "芦苇", "color": Color(0.70, 0.74, 0.52), "kind": "emergent",
		"role": "挺水植物，净化水质、为鸟类提供筑巢地。",
		"drivers": ["vegetation", "water_level"],
	},
	"lian": {
		"name": "莲", "color": Color(0.52, 0.72, 0.56), "kind": "floating",
		"role": "浮叶植物，白鹤取食莲藕，人鸟冲突焦点。",
		"drivers": ["vegetation", "water_level"],
	},
	"lihao": {
		"name": "藜蒿", "color": Color(0.72, 0.76, 0.54), "kind": "marsh",
		"role": "草洲先锋植物，固土防冲刷。",
		"drivers": ["vegetation", "community"],
	},
	"taicao": {
		"name": "苔草", "color": Color(0.58, 0.70, 0.50), "kind": "marsh",
		"role": "草洲优势种，雁类的主要食物。",
		"drivers": ["vegetation", "water_quality"],
	},
	"chishan": {
		"name": "池杉", "color": Color(0.50, 0.66, 0.46), "kind": "tree",
		"role": "岸边乔木，为候鸟提供筑巢与停歇的栖息地。",
		"drivers": ["vegetation"],
	},
}

# 行动卡 → 直接提升的植物
const ACTION_PLANT_BONUS := {
	"veg_restore": {"kucao": 18, "taicao": 14},
	"water_control": {"luwei": 10, "lian": 10},
	"water_monitor": {"kucao": 8},
	"water_replenish": {"luwei": 8, "lian": 8},
	"water_storage": {"luwei": 8, "lian": 8},
	"water_schedule": {"luwei": 7, "lian": 7},
	"wetland_restore": {"kucao": 12, "taicao": 12, "lihao": 10},
	"floating_island": {"lian": 6},
	"grazing_ban": {"taicao": 10},
}

# 行动卡 → 环湖人类围垦强度（settlement）变化：正值扩张、负值收缩
const ACTION_SETTLEMENT_DELTA := {
	"wetland_restore": -35,  # 退田还湿：农田退还湿地
	"industry_switch": -20,  # 转产投资：退捕退耕
	"grazing_ban": -15,      # 封洲禁牧：放牧点撤除
}

# ==================== 行动卡数据 ====================
# effects: [{metric, delta, delay}]  delay=0 即时；>0 进延迟队列
const ACTION_CARDS := [
	{
		"id": "water_control", "name": "碟形湖控水", "category": "ecology",
		"season": "winter",
		"tags": ["补水调度"],
		"desc": "调节湖区水位，改善沉水植物块茎发育。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_level", "delta": 6, "delay": 1} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_level", "delta": 8, "delay": 0}, {"metric": "vegetation", "delta": 4, "delay": 2} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_level", "delta": 18, "delay": 0}, {"metric": "vegetation", "delta": 8, "delay": 0}, {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"deep": "深度控水可能淹没下游农田，社区信任 -4"},
	},
	{
		"id": "veg_restore", "name": "植被补种", "category": "ecology",
		"season": "spring",
		"tags": ["生态修复", "物种防控"],
		"desc": "补种苦草等沉水植物，扩大草洲覆盖。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "vegetation", "delta": 6, "delay": 2} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "vegetation", "delta": 8, "delay": 2}, {"metric": "birds", "delta": 5, "delay": 3} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "vegetation", "delta": 9, "delay": 0}, {"metric": "birds", "delta": 7, "delay": 0} , {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"effective": "效果延迟 2~3 回合后显现"},
	},
	{
		# 与「植被补种」的分工：补种是**播种**（delayed 2~3 回合，便宜、附带候鸟收益），
		# 这张是**移栽成株**（当回合落地，贵、只加植被）—— 补的是
		# 「植被眼看要跌破红线、这回合必须拉回来」那类救火场景。
		# 全场原本只有「禁牧禁渔」给即时植被，而它要拿社区信任换（+9 配 -4）。
		"id": "submerged_planting", "name": "沉水植物移栽", "category": "ecology",
		"season": "spring",
		"tags": ["生态修复"],
		"desc": "移栽成株苦草、黑藻，快速重建水下草场 —— 当回合见效，但成株与固定成本高。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "vegetation", "delta": 6, "delay": 1} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "vegetation", "delta": 11, "delay": 0} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "vegetation", "delta": 25, "delay": 0}, {"metric": "community", "delta": -3, "delay": 0}]},
		},
		"side_note": {"deep": "大规模移栽要占用湖区作业面，社区信任 -3"},
	},
	{
		# 与「沉水植物移栽」配成一对：移栽是**买成株**（贵、当回合落地、有社区代价），
		# 这张是**养冬芽/种子库**（便宜、要等 2~3 回合、总量更大且不伤社区）。
		# 一救火一长投，玩家按「这波撑不撑得住」自己选，而不是只有一条路。
		"id": "seed_bank", "name": "草种库保育", "category": "ecology",
		"season": "spring",
		"tags": ["生态修复"],
		"desc": "保育苦草、黑藻的冬芽与种子库，为后续萌发留足种源 —— 便宜，但要等 2~3 回合才见效。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "vegetation", "delta": 8, "delay": 3} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "vegetation", "delta": 13, "delay": 2} , {"metric": "community", "delta": -1, "delay": 0}]},
			"deep":      {"effects": [{"metric": "vegetation", "delta": 20, "delay": 0}, {"metric": "community", "delta": -2, "delay": 0}]},
		},
		"side_note": {"effective": "效果延迟 2~3 回合后显现"},
	},
	{
		"id": "water_monitor", "name": "水质监测与病害防治", "category": "ecology",
		"season": "all",
		"tags": ["水体治理", "病害防控"],
		"desc": "监测总磷总氮，提前发现并防治病害风险。",
		"cost": 20,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_quality", "delta": 3, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_quality", "delta": 6, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_quality", "delta": 12, "delay": 0}]},
		},
		"side_note": {"effective": "提前发现病害，避免植被延迟受损"},
	},
	{
		"id": "invasive_clear", "name": "外来物种清除", "category": "ecology",
		"season": "summer",
		"tags": ["物种防控"],
		"desc": "清除福寿螺、凤眼莲等外来入侵物种。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "vegetation", "delta": 2, "delay": 0}, {"metric": "fish", "delta": 2, "delay": 0} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "vegetation", "delta": 5, "delay": 1}, {"metric": "fish", "delta": 5, "delay": 1} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "vegetation", "delta": 9, "delay": 0}, {"metric": "fish", "delta": 10, "delay": 0}, {"metric": "water_quality", "delta": -3, "delay": 0} , {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"deep": "快速化学清除有副作用，水质 -3"},
	},
	{
		"id": "bird_canteen", "name": "候鸟食堂营建", "category": "ecology",
		"season": "autumn",
		"tags": ["栖息地营造"],
		"desc": "在堤外农田预留食物地块，减少人鸟冲突。",
		"cost": 20,
		"tiers": {
			"basic":     {"effects": [{"metric": "birds", "delta": 3, "delay": 1} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "birds", "delta": 6, "delay": 1} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "birds", "delta": 13, "delay": 0}, {"metric": "community", "delta": -3, "delay": 0}]},
		},
		"side_note": {"deep": "未与农户充分协商，社区信任 -3"},
	},
	{
		"id": "rescue", "name": "应急救护", "category": "ecology",
		"season": "all",
		"tags": ["应急救护"],
		"desc": "救护搁浅或受伤个体，建立响应机制。",
		"cost": 10,
		"tiers": {
			"basic":     {"effects": [{"metric": "birds", "delta": 2, "delay": 2}]},
			"effective": {"effects": [{"metric": "birds", "delta": 3, "delay": 0}]},
			"deep":      {"effects": [{"metric": "birds", "delta": 6, "delay": 0}]},
		},
		"side_note": {},
	},
	{
		"id": "community_comp", "name": "社区补偿", "category": "social",
		"season": "all",
		"tags": ["社区补偿"],
		"desc": "补偿农户候鸟致害损失，缓解人鸟冲突。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "community", "delta": 4, "delay": 0}]},
			"effective": {"effects": [{"metric": "community", "delta": 8, "delay": 0}]},
			"deep":      {"effects": [{"metric": "community", "delta": 16, "delay": 0}]},
		},
		"side_note": {"deep": "全额补偿 + 转产扶持"},
	},
	{
		"id": "industry_switch", "name": "转产投资", "category": "social",
		"season": "all",
		"tags": ["产业转产"],
		"desc": "扶持退捕渔民转产，形成替代生计。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "community", "delta": 7, "delay": 3}]},
			"effective": {"effects": [{"metric": "community", "delta": 8, "delay": 2}, {"metric": "fish", "delta": 3, "delay": 2}]},
			"deep":      {"effects": [{"metric": "community", "delta": 11, "delay": 0}, {"metric": "fish", "delta": 4, "delay": 0}]},
		},
		"side_note": {"effective": "见效慢，2~3 回合后显现"},
	},
	{
		"id": "guard_team", "name": "社区共管与护鸟队", "category": "social",
		"season": "all",
		"tags": ["公众参与"],
		"desc": "建立护鸟员队伍，形成社区巡护网络。",
		"cost": 20,
		"tiers": {
			"basic":     {"effects": [{"metric": "community", "delta": 4, "delay": 1}]},
			"effective": {"effects": [{"metric": "community", "delta": 5, "delay": 1}, {"metric": "fish", "delta": 3, "delay": 1}]},
			"deep":      {"effects": [{"metric": "community", "delta": 8, "delay": 0}, {"metric": "fish", "delta": 5, "delay": 0}]},
		},
		"side_note": {"effective": "与执法巡逻有协同加成"},
	},
	{
		"id": "education", "name": "科普宣传与公众参与", "category": "social",
		"season": "all",
		"tags": ["公众参与"],
		"desc": "提升村民与学生认知，形成公众监测网络。",
		"cost": 20,
		"tiers": {
			"basic":     {"effects": [{"metric": "community", "delta": 3, "delay": 1}]},
			"effective": {"effects": [{"metric": "community", "delta": 5, "delay": 0}]},
			"deep":      {"effects": [{"metric": "community", "delta": 10, "delay": 0}]},
		},
		"side_note": {},
	},
	{
		"id": "patrol", "name": "执法巡逻", "category": "manage",
		"season": "all",
		"tags": ["执法巡护"],
		"desc": "严查非法捕捞，直接决定鱼类恢复速度。",
		"cost": 20,
		"tiers": {
			"basic":     {"effects": [{"metric": "fish", "delta": 3, "delay": 1} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "fish", "delta": 6, "delay": 1} , {"metric": "community", "delta": -1, "delay": 0}]},
			"deep":      {"effects": [{"metric": "fish", "delta": 12, "delay": 0}, {"metric": "community", "delta": -2, "delay": 0}]},
		},
		"side_note": {"deep": "严格执法可能引发不满，社区信任 -2"},
	},
	{
		"id": "research", "name": "生态监测与科研", "category": "manage",
		"season": "all",
		"tags": ["科研监测"],
		"desc": "提高预报准确率，建立长期数据库。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_quality", "delta": 2, "delay": 2}]},
			"effective": {"effects": [{"metric": "water_quality", "delta": 3, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_quality", "delta": 6, "delay": 0}]},
		},
		"side_note": {"deep": "科研点数 +3，预报更准"},
	},
	{
		"id": "water_replenish", "name": "生态补水（引江济湖）", "category": "ecology",
		"season": "winter",
		"tags": ["补水调度"],
		"desc": "跨流域引水补充湖区水量，缓解枯水、恢复浅滩生境。",
		"cost": 50,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_level", "delta": 7, "delay": 0} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_level", "delta": 11, "delay": 0}, {"metric": "vegetation", "delta": 3, "delay": 1} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_level", "delta": 24, "delay": 0}, {"metric": "vegetation", "delta": 6, "delay": 0}, {"metric": "community", "delta": -3, "delay": 0}]},
		},
		"side_note": {"deep": "引水挤占下游农业用水，社区信任 -3"},
	},
	{
		"id": "water_storage", "name": "蓄水保水工程", "category": "ecology",
		"season": "autumn",
		"tags": ["补水调度"],
		"desc": "在碟形湖与入江水道修建蓄水闸，汛期拦蓄、旱季保水，稳定湖区水位。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_level", "delta": 5, "delay": 1} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_level", "delta": 9, "delay": 0} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_level", "delta": 21, "delay": 0}, {"metric": "community", "delta": -3, "delay": 0}]},
		},
		"side_note": {"deep": "拦蓄过多影响下游用水，社区信任 -3"},
	},
	{
		"id": "water_schedule", "name": "闸坝联合调度", "category": "manage",
		"season": "summer",
		"tags": ["补水调度"],
		"desc": "协调上游水库联合调度，保障湖区生态流量，缓解枯水并改善水体流动性。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_level", "delta": 5, "delay": 1} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_level", "delta": 7, "delay": 0}, {"metric": "water_quality", "delta": 2, "delay": 0} , {"metric": "community", "delta": -1, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_level", "delta": 15, "delay": 0}, {"metric": "water_quality", "delta": 5, "delay": 0}, {"metric": "community", "delta": -2, "delay": 0}]},
		},
		"side_note": {"deep": "调水涉及上下游利益，社区信任 -2"},
	},
	{
		"id": "flood_release", "name": "分洪退水调度", "category": "manage",
		"season": "all", "tags": ["洪水调度"],
		"desc": "协调闸坝泄水与分洪通道，降低过高水位，让淹没的草场和浅滩重新露出。四季可用，低水位时慎用。",
		"cost": 30,
		"tiers": {
			"basic": {"effects": [{"metric": "water_level", "delta": -6, "delay": 0}, {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_level", "delta": -12, "delay": 0}, {"metric": "community", "delta": -2, "delay": 0}]},
			"deep": {"effects": [{"metric": "water_level", "delta": -20, "delay": 0}, {"metric": "community", "delta": -3, "delay": 0}]},
		},
		"side_note": {"deep": "集中分洪占用沿岸作业空间，社区信任 -3；退水过度会加重干旱"},
	},
	{
		"id": "emergency_drainage", "name": "应急排涝", "category": "manage",
		"season": "all", "tags": ["洪水调度", "水工调控"],
		"desc": "启用临时泵站与排水设施，快速降低偏高水位。投入较低、退水幅度较小，适合应急；低水位时慎用。",
		"cost": 20,
		"tiers": {
			"basic": {"effects": [{"metric": "water_level", "delta": -4, "delay": 0}, {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_level", "delta": -7, "delay": 0}, {"metric": "community", "delta": -1, "delay": 0}]},
			"deep": {"effects": [{"metric": "water_level", "delta": -12, "delay": 0}, {"metric": "community", "delta": -2, "delay": 0}]},
		},
		"side_note": {"deep": "泵站作业扰动沿岸生活，社区信任 -2；退水过度会加重干旱"},
	},
	{
		"id": "outlet_clearance", "name": "泄水口疏通", "category": "manage",
		"season": "all", "tags": ["洪水调度", "水体治理"],
		"desc": "清理泄水口与排水通道的堵塞，恢复出流能力，即时降低湖区水位，并在下一回合改善水质。低水位时慎用。",
		"cost": 30,
		"tiers": {
			"basic": {"effects": [{"metric": "water_level", "delta": -5, "delay": 0}, {"metric": "water_quality", "delta": 1, "delay": 1}, {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_level", "delta": -9, "delay": 0}, {"metric": "water_quality", "delta": 2, "delay": 1}, {"metric": "community", "delta": -2, "delay": 0}]},
			"deep": {"effects": [{"metric": "water_level", "delta": -16, "delay": 0}, {"metric": "water_quality", "delta": 3, "delay": 1}, {"metric": "community", "delta": -3, "delay": 0}]},
		},
		"side_note": {"effective": "疏通施工影响沿岸作业，社区信任 -2；水质改善在下一回合生效"},
	},
	{
		"id": "floodplain_diversion", "name": "滞洪区分流", "category": "ecology",
		"season": "summer", "tags": ["洪水调度", "生态修复"],
		"desc": "汛期启用滞洪区与分流沟渠，分担湖区高水位压力，退水后恢复浅滩植被。夏季可用，需兼顾滞洪区居民利益。",
		"cost": 40,
		"tiers": {
			"basic": {"effects": [{"metric": "water_level", "delta": -4, "delay": 0}, {"metric": "vegetation", "delta": 2, "delay": 1}, {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_level", "delta": -10, "delay": 0}, {"metric": "vegetation", "delta": 3, "delay": 1}, {"metric": "community", "delta": -2, "delay": 0}]},
			"deep": {"effects": [{"metric": "water_level", "delta": -18, "delay": 0}, {"metric": "vegetation", "delta": 6, "delay": 1}, {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"deep": "扩大滞洪区占用沿岸土地，社区信任 -4；植被在下一回合恢复"},
	},
	{
		"id": "wetland_restore", "name": "退田还湿（湿地生态修复）", "category": "ecology",
		"season": "autumn",
		"tags": ["生态修复"],
		"desc": "将环湖低产农田退还为湿地，重建自然水文节律。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "vegetation", "delta": 5, "delay": 1} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "vegetation", "delta": 10, "delay": 2}, {"metric": "water_quality", "delta": 5, "delay": 2}, {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "vegetation", "delta": 11, "delay": 0}, {"metric": "water_quality", "delta": 6, "delay": 0}, {"metric": "birds", "delta": 3, "delay": 0}, {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"effective": "退田农户短期受损，社区信任 -2"},
	},
	{
		"id": "floating_island", "name": "人工浮岛（生态浮床）", "category": "ecology",
		"season": "spring",
		"tags": ["水体治理"],
		"desc": "布置人工浮岛与生态浮床，吸附氮磷、净化水体。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_quality", "delta": 5, "delay": 1} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_quality", "delta": 7, "delay": 0}, {"metric": "vegetation", "delta": 3, "delay": 1} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_quality", "delta": 14, "delay": 0}, {"metric": "vegetation", "delta": 5, "delay": 0} , {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {},
	},
	{
		"id": "dredge", "name": "底泥清淤疏浚", "category": "ecology",
		"season": "winter",
		"tags": ["水体治理"],
		"desc": "疏浚淤积底泥，削减内源污染、恢复湖床通透性。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_quality", "delta": 5, "delay": 2} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_quality", "delta": 7, "delay": 1}, {"metric": "fish", "delta": 2, "delay": 2} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_quality", "delta": 14, "delay": 0}, {"metric": "fish", "delta": 4, "delay": 0}, {"metric": "vegetation", "delta": -3, "delay": 0} , {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"deep": "机械清淤扰动湖床，短期植被 -3"},
	},
	{
		"id": "habitat_protect", "name": "越冬栖息地保护", "category": "ecology",
		"season": "autumn",
		"tags": ["栖息地营造"],
		"desc": "划定并管护候鸟越冬栖息地，控制人为干扰与栖息地破碎化。",
		"cost": 20,
		"tiers": {
			"basic":     {"effects": [{"metric": "birds", "delta": 4, "delay": 1} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "birds", "delta": 7, "delay": 1}, {"metric": "vegetation", "delta": 2, "delay": 2} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "birds", "delta": 12, "delay": 0}, {"metric": "vegetation", "delta": 3, "delay": 0} , {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {},
	},
	{
		"id": "ecotourism", "name": "生态旅游与观鸟经济", "category": "social",
		"season": "winter",
		"tags": ["产业转产"],
		"desc": "发展观鸟旅游与生态体验，让保护产生社区收益。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "community", "delta": 5, "delay": 1}]},
			"effective": {"effects": [{"metric": "community", "delta": 6, "delay": 0}, {"metric": "birds", "delta": 3, "delay": 1}]},
			"deep":      {"effects": [{"metric": "community", "delta": 12, "delay": 0}, {"metric": "birds", "delta": 7, "delay": 0}, {"metric": "water_quality", "delta": -2, "delay": 0}]},
		},
		"side_note": {"deep": "游客激增带来环境压力，水质 -2"},
	},
	{
		"id": "damage_insurance", "name": "野生动物致害保险", "category": "social",
		"season": "autumn",
		"tags": ["社区补偿"],
		"desc": "建立候鸟致害补偿保险，农户损失及时赔付。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "community", "delta": 5, "delay": 1}]},
			"effective": {"effects": [{"metric": "community", "delta": 7, "delay": 0}, {"metric": "birds", "delta": 2, "delay": 1}]},
			"deep":      {"effects": [{"metric": "community", "delta": 12, "delay": 0}, {"metric": "birds", "delta": 5, "delay": 0}]},
		},
		"side_note": {"deep": "保险兜底后农户不再驱赶候鸟"},
	},
	{
		"id": "eco_brand", "name": "生态产品认证与助销", "category": "social",
		"season": "all",
		"tags": ["产业转产"],
		"desc": "认证湖区生态农产品并拓展销路，让绿色生产有利可图。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "community", "delta": 5, "delay": 2}]},
			"effective": {"effects": [{"metric": "community", "delta": 6, "delay": 1}, {"metric": "water_quality", "delta": 3, "delay": 2}]},
			"deep":      {"effects": [{"metric": "community", "delta": 7, "delay": 0}, {"metric": "water_quality", "delta": 5, "delay": 0}, {"metric": "vegetation", "delta": 3, "delay": 0}]},
		},
		"side_note": {"effective": "减少化肥农药投入，水质间接改善"},
	},
	{
		"id": "fish_restock", "name": "增殖放流", "category": "manage",
		"season": "spring",
		"tags": ["增殖放流"],
		"desc": "投放鱼苗，恢复鱼类资源量与江湖洄游通道。",
		"cost": 20,
		"tiers": {
			"basic":     {"effects": [{"metric": "fish", "delta": 5, "delay": 2} ]},
			"effective": {"effects": [{"metric": "fish", "delta": 8, "delay": 2}, {"metric": "community", "delta": 2, "delay": 2}]},
			"deep":      {"effects": [{"metric": "fish", "delta": 11, "delay": 0}, {"metric": "community", "delta": 3, "delay": 0}]},
		},
		"side_note": {"deep": "渔民共享放流收益，社区信任 +4"},
	},
	{
		# 与「增殖放流」配成一对：放流是**直接投鱼苗**（manage 类，全部延迟 1~2 回合，
		# 还附带社区收益），这张是**修产卵场与洄游通道**（当回合见效、只加鱼）。
		# 补的是「鱼类眼看跌破红线、这回合必须拉回来」的救火位 ——
		# 全场原本给即时鱼的只有执法巡逻与外来物种清除的 +2，杯水车薪。
		"id": "spawning_ground", "name": "鱼类产卵场修复", "category": "manage",
		"season": "spring",
		"tags": ["生态修复"],
		"desc": "修复四大家鱼产卵场与洄游通道：当回合就见鱼群回补，后续繁殖还会再涨一波。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "fish", "delta": 6, "delay": 0} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "fish", "delta": 9, "delay": 0}, {"metric": "fish", "delta": 4, "delay": 2} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "fish", "delta": 19, "delay": 0}, {"metric": "fish", "delta": 8, "delay": 0}, {"metric": "community", "delta": -3, "delay": 0}]},
		},
		"side_note": {"deep": "产卵场禁渔期影响短期捕捞，社区信任 -3"},
	},
	{
		"id": "smart_patrol", "name": "智慧巡护（无人机遥感）", "category": "manage",
		"season": "all",
		"tags": ["执法巡护"],
		"desc": "无人机与遥感全天候巡护，监测非法捕捞、火情与水质。",
		"cost": 20,
		"tiers": {
			"basic":     {"effects": [{"metric": "fish", "delta": 4, "delay": 1}]},
			"effective": {"effects": [{"metric": "fish", "delta": 6, "delay": 1}, {"metric": "water_quality", "delta": 2, "delay": 1}]},
			"deep":      {"effects": [{"metric": "fish", "delta": 10, "delay": 0}, {"metric": "water_quality", "delta": 3, "delay": 0}]},
		},
		"side_note": {},
	},
	{
		"id": "wetland_law", "name": "湿地保护立法", "category": "manage",
		"season": "all",
		"tags": ["执法巡护"],
		"desc": "推动地方湿地保护条例，划定禁渔区与生态红线。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "fish", "delta": 8, "delay": 3} ]},
			"effective": {"effects": [{"metric": "fish", "delta": 6, "delay": 2}, {"metric": "birds", "delta": 4, "delay": 2}, {"metric": "community", "delta": 3, "delay": 2}]},
			"deep":      {"effects": [{"metric": "fish", "delta": 8, "delay": 0}, {"metric": "birds", "delta": 6, "delay": 0}, {"metric": "community", "delta": 4, "delay": 0}]},
		},
		"side_note": {"effective": "立法见效慢，2 回合后逐步显现"},
	},
	{
		"id": "grazing_ban", "name": "封洲禁牧", "category": "manage",
		"season": "autumn",
		"tags": ["生态修复"],
		"desc": "禁止湖洲过度放牧，保护洲滩草甸植被。",
		"cost": 10,
		"tiers": {
			"basic":     {"effects": [{"metric": "vegetation", "delta": 2, "delay": 2} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "vegetation", "delta": 5, "delay": 0}, {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "vegetation", "delta": 10, "delay": 0}, {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"effective": "牧民失去放牧地，社区信任 -2"},
	},

	# ==================== 补牌：社会 / 管理（2026-09-28）====================
	# 加这批的原因：三色能力严重不对等 —— 生态 14 张覆盖全部六项，
	# 社会 7 张里**连一张水位卡都没有**，管理 8 张的候鸟只靠 wetland_law 一张弱覆盖。
	# 「？！同花！？」成就也因此偏易（生态三张比社会/管理三张好凑太多）。
	#
	# 设计准则两条：
	#   ① 每个颜色都要能应对**全部六项指标**，不再有"这项只能靠生态"的死角；
	#   ② 每个颜色都要有**当回合见效**的救火牌 —— 否则指标逼近致死线时，
	#      带这个颜色出战就等于没有还手之力（配合 RESCUE_WEIGHT 的加权才有意义）。
	# 数值口径与生态那边对齐：即时救火牌统一 +4/+9~11/+14~18，
	# 带代价的更高一档，延迟牌总量更大但便宜。

	# ---------- 社会（7 张）----------
	{
		"id": "water_comanage", "name": "社区水权共管", "category": "social",
		"season": "all",
		"tags": ["社区参与", "补水调度"],
		"desc": "把灌溉与生态用水的分配权交给村民议事会，从抢水变成共管。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_level", "delta": 6, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_level", "delta": 9, "delay": 0}, {"metric": "community", "delta": 3, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_level", "delta": 18, "delay": 0}, {"metric": "community", "delta": 6, "delay": 0}]},
		},
		"side_note": {"effective": "议事会需要时间磨合，但一旦跑通，调度阻力大减"},
	},
	{
		"id": "sewage_comanage", "name": "社区污水共治", "category": "social",
		"season": "all",
		"tags": ["水体治理", "社区参与"],
		"desc": "村民自建自管小型污水设施，从源头削减入湖污染。",
		"cost": 50,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_quality", "delta": 8, "delay": 1}]},
			"effective": {"effects": [{"metric": "water_quality", "delta": 10, "delay": 0}, {"metric": "community", "delta": 3, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_quality", "delta": 20, "delay": 0}, {"metric": "community", "delta": 6, "delay": 0}]},
		},
		"side_note": {"basic": "见效快，但覆盖范围取决于参与的户数"},
	},
	{
		"id": "fish_market", "name": "社区渔市共营", "category": "social",
		"season": "all",
		"tags": ["社区参与", "增殖放流"],
		"desc": "村集体统一经营渔获与品牌，收益按户分红，让护鱼的人有饭吃。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "fish", "delta": 6, "delay": 0}]},
			"effective": {"effects": [{"metric": "fish", "delta": 9, "delay": 0}, {"metric": "community", "delta": 3, "delay": 0}]},
			"deep":      {"effects": [{"metric": "fish", "delta": 18, "delay": 0}, {"metric": "community", "delta": 6, "delay": 0}]},
		},
		"side_note": {"effective": "渔获归集体后，个体偷捕的动机下降"},
	},
	{
		"id": "bird_friendly", "name": "候鸟友好社区", "category": "social",
		"season": "all",
		"tags": ["社区参与", "栖息地营造"],
		"desc": "与社区共建候鸟友好型生产生活方式，减少人鸟冲突。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "birds", "delta": 6, "delay": 0}]},
			"effective": {"effects": [{"metric": "birds", "delta": 9, "delay": 0}, {"metric": "community", "delta": 3, "delay": 0}]},
			"deep":      {"effects": [{"metric": "birds", "delta": 18, "delay": 0}, {"metric": "community", "delta": 6, "delay": 0}]},
		},
		"side_note": {"deep": "农田为候鸟留食，短期有减产压力"},
	},
	{
		"id": "fisher_retrain", "name": "渔民转产培训", "category": "social",
		"season": "all",
		"tags": ["产业转型", "社区参与"],
		"desc": "组织退捕渔民参加技能培训与就业对接，转产不离乡。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "community", "delta": 6, "delay": 0}]},
			"effective": {"effects": [{"metric": "community", "delta": 9, "delay": 0}, {"metric": "fish", "delta": 3, "delay": 1}]},
			"deep":      {"effects": [{"metric": "community", "delta": 15, "delay": 0}, {"metric": "fish", "delta": 8, "delay": 0}]},
		},
		"side_note": {"effective": "转产后下湖的人少了，鱼类压力随之下降"},
	},
	{
		"id": "eco_jobs", "name": "生态管护公益岗", "category": "social",
		"season": "all",
		"tags": ["社区参与", "生态修复"],
		"desc": "设护湿员、护鸟员等公益岗位，把生态保护变成村民的稳定收入。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "community", "delta": 4, "delay": 1}, {"metric": "vegetation", "delta": 2, "delay": 0}]},
			"effective": {"effects": [{"metric": "community", "delta": 7, "delay": 0}, {"metric": "vegetation", "delta": 5, "delay": 1}]},
			"deep":      {"effects": [{"metric": "community", "delta": 14, "delay": 0}, {"metric": "vegetation", "delta": 8, "delay": 0}]},
		},
		"side_note": {"effective": "护湿员日常巡护，草洲破坏随之减少"},
	},
	{
		"id": "eco_resettle", "name": "生态搬迁安置", "category": "social",
		"season": "all",
		"tags": ["生态修复", "产业转型"],
		"desc": "把圩区内的居民迁出并妥善安置，退出的土地交给湿地自然恢复。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "vegetation", "delta": 10, "delay": 2}, {"metric": "community", "delta": -2, "delay": 2}]},
			"effective": {"effects": [{"metric": "vegetation", "delta": 12, "delay": 1}, {"metric": "water_quality", "delta": 5, "delay": 1}, {"metric": "community", "delta": -3, "delay": 0}]},
			"deep":      {"effects": [{"metric": "vegetation", "delta": 19, "delay": 0}, {"metric": "water_quality", "delta": 9, "delay": 0}, {"metric": "community", "delta": -5, "delay": 0}]},
		},
		"side_note": {"deep": "搬迁触动既有生计，社区信任 -5"},
	},

	# ---------- 管理（6 张）----------
	{
		"id": "sluice_fry", "name": "灌江纳苗", "category": "manage",
		"season": "spring",
		"tags": ["增殖放流", "水工调控"],
		"desc": "汛期开闸引江，让长江鱼苗随水进入湖区 —— 老办法，但管用。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "fish", "delta": 6, "delay": 0} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "fish", "delta": 9, "delay": 0}, {"metric": "water_level", "delta": 3, "delay": 1} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "fish", "delta": 18, "delay": 0}, {"metric": "water_level", "delta": 5, "delay": 0} , {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"effective": "引江也会抬高水位，枯水期效果更明显"},
	},
	{
		"id": "migration_corridor", "name": "迁徙廊道管理", "category": "manage",
		"season": "autumn",
		"tags": ["栖息地营造", "执法巡护"],
		"desc": "维护候鸟停歇地的水位与人为干扰管控，保证迁徙通道畅通。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "birds", "delta": 6, "delay": 0} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "birds", "delta": 9, "delay": 0}, {"metric": "vegetation", "delta": 3, "delay": 1} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "birds", "delta": 18, "delay": 0}, {"metric": "vegetation", "delta": 5, "delay": 0} , {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"effective": "管控干扰的同时，停歇地草洲也得以休养"},
	},
	{
		"id": "algae_response", "name": "水质应急除藻", "category": "manage",
		"season": "summer",
		"tags": ["水体治理"],
		"desc": "蓝藻暴发时应急打捞与除藻，先把水质压住再谈长效治理。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_quality", "delta": 6, "delay": 1} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_quality", "delta": 11, "delay": 0} , {"metric": "community", "delta": -1, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_quality", "delta": 24, "delay": 0}, {"metric": "community", "delta": -2, "delay": 0}]},
		},
		"side_note": {"deep": "大规模打捞影响湖面作业，社区信任 -2"},
	},
	{
		"id": "obstruction_clear", "name": "湖区清障执法", "category": "manage",
		"season": "winter",
		"tags": ["执法巡护", "生态修复"],
		"desc": "清理湖区内违规围网、矮围与违建，让水草重新长回来。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "vegetation", "delta": 6, "delay": 0} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "vegetation", "delta": 9, "delay": 0}, {"metric": "fish", "delta": 3, "delay": 1} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "vegetation", "delta": 15, "delay": 0}, {"metric": "fish", "delta": 8, "delay": 0} , {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"deep": "拆除围网触及既得利益，执法阻力不小"},
	},
	{
		"id": "lake_chief", "name": "湖长制考核", "category": "manage",
		"season": "winter",
		"tags": ["执法巡护", "社区参与"],
		"desc": "把生态指标纳入湖区干部考核，压着各级真正去治。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "community", "delta": 6, "delay": 1}]},
			"effective": {"effects": [{"metric": "community", "delta": 8, "delay": 0}, {"metric": "water_quality", "delta": 4, "delay": 1}]},
			"deep":      {"effects": [{"metric": "community", "delta": 12, "delay": 0}, {"metric": "water_quality", "delta": 7, "delay": 0}, {"metric": "vegetation", "delta": 4, "delay": 0}]},
		},
		"side_note": {"effective": "考核压力层层传导，治理动作随之变快"},
	},
	{
		"id": "fishway", "name": "水工程鱼道建设", "category": "manage",
		"season": "winter",
		"tags": ["栖息地营造", "增殖放流"],
		"desc": "在闸坝上补建过鱼设施，恢复江湖洄游通道 —— 工程量大，见效要等。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "fish", "delta": 9, "delay": 2} , {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "fish", "delta": 11, "delay": 1}, {"metric": "birds", "delta": 4, "delay": 2} , {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "fish", "delta": 17, "delay": 0}, {"metric": "birds", "delta": 7, "delay": 0} , {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"effective": "洄游通道打通后，以鱼为食的候鸟也跟着回来"},
	},
	{
		"id": "sand_mining", "name": "采砂监管", "category": "manage",
		"season": "summer",
		"tags": ["执法巡护", "水体治理"],
		"desc": "汛期高水位下非法采砂最猖獗：搅动河床、悬浮物激增，沉水植物被连根冲走。集中巡江可护住水质与草场 —— 但触及砂石从业者的生计。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_quality", "delta": 6, "delay": 0}, {"metric": "vegetation", "delta": 1, "delay": 0}, {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_quality", "delta": 11, "delay": 0}, {"metric": "vegetation", "delta": 3, "delay": 0}, {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_quality", "delta": 22, "delay": 0}, {"metric": "vegetation", "delta": 6, "delay": 0}, {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"deep": "砂石行业转产安置不到位，社区信任 -4"},
	},
	{
		"id": "nonpoint_intercept", "name": "汛期面源污染拦截", "category": "ecology",
		"season": "summer",
		"tags": ["水体治理", "生态修复"],
		"desc": "夏季暴雨把农田化肥、畜禽粪污一股脑冲进湖里，是全年总磷总氮的最高峰。在入湖沟渠布设生态拦截带，把污染挡在湖外。",
		"cost": 40,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_quality", "delta": 5, "delay": 0}, {"metric": "fish", "delta": 2, "delay": 0}, {"metric": "community", "delta": -1, "delay": 0}]},
			"effective": {"effects": [{"metric": "water_quality", "delta": 9, "delay": 0}, {"metric": "fish", "delta": 4, "delay": 0}, {"metric": "community", "delta": -2, "delay": 0}]},
			"deep":      {"effects": [{"metric": "water_quality", "delta": 18, "delay": 0}, {"metric": "fish", "delta": 8, "delay": 0}, {"metric": "community", "delta": -4, "delay": 0}]},
		},
		"side_note": {"deep": "拦截带要占用沿岸农田与作业面，社区信任 -4"},
	},
	# ==================== 新增：7 张四季通用卡（2026-10-07）====================
	# 每项指标各配一张正向/调节卡；定价按工程平衡口径（三档 = 0.5/1/2 倍价，
	# 延迟按 1.00/0.85/0.70/0.55 折算，折后点/万落在现有卡 0.22~0.29 带内）。
	# 科学依据与实测见《保卫鄱阳湖_手牌数值与顶部文本_v0.1.16》附录六。
	{
		"id": "eco_water_scheduling", "name": "生态水位联合调度", "category": "manage",
		"season": "all",
		"tags": ["补水调度", "水工调控"],
		"desc": "联合调度五河水库群与湖口闸站，在枯水期加大下泄流量抬升湖区水位。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_level", "delta": 4, "delay": 1}]},
			"effective": {"effects": [{"metric": "water_level", "delta": 8, "delay": 1}, {"metric": "vegetation", "delta": 2, "delay": 2}]},
			"deep":      {"effects": [{"metric": "water_level", "delta": 15, "delay": 0}, {"metric": "vegetation", "delta": 4, "delay": 2}, {"metric": "community", "delta": -2, "delay": 0}]},
		},
		"side_note": {"deep": "大流量下泄要占用灌溉与发电用水，社区信任 -2"},
	},
	{
		"id": "preseason_drawdown", "name": "汛前预泄腾库", "category": "manage",
		"season": "all",
		"tags": ["洪水调度", "水工调控"],
		"desc": "汛前把湖库水位降到防洪限制水位腾出调蓄库容，湖滩出露晒滩促进苦草萌发。",
		"cost": 20,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_level", "delta": -8, "delay": 1}, {"metric": "vegetation", "delta": 5, "delay": 2}]},
			"effective": {"effects": [{"metric": "water_level", "delta": -16, "delay": 1}, {"metric": "vegetation", "delta": 7, "delay": 2}]},
			"deep":      {"effects": [{"metric": "water_level", "delta": -26, "delay": 1}, {"metric": "vegetation", "delta": 12, "delay": 1}, {"metric": "community", "delta": 2, "delay": 0}]},
		},
		"side_note": {"basic": "预泄留出库容，水位变化要等一回合才落到湖里"},
	},
	{
		"id": "riparian_buffer", "name": "滨湖缓冲带与生态沟渠", "category": "ecology",
		"season": "all",
		"tags": ["水体治理", "生态修复"],
		"desc": "在入湖河口与农田退水口建生态沟渠和挺水植物缓冲带，拦截氮磷面源。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "water_quality", "delta": 4, "delay": 1}]},
			"effective": {"effects": [{"metric": "water_quality", "delta": 7, "delay": 1}, {"metric": "vegetation", "delta": 2, "delay": 1}]},
			"deep":      {"effects": [{"metric": "water_quality", "delta": 13, "delay": 0}, {"metric": "vegetation", "delta": 4, "delay": 1}]},
		},
		"side_note": {"effective": "拦截带建成后逐步生效，延迟 1 回合"},
	},
	{
		"id": "artificial_spawning_nest", "name": "人工鱼巢投放", "category": "manage",
		"season": "all",
		"tags": ["增殖放流", "栖息地营造"],
		"desc": "在湖湾缓流区投放棕片与水草束鱼巢，提高鲤鲫与四大家鱼受精卵附着孵化率。",
		"cost": 20,
		"tiers": {
			"basic":     {"effects": [{"metric": "fish", "delta": 4, "delay": 2}]},
			"effective": {"effects": [{"metric": "fish", "delta": 6, "delay": 2}, {"metric": "water_quality", "delta": 2, "delay": 2}]},
			"deep":      {"effects": [{"metric": "fish", "delta": 11, "delay": 1}, {"metric": "water_quality", "delta": 3, "delay": 2}, {"metric": "community", "delta": -1, "delay": 0}]},
		},
		"side_note": {"basic": "鱼巢需浸没一段时间才见效，延迟 2 回合"},
	},
	{
		"id": "crab_control_replanting", "name": "控蟹护草与底质改良", "category": "ecology",
		"season": "all",
		"tags": ["生态修复", "物种防控"],
		"desc": "围网阻隔并清除啃食幼苗的绒螯蟹幼蟹，配合底质改良重建沉水植物群落。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "vegetation", "delta": 5, "delay": 2}]},
			"effective": {"effects": [{"metric": "vegetation", "delta": 10, "delay": 2}]},
			"deep":      {"effects": [{"metric": "vegetation", "delta": 20, "delay": 1}, {"metric": "community", "delta": -2, "delay": 0}]},
		},
		"side_note": {"deep": "围网作业影响湖区捕捞，社区信任 -2"},
	},
	{
		"id": "waterbird_food_supply", "name": "越冬候鸟食源补给", "category": "ecology",
		"season": "all",
		"tags": ["栖息地营造", "社区补偿"],
		"desc": "与农户签订留茬留水协议，保留部分稻田藕田不翻耕，为白鹤等提供块茎与残茬食源。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "birds", "delta": 4, "delay": 1}]},
			"effective": {"effects": [{"metric": "birds", "delta": 8, "delay": 1}, {"metric": "vegetation", "delta": 2, "delay": 2}]},
			"deep":      {"effects": [{"metric": "birds", "delta": 16, "delay": 0}, {"metric": "vegetation", "delta": 3, "delay": 2}, {"metric": "community", "delta": -2, "delay": 0}]},
		},
		"side_note": {"deep": "大面积留茬影响农户复种，社区信任 -2"},
	},
	{
		"id": "wetland_benefit_compensation", "name": "湿地生态效益补偿", "category": "social",
		"season": "all",
		"tags": ["社区补偿", "社区参与"],
		"desc": "按亩补偿候鸟取食与限产损失，以共管协议约定禁捕限牧，把保护成本内部化。",
		"cost": 30,
		"tiers": {
			"basic":     {"effects": [{"metric": "community", "delta": 4, "delay": 1}]},
			"effective": {"effects": [{"metric": "community", "delta": 8, "delay": 1}, {"metric": "birds", "delta": 2, "delay": 1}]},
			"deep":      {"effects": [{"metric": "community", "delta": 15, "delay": 0}, {"metric": "birds", "delta": 3, "delay": 2}]},
		},
		"side_note": {"effective": "补偿款按季兑付，社区信任延迟 1 回合到账"},
	},

]

# ==================== 知识卡数据 ====================
## 分类与美术 Card.zip 的九套牌底一致；彩蛋单独排在末尾。
const KNOWLEDGE_CATEGORIES := preload("res://scripts/knowledge_categories.gd").ORDER
const KNOWLEDGE_CARDS := {
	"egg_dixinhu": {
		"name": "狄鑫斛", "category": "彩蛋", "trigger": "random_only",
		"random_only": true, "condition": "", "tags": [], "action_ids": [], "seasons": [],
		"short": "碟形湖讲解图里的小人，悄悄走进了知识卡。",
		"ecology": "名字取自“碟形湖”，是制作组的创作彩蛋，并非真实物种。",
		"threat": "别把这个小人的名字当成地理术语哦！",
		"management": "想了解真正的碟形湖，请翻阅“碟形湖：大湖里的小湖”。",
		"creator": "Oliveira", "origin": "开发者 Oliveira 为制作组成员绘制的碟形湖讲解图",
	},
	"plant_kucao": {
		"name": "苦草", "category": "植物", "trigger": "observation",
		"short": "鄱阳湖湖区分布面积最大的沉水植物。",
		"ecology": "白鹤越冬食物的主要来源之一，通过块茎无性繁殖。",
		"threat": "水体富营养化可能导致种群大面积腐烂死亡。",
		"management": "补种前应先检测水质，控制总磷、总氮浓度。",
		"condition": "vegetation < 62",
		"tags": ["生态修复", "水体治理"],
	},
	"bird_baihe": {
		"name": "白鹤", "category": "鸟类", "trigger": "observation",
		"short": "国家一级保护动物，鄱阳湖是重要的越冬地。",
		"ecology": "全身白羽、脸部裸区红色，取食苦草块茎。",
		"threat": "沉水植被退化导致食物不足，转向农田觅食。",
		"management": "保护碟形湖与草洲，营建候鸟食堂。",
		"condition": "birds < 62",
		"tags": ["栖息地营造", "应急救护"],
	},
	"bird_xiaotiane": {
		"name": "小天鹅", "category": "鸟类", "trigger": "observation",
		"short": "体型较小的天鹅，嘴基黄黑，是国家二级保护动物。",
		"ecology": "浅水滤食者，靠碟形湖浅水区觅食沉水植物与底栖动物。",
		"threat": "水位异常波动会让浅水觅食地消失，种群随之下滑。",
		"management": "碟形湖控水应维持适宜浅水深度，保障小天鹅觅食地。",
		"condition": "water_level < 58",
		"tags": ["水工调控", "补水调度"],
	},
	"bird_dongfang": {
		"name": "东方白鹳", "category": "鸟类", "trigger": "observation",
		"short": "白身黑翅、嘴黑而长的大型涉禽。",
		"ecology": "迁徙季大量取食鱼类，是湿地健康指示物种。",
		"threat": "鱼类资源下降与栖息地破碎化。",
		"management": "禁渔与执法巡逻是恢复鱼类资源的关键。",
		"condition": "fish < 62",
		"tags": ["执法巡护", "增殖放流"],
	},
	"mech_water_quality": {
		"name": "水质与苦草", "category": "机制", "trigger": "decision",
		"short": "富营养化是沉水植被退化的主因之一。",
		"ecology": "总磷、总氮超标会诱发藻类暴发，遮蔽苦草。",
		"threat": "忽视水质监测，病害可能滞后爆发。",
		"management": "补种与水质治理应同步推进。",
		"condition": "vegetation < 45",
		"tags": ["水体治理", "科研监测"],
	},
	"mech_fushouluo": {
		"name": "福寿螺综合防控", "category": "外来物种", "trigger": "decision",
		"short": "外来入侵物种会挤占本土物种空间。",
		"ecology": "福寿螺繁殖快，啃食水生植物。",
		"threat": "化学灭杀可能误伤本土螺类。",
		"management": "应优先农业防治与生态调控，科学用药为最后手段。",
		"condition": "vegetation < 40",
		"tags": ["物种防控"],
	},
	"cons_disease": {
		"name": "苦草病害的因果", "category": "案例", "trigger": "consequence",
		"short": "水质超标会滞后引发植被病害。",
		"ecology": "早期水质超标 → 后续苦草病害暴发。",
		"threat": "后果延迟 2~3 回合，容易被忽略。",
		"management": "长期监测水质是预防的关键。",
		"condition": "water_quality < 35",
		"tags": ["病害防控", "水体治理"],
	},
	"cons_compensate": {
		"name": "野生动物致害补偿", "category": "管理策略", "trigger": "consequence",
		"short": "人鸟冲突需要共管而非对立。",
		"ecology": "白鹤取食莲藕、踩踏稻田造成农户损失。",
		"threat": "补偿缺位可能触发驱鸟等对抗行为。",
		"management": "走合规补偿渠道，配合转产扶持。",
		"condition": "community < 40",
		"tags": ["社区补偿", "产业转产"],
	},
	"geo_poyang": {
		"name": "认识鄱阳湖", "category": "地理", "trigger": "observation",
		"short": "鄱阳湖位于江西，是中国最大的淡水湖。",
		"ecology": "它与长江相连，是许多水生生物和候鸟的家园。",
		"threat": "污染和湿地破坏会影响湖泊中的生命。",
		"management": "从认识家乡的河湖开始，参与保护水环境。",
		"condition": "turn == 1", "tags": ["公众参与"],
		"source_title": "中科院地理所：鄱阳湖",
		"source_url": "https://igsnrr.cas.cn/cbkx/kpyd/zgdl/cnszy/202009/t20200910_5692411.html",
	},
	"geo_five_rivers": {
		"name": "五河汇入一湖", "category": "地理", "trigger": "observation",
		"short": "赣江、抚河、信江、饶河和修水汇入鄱阳湖。",
		"ecology": "这些河流把流域里的来水送到湖中，再与长江相接。",
		"threat": "上游污染可能沿河进入湖区。",
		"management": "保护湖泊也要保护上游河流，治理需要多地合作。",
		"condition": "", "tags": ["水体治理", "社区参与"], "action_ids": ["lake_chief", "nonpoint_intercept"],
		"source_title": "中科院：科普湿地",
		"source_url": "https://neigae.cas.cn/klwee/qt/kpsd/201604/t20160421_7562770.html",
	},
	"geo_hukou": {
		"name": "湖口：江湖相连的通道", "category": "地理", "trigger": "observation",
		"short": "鄱阳湖通过北部的湖口与长江相连。",
		"ecology": "江湖之间的水流联系也是生物迁移的重要条件。",
		"threat": "人为阻隔会改变水流与生物的通行条件。",
		"management": "研究江湖联系后再开展水工程，保护必要的通道。",
		"condition": "", "tags": ["水工调控", "增殖放流"], "action_ids": ["sluice_fry", "fishway", "water_replenish"],
		"source_title": "中科院地理所：鄱阳湖",
		"source_url": "https://igsnrr.cas.cn/cbkx/kpyd/zgdl/cnszy/202009/t20200910_5692411.html",
	},
	"geo_seasonal_lake": {
		"name": "会变大小的湖", "category": "地理", "trigger": "observation",
		"short": "鄱阳湖的湖面会随丰水期和枯水期发生变化。",
		"ecology": "涨水时湖面扩大，退水时洲滩显露，生物利用的环境也随之改变。",
		"threat": "把每次退水都当成灾害，会忽略自然的季节节律。",
		"management": "连续观察水位与季节，分清正常变化和异常旱涝。",
		"condition": "", "tags": ["补水调度", "科研监测"], "seasons": ["春", "夏", "秋", "冬"],
		"source_title": "中科院地理所：鄱阳湖",
		"source_url": "https://igsnrr.cas.cn/cbkx/kpyd/zgdl/cnszy/202009/t20200910_5692411.html",
	},
	"geo_saucer_lakes": {
		"name": "碟形湖：大湖里的小湖", "category": "地理", "trigger": "observation",
		"short": "湖区的部分浅洼地会在退水后成为相对独立的小湖。",
		"ecology": "碟形湖与主湖的连接或分离，影响其中的水、植物和动物。",
		"threat": "改变水文联系可能改变小湖原有的生态环境。",
		"management": "因地制宜维护生态水位，保留不同类型的湿地生境。",
		"condition": "", "tags": ["补水调度", "栖息地营造"], "action_ids": ["water_control", "water_comanage"], "seasons": ["秋"],
		"source_title": "中科院：通江湖泊水文过程研究",
		"source_url": "https://niglas.cas.cn/xwdt_1_1/yjjz/202005/t20200528_5599537.html",
	},
	"geo_flood_storage": {
		"name": "湖泊如何调蓄洪水", "category": "地理", "trigger": "observation",
		"short": "湖泊能容纳来水，参与调节河湖水量。",
		"ecology": "鄱阳湖接纳五河来水，经过调蓄后与长江相接。",
		"threat": "侵占湖泊空间会影响湖泊原有的功能。",
		"management": "保护湖泊与湿地空间，防洪要考虑整个流域。",
		"condition": "", "tags": ["生态修复", "补水调度"], "action_ids": ["wetland_restore", "water_storage"], "seasons": ["夏"],
		"source_title": "中科院地理所：鄱阳湖",
		"source_url": "https://igsnrr.cas.cn/cbkx/kpyd/zgdl/cnszy/202009/t20200910_5692411.html",
	},
	"animal_finless_porpoise": {
		"name": "长江江豚", "category": "水生动物", "trigger": "observation",
		"short": "江豚生活在水里，却是哺乳动物，幼豚靠母乳成长。",
		"ecology": "鄱阳湖是长江江豚的重要家园，它需要安全的水域。",
		"threat": "水下噪声和人类活动可能影响江豚及幼豚。",
		"management": "保护栖息水域，支持巡护、监测和减少干扰。",
		"condition": "", "tags": ["执法巡护", "科研监测"], "action_ids": ["patrol", "research"],
		"source_title": "中科院水生所：新生长江江豚",
		"source_url": "https://ihb.cas.cn/xwdt/zhxw/202406/t20240621_7193987.html",
	},
	"bird_white_naped_crane": {
		"name": "白枕鹤", "category": "鸟类", "trigger": "observation",
		"short": "白枕鹤身体多为灰色，喉部和枕部为白色。",
		"ecology": "这种大型涉禽会迁徙，利用湿地和部分农田栖息觅食。",
		"threat": "栖息地中的干扰会影响机警的鹤类。",
		"management": "远距离观察外形，不为了拍照追赶鸟群。",
		"condition": "", "tags": ["栖息地营造", "公众参与"], "action_ids": ["habitat_protect", "education"], "seasons": ["冬"],
		"source_title": "国家林草局：白枕鹤",
		"source_url": "https://www.forestry.gov.cn/c/www/xtq/26044.jhtml",
	},
	"bird_wintering_geese": {
		"name": "鄱阳湖的雁类", "category": "鸟类", "trigger": "observation",
		"short": "豆雁、鸿雁和白额雁等雁类会到鄱阳湖越冬。",
		"ecology": "不同雁类在不同子湖活动，调查能帮助了解它们的分布。",
		"threat": "只把所有雁记成一种，会遗漏物种之间的差异。",
		"management": "借助图鉴与望远镜辨认，记录时间、地点和种类。",
		"condition": "", "tags": ["科研监测", "栖息地营造"], "action_ids": ["research", "habitat_protect"], "seasons": ["冬"],
		"source_title": "中科院：鄱阳湖越冬雁类研究",
		"source_url": "https://igsnrr.cas.cn/sourcedb/zw/lw/202504/t20250409_7592059.html",
	},
	"plant_sedge": {
		"name": "苔草：草洲上的绿色食堂", "category": "植物", "trigger": "observation",
		"short": "洲滩上的嫩苔草是部分雁鸭类的重要食物。",
		"ecology": "草的生长时间和嫩老程度会影响候鸟能否获得适口食物。",
		"threat": "异常干旱可能让草提前生长、老化，错过候鸟的需求。",
		"management": "监测草的生长与候鸟食性，由专业人员制定食源管理方案。",
		"condition": "", "tags": ["生态修复", "栖息地营造"], "action_ids": ["seed_bank", "bird_canteen"], "seasons": ["秋", "冬"],
		"source_title": "国家林草局：守护候鸟迁飞栖息地",
		"source_url": "https://www.forestry.gov.cn/c/www/lcdt/77840.jhtml",
	},
	"plant_reeds": {
		"name": "芦苇与南荻", "category": "植物", "trigger": "observation",
		"short": "鄱阳湖较高的洲滩上分布着芦苇、荻等植物。",
		"ecology": "它们与低处的苔草、水生植物组成不同的植被群落。",
		"threat": "把不同高度的湿地改成同一种环境，会减少生境差异。",
		"management": "修复时观察地势和水位，保留自然植被的分布带。",
		"condition": "", "tags": ["生态修复", "科研监测"], "action_ids": ["veg_restore", "wetland_restore"],
		"source_title": "生态学报：鄱阳湖湿地植被分布",
		"source_url": "https://www.ecologica.cn/stxb/article/abstract/stxb201307301983?st=search",
	},
	"plant_lotus": {
		"name": "莲与藕的秘密", "category": "植物", "trigger": "observation",
		"short": "荷花、莲叶和藕属于同一种植物，藕是地下茎。",
		"ecology": "莲是水生植物，膨大的地下茎也是它的植物器官。",
		"threat": "只认识花和菜肴，容易忽略水生植物的完整结构。",
		"management": "观察花、叶和茎的关系，在允许的地方开展自然学习。",
		"condition": "", "tags": ["公众参与", "生态修复"], "action_ids": ["education", "bird_canteen"], "seasons": ["夏"],
		"source_title": "中科院华南植物园：莲的心事",
		"source_url": "https://scbg.cas.cn/hx/201908/t20190803_6734975.html",
	},
	"mech_fish_migration": {
		"name": "鱼儿的江湖旅行", "category": "机制", "trigger": "observation",
		"short": "部分鱼类在江里繁殖，再到湖泊里摄食和长大。",
		"ecology": "青、草、鲢、鳙等江湖洄游性鱼类需要连通的河湖环境。",
		"threat": "通道受阻会影响亲鱼迁移和鱼苗进入湖泊。",
		"management": "保护江湖联系、产卵环境和育幼环境。",
		"condition": "", "tags": ["增殖放流", "水工调控"], "action_ids": ["sluice_fry", "fishway", "spawning_ground"], "seasons": ["春"],
		"source_title": "中科院水生所：鄱阳湖与鱼类资源",
		"source_url": "https://www.ihb.cas.cn/kxcb_1/kxcb/202103/t20210325_5984541.html",
	},
	"mech_vegetation_zones": {
		"name": "湿地植物的分布带", "category": "机制", "trigger": "observation",
		"short": "不同地势和水分条件下，湿地植物的分布并不一样。",
		"ecology": "从较低的湖区到较高的洲滩，可见水生植物、苔草和芦苇等群落。",
		"threat": "忽略生长环境、盲目补种，可能不适合当地水文条件。",
		"management": "先调查水位与地势，再选择适宜的植物和修复位置。",
		"condition": "", "tags": ["生态修复", "科研监测"], "action_ids": ["submerged_planting", "veg_restore", "research"],
		"source_title": "生态学报：鄱阳湖湿地植被分布",
		"source_url": "https://www.ecologica.cn/stxb/article/abstract/stxb201307301983?st=search",
	},
	"mech_food_web": {
		"name": "湿地里的食物联系", "category": "机制", "trigger": "observation",
		"short": "水草、鱼虾和水鸟通过食物关系联系在一起。",
		"ecology": "改善湿地生境、恢复食物供应，有助于水鸟栖息觅食。",
		"threat": "只关注某一种动物，可能忽略它赖以生存的食物和环境。",
		"management": "一起保护生境和食源，观察治理带来的连锁变化。",
		"condition": "", "tags": ["生态修复", "栖息地营造"], "action_ids": ["veg_restore", "spawning_ground", "habitat_protect"],
		"source_title": "国家林草局：多方协力守护候鸟家园",
		"source_url": "https://www.forestry.gov.cn/c/www/dzbhdt/657022.jhtml",
	},
	"mech_feeding_depth": {
		"name": "水鸟需要适宜的水深", "category": "机制", "trigger": "decision",
		"short": "水里有食物，还要看鸟能不能够得着。",
		"ecology": "浅水、湿泥滩和草洲为不同水鸟提供不同的觅食空间。",
		"threat": "异常水位和退水时间会改变觅食环境与食物供给。",
		"management": "依据水鸟需求科学调水，保留多样的觅食环境。",
		"condition": "", "tags": ["补水调度", "栖息地营造"], "action_ids": ["water_control", "water_schedule", "habitat_protect"],
		"source_title": "国家林草局：守护候鸟迁飞栖息地",
		"source_url": "https://www.forestry.gov.cn/c/www/lcdt/77840.jhtml",
	},
	"case_extreme_drought": {
		"name": "极端干旱的连锁影响", "category": "案例", "trigger": "consequence",
		"short": "异常缺水会同时改变水面、植物和候鸟的食物。",
		"ecology": "2022年的极端干旱让鄱阳湖部分传统越冬生境发生变化。",
		"threat": "食源减少与栖息环境改变会给越冬候鸟带来困难。",
		"management": "监测旱情，结合生态补水和补充食源开展应对。",
		"condition": "water_level < 40", "tags": ["补水调度", "栖息地营造"], "action_ids": ["water_replenish", "water_storage"],
		"source_title": "国家林草局：守护候鸟迁飞栖息地",
		"source_url": "https://www.forestry.gov.cn/c/www/lcdt/77840.jhtml",
	},
	"mech_micro_wetlands": {
		"name": "小微湿地帮助净水", "category": "机制", "trigger": "decision",
		"short": "小水塘和河沟也能参与水环境保护。",
		"ecology": "水生植物可帮助拦截、过滤污染物，增强水体自净能力。",
		"threat": "持续排入污染物会给小微湿地增加负担。",
		"management": "把源头减污、污水处理和湿地修复结合起来。",
		"condition": "", "tags": ["水体治理", "社区参与"], "action_ids": ["floating_island", "sewage_comanage"],
		"source_title": "国家林草局：一泓碧水润泽万物",
		"source_url": "https://www.forestry.gov.cn/c/www/sdfc/598794.jhtml",
	},
	"mech_wetland_carbon": {
		"name": "湿地也能储存碳", "category": "机制", "trigger": "observation",
		"short": "湿地植被参与固碳，也是碳循环的一部分。",
		"ecology": "鄱阳湖碟形湖研究发现，水文连通条件会影响植被固碳能力。",
		"threat": "不能简单认为连通越强、固碳就一定越多。",
		"management": "长期监测不同湿地，依据证据制定保护方案。",
		"condition": "", "tags": ["科研监测", "生态修复"], "action_ids": ["research", "wetland_restore"], "level": "初中拓展",
		"source_title": "中科院：水文连通性与湿地植被固碳",
		"source_url": "https://www.niglas.cas.cn/xwdt_1_1/yjjz/202601/t20260126_8118721.html",
	},
	"mech_runoff_pollution": {
		"name": "雨水带来的面源污染", "category": "机制", "trigger": "consequence",
		"short": "污染不只来自排污口，也可能分散在农田等区域。",
		"ecology": "肥料等物质可随径流进入水体，增加湖泊的污染负荷。",
		"threat": "过量施肥及管理不当会加重农业面源污染。",
		"management": "科学减量施肥，结合拦截带和流域治理减少污染输入。",
		"condition": "", "tags": ["水体治理", "生态修复"], "action_ids": ["nonpoint_intercept", "lake_chief"], "seasons": ["夏"],
		"source_title": "生态环境部：鄱阳湖保护修复问题",
		"source_url": "https://www.mee.gov.cn/ywgz/zysthjbhdc/dcjl/202405/t20240517_1073473.shtml",
	},
	"manage_flyway": {
		"name": "候鸟迁飞通道", "category": "管理策略", "trigger": "decision",
		"short": "候鸟的一次迁徙，需要一路上许多地方共同守护。",
		"ecology": "繁殖地、停歇地和越冬地构成迁徙生活中的不同环节。",
		"threat": "其中一个环节受损，也可能影响整条迁徙路线。",
		"management": "各地共享监测信息，协同保护迁徙沿线生境。",
		"condition": "", "tags": ["栖息地营造", "执法巡护"], "action_ids": ["migration_corridor"], "seasons": ["春", "秋"],
		"source_title": "国家林草局：多方协力守护候鸟家园",
		"source_url": "https://www.forestry.gov.cn/c/www/dzbhdt/657022.jhtml",
	},
	"mech_bird_rings": {
		"name": "鸟脚上的“身份证”", "category": "机制", "trigger": "observation",
		"short": "科研人员给部分鸟佩戴脚环，用来识别个体。",
		"ecology": "在鄱阳湖重新观察到带环白枕鹤，能为迁徙研究提供线索。",
		"threat": "追赶、捕捉鸟类查看脚环，会干扰它们。",
		"management": "远距离记录可见环号，向专业机构报告；环志由专业人员开展。",
		"condition": "", "tags": ["科研监测", "公众参与"], "action_ids": ["research", "education"],
		"source_title": "国家林草局：白枕鹤环志与协作保护",
		"source_url": "https://www.forestry.gov.cn/c/www/dzbhdt/657022.jhtml",
	},
	"manage_bird_surveys": {
		"name": "怎样调查候鸟", "category": "管理策略", "trigger": "decision",
		"short": "连续调查比一次看到多少只鸟更能说明变化。",
		"ecology": "定期调查、视频和声纹识别能帮助了解鸟类分布。",
		"threat": "调查范围和记录方式不一致，会增加比较的困难。",
		"management": "按规范记录时间、地点、种类与数量，使用科技手段辅助监测。",
		"condition": "", "tags": ["科研监测", "执法巡护"], "action_ids": ["research", "smart_patrol"],
		"source_title": "国家林草局：鄱阳湖候鸟保护工作",
		"source_url": "https://www.forestry.gov.cn/c/www/dzbhdt/655834.jhtml",
	},
	"manage_fishing_ban": {
		"name": "十年禁渔保护了什么", "category": "管理策略", "trigger": "decision",
		"short": "禁渔为鱼类等水生生物恢复提供了机会。",
		"ecology": "鄱阳湖禁捕后的监测记录到鱼类资源恢复，也关注江豚变化。",
		"threat": "非法捕捞会损害恢复中的水生生物资源。",
		"management": "支持禁捕巡护与长期监测，也帮助退捕渔民转产就业。",
		"condition": "", "tags": ["执法巡护", "产业转型"], "action_ids": ["patrol", "fisher_retrain"],
		"source_title": "国家林草局：一泓碧水润泽万物",
		"source_url": "https://www.forestry.gov.cn/c/www/sdfc/598794.jhtml",
	},
	"protect_scientific_release": {
		"name": "科学放流，拒绝随意放生", "category": "保护行动", "trigger": "decision",
		"short": "把动物放进水里，不一定是在帮助自然。",
		"ecology": "科学放流需要考虑物种与当地生态环境是否适宜。",
		"threat": "向天然开放水域投放外来物种、杂交种等可能破坏生态。",
		"management": "不自行放生宠物或外来鱼，参与由专业部门组织的科学活动。",
		"condition": "", "tags": ["增殖放流", "物种防控"], "action_ids": ["fish_restock", "invasive_clear"],
		"source_title": "农业农村部：推进长江十年禁渔工作",
		"source_url": "https://yyj.moa.gov.cn/tzgg/202403/t20240322_6452083.htm",
	},
	"manage_bird_canteens": {
		"name": "候鸟食堂怎样建", "category": "管理策略", "trigger": "decision",
		"short": "保留稻谷、管理藕田等措施可提供候鸟补充食源。",
		"ecology": "人工食源地可以帮助缓解候鸟食物不足。",
		"threat": "候鸟进入农田觅食，也可能给农户带来损失。",
		"management": "食源管理与生态补偿一起推进；游客不自行投喂。",
		"condition": "", "tags": ["栖息地营造", "社区补偿"], "action_ids": ["bird_canteen", "bird_friendly"],
		"source_title": "国家林草局：人鸟共处鄱阳湖",
		"source_url": "https://www.forestry.gov.cn/c/www/dzbhdt/668059.jhtml",
	},
	"protect_birdwatching": {
		"name": "文明观鸟", "category": "保护行动", "trigger": "decision",
		"short": "欣赏鸟类，要把不打扰它们放在前面。",
		"ecology": "远距离安静观察，能看到鸟类自然的生活状态。",
		"threat": "追逐、投喂、无人机和闪光灯可能惊扰鸟群。",
		"management": "遵守观鸟区规定，使用望远镜，不追鸟、不诱拍、不随意投喂。",
		"condition": "", "tags": ["公众参与", "产业转产"], "action_ids": ["education", "ecotourism"],
		"source_title": "吴城候鸟小镇：观鸟须知",
		"source_url": "https://www.wchnxz.com/wap/notice.html?n=%E6%97%85%E6%B8%B8%E9%A1%BB%E7%9F%A5&num=4&pn=%E6%99%AF%E5%8C%BA%E5%AF%BC%E8%A7%88&ppn=%E9%A6%96%E9%A1%B5",
	},
	"protect_bird_rescue": {
		"name": "发现伤病鸟怎么办", "category": "保护行动", "trigger": "decision",
		"short": "发现伤病鸟，及时报告并联系专业救助人员。",
		"ecology": "专业救助包括发现、响应、救治、康复和放归。",
		"threat": "自行追捕、喂食或治疗，可能给鸟和自己带来风险。",
		"management": "保持距离，告知监护人并记录位置，联系保护区或专业救助机构。",
		"condition": "", "tags": ["应急救护", "公众参与"], "action_ids": ["rescue", "guard_team"],
		"source_title": "国家林草局：鄱阳湖的候鸟救助",
		"source_url": "https://www.forestry.gov.cn/c/www/dzbhdt/634206.jhtml",
	},
	"protect_wetland_tracks": {
		"name": "草洲不是越野场", "category": "保护行动", "trigger": "decision",
		"short": "湿地洲滩是生物的家园，不能当成随意行驶的空地。",
		"ecology": "保护完整的湿地与安静的栖息环境，有助于候鸟越冬。",
		"threat": "车辆碾压湿地等行为会破坏栖息环境。",
		"management": "只在允许区域活动，不驾车进入草洲，支持保护区巡护。",
		"condition": "", "tags": ["执法巡护", "公众参与"], "action_ids": ["patrol", "wetland_law", "obstruction_clear"],
		"source_title": "国家林草局：鄱阳湖候鸟保护工作",
		"source_url": "https://www.forestry.gov.cn/c/www/dzbhdt/655834.jhtml",
	},
	"case_entanglement": {
		"name": "渔网和鱼线的隐患", "category": "案例", "trigger": "consequence",
		"short": "水中的渔网和鱼线可能缠住江豚。",
		"ecology": "鄱阳湖曾记录江豚因渔网和鱼线缠绕死亡的案例。",
		"threat": "非法渔具不仅影响鱼类，也会伤害其他水生动物。",
		"management": "发现可疑渔具及时报告，由专业巡护人员处理，不自行下水。",
		"condition": "", "tags": ["执法巡护", "应急救护"], "action_ids": ["patrol", "obstruction_clear", "rescue"],
		"source_title": "生态环境部：鄱阳湖保护修复问题",
		"source_url": "https://www.mee.gov.cn/ywgz/zysthjbhdc/dcjl/202405/t20240517_1073473.shtml",
	},
	"manage_fisher_transition": {
		"name": "从捕鱼人到护鱼员", "category": "管理策略", "trigger": "decision",
		"short": "退捕渔民也可以成为水域的保护者。",
		"ecology": "鄱阳湖周边有渔民转做巡护，原来的渔船成为巡护船。",
		"threat": "保护措施如果忽略居民生计，会增加转型困难。",
		"management": "结合培训、就业帮扶和管护岗位，让保护与生活相互支持。",
		"condition": "", "tags": ["产业转型", "社区参与"], "action_ids": ["fisher_retrain", "eco_jobs", "industry_switch"],
		"source_title": "国家林草局：一泓碧水润泽万物",
		"source_url": "https://www.forestry.gov.cn/c/www/sdfc/598794.jhtml",
	},
	"mech_underwater_noise": {
		"name": "水下也有噪声", "category": "机制", "trigger": "observation",
		"short": "水下并不总是安静的，江豚依赖声音感知环境。",
		"ecology": "江豚靠声音定位、寻找食物，听觉对它的生活很重要。",
		"threat": "水下噪声可能影响江豚的健康和栖息地选择。",
		"management": "开展声学监测，减少航运等活动对江豚的干扰。",
		"condition": "", "tags": ["科研监测", "执法巡护"], "action_ids": ["research", "sand_mining"],
		"source_title": "中科院水生所：江豚与水下噪声",
		"source_url": "https://www.ihb.cas.cn/kxcb_1/cmsj/201211/t20121112_5735674.html",
	},
}

# ==================== 危机事件池（肉鸽随机性核心）====================
# 每回合有概率抽中危机；危机提前 1 回合预警，下回合生效。
# weight：同一轮候选之间的相对权重；cond：只有当前状态吻合的危机才会进入候选。
# 防连出与冷却：刚爆发的那个不会紧接着再来；爆发过的在各自的冷却回合内不再抽中。
# 全局喘息：任意两场危机之间至少空出 CRISIS_BREATH_TURNS 个回合（与是不是同一个危机无关）。
# 冷却时长默认走全局 CRISIS_COOLDOWN_TURNS；某个危机若在自己的条目里写了 "cooldown"，
# 就用它自己的 —— 便于给「汛期洪水」「非法捕捞」这类刷得凶的单独拉长间隔。
# 条目里不写 "cooldown" = 用全局值 = 与加这个机制之前完全一样（零行为变化）。
const CRISIS_COOLDOWN_TURNS := 3
const CRISIS_BREATH_TURNS := 1

# 深预警：科研点**累计**到这个数，危机预警从「提前 1 回合」延长到「提前 2 回合」。
# ⚠ 是累计达标而不是消耗 —— 科研点同时是结算报告的评分依据
#   （见 generate_report 里 research_points >= 20 的档位），花掉会连带拉低评价，
#   那就变成「拿成绩换情报」，与「科研投入换监测能力」的设定也不符。
const DEEP_WARN_RESEARCH := 8
const CRISES := [
	{
		"id": "drought", "name": "极端干旱", "weight": 1.0, "cond": "water_level < seasonal_low",
		"cooldown": 5,   # 重事件：掉 14 水位，两次之间至少隔 5 回合
		"needs": ["补水调度"],
		"warn": "【自然预警】气象部门预报：未来一季降水显著偏少，湖区面临枯水风险。",
		"hit": "【危机爆发】极端干旱来袭——湖区水位骤降，沉水植物块茎大面积发育受阻，湖床裸露。",
		"effects": [{"metric": "water_level", "delta": -14}, {"metric": "vegetation", "delta": -7}],
	},
	{
		"id": "disease", "name": "苦草病害暴发", "weight": 0.9, "cond": "water_quality < 50",
		"cooldown": 4,   # 慢性病害：会反复，但别连着来
		"needs": ["病害防控", "生态修复"],
		"warn": "【监测提示】巡护员发现局部水草出现腐烂迹象，疑与水体富营养化有关，建议加强监测。",
		"hit": "【危机爆发】苦草病害大面积暴发——沉水植被成片腐烂死亡，候鸟食物锐减。",
		"effects": [{"metric": "vegetation", "delta": -12}, {"metric": "water_quality", "delta": -6}],
	},
	{
		"id": "illegal_fishing", "name": "非法捕捞猖獗", "weight": 1.0, "cond": "fish < 50",
		"cooldown": 5,   # 实测最易刷屏的之一（简单档随机打牌 0.54/局），拉长间隔
		"needs": ["执法巡护"],
		"warn": "【巡护通报】近期湖区外围发现可疑船只活动轨迹，疑似非法捕捞，建议加强执法。",
		"hit": "【危机爆发】非法捕捞猖獗——电捕鱼与密眼网具造成鱼类资源骤减。",
		"effects": [{"metric": "fish", "delta": -13}],
	},
	{
		"id": "bird_conflict", "name": "候鸟大规模进田", "weight": 1.0, "cond": "fish < 50 and community < 55",
		"cooldown": 3,   # 社会摩擦：本来就不密（0.04/局），维持全局值
		"needs": ["社区补偿", "栖息地营造"],
		"warn": "【社区报告】湖里鱼不够吃，白鹤开始成群转向稻田觅食，农户损失在扩大 —— 建议提前协商补偿。",
		"hit": "【危机爆发】数千只候鸟涌入农田取食莲藕、踩踏稻苗：农户损失严重、矛盾激化，而候鸟也因食物不足与人为驱赶出现伤亡。",
		"effects": [{"metric": "community", "delta": -7}, {"metric": "birds", "delta": -6}],
	},
	{
		"id": "flood", "name": "汛期洪水", "weight": 0.8, "cond": "water_level > seasonal_high",
		"cooldown": 6,   # 大戏一场就够：季节性洪水，一局最多两三次
		"needs": ["生态修复", "栖息地营造", "洪水调度"],
		"warn": "【自然预警】上游持续降雨，水文站预计湖区水位将快速上涨。",
		"hit": "【危机爆发】汛期洪水漫过草洲——新生沉水植被被冲毁，底质遭到破坏。",
		"effects": [{"metric": "water_level", "delta": 18}, {"metric": "vegetation", "delta": -10}],
	},
	{
		"id": "pollution", "name": "上游污染输入", "weight": 0.9, "cond": "water_quality < 55",
		"cooldown": 5,   # 实测密度最高（简单档随机打牌 0.91/局），必须压
		"needs": ["水体治理"],
		"warn": "【水质预警】上游监测断面总磷浓度上升，污染团可能随水流进入湖区。",
		"hit": "【危机爆发】上游污染团入境——总磷总氮严重超标，鱼类与沉水植物同时受损。",
		"effects": [{"metric": "water_quality", "delta": -14}, {"metric": "fish", "delta": -6}],
	},
	{
		"id": "invasive", "name": "外来物种暴发", "weight": 0.9, "cond": "vegetation < 55",
		"cooldown": 5,   # 入侵要时间累积（0.62/局 → 拉开）
		"needs": ["物种防控", "生态修复"],
		"warn": "【巡查发现】湖区外围发现福寿螺与凤眼莲扩散迹象，繁殖速度较快。",
		"hit": "【危机爆发】外来物种暴发——福寿螺啃食水生植物，凤眼莲覆盖水面挤占生存空间。",
		"effects": [{"metric": "vegetation", "delta": -10}, {"metric": "fish", "delta": -5}],
	},
	{
		"id": "algal_bloom", "name": "蓝藻水华", "weight": 0.85, "cond": "water_quality < 45",
		"cooldown": 4,   # 与「上游污染」同属水体治理线，错开但不至于消失
		"needs": ["水体治理"],
		"warn": "【监测提示】气温升高、水体流动性变差，蓝藻水华风险上升。",
		"hit": "【危机爆发】蓝藻水华暴发——水面被绿色藻膜覆盖，水体缺氧，候鸟中毒与食物短缺同时发生。",
		"effects": [{"metric": "water_quality", "delta": -12}, {"metric": "birds", "delta": -8}],
	},
	{
		"id": "wetland_encroach", "name": "围湖造田", "weight": 1.0, "cond": "community < 55",
		"cooldown": 6,   # 重事件（还扣 30 安置额度）：一局出现一次就很有分量
		"needs": ["执法巡护", "生态修复"],
		"warn": "【社区动向】部分村民在湿地边缘围垦造田、搭建临时房，有向湖区推进的迹象。",
		"hit": "【危机爆发】围湖造田蔓延——环湖湿地被侵占，临时房屋与圩田向湖推进。",
		"effects": [
			{"metric": "vegetation", "delta": -8},
			{"metric": "water_quality", "delta": -4},
			{"metric": "birds", "delta": -5},
		],
		"settlement": 30,
	},
]

# ==================== 危机对策卡（标签匹配 + 概率加权）====================
# 卡牌上的 tags 与危机上的 needs 做标签匹配：命中任一 needs 的卡就是该危机的对策卡。
# 映射不再写死成卡 id 列表 —— 以后加新卡，只要挂上对的标签就自动进对策池。
#
# 供给策略：预警期抽牌时，对策卡的权重 ×CRISIS_COUNTER_WEIGHT（普通卡 1.0）。
# **大概率但不是必出** —— 肉鸽要有"这波没抽到、只能硬扛"的局面，所以不做硬保底。
# 精确算出的「手上至少 1 张对策卡」概率（26 张里抽 7 张，对策池 3~6 张）：
#   权重 2.5 → 89%~98%　权重 3.0 → 93%~99%　权重 4.0 → 96%~99.8%
# 2026-09-28 之前是"硬保底 2 张"（100% 必出，池 6 张的危机手上平均 2.8 张对策卡）；
# 玩测反馈"不该必出"，故改为概率加权。想调轻重只改这一个数字。
const CRISIS_COUNTER_WEIGHT := 3.0

# 救火加权：某项指标**逼近致死线**时，能拉高那一项的牌抽中概率提高。
# 与对策卡加权**相乘**叠加（一张既是对策又是救火的牌确实该最优先）。
#
# 为什么需要：危机有专门的预警期供给倾斜（上面那条），而**指标本身逼近致死线**
# 原本没有任何供给倾斜 —— 尤其是自然演化的慢性下滑，玩家常常
# 「明知这一项快撑不住了，手上却抽不到能救的牌」。这条补的就是那个缺口。
# 判定用 failure_threshold_for（含每项偏移与难度额外调整），不是裸的难度线。
const RESCUE_MARGIN := 10      # 低于「该指标致死线 + 该值」就算逼近
const RESCUE_WEIGHT := 2.5

# ==================== 卡牌协同（组合出招）====================
# 同回合内同时执行 requires 中全部卡牌，触发额外效果
const SYNERGIES := [
	{
		"id": "sci_plant", "name": "科学补种", "requires": ["water_monitor", "veg_restore"],
		"desc": "先测水质再补种，成活率大幅提升",
		"bonus": [{"metric": "vegetation", "delta": 9}],
	},
	{
		"id": "hydro_restore", "name": "水文修复", "requires": ["water_control", "veg_restore"],
		"desc": "控水与补种协同，为沉水植物创造适宜水位",
		"bonus": [{"metric": "vegetation", "delta": 7}, {"metric": "birds", "delta": 4}],
	},
	{
		"id": "joint_defense", "name": "群防群治", "requires": ["patrol", "guard_team"],
		"desc": "执法与社区共管协同，巡护覆盖翻倍",
		"bonus": [{"metric": "fish", "delta": 8}, {"metric": "community", "delta": 4}],
	},
	{
		"id": "livelihood", "name": "生计转型", "requires": ["community_comp", "industry_switch"],
		"desc": "补偿与转产配套，农户与渔民获得长期出路",
		"bonus": [{"metric": "community", "delta": 9}],
	},
	{
		"id": "coexist", "name": "人鸟共处", "requires": ["bird_canteen", "community_comp"],
		"desc": "候鸟食堂配合社区补偿，把冲突转化为共管",
		"bonus": [{"metric": "birds", "delta": 6}, {"metric": "community", "delta": 5}],
	},
	{
		"id": "clear_water", "name": "清源活水", "requires": ["dredge", "floating_island"],
		"desc": "清淤与浮岛协同，内源外源污染一起削减",
		"bonus": [{"metric": "water_quality", "delta": 8}, {"metric": "vegetation", "delta": 4}],
	},
	{
		"id": "sky_net", "name": "天网巡护", "requires": ["smart_patrol", "patrol"],
		"desc": "无人机侦察配合地面执法，非法捕捞无所遁形",
		"bonus": [{"metric": "fish", "delta": 9}, {"metric": "water_quality", "delta": 3}],
	},
	{
		"id": "river_link", "name": "江湖连通", "requires": ["fish_restock", "water_replenish"],
		"desc": "引水恢复洄游通道，放流鱼苗直达新家园",
		"bonus": [{"metric": "fish", "delta": 8}, {"metric": "water_level", "delta": 3}],
	},
	{
		"id": "green_livelihood", "name": "绿色生计", "requires": ["eco_brand", "industry_switch"],
		"desc": "认证品牌叠加转产投资，绿色产业形成闭环",
		"bonus": [{"metric": "community", "delta": 7}, {"metric": "water_quality", "delta": 5}],
	},
	{
		"id": "bird_tourism", "name": "观鸟经济", "requires": ["ecotourism", "habitat_protect"],
		"desc": "栖息地保护好，观鸟旅游才有持续客流",
		"bonus": [{"metric": "birds", "delta": 7}, {"metric": "community", "delta": 5}],
	},
]

# ==================== 失败原因（任一指标归零即提前结束）====================
const FAILURE_TEXT := {
	"water_level": "鄱阳湖干涸见底，湖床裸露龟裂，候鸟失去越冬栖息地。",
	"vegetation": "沉水植被彻底消失，白鹤失去主要食物来源，草洲退化为荒滩。",
	"water_quality": "水质彻底恶化，蓝藻暴发、水体缺氧，水生生物大面积死亡。",
	"fish": "鱼类资源枯竭，江豚与食鱼水鸟无以为继，禁渔成果付诸东流。",
	"birds": "候鸟种群崩溃，鄱阳湖失去国际重要湿地的生态价值。",
	"community": "社区信任彻底破裂，农户与渔民转入对抗，保护工作再也无法开展。",
}

# ==================== 叙事节拍（固定，但不做生态判断）====================
# ⚠ 只有「与当前状态无关」的话才允许写在这里 —— 开场设定、制度通知、收官预告。
#   任何断言「现在水位如何 / 候鸟如何」的句子都必须由 situation_report() 现场生成。
#   这一版之前这里是「按回合念稿」的事件表：第 3 回合必播「枯水期」、第 7 回合必播
#   「极端干旱持续」，于是水位 80 的那一局照样报警干旱；第 5/9 回合必播「候鸟进田 /
#   矛盾激化」，但机制上什么都不发生。玩测反馈原话：「他和游戏没有一点关系」。
# ⚠ 开场那句**也不能描述当下的生态**：开局六项是 _roll_starting_metrics() 按种子掷的
#   （每项 ±9，另有一项随机 −12 当软肋，天赋还会再加），水位完全可能是高的、软肋也可能
#   是社区信任。所以这里只说「你是谁、该干什么」，眼下什么样由弹窗里的态势那句去讲。
const NARRATIVE_BEATS := {
	1: "【开场】你作为新晋的湖区管理员，从这一回合起接手鄱阳湖的生态修复。先诊断问题，开启你的第一个决策。",
	11: "【政策通知】上级将在第 3 年末进行生态成效考核，鱼类指数达标可获专项拨款。",
	15: "【收官】四年过去了，准备验收最终成果。",
}

# ==================== 顶部态势播报（0.1.17）====================
# 顶部横幅不再是念稿，而是**每回合从当前六项指标现场判断该说哪一句**；
# 但说出来的话**只描述情况，不报数字** —— 数字在右侧指标面板和悬停小窗里，横幅照原样
# 用【自然预警】【社区报告】这种口径把「现在出了什么事」讲清楚就够了。
#
#   drought      水位低于本季参考下限、且偏离 ≥ WATER_ALERT_MARGIN 点
#   flood        水位高于本季参考上限、且偏离 ≥ WATER_ALERT_MARGIN 点
#   birds_field  候鸟 ≥ BIRD_SURPLUS_MIN、且沉水植被或鱼类低于 FOOD_SHORT_LINE
#   calm         以上都没有（水位在区间内 / 只是小幅偏离，两种说法）
#
# ⚠「人鸟矛盾」**不在这里出现**（见下面暗线一节）。
const SITUATION_TEXT := {
	"drought": "【自然预警】气象预报未来一季降水显著偏少，湖区面临干旱风险。",
	"flood": "【自然预警】上游持续降雨，水文站预计湖区水位快速上涨，有洪水风险。",
	"birds_field": "【社区报告】农户报告白鹤进入稻田取食，人鸟冲突初现端倪。",
	"calm_safe": "【湖区简报】暂未触发明显洪旱预警或候鸟进田情况。",
	"calm_off": "【湖区简报】水位略偏离本季参考区间，暂未触发明显洪旱预警或候鸟进田情况。",
}
# 弹窗里在横幅那句话后面，再补一句它意味着什么（同样只描述，不给数字）
const SITUATION_WHY := {
	"drought": "低水位下鱼类资源与沉水植被会跟着流失。",
	"flood": "新生沉水植被与草洲有被淹风险。",
	"birds_field": "农户损失正在累积。",
}
# 这两回合的横幅**只放开场 / 收官那句台词**，不拼当前态势（横幅是单行、超出会打省略号，
# 见 situation_banner()）。想让第 11 回合的政策通知也上横幅，把 11 加进来即可。
const BANNER_BEAT_TURNS := [1, 15]

# ==================== 人鸟矛盾（0.1.17 · 暗线）====================
# 设计意图（玩测反馈）：这**不是一个会自动提醒的危机**，是玩家该自己算出来的一条暗线 ——
# 「候鸟越堆越高、食源越来越空，早晚要出事」。所以：
#   · 横幅与事件弹窗里**一个字都不提**；
#   · 只有差值彻底拉开（≥ CONFLICT_THRESHOLD）才在**回合末**扣值，也就是「再不管就挨扣」；
#   · 扣值只出现在两处，且都与其它自然扣值放在一起：结算数字、以及悬停「社区信任 / 候鸟种群」
#     的详情页（那里会把这一笔并进「自然演化」那一栏，见 main.gd 的 _fill_metric_tip）；
#   · 同时**悄悄**把抽牌偏向能抬「沉水植被 / 鱼类」的牌（CONFLICT_FEED_WEIGHT），
#     不做任何「已列入下批分配」的提示 —— 玩家只会在「怎么最近老抽到补种/护渔」里自己悟。
#
# 判定链：
#   ① 候鸟 ≥ BIRD_SURPLUS_MIN（「候鸟多」）
#   ② 且（沉水植被 < FOOD_SHORT_LINE 或 鱼类 < FOOD_SHORT_LINE）（「食源紧」）→ 横幅「候鸟进田」
#   ③ 且 差值 ≥ CONFLICT_THRESHOLD → 人鸟矛盾激化，回合末扣值
# 差值 = max(0, 候鸟−沉水植被) + max(0, 候鸟−鱼类)
#   —— 候鸟越高、食源越低，差值越大；两边都不低于候鸟时为 0（候鸟没多出来，谈不上抢食）。
#
# 调轻重的旋钮就在下面这组常量里（详见版本更新0.1.17.md 的平衡表）。
const BIRD_SURPLUS_MIN := 62        # 「候鸟多」的起点：低于它一律不提、不扣
const FOOD_SHORT_LINE := 50         # 「食源紧」的线：沉水植被或鱼类低于它才算
const CONFLICT_THRESHOLD := 48      # 差值到多少才激化（实测：随机打法约 15% 的局会碰到，
                                    #   会管数值的打法不到 10%；只管候鸟不管食源才成串触发）
const CONFLICT_PENALTY_STEP := 12   # 差值每多这么多，社区与候鸟各多扣 1 点
const CONFLICT_PENALTY_MAX := 8     # 单次最多各扣这么多（差值 ≥ 132 才会顶到）
# 激化期间抽牌偏袒的「食源对策卡」：按**标签**选，和危机对策卡是同一套机制。
# ⚠ 刻意不用「任何对沉水植被 / 鱼类有正向效果的牌」这个数值口径 —— 实测 52 张里有 36 张
#   都沾边（很多卡只是顺手 +1/+2），一把加权下去等于没加。标签口径更准：12 张挂「生态修复」、
#   5 张挂「增殖放流」。以后想换口径只改 _conflict_feed_set()。
const CONFLICT_FEED_TAGS := ["生态修复", "增殖放流"]
const CONFLICT_FEED_WEIGHT := 2.0   # 这些牌权重 ×2.0；1.0 = 完全不偏
const WATER_ALERT_MARGIN := 4       # 水位偏离参考区间多少点才算「干旱 / 洪水」（区间内外的小抖动只写偏低/偏高）

# ==================== 运行时状态 ====================
var turn: int = 0
var funds: int = 0          # 本回合可用资金
var carry: int = 0          # 结转下回合
var last_metric_funding: int = 0   # 上一回合由六项指标换来的额外拨款（结算里显示用，仅结果不给解释）
var research_points: int = 0
var metrics: Dictionary = {}
# Bounded read-only HUD cache; excluded from saves and simulation state.
var _hover_preview_key: Array = []
var _hover_previews: Dictionary = {}
var species_pop: Dictionary = {}     # 每物种数量 0-100
var plant_pop: Dictionary = {}       # 每植物数量 0-100
var effects_queue: Array = []       # 延迟效果 {metric, delta, remaining, source}
var used_action_ids: Array = []     # 本回合已执行的卡（含调度，供协同与知识卡判定）
var free_actions_executed: int = 0  # 调度牌不消耗普通行动位
var knowledge_unlocked: Array = []
var pending_knowledge: Array = []   # 待弹出的知识卡 id
## 知识卡随机赠送用**独立**随机源：不消耗对局主随机流，
## 老种子下的对局走向不会被这次改动带偏（同种子仍可复现，只是多了一条支线）。
var _knowledge_rng := RandomNumberGenerator.new()
## 上一次弹出知识卡是在第几回合（-99 = 本局还没出过）——
## 用来保证「不连续两回合都出」，见 KNOWLEDGE_MIN_GAP_TURNS。
var knowledge_last_turn: int = -99
var log_messages: Array = []        # 因果提示
# ==================== 算分流水账 ====================
# 每笔指标增减的归因记录，供主场景播「小丑牌风算分动画」。纯只读副产品，不参与任何判定。
# 每项：{phase, label, ref_id, metric, raw, applied, before, after}
#   raw     = 吃过难度负向倍率后、被 clampi 截断前的「效果值」（弹窗显示的是 applied，见下）
#   applied = 实际落地的变化量（metrics 前后差）——指标贴 0/100 时会被截断而与 raw 不等
# ⚠ 故意不写进 serialize()：动画只在实时的 _finish_turn 路径播，读档永远走不到，
#   加进去只会给存档增加无谓的不兼容面。
var score_ledger: Array = []
var game_over: bool = false
var total_spent: int = 0            # 累计行动、调度与刷新支出（用于资金效率评价）
var turn_budget: int = 0            # 本回合拨款、结转与运营扣除后的总预算
var turn_card_spent: int = 0        # 本回合普通行动卡 + 紧急调度费用，不含刷新手牌
var turn_other_spent: int = 0       # 本回合刷新等非卡牌支出，同样占用总预算
# ===== 肉鸽机制状态 =====
var run_seed: int = 0               # 本局种子（同种子可复现，用于反事实对照）
var run_id: String = ""             # Unique reward receipt; independent of seeded gameplay RNG.
var settlement: int = 70            # 环湖人类围垦强度 0-100，仅用于 3D 房子表现
var difficulty: int = Difficulty.EASY   # 当前难度档位（主菜单选择）
var floating_islands: int = 0       # 人工浮岛数量（视觉表现，0=无）
var pending_crisis: Dictionary = {} # 待爆发的危机（本回合预警，下回合生效）
var forecast_crisis: Dictionary = {} # 深预警：2 回合后那一场，下回合升格为 pending_crisis
                                     # （不是另抽一次随机 —— 是把本来下一回合才抽的那个
                                     #   提前一回合抽出来存着，所以预告一定兑现）
var last_crisis_name: String = ""   # 上回合爆发的危机名（用于结算展示）
const MUSIC_CRISIS_RECOVERY_RATIO := 0.5
var music_crisis_recovery: Dictionary = {} # 危机曲解除条件：补回 50% 实际损失（向上取整）
var crisis_history: Array = []      # 已爆发的危机 [{id, turn}]，防连出与冷却的依据
var warn_history: Array = []        # 本局预警历史 [{turn, id, value, hit_turn}]，顶部「预警回顾」用
                                    # hit_turn = -1 表示这条预警还没等到爆发（本局就结束了）
# ===== 顶部态势播报（0.1.17）=====
var situation: Dictionary = {}       # 本回合的态势播报（situation_report() 的结果，UI 只读）
var prev_situation_tags: Array = []  # 上一回合的告急标签；用来判断「这一回合有没有新冒出来的」→
                                     # 只有**新出现**的告急才弹事件窗，否则每回合都弹会烦
var turn_bird_conflict: Dictionary = {}  # 本回合末实际结算的人鸟矛盾 {index, penalty, ...}；空 = 没激化
var conflict_history: Array = []     # 本局人鸟矛盾结算记录 [{turn, index, penalty}]（诊断/平衡用）
                                     # ⚠ 与 score_ledger 同理：实时对局的副产品，不进存档
var triggered_synergies: Array = [] # 本回合触发的协同
var _fired_synergies: Array = []    # 本局已触发过的协同（防重复）
var is_failure: bool = false        # 是否因生态崩溃提前结束
var failure_reason: String = ""     # 失败原因文案
var failure_metric: String = ""     # 崩溃的指标
var failure_value: int = 0          # 判负时该指标的数值（失败报告用）

signal metrics_changed
signal funds_changed
signal event_triggered(text: String)
signal crisis_warned(crisis: Dictionary)
signal crisis_hit(crisis: Dictionary)
signal knowledge_triggered(card_id: String)
signal turn_changed
signal game_ended(report: Dictionary)


func _ready() -> void:
	pass  # 由主场景在连接信号后调用 reset_game()，避免首个事件信号丢失


# ==================== 存档 ====================
## 序列化全部运行时状态，供暂停退出后读档续玩
func serialize() -> Dictionary:
	return {
		"turn": turn, "funds": funds, "carry": carry,
		"last_metric_funding": last_metric_funding,
		"research_points": research_points,
		"metrics": metrics.duplicate(),
		"species_pop": species_pop.duplicate(),
		"plant_pop": plant_pop.duplicate(),
		"effects_queue": effects_queue.duplicate(true),
		"used_action_ids": used_action_ids.duplicate(),
		"free_actions_executed": free_actions_executed,
		"ever_played": ever_played.duplicate(),
		# 紧急调度：待结算的调度牌与冷却回合都要带回来，否则中途读档会白丢那 40 万
		"dispatched_cards": dispatched_cards.duplicate(true),
		"dispatch_last_turn": dispatch_last_turn,
		"dispatch_used_count": dispatch_used_count,
		"knowledge_unlocked": knowledge_unlocked.duplicate(),
		"pending_knowledge": pending_knowledge.duplicate(),
		"log_messages": log_messages.duplicate(),
		"game_over": game_over, "total_spent": total_spent,
		"turn_budget": turn_budget, "turn_card_spent": turn_card_spent,
		"turn_other_spent": turn_other_spent,
		"run_seed": run_seed, "run_id": run_id, "settlement": settlement,
		# 本局天赋词条：继续游戏要原样带回来，否则中途读档会丢加成
		"talents": Talents.granted.duplicate(),
		"tree_talents": Talents.run_tree_ranks.duplicate(), "tree_mastery": Talents.run_tree_mastery,
		"difficulty": difficulty, "floating_islands": floating_islands,
		"pending_crisis": pending_crisis.duplicate(true),
		"music_crisis_recovery": music_crisis_recovery.duplicate(),
		"music_crisis_recovery_ratio": MUSIC_CRISIS_RECOVERY_RATIO,
		"forecast_crisis": forecast_crisis.duplicate(true),
		"last_crisis_name": last_crisis_name,
		"crisis_history": crisis_history.duplicate(true),
		"warn_history": warn_history.duplicate(true),
		# 态势播报：本回合的 report 不存（读档后由 situation_report() 现场重算），
		# 但「上一回合的告急标签」要带回来，否则读档后第一回合会把老告急当新告急再弹一次窗。
		"prev_situation_tags": prev_situation_tags.duplicate(),
		"turn_bird_conflict": turn_bird_conflict.duplicate(true),
		"triggered_synergies": triggered_synergies.duplicate(),
		"fired_synergies": _fired_synergies.duplicate(),
		"is_failure": is_failure, "failure_reason": failure_reason,
		"failure_metric": failure_metric, "failure_value": failure_value,
	}


## 从存档恢复全部运行时状态（不触发信号，由主场景随后刷新 HUD 与 3D）
func load_state(d: Dictionary, restore_talents: bool = true) -> void:
	turn = int(d.get("turn", 0))
	funds = int(d.get("funds", 0))
	# 旧存档可由已调度记录恢复确定的调度费用。
	var legacy_dispatch_spent := 0
	if not d.get("dispatched_cards", []).is_empty():
		legacy_dispatch_spent = DISPATCH_COST + DISPATCH_PRICE_STEP * maxi(0, int(d.get("dispatch_used_count", 1)) - 1)
	turn_card_spent = int(d.get("turn_card_spent", legacy_dispatch_spent))
	turn_budget = int(d.get("turn_budget", maxi(0, funds + turn_card_spent)))
	turn_other_spent = int(d.get("turn_other_spent", 0))
	carry = int(d.get("carry", 0))
	last_metric_funding = int(d.get("last_metric_funding", 0))
	research_points = int(d.get("research_points", 0))
	metrics = _int_dict(d.get("metrics", {}))
	species_pop = _int_dict(d.get("species_pop", {}))
	plant_pop = _int_dict(d.get("plant_pop", {}))
	effects_queue = d.get("effects_queue", [])
	used_action_ids = d.get("used_action_ids", [])
	free_actions_executed = clampi(int(d.get("free_actions_executed", 0)), 0, used_action_ids.size())
	ever_played = d.get("ever_played", {})
	dispatched_cards = d.get("dispatched_cards", [])
	dispatch_last_turn = int(d.get("dispatch_last_turn", -99))
	dispatch_used_count = int(d.get("dispatch_used_count", 0))
	knowledge_unlocked = d.get("knowledge_unlocked", [])
	pending_knowledge = d.get("pending_knowledge", [])
	log_messages = d.get("log_messages", [])
	game_over = bool(d.get("game_over", false))
	total_spent = int(d.get("total_spent", 0))
	run_seed = int(d.get("run_seed", 0))
	if restore_talents:
		Talents.set_granted(d.get("talents", []))
		Talents.set_run_tree(d.get("tree_talents", {}), bool(d.get("tree_mastery", false)))
	settlement = int(d.get("settlement", 70))
	difficulty = int(d.get("difficulty", 1 if d.get("hard_mode", false) else 0))
	run_id = str(d.get("run_id", "legacy:%d:%d" % [run_seed, difficulty]))
	floating_islands = int(d.get("floating_islands", 0))
	pending_crisis = d.get("pending_crisis", {})
	music_crisis_recovery = d.get("music_crisis_recovery", {})
	# 旧存档要求全量修复：将剩余修复量减半，不影响游戏指标和判负规则。
	if float(d.get("music_crisis_recovery_ratio", 1.0)) > MUSIC_CRISIS_RECOVERY_RATIO:
		for metric in music_crisis_recovery:
			var current: int = int(metrics.get(metric, 0))
			var remaining := maxi(0, int(music_crisis_recovery[metric]) - current)
			music_crisis_recovery[metric] = current + ceili(remaining * MUSIC_CRISIS_RECOVERY_RATIO)
	forecast_crisis = d.get("forecast_crisis", {})
	last_crisis_name = str(d.get("last_crisis_name", ""))
	crisis_history = d.get("crisis_history", [])
	warn_history = d.get("warn_history", [])
	prev_situation_tags = d.get("prev_situation_tags", [])
	turn_bird_conflict = d.get("turn_bird_conflict", {})
	situation = {}   # 现场重算；不信任存档里的旧播报
	triggered_synergies = d.get("triggered_synergies", [])
	_fired_synergies = d.get("fired_synergies", [])
	is_failure = bool(d.get("is_failure", false))
	failure_reason = str(d.get("failure_reason", ""))
	failure_metric = str(d.get("failure_metric", ""))
	failure_value = int(d.get("failure_value", 0))
	# 流水账是实时算分动画的副产品，读档后没有「刚刚结算过」的语义，直接清空
	score_ledger = []


## 把字典的值统一转成 int（JSON 兜底）
func _int_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k])
	return out


func reset_game() -> void:
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	turn = 0
	carry = 0
	funds = 0
	research_points = 0
	total_spent = 0
	turn_budget = 0
	turn_card_spent = 0
	turn_other_spent = 0
	settlement = 70
	floating_islands = 0
	effects_queue = []
	used_action_ids = []
	free_actions_executed = 0
	knowledge_unlocked = []
	pending_knowledge = []
	knowledge_last_turn = -99
	log_messages = []
	score_ledger = []
	game_over = false
	pending_crisis = {}
	music_crisis_recovery = {}
	forecast_crisis = {}
	last_crisis_name = ""
	crisis_history = []
	warn_history = []
	triggered_synergies = []
	_fired_synergies = []
	# 态势播报 / 人鸟矛盾：新局必须清干净，否则上一局的告急标签会让新局少弹一次事件窗
	situation = {}
	prev_situation_tags = []
	turn_bird_conflict = {}
	conflict_history = []
	ever_played = {}
	# ⚠ 紧急调度的冷却必须跟着新局一起归零。它只在**声明处**初始化过，
	#   若不在 reset_game 里重置，上一局用掉之后新局（turn 又是 1）会继续判冷却中 ——
	#   实测 bug：困难档第 1 回合用过，退回主菜单开简单档，紧急调度仍是灰的。
	dispatched_cards = []
	dispatch_last_turn = -99
	dispatch_used_count = 0
	is_failure = false
	failure_reason = ""
	failure_metric = ""
	failure_value = 0
	# 每局随机种子：同种子可复现（企划书 8.3 反事实对照）
	if run_seed == 0:
		randomize()
		run_seed = randi()
	seed(run_seed)
	# 知识卡随机赠送的独立随机流：由本局种子派生，但与主随机流错开
	_knowledge_rng.seed = run_seed * 2654435761 + 0x5EED
	# 本局天赋：随种子随机附赠 0~3 条词条。必须在 _roll_starting_metrics() 之前 ——
	# 开局指标要吃「开局 +N」这类词条。见 版本更新0.0.8.md。
	Talents.roll_for_run(run_seed, difficulty)
	metrics = _roll_starting_metrics()
	_guard_starting_metrics()
	_sync_species()
	_sync_plants()
	start_new_turn()


## 随机开局：在基线附近小幅偏移，每局困境不同
func _roll_starting_metrics() -> Dictionary:
	var base := {
		"water_level": 35,   # 偏枯水
		"vegetation": 45,    # 退化
		"water_quality": 40, # 富营养化风险
		"fish": 35,          # 禁渔初期
		"birds": 50,
		"community": 55,
	}
	# 开局数值各难度统一（难度差异体现在判负阈值上），统一抬高下限避免开局过低
	var floor: int = START_FLOOR[difficulty]
	var boost: int = START_BOOST[difficulty]
	var out := {}
	for k in base:
		# 每项在 ±9 内偏移，并保证不低于统一下限
		out[k] = clampi(base[k] + boost + _randi_range(-9, 9), floor, 88)
	# 至少保证有一项明显偏弱，制造"这局的软肋"
	var weak_keys: Array = out.keys()
	var weak: String = weak_keys[_randi_range(0, weak_keys.size() - 1)]
	out[weak] = clampi(out[weak] - 12, floor, 88)
	# 本局天赋加成：定点指标加成 + 全指标加成。
	# ⚠ 放在**最后**加（下限夹取和软肋 -12 都做完之后）：开局值贴着 48 下限的那几项
	#   会把「开局 +N」吞掉 —— 0.0.8 实测：生态专家 +2 在 6 项里有 4 项被下限吞成 0，
	#   还有 1 项被软肋压到下限、只显示出 +1（玩家拿到词条却量不出效果）。
	#   加完再夹一次 [0,88]。
	out["water_level"] = clampi(int(out["water_level"]) + int(Talents.get_bonus("start_water")), 0, 88)
	out["vegetation"] = clampi(int(out["vegetation"]) + int(Talents.get_bonus("start_veg")), 0, 88)
	out["fish"] = clampi(int(out["fish"]) + int(Talents.get_bonus("start_fish")), 0, 88)
	out["birds"] = clampi(int(out["birds"]) + int(Talents.get_bonus("start_birds")), 0, 88)
	out["water_quality"] = clampi(int(out["water_quality"]) + int(Talents.get_bonus("start_quality")), 0, 88)
	out["community"] = clampi(int(out["community"]) + int(Talents.get_bonus("start_community")), 0, 88)
	var all_bonus := int(Talents.get_bonus("start_all"))
	if all_bonus != 0:
		for k in out:
			out[k] = clampi(int(out[k]) + all_bonus, 0, 88)
	return out


## 开局不该"站在悬崖上"：任何低于「该项致死线 + 2」的开局值都抬上来。
## 背景：困难档社区信任致死线是 50、而开局下限只有 48 → 实测 9.3% 的局
## 玩家还没出手就在第一回合被判负（必现的 bug 级体验，且与"难度"无关）。
## ⚠ 噩梦档**不做开局保护**：995f784 那版根本没有这个函数，
##   "开局就离死 3~5 点"正是噩梦档的设计前提 —— 加了保护等于把它废掉。
##   其余三档照旧（那条保护是修「还没出手就输」的 P0 bug 加的，别退回去）。
func _guard_starting_metrics() -> void:
	if difficulty == Difficulty.NIGHTMARE:
		return
	for m in metrics.keys():
		if m == "water_level": continue
		var safe: int = failure_threshold_for(str(m)) + 2
		if int(metrics[m]) < safe:
			metrics[m] = safe


## 将物种数量同步到目标值（由驱动指标决定）
func _sync_species() -> void:
	for sid in SPECIES:
		species_pop[sid] = _species_target(sid)


## 将植物数量同步到目标值（由驱动指标决定）
func _sync_plants() -> void:
	for pid in PLANTS:
		plant_pop[pid] = _plant_target(pid)


## 物种目标数量 = 驱动指标均值（0-100）
func _species_target(sid: String) -> int:
	var drivers: Array = SPECIES[sid]["drivers"]
	var sum := 0
	for d in drivers:
		sum += _water_habitat_score() if d == "water_level" else int(metrics[d])
	return int(sum / drivers.size())


## 植物目标数量 = 驱动指标均值（0-100）
func _plant_target(pid: String) -> int:
	var drivers: Array = PLANTS[pid]["drivers"]
	var sum := 0
	for d in drivers:
		sum += _water_habitat_score() if d == "water_level" else int(metrics[d])
	return int(sum / drivers.size())

func _water_habitat_score() -> int:
	return clampi(100 - int(water_pressure(int(metrics.get("water_level", 50)))["deviation"]) * 3, 0, 100)


## 本回合由六项指标换来的额外拨款（万）。FUNDING_STEPS 的求值器。
## 每一项取**第一个**满足的阶梯（表按强度递减写），不累加同一项的多档。
func _metric_funding() -> int:
	var extra := 0
	for metric in FUNDING_STEPS:
		var cur: int = int(metrics.get(metric, 0))
		for step in FUNDING_STEPS[metric]:
			var thr: int = int(step[0])
			var hit: bool = (cur >= thr) if thr > 0 else (cur <= -thr)
			if hit:
				extra += int(step[1])
				break
	return extra


## 回合开始：结算拨款 + 扣运营支出
func start_new_turn() -> void:
	turn += 1
	used_action_ids = []
	free_actions_executed = 0
	clear_dispatch()          # 上一轮的调度牌已在回合末结算完，这里清空待办清单
	log_messages = []

	# 基础拨款随指标浮动：社区信任、候鸟种群决定能拉到多少社会/旅游资金。
	# 具体阶梯见 FUNDING_STEPS；这一段是「指标 → 钱」的唯一入口。
	last_metric_funding = _metric_funding()
	var funding := BASE_FUNDING + last_metric_funding
	# 按难度削减每回合拨款（普通/困难）
	funding -= FUNDING_PENALTY[difficulty]
	# 天赋加成：基础拨款 + 运营成本减免
	funding += int(Talents.get_bonus("funding"))

	funds = carry + funding - (OPERATION_COST + int(Talents.get_bonus("operation")))
	turn_budget = funds
	turn_card_spent = 0
	turn_other_spent = 0
	carry = 0

	metrics_changed.emit()
	funds_changed.emit()
	turn_changed.emit()

	# 本回合态势：从当前六项指标现场生成（顶部横幅实时读它，见 main.gd _refresh_event_banner）。
	situation = situation_report()
	# 弹窗规则：只有「叙事节拍」或「这一回合**新冒出来**的告急」才弹事件窗 ——
	# 否则每回合都弹会把玩家烦死；而告急是持续状态时横幅一直在，不需要再弹一次。
	# 「calm」不算告急：一切正常的回合不弹窗，只有从告急回到平稳时才让横幅自己变回平稳。
	var beat: String = narrative_beat(turn)
	var fresh: Array = []
	for t in situation["tags"]:
		if str(t) == "calm":
			continue
		if not prev_situation_tags.has(t):
			fresh.append(t)
	prev_situation_tags = situation["tags"].duplicate()
	if beat != "" or not fresh.is_empty():
		var body: String = str(situation["body"])
		if beat != "":
			body = beat + "\n\n" + body
		event_triggered.emit(body)

	# 危机系统已整体挪到 end_turn()（回合末）：预警与结算都在那里做。
	# 原因见 end_turn 里的注释 —— 伤害与判负要发生在玩家正看着数字的结算里。


## 结算上回合预警的危机：爆发并造成较重惩罚
func _resolve_pending_crisis() -> void:
	if pending_crisis.is_empty():
		return
	var c: Dictionary = pending_crisis
	pending_crisis = {}
	last_crisis_name = c["name"]
	crisis_history.append({"id": c["id"], "turn": turn})   # 防连出 / 冷却的依据
	record_crisis_notice(c, 0)
	_mark_warning_hit(str(c["id"]), turn)
	_add_log("⚠ %s" % c["hit"])
	for e in c["effects"]:
		if int(e["delta"]) < 0:
			var metric: String = str(e["metric"])
			var before: int = int(metrics[metric])
			var after := clampi(before + int(e["delta"]), 0, 100)
			var recovery_target := after + ceili((before - after) * MUSIC_CRISIS_RECOVERY_RATIO)
			music_crisis_recovery[metric] = maxi(recovery_target, int(music_crisis_recovery.get(metric, 0)))
		_apply_delta(e["metric"], e["delta"], false, "crisis", str(c["name"]))   # 危机伤害不叠负向倍率，见 _apply_delta 注释
		_add_log("   %s %+d" % [METRIC_NAMES[e["metric"]], e["delta"]])
	if c.has("settlement"):
		_apply_settlement(c["settlement"])
	_sync_species()
	_sync_plants()
	metrics_changed.emit()
	crisis_hit.emit(c)
	check_failure_now()   # 危机爆发把指标打到致死线以下 → 当场判负，不再放你一回合


## 音乐的危机生命周期独立于警示弹窗；关掉弹窗不会解除危机。
func has_unresolved_music_crisis() -> bool:
	for metric in music_crisis_recovery.keys():
		if int(metrics.get(metric, 0)) >= int(music_crisis_recovery[metric]):
			music_crisis_recovery.erase(metric)
	return not pending_crisis.is_empty() or not music_crisis_recovery.is_empty()


## 抽取本回合的危机预警（提前 1 回合告知，给玩家应对机会）
## 预警：抽出「下回合爆发」的那一场。只设置 pending_crisis，**不在这里 emit** ——
## 深预警紧接着还要抽出「2 回合后」的那一场，两个一起交给 UI，
## 弹窗同时展示「下回合」和「再下一回合」，避免同一回合弹两次。
## 真正的 emit 在 start_new_turn() 末尾统一发。
func _maybe_warn_crisis() -> void:
	if game_over:
		return  # 已经判负，不再抽新危机（否则预警会盖在失败报告上）
	if turn >= TOTAL_TURNS - 1:
		return  # 最后两回合不再新增危机，避免无法应对
	if not pending_crisis.is_empty():
		return  # 已有待爆发的危机，不叠加
	# 从第 3 回合起才开始抽危机，给玩家缓冲
	if turn < 3:
		return
	var c := _roll_crisis(turn)
	if c.is_empty():
		return
	pending_crisis = c
	_note_warning(c, 1)


## 深预警：再抽出「2 回合后」的那一场，存进 forecast_crisis。
## 它不是另抽一次随机 —— 是把本来要到下一回合才抽的那一场**提前一回合**抽出来存着，
## 下一回合升格为正式预警（见 _promote_forecast_if_needed），所以预告一定兑现。
func _maybe_forecast_crisis() -> void:
	if game_over or not deep_warning_on():
		return
	if not forecast_crisis.is_empty():
		return
	if pending_crisis.is_empty():
		return  # 连下回合的都还没定，谈不上预告再下一回合
	if turn + 2 > TOTAL_TURNS:
		return  # 会落在局末之后，就别给一个永远不会来的「预报」
	# at_turn 传 turn+1：这一场本来会在下一回合才抽，
	# 冷却 / 喘息 / 概率都该按那个时点判，否则会预告出一个到那时早已过期、
	# 或反而还在冷却中的危机。
	# 排除 pending_crisis：那一场会在本预告之前一回合爆发，必须避免「连着同一个」
	var c := _roll_crisis(turn + 1, str(pending_crisis.get("id", "")))
	if c.is_empty():
		return
	forecast_crisis = c
	_note_warning(c, 2)


## 深预警兑现：上一回合预告的那一场，本回合升格为「下回合爆发」的正式预警。
## ⚠ 必须在 _maybe_warn_crisis() **之前**调用 —— 否则它会先抽一个新的把预告顶掉，
##   预告就成假的了。
func _promote_forecast_if_needed() -> void:
	if forecast_crisis.is_empty() or not pending_crisis.is_empty():
		return  # 预告与正式预警一一对应，正常不会同时存在（后者是防御）
	pending_crisis = forecast_crisis
	forecast_crisis = {}
	# 同一爆发回合会合并到已有深预警，同时补齐旧档遗漏。
	record_crisis_notice(pending_crisis, 1)


## 抽一场危机。at_turn = 判定「冷却 / 全局喘息 / 概率」用的时点：
##   正式预警传当前回合；深预警传**它本来会被抽出的那个回合**（turn + 1）。
## exclude_id = 额外排除的危机 id。
##   ⚠ 预告必须把 pending_crisis 传进来：那一场会在预告之前一回合爆发，
##     而此刻它还没进 crisis_history，所以「防连出」和「冷却」两道过滤都拦不住它 ——
##     不排除的话会预告出一个「紧接着上一场、同一个危机」的结果（实测出现过连爆两次）。
## 过滤规则与原来完全一致，只是时点可参数化、多一道排除。抽不到返回空字典。
func _roll_crisis(at_turn: int, exclude_id: String = "") -> Dictionary:
	# 全局喘息：任意两场危机爆发之间至少空出 CRISIS_BREATH_TURNS 个回合。
	var last_hit := _last_crisis_hit_turn()
	if last_hit >= 0 and at_turn - last_hit < CRISIS_BREATH_TURNS:
		return {}  # 上一场危机刚落地，先把这一段喘息时间给玩家
	# 基础概率随难度递增，随回合推进略升（后期压力更大）
	var chance: float = CRISIS_CHANCE[difficulty] + float(at_turn) / float(TOTAL_TURNS) * CRISIS_SLOPE[difficulty]
	# 天赋加成：降低危机触发概率
	chance += Talents.get_bonus("crisis_chance")
	if randf() > chance:
		return {}
	# 加权抽选：只抽「当前状态真的吻合」的危机
	# 预警文案会引用当前值与警戒线（如「水质 90，警戒线 55」），若状态不吻合
	# 就会在安全区报警、自相矛盾 —— 所以这里必须硬性过滤，而不只是加权。
	# 再叠一层「防连出 + 冷却」：
	#   防连出 = 本回合刚爆发过的绝不连着再出（与冷却常量无关，永远生效）
	#   冷却   = 爆发过的在 CRISIS_COOLDOWN_TURNS 回合内不再进候选
	# 两条都过滤完之后候选为空 → 不预警，把喘息空间真的留给玩家。
	var pool: Array = []
	var total_w := 0.0
	for c in CRISES:
		if exclude_id != "" and str(c["id"]) == exclude_id:
			continue
		if not _eval_condition_simple(c["cond"]):
			continue
		if _crisis_hit_at(str(c["id"]), at_turn):
			continue
		if _crisis_cooldown_left(str(c["id"]), at_turn) > 0:
			continue
		pool.append(c)
		total_w += c["weight"]
	if pool.is_empty():
		return {}
	var roll := randf() * total_w
	for c in pool:
		roll -= c["weight"]
		if roll <= 0.0:
			return c
	return {}


## 记一条预警历史（顶部「预警回顾」读它）。
## lead = 提前几回合告知：1 = 常规预警，2 = 深预警
func _note_warning(c: Dictionary, lead: int) -> void:
	record_crisis_notice(c, lead)


## 用预计爆发回合区分每一场危机；生成、展示、读档均可安全补记。
func record_crisis_notice(c: Dictionary, lead: int = 1, notice_turn: int = -1) -> void:
	if c.is_empty():
		return
	var issued := turn if notice_turn < 0 else notice_turn
	var expected := issued + lead
	var id := str(c.get("id", ""))
	for entry in warn_history:
		var old_expected := int(entry.get("expected_hit_turn", int(entry.get("turn", 0)) + int(entry.get("lead", 1))))
		if str(entry.get("id", "")) == id and old_expected == expected:
			entry["expected_hit_turn"] = expected
			entry["crisis"] = c.duplicate(true)
			if lead == 0:
				entry["hit_turn"] = expected
			return
	var pc := _parse_cond_simple(str(c.get("cond", "")))
	warn_history.append({
		"turn": issued, "id": id, "hit_turn": expected if lead == 0 else -1,
		"lead": lead, "expected_hit_turn": expected, "crisis": c.duplicate(true),
		"value": int(metrics.get(str(pc.get("metric", "")), 0)),
	})


func restore_crisis_notices(next_hit_turn: int) -> void:
	record_crisis_notice(pending_crisis, 1, next_hit_turn - 1)
	record_crisis_notice(forecast_crisis, 2, next_hit_turn - 1)
	for hit in crisis_history:
		var c := crisis_by_id(str(hit.get("id", "")))
		record_crisis_notice(c, 0, int(hit.get("turn", turn)))


## 深预警是否已开启（科研点累计达标，**不消耗**）
func deep_warning_on() -> bool:
	return research_points >= DEEP_WARN_RESEARCH


## 该危机自己的冷却回合数：条目里写了 "cooldown" 就用它，没写就回落全局 CRISIS_COOLDOWN_TURNS
func crisis_cooldown_of(id: String) -> int:
	for c in CRISES:
		if c["id"] == id:
			return maxi(0, int(c.get("cooldown", CRISIS_COOLDOWN_TURNS)))
	return CRISIS_COOLDOWN_TURNS


## 该危机在 at_turn 时点还剩几回合冷却（>0 = 冷却中，不许再抽中）。
## at_turn 传 -1 表示「当前回合」；深预警要传它本来会被抽出的那个回合。
func _crisis_cooldown_left(id: String, at_turn: int = -1) -> int:
	var t: int = turn if at_turn < 0 else at_turn
	var cooldown := crisis_cooldown_of(id)
	var left := 0
	for h in crisis_history:
		if str(h["id"]) == id:
			left = maxi(left, cooldown - (t - int(h["turn"])))
	return left


## 该危机是不是「在 at_turn 这个回合刚刚爆发过」（防连出的硬底线）
func _crisis_hit_at(id: String, at_turn: int) -> bool:
	for h in crisis_history:
		if str(h["id"]) == id and int(h["turn"]) == at_turn:
			return true
	return false


## 最近一场危机爆发的回合（没有则 -1）
func _last_crisis_hit_turn() -> int:
	var t := -1
	for h in crisis_history:
		t = maxi(t, int(h["turn"]))
	return t


## 按 id 取危机条目（预警回顾面板要用名字、原文、影响、对策标签）
func crisis_by_id(id: String) -> Dictionary:
	for c in CRISES:
		if c["id"] == id:
			return c
	return {}


## 把预警历史里最近一条同名、还没爆发的记录标成「已爆发」
func _mark_warning_hit(id: String, hit_turn: int) -> void:
	for i in range(warn_history.size() - 1, -1, -1):
		var e: Dictionary = warn_history[i]
		if str(e["id"]) == id and int(e.get("expected_hit_turn", int(e.get("turn", 0)) + int(e.get("lead", 1)))) == hit_turn:
			e["hit_turn"] = hit_turn
			return


## 从 cond 字符串里取出 {metric, op, threshold}（预警历史要记下当时的数值）
func _parse_cond_simple(cond: String) -> Dictionary:
	cond = _seasonal_water_condition(cond)
	var m := RegEx.new()
	m.compile("(\\w+)\\s*(<=|>=|<|>|==)\\s*(-?\\d+)")
	var res := m.search(cond)
	if res == null:
		return {}
	return {"metric": res.get_string(1), "op": res.get_string(2), "threshold": int(res.get_string(3))}


## 简易条件求值（复用知识卡的表达式风格）
## 支持单个比较，也支持用 and 串起来的多个比较（**全部成立**才算通过）。
## 复合条件是为「候鸟大规模进田」加的：它的触发前提是「湖里鱼不够吃 **且** 社区本就有怨气」，
## 单独看社区低就报警会冤枉玩家（鱼还多的时候，候鸟不会大规模进田）。
## 注意：单条件的老写法（如 "turn == 1"、"vegetation < 45"）走的是同一条路，行为与改动前一致。
func _eval_condition_simple(cond: String) -> bool:
	cond = _seasonal_water_condition(cond)
	var m := RegEx.new()
	m.compile("(\\w+)\\s*(<=|>=|<|>|==)\\s*(-?\\d+)")
	var all := m.search_all(cond)
	if all.is_empty():
		return false
	for res in all:
		var metric := res.get_string(1)
		if not metrics.has(metric):
			return false          # 取不到的指标一律判不成立（老行为：单个取不到就 false）
		var cur: int = metrics[metric]
		var val := int(res.get_string(3))
		var ok := false
		match res.get_string(2):
			"<": ok = cur < val
			">": ok = cur > val
			"<=": ok = cur <= val
			">=": ok = cur >= val
			"==": ok = cur == val
		if not ok:
			return false
	return true
	return false


func _seasonal_water_condition(cond: String) -> String:
	var rule := water_reference()
	return cond.replace("seasonal_low", str(rule["low"])).replace("seasonal_high", str(rule["high"]))


## 某张卡某档位的成本（万，取整）
func tier_cost(card_id: String, tier: String) -> int:
	var card := _find_card(card_id)
	var discount := 1.0 + Talents.get_bonus("card_cost")
	return maxi(1, int(round(card["cost"] * TIER_COST_MULT[tier] * discount)))


## 从卡池抽 n 张（不重复）。
## 抽 n 张行动卡：预警期对策卡权重 ×CRISIS_COUNTER_WEIGHT（**概率提高，但不是必出**）；
## 没有预警时全体等权，与旧行为完全一致。整手最后打乱，免得对策卡永远躺在最左边。
## 第三条通路（0.1.17）：人鸟矛盾激化期间，食源对策卡（标签「生态修复 / 增殖放流」）权重
## ×CONFLICT_FEED_WEIGHT —— 这是暗线，**界面上不做任何提示**，玩家只会觉得
## 「最近老抽到补种/护渔的牌」。
func draw_cards(n: int, guarantee_season: bool = false) -> Array:
	var pool := season_pool()
	var total: int = mini(n, pool.size())
	var wanted := _crisis_counter_set()
	var rescue := _rescue_metric_set()
	var feed := _conflict_feed_set()
	var picked: Array = []

	while picked.size() < total and not pool.is_empty():
		var idx := _pick_weighted_index(pool, wanted, rescue, feed)
		picked.append(pool[idx])
		pool.remove_at(idx)

	if guarantee_season:
		_ensure_one_season_card(picked)
	picked.shuffle()
	return picked


# ==================== 季节卡池 ====================
# 卡池分季的依据是鄱阳湖的水文节律（春涨水→鱼群洄游产卵、夏高水→防洪度汛、
# 秋落水→洲滩露出好施工、冬枯水→碟形湖独立成湖），每张卡的 "season" 字段标它属于哪一季。
# 抽牌池 = 当季专属卡 + 四季通用卡（"all"）。四季通用的是补偿、转产、共管、立法、监测这类
# 现实里全年都在做的工作 —— 它们也是夏季（专属卡最少）的主要构成。

## 当前季节（spring / summer / autumn / winter）
func current_season() -> String:
	# Before the first turn, the title landscape previews spring.
	return SEASONS[(maxi(1, turn) - 1) % SEASONS.size()]


## 本回合是不是「本季的第 1 回合」（一局只有 4 次：第 1 / 5 / 9 / 13 回合）
func is_season_opener() -> bool:
	return (turn - 1) % 4 == 0


## 当季可抽的卡池 = 当季专属卡 + 四季通用卡
func season_pool() -> Array:
	var s := current_season()
	var out: Array = []
	for c in ACTION_CARDS:
		var cs: String = str(c.get("season", "all"))
		if cs == s or cs == "all":
			out.append(c)
	return out


## 当季专属卡（不含四季通用）—— 保底与图鉴提示用
func season_exclusive_cards() -> Array:
	var s := current_season()
	var out: Array = []
	for c in ACTION_CARDS:
		if str(c.get("season", "all")) == s:
			out.append(c)
	return out


## 季节首回合保底：手牌里一张当季专属卡都没有时，把最后一张换成随机一张专属卡。
## ⚠ 抽 7 张时春/秋/冬的自然命中率已 ~93%，这条实际主要在救夏季（专属卡本来就少）。
##   留着它的意义是「每年开局先看季节主题」这个节奏记忆点，不是真的防干涸。
func _ensure_one_season_card(picked: Array) -> void:
	if picked.is_empty():
		return
	var s := current_season()
	for c in picked:
		if str(c.get("season", "all")) == s:
			return
	var exclusives := season_exclusive_cards()
	if exclusives.is_empty():
		return
	picked[picked.size() - 1] = exclusives[_randi_range(0, exclusives.size() - 1)]


# ==================== 紧急调度 / 刷新手牌 ====================

## 本回合已调度、等着与手牌一起结算的牌：[{card_id, tier}]。
## 不放进 current_hand —— 它不占行动位，也不该被玩家取消，到回合末直接进算分队列。
var dispatched_cards: Array = []
## 整局累计打过哪些牌（id → 次数）。**不随回合清零**，供结算报告按整局口径评语。
var ever_played: Dictionary = {}
## 上一次用紧急调度的回合（-99 = 本局还没用过 → 首次可直接用）
var dispatch_last_turn: int = -99
## 本局已经用过几次（0 = 还没用过）。价格随它递增，reset_game() 要归零。
var dispatch_used_count: int = 0


## 本次调度要花多少钱：首次 DISPATCH_COST，之后**每用一次 +DISPATCH_PRICE_STEP**。
## 递增是为了让它在同一局里越用越不划算 —— 它是容错阀，不该变成常规出牌手段。
func dispatch_cost() -> int:
	return DISPATCH_COST + DISPATCH_PRICE_STEP * dispatch_used_count


## 按 id 取卡（找不到返回空字典）。界面层要用它拿卡面数据（名字/类别/费用），
## 所以这里给一个公开入口，不必从外面调私有的 _find_card。
func card_by_id(id: String) -> Dictionary:
	return _find_card(id)


## 花一笔钱（返回是否成功）。局内消费统一走这里，保证 total_spent 记账不漏。
func spend(amount: int, count_for_cards: bool = false) -> bool:
	if funds < amount:
		return false
	funds -= amount
	total_spent += amount
	if count_for_cards:
		turn_card_spent += amount
	else:
		turn_other_spent += amount
	funds_changed.emit()
	return true


## 现在能不能用紧急调度：钱够 + 本回合还没调过 + 过了冷却
func can_dispatch() -> bool:
	if funds < dispatch_cost():
		return false
	if not dispatched_cards.is_empty():
		return false          # 一回合只能调度一张
	if dispatch_last_turn > 0 and turn < dispatch_last_turn + DISPATCH_COOLDOWN_TURNS + 1:
		return false          # 中间要空满 DISPATCH_COOLDOWN_TURNS 个回合
	return true


## 还要等几个回合才能再用紧急调度（0 = 现在就能用）
func dispatch_cooldown_left() -> int:
	if dispatch_last_turn <= 0:
		return 0
	return maxi(0, dispatch_last_turn + DISPATCH_COOLDOWN_TURNS + 1 - turn)


## 调度一张牌：扣钱、记账。一律按有效投入档（见 DISPATCH_TIER 注释）。
func dispatch_card(card_id: String) -> bool:
	if not can_dispatch():
		return false
	if _find_card(card_id).is_empty():
		return false
	var paid := dispatch_cost()
	var previous_last_turn := dispatch_last_turn
	if not spend(paid, true):
		return false
	dispatch_used_count += 1     # 记在前头：下一次的报价立刻变贵
	dispatch_last_turn = turn
	dispatched_cards.append({"card_id": card_id, "tier": DISPATCH_TIER,
		"paid_cost": paid, "previous_last_turn": previous_last_turn})
	return true


## 撤销尚未结算的调度：按实际成交价退费，恢复报价及冷却。
func cancel_dispatch(card_id: String) -> bool:
	for i in dispatched_cards.size():
		var entry: Dictionary = dispatched_cards[i]
		if str(entry["card_id"]) != card_id: continue
		var paid := int(entry.get("paid_cost", DISPATCH_COST + DISPATCH_PRICE_STEP * maxi(0, dispatch_used_count - 1)))
		dispatched_cards.remove_at(i)
		funds += paid
		total_spent = maxi(0, total_spent - paid)
		turn_card_spent = maxi(0, turn_card_spent - paid)
		dispatch_used_count = maxi(0, dispatch_used_count - 1)
		dispatch_last_turn = int(entry.get("previous_last_turn", -99))
		funds_changed.emit()
		return true
	return false


## 每回合开始清掉上一轮的调度记录（dispatch_last_turn 要留着，冷却靠它算）
func clear_dispatch() -> void:
	dispatched_cards = []


## 加权随机抽一张的下标。权重 = 1.0 ×（对策卡 ? ×3）×（救火卡 ? ×2.5）×（食源牌 ? ×CONFLICT_FEED_WEIGHT）
func _pick_weighted_index(pool: Array, wanted: Dictionary, rescue: Dictionary, feed: Dictionary = {}) -> int:
	var total_w := 0.0
	for c in pool:
		total_w += _card_weight(c, wanted, rescue, feed)
	var roll := randf() * total_w
	for i in pool.size():
		roll -= _card_weight(pool[i], wanted, rescue, feed)
		if roll <= 0.0:
			return i
	return pool.size() - 1


func _card_weight(card: Dictionary, wanted: Dictionary, rescue: Dictionary, feed: Dictionary = {}) -> float:
	var w: float = CRISIS_COUNTER_WEIGHT if wanted.has(card["id"]) else 1.0
	if not rescue.is_empty() and _card_helps_any(card, rescue):
		w *= RESCUE_WEIGHT
	# 人鸟矛盾（暗线）：食源顶不住候鸟时，悄悄偏向补种 / 护渔一类的牌
	if not feed.is_empty() and feed.has(card["id"]):
		w *= CONFLICT_FEED_WEIGHT
	return w


## 人鸟矛盾激化期间要偏袒的卡 id 集合（按标签选，与危机对策卡同一套机制）；
## 没激化就是空字典 = 第三条通路不生效。⚠ 界面上**不做任何提示** —— 这是暗线。
func _conflict_feed_set() -> Dictionary:
	var out := {}
	if not bool(bird_conflict_state()["active"]):
		return out
	for c in ACTION_CARDS:
		for tag in c.get("tags", []):
			if str(tag) in CONFLICT_FEED_TAGS:
				out[str(c["id"])] = true
				break
	return out


## 当前哪些指标「逼近致死线」：低于「该指标致死线 + RESCUE_MARGIN」即算
func _rescue_metric_set() -> Dictionary:
	var out: Dictionary = {}
	for m in metrics:
		if m == "water_level": continue
		if int(metrics[m]) < failure_threshold_for(m) + RESCUE_MARGIN:
			out[m] = true
	var pressure := water_pressure(int(metrics.get("water_level", 50)))
	if pressure["side"] != "safe": out["water_level"] = pressure["side"]
	return out


## 这张牌能不能拉高 needed 里的任意一项（只看正向效果，即时/延迟都算）
func _card_helps_any(card: Dictionary, needed: Dictionary) -> bool:
	for tier in card.get("tiers", {}).values():
		for e in tier.get("effects", []):
			if e["metric"] == "water_level" and needed.has("water_level"):
				if (needed["water_level"] == "high" and int(e["delta"]) < 0) or (needed["water_level"] == "low" and int(e["delta"]) > 0):
					return true
				continue
			if int(e["delta"]) > 0 and needed.has(str(e["metric"])):
				return true
	return false


## 某个危机的对策卡 id 列表（卡牌 tags 命中危机 needs 任一项即算对策卡）
func counter_ids_for(crisis: Dictionary) -> Array:
	var needs: Array = crisis.get("needs", [])
	var out: Array = []
	if needs.is_empty():
		return out
	for c in ACTION_CARDS:
		for tag in c.get("tags", []):
			if tag in needs:
				out.append(c["id"])
				break
	return out


## 当前预警危机的对策卡 id 列表（无预警时为空）
func counter_card_ids() -> Array:
	if pending_crisis.is_empty():
		return []
	return counter_ids_for(pending_crisis)


## 当前预警危机的对策卡集合（字典，抽牌时快速命中判定用）
func _crisis_counter_set() -> Dictionary:
	var out := {}
	for cid in counter_card_ids():
		out[cid] = true
	return out


## 能否执行：资金够 + 行动位够
func can_execute(card_id: String, tier: String) -> bool:
	var max_actions := action_slots()
	if used_action_ids.size() - free_actions_executed >= max_actions:
		return false
	return funds >= tier_cost(card_id, tier)


## 执行一张行动卡（返回是否成功）。
##
## free = true 是**紧急调度**专用的路径：那张牌在调度时就已经付过调度费了，
## 而且**不占行动位** —— 所以既不再扣这张卡自己的钱，也不受行动位上限拦阻。
## 其余流程一字不改（即时效果、延迟入队、物种/植物/围垦加成、协同触发、
## 算分流水账），所以它照样会出现在算分动画与结算里。
##
## ⚠ 踩过的坑：不给这条路径的话会有两个 bug ——
##   ① 简单模式打满 4 张后，调度牌的 can_execute 直接返回 false（4 >= 4），
##      整张牌被跳过：玩家付了 40 万什么都没拿到，算分动画里也少一张；
##   ② 没被拦时（只打 3 张）会 **扣两次钱** —— 调度费 + 这张卡自己的档位价。
func execute_action(card_id: String, tier: String, free: bool = false) -> bool:
	var card := _find_card(card_id)
	if card.is_empty():
		return false
	if not free:
		if not can_execute(card_id, tier):
			return false
		var cost := tier_cost(card_id, tier)
		funds -= cost
		total_spent += cost
		turn_card_spent += cost
	# 行动位上限只在 free=false 时拦；但两种路径都要记进 used_action_ids ——
	# 它同时是「本回合打过什么」的依据（自然演化的条件、协同触发都读它）。
	used_action_ids.append(card_id)
	if free:
		free_actions_executed += 1
	# 全局累计（**跨回合不清零**）：结算报告的「转产与补偿覆盖率」要按整局口径算，
	# 而 used_action_ids 每回合开始都会被清空，拿它统计等于只看最后一回合。
	ever_played[card_id] = int(ever_played.get(card_id, 0)) + 1

	var tier_data: Dictionary = card["tiers"][tier]
	for e in tier_data["effects"]:
		var delay: int = e["delay"]
		if delay <= 0:
			_apply_delta(e["metric"], e["delta"], true, "card", str(card["name"]), str(card["id"]))
		else:
			effects_queue.append({
				"metric": e["metric"], "delta": e["delta"],
				"remaining": delay, "source": card["name"],
				# 记下排入的回合：delay=1 的效果当回合结算就会到期，
				# 若不记这个，它会和「前几轮留下的」混在一起，第 1 回合就会出现
				# 「前几轮遗留」这种不存在的说法。见 advance_effects()。
				"queued_turn": turn,
			})
			# 延迟效果在流水账里也记一条**预告**：applied 恒为 0（此刻确实还没落地），
			# 只为让算分动画能在这张牌上标出「N 回合后才生效」。
			# 没有它就麻烦了：26 张牌里有 12 张的 effective 档是纯延迟效果
			# （植被补种 / 增殖放流 / 湿地保护立法 等全部"长效牌"），
			# 打出去一个字都不爆，看起来像什么都没干。
			# phase 用 "card_delayed" —— 它**不在** SCORE_PHASE_ORDER 里，
			# 所以小票的四类来源求和完全不受影响。
			if metrics.has(e["metric"]):
				var preview: int = int(e["delta"])
				if preview < 0 and e["metric"] != "water_level":
					preview = _scaled_delta(preview)   # 与到期时 _apply_delta 的口径保持一致
				score_ledger.append({
					"phase": "card_delayed", "label": str(card["name"]),
					"ref_id": str(card["id"]), "metric": str(e["metric"]),
					"raw": preview, "applied": 0,
					"before": metrics[e["metric"]], "after": metrics[e["metric"]],
					"remaining": delay,
				})

	# 科研投入奖励
	if card_id == "research":
		research_points += {"basic": 1, "effective": 2, "deep": 3}[tier]

	# 行动对特定物种的直接加成（某选项让某物种增多）
	if ACTION_SPECIES_BONUS.has(card_id):
		for sid in ACTION_SPECIES_BONUS[card_id]:
			species_pop[sid] = clampi(species_pop[sid] + ACTION_SPECIES_BONUS[card_id][sid], 0, 100)

	# 行动对特定植物的直接加成
	if ACTION_PLANT_BONUS.has(card_id):
		for pid in ACTION_PLANT_BONUS[card_id]:
			plant_pop[pid] = clampi(plant_pop[pid] + ACTION_PLANT_BONUS[card_id][pid], 0, 100)

	# 行动对环湖用地（房子数量）的影响
	if ACTION_SETTLEMENT_DELTA.has(card_id):
		_apply_settlement(ACTION_SETTLEMENT_DELTA[card_id])

	# 人工浮岛：打出「人工浮岛」→ 沙盘出现浮岛；「底泥清淤疏浚」→ 清除
	if card_id == "floating_island":
		floating_islands = 4
	elif card_id == "dredge":
		floating_islands = 0

	funds_changed.emit()
	metrics_changed.emit()
	check_failure_now()   # 出牌把指标打到致死线以下 → 当场判负
	return true


## 结算自然演化（每回合结束调用）
## 设计：不做决策生态会缓慢恶化（压力），但不会瞬间崩盘（给玩家反应时间）
## ⚠ 增减清单由 natural_evolution_plan() 给出：HUD 的「悬停提示」读的是同一份 plan，
##   所以提示里写的数字和实际结算的数字同源，不会各写一套。
func natural_evolution() -> void:
	for e in natural_evolution_plan():
		# 统一换算实际变动；水位与洪旱已给最终值，其余负向演化只缩放一次。
		var d: int = _evolution_delta(e)
		_apply_delta(str(e["metric"]), d, false, "routine", str(e["why"]))
		if e.get("hydrology", false) and d != 0:
			_add_log("%s：%s %+d" % [e["why"], METRIC_NAMES[e["metric"]], d])
	_sync_species()
	_sync_plants()
	metrics_changed.emit()


## 本回合自然演化会发生哪些增减（只读推演，不改任何状态）
## 返回 [{metric, delta, min, max, kind, why}]
##   delta   = 引擎实际使用的原始值（水位那一条是本次随机到的值）
##   min/max = 叠加难度负向倍率后，玩家真正会看到的区间
##   kind    = random / loss / gain / none
## roll_random=false 时不去动水位那次随机（HUD 每帧查它，绝不能扰动全局随机序列）
func settlement_water_delta() -> int:
	# Reserve one seasonal weather result per run/turn. Forecasts and reloads
	# read the same roll, without consuming or rerolling the global RNG.
	var drift := water_drift_range(current_season())
	var weather := RandomNumberGenerator.new()
	weather.seed = run_seed + turn * 104729 + 0x5455524E
	return weather.randi_range(int(drift[0]), int(drift[1]))


func natural_evolution_plan(roll_random: bool = true, water_delta_override: int = 999, source_metrics: Dictionary = {}) -> Array:
	var sim: Dictionary = (source_metrics if not source_metrics.is_empty() else metrics).duplicate()   # 推演副本：后一步的条件要看前几步之后的值（与原执行顺序一致）
	var out: Array = []

	# 1) 水位按**季节节律**变化 —— 贴鄱阳湖的水文现实：春涨水、夏高水、秋落水、冬枯水。
	#    水位涨落独立于难度；难度放大的是下面的生态压力。
	#    ⚠ 区间内的随机是保留的：节律决定「往哪个方向走」，具体走几步仍不确定，
	#      否则每局的水位曲线会一模一样，肉鸽性就没了。
	var season := current_season()
	var rule := water_reference(season)
	var drift := water_drift_range(season)
	var wl_raw_lo: int = int(drift[0])
	var wl_raw_hi: int = int(drift[1])
	var wl_why: String = "春季涨水（五河来水，水位小幅回升）"
	match season:
		"summer":
			wl_why = "夏季高水（长江汛期，水位大幅上涨、易漫滩）"
		"autumn":
			wl_why = "秋季落水（水位回落，洲滩渐次露出）"
		"winter":
			wl_why = "冬季枯水（全年最低，碟形湖脱离主湖）"
	var wl: int = settlement_water_delta() if roll_random else roundi((wl_raw_lo + wl_raw_hi) / 2.0)
	if water_delta_override != 999: wl = clampi(water_delta_override, wl_raw_lo, wl_raw_hi)
	out.append({"metric": "water_level", "delta": wl,
		"applied_delta": wl, "min": wl_raw_lo, "max": wl_raw_hi, "kind": "random",
		"why": wl_why})
	var water_before: int = int(sim.get("water_level", 0))
	sim["water_level"] = clampi(water_before + wl, 0, 100)

	# 水位本身不致死；按整季暴露结算一次，再让水质→植被→候鸟继续联动。
	var pressure := water_turn_pressure(water_before, int(sim["water_level"]))
	for metric in pressure["effects"]:
		var loss: int = int(pressure["effects"][metric])
		var why := "%s季%s：行动后水位 %d → 自然变化后 %d，参考 %d–%d，季内暴露 ×%.2f" % [
			SEASON_NAMES[season], "干旱压力" if pressure["side"] == "low" else "淹水压力",
			water_before, sim["water_level"], pressure["low"], pressure["high"], pressure["multiplier"]]
		out.append({"metric": metric, "delta": loss, "applied_delta": loss,
			"min": loss, "max": loss, "kind": "loss", "why": why, "hydrology": true})
		sim[metric] = clampi(int(sim.get(metric, 0)) + loss, 0, 100)

	# 2) 水质：无治理则缓慢恶化
	if used_action_ids.has("water_monitor") or used_action_ids.has("research") or used_action_ids.has("smart_patrol"):
		out.append({"metric": "water_quality", "delta": 0, "min": 0, "max": 0, "kind": "none",
			"why": "本回合已投入监测/科研/智慧巡护 → 水质不恶化"})
	else:
		out.append({"metric": "water_quality", "delta": -2,
			"min": _scaled_delta(-2), "max": _scaled_delta(-2), "kind": "loss",
			"why": "没打监测/科研/智慧巡护 → 缓慢恶化"})
		sim["water_quality"] = clampi(int(sim.get("water_quality", 0)) + _scaled_delta(-2), 0, 100)

	# 3) 植被受水质拖累：水质差则植被退化（看推演后的水质）
	var q: int = int(sim.get("water_quality", 0))   # 一律 .get：残留/老存档可能缺项，HUD 每帧都要调它，不能抛错
	if q < 45:
		out.append({"metric": "vegetation", "delta": -3,
			"min": _scaled_delta(-3), "max": _scaled_delta(-3), "kind": "loss",
			"why": "水质 %d 已低于 45 → 植被被拖累" % q})
		sim["vegetation"] = clampi(int(sim.get("vegetation", 0)) + _scaled_delta(-3), 0, 100)
	elif q > 70:
		out.append({"metric": "vegetation", "delta": 1, "min": 1, "max": 1, "kind": "gain",
			"why": "水质 %d 良好（>70）→ 植被恢复" % q})
		sim["vegetation"] = clampi(int(sim.get("vegetation", 0)) + 1, 0, 100)
	else:
		out.append({"metric": "vegetation", "delta": 0, "min": 0, "max": 0, "kind": "none",
			"why": "水质 %d（45~70）→ 植被本回合不变" % q})

	# 4) 季节迁徙与栖息地变化共同决定候鸟值，预览和实际结算共用。
	var migration: int = BIRD_MIGRATION_DELTA[season]
	out.append({"metric": "birds", "delta": migration, "applied_delta": migration,
		"min": migration, "max": migration, "kind": "loss" if migration < 0 else "gain",
		"why": BIRD_MIGRATION_REASON[season]})
	# 植被仍是候鸟食物基础（看推演后的植被）。
	var veg: int = int(sim.get("vegetation", 0))
	if veg < 42:
		out.append({"metric": "birds", "delta": -3,
			"min": _scaled_delta(-3), "max": _scaled_delta(-3), "kind": "loss",
			"why": "植被 %d 已低于 42 → 候鸟食物不足" % veg})
	elif veg > 70:
		out.append({"metric": "birds", "delta": 1, "min": 1, "max": 1, "kind": "gain",
			"why": "植被 %d 良好（>70）→ 候鸟种群回升" % veg})
	else:
		out.append({"metric": "birds", "delta": 0, "min": 0, "max": 0, "kind": "none",
			"why": "植被 %d（42~70）→ 候鸟本回合不变" % veg})

	# 5) 鱼类：禁渔带来缓慢恢复，但执法不足则恢复停滞
	if used_action_ids.has("patrol") or used_action_ids.has("guard_team"):
		out.append({"metric": "fish", "delta": 2, "min": 2, "max": 2, "kind": "gain",
			"why": "本回合已投入巡护/护渔 → 鱼类缓慢恢复"})
	else:
		out.append({"metric": "fish", "delta": -1,
			"min": _scaled_delta(-1), "max": _scaled_delta(-1), "kind": "loss",
			"why": "没打巡护/护渔 → 被非法捕捞蚕食"})

	# 6) 社区信任：长期缺补偿则持续下降
	if int(sim.get("community", 0)) < 45 and not used_action_ids.has("community_comp"):
		out.append({"metric": "community", "delta": -3,
			"min": _scaled_delta(-3), "max": _scaled_delta(-3), "kind": "loss",
			"why": "信任度 %d 低于 45 且本回合没打补偿 → 持续下降" % int(sim.get("community", 0))})
	else:
		out.append({"metric": "community", "delta": 0, "min": 0, "max": 0, "kind": "none",
			"why": "本回合不变（信任度 ≥ 45，或已投入补偿）"})

	return out


## 只读：负向变动在本地难度下实际会掉多少（与 _apply_delta 走同一处代码，保证口径一致）
func _scaled_delta(delta: int) -> int:
	if delta < 0:
		return roundi(delta * PENALTY_MULT[difficulty])
	return delta

func _evolution_delta(e: Dictionary) -> int:
	if e.has("applied_delta"): return int(e["applied_delta"])
	return clampi(_scaled_delta(int(e["delta"])), int(e["min"]), int(e["max"]))

## 枚举全部水文随机值，逐条夹取，保留水质/植被门槛联动，悬停推演不消耗随机数。
func natural_evolution_outcomes(source_metrics: Dictionary = {}) -> Array:
	var drift: Array = water_drift_range()
	var outcomes: Array = []
	var starting_metrics: Dictionary = (source_metrics if not source_metrics.is_empty() else metrics).duplicate()
	for wl in range(int(drift[0]), int(drift[1]) + 1):
		var snapshot: Dictionary = starting_metrics.duplicate()
		var pressure_losses: Dictionary = {}
		for e in natural_evolution_plan(false, wl, starting_metrics):
			var metric: String = str(e["metric"])
			var d := _evolution_delta(e)
			snapshot[metric] = clampi(int(snapshot.get(metric, 0)) + d, 0, 100)
			if e.get("hydrology", false): pressure_losses[metric] = d
		outcomes.append({"metrics": snapshot, "pressure_losses": pressure_losses})
	return outcomes


## ── HUD 悬停提示用：某一项指标「本回合会掉多少 / 红线在哪」──
## 只读，不改状态。数据来源：natural_evolution_plan()（回合末自然演化）+ pending_crisis（下回合结算时爆发的危机）
## 枚举水位随机值，汇总同一指标的全部变动，包含越界压力及后续生态联动。
func metric_hover_preview(metric: String) -> Dictionary:
	# Snapshot all inputs used by the deterministic forecast. Comparing small
	# values catches in-place changes as well as new games and loaded saves.
	var key: Array = [metrics, difficulty, turn, run_seed, used_action_ids, pending_crisis]
	if key != _hover_preview_key:
		_hover_preview_key = key.duplicate(true)
		_hover_previews.clear()
	if not _hover_previews.has(metric):
		_hover_previews[metric] = _compute_metric_hover_preview(metric)
	# Callers may freely edit their returned copy without poisoning the cache.
	return _hover_previews[metric].duplicate(true)

func _compute_metric_hover_preview(metric: String) -> Dictionary:
	var cur: int = int(metrics.get(metric, 0))
	var line: int = failure_threshold_for(metric)
	var conflict: Dictionary = bird_conflict_state()
	var conflict_penalty: int = int(conflict["penalty"]) if bool(conflict["active"]) else 0
	# 回合结算先扣人鸟矛盾，再推进自然演化。自然演化可能因此跨过社区信任等指标的衰减门槛，
	# 所以要在这份只读推演副本上先扣分，再重新计算全链自然变化，不能只从最终结果减一个常数。
	var projected_metrics: Dictionary = metrics.duplicate(true)
	if conflict_penalty > 0:
		for affected in ["community", "birds"]:
			projected_metrics[affected] = clampi(int(projected_metrics.get(affected, 0)) - conflict_penalty, 0, 100)

	var end_min := 100
	var end_max := 0
	for outcome in natural_evolution_outcomes(projected_metrics):
		var value: int = int(outcome["metrics"].get(metric, cur))
		end_min = mini(end_min, value)
		end_max = maxi(end_max, value)
	var nat_min: int = end_min - cur
	var nat_max: int = end_max - cur

	# 已预警、下回合结算时才爆发的危机：只看它有没有打到这一项（危机伤害不吃难度负向倍率）
	var crisis_name := ""
	var crisis_delta := 0
	if not pending_crisis.is_empty():
		for e in pending_crisis.get("effects", []):
			if str(e["metric"]) == metric:
				crisis_name = str(pending_crisis.get("name", "危机"))
				crisis_delta = int(e["delta"])
				break

	var worst: int = clampi(end_min + crisis_delta, 0, 100)
	return {
		"metric": metric, "cur": cur, "line": line,
		"kind": "random" if end_min != end_max else ("loss" if nat_min < 0 else ("gain" if nat_min > 0 else "none")),
		"nat_min": nat_min, "nat_max": nat_max,
		"end_min": end_min, "end_max": end_max,
		"crisis_name": crisis_name, "crisis_delta": crisis_delta, "worst": worst,
		"margin_nat": end_min - line,      # 只算自然演化时的余量（取最坏的一头）
		"break_nat": metric != "water_level" and end_min < line,
		"break_total": metric != "water_level" and worst < line,
		"penalty_mult": PENALTY_MULT[difficulty],
		# 人鸟矛盾 / 候鸟进田的判定原样带上：悬停小窗要显示「回合末会扣多少」，
		# 数字必须和回合末真正结算的那一次同源（两侧都调 bird_conflict_state）。
		"conflict": conflict,
	}


# ==================== 顶部态势播报 + 人鸟矛盾（0.1.17）====================
## 人鸟矛盾差值 = max(0, 候鸟−沉水植被) + max(0, 候鸟−鱼类)。纯只读。
func bird_conflict_index() -> int:
	var b: int = int(metrics.get("birds", 0))
	var v: int = int(metrics.get("vegetation", 0))
	var f: int = int(metrics.get("fish", 0))
	return maxi(0, b - v) + maxi(0, b - f)


## 人鸟矛盾的一次判定（纯只读，不改状态）。
## ⚠ 顶部播报、悬停小窗、回合末实际结算**全走这一个入口** —— 提示里写的数字和真正
##   扣的数字永远同源，不会各写一套。
func bird_conflict_state() -> Dictionary:
	var b: int = int(metrics.get("birds", 0))
	var v: int = int(metrics.get("vegetation", 0))
	var f: int = int(metrics.get("fish", 0))
	var gap_v: int = maxi(0, b - v)
	var gap_f: int = maxi(0, b - f)
	var index: int = gap_v + gap_f
	var abundant: bool = b >= BIRD_SURPLUS_MIN
	# 「候鸟进田」＝ 候鸟多 + 食源紧（沉水植被或鱼类低于线）
	var field: bool = abundant and (v < FOOD_SHORT_LINE or f < FOOD_SHORT_LINE)
	var penalty: int = 0
	if field and index >= CONFLICT_THRESHOLD:
		penalty = clampi(1 + (index - CONFLICT_THRESHOLD) / CONFLICT_PENALTY_STEP, 1, CONFLICT_PENALTY_MAX)
	return {
		"birds": b, "vegetation": v, "fish": f,
		"gap_veg": gap_v, "gap_fish": gap_f, "index": index,
		"threshold": CONFLICT_THRESHOLD, "abundant": abundant,
		"field": field, "active": penalty > 0, "penalty": penalty,
	}


## 本回合的顶部态势（纯只读，指标一变就能重算 → 横幅是「实时」的，不是念稿）。
## 返回 {tags, short, lines, body}
##   tags  告急标签（drought / flood / birds_field / calm）；弹窗去重与测试判据都用它
##   short 单行简报：顶部横幅
##   body  多行详述：给「第 N 回合 · 事件」弹窗
##
## ⚠ 人鸟矛盾**永远不出现在这里**（也不出现在弹窗里）—— 它是暗线：
##   横幅只给「水位越界 / 候鸟进田」这类参考，玩家自己该不该管、管哪一项，要自己判断。
##   激化后的扣值只在两处可见：① 结算数字里；② 悬停「社区信任 / 候鸟种群」的详情页，
##   与其余自然扣值显示在一起（见 main.gd 的 _fill_metric_tip）。
func situation_report() -> Dictionary:
	var st := bird_conflict_state()
	var season := current_season()
	var wl: int = int(metrics.get("water_level", 0))
	var pressure := water_pressure(wl, season)
	var side := str(pressure["side"])
	var dev: int = int(pressure["deviation"])

	var tags: Array = []
	var shorts: Array = []
	var lines: Array = []

	# 命中的情况，按优先级排：水位越界 → 候鸟进田
	var keys: Array = []
	if side == "low" and dev >= WATER_ALERT_MARGIN:
		keys.append("drought")
	elif side == "high" and dev >= WATER_ALERT_MARGIN:
		keys.append("flood")
	if bool(st["field"]):
		keys.append("birds_field")

	if keys.is_empty():
		# 什么都不告急：只说水位在不在区间里，不报数字
		var calm_key: String = "calm_safe" if side == "safe" else "calm_off"
		tags.append("calm")
		shorts.append(str(SITUATION_TEXT[calm_key]))
		lines.append(str(SITUATION_TEXT[calm_key]))
	else:
		for k in keys:
			var key := str(k)
			tags.append(key)
			shorts.append(str(SITUATION_TEXT[key]))
			lines.append(str(SITUATION_TEXT[key]) + str(SITUATION_WHY.get(key, "")))

	# 详情正文 = 上面那几句 + 一行现状数值（数字只留在这里，横幅上不出现）
	var vals: Array = []
	for metric in METRIC_NAMES:
		vals.append("%s %d" % [METRIC_NAMES[metric], int(metrics.get(metric, 0))])
	var body := ""
	for l in lines:
		body += "· " + str(l) + "\n"
	body += "· 当前六项：" + "、".join(vals)
	# ⚠ body 里刻意不写「水位 40（春季参考 49–61，偏低 9 点）」这种行：和上面那句重复，
	#   而且把参考区间摆到玩家眼前就等于把「该往哪个方向调」直接送出去。
	return {"tags": tags, "short": " ｜ ".join(shorts), "lines": lines, "body": body}


## 顶部横幅当前该显示的那一行（纯只读）。整局任何时刻调都返回与当前数值一致的话。
## ⚠ 第 1 / 15 回合例外：这两回合的横幅**让给开场与收官那两句**（玩测反馈明确要求
##   「开头和结尾就在事件幅里」，不能只躺在弹窗里）。这两回合只放那一句，不拼当前态势 ——
##   横幅是单行 Label（clip_text + TRIM_ELLIPSIS，可用宽 810px）：实测 13 号字约 11px/字，
##   容量 70 字出头；开场那句 48 字，再拼一段态势（洪水 32 字）就是 83 字，尾巴会被吃掉。
##   当下态势在事件弹窗正文与右侧指标面板里都有，丢不了。
##   想让第 11 回合的政策通知也上横幅，把它加进 BANNER_BEAT_TURNS。
func situation_banner() -> String:
	if turn in BANNER_BEAT_TURNS:
		var beat := narrative_beat(turn)
		if beat != "":
			return beat
	return str(situation_report()["short"])


## 本回合的叙事节拍（固定台词，不做生态判断）；没有就返回空串
func narrative_beat(at_turn: int) -> String:
	return str(NARRATIVE_BEATS.get(at_turn, ""))


## 回合末结算人鸟矛盾：差值彻底拉开才扣，社区与候鸟各扣 penalty 点。
## ⚠ 这是暗线：横幅 / 事件弹窗里都不提；流水账也**并进 routine 相位**，让它和其余自然扣值
##   在结算动画与悬停小窗里显示在同一处（玩家要把「候鸟比食源高多少」当线索自己算）。
## ⚠ 也不走负向难度倍率（_apply_delta 的 apply_penalty=false）—— 「显示多少就扣多少」，
##   否则悬停小窗写的「社区 −2」在困难档实际是 −4，提示就成了假话。
func _maybe_bird_conflict() -> void:
	turn_bird_conflict = {}
	if game_over:
		return
	var st := bird_conflict_state()
	if not bool(st["active"]):
		return
	var pen: int = int(st["penalty"])
	_apply_delta("community", -pen, false, "routine", "人鸟矛盾")
	_apply_delta("birds", -pen, false, "routine", "人鸟矛盾")
	turn_bird_conflict = st.duplicate(true)
	turn_bird_conflict["turn"] = turn
	conflict_history.append({"turn": turn, "index": int(st["index"]), "penalty": pen})
	# 结算里只留一句事实，不给公式、不给 ⚠：想弄明白的玩家自己去看悬停小窗
	_add_log("人鸟矛盾 −%d：社区信任、候鸟种群" % pen)


## 结算卡牌协同：本回合打出指定组合则触发额外效果
func resolve_synergies() -> void:
	triggered_synergies = []
	for s in SYNERGIES:
		var ok := true
		for req in s["requires"]:
			if not used_action_ids.has(req):
				ok = false
				break
		if not ok:
			continue
		# 避免重复触发（同一协同一局内只生效一次）
		if s["id"] in _fired_synergies:
			continue
		_fired_synergies.append(s["id"])
		triggered_synergies.append(s["name"])
		_add_log("★ 协同「%s」：%s" % [s["name"], s["desc"]])
		for e in s["bonus"]:
			_apply_delta(e["metric"], e["delta"], true, "synergy", str(s["name"]), str(s["id"]))
			_add_log("   %s %+d" % [METRIC_NAMES[e["metric"]], e["delta"]])
	_sync_species()
	_sync_plants()


## 推进延迟效果队列（回合结束调用）
func advance_effects() -> void:
	var remaining: Array = []
	for e in effects_queue:
		e["remaining"] -= 1
		if e["remaining"] <= 0:
			# 分成两个来源：
			#   pending  = 本回合刚打出的牌、当回合就到期（delay=1 就是这种）
			#   leftover = 前几轮排队、现在才到期
			# 两者执行时机相同，但玩家看到「前几轮遗留」出现在第 1 回合会莫名其妙。
			# 旧存档的队列条目没有 queued_turn，按 -1 处理 → 归入 leftover，安全。
			var ph: String = "pending" if int(e.get("queued_turn", -1)) == turn else "leftover"
			_apply_delta(e["metric"], e["delta"], true, ph, str(e["source"]))
			_add_log("「%s」的延迟效果显现：%s %+d" % [e["source"], METRIC_NAMES[e["metric"]], e["delta"]])
		else:
			remaining.append(e)
	effects_queue = remaining
	metrics_changed.emit()


## 回合结束：推进延迟、自然演化、结算协同、检查失败与知识卡
## Isolated forecast: reuse settlement rules without signals to the live scene,
## talent writes, purchases, or consuming the run's global random stream.
var _is_settlement_preview := false

func preview_settlement(cards: Array) -> Dictionary:
	var forecast = get_script().new()
	forecast.load_state(serialize().duplicate(true), false)
	forecast._is_settlement_preview = true
	for card in cards:
		forecast.execute_action(str(card["card_id"]), str(card["tier"]), bool(card.get("dispatched", false)))
		if forecast.game_over: break
	if not forecast.game_over:
		forecast.end_turn()
	var result: Dictionary = forecast.metrics.duplicate(true)
	forecast.free()
	return result


func end_turn() -> void:
	advance_effects()
	resolve_synergies()      # 卡牌协同（在自然演化前结算，让玩家看到组合收益）
	# 人鸟矛盾：用「这一手打完、自然涨落之前」的数值判定 —— 判据就是「你这回合把候鸟
	# 撑得比食源高了多少」。放在自然演化之前，是为了让它和悬停小窗的推演走同一批数字。
	_maybe_bird_conflict()
	natural_evolution()

	# 结转规则：未用资金计息（利滚利），最多 max_carry 万，溢出转科研点（天赋可提升）
	var max_carry := MAX_CARRY + int(Talents.get_bonus("carry"))
	var rate := INTEREST_RATE + Talents.get_bonus("interest")
	carry = int(round(funds * (1.0 + rate)))
	if carry > max_carry:
		var overflow := carry - max_carry
		research_points += overflow / 10
		carry = max_carry
	funds = 0

	# ==================== 危机系统（回合末，2026-09-28 从 start_new_turn 挪来）====================
	# 结算预警中的危机 → 深预警升格 → 抽新预警 → 预告 2 回合后，全部在回合末做。
	#
	# 为什么挪：原来危机的伤害与判负发生在**下回合开局**，而玩家在结算弹窗里看到的
	# 指标是「本回合结算后」的值（还都在红线上）。结果是看着条都还是绿的、点一下
	# 「继续」，下一刻就判负，完全莫名其妙。挪到回合末后，危机伤害直接进本回合的
	# 结算数字，判负也在结算里发生，玩家看得见自己是怎么死的。
	#
	# ⚠ 预警必须**一起**挪，不能只挪结算：只挪结算会让危机晚一整回合才落地，
	#   玩家白得多一整个回合准备（难度变松）。现在预警在本回合末发出 → 玩家下一
	#   回合整回合可以应对 → 下回合末爆发，准备窗口仍是 1 个回合，与原来一致。
	# ⚠ 顺序不能换：升格必须在抽新的之前，否则新抽的会把预告顶掉（预告就成假的了）。
	# ⚠ 放在 _check_failure() 之前：_resolve_pending_crisis 内部会 check_failure_now()，
	#   判负后 _check_failure() 直接返回 true 让 end_turn 提前 return，
	#   后面「打满回合」的 game_ended 就不会重复发一次报告。
	_resolve_pending_crisis()
	_promote_forecast_if_needed()
	if not _is_settlement_preview:
		_maybe_warn_crisis()
		_maybe_forecast_crisis()
	# 统一 emit 一次：UI 弹窗要同时展示「下回合」与「再下一回合」两条，
	# 所以必须等两场都定下来再通知（emit 在 _maybe_* 里发会导致弹窗只有前一条）。
	if not pending_crisis.is_empty():
		crisis_warned.emit(pending_crisis)

	# 失败判定：任一指标跌破致死线 → 被撤换，提前结束
	if _check_failure():
		return

	if not _is_settlement_preview:
		_check_knowledge_triggers()

	if turn >= TOTAL_TURNS:
		game_over = true
		game_ended.emit(generate_report())
	# 下一回合由主场景在展示完结算反馈后调用 start_new_turn()


## 当前难度的每回合行动位（= 一回合最多能打几张牌）
func action_slots() -> int:
	# ⚠ 首回合要算上「运筹帷幄」类词条的 +N。所有地方（能否出牌判定、HUD 提示、
	#   「已选 x/y」）都必须走这个入口 —— 0.0.8 真窗口实测：以前只有 can_execute
	#   自己加这一项，结果首回合 HUD 写「每回合最多 3 个行动」、实际能打 4 张。
	var n := int(MAX_ACTIONS_BY_DIFFICULTY.get(difficulty, 3))
	if turn == 1:
		n += int(Talents.get_bonus("first_turn_actions"))
	return n


## 当前难度的判负阈值：指标低于此值即判负
func failure_threshold() -> int:
	return FAILURE_THRESHOLD[difficulty]


## 某一项指标的判负阈值 = 难度线 + 该项偏移 + 该难度下的额外调整
## （两张表里都没写就是难度线本身）
func failure_threshold_for(metric: String) -> int:
	# -1 表示没有致死线；所有难度（包括噩梦）都按季节生态影响处理水位。
	if metric == "water_level": return -1
	# ⚠ 噩梦档**不叠任何偏移**：995f784 那版就是六项共用一条线，
	#   "每指标单独红线"是后来才加的。照搬偏移会把噩梦档悄悄变简单
	#   （社区 +10 会把它的线从 45 抬到 55，等于开局凭空多出 7 点余量）。
	if difficulty == Difficulty.NIGHTMARE:
		return clampi(failure_threshold(), 5, 95)
	var offset: int = int(FAILURE_THRESHOLD_OFFSET.get(metric, 0))
	offset += int(FAILURE_THRESHOLD_EXTRA.get(difficulty, {}).get(metric, 0))
	return clampi(failure_threshold() + offset, 5, 95)


## 检查是否有指标跌破失败线（上级对政绩不满，将你撤换）
func _check_failure() -> bool:
	if game_over:
		return is_failure   # 已经判负，不重复判、不重复发信号
	for metric in metrics:
		if metric == "water_level": continue
		var threshold: int = failure_threshold_for(metric)
		if metrics[metric] < threshold:
			is_failure = true
			game_over = true
			failure_metric = metric
			failure_value = metrics[metric]
			failure_reason = "上级对你的政绩不满意，将你撤换。"
			_add_log("✖ %s（%s 只剩 %d，已跌破生态红线 %d）" % [failure_reason, METRIC_NAMES.get(metric, metric), failure_value, threshold])
			game_ended.emit(generate_report())
			return true
	return false


## 指标一变就查：出牌、危机爆发、自然演化都可以直接调用 → 判负即时生效
func check_failure_now() -> bool:
	return _check_failure()


## 当前所有跌破致死线的指标（失败报告用来把死因说全）
func metrics_below_threshold() -> Array:
	var out: Array = []
	for metric in metrics:
		if metric == "water_level": continue
		var threshold: int = failure_threshold_for(metric)
		if metrics[metric] < threshold:
			out.append({"metric": metric, "value": metrics[metric]})
	out.sort_custom(func(a, b): return int(a["value"]) < int(b["value"]))
	return out


## 知识卡的两条节拍规则（2026-10-03 反馈）——
##   ① 一回合最多出一张：原先「条件同时满足几张就排队弹几张」会一回合连弹；
##   ② 不连续两回合都出：出了卡的下一回合必定安静。
const KNOWLEDGE_MIN_GAP_TURNS := 1

## 知识卡的标签权重：本回合打出的行动卡里出现同名标签，这张卡就更容易被抽中。
## 与「危机 - 对策」同一套标签词表（见 ACTION_CARDS 的 tags / CRISES 的 needs）。
## 命中一个标签乘一刀 —— 命中越多越容易出。
const KNOWLEDGE_TAG_BOOST := 3.0

## 每回合末：除了「指标跌破条件」触发的，还有这么大概率**随机**送一张还没解锁的知识卡。
## 为什么需要它：现有 8 张卡的条件全是 `指标 < 阈值` —— 也就是**玩崩了才会触发**，
## 认真治理的玩家反而一张都收不到。加这条随机线，图鉴在正常对局里才收得动。
## 0.0 = 关掉随机赠送（只剩条件触发）。
const KNOWLEDGE_RANDOM_CHANCE := 0.25

## 独立随机彩蛋：每个允许掉卡的回合 3%，不受季节、行动、标签或收藏补齐影响。
const DIXINHU_RANDOM_CHANCE := 0.03


## 回合末的知识卡检查 —— **每回合最多挑一张**，压入待弹出队列。
##
## 优先级：
##   ① 节拍闸门：上一回合刚出过 → 整回合安静（不掷、不触发）；
##   ② 条件命中的卡优先（可能同时命中好几张，但**只挑一张**）；
##   ③ 都没命中时，走那条随机线（概率见 KNOWLEDGE_RANDOM_CHANCE）。
## ②③ 两步都用「本回合打过的牌」的标签做权重：出什么类型的牌，就更容易出什么样的知识卡。
func _check_knowledge_triggers() -> void:
	if knowledge_last_turn >= turn - KNOWLEDGE_MIN_GAP_TURNS:
		return

	var candidates: Array = []
	for card_id in KNOWLEDGE_CARDS:
		if KNOWLEDGE_CARDS[card_id].get("random_only", false):
			continue
		if not (card_id in knowledge_unlocked):
			candidates.append(card_id)
	var egg_available := not ("egg_dixinhu" in knowledge_unlocked)
	if candidates.is_empty() and not egg_available:
		return

	# 本回合打过的行动卡带的标签 —— 决定「哪张更容易被抽中」
	var turn_tags := _knowledge_turn_tags()

	var hit: Array = []
	for card_id in candidates:
		if _knowledge_condition_met(KNOWLEDGE_CARDS[card_id]):
			hit.append(card_id)

	var pick := ""
	if egg_available and _knowledge_rng.randf() < DIXINHU_RANDOM_CHANCE:
		pick = "egg_dixinhu"
	elif not hit.is_empty():
		# 条件命中优先，但一次只出一张：同时踩线时，与本回合出牌同标签的那张更容易被挑中
		pick = _pick_knowledge(hit, turn_tags)
	elif KNOWLEDGE_RANDOM_CHANCE > 0.0 and _knowledge_rng.randf() < KNOWLEDGE_RANDOM_CHANCE:
		pick = _pick_knowledge(candidates, turn_tags)

	if pick == "":
		return
	knowledge_unlocked.append(pick)
	pending_knowledge.append(pick)
	knowledge_last_turn = turn


func _knowledge_condition_met(card: Dictionary) -> bool:
	if card.get("random_only", false):
		return false
	var condition := str(card.get("condition", ""))
	if not condition.is_empty() and _eval_condition(condition):
		return true
	for action_id in card.get("action_ids", []):
		if action_id in used_action_ids:
			return true
	if turn > 0:
		var season_name: String = ["春", "夏", "秋", "冬"][(turn - 1) % 4]
		if season_name in card.get("seasons", []):
			return true
	return false


## 本回合打过的行动卡带的所有标签（去重）
func _knowledge_turn_tags() -> Dictionary:
	var out := {}
	for cid in used_action_ids:
		for c in ACTION_CARDS:
			if str(c["id"]) == str(cid):
				for t in c.get("tags", []):
					out[str(t)] = true
				break
	return out


## 按权重从候选里抽一张：每命中一个「本回合打过的标签」就把权重乘一刀
## （KNOWLEDGE_TAG_BOOST）。命中越多越容易出，全不命中就是等概率。
func _pick_knowledge(candidates: Array, turn_tags: Dictionary) -> String:
	if candidates.is_empty():
		return ""
	# 跨局优先补齐收藏；全部收集后仍可重温，但同局不重复。
	var missing: Array = []
	for card_id in candidates:
		if not Knowledge.is_collected(str(card_id)):
			missing.append(card_id)
	if not missing.is_empty():
		candidates = missing
	var weights: Array = []
	var total := 0.0
	for card_id in candidates:
		var w := 1.0
		for t in KNOWLEDGE_CARDS[card_id].get("tags", []):
			if turn_tags.has(str(t)):
				w *= KNOWLEDGE_TAG_BOOST
		weights.append(w)
		total += w
	if total <= 0.0:
		return ""
	var roll := _knowledge_rng.randf() * total
	for i in candidates.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return str(candidates[i])
	return str(candidates[candidates.size() - 1])


func pop_pending_knowledge() -> String:
	if pending_knowledge.is_empty():
		return ""
	return pending_knowledge.pop_front()


## 简单条件求值：支持 "turn == 1" 或 "metric < value"
func _eval_condition(cond: String) -> bool:
	var expr := cond.strip_edges()
	if expr.begins_with("turn"):
		var parts := expr.split("==")
		return turn == int(parts[1].strip_edges())
	# metric 比较
	var m := RegEx.new()
	m.compile("(\\w+)\\s*(<=|>=|<|>|==)\\s*(-?\\d+)")
	var res := m.search(expr)
	if res:
		var metric := res.get_string(1)
		var op := res.get_string(2)
		var val := int(res.get_string(3))
		if not metrics.has(metric):
			return false
		match op:
			"<": return metrics[metric] < val
			">": return metrics[metric] > val
			"<=": return metrics[metric] <= val
			">=": return metrics[metric] >= val
			"==": return metrics[metric] == val
	return false


## 指标增减。apply_penalty = false 时不吃「负向倍率」（危机伤害走这条路）。
## phase/label/ref_id 只用于算分动画的归因；phase 传空字符串 = 不入账（保持旧行为）。
func _apply_delta(metric: String, delta: int, apply_penalty: bool = true,
		phase: String = "", label: String = "", ref_id: String = "") -> void:
	if not metrics.has(metric):
		return
	# 扣分（负向变动）惩罚加成，倍率随难度递增。
	# ⚠ 危机伤害**不吃**这个倍率：危机数值（-14 之类）本身就是设计好的惩罚，
	#   再乘 1.5 / 2.0 会让困难档"任何一次危机都是一击必杀"——对策卡给的是正向数值
	#   （正向不乘倍率），+8 永远追不上 -28，"预警 → 对策卡 → 应对"的核心循环就废了。
	if delta < 0 and apply_penalty and metric != "water_level":
		delta = _scaled_delta(delta)
	var before: int = metrics[metric]
	var after: int = clampi(before + delta, 0, 100)
	metrics[metric] = after
	if phase != "":
		score_ledger.append({
			"phase": phase, "label": label, "ref_id": ref_id, "metric": metric,
			"raw": delta, "applied": after - before, "before": before, "after": after,
		})


## 清空流水账（每回合出牌结算前调用）
func clear_score_ledger() -> void:
	score_ledger.clear()


## 环湖人类围垦强度变化（仅驱动 3D 房子数量，不参与指标/失败判定）
func _apply_settlement(delta: int) -> void:
	var before := settlement
	settlement = clampi(settlement + delta, 0, 100)
	if settlement != before:
		_add_log("环湖人类围垦%s（%d）" % ["扩张" if delta > 0 else "收缩", delta])


func _find_card(card_id: String) -> Dictionary:
	for c in ACTION_CARDS:
		if c["id"] == card_id:
			return c
	return {}


func _add_log(msg: String) -> void:
	log_messages.append(msg)


func _randi_range(a: int, b: int) -> int:
	return randi() % (b - a + 1) + a


## 生成结局报告
func generate_report() -> Dictionary:
	var eco := _eval_eco()
	var social := _eval_social()
	var manage := _eval_manage()
	var reflection := _build_reflection()
	# 奖励看胜利结果；提前胜利也适用，不把奖励绑在回合数上。
	var victory := game_over and not is_failure
	var earned: int = Talents.CLEAR_REWARDS[difficulty] if victory else 0
	return {
		"eco": eco, "social": social, "manage": manage,
		"reflection": reflection,
		"is_failure": is_failure,
		"failure_reason": failure_reason,
		"failure_metric": failure_metric,
		"failure_metric_name": METRIC_NAMES.get(failure_metric, failure_metric),
		"failure_value": failure_value,
		"failure_threshold": failure_threshold_for(failure_metric) if failure_metric != "" else failure_threshold(),
		"metrics_below": metrics_below_threshold(),
		"seed": run_seed,
		"turns_survived": turn,
		"research_points": research_points,
		"knowledge_count": knowledge_unlocked.size(),
		"total_knowledge": KNOWLEDGE_CARDS.size(),
		"victory": victory, "difficulty": difficulty, "run_id": run_id,
		"inspiration_reward": earned, "unlock_all_talents": victory and difficulty == Difficulty.NIGHTMARE,
	}


func _eval_eco() -> Dictionary:
	var veg: int = metrics["vegetation"]
	var fish: int = metrics["fish"]
	var birds: int = metrics["birds"]
	var score: float = (veg + fish + birds) / 3.0
	var grade := _grade(score)
	var notes: Array = []
	if birds >= 70:
		notes.append("候鸟保护优秀，白鹤与雁类种群稳定。")
	elif birds < 40:
		notes.append("候鸟种群萎缩，白鹤食物不足。")
	if veg >= 70:
		notes.append("沉水植被恢复良好。")
	elif veg < 40:
		notes.append("沉水植被仍处于退化状态。")
	if fish >= 70:
		notes.append("鱼类资源显著恢复，禁渔成效明显。")
	elif fish < 40:
		notes.append("鱼类资源恢复缓慢。")
	if notes.is_empty():
		notes.append("生态整体均衡，但没有指标特别突出。")
	return {"score": score, "grade": grade, "notes": notes}


func _eval_social() -> Dictionary:
	var comm: int = metrics["community"]
	var grade := _grade(comm)
	var notes: Array = []
	if comm >= 70:
		notes.append("社区信任度高，护鸟队与志愿者形成合力。")
	elif comm < 40:
		notes.append("社区信任度低，人鸟矛盾激化。")
	# 覆盖率 = 整局到底打过几张「转产 / 补偿」类的牌。
	# ⚠ 修 bug：原句是 used_action_ids.size() >= 0 —— 恒为真，所以永远输出「高」，
	#   「需评估」是死分支；而且 used_action_ids 只装**本回合**打过的牌，口径也不对。
	var cover := 0
	for cid in ["community_comp", "industry_switch", "fisher_retrain", "eco_resettle"]:
		cover += int(ever_played.get(str(cid), 0))
	if cover >= 3:
		notes.append("转产与补偿覆盖到位（整局累计 %d 次）。" % cover)
	elif cover > 0:
		notes.append("转产与补偿有投入但不连续（整局累计 %d 次），建议补强。" % cover)
	else:
		notes.append("整局没做过转产与补偿，社区信任缺乏支撑。")
	return {"score": float(comm), "grade": grade, "notes": notes}


func _eval_manage() -> Dictionary:
	var eff := 100.0 if total_spent == 0 else clampf(100.0 - abs(total_spent - (TOTAL_TURNS * 55)) / (TOTAL_TURNS * 55) * 100.0, 0, 100)
	var grade := _grade(eff)
	var notes: Array = []
	notes.append("科研点数累计：%d（代表长期监测积累）" % research_points)
	# 科研点现在有实际作用了（深预警），评语要与机制对齐，不能还是纯叙述
	if deep_warning_on():
		notes.append("监测预警已升级：危机可提前 2 回合预判。")
	else:
		notes.append("科研点累计到 %d 可升级监测预警，把危机预判从 1 回合延长到 2 回合。" % DEEP_WARN_RESEARCH)
	if research_points >= 20:
		notes.append("长期数据库建立，预报准确率高。")
	return {"score": eff, "grade": grade, "notes": notes}


func _grade(score: float) -> String:
	if score >= 80:
		return "优秀"
	elif score >= 60:
		return "良好"
	elif score >= 40:
		return "合格"
	else:
		return "警示"


func _build_reflection() -> String:
	var parts: Array = []
	if metrics["community"] >= 60 and metrics["birds"] < 50:
		parts.append("你优先安抚了社区，但候鸟食物供给被牺牲，白鹤种群承压。")
	elif metrics["birds"] >= 60 and metrics["community"] < 50:
		parts.append("你优先保护候鸟，但社区补偿不足，人鸟矛盾可能持续。")
	else:
		parts.append("你在生态与生计之间寻求平衡，没有明显的单边倾斜。")

	if "research" in used_action_ids or research_points > 0:
		parts.append("你对科研监测的投入让预报更准确，降低了不确定性。")
	else:
		parts.append("你长期忽视科研监测，很多风险直到爆发才被发现。")

	parts.append("这是代价认知：每一个决策都在改变鄱阳湖，而资源永远不够覆盖所有需求。")
	return "　".join(parts)
