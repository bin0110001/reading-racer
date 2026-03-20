## Diagnostic autoload to check what's loading at startup
extends Node

var diagnostics: Dictionary = {}


func _ready() -> void:
	print("\n=== Reading Racer Diagnostic Report ===\n")

	# Check class availability
	_check_class("TrackGenerator")
	_check_class("TrackSegment")
	_check_class("StraightSegment")
	_check_class("CurveSegment")
	_check_class("ControlProfile")
	_check_class("LaneChangeController")
	_check_class("SmoothSteeringController")
	_check_class("ThrottleSteeringController")
	_check_class("ReadingPickupTrigger")
	_check_class("ReadingObstacleTrigger")
	_check_class("ReadingFinishGateTrigger")
	_check_class("ReadingContentLoader")
	_check_class("ReadingSettingsStore")
	_check_class("ReadingHUD")
	_check_class("PhonemePlayer")

	# Check scene
	_check_scene("res://scenes/reading_mode.tscn")

	# Print report
	print("\n=== Diagnostic Results ===\n")
	for key: String in diagnostics.keys():
		var status = "✓" if diagnostics[key] else "✗"
		print("%s %s" % [status, key])

	# Calculate passed/failed
	var passed = diagnostics.values().count(true)
	var total = diagnostics.size()
	print("\nPassed: %d/%d\n" % [passed, total])

	if passed == total:
		print("✓ All systems loaded successfully!")
	else:
		print("✗ Some systems failed to load. See above for details.")


func _check_class(check_class: String) -> void:
	var success = ClassDB.class_exists(check_class)
	diagnostics[check_class] = success
	if not success:
		print("ERROR: Class '%s' not found" % check_class)


func _check_scene(scene_path: String) -> void:
	var success = ResourceLoader.exists(scene_path)
	diagnostics[scene_path] = success
	if not success:
		print("ERROR: Scene '%s' not found" % scene_path)
