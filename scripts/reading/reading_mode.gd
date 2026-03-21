extends Node3D
# gdlint: disable=max-file-lines

const CameraController3DClass = preload("res://scripts/reading/CameraController3D.gd")
const MovementSystem = preload("res://scripts/reading/systems/MovementSystem.gd")
const MapDisplayManager = preload("res://scripts/reading/systems/MapDisplayManager.gd")
const GameplayController = preload("res://scripts/reading/systems/GameplayController.gd")

# Grid layout constants
const GRID_WIDTH := 7  # Z-axis: 7 columns (decorations + 1 road + decorations)
const GRID_AHEAD := 10  # X-axis: 10 rows ahead of camera
const GRID_BEHIND := 3  # X-axis: 3 rows behind camera
const GRID_DEPTH := GRID_AHEAD + GRID_BEHIND  # Total 13 rows
const GRID_CENTER_START := 3  # Column where the road is (col 3, centered)
const GRID_CENTER_END := 3  # Last center column (inclusive)

const LANE_WIDTH := 4
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
@export var debug_draw_path: bool = true

# Systems (separation of concerns)
var movement_system: MovementSystem = null
var map_display_manager: MapDisplayManager = null
var gameplay_controller: GameplayController = null

# Member variables
var track_generator: TrackGenerator
var settings_store := ReadingSettingsStore.new()
var content_loader := ReadingContentLoader.new()
var camera_controller = null  # CameraController3D instance

var settings: Dictionary = {}
var available_groups: Array[String] = []
var current_entries: Array[Dictionary] = []
var current_entry: Dictionary = {}
var current_entry_index := -1

# Game state
var state := "loading"
var state_before_pause := "countdown"
var countdown_remaining := 3.0
var completion_timer := 0.0
var course_length := 120.0
var finish_line_x := 0.0
var farthest_spawned_x := 0.0

# Track layout data
var shared_track_layout: Variant = null
var track_tile_length := 0.0
var track_tile_width := 0.0
var layout_origin := Vector3.ZERO

# Word progression state
var current_word_start_x := WORD_START_X
var next_word_start_x := WORD_START_X
var next_spawn_entry_index := 0

@onready var road: Node3D = $Road
@onready var spawn_root: Node3D = $SpawnRoot
@onready var player: Node3D = $Player
@onready var vehicle_anchor: Node3D = $Player/VehicleAnchor
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var hud: ReadingHUD = $ReadingHUD
@onready var phoneme_player: PhonemePlayer = $PhonemePlayer
@onready var control_profile: ControlProfile = null


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


func _catmull_rom_point(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	# Smooth interpolation across 4 control points
	var t2 = t * t
	var t3 = t2 * t
	return (
		0.5
		* (
			(2.0 * p1)
			+ (p2 - p0) * t
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
		)
	)


func _catmull_rom_tangent(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	# Derivative for heading direction
	var t2 = t * t
	return (
		0.5
		* (
			(p2 - p0)
			+ (4.0 * p0 - 10.0 * p1 + 8.0 * p2 - 2.0 * p3) * t
			+ (-3.0 * p0 + 9.0 * p1 - 9.0 * p2 + 3.0 * p3) * t2
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


func _get_max_lane_offset() -> float:
	if track_tile_width > 0.0:
		return min(LANE_WIDTH, (track_tile_width * 0.5) - 1.0)
	return LANE_WIDTH


func _get_pose_at_path_distance(path_distance: float, lane_offset: float) -> Dictionary:
	var path_count := _get_layout_path_count()
	if path_count <= 0 or track_tile_length <= 0.0:
		return {}

	var loop_length := float(path_count) * track_tile_length
	var wrapped_distance := fposmod(path_distance, loop_length)
	if wrapped_distance < 0.0:
		wrapped_distance += loop_length

	var lane_offset_clamped: float = clamp(
		lane_offset, -_get_max_lane_offset(), _get_max_lane_offset()
	)
	var segment_float := wrapped_distance / track_tile_length
	var segment_index := int(floor(segment_float))
	var segment_progress := segment_float - float(segment_index)

	# Build smooth point via Catmull-Rom interpolation across neighboring path cells
	var prev_cell := _get_path_cell(segment_index - 1)
	var current_cell := _get_path_cell(segment_index)
	var next_cell := _get_path_cell(segment_index + 1)
	var next_next_cell := _get_path_cell(segment_index + 2)

	var p0 := _cell_to_world_center(prev_cell)
	var p1 := _cell_to_world_center(current_cell)
	var p2 := _cell_to_world_center(next_cell)
	var p3 := _cell_to_world_center(next_next_cell)
	var center := _catmull_rom_point(p0, p1, p2, p3, segment_progress)
	var tangent := _catmull_rom_tangent(p0, p1, p2, p3, segment_progress)
	if tangent.length_squared() == 0.0:
		# Fallback to linear segment direction
		var fallback_forward := (p2 - p1).normalized()
		if fallback_forward.length_squared() == 0.0:
			fallback_forward = Vector3.RIGHT
		var right = Vector3(-fallback_forward.z, 0.0, fallback_forward.x)
		return {
			"center": center,
			"position": center + right * lane_offset_clamped,
			"right": right,
			"heading": atan2(fallback_forward.z, fallback_forward.x),
			"segment_index": segment_index,
			"segment_progress": segment_progress,
		}

	var forward := tangent.normalized()
	if forward.length_squared() == 0.0:
		forward = Vector3.RIGHT
	var right := Vector3(-forward.z, 0.0, forward.x)

	return {
		"center": center,
		"position": center + right * lane_offset_clamped,
		"forward": forward,
		"right": right,
		"heading": atan2(forward.z, forward.x),
		"segment_index": segment_index,
		"segment_progress": segment_progress,
	}


func _get_word_anchor(word_index: int) -> Dictionary:
	if shared_track_layout == null:
		return {}
	if word_index < 0 or word_index >= shared_track_layout.word_anchors.size():
		return {}
	return shared_track_layout.word_anchors[word_index] as Dictionary


func _ready() -> void:
	print("[ReadingMode._ready] Starting initialization...")
	ReadingControlProfile.ensure_input_actions()
	settings = settings_store.load_settings()
	var debug_draw_path = bool(settings.get("debug_draw_path", true))
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
	hud.set_debug_path(debug_draw_path)
	hud.control_mode_changed.connect(_on_control_mode_changed)
	hud.word_group_changed.connect(_on_word_group_changed)
	hud.volume_changed.connect(_on_volume_changed)
	hud.debug_path_toggled.connect(_on_debug_path_toggled)
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
	_create_control_profile(control_mode)
	print("[ReadingMode] Control profile set to: %s" % control_mode)

	# Initialize Movement System
	movement_system = MovementSystem.new(control_profile)
	print("[ReadingMode] MovementSystem initialized")

	_update_help_text()
	_attach_player_model()
	player.add_to_group("player")  # For trigger detection
	print("[ReadingMode] Player model attached and added to 'player' group")
	_load_group(requested_group)

	# Initialize Map Display Manager early so _build_course_geometry can signal into it
	map_display_manager = MapDisplayManager.new()
	map_display_manager.set_nodes(road, spawn_root)
	map_display_manager.stream_tiles_each_side = stream_tiles_each_side
	map_display_manager.stream_tiles_ahead = stream_tiles_ahead
	map_display_manager.stream_tiles_behind = stream_tiles_behind
	print("[ReadingMode] MapDisplayManager initialized")

	_build_course_geometry()
	print("[ReadingMode] Course geometry built")

	map_display_manager.update_debug_visualization(
		debug_draw_path, Callable(self, "_get_pose_at_path_distance"), track_tile_length
	)

	# Initialize Gameplay Controller
	gameplay_controller = GameplayController.new(content_loader)
	gameplay_controller.set_spawn_root(spawn_root)
	gameplay_controller.pickup_collected.connect(_on_gameplay_pickup_collected)
	gameplay_controller.obstacle_hit.connect(_on_gameplay_obstacle_hit)
	gameplay_controller.word_completed.connect(_on_gameplay_word_completed)
	print("[ReadingMode] GameplayController initialized")

	# Initialize camera controller
	camera_controller = CameraController3DClass.new()
	add_child(camera_controller)
	camera_controller.attach_camera(camera)
	camera_controller.set_smoothing_factor(0.15)  # Smooth camera movement around corners
	camera_controller.set_distance(15.0)
	camera_controller.set_vertical_angle(-30.0)  # Look down at the car
	camera_controller.focus_on(player.position, 15.0)
	print("[ReadingMode] Camera controller initialized with smoothing")

	# Start the first word in playing mode to avoid perceived 'no movement' startup wait
	_start_next_word(false, false, true)
	print("[ReadingMode] Initialization complete!")


func _unhandled_input(event: InputEvent) -> void:
	# Allow camera controller to handle input first
	if camera_controller and camera_controller.handle_input(event):
		return

	# Delegate input to movement system
	if movement_system:
		movement_system.handle_input(event)

	if event.is_action_pressed(ReadingControlProfile.ACTION_TOGGLE_OPTIONS):
		_toggle_options()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		var debug_draw_path = not bool(settings.get("debug_draw_path", true))
		settings["debug_draw_path"] = debug_draw_path
		settings_store.save_settings(settings)
		if map_display_manager:
			map_display_manager.update_debug_visualization(
				debug_draw_path, Callable(self, "_get_pose_at_path_distance"), track_tile_length
			)
		var status_text := "ON" if debug_draw_path else "OFF"
		hud.set_help("F10 toggles path debug - %s" % status_text)
		hud.flash_feedback("Path debug %s" % status_text, Color(0.4, 0.9, 0.4))
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


func _create_control_profile(mode_name: String) -> void:
	# Create appropriate control profile based on mode
	match mode_name:
		"smooth_steering":
			control_profile = SmoothSteeringController.new()
		"throttle_steering":
			control_profile = ThrottleSteeringController.new()
		_:
			# Default to lane change for "lane_change" or any unknown mode
			control_profile = LaneChangeController.new()

	# Update movement system with new profile
	if movement_system:
		movement_system.set_control_profile(control_profile)


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

		# Always keep map tiles visible while waiting for countdown end.
		if map_display_manager and movement_system:
			map_display_manager.update_visible_cells(
				player.position, movement_system.player_heading
			)
			_ensure_road_ahead()

		_update_camera(delta)
		return

	if state == "transition":
		completion_timer -= delta
		if completion_timer <= 0.0:
			_start_next_word(true, false, false)
		# allow the player to keep moving into the empty area

	# Update movement system
	movement_system.update(delta)

	# Get track pose for current path distance
	var track_pose := _get_pose_at_path_distance(
		movement_system.player_path_distance, movement_system.player_lane_offset
	)

	# Update player heading and position
	movement_system.update_position_and_heading(delta, track_pose)

	# Update player visuals
	player.position = movement_system.get_player_position(track_pose)
	var player_basis = movement_system.get_player_basis()
	vehicle_anchor.global_transform = Transform3D(player_basis, player.position)

	# Update map display
	if map_display_manager:
		map_display_manager.update_visible_cells(player.position, movement_system.player_heading)

	# Update gameplay triggers
	if gameplay_controller:
		gameplay_controller.update_finish_gate_state()

	_ensure_road_ahead()
	_update_status()
	_update_camera(delta)


func _ensure_road_ahead() -> void:
	if map_display_manager:
		var active_tiles_count = map_display_manager.grid_cells.size()
		print(
			(
				"[ReadingMode._ensure_road_ahead] path_distance=%.1f active_tiles=%d"
				% [movement_system.player_path_distance, active_tiles_count]
			)
		)
	_cleanup_spawned_content()
	_ensure_words_ahead()


# Movement update now handled by MovementSystem


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
	if map_display_manager:
		_build_course_geometry()


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
	if map_display_manager and movement_system:
		map_display_manager.update_visible_cells(player.position, movement_system.player_heading)
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
	if reset_position and movement_system:
		var path_distance_offset = current_word_start_x - WORD_START_OFFSET
		movement_system.reset(true, path_distance_offset)
		var reset_pose: Dictionary = _get_pose_at_path_distance(
			movement_system.player_path_distance, movement_system.player_lane_offset
		)
		player.position = reset_pose.get("position", Vector3.ZERO) as Vector3
		# Initialize vehicle anchor to the exact target heading to prevent snap correction
		var heading = float(reset_pose.get("heading", 0.0))
		vehicle_anchor.rotation = Vector3(0.0, heading + PI / 2, 0.0)

	if gameplay_controller:
		gameplay_controller.reset()

	completion_timer = 0.0
	countdown_remaining = 3.0
	if use_countdown:
		state = "countdown"
	else:
		state = "playing"
	phoneme_player.stop_phoneme()


func _spawn_course_for_entry(
	entry: Dictionary,
	_unused_word_start_x: float,
	clear_existing: bool = true,
	register_pickups: bool = true
) -> void:
	if shared_track_layout == null or not gameplay_controller:
		return

	# When changing words, reset active pickups/obstacles but keep geometry (continuous feel)
	if clear_existing:
		for child in spawn_root.get_children():
			child.queue_free()
		# Reset the base course so the new word feels like a fresh run
		course_length = 120.0
		finish_line_x = 0.0
		farthest_spawned_x = 0.0
		if not current_entries.is_empty():
			next_spawn_entry_index = (current_entry_index + 1) % current_entries.size()
		else:
			next_spawn_entry_index = 0
		_build_course_geometry()

	# Load entry into gameplay controller
	gameplay_controller.load_entry(entry, current_entry_index)

	var word_anchor: Dictionary = _get_word_anchor(current_entry_index)
	if word_anchor.is_empty():
		return

	# Spawn pickups and obstacles via gameplay controller
	var get_path_frame_callable = Callable(self, "_get_path_frame")
	var path_wrap_callable = Callable(self, "_wrap_path_index")
	gameplay_controller.spawn_course_pickups_and_obstacles(
		word_anchor, get_path_frame_callable, path_wrap_callable, register_pickups
	)

	# Update word progression state
	var start_index: int = int(word_anchor.get("start_index", 0))
	var finish_index: int = path_wrap_callable.call(int(word_anchor.get("end_index", 0)) + 1)
	finish_line_x = _path_index_to_distance(finish_index)
	current_word_start_x = _path_index_to_distance(start_index)

	next_word_start_x = _path_index_to_distance(
		finish_index + int(round(WORD_GAP / SEGMENT_SPACING))
	)
	farthest_spawned_x = max(farthest_spawned_x, finish_line_x)


func _build_course_geometry() -> void:
	# Clear all existing grid cells via map display manager
	if map_display_manager:
		map_display_manager.clear_all_cells()

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

	# Update map display manager with dimensions
	if map_display_manager:
		map_display_manager.set_layout_data(
			shared_track_layout, layout_origin, track_tile_length, track_tile_width
		)


# Grid visualization now handled by MapDisplayManager

# Grid management now handled by MapDisplayManager

# Removed - now handled by MapDisplayManager


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
	# Model orientation is handled by the vehicle_anchor heading, no pre-rotation.
	model.rotation_degrees = Vector3.ZERO
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


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found
	return null


# Old trigger methods removed - now handled by GameplayController


func _complete_word() -> void:
	state = "transition"
	completion_timer = 2.0
	phoneme_player.stop_phoneme()
	phoneme_player.play_word(content_loader.get_word_stream(current_entry))
	hud.set_status("Great job")
	hud.flash_feedback("%s" % str(current_entry.get("text", "")).to_upper(), Color(0.45, 1.0, 0.55))


func _update_camera(delta: float) -> void:
	if camera_controller and movement_system:
		var pose := _get_pose_at_path_distance(
			movement_system.player_path_distance, movement_system.player_lane_offset
		)
		if pose.is_empty():
			return

		var target_position := (
			(pose.get("position", player.position) as Vector3) + Vector3(0.0, 1.5, 0.0)
		)
		var path_heading := float(pose.get("heading", movement_system.player_heading))
		var camera_angle := 270.0 - rad_to_deg(path_heading)

		camera_controller.set_target(target_position)
		camera_controller.set_horizontal_angle(camera_angle)
		camera_controller.set_vertical_angle(-20.0)
		camera_controller.update(delta)


func _update_status() -> void:
	if current_entry.is_empty() or not gameplay_controller:
		return
	var total_letters: int = gameplay_controller.get_total_letters()
	var target_text := (
		"Complete"
		if gameplay_controller.is_word_complete()
		else "Next: %s" % gameplay_controller.get_next_target_letter()
	)
	var mode_text := control_profile.mode_name.capitalize() if control_profile else "Unknown"
	var status_format = "%s   %d/%d   %s"
	hud.set_status(
		(
			status_format
			% [target_text, gameplay_controller.next_target_index, total_letters, mode_text]
		)
	)


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
	_create_control_profile(mode_name)
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


func _on_debug_path_toggled(enabled: bool) -> void:
	var debug_draw_path = enabled
	settings["debug_draw_path"] = enabled
	settings_store.save_settings(settings)
	if map_display_manager:
		map_display_manager.update_debug_visualization(
			debug_draw_path, Callable(self, "_get_pose_at_path_distance"), track_tile_length
		)
	var status_text := "ON" if enabled else "OFF"
	hud.flash_feedback("Path debug %s" % status_text, Color(0.4, 0.9, 0.4))


func _on_phoneme_changed(label: String) -> void:
	hud.set_phoneme(label)


# ============ Gameplay System Signal Handlers ============


func _on_gameplay_pickup_collected(letter: String, phoneme_label: String) -> void:
	var phoneme_stream = content_loader.get_phoneme_stream(phoneme_label)
	phoneme_player.stop_phoneme()
	phoneme_player.play_looping_phoneme(phoneme_label, phoneme_stream)
	hud.flash_feedback(letter, Color(1.0, 0.94, 0.45))


func _on_gameplay_obstacle_hit(duration: float) -> void:
	movement_system.apply_slowdown(duration)
	hud.flash_feedback("Bump", Color(1.0, 0.42, 0.32))


func _on_gameplay_word_completed() -> void:
	_complete_word()


func _update_help_text() -> void:
	if not control_profile:
		hud.set_help("Left/Right or A/D to switch lanes   Esc/Tab: options   F10: path debug")
		return

	if control_profile is LaneChangeController:
		hud.set_help("Left/Right or A/D to switch lanes   Esc/Tab: options   F10: path debug")
	elif control_profile is SmoothSteeringController:
		hud.set_help("Left/Right or A/D to steer smoothly   Esc/Tab: options")
	elif control_profile is ThrottleSteeringController:
		hud.set_help("Arrow keys/WASD to steer and throttle   Esc/Tab: options")
	else:
		hud.set_help("Left/Right or A/D to switch lanes   Esc/Tab: options")
