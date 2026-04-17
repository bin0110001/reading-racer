class_name ReadingPickupTrigger extends Area3D

## Invisible trigger area for letter pickups.
## Detects when player enters the area and emits a signal.

signal pickup_triggered(index: int, letter: String, phoneme_label: String)
@warning_ignore("unused_signal")
signal pickup_missed

const TriggerCollisionBuilder = preload(
	"res://scripts/reading/triggers/ReadingTriggerCollisionBuilder.gd"
)

@export var word_index: int = 0
@export var letter_index: int = 0
@export var letter: String = ""
@export var phoneme_label: String = ""
@export var trigger_width: float = 8.0  # X-axis width
@export var trigger_depth: float = 6.0  # Z-axis depth

var has_triggered := false
var player: Node3D = null


func _ready() -> void:
	TriggerCollisionBuilder.add_box_collision(self, trigger_width, 2.0, trigger_depth)

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
