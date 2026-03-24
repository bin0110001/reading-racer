class_name ReadingObstacleTrigger extends Area3D

## Invisible trigger area for obstacles.
## Detects when player collides and applies slowdown penalty.

signal obstacle_hit(obstacle_index: int)

@export var word_index: int = 0
@export var obstacle_index: int = 0
@export var trigger_width: float = 1.35  # X-axis width (±0.675)
@export var trigger_depth: float = 1.0  # Z-axis depth (±0.5)
@export var penalty_seconds: float = 0.75
@export var hit_sound_path: String = "res://audio/skid.ogg"

var has_triggered := false
var _hit_sound_player: AudioStreamPlayer3D = null


func _ready() -> void:
	# Create a box collision shape for detection
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(trigger_width, 2.0, trigger_depth)
	collision_shape.shape = box_shape
	add_child(collision_shape)

	# Position the collision shape centered at origin
	collision_shape.position = Vector3.ZERO

	# Prepare hit sound player
	_hit_sound_player = AudioStreamPlayer3D.new()
	_hit_sound_player.name = "HitSoundPlayer"
	if ResourceLoader.exists(hit_sound_path):
		_hit_sound_player.stream = load(hit_sound_path) as AudioStream
	add_child(_hit_sound_player)

	area_entered.connect(_on_area_entered)


func trigger_obstacle() -> void:
	if not has_triggered:
		has_triggered = true
		_play_hit_sound()
		_send_flying_animation()
		obstacle_hit.emit(obstacle_index)


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player"):
		trigger_obstacle()


func _play_hit_sound() -> void:
	if _hit_sound_player != null and _hit_sound_player.stream != null:
		_hit_sound_player.stop()
		_hit_sound_player.play()


func _send_flying_animation() -> void:
	var flight_offset = Vector3(4.0, 2.5, 0.0)
	var target_position = global_position + flight_offset
	var target_rotation = rotation_degrees + Vector3(0.0, 80.0, 160.0)

	var tween = create_tween()
	var pos_tween = tween.tween_property(self, "global_position", target_position, 0.35)
	pos_tween.set_trans(Tween.TRANS_SINE)
	pos_tween.set_ease(Tween.EASE_OUT)
	var rot_tween = tween.tween_property(self, "rotation_degrees", target_rotation, 0.35)
	rot_tween.set_trans(Tween.TRANS_SINE)
	rot_tween.set_ease(Tween.EASE_OUT)
	tween.connect("finished", Callable(self, "queue_free"))


func reset() -> void:
	has_triggered = false
