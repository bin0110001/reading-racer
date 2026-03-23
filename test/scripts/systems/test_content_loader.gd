class_name TestContentLoader
extends GdUnitTestSuite

const ReadingContentLoaderScript = preload("res://scripts/reading/content_loader.gd")


func before_all() -> void:
	# Setup for all tests
	pass


func test_content_loader_creation() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	assert_that(loader).is_not_null()


func test_list_word_groups_returns_array() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var groups: Array[String] = loader.list_word_groups()
	assert_that(groups).is_instance_of(Array)


func test_load_word_entries_with_invalid_group() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var entries: Array[Dictionary] = loader.load_word_entries("nonexistent_group")
	assert_that(entries).is_empty()


func test_load_word_entries_returns_array() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var entries: Array[Dictionary] = loader.load_word_entries("test_group")
	# Should return an array (empty if group doesn't exist)
	assert_that(entries).is_instance_of(Array)


func test_load_word_entries_structure() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	# Try to load any existing group
	var groups: Array[String] = loader.list_word_groups()
	if groups.is_empty():
		skip("No word groups available to test")
	var entries: Array[Dictionary] = loader.load_word_entries(groups[0])
	if entries.is_empty():
		skip("Test group has no entries")
	# Verify first entry has expected fields
	var entry: Dictionary = entries[0]
	assert_that(entry.has("text")).is_true()
	assert_that(entry.has("letters")).is_true()
	assert_that(entry.has("phonemes")).is_true()
	assert_that(entry.has("word_audio_path")).is_true()
	assert_that(entry.has("group")).is_true()


func test_load_word_entries_letters_array() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var groups: Array[String] = loader.list_word_groups()
	if groups.is_empty():
		skip("No word groups available to test")
	var entries: Array[Dictionary] = loader.load_word_entries(groups[0])
	if entries.is_empty():
		skip("Test group has no entries")
	var entry: Dictionary = entries[0]
	var letters: Array = entry.get("letters", []) as Array
	assert_that(letters).is_instance_of(Array)
	assert_that(letters.size()).is_greater(0)


func test_load_word_entries_phonemes_array() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var groups: Array[String] = loader.list_word_groups()
	if groups.is_empty():
		skip("No word groups available to test")
	var entries: Array[Dictionary] = loader.load_word_entries(groups[0])
	if entries.is_empty():
		skip("Test group has no entries")
	var entry: Dictionary = entries[0]
	var phonemes: Array = entry.get("phonemes", []) as Array
	assert_that(phonemes).is_instance_of(Array)
	assert_that(phonemes.size()).is_greater_equal(0)


func test_load_word_entries_csv_breakdown_is_used() -> void:
	var loader: ReadingContentLoader = ReadingContentLoader.new()
	var entries: Array[Dictionary] = loader.load_word_entries("sightwords")
	assert_that(entries).is_not_empty()

	var found: Dictionary = {}
	for entry in entries:
		if str(entry.get("text", "")).to_lower() == "go":
			found = entry
			break
	assert_that(found.is_empty()).is_false()
	var letters: Array = found.get("letters", []) as Array
	var phonemes: Array = found.get("phonemes", []) as Array
	assert_that(letters.size()).is_equal_to(2)
	assert_that(phonemes.size()).is_equal_to(2)
	assert_that(phonemes[0]).is_equal_to("ɡ")
	assert_that(phonemes[1]).is_equal_to("oʊ")
