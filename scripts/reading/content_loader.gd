class_name ReadingContentLoader
extends RefCounted

const PHONEME_ROOT := "res://audio/phenomes"
const WORD_ROOT := "res://audio/words"

const LETTER_TO_PHONEME := {
	"a": "ae",
	"b": "b",
	"c": "k",
	"d": "d",
	"e": "ɛ",
	"f": "f",
	"g": "ɡ",
	"h": "H",
	"i": "ɪ",
	"j": "dʒ",
	"k": "k",
	"l": "l",
	"m": "m",
	"n": "n",
	"o": "ɒ",
	"p": "p",
	"q": "k",
	"r": "r",
	"s": "s",
	"t": "t",
	"u": "ʌ",
	"v": "v",
	"w": "w",
	"x": "s",
	"y": "j",
	"z": "z",
}

var _phoneme_paths: Dictionary = {}


func _init() -> void:
	_refresh_phoneme_paths()


func list_word_groups() -> Array[String]:
	var groups: Array[String] = []
	for directory_name in DirAccess.get_directories_at(WORD_ROOT):
		groups.append(directory_name)
	groups.sort()
	return groups


func load_word_entries(group_name: String) -> Array[Dictionary]:
	var group_path := "%s/%s" % [WORD_ROOT, group_name]
	var entries: Array[Dictionary] = []
	var matcher := RegEx.new()
	matcher.compile("^[a-z]+$")

	for file_name in DirAccess.get_files_at(group_path):
		var extension := file_name.get_extension().to_lower()
		if extension not in ["wav", "ogg", "mp3"]:
			continue

		var text_value := file_name.get_basename().strip_edges().to_lower()
		if matcher.search(text_value) == null:
			continue

		var phonemes: Array[String] = []
		var letters: Array[String] = []
		for character in text_value:
			letters.append(character)
			var phoneme_alias: String = LETTER_TO_PHONEME.get(character, character) as String
			if not _phoneme_paths.has(phoneme_alias):
				phoneme_alias = _find_first_existing_alias([character, phoneme_alias, "ə"])
			phonemes.append(phoneme_alias)

		(
			entries
			. append(
				{
					"text": text_value,
					"letters": letters,
					"phonemes": phonemes,
					"word_audio_path": "%s/%s" % [group_path, file_name],
					"group": group_name,
				}
			)
		)

	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return str(a["text"]) < str(b["text"])
	)
	return entries


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


func _find_first_existing_alias(candidates: Array) -> String:
	for candidate in candidates:
		var value := str(candidate)
		if _phoneme_paths.has(value):
			return value
	return ""
