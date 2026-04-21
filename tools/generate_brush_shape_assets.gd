extends SceneTree

const OUTPUT_DIR := "res://sprites/brush_shapes"
const OUTPUT_SIZE := 256


func _initialize() -> void:
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)

	var shapes := {
		"circle": _create_circular_brush_shape(OUTPUT_SIZE),
		"square": _create_square_brush_shape(OUTPUT_SIZE),
		"star": _create_star_brush_shape(OUTPUT_SIZE),
		"smoke": _create_smoke_brush_shape(OUTPUT_SIZE),
	}

	for shape_id in shapes.keys():
		var image: Image = shapes[shape_id]
		var output_path := "%s/%s_brush_shape.webp" % [output_dir, shape_id]
		var error := image.save_webp(output_path)
		print("Saved ", shape_id, " brush shape to ", output_path, " -> ", error)

	quit()


func _create_circular_brush_shape(size: int) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
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


func _create_square_brush_shape(size: int) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
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


func _create_star_brush_shape(size: int) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
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


func _create_smoke_brush_shape(size: int) -> Image:
	var texture := load("res://sprites/smoke.png")
	if texture == null or typeof(texture) != TYPE_OBJECT or not texture is Texture2D:
		return _create_circular_brush_shape(size)

	var image: Image = Image.new()
	if texture is ImageTexture:
		image = (texture as ImageTexture).get_data()
	elif texture.has_method("get_image"):
		image = texture.get_image()
	else:
		return _create_circular_brush_shape(size)

	if image == null or image.get_width() == 0 or image.get_height() == 0:
		return _create_circular_brush_shape(size)

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
		return _create_circular_brush_shape(size)

	return image
