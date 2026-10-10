extends RefCounted
## Native Godot motion, guided by onetake's carry/rhythm method.
## GSAP runs only in tools/motion_preview. Its ease names describe the native
## counterparts here; this class does not claim to execute JavaScript/GSAP.
static var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/motion/profiles.json"))

static func tween(owner: Node, profile: String = "response", channel: String = "") -> Tween:
	if not channel.is_empty(): cancel(owner, channel)
	var result := owner.create_tween()
	curve(result, str(profiles.get(profile, profiles.response).ease))
	if not channel.is_empty():
		owner.set_meta("motion_" + channel, result)
		result.finished.connect(_forget.bind(weakref(owner), channel, result.get_instance_id()), CONNECT_ONE_SHOT)
	return result

static func cancel(owner: Node, channel: String) -> void:
	var key := "motion_" + channel
	if not owner.has_meta(key): return
	var previous: Tween = owner.get_meta(key)
	if previous and previous.is_valid(): previous.kill()
	if owner.has_meta(key): owner.remove_meta(key)

static func _forget(owner_ref: WeakRef, channel: String, completed_id: int) -> void:
	var owner: Node = owner_ref.get_ref()
	var key := "motion_" + channel
	if owner and owner.has_meta(key):
		var current: Tween = owner.get_meta(key)
		if current.get_instance_id() == completed_id: owner.remove_meta(key)

static func seconds(profile: String) -> float:
	return float(profiles[profile].duration)

static func stagger(profile: String, index: int) -> float:
	return float(profiles[profile].get("stagger", 0.0)) * index

static func curve(target: Tween, name: String) -> Tween:
	var pieces := name.split(".")
	var transition: Tween.TransitionType = Tween.TRANS_LINEAR
	match pieces[0]:
		"power1": transition = Tween.TRANS_QUAD
		"power2": transition = Tween.TRANS_CUBIC
		"power3": transition = Tween.TRANS_QUART
		"power4": transition = Tween.TRANS_QUINT
		"sine": transition = Tween.TRANS_SINE
		"expo": transition = Tween.TRANS_EXPO
		"back": transition = Tween.TRANS_BACK
		"elastic": transition = Tween.TRANS_ELASTIC
	var direction: Tween.EaseType = Tween.EASE_IN_OUT
	if pieces.size() > 1:
		if pieces[1] == "in": direction = Tween.EASE_IN
		elif pieces[1] == "out": direction = Tween.EASE_OUT
	return target.set_trans(transition).set_ease(direction)

## Carry one card face into a detail view without leaving a second face behind.
## Opacity preserves container layout. Weak references tolerate viewer rebuilds.
static func borrow_face(proxy: Control, source: Control) -> void:
	proxy.scale = source.scale
	proxy.rotation = source.rotation
	for axis in ["gyro_x", "gyro_y"]:
		if source.has_meta(axis): proxy.set_meta(axis, source.get_meta(axis))
	var alpha := source.modulate.a
	if source.has_meta("motion_arrival"):
		alpha = 1.0
		cancel(source, "arrival")
		source.scale = Vector2.ONE
	proxy.set_meta("motion_source", weakref(source))
	proxy.set_meta("motion_source_alpha", alpha)
	source.modulate.a = 0.0
	var on_exit := release_face.bind(proxy)
	if not proxy.tree_exiting.is_connected(on_exit):
		proxy.tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)

static func release_face(proxy: Control) -> void:
	if not is_instance_valid(proxy) or not proxy.has_meta("motion_source"): return
	var source: Control = (proxy.get_meta("motion_source") as WeakRef).get_ref()
	if source: source.modulate.a = float(proxy.get_meta("motion_source_alpha", 1.0))
	proxy.remove_meta("motion_source")
	proxy.remove_meta("motion_source_alpha")
