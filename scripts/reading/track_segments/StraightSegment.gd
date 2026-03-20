class_name StraightSegment extends TrackSegment

## Represents a straight track segment.


func _init(id: int, pos: Vector3, seg_length: float) -> void:
	super._init(id, pos, seg_length, "straight")
	ideal_heading = 0.0
