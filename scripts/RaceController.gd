class_name RaceController extends Node

var game_manager: GameManager
var vehicle_spawner: VehicleSpawner
var race_track: RaceTrack


func _ready() -> void:
	game_manager = get_node_or_null("../GameManager")
	vehicle_spawner = get_node_or_null("../VehicleSpawner")
	race_track = get_node_or_null("../RaceTrack")
	await get_tree().process_frame
	_initialize_race()


func _physics_process(_delta: float) -> void:
	if InputMap.has_action("bounce") and Input.is_action_just_pressed("bounce"):
		match game_manager.get_race_state():
			GameManager.RaceState.WAITING:
				game_manager.start_countdown()
			GameManager.RaceState.FINISHED:
				_restart_race()


func _initialize_race() -> void:
	print("Race initialized with %d players" % game_manager.get_players_count())


func _restart_race() -> void:
	if vehicle_spawner:
		vehicle_spawner.reset_all_vehicles()
	if game_manager:
		game_manager.set_race_state(GameManager.RaceState.WAITING)
