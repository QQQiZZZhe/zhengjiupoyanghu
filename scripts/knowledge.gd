extends Node
## 知识卡收藏 —— autoload 单例 Knowledge。
##
## 与 Achievements 同构：有状态（哪些知识卡已收集）且要**跨局持久化**，
## 所以是 autoload 而不是纯常量脚本。
##
## 存档：user://knowledge.json —— 这是「账号级」的，独立于
## user://savegame.json（那个是单局进度，删档重开依然在）。
## 判负重来、中途退出、重开一局，已收集的知识卡都不会掉。
##
## 知识卡数据本体仍旧在 GameState.KNOWLEDGE_CARDS（图鉴按美术分类排列）；
## 这里只管「收没收到」。游戏里那张卡真的弹到玩家面前时（main.gd 的 _show_knowledge）
## 调 unlock()，主页图鉴就能点亮它。

const SAVE_PATH := "user://knowledge.json"
signal card_collected(card_id: String)

var _collected: Dictionary = {}


func _ready() -> void:
	_load()


# ==================== 持久化 ====================

func _load() -> void:
	_collected = {}
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
				_collected[str(k)] = true


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("知识卡存档写入失败：%s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(_collected))
	f.close()


# ==================== 查询 ====================

func is_collected(card_id: String) -> bool:
	return _collected.has(card_id)


func total_count() -> int:
	return GameState.KNOWLEDGE_CARDS.size()


func collected_count() -> int:
	var n := 0
	for card_id in GameState.KNOWLEDGE_CARDS:
		if is_collected(str(card_id)):
			n += 1
	return n


## 图鉴按美术分类排列；类内沿用定义顺序，彩蛋置于末尾。
func all_ids() -> Array:
	var out: Array = []
	for category in GameState.KNOWLEDGE_CATEGORIES + ["彩蛋"]:
		for card_id in GameState.KNOWLEDGE_CARDS:
			if str(GameState.KNOWLEDGE_CARDS[card_id]["category"]) == category:
				out.append(str(card_id))
	return out


# ==================== 收集 ====================

## 记下这张知识卡。**已经收过就什么都不做并返回 false** ——
## 「一张卡只记一次」这道闸门设在这里，不靠调用方自觉。
## 调用方（弹知识卡的地方）可以无脑调它。
func unlock(card_id: String) -> bool:
	if card_id == "" or is_collected(card_id):
		return false
	if not GameState.KNOWLEDGE_CARDS.has(card_id):
		push_warning("记录不存在的知识卡：%s" % card_id)
		return false
	_collected[card_id] = true
	_save()
	card_collected.emit(card_id)
	return true


## 清空全部收集（设置里的「清空当前存档」会调它）。
## 与 Achievements.reset_all 一样写空状态而非删文件，避免多一个「文件不存在」分支。
func reset_all() -> void:
	_collected = {}
	_save()
