class_name ReadingHUD
extends CanvasLayer

signal control_mode_changed(mode_name: String)
signal word_group_changed(group_name: String)
signal volume_changed(volume: float)
signal resume_requested

var _status_label := Label.new()
var _word_label := Label.new()
var _phoneme_label := Label.new()
var _help_label := Label.new()
var _feedback_label := Label.new()

var _options_panel := PanelContainer.new()
var _control_mode_option := OptionButton.new()
var _word_group_option := OptionButton.new()
var _volume_slider := HSlider.new()


func _ready() -> void:
	layer = 1
	_build_hud()


func _build_hud() -> void:
	_status_label.anchor_left = 0.02
	_status_label.anchor_top = 0.03
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.text = "Loading reading mode..."
	add_child(_status_label)

	_word_label.anchor_left = 0.5
	_word_label.anchor_top = 0.03
	_word_label.anchor_right = 0.5
	_word_label.offset_left = -180
	_word_label.offset_right = 180
	_word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word_label.add_theme_font_size_override("font_size", 34)
	add_child(_word_label)

	_phoneme_label.anchor_left = 0.5
	_phoneme_label.anchor_top = 0.9
	_phoneme_label.anchor_right = 0.5
	_phoneme_label.offset_left = -160
	_phoneme_label.offset_right = 160
	_phoneme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phoneme_label.add_theme_font_size_override("font_size", 28)
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
	_options_panel.anchor_top = 0.5
	_options_panel.anchor_right = 0.5
	_options_panel.anchor_bottom = 0.5
	_options_panel.offset_left = -210
	_options_panel.offset_top = -140
	_options_panel.offset_right = 210
	_options_panel.offset_bottom = 140
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
	options_layout.add_child(_make_row("Word Group", _word_group_option))

	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	options_layout.add_child(_make_row("Volume", _volume_slider))

	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(func() -> void: emit_signal("resume_requested"))
	options_layout.add_child(resume_button)

	_control_mode_option.item_selected.connect(_on_control_mode_selected)
	_word_group_option.item_selected.connect(_on_word_group_selected)
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

	_word_group_option.clear()
	for group_name in groups:
		_word_group_option.add_item(group_name)

	set_control_mode(str(settings.get("control_mode", ReadingSettingsStore.CONTROL_MODE_KEYBOARD)))
	set_word_group(str(settings.get("word_group", "sightwords")))
	set_volume(float(settings.get("master_volume", 0.8)))


func set_status(text_value: String) -> void:
	_status_label.text = text_value


func set_word(text_value: String) -> void:
	_word_label.text = text_value.to_upper()


func set_phoneme(text_value: String) -> void:
	if text_value.is_empty():
		_phoneme_label.text = ""
	else:
		_phoneme_label.text = "Phoneme: %s" % text_value


func set_help(text_value: String) -> void:
	_help_label.text = text_value


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


func set_control_mode(mode_name: String) -> void:
	var index := ReadingSettingsStore.CONTROL_MODES.find(mode_name)
	if index >= 0:
		_control_mode_option.select(index)


func set_word_group(group_name: String) -> void:
	for index in range(_word_group_option.item_count):
		if _word_group_option.get_item_text(index) == group_name:
			_word_group_option.select(index)
			return


func set_volume(volume: float) -> void:
	_volume_slider.value = clampf(volume, 0.0, 1.0)


func _on_control_mode_selected(index: int) -> void:
	if index >= 0 and index < ReadingSettingsStore.CONTROL_MODES.size():
		emit_signal("control_mode_changed", ReadingSettingsStore.CONTROL_MODES[index])


func _on_word_group_selected(index: int) -> void:
	if index >= 0:
		emit_signal("word_group_changed", _word_group_option.get_item_text(index))


func _on_volume_changed(value: float) -> void:
	emit_signal("volume_changed", value)
