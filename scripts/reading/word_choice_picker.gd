class_name ReadingWordChoicePicker
extends RefCounted


static func build_similar_choice_entries(
	entries: Array,
	current_index: int,
	choice_count: int = 3,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if current_index < 0 or current_index >= entries.size() or choice_count <= 0:
		return result

	var current_text: String = str(entries[current_index].get("text", "")).strip_edges()
	var candidates: Array[Dictionary] = []
	for idx in range(entries.size()):
		if idx == current_index:
			continue
		var entry: Dictionary = entries[idx] as Dictionary
		var text: String = str(entry.get("text", "")).strip_edges()
		candidates.append({"index": idx, "score": score_text_similarity(current_text, text)})

	candidates.sort_custom(func(a, b): return int(b.get("score", 0) - a.get("score", 0)))
	result.append({"text": current_text, "is_correct": true})
	for candidate in candidates:
		if result.size() >= choice_count:
			break
		var candidate_index: int = int(candidate.get("index", 0))
		result.append({"text": str(entries[candidate_index].get("text", "")), "is_correct": false})

	if result.size() < choice_count:
		for idx in range(entries.size()):
			if result.size() >= choice_count:
				break
			if idx == current_index:
				continue
			var text: String = str(entries[idx].get("text", ""))
			if not _result_contains_text(result, text):
				result.append({"text": text, "is_correct": false})

	while result.size() < choice_count:
		result.append({"text": current_text, "is_correct": false})

	result.shuffle()
	return result


static func score_text_similarity(a: String, b: String) -> int:
	var score := 0
	var lower_a := a.to_lower()
	var lower_b := b.to_lower()
	if lower_a.length() > 0 and lower_b.length() > 0:
		if lower_a[0] == lower_b[0]:
			score += 10
		if lower_a.begins_with(lower_b.substr(0, 1)) or lower_b.begins_with(lower_a.substr(0, 1)):
			score += 5
	var length_diff: int = abs(lower_a.length() - lower_b.length())
	score += max(0, 6 - length_diff)
	score += _common_prefix_length(lower_a, lower_b) * 2
	return score


static func _common_prefix_length(a: String, b: String) -> int:
	var max_len: int = min(a.length(), b.length())
	for index in range(max_len):
		if a[index] != b[index]:
			return index
	return max_len


static func _result_contains_text(result: Array[Dictionary], text: String) -> bool:
	for entry in result:
		if str(entry.get("text", "")).to_lower() == text.to_lower():
			return true
	return false
