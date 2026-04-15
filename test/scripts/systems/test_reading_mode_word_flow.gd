class_name TestReadingModeWordFlow
extends GdUnitTestSuite

# Project policy: max 20 public test methods per class (gdlint max-public-methods).
# This flow tests live transitions in a dedicated file.

const ReadingSettingsStoreScript = preload("res://scripts/reading/settings_store.gd")

var obstacle_hit_signaled: bool = false
var _owned_nodes: Array[Node] = []


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


func _find_lane_for_type(gameplay_controller, path_index: int, item_type: String) -> int:
	for lane_index in range(3):
		if (
			gameplay_controller.get_placement_object(path_index, lane_index).get("type", "")
			== item_type
		):
			return lane_index
	return -1


func _own_node(node: Node) -> Node:
	_owned_nodes.append(node)
	return node


func after_each() -> void:
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.free()
	_owned_nodes.clear()
	collect_orphan_node_details()


func _create_reading_mode() -> Variant:
	return _own_node(PronunciationMode.new())


func _configure_reading_mode() -> Variant:
	var reading_mode: Variant = _create_reading_mode()
	var content_loader = ReadingContentLoader.new()
	reading_mode.movement_system = MovementSystem.new(LaneChangeController.new())
	reading_mode.hud = _own_node(ReadingHUD.new())
	reading_mode.phoneme_player = _own_node(PhonemePlayer.new())
	reading_mode.player = _own_node(Node3D.new()) as Node3D
	reading_mode.vehicle_anchor = _own_node(Node3D.new()) as Node3D
	reading_mode.spawn_root = _own_node(Node3D.new()) as Node3D
	reading_mode.settings_store = ReadingSettingsStoreScript.new()
	reading_mode.content_loader = content_loader
	reading_mode.gameplay_controller = GameplayController.new(content_loader)
	reading_mode.gameplay_controller.set_spawn_root(reading_mode.spawn_root)
	return reading_mode


func test_reading_mode_progresses_to_second_word_placement_grid() -> void:
	var reading_mode: Variant = _configure_reading_mode()

	var layout = TrackLayout.new()
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
		{
			"text": "a",
			"letters": PackedStringArray(["a"]),
			"phonemes": PackedStringArray(["ae"]),
		},
		{
			"text": "b",
			"letters": PackedStringArray(["b"]),
			"phonemes": PackedStringArray(["b"]),
		},
	]
	reading_mode.current_entries = current_entries
	reading_mode.current_entry_index = -1

	reading_mode._start_next_word(false, false, true)
	assert_that(reading_mode.current_entry_index).is_equal(0)
	assert_that(reading_mode.current_entry.get("text", "")).is_equal("a")

	reading_mode._start_next_word(false, false, true)
	assert_that(reading_mode.current_entry_index).is_equal(1)
	assert_that(reading_mode.current_entry.get("text", "")).is_equal("b")
	reading_mode.free()


func test_gameplay_controller_suppresses_obstacle_hit_during_pickup_collision() -> void:
	var controller = GameplayController.new(ReadingContentLoader.new())
	controller.current_entry_index = 0

	var pickup_trigger = ReadingPickupTrigger.new()
	pickup_trigger.word_index = 0
	pickup_trigger.letter_index = 0
	controller.pickup_triggers.append(pickup_trigger)

	controller.obstacle_hit.connect(Callable(self, "_on_test_obstacle_hit"))

	controller._on_pickup_triggered(0, "a", "ae", pickup_trigger)

	# Pickup trigger should be removed from pool after collection.
	# This avoids stale pickup presence suppressing future obstacle hits.
	assert_that(controller.pickup_triggers.size()).is_equal(0)

	var obstacle_trigger = ReadingObstacleTrigger.new()
	obstacle_trigger.word_index = 0
	obstacle_trigger.obstacle_index = 0

	obstacle_hit_signaled = false
	controller._on_obstacle_hit(0, obstacle_trigger)
	assert_that(obstacle_hit_signaled).is_false()

	# Force suppression window to expire, then obstacle should hit.
	var expire_ms := GameplayController.PICKUP_OBSTACLE_SUPPRESSION_WINDOW_MS + 10
	controller._last_pickup_time_ms = Time.get_ticks_msec() - expire_ms
	obstacle_hit_signaled = false
	controller._on_obstacle_hit(0, obstacle_trigger)
	assert_that(obstacle_hit_signaled).is_true()


func test_gameplay_controller_suppresses_obstacle_hit_when_pickup_has_triggered() -> void:
	var controller = GameplayController.new(ReadingContentLoader.new())
	controller.current_entry_index = 0

	var pickup_trigger = ReadingPickupTrigger.new()
	pickup_trigger.word_index = 0
	pickup_trigger.letter_index = 0
	pickup_trigger.position = Vector3.ZERO
	pickup_trigger.has_triggered = true
	controller.pickup_triggers.append(pickup_trigger)

	var obstacle_trigger = ReadingObstacleTrigger.new()
	obstacle_trigger.word_index = 0
	obstacle_trigger.obstacle_index = 0
	obstacle_trigger.position = Vector3.ZERO

	obstacle_hit_signaled = false
	controller.obstacle_hit.connect(Callable(self, "_on_test_obstacle_hit"))
	controller._on_obstacle_hit(0, obstacle_trigger)
	assert_that(obstacle_hit_signaled).is_false()


func test_reading_mode_complete_word_transitions_next_entry() -> void:
	var reading_mode: Variant = _configure_reading_mode()

	var layout = TrackLayout.new()
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
		{
			"text": "a",
			"letters": PackedStringArray(["a"]),
			"phonemes": PackedStringArray(["ae"]),
		},
		{
			"text": "b",
			"letters": PackedStringArray(["b"]),
			"phonemes": PackedStringArray(["b"]),
		},
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


func test_reading_mode_plays_phoneme_for_pickup() -> void:
	var reading_mode: Variant = _configure_reading_mode()
	reading_mode.content_loader = ReadingContentLoader.new()
	reading_mode.phoneme_player = _own_node(PhonemePlayer.new())
	reading_mode.hud = _own_node(ReadingHUD.new())

	reading_mode._on_gameplay_pickup_collected("B", "")

	assert_that(reading_mode.phoneme_player._current_label).is_equal("b")
	assert_that(reading_mode.hud._phoneme_label.text).is_equal("Phoneme: b")


func test_reading_mode_choice_entries_include_current_word_and_three_choices() -> void:
	var reading_mode: Variant = _configure_reading_mode()
	var entries: Array[Dictionary] = [
		{"text": "cat"},
		{"text": "cap"},
		{"text": "dog"},
		{"text": "bat"},
	]
	var choices: Array[Dictionary] = reading_mode._pick_choice_entries(0, entries)

	var correct_count := 0
	var has_cat := false
	for choice in choices:
		if bool(choice.get("is_correct", false)):
			correct_count += 1
		if str(choice.get("text", "")).to_lower() == "cat":
			has_cat = true

	assert_that(choices.size()).is_equal(3)
	assert_that(correct_count).is_equal(1)
	assert_that(has_cat).is_true()


func test_gameplay_controller_spawns_word_choice_triggers() -> void:
	var controller: GameplayController = GameplayController.new(ReadingContentLoader.new())
	controller.set_spawn_root(_own_node(Node3D.new()) as Node3D)
	var choices = [
		{"text": "cat", "is_correct": true},
		{"text": "cap", "is_correct": false},
		{"text": "dog", "is_correct": false},
	]
	var triggers = (
		controller
		. spawn_loop_course_word_choices(
			choices,
			0,
			0,
			Callable(self, "_get_test_path_frame"),
			true,
		)
	)

	assert_that(triggers.size()).is_equal(3)
	assert_that(controller.obstacle_triggers).is_empty()
	assert_that(str(triggers[0].choice_text)).is_not_equal("")
	var word_visual := triggers[0].get_node_or_null("WordLaneDisplay") as Node3D
	assert_that(word_visual).is_not_null()
	if word_visual != null:
		assert_that(float(word_visual.rotation_degrees.y)).is_equal(270.0)


func test_reading_mode_spawns_phoneme_smoke_letters() -> void:
	var reading_mode: Variant = _configure_reading_mode()
	reading_mode.player = _own_node(Node3D.new()) as Node3D
	reading_mode.phoneme_player = _own_node(PhonemePlayer.new())
	reading_mode.content_loader = ReadingContentLoader.new()

	reading_mode._on_gameplay_pickup_collected("ch", "")

	assert_that(reading_mode._phoneme_smoke_root).is_not_null()
	assert_that(reading_mode._phoneme_smoke_root.get_child_count()).is_equal(1)
	var smoke_label := reading_mode._phoneme_smoke_root.get_child(0) as Label3D
	assert_that(smoke_label).is_not_null()
	assert_that(smoke_label.text).is_equal("ch")

	reading_mode.phoneme_player._looping_phoneme = true
	reading_mode.phoneme_player._current_label = "ch"
	reading_mode._phoneme_smoke_label = "ch"
	reading_mode._phoneme_smoke_spawn_timer = reading_mode.PHONEME_SMOKE_SPAWN_INTERVAL
	reading_mode._update_phoneme_smoke(0.0)
	assert_that(reading_mode._phoneme_smoke_root.get_child_count()).is_greater_equal(2)


func test_reading_mode_does_not_teleport_at_end_of_word() -> void:
	var reading_mode: Variant = _configure_reading_mode()
	var layout = TrackLayout.new()
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

	reading_mode._start_next_word(false, false, true)
	reading_mode.movement_system.player_path_distance = 10.0

	reading_mode._complete_word()
	reading_mode._physics_process(2.1)

	assert_that(reading_mode.current_entry_index).is_equal(1)
	assert_that(reading_mode.movement_system.player_path_distance).is_greater(10.0)
	assert_that(reading_mode.movement_system.player_path_distance).is_not_equal(
		reading_mode.current_word_start_x - reading_mode.WORD_START_OFFSET
	)
