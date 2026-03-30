## Scene Runner Integration Tests - Tests scenes with simulated input and gameplay
## Phase 2-3: Comprehensive scene validation using Scene Runner
extends GdUnitTestSuite

const MAIN_SCENE_PATH = "res://scenes/main.tscn"
const LEVEL_SELECT_SCENE_PATH = "res://scenes/level_select.tscn"
const VEHICLE_SELECT_SCENE_PATH = "res://scenes/vehicle_select.tscn"
const READING_MODE_SCENE_PATH = "res://scenes/reading_mode.tscn"

var _home_requested_emitted := false


func _create_scene_runner(scene_path: String) -> GdUnitSceneRunner:
	assert_that(scene_path).is_not_empty()
	return scene_runner(scene_path)


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		if child is Node:
			var found = _find_node_recursive(child, target_name)
			if found != null:
				return found
	return null


func _find_node_by_name_token(node: Node, token: String) -> Node:
	if node.name.find(token) >= 0:
		return node
	for child in node.get_children():
		if child is Node:
			var found = _find_node_by_name_token(child, token)
			if found != null:
				return found
	return null


func _mark_home_requested() -> void:
	_home_requested_emitted = true


func test_main_scene_with_scene_runner() -> void:
	"""Test main.tscn initialization and basic scene validity."""
	var runner = _create_scene_runner(MAIN_SCENE_PATH)

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
	var runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)

	# Verify scene loaded correctly
	assert_that(runner).is_not_null()
	assert_that(runner.scene()).is_not_null()

	# Allow scene to initialize
	await runner.simulate_frames(1)

	# Scene should remain valid by still being instantiated and in tree
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_vehicle_select_scene_with_scene_runner() -> void:
	"""Smoke test: vehicle select initializes, exposes paint controls, and can paint."""
	var runner = _create_scene_runner(VEHICLE_SELECT_SCENE_PATH)
	await runner.simulate_frames(3)

	var vehicle_scene = runner.scene()
	assert_that(vehicle_scene).is_not_null()
	assert_that(vehicle_scene.is_inside_tree()).is_true()

	var initial_snapshot: Dictionary = vehicle_scene.call("get_paint_debug_snapshot")
	assert_that(initial_snapshot.get("overlay_manager_ready", false)).is_true()
	assert_that(initial_snapshot.get("camera_brush_ready", false)).is_true()
	assert_that(initial_snapshot.get("brush_viewport_ready", false)).is_true()

	var paint_palette := _find_node_recursive(vehicle_scene, "PaintColorPalette") as GridContainer
	var rotation_controls := _find_node_recursive(vehicle_scene, "VehicleRotationControls")
	var rotate_side_button := _find_node_recursive(vehicle_scene, "RotateVehicleSideButton")
	var rotate_reset_button := _find_node_recursive(vehicle_scene, "RotateVehicleResetButton")
	var brush_size_button := (
		_find_node_recursive(vehicle_scene, "BrushSizeButton_02") as TextureButton
	)
	var paint_color_swatch := (
		_find_node_recursive(vehicle_scene, "PaintColorSwatch_00") as BaseButton
	)
	var camera_brush := _find_node_recursive(vehicle_scene, "CameraBrush")
	var overlay_manager := _find_node_recursive(vehicle_scene, "OverlayAtlasManager")
	assert_that(paint_palette).is_not_null()
	assert_that(rotation_controls).is_not_null()
	assert_that(rotate_side_button).is_not_null()
	assert_that(rotate_reset_button).is_not_null()
	assert_that(brush_size_button).is_not_null()
	assert_that(paint_color_swatch).is_not_null()
	assert_that(camera_brush).is_not_null()
	assert_that(overlay_manager).is_not_null()
	assert_that(paint_palette.get_child_count()).is_equal(24)

	rotate_side_button.emit_signal("pressed")
	await runner.simulate_frames(1)
	var side_snapshot: Dictionary = vehicle_scene.call("get_paint_debug_snapshot")
	var rotation_degrees: Vector3 = side_snapshot.get("vehicle_rotation_degrees", Vector3.ZERO)
	assert_that(rotation_degrees.y).is_equal(90.0)

	rotate_reset_button.emit_signal("pressed")
	await runner.simulate_frames(1)
	var reset_snapshot: Dictionary = vehicle_scene.call("get_paint_debug_snapshot")
	rotation_degrees = reset_snapshot.get("vehicle_rotation_degrees", Vector3.ZERO)
	assert_that(rotation_degrees.is_equal_approx(Vector3.ZERO)).is_true()

	await runner.simulate_frames(2)
	assert_that((camera_brush as CameraBrush).viewport).is_not_null()
	var brush_before := (camera_brush as Node3D).global_position

	paint_color_swatch.emit_signal("pressed")
	brush_size_button.emit_signal("pressed")
	vehicle_scene.call("_on_paint_color_selected", 0)
	vehicle_scene.call("_on_brush_size_selected", 2)

	var preview_container := (
		_find_node_recursive(vehicle_scene, "VehiclePreviewContainer") as SubViewportContainer
	)
	assert_that(preview_container).is_not_null()
	assert_that(preview_container.size.x > 0.0).is_true()
	assert_that(preview_container.size.y > 0.0).is_true()

	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = preview_container.size * 0.5
	vehicle_scene.call("_on_vehicle_preview_gui_input", press_event)
	await runner.simulate_frames(1)
	assert_that((camera_brush as CameraBrush).drawing).is_true()
	assert_that((camera_brush as Node3D).global_position).is_not_equal(brush_before)

	var painting_snapshot: Dictionary = vehicle_scene.call("get_paint_debug_snapshot")
	assert_that(int(painting_snapshot.get("paint_hit_count", 0))).is_greater(0)
	assert_that((painting_snapshot.get("last_paint_hit", {}) as Dictionary).is_empty()).is_false()
	assert_that(int(painting_snapshot.get("overlay_apply_count", 0))).is_greater(0)

	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = preview_container.size * 0.5
	vehicle_scene.call("_on_vehicle_preview_gui_input", release_event)
	await runner.simulate_frames(1)
	assert_that((camera_brush as CameraBrush).drawing).is_false()

	var after_release_snapshot: Dictionary = vehicle_scene.call("get_paint_debug_snapshot")
	assert_that(after_release_snapshot.get("brush_drawing", true)).is_false()

	vehicle_scene.call("_on_clear_paint_pressed")
	assert_that((camera_brush as CameraBrush).drawing).is_false()


func test_reading_mode_scene_with_scene_runner() -> void:
	"""Test reading_mode.tscn initialization and basic scene validity.

	This is the critical gameplay scene that needs comprehensive testing.
	Validates that the scene can initialize without errors and run for several frames.
	"""
	var runner = _create_scene_runner(READING_MODE_SCENE_PATH)

	# Verify scene loaded correctly
	assert_that(runner).is_not_null()
	assert_that(runner.scene()).is_not_null()

	# Allow scene to initialize and run for multiple frames
	await runner.simulate_frames(30, 100)

	# Scene should remain valid throughout simulation
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_reading_mode_home_button_returns_to_level_select() -> void:
	"""Smoke test: in-level home button should return to level select."""
	var runner = _create_scene_runner(READING_MODE_SCENE_PATH)
	await runner.simulate_frames(15, 100)
	var reading_scene = runner.scene()
	assert_that(reading_scene).is_not_null()
	var hud = reading_scene.get_node_or_null("ReadingHUD") as ReadingHUD
	assert_that(hud).is_not_null()
	var home_button := hud.get_home_button()
	assert_that(home_button).is_not_null()
	_home_requested_emitted = false
	hud.home_requested.connect(_mark_home_requested)
	home_button.emit_signal("pressed")
	await runner.simulate_frames(1, 100)
	assert_that(_home_requested_emitted).is_true()


func test_reading_mode_initialization() -> void:
	"""Test that reading_mode.tscn initializes game state correctly.

	Phase 3: Gameplay flow validation - verifies core game initialization.
	"""
	var runner = _create_scene_runner(READING_MODE_SCENE_PATH)

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
	var runner = _create_scene_runner(READING_MODE_SCENE_PATH)

	# Run through several frames to exercise initialization
	await runner.simulate_frames(15, 100)

	# If any orphan nodes are detected, GDUnit will report them
	# This test ensures the scene can run without creating leaked nodes
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_scene_runner_navigation_smoke_flow() -> void:
	"""Smoke test: instantiate all main UI scenes and exercise navigation actions."""

	# Main scene basic startup check
	var main_runner = _create_scene_runner(MAIN_SCENE_PATH)
	await main_runner.simulate_frames(2)
	assert_that(main_runner.scene()).is_not_null()
	assert_that(main_runner.scene().is_inside_tree()).is_true()

	# Level select scene UI navigation check
	var level_runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)
	await level_runner.simulate_frames(2)
	var level_scene = level_runner.scene()
	assert_that(level_scene).is_not_null()

	var config_button: Button = level_scene.get_node("Panel/VBoxContainer/ConfigButton")
	var start_button: Button = level_scene.get_node("Panel/VBoxContainer/StartButton")
	var config_page: Control = _find_node_by_name_token(level_scene, "ConfigPage") as Control
	if config_page == null:
		config_page = _find_node_recursive(level_scene, "ConfigPage") as Control

	assert_that(config_button).is_not_null()
	assert_that(start_button).is_not_null()
	assert_that(config_page).is_not_null()

	# Open and close configuration panel
	config_button.emit_signal("pressed")
	await level_runner.simulate_frames(1)
	assert_that(config_page.visible).is_true()

	var cancel_button: Button = _find_node_by_name_token(level_scene, "CancelButton") as Button
	cancel_button.emit_signal("pressed")
	await level_runner.simulate_frames(1)
	assert_that(config_page.visible).is_false()

	# Ensure start path exists (method accessible)
	assert_that(level_scene.has_method("_on_start_pressed")).is_true()

	# Simulate user pressing Start Race and validate scene transition to ReadingMode
	start_button.emit_signal("pressed")
	await level_runner.simulate_frames(5, 100)

	var tree_current_scene = level_scene.get_tree().current_scene
	assert_that(tree_current_scene).is_not_null()
	assert_that(tree_current_scene.get_name()).is_equal("ReadingMode")
	assert_that(tree_current_scene.is_inside_tree()).is_true()

	# Optionally check reading mode UI content exists
	var reading_hud = tree_current_scene.get_node_or_null("ReadingHUD")
	assert_that(reading_hud).is_not_null()

	# Keep a dedicated runner check for reading mode as final smoke endpoint
	var reading_runner = _create_scene_runner(READING_MODE_SCENE_PATH)
	await reading_runner.simulate_frames(10, 100)
	assert_that(reading_runner.scene()).is_not_null()
	assert_that(reading_runner.scene().is_inside_tree()).is_true()


func test_level_select_holiday_settings_flow() -> void:
	"""Test opening config, setting holiday to Christmas, and restoring settings."""
	var settings_store = ReadingSettingsStore.new()
	var original_settings = settings_store.load_settings()

	var runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)
	await runner.simulate_frames(2)
	var level_scene = runner.scene()
	assert_that(level_scene).is_not_null()

	var config_button: Button = level_scene.get_node("Panel/VBoxContainer/ConfigButton")
	var config_page: Control = _find_node_by_name_token(level_scene, "ConfigPage") as Control
	if config_page == null:
		config_page = _find_node_recursive(level_scene, "ConfigPage") as Control
	var holiday_mode_option: OptionButton = (
		_find_node_by_name_token(level_scene, "HolidayModeOption") as OptionButton
	)
	var holiday_name_option: OptionButton = (
		_find_node_by_name_token(level_scene, "HolidayNameOption") as OptionButton
	)
	var save_button: Button = _find_node_by_name_token(level_scene, "SaveButton") as Button

	assert_that(config_page.visible).is_false()
	config_button.emit_signal("pressed")
	await runner.simulate_frames(1)
	assert_that(config_page.visible).is_true()

	var holiday_on_idx = ReadingSettingsStore.HOLIDAY_MODES.find(
		ReadingSettingsStore.HOLIDAY_MODE_ON
	)
	var christmas_idx = ReadingSettingsStore.HOLIDAY_OPTIONS.find(
		ReadingSettingsStore.HOLIDAY_CHRISTMAS
	)
	assert_that(holiday_on_idx).is_greater_equal(0)
	assert_that(christmas_idx).is_greater_equal(0)

	holiday_mode_option.select(holiday_on_idx)
	holiday_name_option.select(christmas_idx)
	save_button.emit_signal("pressed")
	await runner.simulate_frames(1)
	assert_that(config_page.visible).is_false()

	var settings = settings_store.load_settings()
	assert_that(settings.get("holiday_mode")).is_equal(ReadingSettingsStore.HOLIDAY_MODE_ON)
	assert_that(settings.get("holiday_name")).is_equal(ReadingSettingsStore.HOLIDAY_CHRISTMAS)
	assert_that(ReadingSettingsStore.new().resolve_effective_holiday(settings)).is_equal(
		ReadingSettingsStore.HOLIDAY_CHRISTMAS
	)

	# restore previous settings
	config_button.emit_signal("pressed")
	await runner.simulate_frames(1)
	assert_that(config_page.visible).is_true()
	var none_idx = ReadingSettingsStore.HOLIDAY_OPTIONS.find(ReadingSettingsStore.HOLIDAY_NONE)
	var auto_idx = ReadingSettingsStore.HOLIDAY_MODES.find(ReadingSettingsStore.HOLIDAY_MODE_AUTO)
	assert_that(none_idx).is_greater_equal(0)
	assert_that(auto_idx).is_greater_equal(0)

	holiday_mode_option.select(auto_idx)
	holiday_name_option.select(none_idx)
	save_button.emit_signal("pressed")
	await runner.simulate_frames(1)
	assert_that(settings_store.load_settings().get("holiday_mode")).is_equal(
		ReadingSettingsStore.HOLIDAY_MODE_AUTO
	)

	# persist original settings to avoid side effects for other tests or dev env
	settings_store.save_settings(original_settings)
