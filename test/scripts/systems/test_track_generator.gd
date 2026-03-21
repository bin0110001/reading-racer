class_name TestTrackGenerator
extends GdUnitTestSuite


func before_all() -> void:
	# no setup needed for these stateless tests
	pass


func test_track_generator_initialization() -> void:
	var generator = TrackGenerator.new()
	assert_that(generator).is_not_null()


func test_track_generator_init() -> void:
	var generator = TrackGenerator.new()
	var start_pos = Vector3(0.0, 0.0, 0.0)
	generator.init_generator(start_pos)

	# After init, should have no segments yet
	var segments = generator.get_all_segments()
	assert_that(segments).is_empty()


func test_track_generator_generates_segments() -> void:
	var generator = TrackGenerator.new()
	var start_pos = Vector3(0.0, 0.0, 0.0)
	generator.init_generator(start_pos)

	# Generate segments to 100 units ahead
	generator.generate_to_distance(100.0)

	var segments = generator.get_all_segments()
	assert_that(segments).is_not_empty()
	assert_that(segments.size()).is_greater(0)


func test_track_generator_builds_closed_loop_layout() -> void:
	var generator = TrackGenerator.new()
	var entries: Array[Dictionary] = [
		{"text": "cat", "letters": ["c", "a", "t"]},
		{"text": "dog", "letters": ["d", "o", "g"]},
		{"text": "plane", "letters": ["p", "l", "a", "n", "e"]},
	]

	var layout: TrackLayout = (
		generator.generate_loop_layout(
			entries, {"word_gap_cells": 2, "padding_cells": 6, "decoration_margin": 3}
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
	var generator = TrackGenerator.new()
	var entries: Array[Dictionary] = [
		{"text": "reading", "letters": ["r", "e", "a", "d", "i", "n", "g"]},
		{"text": "racer", "letters": ["r", "a", "c", "e", "r"]},
	]

	var layout: TrackLayout = generator.generate_loop_layout(entries) as TrackLayout
	var seen: Dictionary = {}
	for cell in layout.path_cells:
		var key: String = "%d,%d,%d" % [cell.x, cell.y, cell.z]
		assert_that(seen.has(key)).is_false()
		seen[key] = true


func test_track_generator_loop_layout_is_straight_heavy_and_filled() -> void:
	var generator = TrackGenerator.new()
	var entries: Array[Dictionary] = [
		{"text": "alphabet", "letters": ["a", "l", "p", "h", "a", "b", "e", "t"]},
		{"text": "loop", "letters": ["l", "o", "o", "p"]},
		{"text": "tiles", "letters": ["t", "i", "l", "e", "s"]},
	]

	var layout: TrackLayout = (
		generator.generate_loop_layout(entries, {"decoration_margin": 4}) as TrackLayout
	)
	var straight_count := int(layout.metadata.get("straight_count", 0))
	var corner_count := int(layout.metadata.get("corner_count", 0))
	var expected_decoration_count: int = layout.size.x * layout.size.z - layout.path_cells.size()

	assert_that(straight_count).is_greater(corner_count)
	assert_that(int(layout.metadata.get("decoration_count", -1))).is_equal(
		expected_decoration_count
	)
	assert_that(layout.count_cells_by_kind(TrackGenerator.DECORATION_TILE_EMPTY)).is_greater(0)
	assert_that(layout.word_anchors.size()).is_equal(entries.size())
	assert_that(layout.start_positions.size()).is_equal(8)
	assert_that(layout.checkpoints.size()).is_equal(4)


func test_track_generator_segment_continuity() -> void:
	var generator = TrackGenerator.new()
	var start_pos = Vector3(0.0, 0.0, 0.0)
	generator.init_generator(start_pos)

	generator.generate_to_distance(150.0)
	var segments = generator.get_all_segments()

	# Each segment should have a valid heading
	for seg in segments:
		assert_that(seg).is_instanceof(TrackSegment)
		assert_that(seg.ideal_heading).is_not_equal(NAN)


func test_track_generator_position_lookup() -> void:
	var generator = TrackGenerator.new()
	var start_pos = Vector3(-12.0, 0.0, 0.0)
	generator.init_generator(start_pos)

	generator.generate_to_distance(100.0)

	# Look up segment at starting position
	var seg_idx = generator.get_segment_at_position(start_pos.x)
	assert_that(seg_idx).is_not_equal(-1)

	var segment = generator.get_segment(seg_idx)
	assert_that(segment).is_not_null()


func test_straight_segment_properties() -> void:
	var segment = StraightSegment.new(0, Vector3(0.0, 0.0, 0.0), 18.0)
	segment.ideal_heading = 0.0

	assert_that(segment.ideal_heading).is_equal(0.0)
	assert_that(segment.length).is_equal(18.0)


func test_curve_segment_heading_interpolation() -> void:
	var segment = CurveSegment.new(0, Vector3(0.0, 0.0, 0.0), 18.0, 0.0, PI / 4.0, 1.0)

	# Test heading at various points
	var heading_start = segment.get_heading_at_progress(0.0)
	var heading_mid = segment.get_heading_at_progress(0.5)
	var heading_end = segment.get_heading_at_progress(1.0)

	assert_that(abs(heading_start - 0.0)).is_less_equal(0.01)
	assert_that(heading_mid).is_greater(heading_start)
	assert_that(abs(heading_end - PI / 4.0)).is_less_equal(0.01)
