class_name TestReadingModeSetup
extends GdUnitTestSuite

# Project policy: max 20 public test methods per class (gdlint max-public-methods).
# For additional coverage, create separate files like test_reading_mode_word_flow.gd.

const ReadingModeScript = preload("res://scripts/reading/reading_mode.gd")
const TrackLayoutScript = preload("res://scripts/reading/track_generator/TrackLayout.gd")
const MapDisplayManagerScript = preload("res://scripts/reading/systems/MapDisplayManager.gd")
const MovementSystemScript = preload("res://scripts/reading/systems/MovementSystem.gd")
const GameplayControllerScript = preload("res://scripts/reading/systems/GameplayController.gd")
const LaneChangeControllerScript = preload(
	"res://scripts/reading/control_profiles/LaneChangeController.gd"
)
const ReadingHUDScript = preload("res://scripts/reading/reading_hud.gd")
const ReadingContentLoaderScript = preload("res://scripts/reading/content_loader.gd")


func before_all() -> void:
	# no setup needed for these tests
	pass


func _get_test_path_frame(path_index: int) -> Dictionary:
	return {
		"center": Vector3(float(path_index) * 10.0, 0.0, 0.0),
		"heading": 0.0,
		"right": Vector3(0.0, 0.0, 1.0),
	}


func _get_test_path_index(path_index: int) -> int:
	return path_index


func test_reading_content_loader_creation() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	assert_that(loader).is_not_null()


func test_reading_content_loader_methods_exist() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	assert_that(loader.has_method("list_word_groups")).is_true()
	assert_that(loader.has_method("load_word_entries")).is_true()
	assert_that(loader.has_method("get_word_stream")).is_true()
	assert_that(loader.has_method("get_phoneme_stream")).is_true()
	assert_that(loader.has_method("get_phoneme_label")).is_true()


func test_reading_settings_store_creation() -> void:
	var store = ReadingSettingsStore.new()
	assert_that(store).is_not_null()


func test_reading_settings_store_methods_exist() -> void:
	var store = ReadingSettingsStore.new()
	assert_that(store.has_method("load_settings")).is_true()
	assert_that(store.has_method("save_settings")).is_true()
	assert_that(store.has_method("apply_master_volume")).is_true()


func test_reading_hud_can_be_loaded() -> void:
	assert_that(ReadingHUDScript).is_not_null()


func test_phoneme_player_can_be_loaded() -> void:
	# Try to load the PhonemePlayer script
	var phoneme_script = load("res://scripts/reading/phoneme_player.gd") as Script
	assert_that(phoneme_script).is_not_null()


func test_required_scripts_exist() -> void:
	var scripts = [
		"res://scripts/reading/track_generator/TrackGenerator.gd",
		"res://scripts/reading/track_generator/TrackLayout.gd",
		"res://scripts/reading/track_segments/TrackSegment.gd",
		"res://scripts/reading/track_segments/StraightSegment.gd",
		"res://scripts/reading/track_segments/CurveSegment.gd",
		"res://scripts/reading/control_profiles/ControlProfile.gd",
		"res://scripts/reading/control_profiles/LaneChangeController.gd",
		"res://scripts/reading/control_profiles/SmoothSteeringController.gd",
		"res://scripts/reading/control_profiles/ThrottleSteeringController.gd",
		"res://scripts/reading/triggers/ReadingPickupTrigger.gd",
		"res://scripts/reading/triggers/ReadingObstacleTrigger.gd",
		"res://scripts/reading/triggers/ReadingFinishGateTrigger.gd",
	]

	for script_path in scripts:
		var script = load(script_path) as Script
		assert_that(script).is_not_null()


func test_reading_mode_scene_location() -> void:
	assert_that(ResourceLoader.exists("res://scenes/reading_mode.tscn")).is_true()


func test_reading_mode_path_smooth_corner() -> void:
	var reading_mode: Variant = ReadingModeScript.new()
	var layout = TrackLayoutScript.new()
	var cells: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(1, 0, 1),
		Vector3i(0, 0, 1),
	]
	layout.path_cells = cells
	reading_mode.shared_track_layout = layout
	reading_mode.layout_origin = Vector3.ZERO
	reading_mode.track_tile_length = 10.0
	reading_mode.track_tile_width = 10.0

	var pose = reading_mode._get_pose_at_path_distance(15.0, 0.0)
	assert_that(pose.has("position")).is_true()
	assert_that(pose.has("heading")).is_true()
	assert_that(pose.position.x).is_less(15.0)
	assert_that(pose.position.z).is_greater(5.0)
	assert_that(pose.heading).is_greater(0.0)
	assert_that(pose.heading).is_less(PI / 2.0)

	# Ensure heading is smoothly interpolated across the corner segment
	var before_pose = reading_mode._get_pose_at_path_distance(14.5, 0.0)
	var after_pose = reading_mode._get_pose_at_path_distance(15.5, 0.0)
	assert_that(absf(after_pose.heading - before_pose.heading)).is_less_equal(0.8)


func test_gameplay_controller_does_not_use_invalid_energy_property() -> void:
	var file = FileAccess.open(
		"res://scripts/reading/systems/GameplayController.gd", FileAccess.READ
	)
	var text = file.get_as_text()
	assert_that(text.find("light.energy")).is_equal(-1)


func test_reading_mode_lane_offset_is_clamped_to_track_width() -> void:
	var reading_mode: Variant = ReadingModeScript.new()
	var layout = TrackLayoutScript.new()
	var cells: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(1, 0, 1),
		Vector3i(0, 0, 1),
	]
	layout.path_cells = cells
	reading_mode.shared_track_layout = layout
	reading_mode.layout_origin = Vector3.ZERO
	reading_mode.track_tile_length = 10.0
	reading_mode.track_tile_width = 10.0

	assert_that(reading_mode._get_max_lane_offset()).is_equal(4.0)

	var pose_max = reading_mode._get_pose_at_path_distance(15.0, 4.0)
	var pose_extreme = reading_mode._get_pose_at_path_distance(15.0, 100.0)
	assert_that(pose_max.position.distance_to(pose_extreme.position)).is_less_equal(0.001)


func test_map_display_manager_populates_cell_entries() -> void:
	var layout = TrackLayoutScript.new()
	layout.initialize(Vector3i(4, 1, 4))
	layout.set_cell(
		Vector3i(0, 0, 0), {"scene_path": "res://models/track-straight.glb", "rotation_y": 0.0}
	)

	var manager = MapDisplayManagerScript.new()
	manager.set_nodes(Node3D.new(), Node3D.new())
	manager.set_layout_data(layout, Vector3.ZERO, 18.0, 18.0)

	assert_that(manager.layout_cell_entries.size()).is_equal(1)


func test_map_display_manager_spawns_visible_cells() -> void:
	var layout = TrackLayoutScript.new()
	layout.initialize(Vector3i(4, 1, 4))
	layout.set_cell(
		Vector3i(0, 0, 0), {"scene_path": "res://models/track-straight.glb", "rotation_y": 0.0}
	)

	var manager = MapDisplayManagerScript.new()
	var road = Node3D.new()
	var spawn_root = Node3D.new()
	manager.set_nodes(road, spawn_root)
	manager.set_layout_data(layout, Vector3.ZERO, 18.0, 18.0)
	manager.update_visible_cells(Vector3.ZERO, 0.0)

	assert_that(manager.grid_cells.size()).is_greater(0)


func test_map_display_manager_finish_cell_replaces_tile() -> void:
	var layout = TrackLayoutScript.new()
	layout.initialize(Vector3i(4, 1, 4))
	layout.set_cell(
		Vector3i(0, 0, 0), {"scene_path": "res://models/track-straight.glb", "rotation_y": 0.0}
	)

	var manager = MapDisplayManagerScript.new()
	var road = Node3D.new()
	var spawn_root = Node3D.new()
	manager.set_nodes(road, spawn_root)
	manager.set_layout_data(layout, Vector3.ZERO, 18.0, 18.0)
	manager.update_visible_cells(Vector3.ZERO, 0.0)
	manager.set_finish_cell(Vector3i(0, 0, 0))

	assert_that(manager.grid_cells.size()).is_equal(1)
	var tile = manager.grid_cells.get("0,0,0")
	assert_that(tile).is_not_null()

	# Ensure the logic marks finish cell with finish model in layout
	var finish_entry_found = false
	for entry in manager.layout_cell_entries:
		if entry.get("cell") == Vector3i(0, 0, 0):
			finish_entry_found = true
			var scene_path := str((entry.get("data", {}) as Dictionary).get("scene_path", ""))
			assert_that(scene_path).is_equal("res://models/track-finish.glb")
			break
	assert_that(finish_entry_found).is_true()


func test_start_next_word_transition_resets_player_position() -> void:
	var reading_mode: Variant = ReadingModeScript.new()
	reading_mode.movement_system = MovementSystem.new(LaneChangeController.new())
	reading_mode.hud = ReadingHUD.new()
	reading_mode.player = Node3D.new()
	reading_mode.vehicle_anchor = Node3D.new()
	reading_mode.spawn_root = Node3D.new()
	reading_mode.gameplay_controller = GameplayController.new(ReadingContentLoader.new())
	reading_mode.shared_track_layout = TrackLayoutScript.new()
	reading_mode.shared_track_layout.word_anchors = [
		{"start_index": 2, "end_index": 4},
		{"start_index": 6, "end_index": 8},
	]
	reading_mode.track_tile_length = 18.0
	var current_entries: Array[Dictionary] = [
		{"text": "one", "letters": ["o", "n", "e"]},
		{"text": "two", "letters": ["t", "w", "o"]},
	]
	reading_mode.current_entries = current_entries
	reading_mode.current_entry_index = 0
	reading_mode.current_entry = reading_mode.current_entries[0]
	reading_mode.movement_system.player_path_distance = 100.0

	reading_mode._start_next_word(true, false, true)

	# After transition, one should be repositioned to next word start location.
	var expected_word_anchor: Dictionary = reading_mode._get_word_anchor(1)
	var expected_start_x := reading_mode._path_index_to_distance(
		int(expected_word_anchor.get("start_index", 0))
	)
	var expected_offset: float = expected_start_x - ReadingModeScript.WORD_START_OFFSET
	assert_that(reading_mode.movement_system.player_path_distance).is_equal(expected_offset)


func test_gameplay_controller_populates_placement_grid() -> void:
	var gameplay_controller = GameplayController.new(ReadingContentLoader.new())
	gameplay_controller.set_spawn_root(Node3D.new())
	gameplay_controller.initialize_placement_grid(10, 3)
	gameplay_controller.load_entry({"text": "ab", "letters": ["a", "b"]}, 0)

	var word_anchor = {"start_index": 0, "end_index": 1}
	var get_path_frame = Callable(self, "_get_test_path_frame")
	var wrap_fn = Callable(self, "_get_test_path_index")
	gameplay_controller.spawn_course_pickups_and_obstacles(
		word_anchor, get_path_frame, wrap_fn, true
	)

	var pickup_count = 0
	for lane_index in range(3):
		if gameplay_controller.get_placement_object(0, lane_index).get("type", "") == "pickup":
			pickup_count += 1
	assert_that(pickup_count).is_equal(1)

	pickup_count = 0
	for lane_index in range(3):
		if gameplay_controller.get_placement_object(1, lane_index).get("type", "") == "pickup":
			pickup_count += 1
	assert_that(pickup_count).is_equal(1)

	assert_that(gameplay_controller.get_placement_object(2, 1).get("type", "")).is_equal("finish")


func test_gameplay_controller_resets_pickups_between_words() -> void:
	var gameplay_controller = GameplayController.new(ReadingContentLoader.new())
	var root = Node3D.new()
	gameplay_controller.set_spawn_root(root)

	var first_anchor = {
		"start_index": 0,
		"end_index": 0,
	}
	var second_anchor = {
		"start_index": 1,
		"end_index": 2,
	}

	var get_path_frame = Callable(self, "_get_test_path_frame")
	var wrap_fn = Callable(self, "_get_test_path_index")

	var first_entry = {"text": "ab", "letters": ["a", "b"]}
	var second_entry = {"text": "c", "letters": ["c"]}

	gameplay_controller.load_entry(first_entry, 0)
	(
		gameplay_controller
		. spawn_course_pickups_and_obstacles(
			first_anchor,
			get_path_frame,
			wrap_fn,
			true,
		)
	)
	assert_that(gameplay_controller.get_total_letters()).is_equal(2)

	gameplay_controller.load_entry(second_entry, 1)
	(
		gameplay_controller
		. spawn_course_pickups_and_obstacles(
			second_anchor,
			get_path_frame,
			wrap_fn,
			false,
		)
	)
	assert_that(gameplay_controller.get_total_letters()).is_equal(1)
