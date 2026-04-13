# This is a class
class_name ReadingContentLoader extends Object

const PHONEME_ROOT := "res://audio/phenomes"
const WORD_ROOT := "res://audio/words"
const WORD_CSV_FILE_NAMES := ["Words.csv", "words.csv"]
const SENTENCE_CSV_FILE_NAMES := ["Sentences.csv", "sentences.csv"]
const CONTENT_TEXT_CACHE_PATH := "user://reading_content_text_cache.json"
const CONTENT_TEXT_CACHE_VERSION := 1

const LETTER_TO_PHONEME := {}

static var _shared_word_groups: Array[String] = []
static var _shared_sentence_groups: Array[String] = []
static var _shared_word_entries_by_group: Dictionary = {}
static var _shared_sentence_entries_by_group: Dictionary = {}
static var _shared_phoneme_paths: Dictionary = {}
static var _shared_word_audio_candidates: Dictionary = {}

var _phoneme_paths: Dictionary = {}
var _word_audio_candidates: Dictionary = {}
var _cached_word_texts: Array[String] = []
var _cached_sentence_texts: Array[String] = []


func _init() -> void:
	_refresh_phoneme_paths()
	_refresh_word_audio_paths()
	_load_text_cache_from_disk()


func list_word_groups() -> Array[String]:
	if not _shared_word_groups.is_empty():
		return _shared_word_groups.duplicate()

	var groups: Array[String] = []
	for directory_name in DirAccess.get_directories_at(WORD_ROOT):
		if _group_has_word_csv(directory_name):
			groups.append(directory_name)
	groups.sort()
	_shared_word_groups = groups.duplicate()
	return groups


func list_sentence_groups() -> Array[String]:
	if not _shared_sentence_groups.is_empty():
		return _shared_sentence_groups.duplicate()

	var groups: Array[String] = []
	for directory_name in DirAccess.get_directories_at(WORD_ROOT):
		if _group_has_sentence_csv(directory_name):
			groups.append(directory_name)
	groups.sort()
	_shared_sentence_groups = groups.duplicate()
	return groups


func list_word_reading_lists(group_name: String) -> Array[String]:
	return ReadingContentLoaderHelpers.list_word_reading_lists(self, group_name)


func list_word_texts() -> Array[String]:
	if _cached_word_texts.size() > 0:
		return _cached_word_texts.duplicate()

	_cached_word_texts = _collect_word_texts()
	_save_text_cache_to_disk()
	return _cached_word_texts.duplicate()


func list_sentence_texts() -> Array[String]:
	if _cached_sentence_texts.size() > 0:
		return _cached_sentence_texts.duplicate()

	_cached_sentence_texts = _collect_sentence_texts()
	_save_text_cache_to_disk()
	return _cached_sentence_texts.duplicate()


func _prebuild_text_caches() -> void:
	if _cached_word_texts.is_empty():
		_cached_word_texts = _collect_word_texts()
	if _cached_sentence_texts.is_empty():
		_cached_sentence_texts = _collect_sentence_texts()


func _load_text_cache_from_disk() -> void:
	var file := FileAccess.open(CONTENT_TEXT_CACHE_PATH, FileAccess.READ)
	if file == null:
		return
	var raw_text := file.get_as_text()
	file.close()
	var json_parser := JSON.new()
	var error := json_parser.parse(raw_text)
	if error != OK:
		return
	var data: Dictionary = json_parser.data
	if typeof(data) != TYPE_DICTIONARY:
		return
	if int(data.get("version", -1)) != CONTENT_TEXT_CACHE_VERSION:
		return
	var words: Array[String] = []
	var sentences: Array[String] = []
	var raw_words: Array = data.get("words", []) as Array
	var raw_sentences: Array = data.get("sentences", []) as Array
	if raw_words is Array:
		for raw_word in raw_words:
			if typeof(raw_word) == TYPE_STRING:
				words.append(str(raw_word))
	if raw_sentences is Array:
		for raw_sentence in raw_sentences:
			if typeof(raw_sentence) == TYPE_STRING:
				sentences.append(str(raw_sentence))
	if words is Array and sentences is Array:
		_cached_word_texts = words.duplicate()
		_cached_sentence_texts = sentences.duplicate()


func _save_text_cache_to_disk() -> void:
	var cache_data := {
		"version": CONTENT_TEXT_CACHE_VERSION,
		"words": _cached_word_texts,
		"sentences": _cached_sentence_texts,
	}
	var json_text := JSON.stringify(cache_data)
	var file := FileAccess.open(CONTENT_TEXT_CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(json_text)
	file.close()


func _collect_word_texts() -> Array[String]:
	var texts: Array[String] = []
	for group_name in list_word_groups():
		var csv_path := _find_group_csv_path(group_name)
		if csv_path.is_empty():
			continue
		var file := FileAccess.open(csv_path, FileAccess.READ)
		if not file:
			continue
		var raw_text := file.get_as_text()
		file.close()
		var lines := raw_text.split("\n")
		var header_map: Dictionary = {}
		if lines.size() > 0:
			var header_columns: Array[String] = _parse_csv_line(str(lines[0]).strip_edges())
			if (
				header_columns.size() > 0
				and str(header_columns[0]).strip_edges().to_lower() == "word"
			):
				header_map = _build_csv_header_map(header_columns)

		for i in range(1, lines.size()):
			var line := str(lines[i]).strip_edges()
			if line.is_empty():
				continue
			var columns: Array[String] = _parse_csv_line(line)
			if columns.size() < 1:
				continue
			var word_text := _get_csv_value(columns, header_map, ["word"], 0).strip_edges()
			if word_text != "":
				texts.append(word_text)

	return texts


func _collect_sentence_texts() -> Array[String]:
	var texts: Array[String] = []
	for group_name in list_sentence_groups():
		var csv_path := _find_sentence_group_csv_path(group_name)
		if csv_path.is_empty():
			continue
		var file := FileAccess.open(csv_path, FileAccess.READ)
		if not file:
			continue
		var raw_text := file.get_as_text()
		file.close()
		var lines := raw_text.split("\n")
		var header_map: Dictionary = {}
		if lines.size() > 0:
			var header_columns: Array[String] = _parse_csv_line(str(lines[0]).strip_edges())
			if header_columns.size() > 0:
				var first_header := str(header_columns[0]).strip_edges().to_lower()
				if first_header == "sentence" or first_header == "text":
					header_map = _build_csv_header_map(header_columns)

		for i in range(1, lines.size()):
			var line := str(lines[i]).strip_edges()
			if line.is_empty():
				continue
			var columns: Array[String] = _parse_csv_line(line)
			if columns.size() < 1:
				continue
			var sentence_text := (
				_get_csv_value(columns, header_map, ["sentence", "text"], 0).strip_edges()
			)
			if sentence_text != "":
				texts.append(sentence_text)

	return texts


func load_word_entries(group_name: String) -> Array[Dictionary]:
	if _shared_word_entries_by_group.has(group_name):
		return (_shared_word_entries_by_group.get(group_name, []) as Array).duplicate(true)

	var csv_path := _find_group_csv_path(group_name)
	if csv_path.is_empty():
		return []

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		return []

	var raw_text := file.get_as_text()
	file.close()
	var lines := raw_text.split("\n")
	var entries: Array[Dictionary] = []
	var header_map: Dictionary = {}
	var data_start_index := 0

	if lines.size() > 0:
		var header_columns: Array[String] = _parse_csv_line(str(lines[0]).strip_edges())
		if header_columns.size() > 0 and str(header_columns[0]).strip_edges().to_lower() == "word":
			header_map = _build_csv_header_map(header_columns)
			data_start_index = 1

	for i in range(data_start_index, lines.size()):
		var line := str(lines[i]).strip_edges()
		if line.is_empty():
			continue

		var columns: Array[String] = _parse_csv_line(line)
		if columns.size() < 1:
			continue

		var word_text := _get_csv_value(columns, header_map, ["word"], 0)
		word_text = word_text.to_lower()
		if word_text.is_empty():
			continue

		var reading_lists_text := _get_csv_value(
			columns, header_map, ["reading lists", "reading_lists", "lists"], -1
		)
		var phonics_stage := _get_csv_value(
			columns, header_map, ["phonics stage", "phonics_stage", "stage"], -1
		)
		var simple_pronunciation := _get_csv_value(
			columns, header_map, ["simple pronunciation", "simple_pronunciation"], -1
		)
		var strict_pronunciation := _get_csv_value(
			columns, header_map, ["strict pronunciation", "strict_pronunciation"], -1
		)
		var audio_hint_text := _get_csv_value(
			columns,
			header_map,
			["audio hint", "audio_hint", "pronunciation hint", "pronunciation_hint"],
			-1
		)
		var explicit_audio_path := _get_csv_value(
			columns,
			header_map,
			["word audio path", "word_audio_path", "audio path", "audio_path"],
			-1
		)
		var breakdown := _get_csv_value(
			columns, header_map, ["grapheme to phoneme breakdown", "breakdown"], 2
		)
		var ipa := _get_csv_value(columns, header_map, ["ipa"], 1)

		var simple_phonemes: Array[String] = _phonemes_from_pronunciation_field(
			word_text, simple_pronunciation, breakdown
		)
		if simple_phonemes.is_empty():
			simple_phonemes = _phonemes_from_breakdown(word_text, breakdown)
		if simple_phonemes.is_empty() and not ipa.is_empty():
			simple_phonemes = _phonemes_from_pronunciation_field(word_text, ipa, breakdown)

		var strict_phonemes: Array[String] = _phonemes_from_pronunciation_field(
			word_text, strict_pronunciation, breakdown
		)
		if strict_phonemes.is_empty():
			strict_phonemes = simple_phonemes.duplicate()

		var audio_hints: Array[String] = _build_audio_hints(
			audio_hint_text, simple_pronunciation, strict_pronunciation
		)
		var phonemes: Array[String] = strict_phonemes
		if phonemes.is_empty():
			phonemes = simple_phonemes.duplicate()

		var letters: Array[String] = []
		for character in word_text:
			letters.append(character)

		if phonemes.is_empty():
			phonemes = _phonemes_from_letters(word_text)

		var reading_lists: Array[String] = []
		for reading_list in _split_multi_value_field(reading_lists_text):
			reading_lists.append(str(reading_list))
		var audio_path := _resolve_word_audio_path(
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
			continue

		(
			entries
			. append(
				{
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
			)
		)

	entries.sort_custom(_sort_entries)
	_shared_word_entries_by_group[group_name] = entries.duplicate(true)
	return entries


func load_sentence_entries(group_name: String) -> Array[Dictionary]:
	if _shared_sentence_entries_by_group.has(group_name):
		return (_shared_sentence_entries_by_group.get(group_name, []) as Array).duplicate(true)

	var csv_path := _find_sentence_group_csv_path(group_name)
	if csv_path.is_empty():
		return []

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		return []

	var raw_text := file.get_as_text()
	file.close()
	var lines := raw_text.split("\n")
	var entries: Array[Dictionary] = []
	var header_map: Dictionary = {}
	var data_start_index := 0

	if lines.size() > 0:
		var header_columns: Array[String] = _parse_csv_line(str(lines[0]).strip_edges())
		if (
			header_columns.size() > 0
			and str(header_columns[0]).strip_edges().to_lower() == "sentence"
		):
			header_map = _build_csv_header_map(header_columns)
			data_start_index = 1

	for i in range(data_start_index, lines.size()):
		var line := str(lines[i]).strip_edges()
		if line.is_empty():
			continue

		var columns: Array[String] = _parse_csv_line(line)
		if columns.size() < 1:
			continue

		var sentence_text := _get_csv_value(columns, header_map, ["sentence", "text"], 0)
		sentence_text = sentence_text.strip_edges()
		if sentence_text.is_empty():
			continue

		var reading_lists_text := _get_csv_value(
			columns, header_map, ["reading lists", "reading_lists", "lists"], -1
		)
		var phonics_stage := _get_csv_value(
			columns, header_map, ["phonics stage", "phonics_stage", "stage"], -1
		)
		var pronunciation_map_text := _get_csv_value(
			columns,
			header_map,
			[
				"pronunciations",
				"pronunciation map",
				"word pronunciations",
				"sentence pronunciations",
			],
			-1
		)
		var sentence_audio_path := _get_csv_value(
			columns,
			header_map,
			["sentence audio path", "sentence_audio_path", "audio path", "audio_path"],
			-1
		)

		var pronunciation_map := _parse_pronunciation_map_field(pronunciation_map_text)
		var words := ReadingContentLoaderHelpers.tokenize_audio_text(sentence_text)
		var pronunciation_hints := _build_pronunciation_hints(pronunciation_map)

		(
			entries
			. append(
				{
					"text": sentence_text,
					"words": words,
					"letters": words,
					"reading_lists": _split_multi_value_field(reading_lists_text),
					"phonics_stage": phonics_stage,
					"pronunciations": pronunciation_map,
					"pronunciation_hints": pronunciation_hints,
					"sentence_audio_path": sentence_audio_path,
					"group": group_name,
				}
			)
		)

	entries.sort_custom(_sort_entries)
	_shared_sentence_entries_by_group[group_name] = entries.duplicate(true)
	return entries


func load_sentence_entries_for_text(group_name: String, sentence_text: String) -> Array[Dictionary]:
	return ReadingContentLoaderHelpers.load_sentence_entries_for_text(
		self, group_name, sentence_text
	)


func load_word_entries_for_reading_list(
	group_name: String, reading_list_name: String = "", limit: int = 20
) -> Array[Dictionary]:
	return ReadingContentLoaderHelpers.load_word_entries_for_reading_list(
		self, group_name, reading_list_name, limit
	)


func _group_has_word_csv(group_name: String) -> bool:
	for file_name in WORD_CSV_FILE_NAMES:
		var path := "%s/%s/%s" % [WORD_ROOT, group_name, file_name]
		if FileAccess.file_exists(path):
			return true
	return false


func _group_has_sentence_csv(group_name: String) -> bool:
	for file_name in SENTENCE_CSV_FILE_NAMES:
		var path := "%s/%s/%s" % [WORD_ROOT, group_name, file_name]
		if FileAccess.file_exists(path):
			return true
	return false


func _build_csv_header_map(headers: Array[String]) -> Dictionary:
	var header_map: Dictionary = {}
	for index in range(headers.size()):
		var header := str(headers[index]).strip_edges().to_lower()
		if header.is_empty():
			continue
		header_map[header] = index
	return header_map


func _get_csv_value(
	columns: Array[String],
	header_map: Dictionary,
	header_names: Array[String],
	fallback_index: int = -1
) -> String:
	for header_name in header_names:
		var normalized_header := str(header_name).strip_edges().to_lower()
		if header_map.has(normalized_header):
			var index := int(header_map[normalized_header])
			if index >= 0 and index < columns.size():
				return str(columns[index]).strip_edges()
	if fallback_index >= 0 and fallback_index < columns.size():
		return str(columns[fallback_index]).strip_edges()
	return ""


func _split_multi_value_field(field_text: String) -> Array[String]:
	var values: Array[String] = []
	for item in field_text.split(";", false):
		var trimmed := str(item).strip_edges()
		if trimmed.is_empty():
			continue
		values.append(trimmed)
	return values


func _phonemes_from_pronunciation_field(
	word_text: String, pronunciation_text: String, breakdown: String = ""
) -> Array[String]:
	var trimmed := pronunciation_text.strip_edges()
	if trimmed.is_empty():
		return []
	if trimmed.find("→") >= 0 or trimmed.find("->") >= 0:
		return _phonemes_from_breakdown(word_text, trimmed)

	var phonemes: Array[String] = []
	var normalized := trimmed.replace(",", " ").replace("/", " ").replace("|", " ")
	for token in normalized.split(" ", false):
		var phoneme := str(token).strip_edges()
		if phoneme.is_empty():
			continue
		phonemes.append(phoneme)

	if phonemes.is_empty() and not breakdown.is_empty():
		return _phonemes_from_breakdown(word_text, breakdown)
	return phonemes


func _build_audio_hints(
	audio_hint_text: String, simple_pronunciation: String, strict_pronunciation: String
) -> Array[String]:
	var hints: Array[String] = _split_multi_value_field(audio_hint_text)
	if not hints.is_empty():
		return hints

	var simple_hint := _compact_pronunciation_text(simple_pronunciation)
	var strict_hint := _compact_pronunciation_text(strict_pronunciation)
	if strict_hint.is_empty():
		return hints
	if simple_hint != strict_hint:
		hints.append(strict_hint)

	return hints


func _compact_pronunciation_text(pronunciation_text: String) -> String:
	var compact := str(pronunciation_text).strip_edges()
	if compact.is_empty():
		return ""
	compact = compact.replace("/", "")
	compact = compact.replace(" ", "")
	compact = compact.replace(",", "")
	compact = compact.replace("|", "")
	return compact


func _find_group_csv_path(group_name: String) -> String:
	for file_name in WORD_CSV_FILE_NAMES:
		var path := "%s/%s/%s" % [WORD_ROOT, group_name, file_name]
		if FileAccess.file_exists(path):
			return path
	return ""


func _find_sentence_group_csv_path(group_name: String) -> String:
	for file_name in SENTENCE_CSV_FILE_NAMES:
		var path := "%s/%s/%s" % [WORD_ROOT, group_name, file_name]
		if FileAccess.file_exists(path):
			return path
	return ""


func _parse_pronunciation_map_field(pronunciation_map_text: String) -> Dictionary:
	var pronunciation_map: Dictionary = {}
	for item in _split_multi_value_field(pronunciation_map_text):
		var separator_index := item.find("=")
		if separator_index == -1:
			separator_index = item.find(":")
		if separator_index == -1:
			continue
		var word := item.substr(0, separator_index).strip_edges().to_lower()
		var pronunciation := item.substr(separator_index + 1).strip_edges()
		if word.is_empty() or pronunciation.is_empty():
			continue
		pronunciation_map[word] = pronunciation
	return pronunciation_map


func _build_pronunciation_hints(pronunciation_map: Dictionary) -> Array[String]:
	var hints: Array[String] = []
	for word in pronunciation_map.keys():
		var pronunciation := str(pronunciation_map[word]).strip_edges()
		if pronunciation.is_empty():
			continue
		hints.append("%s=%s" % [str(word).strip_edges().to_lower(), pronunciation])
	return hints


func _parse_csv_line(line: String) -> Array[String]:
	var values: Array[String] = []
	var buffer := ""
	var in_quotes := false
	for ch in line:
		if ch == '"':
			in_quotes = not in_quotes
			continue
		if ch == "," and not in_quotes:
			values.append(buffer.strip_edges())
			buffer = ""
			continue
		buffer += ch
	values.append(buffer.strip_edges())
	return values


func _phonemes_from_breakdown(word_text: String, breakdown: String) -> Array[String]:
	if breakdown.is_empty():
		return []

	var mapping = _parse_grapheme_to_phoneme_breakdown(breakdown)
	if mapping.size() == 0:
		return []

	var lower_word := word_text.to_lower()
	var result: Array[String] = []
	var i := 0
	while i < lower_word.length():
		var match_grapheme := ""
		var match_phoneme := ""

		for pair in mapping:
			var g := str(pair.get("grapheme", "")).to_lower()
			if g == "":
				continue
			if lower_word.substr(i, g.length()) == g and g.length() > match_grapheme.length():
				match_grapheme = g
				match_phoneme = str(pair.get("phoneme", ""))

		if match_grapheme == "":
			var ch := lower_word[i]
			var alias := LETTER_TO_PHONEME.get(ch, ch) as String
			if not _phoneme_paths.has(alias):
				alias = ReadingContentLoaderHelpers.find_first_existing_alias([ch, alias, "uh"])
			result.append(alias)
			i += 1
			continue

		for idx in range(match_grapheme.length()):
			result.append(match_phoneme)
		i += match_grapheme.length()

	return result


func _parse_grapheme_to_phoneme_breakdown(breakdown: String) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	var parts := breakdown.split(",")
	for part in parts:
		var trimmed := str(part).strip_edges()
		if trimmed == "":
			continue

		var arrow := ""
		if trimmed.find("→") >= 0:
			arrow = "→"
		elif trimmed.find("->") >= 0:
			arrow = "->"
		if arrow == "":
			continue

		var items := trimmed.split(arrow, false)
		if items.size() != 2:
			continue

		var grapheme := str(items[0]).strip_edges().to_lower()
		var phoneme := str(items[1]).strip_edges()
		if phoneme.begins_with("/") and phoneme.ends_with("/"):
			phoneme = phoneme.substr(1, phoneme.length() - 2)

		pairs.append({"grapheme": grapheme, "phoneme": phoneme})

	return pairs


func _phonemes_from_letters(word_text: String) -> Array[String]:
	var phonemes: Array[String] = []
	for character in word_text:
		var phoneme_alias: String = LETTER_TO_PHONEME.get(character, character) as String
		if not _phoneme_paths.has(phoneme_alias):
			phoneme_alias = ReadingContentLoaderHelpers.find_first_existing_alias(
				[character, phoneme_alias, "uh"]
			)
		phonemes.append(phoneme_alias)
	return phonemes


func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	return str(a["text"]) < str(b["text"])


func _normalize_phoneme_alias(phoneme_alias: String) -> String:
	var normalized_alias: String = str(phoneme_alias).strip_edges().to_lower()
	normalized_alias = normalized_alias.replace("/", "")
	normalized_alias = normalized_alias.replace("ː", "!")
	return normalized_alias


func get_phoneme_stream(phoneme_alias: String) -> AudioStream:
	var normalized_alias: String = _normalize_phoneme_alias(phoneme_alias)
	var resolved_path: String = _phoneme_paths.get(normalized_alias, "") as String
	if resolved_path.is_empty():
		return null
	return load(resolved_path) as AudioStream


func get_phoneme_stream_for_label(phoneme_label: String, letter: String = "") -> AudioStream:
	# Try exact label first.
	var aliases: Array[String] = []
	if phoneme_label != "":
		aliases.append(phoneme_label)
		aliases.append(phoneme_label.to_lower())

	if letter != "":
		aliases.append(letter.to_lower())
		aliases.append(letter)
		var mapped = LETTER_TO_PHONEME.get(letter.to_lower(), "") as String
		if mapped != "":
			aliases.append(mapped)

	# Common safe fallback alias.
	aliases.append("uh")
	aliases.append("a")

	for alias in aliases:
		if alias == "":
			continue
		var stream = get_phoneme_stream(str(alias))
		if stream != null:
			return stream

	# If no match, pick first available phoneme sample and continue.
	if _phoneme_paths.size() > 0:
		var fallback_alias: String = str(_phoneme_paths.keys()[0])
		return get_phoneme_stream(fallback_alias)

	return null


func list_phonemes() -> Array[String]:
	var phonemes: Array[String] = []
	for key in _phoneme_paths.keys():
		phonemes.append(str(key))
	phonemes.sort()
	return phonemes


func get_word_stream(entry: Dictionary) -> AudioStream:
	var word_audio_path := str(entry.get("word_audio_path", "")).strip_edges()
	if word_audio_path.is_empty():
		word_audio_path = str(entry.get("sentence_audio_path", "")).strip_edges()
	if word_audio_path.is_empty() or not FileAccess.file_exists(word_audio_path):
		word_audio_path = _resolve_word_audio_path_from_entry(entry)
	if word_audio_path.is_empty():
		return null
	return load(word_audio_path) as AudioStream


func get_entry_units(entry: Dictionary) -> Array[String]:
	var units: Array[String] = entry.get("words", []) as Array[String]
	if units.is_empty():
		units = entry.get("letters", []) as Array[String]
	return units


func get_entry_pronunciation_label(entry: Dictionary, index: int) -> String:
	var pronunciation_map: Dictionary = entry.get("pronunciations", {}) as Dictionary
	if pronunciation_map.has(index):
		return str(pronunciation_map[index])
	if pronunciation_map.has(str(index)):
		return str(pronunciation_map[str(index)])
	var units := get_entry_units(entry)
	if index < 0 or index >= units.size():
		return get_phoneme_label(entry, index)
	var unit_text := str(units[index]).strip_edges().to_lower()
	if pronunciation_map.has(unit_text):
		return str(pronunciation_map[unit_text])
	return get_phoneme_label(entry, index)


func get_phoneme_label(entry: Dictionary, index: int) -> String:
	var phonemes: Array = entry.get("phonemes", []) as Array
	if index < 0 or index >= phonemes.size():
		return ""
	return str(phonemes[index])


func _refresh_phoneme_paths() -> void:
	if _shared_phoneme_paths.is_empty():
		var phoneme_paths: Dictionary = {}
		for file_name in DirAccess.get_files_at(PHONEME_ROOT):
			var extension := file_name.get_extension().to_lower()
			if extension not in ["wav", "ogg", "mp3"]:
				continue
			var alias := file_name.get_basename().to_lower()
			phoneme_paths[alias] = "%s/%s" % [PHONEME_ROOT, file_name]
		_shared_phoneme_paths = phoneme_paths
	_phoneme_paths = _shared_phoneme_paths


func _refresh_word_audio_paths() -> void:
	if _shared_word_audio_candidates.is_empty():
		var word_audio_candidates: Dictionary = {}
		for group in list_word_groups():
			var group_path := "%s/%s" % [WORD_ROOT, group]
			var group_candidates: Array[Dictionary] = []
			_collect_word_audio_candidates(group_path, group_path, group, group_candidates)
			word_audio_candidates[group] = group_candidates
		_shared_word_audio_candidates = word_audio_candidates
	_word_audio_candidates = _shared_word_audio_candidates


func _collect_word_audio_candidates(
	directory_path: String, root_path: String, group_name: String, candidates: Array[Dictionary]
) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return

	directory.list_dir_begin()
	while true:
		var file_name := directory.get_next()
		if file_name.is_empty():
			break
		if file_name.begins_with("."):
			continue
		var next_path := "%s/%s" % [directory_path, file_name]
		if directory.current_is_dir():
			_collect_word_audio_candidates(next_path, root_path, group_name, candidates)
			continue

		var extension := file_name.get_extension().to_lower()
		if extension not in ["wav", "ogg", "mp3"]:
			continue

		var relative_path := next_path.replace(root_path + "/", "")
		var base_name := file_name.get_basename().strip_edges().to_lower()
		var candidate := {
			"path": next_path,
			"group": group_name,
			"base_name": base_name,
			"relative_path": relative_path.to_lower(),
			"tokens": ReadingContentLoaderHelpers.tokenize_audio_text(relative_path),
		}
		candidates.append(candidate)
	directory.list_dir_end()


func _resolve_word_audio_path(
	group_name: String,
	word_text: String,
	reading_lists: Array[String],
	phonics_stage: String,
	simple_phonemes: Array[String],
	strict_phonemes: Array[String],
	audio_hints: Array[String] = [],
	explicit_audio_path: String = ""
) -> String:
	var explicit_path := explicit_audio_path.strip_edges()
	if explicit_path != "" and FileAccess.file_exists(explicit_path):
		return explicit_path

	var group_candidates: Array[Dictionary] = []
	var cached_group_candidates: Array = _word_audio_candidates.get(group_name, []) as Array
	for candidate in cached_group_candidates:
		if candidate is Dictionary:
			group_candidates.append(candidate)
	if group_candidates.is_empty():
		for candidate_group in _word_audio_candidates.values():
			for candidate in candidate_group as Array:
				if candidate is Dictionary:
					group_candidates.append(candidate)

	var best_candidate := _pick_best_word_audio_candidate(
		group_candidates,
		word_text,
		reading_lists,
		phonics_stage,
		simple_phonemes,
		strict_phonemes,
		audio_hints
	)
	if best_candidate.is_empty():
		return ""
	return str(best_candidate.get("path", ""))


func _resolve_word_audio_path_from_entry(entry: Dictionary) -> String:
	var reading_lists: Array[String] = []
	for item in entry.get("reading_lists", []):
		reading_lists.append(str(item))

	var simple_phonemes: Array[String] = []
	for item in entry.get("simple_phonemes", []):
		simple_phonemes.append(str(item))

	var strict_phonemes: Array[String] = []
	for item in entry.get("strict_phonemes", []):
		strict_phonemes.append(str(item))

	var audio_hints: Array[String] = []
	for item in entry.get("audio_hints", []):
		audio_hints.append(str(item))

	return _resolve_word_audio_path(
		str(entry.get("group", "")),
		str(entry.get("text", "")),
		reading_lists,
		str(entry.get("phonics_stage", "")),
		simple_phonemes,
		strict_phonemes,
		audio_hints,
		str(entry.get("word_audio_path", ""))
	)


func _pick_best_word_audio_candidate(
	candidates: Array[Dictionary],
	word_text: String,
	reading_lists: Array[String],
	phonics_stage: String,
	simple_phonemes: Array[String],
	strict_phonemes: Array[String],
	audio_hints: Array[String]
) -> Dictionary:
	var search_terms: Array[String] = []
	var basename_candidates: Array[String] = (
		ReadingContentLoaderHelpers.build_word_audio_basename_candidates(word_text, audio_hints)
	)
	var normalized_word := ReadingContentLoaderHelpers.normalize_audio_lookup_text(word_text)
	var word_search_terms: Array[String] = []
	if not normalized_word.is_empty():
		word_search_terms.append(normalized_word)
		word_search_terms.append(word_text.to_lower())
		word_search_terms.append_array(ReadingContentLoaderHelpers.tokenize_audio_text(word_text))
		word_search_terms.append(normalized_word.replace("'", ""))
	search_terms.append_array(word_search_terms)
	search_terms.append_array(reading_lists)
	search_terms.append(phonics_stage)
	search_terms.append_array(audio_hints)
	search_terms.append_array(
		ReadingContentLoaderHelpers.build_word_audio_search_terms_from_phonemes(simple_phonemes)
	)
	search_terms.append_array(
		ReadingContentLoaderHelpers.build_word_audio_search_terms_from_phonemes(strict_phonemes)
	)

	var best_candidate: Dictionary = {}
	var best_score := -2147483648
	for candidate in candidates:
		var score := _score_word_audio_candidate(
			candidate, word_text, normalized_word, basename_candidates, search_terms
		)
		if score > best_score:
			best_score = score
			best_candidate = candidate
		elif score == best_score and not best_candidate.is_empty():
			if str(candidate.get("path", "")) < str(best_candidate.get("path", "")):
				best_candidate = candidate

	return best_candidate


func _score_word_audio_candidate(
	candidate: Dictionary,
	word_text: String,
	normalized_word: String,
	basename_candidates: Array[String],
	search_terms: Array[String]
) -> int:
	var score := 0
	var candidate_base := str(candidate.get("base_name", "")).strip_edges().to_lower()
	var candidate_relative := str(candidate.get("relative_path", "")).strip_edges().to_lower()
	var candidate_tokens: Array = candidate.get("tokens", []) as Array
	var word_terms: Array[String] = ReadingContentLoaderHelpers.build_word_audio_search_terms(
		word_text
	)

	if candidate_base == normalized_word:
		score += 1500
	elif basename_candidates.has(candidate_base):
		score += 2500
	elif candidate_base.begins_with(normalized_word + "-"):
		score += 1200
	elif candidate_relative.find(normalized_word) >= 0:
		score += 250

	for term in word_terms:
		var normalized_term := ReadingContentLoaderHelpers.normalize_audio_lookup_text(term)
		if normalized_term.is_empty():
			continue
		if candidate_tokens.has(normalized_term):
			score += 50
		elif candidate_relative.find(normalized_term) >= 0:
			score += 25

	for term in search_terms:
		var normalized_term := ReadingContentLoaderHelpers.normalize_audio_lookup_text(term)
		if normalized_term.is_empty():
			continue
		if candidate_tokens.has(normalized_term):
			score += 40
		elif candidate_relative.find(normalized_term) >= 0:
			score += 15

	return score


func _find_first_existing_alias(candidates: Array) -> String:
	for candidate in candidates:
		var value := str(candidate).strip_edges().to_lower()
		if _phoneme_paths.has(value):
			return value
	return ""
