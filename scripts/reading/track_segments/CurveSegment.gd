class_name CurveSegment extends TrackSegment

## Represents a curved track segment.
## Curves transition smoothly from one heading to another.

## Ending heading for the curve (in radians)
var end_heading: float = 0.0

## Difficulty indicator: how much the player must steer (0.0 = full auto, 1.0 = full manual)
var difficulty_factor: float = 0.0

## Curve direction: 1.0 for right turn, -1.0 for left turn
var turn_direction: float = 1.0


func _init(
	id: int,
	pos: Vector3,
	seg_length: float,
	start_heading: float,
	end_head: float,
	difficulty: float
) -> void:
	super._init(id, pos, seg_length, "curve")
	ideal_heading = start_heading
	end_heading = end_head
	difficulty_factor = clampf(difficulty, 0.0, 1.0)

	# Determine turn direction
	var heading_delta = end_head - start_heading
	# Normalize to -PI to PI
	while heading_delta > PI:
		heading_delta -= TAU
	while heading_delta < -PI:
		heading_delta += TAU
	turn_direction = 1.0 if heading_delta >= 0 else -1.0


## Get the ideal heading at a specific progression through the curve (0.0 to 1.0)
func get_heading_at_progress(progress: float) -> float:
	progress = clampf(progress, 0.0, 1.0)
	return lerp_angle(ideal_heading, end_heading, progress)


## Get the ideal auto-steer amount for this curve based on difficulty
## Returns a steering influence value (0.0 = no steer, 1.0 = full steer)
func get_auto_steer_influence(difficulty_mode: String) -> float:
	match difficulty_mode:
		"easy":
			return 1.0  # Full auto-steer
		"medium":
			return 0.5 * (1.0 - difficulty_factor)  # Partial auto-steer
		"hard":
			return 0.0  # Manual only
		_:
			return 1.0
