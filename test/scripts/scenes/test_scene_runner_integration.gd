## Scene Runner Integration Tests - Tests scenes with simulated input and gameplay
## Phase 2-3: Comprehensive scene validation using Scene Runner
extends GdUnitTestSuite

const ReadingSettingsStoreScript = preload("res://scripts/reading/settings_store.gd")

const MAIN_SCENE_PATH = "res://scenes/main.tscn"
const LEVEL_SELECT_SCENE_PATH = "res://scenes/level_select.tscn"
const VEHICLE_SELECT_SCENE_PATH = "res://scenes/vehicle_select.tscn"
const READING_MODE_SCENE_PATH = "res://scenes/level_types/pronunciation_mode.tscn"
const WHOLE_WORD_MODE_SCENE_PATH = "res://scenes/level_types/whole_word_mode.tscn"

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


func _count_nodes_by_name_token(node: Node, token: String) -> int:
	var count := 0
	if node.name.find(token) >= 0:
		count += 1
	for child in node.get_children():
		if child is Node:
			count += _count_nodes_by_name_token(child, token)
	return count


func _mark_home_requested() -> void:
	_home_requested_emitted = true


func test_main_scene_with_scene_runner() -> void:
	"""Test main.tscn initialization and basic scene validity."""
	var runner = _create_scene_runner(MAIN_SCENE_PATH)

	# Verify scene loaded correctly
	assert_that(runner).is_not_null()
	assert_that(runner.scene()).is_not_null()

	# Allow scene to initialize for one frame
	runner.simulate_frames(1)

	# Scene should remain valid by still being instantiated and in tree
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_main_scene_debug_menu_button_opens_debug_home() -> void:
	"""Smoke test: the main screen debug button must open the debug home menu."""
	var runner = _create_scene_runner(MAIN_SCENE_PATH)
	runner.simulate_frames(2)

	var main_scene = runner.scene()
	assert_that(main_scene).is_not_null()

	var debug_button := _find_node_by_name_token(main_scene, "DebugMenuButton") as Button
	assert_that(debug_button).is_not_null()

	debug_button.emit_signal("pressed")
	runner.simulate_frames(1)

	var debug_menu := _find_node_by_name_token(main_scene, "DebugHomeMenu")
	assert_that(debug_menu).is_not_null()
	assert_that(debug_menu.is_inside_tree()).is_true()
	assert_that(_find_node_by_name_token(debug_menu, "WholeWordModeButton")).is_not_null()


func test_level_select_scene_with_scene_runner() -> void:
	"""Test level_select.tscn initialization and basic scene validity."""
	var runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)

	# Verify scene loaded correctly
	assert_that(runner).is_not_null()
	assert_that(runner.scene()).is_not_null()

	# Allow scene to initialize
	runner.simulate_frames(1)

	# Scene should remain valid by still being instantiated and in tree
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_main_scene_loads_under_one_second() -> void:
	"""Smoke test: main menu startup must complete within 1 second."""
	var start_ms := Time.get_ticks_msec()
	var runner = _create_scene_runner(MAIN_SCENE_PATH)
	runner.simulate_frames(2)
	var elapsed_ms := Time.get_ticks_msec() - start_ms

	assert_that(elapsed_ms).is_less(1000)
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_level_select_launch_completes_under_one_second() -> void:
	"""Smoke test: selecting a level should launch reading mode within 1 second."""
	var runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)
	runner.simulate_frames(2)

	var level_scene = runner.scene()
	assert_that(level_scene).is_not_null()

	var level_buttons = level_scene.get("level_buttons")
	if typeof(level_buttons) != TYPE_ARRAY:
		level_buttons = []

	var wait_frames := 0
	while level_buttons.size() == 0 and wait_frames < 10:
		runner.simulate_frames(1)
		wait_frames += 1
		level_buttons = level_scene.get("level_buttons")
		if typeof(level_buttons) != TYPE_ARRAY:
			level_buttons = []

	if level_buttons.size() == 0:
		level_buttons = level_scene.get("level_option_buttons")
		if typeof(level_buttons) != TYPE_ARRAY:
			level_buttons = []

	if level_buttons.size() == 0:
		return

	var first_level_button := level_buttons[0] as Button
	assert_that(first_level_button).is_not_null()

	var start_ms := Time.get_ticks_msec()
	first_level_button.emit_signal("pressed")
	var mode_buttons: Array = level_scene.get("mode_buttons") as Array
	var mode_wait_frames := 0
	while mode_buttons.size() == 0 and mode_wait_frames < 10:
		runner.simulate_frames(1)
		mode_wait_frames += 1
		mode_buttons = level_scene.get("mode_buttons") as Array

	assert_that(mode_buttons.size()).is_greater(0)
	var first_mode_button := mode_buttons[0] as Button
	assert_that(first_mode_button).is_not_null()
	first_mode_button.emit_signal("pressed")
	var start_button := level_scene.get("final_start_button") as Button
	assert_that(start_button).is_not_null()
	start_button.emit_signal("pressed")
	runner.simulate_frames(3)
	var elapsed_ms := Time.get_ticks_msec() - start_ms

	assert_that(elapsed_ms).is_less(1000)
	assert_that(level_scene.get_tree().root.has_meta("reading_mode_start_requested_ms")).is_true()
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_level_select_word_choice_launches_whole_word_mode_under_one_second() -> void:
	"""Smoke test: word-choice mode should launch the whole-word scene quickly."""
	var runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)
	runner.simulate_frames(2)

	var level_scene = runner.scene()
	assert_that(level_scene).is_not_null()

	var level_buttons = level_scene.get("level_buttons")
	if typeof(level_buttons) != TYPE_ARRAY:
		level_buttons = []
	while level_buttons.size() == 0:
		runner.simulate_frames(1)
		level_buttons = level_scene.get("level_buttons")
		if typeof(level_buttons) != TYPE_ARRAY:
			level_buttons = []

	var first_level_button := level_buttons[0] as Button
	assert_that(first_level_button).is_not_null()
	first_level_button.emit_signal("pressed")
	runner.simulate_frames(1)

	var mode_buttons: Array = level_scene.get("mode_buttons") as Array
	assert_that(mode_buttons.size()).is_greater_equal(2)
	var whole_word_button := mode_buttons[1] as Button
	assert_that(whole_word_button).is_not_null()

	var start_ms := Time.get_ticks_msec()
	whole_word_button.emit_signal("pressed")
	runner.simulate_frames(2)
	var elapsed_ms := Time.get_ticks_msec() - start_ms

	assert_that(elapsed_ms).is_less(1000)
	assert_that(str(level_scene.get("selected_mode"))).is_equal("word_choice")
	assert_that(level_scene.get_tree().root.has_meta("reading_mode_start_requested_ms")).is_false()

	var whole_word_runner = _create_scene_runner(WHOLE_WORD_MODE_SCENE_PATH)
	whole_word_runner.simulate_frames(10, 100)
	var whole_word_scene := whole_word_runner.scene()
	assert_that(whole_word_scene).is_not_null()
	assert_that(whole_word_scene.is_inside_tree()).is_true()
	var whole_word_display_count := _count_nodes_by_name_token(whole_word_scene, "WordLaneDisplay")
	assert_that(whole_word_display_count).is_equal(3)
	whole_word_scene.queue_free()


func test_level_select_carousel_is_visible_and_laid_out() -> void:
	"""Regression: the level carousel must be visible and occupy real screen space."""
	var runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)
	runner.simulate_frames(5, 100)

	var level_scene = runner.scene()
	assert_that(level_scene).is_not_null()

	var carousel_scroll := level_scene.get("carousel_scroll") as ScrollContainer
	var level_buttons = level_scene.get("level_buttons")
	if typeof(level_buttons) != TYPE_ARRAY:
		level_buttons = []
	var config_button := level_scene.get("config_button") as Button

	assert_that(carousel_scroll).is_not_null()
	assert_that(carousel_scroll.visible).is_true()
	assert_that(carousel_scroll.size.x).is_greater(0.0)
	assert_that(carousel_scroll.size.y).is_greater(0.0)
	assert_that(level_buttons.size()).is_greater(0)
	assert_that(level_buttons[0] is Button).is_true()
	assert_that((level_buttons[0] as Control).size.x).is_greater(0.0)
	assert_that((level_buttons[0] as Control).size.y).is_greater(0.0)
	assert_that((level_buttons[0] as Control).global_position.y).is_less_equal(
		(config_button as Control).global_position.y
	)


func test_level_select_settings_menu_opens_and_saves() -> void:
	"""Regression: the settings menu must reveal controls and persist changes."""
	var settings_store = ReadingSettingsStoreScript.new()
	var original_settings := settings_store.load_settings()

	var runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)
	runner.simulate_frames(2)

	var level_scene = runner.scene()
	assert_that(level_scene).is_not_null()

	var config_button := level_scene.get("config_button") as Button
	var panel: Control = null
	var main_vbox = level_scene.get("main_vbox")
	if main_vbox is VBoxContainer:
		panel = (main_vbox as VBoxContainer).get_parent() as Control
	if panel == null:
		panel = _find_node_by_name_token(level_scene, "Panel") as Control
	var config_page := level_scene.get("config_page") as Control
	var config_page_content := level_scene.get("config_page_content") as Control
	var steering_option := level_scene.get("steering_option") as OptionButton
	var map_option := level_scene.get("map_option") as OptionButton
	var save_button := level_scene.get("save_button") as Button
	var cancel_button := level_scene.get("cancel_button") as Button

	assert_that(config_button).is_not_null()
	assert_that(panel).is_not_null()
	assert_that(config_page).is_not_null()
	assert_that(config_page_content).is_not_null()
	assert_that(steering_option).is_not_null()
	assert_that(map_option).is_not_null()
	assert_that(save_button).is_not_null()
	assert_that(cancel_button).is_not_null()

	assert_that(config_page.visible).is_false()
	assert_that(config_page_content.visible).is_false()

	config_button.emit_signal("pressed")
	runner.simulate_frames(1)

	assert_that(panel.visible).is_false()
	assert_that(config_page.visible).is_true()
	assert_that(config_page_content.visible).is_true()
	assert_that(save_button.visible).is_true()
	assert_that(cancel_button.visible).is_true()

	var steering_index: int = maxi(0, steering_option.item_count - 1)
	var map_index: int = maxi(0, map_option.item_count - 1)
	steering_option.select(steering_index)
	map_option.select(map_index)
	save_button.emit_signal("pressed")
	runner.simulate_frames(1)

	var saved_settings := settings_store.load_settings()
	assert_that(saved_settings.get("steering_type", "")).is_equal(
		ReadingSettingsStoreScript.STEERING_TYPES[steering_index]
	)
	assert_that(saved_settings.get("map_style", "")).is_equal(
		ReadingSettingsStoreScript.MAP_STYLES[map_index]
	)
	assert_that(config_page.visible).is_false()
	assert_that(config_page_content.visible).is_false()
	assert_that(panel.visible).is_true()

	settings_store.save_settings(original_settings)
	var restored_auto_settings = settings_store.load_settings()
	var christmas_date := {"year": 2026, "month": 12, "day": 25}
	(
		assert_that(
			ReadingSettingsStoreScript.new().resolve_effective_holiday(
				restored_auto_settings, christmas_date
			)
		)
		. is_equal(ReadingSettingsStore.HOLIDAY_CHRISTMAS)
	)


func test_level_select_main_screen_steering_buttons_save_selected_scheme() -> void:
	"""Regression: the main screen steering buttons must switch and persist the scheme."""
	var settings_store = ReadingSettingsStoreScript.new()
	var original_settings := settings_store.load_settings()

	var runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)
	runner.simulate_frames(2)

	var level_scene = runner.scene()
	assert_that(level_scene).is_not_null()

	var lane_switch_button := level_scene.get("lane_switch_button") as Button
	var smooth_steering_button := level_scene.get("smooth_steering_button") as Button
	var config_button := level_scene.get("config_button") as Button
	var level_buttons = level_scene.get("level_buttons")
	if typeof(level_buttons) != TYPE_ARRAY:
		level_buttons = []
	assert_that(level_buttons.size()).is_greater(0)
	var first_level_button := level_buttons[0] as Button

	assert_that(lane_switch_button).is_not_null()
	assert_that(smooth_steering_button).is_not_null()
	assert_that(config_button).is_not_null()
	assert_that(first_level_button).is_not_null()
	assert_that(first_level_button.custom_minimum_size.x).is_equal(100.0)
	assert_that(first_level_button.custom_minimum_size.y).is_equal(100.0)
	assert_that(lane_switch_button.icon).is_not_null()
	assert_that(smooth_steering_button.icon).is_not_null()
	assert_that(lane_switch_button.toggle_mode).is_true()
	assert_that(smooth_steering_button.toggle_mode).is_true()
	assert_that(lane_switch_button.button_pressed).is_true()
	assert_that(smooth_steering_button.button_pressed).is_false()

	level_scene.call("_on_smooth_steering_button_pressed")
	runner.simulate_frames(1)
	var expected_smooth := ReadingSettingsStore.STEERING_TYPE_SMOOTH_STEERING
	assert_that(bool(level_scene.get("selected_steering_type") == expected_smooth)).is_true()
	assert_that(lane_switch_button.button_pressed).is_false()
	assert_that(smooth_steering_button.button_pressed).is_true()

	first_level_button.emit_signal("pressed")
	runner.simulate_frames(1)
	assert_that(level_scene.get_tree().current_scene.get_name()).is_equal("ReadingMode")

	var lane_runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)
	lane_runner.simulate_frames(2)
	var lane_scene = lane_runner.scene()
	assert_that(lane_scene).is_not_null()
	var lane_button := lane_scene.get("lane_switch_button") as Button
	assert_that(lane_button).is_not_null()
	lane_button.emit_signal("pressed")
	lane_runner.simulate_frames(1)
	assert_that(lane_button.button_pressed).is_true()
	(
		assert_that(bool((lane_scene.get("smooth_steering_button") as Button).button_pressed))
		. is_false()
	)
	(
		assert_that(
			bool(
				(
					lane_scene.get("selected_steering_type")
					== ReadingSettingsStore.STEERING_TYPE_LANE_CHANGE
				)
			)
		)
		. is_true()
	)

	settings_store.save_settings(original_settings)


func test_level_select_level_and_mode_buttons_respond_within_frames() -> void:
	"""Smoke test: level selection must reveal modes quickly and keep the scene responsive."""
	var runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)
	runner.simulate_frames(3, 50)

	var level_scene = runner.scene()
	assert_that(level_scene).is_not_null()
	assert_that(level_scene.is_inside_tree()).is_true()

	var level_buttons: Array = level_scene.get("level_buttons") as Array
	assert_that(level_buttons.size()).is_greater(1)
	assert_that((level_buttons[0] as Button).text).is_equal("Tests")

	var target_button := level_buttons[1] as Button
	assert_that(target_button).is_not_null()

	# Press a level button and wait for the mode row to update.
	target_button.emit_signal("pressed")
	var mode_buttons: Array = level_scene.get("mode_buttons") as Array

	var frames_waited := 0
	while frames_waited < 10:
		runner.simulate_frames(1, 50)
		frames_waited += 1
		mode_buttons = level_scene.get("mode_buttons") as Array
		if mode_buttons.size() > 0:
			break

	mode_buttons = level_scene.get("mode_buttons") as Array
	assert_that(mode_buttons.size()).is_equal(2)
	assert_that((mode_buttons[0] as Button).text).is_equal("📖")
	assert_that((mode_buttons[0] as Button).icon).is_null()
	assert_that((mode_buttons[0] as Button).tooltip_text).is_equal(
		"Pronounce words from the selected reading list."
	)
	assert_that((mode_buttons[1] as Button).text).is_equal("Select Word")
	assert_that(str(level_scene.get("selected_level_label"))).is_not_empty()
	assert_that(frames_waited).is_less(10)
	assert_that(level_scene.is_inside_tree()).is_true()


func test_vehicle_select_scene_with_scene_runner() -> void:
	"""Smoke test: vehicle select initializes, exposes paint controls, and can paint."""
	var runner = _create_scene_runner(VEHICLE_SELECT_SCENE_PATH)
	runner.simulate_frames(3)

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
	runner.simulate_frames(1)
	var side_snapshot: Dictionary = vehicle_scene.call("get_paint_debug_snapshot")
	var rotation_degrees: Vector3 = side_snapshot.get("vehicle_rotation_degrees", Vector3.ZERO)
	assert_that(rotation_degrees.y).is_equal(90.0)

	rotate_reset_button.emit_signal("pressed")
	runner.simulate_frames(1)
	var reset_snapshot: Dictionary = vehicle_scene.call("get_paint_debug_snapshot")
	rotation_degrees = reset_snapshot.get("vehicle_rotation_degrees", Vector3.ZERO)
	assert_that(rotation_degrees.is_equal_approx(Vector3.ZERO)).is_true()

	runner.simulate_frames(2)
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
	var preview_instance := vehicle_scene.get("vehicle_preview_instance") as Node3D
	assert_that(preview_instance).is_not_null()
	var decals_before_drag := int(
		(vehicle_scene.call("_collect_decals", preview_instance) as Array).size()
	)

	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = preview_container.size * 0.5
	vehicle_scene.call("_on_vehicle_preview_gui_input", press_event)
	runner.simulate_frames(1)
	assert_that((camera_brush as CameraBrush).drawing).is_true()
	assert_that((camera_brush as Node3D).global_position).is_not_equal(brush_before)
	var decals_after_drag := int(
		(vehicle_scene.call("_collect_decals", preview_instance) as Array).size()
	)
	assert_that(decals_after_drag).is_greater(decals_before_drag)

	var painting_snapshot: Dictionary = vehicle_scene.call("get_paint_debug_snapshot")

	var overlay_apply_before := int(painting_snapshot.get("overlay_apply_count", 0))

	# Non-regression: live brush movement should not force repeated atlas apply calls.
	runner.simulate_frames(2)
	var paint_snapshot2: Dictionary = vehicle_scene.call("get_paint_debug_snapshot")
	var overlay_apply_after := int(paint_snapshot2.get("overlay_apply_count", 0))
	assert_that(overlay_apply_after).is_less_equal(overlay_apply_before + 1)

	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = preview_container.size * 0.5
	vehicle_scene.call("_on_vehicle_preview_gui_input", release_event)
	runner.simulate_frames(1)
	assert_that((camera_brush as CameraBrush).drawing).is_false()

	var after_release_snapshot: Dictionary = vehicle_scene.call("get_paint_debug_snapshot")
	assert_that(after_release_snapshot.get("brush_drawing", true)).is_false()

	vehicle_scene.call("_on_clear_paint_pressed")
	assert_that((camera_brush as CameraBrush).drawing).is_false()


func test_vehicle_select_scene_brush_shape_selection_updates_camera_brush() -> void:
	"""Regression: brush shape selection should propagate into the live CameraBrush texture."""
	var runner = _create_scene_runner(VEHICLE_SELECT_SCENE_PATH)
	runner.simulate_frames(3)

	var vehicle_scene = runner.scene()
	assert_that(vehicle_scene).is_not_null()

	var camera_brush := _find_node_recursive(vehicle_scene, "CameraBrush") as CameraBrush
	assert_that(camera_brush).is_not_null()
	assert_that(camera_brush.brush_shape).is_not_null()

	var initial_brush_image := camera_brush.brush_shape
	assert_that(initial_brush_image.get_pixel(0, 0).a).is_equal(0.0)
	assert_that(initial_brush_image.get_pixel(128, 128).a).is_equal(1.0)

	vehicle_scene.call("_on_brush_shape_selected", 1)
	runner.simulate_frames(1)

	var updated_snapshot: Dictionary = vehicle_scene.call("get_paint_debug_snapshot")
	assert_that(str(updated_snapshot.get("selected_brush_shape", ""))).is_equal("square")

	var updated_brush_image := camera_brush.brush_shape
	assert_that(updated_brush_image).is_not_null()
	assert_that(updated_brush_image.get_pixel(0, 0).a).is_equal(0.0)
	assert_that(updated_brush_image.get_pixel(128, 128).a).is_equal(1.0)

	vehicle_scene.call("_on_brush_shape_selected", 0)
	runner.simulate_frames(1)
	updated_snapshot = vehicle_scene.call("get_paint_debug_snapshot")
	assert_that(str(updated_snapshot.get("selected_brush_shape", ""))).is_equal("circle")


func test_reading_mode_scene_with_scene_runner() -> void:
	var runner = _create_scene_runner(READING_MODE_SCENE_PATH)
	assert_that(runner).is_not_null()
	assert_that(runner.scene()).is_not_null()
	runner.simulate_frames(30, 100)
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_reading_mode_home_button_returns_to_level_select() -> void:
	"""Smoke test: in-level home button should return to level select."""
	var runner = _create_scene_runner(READING_MODE_SCENE_PATH)
	runner.simulate_frames(15, 100)
	var reading_scene = runner.scene()
	assert_that(reading_scene).is_not_null()
	var hud = reading_scene.get_node_or_null("ReadingHUD")
	assert_that(hud).is_not_null()
	var home_button: Button = hud.get_home_button()
	assert_that(home_button).is_not_null()
	_home_requested_emitted = false
	hud.home_requested.connect(_mark_home_requested)
	home_button.emit_signal("pressed")
	runner.simulate_frames(1, 100)
	assert_that(_home_requested_emitted).is_true()


func test_reading_mode_initialization() -> void:
	"""Test that pronunciation_mode.tscn initializes game state correctly.

	Phase 3: Gameplay flow validation - verifies core game initialization.
	"""
	var runner = _create_scene_runner(READING_MODE_SCENE_PATH)

	# Let the scene fully initialize
	runner.simulate_frames(5, 100)

	var scene_root = runner.scene()
	assert_that(scene_root).is_not_null()

	# Basic validity checks - scene should be ready
	assert_that(scene_root).is_not_null()
	assert_that(scene_root.is_inside_tree()).is_true()


func test_reading_mode_no_orphan_nodes() -> void:
	"""Test that pronunciation_mode.tscn doesn't create orphan nodes during initialization.

	GDUnit4 orphan detection is enabled; this test documents that we're checking for it.
	"""
	var runner = _create_scene_runner(READING_MODE_SCENE_PATH)

	# Run through several frames to exercise initialization
	runner.simulate_frames(15, 100)

	# If any orphan nodes are detected, GDUnit will report them
	# This test ensures the scene can run without creating leaked nodes
	assert_that(runner.scene()).is_not_null()
	assert_that(runner.scene().is_inside_tree()).is_true()


func test_scene_runner_navigation_smoke_flow() -> void:
	"""Smoke test: instantiate all main UI scenes and exercise navigation actions."""

	# Main scene basic startup check
	var main_runner = _create_scene_runner(MAIN_SCENE_PATH)
	main_runner.simulate_frames(2)
	assert_that(main_runner.scene()).is_not_null()
	assert_that(main_runner.scene().is_inside_tree()).is_true()

	# Level select scene UI navigation check
	var level_runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)
	level_runner.simulate_frames(2)
	var level_scene = level_runner.scene()
	assert_that(level_scene).is_not_null()

	var config_button: Button = level_scene.get_node("Panel/VBoxContainer/ConfigButton")
	var level_buttons: Array = level_scene.get("level_buttons") as Array
	var config_page: Control = _find_node_by_name_token(level_scene, "ConfigPage") as Control
	if config_page == null:
		config_page = _find_node_recursive(level_scene, "ConfigPage") as Control

	assert_that(config_button).is_not_null()
	assert_that(level_buttons.size()).is_greater(0)
	assert_that(config_page).is_not_null()

	# Open and close configuration panel
	config_button.emit_signal("pressed")
	level_runner.simulate_frames(1)
	assert_that(config_page.visible).is_true()

	var cancel_button: Button = _find_node_by_name_token(level_scene, "CancelButton") as Button
	cancel_button.emit_signal("pressed")
	level_runner.simulate_frames(1)
	assert_that(config_page.visible).is_false()

	# Simulate user pressing a level card, then a mode, then start.
	var first_level_button := level_buttons[0] as Button
	assert_that(first_level_button).is_not_null()
	first_level_button.emit_signal("pressed")
	level_runner.simulate_frames(2, 100)

	var mode_buttons: Array = level_scene.get("mode_buttons") as Array
	assert_that(mode_buttons.size()).is_equal(2)
	var first_mode_button := mode_buttons[0] as Button
	assert_that(first_mode_button).is_not_null()
	first_mode_button.emit_signal("pressed")

	var start_button := level_scene.get("final_start_button") as Button
	assert_that(start_button).is_not_null()
	start_button.emit_signal("pressed")
	level_runner.simulate_frames(10, 100)
	assert_that(level_runner.scene()).is_not_null()
	assert_that(level_runner.scene().is_inside_tree()).is_true()

	# Keep a dedicated runner check for reading mode as final smoke endpoint
	var reading_runner = _create_scene_runner(READING_MODE_SCENE_PATH)
	reading_runner.simulate_frames(10, 100)
	assert_that(reading_runner.scene()).is_not_null()
	assert_that(reading_runner.scene().is_inside_tree()).is_true()

	var whole_word_runner = _create_scene_runner(WHOLE_WORD_MODE_SCENE_PATH)
	whole_word_runner.simulate_frames(10, 100)
	assert_that(whole_word_runner.scene()).is_not_null()
	assert_that(whole_word_runner.scene().is_inside_tree()).is_true()
	var whole_word_runner_display_count := _count_nodes_by_name_token(
		whole_word_runner.scene(), "WordLaneDisplay"
	)
	assert_that(whole_word_runner_display_count).is_equal(3)


func test_level_select_holiday_settings_flow() -> void:
	var settings_store = ReadingSettingsStoreScript.new()
	var original_settings = settings_store.load_settings()

	var runner = _create_scene_runner(LEVEL_SELECT_SCENE_PATH)
	runner.simulate_frames(2)
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
	var christmas_date := {"year": 2026, "month": 12, "day": 25}
	var easter_date := {"year": 2026, "month": 4, "day": 5}

	assert_that(config_page.visible).is_false()
	config_button.emit_signal("pressed")
	runner.simulate_frames(1)
	assert_that(config_page.visible).is_true()

	var holiday_on_idx = ReadingSettingsStoreScript.HOLIDAY_MODES.find(
		ReadingSettingsStoreScript.HOLIDAY_MODE_ON
	)
	var christmas_idx = ReadingSettingsStoreScript.HOLIDAY_OPTIONS.find(
		ReadingSettingsStoreScript.HOLIDAY_CHRISTMAS
	)
	assert_that(holiday_on_idx).is_greater_equal(0)
	assert_that(christmas_idx).is_greater_equal(0)
	var easter_idx = ReadingSettingsStoreScript.HOLIDAY_OPTIONS.find(
		ReadingSettingsStoreScript.HOLIDAY_EASTER
	)
	assert_that(easter_idx).is_greater_equal(0)

	holiday_mode_option.select(holiday_on_idx)
	holiday_name_option.select(christmas_idx)
	save_button.emit_signal("pressed")
	runner.simulate_frames(1)
	assert_that(config_page.visible).is_false()

	var settings = settings_store.load_settings()
	assert_that(settings.get("holiday_mode")).is_equal(ReadingSettingsStoreScript.HOLIDAY_MODE_ON)
	assert_that(settings.get("holiday_name")).is_equal(ReadingSettingsStoreScript.HOLIDAY_CHRISTMAS)
	var resolved_christmas := ReadingSettingsStoreScript.new().resolve_effective_holiday(
		settings, christmas_date
	)
	assert_that(resolved_christmas).is_equal(ReadingSettingsStoreScript.HOLIDAY_CHRISTMAS)

	# Save Easter too so the UI and settings round-trip both seasonal options.
	config_button.emit_signal("pressed")
	runner.simulate_frames(1)
	assert_that(config_page.visible).is_true()
	holiday_mode_option.select(holiday_on_idx)
	holiday_name_option.select(easter_idx)
	save_button.emit_signal("pressed")
	runner.simulate_frames(1)

	var easter_settings = settings_store.load_settings()
	assert_that(easter_settings.get("holiday_mode")).is_equal(
		ReadingSettingsStoreScript.HOLIDAY_MODE_ON
	)
	assert_that(easter_settings.get("holiday_name")).is_equal(
		ReadingSettingsStoreScript.HOLIDAY_EASTER
	)
	var resolved_easter := ReadingSettingsStoreScript.new().resolve_effective_holiday(
		easter_settings, easter_date
	)
	assert_that(resolved_easter).is_equal(ReadingSettingsStoreScript.HOLIDAY_EASTER)

	# restore previous settings
	config_button.emit_signal("pressed")
	runner.simulate_frames(1)
	assert_that(config_page.visible).is_true()
	var none_idx = ReadingSettingsStoreScript.HOLIDAY_OPTIONS.find(
		ReadingSettingsStoreScript.HOLIDAY_NONE
	)
	var auto_idx = ReadingSettingsStoreScript.HOLIDAY_MODES.find(
		ReadingSettingsStoreScript.HOLIDAY_MODE_AUTO
	)
	assert_that(none_idx).is_greater_equal(0)
	assert_that(auto_idx).is_greater_equal(0)

	holiday_mode_option.select(auto_idx)
	holiday_name_option.select(none_idx)
	save_button.emit_signal("pressed")
	runner.simulate_frames(1)
	assert_that(settings_store.load_settings().get("holiday_mode")).is_equal(
		ReadingSettingsStoreScript.HOLIDAY_MODE_AUTO
	)

	# persist original settings to avoid side effects for other tests or dev env
	settings_store.save_settings(original_settings)
