class_name TestPlayerVehicleCustomization
extends GdUnitTestSuite

const PlayerVehicleLibrary = preload("res://scripts/reading/player_vehicle_library.gd")


func test_player_vehicle_library_default_scene_exists() -> void:
	var scene_path := PlayerVehicleLibrary.resolve_vehicle_scene_path({})
	assert_that(scene_path.is_empty()).is_false()
	assert_that(ResourceLoader.exists(scene_path)).is_true()


func test_reading_settings_store_persists_vehicle_customization() -> void:
	var store = ReadingSettingsStore.new()
	assert_that(store).is_not_null()
	var original_settings := store.load_settings()
	var updated_settings := store.default_settings()
	updated_settings[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_ID] = "mail_truck"
	updated_settings[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_SCENE_PATH] = (
		PlayerVehicleLibrary.get_vehicle_scene_path("mail_truck")
	)
	updated_settings[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_COLOR] = "d14b32ff"

	store.save_settings(updated_settings)
	var loaded_settings := store.load_settings()

	assert_that(loaded_settings.get(PlayerVehicleLibrary.SETTING_KEY_VEHICLE_ID, "")).is_equal(
		"mail_truck"
	)
	(
		assert_that(loaded_settings.get(PlayerVehicleLibrary.SETTING_KEY_VEHICLE_SCENE_PATH, ""))
		. is_equal(PlayerVehicleLibrary.get_vehicle_scene_path("mail_truck"))
	)
	assert_that(loaded_settings.get(PlayerVehicleLibrary.SETTING_KEY_VEHICLE_COLOR, "")).is_equal(
		"d14b32ff"
	)

	store.save_settings(original_settings)


func test_phoneme_player_leaves_source_stream_unmodified_when_looping() -> void:
	var phoneme_player := PhonemePlayer.new()
	phoneme_player._ready()

	var source_stream := AudioStreamWAV.new()
	source_stream.mix_rate = 44100
	source_stream.format = AudioStreamWAV.FORMAT_16_BITS
	source_stream.stereo = false
	source_stream.data = PackedByteArray([0, 0, 0, 0])

	phoneme_player.play_looping_phoneme("b", source_stream)

	assert_that(source_stream.loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)
	assert_that(phoneme_player._phoneme_player.stream).is_same(source_stream)
	var finished_connection := Callable(phoneme_player, "_on_phoneme_player_finished")
	(
		assert_that(phoneme_player._phoneme_player.is_connected("finished", finished_connection))
		. is_true()
	)


func test_player_vehicle_library_fit_instance_scales_to_max_dimension() -> void:
	var player_library = PlayerVehicleLibrary.new()
	var model := MeshInstance3D.new()
	model.mesh = BoxMesh.new()
	var root := Node3D.new()
	root.add_child(model)

	# Without scaling, one axis of the default BoxMesh is 1.0 units (size vector set in mesh).
	player_library.fit_instance_to_dimension_instance(root, 0.5)

	# The root scale should be reduced to fit the desired range.
	assert_that(root.scale.x < 1.0).is_true()
	assert_that(root.scale.y < 1.0).is_true()
	assert_that(root.scale.z < 1.0).is_true()


func test_player_vehicle_library_apply_paint_color_modifies_material() -> void:
	var player_library = PlayerVehicleLibrary.new()
	var mesh_instance := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mesh_instance.mesh = BoxMesh.new()
	mesh_instance.set_surface_override_material(0, mat)

	player_library.apply_paint_color_instance(mesh_instance, Color(0.2, 0.8, 0.3))

	var applied_material := mesh_instance.get_surface_override_material(0) as BaseMaterial3D
	assert_that(applied_material).is_not_null()
	assert_that(applied_material.albedo_color).is_not_equal(mat.albedo_color)


func test_player_vehicle_library_apply_vehicle_decals_adds_decal_nodes() -> void:
	var player_library = PlayerVehicleLibrary.new()
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)

	var decals := [
		{
			"position": {"x": 0.0, "y": 0.5, "z": 0.0},
			"normal": {"x": 0.0, "y": 1.0, "z": 0.0},
			"color": "ff0000ff",
			"size": 0.25,
		}
	]

	player_library.apply_vehicle_decals_instance(root, decals)

	var decal_count := 0
	for child in root.get_children():
		if child is Decal:
			decal_count += 1

	assert_that(decal_count).is_equal(1)


func test_build_vehicle_settings_persists_empty_decals() -> void:
	var settings := PlayerVehicleLibrary.build_vehicle_settings("mail_truck", Color(1, 0, 0), [])
	assert_that(settings.has(PlayerVehicleLibrary.SETTING_KEY_VEHICLE_DECALS)).is_true()
	assert_that(settings[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_DECALS].size()).is_equal(0)


func test_player_vehicle_library_sets_overlay_lightmap_hints() -> void:
	var player_library = PlayerVehicleLibrary.new()
	var settings_store = ReadingSettingsStore.new()
	var vehicle := player_library.instantiate_vehicle_from_settings(
		settings_store.default_settings(), PlayerVehicleLibrary.PREVIEW_MAX_DIMENSION
	)
	assert_that(vehicle).is_not_null()

	var mesh_instance := _find_first_mesh_instance(vehicle)
	assert_that(mesh_instance).is_not_null()
	assert_that(mesh_instance.mesh).is_not_null()
	assert_that(mesh_instance.mesh.lightmap_size_hint != Vector2i.ZERO).is_true()

	vehicle.queue_free()


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found
	return null
