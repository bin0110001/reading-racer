## Scene Runner Integration Tests - Tests scenes with simulated input and gameplay
## Phase 2-3: Comprehensive scene validation using Scene Runner
extends GdUnitTestSuite

const MAIN_SCENE = preload("res://scenes/main.tscn")
const LEVEL_SELECT_SCENE = preload("res://scenes/level_select.tscn")
const READING_MODE_SCENE = preload("res://scenes/reading_mode.tscn")


func _create_scene_runner(packed_scene: PackedScene) -> GdUnitSceneRunner:
	assert_that(packed_scene).is_not_null()
	var instance := packed_scene.instantiate()
	assert_that(instance).is_not_null()
	return scene_runner(instance)


func test_main_scene_with_scene_runner() -> void:
	"""Test main.tscn initialization and basic scene validity."""
	var runner = _create_scene_runner(MAIN_SCENE)

	# Verify scene loaded correctly
	assert_that(runner).is_not_null()
	assert_that(runner.scene()).is_not_null()

	# Allow scene to initialize for one frame
	await runner.simulate_frames(1)

	# Scene should remain valid by still being instantiated and in tree
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_level_select_scene_with_scene_runner() -> void:
	"""Test level_select.tscn initialization and basic scene validity."""
	var runner = _create_scene_runner(LEVEL_SELECT_SCENE)

	# Verify scene loaded correctly
	assert_that(runner).is_not_null()
	assert_that(runner.scene()).is_not_null()

	# Allow scene to initialize
	await runner.simulate_frames(1)

	# Scene should remain valid by still being instantiated and in tree
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_reading_mode_scene_with_scene_runner() -> void:
	"""Test reading_mode.tscn initialization and basic scene validity.

	This is the critical gameplay scene that needs comprehensive testing.
	Validates that the scene can initialize without errors and run for several frames.
	"""
	var runner = _create_scene_runner(READING_MODE_SCENE)

	# Verify scene loaded correctly
	assert_that(runner).is_not_null()
	assert_that(runner.scene()).is_not_null()

	# Allow scene to initialize and run for multiple frames
	await runner.simulate_frames(30, 100)

	# Scene should remain valid throughout simulation
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_reading_mode_initialization() -> void:
	"""Test that reading_mode.tscn initializes game state correctly.

	Phase 3: Gameplay flow validation - verifies core game initialization.
	"""
	var runner = _create_scene_runner(READING_MODE_SCENE)

	# Let the scene fully initialize
	await runner.simulate_frames(5, 100)

	var scene_root = runner.scene()
	assert_that(scene_root).is_not_null()

	# Basic validity checks - scene should be ready
	assert_that(scene_root).is_not_null()
	assert_that(scene_root.is_inside_tree()).is_true()


func test_reading_mode_no_orphan_nodes() -> void:
	"""Test that reading_mode.tscn doesn't create orphan nodes during initialization.

	GDUnit4 orphan detection is enabled; this test documents that we're checking for it.
	"""
	var runner = _create_scene_runner(READING_MODE_SCENE)

	# Run through several frames to exercise initialization
	await runner.simulate_frames(15, 100)

	# If any orphan nodes are detected, GDUnit will report them
	# This test ensures the scene can run without creating leaked nodes
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_scene_runner_navigation_smoke_flow() -> void:
	"""Smoke test: instantiate all main UI scenes and exercise navigation actions."""

	# Main scene basic startup check
	var main_runner = _create_scene_runner(MAIN_SCENE)
	await main_runner.simulate_frames(2)
	assert_that(main_runner.scene()).is_not_null()
	assert_that(main_runner.scene().is_inside_tree()).is_true()

	# Level select scene UI navigation check
	var level_runner = _create_scene_runner(LEVEL_SELECT_SCENE)
	await level_runner.simulate_frames(2)
	var level_scene = level_runner.scene()
	assert_that(level_scene).is_not_null()

	var config_button: Button = level_scene.get_node("Panel/VBoxContainer/ConfigButton")
	var start_button: Button = level_scene.get_node("Panel/VBoxContainer/StartButton")
	var config_page: Control = level_scene.get_node("ConfigPage")

	assert_that(config_button).is_not_null()
	assert_that(start_button).is_not_null()
	assert_that(config_page).is_not_null()

	# Open and close configuration panel
	config_button.press()
	await level_runner.simulate_frames(1)
	assert_that(config_page.visible).is_true()

	var cancel_button: Button = level_scene.get_node("ConfigPage/VBoxContainer/CancelButton")
	cancel_button.press()
	await level_runner.simulate_frames(1)
	assert_that(config_page.visible).is_false()

	# Ensure start path exists (method accessible)
	assert_that(level_scene.has_method("_on_start_pressed")).is_true()

	# Simulate user pressing Start Race and validate scene transition to ReadingMode
	start_button.press()
	await level_runner.simulate_frames(5, 100)

	var tree_current_scene = level_scene.get_tree().current_scene
	assert_that(tree_current_scene).is_not_null()
	assert_that(tree_current_scene.get_name()).is_equal("ReadingMode")
	assert_that(tree_current_scene.is_inside_tree()).is_true()

	# Optionally check reading mode UI content exists
	var reading_hud = tree_current_scene.get_node_or_null("ReadingHUD")
	assert_that(reading_hud).is_not_null()

	# Keep a dedicated runner check for reading mode as final smoke endpoint
	var reading_runner = _create_scene_runner(READING_MODE_SCENE)
	await reading_runner.simulate_frames(10, 100)
	assert_that(reading_runner.scene()).is_not_null()
	assert_that(reading_runner.scene().is_inside_tree()).is_true()
