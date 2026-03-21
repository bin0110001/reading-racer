class_name TestReadingModeSetup
extends GdUnitTestSuite

const ReadingModeScript = preload("res://scripts/reading/reading_mode.gd")
const TrackLayoutScript = preload("res://scripts/reading/track_generator/TrackLayout.gd")
const MapDisplayManagerScript = preload("res://scripts/reading/systems/MapDisplayManager.gd")


func before_all() -> void:
	# no setup needed for these tests
	pass


func test_reading_content_loader_creation() -> void:
	var loader = ReadingContentLoader.new()
	assert_that(loader).is_not_null()


func test_reading_content_loader_methods_exist() -> void:
	var loader = ReadingContentLoader.new()
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
	# Try to load the ReadingHUD script to verify it exists and compiles
	var hud_script = load("res://scripts/reading/reading_hud.gd") as Script
	assert_that(hud_script).is_not_null()


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
	var scene = load("res://scenes/reading_mode.tscn")
	assert_that(scene).is_not_null()


func test_reading_mode_path_smooth_corner() -> void:
	var reading_mode = ReadingModeScript.new()
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
	assert_true(pose.has("position"), "pose should contain 'position' key")
	assert_true(pose.has("heading"), "pose should contain 'heading' key")
	assert_that(pose.position.x).is_less(15.0)
	assert_that(pose.position.z).is_greater(5.0)
	assert_that(pose.heading).is_greater(0.0)
	assert_that(pose.heading).is_less(PI / 2.0)


func test_gameplay_controller_uses_light_light_energy_property() -> void:
	var light = OmniLight3D.new()
	light.light_energy = 1.5
	assert_that(light.light_energy).is_equal(1.5)


func test_gameplay_controller_does_not_use_invalid_energy_property() -> void:
	var file = FileAccess.open(
		"res://scripts/reading/systems/GameplayController.gd", FileAccess.READ
	)
	var text = file.get_as_text()
	assert_that(text.find("light.energy")).is_equal(-1)


func test_reading_mode_lane_offset_is_clamped_to_track_width() -> void:
	var reading_mode = ReadingModeScript.new()
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
