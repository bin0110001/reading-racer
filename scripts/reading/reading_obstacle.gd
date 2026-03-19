class_name ReadingObstacle
extends Node3D

var lane_index := 0
var segment_index := 0
var cleared := false
var penalty_seconds := 0.75

var _label := Label3D.new()
var _base_height := 0.0


func _ready() -> void:
	_base_height = position.y
	_label.text = "!"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.modulate = Color(1.0, 0.35, 0.25)
	_label.position = Vector3(0.0, 1.5, 0.0)
	add_child(_label)


func configure(next_segment_index: int, next_lane_index: int) -> void:
	segment_index = next_segment_index
	lane_index = next_lane_index


func set_cleared() -> void:
	if cleared:
		return
	cleared = true

	# Knock the obstacle out of the way rather than instantly disappearing.
	# This gives a better sense that the player bumped it out of the lane.
	var target_position := position + Vector3(4.0, 0.0, randf_range(-1.0, 1.0) * 2.0)
	var tween := create_tween()
	var prop_tween := tween.tween_property(self, "position", target_position, 0.3)
	prop_tween.set_trans(Tween.TRANS_SINE)
	prop_tween.set_ease(Tween.EASE_OUT)
	tween.connect("finished", Callable(self, "queue_free"))


func _process(delta: float) -> void:
	if cleared:
		return
	rotation.y += delta * 0.8
	position.y = _base_height + sin(Time.get_ticks_msec() / 220.0) * 0.08
