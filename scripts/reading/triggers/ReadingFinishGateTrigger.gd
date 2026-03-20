class_name ReadingFinishGateTrigger extends Area3D

## Invisible trigger area for the finish gate.
## Detects when player enters and all pickups are collected.

signal finish_gate_reached

@export var word_index: int = 0
@export var trigger_width: float = 16.0  # X-axis width
@export var trigger_depth: float = 8.0  # Z-axis depth

var has_triggered := false
var all_pickups_collected := false


func _ready() -> void:
	# Create a box collision shape for detection
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(trigger_width, 3.0, trigger_depth)
	collision_shape.shape = box_shape
	add_child(collision_shape)

	# Position the collision shape centered at origin
	collision_shape.position = Vector3.ZERO

	area_entered.connect(_on_area_entered)


func trigger_finish() -> void:
	if not has_triggered and all_pickups_collected:
		has_triggered = true
		finish_gate_reached.emit()


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player"):
		trigger_finish()


func reset() -> void:
	has_triggered = false
