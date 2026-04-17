class_name ReadingWordChoiceTrigger extends Area3D

signal choice_selected(text: String, correct: bool, word_index: int)

const TriggerCollisionBuilder = preload(
	"res://scripts/reading/triggers/ReadingTriggerCollisionBuilder.gd"
)

@export var word_index: int = 0
@export var choice_text: String = ""
@export var is_correct: bool = false
@export var trigger_width: float = 10.0
@export var trigger_depth: float = 4.0

var has_triggered := false


func _ready() -> void:
	(
		TriggerCollisionBuilder
		. add_box_collision(
			self,
			trigger_width,
			3.0,
			trigger_depth,
			Vector3(0.0, -0.5, 0.0),
		)
	)
	area_entered.connect(_on_area_entered)


func trigger_choice() -> void:
	if has_triggered:
		return
	has_triggered = true
	choice_selected.emit(choice_text, is_correct, word_index)


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player"):
		trigger_choice()


func reset() -> void:
	has_triggered = false
