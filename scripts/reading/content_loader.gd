# This is a class
class_name ReadingContentLoader extends Object

const PHONEME_ROOT := "res://audio/phenomes"
const WORD_ROOT := "res://audio/words"

const LETTER_TO_PHONEME := {}

var _phoneme_paths: Dictionary = {}
var _word_audio_paths: Dictionary = {}


func _init() -> void:
	_refresh_phoneme_paths()
	_refresh_word_audio_paths()


func list_word_groups() -> Array[String]:
	var groups: Array[String] = []
	for directory_name in DirAccess.get_directories_at(WORD_ROOT):
		var json_path := "%s/%s/words.json" % [WORD_ROOT, directory_name]
		if FileAccess.file_exists(json_path):
			groups.append(directory_name)
	groups.sort()
	return groups


func load_word_entries(group_name: String) -> Array[Dictionary]:
	var json_path := "%s/%s/words.json" % [WORD_ROOT, group_name]
	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		return []
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		return []
	var data: Variant = json.get_data()
	if not data is Dictionary or not data.has("words"):
		return []
	var words: Array = data["words"] as Array
	var entries: Array[Dictionary] = []
	for word_text in words:
		word_text = str(word_text).strip_edges().to_lower()
		if word_text.is_empty():
			continue
		var audio_path: String = _word_audio_paths.get(word_text, "") as String
		if audio_path.is_empty():
			continue
		var phonemes: Array[String] = []
		var letters: Array[String] = []
		for character in word_text:
			letters.append(character)
			var phoneme_alias: String = LETTER_TO_PHONEME.get(character, character) as String
			if not _phoneme_paths.has(phoneme_alias):
				phoneme_alias = _find_first_existing_alias([character, phoneme_alias, "uh"])
			phonemes.append(phoneme_alias)
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


func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	return str(a["text"]) < str(b["text"])


func get_phoneme_stream(phoneme_alias: String) -> AudioStream:
	var resolved_path: String = _phoneme_paths.get(phoneme_alias, "") as String
	if resolved_path.is_empty():
		return null
	return load(resolved_path) as AudioStream


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
		var alias := file_name.get_basename()
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
		var value := str(candidate)
		if _phoneme_paths.has(value):
			return value
	return ""
