class_name VehicleSelectUtils
extends RefCounted

const _BRUSH_SHAPE_RESOURCE_PATHS := {
	"circle": "res://sprites/brush_shapes/circle_brush_shape.webp",
	"square": "res://sprites/brush_shapes/square_brush_shape.webp",
	"star": "res://sprites/brush_shapes/star_brush_shape.webp",
	"smoke": "res://sprites/brush_shapes/smoke_brush_shape.webp",
}


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
	var radius := size * 0.38
	var feather := maxf(size * 0.08, 2.0)
	for y in range(size):
		for x in range(size):
			var pos = Vector2(x + 0.5, y + 0.5)
			var dist = pos.distance_to(center)
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
			var pos = Vector2(x + 0.5, y + 0.5) - center
			var max_dist = max(abs(pos.x), abs(pos.y))
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
			var pos = Vector2(x + 0.5, y + 0.5) - center
			var r = pos.length()
			if r == 0.0:
				image.set_pixel(x, y, Color(1, 1, 1, 1))
				continue
			var angle = atan2(pos.y, pos.x)
			var spoke = (cos(5.0 * angle) * 0.5) + 0.5
			var radius_at_angle = lerp(inner_radius, outer_radius, spoke)
			var alpha: float = clamp(1.0 - ((r - radius_at_angle) / feather), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return image


static func create_smoke_brush_shape(size: int = 256) -> Image:
	var texture := load("res://sprites/smoke.png")
	if texture == null:
		return create_circular_brush_shape(size)

	if typeof(texture) != TYPE_OBJECT or not texture is Texture2D:
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

	return image


static func create_brush_shape_preview_texture(shape_id: String, size: int = 64) -> Texture2D:
	var image := _load_brush_shape_image(shape_id, size)

	var texture := ImageTexture.create_from_image(image)
	return texture


static func _load_brush_shape_image(shape_id: String, size: int) -> Image:
	var normalized_shape_id := shape_id.strip_edges().to_lower()
	if _BRUSH_SHAPE_RESOURCE_PATHS.has(normalized_shape_id):
		var resource_path := str(_BRUSH_SHAPE_RESOURCE_PATHS[normalized_shape_id])
		if ResourceLoader.exists(resource_path):
			var resource := load(resource_path)
			var loaded_image := _resource_to_image(resource)
			if (
				loaded_image != null
				and loaded_image.get_width() > 0
				and loaded_image.get_height() > 0
			):
				if loaded_image.get_width() != size or loaded_image.get_height() != size:
					loaded_image = loaded_image.duplicate()
					loaded_image.resize(size, size, Image.INTERPOLATE_BILINEAR)
				return loaded_image

	match normalized_shape_id:
		"circle":
			return create_circular_brush_shape(size)
		"square":
			return create_square_brush_shape(size)
		"star":
			return create_star_brush_shape(size)
		"smoke":
			return create_smoke_brush_shape(size)
		_:
			return create_circular_brush_shape(size)


static func _resource_to_image(resource: Variant) -> Image:
	if resource is Image:
		return resource as Image
	if resource is Texture2D:
		var texture_image := (resource as Texture2D).get_image()
		if texture_image != null:
			return texture_image
	return null


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
