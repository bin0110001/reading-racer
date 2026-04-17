class_name WholeWordMode
extends Node3D

const WorldTextBuilder = preload("res://scripts/reading/word_text_builder.gd")
const WordChoiceTriggerScript = preload(
	"res://scripts/reading/triggers/ReadingWordChoiceTrigger.gd"
)

const DEMO_WORDS := [
	{"text": "CAT", "position": Vector3(-12.0, 0.5, 0.0), "width": 6.5},
	{"text": "VELOCITY", "position": Vector3(0.0, 0.5, 0.0), "width": 8.0},
	{"text": "RAINBOW", "position": Vector3(12.0, 0.5, 0.0), "width": 7.5},
]

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var display_root: Node3D = $WordDisplayRoot


func _ready() -> void:
	_setup_player_group()
	_setup_camera()
	await get_tree().process_frame
	_spawn_demo_words()


func _setup_player_group() -> void:
	var player = get_node_or_null("Player")
	if player != null and player is Area3D:
		player.add_to_group("player")


func _setup_camera() -> void:
	if camera_rig != null:
		camera_rig.position = Vector3(0.0, 10.5, 22.0)
		camera_rig.rotation_degrees = Vector3(-25.0, 0.0, 0.0)
	if camera != null:
		camera.current = true
		camera.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
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
	if word_text.strip_edges().is_empty():
		return null
	var word_root := Node3D.new()
	var width_divisor := maxf(float(max(1, word_text.length())), 1.0)
	var word_label := (
		WorldTextBuilder
		. create_billboard_label(
			word_text,
			72,
			Color(0.0, 0.0, 0.0),
			8,
			BaseMaterial3D.BILLBOARD_ENABLED,
			Vector3.ZERO,
			Vector3.ONE * clampf(target_width / width_divisor, 0.45, 2.2),
		)
	)
	word_root.add_child(word_label)
	_add_word_trigger(word_root, word_text, target_width)
	return word_root


func _add_word_trigger(word_root: Node3D, word_text: String, target_width: float) -> void:
	var trigger = WordChoiceTriggerScript.new()
	trigger.word_index = 0
	trigger.choice_text = word_text.strip_edges()
	trigger.is_correct = false
	trigger.trigger_width = target_width * 0.8
	trigger.trigger_depth = 4.0
	trigger.position = Vector3(0.0, 1.0, 0.0)
	word_root.add_child(trigger)
