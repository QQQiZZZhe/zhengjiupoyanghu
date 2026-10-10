extends "res://scripts/main.gd"
var replayed_cards: Array[String] = []
var popped_cards: Array[String] = []
var replayed_panels: Array[PanelContainer] = []
var row_y_spreads: Array[float] = []
var active_settlement_springs := 0
var unsettled_gyro_cards := 0
func _play_score_animation(ledger: Array, before_all: Dictionary, played: Array, after: Dictionary) -> void:
	for index in played:
		replayed_cards.append(str(card_infos[index]["card_id"]))
		replayed_panels.append(card_infos[index]["panel"])
	await super._play_score_animation(ledger, before_all, played, after)
func _play_card_shake(panel: PanelContainer, amp: float, strength: float = 1.0, duration_scale: float = 1.0) -> void:
	var low := INF
	var high := -INF
	for card in replayed_panels:
		var mat := card.material as ShaderMaterial
		if mat and (absf(float(mat.get_shader_parameter("tilt_x"))) > 0.0001 or absf(float(mat.get_shader_parameter("tilt_y"))) > 0.0001): unsettled_gyro_cards += 1
		low = minf(low, card.global_position.y)
		high = maxf(high, card.global_position.y)
		for key in ["position", "rotation", "scale"]:
			var spring := card.get_node_or_null("MotionSpring_" + key)
			if spring and spring.is_processing(): active_settlement_springs += 1
	row_y_spreads.append(high - low)
	popped_cards.append(str(panel.get_meta("probe_card_id", "")))
	super._play_card_shake(panel, amp, strength, duration_scale)
