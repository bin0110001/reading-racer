class_name ReadingSettingsStore
extends RefCounted

const PlayerVehicleLibraryScript = preload("res://scripts/reading/player_vehicle_library.gd")

const SAVE_PATH := "user://reading_racer_settings.cfg"
const CONTROL_MODE_KEYBOARD := "keyboard"
const CONTROL_MODE_SWIPE := "swipe"
const CONTROL_MODE_TILT := "tilt"
const CONTROL_MODES := [
	CONTROL_MODE_KEYBOARD,
	CONTROL_MODE_SWIPE,
	CONTROL_MODE_TILT,
]
const STEERING_TYPE_LANE_CHANGE := "lane_change"
const STEERING_TYPE_SMOOTH_STEERING := "smooth_steering"
const STEERING_TYPE_THROTTLE_STEERING := "throttle_steering"
const STEERING_TYPES := [
	STEERING_TYPE_LANE_CHANGE,
	STEERING_TYPE_SMOOTH_STEERING,
	STEERING_TYPE_THROTTLE_STEERING,
]
const MAP_STYLE_CIRCULAR := "circular"
const MAP_STYLE_SERPENTINE := "serpentine"
const MAP_STYLE_STRAIGHT := "straight"
const MAP_STYLES := [
	MAP_STYLE_CIRCULAR,
	MAP_STYLE_SERPENTINE,
	MAP_STYLE_STRAIGHT,
]

const HOLIDAY_NONE := "none"
const HOLIDAY_CHRISTMAS := "christmas"
const HOLIDAY_EASTER := "easter"
const HOLIDAY_HALLOWEEN := "halloween"
const HOLIDAY_OPTIONS := [HOLIDAY_NONE, HOLIDAY_CHRISTMAS, HOLIDAY_HALLOWEEN, HOLIDAY_EASTER]

const HOLIDAY_MODE_AUTO := "auto"
const HOLIDAY_MODE_ON := "on"
const HOLIDAY_MODE_OFF := "off"
const HOLIDAY_MODES := [HOLIDAY_MODE_AUTO, HOLIDAY_MODE_ON, HOLIDAY_MODE_OFF]


static func default_settings() -> Dictionary:
	return {
		"control_mode": CONTROL_MODE_KEYBOARD,
		"word_group": "sightwords",
		"master_volume": 0.8,
		"random_word_order": false,
		"steering_type": STEERING_TYPE_LANE_CHANGE,
		"map_style": MAP_STYLE_CIRCULAR,
		"holiday_mode": HOLIDAY_MODE_AUTO,
		"holiday_name": HOLIDAY_NONE,
		PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_ID:
		PlayerVehicleLibraryScript.DEFAULT_VEHICLE_ID,
		PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_SCENE_PATH:
		PlayerVehicleLibraryScript.get_vehicle_scene_path(
			PlayerVehicleLibraryScript.DEFAULT_VEHICLE_ID
		),
		PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_COLOR:
		PlayerVehicleLibraryScript.DEFAULT_PAINT_COLOR_HEX,
		PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_DECALS: [],
		"paint_brush_size": 0.35,
		"paint_brush_shape": "circle",
	}


func load_settings() -> Dictionary:
	var settings := default_settings()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return settings

	settings["control_mode"] = str(
		config.get_value("reading", "control_mode", settings["control_mode"])
	)
	settings["word_group"] = str(config.get_value("reading", "word_group", settings["word_group"]))
	settings["master_volume"] = clampf(
		float(config.get_value("reading", "master_volume", settings["master_volume"])), 0.0, 1.0
	)
	settings["random_word_order"] = bool(
		config.get_value("reading", "random_word_order", settings["random_word_order"])
	)
	settings["steering_type"] = str(
		config.get_value("reading", "steering_type", settings["steering_type"])
	)
	settings["map_style"] = str(config.get_value("reading", "map_style", settings["map_style"]))
	settings["holiday_mode"] = str(
		config.get_value("reading", "holiday_mode", settings["holiday_mode"])
	)
	settings["holiday_name"] = str(
		config.get_value("reading", "holiday_name", settings["holiday_name"])
	)
	settings[PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_ID] = str(
		config.get_value(
			"reading",
			PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_ID,
			settings[PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_ID]
		)
	)
	settings[PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_SCENE_PATH] = str(
		config.get_value(
			"reading",
			PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_SCENE_PATH,
			settings[PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_SCENE_PATH]
		)
	)
	settings[PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_COLOR] = str(
		config.get_value(
			"reading",
			PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_COLOR,
			settings[PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_COLOR]
		)
	)

	var raw_decals := str(
		config.get_value("reading", PlayerVehicleLibraryScript.SETTING_KEY_VEHICLE_DECALS, "[]")
	)
	var parsed = JSON.parse_string(raw_decals)
	if parsed is Array:
		settings[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_DECALS] = parsed
	else:
		settings[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_DECALS] = []
	settings["paint_brush_size"] = clampf(
		float(config.get_value("reading", "paint_brush_size", settings["paint_brush_size"])),
		0.05,
		2.0
	)
	settings["paint_brush_shape"] = str(
		config.get_value("reading", "paint_brush_shape", settings["paint_brush_shape"])
	)
	return settings


func save_settings(settings: Dictionary) -> void:
	var merged := default_settings()
	for key in settings.keys():
		merged[key] = settings[key]

	var config := ConfigFile.new()
	config.set_value("reading", "control_mode", str(merged["control_mode"]))
	config.set_value("reading", "word_group", str(merged["word_group"]))
	config.set_value("reading", "master_volume", clampf(float(merged["master_volume"]), 0.0, 1.0))
	config.set_value("reading", "random_word_order", bool(merged["random_word_order"]))
	config.set_value("reading", "steering_type", str(merged["steering_type"]))
	config.set_value("reading", "map_style", str(merged["map_style"]))
	config.set_value("reading", "holiday_mode", str(merged["holiday_mode"]))
	config.set_value("reading", "holiday_name", str(merged["holiday_name"]))
	config.set_value(
		"reading",
		PlayerVehicleLibrary.SETTING_KEY_VEHICLE_ID,
		str(merged[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_ID])
	)
	config.set_value(
		"reading",
		PlayerVehicleLibrary.SETTING_KEY_VEHICLE_SCENE_PATH,
		str(merged[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_SCENE_PATH])
	)
	config.set_value(
		"reading",
		PlayerVehicleLibrary.SETTING_KEY_VEHICLE_COLOR,
		str(merged[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_COLOR])
	)
	config.set_value(
		"reading",
		PlayerVehicleLibrary.SETTING_KEY_VEHICLE_DECALS,
		JSON.stringify(merged[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_DECALS])
	)
	config.set_value("reading", "paint_brush_size", str(merged["paint_brush_size"]))
	config.set_value("reading", "paint_brush_shape", str(merged["paint_brush_shape"]))
	config.save(SAVE_PATH)


func apply_master_volume(linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index == -1:
		return
	var safe_volume := maxf(linear_volume, 0.0001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_volume))


func _get_date_parts(date = null) -> Dictionary:
	var date_source = date
	if date_source == null:
		date_source = Time.get_datetime_dict_from_system()
		if date_source.is_empty():
			date_source = Time.get_date_dict_from_system()

	var parts := {"year": 1, "month": 1, "day": 1}
	if date_source is Dictionary:
		parts["year"] = int(date_source.get("year", parts["year"]))
		parts["month"] = int(date_source.get("month", parts["month"]))
		parts["day"] = int(date_source.get("day", parts["day"]))
	elif typeof(date_source) == TYPE_OBJECT and date_source.has_method("year"):
		parts["year"] = int(date_source.year)
		parts["month"] = int(date_source.month)
		parts["day"] = int(date_source.day)

	return parts


func _is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or year % 400 == 0


func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if _is_leap_year(year) else 28
		_:
			return 30


func _shift_date_parts(year: int, month: int, day: int, offset_days: int) -> Dictionary:
	var shifted_year := year
	var shifted_month := month
	var shifted_day := day + offset_days

	while shifted_day > _days_in_month(shifted_year, shifted_month):
		shifted_day -= _days_in_month(shifted_year, shifted_month)
		shifted_month += 1
		if shifted_month > 12:
			shifted_month = 1
			shifted_year += 1

	while shifted_day <= 0:
		shifted_month -= 1
		if shifted_month < 1:
			shifted_month = 12
			shifted_year -= 1
		shifted_day += _days_in_month(shifted_year, shifted_month)

	return {"year": shifted_year, "month": shifted_month, "day": shifted_day}


func _calculate_easter_date(year: int) -> Dictionary:
	var a := year % 19
	var b := int(year / 100)
	var c := year % 100
	var d := int(b / 4)
	var e := b % 4
	var f := int((b + 8) / 25)
	var g := int((b - f + 1) / 3)
	var h := (19 * a + b - d - g + 15) % 30
	var i := int(c / 4)
	var k := c % 4
	var l := (32 + 2 * e + 2 * i - h - k) % 7
	var m := int((a + 11 * h + 22 * l) / 451)
	var month := int((h + l - 7 * m + 114) / 31)
	var day := ((h + l - 7 * m + 114) % 31) + 1
	return {"year": year, "month": month, "day": day}


func _date_in_range(date, start_md: int, end_md: int) -> bool:
	var month: int = 1
	var day: int = 1
	if date is Dictionary:
		month = int(date.get("month", 1))
		day = int(date.get("day", 1))
	elif typeof(date) == TYPE_OBJECT and date.has_method("month"):
		month = int(date.month)
		day = int(date.day)
	var today_md = month * 100 + day
	if start_md <= end_md:
		return today_md >= start_md and today_md <= end_md
	return today_md >= start_md or today_md <= end_md


func get_holiday_date_range(holiday_name: String, date_override = null) -> Dictionary:
	var date_parts := _get_date_parts(date_override)
	match holiday_name:
		HOLIDAY_CHRISTMAS:
			return {"start": {"month": 12, "day": 1}, "end": {"month": 12, "day": 31}}
		HOLIDAY_EASTER:
			var easter_date := _calculate_easter_date(int(date_parts.get("year", 1)))
			var holiday_start := _shift_date_parts(
				int(easter_date.get("year", 1)),
				int(easter_date.get("month", 1)),
				int(easter_date.get("day", 1)),
				-2
			)
			var holiday_end := _shift_date_parts(
				int(easter_date.get("year", 1)),
				int(easter_date.get("month", 1)),
				int(easter_date.get("day", 1)),
				1
			)
			return {
				"start":
				{
					"month": int(holiday_start.get("month", 1)),
					"day": int(holiday_start.get("day", 1)),
				},
				"end":
				{
					"month": int(holiday_end.get("month", 1)),
					"day": int(holiday_end.get("day", 1)),
				},
			}
		HOLIDAY_HALLOWEEN:
			return {"start": {"month": 10, "day": 25}, "end": {"month": 10, "day": 31}}
		_:
			return {}


func is_holiday_in_date_range(holiday_name: String, date_override = null) -> bool:
	if holiday_name == HOLIDAY_NONE:
		return false
	var date_parts := _get_date_parts(date_override)
	var range = get_holiday_date_range(holiday_name, date_parts)
	if range.is_empty():
		return false
	var start = range.get("start", {}) as Dictionary
	var end = range.get("end", {}) as Dictionary
	if start.is_empty() or end.is_empty():
		return false

	var start_md = int(start.get("month", 1)) * 100 + int(start.get("day", 1))
	var end_md = int(end.get("month", 12)) * 100 + int(end.get("day", 31))
	return _date_in_range(date_parts, start_md, end_md)


func _holiday_month(holiday_name: String, date_override = null) -> int:
	var date_parts := _get_date_parts(date_override)
	match holiday_name:
		HOLIDAY_CHRISTMAS:
			return 12
		HOLIDAY_HALLOWEEN:
			return 10
		HOLIDAY_EASTER:
			var easter_date := _calculate_easter_date(int(date_parts.get("year", 1)))
			return int(easter_date.get("month", 1))
		_:
			return 0


func _get_auto_holiday(date_override = null) -> String:
	var date_parts := _get_date_parts(date_override)
	var current_month := int(date_parts.get("month", 1))
	for holiday_name in HOLIDAY_OPTIONS:
		if holiday_name == HOLIDAY_NONE:
			continue
		if _holiday_month(holiday_name, date_override) == current_month:
			return holiday_name
	return HOLIDAY_NONE


func resolve_effective_holiday(settings: Dictionary, date_override = null) -> String:
	var mode = str(settings.get("holiday_mode", HOLIDAY_MODE_AUTO))
	var selected = str(settings.get("holiday_name", HOLIDAY_NONE))
	if mode == HOLIDAY_MODE_OFF:
		return HOLIDAY_NONE
	if mode == HOLIDAY_MODE_ON:
		if selected == HOLIDAY_NONE:
			return HOLIDAY_NONE
		return selected
	return _get_auto_holiday(date_override)
