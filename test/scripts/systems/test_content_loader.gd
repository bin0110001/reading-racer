class_name TestContentLoader
extends GdUnitTestSuite

const ReadingContentLoaderScript = preload("res://scripts/reading/content_loader.gd")


func before_all() -> void:
	# Setup for all tests
	pass


func _get_first_non_empty_word_group(loader: ReadingContentLoader) -> String:
	var groups = loader.list_word_groups() as Array
	for group in groups:
		var entries = loader.load_word_entries(group) as Array
		if not entries.is_empty():
			return group
	return ""


func test_content_loader_creation() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	assert_that(loader).is_not_null()


func test_list_word_groups_returns_array() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var groups = loader.list_word_groups() as Array
	assert_that(groups).is_instance_of(Array)


func test_load_word_entries_with_invalid_group() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var entries = loader.load_word_entries("nonexistent_group") as Array
	assert_that(entries).is_empty()


func test_load_word_entries_returns_array() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var entries = loader.load_word_entries("test_group") as Array
	# Should return an array (empty if group doesn't exist)
	assert_that(entries).is_instance_of(Array)


func test_reading_content_loader_list_word_texts_under_one_second() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var start_ms := Time.get_ticks_msec()
	var words = loader.list_word_texts() as Array
	var elapsed_ms := Time.get_ticks_msec() - start_ms

	assert_that(elapsed_ms).is_less(1000)
	assert_that(words).is_instance_of(Array)


func test_load_word_entries_structure() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var group_name := _get_first_non_empty_word_group(loader)
	if group_name.is_empty():
		return
	var entries = loader.load_word_entries(group_name) as Array
	# Verify first entry has expected fields
	var entry = entries[0] as Dictionary
	assert_that(entry.has("text")).is_true()
	assert_that(entry.has("letters")).is_true()
	assert_that(entry.has("phonemes")).is_true()
	assert_that(entry.has("word_audio_path")).is_true()
	assert_that(entry.has("group")).is_true()


func test_load_word_entries_letters_array() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var group_name := _get_first_non_empty_word_group(loader)
	if group_name.is_empty():
		return
	var entries = loader.load_word_entries(group_name) as Array
	var entry = entries[0] as Dictionary
	var letters = entry.get("letters", []) as Array
	assert_that(letters).is_instance_of(Array)
	assert_that(letters.size()).is_greater(0)


func test_load_word_entries_phonemes_array() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var group_name := _get_first_non_empty_word_group(loader)
	if group_name.is_empty():
		return
	var entries = loader.load_word_entries(group_name) as Array
	var entry = entries[0] as Dictionary
	var phonemes = entry.get("phonemes", []) as Array
	assert_that(phonemes).is_instance_of(Array)
	assert_that(phonemes.size()).is_greater_equal(0)


func test_get_phoneme_stream_for_label_fallback() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var stream = loader.get_phoneme_stream_for_label("XXXX")
	assert_that(stream).is_not_null()


func test_get_phoneme_stream_normalizes_long_vowel_aliases() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()

	var i_stream = loader.get_phoneme_stream("iː")
	assert_that(i_stream).is_not_null()
	if i_stream != null:
		assert_that(i_stream.resource_path).is_equal_to("res://audio/phenomes/i!.wav")

	var u_stream = loader.get_phoneme_stream("uː")
	assert_that(u_stream).is_not_null()
	if u_stream != null:
		assert_that(u_stream.resource_path).is_equal_to("res://audio/phenomes/u!.wav")


func test_load_word_entries_csv_breakdown_is_used() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var entries := loader.load_word_entries("sightwords")
	assert_that(entries).is_not_empty()

	var found := {}
	for entry in entries:
		if str(entry.get("text", "")).to_lower() == "go":
			found = entry
			break
	assert_that(found.is_empty()).is_false()
	var letters := found.get("letters", []) as Array
	var phonemes := found.get("phonemes", []) as Array
	assert_that(letters.size()).is_equal_to(2)
	assert_that(phonemes.size()).is_equal_to(2)
	assert_that(phonemes[0]).is_equal_to("ɡ")
	assert_that(phonemes[1]).is_equal_to("oʊ")


func test_can_cat_word_csv_uses_new_schema() -> void:
	var csv_path := "res://audio/words/can_cat/Words.csv"
	assert_that(FileAccess.file_exists(csv_path)).is_true()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	assert_that(file).is_not_null()
	if file == null:
		return

	var header := file.get_line().strip_edges()
	file.close()
	var expected_header := "Word,Reading Lists,Phonics Stage,Simple Pronunciation,Strict Pronunciation"
	assert_that(header).is_equal(expected_header)


func test_can_cat_word_csv_includes_multiple_pronunciations_for_homographs() -> void:
	var csv_path := "res://audio/words/can_cat/Words.csv"
	assert_that(FileAccess.file_exists(csv_path)).is_true()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	assert_that(file).is_not_null()
	if file == null:
		return

	var wind_rows := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("wind,"):
			wind_rows += 1
	file.close()

	assert_that(wind_rows).is_greater_equal(2)


func test_can_cat_sentence_csv_uses_pronunciation_map_schema() -> void:
	var csv_path := "res://audio/words/can_cat/Sentences.csv"
	assert_that(FileAccess.file_exists(csv_path)).is_true()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	assert_that(file).is_not_null()
	if file == null:
		return

	var header := file.get_line().strip_edges()
	file.close()
	var expected_header := "Sentence,Reading Lists,Phonics Stage,Pronunciations"
	assert_that(header).is_equal(expected_header)


func test_can_cat_sentence_csv_includes_pronunciation_examples() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var entries := loader.load_sentence_entries("can_cat")
	assert_that(entries).is_not_empty()

	var wind_up_sentence := {}
	var wind_blowing_sentence := {}
	for entry in entries:
		var sentence_text := str(entry.get("text", "")).to_lower()
		if sentence_text == "wind up the string":
			wind_up_sentence = entry
		elif sentence_text == "the wind is blowing outside":
			wind_blowing_sentence = entry

	assert_that(wind_up_sentence.is_empty()).is_false()
	assert_that(wind_blowing_sentence.is_empty()).is_false()

	var wind_up_pronunciations := wind_up_sentence.get("pronunciations", {}) as Dictionary
	var wind_blowing_pronunciations := wind_blowing_sentence.get("pronunciations", {}) as Dictionary

	assert_that(str(wind_up_pronunciations.get("wind", ""))).is_equal_to("waɪnd")
	assert_that(str(wind_blowing_pronunciations.get("wind", ""))).is_equal_to("wɪnd")
	assert_that(wind_up_sentence.get("words", [])).is_equal_to(["wind", "up", "the", "string"])

	var wind_in_the_wind_sentence := {}
	for entry in entries:
		var sentence_text := str(entry.get("text", "")).to_lower()
		if sentence_text == "wind in the wind":
			wind_in_the_wind_sentence = entry

	assert_that(wind_in_the_wind_sentence.is_empty()).is_false()
	var wind_in_words := wind_in_the_wind_sentence.get("words", []) as Array
	assert_that(wind_in_words).is_equal_to(["wind", "in", "the", "wind"])
	assert_that(loader.get_entry_pronunciation_label(wind_in_the_wind_sentence, 0)).is_equal_to(
		"waɪnd"
	)
	assert_that(loader.get_entry_pronunciation_label(wind_in_the_wind_sentence, 3)).is_equal_to(
		"wɪnd"
	)


func test_word_audio_candidate_prefers_exact_word_hint_filename() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var candidates := [
		_make_audio_candidate("res://audio/words/sightwords/wind.wav", ["wind", "wav"]),
		_make_audio_candidate("res://audio/words/sightwords/wind-ænd.wav", ["wind", "ænd", "wav"]),
	]

	var best_candidate := loader._pick_best_word_audio_candidate(
		candidates, "wind", [], "", [], [], ["ænd"]
	)

	assert_that(str(best_candidate.get("path", ""))).is_equal_to(
		"res://audio/words/sightwords/wind-ænd.wav"
	)


func test_word_audio_candidate_prefers_pronunciation_hint_filename() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var candidates := [
		_make_audio_candidate("res://audio/words/sightwords/wind.wav", ["wind", "wav"]),
		_make_audio_candidate(
			"res://audio/words/sightwords/wind-wɪnd.wav", ["wind", "wɪnd", "wav"]
		),
	]

	var best_candidate := loader._pick_best_word_audio_candidate(
		candidates, "wind", [], "", [], [], ["wɪnd"]
	)

	assert_that(str(best_candidate.get("path", ""))).is_equal_to(
		"res://audio/words/sightwords/wind-wɪnd.wav"
	)


func test_word_audio_candidate_defaults_to_plain_filename_without_hint() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var candidates := [
		_make_audio_candidate("res://audio/words/sightwords/wind.wav", ["wind", "wav"]),
		_make_audio_candidate("res://audio/words/sightwords/wind-ænd.wav", ["wind", "ænd", "wav"]),
	]

	var best_candidate := loader._pick_best_word_audio_candidate(
		candidates, "wind", [], "", [], [], []
	)

	assert_that(str(best_candidate.get("path", ""))).is_equal_to(
		"res://audio/words/sightwords/wind.wav"
	)


func _make_audio_candidate(path: String, tokens: Array) -> Dictionary:
	return {
		"path": path,
		"group": "sightwords",
		"base_name": path.get_file().get_basename().to_lower(),
		"relative_path": path.get_file().to_lower(),
		"tokens": tokens,
	}
