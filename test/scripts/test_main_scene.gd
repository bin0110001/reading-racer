class_name TestMainScene
extends GdUnitTestSuite


func test_vehicle_velocity_zero_before_race() -> void:
	var scene = load("res://scenes/main.tscn")
	var main = scene.instantiate() as Node
	add_child(main)
	await get_tree().process_frame

	var game_manager = main.get_node("GameManager")
	assert_that(game_manager).is_not_null()
	assert_that(game_manager.call("GetRaceState")).is_equal(0)  # WAITING

	var vehicle_spawner = main.get_node("VehicleSpawner")
	assert_that(vehicle_spawner).is_not_null()
	var vehicles = vehicle_spawner.get_spawned_vehicles()

	for vehicle in vehicles:
		var v = vehicle.get_node("Sphere")
		var velocity = v.linear_velocity.length()
		assert_that(velocity).is_less(0.1).override_failure_message(
			"Vehicle velocity should be zero before race, was %f" % velocity
		)

	# Start countdown
	game_manager.call("StartCountdown")
	await get_tree().create_timer(3.1).timeout

	assert_that(game_manager.call("GetRaceState")).is_equal(2)  # RACING
	# After race starts, vehicles should have some velocity (assuming gravity or input)
	var has_moving_vehicle = false
	for vehicle in vehicles:
		var v = vehicle.get_node("Sphere")
		var velocity = v.linear_velocity.length()
		if velocity > 0.1:
			has_moving_vehicle = true
			break
	assert_that(has_moving_vehicle).is_true().override_failure_message(
		"At least one vehicle should be moving after race starts"
	)

	main.queue_free()
