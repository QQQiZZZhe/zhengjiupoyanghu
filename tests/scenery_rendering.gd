extends Node
var checks := 0
var failures := 0
var wetland: Control

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func reference_shadows(c: Control) -> void:
	for spec in wetland._render_shadow_specs:
		wetland._draw_shadow(c, spec.uv, wetland._px_to_uv(float(spec.radius)), float(spec.alpha), float(spec.foot), str(spec.kind))

func viewport_for(draw: Callable) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color(0.75, 0.8, 0.65)
	background.size = viewport.size
	viewport.add_child(background)
	var canvas := Control.new()
	canvas.size = viewport.size
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(canvas)
	canvas.draw.connect(draw.bind(canvas))
	canvas.queue_redraw()
	return viewport

func compare(a: Image, b: Image, label: String) -> void:
	var max_error := 0.0
	var substantial := 0
	for y in a.get_height():
		for x in a.get_width():
			var left := a.get_pixel(x, y)
			var right := b.get_pixel(x, y)
			var error := maxf(absf(left.r - right.r), maxf(absf(left.g - right.g), absf(left.b - right.b)))
			max_error = maxf(max_error, error)
			if error > 2.0 / 255.0: substantial += 1
	print("RENDER_EQUIVALENCE %s max_error=%.6f substantial_pixels=%d" % [label, max_error, substantial])
	check(substantial == 0, label + " retains original pixels within two quantization levels")

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(1.8).timeout
	var game: Node = scene.get_node("Game")
	wetland = game.wetland
	game.set_process(false)
	wetland.set_process(false)
	var sources: Array = []
	for group in [wetland.sprites, wetland.bird_sprites, wetland.BIRD_ACTIONS, wetland.HOUSE_ART, wetland.prop_textures, wetland.pine_seasons, wetland.seasonal_trees]: sources.append_array(group)
	for frames in wetland.tree_frames: sources.append_array(frames)
	sources.append_array([wetland.FLOATING_ISLAND, wetland.COMMUNITY_CAR])
	for source in sources:
		var original: Image = source.get_image()
		if original.is_compressed(): original.decompress()
		original.convert(Image.FORMAT_RGBA8)
		var packed: Image = wetland._atlas_texture(source).get_image()
		packed.convert(Image.FORMAT_RGBA8)
		check(original.get_size() == packed.get_size() and original.get_data() == packed.get_data(), "Atlas preserves every source pixel and logical texture size")
	var reference := viewport_for(reference_shadows)
	var optimized := viewport_for(wetland._draw_contact_shadows)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	compare(reference.get_texture().get_image(), optimized.get_texture().get_image(), "ground shadows")
	reference.queue_free()
	optimized.queue_free()
	var made: Dictionary = game._make_card(GameState.card_by_id("patrol"), "effective")
	var panel: Control = made.panel
	add_child(panel)
	panel.position = Vector2(300, 220)
	panel.rotation = 0.25
	panel.scale = Vector2(1.1, 0.95)
	var shadow := Node2D.new()
	shadow.set_script(preload("res://scripts/card_projected_shadow.gd"))
	panel.add_child(shadow)
	shadow.update_projection(panel, Vector2(0.21, -0.26))
	var card_reference := func(c: Control):
		var center := Vector2.ZERO
		for point in shadow.points: center += point * 0.25
		for layer in range(8, -1, -1):
			var ring := PackedVector2Array()
			for point in shadow.points: ring.append(point + (point - center).normalized() * shadow.softness * layer / 8.0)
			c.draw_colored_polygon(ring, Color(0.015, 0.025, 0.025, 0.055))
	var card_optimized := func(c: Control):
		c.draw_mesh(shadow._mesh, null)
	await RenderingServer.frame_post_draw
	check(shadow._mesh != null, "Actual card projection builds a retained mesh")
	reference = viewport_for(card_reference)
	optimized = viewport_for(card_optimized)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	compare(reference.get_texture().get_image(), optimized.get_texture().get_image(), "card shadows")
	print("SCENERY_RENDERING: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
