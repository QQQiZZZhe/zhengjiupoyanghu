extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func reference_sample(route: Array[Vector2], phase: float) -> Dictionary:
	var length := 0.0
	for i in range(1, route.size()): length += route[i - 1].distance_to(route[i])
	var remaining := fposmod(phase, 1.0) * length
	for i in range(1, route.size()):
		var segment := route[i - 1].distance_to(route[i])
		if remaining <= segment:
			return {"pos": route[i - 1].lerp(route[i], remaining / maxf(segment, 0.00001)), "direction": (route[i] - route[i - 1]).normalized()}
		remaining -= segment
	return {"pos": route[-1], "direction": Vector2.RIGHT}

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(0.4).timeout
	var game = scene.get_node("Game")
	if game._intro_playing: game._finish_intro()
	game.wetland.set_process(false)
	var wetland = game.wetland
	var bird := {"facing": 1.0}
	var inverse_basis: Transform2D = wetland._screen_projection.affine_inverse()
	for i in 1200:
		var noise := Vector2(-0.001 if i % 2 == 0 else 0.001, 1.0)
		wetland._update_bird_facing(bird, inverse_basis.basis_xform(noise), 1.0 / 120.0)
		check(wetland._bird_facing(bird) == 1.0, "Vertical jitter flipped bird facing")
	for fps in [30, 60, 120]:
		bird = {"facing": 1.0}
		for i in fps:
			wetland._update_bird_facing(bird, inverse_basis.basis_xform(Vector2(-1, 0)), 1.0 / fps)
		check(wetland._bird_facing(bird) == -1.0, "Sustained movement must turn bird at all frame rates")
		for i in fps:
			wetland._update_bird_facing(bird, Vector2.ZERO, 1.0 / fps)
		check(wetland._bird_facing(bird) == -1.0, "Stationary bird must retain facing")
	for route in [wetland.yangtze_route, wetland.gan_route]:
		for i in 300:
			var phase := float(i - 100) / 97.0
			var actual: Dictionary = wetland._river_sample(route, phase)
			var expected := reference_sample(route, phase)
			check(actual["pos"].distance_to(expected["pos"]) < 0.000001, "Boat position changed")
			check(actual["direction"].distance_to(expected["direction"]) < 0.000001, "Boat heading changed")
	for i in 1000:
		var uv := Vector2(float(i % 31) / 30.0 * 2.0 - 0.5, float(i % 47) / 46.0 * 2.0 - 0.5)
		var pixel := ((uv + Vector2.ONE * 0.5) * 64.0 - Vector2.ONE * 0.5).clamp(Vector2.ZERO, Vector2.ONE * 127)
		var a := Vector2i(pixel.floor())
		var b := (a + Vector2i.ONE).min(Vector2i.ONE * 127)
		var image: Image = wetland.relief_image
		var expected := lerpf(lerpf(image.get_pixel(a.x, a.y).r, image.get_pixel(b.x, a.y).r, pixel.x - a.x), lerpf(image.get_pixel(a.x, b.y).r, image.get_pixel(b.x, b.y).r, pixel.x - a.x), pixel.y - a.y)
		check(absf(wetland._relief_at(uv) - expected) < 0.000001, "Terrain projection changed")
	for i in 10:
		wetland._process(1.0 / 60.0)
		for item in wetland._render_items:
			if item["kind"] == "bird": check(item["uv"] == item["bird"]["pos"], "Moving bird snapshot skipped a frame")
		for j in range(1, wetland._render_items.size()):
			check(wetland._scenery_before(wetland._render_items[j - 1], wetland._render_items[j]), "Scenery depth order changed")
	var started := Time.get_ticks_usec()
	for i in 600: wetland._redraw_scenery()
	var redraw := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for i in 3000: wetland._yangtze_boat_sample(i % 10, float(i) * 0.1)
	var boats := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var total := 0.0
	for i in 100000: total += wetland._relief_at(Vector2(float(i % 100) / 99.0, float((i / 100) % 100) / 99.0))
	print("ANIMATION_CPU redraw600_us=", redraw, " boats3000_us=", boats, " relief100000_us=", Time.get_ticks_usec() - started, " checksum=", total)
	print("ANIMATION_PERFORMANCE: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	game.bgm_player.stop()
	game.bgm_player.stream = null
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)
