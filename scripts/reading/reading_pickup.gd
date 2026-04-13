class_name ReadingPickup
extends Node3D

const WorldTextBuilder = preload("res://scripts/reading/word_text_builder.gd")

var segment_index := 0
var lane_index := 0
var letter := ""
var phoneme_alias := ""
var collected := false

var _label := Label3D.new()
var _base_height := 0.0


func _ready() -> void:
	_base_height = position.y
	_label = (
		WorldTextBuilder
		. create_billboard_label(
			letter.to_upper(),
			256,
			Color(1.0, 0.95, 0.45),
			48,
			BaseMaterial3D.BILLBOARD_ENABLED,
		)
	)
	add_child(_label)

	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.35)
	glow.light_energy = 1.4
	glow.omni_range = 4.5
	add_child(glow)


func configure(
	next_letter: String, next_phoneme_alias: String, next_segment_index: int, next_lane_index: int
) -> void:
	letter = next_letter
	phoneme_alias = next_phoneme_alias
	segment_index = next_segment_index
	lane_index = next_lane_index
	if is_inside_tree():
		_label.text = letter.to_upper()


func set_collected() -> void:
	collected = true
	visible = false


func _process(delta: float) -> void:
	if collected:
		return
	rotation.y += delta * 1.4
	position.y = _base_height + sin(Time.get_ticks_msec() / 180.0) * 0.15
