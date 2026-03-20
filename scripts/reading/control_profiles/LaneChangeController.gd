class_name LaneChangeController extends ControlProfile

## Easy mode: Lane-change only control.
## Player switches between 3 lanes, car auto-follows curves.

const ACTION_LANE_LEFT := "ui_left"
const ACTION_LANE_RIGHT := "ui_right"
const ACTION_LANE_LEFT_ALT := "ui_a"
const ACTION_LANE_RIGHT_ALT := "ui_d"

var pending_lane_delta := 0
var pending_confirm := false


func _init() -> void:
	super._init()
	mode_name = "lane_change"


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_LANE_LEFT) or event.is_action_pressed(ACTION_LANE_LEFT_ALT):
		pending_lane_delta = -1
	elif (
		event.is_action_pressed(ACTION_LANE_RIGHT) or event.is_action_pressed(ACTION_LANE_RIGHT_ALT)
	):
		pending_lane_delta = 1


func consume_lane_delta(_delta: float) -> int:
	var delta = pending_lane_delta
	pending_lane_delta = 0
	return delta


func update(_delta: float) -> void:
	# Lane change controller doesn't need per-frame updates
	pass


## In easy mode, the car fully auto-steers to match target heading
func get_steering_influence(_current_heading: float, _target_heading: float) -> float:
	return 1.0  # Full auto-steer
