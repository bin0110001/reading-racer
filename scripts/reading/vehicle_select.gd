class_name VehicleSelect
extends Control

const PlayerVehicleLibraryScript = preload("res://scripts/reading/player_vehicle_library.gd")
const ReadingSettingsStoreScript = preload("res://scripts/reading/settings_store.gd")
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

var settings_store := ReadingSettingsStoreScript.new()
var vehicle_catalog: Array[Dictionary] = []
var selected_vehicle_id := PlayerVehicleLibraryScript.DEFAULT_VEHICLE_ID
var selected_vehicle_color := PlayerVehicleLibraryScript.get_default_paint_color()

var vehicle_option := OptionButton.new()
var paint_color_palette := GridContainer.new()
var brush_size_buttons: Array = []
var vehicle_name_label := Label.new()
var vehicle_preview_container := SubViewportContainer.new()
var vehicle_preview_viewport := SubViewport.new()
var vehicle_preview_root := Node3D.new()
var vehicle_preview_pivot := Node3D.new()
var overlay_atlas_manager: OverlayAtlasManager = null
var camera_brush: CameraBrush = null
var vehicle_preview_instance: Node3D = null
var vehicle_preview_camera: Camera3D = null
var painting_pointer_down := false
var paint_brush_size := 0.35
var selected_vehicle_decals: Array = []
var selected_paint_color_index := 0
var paint_color_buttons: Array[BaseButton] = []
var overlay_refresh_pending := false

@onready var main_vbox: VBoxContainer = null


func _ready() -> void:
	_build_vehicle_ui()
	_populate_vehicle_options()
	_load_settings()
	set_process(true)


func _process(delta: float) -> void:
	if vehicle_preview_pivot == null:
		return
	vehicle_preview_pivot.rotate_y(delta * 0.45)


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
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(main_vbox)

	var title := Label.new()
	title.text = "Vehicle Selection"
	title.add_theme_font_size_override("font_size", 42)
	main_vbox.add_child(title)

	var customizer_row := HBoxContainer.new()
	customizer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	customizer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	customizer_row.add_theme_constant_override("separation", 24)
	main_vbox.add_child(customizer_row)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(560, 380)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	customizer_row.add_child(preview_panel)

	vehicle_preview_container.name = "VehiclePreviewContainer"
	vehicle_preview_container.stretch = true
	vehicle_preview_container.custom_minimum_size = Vector2(560, 380)
	vehicle_preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	vehicle_preview_container.gui_input.connect(_on_vehicle_preview_gui_input)
	preview_panel.add_child(vehicle_preview_container)

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
	camera_brush.min_bleed = 1
	camera_brush.max_bleed = 1
	camera_brush.brush_shape = _create_circular_brush_shape(256)
	camera_brush.resolution = Vector2i(512, 512)
	camera_brush.size = 0.5
	camera_brush.color = selected_vehicle_color
	camera_brush.drawing = false
	vehicle_preview_root.add_child(camera_brush)
	camera_brush.global_transform = preview_camera.global_transform

	var controls_panel := VBoxContainer.new()
	controls_panel.custom_minimum_size = Vector2(300, 0)
	controls_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_panel.add_theme_constant_override("separation", 12)
	customizer_row.add_child(controls_panel)

	vehicle_name_label.name = "VehicleNameLabel"
	vehicle_name_label.add_theme_font_size_override("font_size", 18)
	vehicle_name_label.text = "Preview"
	controls_panel.add_child(vehicle_name_label)

	var vehicle_label := Label.new()
	vehicle_label.text = "Vehicle"
	controls_panel.add_child(vehicle_label)

	vehicle_option.name = "VehicleOption"
	vehicle_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_option.item_selected.connect(_on_vehicle_selected)
	controls_panel.add_child(vehicle_option)

	var brush_label := Label.new()
	brush_label.text = "Brush"
	controls_panel.add_child(brush_label)

	_build_brush_size_selector(controls_panel)

	var paint_mode_hint := Label.new()
	paint_mode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paint_mode_hint.text = "Brush painting is always enabled. Drag on the preview to paint."
	controls_panel.add_child(paint_mode_hint)

	var paint_label := Label.new()
	paint_label.text = "Paint Color"
	controls_panel.add_child(paint_label)

	paint_color_palette.name = "PaintColorPalette"
	paint_color_palette.columns = 6
	paint_color_palette.add_theme_constant_override("h_separation", 10)
	paint_color_palette.add_theme_constant_override("v_separation", 10)
	controls_panel.add_child(paint_color_palette)

	_build_paint_color_palette()
	_set_selected_paint_color(selected_vehicle_color, false)

	var clear_paint_button := Button.new()
	clear_paint_button.name = "ClearPaintButton"
	clear_paint_button.text = "Clear Paint"
	clear_paint_button.pressed.connect(_on_clear_paint_pressed)
	controls_panel.add_child(clear_paint_button)

	var help_text := Label.new()
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.text = (
		"Your selected car, brush, and paint are saved and reused "
		+ "when you start a reading level. "
		+ "Click the preview while brush mode is on to paint on the model."
	)
	controls_panel.add_child(help_text)

	var action_bar := HBoxContainer.new()
	action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_bar.add_theme_constant_override("separation", 12)
	main_vbox.add_child(action_bar)

	var save_button := Button.new()
	save_button.text = "Save"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(_on_save_pressed)
	action_bar.add_child(save_button)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.pressed.connect(_on_back_pressed)
	action_bar.add_child(back_button)


func _populate_vehicle_options() -> void:
	vehicle_catalog = PlayerVehicleLibraryScript.list_vehicles()
	vehicle_option.clear()
	for vehicle in vehicle_catalog:
		vehicle_option.add_item(str(vehicle.get("name", "Vehicle")))


func _load_settings() -> void:
	var settings = settings_store.load_settings()
	_set_selected_paint_color(PlayerVehicleLibraryScript.resolve_paint_color(settings), false)
	selected_vehicle_decals = settings.get(
		PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_DECALS, []
	)
	_set_brush_preset_by_size(float(settings.get("paint_brush_size", paint_brush_size)), false)
	_select_vehicle(str(settings.get(PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_ID, "")))
	_refresh_vehicle_preview()


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
	var selected_vehicle := PlayerVehicleLibraryScript.get_vehicle_by_id(selected_vehicle_id)
	vehicle_name_label.text = str(selected_vehicle.get("name", "Vehicle"))

	_apply_preview_decals()
	_sync_gpu_paint_state()
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
	PlayerVehicleLibraryScript.apply_vehicle_decals(vehicle_preview_instance, selected_vehicle_decals)


func _setup_paint_collision(_node: Node) -> void:
	return


func _add_paint_decal_from_data(
	_local_position, _local_normal, _color: Color, _size: float, _save_data := true
) -> void:
	if vehicle_preview_instance == null:
		return

	var decal_info := {
		"position": {
			"x": float(_local_position.x),
			"y": float(_local_position.y),
			"z": float(_local_position.z),
		},
		"normal": {
			"x": float(_local_normal.x),
			"y": float(_local_normal.y),
			"z": float(_local_normal.z),
		},
		"color": _color.to_html(true),
		"size": _size,
	}

	if _save_data:
		selected_vehicle_decals.append(decal_info)

	PlayerVehicleLibraryScript.apply_vehicle_decals(vehicle_preview_instance, [decal_info])
	_request_overlay_refresh()


func _create_decal_material(_color: Color) -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color
	mat.unshaded = true
	return mat


func _collect_decals(node: Node) -> Array:
	var decals: Array = []
	if node is Decal:
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
	settings["paint_brush_size"] = paint_brush_size


func _on_vehicle_selected(index: int) -> void:
	if index < 0 or index >= vehicle_catalog.size():
		return
	selected_vehicle_id = str(
		vehicle_catalog[index].get("id", PlayerVehicleLibraryScript.DEFAULT_VEHICLE_ID)
	)
	_refresh_vehicle_preview()


func _build_paint_color_palette() -> void:
	paint_color_buttons.clear()
	for child in paint_color_palette.get_children():
		child.queue_free()

	for index in range(PAINT_COLOR_OPTIONS.size()):
		var color: Color = PAINT_COLOR_OPTIONS[index]
		var swatch := TextureButton.new()
		swatch.name = "PaintColorSwatch_%02d" % index
		swatch.toggle_mode = true
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.ignore_texture_size = true
		swatch.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.tooltip_text = color.to_html(true)
		swatch.texture_normal = _create_color_swatch_texture(color, false)
		swatch.texture_pressed = _create_color_swatch_texture(color, true)
		swatch.texture_hover = swatch.texture_normal
		swatch.texture_focused = swatch.texture_normal
		swatch.pressed.connect(_on_paint_color_selected.bind(index))
		paint_color_palette.add_child(swatch)
		paint_color_buttons.append(swatch)

	_update_paint_color_swatches()


func _build_brush_size_selector(parent: Control) -> void:
	brush_size_buttons.clear()
	var size_row := HBoxContainer.new()
	size_row.name = "BrushSizeSelector"
	size_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_theme_constant_override("separation", 8)
	parent.add_child(size_row)

	for index in range(BRUSH_PRESETS.size()):
		var preset: Dictionary = BRUSH_PRESETS[index]
		var preset_size := float(preset.get("size", paint_brush_size))
		var button: TextureButton = TextureButton.new()
		button.name = "BrushSizeButton_%02d" % index
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(48, 48)
		button.texture_normal = _create_brush_size_texture(preset_size, false)
		button.texture_pressed = _create_brush_size_texture(preset_size, true)
		button.texture_hover = button.texture_normal
		button.texture_focused = button.texture_normal
		button.pressed.connect(_on_brush_size_selected.bind(index))
		size_row.add_child(button)
		brush_size_buttons.append(button)

	_update_brush_size_button_states(_find_closest_brush_preset_index(paint_brush_size))


func _update_brush_size_button_states(selected_index: int) -> void:
	for index in range(brush_size_buttons.size()):
		var button: TextureButton = brush_size_buttons[index] as TextureButton
		button.button_pressed = index == selected_index
		button.texture_normal = _create_brush_size_texture(
			float(BRUSH_PRESETS[index].get("size", paint_brush_size))
			, index == selected_index
		)
		button.texture_pressed = _create_brush_size_texture(
			float(BRUSH_PRESETS[index].get("size", paint_brush_size))
			, index == selected_index
		)


func _find_closest_brush_preset_index(brush_size: float) -> int:
	var closest_index := 0
	var closest_distance := INF
	for index in range(BRUSH_PRESETS.size()):
		var preset_size := float(BRUSH_PRESETS[index].get("size", paint_brush_size))
		var distance := absf(preset_size - brush_size)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index


func _create_brush_size_texture(brush_size: float, selected := false) -> Texture2D:
	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	var radius: float = clamp(brush_size * 30.0, 6.0, 20.0)
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if dist <= radius:
				image.set_pixel(x, y, Color(1, 1, 1, 1.0 if selected else 0.8))
			elif dist <= radius + 2.0 and selected:
				image.set_pixel(x, y, Color(0.9, 0.9, 0.2, 1))
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)


func _update_paint_color_swatches() -> void:
	for index in range(paint_color_buttons.size()):
		var swatch := paint_color_buttons[index]
		_apply_paint_swatch_state(swatch, index == selected_paint_color_index)
		swatch.button_pressed = index == selected_paint_color_index


func _create_color_swatch_texture(color: Color, selected := false) -> Texture2D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center := Vector2(16.0, 16.0)
	var outer_radius := 14.0
	var inner_radius := 11.0
	for y in range(32):
		for x in range(32):
			var distance := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			if selected and distance <= outer_radius and distance > inner_radius:
				image.set_pixel(x, y, Color(1, 1, 1, 1.0))
			elif distance <= inner_radius:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0))
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)


func _create_circular_brush_shape(size: int = 256) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.5
	for y in size:
		for x in size:
			var pos = Vector2(x + 0.5, y + 0.5)
			var dist = pos.distance_to(center)
			var alpha = clampf(1.0 - (dist / radius), 0.0, 1.0)
			if dist <= radius:
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
			else:
				image.set_pixel(x, y, Color(1, 1, 1, 0))
	return image


func _set_selected_paint_color(color: Color, refresh_preview := true) -> void:
	selected_vehicle_color = color
	selected_paint_color_index = _find_closest_paint_color_index(color)
	_update_paint_color_swatches()
	_sync_gpu_paint_state()
	if refresh_preview:
		_refresh_vehicle_preview()


func _find_closest_paint_color_index(color: Color) -> int:
	var closest_index := 0
	var closest_distance := INF
	for index in range(PAINT_COLOR_OPTIONS.size()):
		var option_color: Color = PAINT_COLOR_OPTIONS[index]
		var distance := (
			absf(option_color.r - color.r)
			+ absf(option_color.g - color.g)
			+ absf(option_color.b - color.b)
		)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index


func _set_brush_preset_by_size(brush_size: float, refresh_preview := true) -> void:
	paint_brush_size = brush_size
	var closest_index := 0
	var closest_distance := INF
	for index in range(BRUSH_PRESETS.size()):
		var preset_size := float(BRUSH_PRESETS[index].get("size", paint_brush_size))
		var distance := absf(preset_size - brush_size)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	_update_brush_size_button_states(closest_index)
	_sync_gpu_paint_state()
	if refresh_preview:
		_refresh_vehicle_preview()


func _on_brush_size_selected(index: int) -> void:
	if index < 0 or index >= BRUSH_PRESETS.size():
		return
	_set_brush_preset_by_size(float(BRUSH_PRESETS[index].get("size", paint_brush_size)))


func _on_paint_color_selected(index: int) -> void:
	if index < 0 or index >= PAINT_COLOR_OPTIONS.size():
		return
	_set_selected_paint_color(PAINT_COLOR_OPTIONS[index])


func _on_brush_preset_selected(index: int) -> void:
	if index < 0 or index >= BRUSH_PRESETS.size():
		return
	_set_brush_preset_by_size(float(BRUSH_PRESETS[index].get("size", paint_brush_size)))


func _on_clear_paint_pressed() -> void:
	selected_vehicle_decals.clear()
	_clear_preview_decals()
	_request_overlay_refresh()
	if camera_brush != null:
		camera_brush.drawing = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_point = vehicle_preview_container.get_local_mouse_position()
		var inside_x = local_point.x >= 0 and local_point.x <= vehicle_preview_container.size.x
		var inside_y = local_point.y >= 0 and local_point.y <= vehicle_preview_container.size.y
		if not inside_x or not inside_y:
			return
		_paint_at_viewport_point(local_point)


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
			return
		var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
		var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
		var brush_position = hit_position + hit_normal * 0.05
		var up_dir = hit_normal
		if absf(up_dir.dot(Vector3.UP)) > 0.995:
			up_dir = Vector3.RIGHT

		camera_brush.global_transform = Transform3D(
			Basis().looking_at((hit_position - brush_position).normalized(), up_dir),
			brush_position
		)
		camera_brush.drawing = true

		if vehicle_preview_instance != null:
			var local_position := vehicle_preview_instance.to_local(hit_position)
			var local_basis := vehicle_preview_instance.global_transform.basis.inverse()
			var local_normal: Vector3 = local_basis * hit_normal
			local_normal = local_normal.normalized()
			var decal_color := selected_vehicle_color
			var brush_size := paint_brush_size
			_add_paint_decal_from_data(
				local_position,
				local_normal,
				decal_color,
				brush_size,
				true,
			)


func _sync_gpu_paint_state() -> void:
	if camera_brush == null:
		return
	camera_brush.color = selected_vehicle_color
	camera_brush.size = paint_brush_size


func _apply_paint_swatch_state(swatch: TextureButton, selected: bool) -> void:
	if selected:
		swatch.modulate = Color(1.2, 1.2, 1.2)
	else:
		swatch.modulate = Color(0.92, 0.92, 0.92)

	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.08, 0.09, 0.11, 1.0)
	frame.border_width_left = 2
	frame.border_width_top = 2
	frame.border_width_right = 2
	frame.border_width_bottom = 2
	frame.corner_radius_top_left = 5
	frame.corner_radius_top_right = 5
	frame.corner_radius_bottom_left = 5
	frame.corner_radius_bottom_right = 5
	frame.border_color = Color(0.95, 0.72, 0.25, 1.0) if selected else Color(0.3, 0.33, 0.38, 1.0)
	swatch.add_theme_stylebox_override("normal", frame)
	swatch.add_theme_stylebox_override("hover", frame)
	swatch.add_theme_stylebox_override("pressed", frame)
	swatch.add_theme_stylebox_override("focus", frame)


func _request_overlay_refresh() -> void:
	if overlay_atlas_manager == null:
		return
	if overlay_refresh_pending:
		return
	overlay_refresh_pending = true
	_refresh_overlay_after_frame()


func _refresh_overlay_after_frame() -> void:
	var tree := get_tree()
	if tree == null:
		overlay_refresh_pending = false
		return

	await tree.process_frame
	overlay_refresh_pending = false
	if overlay_atlas_manager == null or vehicle_preview_instance == null:
		return
	overlay_atlas_manager.apply()


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
	mesh_instance: MeshInstance3D,
	ray_origin: Vector3,
	ray_direction: Vector3
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
	var world_distance = ray_origin.distance_to(world_position)

	return {
		"position": world_position,
		"normal": world_normal,
		"distance": world_distance,
	}


func _intersect_ray_triangle(
	ray_origin: Vector3,
	ray_direction: Vector3,
	v0: Vector3,
	v1: Vector3,
	v2: Vector3
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
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
