class_name PhonemePlayer
extends Node

signal phoneme_changed(label: String)

var _phoneme_player := AudioStreamPlayer.new()
var _word_player := AudioStreamPlayer.new()
var _current_label := ""


func _ready() -> void:
	add_child(_phoneme_player)
	add_child(_word_player)
	_phoneme_player.bus = "Master"
	_word_player.bus = "Master"


func play_looping_phoneme(label: String, stream: AudioStream) -> void:
	_current_label = label
	emit_signal("phoneme_changed", label)
	if stream == null:
		_phoneme_player.stop()
		return

	var looping_stream := stream.duplicate(true)
	if looping_stream is AudioStreamWAV:
		looping_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif looping_stream is AudioStreamOggVorbis:
		looping_stream.loop = true
	elif looping_stream is AudioStreamMP3:
		looping_stream.loop = true

	_phoneme_player.stop()
	_phoneme_player.stream = looping_stream
	_phoneme_player.play()


func stop_phoneme() -> void:
	_current_label = ""
	_phoneme_player.stop()
	emit_signal("phoneme_changed", "")


func play_word(stream: AudioStream) -> void:
	if stream == null:
		return
	_word_player.stop()
	_word_player.stream = stream
	_word_player.play()
