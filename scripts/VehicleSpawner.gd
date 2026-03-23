class_name VehicleSpawner extends Node3D

const VehicleScript = preload("res://scripts/Vehicle.gd")

@export var vehicle_scene_path: String = "res://scenes/vehicle_template.tscn"

var vehicle_colors = ["yellow", "green", "purple", "red", "yellow", "green", "purple", "red"]
var spawned_vehicles: Array[Node3D] = []
var game_manager: GameManager
var race_track: RaceTrack


func _ready() -> void:
	game_manager = get_node_or_null("../GameManager")
	race_track = get_node_or_null("../RaceTrack")
	spawn_all_vehicles()


func spawn_all_vehicles() -> void:
	for i in range(8):
		var v = spawn_vehicle(i)
		if v:
			spawned_vehicles.append(v)


func spawn_vehicle(vehicle_index: int) -> Node3D:
	var vehicle = Node3D.new()
	vehicle.name = "Vehicle_%d" % vehicle_index
	vehicle.set_script(VehicleScript)

	var start_transform = (
		race_track.get_starting_position(vehicle_index) if race_track else Transform3D.IDENTITY
	)
	vehicle.global_transform = start_transform
	add_child(vehicle)

	vehicle.player_id = vehicle_index
	if game_manager:
		game_manager.register_player(vehicle_index, vehicle)

	_setup_vehicle_structure(vehicle, vehicle_index)
	return vehicle


func _setup_vehicle_structure(vehicle: Node3D, index: int) -> void:
	# Create sphere (physics body)
	var sphere = RigidBody3D.new()
	sphere.name = "Sphere"
	sphere.collision_layer = 8
	sphere.mass = 1000.0
	sphere.gravity_scale = 0.0
	sphere.linear_damp = 0.1
	sphere.angular_damp = 4.0
	sphere.continuous_collision_detection = true
	sphere.contact_monitor = true
	sphere.max_contacts_reported = 1

	var physics_mat = PhysicsMaterial.new()
	physics_mat.friction = 5.0
	sphere.physics_material_override = physics_mat

	var col_shape = CollisionShape3D.new()
	col_shape.shape = SphereShape3D.new()
	col_shape.shape.radius = 0.5
	sphere.add_child(col_shape)

	sphere.freeze = true
	sphere.linear_velocity = Vector3.ZERO
	sphere.angular_velocity = Vector3.ZERO
	vehicle.add_child(sphere)

	# Create raycast for ground detection
	var raycast = RayCast3D.new()
	raycast.name = "Ground"
	raycast.target_position = Vector3(0, -0.7, 0)
	vehicle.add_child(raycast)

	# Create container for model
	var container = Node3D.new()
	container.name = "Container"
	vehicle.add_child(container)

	# Load model if it exists
	var color = vehicle_colors[index] if index < vehicle_colors.size() else "yellow"
	var model_path = _get_vehicle_model_path(index)
	if ResourceLoader.exists(model_path):
		var model_scene = load(model_path) as PackedScene
		if model_scene:
			var model = model_scene.instantiate()
			container.add_child(model)

	# Create model structure
	var model_node = Node3D.new()
	model_node.name = "Model"
	container.add_child(model_node)

	var body = Node3D.new()
	body.name = "body"
	model_node.add_child(body)

	model_node.add_child(_create_wheel("wheel-front-left"))
	model_node.add_child(_create_wheel("wheel-front-right"))
	model_node.add_child(_create_wheel("wheel-back-left"))
	model_node.add_child(_create_wheel("wheel-back-right"))

	# Create particle effects
	var trail_left = GPUParticles3D.new()
	trail_left.name = "TrailLeft"
	trail_left.position = Vector3(0.25, 0.05, -0.35)
	container.add_child(trail_left)

	var trail_right = GPUParticles3D.new()
	trail_right.name = "TrailRight"
	trail_right.position = Vector3(-0.25, 0.05, -0.35)
	container.add_child(trail_right)

	# Create sounds
	var screech_sound = AudioStreamPlayer3D.new()
	screech_sound.name = "ScreechSound"
	if ResourceLoader.exists("res://audio/skid.ogg"):
		screech_sound.stream = load("res://audio/skid.ogg")
	container.add_child(screech_sound)

	var engine_sound = AudioStreamPlayer3D.new()
	engine_sound.name = "EngineSound"
	if ResourceLoader.exists("res://audio/engine.ogg"):
		engine_sound.stream = load("res://audio/engine.ogg")
	container.add_child(engine_sound)


func _create_wheel(name: String) -> Node3D:
	var wheel = Node3D.new()
	wheel.name = name
	return wheel


func _get_vehicle_model_path(index: int) -> String:
	var colors = ["yellow", "green", "purple", "red"]
	var color = colors[index % colors.size()]
	return "res://models/vehicle-truck-%s.glb" % color


func get_spawned_vehicles() -> Array[Node3D]:
	return spawned_vehicles


func reset_all_vehicles() -> void:
	for vehicle in spawned_vehicles:
		if vehicle and vehicle.has_method("stop_racing"):
			vehicle.stop_racing()
