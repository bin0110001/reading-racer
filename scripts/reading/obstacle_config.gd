class_name ObstacleConfig
extends RefCounted

const DEFAULT_CONFIG_PATH := "res://config/obstacles.json"
const FALLBACK_OBSTACLE := {
	"model_path": "res://models/track-bump.glb", "sound_paths": ["res://audio/skid.ogg"]
}

var config: Dictionary = {}


func _init(config_path: String = DEFAULT_CONFIG_PATH) -> void:
	_load_config(config_path)


func _load_config(config_path: String) -> void:
	config = {}
	if not FileAccess.file_exists(config_path):
		print("[ObstacleConfig] config not found: %s" % config_path)
		config = {}
		return

	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_warning("[ObstacleConfig] failed to open %s" % config_path)
		config = {}
		return

	var raw = file.get_as_text()
	file.close()
	var json_parser = JSON.new()
	var error = json_parser.parse(raw)
	if error != OK:
		var message = (
			"[ObstacleConfig] invalid JSON in %s: %s"
			% [
				config_path,
				json_parser.get_error_message(),
			]
		)
		push_warning(message)
		config = {}
		return

	var data = json_parser.data
	if data is Dictionary:
		config = data
	else:
		config = {}


func _holiday_date_range(holiday_name: String) -> Dictionary:
	var holidays = config.get("holiday_ranges", {}) as Dictionary
	return holidays.get(holiday_name, {}) as Dictionary


func is_holiday_in_date_range(holiday_name: String, date_time) -> bool:
	var range = _holiday_date_range(holiday_name)
	if range.is_empty():
		return false

	var start = range.get("start", {}) as Dictionary
	var end = range.get("end", {}) as Dictionary
	if start.is_empty() or end.is_empty():
		return false

	var year = date_time.year
	var today_md = date_time.month * 100 + date_time.day
	var start_md = int(start.get("month", 1)) * 100 + int(start.get("day", 1))
	var end_md = int(end.get("month", 12)) * 100 + int(end.get("day", 31))

	# Handle range wrapping around year-end
	if start_md <= end_md:
		return today_md >= start_md and today_md <= end_md
	return today_md >= start_md or today_md <= end_md


func get_obstacle_list_for(group_name: String, active_holiday: String) -> Array:
	var result: Array = []
	result += config.get("base_obstacles", [])

	var level_map = config.get("level_obstacles", {}) as Dictionary
	if level_map.has(group_name):
		result += level_map.get(group_name, [])

	var seasonal_map = config.get("seasonal_obstacles", {}) as Dictionary
	if active_holiday != "" and seasonal_map.has(active_holiday):
		result += seasonal_map.get(active_holiday, [])

	if result.is_empty():
		result.append(FALLBACK_OBSTACLE)

	return result


func choose_random_obstacle(
	group_name: String, active_holiday: String, rng: RandomNumberGenerator
) -> Dictionary:
	var options = get_obstacle_list_for(group_name, active_holiday)
	if options.is_empty():
		return FALLBACK_OBSTACLE

	if options.size() == 1:
		return options[0]

	var idx = rng.randi_range(0, options.size() - 1)
	var obstacle = options[idx]
	if obstacle == null or not (obstacle is Dictionary):
		return FALLBACK_OBSTACLE
	return obstacle


func pick_random_hit_sound(obstacle_data: Dictionary, rng: RandomNumberGenerator) -> String:
	var sounds = obstacle_data.get("sound_paths", []) as Array
	if sounds.is_empty():
		return FALLBACK_OBSTACLE["sound_paths"][0]

	# ensure all are strings
	var valid_sounds = []
	for s in sounds:
		if s is String and s.strip_edges() != "":
			valid_sounds.append(str(s))

	if valid_sounds.is_empty():
		return FALLBACK_OBSTACLE["sound_paths"][0]

	var index = rng.randi_range(0, valid_sounds.size() - 1)
	return valid_sounds[index]
