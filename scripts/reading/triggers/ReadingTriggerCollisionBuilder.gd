class_name ReadingTriggerCollisionBuilder
extends RefCounted


static func add_box_collision(
	owner: Node,
	width: float,
	height: float,
	depth: float,
	position: Vector3 = Vector3.ZERO,
) -> CollisionShape3D:
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(width, height, depth)
	collision_shape.shape = box_shape
	collision_shape.position = position
	owner.add_child(collision_shape)
	return collision_shape
