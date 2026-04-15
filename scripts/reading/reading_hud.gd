class_name ReadingHUD
extends CanvasLayer

signal control_mode_changed(mode_name: String)
signal word_group_changed(group_name: String)
signal volume_changed(volume: float)
signal resume_requested
signal home_requested
signal debug_path_toggled(enabled: bool)
signal steering_type_changed(steering_type: String)
signal map_style_changed(map_style: String)
signal play_debug_audio(selected_word: String, selected_phoneme: String)

var _status_label := Label.new()
var _word_display_root := Control.new()
var _spelling_word_label := RichTextLabel.new()
var _whole_word_strip := Control.new()
var _phoneme_label := Label.new()
var _help_label := Label.new()
var _feedback_label := Label.new()

var _whole_word_word_labels: Array[Label] = []

var _options_panel := PanelContainer.new()
var _control_mode_option := OptionButton.new()
var _word_group_option := OptionButton.new()
var _steering_type_option := OptionButton.new()
var _map_style_option := OptionButton.new()
var _volume_slider := HSlider.new()
var _debug_path_checkbox := CheckBox.new()

var _back_button := Button.new()
var _home_button := Button.new()
var _debug_word_option := OptionButton.new()
var _debug_phoneme_option := OptionButton.new()
var _debug_play_button := Button.new()


func _ready() -> void:
	layer = 1
	_build_hud()


func _build_hud() -> void:
	_back_button.name = "BackButton"
	_back_button.text = "Back"
	_back_button.anchor_left = 0.02
	_back_button.anchor_top = 0.02
	_back_button.offset_right = 96
	_back_button.offset_bottom = 36
	_back_button.pressed.connect(func() -> void: emit_signal("home_requested"))
	add_child(_back_button)

	_status_label.anchor_left = 0.02
	_status_label.anchor_top = 0.03
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.text = "Loading reading mode..."
	add_child(_status_label)

	_word_display_root.anchor_left = 0.0
	_word_display_root.anchor_top = 0.03
	_word_display_root.anchor_right = 1.0
	_word_display_root.anchor_bottom = 0.18
	_word_display_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word_display_root.clip_contents = false
	add_child(_word_display_root)

	_spelling_word_label.anchor_left = 0.5
	_spelling_word_label.anchor_top = 0.0
	_spelling_word_label.anchor_right = 0.5
	_spelling_word_label.offset_left = -420
	_spelling_word_label.offset_right = 420
	_spelling_word_label.offset_top = 0
	_spelling_word_label.offset_bottom = 72
	_spelling_word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spelling_word_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spelling_word_label.bbcode_enabled = true
	_spelling_word_label.fit_content = true
	_spelling_word_label.scroll_active = false
	_spelling_word_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_spelling_word_label.add_theme_font_size_override("normal_font_size", 34)
	_spelling_word_label.add_theme_color_override("default_color", Color.BLACK)
	_word_display_root.add_child(_spelling_word_label)

	_whole_word_strip.anchor_left = 0.5
	_whole_word_strip.anchor_top = 0.0
	_whole_word_strip.anchor_right = 0.5
	_whole_word_strip.offset_left = -960
	_whole_word_strip.offset_right = 960
	_whole_word_strip.offset_top = 0
	_whole_word_strip.offset_bottom = 72
	_whole_word_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whole_word_strip.clip_contents = false
	_whole_word_strip.visible = false
	_word_display_root.add_child(_whole_word_strip)

	_phoneme_label.anchor_left = 0.5
	_phoneme_label.anchor_top = 0.9
	_phoneme_label.anchor_right = 0.5
	_phoneme_label.offset_left = -160
	_phoneme_label.offset_right = 160
	_phoneme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phoneme_label.add_theme_font_size_override("font_size", 28)
	_phoneme_label.add_theme_color_override("font_color", Color.BLACK)
	add_child(_phoneme_label)

	_help_label.anchor_left = 0.02
	_help_label.anchor_bottom = 0.98
	_help_label.anchor_top = 0.88
	_help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help_label.add_theme_font_size_override("font_size", 18)
	_help_label.text = "Up/Down: switch lanes   Esc: options"
	add_child(_help_label)

	_feedback_label.anchor_left = 0.5
	_feedback_label.anchor_top = 0.18
	_feedback_label.anchor_right = 0.5
	_feedback_label.offset_left = -180
	_feedback_label.offset_right = 180
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 24)
	add_child(_feedback_label)

	_options_panel.anchor_left = 0.5
	_options_panel.anchor_top = 0.3
	_options_panel.anchor_right = 0.5
	_options_panel.anchor_bottom = 0.3
	_options_panel.offset_left = -210
	_options_panel.offset_top = -140
	_options_panel.offset_right = 210
	_options_panel.offset_bottom = 260
	_options_panel.visible = false
	add_child(_options_panel)

	var options_margin := MarginContainer.new()
	options_margin.add_theme_constant_override("margin_left", 18)
	options_margin.add_theme_constant_override("margin_top", 18)
	options_margin.add_theme_constant_override("margin_right", 18)
	options_margin.add_theme_constant_override("margin_bottom", 18)
	_options_panel.add_child(options_margin)

	var options_layout := VBoxContainer.new()
	options_layout.add_theme_constant_override("separation", 12)
	options_margin.add_child(options_layout)

	var title := Label.new()
	title.text = "Options"
	title.add_theme_font_size_override("font_size", 28)
	options_layout.add_child(title)

	options_layout.add_child(_make_row("Controls", _control_mode_option))
	options_layout.add_child(_make_row("Steering", _steering_type_option))
	options_layout.add_child(_make_row("Map Style", _map_style_option))
	options_layout.add_child(_make_row("Word Group", _word_group_option))

	# Debug Audio Controls
	_debug_word_option.name = "DebugWordOption"
	_debug_phoneme_option.name = "DebugPhonemeOption"
	_debug_play_button.text = "Play"
	_debug_play_button.pressed.connect(_on_debug_play_pressed)

	options_layout.add_child(_make_row("Debug Word", _debug_word_option))
	options_layout.add_child(_make_row("Debug Phoneme", _debug_phoneme_option))
	options_layout.add_child(_make_row("Debug Play", _debug_play_button))

	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	options_layout.add_child(_make_row("Volume", _volume_slider))

	var path_checkbox := _debug_path_checkbox
	path_checkbox.text = "Show path debug"
	path_checkbox.set_pressed(true)
	path_checkbox.toggled.connect(_on_debug_path_toggled)
	options_layout.add_child(_make_row("Path Debug", path_checkbox))

	_home_button.name = "HomeButton"
	_home_button.text = "Home"
	_home_button.pressed.connect(func() -> void: emit_signal("home_requested"))
	options_layout.add_child(_home_button)

	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(func() -> void: emit_signal("resume_requested"))
	options_layout.add_child(resume_button)

	_control_mode_option.item_selected.connect(_on_control_mode_selected)
	_word_group_option.item_selected.connect(_on_word_group_selected)
	_steering_type_option.item_selected.connect(_on_steering_type_selected)
	_map_style_option.item_selected.connect(_on_map_style_selected)
	_volume_slider.value_changed.connect(_on_volume_changed)


func _make_row(label_text: String, control: Control) -> Control:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	row.add_child(control)
	return row


func configure(groups: Array[String], settings: Dictionary) -> void:
	_control_mode_option.clear()
	for mode_name in ReadingSettingsStore.CONTROL_MODES:
		_control_mode_option.add_item(mode_name.capitalize())

	_steering_type_option.clear()
	for steering_type in ReadingSettingsStore.STEERING_TYPES:
		_steering_type_option.add_item(steering_type.capitalize().replace("_", " "))

	_map_style_option.clear()
	for map_style in ReadingSettingsStore.MAP_STYLES:
		_map_style_option.add_item(map_style.capitalize())

	_word_group_option.clear()
	for group_name in groups:
		_word_group_option.add_item(group_name)

	_debug_word_option.clear()
	_debug_phoneme_option.clear()

	set_control_mode(str(settings.get("control_mode", ReadingSettingsStore.CONTROL_MODE_KEYBOARD)))
	var steering = str(
		settings.get("steering_type", ReadingSettingsStore.STEERING_TYPE_LANE_CHANGE)
	)
	set_steering_type(steering)
	var map = str(settings.get("map_style", ReadingSettingsStore.MAP_STYLE_CIRCULAR))
	set_map_style(map)
	set_word_group(str(settings.get("word_group", "sightwords")))
	set_volume(float(settings.get("master_volume", 0.8)))


func set_status(text_value: String) -> void:
	_status_label.text = text_value


func set_word(text_value: String) -> void:
	set_spelling_word(text_value, -1)


func set_spelling_word(text_value: String, current_letter_index: int = -1) -> void:
	_whole_word_strip.visible = false
	_spelling_word_label.visible = true
	var normalized_text := text_value.to_upper()
	if normalized_text.is_empty():
		_spelling_word_label.text = ""
		return
	var safe_letter_index := clampi(current_letter_index, -1, normalized_text.length() - 1)
	if safe_letter_index < 0 or safe_letter_index >= normalized_text.length():
		_spelling_word_label.text = normalized_text
		return
	var prefix := normalized_text.substr(0, safe_letter_index)
	var highlight := normalized_text.substr(safe_letter_index, 1)
	var suffix := normalized_text.substr(safe_letter_index + 1)
	_spelling_word_label.text = "%s[color=#ffd966][u]%s[/u][/color]%s" % [
		prefix,
		highlight,
		suffix,
	]


func set_word_sequence(entries: Array, current_index: int) -> void:
	_spelling_word_label.visible = false
	_whole_word_strip.visible = true
	_clear_whole_word_strip()

	var words: Array[String] = []
	for entry in entries:
		if entry is Dictionary:
			words.append(str((entry as Dictionary).get("text", "")).to_upper())
		else:
			words.append(str(entry).to_upper())

	if words.is_empty():
		return

	var highlighted_index := clampi(current_index, 0, words.size() - 1)
	var cursor_x := 0.0
	var word_label_data: Array[Dictionary] = []
	for word_index in range(words.size()):
		var word_text := words[word_index]
		var word_label := Label.new()
		word_label.text = word_text
		word_label.add_theme_font_size_override("font_size", 34)
		word_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.95, 0.45) if word_index == highlighted_index else Color.BLACK
		)
		_whole_word_strip.add_child(word_label)
		var word_width := _measure_label_width(word_label)
		word_label.position = Vector2(cursor_x, 0.0)
		word_label.size = Vector2(word_width, 48.0)
		word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		word_label_data.append({"label": word_label, "center": cursor_x + word_width * 0.5, "width": word_width})
		cursor_x += word_width + 24.0

	var screen_center_x := get_viewport_rect().size.x * 0.5
	var highlighted_word := word_label_data[highlighted_index]
	var highlighted_center := float(highlighted_word.get("center", 0.0))
	_whole_word_strip.position = Vector2(screen_center_x - highlighted_center, 0.0)


func _clear_whole_word_strip() -> void:
	for child in _whole_word_strip.get_children():
		child.queue_free()
	_whole_word_word_labels.clear()


func _measure_label_width(label: Label) -> float:
	var font := label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := label.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 34
	return float(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)


func set_phoneme(text_value: String) -> void:
	if text_value.is_empty():
		_phoneme_label.text = ""
	else:
		_phoneme_label.text = "Phoneme: %s" % text_value


func set_help(text_value: String) -> void:
	_help_label.text = text_value


func set_debug_audio_options(words: Array[String], phonemes: Array[String]) -> void:
	_debug_word_option.clear()
	for w in words:
		_debug_word_option.add_item(str(w))

	_debug_phoneme_option.clear()
	for p in phonemes:
		_debug_phoneme_option.add_item(str(p))


func _on_debug_play_pressed() -> void:
	var selected_word = ""
	if _debug_word_option.get_selected_id() >= 0 and _debug_word_option.item_count > 0:
		selected_word = _debug_word_option.get_item_text(_debug_word_option.get_selected_id())
	var selected_phoneme = ""
	if _debug_phoneme_option.get_selected_id() >= 0 and _debug_phoneme_option.item_count > 0:
		selected_phoneme = _debug_phoneme_option.get_item_text(
			_debug_phoneme_option.get_selected_id()
		)
	emit_signal("play_debug_audio", selected_word, selected_phoneme)


func flash_feedback(text_value: String, color: Color = Color(1.0, 1.0, 1.0)) -> void:
	_feedback_label.modulate = color
	_feedback_label.text = text_value
	var tween := create_tween()
	_feedback_label.modulate.a = 1.0
	tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.9)


func show_options() -> void:
	_options_panel.visible = true


func hide_options() -> void:
	_options_panel.visible = false


func is_options_open() -> bool:
	return _options_panel.visible


func get_home_button() -> Button:
	return _back_button


func set_control_mode(mode_name: String) -> void:
	var index := ReadingSettingsStore.CONTROL_MODES.find(mode_name)
	if index >= 0:
		_control_mode_option.select(index)


func set_steering_type(steering_type: String) -> void:
	var index := ReadingSettingsStore.STEERING_TYPES.find(steering_type)
	if index >= 0:
		_steering_type_option.select(index)


func set_map_style(map_style: String) -> void:
	var index := ReadingSettingsStore.MAP_STYLES.find(map_style)
	if index >= 0:
		_map_style_option.select(index)


func set_word_group(group_name: String) -> void:
	for index in range(_word_group_option.item_count):
		if _word_group_option.get_item_text(index) == group_name:
			_word_group_option.select(index)
			return


func set_volume(volume: float) -> void:
	_volume_slider.value = clampf(volume, 0.0, 1.0)


func set_debug_path(enabled: bool) -> void:
	_debug_path_checkbox.set_pressed(enabled)


func _on_control_mode_selected(index: int) -> void:
	if index >= 0 and index < ReadingSettingsStore.CONTROL_MODES.size():
		emit_signal("control_mode_changed", ReadingSettingsStore.CONTROL_MODES[index])


func _on_steering_type_selected(index: int) -> void:
	if index >= 0 and index < ReadingSettingsStore.STEERING_TYPES.size():
		emit_signal("steering_type_changed", ReadingSettingsStore.STEERING_TYPES[index])


func _on_map_style_selected(index: int) -> void:
	if index >= 0 and index < ReadingSettingsStore.MAP_STYLES.size():
		emit_signal("map_style_changed", ReadingSettingsStore.MAP_STYLES[index])


func _on_debug_path_toggled(enabled: bool) -> void:
	emit_signal("debug_path_toggled", enabled)


func _on_word_group_selected(index: int) -> void:
	if index >= 0:
		emit_signal("word_group_changed", _word_group_option.get_item_text(index))


func _on_volume_changed(value: float) -> void:
	emit_signal("volume_changed", value)
