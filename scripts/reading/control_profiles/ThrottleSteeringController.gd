class_name ThrottleSteeringController extends ControlProfile

## Hard mode: Full manual steering and throttle control.
## Player fully controls direction and forward/backward movement.

const ACTION_STEER_LEFT := "ui_left"
const ACTION_STEER_RIGHT := "ui_right"
const ACTION_STEER_LEFT_ALT := "ui_a"
const ACTION_STEER_RIGHT_ALT := "ui_d"
const ACTION_THROTTLE_FORWARD := "ui_up"
const ACTION_THROTTLE_BACKWARD := "ui_down"
const ACTION_THROTTLE_FORWARD_ALT := "ui_w"
const ACTION_THROTTLE_BACKWARD_ALT := "ui_s"

const MAX_STEERING_ANGLE := PI * 0.5  # 90 degrees max for hard mode
const STEERING_LERP_SPEED := 10.0
const THROTTLE_LERP_SPEED := 6.0

var steer_input := 0.0  # Range: -1.0 to 1.0
var throttle_input := 0.0  # Range: -1.0 to 1.0
var target_steering_angle := 0.0
var target_throttle := 0.0


func _init() -> void:
	super._init()
	mode_name = "throttle_steering"


func handle_input(event: InputEvent) -> void:
	# Steering input
	if event.is_action_pressed(ACTION_STEER_LEFT) or event.is_action_pressed(ACTION_STEER_LEFT_ALT):
		steer_input = -1.0
	elif (
		event.is_action_pressed(ACTION_STEER_RIGHT)
		or event.is_action_pressed(ACTION_STEER_RIGHT_ALT)
	):
		steer_input = 1.0
	elif (
		event.is_action_released(ACTION_STEER_LEFT)
		or event.is_action_released(ACTION_STEER_LEFT_ALT)
	):
		if steer_input < 0:
			steer_input = 0.0
	elif (
		event.is_action_released(ACTION_STEER_RIGHT)
		or event.is_action_released(ACTION_STEER_RIGHT_ALT)
	):
		if steer_input > 0:
			steer_input = 0.0

	# Throttle input
	var fwd = ACTION_THROTTLE_FORWARD_ALT
	var bwd = ACTION_THROTTLE_BACKWARD_ALT
	if event.is_action_pressed(ACTION_THROTTLE_FORWARD) or event.is_action_pressed(fwd):
		throttle_input = 1.0
	elif event.is_action_pressed(ACTION_THROTTLE_BACKWARD) or event.is_action_pressed(bwd):
		throttle_input = -1.0
	elif event.is_action_released(ACTION_THROTTLE_FORWARD) or event.is_action_released(fwd):
		if throttle_input > 0:
			throttle_input = 0.0
	elif event.is_action_released(ACTION_THROTTLE_BACKWARD) or event.is_action_released(bwd):
		if throttle_input < 0:
			throttle_input = 0.0


func update(delta: float) -> void:
	# Smooth steering toward target
	target_steering_angle = steer_input * MAX_STEERING_ANGLE
	var steer_spd = STEERING_LERP_SPEED * delta
	current_steering_angle = move_toward(current_steering_angle, target_steering_angle, steer_spd)

	# Smooth throttle toward target
	target_throttle = throttle_input
	current_throttle = move_toward(current_throttle, target_throttle, THROTTLE_LERP_SPEED * delta)


func consume_lane_delta(_delta: float) -> int:
	return 0  # Hard mode doesn't use lane changes


## In hard mode, no auto-steer - player has full control
func get_steering_influence(_current_heading: float, _target_heading: float) -> float:
	return 0.0  # No auto-steer
