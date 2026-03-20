extends Node3D

const CameraController3DClass = preload("res://scripts/reading/CameraController3D.gd")

# Grid layout constants
const GRID_WIDTH := 7  # Z-axis: 7 columns (decorations + 1 road + decorations)
const GRID_AHEAD := 10  # X-axis: 10 rows ahead of camera
const GRID_BEHIND := 3  # X-axis: 3 rows behind camera
const GRID_DEPTH := GRID_AHEAD + GRID_BEHIND  # Total 13 rows
const GRID_CENTER_START := 3  # Column where the road is (col 3, centered)
const GRID_CENTER_END := 3  # Last center column (inclusive)

const LANE_WIDTH := 6.0
const LANE_HALF_WIDTH := LANE_WIDTH * 0.5
const LANE_POSITIONS := [-LANE_WIDTH, 0.0, LANE_WIDTH]
const PLAYER_START_X := -12.0
const WORD_START_X := 26.0
const SEGMENT_SPACING := 18.0
const PLAYER_SPEED := 13.0
const SLOWED_SPEED := 7.0
const LANE_CHANGE_SPEED := 18.0
# Increased pickup radius to match much larger letter render size.
const PICKUP_RADIUS_X := 4.0
const PICKUP_RADIUS_Z := 3.0
const OBSTACLE_RADIUS_X := 2.7
const OBSTACLE_RADIUS_Z := 2.0

const WORD_GAP := 30.0
const PRESPAWN_WORDS := 2
const MIN_ROAD_AHEAD := SEGMENT_SPACING * 10
const WORD_START_OFFSET := WORD_START_X - PLAYER_START_X
const ROAD_CLEAR_GAP := SEGMENT_SPACING

const PLAYER_MODEL_PATH := "res://models/vehicle-truck-yellow.glb"
const ROAD_MODEL_PATH := "res://models/track-straight.glb"
const ROAD_SCALE := 2.0
const OBSTACLE_MODEL_PATH := "res://models/track-bump.glb"
const FINISH_MODEL_PATH := "res://models/track-finish.glb"
const DECORATION_MODEL_PATH := "res://models/decoration-forest.glb"

# Decoration selection (weighted): empty is more common.
const DECORATION_MODELS := [
	{"path": "res://models/decoration-empty.glb", "weight": 6},
	{"path": "res://models/decoration-forest.glb", "weight": 2},
	{"path": "res://models/decoration-tents.glb", "weight": 2},
]

@export var stream_tiles_each_side: int = 5
@export var stream_tiles_ahead: int = 10
@export var stream_tiles_behind: int = 3

# Member variables
var track_generator: TrackGenerator
var shared_track_layout: Variant = null
var current_segments: Array[TrackSegment] = []
var control_profile: ControlProfile
var settings_store := ReadingSettingsStore.new()
var content_loader := ReadingContentLoader.new()
var rng := RandomNumberGenerator.new()
var camera_controller = null  # CameraController3D instance

var settings: Dictionary = {}
var available_groups: Array[String] = []
var current_entries: Array[Dictionary] = []
var current_entry: Dictionary = {}
var current_entry_index := -1

var pickup_triggers: Array[ReadingPickupTrigger] = []
var obstacle_triggers: Array[ReadingObstacleTrigger] = []
var finish_gate_trigger: ReadingFinishGateTrigger = null

var lane_index := 1
var next_target_index := 0
var state := "loading"
var state_before_pause := "countdown"
var countdown_remaining := 3.0
var slowed_timer := 0.0
var completion_timer := 0.0
var course_length := 120.0
var finish_line_x := 0.0
var farthest_spawned_x := 0.0
var player_path_distance := 0.0
var player_lane_offset := 0.0
var layout_origin := Vector3.ZERO
var layout_cell_entries: Array = []

var track_tile_length := 0.0
var track_tile_width := 0.0
var grid_cells: Dictionary = {}  # Key: "x,z", Value: Node3D reference
var current_tile_index := 0

var current_word_start_x := WORD_START_X
var next_word_start_x := WORD_START_X
var next_spawn_entry_index := 0

# Player movement and rotation
var player_heading := 0.0  # Current player rotation in radians
var player_forward_speed := PLAYER_SPEED
var current_steering_input := 0.0  # From control profile

@onready var road: Node3D = $Road
@onready var spawn_root: Node3D = $SpawnRoot
@onready var player: Node3D = $Player
@onready var vehicle_anchor: Node3D = $Player/VehicleAnchor
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var hud: ReadingHUD = $ReadingHUD
@onready var phoneme_player: PhonemePlayer = $PhonemePlayer


# Helper function to get the center Z position of the road (used consistently everywhere)
func _get_road_center_z() -> float:
	return (GRID_CENTER_START - GRID_WIDTH * 0.5) * track_tile_width


func _get_layout_path_count() -> int:
	if shared_track_layout == null:
		return 0
	return shared_track_layout.path_cells.size()


func _wrap_path_index(path_index: int) -> int:
	var path_count := _get_layout_path_count()
	if path_count <= 0:
		return 0
	var wrapped := path_index % path_count
	if wrapped < 0:
		wrapped += path_count
	return wrapped


func _path_index_to_distance(path_index: int) -> float:
	return float(_wrap_path_index(path_index)) * track_tile_length


func _get_path_cell(path_index: int) -> Vector3i:
	if _get_layout_path_count() <= 0:
		return Vector3i.ZERO
	return shared_track_layout.path_cells[_wrap_path_index(path_index)]


func _cell_to_world_center(cell: Vector3i) -> Vector3:
	return (
		layout_origin
		+ Vector3(
			(float(cell.x) + 0.5) * track_tile_length, 0.0, (float(cell.z) + 0.5) * track_tile_width
		)
	)


func _get_path_frame(path_index: int) -> Dictionary:
	if _get_layout_path_count() <= 0:
		return {}
	var current_center := _cell_to_world_center(_get_path_cell(path_index))
	var next_center := _cell_to_world_center(_get_path_cell(path_index + 1))
	var forward := (next_center - current_center).normalized()
	if forward.length_squared() == 0.0:
		forward = Vector3.RIGHT
	var right := Vector3(-forward.z, 0.0, forward.x)
	return {
		"center": current_center,
		"next_center": next_center,
		"forward": forward,
		"right": right,
		"heading": atan2(forward.z, forward.x),
	}


func _get_pose_at_path_distance(path_distance: float, lane_offset: float) -> Dictionary:
	var path_count := _get_layout_path_count()
	if path_count <= 0 or track_tile_length <= 0.0:
		return {}

	var loop_length := float(path_count) * track_tile_length
	var wrapped_distance := fposmod(path_distance, loop_length)
	if wrapped_distance < 0.0:
		wrapped_distance += loop_length

	var segment_float := wrapped_distance / track_tile_length
	var segment_index := int(floor(segment_float))
	var segment_progress := segment_float - float(segment_index)
	var current_center := _cell_to_world_center(_get_path_cell(segment_index))
	var next_center := _cell_to_world_center(_get_path_cell(segment_index + 1))
	var forward := (next_center - current_center).normalized()
	if forward.length_squared() == 0.0:
		forward = Vector3.RIGHT
	var right := Vector3(-forward.z, 0.0, forward.x)
	var center := current_center.lerp(next_center, segment_progress)
	return {
		"center": center,
		"position": center + right * lane_offset,
		"forward": forward,
		"right": right,
		"heading": atan2(forward.z, forward.x),
		"segment_index": segment_index,
		"segment_progress": segment_progress,
	}


func _is_point_in_stream_window(world_pos: Vector3) -> bool:
	var forward := Vector3(cos(player_heading), 0.0, sin(player_heading))
	if forward.length_squared() == 0.0:
		forward = Vector3.RIGHT
	var right := Vector3(-forward.z, 0.0, forward.x)
	var flat_offset := world_pos - player.position
	flat_offset.y = 0.0
	var forward_distance := flat_offset.dot(forward)
	var side_distance := absf(flat_offset.dot(right))
	var ahead_limit := (float(stream_tiles_ahead) + 0.75) * track_tile_length
	var behind_limit := (float(stream_tiles_behind) + 0.75) * track_tile_length
	var side_limit := (float(stream_tiles_each_side) + 0.75) * track_tile_width
	return (
		forward_distance <= ahead_limit
		and forward_distance >= -behind_limit
		and side_distance <= side_limit
	)


func _get_word_anchor(word_index: int) -> Dictionary:
	if shared_track_layout == null:
		return {}
	if word_index < 0 or word_index >= shared_track_layout.word_anchors.size():
		return {}
	return shared_track_layout.word_anchors[word_index] as Dictionary


func _ready() -> void:
	print("[ReadingMode._ready] Starting initialization...")
	rng.randomize()
	ReadingControlProfile.ensure_input_actions()
	settings = settings_store.load_settings()
	print("[ReadingMode] Loaded settings: %s" % str(settings.keys()))
	settings_store.apply_master_volume(float(settings.get("master_volume", 0.8)))
	available_groups = content_loader.list_word_groups()
	print(
		"[ReadingMode] Found %d word groups: %s" % [available_groups.size(), str(available_groups)]
	)
	if available_groups.is_empty():
		state = "error"
		hud.set_status("No audio/words groups were found.")
		hud.flash_feedback("Add word audio to res://audio/words/<group>", Color(1.0, 0.4, 0.3))
		print("[ReadingMode] ERROR: No word groups found!")
		return

	var requested_group: String = str(settings.get("word_group", available_groups[0]))
	if not available_groups.has(requested_group):
		requested_group = available_groups[0]
		settings["word_group"] = requested_group

	hud.configure(available_groups, settings)
	hud.control_mode_changed.connect(_on_control_mode_changed)
	hud.word_group_changed.connect(_on_word_group_changed)
	hud.volume_changed.connect(_on_volume_changed)
	hud.resume_requested.connect(_close_options)
	phoneme_player.phoneme_changed.connect(_on_phoneme_changed)
	print("[ReadingMode] HUD configured with group: %s" % requested_group)

	# Initialize track generator
	print("[ReadingMode] Initializing TrackGenerator...")
	track_generator = TrackGenerator.new()
	track_generator.init_generator(Vector3(PLAYER_START_X, 0.0, 0.0))
	# Pre-generate track ahead
	track_generator.generate_to_distance(course_length)
	var initial_segments = track_generator.get_all_segments()
	print("[ReadingMode] Generated %d initial track segments" % initial_segments.size())

	# Initialize control profile - starts with default, updated when word loads
	var control_mode = str(settings.get("control_mode", "lane_change"))
	_set_control_profile(control_mode)
	print("[ReadingMode] Control profile set to: %s" % control_mode)

	_update_help_text()
	_attach_player_model()
	player.add_to_group("player")  # For trigger detection
	print("[ReadingMode] Player model attached and added to 'player' group")
	_load_group(requested_group)
	_build_course_geometry()
	print("[ReadingMode] Course geometry built")

	# Initialize camera controller
	camera_controller = CameraController3DClass.new()
	add_child(camera_controller)
	camera_controller.attach_camera(camera)
	camera_controller.set_smoothing_factor(0.15)  # Smooth camera movement around corners
	camera_controller.set_distance(15.0)
	camera_controller.set_vertical_angle(-30.0)  # Look down at the car
	camera_controller.focus_on(player.position, 15.0)
	print("[ReadingMode] Camera controller initialized with smoothing")

	_start_next_word(false, true, true)
	print("[ReadingMode] Initialization complete!")


func _unhandled_input(event: InputEvent) -> void:
	# Allow camera controller to handle input first
	if camera_controller and camera_controller.handle_input(event):
		return

	if control_profile:
		control_profile.handle_input(event)
	if event.is_action_pressed(ReadingControlProfile.ACTION_TOGGLE_OPTIONS):
		_toggle_options()
		get_viewport().set_input_as_handled()
		return

	if (
		event.is_action_pressed(ReadingControlProfile.ACTION_CONFIRM)
		and not hud.is_options_open()
		and not current_entry.is_empty()
	):
		phoneme_player.play_word(content_loader.get_word_stream(current_entry))
		hud.flash_feedback("Replay word", Color(0.75, 0.88, 1.0))
		get_viewport().set_input_as_handled()


func _set_control_profile(mode_name: String) -> void:
	# Create appropriate control profile based on mode
	match mode_name:
		"smooth_steering":
			control_profile = SmoothSteeringController.new()
		"throttle_steering":
			control_profile = ThrottleSteeringController.new()
		_:
			# Default to lane change for "lane_change" or any unknown mode
			control_profile = LaneChangeController.new()


func _physics_process(delta: float) -> void:
	if state == "error":
		return

	if state == "paused":
		_update_camera(delta)
		return

	if state == "countdown":
		countdown_remaining -= delta
		if countdown_remaining <= 0.0:
			state = "playing"
			hud.set_status("Go collect the sounds")
			hud.flash_feedback("GO!", Color(0.4, 1.0, 0.5))
		else:
			hud.set_status("Starting in %d" % int(ceil(countdown_remaining)))
		_update_camera(delta)
		return

	if state == "transition":
		completion_timer -= delta
		if completion_timer <= 0.0:
			_start_next_word(true, false, false)
		# allow the player to keep moving into the empty area

	# Update control profile
	if control_profile:
		control_profile.update(delta)

	slowed_timer = maxf(slowed_timer - delta, 0.0)

	# Get movement inputs based on control profile
	var lane_delta = control_profile.consume_lane_delta(delta)
	if lane_delta != 0:
		lane_index = clampi(lane_index + lane_delta, 0, LANE_POSITIONS.size() - 1)

	# Handle speed (slowing from obstacles)
	var speed := SLOWED_SPEED if slowed_timer > 0.0 else PLAYER_SPEED

	# For hard mode, use throttle control; for other modes, use automatic forward
	if control_profile is ThrottleSteeringController:
		var throttle = control_profile.get_throttle()
		player_forward_speed = speed * maxf(0.0, throttle) if throttle >= 0 else -speed * throttle
		# TODO: handle throttle value properly
		speed = PLAYER_SPEED
	else:
		player_forward_speed = speed

	# Advance around the generated loop instead of moving along a fixed X strip.
	player_path_distance += player_forward_speed * delta

	# Update player heading and position based on track
	_update_player_heading_and_position(delta)

	# Update collisions (triggers)
	_update_triggers()

	_ensure_road_ahead()
	_update_status()
	_update_camera(delta)


func _ensure_road_ahead() -> void:
	print(
		(
			"[ReadingMode._ensure_road_ahead] path_distance=%.1f active_tiles=%d"
			% [player_path_distance, grid_cells.size()]
		)
	)
	_update_grid()
	_cleanup_spawned_content()
	_ensure_words_ahead()


func _update_player_heading_and_position(delta: float) -> void:
	var target_lane_offset: float = LANE_POSITIONS[lane_index]
	player_lane_offset = move_toward(
		player_lane_offset, target_lane_offset, LANE_CHANGE_SPEED * delta
	)
	var track_pose: Dictionary = _get_pose_at_path_distance(
		player_path_distance, player_lane_offset
	)
	if track_pose.is_empty():
		return

	var target_heading := float(track_pose.get("heading", player_heading))

	# Apply control profile's steering influence
	var steering_influence = control_profile.get_steering_influence(player_heading, target_heading)
	var player_steering = 0.0

	if control_profile is SmoothSteeringController:
		player_steering = (control_profile as SmoothSteeringController).get_steering_angle()
	elif control_profile is ThrottleSteeringController:
		player_steering = (control_profile as ThrottleSteeringController).get_steering_angle()

	# Blend steering: auto-steer influence + player input
	var blended_heading = player_heading
	if steering_influence > 0.0:
		blended_heading = lerp_angle(
			player_heading, target_heading, steering_influence * delta * 4.0
		)
	if player_steering != 0.0:
		blended_heading += player_steering * (1.0 - steering_influence) * delta

	player_heading = blended_heading
	player.position = track_pose.get("position", player.position) as Vector3

	# Apply heading rotation to vehicle so it visually faces forward on the track
	var tilt_angle = float(lane_index - 1) * -0.14
	vehicle_anchor.rotation.z = lerp_angle(vehicle_anchor.rotation.z, tilt_angle, delta * 9.0)
	# Model is imported facing -Z by default; add 90deg shift so heading vector matches path forward.
	vehicle_anchor.rotation.y = player_heading - PI / 2


func _load_group(group_name: String) -> void:
	current_entries = content_loader.load_word_entries(group_name)
	current_entry_index = -1
	settings["word_group"] = group_name
	settings_store.save_settings(settings)
	hud.set_word_group(group_name)
	if current_entries.is_empty():
		state = "error"
		hud.set_status("No single-word clips found in %s" % group_name)
		hud.flash_feedback("Expected simple word clips like cat.wav", Color(1.0, 0.5, 0.4))
		shared_track_layout = null
		return

	_rebuild_shared_track_layout()


func _rebuild_shared_track_layout() -> void:
	if track_generator == null or current_entries.is_empty():
		shared_track_layout = null
		return

	var word_gap_cells: int = max(1, int(round(WORD_GAP / SEGMENT_SPACING)))
	shared_track_layout = (
		track_generator
		. generate_loop_layout(
			current_entries,
			{
				"word_gap_cells": word_gap_cells,
				"cell_world_length": SEGMENT_SPACING,
				"start_slots": 8,
				"checkpoint_count": 4,
			}
		)
	)

	var budget: Dictionary = shared_track_layout.metadata.get("budget", {}) as Dictionary
	course_length = max(course_length, float(budget.get("required_world_length", course_length)))
	print(
		(
			"[ReadingMode] Shared loop layout prepared: path=%d grid=%s required_cells=%s"
			% [
				shared_track_layout.path_cells.size(),
				str(shared_track_layout.metadata.get("grid_size", Vector3i.ZERO)),
				str(budget.get("required_cells", 0)),
			]
		)
	)


func _start_next_word(
	play_feedback: bool, use_countdown: bool = false, reset_position: bool = false
) -> void:
	if current_entries.is_empty():
		return

	current_entry_index = (current_entry_index + 1) % current_entries.size()
	current_entry = current_entries[current_entry_index]
	next_spawn_entry_index = (current_entry_index + 1) % current_entries.size()

	var word_anchor: Dictionary = _get_word_anchor(current_entry_index)
	current_word_start_x = _path_index_to_distance(int(word_anchor.get("start_index", 0)))

	_reset_word_state(reset_position, use_countdown)
	hud.set_word(str(current_entry.get("text", "")))
	hud.set_phoneme("")
	if play_feedback:
		hud.flash_feedback("Next word", Color(0.45, 0.75, 1.0))
	var clear_existing := current_entry_index == 0
	_spawn_course_for_entry(current_entry, current_word_start_x, clear_existing)
	phoneme_player.play_word(content_loader.get_word_stream(current_entry))
	_update_status()


func _restart_current_word() -> void:
	if current_entry.is_empty():
		return

	_reset_word_state(true, true)
	hud.set_phoneme("")
	_spawn_course_for_entry(current_entry, current_word_start_x, true)
	phoneme_player.play_word(content_loader.get_word_stream(current_entry))
	_update_status()


func _reset_word_state(reset_position: bool = false, use_countdown: bool = true) -> void:
	if reset_position:
		lane_index = 1
		player_lane_offset = 0.0
		player_path_distance = current_word_start_x - WORD_START_OFFSET
		var reset_pose: Dictionary = _get_pose_at_path_distance(
			player_path_distance, player_lane_offset
		)
		player.position = reset_pose.get("position", Vector3.ZERO) as Vector3
		player_heading = float(reset_pose.get("heading", 0.0))
	next_target_index = 0
	slowed_timer = 0.0
	completion_timer = 0.0
	countdown_remaining = 3.0
	if use_countdown:
		state = "countdown"
	else:
		state = "playing"
	phoneme_player.stop_phoneme()


func _spawn_course_for_entry(
	entry: Dictionary,
	_word_start_x: float,
	clear_existing: bool = true,
	register_pickups: bool = true
) -> void:
	if shared_track_layout == null:
		return

	# When changing words we only want to reset the active pickups/obstacles, but we keep the
	# previously spawned world geometry so the course feels continuous.
	# Old spawned objects will be pruned as the player moves forward.
	if clear_existing:
		for child in spawn_root.get_children():
			child.queue_free()
		# Reset the base course so the new word feels like a fresh run.
		course_length = 120.0
		finish_line_x = 0.0
		farthest_spawned_x = 0.0
		if not current_entries.is_empty():
			next_spawn_entry_index = (current_entry_index + 1) % current_entries.size()
		else:
			next_spawn_entry_index = 0
		_build_course_geometry()

	if register_pickups:
		pickup_triggers.clear()
		obstacle_triggers.clear()

	var word_anchor: Dictionary = _get_word_anchor(current_entry_index)
	if word_anchor.is_empty():
		return
	var start_index: int = int(word_anchor.get("start_index", 0))
	var letters: Array = entry.get("letters", []) as Array
	var finish_index: int = _wrap_path_index(int(word_anchor.get("end_index", 0)) + 1)
	finish_line_x = _path_index_to_distance(finish_index)
	current_word_start_x = _path_index_to_distance(start_index)
	var spawn_msg = "[ReadingMode] Spawning %d letters at path index %d"
	print(spawn_msg % [letters.size(), start_index])

	for letter_index in range(letters.size()):
		var path_index := _wrap_path_index(start_index + letter_index)
		var path_frame: Dictionary = _get_path_frame(path_index)
		var segment_pos: Vector3 = path_frame.get("center", Vector3.ZERO) as Vector3
		var segment_heading := float(path_frame.get("heading", 0.0))

		# Create pickup trigger
		var pickup_trigger = ReadingPickupTrigger.new()
		pickup_trigger.position = segment_pos + Vector3(0.0, 2.3, 0.0)
		pickup_trigger.rotation.y = segment_heading
		pickup_trigger.word_index = current_entry_index
		pickup_trigger.letter_index = letter_index
		pickup_trigger.letter = str(letters[letter_index])
		pickup_trigger.phoneme_label = content_loader.get_phoneme_label(entry, letter_index)
		pickup_trigger.trigger_width = PICKUP_RADIUS_X * 2
		pickup_trigger.trigger_depth = PICKUP_RADIUS_Z * 2
		spawn_root.add_child(pickup_trigger)
		await pickup_trigger.tree_entered
		var pickup_msg = "[ReadingMode] Spawned pickup for '%s' at path index %d"
		print(pickup_msg % [pickup_trigger.letter, path_index])

		# Add visual label to pickup
		var label_node = Label3D.new()
		label_node.text = str(letters[letter_index]).to_upper()
		label_node.font_size = 256
		label_node.modulate = Color(1.0, 0.75, 0.0)  # Golden color
		var light = OmniLight3D.new()
		light.omni_range = 8.0
		light.energy = 1.5
		pickup_trigger.add_child(label_node)
		pickup_trigger.add_child(light)

		pickup_trigger.pickup_triggered.connect(_on_pickup_triggered.bindv([pickup_trigger]))
		if register_pickups:
			pickup_triggers.append(pickup_trigger)

		# Spawn obstacles on both sides of the road
		for side in [-1, 1]:
			var obstacle_trigger = ReadingObstacleTrigger.new()
			var path_right: Vector3 = path_frame.get("right", Vector3.RIGHT) as Vector3
			obstacle_trigger.position = (
				segment_pos + path_right * side * LANE_WIDTH + Vector3(0.0, 0.6, 0.0)
			)
			obstacle_trigger.rotation.y = segment_heading
			obstacle_trigger.word_index = current_entry_index
			var side_factor = 0 if side == -1 else 1
			obstacle_trigger.obstacle_index = letter_index * 2 + side_factor
			spawn_root.add_child(obstacle_trigger)
			await obstacle_trigger.tree_entered
			var obst_msg = "[ReadingMode] Spawned obstacle at path index %d (side=%d)"
			print(obst_msg % [path_index, side])

			# Add visual model to obstacle
			var obstacle_visual := _instantiate_scene(OBSTACLE_MODEL_PATH)
			if obstacle_visual != null:
				obstacle_visual.scale = Vector3.ONE * 0.6
				obstacle_trigger.add_child(obstacle_visual)

			obstacle_trigger.obstacle_hit.connect(_on_obstacle_hit.bindv([obstacle_trigger]))
			if register_pickups:
				obstacle_triggers.append(obstacle_trigger)

	# Create finish gate trigger
	if register_pickups:
		if finish_gate_trigger:
			finish_gate_trigger.queue_free()
		finish_gate_trigger = ReadingFinishGateTrigger.new()
		var finish_frame: Dictionary = _get_path_frame(finish_index)
		finish_gate_trigger.position = (
			finish_frame.get("center", Vector3.ZERO) as Vector3 + Vector3(0.0, 1.0, 0.0)
		)
		finish_gate_trigger.rotation.y = float(finish_frame.get("heading", 0.0))
		finish_gate_trigger.word_index = current_entry_index
		finish_gate_trigger.trigger_width = SEGMENT_SPACING
		finish_gate_trigger.trigger_depth = LANE_WIDTH * 2
		spawn_root.add_child(finish_gate_trigger)
		await finish_gate_trigger.tree_entered
		finish_gate_trigger.finish_gate_reached.connect(
			_on_finish_reached.bindv([finish_gate_trigger])
		)
		var finish_visual := _instantiate_scene(FINISH_MODEL_PATH)
		if finish_visual != null:
			finish_visual.scale = Vector3.ONE * ROAD_SCALE
			finish_visual.rotation_degrees = Vector3(0.0, 90.0, 0.0)
			finish_gate_trigger.add_child(finish_visual)
		print("[ReadingMode] Spawned finish gate trigger at path index %d" % finish_index)

	next_word_start_x = _path_index_to_distance(
		finish_index + int(round(WORD_GAP / SEGMENT_SPACING))
	)
	farthest_spawned_x = max(farthest_spawned_x, finish_line_x)

	_update_grid()


func _build_course_geometry() -> void:
	# Clear all existing grid cells
	for child in road.get_children():
		child.queue_free()
	grid_cells.clear()

	# Measure the track tile dimensions
	track_tile_length = SEGMENT_SPACING
	track_tile_width = SEGMENT_SPACING
	var track_sample: Node3D = _instantiate_scene(ROAD_MODEL_PATH)
	if track_sample != null:
		var mesh_instance := _find_first_mesh_instance(track_sample)
		if mesh_instance != null:
			track_tile_length = mesh_instance.get_aabb().size.x
			track_tile_width = mesh_instance.get_aabb().size.z
		track_sample.queue_free()

	# Apply scale
	track_tile_length *= ROAD_SCALE
	track_tile_width *= ROAD_SCALE
	if shared_track_layout != null:
		layout_origin = Vector3(
			-float(shared_track_layout.size.x) * track_tile_length * 0.5,
			0.0,
			-float(shared_track_layout.size.z) * track_tile_width * 0.5
		)
		var layout_dict: Dictionary = shared_track_layout.to_dictionary()
		layout_cell_entries = layout_dict.get("cells", []) as Array

	# Build the initial grid around the player
	_update_grid()


func _update_grid() -> void:
	if shared_track_layout == null:
		return

	var desired_tiles: Dictionary = {}
	for cell_entry in layout_cell_entries:
		var cell: Vector3i = cell_entry.get("cell", Vector3i.ZERO) as Vector3i
		var cell_data: Dictionary = cell_entry.get("data", {}) as Dictionary
		var world_pos := _cell_to_world_center(cell)
		if not _is_point_in_stream_window(world_pos):
			continue
		var key := "%d,%d,%d" % [cell.x, cell.y, cell.z]
		desired_tiles[key] = {"cell": cell, "data": cell_data}

	var tiles_to_remove: Array = []
	for key in grid_cells.keys():
		if not desired_tiles.has(key):
			tiles_to_remove.append(key)

	for key in tiles_to_remove:
		if is_instance_valid(grid_cells[key]):
			grid_cells[key].queue_free()
		grid_cells.erase(key)

	for key in desired_tiles.keys():
		if grid_cells.has(key):
			continue
		var tile_request: Dictionary = desired_tiles[key] as Dictionary
		_spawn_grid_cell(
			tile_request.get("cell", Vector3i.ZERO) as Vector3i,
			tile_request.get("data", {}) as Dictionary,
			str(key)
		)


func _spawn_grid_cell(cell: Vector3i, cell_data: Dictionary, key: String) -> void:
	var cell_node: Node3D = null
	var scene_path := str(cell_data.get("scene_path", ""))
	if scene_path.is_empty():
		return
	cell_node = _instantiate_scene(scene_path)
	if cell_node != null:
		cell_node.scale = Vector3.ONE * ROAD_SCALE
		cell_node.rotation_degrees = Vector3(0.0, float(cell_data.get("rotation_y", 0.0)), 0.0)
		cell_node.position = _cell_to_world_center(cell)
		road.add_child(cell_node)

	if cell_node != null:
		grid_cells[key] = cell_node


func _cleanup_spawned_content() -> void:
	pass


func _ensure_words_ahead() -> void:
	pass


func _attach_player_model() -> void:
	for child in vehicle_anchor.get_children():
		child.queue_free()

	var model := _instantiate_scene(PLAYER_MODEL_PATH)
	if model == null:
		return

	# Increase the car size so the player is more visible and feels closer to the camera.
	model.scale = Vector3.ONE * 1.8
	# Rotate the vehicle to face forward.
	model.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	# Lower the vehicle so it sits closer to the road.
	vehicle_anchor.position = Vector3(0.0, 0.05, 0.0)
	vehicle_anchor.add_child(model)


func _instantiate_scene(resource_path: String) -> Node3D:
	if not ResourceLoader.exists(resource_path):
		return null
	var packed_scene := load(resource_path) as PackedScene
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node3D


func _pick_decoration_path() -> String:
	# Weighted selection: empty decorations are more common.
	var total_weight := 0
	for deco in DECORATION_MODELS:
		total_weight += int(deco.weight)

	var roll := rng.randi_range(1, total_weight)
	for deco in DECORATION_MODELS:
		roll -= int(deco.weight)
		if roll <= 0:
			return str(deco.path)

	# Fallback in case weights are broken.
	return DECORATION_MODEL_PATH


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found
	return null


func _check_pickups() -> void:
	# Replaced by collision trigger system - kept for compatibility
	pass


func _on_pickup_triggered(
	_letter_index: int, _letter: String, _phoneme_label: String, trigger: ReadingPickupTrigger
) -> void:
	if trigger.word_index != current_entry_index:
		return
	if trigger.letter_index != next_target_index:
		# Wrong letter - skip it and mark as missed
		var phoneme_label = trigger.phoneme_label
		var phoneme_stream = content_loader.get_phoneme_stream(phoneme_label)
		phoneme_player.stop_phoneme()
		phoneme_player.play_looping_phoneme(phoneme_label, phoneme_stream)
		hud.flash_feedback("Missed %s" % trigger.letter.to_upper(), Color(1.0, 0.48, 0.38))
		return

	# Correct letter - play phoneme
	phoneme_player.stop_phoneme()
	var phoneme_stream = content_loader.get_phoneme_stream(trigger.phoneme_label)
	phoneme_player.play_looping_phoneme(trigger.phoneme_label, phoneme_stream)
	hud.flash_feedback(trigger.letter.to_upper(), Color(1.0, 0.94, 0.45))
	next_target_index += 1


func _check_obstacles() -> void:
	# Replaced by collision trigger system - kept for compatibility
	pass


func _on_obstacle_hit(_obstacle_index: int, trigger: ReadingObstacleTrigger) -> void:
	if trigger.word_index != current_entry_index:
		return
	slowed_timer = trigger.penalty_seconds
	hud.flash_feedback("Bump", Color(1.0, 0.42, 0.32))


func _check_finish_gate() -> void:
	# Replaced by collision trigger system - kept for compatibility
	pass


func _on_finish_reached(trigger: ReadingFinishGateTrigger) -> void:
	if trigger.word_index != current_entry_index:
		return
	_complete_word()


func _update_triggers() -> void:
	# This method is called each frame to check trigger states
	# Actual triggering happens via Area3D signals, this is for updates only
	if finish_gate_trigger:
		finish_gate_trigger.set_pickups_collected(next_target_index >= pickup_triggers.size())


func _complete_word() -> void:
	state = "transition"
	completion_timer = 2.0
	phoneme_player.stop_phoneme()
	phoneme_player.play_word(content_loader.get_word_stream(current_entry))
	hud.set_status("Great job")
	hud.flash_feedback("%s" % str(current_entry.get("text", "")).to_upper(), Color(0.45, 1.0, 0.55))


func _update_camera(delta: float) -> void:
	if camera_controller:
		var pose := _get_pose_at_path_distance(player_path_distance, player_lane_offset)
		if pose.is_empty():
			return

		var target_position := (
			(pose.get("position", player.position) as Vector3) + Vector3(0.0, 1.5, 0.0)
		)
		var path_heading := float(pose.get("heading", player_heading))
		var camera_angle := 270.0 - rad_to_deg(path_heading)

		camera_controller.set_target(target_position)
		camera_controller.set_horizontal_angle(camera_angle)
		camera_controller.set_vertical_angle(-20.0)
		camera_controller.update(delta)


func _update_status() -> void:
	if current_entry.is_empty():
		return
	var total_letters := pickup_triggers.size()
	var target_text := (
		"Complete"
		if next_target_index >= total_letters
		else "Next: %s" % str(current_entry.get("letters", [])[next_target_index]).to_upper()
	)
	var mode_text := control_profile.mode_name.capitalize() if control_profile else "Unknown"
	hud.set_status("%s   %d/%d   %s" % [target_text, next_target_index, total_letters, mode_text])


func _toggle_options() -> void:
	if state == "error":
		return
	if hud.is_options_open():
		_close_options()
	else:
		state_before_pause = state
		state = "paused"
		hud.show_options()
		hud.set_status("Options")


func _close_options() -> void:
	if not hud.is_options_open():
		return
	hud.hide_options()
	state = state_before_pause
	_update_status()


func _on_control_mode_changed(mode_name: String) -> void:
	settings["control_mode"] = mode_name
	settings_store.save_settings(settings)
	_set_control_profile(mode_name)
	_update_help_text()
	hud.flash_feedback("Controls: %s" % mode_name.capitalize(), Color(0.55, 0.85, 1.0))
	_update_status()


func _on_word_group_changed(group_name: String) -> void:
	_load_group(group_name)
	if state != "error":
		_start_next_word(false)
		hud.flash_feedback("Word group: %s" % group_name, Color(0.8, 0.92, 1.0))


func _on_volume_changed(volume: float) -> void:
	settings["master_volume"] = volume
	settings_store.save_settings(settings)
	settings_store.apply_master_volume(volume)


func _on_phoneme_changed(label: String) -> void:
	hud.set_phoneme(label)


func _update_help_text() -> void:
	if not control_profile:
		hud.set_help("Left/Right or A/D to switch lanes   Esc/Tab: options")
		return

	if control_profile is LaneChangeController:
		hud.set_help("Left/Right or A/D to switch lanes   Esc/Tab: options")
	elif control_profile is SmoothSteeringController:
		hud.set_help("Left/Right or A/D to steer smoothly   Esc/Tab: options")
	elif control_profile is ThrottleSteeringController:
		hud.set_help("Arrow keys/WASD to steer and throttle   Esc/Tab: options")
	else:
		hud.set_help("Left/Right or A/D to switch lanes   Esc/Tab: options")
