class_name GameplayController extends RefCounted

## GameplayController: Solely responsible for gameplay logic.
## Handles pickups, obstacles, finish gates, and word completion.
## Separates gameplay from movement and map concerns.

signal pickup_collected(letter: String, phoneme_label: String)
signal obstacle_hit(duration: float)
signal word_completed

## Constants
const PICKUP_RADIUS_X := 4.0
const PICKUP_RADIUS_Z := 3.0
const OBSTACLE_RADIUS_X := 2.7
const OBSTACLE_RADIUS_Z := 2.0
const OBSTACLE_MODEL_PATH := "res://models/track-bump.glb"
const FINISH_MODEL_PATH := "res://models/track-finish.glb"
const SEGMENT_SPACING := 18.0
const LETTER_MODEL_PREFAB_BASE := "res://Assets/PolygonIcons/Prefabs/SM_Icon_Text_%s.prefab"

## References to content
var content_loader: ReadingContentLoader = null

## Game state
var current_entry: Dictionary = {}
var current_entry_index: int = -1
var next_target_index: int = 0
var pickup_triggers: Array[ReadingPickupTrigger] = []
var obstacle_triggers: Array[ReadingObstacleTrigger] = []
var finish_gate_trigger: ReadingFinishGateTrigger = null
var spawn_root: Node3D = null

# Placement grid for testable map workflow (path_index x lane_index)
var placement_grid: Array = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_content_loader: ReadingContentLoader) -> void:
	content_loader = p_content_loader
	_rng.randomize()


## Set the spawn root node for triggers
func set_spawn_root(p_spawn_root: Node3D) -> void:
	spawn_root = p_spawn_root


## Load entry and prepare gameplay
func load_entry(entry: Dictionary, entry_index: int) -> void:
	current_entry = entry
	current_entry_index = entry_index
	next_target_index = 0


## Spawn all pickups and obstacles for current entry
func spawn_course_pickups_and_obstacles(
	word_anchor: Dictionary,
	p_get_path_frame: Callable,
	p_path_wrap: Callable,
	clear_existing: bool = true
) -> void:
	if word_anchor.is_empty():
		return

	# Always reset existing pickups and obstacles when making a new word course.
	# This keeps current word logic aligned with finish-gate collection state.
	pickup_triggers.clear()
	obstacle_triggers.clear()

	if clear_existing:
		for child in spawn_root.get_children():
			child.queue_free()

	var start_index: int = int(word_anchor.get("start_index", 0))
	var letters: Array = current_entry.get("letters", []) as Array
	var finish_index: int = p_path_wrap.call(int(word_anchor.get("end_index", 0)) + 1)

	# Spawn pickups for each letter, skipping initial segment and corners
	var placed_letters := 0
	var path_index_candidate := start_index
	while placed_letters < letters.size():
		var is_initial := path_index_candidate - start_index < 2
		var is_corner := _is_corner_segment(
			p_get_path_frame,
			p_path_wrap,
			path_index_candidate,
		)
		if is_initial or is_corner:
			path_index_candidate = p_path_wrap.call(path_index_candidate + 1)
			continue

		var path_index: int = p_path_wrap.call(path_index_candidate)
		var path_frame: Dictionary = p_get_path_frame.call(path_index)
		var segment_pos: Vector3 = path_frame.get("center", Vector3.ZERO) as Vector3
		var segment_heading := float(path_frame.get("heading", 0.0))
		var path_right: Vector3 = path_frame.get("right", Vector3.RIGHT) as Vector3

		var pickup_lane_index: int = _rng.randi_range(0, 2)
		var pickup_offset: float = float(pickup_lane_index - 1) * 4.0

		# create pickup trigger using placed_letters index
		var letter_index_in_word := placed_letters
		path_index_candidate = p_path_wrap.call(path_index_candidate + 1)
		placed_letters += 1

		# Create pickup trigger
		var pickup_trigger: ReadingPickupTrigger = ReadingPickupTrigger.new()
		pickup_trigger.position = segment_pos + path_right * pickup_offset + Vector3(0.0, 2.3, 0.0)
		pickup_trigger.rotation.y = segment_heading
		pickup_trigger.word_index = current_entry_index
		pickup_trigger.letter_index = letter_index_in_word
		pickup_trigger.letter = str(letters[letter_index_in_word])
		pickup_trigger.phoneme_label = (
			content_loader
			. get_phoneme_label(
				current_entry,
				letter_index_in_word,
			)
		)
		pickup_trigger.trigger_width = PICKUP_RADIUS_X * 4
		pickup_trigger.trigger_depth = PICKUP_RADIUS_Z * 4
		spawn_root.add_child(pickup_trigger)

		# Add visual model to pickup; fallback to label if no matching 3D prefab found
		var letter_model = _create_letter_model(
			str(letters[letter_index_in_word]).to_upper(),
		)
		if letter_model != null:
			letter_model.scale = Vector3(2.0, 2.0, 2.0)
			letter_model.rotation = Vector3(0.0, -PI * 0.5, 0.0)
			pickup_trigger.add_child(letter_model)
		else:
			var label_node = Label3D.new()
			label_node.text = str(letters[letter_index_in_word]).to_upper()
			label_node.font_size = 512
			label_node.scale = Vector3(2.0, 2.0, 2.0)
			label_node.rotation = Vector3(0.0, -PI * 0.5, 0.0)
			label_node.modulate = Color(1.0, 0.75, 0.0)
			pickup_trigger.add_child(label_node)

		var light = OmniLight3D.new()
		light.omni_range = 8.0
		light.light_energy = 1.5
		pickup_trigger.add_child(light)

		pickup_trigger.pickup_triggered.connect(_on_pickup_triggered.bindv([pickup_trigger]))
		pickup_triggers.append(pickup_trigger)

		# Record generic placement grid entry for headless validation/testing.
		set_placement_object(
			path_index,
			pickup_lane_index,
			"pickup",
			{"letter": pickup_trigger.letter, "phoneme_label": pickup_trigger.phoneme_label},
		)

		# Spawn obstacle(s) in all lanes except pickup lane
		for lane_index in range(3):
			if lane_index == pickup_lane_index:
				continue
			var obstacle_trigger: ReadingObstacleTrigger = ReadingObstacleTrigger.new()
			var lane_offset: float = float(lane_index - 1) * 4.0 + _rng.randf_range(-1.0, 1.0)
			obstacle_trigger.position = (
				segment_pos + path_right * lane_offset + Vector3(0.0, 0.6, 0.0)
			)
			obstacle_trigger.rotation.y = segment_heading
			obstacle_trigger.word_index = current_entry_index
			obstacle_trigger.obstacle_index = letter_index_in_word * 2 + lane_index
			spawn_root.add_child(obstacle_trigger)

			# Add visual model
			var obstacle_visual := _instantiate_scene(OBSTACLE_MODEL_PATH)
			if obstacle_visual != null:
				obstacle_visual.scale = Vector3.ONE * 0.6
				obstacle_trigger.add_child(obstacle_visual)

			obstacle_trigger.obstacle_hit.connect(_on_obstacle_hit.bindv([obstacle_trigger]))
			obstacle_triggers.append(obstacle_trigger)

			# Record generic obstacle placement.
			var lane_idx = lane_index
			set_placement_object(
				path_index,
				lane_idx,
				"obstacle",
				{"obstacle_index": obstacle_trigger.obstacle_index, "lane": lane_idx},
			)

	# Create finish gate
	if finish_gate_trigger:
		finish_gate_trigger.queue_free()
	finish_gate_trigger = ReadingFinishGateTrigger.new() as ReadingFinishGateTrigger
	var finish_frame: Dictionary = p_get_path_frame.call(finish_index)
	finish_gate_trigger.position = finish_frame.get("center", Vector3.ZERO) as Vector3
	finish_gate_trigger.rotation.y = float(finish_frame.get("heading", 0.0))
	finish_gate_trigger.word_index = current_entry_index
	finish_gate_trigger.trigger_width = SEGMENT_SPACING
	finish_gate_trigger.trigger_depth = 8.0
	spawn_root.add_child(finish_gate_trigger)
	finish_gate_trigger.finish_gate_reached.connect(_on_finish_reached.bindv([finish_gate_trigger]))

	# Record finish line placement item.
	set_placement_object(finish_index, 1, "finish", {})


## Update finish gate state based on pickups collected
func update_finish_gate_state() -> void:
	if finish_gate_trigger:
		finish_gate_trigger.set_pickups_collected(next_target_index >= pickup_triggers.size())


## Check if word is complete
func is_word_complete() -> bool:
	return next_target_index >= pickup_triggers.size()


## Get total letters in current word
func get_total_letters() -> int:
	return pickup_triggers.size()


## Get next target letter
func get_next_target_letter() -> String:
	if next_target_index >= pickup_triggers.size():
		return ""
	var letters: Array = current_entry.get("letters", []) as Array
	if next_target_index >= letters.size():
		return ""
	return str(letters[next_target_index]).to_upper()


## Reset gameplay state for new word
func reset() -> void:
	next_target_index = 0
	_clear_placement_grid()


func _create_letter_model(letter: String) -> Node3D:
	var normalized := str(letter).strip_edges().to_upper()
	if normalized == "" or normalized.length() != 1:
		return null

	var model_path := LETTER_MODEL_PREFAB_BASE % normalized
	if not FileAccess.file_exists(model_path):
		return null

	var packed_scene := load(model_path)
	if not packed_scene is PackedScene:
		return null

	var instance = (packed_scene as PackedScene).instantiate()
	if instance is Node3D:
		return instance as Node3D
	return null


func _is_corner_segment(p_get_path_frame: Callable, p_path_wrap: Callable, path_index: int) -> bool:
	var current: Dictionary = p_get_path_frame.call(path_index)
	var next_frame: Dictionary = p_get_path_frame.call(p_path_wrap.call(path_index + 1))
	var next2_frame: Dictionary = p_get_path_frame.call(p_path_wrap.call(path_index + 2))
	var current_center := current.get("center", Vector3.ZERO) as Vector3
	var next_center := next_frame.get("center", Vector3.ZERO) as Vector3
	var next2_center := next2_frame.get("center", Vector3.ZERO) as Vector3
	var forward := next_center - current_center
	var next_forward := next2_center - next_center
	if forward.length_squared() < 0.0001 or next_forward.length_squared() < 0.0001:
		return false
	var forward_dir := forward.normalized()
	var next_dir := next_forward.normalized()
	return forward_dir.dot(next_dir) < 0.999


# ============ Placement grid helpers ============


func initialize_placement_grid(path_cell_count: int, lane_count: int = 3) -> void:
	placement_grid.clear()
	for i in range(path_cell_count):
		var row: Array = []
		for j in range(lane_count):
			row.append({})
		placement_grid.append(row)


func _clear_placement_grid() -> void:
	placement_grid.clear()


func set_placement_object(
	path_index: int,
	lane_index: int,
	object_type: String,
	metadata: Dictionary = {},
) -> void:
	if path_index < 0 or path_index >= placement_grid.size():
		return
	if lane_index < 0 or lane_index >= placement_grid[path_index].size():
		return
	placement_grid[path_index][lane_index] = {
		"type": object_type,
		"metadata": metadata.duplicate(true),
	}


func get_placement_object(path_index: int, lane_index: int) -> Dictionary:
	if path_index < 0 or path_index >= placement_grid.size():
		return {}
	if lane_index < 0 or lane_index >= placement_grid[path_index].size():
		return {}
	return placement_grid[path_index][lane_index] as Dictionary


# ============ Private Signal Handlers ============


func _on_pickup_triggered(
	_letter_index: int, _letter: String, _phoneme_label: String, trigger: ReadingPickupTrigger
) -> void:
	if trigger.word_index != current_entry_index:
		return
	if trigger.letter_index != next_target_index:
		# Wrong letter - emit signal to play "missed" phoneme
		var phoneme_label = trigger.phoneme_label
		pickup_collected.emit(trigger.letter.to_upper(), phoneme_label)  # Negative feedback
		return

	# Correct letter - emit signal to play correct phoneme
	pickup_collected.emit(trigger.letter.to_upper(), trigger.phoneme_label)
	next_target_index += 1


func _on_obstacle_hit(_obstacle_index: int, trigger: ReadingObstacleTrigger) -> void:
	if trigger.word_index != current_entry_index:
		return
	obstacle_hit.emit(trigger.penalty_seconds)


func _on_finish_reached(trigger: ReadingFinishGateTrigger) -> void:
	if trigger.word_index != current_entry_index:
		return
	word_completed.emit()


# ============ Private Helper Methods ============


func _instantiate_scene(resource_path: String) -> Node3D:
	if not ResourceLoader.exists(resource_path):
		return null
	var packed_scene := load(resource_path) as PackedScene
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node3D
