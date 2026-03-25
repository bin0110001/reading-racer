class_name LevelSelect
extends Control

var settings_store := ReadingSettingsStore.new()
var content_loader := ReadingContentLoader.new()
var selected_group: String = ""
var level_buttons: Array[Button] = []

@onready var grid_container: GridContainer = $Panel/VBoxContainer/GridContainer
@onready var start_button: Button = $Panel/VBoxContainer/StartButton
@onready var config_button: Button = $Panel/VBoxContainer/ConfigButton
@onready var config_page: Control = get_node_or_null("ConfigPage")
@onready var steering_option: OptionButton = get_node_or_null(
	"ConfigPage/VBoxContainer/OptionsContainer/SteeringOption"
)
@onready var map_option: OptionButton = get_node_or_null(
	"ConfigPage/VBoxContainer/OptionsContainer/MapOption"
)
@onready var holiday_mode_option: OptionButton = get_node_or_null(
	"ConfigPage/VBoxContainer/OptionsContainer/HolidayModeOption"
)
@onready var holiday_name_option: OptionButton = get_node_or_null(
	"ConfigPage/VBoxContainer/OptionsContainer/HolidayNameOption"
)
@onready var save_button: Button = get_node_or_null("ConfigPage/VBoxContainer/SaveButton")
@onready var cancel_button: Button = get_node_or_null("ConfigPage/VBoxContainer/CancelButton")


func _ready() -> void:
	_populate_level_grid()
	_populate_options()
	_load_settings()
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if config_button:
		config_button.pressed.connect(_on_config_button_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if config_page:
		config_page.visible = false


func _populate_level_grid() -> void:
	var groups = content_loader.list_word_groups()
	for group in groups:
		var button = Button.new()
		button.text = group.capitalize()
		button.custom_minimum_size = Vector2(200, 150)
		button.pressed.connect(_on_level_selected.bind(group))
		grid_container.add_child(button)
		level_buttons.append(button)

	if not groups.is_empty():
		_on_level_selected(groups[0])


func _populate_options() -> void:
	if steering_option:
		steering_option.clear()
		for steering_type in ReadingSettingsStore.STEERING_TYPES:
			var display = steering_type.capitalize().replace("_", " ")
			steering_option.add_item(display)

	if map_option:
		map_option.clear()
		for map_style in ReadingSettingsStore.MAP_STYLES:
			map_option.add_item(map_style.capitalize())

	if holiday_mode_option:
		holiday_mode_option.clear()
		for mode in ReadingSettingsStore.HOLIDAY_MODES:
			holiday_mode_option.add_item(mode.capitalize())

	if holiday_name_option:
		holiday_name_option.clear()
		for holiday in ReadingSettingsStore.HOLIDAY_OPTIONS:
			holiday_name_option.add_item(holiday.capitalize())


func _load_settings() -> void:
	var settings = settings_store.load_settings()

	var steering_index = ReadingSettingsStore.STEERING_TYPES.find(
		settings.get("steering_type", ReadingSettingsStore.STEERING_TYPE_LANE_CHANGE)
	)
	if steering_index >= 0 and steering_option:
		steering_option.select(steering_index)

	var map_index = ReadingSettingsStore.MAP_STYLES.find(
		settings.get("map_style", ReadingSettingsStore.MAP_STYLE_CIRCULAR)
	)
	if map_index >= 0 and map_option:
		map_option.select(map_index)

	var word_group = settings.get("word_group", "sightwords")
	_on_level_selected(word_group)

	var holiday_mode_index = ReadingSettingsStore.HOLIDAY_MODES.find(
		settings.get("holiday_mode", ReadingSettingsStore.HOLIDAY_MODE_AUTO)
	)
	if holiday_mode_index >= 0 and holiday_mode_option:
		holiday_mode_option.select(holiday_mode_index)

	var holiday_name_index = ReadingSettingsStore.HOLIDAY_OPTIONS.find(
		settings.get("holiday_name", ReadingSettingsStore.HOLIDAY_NONE)
	)
	if holiday_name_index >= 0 and holiday_name_option:
		holiday_name_option.select(holiday_name_index)


func _on_level_selected(group: String) -> void:
	selected_group = group
	for button in level_buttons:
		var is_selected = button.text.to_lower() == group
		button.modulate = Color(1, 1, 1) if is_selected else Color(0.5, 0.5, 0.5)


func _on_start_pressed() -> void:
	var settings = settings_store.load_settings()
	settings["word_group"] = selected_group
	if steering_option and steering_option.selected >= 0:
		settings["steering_type"] = ReadingSettingsStore.STEERING_TYPES[steering_option.selected]
	if map_option and map_option.selected >= 0:
		settings["map_style"] = ReadingSettingsStore.MAP_STYLES[map_option.selected]
	settings_store.save_settings(settings)

	get_tree().change_scene_to_file("res://scenes/reading_mode.tscn")


func _on_config_button_pressed() -> void:
	if config_page:
		$Panel.visible = false
		config_page.visible = true


func _on_save_pressed() -> void:
	var settings = settings_store.load_settings()
	settings["holiday_mode"] = ReadingSettingsStore.HOLIDAY_MODES[holiday_mode_option.selected]
	settings["holiday_name"] = ReadingSettingsStore.HOLIDAY_OPTIONS[holiday_name_option.selected]
	settings["steering_type"] = ReadingSettingsStore.STEERING_TYPES[steering_option.selected]
	settings["map_style"] = ReadingSettingsStore.MAP_STYLES[map_option.selected]
	settings_store.save_settings(settings)
	if config_page:
		config_page.visible = false
		$Panel.visible = true


func _on_cancel_pressed() -> void:
	if config_page:
		config_page.visible = false
		$Panel.visible = true
