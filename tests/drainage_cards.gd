extends Node
const Art := preload("res://scripts/pixel_card_art.gd")
const NEW_IDS := ["emergency_drainage", "outlet_clearance", "floodplain_diversion"]
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fixture(state: Node, difficulty: int) -> void:
	state.reset_game()
	Talents.reset_all()
	state.difficulty = difficulty
	state.run_seed = 20261010
	state.turn = 2
	state.funds = 500
	state.turn_budget = 500
	state.metrics = {"water_level": 85, "vegetation": 80, "water_quality": 80, "fish": 80, "birds": 60, "community": 80}
	state.used_action_ids = []
	state._is_settlement_preview = true
func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	Talents.reset_all()
	var state = load("res://scripts/game_state.gd").new()
	var actual = load("res://scripts/game_state.gd").new()
	for difficulty in 4:
		for id in NEW_IDS:
			for tier in ["basic", "effective", "deep"]:
				fixture(state, difficulty)
				var c: Dictionary = state.card_by_id(id)
				var cost: int = state.tier_cost(id, tier)
				var expected_cost := roundi(float(c.cost) * state.TIER_COST_MULT[tier])
				check(cost == expected_cost, "Every tier charges its displayed cost")
				var snapshot: Dictionary = state.serialize().duplicate(true)
				var queue := [{"card_id": id, "tier": tier, "dispatched": false}]
				var forecast: Dictionary = state.preview_settlement(queue)
				check(state.serialize() == snapshot, "New card preview cannot mutate live state")
				actual.load_state(snapshot.duplicate(true), false)
				actual._is_settlement_preview = true
				actual.execute_action(id, tier)
				var delta: int = c.tiers[tier].effects[0].delta
				check(actual.metrics.water_level == 85 + delta, "Water reduction is immediate and independent of difficulty")
				check(actual.funds == 500 - cost and actual.turn_card_spent == cost, "Execution and budget ledger match the amount")
				actual.end_turn()
				check(forecast == actual.metrics, "Preview includes water retreat, delayed effects and natural settlement")
	var seen: Dictionary = {}
	for season in 4:
		fixture(state, 0)
		state.turn = season + 1
		var pool: Array = state.season_pool()
		for id in NEW_IDS:
			check(pool.any(func(c): return c.id == id) == (id != "floodplain_diversion" or season == 1), "New cards use the intended season pools")
		var flood: Dictionary = state.crisis_by_id("flood")
		state.pending_crisis = flood
		for id in NEW_IDS:
			check(state.counter_ids_for(flood).has(id), "New cards are flood countermeasures")
		for sample in 100:
			seed(61010 + season * 1000 + sample)
			for c in state.draw_cards(6): seen[c.id] = true
	for id in NEW_IDS:
		check(seen.has(id), "New cards can actually be drawn")
		var c: Dictionary = state.card_by_id(id)
		Art.base_image(c.category)
		for character in c.name:
			check(Art.mapping.has(character), "Card title glyph exists: " + character)
		check(ResourceLoader.exists("res://assets/art/dispatch/cards/%s.png" % id), "Dispatch has a dedicated baked asset")
		var baked: Image = Art.dispatch_texture(c).get_image()
		var fresh: Image = Art.dispatch_texture(c, false).get_image()
		baked.convert(Image.FORMAT_RGBA8)
		fresh.convert(Image.FORMAT_RGBA8)
		check(baked.get_size() == Vector2i(400, 600) and baked.get_data() == fresh.get_data(), "Baked art matches runtime card name and category")
		for tier in ["basic", "effective", "deep"]:
			Art.texture(c.name, str(state.tier_cost(id, tier)), c.category).get_image().save_png(OS.get_environment("POYANG_SCREENSHOT_DIR").path_join(id + "-" + tier + ".png"))
	# Render actual effective card faces side by side for visual inspection.
	var background := ColorRect.new()
	background.color = Color("354e45")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	for index in NEW_IDS.size():
		var c: Dictionary = state.card_by_id(NEW_IDS[index])
		var face := TextureRect.new()
		face.texture = Art.texture(c.name, str(state.tier_cost(c.id, "effective")), c.category)
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.position = Vector2(40 + index * 400, 40)
		face.size = Vector2(400, 600)
		add_child(face)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("POYANG_SCREENSHOT_DIR").path_join("drainage-cards.png"))
	state.free()
	actual.free()
	print("DRAINAGE_CARDS checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
