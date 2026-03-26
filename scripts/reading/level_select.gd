class_name LevelSelect
extends Control

const PlayerVehicleLibrary = preload("res://scripts/reading/player_vehicle_library.gd")

var settings_store := ReadingSettingsStore.new()
var content_loader := ReadingContentLoader.new()
var selected_group: String = ""
var level_buttons: Array[Button] = []
var vehicle_catalog: Array[Dictionary] = []
var selected_vehicle_id := PlayerVehicleLibrary.DEFAULT_VEHICLE_ID
var selected_vehicle_color := PlayerVehicleLibrary.get_default_paint_color()

var vehicle_option := OptionButton.new()
var vehicle_color_picker := ColorPickerButton.new()
var vehicle_name_label := Label.new()
var vehicle_preview_container := SubViewportContainer.new()
var vehicle_preview_viewport := SubViewport.new()
var vehicle_preview_root := Node3D.new()
var vehicle_preview_pivot := Node3D.new()
var vehicle_preview_instance: Node3D = null

@onready var grid_container: GridContainer = $Panel/VBoxContainer/GridContainer
@onready var start_button: Button = $Panel/VBoxContainer/StartButton
@onready var config_button: Button = $Panel/VBoxContainer/ConfigButton
@onready var config_page: Control = _find_node_by_name_token(self, "ConfigPage") as Control
@onready
var steering_option: OptionButton = _find_node_by_name_token(self, "SteeringOption") as OptionButton
@onready var map_option: OptionButton = _find_node_by_name_token(self, "MapOption") as OptionButton
@onready var holiday_mode_option: OptionButton = (
	_find_node_by_name_token(self, "HolidayModeOption") as OptionButton
)
@onready var holiday_name_option: OptionButton = (
	_find_node_by_name_token(self, "HolidayNameOption") as OptionButton
)
@onready var save_button: Button = _find_node_by_name_token(self, "SaveButton") as Button
@onready var cancel_button: Button = _find_node_by_name_token(self, "CancelButton") as Button


func _ready() -> void:
	_build_vehicle_customizer()
	_populate_vehicle_options()
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
	set_process(true)


func _process(delta: float) -> void:
	if vehicle_preview_pivot == null:
		return
	vehicle_preview_pivot.rotate_y(delta * 0.45)


func _build_vehicle_customizer() -> void:
	var main_layout := $Panel/VBoxContainer
	var customizer_row := HBoxContainer.new()
	customizer_row.name = "VehicleCustomizer"
	customizer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	customizer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	customizer_row.add_theme_constant_override("separation", 24)
	main_layout.add_child(customizer_row)
	main_layout.move_child(customizer_row, 1)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(420, 280)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	customizer_row.add_child(preview_panel)

	vehicle_preview_container.stretch = true
	vehicle_preview_container.custom_minimum_size = Vector2(420, 280)
	preview_panel.add_child(vehicle_preview_container)

	vehicle_preview_viewport.size = Vector2i(960, 720)
	vehicle_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vehicle_preview_viewport.msaa_3d = Viewport.MSAA_4X
	vehicle_preview_container.add_child(vehicle_preview_viewport)

	vehicle_preview_viewport.add_child(vehicle_preview_root)
	vehicle_preview_root.add_child(vehicle_preview_pivot)

	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08, 0.1, 0.13)
	vehicle_preview_root.add_child(environment)

	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(10.0, 10.0)
	floor_mesh.mesh = floor_plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.19, 0.21, 0.25)
	floor_material.roughness = 1.0
	floor_mesh.material_override = floor_material
	floor_mesh.position = Vector3(0.0, 0.0, 0.0)
	vehicle_preview_root.add_child(floor_mesh)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-40.0, 50.0, 0.0)
	key_light.light_energy = 1.8
	vehicle_preview_root.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.5, 2.0, 2.5)
	fill_light.light_energy = 0.9
	vehicle_preview_root.add_child(fill_light)

	var preview_camera := Camera3D.new()
	preview_camera.current = true
	preview_camera.position = Vector3(0.0, 2.1, 7.2)
	vehicle_preview_root.add_child(preview_camera)
	preview_camera.look_at_from_position(
		preview_camera.position, Vector3(0.0, 1.1, 0.0), Vector3.UP
	)

	var controls_panel := VBoxContainer.new()
	controls_panel.custom_minimum_size = Vector2(280, 0)
	controls_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_panel.add_theme_constant_override("separation", 12)
	customizer_row.add_child(controls_panel)

	var header := Label.new()
	header.text = "Choose Your Ride"
	header.add_theme_font_size_override("font_size", 26)
	controls_panel.add_child(header)

	vehicle_name_label.add_theme_font_size_override("font_size", 18)
	vehicle_name_label.text = "Preview"
	controls_panel.add_child(vehicle_name_label)

	var vehicle_label := Label.new()
	vehicle_label.text = "Vehicle"
	controls_panel.add_child(vehicle_label)

	vehicle_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_option.item_selected.connect(_on_vehicle_selected)
	controls_panel.add_child(vehicle_option)

	var color_label := Label.new()
	color_label.text = "Paint"
	controls_panel.add_child(color_label)

	vehicle_color_picker.color = selected_vehicle_color
	vehicle_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_color_picker.color_changed.connect(_on_vehicle_color_changed)
	controls_panel.add_child(vehicle_color_picker)

	var help_text := Label.new()
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.text = "Your selected car and paint are saved and reused when you start a reading level."
	controls_panel.add_child(help_text)


func _populate_vehicle_options() -> void:
	vehicle_catalog = PlayerVehicleLibrary.list_vehicles()
	vehicle_option.clear()
	for vehicle in vehicle_catalog:
		vehicle_option.add_item(str(vehicle.get("name", "Vehicle")))


func _select_vehicle(vehicle_id: String) -> void:
	selected_vehicle_id = PlayerVehicleLibrary.resolve_vehicle_id(
		{PlayerVehicleLibrary.SETTING_KEY_VEHICLE_ID: vehicle_id}
	)
	for index in range(vehicle_catalog.size()):
		var vehicle := vehicle_catalog[index]
		if str(vehicle.get("id", "")) == selected_vehicle_id:
			vehicle_option.select(index)
			break


func _refresh_vehicle_preview() -> void:
	if is_instance_valid(vehicle_preview_instance):
		vehicle_preview_instance.queue_free()
		vehicle_preview_instance = null

	var vehicle_settings := PlayerVehicleLibrary.build_vehicle_settings(
		selected_vehicle_id, selected_vehicle_color
	)
	vehicle_preview_instance = PlayerVehicleLibrary.instantiate_vehicle_from_settings(
		vehicle_settings, PlayerVehicleLibrary.PREVIEW_MAX_DIMENSION
	)
	if vehicle_preview_instance == null:
		vehicle_name_label.text = "Preview unavailable"
		return

	vehicle_preview_pivot.add_child(vehicle_preview_instance)
	var selected_vehicle := PlayerVehicleLibrary.get_vehicle_by_id(selected_vehicle_id)
	vehicle_name_label.text = str(selected_vehicle.get("name", "Vehicle"))


func _apply_vehicle_settings(settings: Dictionary) -> void:
	var vehicle_settings := PlayerVehicleLibrary.build_vehicle_settings(
		selected_vehicle_id, selected_vehicle_color
	)
	for key in vehicle_settings.keys():
		settings[key] = vehicle_settings[key]


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

	selected_vehicle_color = PlayerVehicleLibrary.resolve_paint_color(settings)
	vehicle_color_picker.color = selected_vehicle_color
	_select_vehicle(str(settings.get(PlayerVehicleLibrary.SETTING_KEY_VEHICLE_ID, "")))
	_refresh_vehicle_preview()


func _on_vehicle_selected(index: int) -> void:
	if index < 0 or index >= vehicle_catalog.size():
		return
	selected_vehicle_id = str(
		vehicle_catalog[index].get("id", PlayerVehicleLibrary.DEFAULT_VEHICLE_ID)
	)
	_refresh_vehicle_preview()


func _on_vehicle_color_changed(color: Color) -> void:
	selected_vehicle_color = color
	_refresh_vehicle_preview()


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
	_apply_vehicle_settings(settings)
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
	_apply_vehicle_settings(settings)
	settings_store.save_settings(settings)
	if config_page:
		config_page.visible = false
		$Panel.visible = true


func _on_cancel_pressed() -> void:
	if config_page:
		config_page.visible = false
		$Panel.visible = true


func _find_node_by_name_token(node: Node, token: String) -> Node:
	if node.name.find(token) >= 0:
		return node
	for child in node.get_children():
		if child is Node:
			var found = _find_node_by_name_token(child, token)
			if found != null:
				return found
	return null
