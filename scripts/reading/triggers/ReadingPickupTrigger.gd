class_name ReadingPickupTrigger extends Area3D

## Invisible trigger area for letter pickups.
## Detects when player enters the area and emits a signal.

signal pickup_triggered(index: int, letter: String, phoneme_label: String)
signal pickup_missed

@export var word_index: int = 0
@export var letter_index: int = 0
@export var letter: String = ""
@export var phoneme_label: String = ""
@export var trigger_width: float = 8.0  # X-axis width
@export var trigger_depth: float = 6.0  # Z-axis depth

var has_triggered := false
var player: Node3D = null


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


func trigger_pickup() -> void:
	if not has_triggered:
		has_triggered = true
		pickup_triggered.emit(letter_index, letter, phoneme_label)


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player"):
		trigger_pickup()


func reset() -> void:
	has_triggered = false
