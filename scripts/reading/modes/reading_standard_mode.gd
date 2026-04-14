extends "res://scripts/reading/modes/reading_gameplay_mode.gd"


func spawn_course_for_entry(
	owner,
	_entry: Dictionary,
	_entry_index: int,
	_clear_existing: bool = true,
	_word_anchor: Dictionary = {},
) -> Dictionary:
	if owner == null or owner.gameplay_controller == null:
		return {}

	if not _clear_existing:
		return {}

	var get_path_frame_callable = Callable(owner, "_get_path_frame")
	var path_wrap_callable = Callable(owner, "_wrap_path_index")
	var active_holiday = owner.settings_store.resolve_effective_holiday(owner.settings)
	var course_plan_summary = (
		owner
		. gameplay_controller
		. spawn_loop_course_pickups_and_obstacles(
			owner.current_entries,
			owner.shared_track_layout.word_anchors,
			get_path_frame_callable,
			path_wrap_callable,
			_entry_index,
			owner.requested_group,
			active_holiday,
			true,
		)
	)
	var finish_cells: Array[Vector3i] = []
	for finish_index in owner.gameplay_controller.get_all_finish_indices():
		if finish_index >= 0:
			finish_cells.append(owner._get_path_cell(finish_index))

	return {
		"course_plan_summary": course_plan_summary,
		"finish_cells": finish_cells,
	}
