class_name SmoothSteeringController extends ControlProfile

## Medium mode: Smooth steering with partial auto-follow.
## Player steers gradually left/right, car auto-follows curves partially.

const ACTION_STEER_LEFT := "ui_left"
const ACTION_STEER_RIGHT := "ui_right"
const ACTION_STEER_LEFT_ALT := "ui_a"
const ACTION_STEER_RIGHT_ALT := "ui_d"

const MAX_STEERING_ANGLE := PI * 0.35  # 63 degrees max
const STEERING_LERP_SPEED := 8.0  # Units per second for steering transition

var steer_input := 0.0  # Range: -1.0 to 1.0
var target_steering_angle := 0.0


func _init() -> void:
	super._init()
	mode_name = "smooth_steering"


func handle_input(event: InputEvent) -> void:
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


func update(delta: float) -> void:
	# Smooth steering input toward target
	target_steering_angle = steer_input * MAX_STEERING_ANGLE
	var spd = STEERING_LERP_SPEED * delta
	current_steering_angle = move_toward(current_steering_angle, target_steering_angle, spd)


func consume_lane_delta(_delta: float) -> int:
	return 0  # Medium mode doesn't use discrete lane changes


## In medium mode, partial auto-steer blends with player input
## Returns 0.5 to indicate 50% auto-steer influence
func get_steering_influence(_current_heading: float, _target_heading: float) -> float:
	return 0.5  # Partial auto-steer (blended with player input)
