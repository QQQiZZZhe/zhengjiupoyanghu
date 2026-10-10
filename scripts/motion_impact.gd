extends Node
const Physics = preload("res://scripts/motion_web.gd")
var base := Vector2.ZERO
var base_rotation := 0.0
var velocity := Vector2.ZERO
var rotation_velocity := 0.0
var direction := 1.0
var age := 0.0
var duration := 0.48
signal finished

func _ready() -> void:
	var card := get_parent() as Control
	base = card.position
	base_rotation = card.rotation
	# A short impulse starts the card moving away from the pointer. The damped
	# oscillator keeps each return continuous instead of snapping between offsets.
	velocity = Vector2(direction * 360.0, 64.0)
	rotation_velocity = direction * 3.6

func _process(dt: float) -> void:
	if Physics.paused(self): return
	var card := get_parent() as Control
	if Physics.reduced(self):
		_finish(card)
		return
	age += dt
	var x := Physics.step(card.position.x - base.x, velocity.x, 0.0, dt, 420.0, 14.0)
	var y := Physics.step(card.position.y - base.y, velocity.y, 0.0, dt, 300.0, 18.0)
	var angle := Physics.step(card.rotation - base_rotation, rotation_velocity, 0.0, dt, 360.0, 16.0)
	card.position = base + Vector2(x.x, y.x)
	card.rotation = base_rotation + angle.x
	velocity = Vector2(x.y, y.y)
	rotation_velocity = angle.y
	if age >= duration:
		_finish(card)

func _finish(card: Control) -> void:
	card.position = base
	card.rotation = base_rotation
	set_process(false)
	finished.emit()
	queue_free()
