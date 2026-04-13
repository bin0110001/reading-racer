class_name MovementSystem extends RefCounted

## MovementSystem: Solely responsible for player movement, heading, and position updates.
## Separates movement logic from gameplay, map display, and map generation concerns.

## Constants (copied from ReadingMode for independence)
const SmoothSteeringControllerScript = preload(
	"res://scripts/reading/control_profiles/SmoothSteeringController.gd"
)
const ThrottleSteeringControllerScript = preload(
	"res://scripts/reading/control_profiles/ThrottleSteeringController.gd"
)
const LANE_WIDTH := 4.0
const LANE_HALF_WIDTH := LANE_WIDTH * 0.5
const LANE_POSITIONS := [-LANE_WIDTH, 0.0, LANE_WIDTH]
const LANE_CHANGE_SPEED := 18.0
const PLAYER_SPEED := 13.0
const SLOWED_SPEED := 7.0

## References to path data (set by parent)
var track_layout: Variant = null  # shared_track_layout from ReadingMode
var track_tile_length: float = 0.0
var layout_origin: Vector3 = Vector3.ZERO

## Movement state
var lane_index: int = 1
var player_lane_offset: float = 0.0
var player_path_distance: float = 0.0
var player_heading: float = 0.0
var player_forward_speed: float = PLAYER_SPEED
var slowed_timer: float = 0.0

## Control profile
var control_profile = null


func _init(p_control_profile) -> void:
	control_profile = p_control_profile


## Update control profile and movement state each frame
func update(delta: float) -> void:
	if control_profile:
		control_profile.update(delta)

	# Update slowed timer
	slowed_timer = maxf(slowed_timer - delta, 0.0)

	# Get movement inputs based on control profile
	var lane_delta = control_profile.consume_lane_delta(delta)
	if lane_delta != 0:
		lane_index = clampi(lane_index + lane_delta, 0, LANE_POSITIONS.size() - 1)

	# Determine speed based on obstacles
	var speed := SLOWED_SPEED if slowed_timer > 0.0 else PLAYER_SPEED

	# Handle throttle control vs automatic forward
	if control_profile and control_profile.get_script() == ThrottleSteeringControllerScript:
		var throttle = control_profile.get_throttle()
		player_forward_speed = speed * maxf(0.0, throttle) if throttle >= 0 else -speed * throttle
	else:
		player_forward_speed = speed

	# Advance along the track
	player_path_distance += player_forward_speed * delta


## Update player heading and position based on track pose
func update_position_and_heading(delta: float, track_pose: Dictionary) -> void:
	if track_pose.is_empty():
		return

	var target_lane_offset: float = LANE_POSITIONS[lane_index]
	if control_profile and control_profile.get_script() == SmoothSteeringControllerScript:
		var smooth_controller: SmoothSteeringController = control_profile
		var steering_angle := smooth_controller.get_steering_angle()
		var steering_ratio := 0.0
		if SmoothSteeringController.MAX_STEERING_ANGLE > 0.0:
			steering_ratio = clamp(
				steering_angle / SmoothSteeringController.MAX_STEERING_ANGLE, -1.0, 1.0
			)
		target_lane_offset = steering_ratio * LANE_POSITIONS[LANE_POSITIONS.size() - 1]
	player_lane_offset = move_toward(
		player_lane_offset, target_lane_offset, LANE_CHANGE_SPEED * delta
	)

	var target_heading := float(track_pose.get("heading", player_heading))

	# Apply control profile's steering influence
	var steering_influence = control_profile.get_steering_influence(player_heading, target_heading)
	var player_steering = 0.0

	if control_profile and control_profile.get_script() == SmoothSteeringControllerScript:
		player_steering = control_profile.get_steering_angle()
	elif control_profile and control_profile.get_script() == ThrottleSteeringControllerScript:
		player_steering = control_profile.get_steering_angle()

	# Blend steering: auto-steer influence + player input
	var blended_heading = player_heading
	if steering_influence > 0.0:
		blended_heading = lerp_angle(
			player_heading, target_heading, steering_influence * delta * 4.0
		)
	if player_steering != 0.0:
		blended_heading += player_steering * (1.0 - steering_influence) * delta

	player_heading = fmod(blended_heading + PI * 2.0, PI * 2.0)


## Change the control profile (called when difficulty changes)
func set_control_profile(profile) -> void:
	control_profile = profile


## Handle input events
func handle_input(event: InputEvent) -> void:
	if control_profile:
		control_profile.handle_input(event)


## Set lane directly
func set_lane(index: int) -> void:
	lane_index = clampi(index, 0, LANE_POSITIONS.size() - 1)


## Apply slowdown penalty (called by obstacle hits)
func apply_slowdown(duration: float) -> void:
	slowed_timer = duration


## Get current player position (for display/physics)
func get_player_position(track_pose: Dictionary) -> Vector3:
	return track_pose.get("position", Vector3.ZERO) as Vector3


## Get current player basis for visual rotation
func get_player_basis() -> Basis:
	var forward = Vector3(cos(player_heading), 0.0, sin(player_heading)).normalized()
	var right = Vector3(-forward.z, 0.0, forward.x).normalized()
	var world_up = Vector3.UP
	var base_basis = Basis(right, world_up, forward).orthonormalized()
	return base_basis


## Reset movement state for new word
func reset(reset_position: bool = false, path_distance_offset: float = 0.0) -> void:
	if reset_position:
		lane_index = 1
		player_lane_offset = 0.0
		player_path_distance = path_distance_offset
		player_heading = 0.0
	slowed_timer = 0.0


## Get current state for saving/loading
func get_state() -> Dictionary:
	return {
		"lane_index": lane_index,
		"player_lane_offset": player_lane_offset,
		"player_path_distance": player_path_distance,
		"player_heading": player_heading,
		"player_forward_speed": player_forward_speed,
		"slowed_timer": slowed_timer,
	}


## Restore state from saved data
func set_state(state: Dictionary) -> void:
	lane_index = int(state.get("lane_index", 1))
	player_lane_offset = float(state.get("player_lane_offset", 0.0))
	player_path_distance = float(state.get("player_path_distance", 0.0))
	player_heading = float(state.get("player_heading", 0.0))
	player_forward_speed = float(state.get("player_forward_speed", PLAYER_SPEED))
	slowed_timer = float(state.get("slowed_timer", 0.0))
