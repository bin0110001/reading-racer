class_name TestSimpleSkyCloudSpawner
extends GdUnitTestSuite

func test_spawn_random_clouds() -> void:
	var spawner = SimpleSkyCloudSpawner.new()
	spawner.spawn_area = Aabb(Vector3(-10, 5, -10), Vector3(20, 10, 20))
	spawner.direction = Vector3(1, 0, 0)
	spawner.speed_range = Vector2(1.0, 2.0)

	spawner.spawn_random_clouds(4)
	assert_that(spawner.active_clouds.size()).is_equal(4)
	assert_that(spawner.get_child_count()).is_equal(4)

	# Ensure all clouds keep same direction velocity exponent
	for entry in spawner.active_clouds:
		assert_that(entry.speed).is_between(1.0, 2.0)
		assert_that(entry.node).is_not_null()

func test_clouds_move_same_direction() -> void:
	var spawner = SimpleSkyCloudSpawner.new()
	spawner.spawn_area = Aabb(Vector3(-10, 5, -10), Vector3(20, 10, 20))
	spawner.direction = Vector3(0, 0, 1)
	spawner.speed_range = Vector2(1.0, 1.0)

	spawner.spawn_random_clouds(1)
	var cloud = spawner.active_clouds[0].node
	var before_pos = cloud.global_transform.origin
	spawner._process(1.0)
	var after_pos = cloud.global_transform.origin
	assert_that(after_pos.z).is_greater(before_pos.z)
