class_name ControlProfile extends RefCounted

## Base class for control profiles.
## Different control modes (easy, medium, hard) inherit from this and implement their own logic.

signal mode_name_changed(new_mode: String)

var mode_name: String = "keyboard"
var current_steering_angle: float = 0.0
var current_throttle: float = 0.0


func _init() -> void:
	pass


## Handle input events and update internal state
func handle_input(_event: InputEvent) -> void:
	pass


## Get the lane change delta for this frame (for lane-based controls)
## Returns -1, 0, or 1
func consume_lane_delta(_delta: float) -> int:
	return 0


## Get the steering angle for this frame (for steering-based controls)
## Returns angle in radians
func get_steering_angle() -> float:
	return current_steering_angle


## Get the throttle amount (-1.0 backward to 1.0 forward)
func get_throttle() -> float:
	return current_throttle


## Update the control state each frame
func update(_delta: float) -> void:
	pass


## Set the control mode name
func set_mode(name: String) -> void:
	mode_name = name
	mode_name_changed.emit(name)


## Get the appropriate steering influence based on difficulty
## This is used by reading_mode.gd to auto-correct the car's heading
func get_steering_influence(_current_heading: float, _target_heading: float) -> float:
	return 0.0
