class_name WholeWordMode
extends Node3D

const ReadingWordLaneDisplayScript = preload("res://scripts/reading/word_lane_display.gd")
const WorldTextBuilder = preload("res://scripts/reading/word_text_builder.gd")

const DEMO_WORDS := [
	{"text": "CAT", "position": Vector3(-12.0, 1.2, 0.0), "width": 6.5},
	{"text": "VELOCITY", "position": Vector3(0.0, 1.2, 0.0), "width": 8.0},
	{"text": "RAINBOW", "position": Vector3(12.0, 1.2, 0.0), "width": 7.5},
]

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var display_root: Node3D = $WordDisplayRoot


func _ready() -> void:
	_setup_camera()
	_spawn_demo_words()


func _setup_camera() -> void:
	if camera_rig != null:
		c0amera_rig.position = Vector3(0.0, 10.5, 22.0)
		camera_rig.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	if camera != null:
		camera.current = true
		camera.look_at(Vector3(0.0, 1.1, 0.0), Vector3.UP)
		camera.fov = 40.0


func _spawn_demo_words() -> void:
	if display_root == null:
		return

	for child in display_root.get_children():
		child.queue_free()

	for demo_word in DEMO_WORDS:
		var word_display := _create_demo_word_display(
			str(demo_word.get("text", "")), float(demo_word.get("width", 8.0))
		)
		if word_display == null:
			continue
		word_display.name = ("WordLaneDisplay_%s" % str(demo_word.get("text", "word")))
		word_display.position = demo_word.get("position", Vector3.ZERO) as Vector3
		display_root.add_child(word_display)


func _create_demo_word_display(word_text: String, target_width: float) -> Node3D:
	var word_display := ReadingWordLaneDisplayScript.new() as Node3D
	if word_display == null:
		return (
			WorldTextBuilder
			. create_billboard_label(
				word_text,
				72,
				Color(1.0, 0.95, 0.45),
				8,
				BaseMaterial3D.BILLBOARD_ENABLED,
			)
		)

	(word_display as ReadingWordLaneDisplayScript).configure(word_text, target_width, 0.18)
	return word_display
