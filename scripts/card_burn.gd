extends RefCounted
## Presentation only: no card removal, payments or gameplay RNG.
const Motion := preload("res://scripts/motion.gd")
static var _noise: ImageTexture

static func noise_texture() -> ImageTexture:
	if _noise == null:
		var noise := FastNoiseLite.new()
		noise.seed = 20261010
		noise.frequency = 0.055
		_noise = ImageTexture.create_from_image(noise.get_image(256, 352))
	return _noise

static func play(card: Control, duration: float, delay: float = 0.0) -> void:
	var mat := card.material as ShaderMaterial
	if mat == null: return
	mat.set_shader_parameter("dissolve_texture", noise_texture())
	mat.set_shader_parameter("dissolve_extent", card.size * card.scale)
	mat.set_shader_parameter("dissolve_value", 1.0)
	card.set_meta("burning", true)
	# The projected shadow is a separate canvas item: dissolve it on the same beat.
	var shadow: Node2D = card.get_meta("projected_shadow", null)
	var tw := Motion.tween(card, "linear", "card_burn")
	tw.tween_interval(delay)
	tw.tween_property(mat, "shader_parameter/dissolve_value", 0.0, duration)
	if is_instance_valid(shadow):
		tw.parallel().tween_property(shadow, "modulate:a", 0.0, duration)

static func reset(card: Control) -> void:
	Motion.cancel(card, "card_burn")
	if card.material is ShaderMaterial:
		card.material.set_shader_parameter("dissolve_value", 1.0)
	card.set_meta("burning", false)
	var shadow: Node2D = card.get_meta("projected_shadow", null)
	if is_instance_valid(shadow): shadow.modulate.a = 1.0
