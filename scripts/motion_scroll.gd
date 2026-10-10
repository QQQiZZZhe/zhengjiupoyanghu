extends Node
## wheel-rail adapted to native ScrollContainer: nearest scroller owns the wheel.
## Dragging the scrollbar, keyboard focus and touch remain native.
const Physics = preload("res://scripts/motion_web.gd")
var bar: ScrollBar
var target := 0.0
var current := 0.0
var writing := false

static func attach(scroll: ScrollContainer) -> void:
	if scroll.has_node("MotionWebScroll"): return
	var driver: Node = load("res://scripts/motion_scroll.gd").new()
	driver.name = "MotionWebScroll"
	scroll.add_child(driver)

func _ready() -> void:
	add_to_group("motion_scrollers")
	set_process(false)
	get_parent().visibility_changed.connect(_hide)

func _hide() -> void:
	if not get_parent().is_visible_in_tree():
		if bar: current = bar.value; target = current
		set_process(false)

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed: return
	if event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]: return
	var scroll := get_parent() as ScrollContainer
	if not scroll.is_visible_in_tree() or Physics.paused(self): return
	if not scroll.get_global_rect().has_point(event.position): return
	var host := get_tree().get_first_node_in_group("motion_host")
	if host:
		for overlay in [host.popup_root, host.crisis_root, host.card_detail, host.knowledge_detail]:
			if not overlay.visible or overlay.is_ancestor_of(scroll): continue
			# Returning alone lets native GUI dispatch scroll the covered list.
			# A foreground control keeps its own native wheel handling.
			var foreground := get_viewport().gui_get_hovered_control()
			if foreground and overlay.is_ancestor_of(foreground): return
			get_viewport().set_input_as_handled()
			return
	var hovered := get_viewport().gui_get_hovered_control()
	while hovered and not hovered is ScrollContainer:
		if hovered is Range and hovered.get_global_rect().has_point(event.position): return
		hovered = hovered.get_parent_control()
	if hovered and hovered != scroll and hovered.get_global_rect().has_point(event.position): return
	# _input precedes GUI picking. A moving card can invalidate last-frame hover;
	# use the wheel's actual point as fallback, while giving nested scrollers priority.
	for driver in get_tree().get_nodes_in_group("motion_scrollers"):
		var nested := driver.get_parent() as ScrollContainer
		if nested != scroll and scroll.is_ancestor_of(nested) and nested.is_visible_in_tree() and nested.get_global_rect().has_point(event.position): return
	var horizontal: bool = event.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT] or Input.is_key_pressed(KEY_SHIFT)
	var candidate: ScrollBar = scroll.get_h_scroll_bar() if horizontal else scroll.get_v_scroll_bar()
	if candidate.max_value <= candidate.page:
		candidate = scroll.get_h_scroll_bar()
	if candidate.max_value <= candidate.page: return
	if bar != candidate:
		if bar and bar.value_changed.is_connected(_native_change): bar.value_changed.disconnect(_native_change)
		bar = candidate
		bar.value_changed.connect(_native_change)
		current = bar.value
		target = current
	var direction := -1.0 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1.0
	var next := clampf(target + direction * 72.0 * maxf(0.05, event.factor), bar.min_value, bar.max_value - bar.page)
	if is_equal_approx(next, target):
		# Finish the pending travel before handing the wheel back at the end.
		if is_processing() and absf(current - target) >= 0.4: get_viewport().set_input_as_handled()
		return
	target = next
	get_viewport().set_input_as_handled()
	if Physics.reduced(self):
		current = target
		_write()
	else: set_process(true)

func _native_change(value: float) -> void:
	if writing: return
	current = value
	target = value
	set_process(false)

func _write() -> void:
	writing = true
	bar.value = round(current)
	writing = false

func _process(dt: float) -> void:
	if Physics.paused(self): return
	target = clampf(target, bar.min_value, maxf(bar.min_value, bar.max_value - bar.page))
	current = target if Physics.reduced(self) else Physics.follow(current, target, dt, 12.0)
	if absf(current - target) < 0.4:
		current = target
		set_process(false)
	_write()
