class_name TestMapDisplayManager
extends GdUnitTestSuite

const TrackLayoutScript = preload("res://scripts/reading/track_generator/TrackLayout.gd")
const MapDisplayManagerScript = preload("res://scripts/reading/systems/MapDisplayManager.gd")

var _owned_nodes: Array[Node] = []


func _own_node(node: Node) -> Node:
	_owned_nodes.append(node)
	return node


func after_each() -> void:
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.free()
	_owned_nodes.clear()
	collect_orphan_node_details()


func test_map_display_manager_populates_cell_entries() -> void:
	var layout = TrackLayoutScript.new()
	layout.initialize(Vector3i(4, 1, 4))
	layout.set_cell(
		Vector3i(0, 0, 0), {"scene_path": "res://models/track-straight.glb", "rotation_y": 0.0}
	)

	var manager = MapDisplayManagerScript.new()
	manager.set_nodes(_own_node(Node3D.new()) as Node3D, _own_node(Node3D.new()) as Node3D)
	manager.set_layout_data(layout, Vector3.ZERO, 18.0, 18.0)

	assert_that(manager.layout_cell_entries.size()).is_equal(1)


func test_map_display_manager_spawns_visible_cells() -> void:
	var layout = TrackLayoutScript.new()
	layout.initialize(Vector3i(4, 1, 4))
	layout.set_cell(
		Vector3i(0, 0, 0), {"scene_path": "res://models/track-straight.glb", "rotation_y": 0.0}
	)

	var manager = MapDisplayManagerScript.new()
	var road = _own_node(Node3D.new()) as Node3D
	var spawn_root = _own_node(Node3D.new()) as Node3D
	manager.set_nodes(road, spawn_root)
	manager.set_layout_data(layout, Vector3.ZERO, 18.0, 18.0)
	manager.update_visible_cells(Vector3.ZERO, 0.0)

	assert_that(manager.grid_cells.size()).is_greater(0)


func test_map_display_manager_finish_cell_replaces_tile() -> void:
	var layout = TrackLayoutScript.new()
	layout.initialize(Vector3i(4, 1, 4))
	layout.set_cell(
		Vector3i(0, 0, 0), {"scene_path": "res://models/track-straight.glb", "rotation_y": 0.0}
	)

	var manager = MapDisplayManagerScript.new()
	var road = _own_node(Node3D.new()) as Node3D
	var spawn_root = _own_node(Node3D.new()) as Node3D
	manager.set_nodes(road, spawn_root)
	manager.set_layout_data(layout, Vector3.ZERO, 18.0, 18.0)
	manager.update_visible_cells(Vector3.ZERO, 0.0)
	manager.set_finish_cell(Vector3i(0, 0, 0))

	assert_that(manager.grid_cells.size()).is_equal(1)
	var tile = manager.grid_cells.get("0,0,0")
	assert_that(tile).is_not_null()

	var finish_entry_found = false
	for entry in manager.layout_cell_entries:
		if entry.get("cell") == Vector3i(0, 0, 0):
			finish_entry_found = true
			var scene_path := str((entry.get("data", {}) as Dictionary).get("scene_path", ""))
			assert_that(scene_path).is_equal("res://models/track-finish.glb")
			break
	assert_that(finish_entry_found).is_true()
