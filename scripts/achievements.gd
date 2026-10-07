extends Node
## 成就系统 —— autoload 单例 Achievements。
##
## 与 Changelog 的区别：成就**有状态**（哪些已解锁）且要**跨局持久化**，
## 所以是 autoload 而不是纯常量脚本。
##
## 存档：user://achievements.json —— 这是「账号级」的，独立于
## user://savegame.json（那个是单局进度，删档重开依然在）。
## 一局结束后重开、或者中途判负重来，已解锁的成就都不会掉。
##
## 加新成就：往 LIST 里追加一条，UI 会自动多出一行，不用改界面代码。
## 触发点要自己接（见 main.gd 的 _check_flush_achievement）。

## 解锁时广播。参数是成就 id。调用方拿它去弹「成就解锁」提示。
signal achievement_unlocked(id: String)

const SAVE_PATH := "user://achievements.json"

## 像素网格：'#'=描边 / 'X'=主色 / 'o'=高光 / '.'=透明（与 _icon_grid_for 同规格）
## 未解锁时用同一个网格、只换成灰色，所以形状要能独立认出来。
const MEDAL_GRID := """
	..##....##..
	..#X#..#X#..
	..#X#..#X#..
	..#XX##XX#..
	..########..
	.#XXooooXX#.
	#XXooooooXX#
	#XooooooooX#
	#XooooooooX#
	#XXooooooXX#
	.#XXooooXX#.
	..########..
"""

## 「最强管理员」用的盾形勋章。
## 刻意不做成第二个金牌：这是全成就里最难的一个，形状上就该一眼分得出来。
const SHIELD_GRID := """
	############
	#XXooooooXX#
	#XooooooooX#
	#XooooooooX#
	#XXXXXXXXXX#
	.#XXXXXXXX#.
	.#XXXXXXXX#.
	..#XXXXXX#..
	..#XXXXXX#..
	...#XXXX#...
	....####....
	.....##.....
"""

## 「被做局了」用的骰子：四个点，读作「开局就被灌了铅」。
const DICE_GRID := """
	..########..
	.#XXXXXXXX#.
	.#XXXXXXXX#.
	.#X##XX##X#.
	.#X##XX##X#.
	.#XXXXXXXX#.
	.#XXXXXXXX#.
	.#X##XX##X#.
	.#X##XX##X#.
	.#XXXXXXXX#.
	.#XXXXXXXX#.
	..########..
"""

## 「廉政先锋」用的方孔钱。
const COIN_GRID := """
	..########..
	.#XXXXXXXX#.
	.#XXXXXXXX#.
	.#XX####XX#.
	.#XX#..#XX#.
	.#XX#..#XX#.
	.#XX#..#XX#.
	.#XX####XX#.
	.#XXXXXXXX#.
	.#XXXXXXXX#.
	.#XXXXXXXX#.
	..########..
"""

## 「廉政先锋」的花费门槛（万/回合）。
## ⚠ 改这个数字时**必须同步改下面 LIST 里那条 desc 的文字** ——
##   desc 是 const 字符串，常量表达式里没法做格式化，只能靠这条注释互相提醒。
const THRIFTY_SPEND_PER_TURN := 40

## 成就定义表。desc 会被原样显示在弹窗与成就页里，写成「触发条件」的口气。
const LIST := [
	{
		"id": "flush",
		"name": "？！同花！？",
		"desc": "在同一回合打出三张同一类别的牌（都是生态 / 社会 / 管理）",
		"icon": MEDAL_GRID,
	},
	{
		"id": "hard_clear",
		"name": "最强管理员",
		"desc": "在困难难度下打满 16 回合通关（不是中途被撤换）",
		"icon": SHIELD_GRID,
	},
	{
		"id": "rigged",
		"hidden": true,
		"name": "被做局了",
		"desc": "在噩梦模式下第 1 或第 2 回合就被撤换 —— 这局从发牌起就没打算让你赢",
		"icon": DICE_GRID,
	},
	{
		"id": "thrifty",
		"name": "廉政先锋",
		"desc": "打满 16 回合通关，且全程平均每回合花费不超过 40 万",
		"icon": COIN_GRID,
	},
	{
		"id": "ecology_expert",
		"name": "生态专家",
		"desc": "收集全部知识卡，掌握鄱阳湖的生态与保护知识",
		"icon": MEDAL_GRID,
	},
]

var _unlocked: Dictionary = {}


func _ready() -> void:
	_load()
	# Knowledge 位于此单例之后加载，等它准备好再订阅并补查已有收藏。
	call_deferred("_watch_knowledge")


func _watch_knowledge() -> void:
	if not Knowledge.card_collected.is_connected(_on_knowledge_collected):
		Knowledge.card_collected.connect(_on_knowledge_collected)
	check_knowledge_completion()


func _on_knowledge_collected(_card_id: String) -> void:
	check_knowledge_completion()


func check_knowledge_completion() -> void:
	if Knowledge.total_count() > 0 and Knowledge.collected_count() == Knowledge.total_count():
		try_unlock("ecology_expert")


# ==================== 持久化 ====================

func _load() -> void:
	_unlocked = {}
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if data is Dictionary:
		for k in data:
			if bool(data[k]):
				_unlocked[str(k)] = true


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("成就存档写入失败：%s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(_unlocked))
	f.close()


# ==================== 查询 ====================

func is_unlocked(achievement_id: String) -> bool:
	return _unlocked.has(achievement_id)


func unlocked_count() -> int:
	var n := 0
	for a in LIST:
		if is_unlocked(str(a["id"])):
			n += 1
	return n


func visible_list() -> Array:
	var visible: Array = []
	for achievement in LIST:
		if not bool(achievement.get("hidden", false)) or is_unlocked(str(achievement["id"])):
			visible.append(achievement)
	return visible


func find(achievement_id: String) -> Dictionary:
	for a in LIST:
		if str(a["id"]) == achievement_id:
			return a
	return {}


# ==================== 解锁 ====================

## 尝试解锁。**已经解锁过就什么都不做并返回 false** ——
## 「一个成就只能触发一次」这道闸门就设在这里，不靠调用方自觉。
## 调用方可以无脑地在每次满足条件时调它。
func try_unlock(achievement_id: String) -> bool:
	if achievement_id == "" or is_unlocked(achievement_id):
		return false
	if find(achievement_id).is_empty():
		push_warning("尝试解锁不存在的成就：%s" % achievement_id)
		return false
	_unlocked[achievement_id] = true
	_save()
	achievement_unlocked.emit(achievement_id)
	return true


## 清空全部成就（设置里的「清空当前存档」会调它）。
## 与 Talents.reset_all 一样写空状态而非删文件，避免多一个「文件不存在」分支。
func reset_all() -> void:
	_unlocked = {}
	_save()
