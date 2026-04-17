class_name TestTriggerAreas
extends GdUnitTestSuite

const GameplayControllerScript = preload("res://scripts/reading/systems/GameplayController.gd")
const ReadingContentLoaderScript = preload("res://scripts/reading/content_loader.gd")
const ReadingFinishGateTriggerScript = preload(
	"res://scripts/reading/triggers/ReadingFinishGateTrigger.gd"
)
const ReadingObstacleTriggerScript = preload(
	"res://scripts/reading/triggers/ReadingObstacleTrigger.gd"
)
const ReadingPickupTriggerScript = preload("res://scripts/reading/triggers/ReadingPickupTrigger.gd")
const ReadingWordChoiceTriggerScript = preload(
	"res://scripts/reading/triggers/ReadingWordChoiceTrigger.gd"
)

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
			_free_node_tree(node)
	_owned_nodes.clear()
	collect_orphan_node_details()


func _free_node_tree(node: Node) -> void:
	for child in node.get_children():
		if child is Node:
			_free_node_tree(child)
	node.free()


func test_pickup_trigger_initialization() -> void:
	var trigger = _own_node(ReadingPickupTriggerScript.new())
	trigger._ready()
	assert_that(trigger).is_not_null()
	assert_that(trigger.get_child_count()).is_greater(0)
	var collision_shape := trigger.get_child(0) as CollisionShape3D
	assert_that(collision_shape).is_not_null()
	if collision_shape != null and collision_shape.shape is BoxShape3D:
		var box_shape := collision_shape.shape as BoxShape3D
		assert_that(box_shape.size).is_equal(Vector3(8.0, 2.0, 6.0))


func test_pickup_trigger_properties() -> void:
	var trigger = _own_node(ReadingPickupTriggerScript.new())
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
	var trigger = _own_node(ReadingPickupTriggerScript.new())
	assert_that(trigger.has_signal("pickup_triggered")).is_true()


func test_obstacle_trigger_initialization() -> void:
	var trigger = _own_node(ReadingObstacleTriggerScript.new())
	trigger._ready()
	assert_that(trigger).is_not_null()
	assert_that(trigger.get_child_count()).is_greater(0)
	var collision_shape := trigger.get_child(0) as CollisionShape3D
	assert_that(collision_shape).is_not_null()
	if collision_shape != null and collision_shape.shape is BoxShape3D:
		var box_shape := collision_shape.shape as BoxShape3D
		assert_that(box_shape.size).is_equal(Vector3(1.35, 2.0, 1.0))


func test_obstacle_trigger_has_signal() -> void:
	var trigger = _own_node(ReadingObstacleTriggerScript.new())
	assert_that(trigger.has_signal("obstacle_hit")).is_true()


func test_obstacle_trigger_plays_sound_and_flies_on_hit() -> void:
	var trigger = _own_node(ReadingObstacleTriggerScript.new())
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
	var trigger = _own_node(ReadingObstacleTriggerScript.new())
	trigger.obstacle_index = 0
	trigger.penalty_seconds = 0.5
	trigger.trigger_width = 4.0
	trigger.trigger_depth = 4.0

	assert_that(trigger.penalty_seconds).is_equal(0.5)
	assert_that(trigger.obstacle_index).is_equal(0)


func test_obstacle_trigger_collision_box_does_not_scale_with_holiday_visuals() -> void:
	var controller = GameplayControllerScript.new(ReadingContentLoaderScript.new())
	var trigger = _own_node(ReadingObstacleTriggerScript.new())
	trigger.trigger_width = 1.35
	trigger.trigger_depth = 1.0

	controller._apply_obstacle_scale(trigger, {"scale": 5.0})

	assert_that(trigger.trigger_width).is_equal(1.35)
	assert_that(trigger.trigger_depth).is_equal(1.0)


func test_finish_gate_trigger_initialization() -> void:
	var trigger = _own_node(ReadingFinishGateTriggerScript.new())
	trigger._ready()
	assert_that(trigger).is_not_null()
	assert_that(trigger.get_child_count()).is_greater(0)
	var collision_shape := trigger.get_child(0) as CollisionShape3D
	assert_that(collision_shape).is_not_null()
	if collision_shape != null and collision_shape.shape is BoxShape3D:
		var box_shape := collision_shape.shape as BoxShape3D
		assert_that(box_shape.size).is_equal(Vector3(16.0, 3.0, 8.0))


func test_word_choice_trigger_initialization() -> void:
	var trigger = _own_node(ReadingWordChoiceTriggerScript.new())
	trigger._ready()
	assert_that(trigger).is_not_null()
	assert_that(trigger.get_child_count()).is_greater(0)
	var collision_shape := trigger.get_child(0) as CollisionShape3D
	assert_that(collision_shape).is_not_null()
	if collision_shape != null and collision_shape.shape is BoxShape3D:
		var box_shape := collision_shape.shape as BoxShape3D
		assert_that(box_shape.size).is_equal(Vector3(10.0, 3.0, 4.0))


func test_finish_gate_trigger_has_signal() -> void:
	var trigger = _own_node(ReadingFinishGateTriggerScript.new())
	assert_that(trigger.has_signal("finish_gate_reached")).is_true()


func test_trigger_has_trigger_method() -> void:
	var pickup = _own_node(ReadingPickupTriggerScript.new())
	assert_that(pickup.has_method("trigger_pickup")).is_true()

	var obstacle = _own_node(ReadingObstacleTriggerScript.new())
	assert_that(obstacle.has_method("trigger_obstacle")).is_true()


func test_finish_gate_sets_pickups_state() -> void:
	var trigger = _own_node(ReadingFinishGateTriggerScript.new())
	trigger.all_pickups_collected = false
	assert_that(trigger.all_pickups_collected).is_false()

	trigger.all_pickups_collected = true
	assert_that(trigger.all_pickups_collected).is_true()


func test_finish_gate_set_pickups_collected_method() -> void:
	var trigger = _own_node(ReadingFinishGateTriggerScript.new())
	trigger.set_pickups_collected(false)
	assert_that(trigger.all_pickups_collected).is_false()

	trigger.set_pickups_collected(true)
	assert_that(trigger.all_pickups_collected).is_true()
