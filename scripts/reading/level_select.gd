class_name LevelSelect
extends Control

var settings_store := ReadingSettingsStore.new()
var content_loader := ReadingContentLoader.new()
var selected_group: String = ""
var level_buttons: Array[Button] = []

@onready var grid_container: GridContainer = $Panel/VBoxContainer/GridContainer
@onready var steering_option: OptionButton = $Panel/VBoxContainer/OptionsContainer/SteeringOption
@onready var map_option: OptionButton = $Panel/VBoxContainer/OptionsContainer/MapOption
@onready var start_button: Button = $Panel/VBoxContainer/StartButton


func _ready() -> void:
	_populate_level_grid()
	_populate_options()
	_load_settings()
	start_button.pressed.connect(_on_start_pressed)


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
	steering_option.clear()
	for steering_type in ReadingSettingsStore.STEERING_TYPES:
		var display = steering_type.capitalize().replace("_", " ")
		steering_option.add_item(display)

	map_option.clear()
	for map_style in ReadingSettingsStore.MAP_STYLES:
		map_option.add_item(map_style.capitalize())


func _load_settings() -> void:
	var settings = settings_store.load_settings()

	var steering_index = ReadingSettingsStore.STEERING_TYPES.find(
		settings.get("steering_type", ReadingSettingsStore.STEERING_TYPE_LANE_CHANGE)
	)
	if steering_index >= 0:
		steering_option.select(steering_index)

	var map_index = ReadingSettingsStore.MAP_STYLES.find(
		settings.get("map_style", ReadingSettingsStore.MAP_STYLE_CIRCULAR)
	)
	if map_index >= 0:
		map_option.select(map_index)

	var word_group = settings.get("word_group", "sightwords")
	_on_level_selected(word_group)


func _on_level_selected(group: String) -> void:
	selected_group = group
	for button in level_buttons:
		var is_selected = button.text.to_lower() == group
		button.modulate = Color(1, 1, 1) if is_selected else Color(0.5, 0.5, 0.5)


func _on_start_pressed() -> void:
	var settings = settings_store.load_settings()
	settings["word_group"] = selected_group
	settings["steering_type"] = ReadingSettingsStore.STEERING_TYPES[steering_option.selected]
	settings["map_style"] = ReadingSettingsStore.MAP_STYLES[map_option.selected]
	settings_store.save_settings(settings)

	get_tree().change_scene_to_file("res://scenes/reading_mode.tscn")
