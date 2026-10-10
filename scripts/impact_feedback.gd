extends Node2D
## SNKRX hit circle/particle rhythm + VFX Library combo ring, adapted for UI.
## One bounded drawing node; no gameplay RNG, screen copies or global time scale.
const Physics = preload("res://scripts/motion_web.gd")
const Spring = preload("res://scripts/motion_spring.gd")
const MAX_BURSTS := 6
const ATLAS := preload("res://assets/effects/impact-atlas.png")
const ATLAS_FRAMES := 12
const TILE_SIZE := 128.0
var bursts: Array = []
var emitted := 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)

func pulse(card: Control, color: Color, strength: float = 1.0, punch: bool = false, duration_scale: float = 1.0) -> void:
	if Physics.reduced(self) or Physics.paused(self): return
	# Repeated hits restore the previous pose before taking ownership again.
	for i in range(bursts.size() - 1, -1, -1):
		if bursts[i].target.get_ref() == card:
			_finish(bursts[i])
			bursts.remove_at(i)
	while bursts.size() >= MAX_BURSTS:
		_finish(bursts.pop_front())
	strength = clampf(strength, 0.5, 1.8)
	var burst := {"target": weakref(card), "origin": card.get_global_transform() * (card.size * 0.5),
		"color": color, "strength": strength, "age": 0.0, "duration": 0.32 * maxf(0.25, duration_scale),
		"punch": punch, "base": card.position, "scale": card.scale, "sprite_frame": 0, "flash": -1.0}
	if punch:
		Spring.stop(card, "position")
		Spring.stop(card, "scale")
		card.set_meta("impact_active", true)
	bursts.append(burst)
	emitted += 1
	_apply(burst)
	set_process(true)
	queue_redraw()

func clear() -> void:
	for burst in bursts: _finish(burst)
	bursts.clear()
	set_process(false)
	queue_redraw()

func _finish(burst: Dictionary) -> void:
	var card: Control = burst.target.get_ref()
	if not is_instance_valid(card): return
	if card.material is ShaderMaterial:
		card.material.set_shader_parameter("impact_flash", 0.0)
	if burst.punch:
		card.position = burst.base
		card.scale = burst.scale
		card.set_meta("impact_active", false)

func _apply(burst: Dictionary) -> bool:
	var card: Control = burst.target.get_ref()
	if not is_instance_valid(card): return false
	var phase: float = burst.age / burst.duration
	var frame := mini(ATLAS_FRAMES - 1, int(phase * ATLAS_FRAMES))
	var changed: bool = frame != burst.sprite_frame
	burst.sprite_frame = frame
	if card.material is ShaderMaterial:
		var flash := snappedf(0.28 * burst.strength * maxf(0.0, 1.0 - phase / 0.42), 1.0 / 64.0)
		if flash != burst.flash:
			card.material.set_shader_parameter("impact_flash", flash)
			burst.flash = flash
	if burst.punch:
		# Hold the local contact pose for ~35 ms, then one damped recoil.
		var release := maxf(0.0, (phase - 0.11) / 0.89)
		var kick := cos(release * TAU * 1.15) * exp(-release * 6.0) * (1.0 - release)
		card.scale = burst.scale * (1.0 + 0.055 * burst.strength * kick)
		card.position = burst.base + Vector2(2.0, -3.0) * burst.strength * kick
	return changed

func _process(dt: float) -> void:
	if Physics.reduced(self):
		clear()
		return
	if Physics.paused(self): return
	var redraw := false
	for i in range(bursts.size() - 1, -1, -1):
		var burst: Dictionary = bursts[i]
		burst.age += dt
		if burst.age >= burst.duration or not is_instance_valid(burst.target.get_ref()):
			_finish(burst)
			bursts.remove_at(i)
			redraw = true
		else: redraw = _apply(burst) or redraw
	if redraw: queue_redraw()
	if bursts.is_empty(): set_process(false)

func _draw() -> void:
	for burst in bursts:
		var origin: Vector2 = to_local(burst.origin)
		var extent: float = TILE_SIZE * burst.strength
		# Prebaked ring/chips: one shared atlas and one command per live burst.
		draw_texture_rect_region(ATLAS, Rect2((origin - Vector2.ONE * extent * 0.5).round(), Vector2.ONE * extent),
			Rect2(float(burst.sprite_frame) * TILE_SIZE, 0.0, TILE_SIZE, TILE_SIZE), burst.color)
