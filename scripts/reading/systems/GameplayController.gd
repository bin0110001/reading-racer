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
const OBSTACLE_RADIUS_X := 0.675
const OBSTACLE_RADIUS_Z := 0.5
const OBSTACLE_MODEL_PATH := "res://models/track-bump.glb"
const FINISH_MODEL_PATH := "res://models/track-finish.glb"
const SEGMENT_SPACING := 18.0
const WORD_START_SKIP_MARKERS := 2
const POST_CORNER_SKIP_MARKERS := 2
const DEFAULT_LANE_COUNT := 3

# When a pickup and obstacle share the same letter index window, prefer pickup behavior.
const PICKUP_OBSTACLE_SUPPRESSION_WINDOW_MS := 250
const PICKUP_OBSTACLE_DISTANCE_THRESHOLD := (PICKUP_RADIUS_X * 4.0) / 2.0 + OBSTACLE_RADIUS_X + 0.5

const LETTER_MODEL_PREFAB_BASE := "res://Assets/PolygonIcons/Prefabs/SM_Icon_Text_%s.prefab"
const LETTER_MODEL_FBX_BASE := "res://Assets/PolygonIcons/Models/SM_Icon_Text_%s.fbx"
const LETTER_MODEL_SCENE_BASE := "res://Assets/PolygonIcons/Prefabs/SM_Icon_Text_%s.tscn"
const POLYGON_ICONS_MODEL_PREFIX := "res://Assets/PolygonIcons/Models/"
const POLYGON_ICONS_PREFAB_PREFIX := "res://Assets/PolygonIcons/Prefabs/"
const POLYGON_ICONS_MATERIAL_PATHS_BY_GUID := {
	"e16ac172378295b4093bde7816670f73":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_01_A.mat",
	"7a43395cd3706cb42aaac9090dd06c58":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_01_B.mat",
	"b44401f408455dc449f1714dd03b5e43":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_01_C.mat",
	"ff819c9d7f189b842bc9a6ef0e1974aa":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_01_D.mat",
	"29eed07474159444594ff75f1cbcd174":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_02.mat",
	"e42a10eddf0c1cc46b1f11d43639a5c9":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_03.mat",
	"154f497799dddc540a3fd6002ff9218b":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_04.mat",
	"14115f3d188a0ad4aa0d47acf40d0f2f":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_05.mat",
	"113b726b484083d4587c9097ae836b3e":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_06.mat",
	"fa3bb200bf28cea40b51b5e4d7dc0035":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_07.mat",
	"d851d29fd3df4404d97a8b2e31ebc83c":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_08.mat",
	"e5cc88a0553de0f4f929fef74886d758":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_09.mat",
	"4a967b6dc8efab445b810553c2c3e7bc":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_10.mat",
	"818453dde4905dd4097c3f0ab2f1a5ad":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_11.mat",
	"adba580a63bdcfc48bed437cf8eaa53b":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_12.mat",
	"9bc5a968920469e4e9683dad301cae0c":
	"res://Assets/PolygonIcons/Materials/PolygonIcons_Mat_13.mat",
}
const EASTER_REPLACEMENT_MATERIAL_PATH := (
	"res://Assets/Synty/PolygonEaster/Materials/" + "PolygonEaster_01.material"
)
const GINGERBREAD_REPLACEMENT_MATERIAL_PATH := (
	"res://Assets/Synty/PolygonGingerBread/Materials/" + "PolygonGingerbread_01_A.material"
)
const ObstacleConfigClass = preload("res://scripts/reading/obstacle_config.gd")

## References to content
var content_loader: ReadingContentLoader = null
var player: Area3D = null
var obstacle_config: ObstacleConfig = null

## Game state
var current_entry: Dictionary = {}
var current_entry_index: int = -1
var next_target_index: int = 0
var pickup_triggers: Array[ReadingPickupTrigger] = []
var obstacle_triggers: Array[ReadingObstacleTrigger] = []
var finish_gate_trigger: ReadingFinishGateTrigger = null
var spawn_root: Node3D = null
var word_course_plans: Array[Dictionary] = []
var word_pickup_registry: Dictionary = {}
var word_obstacle_registry: Dictionary = {}
var word_finish_registry: Dictionary = {}

# Placement grid for testable map workflow (path_index x lane_index)
var placement_grid: Array = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Tracking purpose-built pickup-versus-obstacle suppression.
var _last_pickup_letter_index: int = -1
var _last_pickup_time_ms: int = -1000


func _init(p_content_loader: ReadingContentLoader) -> void:
	content_loader = p_content_loader
	_rng.randomize()
	obstacle_config = ObstacleConfigClass.new()


## Set the spawn root node for triggers
func set_spawn_root(p_spawn_root: Node3D) -> void:
	spawn_root = p_spawn_root


func set_player(p_player: Area3D) -> void:
	player = p_player


func _get_obstacle_scale(obstacle_data: Dictionary) -> float:
	return maxf(float(obstacle_data.get("scale", 1.0)), 0.1)


func _apply_obstacle_scale(
	obstacle_trigger: ReadingObstacleTrigger, obstacle_data: Dictionary
) -> void:
	# Holiday obstacle visuals may be scaled, but the trigger collision box should stay constant.
	# This keeps obstacle hit detection independent of decorative model size.
	# The visual scale is applied separately in _spawn_word_course_plan().
	pass


## Load entry and prepare gameplay
func load_entry(entry: Dictionary, entry_index: int) -> void:
	current_entry = entry
	current_entry_index = entry_index
	next_target_index = 0
	pickup_triggers.clear()
	obstacle_triggers.clear()
	finish_gate_trigger = null

	if word_pickup_registry.has(entry_index):
		var valid_pickups: Array = []
		for pickup_trigger in word_pickup_registry[entry_index]:
			if is_instance_valid(pickup_trigger):
				pickup_triggers.append(pickup_trigger)
				valid_pickups.append(pickup_trigger)
		word_pickup_registry[entry_index] = valid_pickups
	if word_obstacle_registry.has(entry_index):
		var valid_obstacles: Array = []
		for obstacle_trigger in word_obstacle_registry[entry_index]:
			if is_instance_valid(obstacle_trigger):
				obstacle_triggers.append(obstacle_trigger)
				valid_obstacles.append(obstacle_trigger)
		word_obstacle_registry[entry_index] = valid_obstacles
	if word_finish_registry.has(entry_index):
		var candidate_finish: ReadingFinishGateTrigger = (
			word_finish_registry[entry_index] as ReadingFinishGateTrigger
		)
		if candidate_finish != null and is_instance_valid(candidate_finish):
			finish_gate_trigger = candidate_finish
			finish_gate_trigger.set_pickups_collected(false)
		else:
			word_finish_registry.erase(entry_index)


func spawn_loop_course_pickups_and_obstacles(
	word_entries: Array,
	word_anchors: Array,
	p_get_path_frame: Callable,
	p_path_wrap: Callable,
	active_word_index: int,
	level_group: String = "",
	active_holiday: String = "",
	clear_existing: bool = true
) -> Dictionary:
	if clear_existing and spawn_root != null:
		for child in spawn_root.get_children():
			child.queue_free()

	_clear_course_registries(false)
	word_course_plans = build_loop_course_plan(
		word_entries, word_anchors, p_get_path_frame, p_path_wrap
	)

	var finish_indices: Array[int] = []
	for word_plan in word_course_plans:
		var spawned: Dictionary = _spawn_word_course_plan(
			word_plan,
			p_get_path_frame,
			level_group,
			active_holiday,
		)
		var word_index := int(word_plan.get("word_index", -1))
		word_pickup_registry[word_index] = spawned.get("pickups", [])
		word_obstacle_registry[word_index] = spawned.get("obstacles", [])
		word_finish_registry[word_index] = spawned.get("finish_gate", null)
		finish_indices.append(int(word_plan.get("finish_index", -1)))

	if active_word_index >= 0 and active_word_index < word_entries.size():
		load_entry(word_entries[active_word_index] as Dictionary, active_word_index)

	return {
		"finish_indices": finish_indices,
		"active_finish_index": get_word_finish_index(active_word_index),
	}


func build_loop_course_plan(
	word_entries: Array,
	word_anchors: Array,
	p_get_path_frame: Callable,
	p_path_wrap: Callable,
) -> Array[Dictionary]:
	var course_plans: Array[Dictionary] = []
	if word_entries.is_empty() or word_anchors.is_empty() or placement_grid.is_empty():
		return course_plans

	var safe_markers: Array[int] = _collect_loop_safe_markers(
		placement_grid.size(), p_get_path_frame, p_path_wrap
	)
	if safe_markers.is_empty():
		return course_plans

	var marker_cursor := 0
	var word_count: int = min(word_entries.size(), word_anchors.size())
	for word_index in range(word_count):
		var word_plan: Dictionary = _build_word_course_plan(
			word_index,
			word_entries[word_index] as Dictionary,
			word_anchors[word_index] as Dictionary,
			safe_markers,
			marker_cursor,
		)
		if word_plan.is_empty():
			continue
		marker_cursor = int(word_plan.get("next_marker_cursor", marker_cursor))
		course_plans.append(word_plan)

	return course_plans


func get_word_finish_index(word_index: int) -> int:
	for word_plan in word_course_plans:
		if int(word_plan.get("word_index", -1)) == word_index:
			return int(word_plan.get("finish_index", -1))
	return -1


func get_word_start_index(word_index: int) -> int:
	for word_plan in word_course_plans:
		if int(word_plan.get("word_index", -1)) == word_index:
			return int(word_plan.get("anchor_start_index", -1))
	return -1


func get_all_finish_indices() -> Array[int]:
	var finish_indices: Array[int] = []
	for word_plan in word_course_plans:
		finish_indices.append(int(word_plan.get("finish_index", -1)))
	return finish_indices


func _collect_word_markers(
	start_index: int,
	required_count: int,
	p_get_path_frame: Callable,
	p_path_wrap: Callable,
) -> Array[int]:
	var markers: Array[int] = []
	if required_count <= 0:
		return markers

	var current_index := start_index
	var start_skip_remaining := WORD_START_SKIP_MARKERS
	var corner_skip_remaining := 0
	var path_count: int = max(placement_grid.size(), required_count + WORD_START_SKIP_MARKERS + 1)
	var scan_limit: int = max(path_count * 3, required_count * 8)

	for _scan_step in range(scan_limit):
		var wrapped_index: int = p_path_wrap.call(current_index)
		if start_skip_remaining > 0:
			start_skip_remaining -= 1
		elif _is_corner_segment(p_get_path_frame, p_path_wrap, wrapped_index):
			corner_skip_remaining = POST_CORNER_SKIP_MARKERS
		elif corner_skip_remaining > 0:
			corner_skip_remaining -= 1
		else:
			markers.append(wrapped_index)
			if markers.size() >= required_count:
				break

		current_index = wrapped_index + 1

	return markers


func _collect_loop_safe_markers(
	path_cell_count: int, p_get_path_frame: Callable, p_path_wrap: Callable
) -> Array[int]:
	var blocked_markers: Dictionary = {}
	var safe_markers: Array[int] = []

	for path_index in range(path_cell_count):
		if not _is_corner_segment(p_get_path_frame, p_path_wrap, path_index):
			continue
		blocked_markers[path_index] = true
		for offset in range(1, POST_CORNER_SKIP_MARKERS + 1):
			blocked_markers[p_path_wrap.call(path_index + offset)] = true

	for path_index in range(path_cell_count):
		if blocked_markers.has(path_index):
			continue
		safe_markers.append(path_index)

	return safe_markers


func _build_word_course_plan(
	word_index: int,
	entry: Dictionary,
	word_anchor: Dictionary,
	safe_markers: Array[int],
	marker_cursor: int
) -> Dictionary:
	var letters: Array = entry.get("letters", []) as Array
	if letters.is_empty():
		return {}

	var minimum_path_index := int(word_anchor.get("start_index", 0)) + WORD_START_SKIP_MARKERS
	var start_cursor := _find_marker_cursor(safe_markers, minimum_path_index, marker_cursor)
	if start_cursor < 0:
		return {}

	var course_rng := RandomNumberGenerator.new()
	course_rng.seed = _compute_word_seed(word_index, entry)

	var pickup_plans: Array[Dictionary] = []
	var obstacle_plans: Array[Dictionary] = []
	var cursor := start_cursor

	for letter_index in range(letters.size()):
		if cursor >= safe_markers.size():
			return {}
		var path_index := safe_markers[cursor]
		var pickup_lane_index: int = course_rng.randi_range(0, DEFAULT_LANE_COUNT - 1)
		(
			pickup_plans
			. append(
				{
					"path_index": path_index,
					"lane_index": pickup_lane_index,
					"letter_index": letter_index,
					"letter": str(letters[letter_index]),
					"phoneme_label": content_loader.get_phoneme_label(entry, letter_index),
				}
			)
		)

		for lane_index in range(DEFAULT_LANE_COUNT):
			if lane_index == pickup_lane_index:
				continue
			(
				obstacle_plans
				. append(
					{
						"path_index": path_index,
						"lane_index": lane_index,
						"obstacle_index": letter_index * 2 + lane_index,
						"lane_jitter": course_rng.randf_range(-1.0, 1.0),
					}
				)
			)

		cursor += 1

	if cursor >= safe_markers.size():
		return {}

	var finish_index := safe_markers[cursor]
	return {
		"word_index": word_index,
		"entry": entry.duplicate(true),
		"anchor_start_index": int(word_anchor.get("start_index", 0)),
		"pickup_plans": pickup_plans,
		"obstacle_plans": obstacle_plans,
		"finish_index": finish_index,
		"next_marker_cursor": cursor + 1,
	}


func _find_marker_cursor(
	safe_markers: Array[int], minimum_path_index: int, start_cursor: int
) -> int:
	for cursor in range(start_cursor, safe_markers.size()):
		if safe_markers[cursor] >= minimum_path_index:
			return cursor
	return -1


func _spawn_word_course_plan(
	word_plan: Dictionary,
	p_get_path_frame: Callable,
	level_group: String = "",
	active_holiday: String = "",
) -> Dictionary:
	var spawned_pickups: Array[ReadingPickupTrigger] = []
	var spawned_obstacles: Array[ReadingObstacleTrigger] = []
	var word_index := int(word_plan.get("word_index", -1))
	var pickup_plans: Array = word_plan.get("pickup_plans", []) as Array
	for pickup_plan in pickup_plans:
		var path_index := int((pickup_plan as Dictionary).get("path_index", 0))
		var lane_index := int((pickup_plan as Dictionary).get("lane_index", 1))
		var path_frame: Dictionary = p_get_path_frame.call(path_index)
		var segment_pos: Vector3 = path_frame.get("center", Vector3.ZERO) as Vector3
		var segment_heading := float(path_frame.get("heading", 0.0))
		var path_right: Vector3 = path_frame.get("right", Vector3.RIGHT) as Vector3
		var pickup_offset: float = float(lane_index - 1) * 4.0

		var pickup_trigger := ReadingPickupTrigger.new()
		pickup_trigger.position = segment_pos + path_right * pickup_offset + Vector3(0.0, 2.3, 0.0)
		pickup_trigger.rotation.y = segment_heading
		pickup_trigger.word_index = word_index
		pickup_trigger.letter_index = int((pickup_plan as Dictionary).get("letter_index", 0))
		pickup_trigger.letter = str((pickup_plan as Dictionary).get("letter", ""))
		pickup_trigger.phoneme_label = str((pickup_plan as Dictionary).get("phoneme_label", ""))
		pickup_trigger.trigger_width = PICKUP_RADIUS_X * 4
		pickup_trigger.trigger_depth = PICKUP_RADIUS_Z * 4
		spawn_root.add_child(pickup_trigger)

		var letter_model = _create_letter_model(pickup_trigger.letter.to_upper())
		if letter_model != null:
			letter_model.scale = Vector3(2.0, 2.0, 2.0)
			letter_model.rotation = Vector3(0.0, -PI * 0.5, 0.0)
			pickup_trigger.add_child(letter_model)
		else:
			var label_node = Label3D.new()
			label_node.text = pickup_trigger.letter.to_upper()
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
		spawned_pickups.append(pickup_trigger)
		set_placement_object(
			path_index,
			lane_index,
			"pickup",
			{"letter": pickup_trigger.letter, "phoneme_label": pickup_trigger.phoneme_label},
		)

	for obstacle_plan in word_plan.get("obstacle_plans", []) as Array:
		var obstacle_path_index := int((obstacle_plan as Dictionary).get("path_index", 0))
		var obstacle_lane_index := int((obstacle_plan as Dictionary).get("lane_index", 1))
		var obstacle_frame: Dictionary = p_get_path_frame.call(obstacle_path_index)
		var obstacle_pos: Vector3 = obstacle_frame.get("center", Vector3.ZERO) as Vector3
		var obstacle_heading := float(obstacle_frame.get("heading", 0.0))
		var obstacle_right: Vector3 = obstacle_frame.get("right", Vector3.RIGHT) as Vector3
		var lane_offset: float = (
			float(obstacle_lane_index - 1) * 4.0
			+ float((obstacle_plan as Dictionary).get("lane_jitter", 0.0))
		)

		var obstacle_trigger := ReadingObstacleTrigger.new()
		obstacle_trigger.position = (
			obstacle_pos + obstacle_right * lane_offset + Vector3(0.0, 0.6, 0.0)
		)
		obstacle_trigger.rotation.y = obstacle_heading
		obstacle_trigger.word_index = word_index
		obstacle_trigger.obstacle_index = int(
			(obstacle_plan as Dictionary).get("obstacle_index", 0)
		)

		var obstacle_data = (
			obstacle_config
			. choose_random_obstacle(
				level_group,
				active_holiday,
				_rng,
			)
		)
		var obstacle_model_path = str(obstacle_data.get("model_path", OBSTACLE_MODEL_PATH))
		var hit_sounds = obstacle_data.get("sound_paths", ["res://audio/skid.ogg"]) as Array
		obstacle_trigger.hit_sound_paths = hit_sounds
		_apply_obstacle_scale(obstacle_trigger, obstacle_data)

		spawn_root.add_child(obstacle_trigger)

		var obstacle_visual := _instantiate_scene(obstacle_model_path)
		if obstacle_visual != null:
			obstacle_visual.scale = Vector3.ONE * _get_obstacle_scale(obstacle_data)
			obstacle_trigger.add_child(obstacle_visual)

		obstacle_trigger.obstacle_hit.connect(_on_obstacle_hit.bindv([obstacle_trigger]))
		spawned_obstacles.append(obstacle_trigger)

		set_placement_object(
			obstacle_path_index,
			obstacle_lane_index,
			"obstacle",
			{"obstacle_index": obstacle_trigger.obstacle_index, "lane": obstacle_lane_index},
		)

	var finish_index := int(word_plan.get("finish_index", -1))
	var finish_frame: Dictionary = p_get_path_frame.call(finish_index)
	var finish_gate := ReadingFinishGateTrigger.new() as ReadingFinishGateTrigger
	finish_gate.position = finish_frame.get("center", Vector3.ZERO) as Vector3
	finish_gate.rotation.y = float(finish_frame.get("heading", 0.0))
	finish_gate.word_index = word_index
	finish_gate.trigger_width = SEGMENT_SPACING
	finish_gate.trigger_depth = 8.0
	spawn_root.add_child(finish_gate)
	finish_gate.finish_gate_reached.connect(_on_finish_reached.bindv([finish_gate]))
	set_placement_object(finish_index, 1, "finish", {})

	return {
		"pickups": spawned_pickups,
		"obstacles": spawned_obstacles,
		"finish_gate": finish_gate,
	}


func _compute_word_seed(word_index: int, entry: Dictionary) -> int:
	var seed_value := 17 + word_index * 101
	var text := str(entry.get("text", ""))
	for character in text:
		seed_value = int((seed_value * 31 + character.unicode_at(0)) % 2147483647)
	if seed_value == 0:
		seed_value = 17
	return seed_value


func _clear_course_registries(clear_placement_grid: bool = true) -> void:
	word_course_plans.clear()
	word_pickup_registry.clear()
	word_obstacle_registry.clear()
	word_finish_registry.clear()
	pickup_triggers.clear()
	obstacle_triggers.clear()
	finish_gate_trigger = null
	if clear_placement_grid:
		_clear_placement_grid()


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
	if finish_gate_trigger != null:
		finish_gate_trigger.set_pickups_collected(false)


func _create_letter_model(letter: String) -> Node3D:
	var normalized := str(letter).strip_edges().to_upper()
	if normalized == "" or normalized.length() != 1:
		return null

	var candidate_paths := [
		LETTER_MODEL_SCENE_BASE % normalized,
		LETTER_MODEL_PREFAB_BASE % normalized,
		LETTER_MODEL_FBX_BASE % normalized,
	]

	for path in candidate_paths:
		if not FileAccess.file_exists(path):
			continue

		var resource := load(path)
		if resource == null:
			continue

		if resource is PackedScene:
			var scene_inst = (resource as PackedScene).instantiate()
			if scene_inst is Node3D:
				return scene_inst as Node3D
			continue

		if resource is Mesh:
			var mi = MeshInstance3D.new()
			mi.mesh = resource
			return mi

		# Some imports can produce a MeshInstance3D directly (unlikely), or a Node3D from FBX.
		var object_resource := resource as Object
		if object_resource is Node3D:
			return object_resource as Node3D

	# Last fallback: no model or not usable
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

	# Track last pickup by letter index in case obstacle and pickup collide together.
	_last_pickup_letter_index = trigger.letter_index
	_last_pickup_time_ms = Time.get_ticks_msec()

	# Clean up collected pickup so old pickups do not suppress future obstacles indefinitely.
	if pickup_triggers.has(trigger):
		pickup_triggers.erase(trigger)
		if trigger.is_inside_tree():
			trigger.queue_free()

	if word_pickup_registry.has(trigger.word_index):
		word_pickup_registry[trigger.word_index].erase(trigger)

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

	# Do not apply obstacle penalty while a pickup from the same letter index is active.
	var obstacle_letter_index := int(floor(float(_obstacle_index) / 2.0))
	var time_since_last_pickup := Time.get_ticks_msec() - _last_pickup_time_ms
	var letter_same_recently := obstacle_letter_index == _last_pickup_letter_index
	if time_since_last_pickup <= PICKUP_OBSTACLE_SUPPRESSION_WINDOW_MS and letter_same_recently:
		return

	# Also avoid bump penalties when a nearby pickup zone overlaps the obstacle.
	# This includes a pickup that may have just triggered and is being cleaned up.
	for pickup in pickup_triggers:
		if pickup.word_index != current_entry_index:
			continue
		if pickup.position.distance_to(trigger.position) <= PICKUP_OBSTACLE_DISTANCE_THRESHOLD:
			return

	# Safety guard: require the player to be close before applying slowdown.
	if player != null and player.is_inside_tree():
		var player_pos := player.global_transform.origin
		var obstacle_pos := trigger.global_transform.origin
		var x_dist: float = abs(player_pos.x - obstacle_pos.x)
		var z_dist: float = abs(player_pos.z - obstacle_pos.z)
		var min_x := (trigger.trigger_width * 0.5) + 2.0
		var min_z := (trigger.trigger_depth * 0.5) + 3.0
		if x_dist > min_x or z_dist > min_z:
			var warn_msg = "[GameplayController] Obstacle hit suppressed due player too far "
			var detail_format = "(x=%.2f z=%.2f) trigger=(%.2f %.2f)"
			var detail = (
				detail_format % [x_dist, z_dist, trigger.trigger_width, trigger.trigger_depth]
			)
			warn_msg += detail
			push_warning(warn_msg)
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
	var preferred_resource_path := _resolve_polygon_icons_scene_path(resource_path)
	for candidate_path in [preferred_resource_path, resource_path]:
		if not ResourceLoader.exists(candidate_path):
			continue
		var packed_scene := load(candidate_path) as PackedScene
		if packed_scene == null:
			continue
		var scene := packed_scene.instantiate() as Node3D
		if scene != null:
			_apply_polygon_icons_material_replacements(scene, resource_path)
			_apply_holiday_material_replacements(scene, candidate_path)
			return scene
	return null


func _resolve_polygon_icons_scene_path(resource_path: String) -> String:
	if not resource_path.begins_with(POLYGON_ICONS_MODEL_PREFIX):
		return resource_path

	var prefab_path := (
		POLYGON_ICONS_PREFAB_PREFIX + resource_path.get_file().get_basename() + ".prefab"
	)
	if FileAccess.file_exists(prefab_path):
		return prefab_path

	return resource_path


func _apply_polygon_icons_material_replacements(root: Node, resource_path: String) -> void:
	if not resource_path.begins_with(POLYGON_ICONS_MODEL_PREFIX):
		return

	var material := _load_polygon_icons_prefab_material(resource_path)
	var debug_file := FileAccess.open(
		"C:/Projects/reading-racer/polygonicons_debug_outer.log", FileAccess.WRITE
	)
	if debug_file != null:
		debug_file.store_line(resource_path + " => " + str(material))
		debug_file.close()
	if material == null:
		return

	_apply_material_to_mesh_instances(root, material)


func _load_polygon_icons_prefab_material(resource_path: String) -> Material:
	var prefab_path := _resolve_polygon_icons_prefab_source_path(resource_path)
	var debug_file := FileAccess.open(
		"C:/Projects/reading-racer/polygonicons_debug_prefab.log", FileAccess.WRITE
	)
	if debug_file != null:
		debug_file.store_line(prefab_path)
		debug_file.close()
	if prefab_path == "" or not FileAccess.file_exists(prefab_path):
		return null

	var prefab_text := FileAccess.get_file_as_string(prefab_path)
	var materials_index := prefab_text.find("m_Materials:")
	if materials_index == -1:
		return null

	var guid_index := prefab_text.find("guid:", materials_index)
	if guid_index == -1:
		return null

	var guid_start := guid_index + 5
	var guid_end := guid_start
	while guid_end < prefab_text.length():
		var character := prefab_text[guid_end]
		if character == "\n" or character == "\r":
			break
		guid_end += 1

	var material_guid := prefab_text.substr(guid_start, guid_end - guid_start).strip_edges()
	debug_file = FileAccess.open(
		"C:/Projects/reading-racer/polygonicons_debug_guid.log", FileAccess.WRITE
	)
	if debug_file != null:
		debug_file.store_line(material_guid)
		debug_file.close()
	if material_guid == "":
		return null

	var material_path := _resolve_polygon_icons_material_path(material_guid)
	debug_file = FileAccess.open(
		"C:/Projects/reading-racer/polygonicons_debug_material.log", FileAccess.WRITE
	)
	if debug_file != null:
		debug_file.store_line(material_path)
		debug_file.close()
	if material_path == "":
		return null

	return load(material_path) as Material


func _resolve_polygon_icons_prefab_source_path(resource_path: String) -> String:
	if not resource_path.begins_with(POLYGON_ICONS_MODEL_PREFIX):
		return ""

	return POLYGON_ICONS_PREFAB_PREFIX + resource_path.get_file().get_basename() + ".prefab"


func _resolve_polygon_icons_material_path(material_guid: String) -> String:
	return str(POLYGON_ICONS_MATERIAL_PATHS_BY_GUID.get(material_guid, ""))


func _apply_material_to_mesh_instances(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh is Mesh:
			var mesh := mesh_instance.mesh as Mesh
			for surface_index in range(mesh.get_surface_count()):
				mesh_instance.set_surface_override_material(surface_index, material)

	for child in node.get_children():
		_apply_material_to_mesh_instances(child, material)


func _apply_holiday_material_replacements(root: Node, resource_path: String) -> void:
	var material_path := ""
	if resource_path.begins_with("res://Assets/Synty/PolygonEaster/"):
		material_path = EASTER_REPLACEMENT_MATERIAL_PATH
	elif resource_path.begins_with("res://Assets/Synty/PolygonGingerBread/"):
		material_path = GINGERBREAD_REPLACEMENT_MATERIAL_PATH
	else:
		return
	var replacement_material := load(material_path) as Material
	if replacement_material == null:
		return
	_apply_holiday_material_replacements_recursive(root, replacement_material)


func _apply_holiday_material_replacements_recursive(
	node: Node, replacement_material: Material
) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh is ArrayMesh:
			var array_mesh := mesh_instance.mesh as ArrayMesh
			for surface_index in range(array_mesh.get_surface_count()):
				var surface_material := mesh_instance.get_surface_override_material(surface_index)
				if surface_material == null:
					surface_material = array_mesh.surface_get_material(surface_index)
				if _should_replace_holiday_material(surface_material):
					mesh_instance.set_surface_override_material(surface_index, replacement_material)

	for child in node.get_children():
		_apply_holiday_material_replacements_recursive(child, replacement_material)


func _should_replace_holiday_material(material: Material) -> bool:
	if material == null:
		return true
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_texture == null
	return false
