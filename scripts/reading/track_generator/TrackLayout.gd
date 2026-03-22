class_name TrackLayout
extends RefCounted

var size: Vector3i = Vector3i.ZERO
var cells: Array = []
var path_cells: Array = []
var word_anchors: Array = []
var checkpoints: Array = []
var start_positions: Array = []
var metadata: Dictionary = {}


func initialize(grid_size: Vector3i) -> void:
	size = grid_size
	cells.clear()
	cells.resize(size.x)
	for x in range(size.x):
		var columns: Array = []
		columns.resize(size.y)
		for y in range(size.y):
			var depth: Array = []
			depth.resize(size.z)
			columns[y] = depth
		cells[x] = columns


func is_in_bounds(cell: Vector3i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.z >= 0
		and cell.x < size.x
		and cell.y < size.y
		and cell.z < size.z
	)


func set_cell(cell: Vector3i, cell_data: Dictionary) -> void:
	if not is_in_bounds(cell):
		return
	cells[cell.x][cell.y][cell.z] = cell_data.duplicate(true)


func has_cell(cell: Vector3i) -> bool:
	if not is_in_bounds(cell):
		return false
	return cells[cell.x][cell.y][cell.z] is Dictionary


func get_cell(cell: Vector3i) -> Dictionary:
	if not is_in_bounds(cell):
		return {}
	var cell_data = cells[cell.x][cell.y][cell.z]
	if cell_data is Dictionary:
		return (cell_data as Dictionary).duplicate(true)
	return {}


func count_cells_by_kind(kind: String) -> int:
	var count := 0
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				var cell_data = cells[x][y][z]
				if (
					cell_data is Dictionary
					and str((cell_data as Dictionary).get("kind", "")) == kind
				):
					count += 1
	return count


func to_dictionary() -> Dictionary:
	var populated_cells: Array[Dictionary] = []
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				var cell_data = cells[x][y][z]
				if cell_data is Dictionary:
					(
						populated_cells
						. append(
							{
								"cell": Vector3i(x, y, z),
								"data": (cell_data as Dictionary).duplicate(true),
							}
						)
					)

	return {
		"size": size,
		"cells": populated_cells,
		"path_cells": path_cells.duplicate(),
		"word_anchors": word_anchors.duplicate(true),
		"checkpoints": checkpoints.duplicate(true),
		"start_positions": start_positions.duplicate(true),
		"metadata": metadata.duplicate(true),
	}
