class_name TestReadingModeWordFlow
extends GdUnitTestSuite

# Project policy: max 20 public test methods per class (gdlint max-public-methods).
# This flow tests live transitions in a dedicated file.

const ReadingModeScript = preload("res://scripts/reading/reading_mode.gd")
const TrackLayoutScript = preload("res://scripts/reading/track_generator/TrackLayout.gd")
const MovementSystemScript = preload("res://scripts/reading/systems/MovementSystem.gd")
const GameplayControllerScript = preload("res://scripts/reading/systems/GameplayController.gd")
const LaneChangeControllerScript = preload(
	"res://scripts/reading/control_profiles/LaneChangeController.gd"
)
const ReadingHUDScript = preload("res://scripts/reading/reading_hud.gd")
const ReadingContentLoaderScript = preload("res://scripts/reading/content_loader.gd")


class TestReadingHUD:
	extends ReadingHUD

	func flash_feedback(_text_value: String, _color: Color = Color(1.0, 1.0, 1.0)) -> void:
		pass


class TestPhonemePlayer:
	extends PhonemePlayer

	func stop_phoneme() -> void:
		pass

	func play_word(_stream: AudioStream) -> void:
		pass


class TestContentLoader:
	extends ReadingContentLoader

	func get_word_stream(_entry: Dictionary) -> AudioStream:  # gdlint: disable=unused-argument
		return null

	func get_phoneme_label(entry: Dictionary, index: int) -> String:
		var phonemes: Array = entry.get("phonemes", []) as Array
		if index < 0 or index >= phonemes.size():
			return ""
		return str(phonemes[index])


func _get_test_path_frame(path_index: int) -> Dictionary:
	return {
		"center": Vector3(float(path_index) * 10.0, 0.0, 0.0),
		"heading": 0.0,
		"right": Vector3(0.0, 0.0, 1.0),
	}


func _get_test_path_index(path_index: int) -> int:
	return path_index


func _find_lane_for_type(
	gameplay_controller: GameplayController, path_index: int, item_type: String
) -> int:
	for lane_index in range(3):
		if (
			gameplay_controller.get_placement_object(path_index, lane_index).get("type", "")
			== item_type
		):
			return lane_index
	return -1


func _create_reading_mode() -> Variant:
	return ReadingModeScript.new()


func _configure_reading_mode() -> Variant:
	var reading_mode: Variant = _create_reading_mode()
	var content_loader = TestContentLoader.new()
	reading_mode.movement_system = MovementSystem.new(LaneChangeController.new())
	reading_mode.hud = TestReadingHUD.new()
	reading_mode.phoneme_player = TestPhonemePlayer.new()
	reading_mode.player = Node3D.new()
	reading_mode.vehicle_anchor = Node3D.new()
	reading_mode.spawn_root = Node3D.new()
	reading_mode.content_loader = content_loader
	reading_mode.gameplay_controller = GameplayController.new(content_loader)
	reading_mode.gameplay_controller.set_spawn_root(reading_mode.spawn_root)
	return reading_mode


func test_reading_mode_progresses_to_second_word_placement_grid() -> void:
	var reading_mode: Variant = _configure_reading_mode()

	var layout = TrackLayoutScript.new()
	layout.path_cells = [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(2, 0, 0),
		Vector3i(3, 0, 0),
		Vector3i(4, 0, 0),
		Vector3i(5, 0, 0),
		Vector3i(6, 0, 0),
		Vector3i(7, 0, 0),
		Vector3i(8, 0, 0),
	]
	layout.word_anchors = [
		{"text": "a", "start_index": 0, "end_index": 0, "letter_count": 1},
		{"text": "b", "start_index": 5, "end_index": 5, "letter_count": 1},
	]
	reading_mode.shared_track_layout = layout
	reading_mode.track_tile_length = 18.0
	reading_mode.track_tile_width = 18.0
	reading_mode.layout_origin = Vector3.ZERO

	var current_entries: Array[Dictionary] = [
		{"text": "a", "letters": ["a"], "phonemes": ["ae"]},
		{"text": "b", "letters": ["b"], "phonemes": ["b"]},
	]
	reading_mode.current_entries = current_entries
	reading_mode.current_entry_index = -1

	reading_mode._start_next_word(false, false, true)
	assert_that(_find_lane_for_type(reading_mode.gameplay_controller, 2, "pickup")).is_not_equal(-1)
	assert_that(_find_lane_for_type(reading_mode.gameplay_controller, 7, "pickup")).is_not_equal(-1)

	reading_mode._start_next_word(false, false, true)
	assert_that(_find_lane_for_type(reading_mode.gameplay_controller, 7, "pickup")).is_not_equal(-1)


func test_reading_mode_complete_word_transitions_next_entry() -> void:
	var reading_mode: Variant = _configure_reading_mode()

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

	var current_entries: Array[Dictionary] = [
		{"text": "a", "letters": ["a"], "phonemes": ["ae"]},
		{"text": "b", "letters": ["b"], "phonemes": ["b"]},
	]
	reading_mode.current_entries = current_entries
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
