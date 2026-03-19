extends Node3D

const LANE_POSITIONS := [-6.0, 0.0, 6.0]
const PLAYER_START_X := -12.0
const WORD_START_X := 26.0
const SEGMENT_SPACING := 18.0
const PLAYER_SPEED := 13.0
const SLOWED_SPEED := 7.0
const LANE_CHANGE_SPEED := 18.0
const PICKUP_RADIUS_X := 2.5
const PICKUP_RADIUS_Z := 1.8
const OBSTACLE_RADIUS_X := 2.7
const OBSTACLE_RADIUS_Z := 2.0

const PLAYER_MODEL_PATH := "res://models/vehicle-truck-yellow.glb"
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
	_start_next_word(false)


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

	if state == "complete":
		completion_timer -= delta
		if completion_timer <= 0.0:
			_start_next_word(true)
		_update_camera(delta)
		return

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


func _start_next_word(play_feedback: bool) -> void:
	if current_entries.is_empty():
		return

	current_entry_index = (current_entry_index + 1) % current_entries.size()
	current_entry = current_entries[current_entry_index]
	_reset_word_state()
	hud.set_word(str(current_entry.get("text", "")))
	hud.set_phoneme("")
	if play_feedback:
		hud.flash_feedback("Next word", Color(0.45, 0.75, 1.0))
	_spawn_course_for_entry(current_entry)
	phoneme_player.play_word(content_loader.get_word_stream(current_entry))
	_update_status()


func _restart_current_word() -> void:
	if current_entry.is_empty():
		return

	_reset_word_state()
	hud.set_phoneme("")
	_spawn_course_for_entry(current_entry)
	phoneme_player.play_word(content_loader.get_word_stream(current_entry))
	_update_status()


func _reset_word_state() -> void:
	lane_index = 1
	next_target_index = 0
	slowed_timer = 0.0
	completion_timer = 0.0
	countdown_remaining = 3.0
	state = "countdown"
	player.position = Vector3(PLAYER_START_X, 0.0, LANE_POSITIONS[lane_index])
	phoneme_player.stop_phoneme()


func _spawn_course_for_entry(entry: Dictionary) -> void:
	for child in spawn_root.get_children():
		child.queue_free()
	pickups.clear()
	obstacles.clear()

	var letters: Array = entry.get("letters", []) as Array
	course_length = WORD_START_X + maxf(float(letters.size()), 1.0) * SEGMENT_SPACING + 30.0
	_build_course_geometry()

	for letter_index in range(letters.size()):
		var lane_for_letter := rng.randi_range(0, LANE_POSITIONS.size() - 1)
		var segment_x := WORD_START_X + letter_index * SEGMENT_SPACING
		var pickup := ReadingPickup.new()
		pickup.position = Vector3(segment_x, 2.3, LANE_POSITIONS[lane_for_letter])
		pickup.configure(
			str(letters[letter_index]),
			content_loader.get_phoneme_label(entry, letter_index),
			letter_index,
			lane_for_letter
		)
		spawn_root.add_child(pickup)
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
			obstacles.append(obstacle)

	var finish_visual := _instantiate_scene(FINISH_MODEL_PATH)
	if finish_visual != null:
		finish_visual.position = Vector3(course_length - 8.0, 0.0, 0.0)
		spawn_root.add_child(finish_visual)


func _build_course_geometry() -> void:
	for child in road.get_children():
		child.queue_free()

	var road_material := StandardMaterial3D.new()
	road_material.albedo_color = Color(0.17, 0.2, 0.24)

	var stripe_material := StandardMaterial3D.new()
	stripe_material.albedo_color = Color(0.95, 0.83, 0.28)

	for lane_number in range(LANE_POSITIONS.size()):
		var lane_mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(course_length + 36.0, 0.25, 3.2)
		lane_mesh.mesh = box_mesh
		lane_mesh.material_override = road_material
		lane_mesh.position = Vector3(
			(course_length + PLAYER_START_X) * 0.5, -0.2, LANE_POSITIONS[lane_number]
		)
		road.add_child(lane_mesh)

		var divider := MeshInstance3D.new()
		var divider_mesh := BoxMesh.new()
		divider_mesh.size = Vector3(course_length + 36.0, 0.03, 0.2)
		divider.mesh = divider_mesh
		divider.material_override = stripe_material
		divider.position = Vector3(
			(course_length + PLAYER_START_X) * 0.5, -0.05, LANE_POSITIONS[lane_number] + 1.75
		)
		road.add_child(divider)

	for decoration_index in range(6):
		var forest := _instantiate_scene(DECORATION_MODEL_PATH)
		if forest == null:
			continue
		forest.position = Vector3(
			18.0 + decoration_index * 24.0, 0.0, -12.0 if decoration_index % 2 == 0 else 12.0
		)
		forest.scale = Vector3.ONE * 1.4
		road.add_child(forest)


func _attach_player_model() -> void:
	for child in vehicle_anchor.get_children():
		child.queue_free()

	var model := _instantiate_scene(PLAYER_MODEL_PATH)
	if model == null:
		return

	model.scale = Vector3.ONE * 0.9
	model.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	vehicle_anchor.position = Vector3(0.0, 0.2, 0.0)
	vehicle_anchor.add_child(model)


func _instantiate_scene(resource_path: String) -> Node3D:
	if not ResourceLoader.exists(resource_path):
		return null
	var packed_scene := load(resource_path) as PackedScene
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node3D


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
		hud.flash_feedback("Missed %s" % pickup.letter.to_upper(), Color(1.0, 0.48, 0.38))
		_restart_current_word()
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
	for obstacle in obstacles:
		if obstacle.cleared:
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


func _complete_word() -> void:
	state = "complete"
	completion_timer = 2.0
	phoneme_player.stop_phoneme()
	phoneme_player.play_word(content_loader.get_word_stream(current_entry))
	hud.set_status("Great job")
	hud.flash_feedback("%s" % str(current_entry.get("text", "")).to_upper(), Color(0.45, 1.0, 0.55))


func _update_camera(delta: float) -> void:
	var desired_position := player.position + Vector3(-18.0, 13.0, 0.0)
	camera_rig.position = camera_rig.position.lerp(desired_position, delta * 4.0)
	camera.look_at(player.position + Vector3(8.0, 1.5, 0.0), Vector3.UP)


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
			hud.set_help("Swipe up/down to switch lanes   Esc/Tab: options")
		ReadingSettingsStore.CONTROL_MODE_TILT:
			hud.set_help("Tilt the tablet to switch lanes   Esc/Tab: options")
		_:
			hud.set_help("Up/Down or W/S to switch lanes   Esc/Tab: options")
