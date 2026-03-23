class_name GameManager extends Node

signal race_state_changed(new_state: int)
signal player_lap_completed(player_id: int, lap: int, time: float)
signal race_finished

enum RaceState { WAITING, COUNTDOWN, RACING, FINISHED }

const RACE_LAPS := 3
const COUNTDOWN_SECONDS := 3
const MAX_PLAYERS := 8

var current_state: int = RaceState.WAITING
var countdown_timer: float = 0.0
var race_start_time: float = 0.0

var players: Dictionary = {}
var player_completion_order: Array[int] = []

var race_track: Node3D
var race_hud: Node


func _ready() -> void:
	race_track = get_node_or_null("../RaceTrack")
	race_hud = get_node_or_null("../RaceHUD")
	set_race_state(RaceState.WAITING)


func _physics_process(delta: float) -> void:
	match current_state:
		RaceState.COUNTDOWN:
			_update_countdown(delta)
		RaceState.RACING:
			_update_racing(delta)


func register_player(player_id: int, vehicle: Node3D) -> void:
	if not players.has(player_id):
		players[player_id] = {
			"vehicle": vehicle,
			"lap": 0,
			"sector": 0,
			"lap_times": [],
			"race_time": 0.0,
			"finished": false,
			"finish_time": 0.0
		}
		print("Player %d registered" % player_id)
		if race_hud and race_hud.has_method("add_player"):
			race_hud.add_player(player_id, vehicle)


func unregister_player(player_id: int) -> void:
	if players.has(player_id):
		players.erase(player_id)
		if race_hud and race_hud.has_method("remove_player"):
			race_hud.remove_player(player_id)


func set_race_state(new_state: int) -> void:
	if new_state == current_state:
		return
	current_state = new_state
	match new_state:
		RaceState.WAITING:
			_on_waiting_start()
		RaceState.COUNTDOWN:
			_on_countdown_start()
		RaceState.RACING:
			_on_racing_start()
		RaceState.FINISHED:
			_on_race_finished()
	race_state_changed.emit(new_state)


func start_countdown() -> void:
	if current_state == RaceState.WAITING:
		set_race_state(RaceState.COUNTDOWN)


func _on_waiting_start() -> void:
	countdown_timer = 0.0
	for data in players.values():
		if data.get("vehicle") and data["vehicle"].has_method("stop_racing"):
			data["vehicle"].stop_racing()
	if race_hud and race_hud.has_method("show_waiting"):
		race_hud.show_waiting()


func _on_countdown_start() -> void:
	countdown_timer = float(COUNTDOWN_SECONDS)
	if race_hud and race_hud.has_method("show_countdown"):
		race_hud.show_countdown(int(countdown_timer))


func _update_countdown(delta: float) -> void:
	countdown_timer -= delta
	if race_hud and race_hud.has_method("update_countdown"):
		race_hud.update_countdown(int(countdown_timer) + 1)
	if countdown_timer <= 0.0:
		set_race_state(RaceState.RACING)


func _on_racing_start() -> void:
	race_start_time = Time.get_ticks_msec() / 1000.0
	for data in players.values():
		if data.get("vehicle") and data["vehicle"].has_method("start_racing"):
			data["vehicle"].start_racing()
	if race_hud and race_hud.has_method("show_race_hud"):
		race_hud.show_race_hud()


func _update_racing(_delta: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	for player_id in players.keys():
		var data = players[player_id]
		if not data.get("finished", false):
			data["race_time"] = current_time - race_start_time


func player_triggered_checkpoint(player_id: int, checkpoint_id: int) -> void:
	if not players.has(player_id) or current_state != RaceState.RACING:
		return
	var player_data = players[player_id]
	if checkpoint_id == 0 and player_data.get("sector", 0) > 0:
		player_data["lap"] = player_data.get("lap", 0) + 1
		var lap_time = Time.get_ticks_msec() / 1000.0 - race_start_time
		var lap_times: Array = player_data.get("lap_times", [])
		if lap_times.size() > 0:
			lap_time -= lap_times[-1]
		lap_times.append(lap_time)
		player_data["lap_times"] = lap_times
		player_lap_completed.emit(player_id, player_data["lap"], lap_time)
		if race_hud and race_hud.has_method("update_player_lap"):
			race_hud.update_player_lap(player_id, player_data["lap"])
		if player_data["lap"] >= RACE_LAPS:
			_finish_player(player_id)
	player_data["sector"] = checkpoint_id + 1


func _finish_player(player_id: int) -> void:
	var player_data = players[player_id]
	player_data["finished"] = true
	player_data["finish_time"] = player_data.get("race_time", 0.0)
	player_completion_order.append(player_id)
	if race_hud and race_hud.has_method("update_player_finished"):
		race_hud.update_player_finished(player_id, player_completion_order.size())
	var all_finished := true
	for data in players.values():
		if not data.get("finished", false):
			all_finished = false
			break
	if all_finished:
		set_race_state(RaceState.FINISHED)


func _on_race_finished() -> void:
	for data in players.values():
		if data.get("vehicle") and data["vehicle"].has_method("stop_racing"):
			data["vehicle"].stop_racing()
	if race_hud and race_hud.has_method("show_results"):
		race_hud.show_results(player_completion_order, players)
	race_finished.emit()


func get_player_data(player_id: int) -> Dictionary:
	if players.has(player_id):
		return players[player_id]
	return {}


func get_race_state() -> int:
	return current_state


func get_players_count() -> int:
	return players.size()
