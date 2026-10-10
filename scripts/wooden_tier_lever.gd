extends Control
## A small, real 3D wooden detent lever rendered inside the 2D HUD.
const MotionSpring = preload("res://scripts/motion_spring.gd")

const MAX_SWING_DEGREES := 55.0
var lever_angle := 0.0:
	set(value):
		lever_angle = value
		if is_instance_valid(arm_pivot):
			arm_pivot.rotation.z = deg_to_rad(value)

var arm_pivot: Node3D
var viewport: SubViewport

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := SubViewportContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.offset_bottom = -16.0
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	viewport = SubViewport.new()
	viewport.size = Vector2i(212, 72)
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	holder.add_child(viewport)

	var world := Node3D.new()
	world.name = "WoodenLeverWorld"
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.14, 4.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.current = true
	world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-22.0, -18.0, -12.0)
	light.light_energy = 1.35
	light.shadow_enabled = false
	world.add_child(light)

	var wood := _wood(Color("94663a"), Color("b6824b"))
	var dark_wood := _wood(Color("57371f"), Color("78502e"))
	var pale_wood := _wood(Color("bd8c50"), Color("d3a368"))

	# A thick, faceted half-round socket below the fixed fulcrum.
	var backing := MeshInstance3D.new()
	backing.name = "SemicircleWoodHousing"
	backing.mesh = _half_round_mesh(0.60, 0.16)
	backing.position.z = 0.0
	backing.material_override = dark_wood
	world.add_child(backing)
	var face := MeshInstance3D.new()
	face.name = "WoodFace"
	face.mesh = _half_round_mesh(0.54, 0.09)
	face.position.z = 0.095
	face.material_override = wood
	world.add_child(face)
	_add_grain(world, pale_wood)

	# The shaft rotates around the center axle. Its parts remain one rigid lever.
	arm_pivot = Node3D.new()
	arm_pivot.name = "Fulcrum"
	arm_pivot.position = Vector3(0.0, 0.0, 0.24)
	world.add_child(arm_pivot)
	var shaft := MeshInstance3D.new()
	shaft.name = "SolidWoodShaft"
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.065
	shaft_mesh.bottom_radius = 0.088
	shaft_mesh.height = 0.88
	shaft_mesh.radial_segments = 12
	shaft.mesh = shaft_mesh
	shaft.position.y = 0.47
	shaft.material_override = dark_wood
	arm_pivot.add_child(shaft)
	var shaft_glint := MeshInstance3D.new()
	var glint_mesh := CylinderMesh.new()
	glint_mesh.top_radius = 0.012
	glint_mesh.bottom_radius = 0.018
	glint_mesh.height = 0.72
	glint_mesh.radial_segments = 6
	shaft_glint.mesh = glint_mesh
	shaft_glint.position = Vector3(-0.035, 0.49, 0.067)
	shaft_glint.material_override = pale_wood
	arm_pivot.add_child(shaft_glint)
	var grip := MeshInstance3D.new()
	grip.name = "CarvedWoodGrip"
	var grip_mesh := SphereMesh.new()
	grip_mesh.radius = 0.135
	grip_mesh.height = 0.27
	grip_mesh.radial_segments = 12
	grip_mesh.rings = 8
	grip.mesh = grip_mesh
	grip.position.y = 0.97
	grip.material_override = wood
	arm_pivot.add_child(grip)
	var axle := MeshInstance3D.new()
	axle.name = "WoodenAxleCap"
	var axle_mesh := SphereMesh.new()
	axle_mesh.radius = 0.12
	axle_mesh.height = 0.16
	axle_mesh.radial_segments = 12
	axle_mesh.rings = 6
	axle.mesh = axle_mesh
	axle.position = Vector3(0.0, 0.0, 0.20)
	axle.material_override = pale_wood
	world.add_child(axle)
	set_process(false)

func _wood(base: Color, variation: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.roughness = clampf(0.84 + absf(variation.r - base.r) * 0.2, 0.0, 1.0)
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _half_round_mesh(radius: float, depth: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 24
	var front_z := depth * 0.5
	var back_z := -depth * 0.5
	var center := Vector3(0.0, 0.0, front_z)
	for i in segments:
		var a0 := PI + PI * float(i) / float(segments)
		var a1 := PI + PI * float(i + 1) / float(segments)
		var p0 := Vector3(cos(a0) * radius, sin(a0) * radius, front_z)
		var p1 := Vector3(cos(a1) * radius, sin(a1) * radius, front_z)
		surface.add_vertex(center)
		surface.add_vertex(p0)
		surface.add_vertex(p1)
		# Back face, reversed so it remains visible from either side.
		surface.add_vertex(Vector3(0.0, 0.0, back_z))
		surface.add_vertex(Vector3(p1.x, p1.y, back_z))
		surface.add_vertex(Vector3(p0.x, p0.y, back_z))
	# Close the curved rim and the flat top edge.
	for i in segments:
		var a0 := PI + PI * float(i) / float(segments)
		var a1 := PI + PI * float(i + 1) / float(segments)
		var p0 := Vector3(cos(a0) * radius, sin(a0) * radius, front_z)
		var p1 := Vector3(cos(a1) * radius, sin(a1) * radius, front_z)
		var b0 := Vector3(p0.x, p0.y, back_z)
		var b1 := Vector3(p1.x, p1.y, back_z)
		surface.add_vertex(p0); surface.add_vertex(b0); surface.add_vertex(p1)
		surface.add_vertex(p1); surface.add_vertex(b0); surface.add_vertex(b1)
	var left := Vector3(-radius, 0.0, front_z)
	var right := Vector3(radius, 0.0, front_z)
	var left_back := Vector3(-radius, 0.0, back_z)
	var right_back := Vector3(radius, 0.0, back_z)
	surface.add_vertex(left); surface.add_vertex(left_back); surface.add_vertex(right)
	surface.add_vertex(right); surface.add_vertex(left_back); surface.add_vertex(right_back)
	surface.generate_normals()
	return surface.commit()

func _add_grain(world: Node3D, material: StandardMaterial3D) -> void:
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for row in 3:
		var y := -0.16 - float(row) * 0.13
		var half_width := sqrt(maxf(0.0, 0.54 * 0.54 - y * y)) * 0.62
		var left := Vector3(-half_width, y, 0.147)
		var right := Vector3(half_width, y + 0.012, 0.147)
		lines.surface_add_vertex(left)
		lines.surface_add_vertex(right)
	lines.surface_end()
	var grain := MeshInstance3D.new()
	grain.name = "FineWoodGrain"
	grain.mesh = lines
	grain.material_override = material
	world.add_child(grain)

func set_drag_angle(value: float) -> void:
	MotionSpring.stop(self, "lever_angle")
	lever_angle = clampf(value, -MAX_SWING_DEGREES, MAX_SWING_DEGREES)

func snap_to_tier(index: int, animate: bool) -> void:
	var target := float(1 - index) * MAX_SWING_DEGREES
	if not animate:
		MotionSpring.stop(self, "lever_angle")
		lever_angle = target
		return
	MotionSpring.to(self, "lever_angle", target, 132.0, 13.0)

func _exit_tree() -> void:
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
