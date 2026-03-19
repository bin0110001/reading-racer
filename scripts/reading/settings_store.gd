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


static func default_settings() -> Dictionary:
	return {
		"control_mode": CONTROL_MODE_KEYBOARD,
		"word_group": "sightwords",
		"master_volume": 0.8,
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
	return settings


func save_settings(settings: Dictionary) -> void:
	var merged := default_settings()
	for key in settings.keys():
		merged[key] = settings[key]

	var config := ConfigFile.new()
	config.set_value("reading", "control_mode", str(merged["control_mode"]))
	config.set_value("reading", "word_group", str(merged["word_group"]))
	config.set_value("reading", "master_volume", clampf(float(merged["master_volume"]), 0.0, 1.0))
	config.save(SAVE_PATH)


func apply_master_volume(linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index == -1:
		return
	var safe_volume := maxf(linear_volume, 0.0001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_volume))
