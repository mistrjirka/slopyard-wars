extends Node
## Optional ENet adapter. Owns connections and RPCs, never gameplay rules.
signal action_received(peer_id: int, action: String, data: Dictionary)
signal hello_received(peer_id: int, player_name: String)
signal peer_arrived(peer_id: int)
signal peer_left(peer_id: int)
signal snapshot_received(snapshot: Dictionary)
signal notice_received(message: String)
signal connection_failed
signal server_left

const Config = preload("res://src/core/game_config.gd")
var _join_name := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int): peer_arrived.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int): peer_left.emit(id))
	multiplayer.connected_to_server.connect(func(): _hello.rpc_id(1, _join_name))
	multiplayer.connection_failed.connect(func(): connection_failed.emit())
	multiplayer.server_disconnected.connect(func(): server_left.emit())


func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(Config.PORT, Config.MAX_PLAYERS - 1)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error


func join(address: String, player_name: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address if address != "" else "127.0.0.1", Config.PORT)
	if error == OK:
		_join_name = player_name
		multiplayer.multiplayer_peer = peer
	return error


func close() -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func send_action(action: String, data: Dictionary) -> void:
	_action.rpc_id(1, action, data)


func send_snapshot(peer_id: int, snapshot: Dictionary) -> void:
	_snapshot.rpc_id(peer_id, snapshot)


func send_notice(peer_id: int, message: String) -> void:
	_notice.rpc_id(peer_id, message)


@rpc("any_peer", "call_remote", "reliable")


func _action(action: String, data: Dictionary) -> void:
	if multiplayer.is_server():
		action_received.emit(multiplayer.get_remote_sender_id(), action, data)


@rpc("any_peer", "call_remote", "reliable")


func _hello(player_name: String) -> void:
	if multiplayer.is_server():
		hello_received.emit(multiplayer.get_remote_sender_id(), player_name)


@rpc("authority", "call_remote", "reliable")


func _snapshot(snapshot: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		snapshot_received.emit(snapshot)


@rpc("authority", "call_remote", "reliable")


func _notice(message: String) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		notice_received.emit(message)
