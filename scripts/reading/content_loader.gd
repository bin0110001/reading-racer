# This is a class
class_name ReadingContentLoader extends Object

const PHONEME_ROOT := "res://audio/phenomes"
const WORD_ROOT := "res://audio/words"
const WORD_CSV_FILE_NAMES := ["Words.csv", "words.csv"]

const LETTER_TO_PHONEME := {}

var _phoneme_paths: Dictionary = {}
var _word_audio_paths: Dictionary = {}


func _init() -> void:
	_refresh_phoneme_paths()
	_refresh_word_audio_paths()


func list_word_groups() -> Array[String]:
	var groups: Array[String] = []
	for directory_name in DirAccess.get_directories_at(WORD_ROOT):
		if _group_has_word_csv(directory_name):
			groups.append(directory_name)
	groups.sort()
	return groups


func load_word_entries(group_name: String) -> Array[Dictionary]:
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

	for i in range(lines.size()):
		var line := str(lines[i]).strip_edges()
		if line.is_empty():
			continue
		if i == 0 and line.to_lower().begins_with("word"):
			continue

		var columns: Array[String] = _parse_csv_line(line)
		if columns.size() < 1:
			continue

		var word_text := str(columns[0]).strip_edges().to_lower()
		if word_text.is_empty():
			continue

		var audio_path: String = _word_audio_paths.get(word_text, "") as String
		if audio_path.is_empty():
			continue

		var breakdown: String = ""
		if columns.size() >= 3:
			breakdown = str(columns[2]).strip_edges()

		var letters: Array[String] = []
		for character in word_text:
			letters.append(character)

		var phonemes: Array[String] = _phonemes_from_breakdown(word_text, breakdown)
		if phonemes.is_empty():
			phonemes = _phonemes_from_letters(word_text)

		(
			entries
			. append(
				{
					"text": word_text,
					"letters": letters,
					"phonemes": phonemes,
					"word_audio_path": audio_path,
					"group": group_name,
				}
			)
		)

	entries.sort_custom(_sort_entries)
	return entries


func _group_has_word_csv(group_name: String) -> bool:
	for file_name in WORD_CSV_FILE_NAMES:
		var path := "%s/%s/%s" % [WORD_ROOT, group_name, file_name]
		if FileAccess.file_exists(path):
			return true
	return false


func _find_group_csv_path(group_name: String) -> String:
	for file_name in WORD_CSV_FILE_NAMES:
		var path := "%s/%s/%s" % [WORD_ROOT, group_name, file_name]
		if FileAccess.file_exists(path):
			return path
	return ""


func _parse_csv_line(line: String) -> Array[String]:
	var values: Array[String] = []
	var buffer := ""
	var in_quotes := false
	for char in line:
		if char == '"':
			in_quotes = not in_quotes
			continue
		if char == "," and not in_quotes:
			values.append(buffer.strip_edges())
			buffer = ""
			continue
		buffer += char
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
			var char := lower_word[i]
			var alias := LETTER_TO_PHONEME.get(char, char) as String
			if not _phoneme_paths.has(alias):
				alias = _find_first_existing_alias([char, alias, "uh"])
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
			phoneme_alias = _find_first_existing_alias([character, phoneme_alias, "uh"])
		phonemes.append(phoneme_alias)
	return phonemes


func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	return str(a["text"]) < str(b["text"])


func get_phoneme_stream(phoneme_alias: String) -> AudioStream:
	var normalized_alias: String = str(phoneme_alias).strip_edges().to_lower()
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
	return load(str(entry.get("word_audio_path", ""))) as AudioStream


func get_phoneme_label(entry: Dictionary, index: int) -> String:
	var phonemes: Array = entry.get("phonemes", []) as Array
	if index < 0 or index >= phonemes.size():
		return ""
	return str(phonemes[index])


func _refresh_phoneme_paths() -> void:
	_phoneme_paths.clear()
	for file_name in DirAccess.get_files_at(PHONEME_ROOT):
		var extension := file_name.get_extension().to_lower()
		if extension not in ["wav", "ogg", "mp3"]:
			continue
		var alias := file_name.get_basename().to_lower()
		_phoneme_paths[alias] = "%s/%s" % [PHONEME_ROOT, file_name]


func _refresh_word_audio_paths() -> void:
	_word_audio_paths.clear()
	for group in list_word_groups():
		var group_path := "%s/%s" % [WORD_ROOT, group]
		for file_name in DirAccess.get_files_at(group_path):
			var extension := file_name.get_extension().to_lower()
			if extension not in ["wav", "ogg", "mp3"]:
				continue
			var word := file_name.get_basename().strip_edges().to_lower()
			var path := "%s/%s" % [group_path, file_name]
			_word_audio_paths[word] = path


func _find_first_existing_alias(candidates: Array) -> String:
	for candidate in candidates:
		var value := str(candidate).strip_edges().to_lower()
		if _phoneme_paths.has(value):
			return value
	return ""
