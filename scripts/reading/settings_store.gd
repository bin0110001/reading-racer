class_name ReadingSettingsStore
extends RefCounted

const PlayerVehicleLibrary = preload("res://scripts/reading/player_vehicle_library.gd")

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
const HOLIDAY_HALLOWEEN := "halloween"
const HOLIDAY_OPTIONS := [HOLIDAY_NONE, HOLIDAY_CHRISTMAS, HOLIDAY_HALLOWEEN]

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
		PlayerVehicleLibrary.SETTING_KEY_VEHICLE_ID: PlayerVehicleLibrary.DEFAULT_VEHICLE_ID,
		PlayerVehicleLibrary.SETTING_KEY_VEHICLE_SCENE_PATH:
		PlayerVehicleLibrary.get_vehicle_scene_path(PlayerVehicleLibrary.DEFAULT_VEHICLE_ID),
		PlayerVehicleLibrary.SETTING_KEY_VEHICLE_COLOR:
		PlayerVehicleLibrary.DEFAULT_PAINT_COLOR_HEX,
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
	settings[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_ID] = str(
		config.get_value(
			"reading",
			PlayerVehicleLibrary.SETTING_KEY_VEHICLE_ID,
			settings[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_ID]
		)
	)
	settings[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_SCENE_PATH] = str(
		config.get_value(
			"reading",
			PlayerVehicleLibrary.SETTING_KEY_VEHICLE_SCENE_PATH,
			settings[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_SCENE_PATH]
		)
	)
	settings[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_COLOR] = str(
		config.get_value(
			"reading",
			PlayerVehicleLibrary.SETTING_KEY_VEHICLE_COLOR,
			settings[PlayerVehicleLibrary.SETTING_KEY_VEHICLE_COLOR]
		)
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
	config.save(SAVE_PATH)


func apply_master_volume(linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index == -1:
		return
	var safe_volume := maxf(linear_volume, 0.0001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_volume))


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


func get_holiday_date_range(holiday_name: String) -> Dictionary:
	match holiday_name:
		HOLIDAY_CHRISTMAS:
			return {"start": {"month": 12, "day": 1}, "end": {"month": 12, "day": 31}}
		HOLIDAY_HALLOWEEN:
			return {"start": {"month": 10, "day": 25}, "end": {"month": 10, "day": 31}}
		_:
			return {}


func is_holiday_in_date_range(holiday_name: String) -> bool:
	if holiday_name == HOLIDAY_NONE:
		return false
	var range = get_holiday_date_range(holiday_name)
	if range.is_empty():
		return false
	var start = range.get("start", {}) as Dictionary
	var end = range.get("end", {}) as Dictionary
	if start.is_empty() or end.is_empty():
		return false

	var date = {"month": 1, "day": 1}
	if OS.has_method("get_date"):
		date = OS.call("get_date")
	elif OS.has_method("get_datetime"):
		date = OS.call("get_datetime")
	# if no date API exists, remain at default Jan 1 (safe fallback)

	var start_md = int(start.get("month", 1)) * 100 + int(start.get("day", 1))
	var end_md = int(end.get("month", 12)) * 100 + int(end.get("day", 31))
	return _date_in_range(date, start_md, end_md)


func resolve_effective_holiday(settings: Dictionary) -> String:
	var mode = str(settings.get("holiday_mode", HOLIDAY_MODE_AUTO))
	var selected = str(settings.get("holiday_name", HOLIDAY_NONE))
	if mode == HOLIDAY_MODE_OFF:
		return HOLIDAY_NONE
	if selected == HOLIDAY_NONE:
		return HOLIDAY_NONE
	if mode == HOLIDAY_MODE_ON:
		return selected
	# auto
	if is_holiday_in_date_range(selected):
		return selected
	return HOLIDAY_NONE
