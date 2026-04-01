class_name LevelSelect
extends Control

const ReadingSettingsStoreScript = preload("res://scripts/reading/settings_store.gd")
const ReadingContentLoaderScript = preload("res://scripts/reading/content_loader.gd")
const PlayerVehicleLibraryScript = preload("res://scripts/reading/player_vehicle_library.gd")
const POLYGON_ICON_PREFABS_BASE := "res://Assets/PolygonIcons/Prefabs/"
const ICON_PREFAB_PLAY := POLYGON_ICON_PREFABS_BASE + "SM_Icon_Play_01.prefab"
const ICON_PREFAB_SETTINGS := POLYGON_ICON_PREFABS_BASE + "SM_Icon_Settings_01.prefab"
const ICON_PREFAB_VEHICLE := POLYGON_ICON_PREFABS_BASE + "SM_Icon_Car_01.prefab"
const ICON_SVG_LANE_SWITCH := "res://sprites/Swipe.svg"
const ICON_SVG_SMOOTH_STEERING := "res://sprites/Tilt.svg"

var settings_store := ReadingSettingsStoreScript.new()
var content_loader := ReadingContentLoaderScript.new()
var selected_group: String = ""
var level_buttons: Array[Button] = []
var selected_level_button: Button = null
var vehicle_catalog: Array[Dictionary] = []
var selected_vehicle_id: String = PlayerVehicleLibraryScript.DEFAULT_VEHICLE_ID
var selected_vehicle_color: Color = PlayerVehicleLibraryScript.get_default_paint_color()
var selected_vehicle_decals: Array = []

var vehicle_option := OptionButton.new()
var vehicle_color_picker := ColorPickerButton.new()
var vehicle_name_label := Label.new()
var vehicle_preview_container := SubViewportContainer.new()
var vehicle_preview_viewport := SubViewport.new()
var vehicle_preview_root := Node3D.new()
var vehicle_preview_pivot := Node3D.new()
var vehicle_preview_instance: Node3D = null
var steering_button_group := ButtonGroup.new()
var lane_switch_button: Button = null
var smooth_steering_button: Button = null
var selected_steering_type: String = ReadingSettingsStore.STEERING_TYPE_LANE_CHANGE

@onready var main_vbox: VBoxContainer = $Panel/VBoxContainer
@onready var carousel_scroll: ScrollContainer = null
@onready var carousel_row: HBoxContainer = null
@onready var config_button: Button = $Panel/VBoxContainer/ConfigButton
@onready var config_page: Control = _find_node_by_name_token(self, "ConfigPage") as Control
@onready var config_page_content: Control = (
	_find_node_by_name_token(self, "ConfigPage#VBoxContainer") as Control
)
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
	_ensure_base_layout()
	_populate_level_grid()
	_populate_options()
	_load_settings()
	_build_steering_type_buttons()
	if config_button:
		config_button.pressed.connect(_on_config_button_pressed)
		config_button.text = "Settings"
		config_button.tooltip_text = "Settings"
	# Add a dedicated vehicle selection screen entry point from level select
	var vehicle_button := Button.new()
	vehicle_button.name = "VehicleSelectButton"
	vehicle_button.text = "Vehicle"
	vehicle_button.tooltip_text = "Vehicle"
	vehicle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_button.pressed.connect(_on_vehicle_button_pressed)
	main_vbox.add_child(vehicle_button)
	main_vbox.move_child(vehicle_button, 4)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if config_page:
		config_page.visible = false
	if config_page_content:
		config_page_content.visible = false
	set_process(true)


func _process(delta: float) -> void:
	if vehicle_preview_pivot == null:
		return
	vehicle_preview_pivot.rotate_y(delta * 0.45)


func _build_vehicle_customizer() -> void:
	var main_layout := main_vbox
	if main_layout == null:
		_ensure_base_layout()
		main_layout = main_vbox
	if main_layout == null:
		return
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
	vehicle_catalog = PlayerVehicleLibraryScript.list_vehicles()
	vehicle_option.clear()
	for vehicle in vehicle_catalog:
		vehicle_option.add_item(str(vehicle.get("name", "Vehicle")))


func _select_vehicle(vehicle_id: String) -> void:
	selected_vehicle_id = PlayerVehicleLibraryScript.resolve_vehicle_id(
		{PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_ID: vehicle_id}
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

	var vehicle_settings: Dictionary = PlayerVehicleLibraryScript.build_vehicle_settings(
		selected_vehicle_id, selected_vehicle_color
	)
	vehicle_preview_instance = PlayerVehicleLibraryScript.instantiate_vehicle_from_settings(
		vehicle_settings, PlayerVehicleLibraryScript.PREVIEW_MAX_DIMENSION
	)
	if vehicle_preview_instance == null:
		vehicle_name_label.text = "Preview unavailable"
		return

	vehicle_preview_pivot.add_child(vehicle_preview_instance)
	var selected_vehicle: Dictionary = PlayerVehicleLibraryScript.get_vehicle_by_id(
		selected_vehicle_id
	)
	vehicle_name_label.text = str(selected_vehicle.get("name", "Vehicle"))


func _apply_vehicle_settings(settings: Dictionary) -> void:
	var vehicle_settings: Dictionary = PlayerVehicleLibrary.build_vehicle_settings(
		selected_vehicle_id, selected_vehicle_color, selected_vehicle_decals
	)
	for key in vehicle_settings.keys():
		settings[key] = vehicle_settings[key]


func _populate_level_grid() -> void:
	var groups = content_loader.list_word_groups()
	for group in groups:
		var button = Button.new()
		button.text = _format_level_group_name(group)
		button.tooltip_text = "Start " + button.text
		button.custom_minimum_size = Vector2(340.0, 240.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.set_meta("group_id", group)
		_apply_level_button_style(button, false)
		button.pressed.connect(_on_level_button_pressed.bind(group))
		carousel_row.add_child(button)
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

	_set_selected_steering_type(
		str(settings.get("steering_type", ReadingSettingsStore.STEERING_TYPE_LANE_CHANGE))
	)

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

	selected_vehicle_id = PlayerVehicleLibrary.resolve_vehicle_id(settings)
	selected_vehicle_color = PlayerVehicleLibrary.resolve_paint_color(settings)
	selected_vehicle_decals = settings.get(PlayerVehicleLibrary.SETTING_KEY_VEHICLE_DECALS, [])

	_select_vehicle(selected_vehicle_id)
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
	selected_level_button = null
	for button in level_buttons:
		var button_group := str(button.get_meta("group_id", ""))
		var is_selected := button_group == group
		if is_selected:
			selected_level_button = button
		_apply_level_button_style(button, is_selected)

	if carousel_scroll and selected_level_button:
		carousel_scroll.call_deferred("ensure_control_visible", selected_level_button)


func _on_level_button_pressed(group: String) -> void:
	_on_level_selected(group)
	_start_selected_level()


func _build_steering_type_buttons() -> void:
	var steering_row := HBoxContainer.new()
	steering_row.name = "SteeringTypeButtons"
	steering_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steering_row.add_theme_constant_override("separation", 12)

	lane_switch_button = Button.new()
	lane_switch_button.name = "LaneSwitchButton"
	lane_switch_button.toggle_mode = true
	lane_switch_button.button_group = steering_button_group
	lane_switch_button.custom_minimum_size = Vector2(180.0, 180.0)
	lane_switch_button.focus_mode = Control.FOCUS_NONE
	_apply_menu_icon(lane_switch_button, _load_svg_icon_texture(ICON_SVG_LANE_SWITCH))
	lane_switch_button.text = ""
	lane_switch_button.tooltip_text = "Lane switch"
	lane_switch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane_switch_button.pressed.connect(_on_lane_switch_button_pressed)
	steering_row.add_child(lane_switch_button)

	smooth_steering_button = Button.new()
	smooth_steering_button.name = "SmoothSteeringButton"
	smooth_steering_button.toggle_mode = true
	smooth_steering_button.button_group = steering_button_group
	smooth_steering_button.custom_minimum_size = Vector2(180.0, 180.0)
	smooth_steering_button.focus_mode = Control.FOCUS_NONE
	_apply_menu_icon(smooth_steering_button, _load_svg_icon_texture(ICON_SVG_SMOOTH_STEERING))
	smooth_steering_button.text = ""
	smooth_steering_button.tooltip_text = "Smooth / tilt"
	smooth_steering_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smooth_steering_button.pressed.connect(_on_smooth_steering_button_pressed)
	steering_row.add_child(smooth_steering_button)

	main_vbox.add_child(steering_row)
	main_vbox.move_child(steering_row, 3)
	_update_steering_button_states()


func _set_selected_steering_type(steering_type: String) -> void:
	if not ReadingSettingsStore.STEERING_TYPES.has(steering_type):
		steering_type = ReadingSettingsStore.STEERING_TYPE_LANE_CHANGE
	selected_steering_type = steering_type
	if steering_option:
		var steering_index := ReadingSettingsStore.STEERING_TYPES.find(steering_type)
		if steering_index >= 0:
			steering_option.select(steering_index)
	_update_steering_button_states()


func _get_selected_steering_type() -> String:
	if steering_option and steering_option.selected >= 0:
		return ReadingSettingsStore.STEERING_TYPES[steering_option.selected]
	return selected_steering_type


func _start_selected_level() -> void:
	if selected_group.is_empty() and not level_buttons.is_empty():
		var fallback_button := level_buttons[0]
		selected_group = str(fallback_button.get_meta("group_id", ""))

	if selected_group.is_empty():
		return

	var settings = settings_store.load_settings()
	settings["word_group"] = selected_group
	settings["steering_type"] = _get_selected_steering_type()
	if map_option and map_option.selected >= 0:
		settings["map_style"] = ReadingSettingsStore.MAP_STYLES[map_option.selected]
	_apply_vehicle_settings(settings)
	settings_store.save_settings(settings)

	get_tree().change_scene_to_file("res://scenes/reading_mode.tscn")


func _on_start_pressed() -> void:
	_start_selected_level()


func _on_config_button_pressed() -> void:
	if config_page:
		var content_panel := _get_main_content_container()
		if content_panel:
			content_panel.visible = false
		config_page.visible = true
	if config_page_content:
		config_page_content.visible = true


func _set_config_page_visible(show_config_page: bool) -> void:
	if config_page:
		config_page.visible = show_config_page
	if config_page_content:
		config_page_content.visible = show_config_page
	var content_panel := _get_main_content_container()
	if content_panel:
		content_panel.visible = not show_config_page


func _on_vehicle_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/vehicle_select.tscn")


func _on_save_pressed() -> void:
	var settings = settings_store.load_settings()
	settings["holiday_mode"] = ReadingSettingsStore.HOLIDAY_MODES[holiday_mode_option.selected]
	settings["holiday_name"] = ReadingSettingsStore.HOLIDAY_OPTIONS[holiday_name_option.selected]
	settings["steering_type"] = _get_selected_steering_type()
	settings["map_style"] = ReadingSettingsStore.MAP_STYLES[map_option.selected]
	_apply_vehicle_settings(settings)
	settings_store.save_settings(settings)
	_set_config_page_visible(false)


func _on_cancel_pressed() -> void:
	_set_config_page_visible(false)


func _on_lane_switch_button_pressed() -> void:
	_set_selected_steering_type(ReadingSettingsStore.STEERING_TYPE_LANE_CHANGE)


func _on_smooth_steering_button_pressed() -> void:
	_set_selected_steering_type(ReadingSettingsStore.STEERING_TYPE_SMOOTH_STEERING)


func _update_steering_button_states() -> void:
	var lane_is_selected := selected_steering_type == ReadingSettingsStore.STEERING_TYPE_LANE_CHANGE
	var smooth_is_selected := (
		selected_steering_type == ReadingSettingsStore.STEERING_TYPE_SMOOTH_STEERING
	)
	_apply_steering_button_state(lane_switch_button, lane_is_selected)
	_apply_steering_button_state(smooth_steering_button, smooth_is_selected)


func _apply_steering_button_state(button: Button, is_selected: bool) -> void:
	if button == null:
		return
	button.button_pressed = is_selected
	button.self_modulate = (
		Color(1.0, 1.0, 1.0, 1.0) if is_selected else Color(0.82, 0.86, 0.92, 0.92)
	)

	var base_color := Color(0.14, 0.17, 0.22, 0.98)
	var selected_color := Color(0.20, 0.28, 0.40, 0.98)
	var border_color := Color(0.33, 0.39, 0.46, 1.0)
	var selected_border_color := Color(0.96, 0.82, 0.22, 1.0)
	var normal_style := _create_steering_button_stylebox(
		selected_color if is_selected else base_color,
		selected_border_color if is_selected else border_color,
		is_selected
	)
	var hover_style := _create_steering_button_stylebox(
		Color(0.26, 0.34, 0.48, 1.0) if is_selected else Color(0.19, 0.22, 0.28, 1.0),
		selected_border_color if is_selected else Color(0.48, 0.54, 0.62, 1.0),
		is_selected
	)
	var pressed_style := _create_steering_button_stylebox(
		Color(0.24, 0.30, 0.44, 1.0) if is_selected else Color(0.16, 0.18, 0.23, 1.0),
		selected_border_color if is_selected else Color(0.40, 0.46, 0.52, 1.0),
		is_selected
	)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", hover_style)


func _get_main_content_container() -> Control:
	if main_vbox != null:
		var parent := main_vbox.get_parent()
		if parent is Control:
			return parent as Control
	if has_node("Panel"):
		return $Panel
	return null


func _ensure_base_layout() -> void:
	if main_vbox != null and carousel_scroll != null and carousel_row != null:
		return

	var panel := get_node_or_null("Panel") as Panel
	if panel == null:
		return

	if main_vbox == null:
		main_vbox = panel.get_node_or_null("VBoxContainer") as VBoxContainer
		if main_vbox == null:
			var fallback_scroll := get_node_or_null("Panel/ContentScroll") as ScrollContainer
			if fallback_scroll == null:
				fallback_scroll = ScrollContainer.new()
				fallback_scroll.name = "ContentScroll"
				panel.add_child(fallback_scroll)
			main_vbox = fallback_scroll.get_node_or_null("VBoxContainer") as VBoxContainer
		if main_vbox == null:
			main_vbox = VBoxContainer.new()
			main_vbox.name = "VBoxContainer"
			panel.add_child(main_vbox)

	if carousel_scroll == null:
		carousel_scroll = main_vbox.get_node_or_null("LevelCarouselScroll") as ScrollContainer
		if carousel_scroll == null:
			carousel_scroll = ScrollContainer.new()
			carousel_scroll.name = "LevelCarouselScroll"
			main_vbox.add_child(carousel_scroll)

	if carousel_row == null:
		carousel_row = carousel_scroll.get_node_or_null("LevelCarouselRow") as HBoxContainer
		if carousel_row == null:
			carousel_row = HBoxContainer.new()
			carousel_row.name = "LevelCarouselRow"
			carousel_scroll.add_child(carousel_row)


func _format_level_group_name(group: String) -> String:
	var parts := group.split("_", false)
	if parts.is_empty():
		return group.capitalize()

	var display_name := ""
	for part in parts:
		if display_name.is_empty():
			display_name = str(part).capitalize()
		else:
			display_name += " " + str(part).capitalize()
	return display_name


func _apply_level_button_style(button: Button, is_selected: bool) -> void:
	if button == null:
		return

	button.self_modulate = (
		Color(1.0, 1.0, 1.0, 1.0) if is_selected else Color(0.88, 0.91, 0.96, 0.94)
	)
	button.add_theme_font_size_override("font_size", 28)
	var normal_style := _create_level_button_stylebox(
		Color(0.15, 0.18, 0.23, 0.98) if not is_selected else Color(0.20, 0.28, 0.40, 0.98),
		Color(0.34, 0.40, 0.48, 1.0) if not is_selected else Color(0.96, 0.82, 0.22, 1.0),
		is_selected
	)
	var hover_style := _create_level_button_stylebox(
		Color(0.20, 0.24, 0.30, 1.0) if not is_selected else Color(0.26, 0.34, 0.48, 1.0),
		Color(0.48, 0.54, 0.62, 1.0) if not is_selected else Color(0.96, 0.82, 0.22, 1.0),
		is_selected
	)
	var pressed_style := _create_level_button_stylebox(
		Color(0.18, 0.20, 0.26, 1.0) if not is_selected else Color(0.24, 0.30, 0.44, 1.0),
		Color(0.42, 0.48, 0.56, 1.0) if not is_selected else Color(0.96, 0.82, 0.22, 1.0),
		is_selected
	)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", hover_style)


func _create_level_button_stylebox(
	background_color: Color, border_color: Color, is_selected: bool
) -> StyleBoxFlat:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = background_color
	stylebox.border_width_left = 4 if is_selected else 2
	stylebox.border_width_top = 4 if is_selected else 2
	stylebox.border_width_right = 4 if is_selected else 2
	stylebox.border_width_bottom = 4 if is_selected else 2
	stylebox.border_color = border_color
	stylebox.corner_radius_top_left = 30
	stylebox.corner_radius_top_right = 30
	stylebox.corner_radius_bottom_right = 30
	stylebox.corner_radius_bottom_left = 30
	stylebox.content_margin_left = 24
	stylebox.content_margin_top = 20
	stylebox.content_margin_right = 24
	stylebox.content_margin_bottom = 20
	return stylebox


func _create_steering_button_stylebox(
	background_color: Color, border_color: Color, is_selected: bool
) -> StyleBoxFlat:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = background_color
	stylebox.border_width_left = 4 if is_selected else 2
	stylebox.border_width_top = 4 if is_selected else 2
	stylebox.border_width_right = 4 if is_selected else 2
	stylebox.border_width_bottom = 4 if is_selected else 2
	stylebox.border_color = border_color
	stylebox.corner_radius_top_left = 18
	stylebox.corner_radius_top_right = 18
	stylebox.corner_radius_bottom_right = 18
	stylebox.corner_radius_bottom_left = 18
	stylebox.content_margin_left = 12
	stylebox.content_margin_top = 12
	stylebox.content_margin_right = 12
	stylebox.content_margin_bottom = 12
	return stylebox


func _apply_menu_icon(button: Button, icon_texture: Texture2D) -> void:
	if button == null:
		return
	button.icon = icon_texture
	button.custom_minimum_size = Vector2(120.0, 120.0)
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_NONE


func _load_svg_icon_texture(svg_path: String) -> Texture2D:
	var image := Image.load_from_file(svg_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _find_node_by_name_token(node: Node, token: String) -> Node:
	if node.name.find(token) >= 0:
		return node
	for child in node.get_children():
		if child is Node:
			var found = _find_node_by_name_token(child, token)
			if found != null:
				return found
	return null
