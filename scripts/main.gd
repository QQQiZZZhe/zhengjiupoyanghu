extends Node

const VisualTheme = preload("res://scripts/visual_theme.gd")
const PixelCardArt = preload("res://scripts/pixel_card_art.gd")
const PixelWetland = preload("res://scripts/pixel_wetland.gd")
var wetland: Control
var card_art_preview: CanvasLayer

func _open_card_art_preview() -> void:
	if is_instance_valid(card_art_preview):
		return
	card_art_preview = preload("res://scripts/card_art_preview.gd").new()
	add_child(card_art_preview)
## 《拯救鄱阳湖》主场景：2.5D 沙盘 + 四区 UI。逻辑在 GameState 单例。

const METRIC_COLORS := {
	"water_level": Color(0.30, 0.58, 0.95),
	"vegetation": Color(0.40, 0.76, 0.38),
	"water_quality": Color(0.30, 0.80, 0.80),
	"fish": Color(0.40, 0.50, 0.88),
	"birds": Color(0.88, 0.88, 0.92),
	"community": Color(0.96, 0.68, 0.32),
}
const CATEGORY_NAMES := {"ecology": "生态", "social": "社会", "manage": "管理"}
const CATEGORY_COLORS := {
	"ecology": Color(0.42, 0.75, 0.46),
	"social": Color(0.95, 0.70, 0.36),
	"manage": Color(0.56, 0.66, 0.90),
}
const SEASONS := ["春", "夏", "秋", "冬"]
const CATEGORY_ORDER := ["ecology", "social", "manage"]

## 知识卡图鉴（主页入口）用的类别配色。
## 与行动卡的三色（生态/社会/管理）分开：知识卡是「科普条目」的口吻，
## 类别更多（植物/鸟类/机制/外来物种/案例/管理策略），各给一个自己的颜色。
const KNOWLEDGE_CATEGORY_COLORS := {
	"植物": Color(0.42, 0.72, 0.45),
	"鸟类": Color(0.44, 0.62, 0.86),
	"机制": Color(0.62, 0.50, 0.82),
	"外来物种": Color(0.82, 0.52, 0.32),
	"案例": Color(0.80, 0.42, 0.46),
	"管理策略": Color(0.36, 0.70, 0.68),
	"地理": Color(0.34, 0.65, 0.78),
	"水生动物": Color(0.38, 0.60, 0.73),
	"保护行动": Color(0.65, 0.72, 0.36),
}
## 未收集时的灰调（卡面 / 详情共用，改一处就整体变灰深浅）
const KNOWLEDGE_LOCKED_INK := Color(0.55, 0.58, 0.58)
## 知识卡没有自己的插图，从行动卡图集（conservation-cards，3 列 × 2 行）里挑一格 ——
## 图鉴与牌库于是是同一套视觉语言。**显式指定 (列, 行)**，不走 id hash：
## hash 挑图会把「苦草」配上鸟图，看着就不对。
## 共用六格主题场景图，不作为各物种的识别图。
const KNOWLEDGE_ART_TILE := {
	"plant_kucao": Vector2i(0, 1),          # 荷花池 + 鱼：沉水植物
	"bird_baihe": Vector2i(0, 0),           # 白鹤站在芦苇里
	"bird_xiaotiane": Vector2i(2, 1),       # 观鸟塔 + 飞鸟群
	"bird_dongfang": Vector2i(0, 0),        # 大型涉禽（与白鹤同图）
	"mech_water_quality": Vector2i(2, 0),   # 研究笔记 + 放大镜
	"mech_fushouluo": Vector2i(1, 1),       # 农田劳作：防控现场
	"cons_disease": Vector2i(0, 1),         # 水草塘：病害发生地（与苦草同图）
	"cons_compensate": Vector2i(1, 0),      # 水乡村庄：社区共管
	"geo_poyang": Vector2i(0, 1),
	"geo_five_rivers": Vector2i(0, 1),
	"geo_hukou": Vector2i(0, 1),
	"geo_seasonal_lake": Vector2i(0, 1),
	"geo_saucer_lakes": Vector2i(0, 1),
	"geo_flood_storage": Vector2i(0, 1),
	"animal_finless_porpoise": Vector2i(0, 1),
	"bird_white_naped_crane": Vector2i(2, 1),
	"bird_wintering_geese": Vector2i(2, 1),
	"plant_sedge": Vector2i(0, 0),
	"plant_reeds": Vector2i(0, 0),
	"plant_lotus": Vector2i(0, 1),
	"mech_fish_migration": Vector2i(0, 1),
	"mech_vegetation_zones": Vector2i(0, 1),
	"mech_food_web": Vector2i(0, 0),
	"mech_feeding_depth": Vector2i(0, 0),
	"case_extreme_drought": Vector2i(2, 0),
	"mech_micro_wetlands": Vector2i(0, 1),
	"mech_wetland_carbon": Vector2i(2, 0),
	"mech_runoff_pollution": Vector2i(1, 1),
	"manage_flyway": Vector2i(2, 1),
	"mech_bird_rings": Vector2i(2, 0),
	"manage_bird_surveys": Vector2i(2, 1),
	"manage_fishing_ban": Vector2i(0, 1),
	"protect_scientific_release": Vector2i(0, 1),
	"manage_bird_canteens": Vector2i(1, 1),
	"protect_birdwatching": Vector2i(2, 1),
	"protect_bird_rescue": Vector2i(2, 0),
	"protect_wetland_tracks": Vector2i(0, 0),
	"case_entanglement": Vector2i(2, 0),
	"manage_fisher_transition": Vector2i(1, 0),
	"mech_underwater_noise": Vector2i(2, 0),
}
## 主页「知识卡」按钮的像素图标（一张卡片：外框 + 两条文字线）
const KNOWLEDGE_ICON_GRID := """..########..
.#XXXXXXXX#.
.#XXXXXXXX#.
.#X######X#.
.#XXXXXXXX#.
.#XXXXXXXX#.
.#X######X#.
.#XXXXXXXX#.
.#XXXXXXXX#.
.#X####XXX#.
.#XXXXXXXX#.
..########.."""
## 未收集卡面上那个大「？」（12×12 像素网格；每行长度必须一致，见 _grid_image）
const KNOWLEDGE_QUESTION_GRID := """..######....
.#XXXXXX#...
.#XX##XX#...
.#XX..XX#...
......XX#...
.....XX#....
....XX#.....
....XX#.....
....XX#.....
............
....XX#.....
....XX#....."""

## 季节指针：左上角的小表盘，指针随回合在四季之间转 90°（春在 12 点、顺时针转）。
## 全工程唯一的自绘控件（_draw）—— 它纯是指示器，不接受任何输入。
class SeasonDial extends Control:
	const RAD := 20.0
	var _angle: float = -PI * 0.5    # 指针角度（弧度）：-90° = 12 点钟方向 = 春
	## 盘内不写字 —— 面板只有 204px 宽，季节名放在盘右边的 Label 里（见 _build_ui）。
	## 四个刻度点就是春/夏/秋/冬：12 点、3 点、6 点、9 点。

	func _init() -> void:
		custom_minimum_size = Vector2(RAD * 2.0 + 6.0, RAD * 2.0 + 6.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## 转到第 index 季（0 春 / 1 夏 / 2 秋 / 3 冬）。animate=false 直接落位（读档/重开用）。
	func turn_to(index: int, animate: bool = true) -> void:
		var target: float = -PI * 0.5 + float(index) * PI * 0.5
		if not animate or is_equal_approx(_angle, target):
			_angle = target
			queue_redraw()
			return
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(_set_angle, _angle, target, 0.45)

	func _set_angle(a: float) -> void:
		_angle = a
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		draw_circle(c, RAD, Color(0.09, 0.13, 0.11, 0.88))
		draw_arc(c, RAD, 0.0, TAU, 48, Color(0.42, 0.50, 0.45), 1.5, true)
		for i in 4:
			var a: float = -PI * 0.5 + float(i) * PI * 0.5
			draw_circle(c + Vector2(cos(a), sin(a)) * (RAD - 4.0), 1.5, Color(0.55, 0.63, 0.57))
		draw_line(c, c + Vector2(cos(_angle), sin(_angle)) * (RAD - 2.0),
			Color(1.0, 0.86, 0.42), 2.0, true)
		draw_circle(c, 2.5, Color(1.0, 0.86, 0.42))

## Permanent study and seeded random talents coexist; allocations start next run.
const TALENT_TREE_ENABLED := true
const TalentTreePanel := preload("res://scripts/talent_tree_panel.gd")

# 成就图标配色：解锁 = 金牌，未解锁 = 灰牌（同一个网格，只换颜色）
const ACH_GOLD := Color(0.98, 0.80, 0.30)
const ACH_LOCKED := Color(0.42, 0.42, 0.47)
# 苦力怕彩蛋（左上角草地，lake_view 局部坐标）
const CREEPER_X := -45.0
const CREEPER_Z := 4.0
const CREEPER_SIZE := 12.0   # 贴图宽度（高度按图片宽高比自动算）
const CREEPER_CHANCE := 0.1  # 进入主菜单时出现的概率
var creeper_mesh: MeshInstance3D = null

# UI 节点
var left_panel: PanelContainer
var turn_label: Label
## 左上「资金 / 回合」栏最下面的「本局天赋」常驻区（0.0.8）。
## 词条每局开局随机，所以这里只建容器、内容由 _refresh_run_talents() 按需重画。
var talents_row: VBoxContainer
var _talents_sig: String = ""      # 已画出的词条签名，内容没变就不重建节点
var season_label: Label
var season_tagline: Label
var season_dial: SeasonDial
var dispatch_btn: Button          # 紧急调度：花 40 万点名一张当季牌
var refresh_btn: Button           # 刷新手牌：花 5 万重抽整手，每回合限一次
var dispatch_panel: Control       # 紧急调度的选牌面板（与牌库同款的全屏卡牌网格）
var dispatch_grid: HFlowContainer
var dispatch_hint: Label          # 面板顶部说明（含当前调度费，逐次递增所以要重写）
var _refresh_used_turn: int = -1  # 本回合是否已刷过手牌（-1 = 没刷过）
var _season_dial_index: int = -1  # 指针当前停在第几季，避免 _update_hud 每帧重触发动画
var funds_label: Label
var spent_label: Label
var research_label: Label
var event_label: Label
var right_panel: PanelContainer
var metric_bars: Dictionary = {}
# 指标悬停小窗（跟随鼠标：本回合会掉多少 / 红线在哪）
var metric_tip: PanelContainer = null
var metric_tip_title: Label = null
var metric_tip_body: RichTextLabel = null
var _tip_metric: String = ""       # 当前小窗显示的是哪一项（"" = 没显示）
var _tip_last_text: String = ""    # 上次写入的正文，内容没变就不重复塞（省得每帧重排版）
var hand_panel: PanelContainer
var sandpan_view: Node
var end_turn_btn: Button
var bottom_right: VBoxContainer
var card_box: Control
var selected_label: Label
var action_hint: Label         # 右下角常驻提示「每回合最多 N 个行动」——N 随难度变化，见 _update_hud
var current_hand: Array = []   # 当前手牌（card dict 数组）
var card_infos: Array = []     # {panel, card_id, base_pos, theta, radial, selected, tier, cost_label}
var _fan_layout_size: Vector2 = Vector2.ZERO  # 上次布局时的容器尺寸
var play_deal_anim: bool = false              # 下次布局时播放发牌入场动画
## 左下角「出牌档位」拉杆（局内 UI）：向左拨 = 基础投入（半价），中间 = 有效投入，向右拨 = 深度投入（双倍价）。
## ⚠ 档位是**选牌那一刻**记进 card_infos 的（info["tier"]）——选中之后再拨拉杆，
##   已选的牌不会改价、也不会改效果，玩家才能一回合内混着打不同档。
var tier_lever: PanelContainer
var lever_track: Control
var lever_handle: Control
var _lever_slide_tween: Tween = null   # 手柄滑动动画（连续点档位时要掐掉上一条）
var lever_cd_label: Label              # 「出牌档位」右边的冷却倒计时
var lever_slot_btns: Array = []
var lever_state_label: Label
var play_tier: String = "effective"           # 拉杆当前档位（新的一局复位成有效档）
var popup_root: Control
var dim: ColorRect
var popup_center: CenterContainer
var popup_panel: PanelContainer
var _knowledge_egg_reveal: Control
var popup_title: Label
var popup_body: RichTextLabel
var popup_button: Button
var _popup_continue: Callable = Callable()
var _popup_reveal: Tween
var _current_event: String = ""
# 顶部横幅的临时覆盖（只有危机弹层会写它：危机预警/爆发时横幅必须让位给危机）。
# 空串 = 横幅显示 GameState 现场生成的态势简报（见 _refresh_event_banner）。
# ⚠ 与 _current_event 分开：后者是「第 N 回合 · 事件」弹窗的正文，不能被危机文案顶掉。
var _banner_override: String = ""

# 主菜单
var menu_root: Control
var menu_utilities: GridContainer
var menu_separator: HSeparator
var menu_col: VBoxContainer            # 左下角选项列
var menu_start_btn: Button
var menu_easy_btn: Button
var menu_normal_btn: Button
var menu_hard_btn: Button
var menu_nightmare_btn: Button
var menu_back_btn: Button
var menu_seed_start_btn: Button
var menu_talent_btn: Button
var menu_settings_btn: Button
var menu_credits_btn: Button
var menu_changelog_btn: Button
var menu_achievements_btn: Button
var menu_knowledge_btn: Button
var menu_quit_btn: Button
var _info_back_to_settings: bool = false   # 更新日志/制作人员是从设置里点进去的 → 返回时回设置而不是主菜单
var menu_seed_label: Label
var menu_mode_label: Label
var seed_input: LineEdit
var menu_hint: Label
var menu_talent_panel: PanelContainer
var menu_settings_panel: PanelContainer
var menu_credits_panel: PanelContainer
var menu_changelog_panel: PanelContainer
var menu_achievements_panel: PanelContainer
var menu_clear_save_btn: Button
var menu_clear_confirm_panel: PanelContainer
var clear_status_label: Label

# 音频 / BGM
var bgm_player: AudioStreamPlayer
var bgm_index: int = 1
var bgm_volume: float = 0.8
## 结算动画速度倍率（1.0 = 正常）。玩家可在设置里调 —— 手感因人而异，
## 与其每次改代码重导，不如给个滑块。与音量一起存在 user://settings.json。
var score_speed: float = 1.0
const SCORE_SPEED_MIN := 0.5
const SCORE_SPEED_MAX := 3.0
var audio_volume_slider: HSlider
var audio_volume_label: Label
var score_speed_slider: HSlider
var score_speed_label: Label
var bgm_switch_btn: Button
var pause_settings_panel: PanelContainer
var pause_volume_slider: HSlider
var pause_volume_label: Label
var pause_bgm_btn: Button
var pause_score_speed_slider: HSlider
var pause_score_speed_label: Label
const BGM_PATHS := ["res://assets/audio/poyanghu.mp3", "res://assets/audio/poyanghunaiyu.mp3"]
const BGM_NAMES := ["鄱阳湖", "评委审核版"]
const AUDIO_SETTINGS_PATH := "user://settings.json"

# 音效（程序化合成，生成器见 tools/make_ding.py —— 要改音色请改脚本重跑，别手改 wav）
const SFX_PATHS := {
	"ding": "res://assets/audio/ding.wav",   # 逐张弹分 / 指标结算的「叮」
	"land": "res://assets/audio/land.wav",   # 甩牌落桌的闷响
}
const SFX_POOL_SIZE := 6        # 复音池：支撑每 0.045s 一个叮而互不打断
var _sfx_players: Array = []
var _sfx_streams: Dictionary = {}
var _sfx_cursor: int = 0        # 轮转下标（比"找空闲播放器"简单，且一定不会切掉正在响的那个）
var menu_camera_far: bool = false      # 开始页期间镜头拉远看全景
var menu_continue_btn: Button

# 暂停 / 存档
var pause_root: Control
var pause_panel: PanelContainer
var pause_hint: Label
var _paused: bool = false
var _playing: bool = false
var _current_phase: String = "allocate"
var _defer_game_over: bool = false   # 回合结算流程中：报告由结算反馈之后再弹，别抢
const SAVE_PATH = "user://savegame.json"

# 危机警示（大红叹号 + 红屏闪烁 + 雷霆大字）
var crisis_root: Control
var crisis_dim: ColorRect
var crisis_icon: TextureRect
var crisis_title: Label
var crisis_tag: Label
var crisis_body: RichTextLabel
var crisis_button: Button
var _crisis_queue: Array = []   # 危机弹窗队列 {crisis, is_warning}

# 危机预警回顾（顶部条 + 全屏列表）
var warn_bar: Button = null
var warn_panel_root: Control = null
var warn_list_box: VBoxContainer = null
var warn_count_label: Label = null

# 牌库 UI（牌堆）
var deck_root: Control            # 牌堆容器（右面板下方）
var deck_border: Control          # 黄色外框（悬停时显示，自绘贴牌形状）
var deck_backs: Array = []        # 叠放的牌背（TextureRect）
var _deck_hovered: bool = false
var card_back_tex: Texture2D
var deck_viewer: Control          # 牌库查看器（全屏弹层）
var deck_viewer_grid: HFlowContainer
var _deck_open: bool = false
var card_detail: Control          # 卡牌详情弹层（点击查看：左大牌 + 右介绍）
var card_detail_card: CenterContainer  # 左侧大牌容器
var card_detail_title: Label
var card_detail_body: RichTextLabel
var _detail_big_card: Control = null   # 当前详情大牌（用于重开时清理）
var _ui_slide_tweens: Array = []       # 牌库开合时收放主界面的 tween
var _ui_slide_origin: Dictionary = {}  # Control -> [l, t, r, b] 初始 offset
var deck_sort_btn: Button             # 排序切换按钮（互旋箭头）
var hand_sort_btn: Button             # 出牌阶段的同一个排序按钮（与牌库共用模式与冷却）
## true=按类别，false=按费用。
## 2026-09-29 起默认**按费用**：玩测反馈「找牌时先看掏不掏得起」，
## 按费用排更省事；想按类别排，界面上那个切换按钮一点就换（牌库与手牌共用这一个开关）。
var _deck_sort_by_category: bool = false
## 手牌「抬起」的高度（选中/悬停时沿径向外移的距离）。
## _update_card_hover 每帧用它，手牌排序的飞行落点也要用同一个值 ——
## 写死两处早晚会漂移，抬起高度一变排序落点就不对了。
const CARD_RAISE := 26.0
var _sort_animating: bool = false
var _sort_cooldown_ms: int = -6000   # 上次排序的时间戳；初始值只要足够久远即可（开局就能排序）
const SORT_COOLDOWN_MS := 3000       # 两次切换排序方式的最低间隔（毫秒），冷却期间按钮禁用并显示倒计时
# 出牌档位的冷却：切一次档后锁 1 秒，期间拉杆不吃输入、并在「出牌档位」旁边显示倒计时。
# 初始值取足够久远 → 开局就是可用的。与排序那套（3 秒）同源，都是防连点。
var _lever_cooldown_ms: int = -6000
const LEVER_COOLDOWN_MS := 1000
var _deck_gyro_view: Control = null   # 当前鼠标悬停的牌库卡牌（只对它做陀螺仪）

# 知识卡图鉴（主页入口）：与牌库查看器同款的网格 + 悬停 + 详情，
# 但它是**独立一层**（MenuLayer 之上，因为入口在开始页而不是对局里）。
var knowledge_viewer: Control          # 知识卡图鉴（全屏弹层）
var knowledge_grid: HFlowContainer     # 知识卡网格
var knowledge_count_label: Label       # 「已收集 x / 总数」
var knowledge_detail: Control          # 知识卡详情弹层（覆盖在查看器之上）
var knowledge_detail_card: CenterContainer  # 左侧大牌容器
var knowledge_detail_title: Label
var knowledge_detail_body: RichTextLabel
var _knowledge_big_card: Control = null     # 当前详情大牌（重开时清理）

# ==================== 算分动画（小丑牌风）====================
# 五类来源的**展示**顺序。⚠ 与 end_turn() 的真实执行顺序**不同**：
#   真实执行 = card → pending/leftover(advance_effects) → synergy(resolve_synergies) → routine(natural_evolution)
# （pending 与 leftover 是同一处代码分出来的两支，见 game_state.gd 的 advance_effects：
#   pending  = 本回合打出的延迟效果、当回合就到期（delay=1 即如此）
#   leftover = 前几轮排队、现在才到期。
#   拆两支是因为不拆的话，第 1 回合就会冒出「前几轮遗留」这种不存在的说法。）
# 这里把 synergy 提到 leftover 之前（pending 留在原位），是为了让「协同」紧跟
# 「本轮牌加成」出现，形成本回合组合技的即时反馈（玩家心智里协同属于"这一手牌"，不属于"旧账"）。
# 代价：clampi(0,100) 的截断是路径相关的，按这个顺序累计时，若某指标被钉在
#   100 附近且来源正负混合，数值条中间段可能偏几个点。
# 兜底：_play_score_animation 把最后一段强制对齐真值 → 「终点」恒正确；
#   而四段数字之和恒等于真实变化量（applied 已含截断修正）→ 「加总」恒正确。
# 想让动画处处精确，把本数组换成 ["card", "leftover", "synergy", "routine"] 即可，
# 其余代码一行都不用动（代价是协同节拍从中间挪到倒数第二拍）。
const SCORE_PHASE_ORDER := ["card", "pending", "synergy", "leftover", "routine", "crisis"]
const SCORE_PHASE_NAMES := {
	"card": "本轮牌加成",
	"pending": "本回合延迟生效",
	"synergy": "卡牌协同",
	"leftover": "前几轮遗留",
	"routine": "常规演化",
	"crisis": "危机爆发",
}
# ★ 指标结算节拍（③+④：图标放大抖动 → 四类来源依次弹 → 合计 → 数值条）的速度倍率。
#   1.0 = 原速，0.8 = 慢到 80%（时长 ×1.25）。只影响指标结算这一段；
#   甩牌与逐张弹分两拍不受影响（要一并调就改 T_TOTAL）。
#   实现上不是只缩放总预算，而是把这一段里的**所有**时长（图标各段、
#   小数字间隔、数值条推进、数值文本弹跳、小票滑入）都乘以 1/此值 ——
#   否则图标那种固定的小节拍会保持原速，看起来像「顿一下」。
const METRIC_SPEED := 0.80
var score_layer: CanvasLayer = null        # 算分动画层（独立 CanvasLayer，层号 7）
var score_stage: Control = null            # 舞台：全屏、不接收鼠标
var score_floats: Control = null           # 卡牌上方 +N 飘字容器
var score_receipt: PanelContainer = null   # 算分小票：滑到当前结算指标行的左侧
var score_receipt_box: VBoxContainer = null
var _score_anim_id: int = 0                # 动画代次：每个 await 回来校验，被作废就立刻退出
var _score_animating: bool = false         # 动画中：锁输入 + 冻结指标 HUD/3D + 抑制悬停与小窗

# ==================== 成就解锁提示 ====================
var ach_layer: CanvasLayer = null          # 独立层，盖在 HUD 与算分动画之上
var ach_popup: PanelContainer = null
var ach_popup_icon: TextureRect = null
var ach_popup_name: Label = null
var ach_popup_desc: Label = null
var _ach_queue: Array = []                 # 待播成就 id（一回合同时解锁多个时排队）
var _ach_showing: bool = false
var ach_count_label: Label = null          # 成就页顶部「已解锁 X / Y」
var ach_rows_col: VBoxContainer = null     # 成就页列表容器（每次打开重建）

# 3D 表现节点
var lake_mesh: MeshInstance3D
var lake_mat: ShaderMaterial
var lake_color: Color = Color(0.62, 0.80, 0.86, 0.88)
var grass_nodes: Array = []
var grass_mats: Array = []
var bird_nodes: Array = []
var fish_nodes: Array = []
var boats: Array = []   # 长江行船 [{rig, x, speed, dir}]
var island_nodes: Array = []      # 人工浮岛节点
var house_slots: Array = []       # 每项 {"house": Node3D, "sprite": Sprite3D, "reeds": Node3D}
var species_views: Dictionary = {}  # sid -> {rigs[], bases[], states[], timers[], targets[]}
var plant_views: Dictionary = {}    # pid -> {meshes[], kind}
var plant_positions: Dictionary = {} # pid -> Array[Vector3]  每局随机散落的位置
var _plant_pos_seed: int = -1        # 已生成位置对应的种子，换局时重新散落

# 开场像素 PPT（Undertale 风：首次游玩讲背景）
var intro_layer: CanvasLayer = null
var intro_root: Control = null
var intro_col: VBoxContainer = null
var intro_image: TextureRect = null
var intro_title: Label = null
var intro_body: Label = null
var intro_hint: Label = null
var intro_slides: Array = []
var intro_index: int = 0
var _intro_playing: bool = false
var _intro_elapsed: float = 0.0
var _intro_advancing: bool = false
const INTRO_SLIDE_SEC := 5.0


func _ready() -> void:
	_load_audio_settings()
	_setup_bgm()
	_setup_sfx()
	_setup_pixel_font()
	_setup_camera()
	_build_wetland()
	_build_ui()
	GameState.metrics_changed.connect(_update_hud)
	GameState.metrics_changed.connect(_update_3d)
	GameState.funds_changed.connect(_update_hud)
	GameState.event_triggered.connect(_on_event)
	GameState.crisis_warned.connect(_on_crisis_warn)
	GameState.crisis_hit.connect(_on_crisis_hit)
	GameState.game_ended.connect(_on_game_end)
	Achievements.achievement_unlocked.connect(_on_achievement_unlocked)
	# 窗口尺寸/全屏变化时自适应相机，避免全屏后沙盘被裁或留黑边
	get_viewport().size_changed.connect(_fit_camera_to_window)
	_fit_camera_to_window()
	if "--card-art-test" in OS.get_cmdline_user_args():
		_show_menu()
		_open_card_art_preview()
		return
	# 首次游玩先放开场 PPT；老玩家直接进主菜单
	if _is_first_play():
		_show_intro()
	else:
		_show_menu()


## 开始页期间镜头拉远的倍率（正交 size 越大 = 视野越广）
const MENU_CAM_ZOOM := 1.3


## 根据窗口宽高比调整正交相机尺寸：让沙盘占满屏幕主体，不因宽屏被推远
func _fit_camera_to_window() -> void:
	if wetland:
		wetland._layout_map()
		return
	var cam := get_node("../Camera3D") as Camera3D
	if cam == null:
		return
	cam.size = _cam_base_size() * (MENU_CAM_ZOOM if menu_camera_far else 1.0)


## 沙盘基准视野：竖直 31 单位，窄屏时按水平需求放宽
func _cam_base_size() -> float:
	var vp := get_viewport().get_visible_rect().size
	if vp.y <= 0.0:
		return 31.0
	var aspect := vp.x / vp.y
	# 沙盘在 45° 俯视下的垂直投影约 29 世界单位，留边距 → 垂直视野 31
	const VIEW_H := 31.0
	# 窄屏时保证水平也能容纳沙盘宽度
	const NEED_W := 50.0
	return maxf(VIEW_H, NEED_W / aspect)


## 开始页：镜头先压回基准再缓缓推远（开场是「拉远」的动作，不是直接远景）；
## 进入游戏时收回来。
func _set_menu_camera(far: bool) -> void:
	menu_camera_far = far
	if wetland:
		wetland.set_menu_camera(far, MENU_CAM_ZOOM)
		return
	var cam := get_node_or_null("../Camera3D") as Camera3D
	if cam == null:
		return
	var base := _cam_base_size()
	if far:
		cam.size = base
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(cam, "size", base * (MENU_CAM_ZOOM if far else 1.0), 1.2 if far else 0.8)


# ==================== 相机 ====================
func _setup_camera() -> void:
	var cam := get_node("../Camera3D") as Camera3D
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 26.0  # 更大的正交尺寸 = 视野更广，能看全沙盘
	# 2.5D 等距俯视：方位角 45°、俯角 45°（视野开阔，地形一览无余）
	cam.position = Vector3(14, 14, 14)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)

	# 沙盘地面：与远景布景协调的草绿（替代场景里的深绿盒子观感）
	var ground_mesh := get_node_or_null("../Ground/GroundMesh") as MeshInstance3D
	if ground_mesh:
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.66, 0.74, 0.52)
		gm.roughness = 1.0
		ground_mesh.material_override = gm

	# 柔白方向光（明亮通透，粉彩感）
	var light := get_node("../DirectionalLight3D") as DirectionalLight3D
	light.light_color = Color(1.0, 0.97, 0.92)
	light.light_energy = 1.15
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.shadow_enabled = true

	# 提亮环境光，画面更柔和明亮
	var env_node := get_node("../WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.76, 0.78, 0.72)
		env.ambient_light_energy = 0.95
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC


# ==================== 3D 表现 ====================
func _build_3d() -> void:
	var lake_view := Node3D.new()
	lake_view.name = "LakeView"
	# 沙盘等比放大（改这个系数即可整体缩放，不影响布局）
	lake_view.scale = Vector3(1.3, 1.3, 1.3)

	# 湖面（鄱阳湖形不规则多边形 + 注入河流）
	lake_mat = ShaderMaterial.new()
	lake_mat.shader = _make_water_shader()
	lake_mat.set_shader_parameter("water_color", lake_color)
	_build_lake_shape(lake_view)

	# 草洲（8 块，主湖区中的草岛，避开河流入湖口）
	var grass_positions := [
		Vector3(-5, 0.05, -1.5), Vector3(-1, 0.05, -2), Vector3(3.5, 0.05, -1.5),
		Vector3(6, 0.05, 0.5), Vector3(1.5, 0.05, 1.5), Vector3(4.5, 0.05, 3.5),
		Vector3(0, 0.05, 5), Vector3(-3.5, 0.05, 4.5),
	]
	for p in grass_positions:
		var mi := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(3.0, 0.25, 3.0)
		mi.mesh = cm
		mi.position = p
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.64, 0.76, 0.50)
		mi.material_override = mat
		lake_view.add_child(mi)
		grass_nodes.append(mi)
		grass_mats.append(mat)

	# 湿地泥滩（浅水与草洲之间的过渡带，暖褐色）
	_build_mudflats(lake_view)

	# 鸟群（8 只白鹤占位）—— 替换为多物种动态个体系统
	_build_species_views(lake_view)

	# 植物（不同湿地植物）
	_build_plant_views(lake_view)

	# 鱼群（8 条占位，水下）
	for i in 8:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.35
		mi.mesh = sm
		mi.position = Vector3(-5 + i * 1.6, -0.15, 2 - (i % 3) * 1.8)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.70, 0.76, 0.82)
		mi.material_override = mat
		lake_view.add_child(mi)
		fish_nodes.append(mi)

	# 人工浮岛（初始隐藏，打出「人工浮岛」牌后显示）
	_build_floating_islands(lake_view)

	# 渔村（湖边一排房子）
	_build_village(lake_view)

	# 长江行船（装饰性，沿长江缓缓往返）
	_build_boats(lake_view)

	# 远景布景草地（环绕沙盘的低多边形起伏草原，不参与游戏交互）
	_build_backdrop_grass(lake_view)

	# 彩蛋：左上角草地刻一个 Minecraft 苦力怕的脸
	_build_creeper_easter_egg(lake_view)

	# 延迟挂到场景，避免父节点初始化期 add_child 冲突
	var root := get_parent() as Node3D
	root.add_child.call_deferred(lake_view)


## 构建鄱阳湖形水面：南宽北狭的「宝葫芦」形，北部狭长入江水道连长江
func _build_lake_shape(parent: Node3D) -> void:
	# 鄱阳湖轮廓（XZ 平面多边形，北为 -z，南为 +z；北窄为入江水道，南宽为主湖区）
	var outline: PackedVector2Array = [
		Vector2(-2.0, -15.5), Vector2(2.0, -15.5),
		Vector2(2.4, -11.5), Vector2(2.8, -8.0), Vector2(3.4, -5.5),
		Vector2(6.5, -5.0), Vector2(8.5, -3.0), Vector2(9.4, 0.0),
		Vector2(9.0, 3.0), Vector2(7.6, 5.5),
		Vector2(5.8, 7.6), Vector2(3.4, 8.4), Vector2(0.0, 8.9),
		Vector2(-3.4, 8.4), Vector2(-5.8, 7.6),
		Vector2(-7.6, 5.5), Vector2(-9.0, 3.0), Vector2(-9.4, 0.0),
		Vector2(-8.5, -3.0), Vector2(-6.5, -5.0),
		Vector2(-3.4, -5.5), Vector2(-2.8, -8.0), Vector2(-2.4, -11.5),
	]
	lake_mesh = _make_flat_polygon(outline, 0.08, lake_mat)
	lake_mesh.name = "PoyangLake"
	parent.add_child(lake_mesh)
	_build_rivers(parent)


## 由中心线生成河流轮廓（两侧各偏移半宽，中心线可弯曲）
func _river_outline(center: PackedVector2Array, width: float) -> PackedVector2Array:
	var left: PackedVector2Array = []
	var right: PackedVector2Array = []
	var n := center.size()
	for i in n:
		var prev: Vector2 = center[clampi(i - 1, 0, n - 1)]
		var nxt: Vector2 = center[clampi(i + 1, 0, n - 1)]
		var dir: Vector2 = (nxt - prev)
		if dir.length() < 0.0001:
			dir = Vector2(1, 0)
		dir = dir.normalized()
		var normal := Vector2(-dir.y, dir.x)  # 垂直方向
		var half := width * 0.5
		left.append(center[i] + normal * half)
		right.append(center[i] - normal * half)
	var outline := left.duplicate()
	for i in range(n - 1, -1, -1):
		outline.append(right[i])
	return outline


## 长江中心线的 z 坐标（随 x 蜿蜒），生成河面与压平地形的公共基准
func _yangtze_z(x: float) -> float:
	return -14.5 + sin(x * 0.16) * 1.0 + sin(x * 0.043 + 1.3) * 0.7


## 河流：长江（北，蜿蜒自西向东）+ 赣江（南，自南向北，与之垂直）+ 修水/饶河
func _build_rivers(parent: Node3D) -> void:
	# 长江：北侧蜿蜒大河，湖体北口（入江水道 z=-14）汇入其中；两端延伸出镜头
	var yangtze_center := PackedVector2Array()
	for i in range(-75, 61, 5):
		var x := float(i)
		yangtze_center.append(Vector2(x, _yangtze_z(x)))
	var yangtze := _make_flat_polygon(_river_outline(yangtze_center, 2.6), 0.08, lake_mat)
	yangtze.name = "Yangtze"
	parent.add_child(yangtze)

	# 赣江：南侧，自南向北注入湖体南部（第一大支流，与长江近垂直）；南端延伸出镜头
	var gan_center := PackedVector2Array()
	for i in range(6, 61, 4):
		gan_center.append(Vector2(0.0, float(i)))
	var gan := _make_flat_polygon(_river_outline(gan_center, 1.8), 0.08, lake_mat)
	gan.name = "GanRiver"
	parent.add_child(gan)

	# 修水：西北注入
	var xiu_center := PackedVector2Array([
		Vector2(-6.0, -3.5), Vector2(-9.5, -6.0), Vector2(-12.5, -8.0), Vector2(-15.0, -10.5),
	])
	var xiu := _make_flat_polygon(_river_outline(xiu_center, 1.1), 0.08, lake_mat)
	xiu.name = "XiuRiver"
	parent.add_child(xiu)

	# 饶河：东侧注入
	var rao_center := PackedVector2Array([
		Vector2(8.0, 1.5), Vector2(11.0, 0.5), Vector2(14.0, 1.5), Vector2(16.5, 2.5),
	])
	var rao := _make_flat_polygon(_river_outline(rao_center, 1.0), 0.08, lake_mat)
	rao.name = "RaoRiver"
	parent.add_child(rao)


# ==================== 长江行船 ====================
## 生成几艘在长江上缓缓往返的船（装饰，不参与游戏交互）
func _build_boats(parent: Node3D) -> void:
	var configs := [
		{"x": -60.0, "speed": 3.2, "dir": 1.0},
		{"x": 18.0, "speed": 2.4, "dir": -1.0},
		{"x": 44.0, "speed": 3.8, "dir": 1.0},
	]
	for c in configs:
		var rig := _make_boat()
		var x: float = c["x"]
		var z: float = _yangtze_z(x)
		rig.position = Vector3(x, 0.12, z)
		parent.add_child(rig)
		boats.append({"rig": rig, "x": x, "speed": c["speed"], "dir": c["dir"]})


## 单艘船的模型：棕色船体 + 船舱 + 桅杆（船头朝 +Z）
func _make_boat() -> Node3D:
	var boat := Node3D.new()
	var hull := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.75, 0.32, 1.9)  # 宽(x) × 高(y) × 长(z，船头朝 +z)
	hull.mesh = hm
	hull.material_override = _mat(Color(0.48, 0.34, 0.24))
	hull.position = Vector3(0, 0.16, 0)
	boat.add_child(hull)
	var cabin := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.6, 0.5, 0.7)
	cabin.mesh = cm
	cabin.material_override = _mat(Color(0.62, 0.46, 0.32))
	cabin.position = Vector3(0, 0.5, -0.35)  # 靠后（-z）
	boat.add_child(cabin)
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.03
	mm.bottom_radius = 0.05
	mm.height = 0.9
	mast.mesh = mm
	mast.material_override = _mat(Color(0.35, 0.28, 0.22))
	mast.position = Vector3(0, 0.75, 0.2)
	boat.add_child(mast)
	return boat


## 长江行船漂移：沿长江中心线缓行，驶出边界后从另一端折返
func _process_boats(delta: float) -> void:
	for b in boats:
		var rig: Node3D = b["rig"]
		var x: float = b["x"] + b["speed"] * b["dir"] * delta
		if x > 61.0:
			x = -76.0
		elif x < -76.0:
			x = 61.0
		b["x"] = x
		# 河流切向 / 垂向：相向而行的船分走河道两侧「车道」，避免会船时穿模
		var dz: float = _yangtze_z(x + 0.6) - _yangtze_z(x - 0.6)
		var tangent := Vector2(1.0, dz).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var lane: float = 0.5 * float(b["dir"])
		var zc: float = _yangtze_z(x)
		rig.position = Vector3(x + normal.x * lane, 0.12, zc + normal.y * lane)
		# 朝向河水流向（船头 +Z 对准切线方向）
		rig.rotation.y = atan2(b["dir"], dz * b["dir"])


## 用多边形构建一块平面水面（在 y 平面，unshaded 水面材质）
func _make_flat_polygon(points: PackedVector2Array, y: float, mat: Material) -> MeshInstance3D:
	var indices := Geometry2D.triangulate_polygon(points)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices:
		var p: Vector2 = points[i]
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(p.x, y, p.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## 为鸟类找一个栖息点：优先乔木树冠，其次草洲/挺水植物
func _find_perch_point(sid: String, seed_i: int) -> Vector3:
	# 优先在乔木上停歇（树冠高度约 1.5~2.6）
	var tree_rigs: Array = plant_views.get("chishan", {}).get("rigs", [])
	var visible_trees: Array = []
	for r in tree_rigs:
		if r.visible:
			visible_trees.append(r)
	if not visible_trees.is_empty():
		var t: Node3D = visible_trees[(seed_i * 7 + int(sid.length())) % visible_trees.size()]
		return t.position + Vector3(0, 2.5, 0)
	# 退而求其次：草洲/挺水植物上方
	for kind_want in ["marsh", "emergent"]:
		for pid in plant_views:
			if plant_views[pid]["kind"] != kind_want:
				continue
			var rigs: Array = plant_views[pid]["rigs"]
			var vis: Array = []
			for r in rigs:
				if r.visible:
					vis.append(r)
			if not vis.is_empty():
				var p: Node3D = vis[(seed_i * 5 + 3) % vis.size()]
				return p.position + Vector3(0, 1.2, 0)
	# 最后兜底：原地
	return Vector3(-6 + seed_i * 1.2, 1.0, -3 + (seed_i % 3) * 2.0)


## 远景布景：环绕沙盘的起伏草原（纯装饰，不参与任何游戏交互）
func _build_backdrop_grass(parent: Node3D) -> void:
	var backdrop := Node3D.new()
	backdrop.name = "Backdrop"
	parent.add_child(backdrop)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260925  # 固定种子，每次启动地貌一致

	# 1) 起伏地面：大尺寸 PlaneMesh + 顶点位移（用 SurfaceTool 造波状起伏）
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 90.0     # 覆盖 180×180，远超沙盘，视野边缘不会露空
	var cells := 60
	var step := half * 2.0 / cells
	for ix in cells:
		for iz in cells:
			var x0 := -half + ix * step
			var z0 := -half + iz * step
			var x1 := x0 + step
			var z1 := z0 + step
			var v00 := Vector3(x0, _backdrop_height(x0, z0), z0)
			var v10 := Vector3(x1, _backdrop_height(x1, z0), z0)
			var v01 := Vector3(x0, _backdrop_height(x0, z1), z1)
			var v11 := Vector3(x1, _backdrop_height(x1, z1), z1)
			# 双面渲染 + 显式向上法线，彻底避免朝向/背光问题
			var up := Vector3.UP
			st.set_normal(up); st.add_vertex(v00)
			st.set_normal(up); st.add_vertex(v11)
			st.set_normal(up); st.add_vertex(v01)
			st.set_normal(up); st.add_vertex(v00)
			st.set_normal(up); st.add_vertex(v10)
			st.set_normal(up); st.add_vertex(v11)
	var ground := MeshInstance3D.new()
	ground.mesh = st.commit()
	ground.material_override = _mat(Color(0.66, 0.74, 0.54))
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.position = Vector3(0, -0.28, 0)  # 略低于沙盘地面，避免z-fighting
	backdrop.add_child(ground)

	# 2) 散落的远景树（沙盘外围才放，避免遮挡主场景）
	var tree_spots: Array = []
	for k in 150:
		var ang := rng.randf_range(0, TAU)
		var dist := rng.randf_range(24.0, 82.0)  # 只在沙盘(±18)之外
		var x := cos(ang) * dist
		var z := sin(ang) * dist
		if _in_river_zone(x, z) or _in_creeper_zone(x, z):
			continue
		tree_spots.append(Vector3(x, _backdrop_height(x, z), z))
	for p in tree_spots:
		var t := _make_backdrop_tree(rng)
		t.position = p
		backdrop.add_child(t)

	# 3) 灌木丛点缀
	for k in 90:
		var ang := rng.randf_range(0, TAU)
		var dist := rng.randf_range(22.0, 85.0)
		var x := cos(ang) * dist
		var z := sin(ang) * dist
		if _in_river_zone(x, z) or _in_creeper_zone(x, z):
			continue
		var bush := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = rng.randf_range(0.7, 1.4)
		bm.height = bm.radius * 1.1
		bush.mesh = bm
		bush.material_override = _mat(Color(0.52, 0.64, 0.44).lightened(rng.randf_range(0.0, 0.14)))
		bush.position = Vector3(x, _backdrop_height(x, z) + bm.radius * 0.4, z)
		bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		backdrop.add_child(bush)


## 是否处于河流走廊内（长江/赣江水面 + 河岸），用于让远景树/灌木避开河道
func _in_river_zone(x: float, z: float) -> bool:
	if x > -77.0 and x < 62.0 and absf(z - _yangtze_z(x)) < 4.0:
		return true
	if z > 5.0 and z < 61.0 and absf(x) < 4.0:
		return true
	return false


## 是否处于苦力怕彩蛋区域，用于让远景树/灌木避开
func _in_creeper_zone(x: float, z: float) -> bool:
	return Vector2(x - CREEPER_X, z - CREEPER_Z).length() < 7.0


## 远景地形高度：几层正弦叠加，形成平缓起伏（距离沙盘越远越不必精确）
func _backdrop_height(x: float, z: float) -> float:
	var h := sin(x * 0.11) * cos(z * 0.13) * 1.6
	h += sin(x * 0.31 + 1.7) * cos(z * 0.27 - 0.6) * 0.55
	h += sin(x * 0.63 - 0.4) * cos(z * 0.58 + 2.1) * 0.22
	# 河流走廊压平到河床高度，避免延伸出的河面被起伏地形掩埋
	var yangtze_d := absf(z - _yangtze_z(x))
	if x > -77.0 and x < 62.0 and yangtze_d < 4.0:
		h = lerpf(-0.28, h, clampf((yangtze_d - 2.2) / 1.8, 0.0, 1.0))
	elif z > 5.0 and z < 61.0 and absf(x) < 4.0:
		h = lerpf(-0.28, h, clampf((absf(x) - 1.8) / 2.2, 0.0, 1.0))
	# 苦力怕彩蛋草地压平，保证脸平整贴地
	var creeper_d := Vector2(x - CREEPER_X, z - CREEPER_Z).length()
	if creeper_d < 8.0:
		h = lerpf(-0.28, h, clampf((creeper_d - 5.0) / 3.0, 0.0, 1.0))
	# 靠近沙盘（半径 22 内）压平并下沉，与沙盘地面平滑衔接
	var d := Vector2(x, z).length()
	if d < 26.0:
		var t := clampf((d - 20.0) / 6.0, 0.0, 1.0)
		h = lerpf(-0.28, h, t)
	return h


## 彩蛋：左上角草地贴一张苦力怕脸（用素材图片，已抠掉亮绿背景）
func _build_creeper_easter_egg(parent: Node3D) -> void:
	# 优先走导入资源（导出打包也能用），失败则直接读文件
	var tex: Texture2D = load("res://assets/creeper.png")
	if tex == null:
		var img := Image.load_from_file("res://assets/creeper.png")
		if img == null:
			return
		tex = ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL  # 与草地同受光照，头部才能和草地同色
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var aspect := float(tex.get_width()) / float(tex.get_height())
	pm.size = Vector2(CREEPER_SIZE, CREEPER_SIZE / aspect)
	mi.mesh = pm
	mi.material_override = mat
	# 草地压平后高度为 -0.28（顶点）+ 节点 -0.28，脸贴在其上略微抬高避免 z-fighting
	mi.position = Vector3(CREEPER_X, -0.28 + _backdrop_height(CREEPER_X, CREEPER_Z) + 0.02, CREEPER_Z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	creeper_mesh = mi


## 苦力怕彩蛋按概率显示（每次进入主菜单重掷）
func _roll_creeper_visibility() -> void:
	if creeper_mesh != null:
		creeper_mesh.visible = randf() < CREEPER_CHANCE
	if wetland != null:
		wetland.call("roll_creeper_visibility")


## 远景树：低多边形锥形树（随机高矮胖瘦）
func _make_backdrop_tree(rng: RandomNumberGenerator) -> Node3D:
	var tree := Node3D.new()
	var h := rng.randf_range(2.2, 4.6)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.10
	tm.bottom_radius = 0.20
	tm.height = h * 0.45
	trunk.mesh = tm
	trunk.material_override = _mat(Color(0.55, 0.45, 0.36))
	trunk.position = Vector3(0, h * 0.225, 0)
	tree.add_child(trunk)
	var layers := 2 + rng.randi() % 2
	for layer in layers:
		var canopy := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		var r := h * 0.30 * (1.0 - layer * 0.22)
		cm.bottom_radius = r
		cm.height = h * 0.42
		canopy.mesh = cm
		var green := rng.randf_range(0.55, 0.72)
		canopy.material_override = _mat(Color(green * 0.80, green, green * 0.82))
		canopy.position = Vector3(0, h * 0.42 + layer * h * 0.20, 0)
		canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tree.add_child(canopy)
	return tree


## 人工浮岛：水面上的绿色浮床（打出「人工浮岛」牌后显示，拆除牌后隐藏）
func _build_floating_islands(parent: Node3D) -> void:
	var island_positions := [
		Vector3(-4, 0, -2.5), Vector3(0, 0, -0.5), Vector3(3.5, 0, 2), Vector3(-2, 0, 3.5),
	]
	for p in island_positions:
		var island := _make_floating_island()
		island.position = p
		island.visible = false
		parent.add_child(island)
		island_nodes.append(island)


## 单个浮岛模型：棕色浮床底座 + 绿色植被 + 几株挺水植物
func _make_floating_island() -> Node3D:
	var island := Node3D.new()
	# 浮床底座
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 0.16, 1.4)
	base.mesh = bm
	base.material_override = _mat(Color(0.55, 0.42, 0.30))
	base.position = Vector3(0, 0.17, 0)
	island.add_child(base)
	# 植被层
	var veg := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(1.4, 0.28, 1.0)
	veg.mesh = vm
	veg.material_override = _mat(Color(0.40, 0.66, 0.36))
	veg.position = Vector3(0, 0.38, 0)
	island.add_child(veg)
	# 几株挺水植物点缀
	for k in 3:
		var sprout := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.02
		sm.bottom_radius = 0.05
		sm.height = 0.5 + (k % 2) * 0.15
		sprout.mesh = sm
		sprout.material_override = _mat(Color(0.45, 0.70, 0.38))
		sprout.position = Vector3((k - 1) * 0.5, 0.38 + (0.5 + (k % 2) * 0.15) / 2.0, (k % 2 - 0.5) * 0.3)
		island.add_child(sprout)
	return island


## 湖边社区：房子数量随用地（settlement）增减，原地拆除处长出湿地芦苇；颜色随社区信任度明暗变化
func _build_village(parent: Node3D) -> void:
	var house_positions := [
		Vector3(-13, 0, -6.5), Vector3(-12.5, 0, -5.2), Vector3(-13, 0, -3.4),
		Vector3(-12.2, 0, -1.6), Vector3(-10.6, 0, 0.2),   # 原有 5 栋（离湖较远）
		Vector3(-9.5, 0, -4.2), Vector3(-10.2, 0, -0.6),   # 新增 2 栋（侵占，靠湖，落在岸上）
	]
	# 美术素材：四款房屋循环使用，营造村庄错落感
	var house_tex_paths := [
		"res://assets/houses/house1.png",
		"res://assets/houses/house2.png",
		"res://assets/houses/house3.png",
		"res://assets/houses/house4.png",
	]
	for i in house_positions.size():
		var p: Vector3 = house_positions[i]
		var house := _make_house(house_tex_paths[i % house_tex_paths.size()])
		house.position = p
		parent.add_child(house)
		var reeds := _make_reed_clump()
		reeds.position = p
		reeds.visible = false
		parent.add_child(reeds)
		var sprite := house.get_child(0) as Sprite3D
		house_slots.append({"house": house, "sprite": sprite, "reeds": reeds})


## 用美术同学画的房屋素材（2D 贴图广告牌）替代原来的 3D 盒子房。
## 返回一个 Node3D 容器（落点 y=0 贴地），内部 Sprite3D 上移半高让贴图底部贴住地面。
func _make_house(path: String) -> Node3D:
	# 优先用导入的贴图（含 mipmap、导出后仍可用）；未导入时直接读 PNG 字节兜底
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		var img := Image.load_from_file(path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		# 素材缺失/读不到时兜底：纯色方块，保证不崩
		var fallback := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		fallback.fill(Color(0.88, 0.78, 0.62))
		tex = ImageTexture.create_from_image(fallback)

	var node := Node3D.new()
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.pixel_size = 0.02
	sprite.position = Vector3(0, 1.0, 0)   # 贴图中心上移，底部贴地
	node.add_child(sprite)
	return node


## 退还湿地的芦苇丛（房子拆除后的替代植被）：低矮底垫 + 几根细高秆芦苇
func _make_reed_clump() -> Node3D:
	var clump := Node3D.new()
	# 底垫：低矮泥/草地，表示田地已退为湿地
	var pad := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(1.5, 0.12, 1.3)
	pad.mesh = pm
	pad.material_override = _mat(Color(0.58, 0.70, 0.48))
	pad.position = Vector3(0, 0.06, 0)
	clump.add_child(pad)
	# 芦苇：细高秆 + 顶部穗
	var reed_col := Color(0.62, 0.72, 0.50)
	for k in 5:
		var ang := k * 1.26
		var h := 1.5 + (k % 3) * 0.22
		var stalk := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.03
		sm.bottom_radius = 0.05
		sm.height = h
		stalk.mesh = sm
		stalk.material_override = _mat(reed_col)
		stalk.position = Vector3(cos(ang) * 0.34, 0.06 + h / 2.0, sin(ang) * 0.30)
		clump.add_child(stalk)
		var tassel := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.02
		tm.bottom_radius = 0.07
		tm.height = 0.28
		tassel.mesh = tm
		tassel.material_override = _mat(reed_col.lightened(0.28))
		tassel.position = Vector3(cos(ang) * 0.34, 0.06 + h, sin(ang) * 0.30)
		clump.add_child(tassel)
	return clump


## 水面 shader：轻微微波 + 波光
func _make_water_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 water_color : source_color = vec4(0.62, 0.80, 0.86, 0.88);
uniform float wave_speed = 0.55;
uniform float wave_strength = 0.06;

void fragment() {
	// 两层正弦叠加，形成缓慢流动的波纹
	float w1 = sin(VERTEX.x * 2.2 + TIME * wave_speed) * 0.5 + 0.5;
	float w2 = sin(VERTEX.z * 1.7 - TIME * wave_speed * 0.8) * 0.5 + 0.5;
	float ripple = (w1 * w2);
	// 波光提亮水面，产生细微的明暗流动
	vec3 col = water_color.rgb + vec3(0.10, 0.13, 0.16) * ripple * wave_strength * 16.0;
	ALBEDO = col;
	ALPHA = water_color.a;
}
"""
	return sh


## 全屏像素化后处理：把屏幕 UV 量化到 pixel_size 大小的块，形成块状像素
func _make_pixelate_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float pixel_size : hint_range(1.0, 16.0) = 3.5;
uniform sampler2D screen_texture : hint_screen_texture;

void fragment() {
	// 最近邻像素化：按块取左上角像素，整块同色
	vec2 block = SCREEN_PIXEL_SIZE * pixel_size;
	vec2 uv = floor(SCREEN_UV / block) * block;
	COLOR = texture(screen_texture, uv);
}
"""
	return sh


## 像素化图层：位于 UICanvas(layer=1) 之下，只像素化 3D，HUD/文字保持清晰
func _build_pixelate_layer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PixelateLayer"
	layer.layer = 0  # 只像素化 3D，UI/文字保持清晰锐利
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = _make_pixelate_shader()
	rect.material = sm
	layer.add_child(rect)


## 生成棋盘网格线（生息演算式棋盘感）
func _build_grid(parent: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var half := 18.0      # 网格半宽（覆盖 36×36）
	var step := 2.0       # 格子大小 2 米
	var y := 0.12         # 略高于地面与湖面
	var n := int(half / step)  # 每方向 9 条线（-18..18）
	for i in range(-n, n + 1):
		var c := i * step
		# 横向线（沿 X）
		st.add_vertex(Vector3(-half, y, c))
		st.add_vertex(Vector3(half, y, c))
		# 纵向线（沿 Z）
		st.add_vertex(Vector3(c, y, -half))
		st.add_vertex(Vector3(c, y, half))
	var grid_mesh := st.commit()

	var mi := MeshInstance3D.new()
	mi.name = "GridLines"
	mi.mesh = grid_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## 湿地泥滩（浅水与草洲之间的过渡带，暖褐色）
func _build_mudflats(parent: Node3D) -> void:
	var positions := [
		Vector3(-12, 0.03, 0), Vector3(12, 0.03, -2), Vector3(-3, 0.03, -12),
		Vector3(3, 0.03, 12), Vector3(-9, 0.03, 7), Vector3(9, 0.03, -8),
	]
	for p in positions:
		var mi := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(4.0, 0.15, 4.0)
		mi.mesh = cm
		mi.position = p
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.80, 0.72, 0.60)
		mi.material_override = mat
		parent.add_child(mi)


func _process(delta: float) -> void:
	# 指标悬停小窗：暂停/弹层时它自己会收起来，所以放在 _paused 提前返回之前
	_update_metric_tip()
	if wetland:
		wetland.set_process(not _paused)
	if _paused:
		return
	# 开场 PPT 计时：不按键则 8 秒自动过一张
	if _intro_playing:
		_intro_elapsed += delta
		if _intro_elapsed >= INTRO_SLIDE_SEC:
			_advance_intro()
	_update_card_hover(delta)
	_process_deck_gyro(delta)
	_process_detail_gyro(delta)   # 点开的那张放大牌：指针压上去时同样要晃
	_update_sort_cooldown()
	_update_lever_cooldown()
	# 容器尺寸变化时重排扇形（居中）
	# ⚠ 算分动画期间必须跳过：_layout_fan() 会把牌瞬间抓回扇形原位**并覆写 base_pos**，
	#   飞出去排开的牌会被一把拽回来。（正常情况下这个尺寸判据是稳定的，
	#   但动画期间任何一次布局抖动都会毁掉整段演出。）
	if not _score_animating and card_box != null and card_box.size.x > 10.0:
		if _fan_layout_size.distance_to(card_box.size) > 1.0:
			_layout_fan()


## 植物随风轻微摆动（只有挺水/乔木/草洲这类露出水面的才明显摆动）
func _process_plants_sway() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for pid in plant_views:
		var kind: String = plant_views[pid]["kind"]
		if kind == "submerged":
			continue  # 沉水植物随水波，不随风
		var amp := 0.045 if kind == "emergent" else 0.03
		var rigs: Array = plant_views[pid]["rigs"]
		for i in rigs.size():
			var rig: Node3D = rigs[i]
			if not rig.visible:
				continue
			# 各自相位错开，避免整齐划一
			var ph := i * 0.8 + rig.position.x * 0.3
			rig.rotation.z = sin(t * 1.1 + ph) * amp
			rig.rotation.x = cos(t * 0.9 + ph * 1.3) * amp * 0.6


## 鸟类状态机：站立 / 啄水 / 行走，朝向符合移动方向
func _process_birds(delta: float) -> void:
	for sid in species_views:
		var view: Dictionary = species_views[sid]
		var rigs: Array = view["rigs"]
		var bases: Array = view["bases"]
		var states: Array = view["states"]
		var timers: Array = view["timers"]
		var targets: Array = view["targets"]
		for i in rigs.size():
			var rig: Node3D = rigs[i]
			if not rig.visible:
				continue
			var base: Vector3 = bases[i]
			timers[i] -= delta
			if timers[i] <= 0.0:
				# 切换状态
				var r := randf()
				# 植被好时，更高概率找栖息地停歇（体现生态联动）
				var veg: int = GameState.metrics.get("vegetation", 50)
				var perch_chance := 0.12 + float(veg) / 100.0 * 0.25
				if r < perch_chance:
					states[i] = 3  # 停歇（飞到栖息点）
					timers[i] = 6.0 + randf() * 4.0
					targets[i] = _find_perch_point(sid, i)
				elif r < 0.45:
					states[i] = 0  # 站立
					timers[i] = 1.0 + randf() * 2.5
				elif r < 0.78:
					states[i] = 1  # 啄水
					timers[i] = 1.2 + randf() * 1.4
				else:
					states[i] = 2  # 行走
					timers[i] = 2.0 + randf() * 2.5
					var ang := randf() * TAU
					var dist := 1.6 + randf() * 3.5
					targets[i] = base + Vector3(cos(ang) * dist, 0, sin(ang) * dist)

			var st: int = states[i]
			match st:
				0:  # 站立：回正，静止
					rig.rotation.x = lerpf(rig.rotation.x, 0.0, delta * 6.0)
					rig.position.y = base.y
				1:  # 啄水：俯身低头
					rig.rotation.x = lerpf(rig.rotation.x, 0.55, delta * 8.0)
					rig.position.y = base.y
				2:  # 行走：朝目标移动，朝向移动方向
					var target: Vector3 = targets[i]
					var to_t := target - rig.position
					var flat := Vector3(to_t.x, 0, to_t.z)
					if flat.length() < 0.2:
						states[i] = 0
						timers[i] = 1.0 + randf() * 2.0
						rig.rotation.x = lerpf(rig.rotation.x, 0.0, delta * 6.0)
					else:
						var dir := flat.normalized()
						var speed := 0.9
						rig.position += dir * speed * delta
						# 朝向移动方向（喙在 +Z）
						rig.rotation.y = atan2(dir.x, dir.z)
						rig.rotation.x = lerpf(rig.rotation.x, 0.0, delta * 6.0)
						# 走路轻微颠簸
						rig.position.y = base.y + abs(sin(Time.get_ticks_msec() * 0.012 + i * 1.7)) * 0.05
				3:  # 停歇：飞向栖息点并在其上停留
					var perch: Vector3 = targets[i]
					var to_p := perch - rig.position
					if to_p.length() < 0.25:
						# 已到栖息点：停在上面（可轻微起伏，像站在枝头）
						rig.position = perch
						rig.rotation.x = lerpf(rig.rotation.x, 0.0, delta * 5.0)
						rig.position.y = perch.y + sin(Time.get_ticks_msec() * 0.004 + i) * 0.03
					else:
						# 飞行：抬升 + 朝目标（速度较快，确保能飞到栖息点）
						var fdir := to_p.normalized()
						rig.position += fdir * 4.5 * delta
						rig.rotation.y = atan2(fdir.x, fdir.z)
						# 飞行时前倾
						rig.rotation.x = lerpf(rig.rotation.x, -0.25, delta * 5.0)


## 为每个物种生成一组会动的个体（最多 10 个/物种），用多几何体拼出可辨识剪影
func _build_species_views(parent: Node3D) -> void:
	for sid in GameState.SPECIES:
		var rigs: Array = []
		var bases: Array = []
		var states: Array = []
		var timers: Array = []
		var targets: Array = []
		for i in 10:
			var rig := Node3D.new()  # 一个物种个体 = 一组几何体
			rig.name = sid
			_build_bird_body(rig, sid)
			rig.visible = false
			parent.add_child(rig)
			rigs.append(rig)
			var base := Vector3(
				(-7 + i * 1.5) + (sid.length() % 3) * 2.0,
				0.0,
				-5 + (i % 4) * 3.0
			)
			bases.append(base)
			states.append(0)
			timers.append(1.0 + (i % 5) * 0.6)
			targets.append(base)
		species_views[sid] = {
			"rigs": rigs, "bases": bases,
			"states": states, "timers": timers, "targets": targets,
		}


## 用几何体拼出鸟类剪影（可辨识）
func _build_bird_body(rig: Node3D, sid: String) -> void:
	var white := Color(0.96, 0.96, 0.94)
	var dark := Color(0.35, 0.35, 0.40)
	var grey := Color(0.78, 0.78, 0.74)
	var red := Color(0.85, 0.45, 0.42)
	var yellow := Color(0.95, 0.85, 0.55)
	var brown := Color(0.72, 0.62, 0.50)

	# 躯干（椭球）
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.28
	bm.height = 0.6
	body.mesh = bm
	body.scale = Vector3(0.8, 0.9, 1.3)
	body.position = Vector3(0, 0.85, 0)
	rig.add_child(body)

	# 头
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.16
	hm.height = 0.34
	head.mesh = hm
	head.position = Vector3(0, 1.35, 0.15)
	rig.add_child(head)

	# 长颈（圆柱，连接头与躯干）
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.06
	nm.bottom_radius = 0.08
	nm.height = 0.55
	neck.mesh = nm
	neck.position = Vector3(0, 1.08, 0.05)
	rig.add_child(neck)

	# 长腿（两根细圆柱）
	for side in [-1, 1]:
		var leg := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.02
		lm.bottom_radius = 0.02
		lm.height = 0.55
		leg.mesh = lm
		leg.position = Vector3(side * 0.12, 0.35, 0.0)
		rig.add_child(leg)

	# 喙
	var beak := MeshInstance3D.new()
	var bkm := CylinderMesh.new()
	bkm.top_radius = 0.015
	bkm.bottom_radius = 0.03
	bkm.height = 0.2
	beak.mesh = bkm
	beak.rotation_degrees = Vector3(90, 0, 0)
	beak.position = Vector3(0, 1.38, 0.32)
	rig.add_child(beak)

	# 按物种上色与特殊特征
	match sid:
		"baihe":
			body.material_override = _mat(white)
			head.material_override = _mat(white)
			neck.material_override = _mat(white)
			beak.material_override = _mat(yellow)
			# 红色裸区（头顶）
			var crown := MeshInstance3D.new()
			var crm := SphereMesh.new()
			crm.radius = 0.07
			crm.height = 0.15
			crown.mesh = crm
			crown.material_override = _mat(red)
			crown.position = Vector3(0, 1.42, 0.15)
			rig.add_child(crown)
			# 黑色翅尖
			var wing := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(0.5, 0.08, 0.3)
			wing.mesh = wm
			wing.material_override = _mat(dark)
			wing.position = Vector3(0, 0.9, -0.35)
			rig.add_child(wing)
		"dongfangbaihuan":
			body.material_override = _mat(white)
			head.material_override = _mat(white)
			neck.material_override = _mat(white)
			beak.material_override = _mat(dark)
			# 黑色大翅
			var dwing := MeshInstance3D.new()
			var dwm := BoxMesh.new()
			dwm.size = Vector3(0.6, 0.1, 0.5)
			dwing.mesh = dwm
			dwing.material_override = _mat(dark)
			dwing.position = Vector3(0, 0.9, -0.45)
			rig.add_child(dwing)
		"xiaotiane":
			body.material_override = _mat(white)
			head.material_override = _mat(white)
			neck.material_override = _mat(white)
			beak.material_override = _mat(yellow)
		"baizhenhe":
			body.material_override = _mat(grey)
			head.material_override = _mat(grey)
			neck.material_override = _mat(grey)
			beak.material_override = _mat(yellow)
			# 红色脸
			var face := MeshInstance3D.new()
			var fsm := SphereMesh.new()
			fsm.radius = 0.08
			fsm.height = 0.16
			face.mesh = fsm
			face.material_override = _mat(red)
			face.position = Vector3(0, 1.36, 0.22)
			rig.add_child(face)
		"yanlei":
			body.material_override = _mat(brown)
			head.material_override = _mat(brown)
			neck.material_override = _mat(brown)
			beak.material_override = _mat(yellow)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _update_species_views() -> void:
	for sid in GameState.SPECIES:
		var pop: int = GameState.species_pop.get(sid, 0)
		var count: int = int(pop / 10.0)  # 0-100 → 0-10 个
		var view: Dictionary = species_views[sid]
		var rigs: Array = view["rigs"]
		for i in rigs.size():
			var rig: Node3D = rigs[i]
			var should_show := i < count
			if should_show and not rig.visible:
				# 新出现的个体：弹性放大登场（TRANS_BACK，有"冒出来"的弹性感）
				rig.visible = true
				rig.scale = Vector3(0.01, 0.01, 0.01)
				var tw := rig.create_tween()
				tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(rig, "scale", Vector3.ONE, 0.4)
			elif should_show and rig.scale.x < 1.0:
				# 正在退场又需要显示：立即恢复
				rig.scale = Vector3.ONE
			elif not should_show and rig.visible:
				# 消失的个体：缩小淡出后隐藏（不打断正在进行的退场动画）
				if rig.scale.x < 0.9:
					continue
				var tw2 := rig.create_tween()
				tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				tw2.tween_property(rig, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
				tw2.tween_callback(func() -> void: rig.visible = false)


## 为每种植物生成一组个体（组合模型：根 Node3D + 多个几何体）
func _build_plant_views(parent: Node3D) -> void:
	for pid in GameState.PLANTS:
		var rigs: Array = []
		var kind: String = GameState.PLANTS[pid]["kind"]
		for i in 14:
			var rig := Node3D.new()
			rig.visible = false
			_build_plant_model(rig, pid, kind)
			parent.add_child(rig)
			rigs.append(rig)
		plant_views[pid] = {"rigs": rigs, "kind": kind}


## 构建植物组合模型（比单几何体更有辨识度）
func _build_plant_model(rig: Node3D, pid: String, kind: String) -> void:
	var c: Color = GameState.PLANTS[pid]["color"]
	match kind:
		"submerged":
			# 苦草：水下丛生的带状叶片
			for k in 5:
				var leaf := MeshInstance3D.new()
				var lm := BoxMesh.new()
				lm.size = Vector3(0.08, 0.7, 0.18)
				leaf.mesh = lm
				leaf.material_override = _mat(c)
				leaf.position = Vector3((k - 2) * 0.11, 0.35, (k % 2) * 0.08)
				leaf.rotation.z = (k - 2) * 0.12
				rig.add_child(leaf)
		"floating":
			# 莲：圆形浮叶 + 花
			for k in 3:
				var pad := MeshInstance3D.new()
				var pm := CylinderMesh.new()
				pm.top_radius = 0.32
				pm.bottom_radius = 0.32
				pm.height = 0.04
				pad.mesh = pm
				pad.material_override = _mat(c)
				pad.position = Vector3((k - 1) * 0.42, 0.06, (k % 2) * 0.3)
				rig.add_child(pad)
			var flower := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.09
			fm.height = 0.18
			flower.mesh = fm
			flower.material_override = _mat(Color(0.94, 0.80, 0.86))
			flower.position = Vector3(0, 0.22, 0)
			rig.add_child(flower)
		"emergent":
			# 芦苇：多根细高秆 + 顶部穗
			for k in 4:
				var stalk := MeshInstance3D.new()
				var sm := CylinderMesh.new()
				sm.top_radius = 0.03
				sm.bottom_radius = 0.045
				sm.height = 1.9 + (k % 3) * 0.25
				stalk.mesh = sm
				stalk.material_override = _mat(c)
				stalk.position = Vector3((k - 1.5) * 0.16, (1.9 + (k % 3) * 0.25) / 2.0, (k % 2) * 0.12)
				rig.add_child(stalk)
				var tassel := MeshInstance3D.new()
				var tm := CylinderMesh.new()
				tm.top_radius = 0.02
				tm.bottom_radius = 0.07
				tm.height = 0.32
				tassel.mesh = tm
				tassel.material_override = _mat(c.lightened(0.28))
				tassel.position = Vector3((k - 1.5) * 0.16, 1.9 + (k % 3) * 0.25, (k % 2) * 0.12)
				rig.add_child(tassel)
		"tree":
			# 池杉：树干 + 三层锥形树冠
			var trunk := MeshInstance3D.new()
			var trm := CylinderMesh.new()
			trm.top_radius = 0.09
			trm.bottom_radius = 0.16
			trm.height = 1.6
			trunk.mesh = trm
			trunk.material_override = _mat(Color(0.55, 0.45, 0.36))
			trunk.position = Vector3(0, 0.8, 0)
			rig.add_child(trunk)
			for layer in 3:
				var canopy := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				var r := 0.85 - layer * 0.22
				cm.top_radius = 0.02
				cm.bottom_radius = r
				cm.height = 0.75
				canopy.mesh = cm
				canopy.material_override = _mat(c.lightened(layer * 0.08))
				canopy.position = Vector3(0, 1.5 + layer * 0.55, 0)
				rig.add_child(canopy)
		_:  # marsh 草洲
			# 草丛：一簇小锥
			for k in 6:
				var blade := MeshInstance3D.new()
				var bm := CylinderMesh.new()
				bm.top_radius = 0.01
				bm.bottom_radius = 0.07
				bm.height = 0.45 + (k % 3) * 0.15
				blade.mesh = bm
				blade.material_override = _mat(c.lightened((k % 3) * 0.06))
				var ang := k * 1.05
				blade.position = Vector3(cos(ang) * 0.14, (0.45 + (k % 3) * 0.15) / 2.0, sin(ang) * 0.14)
				blade.rotation.z = cos(ang) * 0.22
				blade.rotation.x = sin(ang) * 0.22
				rig.add_child(blade)


func _update_plant_views() -> void:
	_ensure_plant_positions()
	for pid in GameState.PLANTS:
		var pop: int = GameState.plant_pop.get(pid, 0)
		var count: int = int(pop / 7.0)  # 0-100 → 0-14
		var view: Dictionary = plant_views[pid]
		var rigs: Array = view["rigs"]
		var kind: String = view["kind"]
		for i in rigs.size():
			var rig: Node3D = rigs[i]
			var should_show := i < count
			if should_show and not rig.visible:
				# 生长动画：从地面纵向"长出来"（高度 0→1 + 轻微过冲）
				rig.visible = true
				rig.position = _plant_position(pid, kind, i)
				rig.scale = Vector3(1.0, 0.01, 1.0)
				var tw := rig.create_tween()
				tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(rig, "scale", Vector3.ONE, 0.55).set_delay(i * 0.03)
			elif should_show:
				# 已在显示：确保缩放正确（防止动画被打断后残留小尺寸）
				if rig.scale.y < 0.95:
					rig.scale = Vector3.ONE
					rig.position = _plant_position(pid, kind, i)
			elif not should_show and rig.visible:
				# 消退：纵向缩回地面
				var tw2 := rig.create_tween()
				tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				tw2.tween_property(rig, "scale", Vector3(1.0, 0.01, 1.0), 0.3)
				tw2.tween_callback(func() -> void: rig.visible = false)


func _plant_position(pid: String, _kind: String, i: int) -> Vector3:
	var pts: Array = plant_positions.get(pid, [])
	if i < pts.size():
		return pts[i]
	return Vector3.ZERO


## 每局按种子随机散落植物位置：打破原来的成排成条网格，改为自然散布
func _ensure_plant_positions() -> void:
	if _plant_pos_seed == GameState.run_seed:
		return
	_plant_pos_seed = GameState.run_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run_seed
	for pid in GameState.PLANTS:
		var kind: String = GameState.PLANTS[pid]["kind"]
		var pts: Array = []
		for i in 14:
			pts.append(_scatter_plant(kind, pts, rng))
		plant_positions[pid] = pts


## 在各自生境区域内随机取点，同类之间保持最小间距，避免叠成一团
func _scatter_plant(kind: String, placed: Array, rng: RandomNumberGenerator) -> Vector3:
	for attempt in 40:
		var p := _plant_zone_point(kind, rng)
		var ok := true
		for q in placed:
			if p.distance_to(q) < 1.4:
				ok = false
				break
		if ok:
			return p
	return _plant_zone_point(kind, rng)


## 各植物的生境区域（沿用原分布范围，仅把固定网格改为随机取点）
func _plant_zone_point(kind: String, rng: RandomNumberGenerator) -> Vector3:
	match kind:
		"submerged":  # 苦草：水下浅水区
			return Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-2.0, 3.0))
		"floating":   # 莲/荷叶：开阔水面
			return Vector3(rng.randf_range(2.0, 12.0), 0.06, rng.randf_range(-4.0, 1.0))
		"emergent":   # 芦苇：岸边浅滩
			return Vector3(rng.randf_range(-9.0, 6.6), 0.5, rng.randf_range(3.0, 5.5))
		"tree":       # 乔木：岸线 / 草洲外围
			return Vector3(rng.randf_range(-13.0, 11.0), 0.0, rng.randf_range(-12.0, -6.8))
		_:            # 草洲
			return Vector3(rng.randf_range(-8.0, 6.4), 0.05, rng.randf_range(5.0, 7.4))


func _build_wetland() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WetlandLayer"
	layer.layer = -5
	add_child(layer)
	wetland = PixelWetland.new()
	wetland.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(wetland)
	get_node("../Ground").hide()


func _update_3d() -> void:
	# Keep the existing signal and score-animation boundary; presentation is read-only.
	if not _score_animating and wetland:
		wetland.sync_state()


# ==================== UI ====================
func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UICanvas"
	add_child(canvas)
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float a = smoothstep(0.57, 1.0, UV.y) * 0.72 + (1.0-smoothstep(0.0, 0.16, UV.y))*0.32; COLOR = vec4(0.16, 0.21, 0.25, a); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	scrim.material = material
	canvas.add_child(scrim)


	# --- 左侧：时间 / 金钱 / 事件（收窄为竖条，把沙盘让出来）---
	left_panel = PanelContainer.new()
	left_panel.anchor_left = 0.0
	left_panel.anchor_top = 0.0
	left_panel.anchor_right = 0.0
	left_panel.anchor_bottom = 0.0
	left_panel.offset_left = 18
	left_panel.offset_right = 222
	left_panel.offset_top = 18
	# 190 → 240：季节行从一行 Label 变成「指针表盘 + 两行文字」，行高多出约 34px；
	# 再留一点余量给「本局天赋」最多 3 条词条的情况。
	left_panel.offset_bottom = 240
	_panel_style(left_panel, Color(0.20, 0.14, 0.09, 0.60))
	canvas.add_child(left_panel)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	left_panel.add_child(lv)

	var title := _make_label("湿地守护站", 20, VisualTheme.GOLD)
	lv.add_child(title)

	turn_label = _make_label("第 1 / 16 回合", 17, Color(1, 1, 1))
	lv.add_child(turn_label)
	# 季节行 = [指针表盘] + [第 X 年 · 春] / [季节旁白]
	var season_row := HBoxContainer.new()
	season_row.add_theme_constant_override("separation", 6)
	season_dial = SeasonDial.new()
	season_dial.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	season_row.add_child(season_dial)
	var season_text := VBoxContainer.new()
	season_text.add_theme_constant_override("separation", 2)
	season_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	season_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	season_label = _make_label("第 1 年 · 春", 14, Color(0.82, 0.86, 0.9))
	season_text.add_child(season_label)
	season_tagline = _make_label("", 12, Color(0.68, 0.78, 0.72))
	season_tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	season_text.add_child(season_tagline)
	season_row.add_child(season_text)
	lv.add_child(season_row)

	var sep1 := HSeparator.new()
	lv.add_child(sep1)

	var spent_row := HBoxContainer.new()
	spent_row.add_theme_constant_override("separation", 6)
	spent_row.add_child(_make_icon(_icon_grid_for("coin"), Color(0.72, 0.62, 0.50), 14))
	spent_label = _make_label("已消耗：0 万", 12, Color(0.82, 0.86, 0.9))
	spent_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spent_row.add_child(spent_label)
	lv.add_child(spent_row)

	var funds_row := HBoxContainer.new()
	funds_row.add_theme_constant_override("separation", 6)
	funds_row.add_child(_make_icon(_icon_grid_for("coin"), Color(0.95, 0.78, 0.25), 18))
	# ⚠ 必须写 24：_snap_px() 只认 12 的倍数，写 17 / 18 都会被吸附回 12px，
	#   改完看不出一丁点变大（原来的 17 就是这么被吃掉的）。
	funds_label = _make_label("80 万", 24, Color(1, 0.95, 0.6))
	funds_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	funds_row.add_child(funds_label)
	lv.add_child(funds_row)

	var research_row := HBoxContainer.new()
	research_row.add_theme_constant_override("separation", 6)
	research_row.add_child(_make_icon(_icon_grid_for("research"), Color(0.82, 0.9, 1), 14))
	research_label = _make_label("科研点：0", 14, Color(0.82, 0.9, 1))
	research_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	research_row.add_child(research_label)
	lv.add_child(research_row)

	# --- 本局天赋：常驻在资金栏最下面 ---
	# 每局开局随机 0~3 条（见 talents.gd roll_for_run），这里只做展示；
	# 显示口径与开局弹窗一致：词条名 + 效果，右边对齐（和上面几行同样的排版习惯）。
	lv.add_child(HSeparator.new())
	lv.add_child(_make_label("本局天赋", 13, Color(0.9, 0.86, 0.72)))
	talents_row = VBoxContainer.new()
	talents_row.add_theme_constant_override("separation", 3)
	lv.add_child(talents_row)
	_refresh_run_talents()

	# --- 右侧：六项指标（收窄为竖条）---
	right_panel = PanelContainer.new()
	right_panel.anchor_left = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_bottom = 0.0
	right_panel.offset_left = -210
	right_panel.offset_right = -18
	right_panel.offset_top = 18
	right_panel.offset_bottom = 266
	_panel_style(right_panel, Color(0.20, 0.14, 0.09, 0.60))
	canvas.add_child(right_panel)

	# ★ 在这里就把两块侧栏的「原位」登记好。
	#   _slide_main_ui() 复位靠的是 _ui_slide_origin，而它是**惰性捕获**的
	#   （if not _ui_slide_origin.has(c) 才记）。若玩家恰好在侧栏滑入/滑出的
	#   0.35s tween 途中第一次打开牌库，捕获到的就是半路的中间值 ——
	#   而且**一旦记错就永久错**，之后每次开合牌库都会把面板复位到那个错位置。
	#   滑动行程有 200+ px，点到 tween 中段能错出上百像素。
	#   搭建时的这两个 offset 就是设计好的常驻位置，是唯一可靠的「原位」来源。
	#   （只登记这两块：_slide_side_panels() 也在改它们的 offset，是冲突的来源；
	#     其余控件没有第二个函数去动，惰性捕获不会出问题。）
	_ui_slide_origin[left_panel] = [left_panel.offset_left, left_panel.offset_top,
			left_panel.offset_right, left_panel.offset_bottom]
	_ui_slide_origin[right_panel] = [right_panel.offset_left, right_panel.offset_top,
			right_panel.offset_right, right_panel.offset_bottom]

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right_panel.add_child(rv)
	var r_title := _make_label("生态监测", 24, VisualTheme.MINT)
	rv.add_child(r_title)
	for metric in GameState.METRIC_NAMES:
		rv.add_child(_make_metric_row(metric))

	# --- 顶部事件横幅（单行、居中、不遮挡沙盘）---
	event_label = _make_label("暂无", 13, Color(0.95, 0.95, 0.92))
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.clip_text = true
	event_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	event_label.anchor_left = 0.0
	event_label.anchor_top = 0.0
	event_label.anchor_right = 1.0
	event_label.offset_left = 240
	event_label.offset_right = -230
	event_label.offset_top = 25
	event_label.offset_bottom = 53
	event_label.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.06, 0.8))
	event_label.add_theme_constant_override("outline_size", 5)
	canvas.add_child(event_label)

	# --- 底部中间：手牌（无背景框，卡牌直接浮在沙盘上）---
	hand_panel = PanelContainer.new()
	hand_panel.anchor_left = 0.5
	hand_panel.anchor_top = 1.0
	hand_panel.anchor_right = 0.5
	hand_panel.anchor_bottom = 1.0
	hand_panel.offset_left = -330
	hand_panel.offset_right = 330
	hand_panel.offset_top = -290
	hand_panel.offset_bottom = -4
	# 透明无边框：手牌区域不遮挡沙盘
	var empty_sb := StyleBoxEmpty.new()
	hand_panel.add_theme_stylebox_override("panel", empty_sb)
	hand_panel.visible = false
	canvas.add_child(hand_panel)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	hand_panel.add_child(hv)

	# 牌区（扇形手牌，手动定位，无背景）
	card_box = Control.new()
	card_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_box.custom_minimum_size = Vector2(0, 200)
	card_box.mouse_filter = Control.MOUSE_FILTER_PASS
	card_box.resized.connect(_on_card_box_resized)
	hv.add_child(card_box)

	# 右下角：行动次数提醒（缩短）+ 结束回合按钮（沙盘素材之外的空白角落）
	bottom_right = VBoxContainer.new()
	bottom_right.anchor_left = 1.0
	bottom_right.anchor_top = 1.0
	bottom_right.anchor_right = 1.0
	bottom_right.anchor_bottom = 1.0
	bottom_right.offset_left = -210
	bottom_right.offset_right = -18
	# 高度要放得下 6 项（已选 / 行动提示 / 排序按钮 / 紧急调度 / 刷新手牌 / 结束回合）。
	# ⚠ 容器装不下时 Godot 会保 offset_top 而向下长，底部按钮会被顶出屏幕。
	bottom_right.offset_top = -276
	bottom_right.offset_bottom = -14
	bottom_right.add_theme_constant_override("separation", 4)
	bottom_right.visible = false
	canvas.add_child(bottom_right)

	selected_label = _make_label("已选：0/3", 14, Color(1, 0.9, 0.5))
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_label.custom_minimum_size.y = 30
	selected_label.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.06, 0.8))
	selected_label.add_theme_constant_override("outline_size", 4)
	bottom_right.add_child(selected_label)

	# 文案不写死：_build_ui 在 _ready 里就跑完了，那时玩家还没选难度。
	# 实际文字由 _update_hud() 按 GameState.action_slots() 填。
	action_hint = _make_label("", 12, Color(0.92, 0.94, 0.96))
	action_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.06, 0.8))
	action_hint.add_theme_constant_override("outline_size", 4)
	bottom_right.add_child(action_hint)

	# 出牌阶段的排序按钮：与牌库那个共用 _deck_sort_by_category 和同一套冷却，
	# 所以两边永远同步 —— 在牌库切过再回来，手牌也是同一套规则，
	# 新一局发牌同样按它排（见 _build_hand_panel）。
	hand_sort_btn = _make_button("按类别排序", _toggle_hand_sort, 14)
	hand_sort_btn.custom_minimum_size = Vector2(166, 40)
	bottom_right.add_child(hand_sort_btn)

	# 两个「花钱换牌」的容错阀（都在结束回合之上）：
	#   紧急调度 = 花 40 万从当季池点名一张牌，不占行动位，回合末与手牌一起结算
	#   刷新手牌 = 花 5 万把整手重抽一遍，每回合限一次
	dispatch_btn = _make_button("紧急调度 · 40 万", _open_dispatch_panel, 14)
	dispatch_btn.custom_minimum_size = Vector2(166, 40)
	bottom_right.add_child(dispatch_btn)

	refresh_btn = _make_button("刷新手牌 · 5 万", _on_refresh_hand, 14)
	refresh_btn.custom_minimum_size = Vector2(166, 40)
	bottom_right.add_child(refresh_btn)

	end_turn_btn = _make_button("执行行动 ▶", _finish_turn, 20)
	VisualTheme.style_button(end_turn_btn, false, true)
	end_turn_btn.custom_minimum_size = Vector2(166, 48)
	bottom_right.add_child(end_turn_btn)

	# 左下角：出牌档位拉杆（向左拨 = 基础投入，中间 = 有效投入，向右拨 = 深度投入）
	_build_tier_lever(canvas)

	# --- 弹窗（顶层）---
	popup_root = Control.new()
	popup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_root.visible = false
	canvas.add_child(popup_root)

	dim = ColorRect.new()
	dim.color = Color(0.015, 0.055, 0.065, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_root.add_child(dim)

	popup_center = CenterContainer.new()
	popup_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_center.mouse_filter = Control.MOUSE_FILTER_PASS
	popup_root.add_child(popup_center)

	popup_panel = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(600, 0)
	_panel_style(popup_panel, Color(0.24, 0.17, 0.11, 0.55))
	popup_center.add_child(popup_panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	popup_panel.add_child(pv)
	popup_title = _make_label("", 22, Color(1, 0.9, 0.55))
	pv.add_child(popup_title)
	popup_body = RichTextLabel.new()
	popup_body.bbcode_enabled = true
	popup_body.meta_clicked.connect(_on_knowledge_source_clicked)
	popup_body.fit_content = true
	popup_body.custom_minimum_size = Vector2(540, 0)
	popup_body.add_theme_font_size_override("normal_font_size", _snap_px(16))
	popup_body.add_theme_color_override("default_color", Color(0.95, 0.95, 0.95))
	pv.add_child(popup_body)
	popup_button = _make_button("继续", _on_popup_button, 18)
	popup_button.custom_minimum_size = Vector2(0, 44)
	pv.add_child(popup_button)

	# 主菜单（独立 CanvasLayer，盖在 HUD 与沙盘之上）
	_build_menu()
	_build_pause_menu()
	_build_crisis_alert()
	_build_warn_history(canvas)
	_build_deck_ui(canvas)
	_build_deck_viewer()
	_build_knowledge_viewer()
	_build_metric_tip(canvas)   # 最后加：小窗要画在 HUD 所有面板之上
	_build_score_layer()        # 算分动画层：独立 CanvasLayer，盖在 HUD 之上
	_build_achievement_popup()  # 成就解锁提示层：盖在最上面
	sandpan_view = preload("res://scripts/sandpan_view.gd").new()
	add_child(sandpan_view)
	sandpan_view.configure(self, canvas)


## 算分动画层。独立 CanvasLayer(layer=7)：盖在 UICanvas(0) 之上，
## 又低于牌库查看器(8) / 主菜单(10) / 暂停(20) / 开场(30)，遮挡关系正确。
## 该层 transform 是单位阵、与主 canvas 同坐标系，所以可以直接用
## metric_bars[...]["row"].get_global_rect() 定位小票，不必做坐标换算。
func _build_score_layer() -> void:
	score_layer = CanvasLayer.new()
	score_layer.name = "ScoreLayer"
	score_layer.layer = 7
	score_layer.visible = false
	add_child(score_layer)

	score_stage = Control.new()
	score_stage.name = "Stage"
	score_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	score_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_layer.add_child(score_stage)

	score_floats = Control.new()
	score_floats.name = "Floats"
	score_floats.set_anchors_preset(Control.PRESET_FULL_RECT)
	score_floats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_layer.add_child(score_floats)

	# 算分小票：整场动画复用同一个节点，逐项滑到当前指标行的左侧
	score_receipt = PanelContainer.new()
	score_receipt.name = "Receipt"
	score_receipt.visible = false
	score_receipt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_style(score_receipt, Color(0.14, 0.10, 0.07, 0.94))
	score_layer.add_child(score_receipt)
	score_receipt_box = VBoxContainer.new()
	score_receipt_box.add_theme_constant_override("separation", 2)
	score_receipt.add_child(score_receipt_box)


# ==================== 主菜单 ====================
func _build_menu() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MenuLayer"
	layer.layer = 10  # 确保在 HUD 之上
	add_child(layer)

	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(menu_root)

	# 很淡的压暗：镜头拉远后沙盘全景仍然看得见，开始页不遮景
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	var shade := Shader.new()
	bg.name = "MenuShade"
	shade.code = "shader_type canvas_item; void fragment(){ float a = 0.78 * (1.0 - smoothstep(0.12, 0.40, UV.x)); COLOR = vec4(0.16, 0.21, 0.25, a); }"
	var shade_mat := ShaderMaterial.new()
	shade_mat.shader = shade
	bg.material = shade_mat
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(bg)

	# --- 左上角：标题 ---
	var title := _make_label("保卫鄱阳湖", 48, VisualTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 0.0
	title.offset_left = 64.0
	title.offset_right = 620.0
	title.offset_top = 64.0
	title.offset_bottom = 140.0
	title.add_theme_color_override("font_shadow_color", VisualTheme.INK)
	title.add_theme_constant_override("shadow_offset_y", 5)
	menu_root.add_child(title)
	var eyebrow := _make_label("P O Y A N G   /   W E T L A N D S", 12, VisualTheme.MINT)
	eyebrow.position = Vector2(68, 44)
	menu_root.add_child(eyebrow)
	var subtitle := _make_label("一湖清水，万物共生。", 24, VisualTheme.PAPER)
	subtitle.position = Vector2(68, 150)
	menu_root.add_child(subtitle)
	var description := _make_label("生态保护 · 卡牌策略 · 四季之旅", 12, VisualTheme.MINT)
	description.position = Vector2(68, 194)
	menu_root.add_child(description)
	var footer := _make_label("守护每一片芦苇，等待每一次归来。", 12, VisualTheme.PAPER)
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = 68
	footer.offset_top = -40
	footer.offset_bottom = -20
	menu_root.add_child(footer)

	# --- 居中容器：留给技能树（天赋树）面板 ---
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)

	# --- 左下角：选项列（逐级展开：主选项 → 难度 → 种子）---
	menu_col = VBoxContainer.new()
	menu_col.anchor_left = 0.0
	menu_col.anchor_right = 0.0
	menu_col.anchor_top = 0.0
	menu_col.anchor_bottom = 1.0
	menu_col.offset_left = 68.0
	menu_col.offset_right = 388.0
	menu_col.offset_top = 270.0
	menu_col.offset_bottom = -82.0
	menu_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	menu_col.add_theme_constant_override("separation", 10)
	menu_root.add_child(menu_col)

	# 一级：新游戏 / 继续游戏
	menu_start_btn = _make_button("开启守护之旅  ▶", _on_title_start, 26)
	VisualTheme.style_button(menu_start_btn, false, true)
	menu_start_btn.custom_minimum_size = Vector2(0, 54)
	menu_col.add_child(menu_start_btn)

	menu_continue_btn = _make_button("继续游戏", _on_continue_pressed, 22)
	menu_continue_btn.custom_minimum_size = Vector2(0, 50)
	menu_continue_btn.visible = false
	menu_col.add_child(menu_continue_btn)

	# 二级：难度（点「开始」后出现在它正下方）
	# 四个按钮共用 _on_difficulty_pick，用 bind 把难度值传进去 ——
	# 之前是四个近乎一样的处理函数，加噩梦档时就得再抄一份，容易漂移。
	menu_easy_btn = _make_button("简单模式", _on_difficulty_pick.bind(GameState.Difficulty.EASY), 20)
	menu_easy_btn.custom_minimum_size = Vector2(0, 46)
	menu_easy_btn.visible = false
	menu_col.add_child(menu_easy_btn)

	menu_normal_btn = _make_button("普通模式", _on_difficulty_pick.bind(GameState.Difficulty.NORMAL), 20)
	menu_normal_btn.custom_minimum_size = Vector2(0, 46)
	menu_normal_btn.visible = false
	menu_col.add_child(menu_normal_btn)

	menu_hard_btn = _make_button("困难模式", _on_difficulty_pick.bind(GameState.Difficulty.HARD), 20)
	menu_hard_btn.custom_minimum_size = Vector2(0, 46)
	menu_hard_btn.visible = false
	menu_col.add_child(menu_hard_btn)

	# 噩梦档：照搬早期困难档的参数（开局就离死 3~5 点），几乎必死。
	# 按钮用暗红 danger 样式，与另外三档在视觉上分开。
	menu_nightmare_btn = _make_button("噩梦模式", _on_difficulty_pick.bind(GameState.Difficulty.NIGHTMARE), 20, true)
	menu_nightmare_btn.custom_minimum_size = Vector2(0, 46)
	menu_nightmare_btn.visible = false
	menu_col.add_child(menu_nightmare_btn)

	# 三级：填写种子
	menu_mode_label = _make_label("模式：简单", 14, Color(0.82, 0.86, 0.9))
	menu_mode_label.visible = false
	menu_col.add_child(menu_mode_label)

	menu_seed_label = _make_label("留空或 0 则随机", 14, Color(0.9, 0.92, 0.94))
	menu_seed_label.visible = false
	menu_col.add_child(menu_seed_label)

	seed_input = LineEdit.new()
	seed_input.add_theme_font_size_override("font_size", _snap_px(18))
	seed_input.custom_minimum_size = Vector2(0, 42)
	seed_input.placeholder_text = "种子"
	seed_input.add_theme_color_override("font_placeholder_color", Color(0.85, 0.88, 0.90, 0.35))
	seed_input.visible = false
	menu_col.add_child(seed_input)

	menu_hint = _make_label("", 12, Color(1, 0.6, 0.5))
	menu_col.add_child(menu_hint)

	menu_seed_start_btn = _make_button("出发，鄱阳湖  ▶", _on_start_pressed, 22)
	VisualTheme.style_button(menu_seed_start_btn, false, true)
	menu_seed_start_btn.custom_minimum_size = Vector2(0, 50)
	menu_seed_start_btn.visible = false
	menu_col.add_child(menu_seed_start_btn)

	# 返回上一层（难度 / 种子环节可见）
	menu_back_btn = _make_button("返回", _on_menu_back, 16)
	menu_back_btn.custom_minimum_size = Vector2(0, 38)
	menu_back_btn.visible = false
	menu_col.add_child(menu_back_btn)

	# 主行动在上，收藏与设置以两列排列，退出单独留在底部。
	menu_separator = HSeparator.new()
	menu_separator.custom_minimum_size.y = 10
	menu_col.add_child(menu_separator)
	menu_utilities = GridContainer.new()
	menu_utilities.columns = 2
	menu_utilities.add_theme_constant_override("h_separation", 10)
	menu_utilities.add_theme_constant_override("v_separation", 10)
	menu_col.add_child(menu_utilities)
	if TALENT_TREE_ENABLED:
		menu_talent_btn = _make_button("天赋树", _show_talent_panel, 18)
		menu_talent_btn.custom_minimum_size = Vector2(0, 44)
		menu_utilities.add_child(menu_talent_btn)

	menu_settings_btn = _make_button("设置", _show_settings_panel, 18)
	menu_settings_btn.custom_minimum_size = Vector2(0, 44)
	menu_utilities.add_child(menu_settings_btn)

	# 「更新日志」「制作人员」已移入设置面板（见下面的 svb），不在这里建 ——
	# 主菜单列少两个按钮，底部才不会溢出屏幕。
	menu_achievements_btn = _make_button("成就", _show_achievements_panel, 18)
	menu_achievements_btn.custom_minimum_size = Vector2(0, 44)
	# 入口图标：像素小金牌。**不挂在 Button.icon 上** —— Button 会把图标宽度算进
	# 「图标+文字」整体居中，结果「成就」两个字相对「技能树/设置/退出」右移约 14px
	# （2026-09-28 截图实测）。改成在按钮内部左侧贴一个独立图标（不吃布局），
	# 文字就与其它按钮完全同心。
	var ach_icon := _make_icon(Achievements.MEDAL_GRID, ACH_GOLD, 22)
	ach_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ach_icon.anchor_left = 0.0
	ach_icon.anchor_top = 0.5
	ach_icon.anchor_right = 0.0
	ach_icon.anchor_bottom = 0.5
	ach_icon.offset_left = 8
	ach_icon.offset_right = 30
	ach_icon.offset_top = -11
	ach_icon.offset_bottom = 11
	menu_achievements_btn.add_child(ach_icon)
	menu_utilities.add_child(menu_achievements_btn)

	# 「知识卡」：与成就同样在按钮内左侧贴一个独立图标（不挂 Button.icon，
	# 避免图标宽度被算进「图标+文字」的整体居中而让文字偏移）。
	menu_knowledge_btn = _make_button("知识卡", _show_knowledge_panel, 18)
	menu_knowledge_btn.custom_minimum_size = Vector2(0, 44)
	var kn_icon := _make_icon(KNOWLEDGE_ICON_GRID, Color(0.55, 0.82, 0.95), 22)
	kn_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kn_icon.anchor_left = 0.0
	kn_icon.anchor_top = 0.5
	kn_icon.anchor_right = 0.0
	kn_icon.anchor_bottom = 0.5
	kn_icon.offset_left = 8
	kn_icon.offset_right = 30
	kn_icon.offset_top = -11
	kn_icon.offset_bottom = 11
	menu_knowledge_btn.add_child(kn_icon)
	menu_utilities.add_child(menu_knowledge_btn)
	menu_utilities.move_child(menu_knowledge_btn, 0)
	menu_utilities.move_child(menu_achievements_btn, 1)
	for utility in menu_utilities.get_children():
		utility.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	menu_quit_btn = _make_button("退出", _on_menu_quit, 18)
	menu_quit_btn.custom_minimum_size = Vector2(0, 40)
	menu_col.add_child(menu_quit_btn)

	# --- 第 4 页：天赋树 ---
	menu_talent_panel = TalentTreePanel.new()
	menu_talent_panel.visible = false
	menu_talent_panel.back_requested.connect(_on_talent_back)
	center.add_child(menu_talent_panel)

	# --- 设置面板 ---
	menu_settings_panel = PanelContainer.new()
	menu_settings_panel.custom_minimum_size = Vector2(400, 0)
	_panel_style(menu_settings_panel, Color(0.20, 0.14, 0.09, 0.97))
	menu_settings_panel.visible = false
	center.add_child(menu_settings_panel)

	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 12)
	menu_settings_panel.add_child(svb)

	var s_title := _make_label("设置", 24, Color(1, 0.9, 0.55))
	s_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	svb.add_child(s_title)

	var s_sep := HSeparator.new()
	svb.add_child(s_sep)

	# 音量调节
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 8)
	svb.add_child(vol_row)
	var vol_lbl := _make_label("音量", 16, Color(0.82, 0.86, 0.9))
	vol_row.add_child(vol_lbl)
	audio_volume_slider = HSlider.new()
	audio_volume_slider.min_value = 0
	audio_volume_slider.max_value = 100
	audio_volume_slider.step = 1
	audio_volume_slider.value = bgm_volume * 100
	audio_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_volume_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(audio_volume_slider)
	audio_volume_label = _make_label("音量：%d%%" % int(bgm_volume * 100), 14, Color(1, 0.95, 0.6))
	vol_row.add_child(audio_volume_label)

	# 切换 BGM
	bgm_switch_btn = _make_button("", _on_switch_bgm, 16)
	bgm_switch_btn.custom_minimum_size = Vector2(0, 44)
	svb.add_child(bgm_switch_btn)
	_update_bgm_btn()

	# 结算动画速度：手感因人而异，做成滑块而不是写死在代码里
	var spd_row := HBoxContainer.new()
	spd_row.add_theme_constant_override("separation", 8)
	svb.add_child(spd_row)
	spd_row.add_child(_make_label("结算速度", 16, Color(0.82, 0.86, 0.9)))
	score_speed_slider = HSlider.new()
	score_speed_slider.min_value = SCORE_SPEED_MIN * 100.0
	score_speed_slider.max_value = SCORE_SPEED_MAX * 100.0
	score_speed_slider.step = 5
	score_speed_slider.value = score_speed * 100.0
	score_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_speed_slider.tooltip_text = "结算动画的快慢。100% 为默认；调小则更慢、看得更清楚，调大则更快。下一回合结算起生效。"
	score_speed_slider.value_changed.connect(_on_score_speed_changed)
	spd_row.add_child(score_speed_slider)
	score_speed_label = _make_label("", 14, Color(1, 0.95, 0.6))
	spd_row.add_child(score_speed_label)
	_sync_score_speed_ui()

	var replay_btn := _make_button("重新观看开场动画", _on_replay_intro, 20)
	replay_btn.custom_minimum_size = Vector2(0, 52)
	svb.add_child(replay_btn)

	# 更新日志 / 制作人员：从主菜单挪进设置里
	menu_changelog_btn = _make_button("更新日志", _show_changelog_panel, 18)
	menu_changelog_btn.custom_minimum_size = Vector2(0, 44)
	svb.add_child(menu_changelog_btn)

	menu_credits_btn = _make_button("制作人员", _show_credits_panel, 18)
	menu_credits_btn.custom_minimum_size = Vector2(0, 44)
	svb.add_child(menu_credits_btn)

	# --- 危险操作：清空存档（红色 + 二次确认）---
	svb.add_child(HSeparator.new())
	clear_status_label = _make_label("", 13, Color(0.66, 0.88, 0.68))
	clear_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	svb.add_child(clear_status_label)
	menu_clear_save_btn = _make_button("清空当前存档", _show_clear_confirm, 18, true)
	menu_clear_save_btn.custom_minimum_size = Vector2(0, 44)
	svb.add_child(menu_clear_save_btn)

	var s_back := _make_button("返回", _on_settings_back, 16)
	s_back.custom_minimum_size = Vector2(0, 40)
	svb.add_child(s_back)

	# --- 清空存档的二次确认框 ---
	menu_clear_confirm_panel = PanelContainer.new()
	menu_clear_confirm_panel.custom_minimum_size = Vector2(440, 0)
	_panel_style(menu_clear_confirm_panel, Color(0.26, 0.12, 0.10, 0.98))
	menu_clear_confirm_panel.visible = false
	center.add_child(menu_clear_confirm_panel)

	# 变量名统一加 cl_ 前缀：_build_menu 是个超长函数，
	# 制作人员面板已经占用了 cvb / c_title 这些短名字，别撞
	var cl_vb := VBoxContainer.new()
	cl_vb.add_theme_constant_override("separation", 12)
	menu_clear_confirm_panel.add_child(cl_vb)

	var cl_title := _make_label("确认清空存档？", 22, Color(1.0, 0.72, 0.66))
	cl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl_vb.add_child(cl_title)

	var cl_body := _make_label(
			"将永久删除：\n· 当前对局进度（继续游戏）\n· 全部灵感、研修分配与噩梦满树奖励\n· 旧天赋进度备份\n· 全部成就\n\n此操作不可撤销。",
			14, Color(0.92, 0.88, 0.86))
	cl_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl_body.custom_minimum_size = Vector2(320, 0)
	cl_vb.add_child(cl_body)

	var cl_ok := _make_button("确认清空", _on_clear_confirm_ok, 18, true)
	cl_ok.custom_minimum_size = Vector2(0, 46)
	cl_vb.add_child(cl_ok)

	var cl_cancel := _make_button("取消", _on_clear_confirm_cancel, 18)
	cl_cancel.custom_minimum_size = Vector2(0, 44)
	cl_vb.add_child(cl_cancel)

	# --- 制作人员面板 ---
	menu_credits_panel = PanelContainer.new()
	menu_credits_panel.custom_minimum_size = Vector2(420, 0)
	_panel_style(menu_credits_panel, Color(0.20, 0.14, 0.09, 0.97))
	menu_credits_panel.visible = false
	center.add_child(menu_credits_panel)

	var cvb := VBoxContainer.new()
	cvb.add_theme_constant_override("separation", 10)
	menu_credits_panel.add_child(cvb)

	var c_title := _make_label("制作人员", 24, Color(1, 0.9, 0.55))
	c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cvb.add_child(c_title)

	var c_sep := HSeparator.new()
	cvb.add_child(c_sep)

	var credits := [
		["策划", "QQQi_ZZZhe"],
		["主程 / 配乐", "Kanshin"],
		["美术", "C3L1K1N4"],
		["林学专家", "Oliveira"],
	]
	for e in credits:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		cvb.add_child(row)
		var role_l := _make_label(str(e[0]) + "：", 16, Color(0.72, 0.76, 0.80))
		row.add_child(role_l)
		var name_l := _make_label(str(e[1]), 16, Color(0.96, 0.94, 0.88))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(name_l)

	var c_back := _make_button("返回", _on_credits_back, 16)
	c_back.custom_minimum_size = Vector2(0, 40)
	cvb.add_child(c_back)

	# --- 更新日志面板 ---
	menu_changelog_panel = PanelContainer.new()
	menu_changelog_panel.custom_minimum_size = Vector2(580, 0)
	_panel_style(menu_changelog_panel, Color(0.20, 0.14, 0.09, 0.97))
	menu_changelog_panel.visible = false
	center.add_child(menu_changelog_panel)

	var gvb := VBoxContainer.new()
	gvb.add_theme_constant_override("separation", 10)
	menu_changelog_panel.add_child(gvb)

	var g_title := _make_label("更新日志", 24, Color(1, 0.9, 0.55))
	g_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gvb.add_child(g_title)

	var g_sub := _make_label("当前版本 %s" % Changelog.CURRENT, 14, Color(0.72, 0.76, 0.80))
	g_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gvb.add_child(g_sub)

	var g_sep := HSeparator.new()
	gvb.add_child(g_sep)

	# 必须用 ScrollContainer：日志只会越写越长，老弹窗系统不滚动会顶穿窗口
	var g_scroll := ScrollContainer.new()
	g_scroll.custom_minimum_size = Vector2(540, 360)
	g_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gvb.add_child(g_scroll)

	var g_col := VBoxContainer.new()
	g_col.add_theme_constant_override("separation", 12)
	g_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g_scroll.add_child(g_col)

	_build_changelog_rows(g_col)

	var g_back := _make_button("返回", _on_changelog_back, 16)
	g_back.custom_minimum_size = Vector2(0, 40)
	gvb.add_child(g_back)

	# --- 成就面板 ---
	menu_achievements_panel = PanelContainer.new()
	menu_achievements_panel.custom_minimum_size = Vector2(580, 0)
	_panel_style(menu_achievements_panel, Color(0.20, 0.14, 0.09, 0.97))
	menu_achievements_panel.visible = false
	center.add_child(menu_achievements_panel)

	var avb := VBoxContainer.new()
	avb.add_theme_constant_override("separation", 10)
	menu_achievements_panel.add_child(avb)

	var a_title := _make_label("成就", 24, Color(1, 0.9, 0.55))
	a_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avb.add_child(a_title)

	ach_count_label = _make_label("", 14, Color(0.72, 0.76, 0.80))
	ach_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avb.add_child(ach_count_label)

	avb.add_child(HSeparator.new())

	var a_scroll := ScrollContainer.new()
	a_scroll.custom_minimum_size = Vector2(540, 360)
	a_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	avb.add_child(a_scroll)

	ach_rows_col = VBoxContainer.new()
	ach_rows_col.add_theme_constant_override("separation", 14)
	ach_rows_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_scroll.add_child(ach_rows_col)

	var a_back := _make_button("返回", _on_achievements_back, 16)
	a_back.custom_minimum_size = Vector2(0, 40)
	avb.add_child(a_back)


## 把 Changelog.RELEASES 渲染进面板 —— 以后加版本只改 scripts/changelog.gd，这里不用动
func _build_changelog_rows(col: VBoxContainer) -> void:
	for rel in Changelog.RELEASES:
		var v_head := _make_label("v%s · %s" % [str(rel["version"]), str(rel["title"])], 19, Color(1, 0.88, 0.55))
		v_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 标题写长了要能折行，不然会被裁
		v_head.custom_minimum_size = Vector2(520, 0)
		col.add_child(v_head)
		col.add_child(_make_label(str(rel["date"]), 13, Color(0.72, 0.76, 0.80)))
		for sec in rel["sections"]:
			col.add_child(_make_label("◆ " + str(sec["head"]), 16, Color(0.62, 0.82, 1.0)))
			for item in sec["items"]:
				var body := RichTextLabel.new()
				# 公告正文里作者会写 **重点**（markdown 习惯）。以前 bbcode 是关的，
				# 于是星号原样露在页面上（0.0.5 那几条一直是这样）。
				# 现在开 bbcode + 把 **x** 转成 [b]x[/b]，顺带把其余方括号转义，
				# 免得正文里出现 [某字] 被当成标签吃掉。
				body.bbcode_enabled = true
				body.fit_content = true
				body.scroll_active = false
				body.custom_minimum_size = Vector2(520, 0)
				body.add_theme_font_size_override("normal_font_size", _snap_px(14))
				body.add_theme_color_override("default_color", Color(0.92, 0.90, 0.86))
				body.text = "· " + _md_emphasis(str(item))
				col.add_child(body)


## 把公告里的 **重点** 转成 BBCode 加粗。
## ⚠ 开了 bbcode 之后，正文里其余的方括号必须转义成 [lb]，否则会被当成标签吃掉 ——
##   例如「[已解决]」这种写法会静默消失。所以先转义、再插 [b]。
func _md_emphasis(s: String) -> String:
	var parts := s.split("**")
	var out := ""
	for i in parts.size():
		var chunk: String = str(parts[i]).replace("[", "[lb]")
		if i % 2 == 1:
			out += "[b]" + chunk + "[/b]"
		else:
			out += chunk
	return out


# ==================== 成就 ====================

func _show_achievements_panel() -> void:
	menu_col.visible = false
	menu_talent_panel.visible = false
	menu_settings_panel.visible = false
	menu_credits_panel.visible = false
	menu_changelog_panel.visible = false
	_build_achievement_rows()   # 每次打开重建：解锁状态可能刚变过，不能只在建菜单时铺一次
	menu_achievements_panel.visible = true


func _on_achievements_back() -> void:
	menu_achievements_panel.visible = false
	menu_col.visible = true
	_menu_state(0)


## 重建成就列表。解锁的点亮成金牌，未解锁的用灰牌。
func _build_achievement_rows() -> void:
	if ach_rows_col == null:
		return
	for c in ach_rows_col.get_children():
		ach_rows_col.remove_child(c)
		c.queue_free()
	var visible_achievements := Achievements.visible_list()
	ach_count_label.text = "已解锁 %d / %d" % [Achievements.unlocked_count(), visible_achievements.size()]
	for a in visible_achievements:
		var got: bool = Achievements.is_unlocked(str(a["id"]))
		var row := HBoxContainer.new()
		row.set_meta("achievement_id", str(a["id"]))
		row.add_theme_constant_override("separation", 14)

		var icon := _make_icon(str(a["icon"]), ACH_GOLD if got else ACH_LOCKED, 44)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_make_label(str(a["name"]), 18,
				Color(1, 0.88, 0.55) if got else Color(0.60, 0.60, 0.64)))
		var ds := _make_label(str(a["desc"]), 13,
				Color(0.80, 0.78, 0.74) if got else Color(0.52, 0.52, 0.56))
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.custom_minimum_size = Vector2(430, 0)
		col.add_child(ds)
		row.add_child(col)
		ach_rows_col.add_child(row)


## 成就解锁提示层。layer=12：盖在算分动画(7)与结算弹窗之上，
## 又低于暂停(20)/开场(30) —— 「Steam 式」提示本来就该压在游戏画面上。
func _build_achievement_popup() -> void:
	ach_layer = CanvasLayer.new()
	ach_layer.name = "AchievementLayer"
	ach_layer.layer = 12
	ach_layer.visible = false
	add_child(ach_layer)

	ach_popup = PanelContainer.new()
	ach_popup.name = "AchPopup"
	ach_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 不挡操作
	_panel_style(ach_popup, Color(0.12, 0.10, 0.08, 0.96))
	ach_layer.add_child(ach_popup)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	ach_popup.add_child(hb)

	ach_popup_icon = _make_icon(Achievements.MEDAL_GRID, ACH_GOLD, 44)
	ach_popup_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ach_popup_icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	col.add_child(_make_label("成就已解锁", 11, Color(0.72, 0.76, 0.80)))
	ach_popup_name = _make_label("", 18, Color(1, 0.88, 0.55))
	col.add_child(ach_popup_name)
	# 触发条件用小字写在下面
	ach_popup_desc = _make_label("", 12, Color(0.80, 0.78, 0.74))
	ach_popup_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ach_popup_desc.custom_minimum_size = Vector2(206, 0)
	col.add_child(ach_popup_desc)


## Achievements.achievement_unlocked 的接收端。一回合可能同时解锁多个，排队播。
func _on_achievement_unlocked(achievement_id: String) -> void:
	if menu_achievements_panel != null and menu_achievements_panel.visible:
		_build_achievement_rows()
	_ach_queue.append(achievement_id)
	if not _ach_showing:
		_drain_achievement_queue()


func _drain_achievement_queue() -> void:
	_ach_showing = true
	while not _ach_queue.is_empty():
		await _show_achievement_popup(str(_ach_queue.pop_front()))
	_ach_showing = false


## 弹一次成就提示：从屏幕右侧滑入 → 停住 → 滑出，全程约 5 秒。
## 位置取屏幕右侧偏下 —— 上方是生态指标面板与牌堆，别压上去。
func _show_achievement_popup(achievement_id: String) -> void:
	var a: Dictionary = Achievements.find(achievement_id)
	if a.is_empty() or ach_popup == null:
		return
	const SLIDE := 0.35
	const HOLD := 4.30        # 0.35 + 4.30 + 0.35 ≈ 5 秒

	ach_popup_icon.texture = _pixel_icon_sized(str(a["icon"]), ACH_GOLD, 44)
	ach_popup_name.text = str(a["name"])
	ach_popup_desc.text = str(a["desc"])

	ach_layer.visible = true
	ach_popup.visible = true
	# 先让它自己算出尺寸再定位：第一帧 size 还是 0，直接算会闪一下
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	var w: float = maxf(ach_popup.size.x, 280.0)
	var h: float = ach_popup.size.y
	var y: float = clampf(vp.y * 0.66 - h * 0.5, 6.0, vp.y - h - 6.0)
	var x_home: float = vp.x - w - 16.0
	var x_hidden: float = vp.x + 8.0
	ach_popup.position = Vector2(x_hidden, y)

	var tw := ach_popup.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ach_popup, "position:x", x_home, SLIDE)
	await get_tree().create_timer(SLIDE + HOLD).timeout
	# ⚠ 时序用 create_timer，不用 await tween.finished —— tween 被 kill 时该信号永不发出
	var tw2 := ach_popup.create_tween()
	tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw2.tween_property(ach_popup, "position:x", x_hidden, SLIDE)
	await get_tree().create_timer(SLIDE).timeout
	ach_popup.visible = false
	ach_layer.visible = false


## 成就「？！同花！？」：同一回合打出三张及以上同一类别的牌
## 调用点：_finish_turn 执行完所有牌之后。已解锁时 try_unlock 内部直接返回，
## 所以这里可以无脑调，不用自己判重。
func _check_flush_achievement(played: Array) -> void:
	var cnt: Dictionary = {}
	for i in played:
		var cat := _card_category(str(card_infos[i]["card_id"]))
		if cat == "":
			continue
		cnt[cat] = int(cnt.get(cat, 0)) + 1
	for cat in cnt:
		if int(cnt[cat]) >= 3:
			Achievements.try_unlock("flush")
			return


## 按 id 取卡牌数据字典（找不到返回空字典）
func _find_card_data(card_id: String) -> Dictionary:
	for c in GameState.ACTION_CARDS:
		if str(c["id"]) == card_id:
			return c
	return {}


## 卡牌的类别（ecology / social / manage）；找不到返回空串
func _card_category(card_id: String) -> String:
	return str(_find_card_data(card_id).get("category", ""))


# ==================== 开场像素 PPT（Undertale 风） ====================
func _is_first_play() -> bool:
	return not FileAccess.file_exists("user://intro_seen")


func _mark_intro_seen() -> void:
	var f := FileAccess.open("user://intro_seen", FileAccess.WRITE)
	if f != null:
		f.close()


## 多色像素画：palette 为 字符->颜色，其余视为透明
func _pixel_art(grid: String, palette: Dictionary) -> ImageTexture:
	var rows: Array = []
	for r in grid.split("\n"):
		var line: String = (r as String).strip_edges()
		if line != "":
			rows.append(line)
	var h := rows.size()
	var w := (rows[0] as String).length()   # 以首行为准，长行截断、短行补透明
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var line: String = rows[y]
		for x in w:
			var ch: String = line[x] if x < line.length() else " "
			img.set_pixel(x, y, palette.get(ch, Color(0, 0, 0, 0)))
	return ImageTexture.create_from_image(img)


func _build_intro() -> void:
	intro_layer = CanvasLayer.new()
	intro_layer.layer = 30
	add_child(intro_layer)
	intro_root = Control.new()
	intro_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_layer.add_child(intro_root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 80
	col.offset_right = -80
	col.offset_top = 30
	col.offset_bottom = -30
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.add_child(col)
	intro_col = col
	intro_image = TextureRect.new()
	intro_image.custom_minimum_size = Vector2(320, 192)
	intro_image.stretch_mode = TextureRect.STRETCH_SCALE
	intro_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intro_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	intro_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	intro_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(intro_image)
	intro_title = _make_label("", 30, Color(1, 0.9, 0.55))
	intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(intro_title)
	intro_body = _make_label("", 20, Color(0.92, 0.94, 0.95))
	intro_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_body.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	intro_body.add_theme_constant_override("outline_size", 3)
	col.add_child(intro_body)
	intro_hint = _make_label("回车 继续　·　ESC 跳过", 13, Color(0.55, 0.6, 0.65))
	intro_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(intro_hint)


func _show_intro() -> void:
	if intro_root == null:
		_build_intro()
	intro_slides = _make_intro_slides()
	intro_index = 0
	_intro_playing = true
	_intro_elapsed = 0.0
	_intro_advancing = false
	intro_layer.visible = true
	_render_intro_slide()


func _render_intro_slide() -> void:
	_intro_elapsed = 0.0
	var slide: Dictionary = intro_slides[intro_index]
	intro_image.texture = _pixel_art(slide["grid"], slide["palette"])
	intro_title.text = slide["title"]
	intro_body.text = slide["body"]
	# 淡入
	intro_col.modulate.a = 0.0
	var tw := intro_col.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(intro_col, "modulate:a", 1.0, 0.45)


func _advance_intro() -> void:
	if _intro_advancing:
		return
	_intro_advancing = true
	# 淡出，完成后再切下一张 / 结束
	var tw := intro_col.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(intro_col, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		_intro_advancing = false
		if not _intro_playing:
			return  # 淡出期间已被 ESC 跳过
		intro_index += 1
		if intro_index >= intro_slides.size():
			_finish_intro()
		else:
			_render_intro_slide())


func _finish_intro() -> void:
	_intro_playing = false
	_intro_advancing = false
	intro_layer.visible = false
	_mark_intro_seen()
	_show_menu()


func _make_intro_slides() -> Array:
	return [
		{
			"title": "鄱阳湖",
			"body": "中国第一大淡水湖，\n也是亚洲最重要的候鸟越冬地之一。",
			"palette": {
				"S": Color(0.55, 0.78, 0.92), "Y": Color(0.98, 0.85, 0.36),
				"B": Color(0.96, 0.96, 0.95), "W": Color(0.30, 0.62, 0.80),
				"w": Color(0.50, 0.76, 0.90), "D": Color(0.16, 0.42, 0.62),
				"G": Color(0.44, 0.72, 0.44), "g": Color(0.28, 0.54, 0.32),
				"r": Color(0.40, 0.55, 0.34),
			},
			"grid": """SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSYYYYYYSSS
SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSYYYYYYYYSS
SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSYYYYYYYYSS
SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSYYYYYYSSS
SSSSSSSSBSSSSSSSSSSSSBSSSSSSSSSSSSSSSSSS
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWwwwwwwWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWWwwWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
rGrGrGrGrGrGrGrGrGrGrGrGrGrGrGrGrGrGrGrG
rGrGrGrGrGrGrGrGrGrGrGrGrGrGrGrGrGrGrGrG
gggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggg""",
		},
		{
			"title": "危机逼近",
			"body": "围垦、污染、干旱……\n湖水缩减，候鸟与鱼类正失去家园。",
			"palette": {
				"K": Color(0.10, 0.12, 0.15), "R": Color(0.85, 0.25, 0.22),
				"E": Color(0.52, 0.40, 0.28), "e": Color(0.38, 0.28, 0.20),
				"W": Color(0.28, 0.48, 0.60),
			},
			"grid": """KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKRRRRRRRRRKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKRRRRRRRRRRRKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKRRRRRRRRRKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
EEEEEEEEeEEEEEEEEEEEEEEEEEEEEEEeEEEEEEEE
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
EEeEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEeEEEE
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEWWWWWWEEEEEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEWWWWWWEEEEEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEEWWWWEEEEEEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
EEEEEEeEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
eEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
eEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
eEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE""",
		},
		{
			"title": "你",
			"body": "你被任命为鄱阳湖\n新一任湖区管理员。",
			"palette": {
				"S": Color(0.55, 0.78, 0.92), "P": Color(0.92, 0.76, 0.62),
				"H": Color(0.25, 0.55, 0.30), "C": Color(0.30, 0.50, 0.70),
				"c": Color(0.22, 0.38, 0.55), "Y": Color(0.95, 0.80, 0.30),
				"G": Color(0.44, 0.72, 0.44),
			},
			"grid": """SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSHHHHHHHSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSHHHHHHHHHHSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSPPPPPPSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSPPPPPPPPSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSPPPPPPPPSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSPPPPPPSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSCCCCCCSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSCCCCCCCCCCSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSCCCCYYCCCCSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSCCCCCCCCCCSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSCCCCCCCCCCSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSCCCCCCCCCCSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSccccccccccSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSccccccccccSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSCCCCCCSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSCCCCCCSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSCCCCCCSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSccccccSSSSSSSSSSSSSSSS
GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG""",
		},
		{
			"title": "你的使命",
			"body": "16 个回合内，平衡资金与生态，\n守护水位、植被、水质、鱼类、鸟类与社区。",
			"palette": {
				"K": Color(0.15, 0.18, 0.25), "O": Color(0.95, 0.60, 0.25),
				"R": Color(0.90, 0.40, 0.25), "Y": Color(0.98, 0.85, 0.40),
				"W": Color(0.30, 0.62, 0.80), "D": Color(0.16, 0.42, 0.62),
			},
			"grid": """KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKYYKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKOOOOOOKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKOOOOOOOOKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKOOOOOOOOKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKROOOOOOOKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKRROOOOOKKKKKKKKKKKKKKKKK
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWOOOWWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWRRRRWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD""",
		},
	]


func _show_menu() -> void:
	# 作废可能还在跑的算分动画：代次 +1，它每个 await 回来都会发现 ID 变了而立即退出。
	# 不这样做的话，回到主菜单后那段协程会继续改已经不该动的节点。
	_score_anim_id += 1
	_score_animating = false
	# 收掉可能在播的成就提示，别让它杵在主菜单上。
	# 它的协程会自己跑完（时序用的是 create_timer，不会挂死），
	# 跑完时再设一次 visible=false 也无害。
	_ach_queue.clear()
	if ach_layer != null:
		ach_layer.visible = false
	menu_root.visible = true
	menu_col.visible = true
	menu_talent_panel.visible = false
	menu_settings_panel.visible = false
	menu_credits_panel.visible = false
	menu_changelog_panel.visible = false
	_close_knowledge_viewer()   # 回到开始页时图鉴也要收起来
	_set_hud_visible(false)   # 开始页是干净的全景：HUD 让位给标题与选项
	_menu_state(0)
	_set_menu_camera(true)
	_roll_creeper_visibility()   # 苦力怕彩蛋按概率出现


## 开始页期间隐藏 HUD（左上信息栏 / 右上生态指标 / 事件横幅 / 右下按钮）
func _set_hud_visible(v: bool) -> void:
	var canvas := get_node_or_null("UICanvas")
	if canvas:
		canvas.visible = v
	if not v:
		_close_warn_history()   # 回主菜单/开始页时，别把回顾面板留在屏幕上


## 开始页层级：0 = 主选项 / 1 = 难度 / 2 = 种子
func _menu_state(state: int) -> void:
	var main_level := state == 0
	menu_start_btn.visible = main_level          # 新游戏
	menu_continue_btn.visible = main_level and has_save()  # 继续游戏（有存档才显示）
	# 天赋树暂关时这个按钮根本没建（见 TALENT_TREE_ENABLED），必须判空
	if menu_talent_btn != null:
		menu_talent_btn.visible = main_level
	menu_settings_btn.visible = main_level
	# 更新日志 / 制作人员已移入设置面板，显隐由面板自己管，不在这里控制
	menu_achievements_btn.visible = main_level
	menu_knowledge_btn.visible = main_level
	menu_utilities.visible = main_level
	menu_separator.visible = main_level
	menu_quit_btn.visible = main_level

	menu_easy_btn.visible = state == 1
	menu_normal_btn.visible = state == 1
	menu_hard_btn.visible = state == 1
	menu_nightmare_btn.visible = state == 1

	var seed_level := state == 2
	menu_mode_label.visible = seed_level
	menu_seed_label.visible = seed_level
	seed_input.visible = seed_level
	menu_seed_start_btn.visible = seed_level

	menu_back_btn.visible = state != 0
	menu_hint.text = ""
	if seed_level:
		seed_input.grab_focus()


func _on_title_start() -> void:
	_menu_state(1)


## 四档难度共用（用 bind 传难度值）。难度名走 GameState.difficulty_name()，
## 界面不再各写一份字面量。
func _on_difficulty_pick(d: int) -> void:
	GameState.difficulty = d
	menu_mode_label.text = "模式：%s" % GameState.difficulty_name()
	_update_threshold_lines()
	_menu_state(2)


## 返回上一层：种子 → 难度，难度 → 主选项
func _on_menu_back() -> void:
	if menu_seed_start_btn.visible:
		_menu_state(1)
	else:
		_menu_state(0)


## 设置 / 制作人员：入口先摆上，具体效果待做
func _on_menu_placeholder() -> void:
	_flash_menu_hint(menu_hint, "（暂未开放）")


## 菜单提示：显示后 3 秒自动消失
func _flash_menu_hint(label: Label, text: String) -> void:
	label.text = text
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(func() -> void:
		if label.text == text:
			label.text = "")


## 退出：直接关闭游戏窗口
func _on_menu_quit() -> void:
	get_tree().quit()


func _show_talent_panel() -> void:
	menu_col.visible = false
	menu_settings_panel.visible = false
	menu_credits_panel.visible = false
	menu_changelog_panel.visible = false
	menu_talent_panel.visible = true
	_refresh_talent_panel()


func _on_talent_back() -> void:
	menu_talent_panel.visible = false
	menu_col.visible = true
	_menu_state(0)


func _show_settings_panel() -> void:
	menu_col.visible = false
	menu_talent_panel.visible = false
	menu_credits_panel.visible = false
	menu_changelog_panel.visible = false
	menu_achievements_panel.visible = false
	# 每次重进都收起确认框、清掉上次的「已清空」提示，免得误导
	menu_clear_confirm_panel.visible = false
	clear_status_label.text = ""
	menu_settings_panel.visible = true


func _on_settings_back() -> void:
	menu_settings_panel.visible = false
	menu_col.visible = true
	_menu_state(0)


# ==================== 清空存档 ====================

## 清空「当前存档」—— 三份一起清：
##   user://savegame.json      单局进度（「继续游戏」读的那个）
##   user://talents.json       天赋点与已解锁天赋
##   user://achievements.json  成就
## 必须先过 _show_clear_confirm() 的二次确认，这个函数只负责真正动手。
func _clear_all_saves() -> void:
	_clear_save()
	Talents.reset_all()
	Achievements.reset_all()
	Knowledge.reset_all()


func _show_clear_confirm() -> void:
	menu_settings_panel.visible = false
	menu_clear_confirm_panel.visible = true


func _on_clear_confirm_cancel() -> void:
	menu_clear_confirm_panel.visible = false
	menu_settings_panel.visible = true


func _on_clear_confirm_ok() -> void:
	_clear_all_saves()
	menu_clear_confirm_panel.visible = false
	menu_settings_panel.visible = true
	clear_status_label.text = "已清空：对局进度 / 天赋 / 成就"
	# 天赋页此时通常还没铺过内容，但铺过就要立刻反映归零后的点数与状态
	_refresh_talent_panel()


func _show_credits_panel() -> void:
	_info_back_to_settings = menu_settings_panel.visible
	menu_col.visible = false
	menu_talent_panel.visible = false
	menu_settings_panel.visible = false
	menu_changelog_panel.visible = false
	menu_achievements_panel.visible = false
	menu_credits_panel.visible = true


func _on_credits_back() -> void:
	menu_credits_panel.visible = false
	if _info_back_to_settings:
		_info_back_to_settings = false
		menu_settings_panel.visible = true
		return
	menu_col.visible = true
	_menu_state(0)


func _show_changelog_panel() -> void:
	# 入口有两个：主菜单和设置面板。记下是从哪来的，返回时才知道该回哪儿。
	_info_back_to_settings = menu_settings_panel.visible
	menu_col.visible = false
	menu_talent_panel.visible = false
	menu_settings_panel.visible = false
	menu_credits_panel.visible = false
	menu_achievements_panel.visible = false
	menu_changelog_panel.visible = true


func _on_changelog_back() -> void:
	menu_changelog_panel.visible = false
	if _info_back_to_settings:
		_info_back_to_settings = false
		menu_settings_panel.visible = true
		return
	menu_col.visible = true
	_menu_state(0)


## 设置里重播开场动画：隐藏菜单后重新播放（播完自动回主菜单）
func _on_replay_intro() -> void:
	menu_settings_panel.visible = false
	menu_root.visible = false
	_show_intro()


# ==================== 音频 / BGM ====================
## 读取音量与 BGM 选择（无存档则用默认）
func _load_audio_settings() -> void:
	if not FileAccess.file_exists(AUDIO_SETTINGS_PATH):
		return
	var f := FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if data is Dictionary:
		bgm_index = clampi(int(data.get("bgm_index", 0)), 0, BGM_PATHS.size() - 1)
		bgm_volume = clampf(float(data.get("bgm_volume", 0.8)), 0.0, 1.0)
		score_speed = clampf(float(data.get("score_speed", 1.0)), SCORE_SPEED_MIN, SCORE_SPEED_MAX)


func _save_audio_settings() -> void:
	var data := {"bgm_index": bgm_index, "bgm_volume": bgm_volume, "score_speed": score_speed}
	var f := FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()


## 建立 BGM 播放器并开始循环播放
func _setup_bgm() -> void:
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	_apply_bgm()
	bgm_player.finished.connect(func() -> void: bgm_player.play())  # 循环


## 载入当前 BGM 与音量并播放
func _apply_bgm() -> void:
	var stream: AudioStream = load(BGM_PATHS[bgm_index])
	if stream is AudioStreamMP3:
		stream.loop = true
	bgm_player.stream = stream
	bgm_player.volume_db = linear_to_db(maxf(bgm_volume, 0.001))
	bgm_player.play()


## 建立音效播放池。同一个 AudioStream 可以被多个 player 同时播，
## 所以轮转复用就能支撑「连击音阶」那种密集触发而互不打断。
func _setup_sfx() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	for key in SFX_PATHS:
		# 缺文件时只告警不崩溃：但必须喊一声 —— 最常见的翻车方式是
		# 「wav 生成了但没在编辑器里导入」，那种情况下游戏照跑、全程静音，极难排查。
		if ResourceLoader.exists(SFX_PATHS[key]):
			_sfx_streams[key] = load(SFX_PATHS[key])
		else:
			push_warning("音效缺失：%s（跑一次 tools/make_ding.py，再在编辑器里打开工程让它导入）" % SFX_PATHS[key])


## 播一个音效。
## pitch 用来做「连击音阶」：同一种叮逐次升 key，是小丑牌那种层层叠加感的来源。
## vol_db 是相对音量偏移 —— 密集的小数字要压到 -8dB，落定的合计给 0dB，
## 否则 1.4 秒内响十几次会变成机关枪。
func play_sfx(sfx_name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if _sfx_players.is_empty() or not _sfx_streams.has(sfx_name):
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	p.stream = _sfx_streams[sfx_name]
	p.pitch_scale = pitch
	# 音量复用 BGM 那一个滑块：拉到 0 就该全静音，不给音效单独开设置项
	p.volume_db = linear_to_db(maxf(bgm_volume, 0.001)) + vol_db
	p.play()


## 音量滑动条回调
func _on_volume_changed(value: float) -> void:
	bgm_volume = value / 100.0
	bgm_volume = clampf(bgm_volume, 0.0, 1.0)
	bgm_player.volume_db = linear_to_db(maxf(bgm_volume, 0.001))
	_save_audio_settings()
	_sync_audio_ui()


## 结算动画速度滑块
func _on_score_speed_changed(value: float) -> void:
	score_speed = clampf(value / 100.0, SCORE_SPEED_MIN, SCORE_SPEED_MAX)
	_sync_score_speed_ui()
	_save_audio_settings()


## 同步两处「结算速度」滑块（主菜单设置 + 暂停设置）——它们共用同一个 score_speed
func _sync_score_speed_ui() -> void:
	var pct := int(round(score_speed * 100.0))
	# 光写百分比会有歧义（50% 是更慢还是更快？），补一个方向词
	var tag := "正常" if is_equal_approx(score_speed, 1.0) else ("更慢" if score_speed < 1.0 else "更快")
	var txt := "%d%%·%s" % [pct, tag]
	if score_speed_slider != null:
		score_speed_slider.set_value_no_signal(score_speed * 100.0)
	if score_speed_label != null:
		score_speed_label.text = txt
	if pause_score_speed_slider != null:
		pause_score_speed_slider.set_value_no_signal(score_speed * 100.0)
	if pause_score_speed_label != null:
		pause_score_speed_label.text = txt


## 切换 BGM（在两个曲目间循环）
func _on_switch_bgm() -> void:
	bgm_index = (bgm_index + 1) % BGM_PATHS.size()
	_apply_bgm()
	_save_audio_settings()
	_sync_audio_ui()


## 同步两处音频 UI（主菜单设置 + 暂停设置）
func _sync_audio_ui() -> void:
	var pct := int(bgm_volume * 100)
	if audio_volume_slider != null:
		audio_volume_slider.set_value_no_signal(bgm_volume * 100)
	if audio_volume_label != null:
		audio_volume_label.text = "音量：%d%%" % pct
	if pause_volume_slider != null:
		pause_volume_slider.set_value_no_signal(bgm_volume * 100)
	if pause_volume_label != null:
		pause_volume_label.text = "音量：%d%%" % pct
	_update_bgm_btn()


## 刷新切换 BGM 按钮文字（两处）
func _update_bgm_btn() -> void:
	var txt := "切换 BGM（当前：%s）" % BGM_NAMES[bgm_index]
	if bgm_switch_btn != null:
		bgm_switch_btn.text = txt
	if pause_bgm_btn != null:
		pause_bgm_btn.text = txt


## The branching panel owns node selection, allocation limits and purchases.
func _refresh_talent_panel() -> void:
	if menu_talent_panel != null: menu_talent_panel.call("refresh")


func _hide_menu() -> void:
	# 开始游戏时图鉴理论上点不到（返回按钮才能关），但万一开着就开局，
	# 它是 MenuLayer(layer 10) 之上的独立层，会直接盖住对局画面 —— 这里关掉保险。
	_close_knowledge_viewer()
	menu_root.visible = false
	_set_hud_visible(true)
	_set_menu_camera(false)


# ==================== 暂停 / 存档 ====================
## 游戏进行中按下 ESC：弹出暂停菜单（继续游戏 / 设置 / 退出至主菜单）
func _unhandled_input(event: InputEvent) -> void:
	if _intro_playing:
		# 开场 PPT：回车/点击下一张，ESC 直接跳过
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_finish_intro()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				_advance_intro()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_advance_intro()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause()


func _can_pause() -> bool:
	# 算分动画期间禁止暂停：_paused 是自定义变量、不是 get_tree().paused，
	# tween 在「暂停」下照常跑，放行只会得到「暂停菜单下面还在飞牌」的画面。
	return _playing and not GameState.game_over and not crisis_root.visible and not _score_animating


func _toggle_pause() -> void:
	if not _can_pause():
		return
	if _paused:
		_resume_game()
	else:
		_pause_game()


func _pause_game() -> void:
	_paused = true
	if sandpan_view: sandpan_view.set_paused(true)
	if wetland: wetland.set_process(false)
	pause_hint.text = ""
	pause_settings_panel.visible = false
	pause_panel.visible = true
	pause_root.visible = true


func _resume_game() -> void:
	_paused = false
	if sandpan_view: sandpan_view.set_paused(false)
	if wetland: wetland.set_process(true)
	pause_root.visible = false


func _on_pause_settings() -> void:
	pause_panel.visible = false
	pause_settings_panel.visible = true
	_sync_audio_ui()   # 打开时同步主菜单设置


func _on_pause_settings_back() -> void:
	pause_settings_panel.visible = false
	pause_panel.visible = true


## 退出至主菜单：先存档，保留本局进度
func _on_pause_exit() -> void:
	save_game()
	_paused = false
	pause_root.visible = false
	popup_root.visible = false
	hand_panel.visible = false
	bottom_right.visible = false
	tier_lever.visible = false
	_playing = false
	_show_menu()


## 主菜单「继续游戏」：读档续玩
func _on_continue_pressed() -> void:
	if not load_game():
		menu_hint.text = "没有可继续的进度"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func save_game() -> void:
	var hand_ids: Array = []
	var selected_ids: Array = []
	for info in card_infos:
		hand_ids.append(info["card_id"])
		if info["selected"]:
			selected_ids.append(info["card_id"])
	var data := {
		"state": GameState.serialize(),
		"hand_ids": hand_ids,
		"selected_ids": selected_ids,
		"phase": _current_phase,
		"event_text": _current_event,
	}
	if _current_phase != "allocate":
		data["popup"] = {
			"title": popup_title.text,
			"body": popup_body.text,
			"button": popup_button.text,
		}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if data == null or not (data is Dictionary):
		return false
	GameState.load_state(data.get("state", {}))
	_update_threshold_lines()
	_hide_menu()
	_playing = true
	_paused = false
	_current_event = str(data.get("event_text", ""))
	_banner_override = ""   # 读档后横幅直接显示当前态势，不继承上一局的危机残留
	_update_hud()
	_update_3d()
	var phase: String = str(data.get("phase", "allocate"))
	_current_phase = phase
	var popup: Dictionary = data.get("popup", {})
	match phase:
		"popup_event":
			_show_popup("第 %d 回合 · 事件" % GameState.turn, str(popup.get("body", "")), "开始分配资金", _enter_allocate)
		"popup_knowledge":
			_show_popup(str(popup.get("title", "")), str(popup.get("body", "")), "收下（继续）", _on_resolve_continue)
		"popup_settlement":
			_show_popup("结算反馈", str(popup.get("body", "")), "继续", _on_resolve_continue)
		_:
			_restore_hand(data)
	return true


## 恢复分配阶段：重建手牌并还原选中状态
func _restore_hand(data: Dictionary) -> void:
	var hand_ids: Array = data.get("hand_ids", [])
	var selected_ids: Array = data.get("selected_ids", [])
	current_hand = []
	for cid in hand_ids:
		var card: Dictionary = GameState._find_card(cid)
		if not card.is_empty():
			current_hand.append(card)
	play_deal_anim = false
	_build_hand_panel()
	for info in card_infos:
		if info["card_id"] in selected_ids:
			info["selected"] = true
			_apply_gold_frame(info["panel"])
	hand_panel.visible = true
	bottom_right.visible = true
	tier_lever.visible = true
	_slide_side_panels(false)
	_update_selected_label()


## 暂停菜单：盖在 HUD 与沙盘之上的独立层
func _build_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PauseLayer"
	layer.layer = 20
	add_child(layer)

	pause_root = Control.new()
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_root.visible = false
	layer.add_child(pause_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(center)

	pause_panel = PanelContainer.new()
	pause_panel.custom_minimum_size = Vector2(360, 0)
	_panel_style(pause_panel, Color(0.24, 0.17, 0.11, 0.96))
	center.add_child(pause_panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	pause_panel.add_child(pv)

	var t := _make_label("暂停", 30, Color(1, 0.9, 0.55))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(t)

	pause_hint = _make_label("", 13, Color(1, 0.6, 0.5))
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pause_hint)

	var b_resume := _make_button("继续游戏", _resume_game, 22)
	b_resume.custom_minimum_size = Vector2(0, 52)
	pv.add_child(b_resume)

	var b_settings := _make_button("设置", _on_pause_settings, 18)
	b_settings.custom_minimum_size = Vector2(0, 46)
	pv.add_child(b_settings)

	var b_exit := _make_button("退出至主菜单", _on_pause_exit, 18)
	b_exit.custom_minimum_size = Vector2(0, 46)
	pv.add_child(b_exit)

	# --- 暂停设置面板（与主菜单设置同步） ---
	pause_settings_panel = PanelContainer.new()
	pause_settings_panel.custom_minimum_size = Vector2(400, 0)
	_panel_style(pause_settings_panel, Color(0.24, 0.17, 0.11, 0.96))
	pause_settings_panel.visible = false
	center.add_child(pause_settings_panel)

	var psv := VBoxContainer.new()
	psv.add_theme_constant_override("separation", 12)
	pause_settings_panel.add_child(psv)

	var ps_title := _make_label("设置", 24, Color(1, 0.9, 0.55))
	ps_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	psv.add_child(ps_title)

	var ps_sep := HSeparator.new()
	psv.add_child(ps_sep)

	var pvol_row := HBoxContainer.new()
	pvol_row.add_theme_constant_override("separation", 8)
	psv.add_child(pvol_row)
	var pvol_lbl := _make_label("音量", 16, Color(0.82, 0.86, 0.9))
	pvol_row.add_child(pvol_lbl)
	pause_volume_slider = HSlider.new()
	pause_volume_slider.min_value = 0
	pause_volume_slider.max_value = 100
	pause_volume_slider.step = 1
	pause_volume_slider.value = bgm_volume * 100
	pause_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_volume_slider.value_changed.connect(_on_volume_changed)
	pvol_row.add_child(pause_volume_slider)
	pause_volume_label = _make_label("音量：%d%%" % int(bgm_volume * 100), 14, Color(1, 0.95, 0.6))
	pvol_row.add_child(pause_volume_label)

	pause_bgm_btn = _make_button("", _on_switch_bgm, 16)
	pause_bgm_btn.custom_minimum_size = Vector2(0, 44)
	psv.add_child(pause_bgm_btn)

	# 结算速度：与主菜单设置共用同一个 score_speed，两边永远同步
	# （_on_score_speed_changed → _sync_score_speed_ui 会同时刷两个滑块）
	var pspd_row := HBoxContainer.new()
	pspd_row.add_theme_constant_override("separation", 8)
	psv.add_child(pspd_row)
	pspd_row.add_child(_make_label("结算速度", 16, Color(0.82, 0.86, 0.9)))
	pause_score_speed_slider = HSlider.new()
	pause_score_speed_slider.min_value = SCORE_SPEED_MIN * 100.0
	pause_score_speed_slider.max_value = SCORE_SPEED_MAX * 100.0
	pause_score_speed_slider.step = 5
	pause_score_speed_slider.value = score_speed * 100.0
	pause_score_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_score_speed_slider.tooltip_text = "结算动画的快慢。100% 为默认；调小则更慢、看得更清楚，调大则更快。下一回合结算起生效。"
	pause_score_speed_slider.value_changed.connect(_on_score_speed_changed)
	pspd_row.add_child(pause_score_speed_slider)
	pause_score_speed_label = _make_label("", 14, Color(1, 0.95, 0.6))
	pspd_row.add_child(pause_score_speed_label)

	var ps_back := _make_button("返回", _on_pause_settings_back, 16)
	ps_back.custom_minimum_size = Vector2(0, 40)
	psv.add_child(ps_back)

	_update_bgm_btn()        # 同步两个切换按钮文字
	_sync_score_speed_ui()   # 两个结算速度滑块的文字也要填上（建的时候标签是空的）


# ==================== 危机警示 ====================
## 危机预警信号：入队，逐个弹出大红警示
func _on_crisis_warn(crisis: Dictionary) -> void:
	_crisis_queue.append({"crisis": crisis, "is_warning": true})
	_process_crisis_queue()


## 危机爆发信号：入队，逐个弹出大红警示
func _on_crisis_hit(crisis: Dictionary) -> void:
	_crisis_queue.append({"crisis": crisis, "is_warning": false})
	_process_crisis_queue()


func _process_crisis_queue() -> void:
	if GameState.game_over:
		return  # 已判负：失败报告优先，危机弹层不再抢屏
	if _score_animating:
		return  # 算分动画期间先攒着：危机预警/爆发已挪到回合末发射，
				# 此刻弹出来会糊在结算动画与结算弹窗上。
				# 队列不会丢 —— _finish_turn 在结算弹窗铺好后会再调一次本函数。
	if _crisis_queue.is_empty() or crisis_root.visible:
		return
	var item: Dictionary = _crisis_queue.pop_front()
	_show_crisis_alert(item["crisis"], item["is_warning"])


## 玩家点掉危机弹窗：还有下一个危机就继续弹，否则（无事件弹窗时）进入分配
func _on_crisis_dismiss() -> void:
	crisis_root.visible = false
	_banner_override = ""   # 危机弹层让出横幅，回到实时态势
	if not _crisis_queue.is_empty():
		_process_crisis_queue()
	elif not popup_root.visible:
		_enter_allocate()


## 弹出危机警示：大红叹号 + 屏幕红闪 + 雷霆大字 + 详细说明
func _show_crisis_alert(crisis: Dictionary, is_warning: bool) -> void:
	var name: String = crisis["name"]
	crisis_title.text = name
	crisis_tag.text = "⚠ 危机预警" if is_warning else "⚠ 危机爆发"
	crisis_button.text = "知道了" if is_warning else "继续"
	crisis_body.text = _crisis_body_text(crisis, is_warning)
	# 危机同步到顶部横幅：危机期间横幅让位给危机（_banner_override），
	# 弹层关掉后自动回到实时态势（见 _on_crisis_dismiss / _refresh_event_banner）。
	_banner_override = "⚠ %s · %s" % [("危机预警" if is_warning else "危机爆发"), name]
	_update_hud()

	crisis_root.visible = true
	# 淡红脉冲：起手轻轻亮一下，随后持续柔和脉冲（不再刺眼）
	crisis_dim.color.a = 0.28
	var pulse := crisis_dim.create_tween().set_loops()
	pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(crisis_dim, "color:a", 0.10, 0.6)
	pulse.tween_property(crisis_dim, "color:a", 0.28, 0.6)
	# 像素感叹号：大小脉冲（像在跳动），动画保持不变
	crisis_icon.pivot_offset = crisis_icon.size * 0.5
	var tw := crisis_icon.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(crisis_icon, "scale", Vector2(1.22, 1.22), 0.45)
	tw.tween_property(crisis_icon, "scale", Vector2.ONE, 0.45)


## 危机的「会造成什么」逐条文案（预警与爆发共用）
func _crisis_effect_lines(crisis: Dictionary) -> Array:
	var out: Array = []
	for e in crisis.get("effects", []):
		out.append("· %s %+d" % [GameState.METRIC_NAMES.get(e["metric"], e["metric"]), int(e["delta"])])
	return out


## 危机警示正文：描述 + 「当前 xx 值较低，可能影响 xx」 + 应对建议
func _crisis_body_text(crisis: Dictionary, is_warning: bool) -> String:
	var c := _parse_cond(str(crisis.get("cond", "")))
	var metric := str(c.get("metric", ""))
	var mname := str(GameState.METRIC_NAMES.get(metric, metric))
	var cur := int(GameState.metrics.get(metric, 0))
	var op := str(c.get("op", "<"))
	var low_high := "偏低" if op in ["<", "<="] else "偏高"
	var threshold := int(c.get("threshold", 0))

	var effect_lines: Array = _crisis_effect_lines(crisis)

	var body := ""
	if is_warning:
		body += "%s\n\n" % crisis["warn"]
		# 只在当前值真的落在危险侧时才提示，避免出现「当前水质 90（偏低）」这种自相矛盾的话。
		# ⚠ 这里**不写**危机的「触发阈值」：那和 HUD 上的「生态红线」（致死线）是两回事
		#   （水质触发线 55，致死线简单/普通/困难 = 15/25/35），两个词又太像，
		#   写出来玩家会以为是同一个数、进而误判自己离死还有多远，反而更糟。
		if metric != "" and _cond_holds(cur, op, threshold):
			body += "[color=#ffb060]⚠ 当前%s %d（%s）[/color]\n\n" % [mname, cur, low_high]
		body += "[color=#ff9090]若未及时应对，下一回合可能造成：[/color]\n"
		body += "\n".join(effect_lines)
		var counters: Array = GameState.counter_ids_for(crisis)
		if not counters.is_empty():
			var names: Array = []
			for cid in counters:
				names.append(_card_name(cid))
			# 标签匹配后对策卡可能有 4~6 张，只列前 4 张，免得这段撑爆弹窗
			var shown: Array = names.slice(0, 4)
			var tail: String = "" if names.size() <= 4 else " 等 %d 张" % names.size()
			# 对策卡是「大概率入手」而不是必出（肉鸽要有没抽到的局面），文案不承诺保底
			body += "\n\n[color=#8fd0ff]应对建议（下批手牌里对策卡概率已提高，不保证到手）：优先打出「%s」%s[/color]" % [
				"」「".join(shown), tail]
		# 深预警（科研点累计达标后开启）：把「2 回合后」那一场一并预告出来 ——
		# 这就是科研点的实际作用，写在弹窗里玩家才知道那个数字不只是评分。
		var fc: Dictionary = GameState.forecast_crisis
		if not fc.is_empty():
			body += "\n\n[color=#a9b7c6]── 深预警 · 2 回合后 ──[/color]\n"
			body += "[color=#ffb060]%s[/color]\n" % str(fc.get("name", "?"))
			body += "\n".join(_crisis_effect_lines(fc))
			var fc_counters: Array = GameState.counter_ids_for(fc)
			if not fc_counters.is_empty():
				var fnames: Array = []
				for cid in fc_counters:
					fnames.append(_card_name(cid))
				var fshown: Array = fnames.slice(0, 4)
				var ftail: String = "" if fnames.size() <= 4 else " 等 %d 张" % fnames.size()
				body += "\n[color=#8fd0ff]可提前布局：%s%s[/color]" % ["」「".join(fshown), ftail]
	else:
		body += "%s\n\n" % crisis["hit"]
		body += "[color=#ff9090]本次已造成：[/color]\n"
		body += "\n".join(effect_lines)
	return body


## 解析危机 cond（如 "water_level < 45"）→ {metric, op, threshold}
func _parse_cond(cond: String) -> Dictionary:
	return GameState._parse_cond_simple(cond)


## 当前值是否真的落在危机条件那一侧（安全区不报警）
func _cond_holds(cur: int, op: String, threshold: int) -> bool:
	match op:
		"<": return cur < threshold
		"<=": return cur <= threshold
		">": return cur > threshold
		">=": return cur >= threshold
		"==": return cur == threshold
	return false


## 危机警示弹层（盖在普通弹窗之上）
func _build_crisis_alert() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CrisisLayer"
	layer.layer = 5
	add_child(layer)

	crisis_root = Control.new()
	crisis_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	crisis_root.mouse_filter = Control.MOUSE_FILTER_STOP
	crisis_root.visible = false
	layer.add_child(crisis_root)

	crisis_dim = ColorRect.new()
	crisis_dim.color = Color(1.0, 0.55, 0.55, 0.22)   # 淡红，不再刺眼
	crisis_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	crisis_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	crisis_root.add_child(crisis_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	crisis_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	_panel_style(panel, Color(0.30, 0.12, 0.10, 0.97))
	center.add_child(panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)

	# 像素感叹号（贴图，最近邻放大保持锐利）
	var exclaim_grid := "..##..\n.#XX#.\n.#XX#.\n.#XX#.\n.#XX#.\n.#XX#.\n.#XX#.\n..##..\n......\n.#XX#.\n..##.."
	var exclaim_c := Color(1.0, 0.32, 0.28)
	crisis_icon = TextureRect.new()
	crisis_icon.texture = _pixel_icon(exclaim_grid, exclaim_c, exclaim_c.darkened(0.42), exclaim_c.lightened(0.25))
	crisis_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crisis_icon.stretch_mode = TextureRect.STRETCH_SCALE
	crisis_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crisis_icon.custom_minimum_size = Vector2(52, 96)
	crisis_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pv.add_child(crisis_icon)

	crisis_title = _make_label("", 44, Color(1.0, 0.30, 0.25))
	crisis_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crisis_title.add_theme_color_override("font_outline_color", Color(0.55, 0.0, 0.0, 0.85))
	crisis_title.add_theme_constant_override("outline_size", 8)
	pv.add_child(crisis_title)

	crisis_tag = _make_label("", 18, Color(1.0, 0.55, 0.45))
	crisis_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(crisis_tag)

	crisis_body = RichTextLabel.new()
	crisis_body.bbcode_enabled = true
	crisis_body.fit_content = true
	crisis_body.custom_minimum_size = Vector2(500, 0)
	crisis_body.add_theme_font_size_override("normal_font_size", _snap_px(16))
	crisis_body.add_theme_color_override("default_color", Color(0.98, 0.95, 0.92))
	pv.add_child(crisis_body)

	crisis_button = _make_button("知道了", _on_crisis_dismiss, 20)
	crisis_button.custom_minimum_size = Vector2(0, 50)
	pv.add_child(crisis_button)


# ==================== 危机预警回顾（P1）====================
## 顶部「预警回顾」条：预警弹窗关掉后信息收在这里，点一下能重看本局全部预警
func _build_warn_history(canvas: CanvasLayer) -> void:
	warn_bar = _make_button("", _open_warn_history, 13)
	warn_bar.anchor_left = 0.5
	warn_bar.anchor_right = 0.5
	warn_bar.offset_left = -240
	warn_bar.offset_right = 240
	warn_bar.offset_top = 34
	warn_bar.offset_bottom = 64
	warn_bar.clip_text = true
	warn_bar.tooltip_text = "点击重看本局全部危机预警"
	warn_bar.visible = false
	canvas.add_child(warn_bar)

	var layer := CanvasLayer.new()
	layer.name = "WarnLayer"
	layer.layer = 6   # 危机弹窗(5) 之上、主菜单(10) 之下
	add_child(layer)

	warn_panel_root = Control.new()
	warn_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	warn_panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	warn_panel_root.visible = false
	layer.add_child(warn_panel_root)

	var warn_dim := ColorRect.new()   # 不叫 dim：类里已有一个 dim，重名会多一条 SHADOWED_VARIABLE 警告
	warn_dim.color = Color(0.04, 0.06, 0.08, 0.74)
	warn_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	warn_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	warn_panel_root.add_child(warn_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	warn_panel_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	_panel_style(panel, Color(0.16, 0.13, 0.10, 0.97))
	center.add_child(panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)

	var title := _make_label("本局危机预警回顾", 24, Color(1, 0.88, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(title)

	warn_count_label = _make_label("", 14, Color(0.85, 0.88, 0.92))
	warn_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(warn_count_label)

	# 列表必须能滚：本局最多可能攒下 8~10 条，弹窗本体不滚动会顶穿窗口
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(scroll)

	warn_list_box = VBoxContainer.new()
	warn_list_box.add_theme_constant_override("separation", 8)
	warn_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(warn_list_box)

	var close_btn := _make_button("关闭", _close_warn_history, 18)
	close_btn.custom_minimum_size = Vector2(0, 46)
	pv.add_child(close_btn)


func _open_warn_history() -> void:
	if warn_panel_root == null:
		return
	_build_warn_rows()
	warn_panel_root.visible = true


func _close_warn_history() -> void:
	if warn_panel_root:
		warn_panel_root.visible = false


## 顶部那一条：显示最近一条预警，点开看全部
func _refresh_warn_bar() -> void:
	if warn_bar == null:
		return
	var rows: Array = GameState.warn_history
	if rows.is_empty():
		warn_bar.visible = false
		return
	var last: Dictionary = rows[rows.size() - 1]
	warn_bar.text = "⚠ 危机预警日志：%s（第 %d 回合）· 共 %d 条" % [
		_crisis_short_label(str(last["id"])), int(last["turn"]), rows.size()]
	warn_bar.visible = true


## 顶部预警条用的短名（比 METRIC_NAMES 更短，避免「沉水植被告急」这种读起来绕的串）
const WARN_SHORT_METRIC := {"vegetation": "植被", "fish": "鱼类", "birds": "候鸟", "community": "社区信任"}


## 危机的短标签，如「水位告急」「水质偏高」（由 cond 里的指标 + 方向推出来）
func _crisis_short_label(id: String) -> String:
	var c: Dictionary = GameState.crisis_by_id(id)
	if c.is_empty():
		return "危机"
	var pc := _parse_cond(str(c.get("cond", "")))
	var metric := str(pc.get("metric", ""))
	var nm := str(WARN_SHORT_METRIC.get(metric, GameState.METRIC_NAMES.get(metric, metric)))
	return nm + ("告急" if str(pc.get("op", "<")) in ["<", "<="] else "偏高")


func _build_warn_rows() -> void:
	for ch in warn_list_box.get_children():
		ch.queue_free()
	var rows: Array = GameState.warn_history
	warn_count_label.text = "共 %d 条（最新的在最上面）" % rows.size()
	if rows.is_empty():
		warn_list_box.add_child(_make_label("本局还没有出现过预警。", 16, Color(0.85, 0.88, 0.92)))
		return
	for i in range(rows.size() - 1, -1, -1):
		warn_list_box.add_child(_make_warn_row(rows[i]))


## 一条预警：第几回合 / 预警原文 / 当时的数值 / 后来有没有爆发 / 当时该打什么标签
func _make_warn_row(e: Dictionary) -> Control:
	var id := str(e["id"])
	var turn := int(e["turn"])
	var hit := int(e.get("hit_turn", -1))
	var c: Dictionary = GameState.crisis_by_id(id)
	var cname: String = str(c.get("name", id))
	var pc := _parse_cond(str(c.get("cond", "")))
	var metric := str(pc.get("metric", ""))
	var mname := str(GameState.METRIC_NAMES.get(metric, metric))

	var panel := PanelContainer.new()
	_panel_style(panel, Color(0.13, 0.11, 0.09, 0.94))
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(520, 0)
	body.add_theme_font_size_override("normal_font_size", _snap_px(14))
	body.add_theme_color_override("default_color", Color(0.94, 0.92, 0.88))

	# lead=2 是深预警（科研点累计达标后开启，提前 2 回合告知），标出来，
	# 否则回看时两条「预警」看着一样、分不清哪条更早
	var lead := int(e.get("lead", 1))
	var tag := "⚠ 危机预警" if lead <= 1 else "⏳ 深预警（提前 2 回合）"
	var t := "[color=#ffb060]第 %d 回合 · %s：%s[/color]\n" % [turn, tag, cname]
	t += "%s\n" % str(c.get("warn", ""))
	# 不写「警戒线」：那是危机的触发阈值，和 HUD 上的「生态红线」（致死线）
	# 完全不是一个数（水质 55 vs 15/25/35），词又像，写出来只会误导。
	t += "当时：%s %d\n" % [mname, int(e.get("value", 0))]
	if hit > 0:
		var eff: Array = []
		for ef in c.get("effects", []):
			eff.append("%s %+d" % [GameState.METRIC_NAMES.get(ef["metric"], ef["metric"]), int(ef["delta"])])
		t += "[color=#ff9090]→ 第 %d 回合已爆发：%s[/color]\n" % [hit, "、".join(eff)]
	else:
		t += "[color=#9aa0a6]→ 未爆发（本局在那之前就结束了）[/color]\n"
	# 沿用预警弹窗里的说法（「应对建议：优先打出「卡名」」），不暴露内部的标签名 ——
	# 「补水调度」「病害防控」这类标签玩家在别处根本看不到，写在日志里会显得割裂。
	var counters: Array = GameState.counter_ids_for(c)
	if not counters.is_empty():
		var names: Array = []
		for cid in counters:
			names.append(_card_name(cid))
		var shown: Array = names.slice(0, 3)
		var tail: String = "" if names.size() <= 3 else " 等 %d 张" % names.size()
		t += "[color=#8fd0ff]应对建议：优先打出「%s」%s[/color]" % ["」「".join(shown), tail]
	body.text = t
	panel.add_child(body)
	return panel


# ==================== 牌库（牌堆）UI ====================
## 生成主题像素牌背（湖水蓝 + 波浪横纹）
func _make_card_back_texture() -> Texture2D:
	return preload("res://assets/art/guardian-card-back.svg")


## 牌堆：生态指标框下方，叠放三张牌背；悬停黄框+孔雀开屏，点击查看牌库
func _build_deck_ui(canvas: CanvasLayer) -> void:
	card_back_tex = _make_card_back_texture()

	deck_root = Control.new()
	deck_root.anchor_left = 1.0
	deck_root.anchor_top = 0.0
	deck_root.anchor_right = 1.0
	deck_root.anchor_bottom = 0.0
	deck_root.offset_left = -210
	deck_root.offset_right = -18
	deck_root.offset_top = 327
	deck_root.offset_bottom = 431
	deck_root.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(deck_root)

	# 黄色外框（悬停时显示，自绘贴牌形状）
	deck_border = Control.new()
	deck_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	deck_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_border.visible = false
	deck_border.draw.connect(_on_deck_border_draw)
	deck_root.add_child(deck_border)

	# 叠放的三张牌背
	var stack_positions := [Vector2(12, 4), Vector2(15, 2), Vector2(18, 0)]
	for i in 3:
		var back := TextureRect.new()
		back.texture = card_back_tex
		back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.custom_minimum_size = Vector2(64, 86)
		back.size = Vector2(64, 86)
		back.position = stack_positions[i]
		back.pivot_offset = Vector2(32, 43)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck_root.add_child(back)
		deck_backs.append(back)

	# 悬停 / 点击
	deck_root.mouse_entered.connect(_on_deck_mouse_entered)
	deck_root.mouse_exited.connect(_on_deck_mouse_exited)
	deck_root.gui_input.connect(_on_deck_gui_input)
	deck_root.tooltip_text = "查看全部行动卡 · 点击打开牌库"
	var caption := _make_label("行动图鉴\n点击查看", 12, VisualTheme.PAPER)
	caption.position = Vector2(100, 35)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_root.add_child(caption)


func _on_deck_mouse_entered() -> void:
	_deck_hovered = true
	_fan_deck(true)
	# 展开动画结束后才显示黄框（途中不显示）
	var tw := create_tween()
	tw.tween_interval(0.22)
	tw.tween_callback(func() -> void:
		if _deck_hovered:
			deck_border.visible = true
			deck_border.queue_redraw())


func _on_deck_mouse_exited() -> void:
	_deck_hovered = false
	deck_border.visible = false
	_fan_deck(false)


## 孔雀开屏：悬停时三张牌背扇形展开，移开后收回
func _fan_deck(out: bool) -> void:
	var fan_positions := [Vector2(-1, 8), Vector2(20, 0), Vector2(41, 8)]
	var fan_rotations := [-0.26, 0.0, 0.26]
	var stack_positions := [Vector2(12, 4), Vector2(15, 2), Vector2(18, 0)]
	for i in deck_backs.size():
		var back: TextureRect = deck_backs[i]
		var pos: Vector2 = fan_positions[i] if out else stack_positions[i]
		var rot: float = fan_rotations[i] if out else 0.0
		var tw := back.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(back, "position", pos, 0.22)
		tw.parallel().tween_property(back, "rotation", rot, 0.22)


## 自绘黄框：给每张牌背各画一条贴牌黄边（严格贴着每张牌的形状）
func _on_deck_border_draw() -> void:
	for back in deck_backs:
		var corners := _card_corners(back)
		var pts := corners.duplicate()
		pts.append(corners[0])
		deck_border.draw_polyline(pts, Color(1.0, 0.85, 0.3), 3.0, true)


## 计算一张牌背（带旋转）的四个角点（deck_root 局部坐标）
func _card_corners(back: TextureRect) -> PackedVector2Array:
	var c := cos(back.rotation)
	var s := sin(back.rotation)
	var corners := PackedVector2Array()
	var locals: Array[Vector2] = [Vector2.ZERO, Vector2(back.size.x, 0), Vector2(back.size.x, back.size.y), Vector2(0, back.size.y)]
	for local in locals:
		var rel: Vector2 = local - back.pivot_offset
		var rotated := Vector2(rel.x * c - rel.y * s, rel.x * s + rel.y * c)
		corners.append(back.position + back.pivot_offset + rotated)
	return corners


func _on_deck_gui_input(event: InputEvent) -> void:
	if _score_animating:
		return      # 算分动画期间不开牌库查看器（它的 CanvasLayer 会盖在动画层上）
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_deck_viewer()


## 牌库查看器：全屏弹层，逐张发牌展示所有卡牌
func _build_deck_viewer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DeckViewerLayer"
	layer.layer = 8
	add_child(layer)

	deck_viewer = Control.new()
	deck_viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	deck_viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	deck_viewer.visible = false
	layer.add_child(deck_viewer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	deck_viewer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 70
	box.offset_right = -70
	box.offset_top = 40
	box.offset_bottom = -40
	box.add_theme_constant_override("separation", 12)
	deck_viewer.add_child(box)

	var title_bar := HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 10)
	box.add_child(title_bar)

	var title := _make_label("全部卡牌", 28, Color(1, 0.9, 0.55))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_bar.add_child(title)

	deck_sort_btn = _make_sort_button()
	title_bar.add_child(deck_sort_btn)
	_update_sort_btn()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	# 四周留内边距：顶部留足放大+漂浮的余量，避免顶行/左列卡被裁剪
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	scroll.add_child(margin)

	deck_viewer_grid = HFlowContainer.new()
	deck_viewer_grid.add_theme_constant_override("h_separation", 14)
	deck_viewer_grid.add_theme_constant_override("v_separation", 14)
	deck_viewer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(deck_viewer_grid)

	var close := _make_button("关闭", _close_deck_viewer, 20)
	close.custom_minimum_size = Vector2(0, 48)
	box.add_child(close)

	_build_card_detail()


## 牌库打开时把 HUD 其余面板收出屏幕，关闭时弹回原位（保持尺寸，仅平移 offset）
func _slide_main_ui(out: bool) -> void:
	for tw in _ui_slide_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_ui_slide_tweens.clear()
	var vp := get_viewport().get_visible_rect().size
	var ctrls: Array = [left_panel, right_panel, event_label, hand_panel, bottom_right, deck_root, tier_lever]
	for c in ctrls:
		if c == null:
			continue
		if not _ui_slide_origin.has(c):
			_ui_slide_origin[c] = [c.offset_left, c.offset_top, c.offset_right, c.offset_bottom]
		var origin: Array = _ui_slide_origin[c]
		var dir := _slide_out_dir(c)
		var dx := dir.x * (vp.x + 200.0)
		var dy := dir.y * (vp.y + 200.0)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if out:
			tw.tween_property(c, "offset_left", c.offset_left + dx, 0.34)
			tw.parallel().tween_property(c, "offset_right", c.offset_right + dx, 0.34)
			tw.parallel().tween_property(c, "offset_top", c.offset_top + dy, 0.34)
			tw.parallel().tween_property(c, "offset_bottom", c.offset_bottom + dy, 0.34)
		else:
			tw.tween_property(c, "offset_left", origin[0], 0.34)
			tw.parallel().tween_property(c, "offset_right", origin[2], 0.34)
			tw.parallel().tween_property(c, "offset_top", origin[1], 0.34)
			tw.parallel().tween_property(c, "offset_bottom", origin[3], 0.34)
		_ui_slide_tweens.append(tw)


## 每个面板收起的方向（向最近的屏幕外平移）
func _slide_out_dir(c: Control) -> Vector2:
	if c == left_panel:
		return Vector2(-1, 0)   # 左面板向左出
	if c == right_panel or c == deck_root:
		return Vector2(1, 0)    # 右面板 / 牌堆向右出
	if c == event_label:
		return Vector2(0, -1)   # 顶部横幅向上出
	if c == bottom_right:
		return Vector2(1, 0)    # 结束回合按钮向右出
	return Vector2(0, 1)       # 手牌向下出


func _open_deck_viewer() -> void:
	if _deck_open:
		return
	_deck_open = true
	deck_viewer.visible = true
	# 收起牌堆的悬停状态（避免残留黄框/孔雀开屏），并把其余 HUD 收出屏幕
	_deck_hovered = false
	deck_border.visible = false
	_fan_deck(false)
	_slide_main_ui(true)
	_update_sort_btn()   # 重开时同步按钮文字与当前排序方式，严格绑定
	# 重建全部卡牌
	for c in deck_viewer_grid.get_children():
		deck_viewer_grid.remove_child(c)
		c.queue_free()
	_deck_gyro_view = null
	var cards: Array = []
	for card in _sorted_action_cards(_deck_sort_by_category):
		var made := _make_card(card, "effective")
		var panel: PanelContainer = made["panel"]
		var view := _make_gyro_card_view(panel)
		view.set_meta("card", card)
		view.tooltip_text = "%s\n\n%s" % [card["desc"], _effect_text(card)]
		view.scale = Vector2(0.3, 0.3)
		view.modulate.a = 0.0
		view.mouse_entered.connect(_on_viewer_card_hover.bind(view, card))
		view.mouse_exited.connect(_on_viewer_card_unhover.bind(view))
		view.gui_input.connect(_on_viewer_card_click.bind(view, card))
		deck_viewer_grid.add_child(view)
		cards.append(view)
	# 等一帧布局完成后逐张发牌
	await get_tree().process_frame
	for i in cards.size():
		var p: Control = cards[i]
		var tw := p.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector2.ONE, 0.28).set_delay(i * 0.03)
		tw.parallel().tween_property(p, "modulate:a", 1.0, 0.18).set_delay(i * 0.03)


## 整张卡作为刚性平面旋转，纹理使用透视正确采样，避免三角形接缝与扭曲。
## 卡面、框线和闪箔共享同一中心与投影；鼠标角度和缓动保持原有手感。
func _make_gyro_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/card_rigid.gdshader")
	return mat


func _use_parent_material_tree(node: Node, overlays: Array) -> void:
	for child in node.get_children():
		if child.get_meta("card_projected_shadow", false):
			continue
		if child is CanvasItem:
			if child.get_meta("card_gyro_overlay", false):
				child.use_parent_material = false
				overlays.append(child.material)
			else:
				child.use_parent_material = true
		_use_parent_material_tree(child, overlays)


func _bind_card_gyro(card: Control) -> void:
	card.material = _make_gyro_material()
	var overlays: Array = []
	_use_parent_material_tree(card, overlays)
	card.set_meta("gyro_overlays", overlays)
	if not card.has_meta("projected_shadow"):
		var shadow := Node2D.new()
		shadow.set_script(preload("res://scripts/card_projected_shadow.gd"))
		shadow.name = "ProjectedCardShadow"
		shadow.set_meta("card_projected_shadow", true)
		shadow.show_behind_parent = true
		shadow.use_parent_material = false
		card.add_child(shadow)
		card.set_meta("projected_shadow", shadow)
	_step_card_gyro(card, Vector2.ZERO, 0.0)


func _make_gyro_card_view(panel: PanelContainer) -> Control:
	var view := Control.new()
	view.set_script(preload("res://scripts/card_hit_view.gd"))
	view.size = Vector2(122, 165)
	view.custom_minimum_size = view.size
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(panel)
	view.set_meta("panel", panel)
	_bind_card_gyro(view)
	return view


func _card_gyro_center(card: Control) -> Vector2:
	return card.get_global_transform() * (card.size * 0.5)


func _card_gyro_target(card: Control, mouse: Vector2, active: bool) -> Vector2:
	if not active:
		return Vector2.ZERO
	var offset := mouse - _card_gyro_center(card)
	return Vector2(clampf(offset.y * 0.0032, -0.32, 0.32), clampf(offset.x * 0.0042, -0.32, 0.32))


func _step_card_gyro(card: Control, target: Vector2, delta: float) -> void:
	var mat := card.material as ShaderMaterial
	if mat == null:
		return
	var current := Vector2(float(card.get_meta("gyro_x", 0.0)), float(card.get_meta("gyro_y", 0.0)))
	var face: TextureRect = preload("res://scripts/card_geometry.gd").face_of(card)
	var geometry_key: Array = [mat.get_instance_id(), card.get_global_transform(), card.size,
		face.position if face else Vector2.ZERO, face.size if face else Vector2.ZERO,
		face.texture.get_instance_id() if face and face.texture else 0]
	var old_poke: float = float(card.get_meta("poke_age", 1.0))
	if old_poke >= 0.28 and current == target and card.get_meta("gyro_geometry_key", []) == geometry_key:
		return
	card.set_meta("gyro_geometry_key", geometry_key)
	current = current.lerp(target, 1.0 - exp(-12.0 * delta))
	if current.distance_squared_to(target) < 0.0000000001: current = target
	var poke_age: float = minf(1.0, float(card.get_meta("poke_age", 1.0)) + delta)
	card.set_meta("poke_age", poke_age)
	var poke_scale := 1.0
	if poke_age < 0.28 and wetland and not wetland.reduced_motion:
		var decay := 1.0 - poke_age / 0.28
		current += Vector2(sin(poke_age * 105.0), sin(poke_age * 83.0)) * 0.035 * decay
		poke_scale = 1.0 - sin(poke_age / 0.28 * PI) * 0.07
	card.set_meta("poke_scale", poke_scale)
	card.set_meta("gyro_x", current.x)
	card.set_meta("gyro_y", current.y)
	mat.set_shader_parameter("tilt_x", current.x)
	mat.set_shader_parameter("tilt_y", current.y)
	mat.set_shader_parameter("card_center", _card_gyro_center(card))
	mat.set_shader_parameter("poke_scale", poke_scale)
	if face != null:
		var face_rect: Rect2 = preload("res://scripts/card_geometry.gd").face_rect(face)
		for child in face.get_parent().get_children():
			if child is Control and child.get_meta("card_gyro_overlay", false):
				child.position = face.position + face_rect.position
				child.size = face_rect.size
	if card.has_meta("projected_shadow"):
		card.get_meta("projected_shadow").update_projection(card, current)
	# 独立的闪箔膜保留片元材质，同时与卡面共用倾斜和透视中心。
	for overlay: ShaderMaterial in card.get_meta("gyro_overlays", []):
		overlay.set_shader_parameter("tilt_x", current.x)
		overlay.set_shader_parameter("tilt_y", current.y)
		overlay.set_shader_parameter("card_center", _card_gyro_center(card))
		overlay.set_shader_parameter("poke_scale", poke_scale)

func _poke_card(card: Control) -> void:
	if card == null or not is_instance_valid(card): return
	card.set_meta("poke_age", 0.0)
	card.set_meta("poke_count", int(card.get_meta("poke_count", 0)) + 1)


func _close_deck_viewer() -> void:
	_deck_open = false
	_deck_gyro_view = null
	deck_viewer.visible = false
	_slide_main_ui(false)


# ==================== 牌库排序（按类别 / 按费用 切换） ====================
## 互旋箭头图标（两个方向相反的箭头，表示切换）
func _make_swap_icon_texture(px: int) -> ImageTexture:
	var grid := """............X...
............XX..
XXXXXXXXXXXXXXX.
XXXXXXXXXXXXXXXX
XXXXXXXXXXXXXXX.
............XX..
............X...
................
................
...X............
..XX............
.XXXXXXXXXXXXXXX
XXXXXXXXXXXXXXXX
.XXXXXXXXXXXXXXX
..XX............
...X............"""
	var img := _grid_image(grid, Color(1.0, 0.92, 0.66), Color(0.85, 0.72, 0.42), Color(1.0, 1.0, 1.0))
	img.resize(px, px, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## 排序切换按钮：互旋箭头 + 文字，点击切换排序方式
func _make_sort_button() -> Button:
	var b := _make_button("", _toggle_deck_sort, 16)
	b.icon = _make_swap_icon_texture(32)
	b.custom_minimum_size = Vector2(150, 42)
	return b


## 刷新排序按钮文字与提示
## 同步两处排序按钮（牌库面板里 + 出牌阶段右下角）。
## 它们共用同一个 _deck_sort_by_category，所以文案永远一致。
## ⚠ 不要因为某一个为 null 就整体 return —— 两个按钮不是同时创建的。
func _update_sort_btn() -> void:
	var mode := "按类别排序" if _deck_sort_by_category else "按费用排序"
	var tip := "切换排序方式（当前：%s）" % mode
	if deck_sort_btn != null:
		deck_sort_btn.text = mode
		deck_sort_btn.tooltip_text = tip
	if hand_sort_btn != null:
		hand_sort_btn.text = mode
		hand_sort_btn.tooltip_text = tip


## 排序冷却：锁死期间按钮禁用并显示倒计时，禁止交互/无按下反馈
func _update_sort_cooldown() -> void:
	var remaining := SORT_COOLDOWN_MS - (Time.get_ticks_msec() - _sort_cooldown_ms)
	_apply_sort_cooldown(deck_sort_btn, remaining)
	_apply_sort_cooldown(hand_sort_btn, remaining)
	if sandpan_view and sandpan_view.collapsed and hand_sort_btn:
		hand_sort_btn.disabled = true


## 冷却期间按钮禁用并显示倒计时。冷却也是两边共用的。
## 抽成独立函数是为了避免每帧构造数组/闭包 —— 它每帧都被 _process 调到。
func _apply_sort_cooldown(btn: Button, remaining: int) -> void:
	if btn == null:
		return
	if remaining > 0:
		if not btn.disabled:
			btn.disabled = true
		btn.text = "冷却中 %d 秒" % int(ceil(remaining / 1000.0))
	elif btn.disabled:
		btn.disabled = false
		_update_sort_btn()


func _toggle_deck_sort() -> void:
	# 锁死两次切换之间的最低时间间隔（见 SORT_COOLDOWN_MS），杜绝连点造成排列错乱
	var now := Time.get_ticks_msec()
	if now - _sort_cooldown_ms < SORT_COOLDOWN_MS:
		return
	if _sort_animating:
		return
	_sort_cooldown_ms = now
	_sort_animating = true
	_deck_sort_by_category = not _deck_sort_by_category
	_update_sort_btn()
	await _sort_deck_cards(_deck_sort_by_category)
	_sort_animating = false


## 按当前排序规则返回 ACTION_CARDS 的有序副本
func _sorted_action_cards(by_category: bool) -> Array:
	var cards: Array = GameState.ACTION_CARDS.duplicate()
	cards.sort_custom(func(a, b): return _card_dict_less(a, b, by_category))
	return cards


## 两张卡牌的比较器：类别排序按类别序（生态→社会→管理），费用排序按费用升序
func _card_dict_less(a: Dictionary, b: Dictionary, by_category: bool) -> bool:
	if by_category:
		var oa := CATEGORY_ORDER.find(a["category"])
		var ob := CATEGORY_ORDER.find(b["category"])
		if oa != ob:
			return oa < ob
	else:
		if a["cost"] != b["cost"]:
			return a["cost"] < b["cost"]
		var oa := CATEGORY_ORDER.find(a["category"])
		var ob := CATEGORY_ORDER.find(b["category"])
		if oa != ob:
			return oa < ob
	# 同级再按费用、id 稳定排序
	if a["cost"] != b["cost"]:
		return a["cost"] < b["cost"]
	return a["id"] < b["id"]


## 重排牌库卡牌并让它们直接飞到新位置
func _sort_deck_cards(by_category: bool) -> void:
	var panels: Array = deck_viewer_grid.get_children()
	if panels.size() < 2:
		return
	# 先停掉所有悬停动画并复位，避免和飞行动画打架
	for p in panels:
		_kill_card_tweens(p)
		p.z_index = 0
		p.rotation = 0.0
		p.scale = Vector2.ONE
		p.modulate.a = 1.0
		_remove_yellow_frame(p)
	# 记录旧位置
	var old_pos := {}
	for p in panels:
		old_pos[p] = p.position
	# 按新规则排序并重排子节点
	panels.sort_custom(func(a, b): return _card_dict_less(a.get_meta("card"), b.get_meta("card"), by_category))
	for i in panels.size():
		deck_viewer_grid.move_child(panels[i], i)
	# 等两帧确保 HFlowContainer 完成重新布局（一帧可能不够，读到旧位置会导致排序没变）
	deck_viewer_grid.queue_sort()
	await get_tree().process_frame
	await get_tree().process_frame
	# 把每张牌拉回旧位置，再 tween 直接飞到新位置
	for p in panels:
		var new_pos: Vector2 = p.position
		p.position = old_pos[p]
		p.set_meta("base_pos", new_pos)   # 更新悬停基准位，避免下次悬停飞到旧位
		var tw: Tween = p.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(p, "position", new_pos, 0.3)
	# 等飞行动画完成，期间 _sort_animating 保持 true，避免连点造成位置 tween 重叠
	await get_tree().create_timer(0.32).timeout


## 出牌阶段的排序：与牌库共用一个模式、一套冷却，只是作用对象换成在场手牌。
func _toggle_hand_sort() -> void:
	if sandpan_view and sandpan_view.collapsed: return
	var now := Time.get_ticks_msec()
	if now - _sort_cooldown_ms < SORT_COOLDOWN_MS:
		return
	if _sort_animating or card_infos.size() < 2:
		return
	_sort_cooldown_ms = now
	_sort_animating = true
	_deck_sort_by_category = not _deck_sort_by_category
	_update_sort_btn()
	await _sort_hand_cards(_deck_sort_by_category)
	_sort_animating = false


## 给在场手牌重排。
##
## 扇形的位置全部由 _layout_fan() 统一算（base_pos / theta / radial 写回 card_infos），
## 所以流程是：先排好 card_infos → 重新布局 → 把每张牌拉回它**原来那个位置** →
## 再 tween 飞到新位置。这样看到的是「牌互相换位」，而不是全体瞬移重排。
##
## ⚠ 旧位置必须按 panel 存，不能按下标 —— 排完序下标就换人了。
## ⚠ 选中状态挂在 card_infos 的条目上，跟着卡片一起走，不需要额外保存/恢复；
##   金色选中框是画在 panel 上的，也随 panel 一起移动。
func _sort_hand_cards(by_category: bool) -> void:
	const GATHER_DUR := 0.24        # 收牌时长
	const GATHER_LAG := 0.016       # 收牌错开（做出"被一把收拢"的层次）
	const DEAL_DUR := 0.28          # 发牌时长
	const DEAL_LAG := 0.040         # 发牌错开（沿用 _play_deal_animation 的节奏）
	const PILE_SPREAD := 3.0        # 牌堆里每张牌往下错一点，完全重合就看不出一叠了
	const PILE_SCALE := 0.92        # 收拢时略微缩小，像被攥成一把

	if card_infos.size() < 2:
		return
	var n := card_infos.size()

	# ① 收牌：全部飞到屏幕中央叠成一堆
	#    屏幕坐标 → card_box 局部坐标；pivot 在底部中心，
	#    所以 position = 落点 - pivot 才是把牌的底部中心放到那个点上。
	var vp := get_viewport().get_visible_rect().size
	var pile_center: Vector2 = _screen_to_card_box(vp * 0.5)
	# 收牌落点按 **panel** 存 —— _layout_fan() 会重排位置，排完序下标就换人了
	var pile_pos: Dictionary = {}
	for i in n:
		var info: Dictionary = card_infos[i]
		var p: PanelContainer = info["panel"]
		if not is_instance_valid(p):
			return
		# 让 _update_card_hover 让出控制权：它每帧把牌拽回 base_pos，
		# 会和飞行 tween 逐帧打架（照抄 shaking / 算分飞牌的既有做法）
		info["flying"] = true
		var spot: Vector2 = pile_center - p.pivot_offset + Vector2(0.0, float(i) * PILE_SPREAD)
		pile_pos[p] = spot
		var d: float = float(i) * GATHER_LAG
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "position", spot, GATHER_DUR).set_delay(d)
		tw.tween_property(p, "rotation", 0.0, GATHER_DUR).set_delay(d)
		tw.tween_property(p, "scale", Vector2(PILE_SCALE, PILE_SCALE), GATHER_DUR).set_delay(d)
	await get_tree().create_timer(GATHER_DUR + float(n - 1) * GATHER_LAG + 0.02).timeout

	# ② 排序 + 重新布局。此刻牌全叠在一点，位置怎么变都看不出来，
	#    排序这一步天然被收拢动作掩盖掉了 —— 顺序要到发牌时才揭晓。
	card_infos.sort_custom(func(a, b):
		return _card_id_dict_less(str(a["card_id"]), str(b["card_id"]), by_category))
	_layout_fan()   # 重写每张牌的 position / rotation / base_pos / theta / radial

	# ③ 发牌：从牌堆位置按新顺序逐张飞回自己的扇形位置
	for i in n:
		var info: Dictionary = card_infos[i]
		var p: PanelContainer = info["panel"]
		if not is_instance_valid(p):
			continue
		var target: Vector2 = info["base_pos"]
		# 已选中的牌最终是「抬起来」的：直接发到抬起后的落点，
		# 别先落平再由 _update_card_hover 抬一次（那样会多一次起落）
		if bool(info["selected"]):
			target += (info["radial"] as Vector2) * CARD_RAISE
		p.position = pile_pos.get(p, target)
		p.rotation = 0.0
		p.scale = Vector2(PILE_SCALE, PILE_SCALE)
		var d: float = float(i) * DEAL_LAG
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "position", target, DEAL_DUR).set_delay(d)
		tw.tween_property(p, "rotation", float(info["theta"]), DEAL_DUR).set_delay(d)
		tw.tween_property(p, "scale", Vector2.ONE, DEAL_DUR).set_delay(d)

	# 等发完，期间 _sort_animating 保持 true，避免连点让位置 tween 重叠
	await get_tree().create_timer(DEAL_DUR + float(n - 1) * DEAL_LAG + 0.02).timeout
	for info in card_infos:
		info["flying"] = false


## 按 card_id 比较（手牌排序用 —— card_infos 里存的是 id，不是卡牌字典）
func _card_id_dict_less(a_id: String, b_id: String, by_category: bool) -> bool:
	var a := _find_card_data(a_id)
	var b := _find_card_data(b_id)
	if a.is_empty() or b.is_empty():
		return a_id < b_id
	return _card_dict_less(a, b, by_category)


# ==================== 牌库卡牌悬停 / 点击查看 ====================
## 悬停：浮起放大 + 黄框；并记录为陀螺仪目标，不添加循环漂浮。
func _on_viewer_card_hover(view: Control, _card: Dictionary) -> void:
	_deck_gyro_view = view
	_kill_card_tweens(view)
	if not view.has_meta("base_pos"):
		view.set_meta("base_pos", view.position)  # 首次悬停才记录原位（此时布局已完成）
	var base: Vector2 = view.get_meta("base_pos")
	view.z_index = 10
	view.pivot_offset = view.size * 0.5
	var tweens: Array = []
	# 浮起放大
	var tw := view.create_tween()
	tweens.append(tw)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(view, "position:y", base.y - 16, 0.16)
	tw.parallel().tween_property(view, "scale", Vector2(1.12, 1.12), 0.16)
	view.set_meta("hover_tweens", tweens)
	_apply_yellow_frame(view)


func _on_viewer_card_unhover(view: Control) -> void:
	if _deck_gyro_view == view:
		_deck_gyro_view = null
	_kill_card_tweens(view)
	view.z_index = 0
	var base: Vector2 = view.get_meta("base_pos", view.position)
	var tw := view.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(view, "position", base, 0.16)
	tw.parallel().tween_property(view, "scale", Vector2.ONE, 0.16)
	tw.parallel().tween_property(view, "rotation", 0.0, 0.16)
	view.set_meta("return_tween", tw)
	_remove_yellow_frame(view)


## 取消该卡牌所有悬停/归位动画，避免快速反复划过时 tween 打架
func _kill_card_tweens(view: Control) -> void:
	var tweens: Array = view.get_meta("hover_tweens", [])
	for t in tweens:
		if t != null:
			t.kill()
	view.set_meta("hover_tweens", null)
	if view.has_meta("return_tween"):
		var ret: Tween = view.get_meta("return_tween")
		if ret != null:
			ret.kill()
	view.set_meta("return_tween", null)


## 牌库陀螺仪：只对鼠标悬停的那张牌做 3D 透视倾斜（绕 X/Y 轴），其余回正
func _process_deck_gyro(delta: float, mouse_override: Vector2 = Vector2.INF) -> void:
	# 三个网格（牌库 / 紧急调度 / 知识卡图鉴）任一开着就继续跑
	var dispatch_open: bool = dispatch_panel != null and dispatch_panel.visible
	var knowledge_open: bool = knowledge_viewer != null and knowledge_viewer.visible
	if not _deck_open and not dispatch_open and not knowledge_open:
		return
	if deck_viewer_grid == null and dispatch_grid == null and knowledge_grid == null:
		return
	var mouse := mouse_override if mouse_override != Vector2.INF else get_viewport().get_mouse_position()
	# 牌库与紧急调度面板用的是同一套卡牌网格与同一个 _deck_gyro_view，
	# 所以这里按「当前开着哪个网格」选目标，两处都能有透视倾斜。
	var grid: HFlowContainer = deck_viewer_grid
	if knowledge_open:
		grid = knowledge_grid      # 图鉴的优先级最高：它盖在开始页上，不会与另两个同时开
	elif not _deck_open and dispatch_panel != null and dispatch_panel.visible:
		grid = dispatch_grid
	if grid == null:
		return
	for view in grid.get_children():
		if not is_instance_valid(view):
			continue
		_step_card_gyro(view, _card_gyro_target(view, mouse, view == _deck_gyro_view), delta)


## 详情大牌的陀螺仪：鼠标压在**这张放大牌**上时，整张牌跟着做同样的 3D 倾斜 ——
## 与网格里悬停一张牌是同一种手感，只是牌已经放大展示在左边了。
##
## 大牌是静态展示（mouse_filter = IGNORE，事件不会到它），所以这里每帧自己算命中。
## 命中用逆变换，兼容缩放后的详情卡。
## mouse_override 同 _update_card_hover，仅供自动化测试顶替真实鼠标。
func _process_detail_gyro(delta: float, mouse_override: Vector2 = Vector2.INF) -> void:
	var targets: Array = []
	if card_detail != null and card_detail.visible and _detail_big_card != null and is_instance_valid(_detail_big_card):
		targets.append(_detail_big_card)
	if knowledge_detail != null and knowledge_detail.visible and _knowledge_big_card != null and is_instance_valid(_knowledge_big_card):
		targets.append(_knowledge_big_card)
	if targets.is_empty():
		return
	var mouse := mouse_override if mouse_override != Vector2.INF else get_viewport().get_mouse_position()
	for big in targets:
		var active := preload("res://scripts/card_geometry.gd").contains(big, mouse)
		_step_card_gyro(big, _card_gyro_target(big, mouse, active), delta)


func _on_viewer_card_click(event: InputEvent, view: Control, card: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_poke_card(view)
		_show_card_detail(view, card)


## 悬停黄框。⚠ 必须用「这张牌**自己的**」悬停样式，不能一律 card_style(true)：
## 知识卡图鉴里未收集的卡是灰纸底，套用行动卡那套样式会让它一被划过就"亮"起来
## （真窗口回归实测抓到：灰卡只要悬停过一次，底色就永久变成纸卡）。
func _apply_yellow_frame(view: Control) -> void:
	var panel: PanelContainer = view.get_meta("panel")
	if view.has_meta("hover_style"):
		panel.add_theme_stylebox_override("panel", view.get_meta("hover_style"))
	else:
		panel.add_theme_stylebox_override("panel", VisualTheme.card_style(true))


## 还原成**这张牌自己的**基础底色（同理，不能硬编码 card_style()）
func _remove_yellow_frame(view: Control) -> void:
	var panel: PanelContainer = view.get_meta("panel")
	if view.has_meta("base_style"):
		panel.add_theme_stylebox_override("panel", view.get_meta("base_style"))
	else:
		panel.add_theme_stylebox_override("panel", VisualTheme.card_style())


## 卡牌详情：左大牌 + 右介绍框（打字机）；大牌从被点击处平移放大投射到左侧展示位
func _show_card_detail(view: Control, card: Dictionary) -> void:
	card_detail.visible = true
	card_detail.set_meta("closing", false)
	if _detail_big_card != null and is_instance_valid(_detail_big_card):
		_detail_big_card.queue_free()
		_detail_big_card = null
	var made_big := _make_card(card)
	var big: PanelContainer = made_big["panel"]
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big.pivot_offset = Vector2(61, 82.5)
	_bind_card_gyro(big)
	big.set_meta("gyro_x", 0.0)
	big.set_meta("gyro_y", 0.0)
	_detail_big_card = big
	big.set_meta("source_view", view)
	_poke_card(big)
	# 起始：被点击卡牌的屏幕中心；终点：左侧展示区中心
	var src_center := view.get_global_rect().get_center()
	var dst_center := card_detail_card.get_global_rect().get_center()
	var inv := card_detail.get_global_transform().affine_inverse()
	var src_local: Vector2 = inv * src_center - big.pivot_offset
	var dst_local: Vector2 = inv * dst_center - big.pivot_offset
	big.position = src_local
	big.scale = Vector2.ONE
	card_detail.add_child(big)
	# 投射动画：平移 + 放大
	var fly := big.create_tween()
	big.set_meta("fly_tween", fly)
	fly.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(big, "position", dst_local, 0.4)
	fly.parallel().tween_property(big, "scale", Vector2(1.8, 1.8), 0.4)
	card_detail_title.text = card["name"]
	card_detail_body.text = _card_detail_text(card)
	card_detail_body.visible_characters = 0
	var total := card_detail_body.get_total_character_count()
	var tw := card_detail_body.create_tween()
	tw.set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(card_detail_body, "visible_characters", total, clampf(total * 0.03, 0.4, 2.5))


func _card_detail_text(card: Dictionary) -> String:
	var body := "[color=#8a8a8a]类别：%s　成本：%d 万[/color]\n\n" % [CATEGORY_NAMES[card["category"]], card["cost"]]
	body += "%s\n\n" % card["desc"]
	body += "[b]档位效果[/b]\n"
	for tier in ["basic", "effective", "deep"]:
		var t: Dictionary = card["tiers"][tier]
		var parts: Array = []
		for e in t["effects"]:
			var d: int = e["delay"]
			var suffix := "（%d 回合后）" % d if d > 0 else ""
			parts.append("%s %+d%s" % [GameState.METRIC_NAMES[e["metric"]], int(e["delta"]), suffix])
		# 顺带把每一档的价格印出来（图鉴是策划比价的地方，价格与效果要挨着看）
		body += "· %s（%d 万）：%s%s\n" % [GameState.TIER_NAMES[tier],
			GameState.tier_cost(str(card["id"]), tier), "、".join(parts),
			"　← 当前档位" if tier == play_tier else ""]
	if card.has("side_note") and not card["side_note"].is_empty():
		for k in card["side_note"]:
			body += "\n[color=#ffb060]※ %s[/color]" % card["side_note"][k]
	return body


func _close_card_detail() -> void:
	card_detail.visible = false


func _on_card_detail_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_detail_click(event, card_detail, _detail_big_card, _close_card_detail)

func _handle_detail_click(event: InputEventMouseButton, detail: Control, big: Control, close: Callable) -> void:
	if detail.get_meta("closing", false): return
	var point := detail.get_global_transform() * event.position
	if big and is_instance_valid(big) and preload("res://scripts/card_geometry.gd").contains(big, point):
		_poke_card(big)
		return
	var info: Control = detail.get_meta("info")
	if info.get_global_rect().has_point(point): return
	if big == null or not is_instance_valid(big) or (wetland and wetland.reduced_motion):
		close.call()
		return
	detail.set_meta("closing", true)
	var old: Tween = big.get_meta("fly_tween", null)
	if old and old.is_valid(): old.kill()
	var source: Control = big.get_meta("source_view", null)
	var position := big.position
	if source and is_instance_valid(source):
		position = detail.get_global_transform().affine_inverse() * _card_gyro_center(source) - big.pivot_offset
	var fly := big.create_tween()
	big.set_meta("fly_tween", fly)
	fly.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(big, "position", position, 0.22)
	fly.parallel().tween_property(big, "scale", Vector2.ONE, 0.22)
	fly.tween_callback(close)


## 卡牌详情弹层（覆盖在牌库查看器之上）
func _build_card_detail() -> void:
	card_detail = Control.new()
	card_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	card_detail.visible = false
	deck_viewer.add_child(card_detail)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_card_detail_dim_input)
	card_detail.add_child(dim)

	card_detail_card = CenterContainer.new()
	card_detail_card.anchor_left = 0.0
	card_detail_card.anchor_right = 0.5
	card_detail_card.anchor_top = 0.0
	card_detail_card.anchor_bottom = 1.0
	card_detail_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_detail.add_child(card_detail_card)

	var info := PanelContainer.new()
	info.anchor_left = 0.52
	info.anchor_right = 0.98
	info.anchor_top = 0.08
	info.anchor_bottom = 0.92
	_panel_style(info, Color(0.24, 0.17, 0.11, 0.96))
	card_detail.add_child(info)
	card_detail.set_meta("info", info)
	info.mouse_filter = Control.MOUSE_FILTER_STOP

	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 10)
	info.add_child(iv)

	card_detail_title = _make_label("", 30, Color(1, 0.9, 0.55))
	card_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(card_detail_title)

	var sep := HSeparator.new()
	iv.add_child(sep)

	card_detail_body = RichTextLabel.new()
	card_detail_body.bbcode_enabled = true
	card_detail_body.fit_content = true
	card_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_detail_body.add_theme_font_size_override("normal_font_size", _snap_px(16))
	card_detail_body.add_theme_color_override("default_color", Color(0.96, 0.94, 0.9))
	iv.add_child(card_detail_body)

	iv.add_child(_make_label("点击牌面和解说栏之外的背景返回", 12, Color("8eaaa8")))


# ==================== 知识卡图鉴（主页入口）====================
## 主页「知识卡」按钮 → 全屏图鉴。交互与反馈**照搬牌库查看器**：
## 同一套卡牌网格、同一个悬停浮起 + 黄框 + 陀螺仪透视倾斜、同一套逐张发牌动画、
## 同一个「点一下 → 大牌飞到左边 + 右边打字机」的详情弹层。
##
## 两处不同（都是刻意的）：
##   ① 未收集的卡整张走灰调、不透露名称与类别，正中一个「？」；
##   ② 它挂在自己的 CanvasLayer(11) 上，因为入口在开始页，而开始页在 MenuLayer(10)。
##
## 构建只在 _build_ui 里跑一次；内容每次打开重建（刚打完一局回来立刻点亮新卡）。

func _build_knowledge_viewer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "KnowledgeViewerLayer"
	layer.layer = 11        # 盖在 MenuLayer(10) 之上 —— 开始页的标题与选项都要让位
	add_child(layer)

	knowledge_viewer = Control.new()
	knowledge_viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	knowledge_viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	knowledge_viewer.visible = false
	layer.add_child(knowledge_viewer)

	# 与牌库同款压暗：开始页的沙盘背景在底下仍然隐约可见
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	knowledge_viewer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 70
	box.offset_right = -70
	box.offset_top = 40
	box.offset_bottom = -40
	box.add_theme_constant_override("separation", 12)
	knowledge_viewer.add_child(box)

	var title_bar := HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 10)
	box.add_child(title_bar)

	var title := _make_label("知识卡图鉴", 28, Color(1, 0.9, 0.55))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_bar.add_child(title)

	knowledge_count_label = _make_label("", 16, Color(0.72, 0.88, 0.92))
	knowledge_count_label.custom_minimum_size = Vector2(150, 0)
	knowledge_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	knowledge_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_bar.add_child(knowledge_count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	# 与牌库同一处理：四周留内边距，免得顶行/左列卡在放大漂浮时被裁剪
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	scroll.add_child(margin)

	knowledge_grid = HFlowContainer.new()
	knowledge_grid.add_theme_constant_override("h_separation", 14)
	knowledge_grid.add_theme_constant_override("v_separation", 14)
	knowledge_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(knowledge_grid)

	# 与牌库查看器同一个措辞（那边底部也是「关闭」），
	# 免得和图鉴里的详情弹层（「返回」）撞名 —— 两个白字按钮叠在一起会分不清点哪个。
	var close := _make_button("关闭", _close_knowledge_viewer, 20)
	close.custom_minimum_size = Vector2(0, 48)
	box.add_child(close)

	_build_knowledge_detail()


func _show_knowledge_panel() -> void:
	_open_knowledge_viewer()


func _open_knowledge_viewer() -> void:
	if knowledge_viewer.visible:
		return
	knowledge_viewer.visible = true
	# 开始页的标题与选项列先让位（图鉴是一整屏）
	menu_col.visible = false
	_deck_gyro_view = null

	# 重建全部卡牌（每次打开都按「当前收集状态」重铺 —— 刚打完一局回来，
	# 新收集到的卡要立刻点亮，不能靠缓存）
	for c in knowledge_grid.get_children():
		knowledge_grid.remove_child(c)
		c.queue_free()
	_deck_gyro_view = null

	knowledge_count_label.text = "已收集 %d / %d" % [Knowledge.collected_count(), Knowledge.total_count()]

	var views: Array = []
	for kid in Knowledge.all_ids():
		var collected: bool = Knowledge.is_collected(kid)
		var panel: PanelContainer = _make_knowledge_card(kid, collected)
		var view := _make_gyro_card_view(panel)
		# 悬停 / 取消悬停要用「这张牌自己的」两套底色（未收集的是灰纸，不是行动卡那张纸卡）
		view.set_meta("base_style", _knowledge_card_style(collected))
		view.set_meta("hover_style", _knowledge_card_style(collected, true))
		view.tooltip_text = _knowledge_tooltip(kid, collected)
		view.scale = Vector2(0.3, 0.3)
		view.modulate.a = 0.0
		# 悬停 / 移出直接复用牌库那对函数（它们只看 meta["panel"]，与卡内容无关）
		view.mouse_entered.connect(_on_viewer_card_hover.bind(view, {}))
		view.mouse_exited.connect(_on_viewer_card_unhover.bind(view))
		view.gui_input.connect(_on_knowledge_card_click.bind(view, kid))
		knowledge_grid.add_child(view)
		views.append(view)

	# 等一帧布局完成后逐张发牌（与牌库同节奏）
	await get_tree().process_frame
	for i in views.size():
		var p: Control = views[i]
		var tw := p.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector2.ONE, 0.28).set_delay(i * 0.03)
		tw.parallel().tween_property(p, "modulate:a", 1.0, 0.18).set_delay(i * 0.03)


func _close_knowledge_viewer() -> void:
	if knowledge_viewer == null:
		return
	knowledge_detail.visible = false
	knowledge_viewer.visible = false
	_deck_gyro_view = null
	menu_col.visible = true


func _on_knowledge_card_click(event: InputEvent, view: Control, kid: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_poke_card(view)
		_show_knowledge_detail(view, kid)


func _knowledge_tooltip(kid: String, collected: bool) -> String:
	if not collected:
		return "尚未收集的知识卡\n\n在游戏里触发它之后，这里会显示完整资料。"
	var k: Dictionary = GameState.KNOWLEDGE_CARDS[kid]
	return "%s\n\n%s" % [str(k["short"]), str(k["ecology"])]


## 知识卡卡面（图鉴网格 / 详情大图共用）。
## 与 _make_card 同规格的 122×165；未收集时整张走灰调、内容只留「？」。
func _make_knowledge_card(kid: String, collected: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_script(preload("res://scripts/card_hit_panel.gd"))
	panel.custom_minimum_size = Vector2(122, 165)
	panel.size = Vector2(122, 165)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", _knowledge_card_style(collected))
	var k: Dictionary = GameState.KNOWLEDGE_CARDS.get(kid, {})
	# category 传**知识卡类别**（植物 / 鸟类 / …）：画好的卡面按类别取，卡名由 PixelCardArt 写到
	# 卡面中间那块空白里。未收集的不传类别 —— 统一用「未知」卡面，不泄露它属于哪一类。
	PixelCardArt.add_face(panel, str(k.get("name", "")) if collected else "？",
		"知识卡" if collected else "未收集", not collected, "",
		collected and kid == "egg_dixinhu", str(k.get("category", "")) if collected else "")
	if collected and kid == "egg_dixinhu":
		var rim := ColorRect.new()
		rim.name = "KnowledgeFoil"
		rim.set_meta("card_gyro_overlay", true)
		rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var foil := ShaderMaterial.new()
		foil.shader = preload("res://scripts/knowledge_foil.gdshader")
		foil.set_shader_parameter("card_mask", PixelCardArt.KNOWLEDGE_FACE_EGG)
		rim.material = foil
		panel.add_child(rim)
		rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return panel


## 测试皮肤的框线与行动卡共用；未收集状态由像素卡图的调暗保留。
func _knowledge_card_style(_collected: bool, hovered: bool = false) -> StyleBoxFlat:
	return VisualTheme.card_style(hovered)


func _knowledge_category_color(cat: String) -> Color:
	return KNOWLEDGE_CATEGORY_COLORS.get(cat, Color("8a8f93"))


## 按 KNOWLEDGE_ART_TILE 取一格图集片。行动卡用的是 VisualTheme.illustration（按类别列 + id hash），
## 知识卡的类别和行动卡三分法对不上，所以直接自己拼 AtlasTexture。
func _knowledge_art(kid: String) -> Texture2D:
	if kid == "egg_dixinhu":
		return preload("res://assets/dixinhu.jpg")
	var tile_pos: Vector2i = KNOWLEDGE_ART_TILE.get(kid, Vector2i(0, 0))
	var art: Texture2D = VisualTheme.ART
	var tile := Vector2(art.get_width() / 3.0, art.get_height() / 2.0)
	var atlas := AtlasTexture.new()
	atlas.atlas = art
	atlas.region = Rect2(Vector2(tile_pos) * tile, tile)
	atlas.filter_clip = true
	return atlas


## 详情：左大牌 + 右介绍框（打字机）—— 与牌库的卡牌详情同一套演出。
## 未收集的卡不透露任何资料，标题与正文都只给「？」。
func _show_knowledge_detail(view: Control, kid: String) -> void:
	var collected: bool = Knowledge.is_collected(kid)
	knowledge_detail.visible = true
	knowledge_detail.set_meta("closing", false)
	if _knowledge_big_card != null and is_instance_valid(_knowledge_big_card):
		_knowledge_big_card.queue_free()
		_knowledge_big_card = null
	var big: PanelContainer = _make_knowledge_card(kid, collected)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big.pivot_offset = Vector2(61, 82.5)
	_bind_card_gyro(big)
	big.set_meta("gyro_x", 0.0)
	big.set_meta("gyro_y", 0.0)
	_knowledge_big_card = big
	big.set_meta("source_view", view)
	_poke_card(big)
	# 起始：被点击卡牌的屏幕中心；终点：左侧展示区中心
	var src_center := view.get_global_rect().get_center()
	var dst_center := knowledge_detail_card.get_global_rect().get_center()
	var inv := knowledge_detail.get_global_transform().affine_inverse()
	var src_local: Vector2 = inv * src_center - big.pivot_offset
	var dst_local: Vector2 = inv * dst_center - big.pivot_offset
	big.position = src_local
	big.scale = Vector2.ONE
	knowledge_detail.add_child(big)
	var fly := big.create_tween()
	big.set_meta("fly_tween", fly)
	fly.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(big, "position", dst_local, 0.4)
	fly.parallel().tween_property(big, "scale", Vector2(1.8, 1.8), 0.4)
	knowledge_detail_title.text = str(GameState.KNOWLEDGE_CARDS[kid]["name"]) if collected else "？？？"
	knowledge_detail_body.text = _knowledge_detail_text(kid, collected)
	knowledge_detail_body.visible_characters = 0
	var total := knowledge_detail_body.get_total_character_count()
	var tw := knowledge_detail_body.create_tween()
	tw.set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(knowledge_detail_body, "visible_characters", total, clampf(total * 0.03, 0.4, 2.5))


func _knowledge_detail_text(kid: String, collected: bool) -> String:
	if not collected:
		return "[color=#8a8a8a]未收集[/color]\n\n这张知识卡还没有收集到。在游戏里触发它之后，这里会显示它的完整资料。\n\n[b]？[/b]"
	var k: Dictionary = GameState.KNOWLEDGE_CARDS[kid]
	if kid == "egg_dixinhu":
		return "[color=#e9b9ff]制作组彩蛋 · 狄鑫斛[/color]\n\n%s\n\n[b]画作作者[/b]：Oliveira\n[b]创作来源[/b]：%s\n\n%s\n%s" % [k["short"], k["origin"], k["ecology"], k["management"]]
	var body := "[color=#8a8a8a]类别：%s[/color]\n\n" % str(k["category"])
	if k.has("level"):
		body += "[color=#8a8a8a]%s[/color]\n\n" % str(k["level"])
	# 关联标签（与「危机 - 对策」同一套词表）：本回合打过带这些标签的牌，这张卡更容易出现
	var ktags: Array = k.get("tags", [])
	if not ktags.is_empty():
		body += "[color=#8a8a8a]关联行动：%s[/color]\n\n" % " / ".join(ktags)
	body += "%s\n\n" % str(k["short"])
	body += "[b]生态角色[/b]：%s\n\n" % str(k["ecology"])
	body += "[b]当前威胁[/b]：%s\n\n" % str(k["threat"])
	body += "[b]管理建议[/b]：%s" % str(k["management"])
	body += _knowledge_source_text(k)
	return body


func _knowledge_source_text(card: Dictionary) -> String:
	if not card.has("source_url"):
		return ""
	return "\n\n[b]资料来源[/b]：[url=%s]%s[/url]" % [card["source_url"], card["source_title"]]


func _on_knowledge_source_clicked(meta: Variant) -> void:
	var url := str(meta)
	for card in GameState.KNOWLEDGE_CARDS.values():
		if url.begins_with("https://") and url == str(card.get("source_url", "")):
			OS.shell_open(url)
			return


func _close_knowledge_detail() -> void:
	knowledge_detail.visible = false


func _on_knowledge_detail_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_detail_click(event, knowledge_detail, _knowledge_big_card, _close_knowledge_detail)


## 知识卡详情弹层（覆盖在图鉴查看器之上）
func _build_knowledge_detail() -> void:
	knowledge_detail = Control.new()
	knowledge_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	knowledge_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	knowledge_detail.visible = false
	knowledge_viewer.add_child(knowledge_detail)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_knowledge_detail_dim_input)
	knowledge_detail.add_child(dim)

	knowledge_detail_card = CenterContainer.new()
	knowledge_detail_card.anchor_left = 0.0
	knowledge_detail_card.anchor_right = 0.5
	knowledge_detail_card.anchor_top = 0.0
	knowledge_detail_card.anchor_bottom = 1.0
	knowledge_detail_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knowledge_detail.add_child(knowledge_detail_card)

	var info := PanelContainer.new()
	info.anchor_left = 0.52
	info.anchor_right = 0.98
	info.anchor_top = 0.08
	info.anchor_bottom = 0.92
	_panel_style(info, Color(0.24, 0.17, 0.11, 0.96))
	knowledge_detail.add_child(info)
	knowledge_detail.set_meta("info", info)
	info.mouse_filter = Control.MOUSE_FILTER_STOP

	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 10)
	info.add_child(iv)

	knowledge_detail_title = _make_label("", 30, Color(1, 0.9, 0.55))
	knowledge_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	knowledge_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(knowledge_detail_title)

	iv.add_child(HSeparator.new())

	knowledge_detail_body = RichTextLabel.new()
	knowledge_detail_body.bbcode_enabled = true
	knowledge_detail_body.fit_content = false
	knowledge_detail_body.scroll_active = true
	knowledge_detail_body.meta_clicked.connect(_on_knowledge_source_clicked)
	knowledge_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	knowledge_detail_body.add_theme_font_size_override("normal_font_size", _snap_px(16))
	knowledge_detail_body.add_theme_color_override("default_color", Color(0.96, 0.94, 0.9))
	iv.add_child(knowledge_detail_body)

	iv.add_child(_make_label("点击牌面和解说栏之外的背景返回", 12, Color("8eaaa8")))


func _on_start_pressed() -> void:
	var s := seed_input.text.strip_edges()
	if s == "" or s == "0":
		GameState.run_seed = 0
	elif s.is_valid_int() and int(s) >= 0:
		GameState.run_seed = int(s)
	else:
		menu_hint.text = "种子需为非负整数（留空则随机）"
		return
	_clear_save()           # 放弃（判负）上一局暂停的进度
	# 作废可能还在跑的算分动画（代次 +1）。新局的手牌稍后会由 _build_hand_panel()
	# 整体重建并清空 card_infos，所以这里不必手工复位卡牌状态。
	_score_anim_id += 1
	_score_animating = false
	_playing = true
	_hide_menu()
	GameState.reset_game()
	# 新的一局：拉杆回到默认的有效档（直接赋值 + 只刷拉杆外观 ——
	# 此刻手牌还是上一局的残留对象，不能走 _set_play_tier 去刷牌面）
	play_tier = "effective"
	_refresh_lever_visuals(false)
	_update_hud()
	_update_3d()
	_play_hud_enter()      # 开局登场：两块面板从屏幕外滑入

	# 本局天赋：第一回合开始前显示一次（0 条也说明一句，顺带公布本局种子）
	_show_run_talents_popup()


## 开局天赋弹窗：本局随机附赠的词条（0~3 条）。
## 这是新一局的第一屏 —— 玩家点掉后才轮到「第 1 回合 · 事件」弹窗（若有）与分配资金。
func _show_run_talents_popup() -> void:
	var ids: Array = Talents.granted
	var body := "[color=#8a8a8a]本局种子：%d[/color]\n\n" % GameState.run_seed
	if ids.is_empty():
		body += "本局没有随机到额外天赋。\n"
	else:
		body += "本局天赋（%d 项）\n" % ids.size()
		for id in ids:
			var t: Dictionary = Talents.entry(str(id))
			if t.is_empty():
				continue
			body += "\n[b]%s[/b]　%s" % [t["name"], t["desc"]]
	if Talents.run_tree_count() > 0:
		body += "\n\n[b]永久研修（%d 项，本局固定）[/b]\n" % Talents.run_tree_count() + Talents.run_tree_effect_summary()
		body += "\n[color=#9dd5bd]在左上角永久研修提示中查看节点详情。[/color]"
	else:
		body += "\n\n[color=#9dd5bd]暂无永久研修。通关可获得灵感，在主菜单天赋树中分配。[/color]"
	_show_popup("本局天赋", body, "开始", _on_run_talents_done)


## 天赋弹窗点掉之后：把可能被它顶掉的「第 1 回合 · 事件」弹窗按原顺序补回来。
## 事件弹窗是在 GameState.reset_game() 里同步弹出的，天赋弹窗必须压在它前面，
## 所以只能这样接力（不能反过来改弹窗顺序：天赋是掷完种子才知道的）。
func _on_run_talents_done() -> void:
	if _current_phase == "popup_event" and _current_event != "":
		_show_popup("第 %d 回合 · 事件" % GameState.turn, _current_event, "开始分配资金", _enter_allocate)
	else:
		_enter_allocate()


## 开局登场：左侧「回合 / 资金」面板从屏幕左外滑入，右侧「生态指标」面板从右外滑入。
## 方向与 _slide_side_panels 保持一致，落点就是两块面板的常驻位置。
## 手感：QUART + EASE_OUT（起步快、收尾稳），右侧晚 0.08s 出发，两侧同时淡入。
func _play_hud_enter() -> void:
	if left_panel == null or right_panel == null:
		return
	const L_HOME_L := 18.0        # 左面板常驻位置
	const L_HOME_R := 222.0
	const R_HOME_L := -210.0     # 右面板常驻位置（锚在屏幕右缘，负值向左）
	const R_HOME_R := -18.0
	const GAP := 12.0            # 屏幕外的额外间隙
	const DUR := 0.55            # 滑入时长（秒）
	const LAG := 0.08            # 右侧延后出发

	# 先瞬移到屏幕外（同帧完成，渲染时看不到中间状态）
	left_panel.offset_left = -(L_HOME_R - L_HOME_L) - GAP
	left_panel.offset_right = -GAP
	right_panel.offset_left = GAP
	right_panel.offset_right = (R_HOME_R - R_HOME_L) + GAP
	left_panel.modulate.a = 0.0
	right_panel.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(left_panel, "offset_left", L_HOME_L, DUR)
	tw.tween_property(left_panel, "offset_right", L_HOME_R, DUR)
	tw.tween_property(left_panel, "modulate:a", 1.0, DUR * 0.7)
	tw.tween_property(right_panel, "offset_left", R_HOME_L, DUR).set_delay(LAG)
	tw.tween_property(right_panel, "offset_right", R_HOME_R, DUR).set_delay(LAG)
	tw.tween_property(right_panel, "modulate:a", 1.0, DUR * 0.7).set_delay(LAG)


func _make_metric_row(metric: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	vb.add_child(head)
	# 图标留引用：算分动画要让它放大 + 抖动（原来这里是匿名创建的，拿不到节点）
	var icon := _make_icon(_icon_grid_for(metric), METRIC_COLORS[metric], 14)
	icon.set_script(preload("res://scripts/metric_icon_effect.gd"))
	icon.effects_owner = self
	head.add_child(icon)
	head.add_child(_make_label(GameState.METRIC_NAMES[metric], 12, Color(0.95, 0.95, 0.95)))
	var val := _make_label("0", 12, METRIC_COLORS[metric])
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(val)

	# 进度条 + 阈值红线：红线作为进度条的兄弟节点，避免被指标颜色 modulate 染色
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, 11)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", VisualTheme.box(Color("0b252e"), Color("42615b"), 0))
	bar.add_theme_stylebox_override("fill", VisualTheme.box(METRIC_COLORS[metric], METRIC_COLORS[metric].lightened(0.2), 0))
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(bar)
	var ripple := ColorRect.new()
	ripple.set_script(preload("res://scripts/metric_bar_ripple.gd"))
	ripple.name = "MetricRipple"
	ripple.bar = bar
	ripple.effects_owner = self
	ripple.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ripple.offset_left = 2
	ripple.offset_right = -2
	ripple.offset_top = 2
	ripple.offset_bottom = -2
	wrap.add_child(ripple)

	var band: ColorRect
	var high_line: ColorRect
	var reference_label: Label
	if metric == "water_level":
		band = ColorRect.new()
		band.color = Color(0.55, 0.95, 0.70, 0.24)
		band.anchor_bottom = 1.0
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(band)

	# 阈值红线（像素竖线）：指标低于此线即判负；锚定在阈值比例处，随难度更新
	var line := ColorRect.new()
	line.color = Color(1.0, 0.2, 0.2, 0.95)
	line.anchor_left = 0.2
	line.anchor_right = 0.2
	line.offset_left = -1
	line.offset_right = 1
	line.anchor_top = 0.0
	line.anchor_bottom = 1.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(line)
	if metric == "water_level":
		line.color = Color("b6ebae")
		high_line = ColorRect.new()
		high_line.color = line.color
		high_line.anchor_bottom = 1.0
		high_line.offset_left = -1
		high_line.offset_right = 1
		high_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(high_line)

	vb.add_child(wrap)
	if metric == "water_level":
		reference_label = _make_label("", 10, Color("b6ebae"))
		vb.add_child(reference_label)

	metric_bars[metric] = {"bar": bar, "val": val, "line": line, "row": vb, "icon": icon,
		"band": band, "high_line": high_line, "reference_label": reference_label, "ripple": ripple}
	return vb


## 按「难度线 + 每指标偏移」更新指标条上的阈值红线位置
## 六项的红线不再一样长：哪项更脆，线就更靠右，玩家一眼看得出来。
func _update_threshold_lines() -> void:
	for metric in metric_bars:
		var line: ColorRect = metric_bars[metric].get("line")
		if metric == "water_level":
			var rule: Dictionary = GameState.water_reference()
			var pressure: Dictionary = GameState.water_pressure(int(GameState.metrics.get(metric, 50)))
			var low_ratio: float = float(rule["low"]) / 100.0
			var high_ratio: float = float(rule["high"]) / 100.0
			line.anchor_left = low_ratio
			line.anchor_right = low_ratio
			var high: ColorRect = metric_bars[metric]["high_line"]
			high.anchor_left = high_ratio
			high.anchor_right = high_ratio
			var band: ColorRect = metric_bars[metric]["band"]
			band.anchor_left = low_ratio
			band.anchor_right = high_ratio
			var reference: Label = metric_bars[metric]["reference_label"]
			var status: String = {"safe": "适宜", "low": "偏低", "high": "偏高"}[pressure["side"]]
			reference.text = "%s参考 %d–%d · %s" % [GameState.SEASON_NAMES[GameState.current_season()], rule["low"], rule["high"], status]
			reference.add_theme_color_override("font_color", Color("b6ebae") if pressure["side"] == "safe" else Color("ffcc66"))
			continue
		if line != null:
			var ratio: float = GameState.failure_threshold_for(metric) / 100.0
			line.anchor_left = ratio
			line.anchor_right = ratio


# ==================== 指标悬停小窗 ====================
## 鼠标移到某一项指标上时，跟随指针弹出的小窗：
## 本回合自然演化会掉多少 / 回合末大概落到哪 / 生态红线在哪 / 余量还剩多少；
## 若已有「已预警、下回合结算时才爆发」的危机且正好打到这一项，也提前告诉你。
## 数字全部来自 GameState.metric_hover_preview()（只读推演），这里只负责显示，不参与任何判定。
## ⚠ 只给结果，不给解释：指标之间的因果链、难度对衰减的放大，都是**隐性参数**，
##   玩家应该自己从数字里总结，不能写在这块板上。
const METRIC_TIP_W := 294.0


func _build_metric_tip(parent: Node) -> void:
	metric_tip = PanelContainer.new()
	metric_tip.custom_minimum_size = Vector2(METRIC_TIP_W, 0)
	metric_tip.anchor_left = 0.0
	metric_tip.anchor_top = 0.0
	metric_tip.anchor_right = 0.0
	metric_tip.anchor_bottom = 0.0
	metric_tip.visible = false
	_panel_style(metric_tip, Color(0.16, 0.12, 0.08, 0.96))
	parent.add_child(metric_tip)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	metric_tip.add_child(vb)

	metric_tip_title = _make_label("", 14, Color(0.95, 0.95, 0.95))
	vb.add_child(metric_tip_title)

	metric_tip_body = RichTextLabel.new()
	metric_tip_body.bbcode_enabled = true
	metric_tip_body.fit_content = true
	metric_tip_body.scroll_active = false
	metric_tip_body.custom_minimum_size = Vector2(METRIC_TIP_W - 26, 0)
	# 全工程最后一处绕过 _snap_px 的字号（写死 13 → 像素字体 12px，会被缩放糊掉）。
	# 统一走 _snap_px 后落回 12px，与其它面板一致。
	metric_tip_body.add_theme_font_size_override("normal_font_size", _snap_px(13))
	metric_tip_body.add_theme_color_override("default_color", Color(0.90, 0.90, 0.88))
	vb.add_child(metric_tip_body)

	# 小窗只负责「看」：整棵子树都不接收鼠标。否则指针一进小窗，指标行的悬停就断了，会闪。
	_ignore_mouse(metric_tip)


## 递归关掉一棵子树的鼠标响应
func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


## 每帧判断鼠标是否落在某个指标行上：是 → 刷新内容并跟随指针；否 → 收起
## mouse_override 仅供自动化测试顶替真实鼠标，正常游戏不传（默认取真实鼠标位置）
func _update_metric_tip(mouse_override: Vector2 = Vector2.INF) -> void:
	if metric_tip == null:
		return
	if not _tip_allowed():
		metric_tip.visible = false
		_tip_metric = ""
		return
	var mp: Vector2 = mouse_override if mouse_override != Vector2.INF else get_viewport().get_mouse_position()
	var hovered := ""
	for metric in metric_bars:
		var row: Control = metric_bars[metric].get("row")
		if row != null and row.is_visible_in_tree() and row.get_global_rect().has_point(mp):
			hovered = str(metric)
			break
	if hovered == "":
		metric_tip.visible = false
		_tip_metric = ""
		return
	if hovered != _tip_metric:
		_tip_metric = hovered
		_tip_last_text = ""
	_fill_metric_tip(hovered)
	metric_tip.visible = true
	_place_metric_tip(mp)


## 什么时候允许显示：正常分配回合，且没有任何弹层盖在 HUD 上
func _tip_allowed() -> bool:
	# 算分动画期间关掉指标悬停小窗，否则鼠标扫过右侧面板弹的小窗会糊在算分小票上
	if _score_animating:
		return false
	if _current_phase != "allocate" or _paused or GameState.game_over:
		return false
	if right_panel == null or not right_panel.is_visible_in_tree():
		return false
	if popup_root != null and popup_root.visible:
		return false
	if crisis_root != null and crisis_root.visible:
		return false
	if warn_panel_root != null and warn_panel_root.visible:
		return false
	if deck_viewer != null and deck_viewer.visible:
		return false
	if menu_root != null and menu_root.visible:
		return false
	if pause_root != null and pause_root.visible:
		return false
	return true


## 小窗正文。每次都按当前数值重算 → 出牌/结算后数字不会停在上一回合
func _fill_metric_tip(metric: String) -> void:
	var p: Dictionary = GameState.metric_hover_preview(metric)
	metric_tip_title.text = "%s   %d" % [str(GameState.METRIC_NAMES.get(metric, metric)), int(p["cur"])]
	metric_tip_title.add_theme_color_override("font_color", METRIC_COLORS.get(metric, Color(0.92, 0.92, 0.92)))
	if metric == "water_level":
		_fill_water_metric_tip(p)
		return

	var cur: int = int(p["cur"])
	var kind: String = str(p["kind"])
	var nat_min: int = int(p["nat_min"])
	var nat_max: int = int(p["nat_max"])
	var end_min: int = int(p["end_min"])
	var end_max: int = int(p["end_max"])

	# 人鸟矛盾（暗线）：这一笔**并进「自然演化」那一栏**，不给它单独的醒目提示 ——
	# 玩家看到的是「自然演化 −N」，想明白为什么就自己把候鸟与食源的差距算一遍。
	# 只有被它扣的那两项（社区信任 / 候鸟种群）带上这笔；数值与实际结算同源（同一个入口）。
	var cf: Dictionary = p.get("conflict", {})
	var cf_pen: int = 0
	if bool(cf.get("active", false)) and (metric == "community" or metric == "birds"):
		cf_pen = int(cf["penalty"])
		nat_min -= cf_pen
		nat_max -= cf_pen
		end_min -= cf_pen
		end_max -= cf_pen

	# ① 本回合自然演化会掉多少（水位是随机，给区间）
	var dtxt := ""
	var dcol := "#8e9aa4"
	if kind == "random":
		dtxt = "%+d ~ %+d" % [nat_min, nat_max]
		dcol = "#ffcc66"
	elif nat_min == 0 and nat_max == 0:
		dtxt = "不变"
	elif nat_min > 0:
		dtxt = "%+d" % nat_min
		dcol = "#7ee08a"
	else:
		dtxt = "%+d" % nat_min
		dcol = "#ff8f7a"
	var rows: Array = []
	rows.append("[color=#cfd6dc]自然演化（含洪旱联动）[/color]   [color=%s][b]%s[/b][/color]" % [dcol, dtxt])
	# 刻意不写「为什么」：水质怎么拖累植被、植被怎么影响候鸟这一类因果，是留给玩家自己悟的隐性参数。
	# 人鸟矛盾同理：只报一个安静的小计，不给公式、不给原因
	if cf_pen > 0:
		rows.append("[color=#8e9aa4]· 其中人鸟矛盾 −%d[/color]" % cf_pen)

	# ② 回合末大概落到哪
	if kind == "random":
		rows.append("[color=#cfd6dc]回合末约[/color]   [b]%d ~ %d[/b]" % [end_min, end_max])
	else:
		rows.append("[color=#cfd6dc]回合末约[/color]   [b]%d[/b] %s" % [end_min, _tip_delta_suffix(cur, end_min)])

	# ③ 生态红线与两个余量
	# ⚠ 必须写清是哪个余量。它们**不相等**：
	#   当前余量   = 眼下的值 - 红线（水位 47、红线 37 → 10）
	#   回合末余量 = 按本回合自然演化的**最坏一头**算（47 - 10 = 37，再减 37 → 0）
	# 以前只写「余量」两个字，同一屏上又摆着 47 和 37，玩家会算成 10 而觉得是 bug。
	var line: int = int(p["line"])
	# ⚠ 余量也要用**调整后**的 end_min 算：同一个数不能两个口径（否则小窗上「回合末约 48」
	#   和「回合末余量 3」（红线 50 时该是 −2）会自相矛盾）。
	var margin: int = end_min - line
	var cur_margin: int = int(p["cur"]) - line
	var mcol := "#7ee08a"
	if margin < 0:
		mcol = "#ff5a5a"
	elif margin <= 3:
		mcol = "#ffcc66"
	var ccol := "#7ee08a"
	if cur_margin < 0:
		ccol = "#ff5a5a"
	elif cur_margin <= 3:
		ccol = "#ffcc66"
	rows.append("[color=#cfd6dc]生态红线[/color]   [color=#ff8080][b]%d[/b][/color]    [color=#cfd6dc]当前余量[/color] [color=%s][b]%d[/b][/color]" % [line, ccol, cur_margin])
	rows.append("[color=#cfd6dc]回合末余量[/color]   [color=%s][b]%d[/b][/color]" % [mcol, margin])
	# 难度怎么放大衰减也是隐性参数，不写出来（两档都玩两把自然就有数）
	# ⚠ 用调整后的 end_min 重新判「会不会跌破」：人鸟矛盾那一笔也算进去，
	#   否则小窗会一边显示回合末 48、一边说「仍在红线上」（红线 50）。
	if end_min < line:
		rows.append("[color=#ff5a5a][b]⚠ 回合末就会跌破生态红线[/b][/color]")
	elif margin <= 3:
		rows.append("[color=#ffcc66]⚠ 回合末将贴近生态红线[/color]")

	# ④ 预警中、下回合结算时才爆发的危机正好打到这一项
	if int(p["crisis_delta"]) != 0:
		rows.append("[color=#ffb060]⚠ 预警中：%s[/color]" % str(p["crisis_name"]))
		var tail := "会跌破生态红线" if bool(p["break_total"]) else "仍在生态红线上"
		rows.append("[color=#8e9aa4]· 下回合结算时 %+d → 约 %d，%s[/color]" % [int(p["crisis_delta"]), int(p["worst"]), tail])

	var txt := ""
	for r in rows:
		txt += str(r) + "\n"
	txt = txt.strip_edges()
	if txt != _tip_last_text:
		_tip_last_text = txt
		metric_tip_body.text = txt


func _fill_water_metric_tip(p: Dictionary) -> void:
	var rule: Dictionary = GameState.water_reference()
	var drift: Array = GameState.water_drift_range()
	var weather: Dictionary = GameState.year_hydrology()
	var pressure: Dictionary = GameState.water_pressure(int(p["cur"]))
	var season: String = GameState.current_season()
	var rows: Array[String] = []
	rows.append("[color=#b6ebae][b]%s·%s季参考 %d–%d[/b][/color]（含端点）" % [GameState.difficulty_name(), GameState.SEASON_NAMES[season], rule["low"], rule["high"]])
	rows.append(str(rule["theme"]))
	rows.append("本年水情：%s（自然涨落修正 %+d）" % [weather["name"], weather["shift"]])
	rows.append("水位不直接判负；过低干旱，过高淹水。")
	if pressure["side"] == "safe":
		rows.append("[color=#7ee08a]当前在参考区间内[/color]")
	else:
		rows.append("[color=#ffcc66]当前%s %d 点 · 生态压力 ×%.2f[/color]" % ["偏低" if pressure["side"] == "low" else "偏高", pressure["deviation"], pressure["multiplier"]])
	# 与顶部横幅同一条线：偏离 ≥ WATER_ALERT_MARGIN 点才升格成「预警」，区间内外的小抖动只写偏低/偏高。
	if int(pressure["deviation"]) >= GameState.WATER_ALERT_MARGIN:
		rows.append("[color=#ffb060]⚠ %s预警：已偏离参考区间 %d 点[/color]" % ["干旱" if pressure["side"] == "low" else "洪水", int(pressure["deviation"])])
	rows.append("自然涨落 [b]%+d ~ %+d[/b] → 回合末水位 [b]%d ~ %d[/b]" % [drift[0], drift[1], p["end_min"], p["end_max"]])
	var losses: Array[String] = []
	var outcomes: Array = GameState.natural_evolution_outcomes()
	for metric in GameState.METRIC_NAMES:
		var lo := 0
		var hi := -100
		for outcome in outcomes:
			var d: int = int(outcome["pressure_losses"].get(metric, 0))
			lo = mini(lo, d)
			hi = maxi(hi, d)
		if lo < 0:
			losses.append("%s %s" % [GameState.METRIC_NAMES[metric], "%+d" % lo if lo == hi else "%+d ~ %+d" % [lo, hi]])
	rows.append("[color=#ffb060]回合末洪旱额外损失（已含难度）：[/color]" if not losses.is_empty() else "[color=#7ee08a]预计回合末无洪旱额外损失[/color]")
	for loss in losses: rows.append("  " + loss)
	rows.append("[color=#8e9aa4]季内偏离平均计算：每 10 点 1 倍，上限 3 倍。[/color]")
	rows.append("自然恢复可减轻损失，不能抹去本季已有压力。")
	var next_season: String = GameState.SEASONS[(GameState.SEASONS.find(season) + 1) % 4]
	var next_rule: Dictionary = GameState.water_reference(next_season)
	if GameState.turn < GameState.TOTAL_TURNS:
		rows.append("下季%s：参考 %d–%d，提前留出调度空间。" % [GameState.SEASON_NAMES[next_season], next_rule["low"], next_rule["high"]])
	if int(p["crisis_delta"]) != 0:
		rows.append("[color=#ffb060]预警：%s，下回合水位 %+d[/color]" % [p["crisis_name"], p["crisis_delta"]])
	var txt := "\n".join(rows)
	if txt != _tip_last_text:
		_tip_last_text = txt
		metric_tip_body.text = txt


func _tip_delta_suffix(from_v: int, to_v: int) -> String:
	var d: int = to_v - from_v
	if d == 0:
		return "（不变）"
	return "（%+d）" % d


## 跟随指针：默认贴在指针左侧；指针右侧是右侧指标面板，所以再限一道「不许压住面板」
func _place_metric_tip(mp: Vector2) -> void:
	metric_tip.reset_size()
	var s: Vector2 = metric_tip.size
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var limit_x: float = vp.x - 8.0
	if right_panel != null and right_panel.is_visible_in_tree():
		limit_x = minf(limit_x, right_panel.get_global_rect().position.x - 8.0)
	var pos := Vector2(mp.x - s.x - 16.0, mp.y - s.y * 0.5)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, limit_x - s.x))
	# 窗口顶部 4~62px 是「当前事件横幅 + 危机预警日志条」，压住它们会看不清；
	# 能整个让到下面就让（悬停上面几项时会触发），否则再退回居中。
	if pos.y < 66.0 and 66.0 + s.y <= vp.y - 8.0:
		pos.y = 66.0
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vp.y - s.y - 8.0))
	metric_tip.position = pos


func _update_hud() -> void:
	_update_threshold_lines()
	var m: Dictionary = GameState.metrics
	# 算分动画期间**只**冻结指标条与数值 —— 这两样由动画逐项驱动，
	# 若在这里一次性刷到终值，动画还没播就先跳完了。
	# ⚠ 不能整体 return：所有 metrics_changed / funds_changed 都在动画开始**之前**
	#   就发完了，整体早退会让左侧「回合/资金/科研」停在旧值，2.8s 后再"啪"地跳一次。
	if not _score_animating:
		for metric in metric_bars:
			var bar: ProgressBar = metric_bars[metric]["bar"]
			var val: Label = metric_bars[metric]["val"]
			# 指标变化不是玩家直接操作 → 用动画"告知"变化（速查表：非用户触发可较长时长）
			var tw := bar.create_tween()
			tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(bar, "value", float(m[metric]), 0.35)
			val.text = str(m[metric])

	var t: int = GameState.turn
	turn_label.text = "第 %d / %d 回合" % [t, GameState.TOTAL_TURNS]
	var year: int = int((t - 1) / 4) + 1
	# 季节从 GameState 取（那里是唯一推导处），名字与旁白也一并取，
	# 免得界面自己再维护一份 %4 映射、跟机制层对不上。
	var season: String = GameState.current_season()
	season_label.text = "第 %d 年 · %s" % [year, GameState.SEASON_NAMES.get(season, "")]
	season_tagline.text = str(GameState.SEASON_TAGLINE.get(season, "")) + "\n" + str(GameState.year_hydrology()["name"])
	var season_index: int = GameState.SEASONS.find(season)
	if season_index >= 0 and season_index != _season_dial_index:
		_season_dial_index = season_index
		if season_dial != null:
			season_dial.turn_to(season_index, t > 1)
	spent_label.text = "已消耗：%d 万" % GameState.total_spent
	funds_label.text = "%d 万" % GameState.funds
	research_label.text = "科研点：%d" % GameState.research_points
	# 行动位上限随难度变化（简单 4 / 普通·困难 3），必须每帧从这个入口刷，
	# 不能在 _build_ui 里写死 —— 那时难度还没选。
	if action_hint != null:
		action_hint.text = "每回合最多 %d 个行动" % GameState.action_slots()
	_refresh_event_banner()
	_update_selected_label()
	_refresh_warn_bar()
	_refresh_run_talents()      # 左上「本局天赋」常驻行（内容没变时直接跳过）
	_refresh_action_buttons()   # 紧急调度 / 刷新手牌 的可用态


# ==================== 顶部态势横幅 ====================
## 顶部横幅显示的**永远是当前状态**，不是本回合开始时写死的那句话 ——
## _update_hud() 每次指标/资金/回合变化都会调它，所以水位一沉下去，
## 横幅下一帧就变成「干旱预警」；水位涨上来就变成「洪水预警」，不会出现
## 「水位 80 还挂着干旱」这种和游戏对不上的念稿（0.1.17 修的就是这个）。
## 唯一的例外是危机弹层：预警/爆发期间横幅让位给危机，弹层关掉后自动回到实时态势。
func _refresh_event_banner() -> void:
	if event_label == null:
		return
	var s: String = ""
	if _banner_override != "":
		s = _banner_override
	else:
		s = GameState.situation_banner()
	if s.strip_edges() == "":
		s = "暂无"
	if event_label.text != s:
		event_label.text = s


# ==================== 事件 / 结算 / 知识卡 / 报告 ====================
func _on_event(text: String) -> void:
	_current_event = text
	_current_phase = "popup_event"
	# 新回合的态势播报盖过上一回合残留的危机横幅
	_banner_override = ""
	_update_hud()
	hand_panel.visible = false
	bottom_right.visible = false
	tier_lever.visible = false
	_show_popup("第 %d 回合 · 事件" % GameState.turn, text, "开始分配资金", _enter_allocate)


## 画左上「本局天赋」常驻区：每局开局掷出的 0~3 条词条。
## ⚠ 本函数被 _update_hud() 调得很勤（指标/资金一变就调），所以拿签名做缓存：
##   词条列表没变就直接返回，绝不每帧重建节点。
func _refresh_run_talents() -> void:
	if talents_row == null:
		return
	var sig := ",".join(Talents.granted) + JSON.stringify(Talents.run_tree_ranks)
	if sig == _talents_sig:
		return
	_talents_sig = sig
	for c in talents_row.get_children():
		talents_row.remove_child(c)
		c.queue_free()
	if Talents.run_tree_count() > 0:
		var study := _make_label("永久研修：%d 节点" % Talents.run_tree_count(), 12, VisualTheme.MINT)
		study.mouse_filter = Control.MOUSE_FILTER_PASS
		study.tooltip_text = "本局固定的永久研修：\n" + Talents.run_tree_summary()
		talents_row.add_child(study)
	if Talents.granted.is_empty():
		talents_row.add_child(_make_label("本局无额外天赋", 12, Color(0.68, 0.66, 0.62)))
		return
	for id in Talents.granted:
		var t: Dictionary = Talents.entry(str(id))
		if t.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var nm := _make_label(str(t["name"]), 12, Color(1, 0.88, 0.55))
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nm)
		var ef := _make_label(str(t["desc"]), 11, Color(0.88, 0.90, 0.92))
		ef.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ef.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ef.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ef.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 名字长的词条不至于被裁
		row.add_child(ef)
		row.tooltip_text = "%s　%s" % [str(t["name"]), str(t["desc"])]
		talents_row.add_child(row)


func _enter_allocate() -> void:
	_current_phase = "allocate"
	_slide_side_panels(false)  # 新回合开始，侧边栏弹回
	# 季节首回合保底：保证每年开局手上有当季专属卡（见 GameState._ensure_one_season_card）
	current_hand = GameState.draw_cards(7 + int(Talents.get_bonus("cards")), GameState.is_season_opener())
	play_deal_anim = true
	_build_hand_panel()
	hand_panel.visible = true
	bottom_right.visible = true
	tier_lever.visible = true
	# 新回合：刷新按钮复原（上回合碎裂掉的碎片早已掉出屏幕，这里把本体恢复出来）
	_refresh_used_turn = -1
	# 档位冷却也一起归零：不然上一回合末尾刚拨过拉杆，新回合一开始就点不动。
	_lever_cooldown_ms = -6000
	if refresh_btn != null:
		refresh_btn.modulate.a = 1.0
	_close_dispatch_panel()
	_update_hud()


# ==================== 紧急调度 / 刷新手牌 ====================

## 刷新两个「花钱换牌」按钮的可用态与文案。
## 由 _update_hud() 频繁调用 —— 只改文本与 disabled，**绝不重建节点**。
func _refresh_action_buttons() -> void:
	if dispatch_btn != null:
		var cd: int = GameState.dispatch_cooldown_left()
		if not GameState.dispatched_cards.is_empty():
			dispatch_btn.text = "已调度 · 待结算"
			dispatch_btn.disabled = true
		elif cd > 0:
			dispatch_btn.text = "紧急调度 · 冷却 %d 回合" % cd
			dispatch_btn.disabled = true
		elif GameState.funds < GameState.dispatch_cost():
			dispatch_btn.text = "紧急调度 · %d 万（资金不足）" % GameState.dispatch_cost()
			dispatch_btn.disabled = true
		else:
			# 价格是**递增**的：本局每用过一次 +10 万，所以这里必须每次重算
			dispatch_btn.text = "紧急调度 · %d 万" % GameState.dispatch_cost()
			dispatch_btn.disabled = false
	if refresh_btn != null:
		if _refresh_used_turn == GameState.turn:
			refresh_btn.text = "本回合已刷新"
			refresh_btn.disabled = true
		elif GameState.funds < GameState.REFRESH_HAND_COST:
			refresh_btn.text = "刷新手牌 · %d 万（资金不足）" % GameState.REFRESH_HAND_COST
			refresh_btn.disabled = true
		else:
			refresh_btn.text = "刷新手牌 · %d 万" % GameState.REFRESH_HAND_COST
			refresh_btn.disabled = false


## 刷新手牌：花 5 万把整手重抽一遍（当季卡池）。每回合限一次。
## 用掉后按钮碎裂掉出屏幕，下回合 _enter_allocate() 复原。
func _on_refresh_hand() -> void:
	if _current_phase != "allocate" or _score_animating or _sort_animating:
		return
	if _refresh_used_turn == GameState.turn:
		return
	if not GameState.spend(GameState.REFRESH_HAND_COST):
		return
	_refresh_used_turn = GameState.turn
	current_hand = GameState.draw_cards(7 + int(Talents.get_bonus("cards")))
	play_deal_anim = true
	_build_hand_panel()
	_play_refresh_break_animation()
	_update_hud()


## UI 根：_build_ui() 里那个 CanvasLayer（名字 "UICanvas"）。
## 碎片、全屏遮罩这类「要盖住所有面板」的节点都往它上面加 ——
## ⚠ 注意 canvas 是 _build_ui 的**局部变量**，别的方法里取不到，必须按名字找。
func _ui_canvas() -> CanvasLayer:
	return get_node_or_null("UICanvas") as CanvasLayer


## 「刷新手牌」用掉后的碎裂演出：按钮本体先隐去（**保留占位**，否则结束回合按钮会往上跳、
## 造成误点），同时在原位炸出几块碎片、旋转着往下掉出屏幕。
func _play_refresh_break_animation() -> void:
	var cv := _ui_canvas()
	if cv == null:
		return
	var rect: Rect2 = refresh_btn.get_global_rect()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 9:
		var shard := ColorRect.new()
		shard.color = Color(0.60, 0.42, 0.23) if i % 2 == 0 else Color(0.80, 0.61, 0.34)
		shard.size = Vector2(rng.randf_range(9.0, 24.0), rng.randf_range(5.0, 13.0))
		shard.position = rect.position + Vector2(
			rng.randf() * maxf(1.0, rect.size.x - shard.size.x),
			rng.randf() * maxf(1.0, rect.size.y - shard.size.y))
		shard.rotation = rng.randf_range(-0.5, 0.5)
		shard.pivot_offset = shard.size * 0.5
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(shard)
		var tw := shard.create_tween()
		tw.set_parallel(true)
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var land := Vector2(shard.position.x + rng.randf_range(-46.0, 46.0), 780.0)
		tw.tween_property(shard, "position", land, rng.randf_range(0.55, 0.95)).set_delay(rng.randf_range(0.0, 0.14))
		tw.tween_property(shard, "rotation", shard.rotation + rng.randf_range(-3.2, 3.2), 0.9)
		tw.tween_property(shard, "modulate:a", 0.0, 0.55).set_delay(0.4)
		shard.create_tween().tween_callback(shard.queue_free).set_delay(1.4)
	refresh_btn.modulate.a = 0.0


## 打开紧急调度的选牌面板
func _open_dispatch_panel() -> void:
	if _current_phase != "allocate" or _score_animating or _sort_animating:
		return
	if not GameState.can_dispatch():
		return
	if dispatch_panel == null:
		_build_dispatch_panel()
	dispatch_panel.visible = true
	_deck_gyro_view = null          # 悬停态是从牌库那边借来的，开面板前先清干净
	# 与牌库同一个做法：把其余 HUD 面板整体收出屏幕，让选牌这一屏是全屏的。
	# _slide_main_ui 的控件清单里本来就有 left/right_panel / event_label / hand_panel /
	# bottom_right / deck_root / tier_lever，所以不用另配一套。
	_slide_main_ui(true)
	if dispatch_hint != null:
		dispatch_hint.text = _dispatch_hint_text()
	_fill_dispatch_grid()


## 调度面板顶部那句说明。**价格逐次递增**，所以每次开面板都要按当前价重写。
func _dispatch_hint_text() -> String:
	var used: int = GameState.dispatch_used_count
	var price: String = "本次调度费 %d 万" % GameState.dispatch_cost()
	if used > 0:
		price += "（本局已用过 %d 次，每再用一次 +%d 万）" % [used, GameState.DISPATCH_PRICE_STEP]
	return "%s·一律按「有效投入」档结算·卡面数字是它的定价不是调度费·不占行动位、回合末与手牌一起算分·每用一次后要空 %d 个回合" % [
		price, GameState.DISPATCH_COOLDOWN_TURNS]


func _close_dispatch_panel() -> void:
	# 本来就没开 → 直接返回：_enter_allocate() 每回合都会调一次这里，
	# 不设这个守卫的话会白白推一轮「滑回原位」的动画（虽然视觉上没差，但白建 7 条 tween）。
	if dispatch_panel == null or not dispatch_panel.visible:
		return
	dispatch_panel.visible = false
	_deck_gyro_view = null          # 别把悬停引用留在已隐藏的卡上
	_slide_main_ui(false)


## 请卡面板 —— **直接照搬牌库查看器的 UI 与交互**：同一套
## 原始卡面子树共用透视材质 + 悬停黄框/浮起/陀螺仪，
## 连悬停处理器都是同一个（_on_viewer_card_hover）。差别只有两处：
##   ① 卡池限定为「当季可抽池」（不是全部 44 张）
##   ② 点一下 = **调度它**，而不是打开卡牌详情
## 这样玩家不必学第二套交互。
func _build_dispatch_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DispatchLayer"
	layer.layer = 8
	add_child(layer)

	dispatch_panel = Control.new()
	dispatch_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	dispatch_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dispatch_panel.visible = false
	layer.add_child(dispatch_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dispatch_panel.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 70
	box.offset_right = -70
	box.offset_top = 40
	box.offset_bottom = -40
	box.add_theme_constant_override("separation", 12)
	dispatch_panel.add_child(box)

	var title := _make_label("紧急调度 · 从当季可抽池点名一张牌", 28, Color(1, 0.9, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# ⚠ 卡面写的是这张牌自己的定价，不是调度费（调度费是 DISPATCH_COST 起、逐次递增）——
	#   不写清楚的话，玩家会以为「卡面 42 万」就是要付的钱。
	# 价格每次用都会变，所以这句文案在 _open_dispatch_panel() 里按当前价重写。
	dispatch_hint = _make_label("", 12, Color(0.86, 0.88, 0.90))
	dispatch_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dispatch_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(dispatch_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	# 四周留内边距，免得顶行/左列卡在放大漂浮时被裁剪（与牌库同一处理）
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	scroll.add_child(margin)

	dispatch_grid = HFlowContainer.new()
	dispatch_grid.add_theme_constant_override("h_separation", 14)
	dispatch_grid.add_theme_constant_override("v_separation", 14)
	dispatch_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(dispatch_grid)

	var close := _make_button("取消", _close_dispatch_panel, 20)
	close.custom_minimum_size = Vector2(0, 48)
	box.add_child(close)


## 铺当季可抽池的牌。排序与手牌/牌库共用同一个开关，所以三处顺序永远一致。
func _fill_dispatch_grid() -> void:
	for c in dispatch_grid.get_children():
		dispatch_grid.remove_child(c)
		c.queue_free()
	var pool: Array = GameState.season_pool()
	pool.sort_custom(func(a, b): return _card_dict_less(a, b, _deck_sort_by_category))
	var views: Array = []
	for card in pool:
		var made := _make_card(card, GameState.DISPATCH_TIER)
		var panel: PanelContainer = made["panel"]
		var view := _make_gyro_card_view(panel)
		view.set_meta("card", card)
		view.tooltip_text = "%s\n\n调度后按「有效投入」档结算：%s" % [
			str(card["desc"]), _tier_effects_text(card, GameState.DISPATCH_TIER)]
		view.scale = Vector2(0.3, 0.3)
		view.modulate.a = 0.0
		view.mouse_entered.connect(_on_viewer_card_hover.bind(view, card))
		view.mouse_exited.connect(_on_viewer_card_unhover.bind(view))
		view.gui_input.connect(_on_dispatch_card_click.bind(view, card))
		dispatch_grid.add_child(view)
		views.append(view)
	# 等一帧布局完成后逐张发牌（与牌库同一节奏，只是牌少、间隔收紧）
	await get_tree().process_frame
	for i in views.size():
		var p: Control = views[i]
		var tw := p.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector2.ONE, 0.28).set_delay(i * 0.02)
		tw.parallel().tween_property(p, "modulate:a", 1.0, 0.18).set_delay(i * 0.02)


## 在调度面板里点一张牌 = 调度它（牌库那边点一下是看详情，这里直接买）。
## 效果**不在这里生效** —— 到回合末由 _spawn_dispatched_cards() 与手牌一起结算，
## 这样它才和常规出牌进同一段算分动画。
func _on_dispatch_card_click(event: InputEvent, _view: Control, card: Dictionary) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if GameState.dispatch_card(str(card["id"])):
		_close_dispatch_panel()
		_update_hud()


## 把本回合紧急调度买下的牌做成**真的卡面板**挂进手牌区、执行，并把下标塞进 played。
## 这么做的好处：甩牌 / 逐张弹分 / 未选中的牌被收走 —— 三个环节全都自动带上它，
## 不必另写一套并行演出，也就不会出现「调度牌的效果进了账、画面上却没有」。
## ⚠ 必须在 _score_animating = true 之后调用，否则这些牌 emit 的 metrics_changed
##   会把指标条先刷到中途值。
func _spawn_dispatched_cards(played: Array) -> void:
	if GameState.dispatched_cards.is_empty():
		return
	for d in GameState.dispatched_cards:
		var cid: String = str(d["card_id"])
		var card: Dictionary = GameState.card_by_id(cid)
		if card.is_empty():
			continue
		# free = true：调度费在买的时候就付过了，且不占行动位（见 execute_action 的注释）
		if not GameState.execute_action(cid, str(d["tier"]), true):
			continue
		# ⚠ _make_card 返回的是 {panel, cost_label} 字典，不是 PanelContainer ——
		#   手牌那边也是这么取的（见 _build_hand_panel）。
		var made: Dictionary = _make_card(card, str(d["tier"]))
		var panel: PanelContainer = made["panel"]
		_bind_card_gyro(panel)
		# ⚠ 必须与手牌用**同一个 pivot**（牌底中点）：甩牌的落点是
		#   slot - panel.pivot_offset，手牌的 pivot 是 (61,165)（_layout_fan 设的）。
		#   这里若留着默认的 (0,0)，调度牌就会比同排的牌右下各偏 61/165px ——
		#   看着像"另起了一行"。踩过一次。
		panel.pivot_offset = Vector2(61.0, 165.0)
		# 起点放在手牌区中间偏下：紧接着会被甩牌动画拉去屏幕中央，
		# 视觉上就是「它从手里一起飞出去」。**不要**调 _layout_fan ——
		# 那会把整手牌重新排一遍，白白多一段动画。
		panel.position = Vector2(card_box.size.x * 0.5 - 61.0, card_box.size.y - 168.0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 调度牌不接受点击（也不该被取消）
		card_box.add_child(panel)
		card_infos.append({
			"panel": panel, "card_id": cid, "cost_label": made["cost_label"],
			"base_pos": panel.position, "theta": 0.0, "radial": Vector2(0.0, -1.0),
			"selected": true, "shaking": false, "hovered": false,
			"tier": str(d["tier"]), "flying": true, "dispatched": true,
			"sandpan_state": wetland.capture_state(),
		})
		played.append(card_infos.size() - 1)


func _build_hand_panel() -> void:
	for c in card_box.get_children():
		c.queue_free()
	card_infos = []
	# 发牌就按当前排序模式排好。排序模式是全局的（与牌库共用），
	# 所以新一局/新一回合发牌都沿用上一次的选择，不会又变回无序抽取的顺序。
	# 比较器是全序（最后按 id 兜底），所以这里的结果与 _sort_hand_cards 的结果一致。
	current_hand.sort_custom(func(a, b): return _card_dict_less(a, b, _deck_sort_by_category))
	for card in current_hand:
		var made := _make_card(card)
		var panel: PanelContainer = made["panel"]
		_bind_card_gyro(panel)
		card_box.add_child(panel)
		card_infos.append({
			"panel": panel, "card_id": card["id"],
			"base_pos": Vector2.ZERO, "theta": 0.0, "radial": Vector2.UP,
			"selected": false, "shaking": false, "hovered": false,
			"tier": "",                                  # "" = 跟随拉杆；非空 = 选中时锁定的档位
			"cost_label": made["cost_label"],
		})
	_refresh_hand_display()      # 用当前档位把牌面的价格填上（加成只在悬停提示里）
	_layout_fan.call_deferred()
	_update_hud()


## 扇形摆放手牌：圆心在下方，牌绕圆心径向排列（牌底小弧、牌顶大弧）
## 屏幕坐标 → card_box 的局部坐标。
##
## ⚠ 不要用 card_box.get_global_transform().affine_inverse()：容器布局尚未跑过时
##   card_box.size 可能是 0（headless 下实测为 (0, 200)），变换矩阵会把 x 轴压成 0，
##   反变换出来的落点是垃圾值 —— 表现是动画目标点乱跳、牌飞不到位。
##   card_box 没有缩放/旋转，所以直接减 global_position 既正确又不受尺寸影响。
func _screen_to_card_box(screen_pt: Vector2) -> Vector2:
	return screen_pt - card_box.global_position


func _layout_fan() -> void:
	var n := card_infos.size()
	if n == 0:
		return
	var card_w := 122.0
	var card_h := 165.0
	var area_size := card_box.size
	if area_size.x < 10.0:
		area_size.x = 528.0

	var step_dist := 66.0                      # 相邻牌在弧上的间距（越小重叠越多）
	var delta_theta := deg_to_rad(8.5)
	var radius: float = step_dist / delta_theta
	var total_span := delta_theta * float(n - 1)

	# 第一遍：以「圆心在原点」计算每张牌的角度与轴心点
	var pivots: Array = []
	var thetas: Array = []
	for i in n:
		var theta := -total_span / 2.0 + delta_theta * float(i)
		pivots.append(Vector2(sin(theta), -cos(theta)) * radius)
		thetas.append(theta)
		var panel: PanelContainer = card_infos[i]["panel"]
		panel.size = Vector2(card_w, card_h)
		panel.custom_minimum_size = Vector2(card_w, card_h)
		panel.pivot_offset = Vector2(card_w / 2.0, card_h)
		panel.rotation = theta

	# 第二遍：算出旋转后整体的真实包围盒（不依赖手算常数）
	var corners := [
		Vector2(-card_w / 2.0, -card_h), Vector2(card_w / 2.0, -card_h),
		Vector2(card_w / 2.0, 0.0), Vector2(-card_w / 2.0, 0.0),
	]
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for i in n:
		for c in corners:
			var p: Vector2 = pivots[i] + c.rotated(thetas[i])
			min_x = minf(min_x, p.x)
			max_x = maxf(max_x, p.x)
			min_y = minf(min_y, p.y)
			max_y = maxf(max_y, p.y)

	# 第三遍：整体平移 —— 水平居中于容器，底部贴边（留下上方空间供悬停弹起）
	var bottom_margin := 4.0
	var dx: float = area_size.x / 2.0 - (min_x + max_x) / 2.0
	var dy: float = (area_size.y - bottom_margin) - max_y
	for i in n:
		var panel: PanelContainer = card_infos[i]["panel"]
		panel.position = pivots[i] + Vector2(dx, dy) - panel.pivot_offset
		card_infos[i]["base_pos"] = panel.position
		card_infos[i]["theta"] = thetas[i]
		card_infos[i]["radial"] = Vector2(sin(thetas[i]), -cos(thetas[i]))
	_fan_layout_size = area_size
	if sandpan_view: sandpan_view.invalidate_layout()
	# 发牌入场动画（从下方滑入 + 逐张错开）
	if play_deal_anim:
		play_deal_anim = false
		_play_deal_animation()


## 发牌入场：牌从下方滑入，逐张错开（EASE_OUT，玩家等待中的入场用稍长时长）
func _play_deal_animation() -> void:
	for i in card_infos.size():
		var info: Dictionary = card_infos[i]
		var panel: PanelContainer = info["panel"]
		var target: Vector2 = info["base_pos"]
		panel.position = target + Vector2(0, 90.0)
		panel.modulate.a = 0.0
		var tw := panel.create_tween()
		tw.set_parallel(true)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "position", target, 0.34).set_delay(i * 0.045)
		tw.tween_property(panel, "modulate:a", 1.0, 0.22).set_delay(i * 0.045)


## 容器尺寸变化时重排（确保扇形始终居中）
func _on_card_box_resized() -> void:
	if not card_infos.is_empty():
		_layout_fan()


# ==================== 出牌档位拉杆 ====================
# 拉杆的三个档位，顺序 = 从左到右
const LEVER_TIERS := ["basic", "effective", "deep"]
# 档位 → 状态文字。半价/全价/双倍价是 0.0.4 定价规则里**明确要给玩家**的那句话，
# 属于规则而非隐性参数，可以上屏（难度负向倍率那类才不许写）。
const LEVER_STATE_TEXT := {
	"basic": "基础投入 · 半价",
	"effective": "有效投入 · 全价",
	"deep": "深度投入 · 双倍价",
}
## 左下角「出牌档位」拉杆。外观照拨杆做：一条木轨 + 三个刻度 + 一根左右平移的手柄（始终竖直）。
## 交互：点最左那一格 = 基础投入，中间 = 有效投入，最右 = 深度投入；按住手柄左右拖也跟手。
## ⚠ 只影响**之后选中的牌**。已选中的牌在选的那一刻就把档位记进了 card_infos[i]["tier"]，
##   所以一回合内可以先拨到基础档选两张便宜牌、再拨到深度档选一张大牌。
func _build_tier_lever(holder: Node) -> void:
	tier_lever = PanelContainer.new()
	tier_lever.anchor_left = 0.0
	tier_lever.anchor_top = 1.0
	tier_lever.anchor_right = 0.0
	tier_lever.anchor_bottom = 1.0
	tier_lever.offset_left = 14
	tier_lever.offset_right = 226
	tier_lever.offset_top = -136
	tier_lever.offset_bottom = -14
	_panel_style(tier_lever, Color(0.22, 0.16, 0.10, 0.96))
	tier_lever.visible = false
	holder.add_child(tier_lever)

	var lvb := VBoxContainer.new()
	lvb.add_theme_constant_override("separation", 2)
	tier_lever.add_child(lvb)

	# 标题行 = [出牌档位] + [冷却倒计时]。倒计时放标题**右边**、不另起一行 ——
	# 否则面板高度会随冷却有无而变化，把整条拉杆顶来顶去。
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lvb.add_child(title_row)

	var title := _make_label("出牌档位", 12, Color(0.86, 0.80, 0.68))
	title_row.add_child(title)

	lever_cd_label = _make_label("", 12, Color(1.0, 0.60, 0.40))
	lever_cd_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(lever_cd_label)

	lever_track = Control.new()
	# 高度要同时容得下「手柄」（上半）+「基础/有效/深度」小字（下半），
	# 否则手柄会压在档位文字上（实测截图里压到过「深度」）。
	lever_track.custom_minimum_size = Vector2(0, 62)
	lever_track.mouse_filter = Control.MOUSE_FILTER_STOP       # 整条轨都能点/拖
	lever_track.resized.connect(_layout_lever_handle)
	lever_track.gui_input.connect(_on_lever_input)
	lvb.add_child(lever_track)

	# 木轨：横贯整条轨，居中 6px 厚
	var rail := ColorRect.new()
	rail.color = Color(0.40, 0.29, 0.17, 1.0)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.anchor_left = 0.0
	rail.anchor_right = 1.0
	rail.anchor_top = 0.5
	rail.anchor_bottom = 0.5
	rail.offset_top = -4
	rail.offset_bottom = 4
	lever_track.add_child(rail)

	# 三个刻度（锚点固定在 1/6、3/6、5/6，自动跟随宽度）
	for i in LEVER_TIERS.size():
		var tick := ColorRect.new()
		var fx: float = (2.0 * float(i) + 1.0) / 6.0
		tick.anchor_left = fx
		tick.anchor_right = fx
		tick.anchor_top = 0.5
		tick.anchor_bottom = 0.5
		tick.offset_left = -1
		tick.offset_right = 1
		tick.offset_top = -7
		tick.offset_bottom = 7
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.set_meta("lever_tier_index", i)
		lever_track.add_child(tick)
		lever_slot_btns.append(tick)     # 复用作「刻度节点」列表（高亮时改颜色）

	# 三个小字标签（基础 / 有效 / 深度），各占 1/3 宽
	for i in LEVER_TIERS.size():
		var lab := _make_label(str(GameState.TIER_NAMES[LEVER_TIERS[i]]).substr(0, 2), 12,
			Color(0.62, 0.58, 0.50))
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.anchor_left = float(i) / 3.0
		lab.anchor_right = float(i + 1) / 3.0
		lab.anchor_top = 1.0
		lab.anchor_bottom = 1.0
		lab.offset_top = -16
		lab.offset_bottom = 0
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.set_meta("lever_tier_index", i)
		lever_track.add_child(lab)
		lever_slot_btns.append(lab)      # 同上：标签也一起高亮

	# 手柄：杆 + 头，支点在底部中心，靠 rotation 做倾倒
	lever_handle = Control.new()
	lever_handle.custom_minimum_size = Vector2(28, 34)
	lever_handle.size = Vector2(28, 34)
	lever_handle.pivot_offset = Vector2(14, 32)
	lever_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lever_track.add_child(lever_handle)

	var stick := ColorRect.new()
	stick.color = Color(0.74, 0.62, 0.44, 1.0)
	stick.position = Vector2(10, 2)
	stick.size = Vector2(8, 30)
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lever_handle.add_child(stick)

	var knob := Panel.new()
	var ksb := StyleBoxFlat.new()
	ksb.bg_color = Color(0.56, 0.41, 0.23, 1.0)
	ksb.border_color = Color(1.0, 0.86, 0.42, 1.0)
	ksb.set_border_width_all(2)
	ksb.corner_radius_top_left = 6
	ksb.corner_radius_top_right = 6
	ksb.corner_radius_bottom_left = 6
	ksb.corner_radius_bottom_right = 6
	knob.add_theme_stylebox_override("panel", ksb)
	knob.position = Vector2(4, 0)
	knob.size = Vector2(20, 17)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lever_handle.add_child(knob)

	lever_state_label = _make_label("", 12, Color(1.0, 0.92, 0.60))
	lever_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvb.add_child(lever_state_label)

	_refresh_lever_visuals(false)


## 点在轨上的哪个位置 → 吸附到最近的一格（按住拖动时也走这里，所以能"拖着拨"）
## ⚠ 点击与拖动的动画策略**不同**：
##   点击 = 手柄**滑过去**（0.24s 缓入缓出，看得出"拉杆被拨动"）；
##   拖动 = 手柄**跟手**，不能播动画 —— 否则手柄会一直慢半拍地追鼠标，手感是坏的。
func _on_lever_input(event: InputEvent) -> void:
	if _current_phase != "allocate" or _paused or GameState.game_over:
		return
	var pressed := false
	var pos := Vector2.ZERO
	var is_click := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		pos = event.position
		is_click = true
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pressed = true
		pos = event.position
	if not pressed:
		return
	var w: float = maxf(1.0, lever_track.size.x)
	var idx := clampi(int(floor(pos.x / (w / 3.0))), 0, LEVER_TIERS.size() - 1)
	_set_play_tier(LEVER_TIERS[idx], is_click)


## 手柄按当前档位归位（尺寸变化时立刻归位，不播动画）
func _layout_lever_handle() -> void:
	if lever_handle == null or lever_track == null:
		return
	_place_lever_handle(false)


func _place_lever_handle(animate: bool) -> void:
	var idx: int = maxi(0, LEVER_TIERS.find(play_tier))
	var w: float = maxf(1.0, lever_track.size.x)
	var cx: float = w * (2.0 * float(idx) + 1.0) / 6.0
	# 手柄底部落在「小字标签」上方，别压字（轨道下半 18px 留给标签）
	var target_pos := Vector2(cx - lever_handle.size.x / 2.0, lever_track.size.y - 52.0)
	# 手柄**始终竖直**，只左右平移。之前让它跟着倾斜 ±29°，实测在基础/深度档看着别扭：
	# 圆头跟着转、还会离开它对应的刻度。竖直滑动读起来干净，位置同样一眼可辨。
	lever_handle.rotation = 0.0
	# 先掐掉上一次的滑动动画：连续点两格时，两条 tween 会抢同一个 position，
	# 结果互相拉扯、手柄在半路抖一下才到位。
	if _lever_slide_tween != null and _lever_slide_tween.is_valid():
		_lever_slide_tween.kill()
		_lever_slide_tween = null
	if not animate:
		lever_handle.position = target_pos
		return
	# 0.24s + 缓入缓出：太短（0.16）看着还是"跳"，太长会拖住操作节奏
	_lever_slide_tween = lever_handle.create_tween()
	_lever_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_lever_slide_tween.tween_property(lever_handle, "position", target_pos, 0.24)


## 切档：更新手柄姿态、刻度/标签高亮、状态文字，并刷新手牌上还没被选中的牌。
## 冷却期间**拉杆锁死**、直接吞掉输入；点当前档不算切档，也不会重置冷却。
func _set_play_tier(tier: String, animate: bool = true) -> void:
	if not GameState.TIER_COST_MULT.has(tier):
		return
	if Time.get_ticks_msec() - _lever_cooldown_ms < LEVER_COOLDOWN_MS:
		return                                   # 冷却中：锁死
	if tier == play_tier:
		return                                   # 点的是当前档：不做任何事
	play_tier = tier
	_lever_cooldown_ms = Time.get_ticks_msec()
	_refresh_lever_visuals(animate)
	_refresh_hand_display()


## 出牌档位的冷却倒计时：冷却时拉杆变暗（看着就知道点不动），
## 并在「出牌档位」右边显示还剩几秒。由 _process 每帧调用 ——
## 所以只改文本与 modulate，绝不重建节点（与排序冷却同一套写法）。
func _update_lever_cooldown() -> void:
	if lever_cd_label == null:
		return
	var remaining := LEVER_COOLDOWN_MS - (Time.get_ticks_msec() - _lever_cooldown_ms)
	var locked: bool = remaining > 0
	if locked:
		lever_cd_label.text = "冷却 %.1f 秒" % (float(remaining) / 1000.0)
	elif lever_cd_label.text != "":
		lever_cd_label.text = ""
	if lever_track != null:
		var want: float = 0.55 if locked else 1.0
		if not is_equal_approx(lever_track.modulate.a, want):
			lever_track.modulate.a = want


func _refresh_lever_visuals(animate: bool) -> void:
	if tier_lever == null:
		return
	var idx: int = maxi(0, LEVER_TIERS.find(play_tier))
	for node in lever_slot_btns:
		var i: int = int(node.get_meta("lever_tier_index", 0))
		var active: bool = i == idx
		if node is ColorRect:
			node.color = Color(1.0, 0.86, 0.42) if active else Color(0.55, 0.45, 0.33)
		else:
			node.add_theme_color_override("font_color",
				Color(1.0, 0.94, 0.66) if active else Color(0.60, 0.55, 0.47))
	if lever_state_label != null:
		lever_state_label.text = str(LEVER_STATE_TEXT.get(play_tier, ""))
	if lever_handle != null:
		_place_lever_handle(animate)


## 建一张卡（手牌 / 牌库网格 / 详情大图共用）。
## 返回 {panel, cost_label}；牌面按 tier 先填一遍，
## tier 传空则用当前拉杆档位。手牌那边之后还会由 _update_card_face() 反复重填。
func _make_card(card: Dictionary, tier: String = "") -> Dictionary:
	var panel := PanelContainer.new()
	panel.set_script(preload("res://scripts/card_hit_panel.gd"))
	panel.custom_minimum_size = Vector2(122, 165)
	panel.size = Vector2(122, 165)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", VisualTheme.card_style())
	panel.gui_input.connect(_on_card_gui_input.bind(panel))
	var use_tier: String = tier if tier != "" else play_tier
	if not card["tiers"].has(use_tier):
		use_tier = "effective"
	var cost: int = GameState.tier_cost(str(card["id"]), use_tier)
	PixelCardArt.add_face(panel, str(card["name"]), str(cost), false, str(card["category"]))
	# Preserve the existing price-state interface; this Label never draws the card text.
	var cost_l := Label.new()
	cost_l.name = "PriceState"
	cost_l.visible = false
	cost_l.text = str(cost)
	panel.add_child(cost_l)
	panel.tooltip_text = "%s\n\n%s（%d 万）：%s" % [card["desc"], GameState.TIER_NAMES[use_tier],
		cost, _tier_effects_text(card, use_tier)]
	return {"panel": panel, "cost_label": cost_l}


## 由卡 id 取中文名
func _card_name(card_id: String) -> String:
	for c in GameState.ACTION_CARDS:
		if c["id"] == card_id:
			return c["name"]
	return card_id


## 由 id 取卡牌字典（刷新牌面要用）
func _card_dict(card_id: String) -> Dictionary:
	for c in GameState.ACTION_CARDS:
		if str(c["id"]) == card_id:
			return c
	return {}


## 某一档的效果文字：「水质 +3、沉水植被 +6（2 回合后）」
func _tier_effects_text(card: Dictionary, tier: String) -> String:
	var t: Dictionary = card["tiers"].get(tier, card["tiers"]["effective"])
	var parts: Array = []
	for e in t["effects"]:
		var d: int = int(e["delay"])
		var suffix := "（%d 回合后）" % d if d > 0 else ""
		parts.append("%s %+d%s" % [GameState.METRIC_NAMES[e["metric"]], int(e["delta"]), suffix])
	return "、".join(parts)


func _effect_text(card: Dictionary) -> String:
	return "效果：" + _tier_effects_text(card, play_tier)


## 这张牌锁定在哪一档：**已选中的牌用它自己被记下的档位**（选完再拨拉杆也不变），
## 没选中的牌跟随拉杆当前档位。
func _info_tier(info: Dictionary) -> String:
	var t: String = str(info.get("tier", ""))
	return t if t != "" else play_tier


## 刷新一张牌的牌面：价格（含档位标签）+ 悬停提示里的「这一档」加成
func _update_card_face(info: Dictionary) -> void:
	var card := _card_dict(str(info["card_id"]))
	if card.is_empty():
		return
	var tier: String = _info_tier(info)
	var cost: int = GameState.tier_cost(str(info["card_id"]), tier)
	var locked: bool = str(info.get("tier", "")) != ""
	var tag: String = ("%s " % str(GameState.TIER_NAMES[tier]).substr(0, 2)) if locked else ""
	var cost_l: Label = info["cost_label"]
	cost_l.text = "%s%d" % [tag, cost]
	var face: TextureRect = info["panel"].get_meta("pixel_face")
	face.texture = PixelCardArt.texture(str(card["name"]), str(cost), str(card["category"]))
	# 锁定的牌用更亮的金色，一眼看出「这张是按哪个档锁住的」
	cost_l.add_theme_color_override("font_color",
		Color("956523") if locked else Color("6f542a"))
	info["panel"].tooltip_text = "%s\n\n%s（%d 万）：%s" % [
		card["desc"], GameState.TIER_NAMES[tier], cost, _tier_effects_text(card, tier)]


## 拉杆一动就把**还没选中**的牌全部刷新；已选中的保持锁定档位不动
func _refresh_hand_display() -> void:
	for info in card_infos:
		_update_card_face(info)


func _find_card_info(panel: PanelContainer) -> Dictionary:
	for info in card_infos:
		if info["panel"] == panel:
			return info
	return {}


## 点击卡牌：切换选中（可取消）
func _on_card_gui_input(event: InputEvent, panel: PanelContainer) -> void:
	if _score_animating or _sort_animating:
		return      # 算分动画 / 手牌换位进行中，牌正在飞，不接受选中切换
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_card(panel)


func _toggle_card(panel: PanelContainer) -> void:
	var info: Dictionary = _find_card_info(panel)
	if info.is_empty():
		return
	if info["selected"]:
		info["selected"] = false
		info["tier"] = ""              # 取消选中 → 这张牌重新跟随拉杆
		_remove_gold_frame(panel)
		_update_card_face(info)
	else:
		# 行动位上限（随难度变化：简单档 4，普通/困难 3 —— 见 MAX_ACTIONS_BY_DIFFICULTY）
		var slots := GameState.action_slots()
		if _selected_count() >= slots:
			_reject_card(panel, "行动位已满（本难度每回合最多 %d 个）" % slots)
			return
		# 资金检查：已选卡的总花费 + 这张，不能超过可用资金
		# ★ 用拉杆当前档位算价 —— 基础档便宜、深度档贵，选之前先把拉杆拨对
		var cost := GameState.tier_cost(info["card_id"], play_tier)
		if _committed_funds() + cost > GameState.funds:
			_reject_card(panel, "资金不足（还需 %d 万，可用 %d 万）" % [cost, GameState.funds - _committed_funds()])
			return
		info["selected"] = true
		info["tier"] = play_tier         # ★ 选中的那一刻把档位锁定在这张牌上
		_apply_gold_frame(panel)
		_update_card_face(info)
	_update_selected_label()


## 已选卡牌的总花费（万）
func _committed_funds() -> int:
	var total := 0
	for info in card_infos:
		if info["selected"]:
			# 每张牌按它自己锁定的档位算 —— 一回合里混着打不同档也能算对预算
			total += GameState.tier_cost(info["card_id"], _info_tier(info))
	return total


func _selected_count() -> int:
	var n := 0
	for info in card_infos:
		if info["selected"]:
			n += 1
	return n


func _update_selected_label() -> void:
	var used := _committed_funds()
	selected_label.text = "已选：%d/%d　预算：%d/%d 万" % [
		_selected_count(), GameState.action_slots(), used, GameState.funds]


## 拒绝选中：红框闪烁 + 左右抖动 + 提示原因
func _reject_card(panel: PanelContainer, reason: String) -> void:
	var info: Dictionary = _find_card_info(panel)
	if info.is_empty() or info.get("shaking", false):
		return
	info["shaking"] = true
	var sb := panel.get_theme_stylebox("panel")
	var old_border := Color.WHITE
	if sb is StyleBoxFlat:
		old_border = sb.border_color
		sb.border_color = Color(0.92, 0.26, 0.22)
	var base: Vector2 = panel.position
	var tw := panel.create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	for k in 3:
		tw.tween_property(panel, "position:x", base.x + 9.0, 0.045)
		tw.tween_property(panel, "position:x", base.x - 9.0, 0.045)
	tw.tween_property(panel, "position:x", base.x, 0.05)
	tw.tween_callback(func() -> void:
		if is_instance_valid(sb):
			sb.border_color = old_border
		info["shaking"] = false)
	_flash_hint(reason)


## 顶部提示条短暂显示（红字），随后恢复
func _flash_hint(text: String) -> void:
	selected_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
	selected_label.text = text
	var tw := selected_label.create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void:
		selected_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		_update_selected_label())


## 每帧轮询卡牌悬停：精确判断鼠标是否在旋转后的卡牌内（避免相邻牌误判）
## mouse_override 仅供自动化测试顶替真实鼠标（与 _update_metric_tip 同一个套路），
## 正常游戏不传 —— 但手牌陀螺仪要拍证据，就必须能凭空指定一个悬停点。
func _update_card_hover(delta: float, mouse_override: Vector2 = Vector2.INF) -> void:
	if sandpan_view and sandpan_view.collapsed: return
	if hand_panel.visible == false or card_infos.is_empty():
		return
	if _score_animating:
		# 算分动画期间由动画独占控制卡牌位置/缩放（本函数每帧把牌拽回 base_pos）。
		# 但倾斜要收回：牌正被动画带着飞，残留的歪角会让飞出去的牌看着还是斜的。
		_decay_hand_gyro(delta)
		return
	var mouse_global := mouse_override if mouse_override != Vector2.INF else get_viewport().get_mouse_position()
	var box_tf := card_box.get_global_transform()
	# 用稳定素材轮廓进入悬停，悬停后保留初始轮廓与当前卡面的并集。
	# 视觉抬起不能自行撤销鼠标命中；点击仍由实际透视卡面单独判断。
	var hits: Array = []   # 命中的 card_infos 下标
	for i in card_infos.size():
		var info: Dictionary = card_infos[i]
		var panel: PanelContainer = info["panel"]
		if not is_instance_valid(panel):
			continue
		# flying = 正在被动画独占控制（算分飞牌 / 手牌收拢发牌），别做悬停命中
		if info.get("shaking", false) or info.get("flying", false):
			info["hovered"] = false
			continue
		var rest: Vector2 = info["base_pos"] + info["radial"] * (CARD_RAISE if info["selected"] else 0.0)
		var angle: float = info["theta"]
		var origin := rest + panel.pivot_offset - panel.pivot_offset.rotated(angle)
		var stable := box_tf * Transform2D(angle, Vector2.ONE, 0.0, origin)
		var base_hit: bool = preload("res://scripts/card_geometry.gd").contains(panel, mouse_global, stable, true)
		var held_hit: bool = info.get("hovered", false) and _point_in_card(panel, info["base_pos"], mouse_global, box_tf)
		if base_hit or held_hit:
			hits.append(i)
	# 2) 重叠时只留最上层那张：从子列表末尾（最后绘制 = 最上层）往前找第一个命中的
	var hovered_idx: int = -1
	if hits.size() == 1:
		hovered_idx = hits[0]
	elif hits.size() > 1:
		var children: Array = card_box.get_children()
		for c in range(children.size() - 1, -1, -1):
			for i in hits:
				if card_infos[i]["panel"] == children[c]:
					hovered_idx = i
					break
			if hovered_idx != -1:
				break
	# 3) 驱动弹起 / 放大（与帧率无关的平滑，替代固定系数 lerp）
	for i in card_infos.size():
		var info: Dictionary = card_infos[i]
		var panel: PanelContainer = info["panel"]
		# ⚠ flying 必须在这里挡住：本函数每帧把牌 lerp 回 base_pos，
		#   会与飞行 tween 逐帧打架（表现为牌往目标飞一点又被拽回来，来回抖）。
		#   算分动画靠 _score_animating 整段挡掉了本函数所以看不出问题，
		#   手牌收拢发牌没有那种全局开关，只能靠这个逐张的标志。
		if not is_instance_valid(panel) or info.get("shaking", false) or info.get("flying", false):
			continue  # 抖动 / 飞行期间不要抢它的 position
		var hovering: bool = (i == hovered_idx)
		info["hovered"] = hovering
		panel.get_theme_stylebox("panel").set_meta("card_outline", hovering or info["selected"])
		# 抬起：鼠标悬停的牌 + 已选定的牌（已选牌保持"抬起来挂在那儿"的状态）
		var raised: bool = hovering or info["selected"]
		# 弹起方向：沿径向向外（远离圆心，即向上弹出）
		var target: Vector2 = info["base_pos"] + info["radial"] * (CARD_RAISE if raised else 0.0)
		panel.position = panel.position.lerp(target, 1.0 - exp(-12.0 * delta))
		var s: float = 1.06 if hovering else 1.0
		panel.scale = panel.scale.lerp(Vector2(s, s), 1.0 - exp(-14.0 * delta))
		var tilt: float = info["theta"]
		if hovering:
			tilt *= 0.65
		panel.rotation = lerp_angle(panel.rotation, tilt, 1.0 - exp(-15.0 * delta))
		# 陀螺仪：悬停那一张跟着鼠标做 3D 透视倾斜（与牌库 / 知识卡图鉴同一套系数）
		_step_card_gyro(panel, _card_gyro_target(panel, mouse_global, hovering), delta)
	_update_card_stack()


## 手牌不在焦点 / 算分动画期间：把残留的倾斜平滑收回
func _decay_hand_gyro(delta: float) -> void:
	for info in card_infos:
		var panel: PanelContainer = info.get("panel")
		if not is_instance_valid(panel):
			continue
		_step_card_gyro(panel, Vector2.ZERO, delta)


## 手牌分三层叠放（像斗地主那样，选中的牌整体浮起一排）：
##   底层 = 未选中的牌 → 中层 = 已选中的牌 → 顶层 = 鼠标正悬停的那张
## Godot 里兄弟节点越靠后越晚绘制、也就越在上层，所以把三组按这个顺序排进子列表即可。
## 各层内部保持原本的左右顺序；鼠标一移开，悬停那张就插回它自己那一层（不留痕迹）。
## 只改「绘制与拾取顺序」，不动任何坐标，所以不会和扇形布局打架。
func _update_card_stack() -> void:
	if card_infos.is_empty():
		return
	var front: PanelContainer = null
	for info in card_infos:
		if info.get("hovered", false) and is_instance_valid(info["panel"]):
			front = info["panel"]
			break
	var plain: Array = []   # 未选中
	var picked: Array = []  # 已选中
	for info in card_infos:
		var panel: PanelContainer = info["panel"]
		if not is_instance_valid(panel) or panel == front:
			continue
		if info["selected"]:
			picked.append(panel)
		else:
			plain.append(panel)
	var want: Array = plain.duplicate()
	want.append_array(picked)
	if front != null:
		want.append(front)
	# 与当前顺序一致就不动，避免每帧无谓重排
	var cur: Array = card_box.get_children()
	if cur.size() == want.size():
		var same := true
		for i in want.size():
			if cur[i] != want[i]:
				same = false
				break
		if same:
			return
	for i in want.size():
		card_box.move_child(want[i], i)


## 判断鼠标是否落在当前可见卡面；包含扇形旋转、缩放与陀螺仪透视。
func _point_in_card(panel: PanelContainer, _base_pos: Vector2, mouse_global: Vector2, _box_tf: Transform2D) -> bool:
	return preload("res://scripts/card_geometry.gd").contains(panel, mouse_global)


## 金色闪光框（选中标记，呼吸发光）
func _apply_gold_frame(panel: PanelContainer) -> void:
	_stop_card_glow(panel)
	var sb := VisualTheme.card_style(true)
	panel.add_theme_stylebox_override("panel", sb)
	var tw := panel.create_tween().set_loops()
	panel.set_meta("selection_glow", tw)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(sb, "border_color", Color("fff3b0"), 0.8)
	tw.tween_property(sb, "border_color", VisualTheme.GOLD, 0.8)


func _stop_card_glow(panel: PanelContainer) -> void:
	var tw: Tween = panel.get_meta("selection_glow") if panel.has_meta("selection_glow") else null
	if tw and tw.is_valid(): tw.kill()
	if panel.has_meta("selection_glow"): panel.remove_meta("selection_glow")


func _remove_gold_frame(panel: PanelContainer) -> void:
	_stop_card_glow(panel)
	panel.add_theme_stylebox_override("panel", VisualTheme.card_style())


func _finish_turn() -> void:
	if _score_animating or _sort_animating:
		return      # 算分动画 / 手牌排序进行中，忽略连点
	if sandpan_view: sandpan_view.prepare_settlement()

	# 执行所有选中的卡（防御：资金/行动位不足的记录为失败，不静默吞掉）
	GameState.clear_score_ledger()
	# ★ 出牌**前**的快照：这是本轮动画的起点，也是唯一含「本轮牌加成」的口径。
	#   注意与下面那个 before 的区别 —— 那个取在 execute_action 之后，是弹窗文案用的旧口径。
	var before_all: Dictionary = GameState.metrics.duplicate()
	var failed: Array = []
	var played: Array = []      # 成功执行的卡片下标（甩牌与逐张弹分用）
	# ★ 必须在 execute_action 之前置位：否则每张牌 emit 的 metrics_changed
	#   会把指标条先刷到中途值，动画还没开始就已经跳过了。
	_score_animating = true
	for i in card_infos.size():
		var info: Dictionary = card_infos[i]
		if info["selected"]:
			if GameState.execute_action(info["card_id"], _info_tier(info)):
				info["sandpan_state"] = wetland.capture_state()
				played.append(i)
			else:
				failed.append(info["card_id"])
			if GameState.game_over:
				break   # 已经判负，剩下的牌不再执行

	# 紧急调度买下的牌：不占行动位，所以不进上面那个循环；
	# 但**要和手牌一起进同一段算分动画**（这是这一手牌的一部分），见 _spawn_dispatched_cards。
	_spawn_dispatched_cards(played)

	# 成就判定放在判负早退**之前**：玩家确实打出了三张同类别，
	# 哪怕这一手同时把自己打崩了，成就也该照给。
	_check_flush_achievement(played)

	# 判负即时化：出牌当场把指标打到致死线以下 → 不播动画、直接给失败报告
	# （保住已修复的 P0 体验：判负必须立刻可见，不能先播 2.8 秒动画）
	if GameState.game_over:
		_score_animating = false
		_update_hud()
		_update_3d()
		if _current_phase != "popup_report":
			_show_report(GameState.generate_report())
		return

	var before: Dictionary = GameState.metrics.duplicate()
	_defer_game_over = true   # 结算流程自己按「结算反馈 → 报告」的顺序收尾
	GameState.end_turn()
	_defer_game_over = false
	var after: Dictionary = GameState.metrics
	var ledger: Array = GameState.score_ledger.duplicate(true)

	var lines: Array = []
	if GameState.last_crisis_name != "":
		lines.append("⚠ 危机爆发：%s" % GameState.last_crisis_name)
		lines.append("")
	lines.append("本回合结算：")
	for metric in GameState.METRIC_NAMES:
		var d: int = after[metric] - before[metric]
		if d != 0:
			lines.append("  %s：%+d" % [GameState.METRIC_NAMES[metric], d])
	for msg in GameState.log_messages:
		lines.append("  · %s" % msg)
	if not failed.is_empty():
		var names: Array = []
		for cid in failed:
			names.append(_card_name(cid))
		lines.append("  ⚠ 以下行动因资金不足未能执行：%s" % "、".join(names))
	lines.append("")
	# 指标换来的额外拨款：**只报结果，不解释是哪一项换来的** ——
	# 「哪些指标决定钱」属于隐性参数，要玩家自己从数字里总结（与 METRIC_REMEDY 同一条铁律）。
	if GameState.last_metric_funding != 0:
		lines.append("额外拨款：%+d 万" % GameState.last_metric_funding)
	lines.append("结转资金：%d 万（未用资金享 %d%% 利息，上限 %d 万）" % [GameState.carry, int(GameState.INTEREST_RATE * 100), GameState.MAX_CARRY])
	# 下回合危机预警。
	# ⚠ 光报名字是不够的：危机是在**下回合结算时**才爆发的，而玩家在结算弹窗里看到的
	#    指标是「本回合结算后」的值（还都在红线上）。只写个名字，玩家点「继续」
	#    下一刻就判负，会觉得「明明条都还是绿的，怎么就输了」。所以这里必须把
	#    「会掉多少 → 大概落到哪 → 会不会跌破红线」逐项写清楚。
	if not GameState.pending_crisis.is_empty():
		lines.append("")
		lines.append("[color=#ffb060]⏳ 预警：%s（下回合结算时爆发）[/color]" % GameState.pending_crisis["name"])
		var fatal_names: Array = []
		for e in GameState.pending_crisis.get("effects", []):
			var em := str(e["metric"])
			var ed := int(e["delta"])
			var ecur := int(GameState.metrics.get(em, 0))
			var eline := GameState.failure_threshold_for(em)
			var eafter := clampi(ecur + ed, 0, 100)
			var verdict := "[color=#7ee08a]仍在生态红线 %d 之上[/color]" % eline
			if em == "water_level":
				var next_season: String = GameState.SEASONS[GameState.turn % 4]
				var pressure: Dictionary = GameState.water_pressure(eafter, next_season)
				verdict = "[color=#ffcc66]水位不直接判负；%s季参考 %d–%d，%s[/color]" % [GameState.SEASON_NAMES[next_season], pressure["low"], pressure["high"], {"safe": "区间内", "low": "注意干旱", "high": "注意淹水"}[pressure["side"]]]
			elif eafter < eline:
				verdict = "[color=#ff5a5a]会跌破生态红线 %d[/color]" % eline
				fatal_names.append(str(GameState.METRIC_NAMES.get(em, em)))
			lines.append("  %s %+d → 约 %d，%s" % [GameState.METRIC_NAMES.get(em, em), ed, eafter, verdict])
		# 逐项列了数字，但玩家未必会自己加总 —— 会致死时再补一句总括。
		# ⚠ 措辞要**如实反映还能补救**：危机是在下一回合的回合末才结算的，
		#   玩家下一回合整回合可以出牌把这一项拉上去，真的有可能救回来。
		#   （早先这里写过「来不及补救了」—— 那是照搬危机还在「下回合开局」结算时的
		#     旧时序，时序一挪就变成了假话。文案必须跟着机制走。）
		if not fatal_names.is_empty():
			lines.append("[color=#ff5a5a][b]⚠ 下回合结算时若仍未改善，将因「%s」跌破生态红线而被撤换 —— 你还有下回合一整个回合可以补救[/b][/color]" % "、".join(fatal_names))
		var counter_names: Array = []
		for cid in GameState.counter_card_ids():
			counter_names.append(_card_name(cid))
		var shown_c: Array = counter_names.slice(0, 3)
		var tail_c: String = "" if counter_names.size() <= 3 else " 等 %d 张" % counter_names.size()
		lines.append("[color=#8a8a8a]   （专项响应已列入下批：%s%s，出现概率已提高，不保证到手）[/color]" % [
			"、".join(shown_c), tail_c])

	# ★ 算分动画。必须在收起手牌 / 侧栏之**前**播 —— 指标行得留在屏幕上才有的演。
	await _play_score_animation(ledger, before_all, played, after)

	hand_panel.visible = false
	bottom_right.visible = false
	tier_lever.visible = false
	_slide_side_panels(true)  # 结算后侧边栏收回屏幕外，让出沙盘
	_current_phase = "popup_settlement"
	_show_popup("结算反馈", "\n".join(lines), "继续", _on_resolve_continue)
	# 结算弹窗铺好之后再放攒下的危机预警/爆发。
	# ⚠ 此时 popup_root 已可见，所以 _on_crisis_dismiss 里那句
	#   `elif not popup_root.visible: _enter_allocate()` 不会误触发 ——
	#   否则玩家在结算期间点掉危机弹窗会直接跳进分配阶段、把刚发的手牌重建掉。
	_process_crisis_queue()


## 小丑牌风算分动画：甩牌 → 逐张弹分 → 指标从上到下结算（含四类来源小票）
##
## 时长预算（秒）：甩牌 0.00-0.35 / 逐张弹分 0.35-1.40 / 指标结算 1.40-2.80
##
## ⚠ 时序一律用 create_timer，**绝不用 await tw.finished**：
##   Tween 被 kill() 时 finished 永远不会发射，await 会永久挂起 = 游戏假死。
## ⚠ 每个 await 之后都要校验 _score_anim_id：动画可能被重开/回主菜单作废。
## ⚠ 本函数不做任何游戏逻辑、不碰任何随机数 —— 它只是「回放」已经算完的流水账。
##   一旦在这里调了带 roll_random 的推演，同种子复现就废了。
func _play_score_animation(ledger: Array, before_all: Dictionary, played: Array, after: Dictionary) -> void:
	const T_FLY_END := 0.35        # 甩牌节拍结束时刻
	const FLY_DUR := 0.26          # 单张牌飞行时长
	const FLY_LAG := 0.035         # 相邻牌甩出的错开间隔
	const FLY_LEAD := 10.0         # 砸桌过冲高度 —— 「重量感」的来源：先冲过头再砸下来
	const FLY_SPACING := 132.0     # 落点间距（牌宽 122 + 10）
	const CARD_BUDGET := 1.30      # 逐张弹分总预算（0.35 → 1.65）
	const CARD_BEAT_MIN := 0.24
	const CARD_BEAT_MAX := 0.45
	const T_TOTAL := 3.00          # 全片目标时长（实测含收尾约 3.45s；玩测反馈偏快，已放慢）
	const METRIC_MIN_STEP := 0.07
	const METRIC_MAX_STEP := 0.55
	const IDLE_WEIGHT := 0.25      # 未变动指标的权重（快速掠过）
	const SHAKE_A := 7.0           # 卡牌抖动振幅（像素）
	const DISMISS_DY := 260.0      # 未选中牌向下滑出的距离（手牌贴屏幕底，260 足够完全出屏）
	const DISMISS_DUR := 0.26      # 滑出时长
	const DISMISS_LAG := 0.012     # 相邻牌轻微错开，做出"扫过去"的层次

	# 玩家在设置里可调的「结算速度」。这里是**时长倍率**（速度的倒数）：
	# 速度 0.5× → 时长 2×。下面每一处节拍都乘它，整段动画才是匀速缩放，
	# 不会出现「某个阶段还是原速」的断层。
	var ds: float = 1.0 / clampf(score_speed, SCORE_SPEED_MIN, SCORE_SPEED_MAX)
	var my_id := _score_anim_id
	var vp := get_viewport().get_visible_rect().size
	var t_start := Time.get_ticks_msec() / 1000.0

	# ---- 建索引：metric → phase → 条目；card_id → 该卡的即时效果 ----
	var by_metric: Dictionary = {}
	for metric in GameState.METRIC_NAMES:
		by_metric[metric] = {}
	var card_fx: Dictionary = {}
	for e in ledger:
		var ph: String = str(e["phase"])
		# crisis 也进小票了：危机结算已从「下回合开局」挪到「回合末」
		# （见 game_state.gd 的 end_turn 注释），所以它本来就该出现在本回合的结算里。
		var mt: String = str(e["metric"])
		if not by_metric.has(mt):
			continue
		if not by_metric[mt].has(ph):
			by_metric[mt][ph] = []
		by_metric[mt][ph].append(e)
		# card_delayed 是延迟效果的「预告」（applied=0），只用来在牌上标「N 回合后」，
		# 不参与小票求和（它不在 SCORE_PHASE_ORDER 里）
		if ph == "card" or ph == "card_delayed":
			var rid: String = str(e["ref_id"])
			if not card_fx.has(rid):
				card_fx[rid] = []
			card_fx[rid].append(e)

	# ---- ① 甩牌（0.00 → 0.35）----
	score_layer.visible = true
	score_receipt.visible = false
	# 把指标条钉回出牌前的值：动画从这里出发，不受之前残留 tween 的影响
	for metric in metric_bars:
		metric_bars[metric]["bar"].value = float(before_all.get(metric, 0))
		metric_bars[metric]["val"].text = str(int(before_all.get(metric, 0)))

	var n_played: int = played.size()
	# 落点间距：默认 FLY_SPACING（牌宽 122 + 10 的余量）。简单模式一回合最多可能出现
	# **5 张**（4 个行动位 + 1 张紧急调度），此时整行 4×132 + 122 = 650px，1280 宽下放得下；
	# 但仍按可用宽度收一道口子 —— 以后若放宽行动位、或窗口比例变化，不至于把牌挤出屏幕。
	# 行本身是**居中**排的（下面 slot 用 k - (n-1)/2 算），所以收紧后左右余量仍然相等。
	var spacing: float = FLY_SPACING
	if n_played > 1:
		var row_limit: float = vp.x * 0.86 - 122.0
		if float(n_played - 1) * FLY_SPACING > row_limit:
			spacing = maxf(96.0, row_limit / float(n_played - 1))
	var slot_y: float = vp.y * 0.42
	for k in n_played:
		var info: Dictionary = card_infos[played[k]]
		var panel: PanelContainer = info["panel"]
		if not is_instance_valid(panel):
			continue
		info["flying"] = true          # 让 _update_card_hover 让出控制权（照抄 shaking 的既有模式）
		panel.z_index = 5              # 保证甩出去的牌画在最上层
		panel.scale = Vector2.ONE
		var slot := Vector2(vp.x * 0.5 + (float(k) - float(n_played - 1) * 0.5) * spacing, slot_y)
		var target: Vector2 = _screen_to_card_box(slot) - panel.pivot_offset
		var d: float = k * FLY_LAG * ds
		var tw := panel.create_tween()
		tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "position", target + Vector2(0, -FLY_LEAD), FLY_DUR * 0.70 * ds).set_delay(d)
		# 末段换成 BACK/EASE_OUT：越过落点再弹回来 —— 这一下就是「砸在桌上」
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "position", target, FLY_DUR * 0.30 * ds)
		var tw_rot := panel.create_tween()
		tw_rot.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_rot.tween_property(panel, "rotation", 0.0, FLY_DUR * 0.85 * ds).set_delay(d)
		# 甩牌落桌：闷响，比叮低一档，做"拍在桌上"的质感
		play_sfx("land", 1.0 + 0.05 * float(k), -4.0)

	# 未选中的牌同步「收走」：向下滑出 + 淡出。
	# 留在原地会变成碍眼的背景，视觉上也说不通 —— 这一手已经打完了。
	# 与选中牌往上飞形成一上一下的分流，读起来就是「打出去的留下、没用的清掉」。
	var dismissed: int = 0
	for i in card_infos.size():
		if played.has(i):
			continue
		var info_u: Dictionary = card_infos[i]
		var panel_u: PanelContainer = info_u["panel"]
		if not is_instance_valid(panel_u):
			continue
		info_u["flying"] = true      # 同样让 _update_card_hover 让出控制权
		# 错开量按「第几张被收走」算，不按手牌下标 —— 否则手牌一多，
		# 最后一张的延迟会拖过 T_FLY_END，跟后面第一处代次校验抢时序。
		var du: float = float(dismissed) * DISMISS_LAG
		dismissed += 1
		var tw_u := panel_u.create_tween()
		tw_u.set_parallel(true)
		tw_u.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw_u.tween_property(panel_u, "position:y", panel_u.position.y + DISMISS_DY, DISMISS_DUR).set_delay(du)
		tw_u.tween_property(panel_u, "modulate:a", 0.0, DISMISS_DUR * 0.75).set_delay(du)
		tw_u.tween_property(panel_u, "scale", Vector2(0.88, 0.88), DISMISS_DUR).set_delay(du)

	await get_tree().create_timer(T_FLY_END * ds).timeout
	if _score_anim_id != my_id:
		return _score_anim_cleanup()

	# ---- ② 逐张弹分（0.35 → 1.40）----
	var card_beat: float = clampf(CARD_BUDGET * ds / float(maxi(1, n_played)), CARD_BEAT_MIN * ds, CARD_BEAT_MAX * ds)
	for k in n_played:
		var info: Dictionary = card_infos[played[k]]
		var panel: PanelContainer = info["panel"]
		if not is_instance_valid(panel):
			continue
		_play_card_shake(panel, SHAKE_A)
		# 连击音阶：逐张升高半音，是小丑牌那种层层叠加感的听觉来源
		# 逐张弹分的叮：连击音阶是灵魂，但**不要给满音量** ——
		# 3~4 张牌各响一次 0dB，和指标合计的 0dB 叠起来能到 9 次满音量，玩测反馈"吵"。
		# 现在压到 -4dB，把"最响"留给指标合计那一下"落定"。
		play_sfx("ding", 1.0 + 0.05 * float(k), -4.0)
		var fx: Array = card_fx.get(str(info["card_id"]), [])
		if wetland and info.has("sandpan_state"):
			wetland.play_action(str(info["card_id"]), info["sandpan_state"], card_beat)
		var anchor: Vector2 = panel.global_position + Vector2(panel.size.x * 0.5, 0.0)
		for j in fx.size():
			var e: Dictionary = fx[j]
			var col: Color = METRIC_COLORS.get(str(e["metric"]), Color.WHITE)
			if str(e["phase"]) == "card_delayed":
				# 延迟预告压暗一档，与「已经落地」的即时效果在视觉上区分开
				col = col.lerp(Color(0.72, 0.70, 0.66), 0.45)
			_play_delta_float(_fmt_delta_line(e), col,
					anchor + Vector2(0.0, -20.0 * float(j)), 0.04 + 0.05 * float(j))
		await get_tree().create_timer(card_beat).timeout
		if _score_anim_id != my_id:
			return _score_anim_cleanup()

	# Delayed effects, synergy, natural evolution and crises follow the card replay.
	# Presentation uses snapshots only; never execute cards or roll RNG again.
	if wetland: wetland.sync_state({}, true, 0.85 * ds)
	# ---- ③+④ 指标结算（→ 2.80）：按已耗时自适应预算，保证总时长贴近 2.8s ----
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - t_start
	# 指标结算节拍的时长倍率（速度 ÷0.8 ⇔ 时长 ×1.25）
	var ms: float = 1.0 / METRIC_SPEED
	var budget: float = maxf(0.6 * ds, T_TOTAL * ds - elapsed) * ms
	var weights: Dictionary = {}
	var wsum: float = 0.0
	for metric in GameState.METRIC_NAMES:
		var w: float = IDLE_WEIGHT
		if _phase_sum(by_metric[metric]) != 0:
			w = 0.55 + 0.14 * float(by_metric[metric].size())
		weights[metric] = w
		wsum += w
	for metric in GameState.METRIC_NAMES:
		var step: float = clampf(budget * float(weights[metric]) / maxf(wsum, 0.001),
				METRIC_MIN_STEP * ms, METRIC_MAX_STEP * ms)
		await _play_metric_settle(metric, by_metric[metric], before_all, after, step)
		if _score_anim_id != my_id:
			return _score_anim_cleanup()

	# ---- 收尾 ----
	await get_tree().create_timer(0.12 * ds).timeout
	if _score_anim_id != my_id:
		return _score_anim_cleanup()
	_score_anim_cleanup()


## 某个指标的四类来源合计（按 applied 求和，天然含 clampi 截断修正）
func _phase_sum(by_phase: Dictionary) -> int:
	var s: int = 0
	for ph in by_phase:
		for e in by_phase[ph]:
			s += int(e["applied"])
	return s


## 单项指标的结算演出：图标放大抖动 → 四类来源小数字依次弹 → 合计 → 数值条推进
func _play_metric_settle(metric: String, by_phase: Dictionary, before_all: Dictionary,
		after: Dictionary, step: float) -> void:
	const ICON_SCALE := 1.75        # 图标放大倍数
	const ICON_UP := 0.07           # 放大耗时
	const ICON_SHAKE := 0.03        # 抖动单次行程
	const ICON_DOWN := 0.09         # 缩回耗时
	const SUB_GAP_MIN := 0.045
	const SUB_GAP_MAX := 0.075
	# 指标结算段的时长倍率（见 METRIC_SPEED）。下面每一处时长都要乘它 ——
	# 少乘一处就会露出「某一段还是原速」的破绽。
	var ms: float = 1.0 / METRIC_SPEED

	var icon: TextureRect = metric_bars[metric]["icon"]
	var bar: ProgressBar = metric_bars[metric]["bar"]
	var val: Label = metric_bars[metric]["val"]
	var row: VBoxContainer = metric_bars[metric]["row"]

	# 图标 pivot 必须运行时取：容器会把图标纵向拉伸，写死尺寸会绕着错的点缩放
	if is_instance_valid(icon):
		icon.pivot_offset = icon.size * 0.5
		var ti := icon.create_tween()
		ti.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ti.tween_property(icon, "scale", Vector2(ICON_SCALE, ICON_SCALE), ICON_UP * ms)
		ti.set_trans(Tween.TRANS_SINE)
		for r in 3:
			ti.tween_property(icon, "rotation", deg_to_rad(7.0), ICON_SHAKE * ms)
			ti.tween_property(icon, "rotation", deg_to_rad(-7.0), ICON_SHAKE * ms)
		ti.tween_property(icon, "rotation", 0.0, ICON_SHAKE * ms)
		ti.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ti.tween_property(icon, "scale", Vector2.ONE, ICON_DOWN * ms)

	# 四类来源：按展示顺序累计真值，最后一段强制对齐录制真值
	var parts: Array = []
	var acc: int = int(before_all.get(metric, 0))
	for ph in SCORE_PHASE_ORDER:
		if not by_phase.has(ph):
			continue
		var v: int = _phase_sum({ph: by_phase[ph]})
		acc += v
		parts.append({"phase": ph, "value": v, "capped": _phase_capped(by_phase[ph]),
				"target": clampi(acc, 0, 100)})
	var true_end: int = int(after.get(metric, acc))
	if not parts.is_empty():
		parts[parts.size() - 1]["target"] = true_end   # ★ 末段对齐真值 → 终点恒正确

	var shown: Array = parts.filter(func(p): return int(p["value"]) != 0)
	# 0.22 是留给「图标各段 + 合计」的固定时间，同样要跟着缩放
	var gap: float = clampf((step - 0.22 * ms) / float(maxi(1, shown.size())),
			SUB_GAP_MIN * ms, SUB_GAP_MAX * ms)

	# 小票：先填第一行并定位，再逐行追加
	_rebuild_receipt(metric, shown, 0, true_end)
	await get_tree().process_frame      # 等容器算完 size 才能定位
	_place_receipt(row)
	for i in shown.size():
		if i > 0:
			_rebuild_receipt(metric, shown, i, true_end)
		# 小数字逐次降 key 且压到 -8dB；合计给 0dB —— 听感是「噼啪数完 → 咚，落定」。
		# 不分层的话，1.4 秒内响十几次会变成机关枪。
		play_sfx("ding", 1.15 - 0.05 * float(i), -11.0)
		var seg: float = gap
		var target_v: int = int(shown[i]["target"])
		var tbs := bar.create_tween()
		tbs.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tbs.tween_property(bar, "value", float(target_v), seg)
		await get_tree().create_timer(seg).timeout

	if shown.is_empty():
		# 该项本轮无变化：图标只放大缩回，数值不动
		await get_tree().create_timer(step).timeout
		return

	# 合计 + 数值文本
	await get_tree().create_timer(maxf(0.0, step * 0.62 - gap * float(shown.size()))).timeout
	_rebuild_receipt(metric, shown, shown.size(), true_end)
	# 合计的那一声是整段里最"重"的落定音（0dB 层里最低频），
	# 其余都压在它之下，听感才是"噼啪数完 → 咚，落定"
	play_sfx("ding", 0.85, -3.0)
	var tbf := bar.create_tween()
	tbf.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tbf.tween_property(bar, "value", float(true_end), maxf(0.10 * ms, step * 0.25))
	val.text = str(true_end)
	var tv := val.create_tween()
	tv.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tv.tween_property(val, "scale", Vector2(1.25, 1.25), 0.06 * ms)
	tv.tween_property(val, "scale", Vector2.ONE, 0.08 * ms)
	await get_tree().create_timer(maxf(0.0, step * 0.38)).timeout


## 该 phase 的条目里有没有被 clampi 截断的（用于「已满/见底」角标）
func _phase_capped(entries: Array) -> bool:
	for e in entries:
		if int(e["applied"]) != int(e["raw"]):
			return true
	return false


## 把一笔增减格式化成「水质 +8」/「水质 +0（已满）」/「水质 +4（2 回合后）」
func _fmt_delta_line(e: Dictionary) -> String:
	var name: String = str(GameState.METRIC_NAMES.get(str(e["metric"]), str(e["metric"])))
	# 延迟效果的预告：显示 raw（未来会生效的值）而不是 applied（恒为 0），
	# 并带上倒计时 —— 否则会显示成「水质 +0」，比不显示更让人困惑
	if str(e["phase"]) == "card_delayed":
		# ⚠ 口径：remaining=1 表示**本回合结算时**就生效，不是「1 回合后」——
		# advance_effects() 在本回合的 end_turn 里就把它减到 0 并立即结算了。
		# 所以 remaining>=2 时，真正还要等的回合数是 remaining-1。
		var rem: int = int(e.get("remaining", 1))
		var when: String = "本回合结算时生效" if rem <= 1 else "%d 回合后生效" % (rem - 1)
		return "%s %+d（%s）" % [name, int(e["raw"]), when]
	var applied: int = int(e["applied"])
	var suffix: String = ""
	if applied != int(e["raw"]):
		suffix = "（已满）" if applied >= 0 else "（见底）"
	return "%s %+d%s" % [name, applied, suffix]


## 算分小票：重建内容并滑到当前指标行的左侧
##   shown       = 需要展示的来源行 [{phase, value, capped, target}]
##   reveal_cnt  = 显示到第几行（传 shown.size() 表示再追加「合计」行）
func _rebuild_receipt(metric: String, shown: Array, reveal_cnt: int, true_end: int) -> void:
	if score_receipt_box == null:
		return
	for c in score_receipt_box.get_children():
		c.queue_free()
	var col: Color = METRIC_COLORS.get(metric, Color.WHITE)
	for i in mini(reveal_cnt, shown.size()):
		var p: Dictionary = shown[i]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var nm := _make_label(str(SCORE_PHASE_NAMES.get(str(p["phase"]), str(p["phase"]))), 11,
				Color(0.68, 0.66, 0.62))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(nm)
		var v: int = int(p["value"])
		var txt: String = "%+d" % v
		var vc: Color = col
		if bool(p["capped"]):
			txt += "（已满）" if v >= 0 else "（见底）"
			vc = Color(0.62, 0.60, 0.56)
		hb.add_child(_make_label(txt, 13, vc))
		score_receipt_box.add_child(hb)
	if reveal_cnt >= shown.size():
		var hb2 := HBoxContainer.new()
		hb2.add_theme_constant_override("separation", 8)
		var nm2 := _make_label("合计", 13, Color(0.90, 0.86, 0.78))
		nm2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb2.add_child(nm2)
		hb2.add_child(_make_label("%+d" % true_end, 15, col))
		score_receipt_box.add_child(hb2)
	score_receipt.visible = true


## 把小票滑到指标行的左侧（避开右上角的牌堆区域）
func _place_receipt(row: VBoxContainer) -> void:
	if score_receipt == null or row == null or not is_instance_valid(row):
		return
	var vp := get_viewport().get_visible_rect().size
	var rg: Rect2 = row.get_global_rect()
	var target := Vector2(
		rg.position.x - score_receipt.size.x - 10.0,
		clampf(rg.get_center().y - score_receipt.size.y * 0.5, 6.0, vp.y - score_receipt.size.y - 6.0))
	var tw := score_receipt.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(score_receipt, "position", target, 0.12 / METRIC_SPEED)


## 卡牌抖动：在**当前位置**上抖（甩牌后牌已经不在 base_pos 了）
func _play_card_shake(panel: PanelContainer, amp: float) -> void:
	const SHAKE_T := 0.035
	var base: Vector2 = panel.position
	var tw := panel.create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	for i in 3:
		tw.tween_property(panel, "position:x", base.x + amp, SHAKE_T)
		tw.tween_property(panel, "position:x", base.x - amp, SHAKE_T)
	tw.tween_property(panel, "position:x", base.x, SHAKE_T * 1.2)


## 卡牌上方弹出「+N」飘字：弹入 → 停留 → 上升淡出
func _play_delta_float(text: String, color: Color, anchor: Vector2, delay: float) -> void:
	if score_floats == null:
		return
	var l := _make_label(text, 18, color)
	l.position = anchor + Vector2(-60.0, -14.0)
	l.custom_minimum_size = Vector2(120.0, 0.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(60.0, 10.0)
	l.modulate.a = 0.0
	l.scale = Vector2(0.6, 0.6)
	score_floats.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.10).set_delay(delay)
	tw.tween_property(l, "modulate:a", 1.0, 0.08).set_delay(delay)
	tw.chain().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "position:y", l.position.y - 26.0, 0.30)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.30)


## 唯一的复位出口：成功播完与中途作废都走这里。
## ⚠ _update_hud() 必须在 _score_animating = false **之后**调，
##   否则会被它自己的抑制逻辑吞掉，指标条永远停在动画中途的值。
func _score_anim_cleanup() -> void:
	_score_animating = false
	for info in card_infos:
		var panel: PanelContainer = info.get("panel")
		if not is_instance_valid(panel):
			continue
		if info.get("flying", false):
			info["flying"] = false
			panel.z_index = 0
			panel.scale = Vector2.ONE
			# 未选中的牌是被淡出收走的，必须把 alpha 也复位，
			# 否则中断复位后它们会以全透明状态"复活"
			panel.modulate.a = 1.0
			panel.rotation = info.get("theta", 0.0)
			panel.position = info.get("base_pos", panel.position)
	if score_layer != null:
		score_layer.visible = false
	if score_receipt != null:
		score_receipt.visible = false
	if score_floats != null:
		for c in score_floats.get_children():
			c.queue_free()
	_update_hud()
	_update_3d()


func _on_resolve_continue() -> void:
	var kid := GameState.pop_pending_knowledge()
	if kid != "":
		_show_knowledge(kid)
	else:
		_advance_to_next()


func _show_knowledge(card_id: String) -> void:
	# 这张卡真的弹到玩家面前了 = 收集到 → 记进跨局的知识卡收藏，主页图鉴里就亮了。
	# unlock() 自带幂等闸门，重复调不会出事。
	Knowledge.unlock(card_id)
	_current_phase = "popup_knowledge"
	var k: Dictionary = GameState.KNOWLEDGE_CARDS[card_id]
	var body := _knowledge_detail_text(card_id, true)
	_show_popup("知识卡 · %s" % k["name"], body, "收下（继续）", _on_resolve_continue)
	if card_id == "egg_dixinhu":
		var reveal := CenterContainer.new()
		reveal.custom_minimum_size.y = 176
		reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup_body.get_parent().add_child(reveal)
		popup_body.get_parent().move_child(reveal, 1)
		_knowledge_egg_reveal = reveal
		var card := _make_knowledge_card(card_id, true)
		reveal.add_child(card)
		card.pivot_offset = Vector2(61, 82.5)
		card.scale = Vector2(0.65, 0.65)
		card.rotation = -0.12
		card.modulate.a = 0.0
		var arrival := card.create_tween().set_parallel(true)
		arrival.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		arrival.tween_property(card, "scale", Vector2.ONE, 0.65)
		arrival.tween_property(card, "rotation", 0.0, 0.65)
		arrival.tween_property(card, "modulate:a", 1.0, 0.35)


func _advance_to_next() -> void:
	if GameState.game_over:
		_show_report(GameState.generate_report())
	else:
		GameState.start_new_turn()
		# start_new_turn 会触发事件信号（有事件回合）。无事件回合不弹窗，
		# 但知识卡弹窗此时已经关闭，所以直接进入分配阶段即可。
		# 危机警示是独立弹层，也计入「有弹窗」判断，避免危机弹窗未关就发牌。
		if not popup_root.visible and not crisis_root.visible:
			_enter_allocate()


func _on_game_end(report: Dictionary) -> void:
	# 中途判负（出牌 / 危机爆发）→ 立刻把失败报告推到玩家面前，
	# 不让他继续出牌、产生「还能救」的错觉。
	if _defer_game_over:
		return      # 回合结算流程：结算反馈展示完，由 _advance_to_next 再出报告
	if _current_phase == "popup_report":
		return      # 报告已经开着，别叠层
	if report.get("is_failure", false):
		_crisis_queue.clear()
		crisis_root.visible = false   # 危机警示让位给失败报告，不留残影
		_banner_override = ""         # 横幅也一起交还给实时态势
		_show_report(report)


func _show_report(r: Dictionary) -> void:
	_current_phase = "popup_report"
	_clear_save()  # 一局已结束，清掉存档（不能再继续）
	# 通关成就必须在**这里**判，不能放进 _on_game_end：
	# 打满回合的通关走的是 _finish_turn → _advance_to_next → _show_report 这条路，
	# 而 _on_game_end 只处理判负（`if report.is_failure`），通关时它什么都不做；
	# 何况结算期间 _defer_game_over 还会让它整个提前 return。
	# _show_report 是两种结局的唯一汇合点，判在这里才不会漏。
	# 只认「不是判负」，不看分数档位 —— 困难难度能撑满 16 回合本身就是成就。
	if bool(r.get("victory", false)) and int(r.get("turns_survived", 0)) >= GameState.TOTAL_TURNS and GameState.difficulty == GameState.Difficulty.HARD:
		Achievements.try_unlock("hard_clear")
	# 「被做局了」：噩梦档第 1 或第 2 回合就被撤换。
	# 这个模式本来就打不过，能死得这么快纯粹是开局掷得差（或运气）——
	# 所以它是枚**纪念章**，不是惩罚。turns_survived 就是死亡时的回合号（见 generate_report）。
	if bool(r.get("is_failure", false)) \
			and GameState.difficulty == GameState.Difficulty.NIGHTMARE \
			and int(r.get("turns_survived", 0)) <= 2:
		Achievements.try_unlock("rigged")
	# 「廉政先锋」：通关，且全程平均每回合花费不到门槛。
	# 用 total_spent / 总回合数 这个**均值**口径，而不是"每一回合都得少花"——
	# 后者太苛刻：玩家偶尔砸一张大牌救火就会被判出局，不给人留余地。
	if bool(r.get("victory", false)) \
			and int(r.get("turns_survived", 0)) >= GameState.TOTAL_TURNS \
			and float(GameState.total_spent) / float(GameState.TOTAL_TURNS) <= float(Achievements.THRIFTY_SPEND_PER_TURN):
		Achievements.try_unlock("thrifty")
	var reward: Dictionary = Talents.claim_victory_report(r)
	var body := ""
	var title := "四年 · 生态报告"
	if bool(r.get("victory", false)) and int(r.get("turns_survived", 0)) < GameState.TOTAL_TURNS:
		title = "提前胜利 · 生态报告"
	if r.get("is_failure", false):
		title = "被撤换 · 修复失败"
		body += "[color=#ff7060][b]第 %d 回合，%s[/b][/color]\n\n" % [
			r.get("turns_survived", 0), r.get("failure_reason", "生态崩溃")]
		# 死因：点名是哪个指标先崩的、崩到多少、线在哪 —— 玩家才知道自己输在哪
		var fm: String = str(r.get("failure_metric", ""))
		if fm != "":
			var fname: String = str(r.get("failure_metric_name", fm))
			var fval: int = int(r.get("failure_value", GameState.metrics.get(fm, 0)))
			var fthr: int = int(r.get("failure_threshold", GameState.failure_threshold_for(fm)))
			body += "[b]直接死因：[/b]%s 跌至 [color=#ff9090]%d[/color]（生态红线 %d）\n" % [fname, fval, fthr]
			var remedy: String = str(GameState.METRIC_REMEDY.get(fm, ""))
			if remedy != "":
				body += "[color=#8fd0ff]补强建议：%s[/color]\n" % remedy
		var below: Array = r.get("metrics_below", [])
		if below.size() > 1:
			var parts: Array = []
			for e in below:
				parts.append("%s %d" % [GameState.METRIC_NAMES.get(e["metric"], e["metric"]), int(e["value"])])
			body += "[color=#c08080]同一回合跌破生态红线的还有：%s[/color]\n" % "、".join(parts)
		if GameState.last_crisis_name != "":
			body += "[color=#c08080]本回合危机：%s[/color]\n" % GameState.last_crisis_name
		body += "你的修复工作被迫中止。这不是终点——换一个策略，再试一次。\n\n"
	body += "[b]生态维度[/b]（%s）\n" % r["eco"]["grade"]
	for n in r["eco"]["notes"]:
		body += "  · %s\n" % n
	body += "\n[b]社会维度[/b]（%s）\n" % r["social"]["grade"]
	for n in r["social"]["notes"]:
		body += "  · %s\n" % n
	body += "\n[b]管理维度[/b]（%s）\n" % r["manage"]["grade"]
	for n in r["manage"]["notes"]:
		body += "  · %s\n" % n
	body += "\n[b]知识卡收集[/b]：%d / %d　[b]科研点[/b]：%d\n" % [r["knowledge_count"], r["total_knowledge"], r["research_points"]]
	body += "[color=#8a8a8a]本局种子：%d（同种子可复现，便于对照实验）[/color]\n" % r.get("seed", 0)
	if reward.save_error:
		body += "[color=#ff9090]通关奖励未能保存，请检查本地存档目录。[/color]\n"
	elif reward.duplicate:
		body += "[color=#9dd5bd]本局通关奖励已领取。[/color]\n"
	elif reward.mastery:
		body += "[color=#ffd060][b]噩梦通关奖励：全部天赋满级，解除分配上限！[/b][/color]\n"
	elif int(reward.amount) > 0:
		body += "[color=#ffd060]通关获得灵感：+%d　（当前 %d）[/color]\n" % [reward.amount, Talents.inspiration]
	else:
		body += "[color=#9dd5bd]胜利通关（含提前胜利）可获得灵感，本次未获得。[/color]\n"
	body += "\n[b]反思[/b]\n%s" % r["reflection"]
	_show_popup(title, body, "返回主菜单", _restart)


func _restart() -> void:
	_playing = false
	_current_event = ""
	_banner_override = ""
	# 回到主菜单，让玩家可重新输入种子（留空则随机）
	_show_menu()


# ==================== 通用弹窗 ====================
func _show_popup(title: String, body: String, button_text: String, on_continue: Callable) -> void:
	if is_instance_valid(_knowledge_egg_reveal):
		_knowledge_egg_reveal.get_parent().remove_child(_knowledge_egg_reveal)
		_knowledge_egg_reveal.queue_free()
		_knowledge_egg_reveal = null
	if _popup_reveal and _popup_reveal.is_valid(): _popup_reveal.kill()
	popup_title.text = title
	popup_body.text = body
	popup_button.text = button_text
	_popup_continue = on_continue
	popup_root.visible = true
	# 面板 pivot 需要等布局完成后再设，否则用旧尺寸缩放会偏移
	popup_panel.pivot_offset = popup_panel.size * 0.5
	# 弹窗淡入 + 面板轻微弹入（玩家等待中的反馈，用稍长时长更从容）
	popup_root.modulate.a = 0.0
	popup_panel.scale = Vector2(0.94, 0.94)
	var tw := popup_root.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup_root, "modulate:a", 1.0, 0.18)
	var tw2 := popup_panel.create_tween()
	tw2.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(popup_panel, "scale", Vector2.ONE, 0.24)
	# 正文打字机效果：逐字从左到右、从上到下依次打出
	popup_body.visible_ratio = 1.0
	popup_body.visible_characters = 0
	var total := popup_body.get_total_character_count()
	var reveal_time: float = clampf(total * 0.016, 0.3, 2.5)
	var tw3 := popup_body.create_tween()
	_popup_reveal = tw3
	tw3.set_trans(Tween.TRANS_LINEAR)
	tw3.tween_property(popup_body, "visible_characters", total, reveal_time).set_delay(0.1)


func _on_popup_button() -> void:
	# 若正文还在逐字打字中，第一次点击先把文字补全（避免误关）
	if popup_body.visible_characters >= 0 and popup_body.visible_characters < popup_body.get_total_character_count():
		if _popup_reveal and _popup_reveal.is_valid(): _popup_reveal.kill()
		popup_body.visible_characters = -1
		return
	popup_root.visible = false
	var cb := _popup_continue
	_popup_continue = Callable()
	if cb.is_valid():
		cb.call()


# ==================== 控件工厂 ====================
func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _snap_px(size))
	l.add_theme_color_override("font_color", color)
	return l


## danger = true 时换成暗红木纹 + 浅红字：危险操作（清空存档）要一眼看出来
func _make_button(text: String, cb: Callable, size: int, danger: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", _snap_px(size))
	VisualTheme.style_button(b, danger)
	b.mouse_entered.connect(func(): VisualTheme.button_feedback(b, true))
	b.mouse_exited.connect(func(): VisualTheme.button_feedback(b, false))
	b.focus_entered.connect(func(): VisualTheme.button_feedback(b, true))
	b.focus_exited.connect(func(): VisualTheme.button_feedback(b, false))
	b.pressed.connect(cb)
	return b


func _wood_button(bg: Color, border: Color) -> StyleBoxFlat:
	return VisualTheme.box(bg, border, 7)


func _panel_style(p: PanelContainer, color: Color) -> void:
	# Slate surfaces and warm paper keep small text legible over the meadow.
	var bg := Color("765653") if color.r > color.g * 1.8 else VisualTheme.PANEL
	bg.a = 0.97 if color.a < 0.9 else 0.99
	p.add_theme_stylebox_override("panel", VisualTheme.box(bg, VisualTheme.EDGE))


## 左侧/右侧信息面板滑出屏幕（结算后）或滑回（下一回合开始）
func _slide_side_panels(out: bool) -> void:
	# 收出屏幕后额外留的余量（像素）。必须让整块面板离开可视区。
	const GAP := 24.0
	if left_panel == null or right_panel == null:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if out:
		var lw := left_panel.offset_right - left_panel.offset_left
		var rw := right_panel.offset_right - right_panel.offset_left
		# 左面板锚在左缘：offset 取负值 = 移到屏幕左侧之外
		tw.tween_property(left_panel, "offset_left", -lw - GAP, 0.35)
		tw.tween_property(left_panel, "offset_right", -GAP, 0.35)
		# 右面板锚在**右缘**（anchor_left = anchor_right = 1.0，x = 屏宽 + offset）：
		# offset 必须取**正值**才表示移出屏幕右侧。
		# ⚠ 原实现照抄了左面板的负号（-6 / rw-6），结果是面板左缘停在「屏宽-6」处，
		#   屏幕上残留 6px 的一条边 —— 方向反了，等于往屏幕里推。
		tw.tween_property(right_panel, "offset_left", GAP, 0.35)
		tw.tween_property(right_panel, "offset_right", rw + GAP, 0.35)
	else:
		tw.tween_property(left_panel, "offset_left", 18, 0.35)
		tw.tween_property(left_panel, "offset_right", 222, 0.35)
		tw.tween_property(right_panel, "offset_left", -210, 0.35)
		tw.tween_property(right_panel, "offset_right", -18, 0.35)


# ==================== 像素图标 ====================
## 从字符网格生成像素图标纹理（'#'=描边, 'X'=主色, 'o'=高光, '.'=透明）
func _pixel_icon(grid: String, main: Color, dark: Color, light: Color) -> ImageTexture:
	return ImageTexture.create_from_image(_grid_image(grid, main, dark, light))


## 把网格字符串解析成 Image（# 深色 / X 主色 / o 高亮）
func _grid_image(grid: String, main: Color, dark: Color, light: Color) -> Image:
	var rows: Array = []
	for r in grid.split("\n"):
		var line: String = (r as String).strip_edges()
		if line != "":
			rows.append(line)
	var h := rows.size()
	var w := (rows[0] as String).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var line: String = rows[y]
		for x in w:
			match line[x]:
				"#": img.set_pixel(x, y, dark)
				"X": img.set_pixel(x, y, main)
				"o": img.set_pixel(x, y, light)
				_: img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img


## 生成放大到约 px 宽的像素图标**纹理**（最近邻，保持锐利）。
## 与 _make_icon 的区别：那个返回 TextureRect 控件，用于往容器里塞；
## 这个返回 Texture，因为 Button.icon 和运行时换图要的是纹理本身。
func _pixel_icon_sized(grid: String, main_color: Color, px: int) -> ImageTexture:
	var img := _grid_image(grid, main_color, main_color.darkened(0.38), main_color.lightened(0.32))
	var scale := maxi(1, int(round(float(px) / maxf(1.0, float(img.get_width())))))
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## 生成指定显示尺寸的像素图标控件（最近邻放大保持锐利）
func _make_icon(grid: String, main: Color, px: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _pixel_icon(grid, main, main.darkened(0.38), main.lightened(0.32))
	tr.custom_minimum_size = Vector2(px, px)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return tr


## 各数值/指标对应的像素图标网格
func _icon_grid_for(kind: String) -> String:
	match kind:
		"coin":
			return """..####..
.#XXXX#.
#XooXXX#
#XooXXX#
#XXXXXX#
#XXXXXX#
.#XXXX#.
..####.."""
		"water_level":
			return """...##...
..#XX#..
.#XooX#.
.#XXXX#.
.#XXXX#.
..#XX#..
...##...
........"""
		"vegetation":
			return """....#...
....##..
..###X#.
.###XX#.
.###XX#.
..###...
....#...
........"""
		"water_quality":
			return """...##...
...##...
..#XX#..
.#XXXX#.
#XXXXXX#
#XXXXXX#
.#XXXX#.
..####.."""
		"fish":
			return """........
..##....
.####..#
#######.
.####..#
..##....
........
........"""
		"birds":
			return """........
..##....
.#####.#
#######.
.####...
..##....
........
........"""
		"community":
			return """........
.##..##.
#XX##XX#
#XXXXXX#
#XXXXXX#
.#XXXX#.
..####..
...##..."""
		"research":
			return """........
.#######
.#######
.#######
.#.#.#.#
.#######
........
........"""
	return ""


# ==================== 像素字体 ====================
## 加载中文像素字体（缝合像素/融合像素，OFL 授权）并设为全局默认字体
func _setup_pixel_font() -> void:
	# 用 load() 读导入后的 FontFile，导出包（.pck）里也能正确加载
	var zh: FontFile = load("res://fonts/fusion-pixel-12px-monospaced-zh_hans.ttf")
	if zh == null:
		return
	var latin: FontFile = load("res://fonts/fusion-pixel-12px-monospaced-latin.ttf")
	if latin != null:
		zh.fallbacks = [latin]
	# 关抗锯齿 + 整数像素对齐，保证像素字体锐利
	zh.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	zh.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	ThemeDB.fallback_font = zh
	var theme := Theme.new()
	theme.default_font = zh
	theme.default_font_size = 12
	theme.set_stylebox("panel", "TooltipPanel", VisualTheme.box(VisualTheme.INK, VisualTheme.GOLD))
	theme.set_color("font_color", "TooltipLabel", VisualTheme.PAPER)
	theme.set_font_size("font_size", "TooltipLabel", 12)
	for state in ["normal", "focus", "read_only"]:
		theme.set_stylebox(state, "LineEdit", VisualTheme.box(VisualTheme.INK, VisualTheme.EDGE, 8))
	theme.set_color("font_color", "LineEdit", VisualTheme.PAPER)
	get_tree().root.theme = theme


## 把字号吸附到像素字体的原生尺寸（12px 的整数倍），避免缩放发虚
func _snap_px(s: int) -> int:
	return maxi(12, int(round(s / 12.0)) * 12)
