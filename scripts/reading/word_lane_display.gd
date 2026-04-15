class_name ReadingWordLaneDisplay
extends Node3D

const WorldTextBuilder = preload("res://scripts/reading/word_text_builder.gd")

const LETTER_MODEL_PREFAB_BASE := "res://Assets/PolygonIcons/Prefabs/SM_Icon_Text_%s.prefab"
const LETTER_MODEL_FBX_BASE := "res://Assets/PolygonIcons/Models/SM_Icon_Text_%s.fbx"

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
				return scene_instance as Node3D
		elif resource is Mesh:
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = resource
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


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found
	return null
