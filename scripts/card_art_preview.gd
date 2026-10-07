extends CanvasLayer
## Display-only test card: does not enter the draw pool or write player saves.
const ART := preload("res://assets/art/artist-test-card.png")
const BLANK := preload("res://assets/art/artist-test-card-blank.png")
const PixelCardArt = preload("res://scripts/pixel_card_art.gd")
const FONT := preload("res://fonts/fusion-pixel-12px-monospaced-zh_hans.ttf")
const VisualTheme = preload("res://scripts/visual_theme.gd")
var card_pictures: Array[TextureRect] = []
var root: Control
var preview_cards: Array[Control] = []

func _ready() -> void:
	layer = 30
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color("102f35f5")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(_label("美术测试卡 · 费用与图片", 24))
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 72)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(cards)
	for entry in [{"size": Vector2(122, 183), "title": "手牌尺寸"}, {"size": Vector2(288, 432), "title": "放大查看"}]:
		var section := VBoxContainer.new()
		cards.add_child(section)
		section.add_child(_label(entry.title, 18))
		var center := CenterContainer.new()
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		section.add_child(center)
		center.add_child(_make_card(entry.size))
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 16)
	column.add_child(controls)
	for amount in [60, 600, 9999]:
		var price := Button.new()
		price.text = str(amount)
		price.add_theme_font_override("font", FONT)
		price.custom_minimum_size = Vector2(150, 42)
		VisualTheme.style_button(price)
		price.pressed.connect(_update_cost.bind(float(amount)))
		controls.add_child(price)
	var close := Button.new()
	close.text = "返回游戏"
	close.add_theme_font_override("font", FONT)
	close.custom_minimum_size = Vector2(160, 42)
	VisualTheme.style_button(close)
	close.pressed.connect(queue_free)
	controls.add_child(close)
	column.add_child(_label("人偶仿宋 16 px · 阿拉伯数字费用 · 直接写入原图像素", 16))
	_update_cost(600)
	root.resized.connect(_fit_cards)
	_fit_cards()
	# Opt-in capture for visual verification of the actual game viewport.
	if "--card-art-capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screenshots/artist-test-card.png")

func _label(content: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = content
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", VisualTheme.PAPER)
	return label

func _make_card(dimensions: Vector2) -> Control:
	var card := Control.new()
	card.name = "ArtistTestCard"
	card.custom_minimum_size = dimensions
	card.size = dimensions
	preview_cards.append(card)
	var picture := TextureRect.new()
	picture.texture = ART
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(picture)
	card_pictures.append(picture)
	return card

func _update_cost(value: float) -> void:
	var texture := PixelCardArt.texture("测试卡", str(clampi(int(value), 0, 9999)))
	for picture in card_pictures:
		picture.texture = texture


func _fit_cards() -> void:
	if preview_cards.size() != 2:
		return
	var height := minf(432.0, maxf(183.0, get_viewport().get_visible_rect().size.y - 220.0))
	preview_cards[1].custom_minimum_size = Vector2(height * 2.0 / 3.0, height)
	preview_cards[1].size = preview_cards[1].custom_minimum_size
