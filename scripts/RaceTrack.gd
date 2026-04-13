class_name RaceTrack extends Node3D

const ContentLoaderScript = preload("res://scripts/reading/content_loader.gd")
const TrackGeneratorScript = preload("res://scripts/reading/track_generator/TrackGenerator.gd")

@export var word_group: String = ""
@export var max_word_entries: int = 8
@export var checkpoint_count: int = 4
@export var start_slot_count: int = 8
@export var cell_world_length: float = 8.0
@export var starting_height: float = 0.0
@export var checkpoint_height: float = 1.0
@export var starting_lane_spacing: float = 2.2
@export var starting_row_spacing: float = 4.5

var starting_positions: Array[Transform3D] = []
var checkpoints: Array[Node3D] = []

var game_manager: GameManager
var generated_layout: Dictionary = {}


func _ready() -> void:
	game_manager = get_node_or_null("../GameManager")
	_build_generated_track_data()
	if starting_positions.is_empty():
		starting_positions = _create_default_starting_positions()
	if checkpoints.is_empty():
		_create_default_checkpoints()


func _build_generated_track_data() -> void:
	generated_layout = _generate_loop_layout()
	if generated_layout.is_empty():
		return

	starting_positions = _build_starting_positions(generated_layout)
	_rebuild_checkpoints(generated_layout)


func _generate_loop_layout() -> Dictionary:
	var loader = ContentLoaderScript.new()
	var generator = TrackGeneratorScript.new()

	var selected_group = _resolve_word_group(loader)
	if selected_group.is_empty():
		return {}

	var entries = loader.load_word_entries(selected_group)
	if entries.is_empty():
		return {}

	var limited_entries: Array[Dictionary] = []
	var entry_limit = mini(entries.size(), maxi(1, max_word_entries))
	for i in range(entry_limit):
		limited_entries.append(entries[i])

	var config = {
		"checkpoint_count": maxi(1, checkpoint_count),
		"start_slots": maxi(1, start_slot_count),
		"cell_world_length": cell_world_length
	}

	var layout = generator.generate_loop_layout(limited_entries, config)
	if layout is TrackLayout:
		return layout.to_dictionary()
	if layout is Dictionary:
		return layout
	return {}


func _resolve_word_group(loader: Object) -> String:
	if not word_group.is_empty():
		return word_group

	var groups = loader.list_word_groups()
	if groups.is_empty():
		return ""

	return groups[0]


func _build_starting_positions(layout: Dictionary) -> Array[Transform3D]:
	var start_positions: Array[Transform3D] = []
	var start_positions_data: Array = layout.get("start_positions", [])

	for pos_data in start_positions_data:
		var cell = pos_data.get("cell", Vector3i.ZERO)
		var rotation_y = pos_data.get("rotation_y", 0.0)

		var world_pos = _cell_to_world_position(cell, layout)
		var start_transform = Transform3D()
		start_transform.origin = world_pos + Vector3(0, starting_height, 0)
		start_transform.basis = Basis.from_euler(Vector3(0, rotation_y, 0))
		start_positions.append(start_transform)

	return start_positions


func _rebuild_checkpoints(layout: Dictionary) -> void:
	var checkpoint_data_list: Array = layout.get("checkpoints", [])

	for cp_data in checkpoint_data_list:
		var cell = cp_data.get("cell", Vector3i.ZERO)
		var world_pos = _cell_to_world_position(cell, layout)
		var checkpoint_node = Node3D.new()
		checkpoint_node.global_position = world_pos + Vector3(0, checkpoint_height, 0)
		checkpoints.append(checkpoint_node)


func _cell_to_world_position(cell: Vector3i, layout: Dictionary) -> Vector3:
	var grid_size = layout.get("grid_size", Vector3i(10, 1, 10))
	var cell_length = cell_world_length

	var world_x = (cell.x - grid_size.x / 2.0) * cell_length
	var world_z = (cell.z - grid_size.z / 2.0) * cell_length

	return Vector3(world_x, 0, world_z)


func _create_default_starting_positions() -> Array[Transform3D]:
	var positions: Array[Transform3D] = []
	for i in range(8):
		var start_transform = Transform3D()
		start_transform.origin = Vector3(0, starting_height, i * starting_row_spacing)
		positions.append(start_transform)
	return positions


func _create_default_checkpoints() -> void:
	var positions = [
		Vector3(0, checkpoint_height, 10),
		Vector3(0, checkpoint_height, 20),
		Vector3(0, checkpoint_height, 30),
		Vector3(0, checkpoint_height, 40),
	]
	for pos in positions:
		var checkpoint = Node3D.new()
		checkpoint.global_position = pos
		checkpoints.append(checkpoint)


func get_starting_position(vehicle_index: int) -> Transform3D:
	if vehicle_index >= 0 and vehicle_index < starting_positions.size():
		return starting_positions[vehicle_index]
	return Transform3D.IDENTITY
