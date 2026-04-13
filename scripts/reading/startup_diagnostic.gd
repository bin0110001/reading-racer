## Diagnostic autoload to check what's loading at startup
extends Node

const _TRACK_GENERATOR_DIR := "res://scripts/reading/track_generator/"
const _TRACK_SEGMENTS_DIR := "res://scripts/reading/track_segments/"
const _CONTROL_PROFILES_DIR := "res://scripts/reading/control_profiles/"
const _TRIGGERS_DIR := "res://scripts/reading/triggers/"

const _CLASS_SCRIPTS := {
	"TrackGenerator": _TRACK_GENERATOR_DIR + "TrackGenerator.gd",
	"TrackSegment": _TRACK_SEGMENTS_DIR + "TrackSegment.gd",
	"StraightSegment": _TRACK_SEGMENTS_DIR + "StraightSegment.gd",
	"CurveSegment": _TRACK_SEGMENTS_DIR + "CurveSegment.gd",
	"ControlProfile": _CONTROL_PROFILES_DIR + "ControlProfile.gd",
	"LaneChangeController": _CONTROL_PROFILES_DIR + "LaneChangeController.gd",
	"SmoothSteeringController": _CONTROL_PROFILES_DIR + "SmoothSteeringController.gd",
	"ThrottleSteeringController": _CONTROL_PROFILES_DIR + "ThrottleSteeringController.gd",
	"ReadingPickupTrigger": _TRIGGERS_DIR + "ReadingPickupTrigger.gd",
	"ReadingObstacleTrigger": _TRIGGERS_DIR + "ReadingObstacleTrigger.gd",
	"ReadingFinishGateTrigger": _TRIGGERS_DIR + "ReadingFinishGateTrigger.gd",
	"ReadingContentLoader": "res://scripts/reading/content_loader.gd",
	"ReadingSettingsStore": "res://scripts/reading/settings_store.gd",
	"ReadingHUD": "res://scripts/reading/reading_hud.gd",
	"PhonemePlayer": "res://scripts/reading/phoneme_player.gd",
}

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
	_check_scene("res://scenes/level_types/pronunciation_mode.tscn")
	_check_scene("res://scenes/level_types/whole_word_mode.tscn")

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
	var script_path := str(_CLASS_SCRIPTS.get(check_class, ""))
	var success := false
	if script_path != "":
		var script := load(script_path) as Script
		success = script != null
	else:
		success = ClassDB.class_exists(check_class)
	diagnostics[check_class] = success
	if not success:
		print("ERROR: Class '%s' not found" % check_class)


func _check_scene(scene_path: String) -> void:
	var success = ResourceLoader.exists(scene_path)
	diagnostics[scene_path] = success
	if not success:
		print("ERROR: Scene '%s' not found" % scene_path)
