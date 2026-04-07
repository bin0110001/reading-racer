extends SceneTree


func _initialize() -> void:
	var material_specs := [
		{
			"path": "res://Assets/Synty/PolygonEaster/Materials/PolygonEaster_01.material",
			"resource_name": "PolygonEaster_01",
			"albedo": "res://Assets/Synty/PolygonEaster/Textures/PolygonEaster_01.png",
			"normal": "",
		},
		{
			"path":
			"res://Assets/Synty/PolygonGingerBread/Materials/PolygonGingerbread_01_A.material",
			"resource_name": "PolygonGingerbread_01_A",
			"albedo": "res://Assets/Synty/PolygonGingerBread/Textures/PolygonGingerbread_01_A.png",
			"normal":
			"res://Assets/Synty/PolygonGingerBread/Textures/PolygonGingerbread_01_Normals.png",
		},
	]

	for spec in material_specs:
		var material := StandardMaterial3D.new()
		material.resource_name = spec["resource_name"]
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.albedo_texture = load(spec["albedo"])
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if spec["normal"] != "":
			material.normal_enabled = true
			material.normal_texture = load(spec["normal"])
		var error := ResourceSaver.save(material, spec["path"])
		print(spec["path"], " save=", error)
		print("  albedo=", material.albedo_texture, " normal=", material.normal_texture)
	quit()
