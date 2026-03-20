class_name ReadingObstacleTrigger extends Area3D

## Invisible trigger area for obstacles.
## Detects when player collides and applies slowdown penalty.

signal obstacle_hit(obstacle_index: int)

@export var word_index: int = 0
@export var obstacle_index: int = 0
@export var trigger_width: float = 5.4  # X-axis width (±2.7)
@export var trigger_depth: float = 4.0  # Z-axis depth (±2.0)
@export var penalty_seconds: float = 0.75

var has_triggered := false


func _ready() -> void:
	# Create a box collision shape for detection
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(trigger_width, 2.0, trigger_depth)
	collision_shape.shape = box_shape
	add_child(collision_shape)

	# Position the collision shape centered at origin
	collision_shape.position = Vector3.ZERO

	area_entered.connect(_on_area_entered)


func trigger_obstacle() -> void:
	if not has_triggered:
		has_triggered = true
		obstacle_hit.emit(obstacle_index)


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player"):
		trigger_obstacle()


func reset() -> void:
	has_triggered = false
