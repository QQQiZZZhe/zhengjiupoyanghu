extends PanelContainer
signal back_requested
const VisualTheme := preload("res://scripts/visual_theme.gd")
const NODE_SIZE := Vector2(112, 52)
const GRAPH_MARGIN := Vector2(96, 12)
const COLUMN_STEP := 126.0
const LAYER_STEP := 100.0
const GRAPH_SIZE := Vector2(850, 476)
const LINE_WIDTH := 1.5
const DASH_LENGTH := 6.0
const DASH_GAP := 4.0
var graph: Control
var graph_scroll: ScrollContainer
var buttons: Dictionary = {}
var selected_id := "hydro"
var hovered_id := ""
var wallet: Label
var detail_title: Label
var detail_text: Label
var status: Label
var feedback: Label
var upgrade_button: Button
var respec_button: Button
var back_button: Button

func text_label(text: String, font_size: int, color: Color = VisualTheme.PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.add_theme_font_size_override("font_size", 15)
	VisualTheme.style_button(node)
	node.pressed.connect(action)
	return node

func _ready() -> void:
	add_theme_stylebox_override("panel", VisualTheme.box(VisualTheme.INK, VisualTheme.EDGE, 16))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title := text_label("天赋树 · 湿地研修", 25, VisualTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	wallet = text_label("灵感 0", 22, VisualTheme.MINT)
	wallet.mouse_filter = Control.MOUSE_FILTER_PASS
	heading.add_child(wallet)
	var rewards := text_label("胜利奖励（含提前胜利）：简单 1 灵感 · 普通 2 灵感 · 困难 3 灵感 · 噩梦全树满级", 13, VisualTheme.MINT)
	rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(rewards)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	content.add_child(body)
	graph_scroll = ScrollContainer.new()
	preload("res://scripts/motion_scroll.gd").attach(graph_scroll)
	graph_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_scroll.custom_minimum_size = Vector2(180, 200)
	body.add_child(graph_scroll)
	graph = Control.new()
	graph.custom_minimum_size = GRAPH_SIZE
	graph.draw.connect(_draw_graph)
	graph_scroll.add_child(graph)
	for node in Talents.TREE:
		var id := str(node.id)
		var view := button("", select_node.bind(id))
		view.position = node_position(node)
		view.size = NODE_SIZE
		view.custom_minimum_size = NODE_SIZE
		view.add_theme_font_size_override("font_size", 13)
		view.mouse_entered.connect(_hover_node.bind(id))
		view.mouse_exited.connect(_hover_node.bind(""))
		graph.add_child(view)
		buttons[id] = view
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 230
	detail.size_flags_horizontal = Control.SIZE_FILL
	detail.add_theme_constant_override("separation", 12)
	body.add_child(detail)
	detail_title = text_label("", 21, VisualTheme.GOLD)
	detail.add_child(detail_title)
	detail_text = text_label("", 14)
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(detail_text)
	status = text_label("", 13, VisualTheme.MINT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(status)
	upgrade_button = button("投入灵感", purchase_selected)
	upgrade_button.custom_minimum_size.y = 42
	detail.add_child(upgrade_button)
	feedback = text_label("", 13, VisualTheme.GOLD)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 34
	detail.add_child(feedback)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)
	var hint := text_label("每组上限按等级计算。\n调整仅对下一局生效。\n实线：全部前置\n虚线：任选一个前置", 12, VisualTheme.MINT)
	detail.add_child(hint)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	respec_button = button("重置分配 · 全额返还灵感", reset_allocation)
	respec_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	respec_button.custom_minimum_size.y = 38
	footer.add_child(respec_button)
	back_button = button("返回", func(): back_requested.emit())
	back_button.custom_minimum_size = Vector2(110, 38)
	footer.add_child(back_button)
	get_viewport().size_changed.connect(fit_viewport)
	fit_viewport()
	refresh()

func fit_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	custom_minimum_size = Vector2(minf(1140, viewport_size.x - 48), minf(620, viewport_size.y - 48))
	graph.queue_redraw()

func node_position(node: Dictionary) -> Vector2:
	return GRAPH_MARGIN + Vector2(float(node.slot) * COLUMN_STEP, int(node.layer) * LAYER_STEP)

func _hover_node(id: String) -> void:
	hovered_id = id
	graph.queue_redraw()

func select_node(id: String) -> void:
	selected_id = id
	feedback.text = ""
	refresh()

func purchase_selected() -> void:
	if Talents.unlock(selected_id):
		feedback.text = "已研修「%s」%d级" % [Talents.tree_entry(selected_id).name, Talents.tree_rank(selected_id)]
	else:
		feedback.text = "研修未完成，请检查灵感、前置和分配上限。"
	refresh()

func reset_allocation() -> void:
	var refund: int = Talents.allocated_cost()
	if Talents.respec(): feedback.text = "已重置分配，返还 %d 灵感。" % refund
	else: feedback.text = "分配未变更。"
	refresh()

func refresh() -> void:
	if wallet == null: return
	wallet.text = "灵感 %d" % Talents.inspiration
	wallet.tooltip_text = "灵感来自胜利通关，提前胜利也计入。"
	if Talents.points > 0 or not Talents.unlocked.is_empty():
		wallet.tooltip_text += "\n旧版点数和线性解锁已保留备份；灵感从新规则下的胜利获取。"
	for node in Talents.TREE:
		var view: Button = buttons[node.id]
		var rank: int = Talents.tree_rank(node.id)
		var state: Dictionary = Talents.upgrade_status(node.id)
		view.text = "%s\n%d/%d · %s" % [node.name, rank, node.max_rank, "起点" if node.cost == 0 else "%d灵感" % node.cost]
		view.tooltip_text = "%s\n%s\n%s" % [node.name, node.desc, state.reason]
		var edge := VisualTheme.GOLD if node.id == selected_id else (VisualTheme.MINT if rank > 0 or state.ok else Color("536b69"))
		var fill := Color("28504b") if rank > 0 else (Color("1c4144") if state.ok else Color("1b3035"))
		for style in ["normal", "hover", "pressed"]:
			view.add_theme_stylebox_override(style, VisualTheme.box(fill.lightened(0.12) if style == "hover" else fill, edge, 4))
		view.add_theme_color_override("font_color", VisualTheme.PAPER if rank > 0 or state.ok else Color("8a9c98"))
	var selected: Dictionary = Talents.tree_entry(selected_id)
	var state: Dictionary = Talents.upgrade_status(selected_id)
	detail_title.text = selected.name
	detail_text.text = "等级 %d / %d\n\n%s" % [Talents.tree_rank(selected_id), selected.max_rank, selected.desc]
	if not selected.parents.is_empty():
		detail_text.text += "\n\n%s" % ("任选一个前置：" if selected.get("mode", "all") == "any" else "需要全部前置：")
		for parent in selected.parents:
			detail_text.text += "\n%s %s" % ["✓" if Talents.tree_rank(parent) > 0 else "○", Talents.tree_entry(parent).name]
	if Talents.GROUPS.has(selected.group):
		var group: Dictionary = Talents.GROUPS[selected.group]
		detail_text.text += "\n\n%s：%d / %d级" % [group.name, Talents.group_used(selected.group, Talents.tree_ranks), group.cap]
		if Talents.nightmare_mastery: detail_text.text += "\n噩梦通关：已解除分配上限"
	status.text = state.reason
	upgrade_button.text = "投入 %d 灵感 · 研修" % selected.cost
	upgrade_button.disabled = not bool(state.ok)
	respec_button.disabled = Talents.nightmare_mastery or Talents.allocated_cost() == 0
	graph.queue_redraw()

func _graph_connections() -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for node in Talents.TREE:
		for parent_id in node.parents:
			edges.append({"parent": str(parent_id), "node": node})
	# Give each connection its own port and horizontal lane in the inter-row gap.
	for edge in edges:
		var node: Dictionary = edge.node
		var parent: Dictionary = Talents.tree_entry(edge.parent)
		var siblings: Array[Dictionary] = []
		var layer_edges: Array[Dictionary] = []
		for candidate in edges:
			if candidate.parent == edge.parent: siblings.append(candidate)
			if candidate.node.layer == node.layer: layer_edges.append(candidate)
		var out_index := siblings.find(edge)
		var in_index: int = node.parents.find(edge.parent)
		var start := node_position(parent) + Vector2(NODE_SIZE.x * 0.5, NODE_SIZE.y + 2)
		var finish := node_position(node) + Vector2(NODE_SIZE.x * 0.5, -2)
		start.x += (out_index - (siblings.size() - 1) * 0.5) * 12.0
		finish.x += (in_index - (node.parents.size() - 1) * 0.5) * 12.0
		var lane := lerpf(start.y + 7, finish.y - 7, float(layer_edges.find(edge) + 1) / float(layer_edges.size() + 1))
		edge["points"] = _rounded_route(PackedVector2Array([start, Vector2(start.x, lane), Vector2(finish.x, lane), finish]))
	return edges

func _rounded_route(corners: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array([corners[0]])
	for i in range(1, corners.size() - 1):
		var corner := corners[i]
		var before := corners[i - 1] - corner
		var after := corners[i + 1] - corner
		var radius := minf(5.0, minf(before.length(), after.length()) * 0.5)
		var entry := corner + before.normalized() * radius
		var exit := corner + after.normalized() * radius
		points.append(entry)
		for step in range(1, 7):
			var t := float(step) / 6.0
			points.append(entry.lerp(corner, t).lerp(corner.lerp(exit, t), t))
	points.append(corners[corners.size() - 1])
	return points

func _draw_connection(points: PackedVector2Array, color: Color, dashed: bool) -> void:
	if not dashed:
		graph.draw_polyline(points, color, LINE_WIDTH, true)
		return
	# Measure dashes along the whole path so bends do not change their rhythm.
	var distance := 0.0
	for i in range(points.size() - 1):
		var segment := points[i + 1] - points[i]
		var length := segment.length()
		var offset := 0.0
		while offset < length:
			var phase := fposmod(distance, DASH_LENGTH + DASH_GAP)
			var drawing := phase < DASH_LENGTH
			var remaining := (DASH_LENGTH if drawing else DASH_LENGTH + DASH_GAP) - phase
			var advance := minf(length - offset, maxf(remaining, 0.001))
			if drawing:
				graph.draw_line(points[i] + segment.normalized() * offset, points[i] + segment.normalized() * (offset + advance), color, LINE_WIDTH, true)
			offset += advance
			distance += advance

func _draw_graph() -> void:
	var focus_id := hovered_id if not hovered_id.is_empty() else selected_id
	var edges := _graph_connections()
	# Focused routes are drawn last, with a small clearance at unavoidable crossings.
	for focused_pass in [false, true]:
		for edge in edges:
			var node: Dictionary = edge.node
			var focused: bool = edge.parent == focus_id or node.id == focus_id
			if focused != focused_pass: continue
			var color := Color("708e87")
			color.a = 0.28
			if Talents.tree_rank(edge.parent) > 0:
				color = VisualTheme.MINT
				color.a = 0.38
			if focused:
				color = VisualTheme.GOLD if node.id == focus_id else VisualTheme.MINT
				graph.draw_polyline(edge.points, VisualTheme.INK, 5.0, true)
			_draw_connection(edge.points, color, node.get("mode", "all") == "any")
			if focused:
				graph.draw_circle(edge.points[0], 2.2, color, true, -1, true)
				graph.draw_circle(edge.points[edge.points.size() - 1], 2.2, color, true, -1, true)
	var font := get_theme_default_font()
	var layer_titles := ["研修起点", "基础方向", "分支研修", "交叉研修", "终层专精"]
	var layer_notes := ["", "三选二", "每组至多三级", "总计至多三级", "三选一"]
	for layer in layer_titles.size():
		var y := GRAPH_MARGIN.y + layer * LAYER_STEP
		graph.draw_string(font, Vector2(8, y + 22), layer_titles[layer], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, VisualTheme.MINT)
		graph.draw_string(font, Vector2(8, y + 41), layer_notes[layer], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("829b94"))
