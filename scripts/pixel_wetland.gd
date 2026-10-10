extends Control

const Motion = preload("res://scripts/motion.gd")
const MotionWeb = preload("res://scripts/motion_web.gd")
const VisualTheme := preload("res://scripts/visual_theme.gd")
var scenery_atlas := preload("res://scripts/scenery_atlas.gd").new()

func _atlas_texture(source: Texture2D) -> Texture2D:
	return scenery_atlas.texture(source)

func _build_scenery_atlas() -> void:
	var sources: Array = []
	for group in [sprites, bird_sprites, BIRD_ACTIONS, HOUSE_ART, prop_textures, pine_seasons, seasonal_trees]:
		sources.append_array(group)
	for frames in tree_frames: sources.append_array(frames)
	sources.append_array([FLOATING_ISLAND, COMMUNITY_CAR])
	scenery_atlas.build(sources)
## Orthographic 45-degree wetland view, with upright scenery and wildlife.
## All decorative placement is deterministic; never consume gameplay RNG.
const LANDSCAPE := preload("res://assets/art/poyang-terrain-base.png")
const SHORE_DISTANCE := preload("res://assets/art/lake-shore-distance.png")
const GROUND_SHADER := preload("res://scripts/wetland_ground.gdshader")
const CONTACT_SHADOW_SHADER := preload("res://scripts/wetland_contact_shadow.gdshader")
const YANGTZE_HALF_WIDTH := 0.030
const RIVER_BOAT_SPEED := 0.00035
const RIVER_BOAT_LANE := 0.010
const FISHING_BOAT_EXTENT := Vector2(60, 62)
# Bow-to-stern axis in the existing diagonal artwork at its rendered aspect.
const FISHING_BOAT_FORWARD := Vector2(-0.78, 0.62)
const GAN_HALF_WIDTH := 0.010
const LAND_COLOR := VisualTheme.MEADOW
const SEASON_CHANGE_DURATION := 1.15
const MAX_WEATHER_PARTICLES := 180
## 相机方位角转正后，地面在屏幕上的投影宽度从 GROUND_SIZE*(sin45+cos45)=1.414 倍
## 变成 GROUND_SIZE*1.0 倍；把 MAP_ZOOM 按同样比例缩回来，视野才跟转正前一致。
const MAP_ZOOM := 1.12
const GAME_CAMERA_ZOOM := 0.9
const VIEW_AZIMUTH := 0.0
const VIEW_PITCH := PI / 4.0
const GROUND_SIZE := 100.0
const BIRD_DISPLAY_SCALE := 0.65
const BIRD_PERCH_BODY := [0.56, 0.54, 0.60, 0.59, 0.65]
const BOAT_BIRD_CLEARANCE := Vector2(44, 40)
var _perch_heights: Dictionary = {}
const RiverRoutes := preload("res://scripts/wetland_rivers.gd")
const CREEPER_ART := preload("res://assets/creeper.png")
# Peripheral grass: within the menu view, beyond the closer gameplay view.
# 转正后实测（tools 探针扫描）：菜单半视野里的 216 个候选点中，有 144 个在进入对局后会出画；
# 出画的判据是屏幕 y 落到画面上方。取右上方那一档 —— 开始页完整可见、对局时整只出画。
const CREEPER_ANCHOR := Vector2(0.9700000, 0.0400000)
const HOUSE_ART := [
	preload("res://assets/houses/house1.png"),
	preload("res://assets/houses/house2.png"),
	preload("res://assets/houses/house3.png"),
	preload("res://assets/houses/house4.png"),
]
## 房子贴图被画进 76×76 的方框、锚点纵向在 0.86 —— 必须和 _draw_houses 的绘制一致。
const COMMUNITY_CAR := preload("res://assets/houses/community-car.png")
const CAR_COMMUNITY_THRESHOLD := 75
const CAR_HOUSE_INDEX := 11
const CAR_EXTENT := Vector2(44, 31)
const HOUSE_BOX := 76.0
const HOUSE_ANCHOR_Y := 0.86
## 影子按对象分开关。反馈历史：先"太诡异，把影子都删掉" → 再"船不加影子，建筑物加回来"。
## 默认只给建筑开着，其余随时改这里，不用动调用点。
const SHADOWS := {
	"building": true,    # 房屋
	"boat": false,       # 渔船
	"tree": true,        # 树 / 沿岸植被
	"island": false,     # 浮岛
}
## Per-art radius caps, further limited by the opaque sprite footprint.
const HOUSE_SHADOW_RADIUS := [30.0, 31.0, 34.0, 36.0]
const HOUSE_SHADOW_FOOT := [0.0, 0.0, 6.0, 6.0]
## 空地（只有一株芦苇标记）的接触阴影：草本植物，给小一号的。
const PLOT_SHADOW_RADIUS := 15.0
const PLOT_SHADOW_FOOT := 3.0
## 额外把影子在地面平面上再压扁一点。真 3D 的相机投影只压到 sin(45°)≈0.707，看着仍偏圆；
## 1.0 = 不再额外压（纯相机投影），越小越扁。
const SHADOW_FLATTEN := 0.62
## 树（岸树 / 草地上的树 / 赤山树）的接触阴影。
const TREE_SHADOW_RADIUS := 19.0
const TREE_SHADOW_FOOT := 4.0
const SPRITES := preload("res://assets/art/wetland-sprites.png")
const BIRDS := preload("res://assets/art/wetland-birds.png")
const BIRD_ACTIONS := [
	preload("res://assets/art/bird-baihe-v2.png"),
	preload("res://assets/art/bird-dongfangbaihuan-v2.png"),
	preload("res://assets/art/bird-xiaotiane-v2.png"),
	preload("res://assets/art/bird-baizhenhe-v2.png"),
	preload("res://assets/art/bird-yanlei-v2.png"),
]
const BIRD_ATLAS_GRID := Vector2(4, 4)
const FLOATING_ISLAND := preload("res://assets/art/floating-island.png")
const SHORE_TREE := preload("res://assets/art/shore-tree.png")
const SPECIES_ART := {"baihe": 0, "dongfangbaihuan": 1, "xiaotiane": 2, "baizhenhe": 3, "yanlei": 4}
# Fixed habitat anchors sampled against the terrain palette; no gameplay RNG.
const WATER_ANCHORS: Array[Vector2] = [
	Vector2(0.36, 0.50), Vector2(0.40, 0.50), Vector2(0.43, 0.51),
	Vector2(0.36, 0.55), Vector2(0.40, 0.55), Vector2(0.44, 0.55),
	Vector2(0.36, 0.60), Vector2(0.40, 0.60), Vector2(0.42, 0.63),
	Vector2(0.37, 0.66), Vector2(0.35, 0.70), Vector2(0.37, 0.73),
]
const ISLAND_ANCHORS: Array[Vector2] = [
	Vector2(0.38, 0.54), Vector2(0.40, 0.59), Vector2(0.39, 0.64),
	Vector2(0.38, 0.68), Vector2(0.35, 0.73), Vector2(0.41, 0.54),
]
const SHORE_ANCHORS: Array[Vector2] = [
	Vector2(0.304688, 0.500000), Vector2(0.301758, 0.549805),
	Vector2(0.309570, 0.599609), Vector2(0.320312, 0.650391),
	Vector2(0.309570, 0.700195), Vector2(0.291992, 0.750000),
	Vector2(0.268555, 0.790039), Vector2(0.351563, 0.792969),
	Vector2(0.408204, 0.732422), Vector2(0.451172, 0.650391),
	Vector2(0.450195, 0.596680), Vector2(0.495117, 0.621094),
	Vector2(0.545898, 0.634766), Vector2(0.628907, 0.611329),
	Vector2(0.629883, 0.660156), Vector2(0.691407, 0.700195),
	Vector2(0.636719, 0.761719), Vector2(0.528320, 0.783203),
	Vector2(0.480469, 0.860352), Vector2(0.472656, 0.900391),
]
const HOUSE_RING_TARGETS: Array[Vector2] = [
	Vector2(0.35, 0.25), Vector2(0.43, 0.31), Vector2(0.51, 0.36),
	Vector2(0.60, 0.41), Vector2(0.71, 0.45), Vector2(0.78, 0.51),
	Vector2(0.79, 0.60), Vector2(0.73, 0.69), Vector2(0.65, 0.77),
	Vector2(0.55, 0.79), Vector2(0.44, 0.80), Vector2(0.35, 0.77),
	Vector2(0.29, 0.70), Vector2(0.28, 0.60), Vector2(0.28, 0.49),
	Vector2(0.30, 0.38),
]
const EDGE_TREE_TARGETS: Array[Vector2] = [
	Vector2(0.15, 0.22), Vector2(0.19, 0.67), Vector2(0.24, 0.79),
	Vector2(0.71, 0.25), Vector2(0.81, 0.34), Vector2(0.87, 0.72),
	Vector2(0.75, 0.79), Vector2(0.59, 0.18),
]
const BOAT_ANCHOR := Vector2(0.40, 0.57)
var bird_sprites: Array[AtlasTexture] = []
var sprites: Array[AtlasTexture] = []
var metrics: Dictionary = {}
var populations: Dictionary = {}
var plants: Dictionary = {}
var islands := 0
var settlement := 50.0
var season := 0
var previous_season := 0
var season_progress := 1.0
var tree_season_age := 4.0
var elapsed := 0.0
var backdrop: TextureRect
var terrain_viewport: SubViewport
var map_camera: Camera3D
var creeper_mesh: MeshInstance3D
var _reserved_camera_zoom := 1.3
var camera_zoom_factor := GAME_CAMERA_ZOOM
var camera_tween: Tween
var hand_view_tween: Tween
var hand_view_state := Vector2(0.0, 1.0)
var _hand_view_target := Vector2(0.0, 1.0)
var _screen_projection := Transform2D.IDENTITY
var _shadow_projection := Transform2D.IDENTITY
var _overlay_inverse := Transform2D.IDENTITY
var _shadow_unit_rings: Dictionary = {}
var _static_items: Array[Dictionary] = []
var _static_key: Array = []
var _scenery_revision := 0
var _shadow_key: Array = []
var _relief_values := PackedFloat32Array()
var _relief_cache: Dictionary = {}
var _route_lengths: Dictionary = {}
var _render_items: Array[Dictionary] = []
var _render_shadow_specs: Array[Dictionary] = []
var _river_distance_cache: Dictionary = {}
var water_material: ShaderMaterial
var ground_material: ShaderMaterial
var ground_plane: PlaneMesh
var relief_image: Image
var relief_texture: ImageTexture
var river_surface_texture: ImageTexture
var river_water_materials: Array[ShaderMaterial] = []
var clearing_material: ShaderMaterial
var river_bank_material: ShaderMaterial
var reduced_motion := false
var terrain_image: Image
var shore_image: Image
var displayed_metrics: Dictionary = {}
var displayed_populations: Dictionary = {}
var displayed_plants: Dictionary = {}
var displayed_islands := 0.0
var transition_from: Dictionary = {}
var transition_age := 1.0
var transition_duration := 0.85
var action_effects: Array[Dictionary] = []
var visual_rng := RandomNumberGenerator.new()
var easter_rng := RandomNumberGenerator.new()
var visual_seed := -1
var plant_sites: Dictionary = {}
var bird_agents: Array[Dictionary] = []
const MAX_INTERESTS := 4
var interests: Array[Dictionary] = []
var interest_cooldown := 0.0
var interest_captures := 0
var house_sites: Array[Vector2] = []
var house_progress: Array[float] = []
var house_target_count := 0
var car_site := Vector2.ZERO
var car_progress := 0.0
var yangtze_route: Array[Vector2] = []
var gan_route: Array[Vector2] = []
var scenery_props: Array[Dictionary] = []
var prop_textures: Array[ImageTexture] = []
var exterior_image: Image
var exterior_texture: ImageTexture
var seasonal_trees: Array[Texture2D] = []
var tree_frames: Array = []
var pine_seasons: Array[Texture2D] = []
var summer_flowers: Array[Vector2] = []
var snow_sites: Array[Vector2] = []
## Opaque sprite footprints keep contact shadows under the actual feet.
var house_art_shape: Array[Dictionary] = []

func _ready() -> void:
	for i in 8:
		var atlas := AtlasTexture.new()
		atlas.atlas = SPRITES
		atlas.region = Rect2((i % 4) * 384, floori(float(i) / 4.0) * 512, 384, 512)
		atlas.filter_clip = true
		sprites.append(atlas)
	for i in 6:
		var atlas := AtlasTexture.new()
		atlas.atlas = BIRDS
		atlas.region = Rect2((i % 3) * 512, floori(float(i) / 3.0) * 512, 512, 512)
		atlas.filter_clip = true
		bird_sprites.append(atlas)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terrain_image = LANDSCAPE.get_image()
	shore_image = SHORE_DISTANCE.get_image()
	_build_river_routes()
	_make_house_sites()
	_make_car_site()
	_measure_house_art()
	_build_exterior_seasons()
	_build_meadow_scenery()
	_build_scenery_atlas()
	_build_land_relief()
	easter_rng.randomize()
	var land_margin := ColorRect.new()
	land_margin.name = "LandMargin"
	land_margin.color = LAND_COLOR
	land_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	land_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(land_margin)
	backdrop = TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float quality = 0.65;
uniform float level = 0.5;
uniform float vegetation = 0.5;
uniform vec4 season_tint : source_color = vec4(1.0);
void fragment() {
 // COLOR includes the texture, or the flat ColorRect color for land margins.
 vec4 original = COLOR;
 float water = smoothstep(0.04, 0.18, original.b - original.r) * smoothstep(0.04, 0.16, original.g - original.r);
 vec4 col = original;
 col.rgb = mix(col.rgb, col.rgb * vec3(0.85, 0.89, 0.58), water * (1.0 - quality) * 0.55);
 float shallows = water * smoothstep(0.42, 0.80, original.g);
 col.rgb = mix(col.rgb, vec3(0.69, 0.65, 0.42), shallows * (1.0 - level) * 0.55);
 float foliage = smoothstep(0.03, 0.17, original.g - original.b) * (1.0-water);
 col.rgb = mix(col.rgb, col.rgb * vec3(1.12, 0.88, 0.70), foliage * (1.0-vegetation) * 0.65);
 COLOR = col * season_tint;
}"""
	water_material = ShaderMaterial.new()
	water_material.shader = shader
	# The terrain viewport fills the view with seasonal ground, including margins.
	backdrop.material = water_material
	_build_terrain_viewport()
	backdrop.texture = terrain_viewport.get_texture()
	add_child(backdrop)
	_layout_map()
	# Contact shadows are ground decals, always below all upright scenery.
	var shadows := Control.new()
	shadows.name = "GroundShadows"
	shadows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = CONTACT_SHADOW_SHADER
	shadow_material.set_shader_parameter("ground_texture", terrain_viewport.get_texture())
	shadows.material = shadow_material
	shadows.draw.connect(_draw_contact_shadows.bind(shadows))
	add_child(shadows)
	# Wildlife stays separate from the terrain-only texture.
	var wildlife := Control.new()
	wildlife.name = "Wildlife"
	var scenery_material := ShaderMaterial.new()
	scenery_material.shader = preload("res://scripts/wetland_scenery.gdshader")
	wildlife.material = scenery_material
	wildlife.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wildlife.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wildlife.draw.connect(_draw_wildlife.bind(wildlife))
	add_child(wildlife)
	var weather := Control.new()
	weather.name = "SeasonWeather"
	weather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weather.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weather.draw.connect(_draw_season_weather.bind(weather))
	add_child(weather)
	_layout_map()
	resized.connect(_layout_map)
	sync_state()

func _build_terrain_viewport() -> void:
	terrain_viewport = SubViewport.new()
	terrain_viewport.name = "TerrainViewport"
	terrain_viewport.own_world_3d = true
	terrain_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(terrain_viewport)
	var world := Node3D.new()
	terrain_viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = LAND_COLOR
	world.add_child(environment)
	var ground := MeshInstance3D.new()
	ground.name = "WetlandGround"
	ground_plane = PlaneMesh.new()
	ground_plane.size = Vector2.ONE * GROUND_SIZE
	ground_plane.subdivide_width = 127
	ground_plane.subdivide_depth = 127
	ground.mesh = ground_plane
	ground_material = _make_ground_material(false)
	ground.material_override = ground_material
	world.add_child(ground)
	river_bank_material = _make_river_bank_material()
	_build_river_mesh(world, yangtze_route, YANGTZE_HALF_WIDTH)
	_build_river_mesh(world, gan_route, GAN_HALF_WIDTH)
	map_camera = Camera3D.new()
	map_camera.name = "WetlandCamera"
	map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	map_camera.position = Vector3(sin(VIEW_AZIMUTH) * cos(VIEW_PITCH),
		sin(VIEW_PITCH), cos(VIEW_AZIMUTH) * cos(VIEW_PITCH)) * 150.0
	world.add_child(map_camera)
	map_camera.look_at(Vector3.ZERO, Vector3.UP)
	map_camera.current = true
	var clearing := MeshInstance3D.new()
	clearing.name = "CreeperClearing"
	var clearing_plane := PlaneMesh.new()
	clearing_plane.size = Vector2(30, 30)
	clearing.mesh = clearing_plane
	clearing.position = _ground_position(CREEPER_ANCHOR)
	clearing_material = _make_ground_material(false)
	clearing_material.set_shader_parameter("meadow_only", true)
	clearing_material.set_shader_parameter("terrain_relief", false)
	clearing.material_override = clearing_material
	clearing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(clearing)
	# Keep the original face as a ground decal, viewed by the same 3D camera.
	creeper_mesh = MeshInstance3D.new()
	creeper_mesh.name = "CreeperEasterEgg"
	var creeper_plane := PlaneMesh.new()
	creeper_plane.size = Vector2(8.0, 8.0 * CREEPER_ART.get_height() / CREEPER_ART.get_width())
	creeper_mesh.mesh = creeper_plane
	creeper_mesh.position = _ground_position(CREEPER_ANCHOR) + Vector3(0, 0.03, 0)
	var creeper_shader := Shader.new()
	creeper_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D face_texture : source_color, filter_nearest;
void fragment() {
 vec4 pixel = texture(face_texture, UV);
 if (pixel.a < 0.5 || (pixel.g > 0.63 && pixel.g > pixel.r * 1.08 && pixel.r > 0.48)) discard;
 ALBEDO = pixel.rgb;
}"""
	var creeper_material := ShaderMaterial.new()
	creeper_material.shader = creeper_shader
	creeper_material.set_shader_parameter("face_texture", CREEPER_ART)
	creeper_mesh.material_override = creeper_material
	creeper_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	creeper_mesh.visible = false
	world.add_child(creeper_mesh)

func _layout_map() -> void:
	var viewport_size := Vector2i(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))
	if terrain_viewport.size != viewport_size:
		terrain_viewport.size = viewport_size
	var aspect := float(viewport_size.x) / float(viewport_size.y)
	var ground_width := GROUND_SIZE * (sin(VIEW_AZIMUTH) + cos(VIEW_AZIMUTH))
	var ground_height := ground_width * sin(VIEW_PITCH)
	var view_zoom := camera_zoom_factor * hand_view_state.y
	map_camera.size = maxf(ground_height, ground_width / aspect) / MAP_ZOOM * view_zoom
	map_camera.v_offset = -hand_view_state.x * map_camera.size
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(viewport_size)
	for layer_name in ["Wildlife", "GroundShadows"]:
		var layer := get_node_or_null(layer_name) as Control
		if layer:
			layer.scale = Vector2.ONE / view_zoom
			layer.position = size * 0.5 * (1.0 - 1.0 / view_zoom)
	# Orthographic ground projection is affine. Compute it once per camera or
	# window change instead of asking Camera3D for every sprite/shadow vertex.
	var origin := map_camera.unproject_position(_ground_position(Vector2.ZERO))
	_screen_projection = Transform2D(
		map_camera.unproject_position(_ground_position(Vector2.RIGHT)) - origin,
		map_camera.unproject_position(_ground_position(Vector2.DOWN)) - origin, origin)
	# Cover every camera corner during menu zoom, hand focus and window resizing.
	# Artwork UVs retain their original scale as the surrounding meadow expands.
	var screen_to_map := _screen_projection.affine_inverse()
	var half_extent := Vector2.ONE * GROUND_SIZE * 0.5
	for corner in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		var reserve_scale := maxf(view_zoom, _reserved_camera_zoom) / view_zoom
		var uv: Vector2 = screen_to_map * (size * 0.5 + (corner - size * 0.5) * reserve_scale)
		half_extent = half_extent.max((uv - Vector2.ONE * 0.5).abs() * GROUND_SIZE)
	# Extra margin also covers the screen displacement of raised outer hills.
	var required_size := (half_extent + Vector2.ONE * 4.0) * 2.0
	# PlaneMesh setters rebuild the subdivided mesh. Reserve the farthest camera
	# endpoint once and grow only for a genuinely larger window/focus footprint.
	var reserved_size := ground_plane.size.max(required_size)
	if not reserved_size.is_equal_approx(ground_plane.size): ground_plane.size = reserved_size
	var wildlife := get_node_or_null("Wildlife") as Control
	if wildlife:
		_overlay_inverse = wildlife.get_transform().affine_inverse()
		_shadow_projection = _overlay_inverse * _screen_projection
	_redraw_scenery()

func set_menu_camera(far: bool, menu_zoom: float = 1.3) -> void:
	if camera_tween and camera_tween.is_valid(): camera_tween.kill()
	_reserved_camera_zoom = maxf(_reserved_camera_zoom, menu_zoom)
	var target := menu_zoom if far else GAME_CAMERA_ZOOM
	if reduced_motion:
		_set_camera_zoom(target)
		return
	# Retarget from the current pose, including interrupted transitions.
	camera_tween = Motion.tween(self, "camera", "camera")
	camera_tween.tween_method(_set_camera_zoom, camera_zoom_factor, menu_zoom if far else GAME_CAMERA_ZOOM, 1.2 if far else 0.8)

func _set_camera_zoom(value: float) -> void:
	camera_zoom_factor = value
	_layout_map()

func set_hand_view(focus_fraction: float, zoom_multiplier: float, animate: bool = true) -> void:
	var target := Vector2(focus_fraction, zoom_multiplier)
	if animate and target.is_equal_approx(_hand_view_target): return
	_hand_view_target = target
	if hand_view_tween and hand_view_tween.is_valid(): hand_view_tween.kill()
	if not animate or reduced_motion:
		_set_hand_view_state(target)
		return
	hand_view_tween = Motion.tween(self, "focus", "hand_focus")
	hand_view_tween.tween_method(_set_hand_view_state, hand_view_state, target, 0.28)

func _set_hand_view_state(value: Vector2) -> void:
	hand_view_state = value
	_layout_map()

func roll_creeper_visibility() -> void:
	if creeper_mesh:
		creeper_mesh.visible = easter_rng.randf() < 0.1

## Read-only snapshots allow the score choreography to replay each card's result.
func capture_state() -> Dictionary:
	return {"metrics": GameState.metrics.duplicate(), "populations": GameState.species_pop.duplicate(),
		"plants": GameState.plant_pop.duplicate(), "islands": GameState.floating_islands,
		"settlement": GameState.settlement, "season": maxi(0, GameState.SEASONS.find(GameState.current_season())),
		"seed": GameState.run_seed}

func sync_state(state: Dictionary = {}, animate: bool = true, duration: float = 0.85) -> void:
	if state.is_empty(): state = capture_state()
	var new_seed := visual_seed != int(state["seed"])
	var changed: bool = metrics != state["metrics"] or populations != state["populations"] or plants != state["plants"] or islands != int(state["islands"])
	metrics = state["metrics"].duplicate()
	populations = state["populations"].duplicate()
	plants = state["plants"].duplicate()
	islands = int(state["islands"])
	settlement = float(state["settlement"])
	var next_season := int(state["season"])
	if new_seed or not animate or reduced_motion or displayed_metrics.is_empty():
		previous_season = next_season
		season_progress = 1.0
		tree_season_age = 4.0
	elif next_season != season:
		previous_season = season
		season_progress = 0.0
		tree_season_age = 0.0
	season = next_season
	if new_seed:
		_reset_scenery()
	sync_community_targets()
	if new_seed or not animate or reduced_motion or displayed_metrics.is_empty():
		displayed_metrics = metrics.duplicate()
		displayed_populations = populations.duplicate()
		displayed_plants = plants.duplicate()
		displayed_islands = float(islands)
		transition_age = duration
		transition_duration = duration
		for i in house_progress.size():
			house_progress[i] = 1.0 if i < house_target_count else 0.0
	elif changed:
		transition_from = {"metrics": displayed_metrics.duplicate(), "populations": displayed_populations.duplicate(),
			"plants": displayed_plants.duplicate(), "islands": displayed_islands}
		transition_age = 0.0
		transition_duration = maxf(0.05, duration)
	_apply_terrain_state()
	_redraw_scenery()

func _lake_offset() -> float:
	var level := float(displayed_metrics.get("water_level", 50))
	return (level - 50.0) / 50.0 * (22.0 if level >= 50.0 else 18.0)

func _apply_terrain_state() -> void:
	for material in [ground_material, river_bank_material, clearing_material] + river_water_materials:
		if material:
			material.set_shader_parameter("lake_offset", _lake_offset())
			material.set_shader_parameter("season", season)
			material.set_shader_parameter("previous_season", previous_season)
			material.set_shader_parameter("season_progress", season_progress)
	if water_material:
		water_material.set_shader_parameter("quality", float(displayed_metrics.get("water_quality", 65)) / 100.0)
		water_material.set_shader_parameter("vegetation", float(displayed_metrics.get("vegetation", 50)) / 100.0)
		water_material.set_shader_parameter("level", float(displayed_metrics.get("water_level", 50)) / 100.0)
		water_material.set_shader_parameter("season_tint", Color.WHITE)

func _advance_presentation(delta: float) -> void:
	if transition_age >= transition_duration or transition_from.is_empty(): return
	transition_age = minf(transition_duration, transition_age + delta)
	var fraction := 1.0 if reduced_motion else smoothstep(0.0, 1.0, transition_age / transition_duration)
	for entry in [[displayed_metrics, metrics, "metrics"], [displayed_populations, populations, "populations"], [displayed_plants, plants, "plants"]]:
		for key in entry[1]:
			entry[0][key] = lerpf(float(transition_from[entry[2]].get(key, entry[1][key])), float(entry[1][key]), fraction)
	displayed_islands = lerpf(float(transition_from["islands"]), float(islands), fraction)
	_apply_terrain_state()

func _advance_season(delta: float) -> void:
	tree_season_age = 4.0 if reduced_motion else minf(4.0, tree_season_age + delta)
	if season_progress >= 1.0: return
	season_progress = 1.0 if reduced_motion else minf(1.0, season_progress + delta / SEASON_CHANGE_DURATION)
	for material in [ground_material, river_bank_material, clearing_material]:
		if material: material.set_shader_parameter("season_progress", season_progress)

func _season_blend_for_y(screen_y: float) -> float:
	if season_progress >= 1.0: return 1.0
	var edge := lerpf(-0.10, 1.10, season_progress)
	return 1.0 - smoothstep(edge - 0.08, edge + 0.08, screen_y)

func _season_blend_at(uv: Vector2) -> float:
	return _season_blend_for_y(_point(uv).y / maxf(1.0, size.y))

func _flower_amount(uv: Vector2, season_index: int) -> float:
	if season_index == 1: return 1.0
	# Spring opens a sparse first flush; summer fills in the other patches.
	if season_index == 0 and int(absf(uv.x * 1307 + uv.y * 791)) % 3 == 0: return 0.70
	return 0.0

func _flower_amount_at(uv: Vector2) -> float:
	return lerpf(_flower_amount(uv, previous_season), _flower_amount(uv, season), _season_blend_at(uv))

func play_action(card_id: String, state: Dictionary, duration: float) -> void:
	sync_state(state, true, duration)
	if not reduced_motion:
		action_effects.append({"card": card_id, "age": 0.0, "duration": maxf(0.45, duration), "slot": action_effects.size() % 3})

func _process(delta: float) -> void:
	_advance_presentation(delta)
	_advance_season(delta)
	for i in range(action_effects.size() - 1, -1, -1):
		action_effects[i]["age"] += delta
		if action_effects[i]["age"] >= action_effects[i]["duration"]: action_effects.remove_at(i)
	if not reduced_motion:
		elapsed += delta
		interest_cooldown = maxf(0.0, interest_cooldown - delta)
		for interest in interests: interest.age += delta
		_process_birds(delta)
		for i in range(interests.size() - 1, -1, -1):
			if interests[i].age >= 4.0 or interests[i].caught: interests.remove_at(i)
	else:
		interests.clear()
	for i in house_progress.size():
		var target := 1.0 if i < house_target_count else 0.0
		house_progress[i] = target if reduced_motion else move_toward(house_progress[i], target, delta * (1.8 if target > house_progress[i] else 2.2))
	var car_target := 1.0 if _community_car_visible() else 0.0
	car_progress = car_target if reduced_motion else move_toward(car_progress, car_target, delta * 1.8)
	_redraw_scenery()

## Actual lake gestures drive scenery, never gameplay funds/populations/RNG.
func _input(event: InputEvent) -> void:
	if reduced_motion or not is_processing() or MotionWeb.paused(self): return
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var swept: bool = event is InputEventMouseMotion and event.relative.length() >= 12.0
	if not clicked and not swept: return
	var host := get_tree().get_first_node_in_group("motion_host")
	if host:
		if host._intro_playing or host._deck_open or host.knowledge_viewer.visible or host.popup_root.visible or host.crisis_root.visible: return
		if host.menu_root.visible and not host.menu_col.visible: return
	var hovered := get_viewport().gui_get_hovered_control()
	while hovered:
		if hovered is Button or hovered is PanelContainer or hovered is ScrollContainer or hovered is LineEdit: return
		hovered = hovered.get_parent_control()
	var local: Vector2 = get_global_transform().affine_inverse() * event.position
	if not Rect2(Vector2.ZERO, size).has_point(local): return
	var uv := _screen_projection.affine_inverse() * local
	_emit_interest(uv)

func _emit_interest(uv: Vector2) -> bool:
	if reduced_motion or interest_cooldown > 0.0 or interests.size() >= MAX_INTERESTS: return false
	if not Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv) or not _is_water(uv) or _bird_boat_space(uv).length_squared() < 1.0: return false
	interests.append({"pos": uv, "age": 0.0, "caught": false})
	interest_cooldown = 0.8
	return true

## ink-crowd / lyre-crows: acceleration-limited response with a finite consequence.
func _follow_interest(bird: Dictionary, delta: float) -> bool:
	var pos: Vector2 = bird.pos
	var selected: Dictionary = {}
	var best := 0.12 * 0.12
	if int(bird.state) not in [3, 4, 5]:
		for interest in interests:
			var gap := pos.distance_squared_to(interest.pos)
			if not interest.caught and gap < best and _is_water((pos + interest.pos) * 0.5):
				selected = interest
				best = gap
	if selected.is_empty():
		bird["motion_hunting"] = false
		bird["motion_velocity"] = Vector2.ZERO
		return false
	bird["motion_hunting"] = true
	if best < 0.006 * 0.006:
		selected.caught = true
		interest_captures += 1
		bird.state = 1
		bird.timer = 2.2
		bird["motion_response_age"] = 1.0
		bird["animation_age"] = 0.0
		bird["motion_velocity"] = Vector2.ZERO
		return true
	var waypoint := _bird_water_waypoint(bird, selected.pos)
	var velocity := MotionWeb.steer(bird.get("motion_velocity", Vector2.ZERO), waypoint - pos, delta, 0.035, 0.12)
	var next := pos + velocity * delta
	if not _bird_water_segment_clear(pos, next):
		bird["motion_velocity"] = Vector2.ZERO
		bird["motion_hunting"] = false
		return false
	bird["motion_velocity"] = velocity
	bird.pos = next
	bird.angle = velocity.angle()
	bird.state = 2
	return true

func _redraw_scenery() -> void:
	if not has_node("Wildlife"): return
	_render_items = _scenery_draw_order()
	# Birds have no contact decals. Reuse shadow draw commands until the ground,
	# camera, vegetation or building growth actually changes.
	var shadow_key: Array = [_static_key, house_progress.duplicate(), _screen_projection, _overlay_inverse]
	if shadow_key != _shadow_key:
		_shadow_key = shadow_key.duplicate(true)
		_render_shadow_specs = _contact_shadow_specs(_render_items)
		get_node("GroundShadows").queue_redraw()
	get_node("Wildlife").queue_redraw()
	get_node("SeasonWeather").queue_redraw()

func _point(uv: Vector2) -> Vector2:
	# Camera projection keeps upright screen sprites attached to the 3D ground.
	return (_screen_projection * uv + _relief_screen_offset(uv)).round()

func _relief_screen_offset(uv: Vector2) -> Vector2:
	return Vector2(0, -_relief_at(uv) * _screen_projection.y.y / GROUND_SIZE / tan(VIEW_PITCH))

func _relief_at(uv: Vector2) -> float:
	if relief_image == null: return 0.0
	if _relief_cache.has(uv): return _relief_cache[uv]
	var width := relief_image.get_width()
	var pixel := ((uv + Vector2.ONE * 0.5) * 0.5 * width - Vector2.ONE * 0.5).clamp(Vector2.ZERO, Vector2.ONE * (width - 1))
	var a := Vector2i(pixel.floor())
	var b := (a + Vector2i.ONE).min(Vector2i.ONE * (width - 1))
	var value := lerpf(lerpf(_relief_values[a.y * width + a.x], _relief_values[a.y * width + b.x], pixel.x - a.x),
		lerpf(_relief_values[b.y * width + a.x], _relief_values[b.y * width + b.x], pixel.x - a.x), pixel.y - a.y)
	# Bound memory while keeping frequently used fixed scenery anchors hot.
	if _relief_cache.size() < 8192: _relief_cache[uv] = value
	return value

func _build_land_relief() -> void:
	const N := 128
	var dem: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/geography/poyang-elevation.json"))
	assert(int(dem["size"]) == N and dem["north_up"], "Elevation grid must match the north-up terrain")
	var elevations: Array = dem["elevation"]
	var river_surface := Image.create(N, N, false, Image.FORMAT_R8)
	relief_image = Image.create(N, N, false, Image.FORMAT_RF)
	for y in N:
		for x in N:
			var uv := Vector2(x + 0.5, y + 0.5) / N * 2.0 - Vector2.ONE * 0.5
			var rivers := _river_distances_squared(uv)
			var margin := minf(sqrt(rivers.x) - YANGTZE_HALF_WIDTH, sqrt(rivers.y) - GAN_HALF_WIDTH)
			river_surface.set_pixel(x, y, Color.WHITE if margin < 0.014 else Color.BLACK)
			var height := 0.0
			if _is_exterior_land(uv) and not _is_water(uv, true):
				var fade := smoothstep(0.035, 0.075, margin)
				fade *= smoothstep(0.23, 0.30, uv.distance_to(CREEPER_ANCHOR))
				if Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv):
					var shore := shore_image.get_pixel(clampi(int(uv.x * shore_image.get_width()), 0, shore_image.get_width() - 1), clampi(int(uv.y * shore_image.get_height()), 0, shore_image.get_height() - 1))
					if shore.g > 0.0: fade *= smoothstep(10.0, 28.0, (shore.r - 0.5) * 128.0)
				for home in house_sites: fade *= smoothstep(0.022, 0.044, uv.distance_to(home))
				# Compress surveyed relief to the existing gentle sandbox amplitude.
				# Low alluvial plains stay low; mountains remain at their real locations.
				var elevation := maxf(0.0, float(elevations[y * N + x]) - 15.0)
				height = fade * 2.05 * pow(clampf(elevation / 1200.0, 0.0, 1.0), 0.55)
			relief_image.set_pixel(x, y, Color(height, 0, 0))
	_relief_values = relief_image.get_data().to_float32_array()
	_relief_cache.clear()
	relief_texture = ImageTexture.create_from_image(relief_image)
	river_surface_texture = ImageTexture.create_from_image(river_surface)

func _wildlife_point(uv: Vector2) -> Vector2:
	# Undo the overlay's camera zoom for local coordinates; its scale then makes
	# every sprite and ripple zoom in sync with the ground and Creeper decal.
	if (camera_tween and camera_tween.is_running()) or (hand_view_tween and hand_view_tween.is_running()):
		return _shadow_point(uv)
	return (_overlay_inverse * _point(uv)).round()

func _ground_position(uv: Vector2) -> Vector3:
	return Vector3((uv.x - 0.5) * GROUND_SIZE, 0.0, (uv.y - 0.5) * GROUND_SIZE)

func _bird_facing(bird: Dictionary) -> float:
	return float(bird.get("facing", 1.0))

func _update_bird_facing(bird: Dictionary, displacement: Vector2, delta: float) -> void:
	# Near-vertical movement and brief steering corrections retain the last facing.
	var screen_motion := _screen_projection.basis_xform(displacement)
	if screen_motion.length_squared() < 0.00000001 or absf(screen_motion.x) < screen_motion.length() * 0.16:
		bird["facing_age"] = 0.0
		return
	var desired := -1.0 if screen_motion.x < 0.0 else 1.0
	if desired == _bird_facing(bird):
		bird["facing_age"] = 0.0
		return
	if desired != float(bird.get("facing_candidate", 0.0)):
		bird["facing_age"] = 0.0
		bird["facing_candidate"] = desired
	var age := float(bird.get("facing_age", 0.0)) + delta
	bird["facing_age"] = age
	if age >= 0.12:
		bird["facing"] = desired
		bird["facing_age"] = 0.0

func _terrain_color(uv: Vector2) -> Color:
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0: return LAND_COLOR
	var x := clampi(int(uv.x * terrain_image.get_width()), 0, terrain_image.get_width() - 1)
	var y := clampi(int(uv.y * terrain_image.get_height()), 0, terrain_image.get_height() - 1)
	return terrain_image.get_pixel(x, y)

func _is_water(uv: Vector2, baseline: bool = false) -> bool:
	var river_distance := _river_distances_squared(uv)
	if river_distance.x <= YANGTZE_HALF_WIDTH * YANGTZE_HALF_WIDTH or river_distance.y <= GAN_HALF_WIDTH * GAN_HALF_WIDTH: return true
	if not baseline and Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv):
		var mask := shore_image.get_pixel(clampi(int(uv.x * shore_image.get_width()), 0, shore_image.get_width() - 1), clampi(int(uv.y * shore_image.get_height()), 0, shore_image.get_height() - 1))
		if mask.g > 0.0 and absf(_lake_offset()) > 0.01:
			return (mask.r - 0.5) * 128.0 <= _lake_offset() * mask.g
	var color := _terrain_color(uv)
	return color.b > color.g and color.g > color.r

func _is_shore(uv: Vector2) -> bool:
	var color := _terrain_color(uv)
	return color.r > 0.7 and color.r > color.g and color.g > color.b

func _is_land(uv: Vector2, baseline: bool = false) -> bool:
	if _in_river_corridor(uv, 0.025): return false
	if _is_water(uv, baseline): return false
	var color := _terrain_color(uv)
	return color.g > color.r and color.r > color.b

func _near_water(uv: Vector2, baseline: bool = false) -> bool:
	for offset in [Vector2(0.025, 0), Vector2(-0.025, 0), Vector2(0, 0.025), Vector2(0, -0.025),
			Vector2(0.038, 0.015), Vector2(-0.038, -0.015)]:
		if _is_water(uv + offset, baseline):
			return true
	return false

func _make_house_sites() -> void:
	_scenery_revision += 1
	# Sample land immediately beside water, then pick evenly spaced points all
	# around the actual shoreline. The choice is map-dependent, not RNG-dependent.
	var candidates: Array[Vector2] = []
	for y in range(20, 82):
		for x in range(23, 83):
			var uv := Vector2(float(x) / 100.0, float(y) / 100.0)
			if _is_land(uv) and _near_water(uv) and uv.distance_to(CREEPER_ANCHOR) > 0.11:
				candidates.append(uv)
	house_sites.clear()
	for target in HOUSE_RING_TARGETS:
		var nearest := Vector2(-1, -1)
		var best := INF
		for candidate in candidates:
			if candidate.distance_to(target) >= best:
				continue
			var clear := true
			for existing in house_sites:
				if candidate.distance_to(existing) < 0.053:
					clear = false
					break
			if clear:
				best = candidate.distance_to(target)
				nearest = candidate
		if nearest.x >= 0.0:
			house_sites.append(nearest)
	# Alternate sectors when community grows, so the first homes already
	# form a visible ring instead of filling one side of the lake first.
	var clockwise_sites := house_sites.duplicate()
	house_sites.clear()
	for index in [0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15]:
		if index < clockwise_sites.size():
			house_sites.append(clockwise_sites[index])
	house_progress.resize(house_sites.size())

## 唯一停车位，靠社区增长后出现的房屋外侧，采样确保落在陆地。
func _make_car_site() -> void:
	_scenery_revision += 1
	if house_sites.size() <= CAR_HOUSE_INDEX: return
	var home := house_sites[CAR_HOUSE_INDEX]
	var target := home + Vector2(0.038, 0.016)
	var best := INF
	for y in range(-5, 6):
		for x in range(-5, 6):
			var candidate := home + Vector2(x, y) * 0.01
			if not _is_land(candidate) or home.distance_to(candidate) < 0.035 or home.distance_to(candidate) > 0.06: continue
			var clear := true
			for other in house_sites:
				if other.distance_to(candidate) < 0.033: clear = false
			if clear and candidate.distance_to(target) < best:
				best = candidate.distance_to(target)
				car_site = candidate

func _community_car_visible() -> bool:
	return car_site != Vector2.ZERO and int(metrics.get("community", 0)) >= CAR_COMMUNITY_THRESHOLD and house_target_count > CAR_HOUSE_INDEX

func _draw_community_car(c: Control) -> void:
	if car_progress <= 0.01: return
	var p := _wildlife_point(car_site)
	var extent := CAR_EXTENT
	c.draw_texture_rect(_atlas_texture(COMMUNITY_CAR), Rect2((p - extent * Vector2(0.5, 0.88)).round(), extent), false, Color(1, 1, 1, car_progress))

func sync_community_targets() -> void:
	# 社区指数决定可见村落规模，使用全部环湖位置；不再由围垦强度决定栋数。
	house_target_count = _community_house_count()

func _community_house_count() -> int:
	return roundi(clampf(float(metrics.get("community", 0)), 0.0, 100.0) / 100.0 * house_sites.size())

func _accept_habitat(kind: String, uv: Vector2) -> bool:
	# Seeded placement uses the original geography, independent of the previous
	# run's animated water level. Movement uses the current, changing shoreline.
	match kind:
		"bird":
			return _is_water(uv, true) and _bird_boat_space(uv).length_squared() >= 1.2 * 1.2
		"submerged", "floating":
			return _is_water(uv, true)
		"emergent", "marsh":
			return _is_shore(uv) or (_is_land(uv, true) and _near_water(uv, true))
		"tree":
			return _is_land(uv, true) and _near_water(uv, true)
	return false

func _scatter_site(kind: String, placed: Array[Vector2]) -> Vector2:
	var zone := Rect2(0.27, 0.20, 0.53, 0.63)
	if kind == "bird" or kind == "floating" or kind == "submerged":
		zone = Rect2(0.30, 0.29, 0.47, 0.52)
	var spacing := 0.029 if kind == "tree" else 0.021
	for attempt in 250:
		var uv := zone.position + Vector2(visual_rng.randf(), visual_rng.randf()) * zone.size
		if not _accept_habitat(kind, uv):
			continue
		var clear := true
		for other in placed:
			if uv.distance_to(other) < spacing:
				clear = false
				break
		if clear:
			return uv
	# The fixed anchors are a fallback if a particular map region is crowded.
	if kind == "tree":
		return Vector2(0.80, 0.55 + 0.018 * placed.size())
	if kind == "bird" or kind == "floating" or kind == "submerged":
		for i in WATER_ANCHORS.size():
			var anchor := WATER_ANCHORS[(placed.size() + i) % WATER_ANCHORS.size()]
			if _accept_habitat(kind, anchor): return anchor
		return Vector2(0.43, 0.63)
	return SHORE_ANCHORS[placed.size() % SHORE_ANCHORS.size()]

func _reset_scenery() -> void:
	_scenery_revision += 1
	visual_seed = GameState.run_seed
	visual_rng.seed = int(GameState.run_seed) ^ 0x5EED5A7
	for i in house_progress.size():
		house_progress[i] = 1.0 if i < _community_house_count() else 0.0
	action_effects.clear()
	interests.clear()
	interest_cooldown = 0.0
	interest_captures = 0
	plant_sites.clear()
	for pid in GameState.PLANTS:
		var kind: String = GameState.PLANTS[pid]["kind"]
		var sites: Array[Vector2] = []
		for i in 14:
			sites.append(_scatter_site(kind, sites))
		plant_sites[pid] = sites
	bird_agents.clear()
	var homes: Array[Vector2] = []
	for sid in GameState.SPECIES:
		for i in 10:
			var home := _scatter_site("bird", homes)
			homes.append(home)
			bird_agents.append({"sid": sid, "slot": i, "home": home, "pos": home,
				"target": home, "state": 0, "timer": 1.0 + float(i % 5) * 0.6, "angle": 0.0})

func _visible_trees() -> Array:
	var sites: Array = plant_sites.get("chishan", [])
	var count := clampi(int(float(plants.get("chishan", 0)) / 7.0), 0, sites.size())
	return sites.slice(0, count)

## The obstacle follows the drawn lake boat, including its gentle lateral sway.
## Work in the unzoomed billboard plane, so camera zoom cannot change clearance.
func _bird_boat_space(uv: Vector2) -> Vector2:
	var offset := _shadow_projection.basis_xform(uv - BOAT_ANCHOR)
	return (offset - Vector2(round(sin(elapsed * 0.06) * 4), -14)) / BOAT_BIRD_CLEARANCE

func _bird_boat_uv(point: Vector2) -> Vector2:
	return BOAT_ANCHOR + _shadow_projection.affine_inverse().basis_xform(point * BOAT_BIRD_CLEARANCE + Vector2(round(sin(elapsed * 0.06) * 4), -14))

func _bird_water_segment_clear(a: Vector2, b: Vector2) -> bool:
	var nearest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, _bird_boat_space(a), _bird_boat_space(b))
	if nearest.length_squared() < 1.0: return false
	for fraction in [0.25, 0.5, 0.75, 1.0]:
		if not _is_water(a.lerp(b, fraction)): return false
	return true

func _bird_water_route(start: Vector2, target: Vector2) -> Array[Vector2]:
	var direct: Array[Vector2] = [target]
	if _bird_water_segment_clear(start, target): return direct
	var a := _bird_boat_space(start)
	var b := _bird_boat_space(target)
	if a.length_squared() < 1.0 or b.length_squared() < 1.0: return []
	var angle := wrapf(b.angle() - a.angle(), -PI, PI)
	for sweep in [angle, angle - TAU if angle > 0.0 else angle + TAU]:
		var route: Array[Vector2] = []
		var steps := maxi(1, ceili(absf(sweep) / (PI / 12.0)))
		var previous := start
		var clear := true
		for i in steps + 1:
			var point := _bird_boat_uv(Vector2.from_angle(a.angle() + sweep * float(i) / steps) * 1.2)
			if not _bird_water_segment_clear(previous, point):
				clear = false
				break
			route.append(point)
			previous = point
		if clear and _bird_water_segment_clear(previous, target):
			route.append(target)
			return route
	return []

func _bird_water_waypoint(bird: Dictionary, target: Vector2) -> Vector2:
	var basis: Vector2 = Vector2(_shadow_projection.x.length(), _shadow_projection.y.length())
	if bird.get("route_target", Vector2.INF) != target or bird.get("route_basis", Vector2.ZERO) != basis:
		bird["water_route"] = _bird_water_route(bird.pos, target)
		bird["route_target"] = target
		bird["route_basis"] = basis
	var route: Array = bird.get("water_route", [])
	while not route.is_empty() and bird.pos.distance_to(route[0]) < 0.001:
		route.pop_front()
	return bird.pos if route.is_empty() else route[0]

func _tree_perch_height(uv: Vector2) -> float:
	var amount := _tree_season_blend(uv)
	var texture: Texture2D = seasonal_trees[season]
	if amount < 1.0 and (season == 3 or (season == 0 and previous_season == 3)):
		texture = tree_frames[season][clampi(roundi(amount * 16), 0, 16)]
	var key := texture.get_instance_id()
	if not _perch_heights.has(key):
		var image := texture.get_image()
		if image.is_compressed(): image.decompress()
		var crown := 8
		for y in image.get_height():
			var occupied := false
			for x in range(16, 24):
				if image.get_pixel(x, y).a > 0.5: occupied = true
			if occupied:
				crown = y
				break
		_perch_heights[key] = 44.0 * 0.9 - crown - 1.0
	var index: int = plant_sites.get("chishan", []).find(uv)
	var growth := _visual_weight("plants", "chishan", index, 7.0) if index >= 0 else 1.0
	return float(_perch_heights[key]) * growth

func _bird_height(bird: Dictionary) -> float:
	var state := int(bird.state)
	if state == 4: return _tree_perch_height(bird.pos)
	if state not in [3, 5]: return 0.0
	var start: Vector2 = bird.get("flight_start", bird.home)
	var distance := maxf(0.001, start.distance_to(bird.target))
	var fraction := smoothstep(0.0, 1.0, 1.0 - bird.pos.distance_to(bird.target) / distance)
	var from_height := float(bird.get("flight_height", 6.0))
	var to_height := _tree_perch_height(bird.target) if state == 3 else 6.0
	return lerpf(from_height, to_height, fraction)

func _bird_count(sid: String) -> int:
	var count := _metric_bird_count(sid, metrics)
	if transition_age < transition_duration and transition_from.has("metrics"):
		count = maxi(count, _metric_bird_count(sid, transition_from["metrics"]))
	return count

## 候鸟总值映射到 0–50 只，轮流分配到五种鸟，避免逐物种取整放大误差。
func _metric_bird_count(sid: String, values: Dictionary) -> int:
	var species: Array = GameState.SPECIES.keys()
	var index := species.find(sid)
	if index < 0: return 0
	var total := roundi(clampf(float(values.get("birds", 0)), 0.0, 100.0) / 100.0 * species.size() * 10)
	return clampi(ceili(float(total - index) / species.size()), 0, 10)

func _bird_visibility(sid: String, slot: int) -> float:
	var target := 1.0 if slot < _metric_bird_count(sid, metrics) else 0.0
	if transition_age >= transition_duration or not transition_from.has("metrics"): return target
	var previous := 1.0 if slot < _metric_bird_count(sid, transition_from["metrics"]) else 0.0
	return lerpf(previous, target, smoothstep(0.0, 1.0, transition_age / transition_duration))

func _visual_count(bucket: String, key: String, divisor: float) -> int:
	var target: Dictionary = metrics if bucket == "metrics" else (plants if bucket == "plants" else populations)
	var count := int(float(target.get(key, 0)) / divisor)
	if transition_age < transition_duration and transition_from.has(bucket):
		count = maxi(count, int(float(transition_from[bucket].get(key, 0)) / divisor))
	return count

func _visual_weight(bucket: String, key: String, slot: int, divisor: float) -> float:
	var target: Dictionary = metrics if bucket == "metrics" else (plants if bucket == "plants" else populations)
	var to_weight := 1.0 if slot < int(float(target.get(key, 0)) / divisor) else 0.0
	if transition_age >= transition_duration or not transition_from.has(bucket): return to_weight
	var from_weight := 1.0 if slot < int(float(transition_from[bucket].get(key, 0)) / divisor) else 0.0
	return lerpf(from_weight, to_weight, smoothstep(0.0, 1.0, transition_age / transition_duration))

func _choose_bird_state(bird: Dictionary) -> void:
	var roll := visual_rng.randf()
	var trees := _visible_trees()
	var perch_chance := 0.12 + float(metrics.get("vegetation", 50)) / 100.0 * 0.25
	if not trees.is_empty() and roll < perch_chance:
		bird["state"] = 3 # Fly to a visible tree and rest there.
		bird["target"] = trees[visual_rng.randi_range(0, trees.size() - 1)]
		bird["flight_start"] = bird.pos
		bird["flight_height"] = 6.0
	elif roll < 0.60:
		bird["state"] = 0 # Stand in shallow water.
		bird["timer"] = visual_rng.randf_range(2.5, 5.0)
	elif roll < 0.78 and int(bird["state"]) != 1:
		bird["state"] = 1 # One gentle sip, followed by an upright pause.
		bird["timer"] = visual_rng.randf_range(2.2, 3.0)
	else:
		bird["state"] = 2 # Walk to a nearby water pixel.
		bird["timer"] = visual_rng.randf_range(2.0, 4.5)
		var home: Vector2 = bird["home"]
		bird["target"] = home
		for attempt in 20:
			var candidate := home + Vector2(visual_rng.randf_range(-0.045, 0.045), visual_rng.randf_range(-0.045, 0.045))
			if _is_water(candidate) and _bird_boat_space(candidate).length_squared() >= 1.0:
				bird["target"] = candidate
				break

func _process_birds(delta: float) -> void:
	for bird in bird_agents:
		if int(bird["slot"]) >= _bird_count(str(bird["sid"])):
			continue
		var state: int = bird["state"]
		var pos: Vector2 = bird["pos"]
		var target: Vector2 = bird["target"]
		bird["motion_response_age"] = minf(1.0, float(bird.get("motion_response_age", 1.0)) + delta)
		if _follow_interest(bird, delta):
			pass
		elif state == 3 or state == 5:
			var to_target := target - pos
			var step := 0.14 * delta
			if to_target.length() <= step:
				bird["pos"] = target
				bird["state"] = 4 if state == 3 else 0
				bird["timer"] = visual_rng.randf_range(6.0, 10.0) if state == 3 else 1.0
			else:
				bird["pos"] = pos + to_target.normalized() * step
				bird["angle"] = to_target.angle()
		elif state == 4:
			bird["timer"] = float(bird["timer"]) - delta
			if bird["timer"] <= 0.0 or _visible_trees().is_empty():
				bird["flight_start"] = bird.pos
				bird["flight_height"] = _tree_perch_height(bird.pos)
				bird["state"] = 5 # Fly back before walking or pecking again.
				bird["target"] = bird["home"]
		else:
			bird["timer"] = float(bird["timer"]) - delta
			if state == 2:
				var waypoint := _bird_water_waypoint(bird, target)
				var to_target := waypoint - pos
				var step := 0.018 * delta
				var next := pos.move_toward(waypoint, step)
				if _bird_water_segment_clear(pos, next): bird["pos"] = next
				else: bird.erase("route_target")
				if bird.pos.distance_to(target) < 0.001 or waypoint == pos:
					bird["state"] = 0
					bird["timer"] = visual_rng.randf_range(1.0, 3.0)
				elif to_target.length_squared() > 0.0:
					bird["angle"] = to_target.angle()
			if bird["timer"] <= 0.0:
				_choose_bird_state(bird)
		_update_bird_facing(bird, (bird["pos"] as Vector2) - pos, delta)
		var animation_state := int(bird.get("animation_state", 0))
		if animation_state != int(bird["state"]):
			bird["animation_previous_state"] = animation_state
			bird["animation_state"] = int(bird["state"])
			bird["animation_age"] = 0.0
		else:
			bird["animation_age"] = float(bird.get("animation_age", 0.0)) + delta

func _px(c: Control, p: Vector2, rect: Rect2, color: Color, scale_px: float = 2.0) -> void:
	c.draw_rect(Rect2(p + rect.position * scale_px, rect.size * scale_px), color)

func _build_river_routes() -> void:
	_route_lengths.clear()
	_river_distance_cache.clear()
	yangtze_route.assign(RiverRoutes.YANGTZE)
	gan_route.assign(RiverRoutes.GAN)
	# Carry the boundary tangents well past every supported window's view.
	var west := (yangtze_route[0] - yangtze_route[4]).normalized()
	var east := (yangtze_route[-1] - yangtze_route[-4]).normalized()
	yangtze_route.push_front(yangtze_route[0] + west * 2.5)
	yangtze_route.append(yangtze_route[-1] + east * 2.5)
	var south := (gan_route[0] - gan_route[5]).normalized()
	gan_route.push_front(gan_route[0] + south * 2.5)

func _near_route(uv: Vector2, route: Array[Vector2], radius: float) -> bool:
	for i in range(1, route.size()):
		var closest := Geometry2D.get_closest_point_to_segment(uv, route[i - 1], route[i])
		if uv.distance_squared_to(closest) <= radius * radius: return true
	return false

func _in_river_corridor(uv: Vector2, radius: float) -> bool:
	var distances := _river_distances_squared(uv)
	return minf(distances.x, distances.y) <= radius * radius

func _river_distances_squared(uv: Vector2) -> Vector2:
	# River geometry is fixed; only the animated lake mask changes with water
	# level. Cache exact distances, so every existing corridor radius still works.
	if _river_distance_cache.has(uv): return _river_distance_cache[uv]
	var distances := Vector2(INF, INF)
	for route_index in 2:
		var route: Array[Vector2] = yangtze_route if route_index == 0 else gan_route
		for i in range(1, route.size()):
			var closest := Geometry2D.get_closest_point_to_segment(uv, route[i - 1], route[i])
			distances[route_index] = minf(distances[route_index], uv.distance_squared_to(closest))
	# Bound memory when animated agents query new positions over a long session.
	if _river_distance_cache.size() >= 8192: _river_distance_cache.clear()
	_river_distance_cache[uv] = distances
	return distances

func _make_river_bank_material() -> ShaderMaterial:
	return _make_ground_material(true)

func _make_ground_material(bank: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("terrain_texture", LANDSCAPE)
	material.set_shader_parameter("exterior_mask", exterior_texture)
	material.set_shader_parameter("shore_distance", SHORE_DISTANCE)
	material.set_shader_parameter("river_bank", bank)
	material.set_shader_parameter("terrain_relief", not bank)
	material.set_shader_parameter("relief_height", relief_texture)
	material.set_shader_parameter("river_surface_mask", river_surface_texture)
	material.set_shader_parameter("ground_size", GROUND_SIZE)
	material.set_shader_parameter("bank_color", VisualTheme.SAND)
	material.set_shader_parameter("meadow_color", LAND_COLOR)
	# The artwork's base grass drives brightness on both sides of its boundary.
	material.set_shader_parameter("meadow_basis", Color("829666"))
	for entry in [["summer_meadow", VisualTheme.SUMMER_MEADOW], ["autumn_meadow", VisualTheme.AUTUMN_MEADOW],
		["snow_color", VisualTheme.SNOW], ["water_deep", VisualTheme.WATER_DEEP], ["water_mid", VisualTheme.WATER_MID],
		["water_shallow", VisualTheme.WATER_SHALLOW], ["sand_color", VisualTheme.SAND], ["soil_color", VisualTheme.SOIL]]:
		material.set_shader_parameter(entry[0], entry[1])
	return material

func _build_river_mesh(parent: Node3D, route: Array[Vector2], half_width: float) -> void:
	# Individual ground triangles handle tight river bends without intersecting
	# canvas polygons. Banks, shallows and water share the actual 3D camera.
	for band in 2:
		var width: float = half_width + [0.007, 0.0][band]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var lift := Vector3(0, 0.01 + band * 0.006, 0)
		for i in range(1, route.size()):
			var direction := (route[i] - route[i - 1]).normalized()
			var normal := Vector2(-direction.y, direction.x) * width
			var corners := [route[i - 1] - normal, route[i - 1] + normal, route[i] + normal, route[i] - normal]
			for corner in [0, 1, 2, 0, 2, 3]:
				surface.add_vertex(_ground_position(corners[corner]) + lift)
		# Round joins seal any gaps between neighboring segment banks.
		for uv in route:
			for k in 12:
				surface.add_vertex(_ground_position(uv) + lift)
				surface.add_vertex(_ground_position(uv + Vector2.from_angle(TAU * float(k) / 12.0) * width) + lift)
				surface.add_vertex(_ground_position(uv + Vector2.from_angle(TAU * float(k + 1) / 12.0) * width) + lift)
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		if band == 0:
			mesh.material_override = river_bank_material
		else:
			var material := _make_ground_material(false)
			material.set_shader_parameter("terrain_relief", false)
			material.set_shader_parameter("river_water", true)
			river_water_materials.append(material)
			mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mesh)

func _river_sample(route: Array[Vector2], phase: float) -> Dictionary:
	if route.size() < 2: return {"pos": route[0] if not route.is_empty() else Vector2.ZERO, "direction": Vector2.RIGHT}
	# Only built-in immutable routes are cached; arbitrary callers retain exact
	# sampling even when they edit their route in place.
	var key := "yangtze" if is_same(route, yangtze_route) else ("gan" if is_same(route, gan_route) else "")
	var lengths := PackedFloat64Array()
	if not key.is_empty() and _route_lengths.has(key):
		lengths = _route_lengths[key]
	else:
		lengths.append(0.0)
		for i in range(1, route.size()): lengths.append(lengths[-1] + route[i - 1].distance_to(route[i]))
		if not key.is_empty(): _route_lengths[key] = lengths
	var distance := fposmod(phase, 1.0) * lengths[-1]
	var low := 1
	var high := route.size() - 1
	while low < high:
		var mid := (low + high) / 2
		if lengths[mid] < distance: low = mid + 1
		else: high = mid
	return {"pos": route[low - 1].lerp(route[low], (distance - lengths[low - 1]) / maxf(lengths[low] - lengths[low - 1], 0.00001)),
		"direction": (route[low] - route[low - 1]).normalized()}

func _yangtze_boat_sample(index: int, time: float) -> Dictionary:
	var heading := 1.0 if index % 2 == 0 else -1.0
	var phase := time * RIVER_BOAT_SPEED * heading + float(index) / 10.0
	var sample := _river_sample(yangtze_route, phase)
	# Average across bends so lanes and facing do not snap at short OSM segments.
	var before: Vector2 = _river_sample(yangtze_route, phase - 0.001)["pos"]
	var after: Vector2 = _river_sample(yangtze_route, phase + 0.001)["pos"]
	var tangent := (after - before).normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	return {"pos": sample["pos"] + normal * RIVER_BOAT_LANE * heading, "heading": heading, "direction": tangent * heading}

func _river_boat_rotation(direction: Vector2, mirror: float) -> float:
	var artwork_forward := Vector2(FISHING_BOAT_FORWARD.x * mirror, FISHING_BOAT_FORWARD.y)
	return direction.angle() - artwork_forward.angle()

func _draw_fishing_boat(c: Control, p: Vector2, heading: float = 1.0, direction: Vector2 = Vector2.ZERO) -> void:
	if direction == Vector2.ZERO:
		c.draw_set_transform(p, 0.0, Vector2(heading, 1.0))
		_draw_sprite(c, Vector2.ZERO, 7, FISHING_BOAT_EXTENT)
	else:
		# Account for the artwork's diagonal bow; rotate around the hull, not its feet.
		var mirror := -heading
		c.draw_set_transform(p, _river_boat_rotation(direction, mirror), Vector2(mirror, 1.0))
		c.draw_texture_rect(_atlas_texture(sprites[7]), Rect2(-FISHING_BOAT_EXTENT * Vector2(0.5, 0.60), FISHING_BOAT_EXTENT), false)
	c.draw_set_transform(Vector2.ZERO)

func _draw_yangtze_boats(c: Control) -> void:
	for i in 10:
		var sample := _yangtze_boat_sample(i, elapsed)
		var p := _wildlife_point(sample["pos"])
		p.y += sin(elapsed * 0.65 + float(i)) * 0.6 if not reduced_motion else 0.0
		var direction := (_wildlife_point(sample["pos"] + sample["direction"] * 0.01) - _wildlife_point(sample["pos"])).normalized()
		_draw_fishing_boat(c, p, sample["heading"], direction)

func _build_meadow_scenery() -> void:
	_scenery_revision += 1
	# Original code-drawn pixel props: grass, flowers, shrubs, stones and pines.
	var palette := {"d": Color("456244"), "g": Color("668650"), "l": Color("9bb364"),
		"t": Color("73593e"), "r": Color("727b73"), "s": Color("a6ad97"),
		"w": Color("d8d6b5"), "f": Color("e2bc73"), "p": Color("d79196")}
	var patterns := [
		["........", "..l.....", "..g..l..", ".lg..g..", "..g.lg..", "..gdgd..", "...dd..."],
		["..p.....", ".pfp..w.", "..g..wfw", "..g...g.", ".lg..lg.", "..gd.g..", "...dd..."],
		["....ll....", "..llggll..", ".lggggggl.", "lgglgggggl", "gggggldggg", ".dggggggd.", "..dddddd.."],
		["..........", "...ssss...", "..swwsss..", ".sssssrsr.", ".srrsrrrr.", "..rrrrrr..", "...dddd..."],
		[".....l.....", "....lgl....", "....ggg....", "...lgggl...", "..lgggggl..", "...ggdgg...", "..lgggggl..", ".lgggggggl.", "..gggdggg..", ".lgggggggl.", "ggggdgggdgg", ".ddddddddd.", "....ttt....", "....ttt...."]
	]
	for rows in patterns:
		var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y in rows.size():
			for x in rows[y].length():
				if palette.has(rows[y][x]): image.set_pixel(x, y, palette[rows[y][x]])
		prop_textures.append(ImageTexture.create_from_image(image))
	pine_seasons = preload("res://scripts/seasonal_tree_art.gd").build_pine(prop_textures[4].get_image())
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261002
	for y in range(-12, 33):
		for x in range(-12, 33):
			if rng.randf() > 0.36: continue
			var uv := Vector2(x, y) * 0.055 + Vector2(rng.randf_range(-0.018, 0.018), rng.randf_range(-0.018, 0.018))
			if not _is_land(uv) or _in_river_corridor(uv, 0.04) or uv.distance_to(CREEPER_ANCHOR) < 0.15: continue
			var clear := true
			for site in house_sites:
				if uv.distance_to(site) < 0.06: clear = false; break
			if not clear: continue
			var roll := rng.randf()
			var kind := 5 if roll < 0.06 else (4 if roll < 0.15 else (3 if roll < 0.31 else (2 if roll < 0.51 else (1 if roll < 0.68 else 0))))
			scenery_props.append({"pos": uv, "kind": kind, "scale": rng.randf_range(1.9, 3.0)})
	scenery_props.sort_custom(func(a: Dictionary, b: Dictionary): return a["pos"].x + a["pos"].y < b["pos"].x + b["pos"].y)

func _scenery_draw_order() -> Array[Dictionary]:
	var key: Array = [_scenery_revision,
		displayed_plants.duplicate(), displayed_islands, _lake_offset(), season, previous_season, season_progress,
		size if season_progress < 1.0 else Vector2.ZERO,
		_screen_projection if season_progress < 1.0 else Transform2D.IDENTITY]
	if key != _static_key:
		_static_key = key
		_static_items = _build_static_scenery()
	var moving: Array[Dictionary] = []
	for bird in bird_agents:
		if int(bird["slot"]) < _bird_count(str(bird["sid"])) and not int(bird["state"]) in [3, 5]:
			moving.append({"kind": "bird", "uv": bird["pos"], "bird": bird})
	moving.append({"kind": "boat", "uv": BOAT_ANCHOR})
	for i in moving.size():
		moving[i]["depth"] = _scenery_depth(moving[i]["uv"])
		moving[i]["order"] = _static_items.size() + i
	moving.sort_custom(_scenery_before)
	# Copy the fixed list in native code; insert the small moving population by
	# binary search instead of traversing hundreds of static items in GDScript
	# every frame. The same comparator preserves ties and occlusion order.
	var items: Array[Dictionary] = _static_items.duplicate()
	for item in moving:
		items.insert(items.bsearch_custom(item, _scenery_before), item)
	return items

func _scenery_depth(uv: Vector2) -> float:
	# Positive orthographic zoom and vertical pan preserve depth ordering.
	# Use camera-independent depth to avoid resorting static scenery mid-tween.
	return uv.x * sin(VIEW_AZIMUTH) + uv.y * cos(VIEW_AZIMUTH) - _relief_at(uv) / GROUND_SIZE / tan(VIEW_PITCH)

func _scenery_before(a: Dictionary, b: Dictionary) -> bool:
	return int(a["order"]) < int(b["order"]) if float(a["depth"]) == float(b["depth"]) else float(a["depth"]) < float(b["depth"])

func _build_static_scenery() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for prop in scenery_props:
		if not _is_water(prop["pos"]): items.append({"kind": "prop", "uv": prop["pos"], "prop": prop})
	if season in [0, 1] or (season_progress < 1.0 and previous_season in [0, 1]):
		for uv in summer_flowers:
			if _is_exterior_land(uv) and _flower_amount_at(uv) > 0.01: items.append({"kind": "flower", "uv": uv})
	for uv in EDGE_TREE_TARGETS:
		var clear := uv.distance_to(CREEPER_ANCHOR) > 0.13
		for home in house_sites:
			if uv.distance_to(home) < 0.065: clear = false; break
		if clear and _is_land(uv): items.append({"kind": "tree", "uv": uv})
	for pid in GameState.PLANTS:
		var sites: Array = plant_sites.get(pid, [])
		for i in mini(_visual_count("plants", str(pid), 7.0), sites.size()):
			var growth := _visual_weight("plants", str(pid), i, 7.0)
			if growth > 0.001: items.append({"kind": "plant", "uv": sites[i], "pid": str(pid), "growth": growth})
	for i in mini(ISLAND_ANCHORS.size(), ceili(displayed_islands)):
		items.append({"kind": "island", "uv": ISLAND_ANCHORS[i], "index": i})
	for i in house_sites.size(): items.append({"kind": "house", "uv": house_sites[i], "index": i})
	if car_site != Vector2.ZERO: items.append({"kind": "community_car", "uv": car_site})
	for i in items.size():
		items[i]["depth"] = _scenery_depth(items[i]["uv"])
		items[i]["order"] = i
	items.sort_custom(_scenery_before)
	return items

func _draw_wildlife(c: Control) -> void:
	# In local camera coordinates, 96 px covers the largest sprite plus its
	# seasonal leaves/sway. Offscreen items keep simulating and depth order.
	var visible_rect: Rect2 = (c.get_global_transform().affine_inverse() * get_viewport_rect()).grow(96.0)
	_draw_yangtze_boats(c)
	for i in 28:
		var uv: Vector2 = WATER_ANCHORS[i % WATER_ANCHORS.size()]
		if not _is_water(uv): continue
		var p := _wildlife_point(uv)
		var alpha := 0.10 + 0.13 * (sin(elapsed * 1.5 + i * 2.0) + 1.0)
		c.draw_rect(Rect2(p, Vector2(8 + i % 4 * 3, 2)), Color(0.77, 0.94, 0.83, alpha))
	for i in mini(12, _visual_count("metrics", "fish", 12.0)):
		var uv: Vector2 = WATER_ANCHORS[i % WATER_ANCHORS.size()]
		if not _is_water(uv): continue
		var p := _wildlife_point(uv)
		p.x += round(sin(elapsed * 0.35 + i) * 4)
		_draw_sprite(c, p, 3, Vector2(15, 24), Color(0.6, 0.85, 0.8, 0.45 * _visual_weight("metrics", "fish", i, 12.0)))
	for item in _render_items:
		var p := _wildlife_point(item["uv"])
		if not visible_rect.has_point(p): continue
		match str(item["kind"]):
			"prop":
				var prop: Dictionary = item["prop"]
				if prop["kind"] == 5: _draw_tree(c, p, float(prop["scale"]) * 0.55, item["uv"])
				else:
					var texture: Texture2D = prop_textures[prop["kind"]]
					if prop["kind"] == 4: texture = pine_seasons[season]
					var extent := texture.get_size() * float(prop["scale"])
					var rect := Rect2((p - extent * Vector2(0.5, 0.9)).round(), extent.round())
					if prop["kind"] == 4:
						var amount := _tree_season_blend(item["uv"])
						c.draw_texture_rect(_atlas_texture(pine_seasons[previous_season]), rect, false)
						c.draw_texture_rect(_atlas_texture(texture), rect, false, Color(1, 1, 1, amount))
					else: c.draw_texture_rect(_atlas_texture(texture), rect, false, _season_prop_tint(item["uv"]))
			"flower": _draw_summer_flower(c, p, item["uv"])
			"tree": _draw_tree(c, p, 0.78, item["uv"])
			"plant": _draw_plant(c, p, str(item["pid"]), float(item["growth"]), item["uv"])
			"island": _draw_island(c, int(item["index"]))
			"house": _draw_house(c, int(item["index"]))
			"community_car": _draw_community_car(c)
			"bird": _draw_bird_actor(c, item["bird"])
			"boat":
				p.x += round(sin(elapsed * 0.06) * 4)
				_draw_fishing_boat(c, p)
	# Flying birds occupy the air layer; walking/feeding birds obey ground depth.
	for bird in bird_agents:
		if int(bird["slot"]) < _bird_count(str(bird["sid"])) and int(bird["state"]) in [3, 5]: _draw_bird_actor(c, bird)
	_draw_action_effects(c)

func _draw_plant(c: Control, p: Vector2, pid: String, growth: float, uv: Vector2 = Vector2.INF) -> void:
	c.draw_set_transform(p, 0.0, Vector2.ONE * growth)
	match pid:
		"lian": c.draw_texture_rect(_atlas_texture(bird_sprites[5]), Rect2(Vector2(-19, -21), Vector2(38, 38)), false)
		"luwei": _draw_sprite(c, Vector2.ZERO, 4, Vector2(36, 48))
		"chishan": _draw_tree(c, Vector2.ZERO, 1.0, uv)
		"kucao":
			c.draw_line(Vector2(-4, 3), Vector2(-1, -4), Color("7aa980"), 2, false)
			c.draw_line(Vector2(3, 3), Vector2(1, -5), Color("89b68c"), 2, false)
		_: _draw_marsh(c, Vector2.ZERO, pid)
	c.draw_set_transform(Vector2.ZERO)

func _draw_island(c: Control, i: int) -> void:
	var p := _wildlife_point(ISLAND_ANCHORS[i])
	var growth := clampf(displayed_islands - float(i), 0.0, 1.0)
	p.y += round(sin(elapsed + i) * 1.0)
	if growth < 0.99: c.draw_arc(p, 9 + (1.0 - growth) * 15, 0, TAU, 16, Color(0.72, 0.93, 0.98, 1.0 - growth), 2.0)
	var extent := Vector2(48, 48) * maxf(0.08, growth)
	p.y += (1.0 - growth) * 14.0
	c.draw_texture_rect(_atlas_texture(FLOATING_ISLAND), Rect2((p - extent * Vector2(0.5, 0.65)).round(), extent), false, Color(1, 1, 1, growth))

func _draw_action_effects(c: Control) -> void:
	for interest in interests:
		var age: float = interest.age
		var p := _wildlife_point(interest.pos)
		var alpha := maxf(0.0, 1.0 - age / 4.0) * 0.55
		c.draw_arc(p, 5.0 + minf(age, 1.0) * 14.0, 0, TAU, 24, Color(0.73, 0.94, 1.0, alpha), 1.0, false)
		if age < 0.6: c.draw_arc(p, 3.0 + age * 30.0, 0, TAU, 24, Color(0.78, 0.94, 0.62, alpha), 1.0, false)
	for effect in action_effects:
		var phase := float(effect.age) / float(effect.duration)
		var alpha := sin(phase * PI) * 0.8
		var card_id := str(effect.card)
		var anchor := BOAT_ANCHOR + Vector2(0.06 * float(effect.slot), -0.06)
		var p := _wildlife_point(anchor)
		if card_id in ["patrol", "guard_team", "smart_patrol", "research", "water_monitor"]:
			c.draw_arc(p, 10 + phase * 45, 0, TAU, 32, Color(0.78, 0.94, 0.62, alpha), 2.0)
			if card_id in ["patrol", "guard_team", "smart_patrol"]:
				_draw_sprite(c, p + Vector2((phase - 0.5) * 65, 0), 7, Vector2(30, 32), Color(1, 1, 1, alpha))
		else:
			var card := GameState.card_by_id(card_id)
			var water_action := false
			for e in card.get("tiers", {}).get("effective", {}).get("effects", []):
				if e.get("metric") == "water_level" or e.get("metric") == "water_quality": water_action = true
			if water_action:
				for i in 3:
					var wave := _wildlife_point(WATER_ANCHORS[(int(effect.slot) * 3 + i * 2) % WATER_ANCHORS.size()])
					c.draw_arc(wave, 6 + phase * 35, 0, TAU, 24, Color(0.73, 0.94, 1.0, alpha), 2.0)

## 量一遍每栋房子贴图的不透明外形：半宽、脚点、视觉高度（都是 76px 方框里的像素单位）。
## half_w / height 用于给上面那张参数表定值和复核露出比例，绘制只用 bottom。
func _measure_house_art() -> void:
	var unit := HOUSE_BOX / 128.0
	house_art_shape.clear()
	for art in HOUSE_ART:
		var bbox: Rect2i = art.get_image().get_used_rect()
		house_art_shape.append({
			"half_w": bbox.size.x * unit * 0.5,
			"bottom": bbox.end.y * unit - HOUSE_BOX * HOUSE_ANCHOR_Y,
			"height": bbox.size.y * unit,
		})

func _house_shape(art_index: int) -> Dictionary:
	if house_art_shape.is_empty():
		_measure_house_art()
	return house_art_shape[art_index % house_art_shape.size()]

## 76px 房框里的像素长度 → 地图 uv 长度。屏幕像素与 uv 的比例由当前相机决定
## （菜单拉远 / 对局推近时会变，所以每次都现算，不写死）。
func _px_to_uv(px: float) -> float:
	var px_per_uv := _shadow_projection.x.length()
	if px_per_uv <= 0.0001:
		return 0.0
	return px / px_per_uv

## 影子的顶点不能走 _wildlife_point —— 那函数里的两次 round() 是为了让贴图/物件像素对齐，
## 拿来连多边形会把每个顶点都吸到整数格，半径一大就显出锯齿和棱角（看起来"崩"）。这里保留浮点。
func _shadow_point(uv: Vector2) -> Vector2:
	return _shadow_projection * uv + _overlay_inverse.basis_xform(_relief_screen_offset(uv))

## 立着的东西要在地面上留下压扁的影子，"立"才读得出来。
## 正交相机下，地面上的圆投影到屏幕是个椭圆（长轴方向由相机方位角决定），
## 所以不写死屏幕轴向 —— 把一圈地图坐标投影出来连成多边形，方位角 / 俯角 / 缩放全都自动对上。
func _shadow_polygon(uv: Vector2, radius_uv: float, segments: int = 40) -> PackedVector2Array:
	if not _shadow_unit_rings.has(segments):
		var ring := PackedVector2Array()
		for k in segments:
			var a := TAU * float(k) / float(segments)
			ring.append(Vector2(cos(a), sin(a) * SHADOW_FLATTEN))
		_shadow_unit_rings[segments] = ring
	var unit_ring: PackedVector2Array = _shadow_unit_rings[segments]
	var center := _shadow_point(uv)
	var axis_x := _shadow_projection.x * radius_uv
	var axis_y := _shadow_projection.y * radius_uv
	# Native packed-array transform avoids a GDScript call for every vertex.
	return Transform2D(axis_x, axis_y, center) * unit_ring

## foot = 影子中心相对落点再往下推多少像素（贴图底边 ≠ 落点，影子要比脚点再低一点才露得出来）。
func _draw_shadow(c: Control, uv: Vector2, radius_uv: float, alpha: float = 0.22, foot: float = 0.0, kind: String = "building") -> void:
	if not SHADOWS.get(kind, false):
		return
	if radius_uv <= 0.0:
		return
	var pixel_radius := _shadow_point(uv + Vector2(radius_uv, 0)).distance_to(_shadow_point(uv))
	# Very small growth/fade decals collapse below the polygon triangulator's
	# precision. Fade them in only after they have a visible pixel footprint.
	if pixel_radius < 1.0: return
	alpha *= clampf((pixel_radius - 1.0) / 3.0, 0.0, 1.0)
	# Keep the center on the sprite's snapped foot, while preserving continuous
	# radii. Three faint bands give a soft contact edge without a blur dependency.
	var center_offset := _wildlife_point(uv) - _shadow_point(uv) + Vector2(0.0, foot)
	for band in [[1.05, 0.18], [0.90, 0.32], [0.70, 0.45]]:
		var pts := _shadow_polygon(uv, radius_uv * float(band[0]))
		pts = Transform2D(0.0, center_offset) * pts
		c.draw_colored_polygon(pts, Color(0.08, 0.13, 0.11, alpha * float(band[1])))

func _contact_shadow_specs(items: Array[Dictionary] = []) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	if items.is_empty(): items = _scenery_draw_order()
	for item in items:
		var radius := 0.0
		var foot := 0.0
		var alpha := 0.20
		var kind := "tree"
		match str(item["kind"]):
			"prop":
				if int(item["prop"]["kind"]) != 5: continue
				var scale_factor := float(item["prop"]["scale"]) * 0.55
				radius = TREE_SHADOW_RADIUS * scale_factor
				foot = TREE_SHADOW_FOOT * scale_factor
			"tree":
				radius = TREE_SHADOW_RADIUS * 0.78
				foot = TREE_SHADOW_FOOT * 0.78
			"plant":
				if item["pid"] != "chishan": continue
				radius = TREE_SHADOW_RADIUS * float(item["growth"])
				foot = TREE_SHADOW_FOOT * float(item["growth"])
			"house":
				kind = "building"
				var index := int(item["index"])
				var phase: float = house_progress[index]
				if phase <= 0.01:
					radius = PLOT_SHADOW_RADIUS * 0.65
					foot = PLOT_SHADOW_FOOT
					alpha = 0.12
				else:
					var sc := maxf(0.12, phase * phase * (3.0 - 2.0 * phase))
					var art_index := index % HOUSE_ART.size()
					var shape := _house_shape(art_index)
					radius = minf(float(HOUSE_SHADOW_RADIUS[art_index]), float(shape["half_w"]) * 1.12) * sc
					foot = (float(shape["bottom"]) + float(HOUSE_SHADOW_FOOT[art_index]) * 0.5) * sc
					alpha = 0.25
			_: continue
		if not _is_water(item["uv"]): specs.append({"uv": item["uv"], "radius": radius, "foot": foot, "alpha": alpha, "kind": kind})
	return specs

func _draw_contact_shadows(c: Control) -> void:
	# The same translucent polygons, in the same order, share one mesh draw.
	# Rebuild only when the existing shadow invalidation requests a redraw.
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for spec in _render_shadow_specs:
		if not SHADOWS.get(str(spec.kind), false): continue
		var uv: Vector2 = spec.uv
		var radius := _px_to_uv(float(spec.radius))
		if radius <= 0.0: continue
		var pixel_radius := _shadow_point(uv + Vector2(radius, 0)).distance_to(_shadow_point(uv))
		if pixel_radius < 1.0: continue
		var alpha := float(spec.alpha) * clampf((pixel_radius - 1.0) / 3.0, 0.0, 1.0)
		var offset := _wildlife_point(uv) - _shadow_point(uv) + Vector2(0.0, float(spec.foot))
		for band in [[1.05, 0.18], [0.90, 0.32], [0.70, 0.45]]:
			var points := Transform2D(0.0, offset) * _shadow_polygon(uv, radius * float(band[0]))
			var start := vertices.size()
			vertices.append_array(points)
			var color := Color(0.08, 0.13, 0.11, alpha * float(band[1]))
			for point in points: colors.append(color)
			for i in range(1, points.size() - 1):
				indices.append_array(PackedInt32Array([start, start + i, start + i + 1]))
	if vertices.is_empty(): return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	# Canvas draw commands hold a RID, not a Resource reference. Each canvas
	# retains its own mesh until its next redraw or destruction.
	c.set_meta("contact_shadow_mesh", mesh)
	c.draw_mesh(mesh, null)

func _draw_houses(c: Control) -> void:
	for i in house_sites.size(): _draw_house(c, i)

func _draw_house(c: Control, i: int) -> void:
	var lit := roundi(float(metrics.get("community", 50)) / 100.0 * float(house_target_count))
	var uv: Vector2 = house_sites[i]
	var p := _wildlife_point(uv)
	var phase: float = house_progress[i]
	# 空地：村子还没盖到这里，只有一个芦苇标记。它看着就是一株草本植物，所以影子也只能按
	# 草本给小的 —— 挂一整块建筑月牙，看起来就是"草丛带着一个大影子"。
	if phase <= 0.01:
		_draw_sprite(c, p, 4, Vector2(30, 40))
		return
	var eased := phase * phase * (3.0 - 2.0 * phase)
	var sc := maxf(0.12, eased)
	var art_index := i % HOUSE_ART.size()
	if phase < 0.99:
		# Foundation and scaffold make both construction and wetland retreat legible.
		c.draw_rect(Rect2(p + Vector2(-19, -7), Vector2(38, 8)), Color("6f6949"))
		c.draw_rect(Rect2(p + Vector2(-20, -8), Vector2(3, 19)), Color("bca173"))
		c.draw_rect(Rect2(p + Vector2(17, -8), Vector2(3, 19)), Color("bca173"))
		for dust in 4:
			var offset := Vector2(-23 + dust * 13, -12 - int(elapsed * 15.0 + float(i + dust)) % 8)
			c.draw_rect(Rect2((p + offset).round(), Vector2(3, 3)), Color("e4ce9b"))
	var extent := Vector2(HOUSE_BOX, HOUSE_BOX) * sc
	var tint := Color.WHITE if i < lit else Color(0.66, 0.63, 0.56)
	c.draw_texture_rect(_atlas_texture(HOUSE_ART[art_index]), Rect2((p - extent * Vector2(0.5, HOUSE_ANCHOR_Y)).round(), extent.round()), false, tint)
	if phase < 0.22 and i >= house_target_count:
		_draw_sprite(c, p + Vector2(7, 0), 4, Vector2(16, 23))


func _tree_season_blend(uv: Vector2) -> float:
	if reduced_motion or uv == Vector2.INF: return 1.0
	var delay := clampf(_point(uv).y / maxf(size.y, 1.0), 0.0, 1.0) * SEASON_CHANGE_DURATION
	return clampf((tree_season_age - delay) / 1.8, 0.0, 1.0)

func _draw_tree(c: Control, p: Vector2, scale_factor: float = 1.0, _uv: Vector2 = Vector2.INF) -> void:
	# GroundShadows renders its contact decal below every upright sprite.
	var extent := Vector2(40, 44) * scale_factor
	var rect := Rect2((p - extent * Vector2(0.5, 0.9)).round(), extent.round())
	var amount := _tree_season_blend(_uv)
	if amount >= 1.0 or previous_season == season:
		c.draw_texture_rect(_atlas_texture(seasonal_trees[season]), rect, false)
	elif season == 0 and previous_season == 3:
		# Fixed leaf-cluster masks grow real opaque leaves instead of fading a crown.
		c.draw_texture_rect(_atlas_texture(tree_frames[0][clampi(roundi(amount * 16), 0, 16)]), rect, false)
	elif season == 3:
		c.draw_texture_rect(_atlas_texture(tree_frames[3][clampi(roundi(amount * 16), 0, 16)]), rect, false)
		if not reduced_motion and amount > 0.02 and amount < 0.98:
			for i in 6:
				var fall := fposmod(amount * 1.7 + float(i) / 6.0, 1.0)
				var leaf := p + Vector2((float(i) - 2.5) * 5.0 + sin(fall * TAU + i) * 4.0, -28.0 + fall * 31.0) * scale_factor
				var world_leaf := leaf if _uv == Vector2.INF else _wildlife_point(_uv) + leaf - p
				if not _creeper_weather_exclusion().has_point(world_leaf):
					c.draw_rect(Rect2(leaf.round(), Vector2(2, 2) * scale_factor), Color("dbb074", 1.0 - fall))
	else:
		c.draw_texture_rect(_atlas_texture(seasonal_trees[previous_season]), rect, false)
		c.draw_texture_rect(_atlas_texture(seasonal_trees[season]), rect, false, Color(1, 1, 1, amount))

func _draw_marsh(c: Control, p: Vector2, pid: String) -> void:
	var color := Color("a8b86a") if pid == "lihao" else Color("81a26d")
	c.draw_rect(Rect2(p + Vector2(-5, -2), Vector2(3, 8)), color)
	c.draw_rect(Rect2(p + Vector2(0, -5), Vector2(3, 10)), color)
	c.draw_rect(Rect2(p + Vector2(5, -1), Vector2(3, 7)), color)

func _draw_sprite(c: Control, p: Vector2, index: int, extent: Vector2, tint: Color = Color.WHITE) -> void:
	c.draw_texture_rect(_atlas_texture(sprites[index]), Rect2((p - extent * Vector2(0.5, 0.85)).round(), extent), false, tint)

func _bird_animation_frame(bird: Dictionary) -> int:
	var state: int = bird["state"]
	if state == 4: return 13
	var response_age := float(bird.get("motion_response_age", 1.0))
	if not reduced_motion and response_age < 5.0 / 11.0:
		# toy-flipbook: one fully visible atlas frame, held at 11 Hz, no dissolve.
		return [0, 6, 6, 0, 0][mini(4, floori(response_age * 11.0))]
	var age := float(bird.get("animation_age", 0.0))
	var previous := int(bird.get("animation_previous_state", 0))
	if not reduced_motion and age < 0.18:
		if state == 3 or state == 5: return 14 # Takeoff before wingbeat loop.
		if previous == 3 or previous == 5: return 15 # Feet-down landing.
	var tick := int(age * 7.0 + float(bird.get("slot", 0))) if not reduced_motion else 0
	match state:
		1:
			# Hold the shallower bend; omit the deep peck and exaggerated lift.
			# No loop: the remaining state duration is an upright drinking pause.
			if reduced_motion: return 0
			return 6 if age >= 0.45 and age < 1.25 else 0
		2: return 2 + tick % 4 # Four-step walking loop.
		3, 5: return 9 + tick % 4 # Four-phase wingbeat.
		4: return 13 # Folded wings while resting.
	return int(age * 2.0) % 2 if not reduced_motion else 0

func _bird_frame_region(species: int, frame: int) -> Rect2:
	var tile := Vector2(BIRD_ACTIONS[species].get_size()) / BIRD_ATLAS_GRID
	return Rect2(Vector2(frame % 4, floori(float(frame) / 4.0)) * tile, tile)

func _draw_bird_actor(c: Control, bird: Dictionary) -> void:
	var visibility := _bird_visibility(str(bird["sid"]), int(bird["slot"]))
	if visibility <= 0.001: return
	var sprite_index: int = SPECIES_ART.get(str(bird["sid"]), 0)
	var state: int = bird["state"]
	var p := _wildlife_point(bird["pos"])
	var response_age := float(bird.get("motion_response_age", 1.0))
	if not reduced_motion and response_age < 0.55:
		var response_alpha := (1.0 - response_age / 0.55) * visibility
		c.draw_arc(p + Vector2(0, -8), 5.0 + response_age * 8.0, -PI * 0.85, -PI * 0.15, 8, Color(0.78, 0.94, 0.62, response_alpha), 1.5, false)
	var frame := _bird_animation_frame(bird)
	p.y -= _bird_height(bird)
	var extent := (Vector2(46, 46) if sprite_index != 2 else Vector2(50, 50)) * BIRD_DISPLAY_SCALE
	if state == 3 or state == 5:
		extent *= 1.2
	var region := _bird_frame_region(sprite_index, frame)
	var anchor := Vector2(0.5, 0.875)
	if state == 4:
		# Crop the lower leg area without stretching the retained head/body pixels.
		region.size.y = floor(region.size.y * BIRD_PERCH_BODY[sprite_index])
		extent.y *= region.size.y / _bird_frame_region(sprite_index, frame).size.y
		anchor.y = 1.0
	# Billboard sprites remain upright: only mirror horizontally, never rotate.
	# Anchor the feet to the habitat point instead of the middle of the body.
	c.draw_set_transform(p, 0.0, Vector2(_bird_facing(bird), 1.0))
	c.draw_texture_rect_region(_atlas_texture(BIRD_ACTIONS[sprite_index]), Rect2(-extent * anchor, extent), region, Color(1, 1, 1, visibility))
	c.draw_set_transform(Vector2.ZERO)

## Flood-fill from the map edges: isolated lake islands stay outside this mask.
func _build_exterior_seasons() -> void:
	_scenery_revision += 1
	const N := 256
	exterior_image = Image.create(N, N, false, Image.FORMAT_R8)
	var open := PackedByteArray()
	open.resize(N * N)
	for y in N:
		for x in N:
			var col := _terrain_color(Vector2(x + 0.5, y + 0.5) / N)
			open[y * N + x] = 0 if col.b > col.g and col.g > col.r else 1
	var queue := PackedInt32Array()
	for y in N:
		for x in N:
			if (x == 0 or y == 0 or x == N - 1 or y == N - 1) and open[y * N + x] == 1:
				open[y * N + x] = 2
				queue.append(y * N + x)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var x := index % N
		var y := int(index / N)
		exterior_image.set_pixel(x, y, Color.WHITE)
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var next: Vector2i = Vector2i(x, y) + offset
			if next.x < 0 or next.y < 0 or next.x >= N or next.y >= N: continue
			var ni: int = next.y * N + next.x
			if open[ni] == 1:
				open[ni] = 2
				queue.append(ni)
	exterior_texture = ImageTexture.create_from_image(exterior_image)
	tree_frames = preload("res://scripts/seasonal_tree_art.gd").build(SHORE_TREE.get_image())
	for target_season in 4:
		seasonal_trees.append(tree_frames[target_season][16])
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261014
	for i in 1800:
		var uv := Vector2(rng.randf_range(-0.3, 1.3), rng.randf_range(-0.3, 1.3))
		if not _is_exterior_land(uv) or _season_near_water(uv, 0.035) or uv.distance_to(CREEPER_ANCHOR) < 0.15: continue
		var clear := true
		for home in house_sites:
			if uv.distance_to(home) < 0.055: clear = false; break
		if not clear: continue
		if i % 3 == 0: summer_flowers.append(uv)
		snow_sites.append(uv)

func _is_exterior_land(uv: Vector2) -> bool:
	if exterior_image == null or not _is_land(uv): return false
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0: return true
	var pixel := Vector2i((uv.clamp(Vector2.ZERO, Vector2.ONE) * 255).round())
	return exterior_image.get_pixelv(pixel).r > 0.5

func _season_prop_tint(uv: Vector2) -> Color:
	if not _is_exterior_land(uv): return Color.WHITE
	var colors := [Color.WHITE, Color(0.98, 1.04, 0.94), Color(1.40, 1.10, 0.77), Color(1.14, 1.20, 1.20)]
	return colors[previous_season].lerp(colors[season], _season_blend_at(uv))

func _draw_summer_flower(c: Control, p: Vector2, uv: Vector2) -> void:
	var index := int(abs(uv.x * 1307 + uv.y * 791))
	var amount := _flower_amount_at(uv)
	if amount <= 0.01: return
	var sway := 0.0 if reduced_motion else sin(elapsed * 1.4 + index) * 0.035
	c.draw_set_transform(p, sway, Vector2.ONE * maxf(0.08, amount))
	var color: Color = [Color("f5a3ba"), Color("fff0a6"), Color("cdb0ef"), Color("fdf4e5")][index % 4]
	color.a = smoothstep(0.0, 0.35, amount)
	for offset in [Vector2(-5, 0), Vector2(3, -4), Vector2(6, 2)]:
		var stem: Vector2 = offset
		c.draw_rect(Rect2(stem, Vector2(2, 5)), Color("547d43"))
		c.draw_rect(Rect2(stem + Vector2(-2, -3), Vector2(6, 2)), color)
		c.draw_rect(Rect2(stem + Vector2(0, -5), Vector2(2, 6)), color)
		c.draw_rect(Rect2(stem + Vector2(0, -3), Vector2(2, 2)), Color("e6b856"))
	c.draw_set_transform(Vector2.ZERO)

func _creeper_weather_exclusion() -> Rect2:
	var bounds := creeper_mesh.get_aabb()
	var rect := Rect2(map_camera.unproject_position(creeper_mesh.to_global(bounds.get_endpoint(0))), Vector2.ZERO)
	for i in range(1, 8): rect = rect.expand(map_camera.unproject_position(creeper_mesh.to_global(bounds.get_endpoint(i))))
	return rect.grow(12.0)

func _weather_weight(kind: String, season_index: int) -> float:
	if kind == "snow": return 1.0 if season_index == 3 else 0.0
	if kind == "leaf": return 1.0 if season_index == 2 else 0.0
	return 0.65 if season_index == 0 else (0.30 if season_index == 1 else 0.0)

func _season_particle_specs() -> Array[Dictionary]:
	var particles: Array[Dictionary] = []
	if reduced_motion: return particles
	var exclusion := _creeper_weather_exclusion()
	# Fixed screen-space seeds cover every aspect ratio without gameplay RNG.
	for channel in [["snow", 150, 0.11, 0.012], ["leaf", 48, 0.065, 0.024], ["petal", 32, 0.075, 0.018]]:
		var kind: String = channel[0]
		if _weather_weight(kind, previous_season) == 0.0 and _weather_weight(kind, season) == 0.0:
			continue
		for i in int(channel[1]):
			var phase := float(i) + (13.0 if kind == "leaf" else (29.0 if kind == "petal" else 0.0))
			var normalized := Vector2(fposmod(phase * 0.754877 + elapsed * float(channel[3]) + sin(elapsed * 0.65 + phase) * 0.015, 1.10) - 0.05,
				fposmod(phase * 0.618034 + elapsed * float(channel[2]), 1.20) - 0.10)
			var point := (normalized * size).round()
			if not Rect2(Vector2.ZERO, size).grow(8).has_point(point) or exclusion.has_point(point): continue
			var weight := lerpf(_weather_weight(kind, previous_season), _weather_weight(kind, season), _season_blend_for_y(normalized.y))
			if kind == "petal" and previous_season in [0, 1] and season in [2, 3] and season_progress < 1.0:
				weight = maxf(weight, sin(season_progress * PI) * 0.65)
			if weight < 0.01: continue
			particles.append({"kind": kind, "point": point, "alpha": weight, "index": i})
			if particles.size() >= MAX_WEATHER_PARTICLES: return particles
	return particles

func _draw_season_weather(c: Control) -> void:
	for particle in _season_particle_specs():
		var p: Vector2 = particle["point"]
		var i: int = particle["index"]
		var alpha: float = particle["alpha"]
		if particle["kind"] == "snow":
			var color := Color(0.98, 0.99, 0.97, alpha * 0.80)
			c.draw_rect(Rect2(p, Vector2(2, 2)), color)
			if i % 5 == 0:
				c.draw_rect(Rect2(p + Vector2(-2, 0), Vector2(6, 2)), color)
				c.draw_rect(Rect2(p + Vector2(0, -2), Vector2(2, 6)), color)
		else:
			var color: Color = [Color("d8a775"), Color("eac786"), Color("b98c6a")][i % 3] if particle["kind"] == "leaf" else [Color("efb3c2"), Color("f3dbc1"), Color("ddc6ec")][i % 3]
			color.a = alpha * 0.70
			var tilt := roundf(sin(elapsed * 1.5 + i) * 2.0)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(tilt, -2), p + Vector2(3, 1), p + Vector2(-tilt, 3)]), color)

func _season_near_water(uv: Vector2, radius: float) -> bool:
	for i in 8:
		if _is_water(uv + Vector2.from_angle(i * TAU / 8.0) * radius): return true
	return false
