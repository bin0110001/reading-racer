class_name ReadingSettingsStore
extends RefCounted

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


static func default_settings() -> Dictionary:
	return {
		"control_mode": CONTROL_MODE_KEYBOARD,
		"word_group": "sightwords",
		"master_volume": 0.8,
		"random_word_order": false,
		"steering_type": STEERING_TYPE_LANE_CHANGE,
		"map_style": MAP_STYLE_CIRCULAR,
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
	config.save(SAVE_PATH)


func apply_master_volume(linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index == -1:
		return
	var safe_volume := maxf(linear_volume, 0.0001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_volume))
