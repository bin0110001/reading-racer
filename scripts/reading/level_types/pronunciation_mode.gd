class_name PronunciationMode
extends ReadingMode


func _init() -> void:
	startup_reading_mode_override = ReadingSettingsStore.READING_MODE_STANDARD
	startup_scope_mode_override = ReadingSettingsStore.READING_SCOPE_READING_LIST
