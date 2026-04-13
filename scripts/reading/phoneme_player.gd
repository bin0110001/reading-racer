class_name PhonemePlayer
extends Node

signal phoneme_changed(label: String)

var _phoneme_player := AudioStreamPlayer.new()
var _word_player := AudioStreamPlayer.new()
var _current_label := ""
var _looping_phoneme := false


func _ready() -> void:
	add_child(_phoneme_player)
	add_child(_word_player)
	_phoneme_player.bus = "Master"
	_word_player.bus = "Master"
	_phoneme_player.finished.connect(_on_phoneme_player_finished)


func play_looping_phoneme(label: String, stream: AudioStream) -> void:
	_current_label = label
	emit_signal("phoneme_changed", label)
	if stream == null:
		_looping_phoneme = false
		_phoneme_player.stop()
		return

	_looping_phoneme = true
	_word_player.stop()
	_phoneme_player.stop()
	_phoneme_player.stream = stream
	_phoneme_player.volume_db = 0.0
	if is_inside_tree():
		_phoneme_player.play()


func stop_phoneme() -> void:
	_looping_phoneme = false
	_current_label = ""
	_phoneme_player.stop()
	emit_signal("phoneme_changed", "")


func has_active_phoneme() -> bool:
	return _looping_phoneme and _current_label != ""


func get_current_phoneme_label() -> String:
	return _current_label


func play_word(stream: AudioStream) -> void:
	if stream == null:
		return
	_looping_phoneme = false
	_phoneme_player.stop()
	_word_player.stop()
	_word_player.stream = stream
	if is_inside_tree():
		_word_player.play()


func _on_phoneme_player_finished() -> void:
	if not _looping_phoneme:
		return
	if _current_label == "" or _phoneme_player.stream == null:
		return
	if is_inside_tree():
		_phoneme_player.play()
