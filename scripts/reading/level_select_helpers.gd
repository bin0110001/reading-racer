class_name LevelSelectHelpers
extends Object


static func _format_level_group_name(group: String) -> String:
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


static func _apply_level_button_style(button: Button, _is_selected: bool) -> void:
	if button == null:
		return

	button.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	button.add_theme_font_size_override("font_size", 28)
	var normal_style := _create_level_button_stylebox(
		Color(0.15, 0.18, 0.23, 0.98), Color(0.34, 0.40, 0.48, 1.0), false
	)
	var hover_style := _create_level_button_stylebox(
		Color(0.20, 0.24, 0.30, 1.0), Color(0.48, 0.54, 0.62, 1.0), false
	)
	var pressed_style := _create_level_button_stylebox(
		Color(0.18, 0.20, 0.26, 1.0), Color(0.42, 0.48, 0.56, 1.0), false
	)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", hover_style)


static func _apply_grade_button_style(button: Button, is_selected: bool) -> void:
	if button == null:
		return

	button.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	button.add_theme_font_size_override("font_size", 24)
	var background := Color(0.18, 0.22, 0.28, 0.98)
	var border := Color(0.42, 0.52, 0.64, 1.0)
	if is_selected:
		background = Color(0.24, 0.36, 0.52, 1.0)
		border = Color(0.94, 0.76, 0.28, 1.0)
	var normal_style := _create_level_button_stylebox(background, border, is_selected)
	var hover_style := _create_level_button_stylebox(
		Color(0.26, 0.34, 0.48, 1.0), Color(0.76, 0.62, 0.22, 1.0), is_selected
	)
	var pressed_style := _create_level_button_stylebox(
		Color(0.22, 0.30, 0.42, 1.0), Color(0.64, 0.52, 0.18, 1.0), is_selected
	)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", hover_style)


static func _create_level_button_stylebox(
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


static func _create_steering_button_stylebox(
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


static func _apply_menu_icon(button: Button, icon_texture: Texture2D) -> void:
	if button == null:
		return
	button.icon = icon_texture
	button.custom_minimum_size = Vector2(120.0, 120.0)
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_NONE
	button.icon_alignment = 1
	button.vertical_icon_alignment = 1

	button.text = ""


static func _load_svg_icon_texture(svg_path: String) -> Texture2D:
	var image := Image.load_from_file(svg_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


static func _find_node_by_name_token(node: Node, token: String) -> Node:
	if node.name.find(token) >= 0:
		return node
	for child in node.get_children():
		if child is Node:
			var found = _find_node_by_name_token(child, token)
			if found != null:
				return found
	return null
