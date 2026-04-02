class_name VehicleSelect
extends Control
const PlayerVehicleLibraryScript = preload("res://scripts/reading/player_vehicle_library.gd")
const ReadingSettingsStoreScript = preload("res://scripts/reading/settings_store.gd")
const VehicleSelectUtilsScript = preload("res://scripts/reading/vehicle_select_utils.gd")
const VehicleSelectPaintHelpersScript = preload(
	"res://scripts/reading/vehicle_select_paint_helpers.gd"
)
const GPU_TEXTURE_PAINTER_BASE := (
	"res://addons/gpu-texture-painter/"
	+ "gpu-texture-painter-f4faff9106b51a2e95ef6d74abec774ce86cd453/"
	+ "addons/gpu_texture_painter/"
)
const GPUOverlayAtlasManager = preload(
	GPU_TEXTURE_PAINTER_BASE + "manager/" + "overlay_atlas_manager.gd"
)
const GPUCameraBrush = preload(GPU_TEXTURE_PAINTER_BASE + "brush/" + "camera_brush.gd")
const GPU_BRUSH_SHAPE := preload(
	GPU_TEXTURE_PAINTER_BASE + "brush_shapes/" + "smooth_brush_shape.webp"
)
const GPU_OVERLAY_SHADER := preload(
	GPU_TEXTURE_PAINTER_BASE + "overlay_shaders/" + "default_overlay.gdshader"
)
const PAINT_LOG_LEVEL_NONE := 0
const PAINT_LOG_LEVEL_ERROR := 1
const PAINT_LOG_LEVEL_WARN := 2
const PAINT_LOG_LEVEL_INFO := 3
const PAINT_LOG_LEVEL_VERBOSE := 4

const PAINT_COLOR_OPTIONS := [
	Color(0.98, 0.24, 0.20),
	Color(0.98, 0.49, 0.12),
	Color(0.96, 0.78, 0.16),
	Color(0.73, 0.90, 0.20),
	Color(0.23, 0.74, 0.31),
	Color(0.14, 0.78, 0.65),
	Color(0.18, 0.73, 0.94),
	Color(0.20, 0.43, 0.96),
	Color(0.40, 0.27, 0.96),
	Color(0.63, 0.26, 0.94),
	Color(0.86, 0.27, 0.78),
	Color(0.94, 0.30, 0.55),
	Color(0.98, 0.86, 0.86),
	Color(0.92, 0.92, 0.92),
	Color(0.62, 0.62, 0.62),
	Color(0.28, 0.28, 0.28),
	Color(0.39, 0.25, 0.16),
	Color(0.53, 0.32, 0.14),
	Color(0.70, 0.56, 0.30),
	Color(0.99, 0.74, 0.35),
	Color(0.90, 0.68, 0.60),
	Color(0.65, 0.88, 0.82),
	Color(0.70, 0.82, 0.98),
	Color(0.93, 0.72, 0.96),
]

const BRUSH_PRESETS := [
	{"label": "Fine", "size": 0.12},
	{"label": "Small", "size": 0.20},
	{"label": "Medium", "size": 0.35},
	{"label": "Large", "size": 0.50},
	{"label": "XL", "size": 0.72},
]

const BRUSH_SHAPE_OPTIONS := [
	{"label": "Circle", "id": "circle"},
	{"label": "Square", "id": "square"},
	{"label": "Star", "id": "star"},
	{"label": "Smoke", "id": "smoke"},
]
var vehicle_select_utils := VehicleSelectUtilsScript.new()
var vehicle_select_paint_helpers := VehicleSelectPaintHelpersScript.new()
var settings_store := ReadingSettingsStoreScript.new()
var vehicle_catalog: Array[Dictionary] = []
var selected_vehicle_id := PlayerVehicleLibraryScript.DEFAULT_VEHICLE_ID
var selected_vehicle_color := PlayerVehicleLibraryScript.get_default_paint_color()
var vehicle_select_container := HBoxContainer.new()
var vehicle_select_prev_button := Button.new()
var vehicle_select_next_button := Button.new()
var vehicle_option_label := Label.new()
var paint_color_palette := GridContainer.new()
var brush_size_buttons: Array = []
var brush_shape_preview := TextureRect.new()
var vehicle_name_label := Label.new()
var vehicle_preview_container := SubViewportContainer.new()
var selected_vehicle_index := 0
var vehicle_preview_viewport := SubViewport.new()
var vehicle_preview_root := Node3D.new()
var vehicle_preview_pivot := Node3D.new()
var overlay_atlas_manager: OverlayAtlasManager = null
var camera_brush: CameraBrush = null
var vehicle_preview_instance: Node3D = null
var save_feedback_label := Label.new()
var vehicle_preview_camera: Camera3D = null
var painting_pointer_down := false
var paint_brush_size := 0.35
var selected_brush_shape := "circle"
var brush_shape_selector: OptionButton = null
var selected_vehicle_decals: Array = []
var selected_paint_color_index := 0
var paint_color_buttons: Array[BaseButton] = []
var overlay_refresh_pending := false
var overlay_apply_count := 0
var paint_hit_count := 0
var last_paint_hit: Dictionary = {}
var paint_log_level := PAINT_LOG_LEVEL_INFO
var selected_vehicle_rotation := Vector3.ZERO

@onready var main_vbox: VBoxContainer = null


func _ready() -> void:
	vehicle_select_paint_helpers.configure_paint_logging(self)
	_build_vehicle_ui()
	_populate_vehicle_options()
	_load_settings()
	vehicle_select_paint_helpers.sync_gpu_paint_state(self)
	_request_overlay_refresh()


func _build_vehicle_ui() -> void:
	var panel := Panel.new()
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_color = Color(0.5, 0.5, 0.5, 1)
	panel.add_theme_stylebox_override("panel", style_box)

	add_child(panel)
	panel.custom_minimum_size = Vector2(900, 640)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0

	main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 16)
	panel.add_child(main_vbox)

	var customizer_row := HBoxContainer.new()
	customizer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	customizer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	customizer_row.add_theme_constant_override("separation", 24)
	main_vbox.add_child(customizer_row)

	var preview_nav := HBoxContainer.new()
	preview_nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_nav.add_theme_constant_override("separation", 14)
	customizer_row.add_child(preview_nav)

	vehicle_select_prev_button.name = "VehiclePrevButton"
	vehicle_select_prev_button.text = "◀"
	vehicle_select_prev_button.custom_minimum_size = Vector2(70, 140)
	vehicle_select_prev_button.add_theme_font_size_override("font_size", 32)
	vehicle_select_prev_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vehicle_select_prev_button.pressed.connect(_on_prev_vehicle)
	preview_nav.add_child(vehicle_select_prev_button)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(560, 380)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_nav.add_child(preview_panel)

	vehicle_preview_container.name = "VehiclePreviewContainer"
	vehicle_preview_container.stretch = true
	vehicle_preview_container.custom_minimum_size = Vector2(560, 380)
	vehicle_preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	vehicle_preview_container.gui_input.connect(_on_vehicle_preview_gui_input)
	preview_panel.add_child(vehicle_preview_container)

	vehicle_select_next_button.name = "VehicleNextButton"
	vehicle_select_next_button.text = "▶"
	vehicle_select_next_button.custom_minimum_size = Vector2(70, 140)
	vehicle_select_next_button.add_theme_font_size_override("font_size", 32)
	vehicle_select_next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vehicle_select_next_button.pressed.connect(_on_next_vehicle)
	preview_nav.add_child(vehicle_select_next_button)

	vehicle_preview_viewport.name = "VehiclePreviewViewport"
	vehicle_preview_viewport.size = Vector2i(1280, 960)
	vehicle_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vehicle_preview_viewport.msaa_3d = Viewport.MSAA_4X
	vehicle_preview_container.add_child(vehicle_preview_viewport)

	vehicle_preview_viewport.add_child(vehicle_preview_root)
	vehicle_preview_root.add_child(vehicle_preview_pivot)

	overlay_atlas_manager = GPUOverlayAtlasManager.new()
	overlay_atlas_manager.name = "OverlayAtlasManager"
	overlay_atlas_manager.atlas_size = 1024
	overlay_atlas_manager.overlay_shader = GPU_OVERLAY_SHADER
	overlay_atlas_manager.apply_on_ready = false
	vehicle_preview_pivot.add_child(overlay_atlas_manager)
	(
		vehicle_select_paint_helpers
		. log_paint(
			self,
			PAINT_LOG_LEVEL_VERBOSE,
			"Overlay atlas manager created",
			{
				"atlas_size": overlay_atlas_manager.atlas_size,
				"apply_on_ready": overlay_atlas_manager.apply_on_ready,
			},
		)
	)

	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08, 0.1, 0.13)
	vehicle_preview_root.add_child(environment)

	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(12.0, 12.0)
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
	preview_camera.position = Vector3(0.0, 2.3, 5.0)
	vehicle_preview_root.add_child(preview_camera)
	vehicle_preview_camera = preview_camera
	preview_camera.look_at_from_position(
		preview_camera.position, Vector3(0.0, 1.1, 0.0), Vector3.UP
	)

	camera_brush = GPUCameraBrush.new()
	camera_brush.name = "CameraBrush"
	camera_brush.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera_brush.fov = 20.0
	camera_brush.max_distance = 25.0
	camera_brush.min_bleed = 0
	camera_brush.max_bleed = 0
	camera_brush.brush_shape = vehicle_select_paint_helpers.create_circular_brush_shape(256)
	camera_brush.resolution = Vector2i(512, 512)
	camera_brush.size = 0.5
	camera_brush.color = selected_vehicle_color
	camera_brush.drawing = false
	vehicle_preview_root.add_child(camera_brush)
	camera_brush.global_transform = preview_camera.global_transform
	(
		vehicle_select_paint_helpers
		. log_paint(
			self,
			PAINT_LOG_LEVEL_VERBOSE,
			"Camera brush created",
			{
				"projection": camera_brush.projection,
				"fov": camera_brush.fov,
				"size": camera_brush.size,
				"max_distance": camera_brush.max_distance,
			},
		)
	)

	var controls_panel := VBoxContainer.new()
	controls_panel.custom_minimum_size = Vector2(300, 0)
	controls_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_panel.add_theme_constant_override("separation", 12)
	customizer_row.add_child(controls_panel)

	vehicle_select_container.name = "VehicleOption"
	vehicle_select_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_select_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vehicle_select_container.visible = false

	vehicle_option_label.name = "VehicleNameLabel"
	vehicle_option_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_option_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vehicle_option_label.visible = false
	vehicle_select_container.add_child(vehicle_option_label)

	controls_panel.add_child(vehicle_select_container)

	var brush_label := Label.new()
	brush_label.text = "Brush"
	controls_panel.add_child(brush_label)

	vehicle_select_paint_helpers.build_brush_size_selector(self, controls_panel)
	vehicle_select_paint_helpers.build_vehicle_rotation_controls(self, controls_panel)

	var shape_label := Label.new()
	shape_label.text = "Brush Shape"
	controls_panel.add_child(shape_label)

	brush_shape_selector = OptionButton.new()
	for idx in range(BRUSH_SHAPE_OPTIONS.size()):
		brush_shape_selector.add_item(BRUSH_SHAPE_OPTIONS[idx].get("label", ""), idx)
	brush_shape_selector.selected = _find_brush_shape_option_index(selected_brush_shape)
	brush_shape_selector.focus_mode = Control.FOCUS_NONE
	brush_shape_selector.connect("item_selected", Callable(self, "_on_brush_shape_selected"))
	controls_panel.add_child(brush_shape_selector)

	brush_shape_preview = TextureRect.new()
	brush_shape_preview.expand = true
	brush_shape_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brush_shape_preview.texture = vehicle_select_paint_helpers.create_brush_shape_preview_texture(
		selected_brush_shape, 64
	)
	controls_panel.add_child(brush_shape_preview)

	var paint_mode_hint := Label.new()
	paint_mode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paint_mode_hint.text = "🎨 Drag on preview to paint"
	controls_panel.add_child(paint_mode_hint)

	var paint_label := Label.new()
	paint_label.text = "Paint Color"
	controls_panel.add_child(paint_label)

	paint_color_palette.name = "PaintColorPalette"
	paint_color_palette.columns = 6
	paint_color_palette.add_theme_constant_override("h_separation", 10)
	paint_color_palette.add_theme_constant_override("v_separation", 10)
	controls_panel.add_child(paint_color_palette)

	vehicle_select_paint_helpers.build_paint_color_palette(self)
	vehicle_select_paint_helpers.set_selected_paint_color(self, selected_vehicle_color, false)

	var clear_paint_button := Button.new()
	clear_paint_button.name = "ClearPaintButton"
	clear_paint_button.text = "🧼"
	clear_paint_button.tooltip_text = "Clear paint"
	clear_paint_button.pressed.connect(_on_clear_paint_pressed)
	controls_panel.add_child(clear_paint_button)

	var help_text := Label.new()
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.text = "▶ Drag on model to paint, ↔ select car, 💾 save"
	controls_panel.add_child(help_text)
	var action_bar := HBoxContainer.new()
	action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_bar.add_theme_constant_override("separation", 12)
	main_vbox.add_child(action_bar)

	save_feedback_label.text = ""
	save_feedback_label.add_theme_font_size_override("font_size", 16)
	save_feedback_label.self_modulate = Color(0.7, 0.95, 0.7)
	main_vbox.add_child(save_feedback_label)

	var save_button := Button.new()
	save_button.text = "Save"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(_on_save_pressed)
	action_bar.add_child(save_button)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "Back"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.pressed.connect(_on_back_pressed)
	action_bar.add_child(back_button)


func _populate_vehicle_options() -> void:
	vehicle_catalog = PlayerVehicleLibraryScript.list_vehicles()
	selected_vehicle_index = 0
	for index in range(vehicle_catalog.size()):
		if str(vehicle_catalog[index].get("id", "")) == selected_vehicle_id:
			selected_vehicle_index = index
			break
	_update_vehicle_selection_display()


func _update_vehicle_selection_display() -> void:
	if vehicle_catalog.size() == 0:
		vehicle_option_label.text = "No car"
		selected_vehicle_id = PlayerVehicleLibraryScript.DEFAULT_VEHICLE_ID
		return

	selected_vehicle_index = selected_vehicle_index % vehicle_catalog.size()
	if selected_vehicle_index < 0:
		selected_vehicle_index = vehicle_catalog.size() - 1

	var selected_vehicle = vehicle_catalog[selected_vehicle_index]
	selected_vehicle_id = str(
		selected_vehicle.get("id", PlayerVehicleLibraryScript.DEFAULT_VEHICLE_ID)
	)
	# Keep the label hidden to support a clean arrow-only vehicle selector.
	vehicle_option_label.text = ""


func _load_settings() -> void:
	var settings = settings_store.load_settings()
	vehicle_select_paint_helpers.set_selected_paint_color(
		self, PlayerVehicleLibraryScript.resolve_paint_color(settings), false
	)
	selected_vehicle_decals = settings.get(
		PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_DECALS, []
	)
	vehicle_select_paint_helpers.set_brush_preset_by_size(
		self, float(settings.get("paint_brush_size", paint_brush_size)), false
	)
	vehicle_select_paint_helpers.set_selected_brush_shape(
		self, str(settings.get("paint_brush_shape", selected_brush_shape)), false
	)
	_select_vehicle(str(settings.get(PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_ID, "")))
	_refresh_vehicle_preview()
	(
		vehicle_select_paint_helpers
		. log_paint(
			self,
			PAINT_LOG_LEVEL_VERBOSE,
			"Settings loaded",
			{
				"selected_vehicle_id": selected_vehicle_id,
				"paint_color": selected_vehicle_color.to_html(true),
				"brush_size": paint_brush_size,
				"brush_shape": selected_brush_shape,
				"decal_count": selected_vehicle_decals.size(),
			},
		)
	)


func _select_vehicle(vehicle_id: String) -> void:
	selected_vehicle_id = PlayerVehicleLibraryScript.resolve_vehicle_id(
		{PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_ID: vehicle_id}
	)
	for index in range(vehicle_catalog.size()):
		var vehicle := vehicle_catalog[index]
		if str(vehicle.get("id", "")) == selected_vehicle_id:
			selected_vehicle_index = index
			break
	_update_vehicle_selection_display()


func _refresh_vehicle_preview() -> void:
	_clear_preview_decals()
	if is_instance_valid(vehicle_preview_instance):
		vehicle_preview_instance.queue_free()
		vehicle_preview_instance = null

	var vehicle_settings := PlayerVehicleLibraryScript.build_vehicle_settings(
		selected_vehicle_id, selected_vehicle_color, selected_vehicle_decals
	)
	vehicle_preview_instance = PlayerVehicleLibraryScript.instantiate_vehicle_from_settings(
		vehicle_settings, PlayerVehicleLibraryScript.PREVIEW_MAX_DIMENSION * 1.2
	)
	if vehicle_preview_instance == null:
		vehicle_name_label.text = "Preview unavailable"
		return

	vehicle_preview_pivot.add_child(vehicle_preview_instance)
	vehicle_preview_instance.rotation_degrees = selected_vehicle_rotation
	var selected_vehicle: Dictionary = (
		PlayerVehicleLibraryScript.get_vehicle_by_id(selected_vehicle_id) as Dictionary
	)
	var vehicle_name: String = str(selected_vehicle.get("name", "Vehicle"))
	vehicle_name_label.text = vehicle_name
	(
		vehicle_select_paint_helpers
		. log_paint(
			self,
			PAINT_LOG_LEVEL_INFO,
			"Preview vehicle refreshed",
			{
				"vehicle_id": selected_vehicle_id,
				"vehicle_name": vehicle_name_label.text,
				"mesh_count": _collect_preview_mesh_instances(vehicle_preview_instance).size(),
			},
		)
	)

	_apply_preview_decals()
	vehicle_select_paint_helpers.sync_gpu_paint_state(self)
	vehicle_select_paint_helpers.apply_vehicle_rotation(self, selected_vehicle_rotation)
	if camera_brush != null:
		camera_brush.get_atlas_textures()

	_request_overlay_refresh()


func _clear_preview_decals() -> void:
	if vehicle_preview_instance == null:
		return
	for decal in _collect_decals(vehicle_preview_instance):
		if decal is Node:
			(decal as Node).queue_free()


func _apply_preview_decals() -> void:
	if vehicle_preview_instance == null:
		return
	PlayerVehicleLibraryScript.apply_vehicle_decals(
		vehicle_preview_instance, selected_vehicle_decals
	)


func _setup_paint_collision(_node: Node) -> void:
	return


func _collect_decals(node: Node) -> Array:
	var decals: Array = []
	if node is Decal or (node is MeshInstance3D and node.name.begins_with("PaintDecal")):
		decals.append(node)
	for child in node.get_children():
		if child is Node:
			decals += _collect_decals(child as Node)
	return decals


func _apply_vehicle_settings(settings: Dictionary) -> void:
	var vehicle_settings := PlayerVehicleLibraryScript.build_vehicle_settings(
		selected_vehicle_id, selected_vehicle_color, selected_vehicle_decals
	)
	for key in vehicle_settings.keys():
		settings[key] = vehicle_settings[key]
	# Keep brush size and shape setting in sync with the preview state.
	settings["paint_brush_size"] = paint_brush_size
	settings["paint_brush_shape"] = selected_brush_shape
	# Ensure empty decal lists override prior saved decals.
	settings[PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_DECALS] = selected_vehicle_decals


func _on_vehicle_selected(index: int) -> void:
	if index < 0 or index >= vehicle_catalog.size():
		return
	selected_vehicle_index = index
	_update_vehicle_selection_display()
	_refresh_vehicle_preview()


func _on_prev_vehicle() -> void:
	if vehicle_catalog.size() == 0:
		return
	selected_vehicle_index = (
		(selected_vehicle_index - 1 + vehicle_catalog.size()) % vehicle_catalog.size()
	)
	_update_vehicle_selection_display()
	_refresh_vehicle_preview()


func _on_next_vehicle() -> void:
	if vehicle_catalog.size() == 0:
		return
	selected_vehicle_index = (selected_vehicle_index + 1) % vehicle_catalog.size()
	_update_vehicle_selection_display()
	_refresh_vehicle_preview()


func _build_paint_color_palette() -> void:
	vehicle_select_paint_helpers.build_paint_color_palette(self)


func _build_brush_size_selector(parent: Control) -> void:
	vehicle_select_paint_helpers.build_brush_size_selector(self, parent)


func _update_brush_size_button_states(selected_index: int) -> void:
	vehicle_select_paint_helpers.update_brush_size_button_states(self, selected_index)


func _find_closest_brush_preset_index(brush_size: float) -> int:
	return vehicle_select_utils.find_closest_brush_preset_index(brush_size, BRUSH_PRESETS)


func _find_brush_shape_option_index(shape_id: String) -> int:
	return vehicle_select_paint_helpers.find_brush_shape_option_index(self, shape_id)


func _set_selected_brush_shape(shape_id: String, refresh_preview := true) -> void:
	vehicle_select_paint_helpers.set_selected_brush_shape(self, shape_id, refresh_preview)


func _on_brush_shape_selected(index: int) -> void:
	vehicle_select_paint_helpers.on_brush_shape_selected(self, index)


func _on_clear_paint_pressed() -> void:
	selected_vehicle_decals.clear()
	_clear_preview_decals()
	_request_overlay_refresh()
	vehicle_select_paint_helpers.log_paint(
		self, PAINT_LOG_LEVEL_INFO, "Cleared paint state", _paint_debug_snapshot()
	)
	if camera_brush != null:
		camera_brush.drawing = false


func _on_brush_size_selected(index: int) -> void:
	vehicle_select_paint_helpers.on_brush_size_selected(self, index)


func _on_paint_color_selected(index: int) -> void:
	vehicle_select_paint_helpers.on_paint_color_selected(self, index)


func _on_brush_preset_selected(index: int) -> void:
	vehicle_select_paint_helpers.on_brush_preset_selected(self, index)


func _rotate_vehicle_y(delta_degrees: float) -> void:
	vehicle_select_paint_helpers.rotate_vehicle_y(self, delta_degrees)


func _set_vehicle_rotation_preset(preset_name: String) -> void:
	vehicle_select_paint_helpers.set_vehicle_rotation_preset(self, preset_name)


func _on_vehicle_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			painting_pointer_down = true
			if camera_brush != null:
				_paint_at_viewport_point((event as InputEventMouseButton).position)
				camera_brush.drawing = true
		else:
			painting_pointer_down = false
			if camera_brush != null:
				camera_brush.drawing = false

	if event is InputEventMouseMotion and painting_pointer_down and camera_brush != null:
		_paint_at_viewport_point((event as InputEventMouseMotion).position)

	if event is InputEventScreenTouch:
		if event.pressed:
			painting_pointer_down = true
			if camera_brush != null:
				_paint_at_viewport_point(event.position)
				camera_brush.drawing = true
		else:
			painting_pointer_down = false
			if camera_brush != null:
				camera_brush.drawing = false

	if event is InputEventScreenDrag and painting_pointer_down and camera_brush != null:
		_paint_at_viewport_point(event.position)


func _paint_at_viewport_point(_local_point: Vector2) -> void:
	if camera_brush != null:
		var viewport_point := _container_point_to_viewport_point(_local_point)
		var hit := _find_preview_hit(viewport_point)
		if hit.is_empty():
			(
				vehicle_select_paint_helpers
				. log_paint(
					self,
					PAINT_LOG_LEVEL_WARN,
					"Paint ray missed preview mesh",
					{
						"local_point": _local_point,
						"viewport_point": viewport_point,
						"container_size": vehicle_preview_container.size,
						"viewport_size": Vector2(vehicle_preview_viewport.size),
						"preview_mesh_count":
						_collect_preview_mesh_instances(vehicle_preview_instance).size(),
						"preview_camera_ready": vehicle_preview_camera != null,
					},
				)
			)
			return
		paint_hit_count += 1
		last_paint_hit = hit
		var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
		var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
		# Keep brush camera slightly in front of the surface to stay outside the near plane.
		var safe_distance = max(0.02, paint_brush_size * 0.5)
		var brush_position = hit_position + hit_normal * safe_distance
		var look_direction = (hit_position - brush_position).normalized()
		var up_dir = Vector3.UP
		if absf(look_direction.dot(up_dir)) > 0.995:
			up_dir = Vector3.RIGHT

		camera_brush.global_transform = Transform3D(
			Basis().looking_at(look_direction, up_dir), brush_position
		)
		vehicle_select_paint_helpers.sync_gpu_paint_state(self)

		camera_brush.drawing = true

		(
			VehicleSelectPaintHelpersScript
			. log_paint(
				self,
				PAINT_LOG_LEVEL_INFO,
				"Paint hit accepted",
				{
					"hit_position": hit_position,
					"hit_normal": hit_normal,
					"brush_position": brush_position,
					"paint_hit_count": paint_hit_count,
				},
			)
		)

		_request_overlay_refresh()

		# Fallback realtime visuals: add a Decal node directly so painting is visible.
		if vehicle_preview_instance != null:
			var local_position := vehicle_preview_instance.to_local(hit_position)
			var local_basis := vehicle_preview_instance.global_transform.basis.inverse()
			var local_normal: Vector3 = local_basis * hit_normal
			local_normal = local_normal.normalized()
			var decal_color := selected_vehicle_color
			var brush_size := paint_brush_size
			var added_decal_count := 0
			added_decal_count = (
				PlayerVehicleLibraryScript
				. apply_vehicle_decals(
					vehicle_preview_instance,
					[
						{
							"position":
							{
								"x": float(local_position.x),
								"y": float(local_position.y),
								"z": float(local_position.z),
							},
							"normal":
							{
								"x": float(local_normal.x),
								"y": float(local_normal.y),
								"z": float(local_normal.z),
							},
							"color": decal_color.to_html(true),
							"size": brush_size,
							"shape": selected_brush_shape,
						}
					]
				)
			)
			(
				selected_vehicle_decals
				. append(
					{
						"position":
						{
							"x": float(local_position.x),
							"y": float(local_position.y),
							"z": float(local_position.z),
						},
						"normal":
						{
							"x": float(local_normal.x),
							"y": float(local_normal.y),
							"z": float(local_normal.z),
						},
						"color": decal_color.to_html(true),
						"size": brush_size,
						"shape": selected_brush_shape,
					}
				)
			)
			(
				vehicle_select_paint_helpers
				. log_paint(
					self,
					PAINT_LOG_LEVEL_INFO,
					"Preview decal added",
					{
						"added_decal_count": added_decal_count,
						"decal_count": selected_vehicle_decals.size(),
						"shape": selected_brush_shape,
						"brush_size": brush_size,
						"vehicle_rotation_degrees": selected_vehicle_rotation,
						"color": decal_color.to_html(true),
					},
				)
			)
			(
				VehicleSelectPaintHelpersScript
				. log_paint(
					self,
					PAINT_LOG_LEVEL_VERBOSE,
					"Preview decal payload queued",
					{
						"local_position": local_position,
						"local_normal": local_normal,
						"child_count": vehicle_preview_instance.get_child_count(),
					},
				)
			)
			VehicleSelectPaintHelpersScript.spawn_debug_paint_marker(
				self, hit_position, selected_vehicle_color
			)


func get_paint_debug_snapshot() -> Dictionary:
	return vehicle_select_paint_helpers.paint_debug_snapshot(self)


func _paint_debug_snapshot() -> Dictionary:
	return get_paint_debug_snapshot()


func _request_overlay_refresh() -> void:
	if overlay_atlas_manager == null:
		(
			vehicle_select_paint_helpers
			. log_paint(
				self,
				PAINT_LOG_LEVEL_WARN,
				"Overlay refresh skipped: manager missing",
			)
		)
		return
	if overlay_refresh_pending:
		(
			vehicle_select_paint_helpers
			. log_paint(
				self,
				PAINT_LOG_LEVEL_VERBOSE,
				"Overlay refresh already pending",
			)
		)
		return
	overlay_refresh_pending = true
	(
		vehicle_select_paint_helpers
		. log_paint(
			self,
			PAINT_LOG_LEVEL_VERBOSE,
			"Overlay refresh scheduled",
			_paint_debug_snapshot(),
		)
	)
	_refresh_overlay_after_frame()


func _refresh_overlay_after_frame() -> void:
	var tree := get_tree()
	if tree == null:
		overlay_refresh_pending = false
		return

	await tree.process_frame
	overlay_refresh_pending = false
	if overlay_atlas_manager == null or vehicle_preview_instance == null:
		(
			vehicle_select_paint_helpers
			. log_paint(
				self,
				PAINT_LOG_LEVEL_WARN,
				"Overlay refresh aborted after frame",
				_paint_debug_snapshot(),
			)
		)
		return

	overlay_atlas_manager.apply()
	overlay_apply_count += 1
	if camera_brush != null:
		camera_brush.get_atlas_textures()
	(
		vehicle_select_paint_helpers
		. log_paint(
			self,
			PAINT_LOG_LEVEL_INFO,
			"Overlay refresh applied",
			_paint_debug_snapshot(),
		)
	)


func _find_preview_hit(local_point: Vector2) -> Dictionary:
	if vehicle_preview_camera == null or vehicle_preview_instance == null:
		return {}

	var ray_origin := vehicle_preview_camera.project_ray_origin(local_point)
	var ray_direction := vehicle_preview_camera.project_ray_normal(local_point).normalized()
	var best_hit: Dictionary = {}
	var best_distance := INF

	for mesh_instance in _collect_preview_mesh_instances(vehicle_preview_instance):
		if mesh_instance.mesh == null:
			continue
		var hit := _ray_intersect_mesh_instance(mesh_instance, ray_origin, ray_direction)
		if hit.is_empty():
			continue
		var distance := float(hit.get("distance", INF))
		if distance < best_distance:
			best_distance = distance
			best_hit = hit

	# Fallback to AABB when detailed mesh intersection is unavailable.
	if best_hit.is_empty():
		for mesh_instance in _collect_preview_mesh_instances(vehicle_preview_instance):
			if mesh_instance.mesh == null:
				continue
			var bounds: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
			var hit := _intersect_ray_aabb(ray_origin, ray_direction, bounds)
			if hit.is_empty():
				continue
			var distance := float(hit.get("distance", INF))
			if distance < best_distance:
				best_distance = distance
				best_hit = hit

	return best_hit


func _intersect_ray_aabb(ray_origin: Vector3, ray_direction: Vector3, bounds: AABB) -> Dictionary:
	var t_min: float = -INF
	var t_max: float = INF
	var hit_normal := Vector3.ZERO
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]
	var min_corner: Vector3 = bounds.position
	var max_corner: Vector3 = bounds.position + bounds.size

	for axis_index in range(3):
		var origin_component: float = ray_origin[axis_index]
		var direction_component: float = ray_direction[axis_index]
		var min_component: float = min_corner[axis_index]
		var max_component: float = max_corner[axis_index]

		if absf(direction_component) < 0.00001:
			if origin_component < min_component or origin_component > max_component:
				return {}
			continue

		var inv_direction: float = 1.0 / direction_component
		var t1: float = (min_component - origin_component) * inv_direction
		var t2: float = (max_component - origin_component) * inv_direction
		var face_normal: Vector3 = axes[axis_index] * (-signf(direction_component))
		if t1 > t2:
			var swap: float = t1
			t1 = t2
			t2 = swap
			face_normal = -face_normal

		if t1 > t_min:
			t_min = t1
			hit_normal = face_normal
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return {}

	if t_max < 0.0:
		return {}

	var distance: float = t_min if t_min >= 0.0 else t_max
	var hit_position: Vector3 = ray_origin + ray_direction * distance
	return {
		"position": hit_position,
		"normal": hit_normal,
		"distance": distance,
	}


func _ray_intersect_mesh_instance(
	mesh_instance: MeshInstance3D, ray_origin: Vector3, ray_direction: Vector3
) -> Dictionary:
	if mesh_instance.mesh == null:
		return {}

	var local_origin = mesh_instance.to_local(ray_origin)
	var local_end = mesh_instance.to_local(ray_origin + ray_direction)
	var local_direction = (local_end - local_origin).normalized()
	if local_direction.length() < 0.00001:
		return {}

	var mesh = mesh_instance.mesh
	var best_local_distance = INF
	var best_local_position = Vector3.ZERO
	var best_local_normal = Vector3.ZERO

	for surface_index in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue

		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]

		if indices and indices.size() > 0:
			for idx in range(0, indices.size(), 3):
				var a = int(indices[idx])
				var b = int(indices[idx + 1])
				var c = int(indices[idx + 2])
				if a >= vertices.size() or b >= vertices.size() or c >= vertices.size():
					continue
				var v0 = vertices[a]
				var v1 = vertices[b]
				var v2 = vertices[c]
				var t = _intersect_ray_triangle(local_origin, local_direction, v0, v1, v2)
				if t > 0.0 and t < best_local_distance:
					best_local_distance = t
					best_local_position = local_origin + local_direction * t
					best_local_normal = (v1 - v0).cross(v2 - v0).normalized()
		else:
			for vi in range(0, vertices.size(), 3):
				if vi + 2 >= vertices.size():
					break
				var v0 = vertices[vi]
				var v1 = vertices[vi + 1]
				var v2 = vertices[vi + 2]
				var t = _intersect_ray_triangle(local_origin, local_direction, v0, v1, v2)
				if t > 0.0 and t < best_local_distance:
					best_local_distance = t
					best_local_position = local_origin + local_direction * t
					best_local_normal = (v1 - v0).cross(v2 - v0).normalized()

	if best_local_distance == INF:
		return {}

	var world_position = mesh_instance.to_global(best_local_position)
	var world_normal = (mesh_instance.global_transform.basis * best_local_normal).normalized()
	# Ensure normal points toward the ray origin (camera side).
	if world_normal.dot(ray_direction) > 0.0:
		world_normal = -world_normal
	var world_distance = ray_origin.distance_to(world_position)

	return {
		"position": world_position,
		"normal": world_normal,
		"distance": world_distance,
	}


func _intersect_ray_triangle(
	ray_origin: Vector3, ray_direction: Vector3, v0: Vector3, v1: Vector3, v2: Vector3
) -> float:
	var epsilon = 0.000001
	var edge1 = v1 - v0
	var edge2 = v2 - v0
	var h = ray_direction.cross(edge2)
	var a = edge1.dot(h)
	if absf(a) < epsilon:
		return -1.0
	var f = 1.0 / a
	var s = ray_origin - v0
	var u = f * s.dot(h)
	if u < 0.0 or u > 1.0:
		return -1.0
	var q = s.cross(edge1)
	var v = f * ray_direction.dot(q)
	if v < 0.0 or u + v > 1.0:
		return -1.0
	var t = f * edge2.dot(q)
	if t > epsilon:
		return t
	return -1.0


func _collect_preview_mesh_instances(
	node: Node, children_acc: Array[MeshInstance3D] = []
) -> Array[MeshInstance3D]:
	if node is MeshInstance3D:
		children_acc.append(node as MeshInstance3D)

	for child in node.get_children():
		children_acc = _collect_preview_mesh_instances(child, children_acc)

	return children_acc


func _container_point_to_viewport_point(local_point: Vector2) -> Vector2:
	if vehicle_preview_container == null or vehicle_preview_viewport == null:
		return local_point

	var container_size := vehicle_preview_container.size
	if container_size.x <= 0.0 or container_size.y <= 0.0:
		return local_point

	var viewport_size := Vector2(vehicle_preview_viewport.size)
	return Vector2(
		local_point.x / container_size.x * viewport_size.x,
		local_point.y / container_size.y * viewport_size.y,
	)


func _on_save_pressed() -> void:
	var settings = settings_store.load_settings()
	_apply_vehicle_settings(settings)
	settings_store.save_settings(settings)
	if save_feedback_label != null:
		save_feedback_label.text = "Saved vehicle customization"
	await get_tree().create_timer(0.8).timeout
	if save_feedback_label != null:
		save_feedback_label.text = ""
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
