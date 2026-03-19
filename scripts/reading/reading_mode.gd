extends Node3D

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
const ROAD_TILES_AHEAD := 10
const ROAD_TILES_BEHIND := 2
const WORD_START_OFFSET := WORD_START_X - PLAYER_START_X
const ROAD_CLEAR_GAP := SEGMENT_SPACING

const PLAYER_MODEL_PATH := "res://models/vehicle-truck-yellow.glb"
const ROAD_MODEL_PATH := "res://models/track-straight.glb"
const ROAD_SCALE := 2.0
const OBSTACLE_MODEL_PATH := "res://models/track-bump.glb"
const FINISH_MODEL_PATH := "res://models/track-finish.glb"
const DECORATION_MODEL_PATH := "res://models/decoration-forest.glb"

var settings_store := ReadingSettingsStore.new()
var content_loader := ReadingContentLoader.new()
var control_profile := ReadingControlProfile.new()
var rng := RandomNumberGenerator.new()

var settings: Dictionary = {}
var available_groups: Array[String] = []
var current_entries: Array[Dictionary] = []
var current_entry: Dictionary = {}
var current_entry_index := -1

var pickups: Array[ReadingPickup] = []
var obstacles: Array[ReadingObstacle] = []

var lane_index := 1
var next_target_index := 0
var state := "loading"
var state_before_pause := "countdown"
var countdown_remaining := 3.0
var slowed_timer := 0.0
var completion_timer := 0.0
var course_length := 120.0
var finish_line_x := 0.0
var decoration_end_x := 0.0
var farthest_spawned_x := 0.0

var track_tile_length := 0.0
var road_tiles: Dictionary = {}
var min_tile_index := 0
var max_tile_index := -1
var current_tile_index := 0

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


func _ready() -> void:
	rng.randomize()
	ReadingControlProfile.ensure_input_actions()
	settings = settings_store.load_settings()
	settings_store.apply_master_volume(float(settings.get("master_volume", 0.8)))
	available_groups = content_loader.list_word_groups()
	if available_groups.is_empty():
		state = "error"
		hud.set_status("No audio/words groups were found.")
		hud.flash_feedback("Add word audio to res://audio/words/<group>", Color(1.0, 0.4, 0.3))
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

	control_profile.set_mode(
		str(settings.get("control_mode", ReadingSettingsStore.CONTROL_MODE_KEYBOARD))
	)
	_update_help_text()
	_attach_player_model()
	_load_group(requested_group)
	_build_course_geometry()
	_start_next_word(false, true, true)


func _unhandled_input(event: InputEvent) -> void:
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

	slowed_timer = maxf(slowed_timer - delta, 0.0)
	var lane_delta := control_profile.consume_lane_delta(delta)
	if lane_delta != 0:
		lane_index = clampi(lane_index + lane_delta, 0, LANE_POSITIONS.size() - 1)

	var speed := SLOWED_SPEED if slowed_timer > 0.0 else PLAYER_SPEED
	player.position.x += speed * delta
	player.position.z = move_toward(
		player.position.z, LANE_POSITIONS[lane_index], LANE_CHANGE_SPEED * delta
	)
	vehicle_anchor.rotation.z = lerp_angle(
		vehicle_anchor.rotation.z, float(lane_delta) * -0.14, delta * 9.0
	)

	_check_pickups()
	_check_obstacles()
	_ensure_road_ahead()
	_update_status()
	_update_camera(delta)


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


func _start_next_word(
	play_feedback: bool, use_countdown: bool = false, reset_position: bool = false
) -> void:
	if current_entries.is_empty():
		return

	current_entry_index = (current_entry_index + 1) % current_entries.size()
	current_entry = current_entries[current_entry_index]
	next_spawn_entry_index = (current_entry_index + 1) % current_entries.size()

	# Ensure the next word starts ahead of the player.
	# This provides a small empty area between words.
	var is_first_word := current_entry_index == 0
	if is_first_word:
		current_word_start_x = next_word_start_x
	else:
		var desired_start_x := player.position.x + WORD_GAP
		current_word_start_x = max(next_word_start_x, desired_start_x)

	_reset_word_state(reset_position, use_countdown)
	hud.set_word(str(current_entry.get("text", "")))
	hud.set_phoneme("")
	if play_feedback:
		hud.flash_feedback("Next word", Color(0.45, 0.75, 1.0))
	_spawn_course_for_entry(current_entry, current_word_start_x, is_first_word)
	_ensure_words_ahead()
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
		player.position = Vector3(
			current_word_start_x - WORD_START_OFFSET, 0.0, LANE_POSITIONS[lane_index]
		)
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
	word_start_x: float,
	clear_existing: bool = true,
	register_pickups: bool = true
) -> void:
	# When changing words we only want to reset the active pickups/obstacles, but we keep the
	# previously spawned world geometry so the course feels continuous.
	# Old spawned objects will be pruned as the player moves forward.
	if clear_existing:
		for child in spawn_root.get_children():
			child.queue_free()
		# Reset the base course so the new word feels like a fresh run.
		course_length = 120.0
		finish_line_x = 0.0
		decoration_end_x = 0.0
		farthest_spawned_x = 0.0
		if not current_entries.is_empty():
			next_spawn_entry_index = (current_entry_index + 1) % current_entries.size()
		else:
			next_spawn_entry_index = 0
		_build_course_geometry()

	if register_pickups:
		pickups.clear()
		obstacles.clear()

	var letters: Array = entry.get("letters", []) as Array
	var letter_count: float = maxf(float(letters.size()), 1.0)
	var word_end_x: float = word_start_x + letter_count * SEGMENT_SPACING
	var finish_x: float = word_end_x + 22.0
	finish_line_x = finish_x
	# Ensure the road extends far enough ahead of the player.
	var desired_course_end: float = max(finish_x + 8.0, player.position.x + MIN_ROAD_AHEAD)
	var new_course_length: float = max(course_length, desired_course_end)
	if new_course_length > course_length:
		course_length = new_course_length
		_extend_course_decorations()

	for letter_index in range(letters.size()):
		var lane_for_letter := rng.randi_range(0, LANE_POSITIONS.size() - 1)
		var segment_x := word_start_x + letter_index * SEGMENT_SPACING
		var pickup := ReadingPickup.new()
		pickup.position = Vector3(segment_x, 2.3, LANE_POSITIONS[lane_for_letter])
		pickup.configure(
			str(letters[letter_index]),
			content_loader.get_phoneme_label(entry, letter_index),
			letter_index,
			lane_for_letter
		)
		spawn_root.add_child(pickup)
		if register_pickups:
			pickups.append(pickup)

		for obstacle_lane in range(LANE_POSITIONS.size()):
			if obstacle_lane == lane_for_letter:
				continue
			var obstacle := ReadingObstacle.new()
			obstacle.position = Vector3(segment_x, 0.6, LANE_POSITIONS[obstacle_lane])
			obstacle.configure(letter_index, obstacle_lane)
			var obstacle_visual := _instantiate_scene(OBSTACLE_MODEL_PATH)
			if obstacle_visual != null:
				obstacle_visual.scale = Vector3.ONE * 0.6
				obstacle.add_child(obstacle_visual)
			spawn_root.add_child(obstacle)
			if register_pickups:
				obstacles.append(obstacle)

	var finish_visual := _instantiate_scene(FINISH_MODEL_PATH)
	if finish_visual != null:
		finish_visual.position = Vector3(finish_x, 0.0, 0.0)
		finish_visual.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		finish_visual.scale = Vector3.ONE * 2.0
		spawn_root.add_child(finish_visual)

	next_word_start_x = finish_x + WORD_GAP
	farthest_spawned_x = max(farthest_spawned_x, next_word_start_x)


func _build_course_geometry() -> void:
	for child in road.get_children():
		child.queue_free()

	road_tiles.clear()
	min_tile_index = 0
	max_tile_index = -1

	# Build the track using the straight track model rather than procedural lanes.
	track_tile_length = SEGMENT_SPACING
	var track_sample: Node3D = _instantiate_scene(ROAD_MODEL_PATH)
	if track_sample != null:
		# Attempt to infer length from the first mesh in the track scene.
		var mesh_instance := _find_first_mesh_instance(track_sample)
		if mesh_instance != null:
			track_tile_length = mesh_instance.get_aabb().size.x
		track_sample.queue_free()

	# Apply the requested scaling.
	track_tile_length *= ROAD_SCALE

	# Ensure we have enough segments to start with.
	_update_road_tiles(true)

	# Broaden the decoration coverage along the course so the sides feel continuous.
	var decoration_start_x := PLAYER_START_X + 6.0
	var decoration_step_x := 14.0
	# Place decorations well outside the road edge to avoid overlap with lanes.
	# (The models are fairly wide, so we offset beyond the road by a safe margin.)
	var side_z_base := LANE_WIDTH * 2.0 + 4.0
	var side_z_offsets := [side_z_base, side_z_base + 6.0, side_z_base + 12.0]

	var x := decoration_start_x
	while x < course_length + 36.0:
		for z_offset in side_z_offsets:
			for sign in [-1, 1]:
				var forest := _instantiate_scene(DECORATION_MODEL_PATH)
				if forest == null:
					continue
				forest.position = Vector3(x, 0.0, sign * z_offset)
				# Rotate forest tiles so they align better with the road and reduce overlap.
				forest.rotation_degrees = Vector3.ZERO
				forest.scale = Vector3.ONE * 1.0
				road.add_child(forest)
		x += decoration_step_x

	# Track how far we have added decorations so we can extend them incrementally.
	decoration_end_x = course_length + 36.0


func _ensure_road_ahead() -> void:
	_update_road_tiles()
	_cleanup_spawned_content()
	_ensure_words_ahead()


func _extend_course_decorations() -> void:
	# Ensure that side decorations extend as the course grows.
	var target_end_x := course_length + 36.0
	if target_end_x <= decoration_end_x:
		return

	var decoration_step_x := 14.0
	var side_z_base := LANE_WIDTH * 2.0 + 4.0
	var side_z_offsets := [side_z_base, side_z_base + 6.0, side_z_base + 12.0]

	var x: float = maxf(decoration_end_x, PLAYER_START_X + 6.0)
	while x < target_end_x:
		for z_offset in side_z_offsets:
			for sign in [-1, 1]:
				var forest := _instantiate_scene(DECORATION_MODEL_PATH)
				if forest == null:
					continue
				forest.position = Vector3(x, 0.0, sign * z_offset)
				forest.rotation_degrees = Vector3.ZERO
				forest.scale = Vector3.ONE * 1.0
				road.add_child(forest)
		x += decoration_step_x

	decoration_end_x = target_end_x


func _cleanup_spawned_content() -> void:
	# Remove pickups/obstacles/finish markers that are far behind the player.
	# This keeps the world feeling continuous without rebuilding the whole map.
	var clear_x := player.position.x - ROAD_CLEAR_GAP
	for child in spawn_root.get_children():
		if child.global_transform.origin.x < clear_x:
			child.queue_free()


func _ensure_words_ahead() -> void:
	# Pre-spawn future words so the player never sees a gap in the course.
	# This is intentionally done ahead of time instead of regenerating the map when a word ends.
	if current_entries.is_empty():
		return

	var target_x := player.position.x + MIN_ROAD_AHEAD
	var spawned := 0
	while farthest_spawned_x < target_x and spawned < PRESPAWN_WORDS:
		var entry := current_entries[next_spawn_entry_index]
		_spawn_course_for_entry(entry, next_word_start_x, false, false)
		next_spawn_entry_index = (next_spawn_entry_index + 1) % current_entries.size()
		spawned += 1


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


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found
	return null


func _spawn_road_tile(index: int) -> void:
	var track_piece := _instantiate_scene(ROAD_MODEL_PATH)
	if track_piece == null:
		return
	track_piece.scale = Vector3.ONE * ROAD_SCALE
	track_piece.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	var center_x := PLAYER_START_X + track_tile_length * 0.5 + index * track_tile_length
	track_piece.position = Vector3(center_x, 0.0, 0.0)
	road.add_child(track_piece)
	road_tiles[index] = track_piece


func _remove_road_tile(index: int) -> void:
	if road_tiles.has(index):
		road_tiles[index].queue_free()
		road_tiles.erase(index)


func _update_road_tiles(force: bool = false) -> void:
	if track_tile_length <= 0.0:
		return

	var tile_index: int = int(floor((player.position.x - PLAYER_START_X) / track_tile_length))
	current_tile_index = tile_index

	# Determine the target tile range we want to keep around the player.
	var target_min: int = tile_index - ROAD_TILES_BEHIND
	var target_max: int = tile_index + ROAD_TILES_AHEAD

	# Do not build past the finish line.
	if finish_line_x > 0.0:
		var max_x: float = finish_line_x - ROAD_CLEAR_GAP
		var max_allowed_index: int = int(floor((max_x - PLAYER_START_X) / track_tile_length))
		target_max = min(target_max, max_allowed_index)

	# Spawn missing tiles behind the player.
	if force or target_min < min_tile_index:
		for i in range(min_tile_index - 1, target_min - 1, -1):
			_spawn_road_tile(i)
		min_tile_index = min(min_tile_index, target_min)

	# Spawn missing tiles ahead of the player.
	if force or target_max > max_tile_index:
		for i in range(max_tile_index + 1, target_max + 1):
			_spawn_road_tile(i)
		max_tile_index = max(max_tile_index, target_max)

	# Remove tiles that are outside the desired range.
	for i in range(min_tile_index, target_min):
		_remove_road_tile(i)
	for i in range(target_max + 1, max_tile_index + 1):
		_remove_road_tile(i)

	min_tile_index = target_min
	max_tile_index = target_max


func _check_pickups() -> void:
	if next_target_index >= pickups.size():
		return

	var pickup := pickups[next_target_index]
	if pickup.collected:
		next_target_index += 1
		return

	var delta_x := absf(player.position.x - pickup.position.x)
	var delta_z := absf(player.position.z - pickup.position.z)
	if player.position.x > pickup.position.x + 6.0:
		# The player missed this letter; penalize with feedback but do not restart the word.
		pickup.set_collected()
		next_target_index += 1
		var phoneme_label := pickup.phoneme_alias
		var phoneme_stream := content_loader.get_phoneme_stream(phoneme_label)
		phoneme_player.play_looping_phoneme(phoneme_label, phoneme_stream)
		hud.flash_feedback("Missed %s" % pickup.letter.to_upper(), Color(1.0, 0.48, 0.38))
		return
	if delta_x > PICKUP_RADIUS_X or delta_z > PICKUP_RADIUS_Z:
		return

	pickup.set_collected()
	var phoneme_label := pickup.phoneme_alias
	var phoneme_stream := content_loader.get_phoneme_stream(phoneme_label)
	phoneme_player.play_looping_phoneme(phoneme_label, phoneme_stream)
	hud.flash_feedback(pickup.letter.to_upper(), Color(1.0, 0.94, 0.45))
	next_target_index += 1
	if next_target_index >= pickups.size():
		_complete_word()


func _check_obstacles() -> void:
	# Iterate backwards so we can safely remove freed obstacles.
	for i in range(obstacles.size() - 1, -1, -1):
		var obstacle := obstacles[i]
		if not is_instance_valid(obstacle):
			obstacles.remove_at(i)
			continue

		if obstacle.cleared:
			# Remove cleared obstacles to avoid accessing freed memory.
			obstacles.remove_at(i)
			continue

		var delta_x := absf(player.position.x - obstacle.position.x)
		var delta_z := absf(player.position.z - obstacle.position.z)
		if delta_x <= OBSTACLE_RADIUS_X and delta_z <= OBSTACLE_RADIUS_Z:
			obstacle.set_cleared()
			slowed_timer = obstacle.penalty_seconds
			hud.flash_feedback("Bump", Color(1.0, 0.42, 0.32))
			return

		if obstacle.position.x < player.position.x - 6.0:
			obstacle.set_cleared()
			obstacles.remove_at(i)


func _complete_word() -> void:
	state = "transition"
	completion_timer = 2.0
	phoneme_player.stop_phoneme()
	phoneme_player.play_word(content_loader.get_word_stream(current_entry))
	hud.set_status("Great job")
	hud.flash_feedback("%s" % str(current_entry.get("text", "")).to_upper(), Color(0.45, 1.0, 0.55))


func _update_camera(delta: float) -> void:
	# Move the camera closer and slightly lower so the larger vehicle stays in view.
	var desired_position := player.position + Vector3(-12.0, 10.0, 0.0)
	camera_rig.position = camera_rig.position.lerp(desired_position, delta * 4.0)
	camera.look_at(player.position + Vector3(6.0, 1.5, 0.0), Vector3.UP)


func _update_status() -> void:
	if current_entry.is_empty():
		return
	var total_letters := pickups.size()
	var target_text := (
		"Complete"
		if next_target_index >= total_letters
		else "Next: %s" % str(current_entry.get("letters", [])[next_target_index]).to_upper()
	)
	var mode_text := (
		str(settings.get("control_mode", ReadingSettingsStore.CONTROL_MODE_KEYBOARD)).capitalize()
	)
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
	control_profile.set_mode(mode_name)
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
	match str(settings.get("control_mode", ReadingSettingsStore.CONTROL_MODE_KEYBOARD)):
		ReadingSettingsStore.CONTROL_MODE_SWIPE:
			hud.set_help("Swipe left/right to switch lanes   Esc/Tab: options")
		ReadingSettingsStore.CONTROL_MODE_TILT:
			hud.set_help("Tilt the tablet left/right to switch lanes   Esc/Tab: options")
		_:
			hud.set_help("Left/Right or A/D to switch lanes   Esc/Tab: options")
