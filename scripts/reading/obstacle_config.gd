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


func _get_date_parts(date_time) -> Dictionary:
	var parts := {"year": 1, "month": 1, "day": 1}
	if date_time is Dictionary:
		parts["year"] = int(date_time.get("year", parts["year"]))
		parts["month"] = int(date_time.get("month", parts["month"]))
		parts["day"] = int(date_time.get("day", parts["day"]))
	elif date_time != null and typeof(date_time) == TYPE_OBJECT and date_time.has_method("year"):
		parts["year"] = int(date_time.year)
		parts["month"] = int(date_time.month)
		parts["day"] = int(date_time.day)
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


func _holiday_date_range(holiday_name: String, date_time = null) -> Dictionary:
	if holiday_name == "easter":
		var date_parts := _get_date_parts(date_time)
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
	var holidays = config.get("holiday_ranges", {}) as Dictionary
	return holidays.get(holiday_name, {}) as Dictionary


func is_holiday_in_date_range(holiday_name: String, date_time) -> bool:
	var date_parts := _get_date_parts(date_time)
	var range = _holiday_date_range(holiday_name, date_parts)
	if range.is_empty():
		return false

	var start = range.get("start", {}) as Dictionary
	var end = range.get("end", {}) as Dictionary
	if start.is_empty() or end.is_empty():
		return false

	var start_md = int(start.get("month", 1)) * 100 + int(start.get("day", 1))
	var end_md = int(end.get("month", 12)) * 100 + int(end.get("day", 31))
	var today_md = int(date_parts.get("month", 1)) * 100 + int(date_parts.get("day", 1))

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
