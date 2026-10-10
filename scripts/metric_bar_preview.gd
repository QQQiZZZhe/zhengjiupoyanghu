extends Control
const LOSS_COLOR := Color("ef5350")
var effects_owner: Node
var bar: ProgressBar
var tint := Color.WHITE
var current := 0.0
var predicted := 0.0
var _clip: Control
var _background: ProgressBar
var _fill: ProgressBar
var _join_clip: Control
var _join_fill: ProgressBar
var _loss_fill: StyleBoxFlat

func _ready() -> void:
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_background = ProgressBar.new()
	_fill = ProgressBar.new()
	for layer in [_background, _fill]:
		layer.show_percentage = false
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		layer.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
		_clip.add_child(layer)
	_background.add_theme_stylebox_override("background", bar.get_theme_stylebox("background"))
	_fill.add_theme_stylebox_override("fill", bar.get_theme_stylebox("fill"))
	# Only the forecast loss segment uses red; keep the live bar style untouched.
	_loss_fill = bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_loss_fill.bg_color = LOSS_COLOR
	_loss_fill.border_color = LOSS_COLOR.lightened(0.2)
	# Cover the old rounded tip with the body of the longer fill. Clipping
	# only after the old endpoint leaves its inward curve visible as a gap.
	_join_clip = Control.new()
	_join_clip.clip_contents = true
	_join_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_join_clip)
	_join_fill = ProgressBar.new()
	_join_fill.show_percentage = false
	_join_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_join_fill.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	_join_fill.add_theme_stylebox_override("fill", bar.get_theme_stylebox("fill"))
	_join_clip.add_child(_join_fill)
	resized.connect(_layout_segment)

func fill_end(value: float) -> float:
	# Match ProgressBar's rounded pixel width and fill style minimum size.
	var minimum := bar.get_theme_stylebox("fill").get_minimum_size().x
	var pixels := roundf(clampf(value / 100.0, 0.0, 1.0) * (bar.size.x - minimum))
	return pixels + minimum if pixels > 0.0 else 0.0

func segment_rect() -> Rect2:
	var left := fill_end(minf(current, predicted))
	var right := fill_end(maxf(current, predicted))
	return Rect2(Vector2(left, 0.0), Vector2(maxf(0.0, right - left), bar.size.y))

func _layout_segment() -> void:
	if not is_instance_valid(_clip) or bar == null: return
	var segment := segment_rect()
	_clip.position = segment.position
	_clip.size = segment.size
	for layer in [_background, _fill]:
		layer.position = -segment.position
		layer.size = bar.size
	_background.visible = predicted < current
	_background.value = 0.0
	_fill.value = maxf(current, predicted)
	_join_clip.visible = predicted > current and current > 0.0
	var style := bar.get_theme_stylebox("fill") as StyleBoxFlat
	var radius := float(maxi(style.corner_radius_top_right, style.corner_radius_bottom_right)) if style else 5.0
	var boundary := fill_end(current)
	var start := maxf(0.0, boundary - radius - 1.0)
	_join_clip.position = Vector2(start, 0.0)
	_join_clip.size = Vector2(boundary - start, bar.size.y)
	_join_fill.position = Vector2(-start, 0.0)
	_join_fill.size = bar.size
	_join_fill.value = predicted

func configure(before: float, after: float) -> void:
	current = clampf(before, 0.0, 100.0)
	predicted = clampf(after, 0.0, 100.0)
	visible = not is_equal_approx(current, predicted)
	set_process(visible)
	_layout_segment()
	if is_instance_valid(_fill):
		_fill.add_theme_stylebox_override("fill", _loss_fill if predicted < current else bar.get_theme_stylebox("fill"))
		_fill.modulate.a = blink_alpha()

func blink_alpha() -> float:
	var reduce: bool = effects_owner.wetland != null and effects_owner.wetland.reduced_motion
	return 0.75 if reduce else 0.28 + 0.72 * (0.5 + 0.5 * sin(effects_owner._metric_preview_clock * TAU * 1.1))

func _process(_dt: float) -> void:
	if not is_visible_in_tree(): return
	_fill.modulate.a = blink_alpha()
