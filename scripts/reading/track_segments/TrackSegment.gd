class_name TrackSegment extends RefCounted

## Base class for all track segment types.
## Segments are procedurally generated sections of track that define geometry and event positions.

## Unique segment identifier
var segment_id: int

## World position where this segment starts (X-axis forward)
var start_pos: Vector3

## Segment length in world units
var length: float

## Type identifier: "straight" or "curve"
var segment_type: String

## Default road center Z position (can be modified by curves)
var road_center_z: float = 0.0

## Rotation of the segment (Euler angles)
var rotation: Vector3 = Vector3.ZERO

## Stores the ideal heading (angle in radians) for this segment
var ideal_heading: float = 0.0

## Dictionary of event positions relative to segment start
## Key: event type ("pickup_N", "obstacle_N", "finish")
## Value: Dictionary with "pos" (Vector3 local), "index" (int), "side" (int for obstacles)
var events: Dictionary = {}


func _init(id: int, pos: Vector3, seg_length: float, seg_type: String) -> void:
	segment_id = id
	start_pos = pos
	length = seg_length
	segment_type = seg_type


## Get the ending position of this segment
func get_end_pos() -> Vector3:
	return start_pos + Vector3(length, 0.0, 0.0)


## Get the ending world position with rotation applied
func get_end_heading() -> float:
	return ideal_heading


## Convert local position to world position
func local_to_world(local_pos: Vector3) -> Vector3:
	# Apply rotation and translation
	var rotated = local_pos.rotated(Vector3.UP, ideal_heading)
	return start_pos + rotated


## Add an event at a relative distance within this segment
func add_event(
	event_type: String, local_x: float, relative_z: float = 0.0, index: int = 0, side: int = 0
) -> void:
	var key = "%s_%d" % [event_type, index] if index > 0 else event_type
	events[key] = {
		"pos": Vector3(local_x, 0.0, relative_z),
		"type": event_type,
		"index": index,
		"side": side,
	}
