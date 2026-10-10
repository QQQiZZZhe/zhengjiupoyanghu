extends RefCounted

const Motion = preload("res://scripts/motion.gd")
## Shared presentation tokens. No gameplay state is changed here.
const INK := Color("303e49")
const PANEL := Color("44565c")
const EDGE := Color("91a397")
const PAPER := Color("f5ecd8")
const GOLD := Color("edc68a")
const MINT := Color("c7dcae")
const MEADOW := Color("b8c66d")
const SUMMER_MEADOW := Color("a4bd65")
const AUTUMN_MEADOW := Color("d8ad71")
const SNOW := Color("edf1e9")
const WATER_DEEP := Color("526e86")
const WATER_MID := Color("779ba9")
const WATER_SHALLOW := Color("acc9ce")
const SAND := Color("e0c89b")
const SOIL := Color("baaa86")
const ART := preload("res://assets/art/conservation-cards.png")

static func box(bg: Color, edge: Color, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0.12, 0.16, 0.20, 0.30)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 4)
	return s

static func card_style(selected: bool = false) -> StyleBoxFlat:
	var s := box(Color.TRANSPARENT, GOLD, 0)
	s.set_border_width_all(0)
	s.set_meta("card_outline", selected)
	s.set_corner_radius_all(0)
	# 卡牌投影由独立接收平面绘制，StyleBox 阴影会随卡面一起旋转。
	s.shadow_size = 0
	s.shadow_color = Color(0.02, 0.10, 0.11, 0.55)
	return s

static func illustration(card: Dictionary) -> AtlasTexture:
	var category := str(card.get("category", "ecology"))
	var column: int = {"ecology": 0, "social": 1, "manage": 2}.get(category, 0)
	# Stable artwork selection without consuming the game's random generator.
	var row := posmod(str(card.get("id", "")).hash(), 2)
	var tile := Vector2(ART.get_width() / 3.0, ART.get_height() / 2.0)
	var atlas := AtlasTexture.new()
	atlas.atlas = ART
	atlas.region = Rect2(Vector2(column, row) * tile, tile)
	atlas.filter_clip = true
	return atlas

static func style_button(b: Button, danger: bool = false, primary: bool = false) -> void:
	preload("res://scripts/motion_button.gd").attach(b)
	var base := Color("895e59") if danger else PANEL
	var accent := Color("efb7a1") if danger else MINT
	if primary:
		base = GOLD
		accent = Color("fff0b7")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var bg := base
		if state == "hover": bg = base.lightened(0.15)
		if state == "pressed": bg = base.darkened(0.18)
		if state == "disabled": bg = Color("526164")
		var s := box(bg, accent if state == "hover" else base.lightened(0.22), 7)
		s.shadow_size = 1 if state == "pressed" else 4
		s.shadow_offset.y = 1 if state == "pressed" else 3
		b.add_theme_stylebox_override(state, s)
	var focus := box(Color(0, 0, 0, 0), GOLD, 7)
	focus.shadow_size = 0
	b.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, INK if primary else PAPER)
	b.add_theme_color_override("font_disabled_color", Color("8b9b94"))

static func button_feedback(b: Button, active: bool) -> void:
	var previous: Tween = b.get_meta("feedback_tween") if b.has_meta("feedback_tween") else null
	if previous and previous.is_valid(): previous.kill()
	var tw := Motion.tween(b, "response", "feedback")
	b.set_meta("feedback_tween", tw)
	tw.tween_property(b, "modulate", Color(1.09, 1.09, 1.04) if active else Color.WHITE, 0.14)
