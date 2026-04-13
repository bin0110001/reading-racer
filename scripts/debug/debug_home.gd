class_name DebugHomeMenu
extends Control

signal close_requested
signal scene_requested(scene_path: String)

const DEBUG_SCREEN_CHOICES := [
	{
		"name": "MainScreenButton",
		"label": "Main Screen",
		"path": "res://scenes/main.tscn",
		"description": "Return to the race scene.",
	},
	{
		"name": "LevelSelectButton",
		"label": "Level Select",
		"path": "res://scenes/level_select.tscn",
		"description": "Open the reading level chooser.",
	},
	{
		"name": "VehicleSelectButton",
		"label": "Vehicle Select",
		"path": "res://scenes/vehicle_select.tscn",
		"description": "Open vehicle customization.",
	},
	{
		"name": "PronunciationModeButton",
		"label": "Pronunciation Mode",
		"path": "res://scenes/level_types/pronunciation_mode.tscn",
		"description": "Launch the standard reading scene.",
	},
	{
		"name": "WholeWordModeButton",
		"label": "Whole Word Demo",
		"path": "res://scenes/level_types/whole_word_mode.tscn",
		"description": "Launch the three-word display demo.",
	},
]

var _menu_panel: PanelContainer = null
var _button_stack: VBoxContainer = null
var _close_button: Button = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_menu()


func _build_menu() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.03, 0.05, 0.08, 0.88)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_menu_panel = PanelContainer.new()
	_menu_panel.name = "MenuPanel"
	_menu_panel.anchor_left = 0.5
	_menu_panel.anchor_top = 0.5
	_menu_panel.anchor_right = 0.5
	_menu_panel.anchor_bottom = 0.5
	_menu_panel.offset_left = -250.0
	_menu_panel.offset_top = -220.0
	_menu_panel.offset_right = 250.0
	_menu_panel.offset_bottom = 220.0
	add_child(_menu_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 20)
	panel_margin.add_theme_constant_override("margin_top", 20)
	panel_margin.add_theme_constant_override("margin_right", 20)
	panel_margin.add_theme_constant_override("margin_bottom", 20)
	_menu_panel.add_child(panel_margin)

	var panel_stack := VBoxContainer.new()
	panel_stack.name = "MenuStack"
	panel_stack.add_theme_constant_override("separation", 14)
	panel_margin.add_child(panel_stack)

	var title := Label.new()
	title.text = "Debug Home"
	title.add_theme_font_size_override("font_size", 30)
	panel_stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Jump to any debug screen"
	subtitle.add_theme_font_size_override("font_size", 16)
	panel_stack.add_child(subtitle)

	_button_stack = VBoxContainer.new()
	_button_stack.name = "DebugButtonStack"
	_button_stack.add_theme_constant_override("separation", 10)
	panel_stack.add_child(_button_stack)

	for choice in DEBUG_SCREEN_CHOICES:
		_add_debug_button(choice)

	_close_button = Button.new()
	_close_button.name = "CloseDebugMenuButton"
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(92.0, 30.0)
	_close_button.anchor_left = 1.0
	_close_button.anchor_top = 0.0
	_close_button.anchor_right = 1.0
	_close_button.anchor_bottom = 0.0
	_close_button.offset_left = -104.0
	_close_button.offset_top = 14.0
	_close_button.offset_right = -12.0
	_close_button.offset_bottom = 44.0
	_close_button.pressed.connect(_on_close_pressed)
	add_child(_close_button)


func _add_debug_button(choice: Dictionary) -> void:
	if _button_stack == null:
		return

	var button := Button.new()
	button.name = str(choice.get("name", "DebugButton"))
	button.text = str(choice.get("label", button.name))
	button.tooltip_text = str(choice.get("description", button.text))
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_debug_scene_button_pressed.bind(str(choice.get("path", ""))))
	_button_stack.add_child(button)


func _on_debug_scene_button_pressed(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	scene_requested.emit(scene_path)


func _on_close_pressed() -> void:
	close_requested.emit()
