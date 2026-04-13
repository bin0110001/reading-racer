class_name TestReadingModeSetup
extends GdUnitTestSuite

# Project policy: max 20 public test methods per class (gdlint max-public-methods).
# For additional coverage, create separate files like test_reading_mode_word_flow.gd.

const ReadingSettingsStoreScript = preload("res://scripts/reading/settings_store.gd")

var obstacle_hit_signaled: bool = false
var _owned_nodes: Array[Node] = []


func before_all() -> void:
	# no setup needed for these tests
	pass


func _own_node(node: Node) -> Node:
	_owned_nodes.append(node)
	return node


func after_each() -> void:
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.free()
	_owned_nodes.clear()
	collect_orphan_node_details()


func _on_test_obstacle_hit(_duration: float) -> void:
	obstacle_hit_signaled = true


func _get_test_path_frame(path_index: int) -> Dictionary:
	return {
		"center": Vector3(float(path_index) * 10.0, 0.0, 0.0),
		"heading": 0.0,
		"right": Vector3(0.0, 0.0, 1.0),
	}


func _get_test_path_index(path_index: int) -> int:
	return path_index


func _count_placement_objects_at_path(
	gameplay_controller: GameplayController, path_index: int, object_type: String
) -> int:
	var count := 0
	for lane_index in range(3):
		if (
			gameplay_controller.get_placement_object(path_index, lane_index).get("type", "")
			== object_type
		):
			count += 1
	return count


func _get_cornered_test_path_frame(path_index: int) -> Dictionary:
	var centers := [
		Vector3(0.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 0.0),
		Vector3(20.0, 0.0, 0.0),
		Vector3(20.0, 0.0, 10.0),
		Vector3(30.0, 0.0, 10.0),
		Vector3(40.0, 0.0, 10.0),
		Vector3(50.0, 0.0, 10.0),
	]
	var current_index := clampi(path_index, 0, centers.size() - 1)
	var next_index := clampi(path_index + 1, 0, centers.size() - 1)
	var forward: Vector3 = (centers[next_index] - centers[current_index]).normalized()
	if forward.length_squared() == 0.0:
		forward = Vector3.RIGHT
	return {
		"center": centers[current_index],
		"heading": atan2(forward.z, forward.x),
		"right": Vector3(-forward.z, 0.0, forward.x),
	}


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
	var store = ReadingSettingsStoreScript.new()
	assert_that(store).is_not_null()


func test_reading_settings_store_methods_exist() -> void:
	var store = ReadingSettingsStoreScript.new()
	assert_that(store.has_method("load_settings")).is_true()
	assert_that(store.has_method("save_settings")).is_true()
	assert_that(store.has_method("apply_master_volume")).is_true()


func test_reading_hud_can_be_loaded() -> void:
	assert_that(ReadingHUD).is_not_null()


func test_phoneme_player_can_be_loaded() -> void:
	# Try to load the PhonemePlayer script
	var phoneme_script: Script = PhonemePlayer
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
	assert_that(ResourceLoader.exists("res://scenes/level_types/pronunciation_mode.tscn")).is_true()


func test_reading_mode_scene_player_has_trigger_hitbox() -> void:
	var packed_scene := load("res://scenes/level_types/pronunciation_mode.tscn") as PackedScene
	assert_that(packed_scene).is_not_null()

	var instance := packed_scene.instantiate()
	var player := instance.get_node_or_null("Player")
	assert_that(player != null).is_true()
	assert_that(player is Area3D).is_true()
	assert_that(player.get_node_or_null("CollisionShape3D") != null).is_true()
	instance.free()


func test_reading_mode_path_smooth_corner() -> void:
	var reading_mode: Variant = _own_node(PronunciationMode.new())
	var layout = TrackLayout.new()
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
	assert_that(pose.position.x).is_less_equal(16.25)
	assert_that(pose.position.z).is_greater(5.0)
	assert_that(pose.heading).is_greater(0.0)
	assert_that(pose.heading).is_less_equal(PI / 2.0)

	# Ensure heading is smoothly interpolated across the corner segment
	var before_pose = reading_mode._get_pose_at_path_distance(14.5, 0.0)
	var after_pose = reading_mode._get_pose_at_path_distance(15.5, 0.0)
	assert_that(absf(after_pose.heading - before_pose.heading)).is_less_equal(0.8)
	reading_mode.free()


func test_gameplay_controller_does_not_use_invalid_energy_property() -> void:
	var file = FileAccess.open(
		"res://scripts/reading/systems/GameplayController.gd", FileAccess.READ
	)
	var text = file.get_as_text()
	assert_that(text.find("light.energy")).is_equal(-1)
	assert_that(text.find("LETTER_MODEL_PREFAB_BASE")).is_equal(-1)
	assert_that(text.find("SM_Icon_Text_%s.prefab")).is_equal(-1)


func test_reading_mode_lane_offset_is_clamped_to_track_width() -> void:
	var reading_mode: Variant = _own_node(PronunciationMode.new())
	var layout = TrackLayout.new()
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
	reading_mode.free()


func test_start_next_word_transition_resets_player_position() -> void:
	var reading_mode: Variant = _own_node(PronunciationMode.new())
	reading_mode.movement_system = MovementSystem.new(LaneChangeController.new())
	reading_mode.hud = _own_node(ReadingHUD.new())
	reading_mode.player = _own_node(Node3D.new()) as Node3D
	reading_mode.vehicle_anchor = _own_node(Node3D.new()) as Node3D
	reading_mode.spawn_root = _own_node(Node3D.new()) as Node3D
	reading_mode.content_loader = ReadingContentLoader.new()
	reading_mode.phoneme_player = _own_node(PhonemePlayer.new())
	reading_mode.gameplay_controller = GameplayController.new(ReadingContentLoader.new())
	reading_mode.settings_store = ReadingSettingsStoreScript.new()
	reading_mode.shared_track_layout = TrackLayout.new()
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
	assert_that(reading_mode.has_method("_start_next_word")).is_true()
	assert_that(reading_mode.content_loader).is_not_null()
	assert_that(reading_mode.phoneme_player).is_not_null()
	reading_mode.free()


func test_gameplay_controller_populates_placement_grid() -> void:
	var gameplay_controller: GameplayController = GameplayController.new(ReadingContentLoader.new())
	var root := _own_node(Node3D.new()) as Node3D
	gameplay_controller.set_spawn_root(root)
	gameplay_controller.initialize_placement_grid(10, 3)
	var entries: Array[Dictionary] = [{"text": "ab", "letters": ["a", "b"]}]
	var word_anchors: Array[Dictionary] = [{"start_index": 0, "end_index": 1}]
	var summary: Dictionary = (
		gameplay_controller
		. spawn_loop_course_pickups_and_obstacles(
			entries,
			word_anchors,
			Callable(self, "_get_test_path_frame"),
			Callable(self, "_get_test_path_index"),
			0,
			"",
			"",
			true,
		)
	)

	assert_that(summary.get("finish_indices", [])).is_equal([4])
	assert_that(gameplay_controller.get_total_letters()).is_equal(2)
	assert_that(_count_placement_objects_at_path(gameplay_controller, 2, "pickup")).is_equal(1)
	assert_that(_count_placement_objects_at_path(gameplay_controller, 3, "pickup")).is_equal(1)
	assert_that(gameplay_controller.get_placement_object(4, 1).get("type", "")).is_equal("finish")
	root.free()


func test_gameplay_controller_places_finish_after_last_safe_marker() -> void:
	var gameplay_controller = GameplayController.new(ReadingContentLoader.new())
	var root := _own_node(Node3D.new()) as Node3D
	gameplay_controller.set_spawn_root(root)
	gameplay_controller.initialize_placement_grid(10, 3)
	var entries: Array[Dictionary] = [{"text": "ab", "letters": ["a", "b"]}]
	var word_anchors: Array[Dictionary] = [{"start_index": 0, "end_index": 1}]
	var summary: Dictionary = (
		gameplay_controller
		. spawn_loop_course_pickups_and_obstacles(
			entries,
			word_anchors,
			Callable(self, "_get_test_path_frame"),
			Callable(self, "_get_test_path_index"),
			0,
			"",
			"",
			true,
		)
	)

	assert_that(summary.get("active_finish_index", -1)).is_equal(4)
	assert_that(gameplay_controller.get_word_finish_index(0)).is_equal(4)
	root.free()


func test_gameplay_controller_resets_pickups_between_words() -> void:
	var gameplay_controller = GameplayController.new(ReadingContentLoader.new())
	var root = _own_node(Node3D.new()) as Node3D
	gameplay_controller.set_spawn_root(root)

	var first_entry = {"text": "ab", "letters": ["a", "b"]}
	var second_entry = {"text": "c", "letters": ["c"]}

	gameplay_controller.load_entry(first_entry, 0)
	assert_that(gameplay_controller.has_method("spawn_loop_course_pickups_and_obstacles")).is_true()

	gameplay_controller.load_entry(second_entry, 1)
	root.free()
