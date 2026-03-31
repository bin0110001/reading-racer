class_name VehicleSelectPaintHelpers
extends RefCounted

static var vehicle_select_utils := VehicleSelectUtils.new()

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
		"vehicle_rotation_degrees": owner.selected_vehicle_rotation,
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
		swatch.texture_normal = vehicle_select_utils.create_color_swatch_texture(color, false)
		swatch.texture_pressed = vehicle_select_utils.create_color_swatch_texture(color, true)
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
		button.texture_normal = vehicle_select_utils.create_brush_size_texture(preset_size, false)
		button.texture_pressed = vehicle_select_utils.create_brush_size_texture(preset_size, true)
		button.texture_hover = button.texture_normal
		button.texture_focused = button.texture_normal
		button.pressed.connect(owner._on_brush_size_selected.bind(index))
		size_row.add_child(button)
		owner.brush_size_buttons.append(button)

	var closest_index: int = owner._find_closest_brush_preset_index(owner.paint_brush_size)
	update_brush_size_button_states(owner, closest_index)


static func build_vehicle_rotation_controls(owner, parent: Control) -> void:
	var rotation_row := HBoxContainer.new()
	rotation_row.name = "VehicleRotationControls"
	rotation_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotation_row.add_theme_constant_override("separation", 8)
	parent.add_child(rotation_row)

	var rotation_label := Label.new()
	rotation_label.text = "View"
	rotation_row.add_child(rotation_label)

	var rotate_left_button := Button.new()
	rotate_left_button.name = "RotateVehicleLeftButton"
	rotate_left_button.text = "⟲"
	rotate_left_button.tooltip_text = "Rotate left"
	rotate_left_button.pressed.connect(owner._rotate_vehicle_y.bind(-15.0))
	rotation_row.add_child(rotate_left_button)

	var rotate_right_button := Button.new()
	rotate_right_button.name = "RotateVehicleRightButton"
	rotate_right_button.text = "⟳"
	rotate_right_button.tooltip_text = "Rotate right"
	rotate_right_button.pressed.connect(owner._rotate_vehicle_y.bind(15.0))
	rotation_row.add_child(rotate_right_button)

	var rotate_top_button := Button.new()
	rotate_top_button.name = "RotateVehicleTopButton"
	rotate_top_button.text = "Top"
	rotate_top_button.tooltip_text = "Top view"
	rotate_top_button.pressed.connect(owner._set_vehicle_rotation_preset.bind("top"))
	rotation_row.add_child(rotate_top_button)

	var rotate_side_button := Button.new()
	rotate_side_button.name = "RotateVehicleSideButton"
	rotate_side_button.text = "Side"
	rotate_side_button.tooltip_text = "Side view"
	rotate_side_button.pressed.connect(owner._set_vehicle_rotation_preset.bind("side"))
	rotation_row.add_child(rotate_side_button)

	var rotate_bottom_button := Button.new()
	rotate_bottom_button.name = "RotateVehicleBottomButton"
	rotate_bottom_button.text = "Bottom"
	rotate_bottom_button.tooltip_text = "Bottom view"
	rotate_bottom_button.pressed.connect(owner._set_vehicle_rotation_preset.bind("bottom"))
	rotation_row.add_child(rotate_bottom_button)

	var rotate_reset_button := Button.new()
	rotate_reset_button.name = "RotateVehicleResetButton"
	rotate_reset_button.text = "Reset"
	rotate_reset_button.tooltip_text = "Reset view"
	rotate_reset_button.pressed.connect(owner._set_vehicle_rotation_preset.bind("reset"))
	rotation_row.add_child(rotate_reset_button)

	apply_vehicle_rotation(owner, owner.selected_vehicle_rotation)


static func update_brush_size_button_states(owner, selected_index: int) -> void:
	for index in range(owner.brush_size_buttons.size()):
		var button: TextureButton = owner.brush_size_buttons[index] as TextureButton
		button.button_pressed = index == selected_index
		var preset_size := float(owner.BRUSH_PRESETS[index].get("size", owner.paint_brush_size))
		button.texture_normal = vehicle_select_utils.create_brush_size_texture(
			preset_size, index == selected_index
		)
		button.texture_pressed = vehicle_select_utils.create_brush_size_texture(
			preset_size, index == selected_index
		)


static func create_circular_brush_shape(size: int = 256) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.38
	var feather := maxf(size * 0.08, 2.0)
	for y in range(size):
		for x in range(size):
			var pos := Vector2(x + 0.5, y + 0.5)
			var dist := pos.distance_to(center)
			var alpha: float = clamp(1.0 - ((dist - radius) / feather), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return image


static func create_square_brush_shape(size: int = 256) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var half := size * 0.38
	var feather := maxf(size * 0.08, 2.0)
	for y in range(size):
		for x in range(size):
			var pos := Vector2(x + 0.5, y + 0.5) - center
			var max_dist: float = max(abs(pos.x), abs(pos.y))
			var alpha: float = clamp(1.0 - ((max_dist - half) / feather), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return image


static func create_star_brush_shape(size: int = 256) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var outer_radius := size * 0.38
	var inner_radius := outer_radius * 0.42
	var feather := maxf(size * 0.08, 2.0)
	for y in range(size):
		for x in range(size):
			var pos := Vector2(x + 0.5, y + 0.5) - center
			var r := pos.length()
			if r == 0.0:
				image.set_pixel(x, y, Color(1, 1, 1, 1))
				continue
			var angle := atan2(pos.y, pos.x)
			var spoke := (cos(5.0 * angle) * 0.5) + 0.5
			var radius_at_angle: float = lerp(inner_radius, outer_radius, spoke)
			var alpha: float = clamp(1.0 - ((r - radius_at_angle) / feather), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return image


static func create_smoke_brush_shape(size: int = 256) -> Image:
	var texture := load("res://sprites/smoke.png")
	if texture == null or typeof(texture) != TYPE_OBJECT or not texture is Texture2D:
		return create_circular_brush_shape(size)

	var image: Image = Image.new()
	if texture is ImageTexture:
		image = (texture as ImageTexture).get_data()
	elif texture.has_method("get_image"):
		image = texture.get_image()
	else:
		return create_circular_brush_shape(size)

	if image == null or image.get_width() == 0 or image.get_height() == 0:
		return create_circular_brush_shape(size)

	if image.is_compressed():
		image.decompress()

	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	if image.get_width() != size or image.get_height() != size:
		image.resize(size, size, Image.INTERPOLATE_BILINEAR)

	var corner_alpha := maxf(
		maxf(image.get_pixel(0, 0).a, image.get_pixel(size - 1, 0).a),
		maxf(image.get_pixel(0, size - 1).a, image.get_pixel(size - 1, size - 1).a)
	)
	if corner_alpha > 0.05:
		return create_circular_brush_shape(size)

	return image


static func create_brush_shape_preview_texture(shape_id: String, size: int = 64) -> Texture2D:
	var image: Image
	match shape_id:
		"circle":
			image = create_circular_brush_shape(size)
		"square":
			image = create_square_brush_shape(size)
		"star":
			image = create_star_brush_shape(size)
		"smoke":
			image = create_smoke_brush_shape(size)
		_:
			image = create_circular_brush_shape(size)

	return ImageTexture.create_from_image(image)


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
		owner.brush_shape_preview.texture = (
			vehicle_select_utils.create_brush_shape_preview_texture(shape_id, 64)
		)
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


static func apply_vehicle_rotation(owner, rotation_degrees: Vector3) -> void:
	owner.selected_vehicle_rotation = rotation_degrees
	if is_instance_valid(owner.vehicle_preview_instance):
		owner.vehicle_preview_instance.rotation_degrees = rotation_degrees
	log_paint(
		owner,
		owner.PAINT_LOG_LEVEL_INFO,
		"Vehicle rotation updated",
		{
			"vehicle_id": owner.selected_vehicle_id,
			"rotation_degrees": rotation_degrees,
			"preview_instance_ready": is_instance_valid(owner.vehicle_preview_instance),
		},
	)


static func rotate_vehicle_y(owner, delta_degrees: float) -> void:
	var rotation_degrees: Vector3 = owner.selected_vehicle_rotation
	rotation_degrees.y += delta_degrees
	apply_vehicle_rotation(owner, rotation_degrees)


static func set_vehicle_rotation_preset(owner, preset_name: String) -> void:
	var rotation_degrees := Vector3.ZERO
	match preset_name:
		"top":
			rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		"side":
			rotation_degrees = Vector3(0.0, 90.0, 0.0)
		"bottom":
			rotation_degrees = Vector3(90.0, 0.0, 0.0)
		"reset":
			rotation_degrees = Vector3.ZERO
		_:
			rotation_degrees = owner.selected_vehicle_rotation
	apply_vehicle_rotation(owner, rotation_degrees)


static func _get_brush_shape_texture(shape_id: String) -> Image:
	if _brush_shape_texture_cache.has(shape_id):
		return _brush_shape_texture_cache[shape_id]

	var brush_shape_texture: Image
	match shape_id:
		"circle":
			brush_shape_texture = create_circular_brush_shape(256)
		"square":
			brush_shape_texture = create_square_brush_shape(256)
		"star":
			brush_shape_texture = create_star_brush_shape(256)
		"smoke":
			brush_shape_texture = create_smoke_brush_shape(256)
		_:
			brush_shape_texture = create_circular_brush_shape(256)

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
