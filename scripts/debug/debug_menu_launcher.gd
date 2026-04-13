class_name DebugMenuLauncher
extends CanvasLayer

const DEBUG_HOME_SCENE_PATH := "res://scenes/debug/debug_home.tscn"

var _debug_home_scene: Node = null
var _debug_menu_button: Button = null


func _ready() -> void:
	layer = 100
	_build_launcher_button()


func _build_launcher_button() -> void:
	_debug_menu_button = Button.new()
	_debug_menu_button.name = "DebugMenuButton"
	_debug_menu_button.text = "Debug"
	_debug_menu_button.tooltip_text = "Open debug menu"
	_debug_menu_button.focus_mode = Control.FOCUS_NONE
	_debug_menu_button.custom_minimum_size = Vector2(72.0, 28.0)
	_debug_menu_button.anchor_left = 1.0
	_debug_menu_button.anchor_top = 0.0
	_debug_menu_button.anchor_right = 1.0
	_debug_menu_button.anchor_bottom = 0.0
	_debug_menu_button.offset_left = -84.0
	_debug_menu_button.offset_top = 10.0
	_debug_menu_button.offset_right = -12.0
	_debug_menu_button.offset_bottom = 38.0
	_debug_menu_button.pressed.connect(_on_debug_menu_button_pressed)
	add_child(_debug_menu_button)


func _on_debug_menu_button_pressed() -> void:
	if is_instance_valid(_debug_home_scene):
		return

	var debug_home_scene := load(DEBUG_HOME_SCENE_PATH) as PackedScene
	if debug_home_scene == null:
		return

	_debug_home_scene = debug_home_scene.instantiate() as Node
	if _debug_home_scene == null:
		return

	_debug_home_scene.name = "DebugHomeMenu"
	_debug_home_scene.connect("close_requested", Callable(self, "_on_debug_home_close_requested"))
	_debug_home_scene.connect("scene_requested", Callable(self, "_on_debug_home_scene_requested"))
	_debug_home_scene.connect("tree_exited", Callable(self, "_on_debug_home_tree_exited"))
	add_child(_debug_home_scene)


func _on_debug_home_close_requested() -> void:
	if is_instance_valid(_debug_home_scene):
		_debug_home_scene.queue_free()
	_debug_home_scene = null


func _on_debug_home_scene_requested(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)


func _on_debug_home_tree_exited() -> void:
	_debug_home_scene = null
