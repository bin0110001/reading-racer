class_name MapDisplayManager extends RefCounted

## MapDisplayManager: Solely responsible for rendering track grid and visual updates.
## Separates map display logic from movement, gameplay, and map generation.

## Model paths and constants
const ROAD_MODEL_PATH := "res://models/track-straight.glb"
const FINISH_MODEL_PATH := "res://models/track-finish.glb"
const DECORATION_MODEL_PATH := "res://models/decoration-forest.glb"
const ROAD_SCALE := 2.0

const DECORATION_MODELS := [
	{"path": "res://models/decoration-empty.glb", "weight": 6},
	{"path": "res://models/decoration-forest.glb", "weight": 2},
	{"path": "res://models/decoration-tents.glb", "weight": 2},
]

## References to parent nodes
var road_node: Node3D = null
var spawn_root: Node3D = null

## Track dimensions
var track_tile_length: float = 0.0
var track_tile_width: float = 0.0
var layout_origin: Vector3 = Vector3.ZERO

## Grid management
var grid_cells: Dictionary = {}  # Key: "x,y,z", Value: Node3D reference
var layout_cell_entries: Array = []
var shared_track_layout: Variant = null
var current_finish_cell: Vector3i = Vector3i(-1, -1, -1)
var finish_cell_original_scene_path: String = ""

## Debug visualization
var debug_path_mesh_instance: MeshInstance3D = null
var debug_draw_path: bool = false

## Stream window parameters
var stream_tiles_each_side: int = 5
var stream_tiles_ahead: int = 10
var stream_tiles_behind: int = 3

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


## Initialize with parent nodes
func set_nodes(p_road: Node3D, p_spawn_root: Node3D) -> void:
	road_node = p_road
	spawn_root = p_spawn_root


## Set track layout data
func set_layout_data(
	p_layout: Variant,
	p_layout_origin: Vector3,
	p_track_tile_length: float,
	p_track_tile_width: float
) -> void:
	shared_track_layout = p_layout
	layout_origin = p_layout_origin
	track_tile_length = p_track_tile_length
	track_tile_width = p_track_tile_width

	if shared_track_layout != null:
		var layout_dict: Dictionary = shared_track_layout.to_dictionary()
		layout_cell_entries = layout_dict.get("cells", []) as Array
		# Reset finish token when layout is updated
		current_finish_cell = Vector3i(-1, -1, -1)
		finish_cell_original_scene_path = ""


func _cell_key(cell: Vector3i) -> String:
	return "%d,%d,%d" % [cell.x, cell.y, cell.z]


func _restore_finish_cell() -> void:
	if current_finish_cell.x < 0:
		return
	var cell_key = _cell_key(current_finish_cell)
	# restore original path on the layout entry
	for cell_entry in layout_cell_entries:
		if cell_entry.get("cell", Vector3i.ZERO) == current_finish_cell:
			var data = cell_entry.get("data", {}) as Dictionary
			data["scene_path"] = finish_cell_original_scene_path
			break

	# if the tile is in view, respawn as original
	if grid_cells.has(cell_key):
		if is_instance_valid(grid_cells[cell_key]):
			grid_cells[cell_key].queue_free()
		grid_cells.erase(cell_key)
		for cell_entry in layout_cell_entries:
			if cell_entry.get("cell", Vector3i.ZERO) == current_finish_cell:
				_spawn_grid_cell(
					current_finish_cell, cell_entry.get("data", {}) as Dictionary, cell_key
				)
				break

	current_finish_cell = Vector3i(-1, -1, -1)
	finish_cell_original_scene_path = ""


func set_finish_cell(cell: Vector3i) -> void:
	if shared_track_layout == null:
		return

	if current_finish_cell != cell and current_finish_cell.x >= 0:
		_restore_finish_cell()

	var cell_key = _cell_key(cell)
	var target_entry: Dictionary = {}
	for cell_entry in layout_cell_entries:
		if cell_entry.get("cell", Vector3i.ZERO) == cell:
			target_entry = cell_entry
			break

	if target_entry.size() == 0:
		return

	var data = target_entry.get("data", {}) as Dictionary
	if finish_cell_original_scene_path == "":
		finish_cell_original_scene_path = str(data.get("scene_path", ROAD_MODEL_PATH))

	data["scene_path"] = FINISH_MODEL_PATH
	current_finish_cell = cell

	if grid_cells.has(cell_key):
		if is_instance_valid(grid_cells[cell_key]):
			grid_cells[cell_key].queue_free()
		grid_cells.erase(cell_key)

	_spawn_grid_cell(cell, data, cell_key)


## Initialize measurement of track tile from a sample model
func measure_track_tile(track_sample: Node3D) -> void:
	var mesh_instance := _find_first_mesh_instance(track_sample)
	if mesh_instance != null:
		track_tile_length = mesh_instance.get_aabb().size.x
		track_tile_width = mesh_instance.get_aabb().size.z

	# Apply scale
	track_tile_length *= ROAD_SCALE
	track_tile_width *= ROAD_SCALE


## Update visible grid cells based on player position
func update_visible_cells(player_position: Vector3, player_heading: float) -> void:
	if shared_track_layout == null:
		return

	var desired_tiles: Dictionary = {}
	for cell_entry in layout_cell_entries:
		var cell: Vector3i = cell_entry.get("cell", Vector3i.ZERO) as Vector3i
		var cell_data: Dictionary = cell_entry.get("data", {}) as Dictionary
		var world_pos := _cell_to_world_center(cell)
		if not _is_point_in_stream_window(world_pos, player_position, player_heading):
			continue
		var key := "%d,%d,%d" % [cell.x, cell.y, cell.z]
		desired_tiles[key] = {"cell": cell, "data": cell_data}

	# Remove tiles that are no longer visible
	var tiles_to_remove: Array = []
	for key in grid_cells.keys():
		if not desired_tiles.has(key):
			tiles_to_remove.append(key)

	for key in tiles_to_remove:
		if is_instance_valid(grid_cells[key]):
			grid_cells[key].queue_free()
		grid_cells.erase(key)

	# Spawn new visible tiles
	for key in desired_tiles.keys():
		if grid_cells.has(key):
			continue
		var tile_request: Dictionary = desired_tiles[key] as Dictionary
		_spawn_grid_cell(
			tile_request.get("cell", Vector3i.ZERO) as Vector3i,
			tile_request.get("data", {}) as Dictionary,
			str(key)
		)


## Update debug path visualization
func update_debug_visualization(
	p_debug_draw: bool, p_get_pose_func: Callable, track_tile_length_val: float
) -> void:
	debug_draw_path = p_debug_draw

	if not debug_draw_path or shared_track_layout == null:
		if debug_path_mesh_instance and is_instance_valid(debug_path_mesh_instance):
			debug_path_mesh_instance.queue_free()
			debug_path_mesh_instance = null
		return

	var curve_points: Array[Vector3] = []
	var path_count: int = shared_track_layout.path_cells.size()
	if path_count <= 0 or track_tile_length_val <= 0.0:
		return

	var total_length: float = float(path_count) * track_tile_length_val
	var sample_count: int = max(64, min(512, int(total_length / 1.0)))
	for sample_i in range(sample_count):
		var t := float(sample_i) / float(sample_count - 1)
		var distance := t * total_length
		var pose = p_get_pose_func.call(distance, 0.0)
		if not pose.is_empty():
			curve_points.append(pose.position)

	if curve_points.size() < 2:
		return

	var line_mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 1.0, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for point in curve_points:
		line_mesh.surface_add_vertex(point)
	line_mesh.surface_end()

	if debug_path_mesh_instance == null or not is_instance_valid(debug_path_mesh_instance):
		debug_path_mesh_instance = MeshInstance3D.new()
		debug_path_mesh_instance.name = "DebugPath"
		spawn_root.add_child(debug_path_mesh_instance)

	debug_path_mesh_instance.mesh = line_mesh


## Clear all grid cells (for new word)
func clear_all_cells() -> void:
	for child in road_node.get_children():
		child.queue_free()
	grid_cells.clear()


# ============ Private Methods ============


func _cell_to_world_center(cell: Vector3i) -> Vector3:
	return (
		layout_origin
		+ Vector3(
			(float(cell.x) + 0.5) * track_tile_length, 0.0, (float(cell.z) + 0.5) * track_tile_width
		)
	)


func _is_point_in_stream_window(
	world_pos: Vector3, player_pos: Vector3, player_heading: float
) -> bool:
	var forward := Vector3(cos(player_heading), 0.0, sin(player_heading))
	if forward.length_squared() == 0.0:
		forward = Vector3.RIGHT
	var right := Vector3(-forward.z, 0.0, forward.x)
	var flat_offset := world_pos - player_pos
	flat_offset.y = 0.0
	var forward_distance := flat_offset.dot(forward)
	var side_distance := absf(flat_offset.dot(right))
	var ahead_limit := (float(stream_tiles_ahead) + 0.75) * track_tile_length
	var behind_limit := (float(stream_tiles_behind) + 0.75) * track_tile_length
	var side_limit := (float(stream_tiles_each_side) + 0.75) * track_tile_width
	return (
		forward_distance <= ahead_limit
		and forward_distance >= -behind_limit
		and side_distance <= side_limit
	)


func _spawn_grid_cell(cell: Vector3i, cell_data: Dictionary, key: String) -> void:
	var cell_node: Node3D = null
	var scene_path := str(cell_data.get("scene_path", ""))
	if scene_path.is_empty():
		return
	cell_node = _instantiate_scene(scene_path)
	if cell_node != null:
		cell_node.scale = Vector3.ONE * ROAD_SCALE
		cell_node.rotation_degrees = Vector3(0.0, float(cell_data.get("rotation_y", 0.0)), 0.0)
		cell_node.position = _cell_to_world_center(cell)
		road_node.add_child(cell_node)

	if cell_node != null:
		grid_cells[key] = cell_node


func _instantiate_scene(resource_path: String) -> Node3D:
	if not ResourceLoader.exists(resource_path):
		return null
	var packed_scene := load(resource_path) as PackedScene
	if packed_scene == null:
		return null
	return packed_scene.instantiate() as Node3D


func _pick_decoration_path() -> String:
	var total_weight := 0
	for deco in DECORATION_MODELS:
		total_weight += int(deco.weight)

	var roll := rng.randi_range(1, total_weight)
	for deco in DECORATION_MODELS:
		roll -= int(deco.weight)
		if roll <= 0:
			return str(deco.path)

	return DECORATION_MODEL_PATH


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found
	return null
