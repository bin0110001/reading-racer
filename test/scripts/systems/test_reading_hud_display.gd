class_name TestReadingHudDisplay
extends GdUnitTestSuite


func _own_hud() -> ReadingHUD:
	var hud := ReadingHUD.new()
	hud._ready()
	return hud


func test_spelling_display_highlights_current_letter() -> void:
	var hud := _own_hud()
	hud.set_spelling_word("cat", 1)

	assert_that(hud._spelling_word_label.visible).is_true()
	assert_that(hud._whole_word_strip.visible).is_false()
	assert_that(hud._spelling_word_label.text).contains("[color=#ffd966][u]A[/u][/color]")


func test_whole_word_display_centers_current_word() -> void:
	var hud := _own_hud()
	var entries: Array = [
		{"text": "cat"},
		{"text": "velocity"},
		{"text": "rainbow"},
	]

	hud.set_word_sequence(entries, 0)
	var first_strip_x := hud._whole_word_strip.position.x
	assert_that(hud._whole_word_strip.visible).is_true()
	assert_that(hud._whole_word_strip.get_child_count()).is_equal(3)

	hud.set_word_sequence(entries, 1)
	var second_strip_x := hud._whole_word_strip.position.x
	assert_that(second_strip_x).is_not_equal(first_strip_x)

	hud.set_word_sequence(entries, 2)
	var third_strip_x := hud._whole_word_strip.position.x
	assert_that(third_strip_x).is_not_equal(second_strip_x)
