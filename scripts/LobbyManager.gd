extends Node

signal lobby_created(lobby_id)
signal player_joined(player_id, player_name)
signal player_left(player_id)
signal lobby_updated(lobby_data)
signal game_started()

var current_lobby = {
	"id": "",
	"host_id": "",
	"players": {},  # {player_id: {name: "", ready: false}}
	"max_players": 4,
	"is_host": false
}

var player_id = ""
var player_name = ""

const DEFAULT_PORT = 7777
var peer = null


func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func create_lobby(host_name: String, max_players: int = 4) -> bool:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, max_players)
	
	if error != OK:
		print("Failed to create server: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	
	player_id = str(multiplayer.get_unique_id())
	player_name = host_name
	
	current_lobby.id = _generate_lobby_id()
	current_lobby.host_id = player_id
	current_lobby.is_host = true
	current_lobby.max_players = max_players
	current_lobby.players[player_id] = {
		"name": host_name,
		"ready": true
	}
	
	print("Lobby created with ID: ", current_lobby.id)
	lobby_created.emit(current_lobby.id)
	lobby_updated.emit(current_lobby)
	
	return true

func join_lobby(ip_address: String, join_name: String) -> bool:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, DEFAULT_PORT)
	
	if error != OK:
		print("Failed to connect to server: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	player_name = join_name
	
	return true

func leave_lobby():
	if peer:
		if current_lobby.is_host:
			rpc("_notify_lobby_closed")
		else:
			rpc_id(1, "_player_left", player_id)
		
		peer.close()
		peer = null
		multiplayer.multiplayer_peer = null
	
	_reset_lobby()

func start_game():
	if not current_lobby.is_host:
		print("Only the host can start the game!")
		return
	
	# Check if all players are ready (optional)
	# for player in current_lobby.players.values():
	#     if not player.ready:
	#         print("Not all players are ready!")
	#         return
	
	print("Starting game...")
	rpc("_transition_to_game")

func toggle_ready():
	if current_lobby.is_host:
		return  
	
	var is_ready = current_lobby.players[player_id].ready
	current_lobby.players[player_id].ready = !is_ready
	
	# Notify server of ready status change
	rpc_id(1, "_update_player_ready", player_id, !is_ready)

func _on_player_connected(id: int):
	print("Player connected: ", id)

func _on_player_disconnected(id: int):
	print("Player disconnected: ", id)
	var disconnected_player_id = str(id)
	
	if current_lobby.players.has(disconnected_player_id):
		var _player_data = current_lobby.players[disconnected_player_id]
		current_lobby.players.erase(disconnected_player_id)
		
		player_left.emit(disconnected_player_id)
		lobby_updated.emit(current_lobby)
		
		rpc("_sync_lobby_data", current_lobby)

func _on_connected_to_server():
	print("Successfully connected to server")
	player_id = str(multiplayer.get_unique_id())
	
	rpc_id(1, "_request_join", player_id, player_name)

func _on_connection_failed():
	print("Connection to server failed")
	_reset_lobby()

func _on_server_disconnected():
	print("Disconnected from server")
	_reset_lobby()

@rpc("any_peer", "reliable")
func _request_join(join_player_id: String, join_player_name: String):
	if not current_lobby.is_host:
		return
	
	if current_lobby.players.size() >= current_lobby.max_players:
		rpc_id(int(join_player_id), "_join_denied", "Lobby is full")
		return
	
	current_lobby.players[join_player_id] = {
		"name": join_player_name,
		"ready": false
	}
	
	print("Player joined: ", join_player_name)
	player_joined.emit(join_player_id, join_player_name)
	
	rpc_id(int(join_player_id), "_join_accepted", current_lobby)
	
	rpc("_sync_lobby_data", current_lobby)

@rpc("authority", "reliable")
func _join_accepted(lobby_data: Dictionary):
	current_lobby = lobby_data
	current_lobby.is_host = false
	print("Joined lobby successfully")
	lobby_updated.emit(current_lobby)

@rpc("authority", "reliable")
func _join_denied(reason: String):
	print("Failed to join lobby: ", reason)
	_reset_lobby()

@rpc("any_peer", "reliable")
func _sync_lobby_data(lobby_data: Dictionary):
	if current_lobby.is_host:
		return  # Host has authoritative data
	
	current_lobby.players = lobby_data.players
	lobby_updated.emit(current_lobby)

@rpc("any_peer", "reliable")
func _update_player_ready(ready_player_id: String, is_ready: bool):
	if not current_lobby.is_host:
		return
	
	if current_lobby.players.has(ready_player_id):
		current_lobby.players[ready_player_id].ready = is_ready
		
		# Sync to all clients
		rpc("_sync_lobby_data", current_lobby)
		lobby_updated.emit(current_lobby)

@rpc("any_peer", "reliable")
func _player_left(left_player_id: String):
	if not current_lobby.is_host:
		return
	
	if current_lobby.players.has(left_player_id):
		current_lobby.players.erase(left_player_id)
		player_left.emit(left_player_id)
		
		# Sync to all clients
		rpc("_sync_lobby_data", current_lobby)
		lobby_updated.emit(current_lobby)

@rpc("authority", "call_local", "reliable")
func _transition_to_game():
	print("Transitioning to game scene...")
	game_started.emit()
	
	# Change to game scene
	get_tree().change_scene_to_file("res://game.tscn")

@rpc("authority", "call_local", "reliable")
func _notify_lobby_closed():
	print("Lobby has been closed by host")
	_reset_lobby()

func _generate_lobby_id() -> String:
	return str(randi() % 100000).pad_zeros(5)

func _reset_lobby():
	current_lobby = {
		"id": "",
		"host_id": "",
		"players": {},
		"max_players": 4,
		"is_host": false
	}
	player_id = ""
	
	if peer:
		peer.close()
		peer = null
		multiplayer.multiplayer_peer = null


func get_player_count() -> int:
	return current_lobby.players.size()


func is_host() -> bool:
	return current_lobby.is_host


func get_lobby_id() -> String:
	return current_lobby.id
