class_name Vehicle extends Node3D

@export var player_id: int = 0

var game_manager: GameManager
var race_track: RaceTrack

# Nodes
var sphere: RigidBody3D
var raycast: RayCast3D

# Vehicle elements
var vehicle_model: Node3D
var vehicle_body: Node3D

var wheel_fl: Node3D
var wheel_fr: Node3D
var wheel_bl: Node3D
var wheel_br: Node3D

# Effects
var trail_left: GPUParticles3D
var trail_right: GPUParticles3D

# Sounds
var screech_sound: AudioStreamPlayer3D
var engine_sound: AudioStreamPlayer3D

var input: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.UP

var acceleration: float = 0.0
var angular_speed: float = 0.0
var linear_speed: float = 0.0

var colliding: bool = false


func _ready() -> void:
	game_manager = get_node_or_null("/root/Main/GameManager")
	race_track = get_node_or_null("/root/Main/RaceTrack")
	set_meta("player_id", player_id)
	if game_manager:
		game_manager.register_player(player_id, self)
	set_physics_process(false)

	sphere = get_node("Sphere")
	raycast = get_node("Ground")

	vehicle_model = get_node("Container")
	vehicle_body = get_node("Container/Model/body")

	wheel_fl = get_node("Container/Model/wheel-front-left")
	wheel_fr = get_node("Container/Model/wheel-front-right")
	wheel_bl = get_node("Container/Model/wheel-back-left")
	wheel_br = get_node("Container/Model/wheel-back-right")

	trail_left = get_node("Container/TrailLeft")
	trail_right = get_node("Container/TrailRight")

	screech_sound = get_node("Container/ScreechSound")
	engine_sound = get_node("Container/EngineSound")

	# Freeze physics until race starts
	sphere.physics_material_override = PhysicsMaterial.new()
	sphere.physics_material_override.friction = 5.0
	sphere.set_collision_layer_value(4, true)
	sphere.mass = 1000.0
	sphere.gravity_scale = 0.0
	sphere.linear_velocity = Vector3.ZERO
	sphere.angular_velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	_handle_input(delta)

	var direction = sign(linear_speed)
	if direction == 0:
		direction = sign(input.z)
		if abs(input.z) <= 0.1:
			direction = 1

	var steering_grip = clamp(abs(linear_speed), 0.2, 1.0)

	var target_angular = -input.x * steering_grip * 4.0 * direction
	angular_speed = lerp(angular_speed, target_angular, delta * 4.0)

	vehicle_model.rotate_y(angular_speed * delta)

	# Ground alignment
	if raycast.is_colliding():
		if not colliding:
			vehicle_body.position = Vector3(0, 0.1, 0)  # Bounce
			input.z = 0

		var col_point = raycast.get_collision_point()
		var col_normal = raycast.get_collision_normal()
		normal = normal.lerp(col_normal, delta * 4.0)

		# Align rotation to ground
		var forward = -vehicle_model.global_transform.basis.z
		var right = forward.cross(normal).normalized()
		var up = right.cross(forward).normalized()
		vehicle_model.global_transform.basis = Basis(right, up, -forward)

		# Height offset
		var height_offset = col_point - global_position
		global_position += height_offset * delta * 4.0

		colliding = true
		sphere.gravity_scale = 0.0
	else:
		colliding = false
		sphere.gravity_scale = 1.0

	# Apply forces
	var target_velocity = input.z * 20.0
	linear_speed = lerp(linear_speed, target_velocity, delta * 0.2)

	var forward = -vehicle_model.global_transform.basis.z
	sphere.linear_velocity = forward * linear_speed + Vector3(0, sphere.linear_velocity.y, 0)

	# Wheel rotation
	var wheel_rotation = linear_speed * delta / 0.5
	wheel_fl.rotate_z(-wheel_rotation)
	wheel_fr.rotate_z(-wheel_rotation)
	wheel_bl.rotate_z(-wheel_rotation)
	wheel_br.rotate_z(-wheel_rotation)


func _handle_input(_delta: float) -> void:
	input.x = 0
	input.z = 0

	if Input.is_action_pressed("ui_right"):
		input.x = 1
	if Input.is_action_pressed("ui_left"):
		input.x = -1
	if Input.is_action_pressed("ui_up"):
		input.z = 1
	if Input.is_action_pressed("ui_down"):
		input.z = -1


func start_racing() -> void:
	set_physics_process(true)
	sphere.gravity_scale = 1.0
	sphere.set_collision_layer_value(4, true)


func stop_racing() -> void:
	set_physics_process(false)
	linear_speed = 0.0
	sphere.gravity_scale = 0.0
	sphere.linear_velocity = Vector3.ZERO
	sphere.angular_velocity = Vector3.ZERO
