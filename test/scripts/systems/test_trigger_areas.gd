class_name TestTriggerAreas
extends GdUnitTestSuite


func before_all() -> void:
	# no setup needed for these tests
	pass


func test_pickup_trigger_initialization() -> void:
	var trigger = ReadingPickupTrigger.new()
	assert_that(trigger).is_not_null()


func test_pickup_trigger_properties() -> void:
	var trigger = ReadingPickupTrigger.new()
	trigger.letter_index = 0
	trigger.letter = "A"
	trigger.phoneme_label = "ae"
	trigger.trigger_width = 8.0
	trigger.trigger_depth = 6.0
	trigger.position = Vector3(10.0, 2.3, 0.0)

	assert_that(trigger.letter).is_equal("A")
	assert_that(trigger.phoneme_label).is_equal("ae")
	assert_that(trigger.position.x).is_equal(10.0)


func test_pickup_trigger_has_signal() -> void:
	var trigger = ReadingPickupTrigger.new()
	assert_that(trigger.has_signal("pickup_triggered")).is_true()


func test_obstacle_trigger_initialization() -> void:
	var trigger = ReadingObstacleTrigger.new()
	assert_that(trigger).is_not_null()


func test_obstacle_trigger_has_signal() -> void:
	var trigger = ReadingObstacleTrigger.new()
	assert_that(trigger.has_signal("obstacle_hit")).is_true()


func test_obstacle_trigger_properties() -> void:
	var trigger = ReadingObstacleTrigger.new()
	trigger.obstacle_index = 0
	trigger.penalty_seconds = 0.5
	trigger.trigger_width = 4.0
	trigger.trigger_depth = 4.0

	assert_that(trigger.penalty_seconds).is_equal(0.5)
	assert_that(trigger.obstacle_index).is_equal(0)


func test_finish_gate_trigger_initialization() -> void:
	var trigger = ReadingFinishGateTrigger.new()
	assert_that(trigger).is_not_null()


func test_finish_gate_trigger_has_signal() -> void:
	var trigger = ReadingFinishGateTrigger.new()
	assert_that(trigger.has_signal("finish_gate_reached")).is_true()


func test_trigger_has_trigger_method() -> void:
	var pickup = ReadingPickupTrigger.new()
	assert_that(pickup.has_method("trigger_pickup")).is_true()

	var obstacle = ReadingObstacleTrigger.new()
	assert_that(obstacle.has_method("trigger_obstacle")).is_true()


func test_finish_gate_sets_pickups_state() -> void:
	var trigger = ReadingFinishGateTrigger.new()
	trigger.all_pickups_collected = false
	assert_that(trigger.all_pickups_collected).is_false()

	trigger.all_pickups_collected = true
	assert_that(trigger.all_pickups_collected).is_true()


func test_finish_gate_set_pickups_collected_method() -> void:
	var trigger = ReadingFinishGateTrigger.new()
	trigger.set_pickups_collected(false)
	assert_that(trigger.all_pickups_collected).is_false()

	trigger.set_pickups_collected(true)
	assert_that(trigger.all_pickups_collected).is_true()
