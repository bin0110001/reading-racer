class_name TestReadingModeSetup
extends GdUnitTestSuite


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
	var reading_mode = load("res://scripts/reading/reading_mode.gd").new()
	var layout = load("res://scripts/reading/track_generator/TrackLayout.gd").new()
	layout.path_cells = [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(1, 0, 1),
		Vector3i(0, 0, 1),
	]
	reading_mode.shared_track_layout = layout
	reading_mode.layout_origin = Vector3.ZERO
	reading_mode.track_tile_length = 10.0
	reading_mode.track_tile_width = 10.0

	var pose = reading_mode._get_pose_at_path_distance(15.0, 0.0)
	assert_that(pose).contains("position")
	assert_that(pose).contains("heading")
	assert_that(pose.position.x).is_less(15.0)
	assert_that(pose.position.z).is_greater(5.0)
	assert_that(pose.heading).is_greater(0.0)
	assert_that(pose.heading).is_less(PI / 2.0)
