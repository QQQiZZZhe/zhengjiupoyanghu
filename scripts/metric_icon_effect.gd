extends TextureRect
var effects_owner: Node
var hovered := false
var hover_scale := 1.0
var poke_age := 1.0
var poke_count := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	material = ShaderMaterial.new()
	material.shader = preload("res://scripts/metric_icon_effect.gdshader")
	mouse_entered.connect(func(): hovered = true)
	mouse_exited.connect(func(): hovered = false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not effects_owner._tip_allowed(): return
		poke_count += 1
		poke_age = 0.0
		accept_event()

func _process(delta: float) -> void:
	if effects_owner == null: return
	if effects_owner._paused: return
	var reduce: bool = effects_owner.wetland != null and effects_owner.wetland.reduced_motion
	var active: bool = hovered and effects_owner._tip_allowed()
	var target := 1.35 if active else 1.0
	hover_scale = target if reduce else lerpf(hover_scale, target, 1.0 - exp(-18.0 * delta))
	poke_age = minf(1.0, poke_age + delta)
	var shake := Vector2.ZERO
	var press := 1.0
	if poke_age < 0.28 and not reduce:
		var decay := 1.0 - poke_age / 0.28
		shake = Vector2(sin(poke_age * 110.0) * 2.5, sin(poke_age * 83.0) * 1.3) * decay
		press = 1.0 - sin(poke_age / 0.28 * PI) * 0.10
	material.set_shader_parameter("center", size * 0.5)
	material.set_shader_parameter("effect_scale", hover_scale * press)
	material.set_shader_parameter("shake", shake)
