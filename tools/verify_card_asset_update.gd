extends SceneTree
var Art: GDScript
const CATEGORY_FILES := {
	"地理": "geography", "植物": "plants", "鸟类": "birds", "水生动物": "aquatic",
	"外来物种": "invasive", "机制": "mechanisms", "保护行动": "conservation",
	"案例": "cases", "管理策略": "management",
}
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func same_pixels(a: Image, b: Image) -> bool:
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	return a.get_size() == b.get_size() and a.get_data() == b.get_data()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Art = load("res://scripts/pixel_card_art.gd")
	var gs: Node = root.get_node("GameState")
	var knowledge: Node = root.get_node("Knowledge")
	var output := "res://.godot/card-review/rendered"
	DirAccess.make_dir_recursive_absolute(output)
	var ids: Array = knowledge.all_ids()
	check(ids.size() == gs.KNOWLEDGE_CARDS.size(), "Every knowledge entry must be classified")
	check(ids.size() == 41, "Knowledge collection keeps all 41 stable IDs")
	check(ids[-1] == "egg_dixinhu", "Easter egg must be after the nine normal categories")
	var previous := -1
	var counts: Dictionary = {}
	for kid in ids:
		var card: Dictionary = gs.KNOWLEDGE_CARDS[kid]
		var category: String = str(card["category"])
		if category == "彩蛋": continue
		var rank: int = gs.KNOWLEDGE_CATEGORIES.find(category)
		check(rank >= previous and rank >= 0, "Gallery follows category order: " + kid)
		previous = rank
		check(Art.knowledge_face(category) != null, "Every entry has its own category face: " + kid)
		var made: Image = Art.knowledge_texture(card["name"], category).get_image()
		made.save_png(output.path_join(kid + ".png"))
		check(Art._lines(card["name"]).size() <= 4, "Name fits inside the template: " + kid)
		counts[category] = int(counts.get(category, 0)) + 1
	for category in CATEGORY_FILES:
		var source := Image.load_from_file("res://tools/art_sources/card-20261010/kd-done/知识卡/kardz-%s.png" % category)
		check(same_pixels(source, Art.knowledge_face(category).get_image()), "Category face must exactly match artist source: " + category)
		check(int(counts.get(category, 0)) > 0, "Every supplied category is represented: " + category)
	for special in [["anno", Art.KNOWLEDGE_FACE_LOCKED, "unknown"], ["dxh", Art.KNOWLEDGE_FACE_EGG, "easter-egg"]]:
		var source := Image.load_from_file("res://tools/art_sources/card-20261010/kd-done/知识卡/kardz-%s.png" % special[0])
		check(same_pixels(source, special[1].get_image()), "Special face matches source: " + special[0])
		special[1].get_image().save_png(output.path_join(special[2] + ".png"))
	check(Art.COST_INK == Color("384435"), "Amount ink must match the deep green in the artist example")
	for card in gs.ACTION_CARDS:
		for tier in card["tiers"]:
			var face: Image = Art.texture(card["name"], str(gs.tier_cost(card["id"], tier)), card["category"]).get_image()
			var green := 0
			for y in range(417, 481):
				for x in range(100, 235):
					if face.get_pixel(x, y) == Art.COST_INK: green += 1
			check(green > 0, "Each amount uses deep green: %s/%s" % [card["id"], tier])
			if tier == "effective": face.save_png(output.path_join("hand-" + card["id"] + ".png"))
		var baked: Image = Art.dispatch_texture(card).get_image()
		var fresh: Image = Art.dispatch_texture(card, false).get_image()
		check(same_pixels(baked, fresh), "Each dispatch asset must be rebuilt from the new base: " + card["id"])
		baked.save_png(output.path_join("dispatch-" + card["id"] + ".png"))
	print("CARD_ASSET_UPDATE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
