extends SceneTree

const MATERIALS_DIR := "res://Assets/PolygonIcons/Materials"
const TEXTURES_DIR := "res://Assets/PolygonIcons/Textures"


func _initialize() -> void:
	var texture_paths_by_guid: Dictionary = _build_texture_paths_by_guid(TEXTURES_DIR)
	var material_paths: Array[String] = _collect_files_with_extension(MATERIALS_DIR, ".mat")
	var rebuilt_count := 0
	var skipped_count := 0

	for material_path in material_paths:
		var material_info: Dictionary = _parse_unity_material(material_path)
		if material_info.is_empty():
			print("[PolygonIcons] skip (unparsed): ", material_path)
			skipped_count += 1
			continue

		var material_name := str(material_info.get("name", ""))
		var main_tex_guid := str(material_info.get("main_tex_guid", ""))
		var texture_path: String = str(texture_paths_by_guid.get(main_tex_guid, ""))
		if texture_path == "":
			push_warning(
				"[PolygonIcons] missing texture guid %s for %s" % [main_tex_guid, material_path]
			)
			skipped_count += 1
			continue

		var material := StandardMaterial3D.new()
		material.resource_name = material_name
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.albedo_texture = load(texture_path)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

		var save_error := _save_text_resource(material, material_path)
		print(
			"[PolygonIcons] rebuilt ",
			material_path,
			" save=",
			save_error,
			" texture=",
			texture_path
		)
		if save_error == OK:
			rebuilt_count += 1
		else:
			skipped_count += 1

	print("[PolygonIcons] complete rebuilt=", rebuilt_count, " skipped=", skipped_count)
	quit()


func _collect_files_with_extension(directory_path: String, extension: String) -> Array[String]:
	var file_paths: Array[String] = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		push_error("[PolygonIcons] failed to open directory: %s" % directory_path)
		return file_paths

	directory.list_dir_begin()
	while true:
		var file_name := directory.get_next()
		if file_name == "":
			break
		if directory.current_is_dir():
			continue
		if not file_name.ends_with(extension):
			continue
		file_paths.append(directory_path.path_join(file_name))
	directory.list_dir_end()
	file_paths.sort()
	return file_paths


func _build_texture_paths_by_guid(directory_path: String) -> Dictionary:
	var texture_paths_by_guid: Dictionary = {}
	for meta_path in _collect_files_with_extension(directory_path, ".meta"):
		var guid := _extract_meta_guid(meta_path)
		if guid == "":
			continue
		var texture_path := meta_path.trim_suffix(".meta")
		texture_paths_by_guid[guid] = texture_path
	return texture_paths_by_guid


func _extract_meta_guid(meta_path: String) -> String:
	var file := FileAccess.open(meta_path, FileAccess.READ)
	if file == null:
		return ""

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("guid:"):
			return line.trim_prefix("guid:").strip_edges()
	return ""


func _parse_unity_material(material_path: String) -> Dictionary:
	var file := FileAccess.open(material_path, FileAccess.READ)
	if file == null:
		return {}

	var material_name := ""
	var main_tex_guid := ""
	var current_slot := ""

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("m_Name:"):
			material_name = line.trim_prefix("m_Name:").strip_edges()
			continue
		if line.begins_with("- _") and line.ends_with(":"):
			current_slot = line.trim_prefix("- ").trim_suffix(":")
			continue
		if current_slot == "_MainTex" and line.begins_with("m_Texture:"):
			main_tex_guid = _extract_guid_from_texture_line(line)
			current_slot = ""
			continue
		if line.begins_with("- "):
			current_slot = ""

	if material_name == "" or main_tex_guid == "":
		return {}
	return {
		"name": material_name,
		"main_tex_guid": main_tex_guid,
	}


func _extract_guid_from_texture_line(line: String) -> String:
	var guid_marker := "guid: "
	var guid_start := line.find(guid_marker)
	if guid_start == -1:
		return ""
	guid_start += guid_marker.length()
	var guid_end := line.find(",", guid_start)
	if guid_end == -1:
		guid_end = line.length()
	return line.substr(guid_start, guid_end - guid_start).strip_edges()


func _save_text_resource(resource: Resource, target_path: String) -> Error:
	var temp_path := "%s.tmp.tres" % target_path
	var save_error := ResourceSaver.save(resource, temp_path)
	if save_error != OK:
		return save_error

	var text := FileAccess.get_file_as_string(temp_path)
	var output_file := FileAccess.open(target_path, FileAccess.WRITE)
	if output_file == null:
		DirAccess.remove_absolute(temp_path)
		return ERR_CANT_OPEN

	output_file.store_string(text)
	output_file.flush()
	output_file.close()
	DirAccess.remove_absolute(temp_path)
	return OK
