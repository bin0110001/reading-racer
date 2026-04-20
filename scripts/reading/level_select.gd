class_name LevelSelect
extends Control
const ReadingSettingsStoreScript = preload("res://scripts/reading/settings_store.gd")
const ReadingContentLoaderScript = preload("res://scripts/reading/content_loader.gd")
const PlayerVehicleLibraryScript = preload("res://scripts/reading/player_vehicle_library.gd")
const MapDisplayManagerScript = preload("res://scripts/reading/systems/MapDisplayManager.gd")
const POLYGON_ICON_PREFABS_BASE := "res://Assets/PolygonIcons/Prefabs/"
const ICON_PREFAB_PLAY := POLYGON_ICON_PREFABS_BASE + "SM_Icon_Play_01.prefab"
const ICON_PREFAB_SETTINGS := POLYGON_ICON_PREFABS_BASE + "SM_Icon_Settings_01.prefab"
const ICON_PREFAB_VEHICLE := POLYGON_ICON_PREFABS_BASE + "SM_Icon_Car_01.prefab"
const ICON_SVG_LANE_SWITCH := "res://sprites/Swipe.svg"
const ICON_SVG_SMOOTH_STEERING := "res://sprites/Tilt.svg"
const PRONUNCIATION_MODE_EMOJI := "📖"
const LEVEL_OPTION_TYPE_GROUP := "group"
const LEVEL_OPTION_TYPE_MODE := "mode"
const LEVEL_MODE_PRONUNCIATION := "pronunciation"
const LEVEL_MODE_WORD_CHOICE := "word_choice"
const READ_MODE_START_REQUEST_META_KEY := "reading_mode_start_requested_ms"
const PRONUNCIATION_MODE_SCENE_PATH := "res://scenes/level_types/pronunciation_mode.tscn"
const WHOLE_WORD_MODE_SCENE_PATH := "res://scenes/level_types/whole_word_mode.tscn"
var settings_store = null
var content_loader = null
var map_preview_viewport: SubViewport = null
var map_preview_root: Node3D = null
var map_preview_camera: Camera3D = null
var map_preview_manager = null
var map_preview_generator = null
var map_preview_map_center: Vector3 = Vector3.ZERO
var map_preview_container: SubViewportContainer = null
var map_preview_texture_rect: TextureRect = null
var map_preview_base_position: Vector3 = Vector3.ZERO
var map_preview_drift_time: float = 0.0
var map_preview_drift_speed: float = 0.45
var map_preview_drift_radius: float = 2.0
var selected_group: String = ""
var level_buttons: Array[Button] = []
var level_option_buttons: Array[Button] = []
var mode_buttons: Array[Button] = []
var selected_level_button: Button = null
var grade_scroll: ScrollContainer = null
var grade_row: HBoxContainer = null
var final_row: HBoxContainer = null
var final_selection_label: Label = null
var final_start_button: Button = null
var selected_level_label: String = ""
var selected_reading_list: String = ""
var selected_mode: String = ""
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
@onready var config_page: Control = (
	LevelSelectHelpers._find_node_by_name_token(self, "ConfigPage") as Control
)
@onready var config_page_content: Control = (
	LevelSelectHelpers._find_node_by_name_token(self, "ConfigPage#VBoxContainer") as Control
)
@onready var steering_option: OptionButton = (
	LevelSelectHelpers._find_node_by_name_token(self, "SteeringOption") as OptionButton
)
@onready var map_option: OptionButton = (
	LevelSelectHelpers._find_node_by_name_token(self, "MapOption") as OptionButton
)
@onready var holiday_mode_option: OptionButton = (
	LevelSelectHelpers._find_node_by_name_token(self, "HolidayModeOption") as OptionButton
)
@onready var holiday_name_option: OptionButton = (
	LevelSelectHelpers._find_node_by_name_token(self, "HolidayNameOption") as OptionButton
)
@onready
var save_button: Button = LevelSelectHelpers._find_node_by_name_token(self, "SaveButton") as Button
@onready var cancel_button: Button = (
	LevelSelectHelpers._find_node_by_name_token(self, "CancelButton") as Button
)


func _ready() -> void:
	if settings_store == null:
		settings_store = ReadingSettingsStoreScript.new()
	if content_loader == null:
		content_loader = ReadingContentLoaderScript.new()
	_ensure_base_layout()
	_populate_level_grid()
	_populate_options()
	if (
		steering_option
		and not steering_option.item_selected.is_connected(_on_steering_option_selected)
	):
		steering_option.item_selected.connect(_on_steering_option_selected)
	if map_option and not map_option.item_selected.is_connected(_on_map_option_selected):
		map_option.item_selected.connect(_on_map_option_selected)
	_load_settings()
	_build_steering_type_buttons()
	_build_map_preview()
	if config_button:
		config_button.pressed.connect(_on_config_button_pressed)
		# Keep the existing gear icon settings path but hide explicit text label.
		config_button.text = ""
		config_button.tooltip_text = "Settings"
		config_button.visible = true
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if config_page:
		config_page.visible = false
	if config_page_content:
		config_page_content.visible = false
	# Main title branding
	var title_label = $Panel/VBoxContainer/Title as Label
	if title_label:
		title_label.text = "Read & Roll"
		var title_font = load("res://Assets/Fonts/squealer.embossed-regular.otf")
		if title_font is Font:
			title_label.add_theme_font_override("font", title_font)
			title_label.add_theme_font_size_override("font_size", 48)
	set_process(true)


func _process(delta: float) -> void:
	if vehicle_preview_pivot != null:
		vehicle_preview_pivot.rotate_y(delta * 0.45)
	if map_preview_camera != null:
		map_preview_drift_time += delta * map_preview_drift_speed
		var drift_x := sin(map_preview_drift_time) * map_preview_drift_radius
		var drift_z := cos(map_preview_drift_time * 0.8) * map_preview_drift_radius
		map_preview_camera.position = Vector3(
			map_preview_base_position.x + drift_x,
			map_preview_base_position.y,
			map_preview_base_position.z + drift_z,
		)
		map_preview_camera.look_at(Vector3(0, 0, 0), Vector3.UP)


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


func _build_map_preview() -> void:
	# Fullscreen background 3D map preview (under UI controls)
	map_preview_container = SubViewportContainer.new()
	map_preview_container.name = "MapPreviewBackground"
	map_preview_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_preview_container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	map_preview_container.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	map_preview_container.stretch = true
	map_preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_preview_container)
	move_child(map_preview_container, 0)
	map_preview_viewport = SubViewport.new()
	map_preview_viewport.size = Vector2i(960, 720)
	map_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	map_preview_viewport.msaa_3d = Viewport.MSAA_4X
	map_preview_container.add_child(map_preview_viewport)
	map_preview_root = Node3D.new()
	map_preview_viewport.add_child(map_preview_root)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.05, 0.08, 0.12)
	map_preview_root.add_child(environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	key_light.light_energy = 1.2
	map_preview_root.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-8.0, 6.0, 8.0)
	fill_light.light_energy = 0.5
	map_preview_root.add_child(fill_light)
	map_preview_camera = Camera3D.new()
	map_preview_camera.current = true
	map_preview_camera.fov = 48.0
	map_preview_root.add_child(map_preview_camera)
	# Default top-down view; will correct once layout is built
	map_preview_camera.position = Vector3(0.0, 20.0, 0.0)
	map_preview_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	# Build the actual map geometry if available
	_update_map_preview()


func _update_map_preview() -> void:
	if map_preview_manager == null:
		map_preview_manager = MapDisplayManager.new()
		map_preview_manager.set_nodes(map_preview_root, map_preview_root)
		# Limit preview streaming to a small window to avoid spawning thousands of track tiles at startup.
		map_preview_manager.stream_tiles_each_side = 8
		map_preview_manager.stream_tiles_ahead = 10
		map_preview_manager.stream_tiles_behind = 6
	if map_preview_generator == null:
		map_preview_generator = TrackGenerator.new()
	# Choose a sample word group for proto layout
	var group_name := ""
	var groups: Array[String] = content_loader.list_word_groups()
	if groups.size() > 0:
		group_name = str(groups[0])
	var word_entries := []
	if not group_name.is_empty():
		word_entries = _build_preview_word_entries(group_name)
	if word_entries.size() == 0:
		word_entries = [{"letters": ["a", "b", "c"]}]
	# Use selected map style if available
	var style := ReadingSettingsStore.MAP_STYLE_CIRCULAR
	var map_index_is_valid := false
	if map_option:
		var selected := map_option.selected
		map_index_is_valid = (selected >= 0 and selected < ReadingSettingsStore.MAP_STYLES.size())
		if map_index_is_valid:
			style = ReadingSettingsStore.MAP_STYLES[selected]
	var layout_config := {
		"path_style": style, "cell_world_length": 8.0, "checkpoint_count": 4, "start_slots": 8
	}
	var layout = map_preview_generator.generate_loop_layout(word_entries, layout_config)
	if layout == null or layout.size == Vector3i.ZERO:
		return
	# Measure tile size and center layout
	var road_sample := load(MapDisplayManagerScript.ROAD_MODEL_PATH) as PackedScene
	if road_sample != null:
		var road_instance = road_sample.instantiate() as Node3D
		if road_instance != null:
			map_preview_manager.measure_track_tile(road_instance)
			road_instance.queue_free()
	var tile_length: float = max(map_preview_manager.track_tile_length, 8.0)
	var tile_width: float = max(map_preview_manager.track_tile_width, 8.0)
	var grid_size: Vector3i = layout.size as Vector3i
	var origin_x: float = -float(grid_size.x) * tile_length * 0.5
	var origin_z: float = -float(grid_size.z) * tile_width * 0.5
	var origin: Vector3 = Vector3(origin_x, 0.0, origin_z)
	var layout_data = layout
	var layout_origin_value = origin
	var layout_tile_length_value = tile_length
	var layout_tile_width_value = tile_width
	map_preview_manager.set_layout_data(
		layout_data, layout_origin_value, layout_tile_length_value, layout_tile_width_value
	)
	map_preview_manager.update_visible_cells(Vector3.ZERO, 0.0)
	# position a top-down camera at a height that shows most of the track
	var grid_len_x: float = float(grid_size.x * grid_size.x)
	var grid_len_z: float = float(grid_size.z * grid_size.z)
	var diagonal: float = sqrt(grid_len_x + grid_len_z)
	var view_distance: float = clampf(diagonal * 0.55, 16.0, 100.0)
	var cam_height: float = max(10.0, view_distance * 0.45)
	var cam_dist: float = max(8.0, view_distance * 0.8)
	map_preview_base_position = Vector3(0.0, cam_height, -cam_dist)
	map_preview_camera.position = map_preview_base_position
	map_preview_camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	# Bake an overall center point for later use
	map_preview_map_center = Vector3(0, 0, 0)


func _on_map_option_selected(_index: int) -> void:
	_update_map_preview()


func _on_steering_option_selected(index: int) -> void:
	if index < 0 or index >= ReadingSettingsStore.STEERING_TYPES.size():
		return
	_set_selected_steering_type(ReadingSettingsStore.STEERING_TYPES[index])


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
	var vehicle_library := PlayerVehicleLibraryScript.new()
	if is_instance_valid(vehicle_preview_instance):
		vehicle_preview_instance.queue_free()
		vehicle_preview_instance = null
	var vehicle_settings: Dictionary = vehicle_library.build_vehicle_settings_instance(
		selected_vehicle_id, selected_vehicle_color
	)
	vehicle_preview_instance = vehicle_library.instantiate_vehicle_from_settings_instance(
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
	var vehicle_library := PlayerVehicleLibraryScript.new()
	var vehicle_settings: Dictionary = vehicle_library.build_vehicle_settings_instance(
		selected_vehicle_id, selected_vehicle_color, selected_vehicle_decals
	)
	for key in vehicle_settings.keys():
		settings[key] = vehicle_settings[key]


func _populate_level_grid() -> void:
	_populate_level_buttons()
	_refresh_mode_buttons()


func _populate_level_buttons() -> void:
	for child in carousel_row.get_children():
		child.queue_free()
	level_option_buttons.clear()
	level_buttons.clear()
	selected_level_button = null
	var level_entries: Array[Dictionary] = []
	(
		level_entries
		. append(
			{
				"label": "Tests",
				"group": "sightwords",
				"reading_list": "",
				"tooltip": "Practice with the test words.",
			}
		)
	)
	for reading_list in content_loader.list_word_reading_lists("can_cat"):
		var level_label := LevelSelectHelpers._format_level_group_name(reading_list)
		(
			level_entries
			. append(
				{
					"label": level_label,
					"group": "can_cat",
					"reading_list": reading_list,
					"tooltip": "Choose level %s." % level_label,
				}
			)
		)
	for level_index in range(level_entries.size()):
		var level_data: Dictionary = level_entries[level_index]
		var button := Button.new()
		button.text = str(level_data.get("label", ""))
		button.tooltip_text = str(level_data.get("tooltip", button.text))
		button.custom_minimum_size = Vector2(100.0, 100.0)
		button.size_flags_horizontal = Control.SIZE_FILL
		button.size_flags_vertical = Control.SIZE_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.set_meta("level_group", str(level_data.get("group", "")))
		button.set_meta("reading_list", str(level_data.get("reading_list", "")))
		button.set_meta("level_label", str(level_data.get("label", "")))
		var is_selected := _is_level_selected(level_data)
		LevelSelectHelpers._apply_grade_button_style(button, is_selected)
		button.pressed.connect(_on_level_selected.bind(level_data))
		carousel_row.add_child(button)
		level_buttons.append(button)
	level_option_buttons = level_buttons.duplicate()
	if selected_group.is_empty() and not level_entries.is_empty():
		_on_level_selected(level_entries[0])
	else:
		_refresh_mode_buttons()


func _refresh_mode_buttons() -> void:
	for child in grade_row.get_children():
		child.queue_free()
	mode_buttons.clear()
	if selected_group.is_empty():
		grade_scroll.visible = false
		_update_final_row()
		return
	grade_scroll.visible = true
	for mode_name in [LEVEL_MODE_PRONUNCIATION, LEVEL_MODE_WORD_CHOICE]:
		var button := Button.new()
		if mode_name == LEVEL_MODE_PRONUNCIATION:
			button.text = PRONUNCIATION_MODE_EMOJI
			button.add_theme_font_size_override("font_size", 72)
		else:
			button.text = _get_mode_label(mode_name)
		button.tooltip_text = _get_mode_tooltip(mode_name)
		button.custom_minimum_size = Vector2(360.0, 220.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.set_meta("mode", mode_name)
		LevelSelectHelpers._apply_grade_button_style(button, selected_mode == mode_name)
		button.pressed.connect(_on_mode_selected.bind(mode_name))
		grade_row.add_child(button)
		mode_buttons.append(button)
	_update_final_row()


func _is_level_selected(level_data: Dictionary) -> bool:
	return (
		selected_group == str(level_data.get("group", ""))
		and selected_reading_list == str(level_data.get("reading_list", ""))
		and selected_level_label == str(level_data.get("label", ""))
	)


func _on_level_selected(level_data: Dictionary) -> void:
	selected_group = str(level_data.get("group", ""))
	selected_reading_list = str(level_data.get("reading_list", ""))
	selected_level_label = str(level_data.get("label", ""))
	selected_mode = ""
	selected_level_button = null
	for button in level_buttons:
		var button_group := str(button.get_meta("level_group", ""))
		var button_reading_list := str(button.get_meta("reading_list", ""))
		var button_level_label := str(button.get_meta("level_label", ""))
		var is_selected := (
			button_group == selected_group
			and button_reading_list == selected_reading_list
			and button_level_label == selected_level_label
		)
		if is_selected:
			selected_level_button = button
		LevelSelectHelpers._apply_level_button_style(button, is_selected)
	_refresh_mode_buttons()
	_update_final_row()
	if carousel_scroll and selected_level_button:
		carousel_scroll.call_deferred("ensure_control_visible", selected_level_button)
	grade_scroll.visible = not selected_group.is_empty()


func _apply_mode_from_settings(settings: Dictionary) -> void:
	var reading_mode := str(
		settings.get("reading_mode", ReadingSettingsStore.READING_MODE_STANDARD)
	)
	if reading_mode == ReadingSettingsStore.READING_MODE_WORD_CHOICE:
		selected_mode = LEVEL_MODE_WORD_CHOICE
	else:
		selected_mode = LEVEL_MODE_PRONUNCIATION


func _on_mode_selected(mode_name: String) -> void:
	selected_mode = mode_name
	for button in mode_buttons:
		LevelSelectHelpers._apply_grade_button_style(
			button, str(button.get_meta("mode", "")) == selected_mode
		)
	_update_final_row()


func _update_final_row() -> void:
	if final_selection_label == null or final_start_button == null:
		return
	if selected_group.is_empty():
		final_selection_label.text = "Select a reading level from the row above."
		final_start_button.disabled = true
		return
	if selected_mode.is_empty():
		final_selection_label.text = (
			"Selected level: %s. Choose a mode below." % selected_level_label
		)
		final_start_button.disabled = true
		return
	var mode_label := _get_mode_label(selected_mode)
	final_selection_label.text = (
		"Starting %s on level %s with %s mode."
		% [selected_reading_list, selected_level_label, mode_label]
	)
	final_start_button.disabled = false


func _populate_options() -> void:
	_populate_vehicle_options()
	if steering_option:
		steering_option.clear()
		for steering_type in ReadingSettingsStore.STEERING_TYPES:
			steering_option.add_item(steering_type.replace("_", " ").capitalize())
	if map_option:
		map_option.clear()
		for map_style in ReadingSettingsStore.MAP_STYLES:
			map_option.add_item(map_style.capitalize())
	if holiday_mode_option:
		holiday_mode_option.clear()
		for holiday_mode in ReadingSettingsStore.HOLIDAY_MODES:
			holiday_mode_option.add_item(holiday_mode.capitalize())
	if holiday_name_option:
		holiday_name_option.clear()
		for holiday_name in ReadingSettingsStore.HOLIDAY_OPTIONS:
			holiday_name_option.add_item(holiday_name.capitalize())


func _load_settings() -> void:
	if settings_store != null:
		var settings: Dictionary = settings_store.load_settings()
		if settings.is_empty():
			return
		_apply_vehicle_settings(settings)
		_apply_mode_from_settings(settings)
		var default_steering := ReadingSettingsStore.STEERING_TYPE_LANE_CHANGE
		var steering_type := str(settings.get("steering_type", default_steering))
		_set_selected_steering_type(steering_type)
		if map_option:
			var map_style := str(settings.get("map_style", ReadingSettingsStore.MAP_STYLE_CIRCULAR))
			var map_index := ReadingSettingsStore.MAP_STYLES.find(map_style)
			if map_index >= 0:
				map_option.select(map_index)
		if holiday_mode_option:
			var holiday_mode := str(
				settings.get("holiday_mode", ReadingSettingsStore.HOLIDAY_MODE_AUTO)
			)
			var holiday_mode_index := ReadingSettingsStore.HOLIDAY_MODES.find(holiday_mode)
			if holiday_mode_index >= 0:
				holiday_mode_option.select(holiday_mode_index)
		if holiday_name_option:
			var holiday_name := str(settings.get("holiday_name", ReadingSettingsStore.HOLIDAY_NONE))
			var holiday_name_index := ReadingSettingsStore.HOLIDAY_OPTIONS.find(holiday_name)
			if holiday_name_index >= 0:
				holiday_name_option.select(holiday_name_index)


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


func _on_level_button_pressed(level_data: Dictionary) -> void:
	_on_level_selected(level_data)


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
	LevelSelectHelpers._apply_menu_icon(
		lane_switch_button, LevelSelectHelpers._load_svg_icon_texture(ICON_SVG_LANE_SWITCH)
	)
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
	LevelSelectHelpers._apply_menu_icon(
		smooth_steering_button, LevelSelectHelpers._load_svg_icon_texture(ICON_SVG_SMOOTH_STEERING)
	)
	smooth_steering_button.text = ""
	smooth_steering_button.tooltip_text = "Smooth / tilt"
	smooth_steering_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	smooth_steering_button.pressed.connect(_on_smooth_steering_button_pressed)
	steering_row.add_child(smooth_steering_button)
	var settings_button := Button.new()
	settings_button.name = "SteeringSettingsButton"
	settings_button.text = "⚙"
	settings_button.custom_minimum_size = Vector2(120.0, 120.0)
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.tooltip_text = "Settings"
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_button.pressed.connect(_on_config_button_pressed)
	settings_button.add_theme_font_size_override("font_size", 32)
	steering_row.add_child(settings_button)
	var vehicle_button := Button.new()
	vehicle_button.name = "SteeringVehicleButton"
	vehicle_button.text = "🚗"
	vehicle_button.custom_minimum_size = Vector2(120.0, 120.0)
	vehicle_button.focus_mode = Control.FOCUS_NONE
	vehicle_button.tooltip_text = "Vehicle"
	vehicle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_button.pressed.connect(_on_vehicle_button_pressed)
	vehicle_button.add_theme_font_size_override("font_size", 32)
	steering_row.add_child(vehicle_button)
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
	return selected_steering_type


func _start_selected_level() -> void:
	if selected_group.is_empty() and not level_buttons.is_empty():
		_on_level_selected(_get_level_data_from_button(level_buttons[0]))
	if selected_mode.is_empty() or selected_group.is_empty():
		return
	var settings = settings_store.load_settings()
	settings["word_group"] = selected_group
	settings["reading_mode"] = (
		ReadingSettingsStore.READING_MODE_WORD_CHOICE
		if selected_mode == LEVEL_MODE_WORD_CHOICE
		else ReadingSettingsStore.READING_MODE_STANDARD
	)
	settings["reading_scope_mode"] = (
		ReadingSettingsStore.READING_SCOPE_WORD_LIST
		if selected_mode == LEVEL_MODE_WORD_CHOICE
		else ReadingSettingsStore.READING_SCOPE_READING_LIST
	)
	settings["reading_scope_value"] = selected_reading_list
	settings["reading_scope_limit"] = 20
	settings["steering_type"] = _get_selected_steering_type()
	if map_option and map_option.selected >= 0:
		settings["map_style"] = ReadingSettingsStore.MAP_STYLES[map_option.selected]
	_apply_vehicle_settings(settings)
	settings_store.save_settings(settings)
	get_tree().root.set_meta(READ_MODE_START_REQUEST_META_KEY, Time.get_ticks_msec())
	get_tree().change_scene_to_file(_get_start_scene_path())


func _on_start_pressed() -> void:
	_start_selected_level()


func _get_level_data_from_button(button: Button) -> Dictionary:
	if button == null:
		return {}
	return {
		"group": str(button.get_meta("level_group", "")),
		"reading_list": str(button.get_meta("reading_list", "")),
		"label": str(button.get_meta("level_label", "")),
	}


func _get_start_scene_path() -> String:
	return PRONUNCIATION_MODE_SCENE_PATH


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
	if steering_option and steering_option.selected >= 0:
		var steering_index := steering_option.selected
		if steering_index < ReadingSettingsStore.STEERING_TYPES.size():
			selected_steering_type = ReadingSettingsStore.STEERING_TYPES[steering_index]
	if map_option and map_option.selected >= 0:
		var map_index := map_option.selected
		if map_index < ReadingSettingsStore.MAP_STYLES.size():
			settings["map_style"] = ReadingSettingsStore.MAP_STYLES[map_index]
	settings["holiday_mode"] = ReadingSettingsStore.HOLIDAY_MODES[holiday_mode_option.selected]
	settings["holiday_name"] = ReadingSettingsStore.HOLIDAY_OPTIONS[holiday_name_option.selected]
	settings["steering_type"] = _get_selected_steering_type()
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
	var normal_style := LevelSelectHelpers._create_steering_button_stylebox(
		selected_color if is_selected else base_color,
		selected_border_color if is_selected else border_color,
		is_selected
	)
	var hover_style := LevelSelectHelpers._create_steering_button_stylebox(
		Color(0.26, 0.34, 0.48, 1.0) if is_selected else Color(0.19, 0.22, 0.28, 1.0),
		selected_border_color if is_selected else Color(0.48, 0.54, 0.62, 1.0),
		is_selected
	)
	var pressed_style := LevelSelectHelpers._create_steering_button_stylebox(
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
	if grade_scroll == null:
		grade_scroll = main_vbox.get_node_or_null("GradeLevelScroll") as ScrollContainer
		if grade_scroll == null:
			grade_scroll = ScrollContainer.new()
			grade_scroll.name = "GradeLevelScroll"
			grade_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grade_scroll.size_flags_vertical = Control.SIZE_FILL
			grade_scroll.custom_minimum_size = Vector2(760, 140)
			grade_scroll.scroll_horizontal = ScrollContainer.SCROLL_MODE_AUTO
			grade_scroll.visible = false
			main_vbox.add_child(grade_scroll)
			if carousel_scroll != null:
				main_vbox.move_child(grade_scroll, carousel_scroll.get_index())
	if grade_row == null:
		grade_row = grade_scroll.get_node_or_null("GradeLevelRow") as HBoxContainer
		if grade_row == null:
			grade_row = HBoxContainer.new()
			grade_row.name = "GradeLevelRow"
			grade_row.alignment = BoxContainer.ALIGNMENT_CENTER
			grade_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grade_row.add_theme_constant_override("separation", 12)
			grade_scroll.add_child(grade_row)
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
			carousel_row.alignment = BoxContainer.ALIGNMENT_CENTER
			carousel_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			carousel_row.add_theme_constant_override("separation", 12)
			carousel_scroll.add_child(carousel_row)
	if final_row == null:
		final_row = main_vbox.get_node_or_null("FinalSelectionRow") as HBoxContainer
		if final_row == null:
			final_row = HBoxContainer.new()
			final_row.name = "FinalSelectionRow"
			final_row.alignment = BoxContainer.ALIGNMENT_CENTER
			final_row.add_theme_constant_override("separation", 16)
			final_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			main_vbox.add_child(final_row)
			if config_button != null and main_vbox.has_node("ConfigButton"):
				main_vbox.move_child(final_row, config_button.get_index())
	if final_selection_label == null and final_row != null:
		final_selection_label = Label.new()
		final_selection_label.text = "Select a reading level to continue."
		final_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		final_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		final_row.add_child(final_selection_label)
	if final_start_button == null and final_row != null:
		final_start_button = Button.new()
		final_start_button.text = "Start Selected Level"
		final_start_button.disabled = true
		final_start_button.pressed.connect(_on_start_pressed)
		final_row.add_child(final_start_button)


func _get_mode_label(mode_name: String) -> String:
	match mode_name:
		LEVEL_MODE_WORD_CHOICE:
			return "Select Word"
		_:
			return "Pronunciation"


func _get_mode_tooltip(mode_name: String) -> String:
	match mode_name:
		LEVEL_MODE_WORD_CHOICE:
			return "Hear a word and pick the correct match."
		_:
			return "Pronounce words from the selected reading list."


func _build_preview_word_entries(group_name: String) -> Array[Dictionary]:
	var texts: Array[String] = []
	var csv_path: String = content_loader._find_group_csv_path(group_name)
	if csv_path != "":
		var file := FileAccess.open(csv_path, FileAccess.READ)
		if file != null:
			var raw_text := file.get_as_text()
			file.close()
			var lines := raw_text.split("\n")
			var header_map: Dictionary = {}
			var data_start_index := 0
			if lines.size() > 0:
				var header_columns: Array[String] = content_loader._parse_csv_line(
					str(lines[0]).strip_edges()
				)
				if (
					header_columns.size() > 0
					and str(header_columns[0]).strip_edges().to_lower() == "word"
				):
					header_map = content_loader._build_csv_header_map(header_columns)
					data_start_index = 1
			for i in range(data_start_index, lines.size()):
				var line := str(lines[i]).strip_edges()
				if line.is_empty():
					continue
				var columns: Array[String] = content_loader._parse_csv_line(line)
				if columns.size() < 1:
					continue
				var word_text: String = (
					content_loader
					. _get_csv_value(columns, header_map, ["word"] as Array[String], 0)
					. strip_edges()
				)
				if word_text.is_empty():
					continue
				texts.append(word_text)
	if texts.size() == 0:
		return []
	texts.shuffle()
	if texts.size() > 8:
		texts = texts.slice(0, 8)
	var entries: Array[Dictionary] = []
	for text in texts:
		var letters: Array[String] = []
		for character in str(text):
			letters.append(str(character))
		entries.append({"text": str(text), "letters": letters, "group": group_name})
	return entries
