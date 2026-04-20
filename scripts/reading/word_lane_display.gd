class_name ReadingWordLaneDisplay
extends Node3D

const WorldTextBuilder = preload("res://scripts/reading/word_text_builder.gd")

const LETTER_MODEL_PREFAB_BASE := "res://Assets/PolygonIcons/Prefabs/SM_Icon_Text_%s.prefab"
const LETTER_MODEL_FBX_BASE := "res://Assets/PolygonIcons/Models/SM_Icon_Text_%s.fbx"
const DEFAULT_GLYPH_TINT := Color(0.1, 0.35, 0.8, 1.0)

const DEFAULT_TARGET_WIDTH := 8.0
const DEFAULT_LETTER_GAP := 0.18
const MIN_SCALE := 0.12
const MAX_SCALE := 3.5

var text := ""
var target_width := DEFAULT_TARGET_WIDTH
var letter_gap := DEFAULT_LETTER_GAP
var word_scale := 1.0
var word_width := 0.0


func configure(
	next_text: String,
	next_target_width: float = DEFAULT_TARGET_WIDTH,
	next_letter_gap: float = DEFAULT_LETTER_GAP,
) -> void:
	text = str(next_text)
	target_width = maxf(next_target_width, 0.1)
	letter_gap = maxf(next_letter_gap, 0.0)
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	rotation_degrees = Vector3(0.0, 270.0, 0.0)
	word_scale = 1.0
	word_width = 0.0
	var normalized_word := text.strip_edges()
	if normalized_word.is_empty():
		return

	var glyph_specs: Array[Dictionary] = []
	var unscaled_width := 0.0
	for glyph_index in range(normalized_word.length()):
		var glyph_text := normalized_word.substr(glyph_index, 1)
		var glyph_node := _create_glyph_node(glyph_text)
		if glyph_node == null:
			continue

		var glyph_bounds := _measure_node_bounds(glyph_node)
		var glyph_width := maxf(glyph_bounds.size.x, 0.01)
		var glyph_center := glyph_bounds.position + glyph_bounds.size * 0.5
		(
			glyph_specs
			. append(
				{
					"node": glyph_node,
					"width": glyph_width,
					"center": glyph_center,
				}
			)
		)
		unscaled_width += glyph_width

	if glyph_specs.is_empty():
		return

	if glyph_specs.size() > 1:
		unscaled_width += letter_gap * float(glyph_specs.size() - 1)

	if unscaled_width <= 0.0:
		return

	word_scale = clampf(target_width / unscaled_width, MIN_SCALE, MAX_SCALE)
	word_width = unscaled_width * word_scale

	var cursor := -word_width * 0.5
	for spec in glyph_specs:
		var glyph_node: Node3D = spec.get("node") as Node3D
		var glyph_width := float(spec.get("width", 1.0)) * word_scale
		var glyph_center := spec.get("center", Vector3.ZERO) as Vector3

		glyph_node.position = -glyph_center

		var holder := Node3D.new()
		holder.position = Vector3(cursor + glyph_width * 0.5, 0.0, 0.0)
		holder.scale = Vector3.ONE * word_scale
		holder.add_child(glyph_node)
		add_child(holder)

		cursor += glyph_width + letter_gap * word_scale


func _create_glyph_node(glyph_text: String) -> Node3D:
	var normalized := str(glyph_text).strip_edges()
	if normalized.is_empty():
		return null

	var resource_paths := _get_glyph_resource_paths(normalized)
	for resource_path in resource_paths:
		if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
			continue

		var resource := load(resource_path)
		if resource is PackedScene:
			var scene_instance := (resource as PackedScene).instantiate()
			if scene_instance is Node3D:
				_tint_mesh_nodes(scene_instance as Node, DEFAULT_GLYPH_TINT)
				return scene_instance as Node3D
		elif resource is Mesh:
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = resource
			_tint_mesh_instance(mesh_instance, DEFAULT_GLYPH_TINT)
			return mesh_instance

	return _create_label_fallback(normalized)


func _create_label_fallback(glyph_text: String) -> Node3D:
	return (
		WorldTextBuilder
		. create_billboard_label(
			glyph_text.to_upper(),
			256,
			Color(1.0, 0.9, 0.45),
			24,
			BaseMaterial3D.BILLBOARD_ENABLED,
		)
	)


func _get_glyph_resource_paths(glyph_text: String) -> Array[String]:
	var normalized := glyph_text.to_upper()
	var resource_key := normalized

	if normalized == ",":
		resource_key = "Comma"
	elif normalized == ".":
		resource_key = "Period"
	elif (
		normalized.length() == 1
		and normalized.unicode_at(0) >= 48
		and normalized.unicode_at(0) <= 57
	):
		resource_key = normalized
	elif (
		normalized.length() != 1
		or not (normalized.unicode_at(0) >= 65 and normalized.unicode_at(0) <= 90)
	):
		return []

	return [
		LETTER_MODEL_PREFAB_BASE % resource_key,
		LETTER_MODEL_FBX_BASE % resource_key,
	]


func _measure_node_bounds(node: Node) -> AABB:
	var mesh_instance := _find_first_mesh_instance(node)
	if mesh_instance != null:
		var mesh_bounds := mesh_instance.get_aabb()
		if mesh_bounds.size.length_squared() > 0.0:
			return mesh_bounds

	return AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)


static func _tint_mesh_nodes(node: Node, tint_color: Color) -> void:
	if node is MeshInstance3D:
		_tint_mesh_instance(node as MeshInstance3D, tint_color)

	for child in node.get_children():
		if child is Node:
			_tint_mesh_nodes(child as Node, tint_color)


static func _tint_mesh_instance(mesh_instance: MeshInstance3D, tint_color: Color) -> int:
	if mesh_instance.mesh == null:
		return 0

	var tinted_surfaces := 0
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var override_material := mesh_instance.get_surface_override_material(surface_index)
		var base_material := override_material
		if base_material == null:
			base_material = mesh_instance.mesh.surface_get_material(surface_index)
		if not (base_material is BaseMaterial3D):
			continue

		var duplicated := (base_material as BaseMaterial3D).duplicate(true) as BaseMaterial3D
		var source_color := duplicated.albedo_color
		if source_color == Color.WHITE:
			duplicated.albedo_color = tint_color
		else:
			duplicated.albedo_color = source_color.lerp(tint_color, 0.7)
		mesh_instance.set_surface_override_material(surface_index, duplicated)
		tinted_surfaces += 1

	return tinted_surfaces


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found
	return null
