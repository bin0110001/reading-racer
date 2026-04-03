class_name TestReadingModeHolidays
extends GdUnitTestSuite

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
	var auto_settings = store.default_settings()

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

	var on_settings = store.default_settings()
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

	var off_settings = store.default_settings()
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
