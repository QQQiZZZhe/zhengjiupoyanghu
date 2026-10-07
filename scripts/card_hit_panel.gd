extends PanelContainer
func _has_point(point: Vector2) -> bool:
	return preload("res://scripts/card_geometry.gd").contains(self, get_global_transform() * point)
