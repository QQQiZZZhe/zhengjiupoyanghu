extends Node
## Run in an isolated test project/user directory; see docs/UI_REDESIGN.md.
const PixelArt = preload("res://scripts/pixel_card_art.gd")
var game: Node
var failures: Array[String] = []
var checks: int = 0          # 断言总数（最后打印出来，证据里就有确切条数）
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle(seconds: float = 0.4) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(label: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))

func close_popups() -> void:
	for i in 12:
		if game.has_method("_on_expedition_selected") and game.expedition_panel.visible:
			if GameState.expedition.direction.is_empty(): game._on_expedition_selected("habitat")
			elif GameState.expedition.needs_reward(GameState.turn): game._on_expedition_selected(GameState.expedition.reward_offers()[0])
		if not game.popup_root.visible: break
		game._on_popup_button()
		await settle(0.1)

func creeper_screen_rect() -> Rect2:
	var mesh: MeshInstance3D = game.wetland.creeper_mesh
	var camera: Camera3D = game.wetland.map_camera
	var bounds := mesh.get_aabb()
	var rect := Rect2(camera.unproject_position(mesh.to_global(bounds.get_endpoint(0))), Vector2.ZERO)
	for i in range(1, 8):
		rect = rect.expand(camera.unproject_position(mesh.to_global(bounds.get_endpoint(i))))
	return rect

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle(0.3)
	if game._intro_playing: game._finish_intro()
	await settle(1.3)
	var menu_camera_size: float = game.wetland.map_camera.size
	check(is_equal_approx(game.wetland.camera_zoom_factor, game.MENU_CAM_ZOOM), "Menu must pull the active map camera back")
	game.wetland.easter_rng.seed = 20261002
	var saw_creeper := false
	var saw_no_creeper := false
	for i in 100:
		game._roll_creeper_visibility()
		saw_creeper = saw_creeper or game.wetland.creeper_mesh.visible
		saw_no_creeper = saw_no_creeper or not game.wetland.creeper_mesh.visible
	check(saw_creeper and saw_no_creeper, "Creeper probability must allow both outcomes")
	game.wetland.creeper_mesh.visible = true
	check(game.wetland.creeper_mesh.is_visible_in_tree(), "Creeper must be attached to the rendered 3D world")
	check(game.wetland._is_land(game.wetland.CREEPER_ANCHOR), "Creeper decal must remain on land")
	var secret: Vector2 = game.wetland._point(game.wetland.CREEPER_ANCHOR)
	var window_rect := get_viewport().get_visible_rect().grow(-24)
	check(window_rect.has_point(secret) and secret.x > window_rect.size.x * 0.40, "Menu camera must keep the Creeper inside the unshaded view")
	check(window_rect.encloses(creeper_screen_rect()), "Entire Creeper must fit inside the menu view")
	check(game.wetland.scenery_props.size() > 200, "Empty meadows need varied pixel vegetation and stones")
	# 房影：四张贴图各自量过不透明外形（逐栋调半径的依据），且 px→uv 换算可用
	check(game.wetland.house_art_shape.size() == 4, "四张房子贴图都应量出外形，实际 %d" % game.wetland.house_art_shape.size())
	var shape_bottoms: Array = game.wetland.house_art_shape.map(func(s): return float(s["bottom"]))
	check(shape_bottoms.size() == 4, "应量到四栋的脚点")
	check(not is_equal_approx(shape_bottoms[0], shape_bottoms[3]), "四栋房子的脚点不该一样 —— 影子是逐栋调的")
	check(game.wetland.HOUSE_SHADOW_RADIUS.size() == 4, "逐栋影子半径表应有四张")
	check(game.wetland.HOUSE_SHADOW_RADIUS[0] != game.wetland.HOUSE_SHADOW_RADIUS[2], "不同房子的影子半径应不同")
	check(game.wetland.HOUSE_SHADOW_FOOT.size() == 4, "逐栋影子下推量表应有四张")
	check(game.wetland.HOUSE_SHADOW_RADIUS[0] < game.wetland.HOUSE_SHADOW_RADIUS[2], "矮房的影子应比高楼大一圈")
	check(game.wetland.HOUSE_SHADOW_FOOT[0] < game.wetland.HOUSE_SHADOW_FOOT[2], "矮房的影子应比高楼更往前推（高楼要多被压住）")
	check(game.wetland.SHADOWS.get("building", false) and game.wetland.SHADOWS.get("tree", false), "房子和树的影子都应打开")
	check(not game.wetland.SHADOWS.get("boat", true) and not game.wetland.SHADOWS.get("island", true), "船和浮岛暂不投影子")
	check(game.wetland.SHADOW_FLATTEN < 1.0, "影子要额外压扁（真 3D 只压到 0.707，偏圆）")
	check(game.wetland.TREE_SHADOW_RADIUS > 0.0, "树影半径应有效")
	check(game.wetland._px_to_uv(44.0) > 0.0, "px→uv 换算应可用（影子半径换算依赖它）")
	for prop in game.wetland.scenery_props:
		check(prop.pos.distance_to(game.wetland.CREEPER_ANCHOR) >= 0.15, "Scenery must leave the secret clearing open")
	for route in [game.wetland.yangtze_route, game.wetland.gan_route]:
		check(not get_viewport().get_visible_rect().has_point(game.wetland._point(route[0])), "River extension must continue beyond the screen")
	var ship_a: Dictionary = game.wetland._river_sample(game.wetland.yangtze_route, 0.4)
	var ship_b: Dictionary = game.wetland._river_sample(game.wetland.yangtze_route, 0.41)
	check(ship_a.pos.distance_to(ship_b.pos) > 0.01 and game.wetland._in_river_corridor(ship_a.pos, 0.02), "Yangtze ships must move along the channel")
	await capture("01-menu")
	# 主菜单 → 更新日志：确认 v0.1.2 条目渲染出来、且「当前版本」跟着 Changelog.CURRENT 走
	game._show_changelog_panel()
	await settle(0.7)
	check(game.menu_changelog_panel.visible, "更新日志面板应能打开")
	await capture("01a-changelog-v012")
	game._on_changelog_back()
	await settle(0.4)
	# ---------------- 知识卡图鉴（主页入口）----------------
	check(Knowledge.collected_count() == 0, "新账号不该有已收集的知识卡")
	game._open_knowledge_viewer()
	await settle(1.3)
	check(game.knowledge_viewer.visible, "知识卡图鉴应能打开")
	check(game.knowledge_grid.get_child_count() == Knowledge.total_count(), "图鉴应铺出全部知识卡")
	check(game.knowledge_count_label.text == "已收集 0 / %d" % Knowledge.total_count(), "初始收藏计数应正确")
	# 真实鼠标可能恰好停在某张卡上（会把底色换成悬停样式），查颜色前先复位
	for v in game.knowledge_grid.get_children():
		game._on_viewer_card_unhover(v)
	await settle(0.3)
	var first_view: Control = game.knowledge_grid.get_child(0)
	# 卡面自己承担底色：VisualTheme.card_style 的 bg_color 是透明、无边框（卡牌的框画在图里），
	# 所以「未收集变灰」现在是**换一张画好的「未知」卡面**，不再看 stylebox 颜色。
	var locked_face: TextureRect = (first_view.get_meta("panel") as PanelContainer).get_meta("pixel_face")
	check(locked_face.texture == PixelArt.KNOWLEDGE_FACE_LOCKED, "未收集卡应换成「未知」卡面")
	await capture("01b-knowledge-locked")
	# 点开一张未收集的 —— 只该看到「未收集」与「？」
	var click_ev := InputEventMouseButton.new()
	click_ev.pressed = true
	click_ev.button_index = MOUSE_BUTTON_LEFT
	game._on_knowledge_card_click(click_ev, first_view, "plant_kucao")
	await settle(2.6)   # 详情正文是打字机（最长 2.5s），等它写完再拍
	check(game.knowledge_detail.visible, "点未收集的卡也该打开详情（显示未收集 + ？）")
	check(game.knowledge_detail_title.text == "？？？", "未收集详情标题应是 ？？？，实际「%s」" % game.knowledge_detail_title.text)
	check(game.knowledge_detail_body.text.find("未收集") != -1, "未收集详情该写明「未收集」")
	check(game.knowledge_detail_body.text.find("？") != -1, "未收集详情该出现「？」")
	await capture("01c-knowledge-locked-detail")
	game._close_knowledge_detail()
	game._close_knowledge_viewer()
	await settle(0.5)
	# 收集两张后重开：这两张点亮，其余仍是灰卡
	Knowledge.unlock("plant_kucao")
	Knowledge.unlock("bird_baihe")
	game._open_knowledge_viewer()
	await settle(1.3)
	check(game.knowledge_count_label.text == "已收集 2 / %d" % Knowledge.total_count(), "收藏两张后的计数应正确")
	for v in game.knowledge_grid.get_children():
		game._on_viewer_card_unhover(v)
	await settle(0.3)
	# 已收集的卡换成该类别画好的卡面、卡名写在卡面中间（苦草 = 植物）。
	# ⚠ 别用 get_child(0)：第 0 张是彩蛋卡狄鑫壶，这时还没收集，是「未知」卡面。
	var lit_index: int = Knowledge.all_ids().find("plant_kucao")
	var lit_view: Control = game.knowledge_grid.get_child(lit_index)
	var lit_face: TextureRect = (lit_view.get_meta("panel") as PanelContainer).get_meta("pixel_face")
	check(lit_face.texture == PixelArt.knowledge_texture("苦草", "植物"), "已收集卡应换成该类别卡面并写上卡名")
	var locked2: Control = game.knowledge_grid.get_child(0)
	var locked2_face: TextureRect = (locked2.get_meta("panel") as PanelContainer).get_meta("pixel_face")
	check(locked2_face.texture == PixelArt.KNOWLEDGE_FACE_LOCKED, "没收集的卡仍旧是「未知」卡面")
	await capture("01d-knowledge-mixed")
	game._on_knowledge_card_click(click_ev, lit_view, "plant_kucao")
	await settle(2.6)
	check(game.knowledge_detail_title.text == "苦草", "已收集详情标题应是卡名，实际「%s」" % game.knowledge_detail_title.text)
	check(game.knowledge_detail_body.text.find("未收集") == -1, "已收集详情不该出现「未收集」")
	check(game.knowledge_detail_body.text.find("生态角色") != -1, "已收集详情该有「生态角色」")
	check(game.knowledge_detail_body.text.find("关联行动") != -1, "已收集详情该显示「关联行动」标签")
	await capture("01e-knowledge-unlocked-detail")
	game._close_knowledge_detail()
	game._close_knowledge_viewer()
	await settle(0.6)

	# ---------------- 小窗口下菜单必须完整露出彩蛋（朋友版）----------------
	get_window().size = Vector2i(960, 540)
	await settle(0.4)
	var small_secret: Vector2 = game.wetland._point(game.wetland.CREEPER_ANCHOR)
	check(get_viewport().get_visible_rect().grow(-20).has_point(small_secret), "Small-window menu must keep the secret visible")
	check(get_viewport().get_visible_rect().grow(-20).encloses(creeper_screen_rect()), "Small-window menu must show the entire Creeper")
	await capture("01b-menu-small-window")
	get_window().size = Vector2i(1280, 720)
	await settle(0.4)

	game._on_title_start()
	await capture("02-difficulty")
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20260930"
	game._on_start_pressed()
	await settle(0.3)
	check(game.wetland.map_camera.size < menu_camera_size and game.wetland.camera_zoom_factor > game.wetland.GAME_CAMERA_ZOOM, "Entering a run must animate camera zoom")
	check(game.wetland.creeper_mesh.visible, "Starting a run must preserve the menu's Creeper roll")
	await close_popups()
	await settle(1.0)
	check(game.card_infos.size() > 0, "Starting a run must deal cards")
	check(is_equal_approx(game.wetland.camera_zoom_factor, game.wetland.GAME_CAMERA_ZOOM), "Game camera zoom must settle at its closer scale")
	check(not get_viewport().get_visible_rect().intersects(creeper_screen_rect()), "Entire Creeper must be beyond the gameplay viewport")
	# Allocation now pans away from the hand. Check all three original water
	# junctions in the explicit full-view mode, including the northern offscreen one.
	game.sandpan_view.toggle_view()
	await settle(0.4)
	await RenderingServer.frame_post_draw
	var terrain_frame: Image = game.wetland.terrain_viewport.get_texture().get_image()
	# These mapped-water points used to be covered by sand from the added river banks.
	for junction in [Vector2(0.4184458, 0.1112966), Vector2(0.326131, 0.4793997), Vector2(0.3412264, 0.4328778)]:
		var pixel: Vector2 = game.wetland.map_camera.unproject_position(game.wetland._ground_position(junction) + Vector3(0, 0.01, 0)).round()
		var color := terrain_frame.get_pixel(int(pixel.x), int(pixel.y))
		check(color.b > color.g and color.g > color.r, "River/lake junction must render water blue instead of a sand divider")
	game.sandpan_view.toggle_view()
	await settle(0.4)
	var wildlife: Control = game.wetland.get_node("Wildlife")
	var habitat := Vector2(0.4, 0.6)
	var screen_anchor: Vector2 = wildlife.get_transform() * game.wetland._wildlife_point(habitat)
	check(screen_anchor.distance_to(game.wetland._point(habitat)) < 2.0, "Scenery must track the camera projection")
	for species in 5:
		var bird_sheet: Texture2D = game.wetland.BIRD_ACTIONS[species]
		check(bird_sheet.get_width() >= 128 and bird_sheet.get_height() >= 128, "Bird atlas must contain all sixteen poses")
		for frame in 16:
			var region: Rect2 = game.wetland._bird_frame_region(species, frame)
			check(Rect2(Vector2.ZERO, bird_sheet.get_size()).encloses(region), "Bird animation frame exceeds atlas")
	for state in [0, 1, 2, 3, 4, 5]:
		for age in [0.0, 0.2, 0.5, 1.0]:
			var frame: int = game.wetland._bird_animation_frame({"state": state, "animation_age": age, "slot": 0})
			check(frame >= 0 and frame < 16, "Animation state must select a valid bird pose")
	check(game.wetland._bird_animation_frame({"state": 3, "animation_age": 0.0}) == 14, "Flight must begin with takeoff")
	check(game.wetland._bird_animation_frame({"state": 0, "animation_previous_state": 5, "animation_age": 0.0}) == 15, "Return flight must finish with landing")
	var camera: Camera3D = game.wetland.map_camera
	check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Map must use a real orthographic 3D camera")
	check(is_zero_approx(camera.position.x), "Camera azimuth must be 0 (地图转正)")
	check(is_equal_approx(camera.position.y, Vector2(camera.position.x, camera.position.z).length()), "Camera pitch must be 45 degrees")
	var marker := Vector2(0.4, 0.6)
	check(game.wetland._point(marker).is_equal_approx(camera.unproject_position(game.wetland._ground_position(marker)).round()), "Habitat must match projected terrain")
	check(game.wetland.house_sites.size() >= 12, "Village should spread around the lake")
	for site in game.wetland.house_sites:
		check(game.wetland._is_land(site) and game.wetland._near_water(site), "Cottage must be on near-shore land")
		check(site.distance_to(game.wetland.CREEPER_ANCHOR) > 0.11, "Cottage covers Creeper clearing")
	var original_settlement: float = GameState.settlement
	GameState.settlement = 100.0
	GameState.metrics_changed.emit()
	await settle(0.25)
	check(game.wetland.house_target_count == 7, "Settlement must keep the old maximum of seven cottages")
	check(game.wetland.house_progress[6] > 0.0, "Expansion must animate construction")
	game._score_animating = true
	GameState.settlement = 0.0
	GameState.metrics_changed.emit()
	check(game.wetland.house_target_count == 7, "Scenery must stay frozen during score reveal")
	game._score_animating = false
	game._update_3d()
	GameState.settlement = 0.0
	GameState.metrics_changed.emit()
	await settle(0.25)
	check(game.wetland.house_progress[0] < 1.0, "Wetland recovery must animate cottage removal")
	GameState.settlement = original_settlement
	GameState.metrics_changed.emit()
	game._pause_game()
	await settle(0.1)
	var paused_elapsed: float = game.wetland.elapsed
	await settle(0.2)
	check(is_equal_approx(paused_elapsed, game.wetland.elapsed), "Pause must freeze scenery animation")
	game._resume_game()
	var flying_bird: Dictionary = game.wetland.bird_agents[0]
	flying_bird["state"] = 3
	flying_bird["pos"] = Vector2(0.42, 0.50)
	flying_bird["target"] = Vector2(0.35, 0.50)
	game.wetland._process_birds(0.05)
	check(absf(absf(float(flying_bird["angle"])) - PI) < 0.01, "Flying bird must face its destination")
	check(game.wetland._bird_facing(flying_bird) == -1.0, "Bird flying screen-left must mirror horizontally")
	for heading in [0.0, PI / 2.0, PI, -PI / 2.0]:
		var center := Vector2(0.5, 0.5)
		var screen_direction := camera.unproject_position(game.wetland._ground_position(center + Vector2.from_angle(heading) * 0.01)) - camera.unproject_position(game.wetland._ground_position(center))
		var expected_facing := -1.0 if screen_direction.x < 0.0 else 1.0
		check(game.wetland._bird_facing({"angle": heading}) == expected_facing, "Bird facing must follow projected motion")
	for info in game.card_infos:
		check(info.panel.size.is_equal_approx(Vector2(122, 165)), "Card footprint changed: " + str(info.panel.size))
	check(game.end_turn_btn.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y, "End turn button exceeds viewport")
	await capture("03-gameplay")
	# ---------------- 手牌陀螺仪（与牌库 / 知识卡图鉴同一套）----------------
	# 测试机有人在用鼠标：牌堆被点一下就会弹出牌库全屏层，把后面所有画面盖住。
	# 拍手牌之前先把这些层收干净（本测试自己不开它们）。
	game._close_deck_viewer()
	game._close_knowledge_viewer()
	await settle(0.4)
	var probe_info: Dictionary = game.card_infos[game.card_infos.size() - 1]
	var probe_panel: PanelContainer = probe_info["panel"]
	check(probe_panel.material is ShaderMaterial, "手牌应挂上陀螺仪材质")
	var pc: Vector2 = game._card_gyro_center(probe_panel)
	# 注入一个偏离卡片中心的悬停点（右上 40, -30），倾斜才有非零分量
	for i in 24:
		game._update_card_hover(0.05, pc + Vector2(40, -30))
	# 抬起动画会把这 24 帧里的牌挪走，中心要在走完之后重新取
	pc = game._card_gyro_center(probe_panel)
	var pmat: ShaderMaterial = probe_panel.material
	var tx: float = pmat.get_shader_parameter("tilt_x")
	var ty: float = pmat.get_shader_parameter("tilt_y")
	check(absf(tx) > 0.02 or absf(ty) > 0.02, "悬停的手牌应产生非零倾斜，实际 tx=%.4f ty=%.4f" % [tx, ty])
	check(pc.distance_to(Vector2(pmat.get_shader_parameter("card_center"))) < 8.0,
		"倾斜中心应是这张牌的中心")
	# 冻住 process：否则下一帧就用「真实鼠标不在牌上」把倾斜抹掉了，拍不出来
	game.set_process(false)
	await settle(0.3)
	await capture("03b-hand-gyro")
	game.set_process(true)
	# 鼠标移开 → 倾斜收回
	for i in 24:
		game._update_card_hover(0.05, Vector2(-500, -500))
	check(absf(float(pmat.get_shader_parameter("tilt_x"))) < 0.02 and absf(float(pmat.get_shader_parameter("tilt_y"))) < 0.02,
		"鼠标移开后手牌倾斜应收回到零")
	var before: Dictionary = GameState.metrics.duplicate()
	var before_funds: int = GameState.funds
	var info: Dictionary = game.card_infos[0]
	game._set_play_tier("basic", false)
	game._toggle_card(info.panel)
	var locked_tier: String = info.tier
	game._set_play_tier("deep", false)
	check(info.tier == locked_tier, "Changing lever must preserve selected card tier")
	check(GameState.funds == before_funds and GameState.metrics == before, "Selecting cards must not spend/apply effects")
	await settle()
	await capture("04-selected")
	game._toggle_card(info.panel)
	game._set_play_tier("effective", false)
	game._open_deck_viewer()
	await settle(1.8)
	await capture("05-deck")
	# ---------------- 点开的那张放大牌也要会晃 ----------------
	var any_view: Control = game.deck_viewer_grid.get_child(0)
	game._show_card_detail(any_view, any_view.get_meta("card"))
	await settle(0.9)
	var big: Control = game._detail_big_card
	check(big != null and big.material is ShaderMaterial, "详情大牌应挂上陀螺仪材质")
	var bc: Vector2 = big.get_global_transform() * big.pivot_offset
	for i in 24:
		game._process_detail_gyro(0.05, bc + Vector2(50, -40))
	var bmat: ShaderMaterial = big.material
	check(absf(float(bmat.get_shader_parameter("tilt_x"))) > 0.02 or absf(float(bmat.get_shader_parameter("tilt_y"))) > 0.02,
		"鼠标压在大牌上时应产生倾斜")
	check(bc.distance_to(Vector2(bmat.get_shader_parameter("card_center"))) < 6.0,
		"大牌的倾斜中心应是它自己的中心")
	game.set_process(false)
	await settle(0.3)
	await capture("05b-detail-gyro")
	game.set_process(true)
	game._close_card_detail()
	await settle(0.3)
	game._close_deck_viewer()
	await settle(0.7)
	game._open_dispatch_panel()
	await settle(1.0)
	await capture("06-dispatch")
	game._close_dispatch_panel()
	await settle(0.6)
	game._pause_game()
	await settle(0.3)
	await capture("07-pause")
	game._on_pause_settings()
	await settle(0.3)
	game.pause_score_speed_slider.value = 300.0
	check(is_equal_approx(game.score_speed, 3.0) and is_equal_approx(game.score_speed_slider.value, 300.0), "Both settings panels must support and synchronize 300% settlement speed")
	game.score_speed = 1.0
	game._load_audio_settings()
	game._sync_score_speed_ui()
	check(is_equal_approx(game.score_speed, 3.0), "300% settlement speed must survive settings reload")
	await capture("08-settings")
	game._on_pause_settings_back()
	game._resume_game()
	# Resolve an actual turn, including the existing score choreography.
	game._set_play_tier("basic", false)
	game._toggle_card(game.card_infos[0].panel)
	var turn_before: int = GameState.turn
	game._finish_turn()
	await settle(1.0)
	await capture("09-scoring")
	for i in 100:
		if not game._score_animating: break
		await settle(0.2)
	check(not game._score_animating, "Score animation did not finish")
	await close_popups()
	await settle(0.7)
	check(GameState.turn > turn_before or not game._playing, "End turn failed to advance")
	check(game.wetland.metrics == GameState.metrics, "Map must reflect settled ecology")
	await capture("10-next-season")
	# Save/resume exercise uses the isolated test user directory.
	game.save_game()
	var saved_turn: int = GameState.turn
	check(game.load_game(), "Could not load saved run")
	check(GameState.turn == saved_turn, "Resume changed the turn")
	await settle()
	# Every card, including long names, must fit existing animation viewports.
	for card in GameState.ACTION_CARDS:
		var made: Dictionary = game._make_card(card)
		add_child(made.panel)
		await get_tree().process_frame
		check(made.panel.get_combined_minimum_size().y <= 165, "Card too tall: " + str(card.name))
		made.panel.queue_free()
	get_window().size = Vector2i(960, 540)
	await settle(0.8)
	await capture("11-small-window")
	check(not get_viewport().get_visible_rect().intersects(creeper_screen_rect()), "Small-window gameplay must leave the entire Creeper outside")
	check(game.end_turn_btn.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y, "Small-window controls clipped")
	get_window().size = Vector2i(1600, 900)
	await settle(0.8)
	await capture("12-large-window")
	check(not get_viewport().get_visible_rect().intersects(creeper_screen_rect()), "Large-window gameplay must leave the entire Creeper outside")
	# ---------------- 游戏内收集 → 图鉴解锁 的链路 ----------------
	# 走真正的 _show_knowledge（玩家弹知识卡时实际走的那条路径），
	# 验「弹出来了 = 收进收藏了」，再回主页图鉴确认它点亮。
	Knowledge.reset_all()
	check(Knowledge.collected_count() == 0, "重置后不该有已收集的知识卡")
	var probe_kid := "cons_compensate"
	check(not Knowledge.is_collected(probe_kid), "探针卡此刻应为未收集")
	game._show_knowledge(probe_kid)
	await settle(0.5)
	check(Knowledge.is_collected(probe_kid), "游戏内弹出的知识卡应被记入收藏：" + probe_kid)
	check(Knowledge.collected_count() == 1, "收集数应为 1，实际 %d" % Knowledge.collected_count())
	await close_popups()
	game._show_menu()          # 从主页看图鉴 —— 玩家实际的路径（顺带把对局 HUD 收起来）
	await settle(0.7)
	game._open_knowledge_viewer()
	await settle(1.3)
	check(game.knowledge_count_label.text == "已收集 1 / %d" % Knowledge.total_count(), "触发收藏后的计数应正确")
	await capture("13-knowledge-in-game-unlock")
	game._close_knowledge_viewer()
	await settle(0.4)
	# ---------------- 多分辨率下的彩蛋可见性（朋友版）----------------
	# Returning to the menu reveals the same physical clearing as the camera retreats.
	game._pause_game()
	game._on_pause_exit()
	game.wetland.creeper_mesh.visible = true
	await settle(1.3)
	await capture("13-return-to-menu")
	for window_size in [Vector2i(960, 900), Vector2i(1920, 720)]:
		get_window().size = window_size
		await settle(0.4)
		check(get_viewport().get_visible_rect().grow(-20).encloses(creeper_screen_rect()), "Menu must reveal the entire Creeper across aspect ratios")
		game._on_continue_pressed()
		await settle(1.0)
		check(not get_viewport().get_visible_rect().intersects(creeper_screen_rect()), "Resuming must move the entire Creeper beyond the viewport")
		game._pause_game()
		game._on_pause_exit()
		game.wetland.creeper_mesh.visible = true
		await settle(1.3)

	scene.queue_free()
	await get_tree().process_frame
	print("VISUAL_SMOKE: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures / ", checks, " checks)")
	get_tree().quit(0 if failures.is_empty() else 1)
