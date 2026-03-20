class_name TrackGenerator extends RefCounted

const TrackLayoutScript := preload("res://scripts/reading/track_generator/TrackLayout.gd")

## Procedural track generator for reading mode.
## Generates track segments with straights and corners based on difficulty settings.

const SEGMENT_LENGTH := 18.0
const STRAIGHT_PROBABILITY := 0.70  # 70% chance for straight, 30% for curve
const MIN_SEGMENTS_BEFORE_CURVE := 2  # Prevent curves too close together
const MIN_SEGMENTS_BEFORE_BACKTRACK := 8  # Prevent backtracking on recent sections

# Curve parameters
const CURVE_ANGLE_MIN := PI * 0.15  # 27 degrees
const CURVE_ANGLE_MAX := PI * 0.45  # 81 degrees
const CURVE_DIFFICULTY_MIN := 0.2
const CURVE_DIFFICULTY_MAX := 0.8
const DEFAULT_WORD_GAP_CELLS := 2
const DEFAULT_PADDING_CELLS := 12
const DEFAULT_DECORATION_MARGIN := 4
const DEFAULT_START_SLOTS := 8
const DEFAULT_CHECKPOINT_COUNT := 4
const DEFAULT_MIN_TRACK_WIDTH := 8
const DEFAULT_MIN_TRACK_HEIGHT := 4

const TRACK_TILE_STRAIGHT := "track_straight"
const TRACK_TILE_CORNER := "track_corner"
const DECORATION_TILE_EMPTY := "decoration_empty"
const DECORATION_TILE_FOREST := "decoration_forest"
const DECORATION_TILE_TENTS := "decoration_tents"

const DECORATION_WEIGHTS := [
	{
		"kind": DECORATION_TILE_EMPTY,
		"weight": 12,
		"scene_path": "res://models/decoration-empty.glb"
	},
	{
		"kind": DECORATION_TILE_FOREST,
		"weight": 2,
		"scene_path": "res://models/decoration-forest.glb"
	},
	{"kind": DECORATION_TILE_TENTS, "weight": 1, "scene_path": "res://models/decoration-tents.glb"},
]

const CARDINAL_DIRECTIONS := [
	Vector3i(1, 0, 0),
	Vector3i(0, 0, 1),
	Vector3i(-1, 0, 0),
	Vector3i(0, 0, -1),
]

var rng := RandomNumberGenerator.new()

var segments: Array[TrackSegment] = []
var next_segment_id := 0
var last_curve_segment_index := -1
var last_heading := 0.0
var last_position := Vector3.ZERO


func _init() -> void:
	rng.randomize()


## Initialize the track generator
func init_generator(start_pos: Vector3) -> void:
	segments.clear()
	next_segment_id = 0
	last_curve_segment_index = -1
	last_heading = 0.0
	last_position = start_pos


## Generate segments up to a target distance ahead
func generate_to_distance(target_distance: float) -> void:
	while get_total_length() < target_distance:
		_spawn_next_segment()


## Get total length of all generated segments
func get_total_length() -> float:
	if segments.is_empty():
		return 0.0
	return segments[-1].start_pos.x + segments[-1].length


## Get segment at a specific index
func get_segment(index: int) -> TrackSegment:
	if index >= 0 and index < segments.size():
		return segments[index]
	return null


## Find the segment index that contains a given world position
func get_segment_at_position(world_x: float) -> int:
	for i in range(segments.size()):
		var seg = segments[i]
		if world_x >= seg.start_pos.x and world_x < seg.start_pos.x + seg.length:
			return i
		if world_x < seg.start_pos.x:
			return i - 1
	return segments.size() - 1


## Get all segments
func get_all_segments() -> Array[TrackSegment]:
	return segments.duplicate()


## Clear segments before a specific position to save memory
func clear_segments_before(world_x: float) -> void:
	var keep_index := 0
	for i in range(segments.size()):
		if segments[i].start_pos.x + segments[i].length > world_x:
			keep_index = i
			break

	if keep_index > 0:
		segments = segments.slice(keep_index)
		if not segments.is_empty():
			last_heading = segments[-1].get_end_heading()
			last_position = segments[-1].get_end_pos()


func generate_loop_layout(word_entries: Array, config: Dictionary = {}) -> Variant:
	var budget: Dictionary = _build_word_budget(word_entries, config)
	var track_size: Vector2i = _choose_track_dimensions(
		int(budget.get("required_cells", 0)), config
	)
	var margin: int = max(1, int(config.get("decoration_margin", DEFAULT_DECORATION_MARGIN)))
	var grid_size: Vector3i = Vector3i(track_size.x + margin * 2, 1, track_size.y + margin * 2)
	var layout: Variant = TrackLayoutScript.new()
	layout.initialize(grid_size)

	var local_path: Array[Vector3i] = _build_serpentine_cycle(track_size.x, track_size.y)
	var path_offset: Vector3i = Vector3i(margin, 0, margin)
	var global_path: Array[Vector3i] = []
	for local_cell in local_path:
		global_path.append(local_cell + path_offset)
	layout.path_cells = global_path

	var seed_value: int = int(config.get("seed", _compute_seed(word_entries)))
	rng.seed = seed_value

	var turn_count: int = _populate_track_tiles(layout)
	var longest_run: Dictionary = _find_longest_straight_run(layout.path_cells)
	_populate_word_anchors(layout, word_entries, budget)
	_populate_checkpoints(layout, int(config.get("checkpoint_count", DEFAULT_CHECKPOINT_COUNT)))
	_populate_start_positions(
		layout, int(config.get("start_slots", DEFAULT_START_SLOTS)), longest_run
	)
	var decoration_count: int = _fill_decoration_tiles(layout)

	var straight_count: int = layout.count_cells_by_kind(TRACK_TILE_STRAIGHT)
	layout.metadata = {
		"seed": seed_value,
		"budget": budget,
		"grid_size": grid_size,
		"track_size": track_size,
		"decoration_margin": margin,
		"path_length": layout.path_cells.size(),
		"straight_count": straight_count,
		"corner_count": turn_count,
		"decoration_count": decoration_count,
		"longest_straight_run": longest_run,
	}
	return layout


## Generate the next segment
func _spawn_next_segment() -> void:
	var should_curve := rng.randf() > STRAIGHT_PROBABILITY
	var can_curve := (
		segments.size() - last_curve_segment_index >= MIN_SEGMENTS_BEFORE_CURVE
		and segments.size() >= MIN_SEGMENTS_BEFORE_BACKTRACK
	)

	if should_curve and can_curve:
		_add_curve_segment()
	else:
		_add_straight_segment()


## Add a straight segment
func _add_straight_segment() -> void:
	var segment = StraightSegment.new(next_segment_id, last_position, SEGMENT_LENGTH)
	segment.road_center_z = 0.0
	segment.ideal_heading = last_heading
	segments.append(segment)

	last_position = segment.get_end_pos()
	next_segment_id += 1


## Add a curve segment
func _add_curve_segment() -> void:
	var turn_direction := 1.0 if rng.randf() > 0.5 else -1.0
	var curve_angle := randf_range(CURVE_ANGLE_MIN, CURVE_ANGLE_MAX) * turn_direction
	var end_heading := last_heading + curve_angle
	var difficulty := randf_range(CURVE_DIFFICULTY_MIN, CURVE_DIFFICULTY_MAX)

	var segment = CurveSegment.new(
		next_segment_id, last_position, SEGMENT_LENGTH, last_heading, end_heading, difficulty
	)
	segment.road_center_z = 0.0
	segments.append(segment)

	last_position = segment.get_end_pos()
	last_heading = end_heading
	last_curve_segment_index = segments.size() - 1
	next_segment_id += 1


func _build_word_budget(word_entries: Array, config: Dictionary) -> Dictionary:
	var total_letters := 0
	for entry in word_entries:
		var letters: Array = entry.get("letters", []) as Array
		total_letters += letters.size()

	var word_gap_cells: int = max(1, int(config.get("word_gap_cells", DEFAULT_WORD_GAP_CELLS)))
	var padding_cells: int = max(0, int(config.get("padding_cells", DEFAULT_PADDING_CELLS)))
	var cell_world_length := float(config.get("cell_world_length", SEGMENT_LENGTH))
	var word_count := word_entries.size()
	var spacing_cells: int = maxi(word_count - 1, 0) * word_gap_cells
	var required_cells: int = max(
		total_letters + spacing_cells + padding_cells, DEFAULT_MIN_TRACK_WIDTH * 2
	)

	return {
		"total_letters": total_letters,
		"word_count": word_count,
		"word_gap_cells": word_gap_cells,
		"padding_cells": padding_cells,
		"spacing_cells": spacing_cells,
		"required_cells": required_cells,
		"required_world_length": float(required_cells) * cell_world_length,
	}


func _choose_track_dimensions(required_cells: int, config: Dictionary) -> Vector2i:
	var min_width: int = max(4, int(config.get("min_track_width", DEFAULT_MIN_TRACK_WIDTH)))
	var min_height: int = max(4, int(config.get("min_track_height", DEFAULT_MIN_TRACK_HEIGHT)))
	var width: int = max(min_width, int(ceil(sqrt(float(required_cells) * 1.75))))
	var height: int = max(min_height, int(ceil(float(required_cells) / float(width))))

	if height % 2 != 0:
		height += 1

	while width * height < required_cells:
		width += 1
		if height % 2 != 0:
			height += 1

	return Vector2i(width, height)


func _build_serpentine_cycle(width: int, height: int) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	if width < 2 or height < 2:
		return path

	for z in range(height):
		path.append(Vector3i(0, 0, z))

	for x in range(1, width):
		if x % 2 == 1:
			for z in range(height - 1, 0, -1):
				path.append(Vector3i(x, 0, z))
		else:
			for z in range(1, height):
				path.append(Vector3i(x, 0, z))

	for x in range(width - 1, 0, -1):
		path.append(Vector3i(x, 0, 0))

	return path


func _populate_track_tiles(layout: Variant) -> int:
	var corner_count := 0
	var path_count: int = layout.path_cells.size()
	for index in range(path_count):
		var previous_cell: Vector3i = layout.path_cells[(index - 1 + path_count) % path_count]
		var current_cell: Vector3i = layout.path_cells[index]
		var next_cell: Vector3i = layout.path_cells[(index + 1) % path_count]
		var incoming_dir: Vector3i = current_cell - previous_cell
		var outgoing_dir: Vector3i = next_cell - current_cell
		var is_corner := incoming_dir != outgoing_dir
		var tile_kind := TRACK_TILE_CORNER if is_corner else TRACK_TILE_STRAIGHT
		var rotation_y := _get_tile_rotation_degrees(incoming_dir, outgoing_dir, tile_kind)
		(
			layout
			. set_cell(
				current_cell,
				{
					"kind": tile_kind,
					"scene_path":
					(
						"res://models/track-corner.glb"
						if is_corner
						else "res://models/track-straight.glb"
					),
					"rotation_y": rotation_y,
					"path_index": index,
					"incoming_dir": incoming_dir,
					"outgoing_dir": outgoing_dir,
					"is_path": true,
				}
			)
		)
		if is_corner:
			corner_count += 1
	return corner_count


func _populate_word_anchors(layout: Variant, word_entries: Array, budget: Dictionary) -> void:
	var cursor := 0
	var word_gap_cells: int = int(budget.get("word_gap_cells", 0))
	for entry in word_entries:
		var letters: Array = entry.get("letters", []) as Array
		if letters.is_empty():
			continue
		var start_index: int = cursor % layout.path_cells.size()
		var end_index: int = (cursor + letters.size() - 1) % layout.path_cells.size()
		(
			layout
			. word_anchors
			. append(
				{
					"text": str(entry.get("text", "")),
					"start_index": start_index,
					"end_index": end_index,
					"letter_count": letters.size(),
				}
			)
		)
		cursor += letters.size() + word_gap_cells


func _populate_checkpoints(layout: Variant, checkpoint_count: int) -> void:
	var count: int = max(1, checkpoint_count)
	var path_count: int = layout.path_cells.size()
	for checkpoint_index in range(count):
		var path_index: int = int(floor(float(checkpoint_index) * path_count / count)) % path_count
		var cell: Vector3i = layout.path_cells[path_index]
		var cell_data: Dictionary = layout.get_cell(cell)
		(
			layout
			. checkpoints
			. append(
				{
					"checkpoint_index": checkpoint_index,
					"path_index": path_index,
					"cell": cell,
					"rotation_y": float(cell_data.get("rotation_y", 0.0)),
				}
			)
		)


func _populate_start_positions(layout: Variant, start_slots: int, longest_run: Dictionary) -> void:
	var slot_count: int = max(1, start_slots)
	var path_count: int = layout.path_cells.size()
	var run_start: int = int(longest_run.get("start_index", 0))
	var run_length: int = max(2, int(longest_run.get("length", 2)))
	for slot_index in range(slot_count):
		var run_offset: int = slot_index % run_length
		var path_index: int = (run_start + run_offset) % path_count
		var cell: Vector3i = layout.path_cells[path_index]
		var cell_data: Dictionary = layout.get_cell(cell)
		(
			layout
			. start_positions
			. append(
				{
					"slot": slot_index,
					"path_index": path_index,
					"cell": cell,
					"forward_dir": cell_data.get("outgoing_dir", Vector3i(1, 0, 0)),
					"rotation_y": float(cell_data.get("rotation_y", 0.0)),
				}
			)
		)


func _fill_decoration_tiles(layout: Variant) -> int:
	var count := 0
	for x in range(layout.size.x):
		for z in range(layout.size.z):
			var cell := Vector3i(x, 0, z)
			if layout.has_cell(cell):
				continue
			layout.set_cell(cell, _pick_decoration_cell())
			count += 1
	return count


func _pick_decoration_cell() -> Dictionary:
	var total_weight := 0
	for option in DECORATION_WEIGHTS:
		total_weight += int(option.weight)

	var roll := rng.randi_range(1, total_weight)
	for option in DECORATION_WEIGHTS:
		roll -= int(option.weight)
		if roll <= 0:
			return {
				"kind": str(option.kind),
				"scene_path": str(option.scene_path),
				"rotation_y": float(rng.randi_range(0, 3) * 90),
				"is_path": false,
			}

	return {
		"kind": DECORATION_TILE_EMPTY,
		"scene_path": "res://models/decoration-empty.glb",
		"rotation_y": 0.0,
		"is_path": false,
	}


func _find_longest_straight_run(path_cells: Array[Vector3i]) -> Dictionary:
	var longest_length := 0
	var longest_start := 0
	var path_count := path_cells.size()
	if path_count < 2:
		return {"start_index": 0, "length": 0}

	for start_index in range(path_count):
		var current_length := 1
		var base_dir: Vector3i = (
			path_cells[(start_index + 1) % path_count] - path_cells[start_index]
		)
		for offset in range(1, path_count):
			var prev_cell := path_cells[(start_index + offset - 1) % path_count]
			var current_cell := path_cells[(start_index + offset) % path_count]
			var step_dir := current_cell - prev_cell
			if step_dir != base_dir:
				break
			current_length += 1
		if current_length > longest_length:
			longest_length = current_length
			longest_start = start_index

	return {"start_index": longest_start, "length": longest_length}


func _get_tile_rotation_degrees(
	incoming_dir: Vector3i, outgoing_dir: Vector3i, tile_kind: String
) -> float:
	if tile_kind == TRACK_TILE_STRAIGHT:
		return 90.0 if abs(incoming_dir.x) == 1 else 0.0

	var corner_map := {
		"1,0,0|0,0,1": 180.0,
		"0,0,1|1,0,0": 180.0,
		"1,0,0|0,0,-1": 270.0,
		"0,0,-1|1,0,0": 270.0,
		"-1,0,0|0,0,-1": 0.0,
		"0,0,-1|-1,0,0": 0.0,
		"-1,0,0|0,0,1": 90.0,
		"0,0,1|-1,0,0": 90.0,
	}
	var key := (
		"%d,%d,%d|%d,%d,%d"
		% [
			incoming_dir.x,
			incoming_dir.y,
			incoming_dir.z,
			outgoing_dir.x,
			outgoing_dir.y,
			outgoing_dir.z,
		]
	)
	return float(corner_map.get(key, 0.0))


func _compute_seed(word_entries: Array) -> int:
	var seed_value := 17
	for entry in word_entries:
		var text := str(entry.get("text", ""))
		for character in text:
			seed_value = int((seed_value * 31 + character.unicode_at(0)) % 2147483647)
	if seed_value == 0:
		seed_value = 17
	return seed_value
