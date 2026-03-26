class_name TestPlayerVehicleCustomization
extends GdUnitTestSuite


func test_player_vehicle_library_default_scene_exists() -> void:
	var scene_path := PlayerVehicleLibrary.resolve_vehicle_scene_path({})
	assert_that(scene_path.is_empty()).is_false()
	assert_that(ResourceLoader.exists(scene_path)).is_true()


func test_reading_settings_store_persists_vehicle_customization() -> void:
	var store = ReadingSettingsStore.new()
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
	assert_that((phoneme_player._phoneme_player.stream as AudioStreamWAV).loop_mode).is_equal(
		AudioStreamWAV.LOOP_FORWARD
	)


func test_player_vehicle_library_fit_instance_scales_to_max_dimension() -> void:
	var model := MeshInstance3D.new()
	model.mesh = BoxMesh.new()
	var root := Node3D.new()
	root.add_child(model)

	# Without scaling, one axis of the default BoxMesh is 1.0 units (size vector set in mesh).
	PlayerVehicleLibrary.fit_instance_to_dimension(root, 0.5)

	# The root scale should be reduced to fit the desired range.
	assert_that(root.scale.x < 1.0).is_true()
	assert_that(root.scale.y < 1.0).is_true()
	assert_that(root.scale.z < 1.0).is_true()


func test_player_vehicle_library_apply_paint_color_modifies_material() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mesh_instance.mesh = BoxMesh.new()
	mesh_instance.set_surface_override_material(0, mat)

	PlayerVehicleLibrary.apply_paint_color(mesh_instance, Color(0.2, 0.8, 0.3))

	var applied_material := mesh_instance.get_surface_override_material(0) as BaseMaterial3D
	assert_that(applied_material).is_not_null()
	assert_that(applied_material.albedo_color).is_not_equal(mat.albedo_color)
