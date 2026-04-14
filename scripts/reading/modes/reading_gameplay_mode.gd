extends RefCounted


func get_start_word_label(_owner, entry: Dictionary) -> String:
	return str(entry.get("text", ""))


func get_status_text(owner) -> String:
	if owner == null or owner.current_entry.is_empty() or not owner.gameplay_controller:
		return ""

	var mode_text: String = "Unknown"
	if owner.control_profile:
		mode_text = owner.control_profile.mode_name.capitalize()

	var total_letters: int = owner.gameplay_controller.get_total_letters()
	var target_text := (
		"Complete"
		if owner.gameplay_controller.is_word_complete()
		else "Next: %s" % owner.gameplay_controller.get_next_target_letter()
	)
	var status_format := "%s   %d/%d   %s"
	return (
		status_format
		% [
			target_text,
			owner.gameplay_controller.next_target_index,
			total_letters,
			mode_text,
		]
	)


func spawn_course_for_entry(
	_owner,
	_entry: Dictionary,
	_entry_index: int,
	_clear_existing: bool = true,
	_word_anchor: Dictionary = {},
) -> Dictionary:
	return {}


func handle_word_choice_selected(
	_owner, _choice_text: String, _correct: bool, _word_index: int
) -> bool:
	return false
