class_name TestControlProfiles
extends GdUnitTestSuite

const MovementSystemScript = preload("res://scripts/reading/systems/MovementSystem.gd")


func before_all() -> void:
	pass


func test_lane_change_controller_creation() -> void:
	var controller = LaneChangeController.new()
	assert_that(controller).is_not_null()


func test_lane_change_controller_mode_name() -> void:
	var controller = LaneChangeController.new()
	assert_that(controller.mode_name).is_equal("lane_change")


func test_smooth_steering_controller_creation() -> void:
	var controller = SmoothSteeringController.new()
	assert_that(controller).is_not_null()


func test_smooth_steering_controller_mode_name() -> void:
	var controller = SmoothSteeringController.new()
	assert_that(controller.mode_name).is_equal("smooth_steering")


func test_throttle_steering_controller_creation() -> void:
	var controller = ThrottleSteeringController.new()
	assert_that(controller).is_not_null()


func test_throttle_steering_controller_mode_name() -> void:
	var controller = ThrottleSteeringController.new()
	assert_that(controller.mode_name).is_equal("throttle_steering")


func test_control_profile_methods_exist() -> void:
	var controllers = [
		LaneChangeController.new(), SmoothSteeringController.new(), ThrottleSteeringController.new()
	]

	for controller in controllers:
		assert_that(controller.has_method("handle_input")).is_true()
		assert_that(controller.has_method("update")).is_true()
		assert_that(controller.has_method("get_steering_influence")).is_true()
		assert_that(controller.has_method("consume_lane_delta")).is_true()


func test_steering_influence_values() -> void:
	var lane_controller = LaneChangeController.new()
	var smooth_controller = SmoothSteeringController.new()
	var throttle_controller = ThrottleSteeringController.new()

	# Lane change should have 100% (1.0) auto-steer
	var lane_influence = lane_controller.get_steering_influence(0.0, PI / 4.0)
	assert_that(abs(lane_influence - 1.0)).is_less_equal(0.1)

	# Smooth steering should have partial auto-steer (~50%)
	var smooth_influence = smooth_controller.get_steering_influence(0.0, PI / 4.0)
	assert_that(smooth_influence).is_greater(0.3)
	assert_that(smooth_influence).is_less(0.7)

	# Throttle steering should have 0% auto-steer
	var throttle_influence = throttle_controller.get_steering_influence(0.0, PI / 4.0)
	assert_that(abs(throttle_influence - 0.0)).is_less_equal(0.1)


func test_smooth_steering_moves_laterally_with_input() -> void:
	var controller = SmoothSteeringController.new()
	controller.steer_input = 1.0
	controller.update(0.25)

	var movement_system = MovementSystemScript.new(controller)
	movement_system.update_position_and_heading(0.25, {"heading": 0.0})

	assert_that(movement_system.player_lane_offset).is_greater(0.0)
	assert_that(movement_system.player_lane_offset).is_less_equal(4.0)


func test_lateral_movement_does_not_bank_the_vehicle() -> void:
	var controller = LaneChangeController.new()
	var movement_system = MovementSystemScript.new(controller)
	movement_system.player_heading = 0.0
	movement_system.player_lane_offset = 0.0

	var neutral_basis := movement_system.get_player_basis()
	movement_system.player_lane_offset = 4.0
	var offset_basis := movement_system.get_player_basis()

	assert_that(offset_basis.is_equal_approx(neutral_basis)).is_true()


func test_keyboard_lane_input_works_in_swipe_and_tilt_modes() -> void:
	var controller = ReadingControlProfile.new()
	var up_event := InputEventAction.new()
	up_event.action = ReadingControlProfile.ACTION_MOVE_UP
	up_event.pressed = true
	var down_event := InputEventAction.new()
	down_event.action = ReadingControlProfile.ACTION_MOVE_DOWN
	down_event.pressed = true

	controller.set_mode(ReadingSettingsStore.CONTROL_MODE_SWIPE)
	controller.handle_input(up_event)
	assert_that(controller.consume_lane_delta(0.016)).is_equal(-1)

	controller.set_mode(ReadingSettingsStore.CONTROL_MODE_TILT)
	controller.handle_input(down_event)
	assert_that(controller.consume_lane_delta(0.016)).is_equal(1)
