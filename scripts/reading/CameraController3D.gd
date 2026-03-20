# gdlint: disable=max-public-methods
class_name CameraController3D

extends Node
## Shared 3D camera controller with Godot-style controls.
## Provides orbit, pan, zoom, and focus functionality.
##
## Controls:
## - Right-click + drag: Orbit around target
## - Middle-click + drag (or Alt + Left-click): Pan the view
## - Scroll wheel: Zoom in/out
## - Shift + scroll: Fast zoom
## - F key: Focus on target/reset view

## Distance limits
const MIN_DISTANCE = 2.0
const MAX_DISTANCE = 200.0
const DEFAULT_DISTANCE = 20.0

## Angle limits
const MIN_VERTICAL_ANGLE = -89.0
const MAX_VERTICAL_ANGLE = -5.0

## Sensitivity settings
const ORBIT_SENSITIVITY = 0.3
const PAN_SENSITIVITY = 0.05
const ZOOM_SENSITIVITY = 2.0
const FAST_ZOOM_MULTIPLIER = 3.0

var _camera: Camera3D = null

## Smoothing (0 = instant, higher = slower)
var _smoothing_factor: float = 0.0

## Current camera state
var _target: Vector3 = Vector3.ZERO
var _distance: float = DEFAULT_DISTANCE
var _horizontal_angle: float = 45.0  # Degrees, around Y axis
var _vertical_angle: float = -45.0  # Degrees, up/down from horizontal

## Target state for smoothing (if enabled)
var _target_goal: Vector3 = Vector3.ZERO
var _distance_goal: float = DEFAULT_DISTANCE
var _horizontal_angle_goal: float = 45.0
var _vertical_angle_goal: float = -45.0

## Input state
var _is_orbiting: bool = false
var _is_panning: bool = false
var _last_mouse_position: Vector2 = Vector2.ZERO
var _shift_held: bool = false
var _alt_held: bool = false
var _enabled: bool = true


## Smoothing factor for camera movement. 0 = instant, higher = slower.
func get_smoothing_factor() -> float:
	return _smoothing_factor


func set_smoothing_factor(value: float) -> void:
	_smoothing_factor = maxf(0, value)


## Whether the controller is enabled.
func get_enabled() -> bool:
	return _enabled


func set_enabled(value: bool) -> void:
	_enabled = value


## The point the camera orbits around.
func get_target() -> Vector3:
	return _target_goal


func set_target(value: Vector3) -> void:
	_target_goal = value
	if _smoothing_factor <= 0:
		_target = value


## Distance from camera to target.
func get_distance() -> float:
	return _distance_goal


func set_distance(value: float) -> void:
	_distance_goal = clampf(value, MIN_DISTANCE, MAX_DISTANCE)
	if _smoothing_factor <= 0:
		_distance = _distance_goal


## Horizontal orbit angle in degrees.
func get_horizontal_angle() -> float:
	return _horizontal_angle_goal


func set_horizontal_angle(value: float) -> void:
	_horizontal_angle_goal = fmod(value, 360.0)
	if _smoothing_factor <= 0:
		_horizontal_angle = _horizontal_angle_goal


## Vertical orbit angle in degrees (negative = looking down).
func get_vertical_angle() -> float:
	return _vertical_angle_goal


func set_vertical_angle(value: float) -> void:
	_vertical_angle_goal = clampf(value, MIN_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE)
	if _smoothing_factor <= 0:
		_vertical_angle = _vertical_angle_goal


## Whether the camera is currently being manipulated.
func get_is_active() -> bool:
	return _is_orbiting or _is_panning


## The camera being controlled.
func get_camera() -> Camera3D:
	return _camera


## Attaches this controller to a camera.
func attach_camera(camera: Camera3D) -> void:
	_camera = camera
	update_camera_position()
	print("[CameraController3D] Camera attached")


## Resets the camera to default view.
func reset() -> void:
	_target = Vector3.ZERO
	_target_goal = Vector3.ZERO
	_distance = DEFAULT_DISTANCE
	_distance_goal = DEFAULT_DISTANCE
	_horizontal_angle = 45.0
	_horizontal_angle_goal = 45.0
	_vertical_angle = -45.0
	_vertical_angle_goal = -45.0

	update_camera_position()


## Focuses the camera on a specific position.
func focus_on(position: Vector3, distance: float = -1.0) -> void:
	set_target(position)
	if distance >= 0:
		set_distance(distance)
	update_camera_position()


## Focuses the camera on a grid position (for map editors).
func focus_on_grid(grid_x: int, grid_y: int, tile_size: float = 1.0, height: float = 0.0) -> void:
	var world_pos = Vector3(
		grid_x * tile_size + tile_size / 2.0, height, grid_y * tile_size + tile_size / 2.0
	)
	focus_on(world_pos)


## Centers on a map of given dimensions.
func center_on_map(grid_width: int, grid_height: int, tile_size: float = 1.0) -> void:
	var center = Vector3(grid_width * tile_size / 2.0, 0, grid_height * tile_size / 2.0)

	# Calculate distance to see most of the map
	var map_diagonal = sqrt(float(grid_width * grid_width + grid_height * grid_height)) * tile_size
	var optimal_distance = clampf(map_diagonal * 0.6, MIN_DISTANCE, MAX_DISTANCE)

	focus_on(center, optimal_distance)


## Handles input events for camera control.
## Call this from your GuiInput handler.
## Returns true if the event was consumed.
func handle_input(event: InputEvent) -> bool:
	if not _enabled:
		return false

	# Track modifier keys
	if event is InputEventKey:
		_handle_key_input(event)
		return false  # Don't consume key events

	if event is InputEventMouseButton:
		return _handle_mouse_button(event)

	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event)

	return false


func _handle_key_input(key_event: InputEventKey) -> void:
	# Track Shift key
	if key_event.keycode == KEY_SHIFT:
		_shift_held = key_event.pressed

	# Track Alt key
	if key_event.keycode == KEY_ALT:
		_alt_held = key_event.pressed

	# Focus key (F)
	if key_event.keycode == KEY_F and key_event.pressed and not key_event.echo:
		reset()


func _handle_mouse_button(event: InputEventMouseButton) -> bool:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_orbiting = true
				_last_mouse_position = event.position
			else:
				_is_orbiting = false
			return true

		MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_panning = true
				_last_mouse_position = event.position
			else:
				_is_panning = false
			return true

		MOUSE_BUTTON_LEFT:
			if _alt_held:
				# Alt + Left click = Pan (Godot style)
				if event.pressed:
					_is_panning = true
					_last_mouse_position = event.position
				else:
					_is_panning = false
				return true

		MOUSE_BUTTON_WHEEL_UP:
			zoom(-1, _shift_held)
			return true

		MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1, _shift_held)
			return true

	return false


func _handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	if not _is_orbiting and not _is_panning:
		return false

	var delta = event.position - _last_mouse_position
	_last_mouse_position = event.position

	if _is_orbiting:
		orbit(delta)
		return true

	if _is_panning:
		pan(delta)
		return true

	return false


## Orbits the camera around the target.
func orbit(delta: Vector2) -> void:
	_horizontal_angle_goal += delta.x * ORBIT_SENSITIVITY
	_vertical_angle_goal -= delta.y * ORBIT_SENSITIVITY
	_vertical_angle_goal = clampf(_vertical_angle_goal, MIN_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE)

	update_camera_position()


## Pans the camera (moves the target).
func pan(delta: Vector2) -> void:
	if _camera == null:
		return

	# Calculate pan in camera's local space
	var pan_speed = PAN_SENSITIVITY * _distance_goal * 0.1

	# Get camera's right and up vectors for panning
	var camera_transform = _camera.global_transform
	var right = -camera_transform.basis.x
	var up = camera_transform.basis.y

	# Move target
	var pan_offset = right * delta.x * pan_speed + up * delta.y * pan_speed
	_target_goal += pan_offset

	update_camera_position()


## Zooms the camera in or out.
## param direction: Positive = zoom out, negative = zoom in
## param fast: Use fast zoom speed
func zoom(direction: int, fast: bool = false) -> void:
	var zoom_amount = ZOOM_SENSITIVITY
	if fast:
		zoom_amount *= FAST_ZOOM_MULTIPLIER

	# Scale zoom by distance for consistent feel
	zoom_amount *= _distance_goal * 0.1

	_distance_goal += direction * zoom_amount
	_distance_goal = clampf(_distance_goal, MIN_DISTANCE, MAX_DISTANCE)

	update_camera_position()


## Sets the zoom level directly (for UI sliders, etc.)
func set_zoom(distance: float) -> void:
	set_distance(distance)
	update_camera_position()


## Call this every frame to update smoothing (if enabled).
func update(delta: float) -> void:
	if _smoothing_factor <= 0:
		return

	# Smooth interpolation
	var t = 1.0 - pow(_smoothing_factor, delta)

	_target = _target.lerp(_target_goal, t)
	_distance = lerpf(_distance, _distance_goal, t)
	_horizontal_angle = lerp_angle(_horizontal_angle, _horizontal_angle_goal, t)
	_vertical_angle = lerpf(_vertical_angle, _vertical_angle_goal, t)

	update_camera_position()


## Updates the camera's position and orientation based on current state.
func update_camera_position() -> void:
	if _camera == null:
		return

	# Convert angles to radians
	var h_rad = deg_to_rad(_horizontal_angle_goal)
	var v_rad = deg_to_rad(_vertical_angle_goal)

	# Calculate camera position on sphere around target
	# Note: In Godot, Y is up, Z is forward
	var cos_v = cos(v_rad)
	var sin_v = sin(v_rad)
	var cos_h = cos(h_rad)
	var sin_h = sin(h_rad)

	# Negative because our vertical angle is negative for looking down
	var offset = Vector3(
		_distance_goal * cos_v * sin_h, -_distance_goal * sin_v, _distance_goal * cos_v * cos_h
	)

	_camera.global_position = _target_goal + offset
	_camera.look_at(_target_goal, Vector3.UP)


## Gets the world position under the mouse cursor.
## Useful for picking/selection.
func get_world_position_under_mouse(mouse_pos: Vector2, plane_y: float = 0.0) -> Vector3:
	if _camera == null:
		return Vector3.ZERO

	# Get ray from camera
	var from = _camera.project_ray_origin(mouse_pos)
	var direction = _camera.project_ray_normal(mouse_pos)

	# Intersect with horizontal plane at plane_y
	if absf(direction.y) < 0.0001:
		return Vector3.ZERO  # Ray is parallel to plane

	var t = (plane_y - from.y) / direction.y
	if t < 0:
		return Vector3.ZERO  # Intersection is behind camera

	return from + direction * t


## Converts a world position to grid coordinates.
func world_to_grid(world_pos: Vector3, tile_size: float = 1.0) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / tile_size)), int(floor(world_pos.z / tile_size)))


## Gets the grid position under the mouse cursor.
func get_grid_position_under_mouse(
	mouse_pos: Vector2, tile_size: float = 1.0, plane_y: float = 0.0
) -> Vector2i:
	var world_pos = get_world_position_under_mouse(mouse_pos, plane_y)
	return world_to_grid(world_pos, tile_size)
