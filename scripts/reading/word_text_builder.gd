class_name ReadingWorldTextBuilder
extends RefCounted


static func create_billboard_label(
	text: String,
	font_size: int,
	modulate_color: Color,
	outline_size: int = 0,
	billboard_mode: BaseMaterial3D.BillboardMode = BaseMaterial3D.BILLBOARD_ENABLED,
	position: Vector3 = Vector3.ZERO,
	scale: Vector3 = Vector3.ONE,
	rotation: Vector3 = Vector3.ZERO,
) -> Label3D:
	var label := Label3D.new()
	label.text = str(text)
	label.billboard = billboard_mode
	label.font_size = font_size
	label.modulate = modulate_color
	label.outline_size = outline_size
	label.position = position
	label.scale = scale
	label.rotation = rotation
	return label


static func build_word_node(
	word_text: String,
	p_create_glyph_visual: Callable,
	letter_spacing: float = 1.1,
	center_word: bool = true,
) -> Node3D:
	var word_root := Node3D.new()
	var normalized_word := str(word_text).strip_edges()
	if normalized_word.is_empty():
		return word_root

	var glyph_count := normalized_word.length()
	var width_offset := 0.0
	if center_word and glyph_count > 1:
		width_offset = float(glyph_count - 1) * letter_spacing * 0.5

	for glyph_index in range(glyph_count):
		var glyph_text := normalized_word.substr(glyph_index, 1)
		var glyph_visual: Node3D = p_create_glyph_visual.call(glyph_text, glyph_index)
		if glyph_visual == null:
			continue
		glyph_visual.position = Vector3(
			float(glyph_index) * letter_spacing - width_offset, 0.0, 0.0
		)
		word_root.add_child(glyph_visual)

	return word_root
