class_name TestReadingModeWordFlow
extends GdUnitTestSuite

# Project policy: max 20 public test methods per class (gdlint max-public-methods).
# This flow tests live transitions in a dedicated file.

const ReadingModeScript = preload("res://scripts/reading/reading_mode.gd")
const TrackLayoutScript = preload("res://scripts/reading/track_generator/TrackLayout.gd")


func _get_test_path_frame(path_index: int) -> Dictionary:
	return {
		"center": Vector3(float(path_index) * 10.0, 0.0, 0.0),
		"heading": 0.0,
		"right": Vector3(0.0, 0.0, 1.0),
	}


func _get_test_path_index(path_index: int) -> int:
	return path_index


func test_reading_mode_progresses_to_second_word_placement_grid() -> void:
	var reading_mode = ReadingModeScript.new()
	reading_mode.movement_system = MovementSystem.new(LaneChangeController.new())
	reading_mode.hud = ReadingHUD.new()
	reading_mode.player = Node3D.new()
	reading_mode.vehicle_anchor = Node3D.new()
	reading_mode.spawn_root = Node3D.new()
	reading_mode.gameplay_controller = GameplayController.new(ReadingContentLoader.new())

	var layout = TrackLayoutScript.new()
	layout.path_cells = [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(2, 0, 0),
		Vector3i(3, 0, 0),
		Vector3i(4, 0, 0),
	]
	layout.word_anchors = [
		{"text": "a", "start_index": 0, "end_index": 0, "letter_count": 1},
		{"text": "b", "start_index": 3, "end_index": 3, "letter_count": 1},
	]
	reading_mode.shared_track_layout = layout
	reading_mode.track_tile_length = 18.0
	reading_mode.track_tile_width = 18.0
	reading_mode.layout_origin = Vector3.ZERO

	reading_mode.current_entries = [
		{"text": "a", "letters": ["a"], "phonemes": ["ae"]},
		{"text": "b", "letters": ["b"], "phonemes": ["b"]},
	]
	reading_mode.current_entry_index = -1

	reading_mode._start_next_word(false, false, true)
	var first_pickup = reading_mode.gameplay_controller.get_placement_object(0, 1).get("type", "")
	assert_that(first_pickup).is_equal("pickup")

	reading_mode._start_next_word(false, false, true)
	var second_pickup = reading_mode.gameplay_controller.get_placement_object(3, 1).get("type", "")
	assert_that(second_pickup).is_equal("pickup")


func test_reading_mode_complete_word_transitions_next_entry() -> void:
	var reading_mode = ReadingModeScript.new()
	reading_mode.movement_system = MovementSystem.new(LaneChangeController.new())
	reading_mode.hud = ReadingHUD.new()
	reading_mode.player = Node3D.new()
	reading_mode.vehicle_anchor = Node3D.new()
	reading_mode.spawn_root = Node3D.new()
	reading_mode.gameplay_controller = GameplayController.new(ReadingContentLoader.new())

	var layout = TrackLayoutScript.new()
	layout.path_cells = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0)]
	layout.word_anchors = [
		{"text": "a", "start_index": 0, "end_index": 0, "letter_count": 1},
		{"text": "b", "start_index": 2, "end_index": 2, "letter_count": 1},
	]
	reading_mode.shared_track_layout = layout
	reading_mode.track_tile_length = 18.0
	reading_mode.track_tile_width = 18.0
	reading_mode.layout_origin = Vector3.ZERO

	reading_mode.current_entries = [
		{"text": "a", "letters": ["a"], "phonemes": ["ae"]},
		{"text": "b", "letters": ["b"], "phonemes": ["b"]},
	]
	reading_mode.current_entry_index = -1
	reading_mode.random_word_order = false

	# start with first word
	reading_mode._start_next_word(false, false, true)
	assert_that(reading_mode.current_entry_index).is_equal(0)
	assert_that(reading_mode.current_entry.get("text", "")).is_equal("a")

	# complete word and force transition to next
	reading_mode._complete_word()
	reading_mode._physics_process(2.1)

	assert_that(reading_mode.current_entry_index).is_equal(1)
	assert_that(reading_mode.current_entry.get("text", "")).is_equal("b")
