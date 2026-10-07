extends ColorRect
var bar: ProgressBar
var effects_owner: Node
var flow_clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = preload("res://scripts/metric_bar_ripple.gdshader")

func _process(delta: float) -> void:
	if effects_owner == null or bar == null: return
	var reduce: bool = effects_owner.wetland != null and effects_owner.wetland.reduced_motion
	if not effects_owner._paused and not reduce and is_visible_in_tree(): flow_clock += delta
	material.set_shader_parameter("flow_clock", flow_clock)
	material.set_shader_parameter("enabled", not reduce)
	material.set_shader_parameter("fill_ratio", clampf((bar.value - bar.min_value) / (bar.max_value - bar.min_value), 0.0, 1.0))
	material.set_shader_parameter("extent", size)
