class_name VehicleSelectPaintHelpers
extends RefCounted

static var _brush_shape_texture_cache: Dictionary = {}


static func configure_paint_logging(owner) -> void:
	var environment_level := (
		str(OS.get_environment("READING_VEHICLE_PAINT_LOG_LEVEL")).strip_edges().to_lower()
	)
	if environment_level.is_empty():
		owner.paint_log_level = owner.PAINT_LOG_LEVEL_INFO
		return

	match environment_level:
		"none", "off", "0":
			owner.paint_log_level = owner.PAINT_LOG_LEVEL_NONE
		"error", "1":
			owner.paint_log_level = owner.PAINT_LOG_LEVEL_ERROR
		"warn", "warning", "2":
			owner.paint_log_level = owner.PAINT_LOG_LEVEL_WARN
		"verbose", "trace", "4":
			owner.paint_log_level = owner.PAINT_LOG_LEVEL_VERBOSE
		_:
			owner.paint_log_level = owner.PAINT_LOG_LEVEL_INFO


static func log_paint(owner, level: int, message: String, payload: Variant = null) -> void:
	if owner.paint_log_level < level:
		return

	var level_name := "INFO"
	match level:
		owner.PAINT_LOG_LEVEL_ERROR:
			level_name = "ERROR"
		owner.PAINT_LOG_LEVEL_WARN:
			level_name = "WARN"
		owner.PAINT_LOG_LEVEL_INFO:
			level_name = "INFO"
		owner.PAINT_LOG_LEVEL_VERBOSE:
			level_name = "VERBOSE"

	if payload == null:
		print("[VehicleSelect][", level_name, "] ", message)
	else:
		print("[VehicleSelect][", level_name, "] ", message, " | ", payload)


static func paint_debug_snapshot(owner) -> Dictionary:
	var preview_mesh_count := 0
	if owner.vehicle_preview_instance != null:
		preview_mesh_count = (
			owner._collect_preview_mesh_instances(owner.vehicle_preview_instance).size()
		)

	return {
		"vehicle_id": owner.selected_vehicle_id,
		"vehicle_name": owner.vehicle_name_label.text,
		"preview_instance_ready": is_instance_valid(owner.vehicle_preview_instance),
		"preview_mesh_count": preview_mesh_count,
		"overlay_manager_ready": is_instance_valid(owner.overlay_atlas_manager),
		"overlay_atlas_rid_valid":
		(
			owner.overlay_atlas_manager != null
			and owner.overlay_atlas_manager.atlas_texture_rid.is_valid()
		),
		"overlay_apply_count": owner.overlay_apply_count,
		"overlay_refresh_pending": owner.overlay_refresh_pending,
		"camera_brush_ready": is_instance_valid(owner.camera_brush),
		"brush_viewport_ready": owner.camera_brush != null and owner.camera_brush.viewport != null,
		"brush_drawing": owner.camera_brush != null and owner.camera_brush.drawing,
		"paint_hit_count": owner.paint_hit_count,
		"last_paint_hit": owner.last_paint_hit,
		"selected_brush_shape": owner.selected_brush_shape,
		"brush_size": owner.paint_brush_size,
		"paint_color": owner.selected_vehicle_color.to_html(true),
		"decal_count": owner.selected_vehicle_decals.size(),
	}


static func build_paint_color_palette(owner) -> void:
	owner.paint_color_buttons.clear()
	for child in owner.paint_color_palette.get_children():
		child.queue_free()

	for index in range(owner.PAINT_COLOR_OPTIONS.size()):
		var color: Color = owner.PAINT_COLOR_OPTIONS[index]
		var swatch: TextureButton = TextureButton.new()
		swatch.name = "PaintColorSwatch_%02d" % index
		swatch.toggle_mode = true
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.ignore_texture_size = true
		swatch.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.tooltip_text = color.to_html(true)
		swatch.texture_normal = VehicleSelectUtils.create_color_swatch_texture(color, false)
		swatch.texture_pressed = VehicleSelectUtils.create_color_swatch_texture(color, true)
		swatch.texture_hover = swatch.texture_normal
		swatch.texture_focused = swatch.texture_normal
		swatch.pressed.connect(owner._on_paint_color_selected.bind(index))
		owner.paint_color_palette.add_child(swatch)
		owner.paint_color_buttons.append(swatch)

	update_paint_color_swatches(owner)


static func build_brush_size_selector(owner, parent: Control) -> void:
	owner.brush_size_buttons.clear()
	var size_row := HBoxContainer.new()
	size_row.name = "BrushSizeSelector"
	size_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_theme_constant_override("separation", 8)
	parent.add_child(size_row)

	for index in range(owner.BRUSH_PRESETS.size()):
		var preset: Dictionary = owner.BRUSH_PRESETS[index]
		var preset_size := float(preset.get("size", owner.paint_brush_size))
		var button: TextureButton = TextureButton.new()
		button.name = "BrushSizeButton_%02d" % index
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(48, 48)
		button.texture_normal = VehicleSelectUtils.create_brush_size_texture(preset_size, false)
		button.texture_pressed = VehicleSelectUtils.create_brush_size_texture(preset_size, true)
		button.texture_hover = button.texture_normal
		button.texture_focused = button.texture_normal
		button.pressed.connect(owner._on_brush_size_selected.bind(index))
		size_row.add_child(button)
		owner.brush_size_buttons.append(button)

	var closest_index: int = owner._find_closest_brush_preset_index(owner.paint_brush_size)
	update_brush_size_button_states(owner, closest_index)


static func update_brush_size_button_states(owner, selected_index: int) -> void:
	for index in range(owner.brush_size_buttons.size()):
		var button: TextureButton = owner.brush_size_buttons[index] as TextureButton
		button.button_pressed = index == selected_index
		var preset_size := float(owner.BRUSH_PRESETS[index].get("size", owner.paint_brush_size))
		button.texture_normal = VehicleSelectUtils.create_brush_size_texture(
			preset_size, index == selected_index
		)
		button.texture_pressed = VehicleSelectUtils.create_brush_size_texture(
			preset_size, index == selected_index
		)


static func apply_paint_swatch_state(swatch: TextureButton, selected: bool) -> void:
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


static func update_paint_color_swatches(owner) -> void:
	for index in range(owner.paint_color_buttons.size()):
		var swatch: TextureButton = owner.paint_color_buttons[index] as TextureButton
		apply_paint_swatch_state(swatch, index == owner.selected_paint_color_index)
		swatch.button_pressed = index == owner.selected_paint_color_index


static func find_brush_shape_option_index(owner, shape_id: String) -> int:
	for idx in range(owner.BRUSH_SHAPE_OPTIONS.size()):
		if owner.BRUSH_SHAPE_OPTIONS[idx].get("id", "") == shape_id:
			return idx
	return 0


static func set_selected_brush_shape(owner, shape_id: String, refresh_preview := true) -> void:
	owner.selected_brush_shape = shape_id
	if owner.brush_shape_selector != null:
		owner.brush_shape_selector.selected = find_brush_shape_option_index(owner, shape_id)
	if owner.brush_shape_preview != null:
		owner.brush_shape_preview.texture = (VehicleSelectUtils.create_brush_shape_preview_texture(
			shape_id, 64
		))
	sync_gpu_paint_state(owner)
	if refresh_preview:
		owner._refresh_vehicle_preview()


static func on_brush_shape_selected(owner, index: int) -> void:
	if index < 0 or index >= owner.BRUSH_SHAPE_OPTIONS.size():
		return
	set_selected_brush_shape(owner, owner.BRUSH_SHAPE_OPTIONS[index].get("id", "circle"))


static func set_selected_paint_color(owner, color: Color, refresh_preview := true) -> void:
	owner.selected_vehicle_color = color
	owner.selected_paint_color_index = find_closest_paint_color_index(owner, color)
	update_paint_color_swatches(owner)
	sync_gpu_paint_state(owner)
	if refresh_preview:
		owner._refresh_vehicle_preview()


static func find_closest_paint_color_index(owner, color: Color) -> int:
	var closest_index := 0
	var closest_distance := INF
	for index in range(owner.PAINT_COLOR_OPTIONS.size()):
		var option_color: Color = owner.PAINT_COLOR_OPTIONS[index]
		var distance := (
			absf(option_color.r - color.r)
			+ absf(option_color.g - color.g)
			+ absf(option_color.b - color.b)
		)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index


static func set_brush_preset_by_size(owner, brush_size: float, refresh_preview := true) -> void:
	owner.paint_brush_size = brush_size
	var closest_index := 0
	var closest_distance := INF
	for index in range(owner.BRUSH_PRESETS.size()):
		var preset_size := float(owner.BRUSH_PRESETS[index].get("size", owner.paint_brush_size))
		var distance := absf(preset_size - brush_size)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	update_brush_size_button_states(owner, closest_index)
	sync_gpu_paint_state(owner)
	if refresh_preview:
		owner._refresh_vehicle_preview()


static func on_brush_size_selected(owner, index: int) -> void:
	if index < 0 or index >= owner.BRUSH_PRESETS.size():
		return
	var preset: Dictionary = owner.BRUSH_PRESETS[index]
	var preset_size := float(preset.get("size", owner.paint_brush_size))
	set_brush_preset_by_size(owner, preset_size)


static func on_paint_color_selected(owner, index: int) -> void:
	if index < 0 or index >= owner.PAINT_COLOR_OPTIONS.size():
		return
	var selected_color: Color = owner.PAINT_COLOR_OPTIONS[index]
	set_selected_paint_color(owner, selected_color)


static func on_brush_preset_selected(owner, index: int) -> void:
	if index < 0 or index >= owner.BRUSH_PRESETS.size():
		return
	var preset: Dictionary = owner.BRUSH_PRESETS[index]
	var preset_size := float(preset.get("size", owner.paint_brush_size))
	set_brush_preset_by_size(owner, preset_size)


static func sync_gpu_paint_state(owner) -> void:
	if owner.camera_brush == null:
		return
	owner.camera_brush.color = owner.selected_vehicle_color
	owner.camera_brush.size = owner.paint_brush_size
	owner.camera_brush.brush_shape = _get_brush_shape_texture(owner.selected_brush_shape)


static func _get_brush_shape_texture(shape_id: String) -> Image:
	if _brush_shape_texture_cache.has(shape_id):
		return _brush_shape_texture_cache[shape_id]

	var brush_shape_texture: Image
	match shape_id:
		"circle":
			brush_shape_texture = VehicleSelectUtils.create_circular_brush_shape(256)
		"square":
			brush_shape_texture = VehicleSelectUtils.create_square_brush_shape(256)
		"star":
			brush_shape_texture = VehicleSelectUtils.create_star_brush_shape(256)
		"smoke":
			brush_shape_texture = VehicleSelectUtils.create_smoke_brush_shape(256)
		_:
			brush_shape_texture = VehicleSelectUtils.create_circular_brush_shape(256)

	_brush_shape_texture_cache[shape_id] = brush_shape_texture
	return brush_shape_texture


static func spawn_debug_paint_marker(owner, global_position: Vector3, color: Color) -> void:
	var sphere = MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.28)
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b, 0.18)
	mat.flags_unshaded = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material_override = mat
	sphere.scale = Vector3.ONE * 0.05
	owner.vehicle_preview_root.add_child(sphere)
	sphere.global_transform = Transform3D(Basis(), global_position)
	await owner.get_tree().create_timer(1.5).timeout
	if is_instance_valid(sphere):
		sphere.queue_free()
