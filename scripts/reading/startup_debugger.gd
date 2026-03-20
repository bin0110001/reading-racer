## Startup debugging for reading mode
class_name ReadingModeDebugger
extends Node3D

@export var debug_enabled: bool = true
var debug_log: Array[String] = []


func _ready() -> void:
	if not debug_enabled:
		return

	print("\n=== Reading Mode Startup Debug ===\n")

	# Check scene structure
	_check_scene_structure()

	# Check content loader
	_check_content_loader()

	# Check settings
	_check_settings()

	# Check track generator
	_check_track_generator()

	# Check control profiles
	_check_control_profiles()

	# Check trigger classes
	_check_triggers()

	# Print all logs
	print("\n--- Debug Log ---\n")
	for log in debug_log:
		print(log)

	print("\n=== End Debug ===\n")


func _check_scene_structure() -> void:
	var expected_nodes = ["Road", "SpawnRoot", "Player", "CameraRig", "ReadingHUD", "PhonemePlayer"]

	print("Checking scene structure...")
	for node_name in expected_nodes:
		var node = get_node_or_null(node_name)
		if node:
			_log("✓ Found node: %s" % node_name)
		else:
			_log("✗ MISSING node: %s" % node_name)


func _check_content_loader() -> void:
	print("Checking content loader...")
	var loader = ReadingContentLoader.new()
	_log("✓ ReadingContentLoader instantiated")

	var groups = loader.list_word_groups()
	_log("✓ Word groups found: %d" % groups.size())

	if groups.size() > 0:
		_log("  Groups: %s" % str(groups))


func _check_settings() -> void:
	print("Checking settings...")
	var store = ReadingSettingsStore.new()
	_log("✓ ReadingSettingsStore instantiated")

	var settings = store.load_settings()
	_log("✓ Settings loaded: %s" % str(settings.keys()))


func _check_track_generator() -> void:
	print("Checking track generator...")
	var gen = TrackGenerator.new()
	_log("✓ TrackGenerator instantiated")

	gen.init_generator(Vector3(-12.0, 0.0, 0.0))
	_log("✓ TrackGenerator initialized")

	gen.generate_to_distance(100.0)
	var segments = gen.get_all_segments()
	_log("✓ Generated %d segments" % segments.size())

	if segments.size() > 0:
		var seg = segments[0]
		_log("  First segment type: %s at x=%.1f" % [seg.get_class(), seg.start_pos.x])


func _check_control_profiles() -> void:
	print("Checking control profiles...")
	var profile1 = LaneChangeController.new()
	_log("✓ LaneChangeController instantiated")

	var profile2 = SmoothSteeringController.new()
	_log("✓ SmoothSteeringController instantiated")

	var profile3 = ThrottleSteeringController.new()
	_log("✓ ThrottleSteeringController instantiated")


func _check_triggers() -> void:
	print("Checking trigger classes...")
	var trigger1 = ReadingPickupTrigger.new()
	_log("✓ ReadingPickupTrigger instantiated")

	var trigger2 = ReadingObstacleTrigger.new()
	_log("✓ ReadingObstacleTrigger instantiated")

	var trigger3 = ReadingFinishGateTrigger.new()
	_log("✓ ReadingFinishGateTrigger instantiated")


func _log(message: String) -> void:
	debug_log.append(message)
	print(message)
