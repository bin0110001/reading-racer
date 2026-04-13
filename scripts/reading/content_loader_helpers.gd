class_name ReadingContentLoaderHelpers extends RefCounted


static func list_word_reading_lists(
	loader: ReadingContentLoader,
	group_name: String,
) -> Array[String]:
	var reading_lists: Array[String] = []
	var seen_lists: Dictionary = {}
	var csv_path: String = loader._find_group_csv_path(group_name)
	if csv_path.is_empty():
		return reading_lists

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		return reading_lists

	var raw_text := file.get_as_text()
	file.close()
	var lines := raw_text.split("\n")
	var header_map: Dictionary = {}
	var data_start_index := 0

	if lines.size() > 0:
		var header_columns: Array[String] = loader._parse_csv_line(str(lines[0]).strip_edges())
		if header_columns.size() > 0 and str(header_columns[0]).strip_edges().to_lower() == "word":
			header_map = loader._build_csv_header_map(header_columns)
			data_start_index = 1

	for i in range(data_start_index, lines.size()):
		var line := str(lines[i]).strip_edges()
		if line.is_empty():
			continue

		var columns: Array[String] = loader._parse_csv_line(line)
		if columns.size() < 1:
			continue

		var reading_lists_text := loader._get_csv_value(
			columns, header_map, ["reading lists", "reading_lists", "lists"], -1
		)
		for entry_list in loader._split_multi_value_field(reading_lists_text):
			var list_name := str(entry_list).strip_edges()
			if list_name.is_empty():
				continue
			var normalized_list := list_name.to_lower()
			if seen_lists.has(normalized_list):
				continue
			seen_lists[normalized_list] = true
			reading_lists.append(list_name)

	return reading_lists


static func load_sentence_entries_for_text(
	loader: ReadingContentLoader, group_name: String, sentence_text: String
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = loader.load_sentence_entries(group_name)
	var trimmed_sentence := sentence_text.strip_edges().to_lower()
	if trimmed_sentence.is_empty():
		return entries

	var filtered: Array[Dictionary] = []
	for entry in entries:
		if str(entry.get("text", "")).strip_edges().to_lower() == trimmed_sentence:
			filtered.append(entry)

	return filtered


static func load_word_entries_for_reading_list(
	loader: ReadingContentLoader,
	group_name: String,
	reading_list_name: String = "",
	limit: int = 20
) -> Array[Dictionary]:
	var csv_path: String = loader._find_group_csv_path(group_name)
	if csv_path.is_empty():
		return []

	var available_lists := list_word_reading_lists(loader, group_name)
	var target_list := reading_list_name.strip_edges().to_lower()
	if target_list.is_empty() and not available_lists.is_empty():
		target_list = available_lists[0].strip_edges().to_lower()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		return []

	var raw_text := file.get_as_text()
	file.close()
	var lines := raw_text.split("\n")
	var header_map: Dictionary = {}
	var data_start_index := 0

	if lines.size() > 0:
		var header_columns: Array[String] = loader._parse_csv_line(str(lines[0]).strip_edges())
		if header_columns.size() > 0 and str(header_columns[0]).strip_edges().to_lower() == "word":
			header_map = loader._build_csv_header_map(header_columns)
			data_start_index = 1

	var selected_rows: Array[Dictionary] = []
	for i in range(data_start_index, lines.size()):
		var line := str(lines[i]).strip_edges()
		if line.is_empty():
			continue

		var columns: Array[String] = loader._parse_csv_line(line)
		if columns.size() < 1:
			continue

		var word_text := loader._get_csv_value(columns, header_map, ["word"], 0).to_lower()
		if word_text.is_empty():
			continue

		var reading_lists_text := loader._get_csv_value(
			columns, header_map, ["reading lists", "reading_lists", "lists"], -1
		)
		var row_reading_lists: Array[String] = []
		var matches_target_list := target_list.is_empty()
		for entry_list in loader._split_multi_value_field(reading_lists_text):
			var list_name := str(entry_list).strip_edges()
			if list_name.is_empty():
				continue
			row_reading_lists.append(list_name)
			if not matches_target_list and list_name.to_lower() == target_list:
				matches_target_list = true

		if not matches_target_list:
			continue

		var row := {
			"text": word_text,
			"letters": [],
			"reading_lists": row_reading_lists,
			"phonics_stage":
			loader._get_csv_value(
				columns, header_map, ["phonics stage", "phonics_stage", "stage"], -1
			),
			"simple_pronunciation":
			loader._get_csv_value(
				columns, header_map, ["simple pronunciation", "simple_pronunciation"], -1
			),
			"strict_pronunciation":
			loader._get_csv_value(
				columns, header_map, ["strict pronunciation", "strict_pronunciation"], -1
			),
			"audio_hint_text":
			(
				loader
				. _get_csv_value(
					columns,
					header_map,
					["audio hint", "audio_hint", "pronunciation hint", "pronunciation_hint"],
					-1,
				)
			),
			"explicit_audio_path":
			(
				loader
				. _get_csv_value(
					columns,
					header_map,
					["word audio path", "word_audio_path", "audio path", "audio_path"],
					-1,
				)
			),
			"breakdown":
			loader._get_csv_value(
				columns, header_map, ["grapheme to phoneme breakdown", "breakdown"], 2
			),
			"ipa": loader._get_csv_value(columns, header_map, ["ipa"], 1),
		}

		if limit > 0:
			_insert_word_row_sorted(selected_rows, row, limit)
		else:
			selected_rows.append(row)

	var entries: Array[Dictionary] = []
	for row in selected_rows:
		var entry := _build_word_entry_from_row(loader, group_name, row)
		if not entry.is_empty():
			entries.append(entry)

	entries.sort_custom(loader._sort_entries)
	return entries


static func _insert_word_row_sorted(rows: Array[Dictionary], row: Dictionary, limit: int) -> void:
	var row_text := str(row.get("text", "")).strip_edges().to_lower()
	if row_text.is_empty():
		return

	var insert_index := rows.size()
	for index in range(rows.size()):
		var existing_text := str(rows[index].get("text", "")).strip_edges().to_lower()
		if row_text < existing_text:
			insert_index = index
			break

	rows.insert(insert_index, row)
	if rows.size() > limit:
		rows.remove_at(rows.size() - 1)


static func _build_word_entry_from_row(
	loader: ReadingContentLoader, group_name: String, row: Dictionary
) -> Dictionary:
	var word_text := str(row.get("text", "")).strip_edges().to_lower()
	if word_text.is_empty():
		return {}

	var reading_lists: Array[String] = []
	for reading_list in row.get("reading_lists", []) as Array:
		reading_lists.append(str(reading_list))

	var phonics_stage := str(row.get("phonics_stage", ""))
	var simple_pronunciation := str(row.get("simple_pronunciation", ""))
	var strict_pronunciation := str(row.get("strict_pronunciation", ""))
	var audio_hint_text := str(row.get("audio_hint_text", ""))
	var explicit_audio_path := str(row.get("explicit_audio_path", ""))
	var breakdown := str(row.get("breakdown", ""))
	var ipa := str(row.get("ipa", ""))

	var simple_phonemes: Array[String] = loader._phonemes_from_pronunciation_field(
		word_text, simple_pronunciation, breakdown
	)
	if simple_phonemes.is_empty():
		simple_phonemes = loader._phonemes_from_breakdown(word_text, breakdown)
	if simple_phonemes.is_empty() and not ipa.is_empty():
		simple_phonemes = loader._phonemes_from_pronunciation_field(word_text, ipa, breakdown)

	var strict_phonemes: Array[String] = loader._phonemes_from_pronunciation_field(
		word_text, strict_pronunciation, breakdown
	)
	if strict_phonemes.is_empty():
		strict_phonemes = simple_phonemes.duplicate()

	var audio_hints: Array[String] = loader._build_audio_hints(
		audio_hint_text, simple_pronunciation, strict_pronunciation
	)
	var phonemes: Array[String] = strict_phonemes
	if phonemes.is_empty():
		phonemes = simple_phonemes.duplicate()

	var letters: Array[String] = []
	for character in word_text:
		letters.append(character)

	if phonemes.is_empty():
		phonemes = loader._phonemes_from_letters(word_text)

	var audio_path := loader._resolve_word_audio_path(
		group_name,
		word_text,
		reading_lists,
		phonics_stage,
		simple_phonemes,
		strict_phonemes,
		audio_hints,
		explicit_audio_path
	)
	if audio_path.is_empty():
		return {}

	return {
		"text": word_text,
		"letters": letters,
		"phonemes": phonemes,
		"simple_phonemes": simple_phonemes,
		"strict_phonemes": strict_phonemes,
		"reading_lists": reading_lists,
		"phonics_stage": phonics_stage,
		"audio_hints": audio_hints,
		"audio_hint": audio_hint_text,
		"simple_pronunciation": simple_pronunciation,
		"strict_pronunciation": strict_pronunciation,
		"word_audio_path": audio_path,
		"group": group_name,
	}


static func find_first_existing_alias(candidates: Array) -> String:
	for candidate in candidates:
		var value := str(candidate).strip_edges().to_lower()
		if value != "":
			return value
	return ""


static func build_word_audio_search_terms(word_text: String) -> Array[String]:
	var terms: Array[String] = []
	var normalized_word := normalize_audio_lookup_text(word_text)
	if normalized_word.is_empty():
		return terms

	terms.append(normalized_word)
	terms.append(word_text.to_lower())
	terms.append_array(tokenize_audio_text(word_text))
	terms.append(normalized_word.replace("'", ""))
	return terms


static func build_word_audio_basename_candidates(
	word_text: String, audio_hints: Array[String]
) -> Array[String]:
	var basenames: Array[String] = []
	var normalized_word := normalize_audio_lookup_text(word_text)
	if normalized_word.is_empty():
		return basenames

	basenames.append(normalized_word)
	for hint in audio_hints:
		var normalized_hint := normalize_audio_filename_component(hint)
		if normalized_hint.is_empty():
			continue
		basenames.append("%s-%s" % [normalized_word, normalized_hint])

	return basenames


static func build_word_audio_search_terms_from_phonemes(phonemes: Array[String]) -> Array[String]:
	var terms: Array[String] = []
	var joined_tokens: Array[String] = []
	for phoneme in phonemes:
		var normalized_phoneme := normalize_audio_lookup_text(phoneme)
		if normalized_phoneme.is_empty():
			continue
		terms.append(normalized_phoneme)
		joined_tokens.append(normalized_phoneme)

	if not joined_tokens.is_empty():
		terms.append("".join(joined_tokens))
		terms.append("-".join(joined_tokens))
		terms.append("_".join(joined_tokens))

	return terms


static func normalize_audio_lookup_text(value: String) -> String:
	var normalized := str(value).strip_edges().to_lower()
	normalized = normalized.replace("’", "'")
	normalized = normalized.replace("`", "'")
	return normalized


static func normalize_audio_filename_component(value: String) -> String:
	var normalized := normalize_audio_lookup_text(value)
	normalized = normalized.replace(" ", "")
	normalized = normalized.replace("/", "")
	normalized = normalized.replace("|", "")
	return normalized


static func tokenize_audio_text(value: String) -> Array[String]:
	var normalized := normalize_audio_lookup_text(value)
	if normalized.is_empty():
		return []

	for separator in [
		"/",
		"\\",
		"-",
		"_",
		".",
		",",
		"(",
		")",
		"[",
		"]",
		"{",
		"}",
	]:
		normalized = normalized.replace(separator, " ")
	var tokens: Array[String] = []
	for token in normalized.split(" ", false):
		var trimmed := str(token).strip_edges()
		if trimmed.is_empty():
			continue
		tokens.append(trimmed)
	return tokens
