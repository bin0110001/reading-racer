class_name TestContentLoaderReadingLists
extends GdUnitTestSuite


class CountingReadingContentLoader:
	extends ReadingContentLoader

	var resolve_word_audio_path_calls := 0

	func _resolve_word_audio_path(
		_group_name: String,
		_word_text: String,
		_reading_lists: Array[String],
		_phonics_stage: String,
		_simple_phonemes: Array[String],
		_strict_phonemes: Array[String],
		_audio_hints: Array[String] = [],
		_explicit_audio_path: String = ""
	) -> String:
		resolve_word_audio_path_calls += 1
		return "res://audio/words/sightwords/cat.wav"


func test_can_cat_reading_lists_are_discoverable() -> void:
	var loader = ReadingContentLoader.new()
	var lists := loader.list_word_reading_lists("can_cat")
	assert_that(lists).is_equal(["1-5", "k-3"])


func test_can_cat_reading_list_is_limited_to_twenty_words() -> void:
	var loader = ReadingContentLoader.new()
	var entries := loader.load_word_entries_for_reading_list("can_cat", "1-5", 20)
	assert_that(entries.size()).is_equal(20)

	for entry in entries:
		var reading_lists := entry.get("reading_lists", []) as Array
		assert_that(reading_lists.has("1-5")).is_true()


func test_can_cat_reading_list_only_resolves_audio_for_returned_entries() -> void:
	var loader = CountingReadingContentLoader.new()
	var entries := loader.load_word_entries_for_reading_list("can_cat", "1-5", 20)

	assert_that(entries.size()).is_equal(20)
	assert_that(loader.resolve_word_audio_path_calls).is_equal(entries.size())
	loader.free()


func test_can_cat_sentence_lookup_by_text_returns_single_entry() -> void:
	var loader = ReadingContentLoader.new()
	var entries := loader.load_sentence_entries_for_text("can_cat", "wind up the string")
	assert_that(entries.size()).is_equal(1)
	assert_that(str(entries[0].get("text", ""))).is_equal("wind up the string")
