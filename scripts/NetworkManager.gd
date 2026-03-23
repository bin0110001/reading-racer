class_name NetworkManager extends Node

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal server_connected
signal server_disconnected

var multiplayer_api: MultiplayerAPI


func _ready() -> void:
	multiplayer_api = get_multiplayer()
	if multiplayer_api:
		multiplayer_api.connected_to_server.connect(_on_connected_to_server)
		multiplayer_api.peer_connected.connect(_on_peer_connected)
		multiplayer_api.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer_api.server_disconnected.connect(_on_server_disconnected)


func start_server(port: int = 9999) -> bool:
	if not multiplayer_api:
		return false
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, 8)
	if err != OK:
		push_error("Failed to create server: %s" % err)
		return false
	multiplayer_api.multiplayer_peer = peer
	print("Server started on port %d" % port)
	return true


func start_client(address: String, port: int = 9999) -> bool:
	if not multiplayer_api:
		return false
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, port)
	if err != OK:
		push_error("Failed to connect to server: %s" % err)
		return false
	multiplayer_api.multiplayer_peer = peer
	print("Connecting to server at %s:%d" % [address, port])
	return true


func is_server() -> bool:
	return multiplayer_api and multiplayer_api.is_server()


func is_client() -> bool:
	return multiplayer_api and multiplayer_api.is_client()


func get_local_peer_id() -> int:
	return multiplayer_api.get_unique_id() if multiplayer_api else -1


func get_connected_peers() -> Array[int]:
	if multiplayer_api:
		return Array(multiplayer_api.get_peers(), TYPE_INT, "", null)
	return []


@rpc(MultiplayerAPI.RPC_MODE_ANY_PEER, MultiplayerAPI.RPC_UNRELIABLE)
func broadcast_input(_player_id: int, _input_data: Dictionary) -> void:
	pass


func sync_player_input(_player_id: int, _input_data: Dictionary) -> void:
	if not multiplayer_api or not is_server():
		return
	rpc_id(MultiplayerAPI.RPC_TARGET_REMOTE, "broadcast_input", player_id, input_data)


@rpc(MultiplayerAPI.RPC_MODE_ANY_PEER, MultiplayerAPI.RPC_UNRELIABLE)
func sync_vehicle_transform(
	_player_id: int, _position: Vector3, _velocity: Vector3, _rotation: Quaternion
) -> void:
	pass


func sync_vehicle_state(
	_player_id: int, _position: Vector3, _velocity: Vector3, _rotation: Quaternion
) -> void:
	if not multiplayer_api:
		return
	rpc_id(
		MultiplayerAPI.RPC_TARGET_REMOTE,
		"sync_vehicle_transform",
		_player_id,
		_position,
		_velocity,
		_rotation
	)


@rpc(MultiplayerAPI.RPC_MODE_AUTHORITY, MultiplayerAPI.RPC_CALL_LOCAL)
func update_race_state(new_state: int) -> void:
	var gm = get_node_or_null("/root/Main/GameManager")
	if gm:
		gm.set_race_state(new_state)


func _on_connected_to_server() -> void:
	print("Connected to server")
	server_connected.emit()


func _on_peer_connected(peer_id: int) -> void:
	print("Peer joined: %d" % peer_id)
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: %d" % peer_id)
	peer_disconnected.emit(peer_id)


func _on_server_disconnected() -> void:
	print("Disconnected from server")
	server_disconnected.emit()
