class_name TestReadingModeHolidays
extends GdUnitTestSuite

const GameplayControllerScript = load("res://scripts/reading/systems/GameplayController.gd")
const ReadingContentLoaderScript = load("res://scripts/reading/content_loader.gd")
const APRIL_DATE_2026 := {"year": 2026, "month": 4, "day": 2}
const EASTER_DATE_2026 := {"year": 2026, "month": 4, "day": 5}
const CHRISTMAS_DATE_2026 := {"year": 2026, "month": 12, "day": 25}
const HALLOWEEN_DATE_2026 := {"year": 2026, "month": 10, "day": 31}
const JANUARY_DATE_2026 := {"year": 2026, "month": 1, "day": 15}
const EASTER_OBSTACLE_PATHS := [
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_1.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_2.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_3.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_4.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_5.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_6.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_7.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_8.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_9.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_10.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_11.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_12.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_13.prefab.scn",
	"res://Assets/Synty/PolygonEaster/Prefabs/SM_Easter_Egg_14.prefab.scn",
]
const EASTER_OBSTACLE_SCALE := 5.0
const CHRISTMAS_OBSTACLE_PATHS := [
	"res://Assets/Synty/PolygonGingerBread/Prefabs/SM_Prop_Gingerbread_CandyCane_01.prefab.scn",
	"res://Assets/Synty/PolygonGingerBread/Prefabs/SM_Prop_Gingerbread_Fence_01.prefab.scn",
	"res://Assets/Synty/PolygonGingerBread/Prefabs/SM_Prop_Gingerbread_House_01.prefab.scn",
	"res://Assets/Synty/PolygonGingerBread/Prefabs/SM_Prop_Gingerbread_Lollypop_01.prefab.scn",
	"res://Assets/Synty/PolygonGingerBread/Prefabs/SM_Prop_Tree_Cookie_Small_01.prefab.scn",
	"res://Assets/Synty/PolygonGingerBread/Prefabs/SM_Prop_Tree_Cookie_Large_01.prefab.scn",
]


func test_reading_settings_store_holiday_resolution() -> void:
	var store = ReadingSettingsStore.new()
	var auto_settings = ReadingSettingsStore.default_settings()

	assert_that(store.resolve_effective_holiday(auto_settings, APRIL_DATE_2026)).is_equal(
		ReadingSettingsStore.HOLIDAY_EASTER
	)
	assert_that(store.resolve_effective_holiday(auto_settings, EASTER_DATE_2026)).is_equal(
		ReadingSettingsStore.HOLIDAY_EASTER
	)
	assert_that(store.resolve_effective_holiday(auto_settings, CHRISTMAS_DATE_2026)).is_equal(
		ReadingSettingsStore.HOLIDAY_CHRISTMAS
	)
	assert_that(store.resolve_effective_holiday(auto_settings, HALLOWEEN_DATE_2026)).is_equal(
		ReadingSettingsStore.HOLIDAY_HALLOWEEN
	)
	assert_that(store.resolve_effective_holiday(auto_settings, JANUARY_DATE_2026)).is_equal(
		ReadingSettingsStore.HOLIDAY_NONE
	)

	var on_settings = ReadingSettingsStore.default_settings()
	on_settings["holiday_mode"] = ReadingSettingsStore.HOLIDAY_MODE_ON
	on_settings["holiday_name"] = ReadingSettingsStore.HOLIDAY_EASTER
	assert_that(store.resolve_effective_holiday(on_settings, EASTER_DATE_2026)).is_equal(
		ReadingSettingsStore.HOLIDAY_EASTER
	)
	assert_that(store.resolve_effective_holiday(on_settings, CHRISTMAS_DATE_2026)).is_equal(
		ReadingSettingsStore.HOLIDAY_EASTER
	)

	on_settings["holiday_name"] = ReadingSettingsStore.HOLIDAY_CHRISTMAS
	assert_that(store.resolve_effective_holiday(on_settings, CHRISTMAS_DATE_2026)).is_equal(
		ReadingSettingsStore.HOLIDAY_CHRISTMAS
	)

	var off_settings = ReadingSettingsStore.default_settings()
	off_settings["holiday_mode"] = ReadingSettingsStore.HOLIDAY_MODE_OFF
	off_settings["holiday_name"] = ReadingSettingsStore.HOLIDAY_EASTER
	assert_that(store.resolve_effective_holiday(off_settings, EASTER_DATE_2026)).is_equal(
		ReadingSettingsStore.HOLIDAY_NONE
	)


func test_obstacle_config_loading_and_random_choice() -> void:
	var config = ObstacleConfig.new()
	var item = config.choose_random_obstacle(
		"sightwords", ReadingSettingsStore.HOLIDAY_NONE, RandomNumberGenerator.new()
	)
	assert_that(item).is_not_null()
	assert_that(item.has("model_path")).is_true()
	assert_that(item.has("sound_paths")).is_true()


func test_obstacle_config_uses_easter_obstacles_when_holiday_is_active() -> void:
	var config = ObstacleConfig.new()
	var options = config.get_obstacle_list_for("sightwords", ReadingSettingsStore.HOLIDAY_EASTER)
	assert_that(options.size()).is_greater(10)
	for expected_path in EASTER_OBSTACLE_PATHS:
		var found := false
		for option in options:
			if str((option as Dictionary).get("model_path", "")) == expected_path:
				assert_that(float((option as Dictionary).get("scale", 1.0))).is_equal(
					EASTER_OBSTACLE_SCALE
				)
				found = true
				break
		assert_that(found).is_true()


func test_obstacle_config_uses_christmas_obstacles_when_holiday_is_active() -> void:
	var config = ObstacleConfig.new()
	var options = config.get_obstacle_list_for("sightwords", ReadingSettingsStore.HOLIDAY_CHRISTMAS)
	assert_that(options.size()).is_greater(2)
	for expected_path in CHRISTMAS_OBSTACLE_PATHS:
		var found := false
		for option in options:
			if str((option as Dictionary).get("model_path", "")) == expected_path:
				found = true
				break
		assert_that(found).is_true()


func test_holiday_prefabs_load_with_textured_materials() -> void:
	var controller := GameplayControllerScript.new(ReadingContentLoaderScript.new())
	var sample_paths := [
		EASTER_OBSTACLE_PATHS[0],
		CHRISTMAS_OBSTACLE_PATHS[2],
		"res://Assets/PolygonIcons/Models/SM_Icon_Text_A.fbx",
		"res://Assets/PolygonIcons/Models/SM_Icon_Play_01.fbx",
	]

	for sample_path in sample_paths:
		var scene := controller._instantiate_scene(sample_path)
		assert_that(scene).is_not_null()
		assert_that(_count_missing_holiday_textures(scene)).is_equal(0)


func test_polygon_icon_models_keep_textured_materials() -> void:
	var controller := GameplayControllerScript.new(ReadingContentLoaderScript.new())
	var sample_paths := [
		"res://Assets/PolygonIcons/Models/SM_Icon_Text_A.fbx",
		"res://Assets/PolygonIcons/Models/SM_Icon_Play_01.fbx",
	]

	for sample_path in sample_paths:
		var scene := controller._instantiate_scene(sample_path)
		assert_that(scene).is_not_null()
		assert_that(_count_textured_polygon_icon_materials(scene)).is_greater(0)


func _count_missing_holiday_textures(node: Node) -> int:
	var missing_count := 0
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh is ArrayMesh:
			var array_mesh := mesh_instance.mesh as ArrayMesh
			for surface_index in range(array_mesh.get_surface_count()):
				var material := mesh_instance.get_surface_override_material(surface_index)
				if material == null:
					material = array_mesh.surface_get_material(surface_index)
				var material_name := ""
				if material != null:
					material_name = str(material.resource_name)
				if not (
					material_name.begins_with("PolygonIcons_Mat_")
					or material_name.begins_with("PolygonEaster_")
					or material_name.begins_with("PolygonGingerBread_")
				):
					continue
				if material == null:
					missing_count += 1
				elif material is StandardMaterial3D:
					if (material as StandardMaterial3D).albedo_texture == null:
						missing_count += 1

	for child in node.get_children():
		missing_count += _count_missing_holiday_textures(child)

	return missing_count


func _count_textured_polygon_icon_materials(node: Node) -> int:
	var textured_count := 0
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh is Mesh:
			var mesh := mesh_instance.mesh as Mesh
			for surface_index in range(mesh.get_surface_count()):
				var material := mesh_instance.get_surface_override_material(surface_index)
				if material == null:
					material = mesh.surface_get_material(surface_index)
				if material is StandardMaterial3D:
					var standard_material := material as StandardMaterial3D
					if standard_material.albedo_texture != null:
						textured_count += 1

	for child in node.get_children():
		textured_count += _count_textured_polygon_icon_materials(child)

	return textured_count
