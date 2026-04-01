class_name ReadingControlProfile
extends RefCounted

const ACTION_MOVE_UP := "reading_move_up"
const ACTION_MOVE_DOWN := "reading_move_down"
const ACTION_TOGGLE_OPTIONS := "reading_toggle_options"
const ACTION_CONFIRM := "reading_confirm"

const SWIPE_DEADZONE := 36.0
const TILT_DEADZONE := 0.2
const TILT_REPEAT_SECONDS := 0.35

var mode: String = ReadingSettingsStore.CONTROL_MODE_KEYBOARD
var _swipe_start := Vector2.ZERO
var _swipe_active := false
var _pending_lane_delta := 0
var _tilt_cooldown := 0.0


static func ensure_input_actions() -> void:
	# Controls are left/right now that the map is rotated.
	_ensure_action(ACTION_MOVE_UP, [KEY_LEFT, KEY_A])
	_ensure_action(ACTION_MOVE_DOWN, [KEY_RIGHT, KEY_D])

	# Add fallback/default UI actions for control profiles that use built-in names.
	_ensure_action("ui_left", [KEY_LEFT, KEY_A])
	_ensure_action("ui_right", [KEY_RIGHT, KEY_D])
	_ensure_action("ui_up", [KEY_UP, KEY_W])
	_ensure_action("ui_down", [KEY_DOWN, KEY_S])
	_ensure_action("ui_a", [KEY_A])
	_ensure_action("ui_d", [KEY_D])
	_ensure_action("ui_w", [KEY_W])
	_ensure_action("ui_s", [KEY_S])

	_ensure_action(ACTION_TOGGLE_OPTIONS, [KEY_ESCAPE, KEY_TAB])
	_ensure_action(ACTION_CONFIRM, [KEY_SPACE, KEY_ENTER])


static func _ensure_action(action_name: String, keys: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for keycode in keys:
		var already_present := false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey and event.physical_keycode == keycode:
				already_present = true
				break
		if already_present:
			continue

		var key_event := InputEventKey.new()
		key_event.physical_keycode = keycode
		InputMap.action_add_event(action_name, key_event)


func set_mode(next_mode: String) -> void:
	if ReadingSettingsStore.CONTROL_MODES.has(next_mode):
		mode = next_mode
	_pending_lane_delta = 0
	_swipe_active = false
	_tilt_cooldown = 0.0


func handle_input(event: InputEvent) -> void:
	if event is InputEventAction:
		var action_event := event as InputEventAction
		if action_event.pressed and action_event.action == ACTION_MOVE_UP:
			_pending_lane_delta = -1
		elif action_event.pressed and action_event.action == ACTION_MOVE_DOWN:
			_pending_lane_delta = 1
	elif event.is_action_pressed(ACTION_MOVE_UP):
		_pending_lane_delta = -1
	elif event.is_action_pressed(ACTION_MOVE_DOWN):
		_pending_lane_delta = 1

	if mode != ReadingSettingsStore.CONTROL_MODE_SWIPE:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start = event.position
			_swipe_active = true
		else:
			_swipe_active = false
	elif event is InputEventScreenDrag and _swipe_active:
		var delta: Vector2 = event.position - _swipe_start
		# Swipe left/right maps to lane changes when the map is rotated.
		if absf(delta.x) >= SWIPE_DEADZONE:
			_pending_lane_delta = -1 if delta.x < 0.0 else 1
			_swipe_start = event.position


func consume_lane_delta(delta: float) -> int:
	var result := 0
	if _pending_lane_delta != 0:
		result = _pending_lane_delta
		_pending_lane_delta = 0
		return result

	if mode == ReadingSettingsStore.CONTROL_MODE_SWIPE:
		result = _pending_lane_delta
		_pending_lane_delta = 0
	elif mode == ReadingSettingsStore.CONTROL_MODE_TILT:
		_tilt_cooldown = maxf(_tilt_cooldown - delta, 0.0)
		if _tilt_cooldown <= 0.0:
			var accelerometer := Input.get_accelerometer()
			if accelerometer != Vector3.ZERO:
				if accelerometer.x < -TILT_DEADZONE:
					_tilt_cooldown = TILT_REPEAT_SECONDS
					result = -1
				elif accelerometer.x > TILT_DEADZONE:
					_tilt_cooldown = TILT_REPEAT_SECONDS
					result = 1

	return result
