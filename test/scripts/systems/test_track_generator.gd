class_name TestTrackGenerator
extends GdUnitTestSuite

const TrackGeneratorScript = preload("res://scripts/reading/track_generator/TrackGenerator.gd")
const TrackSegmentScript = preload("res://scripts/reading/track_segments/TrackSegment.gd")
const StraightSegmentScript = preload("res://scripts/reading/track_segments/StraightSegment.gd")
const CurveSegmentScript = preload("res://scripts/reading/track_segments/CurveSegment.gd")
const GameplayControllerScript = preload("res://scripts/reading/systems/GameplayController.gd")
const ReadingContentLoaderScript = preload("res://scripts/reading/content_loader.gd")
const ReadingFinishGateTriggerScript = preload(
	"res://scripts/reading/triggers/ReadingFinishGateTrigger.gd"
)
const ReadingObstacleTriggerScript = preload(
	"res://scripts/reading/triggers/ReadingObstacleTrigger.gd"
)
const ReadingPickupTriggerScript = preload("res://scripts/reading/triggers/ReadingPickupTrigger.gd")

var _owned_nodes: Array[Node] = []


func _own_node(node: Node) -> Node:
	_owned_nodes.append(node)
	return node


func after_each() -> void:
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.free()
	_owned_nodes.clear()
	collect_orphan_node_details()


func before_all() -> void:
	# no setup needed for these stateless tests
	pass


func _wrap_layout_path_index(path_index: int, path_count: int) -> int:
	if path_count <= 0:
		return 0
	var wrapped := path_index % path_count
	if wrapped < 0:
		wrapped += path_count
	return wrapped


func _get_layout_path_frame(path_index: int, path_cells: Array) -> Dictionary:
	if path_cells.is_empty():
		return {}

	var path_count: int = path_cells.size()
	var current_index: int = _wrap_layout_path_index(path_index, path_count)
	var next_index: int = _wrap_layout_path_index(path_index + 1, path_count)
	var current_cell: Vector3i = path_cells[current_index]
	var next_cell: Vector3i = path_cells[next_index]
	var forward: Vector3 = Vector3(
		float(next_cell.x - current_cell.x), 0.0, float(next_cell.z - current_cell.z)
	)
	if forward.length_squared() == 0.0:
		forward = Vector3.RIGHT
	else:
		forward = forward.normalized()
	return {
		"center": Vector3(float(current_cell.x), 0.0, float(current_cell.z)),
		"heading": atan2(forward.z, forward.x),
		"right": Vector3(-forward.z, 0.0, forward.x),
	}


func test_track_generator_initialization() -> void:
	var generator = TrackGeneratorScript.new()
	assert_that(generator).is_not_null()


func test_track_generator_corner_rotation_is_180_degrees() -> void:
	var generator = TrackGeneratorScript.new()

	# A right turn corner rotation before adding 180 degrees is 180
	var rotation = generator._get_tile_rotation_degrees(
		Vector3i(1, 0, 0), Vector3i(0, 0, 1), TrackGeneratorScript.TRACK_TILE_CORNER
	)
	assert_that(rotation).is_equal(0.0)

	# A left turn corner rotation before adding 180 degrees is 90
	rotation = generator._get_tile_rotation_degrees(
		Vector3i(0, 0, 1), Vector3i(-1, 0, 0), TrackGeneratorScript.TRACK_TILE_CORNER
	)
	assert_that(rotation).is_equal(270.0)


func test_track_generator_init() -> void:
	var generator = TrackGeneratorScript.new()
	var start_pos = Vector3(0.0, 0.0, 0.0)
	generator.init_generator(start_pos)

	# After init, should have no segments yet
	var segments = generator.get_all_segments()
	assert_that(segments).is_empty()


func test_track_generator_generates_segments() -> void:
	var generator = TrackGeneratorScript.new()
	var start_pos = Vector3(0.0, 0.0, 0.0)
	generator.init_generator(start_pos)

	# Generate segments to 100 units ahead
	generator.generate_to_distance(100.0)

	var segments = generator.get_all_segments()
	assert_that(segments).is_not_empty()
	assert_that(segments.size()).is_greater(0)


func test_track_generator_builds_closed_loop_layout() -> void:
	var generator = TrackGeneratorScript.new()
	var entries = [
		{"text": "cat", "letters": ["c", "a", "t"]},
		{"text": "dog", "letters": ["d", "o", "g"]},
		{"text": "plane", "letters": ["p", "l", "a", "n", "e"]},
	]

	var layout: TrackLayout = (
		generator.generate_loop_layout(
			entries,
			{
				"word_gap_cells": 2,
				"padding_cells": 6,
				"decoration_margin": 3,
				"path_style": "serpentine"
			}
		)
		as TrackLayout
	)

	assert_that(layout).is_not_null()
	assert_that(layout.path_cells.size()).is_greater(0)
	assert_that(int(layout.metadata.get("path_length", 0))).is_equal(layout.path_cells.size())
	var budget: Dictionary = layout.metadata.get("budget", {}) as Dictionary
	assert_that(int(budget.get("required_cells", 0))).is_less_equal(layout.path_cells.size())

	for index in range(layout.path_cells.size()):
		var current_cell: Vector3i = layout.path_cells[index]
		var next_cell: Vector3i = layout.path_cells[(index + 1) % layout.path_cells.size()]
		var step: Vector3i = next_cell - current_cell
		var manhattan_distance: int = abs(step.x) + abs(step.y) + abs(step.z)
		assert_that(manhattan_distance).is_equal(1)


func test_track_generator_loop_layout_does_not_repeat_cells() -> void:
	var generator = TrackGeneratorScript.new()
	var entries = [
		{"text": "reading", "letters": ["r", "e", "a", "d", "i", "n", "g"]},
		{"text": "racer", "letters": ["r", "a", "c", "e", "r"]},
	]

	var layout: TrackLayout = (
		generator.generate_loop_layout(entries, {"path_style": "circular"}) as TrackLayout
	)
	var seen: Dictionary = {}
	for cell in layout.path_cells:
		var key: String = "%d,%d,%d" % [cell.x, cell.y, cell.z]
		assert_that(seen.has(key)).is_false()
		seen[key] = true


func test_track_generator_loop_layout_is_windy_and_filled() -> void:
	var generator = TrackGeneratorScript.new()
	var entries = [
		{"text": "alphabet", "letters": ["a", "l", "p", "h", "a", "b", "e", "t"]},
		{"text": "loop", "letters": ["l", "o", "o", "p"]},
		{"text": "tiles", "letters": ["t", "i", "l", "e", "s"]},
	]

	var layout: TrackLayout = (
		generator.generate_loop_layout(
			entries, {"decoration_margin": 4, "path_style": "serpentine"}
		)
		as TrackLayout
	)
	var straight_count := int(layout.metadata.get("straight_count", 0))
	var corner_count := int(layout.metadata.get("corner_count", 0))
	var longest_run: Dictionary = layout.metadata.get("longest_straight_run", {}) as Dictionary
	var expected_decoration_count: int = layout.size.x * layout.size.z - layout.path_cells.size()

	assert_that(straight_count).is_greater(0)
	assert_that(corner_count).is_greater(0)
	assert_that(int(longest_run.get("length", 0))).is_less_equal(6)
	assert_that(int(layout.metadata.get("decoration_count", -1))).is_equal(
		expected_decoration_count
	)
	assert_that(layout.count_cells_by_kind(TrackGeneratorScript.DECORATION_TILE_EMPTY)).is_greater(
		0
	)
	assert_that(layout.word_anchors.size()).is_equal(entries.size())
	assert_that(layout.start_positions.size()).is_equal(8)
	assert_that(layout.checkpoints.size()).is_equal(4)


func test_track_generator_serpentine_corner_rotations_follow_path() -> void:
	var generator = TrackGeneratorScript.new()
	var entries = [
		{"text": "cat", "letters": ["c", "a", "t"]},
		{"text": "dog", "letters": ["d", "o", "g"]},
		{"text": "plane", "letters": ["p", "l", "a", "n", "e"]},
		{"text": "loop", "letters": ["l", "o", "o", "p"]},
	]

	var layout: TrackLayout = (
		(
			generator
			. generate_loop_layout(
				entries,
				{
					"decoration_margin": 4,
					"padding_cells": 8,
					"word_gap_cells": 2,
					"path_style": "serpentine",
				}
			)
		)
		as TrackLayout
	)

	assert_that(layout).is_not_null()
	var path_count: int = layout.path_cells.size()
	assert_that(path_count).is_greater(0)

	for index in range(path_count):
		var current_cell: Vector3i = layout.path_cells[index]
		var previous_cell: Vector3i = layout.path_cells[(index - 1 + path_count) % path_count]
		var next_cell: Vector3i = layout.path_cells[(index + 1) % path_count]
		var incoming_dir: Vector3i = current_cell - previous_cell
		var outgoing_dir: Vector3i = next_cell - current_cell
		var expected_kind := (
			TrackGeneratorScript.TRACK_TILE_CORNER
			if incoming_dir != outgoing_dir
			else TrackGeneratorScript.TRACK_TILE_STRAIGHT
		)
		var cell_data: Dictionary = layout.get_cell(current_cell)
		assert_that(str(cell_data.get("kind", ""))).is_equal(expected_kind)
		var expected_rotation := generator._get_tile_rotation_degrees(
			incoming_dir, outgoing_dir, expected_kind
		)
		assert_that(float(cell_data.get("rotation_y", -1.0))).is_equal(expected_rotation)


func test_track_generator_serpentine_allocates_words_and_finish_gates() -> void:
	var generator = TrackGeneratorScript.new()
	var entries = [
		{
			"text": "cat",
			"letters": ["c", "a", "t"],
			"phonemes": ["k", "a", "t"],
		},
		{
			"text": "dog",
			"letters": ["d", "o", "g"],
			"phonemes": ["d", "o", "g"],
		},
		{
			"text": "plane",
			"letters": ["p", "l", "a", "n", "e"],
			"phonemes": ["p", "l", "a", "n", "e"],
		},
		{
			"text": "loop",
			"letters": ["l", "o", "o", "p"],
			"phonemes": ["l", "o", "o", "p"],
		},
	]

	var layout: TrackLayout = (
		(
			generator
			. generate_loop_layout(
				entries,
				{
					"decoration_margin": 4,
					"padding_cells": 8,
					"word_gap_cells": 2,
					"path_style": "serpentine",
				}
			)
		)
		as TrackLayout
	)
	assert_that(layout).is_not_null()
	assert_that(layout.word_anchors.size()).is_greater_equal(0)
	assert_that(layout.start_positions.size()).is_greater_equal(0)
	assert_that(layout.checkpoints.size()).is_greater_equal(0)


func test_track_generator_segment_continuity() -> void:
	var generator = TrackGeneratorScript.new()
	var start_pos = Vector3(0.0, 0.0, 0.0)
	generator.init_generator(start_pos)

	generator.generate_to_distance(150.0)
	var segments = generator.get_all_segments()

	# Each segment should have a valid heading
	for seg in segments:
		assert_that(seg).is_instanceof(TrackSegmentScript)
		assert_that(seg.ideal_heading).is_not_equal(NAN)


func test_track_generator_position_lookup() -> void:
	var generator = TrackGeneratorScript.new()
	var start_pos = Vector3(-12.0, 0.0, 0.0)
	generator.init_generator(start_pos)

	generator.generate_to_distance(100.0)

	# Look up segment at starting position
	var seg_idx = generator.get_segment_at_position(start_pos.x)
	assert_that(seg_idx).is_not_equal(-1)

	var segment = generator.get_segment(seg_idx)
	assert_that(segment).is_not_null()


func test_straight_segment_properties() -> void:
	var segment = StraightSegmentScript.new(0, Vector3(0.0, 0.0, 0.0), 18.0)
	segment.ideal_heading = 0.0

	assert_that(segment.ideal_heading).is_equal(0.0)
	assert_that(segment.length).is_equal(18.0)


func test_curve_segment_heading_interpolation() -> void:
	var segment = CurveSegmentScript.new(0, Vector3(0.0, 0.0, 0.0), 18.0, 0.0, PI / 4.0, 1.0)

	# Test heading at various points
	var heading_start = segment.get_heading_at_progress(0.0)
	var heading_mid = segment.get_heading_at_progress(0.5)
	var heading_end = segment.get_heading_at_progress(1.0)

	assert_that(abs(heading_start - 0.0)).is_less_equal(0.01)
	assert_that(heading_mid).is_greater(heading_start)
	assert_that(abs(heading_end - PI / 4.0)).is_less_equal(0.01)
