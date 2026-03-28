class_name VehicleSelectUtils
extends RefCounted


static func create_brush_size_texture(brush_size: float, selected: bool) -> Texture2D:
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


static func create_color_swatch_texture(color: Color, selected: bool) -> Texture2D:
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


static func create_circular_brush_shape(size: int = 256) -> Image:
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


static func find_closest_brush_preset_index(brush_size: float, brush_presets: Array) -> int:
	var closest_index := 0
	var closest_distance := INF
	for index in range(brush_presets.size()):
		var preset_size := float(brush_presets[index].get("size", brush_size))
		var distance := absf(preset_size - brush_size)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index


static func find_closest_paint_color_index(color: Color, color_options: Array) -> int:
	var closest_index := 0
	var closest_distance := INF
	for index in range(color_options.size()):
		var option_color: Color = color_options[index]
		var distance := (
			absf(option_color.r - color.r)
			+ absf(option_color.g - color.g)
			+ absf(option_color.b - color.b)
		)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index
