extends "res://scripts/reading/modes/reading_gameplay_mode.gd"

const WordChoicePicker = preload("res://scripts/reading/word_choice_picker.gd")


func get_start_word_label(_owner, _entry: Dictionary) -> String:
	return "LISTEN"


func get_status_text(owner) -> String:
	if owner == null:
		return ""

	var mode_text: String = "Unknown"
	if owner.control_profile:
		mode_text = owner.control_profile.mode_name.capitalize()
	return "Choose the spoken word   %s" % mode_text


func spawn_course_for_entry(
	owner,
	_entry: Dictionary,
	_entry_index: int,
	_clear_existing: bool = true,
	_word_anchor: Dictionary = {},
) -> Dictionary:
	if owner == null or owner.gameplay_controller == null or _word_anchor.is_empty():
		return {}

	var choice_index := int(_word_anchor.get("end_index", int(_word_anchor.get("start_index", 0))))
	choice_index = owner._wrap_path_index(choice_index + 1)
	var choice_entries := WordChoicePicker.build_similar_choice_entries(
		owner.current_entries, _entry_index
	)
	var course_plan_summary = (
		owner
		. gameplay_controller
		. spawn_loop_course_word_choices(
			choice_entries,
			choice_index,
			_entry_index,
			Callable(owner, "_get_path_frame"),
			true,
		)
	)
	return {
		"course_plan_summary": course_plan_summary,
		"finish_cells": [],
	}


func handle_word_choice_selected(
	owner, choice_text: String, correct: bool, word_index: int
) -> bool:
	if owner == null or word_index != owner.current_entry_index:
		return false

	if correct:
		owner.gameplay_controller.reset()
		owner.phoneme_player.play_word(owner.content_loader.get_word_stream(owner.current_entry))
		owner.hud.flash_feedback("Correct!", Color(0.45, 1.0, 0.55))
		owner._complete_word()
		return true

	owner.movement_system.apply_slowdown(1.2)
	owner.hud.flash_feedback("Wrong: %s" % choice_text, Color(1.0, 0.42, 0.32))
	var wrong_entry: Dictionary = owner._find_entry_by_text(choice_text)
	if not wrong_entry.is_empty():
		owner.phoneme_player.play_word(owner.content_loader.get_word_stream(wrong_entry))
	return true
