class_name View extends Node3D

@export var target: Node3D

var camera: Camera3D


func _ready() -> void:
	camera = get_node("Camera3D")


func _physics_process(delta: float) -> void:
	if not target:
		return

	global_position = global_position.lerp(target.global_position, delta * 4.0)
