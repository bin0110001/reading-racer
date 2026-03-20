class_name TestControlProfiles
extends GdUnitTestSuite


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
