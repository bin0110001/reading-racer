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


func test_obstacle_trigger_plays_sound_and_flies_on_hit() -> void:
	var trigger = ReadingObstacleTrigger.new()
	# In tests, _ready may not be called automatically until added to scene tree
	trigger._ready()
	assert_that(trigger.has_method("trigger_obstacle")).is_true()

	trigger.trigger_obstacle()
	assert_that(trigger.has_triggered).is_true()

	var sound_player = trigger.get_node_or_null("HitSoundPlayer") as AudioStreamPlayer3D
	assert_that(sound_player).is_not_null()
	if sound_player != null:
		assert_that(sound_player.stream).is_not_null()


func test_obstacle_trigger_properties() -> void:
	var trigger = ReadingObstacleTrigger.new()
	trigger.obstacle_index = 0
	trigger.penalty_seconds = 0.5
	trigger.trigger_width = 4.0
	trigger.trigger_depth = 4.0

	assert_that(trigger.penalty_seconds).is_equal(0.5)
	assert_that(trigger.obstacle_index).is_equal(0)


func test_obstacle_trigger_collision_box_does_not_scale_with_holiday_visuals() -> void:
	var controller = load("res://scripts/reading/systems/GameplayController.gd").new(
		load("res://scripts/reading/content_loader.gd").new()
	)
	var trigger = ReadingObstacleTrigger.new()
	trigger.trigger_width = 1.35
	trigger.trigger_depth = 1.0

	controller._apply_obstacle_scale(trigger, {"scale": 5.0})

	assert_that(trigger.trigger_width).is_equal(1.35)
	assert_that(trigger.trigger_depth).is_equal(1.0)


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
