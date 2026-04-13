class_name TrackGenerator
extends RefCounted

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
const DEFAULT_PATH_STYLE := "serpentine"

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

var segments: Array = []
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
func get_segment(index: int):
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
func get_all_segments():
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
	var path_style: String = config.get("path_style", DEFAULT_PATH_STYLE) as String
	var track_size: Vector2i = _choose_track_dimensions(
		int(budget.get("required_cells", 0)), config, path_style
	)
	var margin: int = max(1, int(config.get("decoration_margin", DEFAULT_DECORATION_MARGIN)))
	var grid_size: Vector3i = Vector3i(track_size.x + margin * 2, 1, track_size.y + margin * 2)
	var layout: TrackLayout = TrackLayoutScript.new()
	layout.initialize(grid_size)

	var seed_value: int = int(config.get("seed", _compute_seed(word_entries)))
	rng.seed = seed_value

	var local_path: Array[Vector3i] = _build_path(track_size.x, track_size.y, path_style)
	var path_offset: Vector3i = Vector3i(margin, 0, margin)
	var global_path: Array[Vector3i] = []
	for local_cell in local_path:
		global_path.append(local_cell + path_offset)
	layout.path_cells = global_path

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
	var cell_world_length: float = float(config.get("cell_world_length", SEGMENT_LENGTH))
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


func _path_capacity(width: int, height: int) -> int:
	if width < 2 or height < 2:
		return 0
	return 2 * (width + height) - 4


func _choose_track_dimensions(
	required_cells: int, config: Dictionary, path_style: String = DEFAULT_PATH_STYLE
) -> Vector2i:
	var min_width: int = max(4, int(config.get("min_track_width", DEFAULT_MIN_TRACK_WIDTH)))
	if path_style == "serpentine":
		min_width = max(4, int(config.get("serpentine_min_track_width", 5)))
	var min_height: int = max(4, int(config.get("min_track_height", DEFAULT_MIN_TRACK_HEIGHT)))
	if path_style == "serpentine":
		var serpentine_width: int = max(min_width, int(ceil(sqrt(float(required_cells)))))
		var serpentine_height: int = max(
			min_height, int(ceil(float(required_cells) / float(serpentine_width)))
		)

		if serpentine_height % 2 != 0:
			serpentine_height += 1

		while serpentine_width * serpentine_height < required_cells:
			if serpentine_width <= serpentine_height:
				serpentine_width += 1
			else:
				serpentine_height += 1
			if serpentine_height % 2 != 0:
				serpentine_height += 1

		return Vector2i(serpentine_width, serpentine_height)

	var width_factor: float = 1.75
	var width: int = max(min_width, int(ceil(sqrt(float(required_cells) * width_factor))))
	var height: int = max(min_height, int(ceil(float(required_cells) / float(width))))

	if height % 2 != 0:
		height += 1

	while _path_capacity(width, height) < required_cells:
		if width <= height:
			width += 1
		else:
			height += 1
		if height % 2 != 0:
			height += 1

	return Vector2i(width, height)


func _build_serpentine_cycle(width: int, height: int) -> Array[Vector3i]:
	if width < 5 or height < 5:
		return _build_circular_cycle(width, height)

	var path: Array[Vector3i] = []
	var bottom_bump_x: int = maxi(2, int(floor(float(width) / 3.0)))
	var right_bump_z: int = maxi(2, int(floor(float(height) / 3.0)))
	var top_bump_x: int = mini(width - 3, int(ceil(float(width) * 0.66)))
	var left_bump_z: int = mini(height - 3, int(ceil(float(height) * 0.66)))

	var x := 0
	while x < width:
		path.append(Vector3i(x, 0, 0))
		if x == bottom_bump_x and x + 1 < width:
			path.append(Vector3i(x, 0, 1))
			path.append(Vector3i(x + 1, 0, 1))
			path.append(Vector3i(x + 1, 0, 0))
			x += 1
		x += 1

	var z := 1
	while z < height:
		path.append(Vector3i(width - 1, 0, z))
		if z == right_bump_z and z + 1 < height:
			path.append(Vector3i(width - 2, 0, z))
			path.append(Vector3i(width - 2, 0, z + 1))
			path.append(Vector3i(width - 1, 0, z + 1))
			z += 1
		z += 1

	x = width - 2
	while x >= 0:
		path.append(Vector3i(x, 0, height - 1))
		if x == top_bump_x and x - 1 >= 0:
			path.append(Vector3i(x, 0, height - 2))
			path.append(Vector3i(x - 1, 0, height - 2))
			path.append(Vector3i(x - 1, 0, height - 1))
			x -= 1
		x -= 1

	z = height - 2
	while z > 0:
		path.append(Vector3i(0, 0, z))
		if z == left_bump_z and z - 1 >= 0:
			path.append(Vector3i(1, 0, z))
			path.append(Vector3i(1, 0, z - 1))
			path.append(Vector3i(0, 0, z - 1))
			z -= 1
		z -= 1

	if path.size() >= 4:
		path = _optimize_cycle_geometry(path, max(1, path.size() * 2))
	return path


func _build_hamiltonian_cycle(width: int, height: int) -> Array[Vector3i]:
	var total_cells := width * height
	if width < 2 or height < 2 or total_cells < 4:
		return []

	var start := Vector3i(0, 0, 0)
	var visited: Dictionary = {_cell_key(start): true}
	var path: Array[Vector3i] = [start]
	if _extend_hamiltonian_cycle(start, width, height, total_cells, visited, path):
		return path

	return []


func _extend_hamiltonian_cycle(
	current: Vector3i,
	width: int,
	height: int,
	total_cells: int,
	visited: Dictionary,
	path: Array[Vector3i],
) -> bool:
	if path.size() == total_cells:
		return _are_adjacent(current, path[0])

	var previous_direction := Vector3i.ZERO
	if path.size() >= 2:
		previous_direction = current - path[path.size() - 2]

	var candidates := _ordered_hamiltonian_neighbors(
		current, previous_direction, width, height, visited, path[0]
	)

	for next_cell in candidates:
		var next_key := _cell_key(next_cell)
		visited[next_key] = true
		path.append(next_cell)
		if _extend_hamiltonian_cycle(next_cell, width, height, total_cells, visited, path):
			return true
		path.remove_at(path.size() - 1)
		visited.erase(next_key)

	return false


func _ordered_hamiltonian_neighbors(
	current: Vector3i,
	previous_direction: Vector3i,
	width: int,
	height: int,
	visited: Dictionary,
	start_cell: Vector3i,
) -> Array[Vector3i]:
	var candidates: Array[Dictionary] = []
	for direction in CARDINAL_DIRECTIONS:
		var next_cell: Vector3i = current + direction
		if not _is_cell_in_hamiltonian_bounds(next_cell, width, height):
			continue
		if visited.has(_cell_key(next_cell)):
			continue

		var onward_count := 0
		for onward_direction in CARDINAL_DIRECTIONS:
			var onward_cell: Vector3i = next_cell + onward_direction
			if not _is_cell_in_hamiltonian_bounds(onward_cell, width, height):
				continue
			if visited.has(_cell_key(onward_cell)):
				continue
			onward_count += 1

		var turn_penalty := 0
		if previous_direction != Vector3i.ZERO and direction == previous_direction:
			turn_penalty = 1

		var close_bonus := 0
		if _are_adjacent(next_cell, start_cell):
			close_bonus = -1

		(
			candidates
			. append(
				{
					"cell": next_cell,
					"score": onward_count * 2 + turn_penalty + close_bonus,
				}
			)
		)

	var ordered: Array[Vector3i] = []
	while not candidates.is_empty():
		var best_index := 0
		for candidate_index in range(1, candidates.size()):
			var candidate_score := int((candidates[candidate_index] as Dictionary).get("score", 0))
			var best_score := int((candidates[best_index] as Dictionary).get("score", 0))
			if candidate_score < best_score:
				best_index = candidate_index
			elif candidate_score == best_score and rng.randf() < 0.5:
				best_index = candidate_index

		ordered.append((candidates[best_index] as Dictionary).get("cell", Vector3i.ZERO))
		candidates.remove_at(best_index)

	return ordered


func _is_cell_in_hamiltonian_bounds(cell: Vector3i, width: int, height: int) -> bool:
	return cell.x >= 0 and cell.z >= 0 and cell.x < width and cell.z < height


func _cell_key(cell: Vector3i) -> String:
	return "%d,%d" % [cell.x, cell.z]


func _build_base_cycle(width: int, height: int) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	if width < 2 or height < 2:
		return path

	for z in range(height):
		if z % 2 == 0:
			for x in range(width):
				path.append(Vector3i(x, 0, z))
		else:
			for x in range(width - 1, -1, -1):
				path.append(Vector3i(x, 0, z))

	for start_idx in range(path.size()):
		var candidate_first := path[start_idx]
		var candidate_last := path[(start_idx - 1 + path.size()) % path.size()]
		if _are_adjacent(candidate_first, candidate_last):
			var first_part := path.slice(start_idx)
			var second_part := path.slice(0, start_idx)
			path = first_part + second_part
			break

	return path


func _build_spiral_path(width: int, height: int) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	var left := 0
	var right := width - 1
	var top := 0
	var bottom := height - 1

	while left <= right and top <= bottom:
		for x in range(left, right + 1):
			path.append(Vector3i(x, 0, top))
		top += 1
		if top > bottom:
			break

		for z in range(top, bottom + 1):
			path.append(Vector3i(right, 0, z))
		right -= 1
		if left > right:
			break

		for x in range(right, left - 1, -1):
			path.append(Vector3i(x, 0, bottom))
		bottom -= 1
		if top > bottom:
			break

		for z in range(bottom, top - 1, -1):
			path.append(Vector3i(left, 0, z))
		left += 1

	return path


func _optimize_cycle_geometry(path: Array[Vector3i], iterations: int) -> Array[Vector3i]:
	var n := path.size()
	if n < 4:
		return path

	var current_score := _cycle_curviness_score(path)
	if current_score == -9999:
		var repaired_path := _find_best_valid_cycle_candidate(path)
		if not repaired_path.is_empty():
			path = repaired_path
			current_score = _cycle_curviness_score(path)

	for iteration in range(iterations):
		var i := rng.randi_range(0, n - 2)
		var j := rng.randi_range(i + 2, n - 1)
		if i + 2 > n - 1 or i == 0 and j == n - 1:
			continue

		var a := path[i]
		var b := path[(i + 1) % n]
		var c := path[j]
		var d := path[(j + 1) % n]

		if not (_are_adjacent(a, c) and _are_adjacent(b, d)):
			continue

		var candidate := _two_opt_swap(path, i, j)
		var candidate_score := _cycle_curviness_score(candidate)

		# Only accept valid candidates (score != -9999)
		if candidate_score != -9999 and (candidate_score > current_score or rng.randf() < 0.2):
			path = candidate
			current_score = candidate_score

	return path


func _find_best_valid_cycle_candidate(path: Array[Vector3i]) -> Array[Vector3i]:
	var n := path.size()
	var best_candidate: Array[Vector3i] = []
	var best_score := -9999.0

	for i in range(n - 1):
		for j in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue

			var a := path[i]
			var b := path[(i + 1) % n]
			var c := path[j]
			var d := path[(j + 1) % n]

			if not (_are_adjacent(a, c) and _are_adjacent(b, d)):
				continue

			var candidate := _two_opt_swap(path, i, j)
			var candidate_score := _cycle_curviness_score(candidate)
			if candidate_score == -9999:
				continue

			if best_candidate.is_empty() or candidate_score > best_score:
				best_candidate = candidate
				best_score = candidate_score

	return best_candidate


func _two_opt_swap(path: Array[Vector3i], i: int, j: int) -> Array[Vector3i]:
	var new_path: Array[Vector3i] = []
	new_path += path.slice(0, i + 1)
	var reversed_segment := path.slice(i + 1, j + 1).duplicate()
	reversed_segment.reverse()
	new_path += reversed_segment
	new_path += path.slice(j + 1, path.size())
	return new_path


func _cycle_curviness_score(path: Array[Vector3i]) -> float:
	var n := path.size()
	if n == 0:
		return -9999
	var corners := 0
	var max_straight_run := 0
	var current_straight_run := 0

	for k in range(n):
		var prev := path[(k - 1 + n) % n]
		var current := path[k]
		var next := path[(k + 1) % n]
		var v1 := current - prev
		var v2 := next - current

		if abs(v1.x) + abs(v1.z) != 1 or abs(v2.x) + abs(v2.z) != 1:
			return -9999
		if v1 == v2:
			current_straight_run += 1
			max_straight_run = max(max_straight_run, current_straight_run)
		else:
			# a corner (including 90 degrees), 180 degrees is disallowed in valid path
			corners += 1
			current_straight_run = 0

	# Score: prefer more curvature and shorter straights.
	var score := float(corners) * 10.0 - float(max_straight_run) * 3.0
	return score


func _are_adjacent(a: Vector3i, b: Vector3i) -> bool:
	return abs(a.x - b.x) + abs(a.z - b.z) == 1


func _rotate_cell(cell: Vector3i, width: int, height: int, rotation: int) -> Vector3i:
	match rotation:
		0:
			return cell
		1:
			# Only valid when width == height, otherwise skip because the grid would not match dimensions.
			return Vector3i(cell.z, 0, width - 1 - cell.x)
		2:
			return Vector3i(width - 1 - cell.x, 0, height - 1 - cell.z)
		3:
			# Only valid when width == height.
			return Vector3i(height - 1 - cell.z, 0, cell.x)
		_:
			return cell


func _randomize_cycle_orientation(p: Array[Vector3i], w: int, h: int) -> Array[Vector3i]:
	var transformed: Array[Vector3i] = []
	var rotation: int
	if w == h:
		rotation = rng.randi_range(0, 3)
	else:
		# For non-square grids, use only 0 or 180 degrees shift in place.
		rotation = rng.randi_range(0, 1) * 2

	for cell in p:
		transformed.append(_rotate_cell(cell, w, h, rotation))

	if rng.randf() < 0.5:
		for i in range(transformed.size()):
			var c: Vector3i = transformed[i]
			c.x = w - 1 - c.x
			transformed[i] = c

	if rng.randf() < 0.5:
		for i in range(transformed.size()):
			var c: Vector3i = transformed[i]
			c.z = h - 1 - c.z
			transformed[i] = c

	return transformed


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
	if layout.path_cells.is_empty():
		return
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
	if path_count == 0:
		return
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
	if path_count == 0:
		return
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
	var base_rotation := float(corner_map.get(key, 0.0))
	return fmod(base_rotation + 180.0, 360.0)


func _compute_seed(word_entries: Array) -> int:
	var seed_value := 17
	for entry in word_entries:
		var text := str(entry.get("text", ""))
		for character in text:
			seed_value = int((seed_value * 31 + character.unicode_at(0)) % 2147483647)
	if seed_value == 0:
		seed_value = 17
	return seed_value


func _build_path(width: int, height: int, style: String) -> Array[Vector3i]:
	match style:
		"serpentine":
			return _build_serpentine_cycle(width, height)
		"straight":
			return _build_straight_cycle(width, height)
		"circular":
			return _build_circular_cycle(width, height)
		_:
			return _build_circular_cycle(width, height)


func _build_straight_cycle(width: int, height: int) -> Array[Vector3i]:
	return _build_base_cycle(width, height)


func _build_circular_cycle(width: int, height: int) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	if width < 2 or height < 2:
		return path

	# Go right along bottom
	for x in range(width):
		path.append(Vector3i(x, 0, 0))

	# Go up along right
	for z in range(1, height):
		path.append(Vector3i(width - 1, 0, z))

	# Go left along top
	for x in range(width - 2, -1, -1):
		path.append(Vector3i(x, 0, height - 1))

	# Go down along left
	for z in range(height - 2, 0, -1):
		path.append(Vector3i(0, 0, z))

	return path
