class_name RaceHUD extends CanvasLayer

var countdown_label: Label
var race_hud_label: Label
var player_labels: Dictionary = {}
var active_players: Dictionary = {}
var game_manager: GameManager


func _ready() -> void:
	game_manager = get_node_or_null("../GameManager")

	countdown_label = Label.new()
	countdown_label.name = "CountdownLabel"
	countdown_label.anchor_left = 0.5
	countdown_label.anchor_top = 0.5
	countdown_label.offset_left = -120
	countdown_label.offset_top = -60
	countdown_label.custom_minimum_size = Vector2(240, 120)
	countdown_label.text = "GET READY!"
	countdown_label.add_theme_font_size_override("font_sizes", 80)
	add_child(countdown_label)

	race_hud_label = Label.new()
	race_hud_label.name = "RaceHUDLabel"
	race_hud_label.anchor_left = 0.02
	race_hud_label.anchor_top = 0.02
	race_hud_label.text = ""
	race_hud_label.add_theme_font_size_override("font_sizes", 20)
	race_hud_label.visible = false
	add_child(race_hud_label)

	if game_manager:
		game_manager.race_state_changed.connect(_on_race_state_changed)


func _physics_process(_delta: float) -> void:
	if game_manager and game_manager.get_race_state() == GameManager.RaceState.RACING:
		_update_race_hud_display()


func add_player(player_id: int, vehicle: Node3D) -> void:
	active_players[player_id] = vehicle


func remove_player(player_id: int) -> void:
	if active_players.has(player_id):
		active_players.erase(player_id)
	if player_labels.has(player_id):
		player_labels[player_id].queue_free()
		player_labels.erase(player_id)


func show_waiting() -> void:
	countdown_label.text = "WAITING FOR PLAYERS"
	countdown_label.visible = true
	race_hud_label.visible = false


func show_countdown(remaining_seconds: int) -> void:
	if remaining_seconds > 0:
		countdown_label.text = str(remaining_seconds)
	else:
		countdown_label.text = "GO!"
	countdown_label.visible = true
	race_hud_label.visible = false


func update_countdown(remaining_seconds: int) -> void:
	if remaining_seconds > 0:
		countdown_label.text = str(remaining_seconds)
	else:
		countdown_label.text = "GO!"


func show_race_hud() -> void:
	countdown_label.visible = false
	race_hud_label.visible = true


func _update_race_hud_display() -> void:
	var hud_text = "=== RACE HUD ===\n"
	var player_ids = active_players.keys()
	player_ids.sort()

	for player_id in player_ids:
		var player_data = game_manager.get_player_data(player_id)
		if player_data.is_empty():
			continue
		var lap = player_data.get("lap", 0)
		var race_time = player_data.get("race_time", 0.0)
		var finished = player_data.get("finished", false)
		var time_str = _format_time(race_time)
		var status = "Lap %d" % (lap + 1)
		if finished:
			status = "FINISHED"
		hud_text += "P%d: %s (%s)\n" % [player_id, status, time_str]

	race_hud_label.text = hud_text


func _format_time(seconds: float) -> String:
	var secs = int(seconds) % 60
	var mins = int(seconds) / 60
	return "%02d:%02d" % [mins, secs]


func show_results(completion_order: Array[int], players_data: Dictionary) -> void:
	var results_text = "=== RACE RESULTS ===\n"
	for i in range(completion_order.size()):
		var player_id = completion_order[i]
		var data = players_data.get(player_id, {})
		var finish_time = data.get("finish_time", 0.0)
		results_text += "%d. Player %d - %s\n" % [i + 1, player_id, _format_time(finish_time)]
	race_hud_label.text = results_text


func _on_race_state_changed(_new_state: int) -> void:
	pass
