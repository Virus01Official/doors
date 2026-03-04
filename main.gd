extends Node
var peer = ENetMultiplayerPeer.new()
@export var player_Scene: PackedScene
@export var use_seed := false
@export var world_seed := 0
var rng := RandomNumberGenerator.new()
@onready var lobbyname = $"CanvasLayer/UI/CreateLobby/LobbyName"
@onready var username = $"CanvasLayer/UI/CreateLobby/PlayerName"
@onready var joinlobbyname = $"CanvasLayer/UI/JoinLobby/LobbyName"
@onready var joinusername = $"CanvasLayer/UI/JoinLobby/PlayerName"

var fps_enabled = false
var deaf_enabled = false

var player_usernames := {}

func _ready():
	var create_button = $"CanvasLayer/UI/CreateLobby/CreateButton"
	create_button.pressed.connect(_on_host_pressed)
	
	var join_button = $"CanvasLayer/UI/JoinLobby/JoinButton2"
	join_button.pressed.connect(_on_join_pressed)
	
	var singleplayerButton = $"CanvasLayer/UI/Panel/VBoxContainer/Singleplayer"
	singleplayerButton.pressed.connect(_on_single_pressed)
	
	multiplayer.peer_connected.connect(_on_peer_connected)

func lobby_name_to_port(lobby_name: String) -> int:
	var hash_value = lobby_name.hash()
	return 10000 + (abs(hash_value) % 55535)
	
func _on_host_pressed() -> void:
	var port = lobby_name_to_port(lobbyname.text)
	print("Creating lobby '", lobbyname.text, "' on port: ", port)
	
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	
	var host_id = multiplayer.get_unique_id()
	player_usernames[host_id] = username.text
	
	add_player(host_id)
	$CanvasLayer.hide()
	
	if use_seed:
		rng.seed = world_seed
		print("Using seed: ", world_seed)
	else:
		rng.randomize()
		print("Using random seed: ", rng.seed)
		
func _on_single_pressed() -> void:
	var host_id = 1
	player_usernames[host_id] = "player"
	
	add_player(host_id)
	$CanvasLayer.hide()
	
	if use_seed:
		rng.seed = world_seed
		print("Using seed: ", world_seed)
	else:
		rng.randomize()
		print("Using random seed: ", rng.seed)
		
func _on_join_pressed() -> void:
	var port = lobby_name_to_port(joinlobbyname.text)
	print("Joining lobby '", joinlobbyname.text, "' on port: ", port)
	
	peer.create_client("127.0.0.1", port)
	multiplayer.multiplayer_peer = peer
	
	player_usernames[multiplayer.get_unique_id()] = joinusername.text
	
	$CanvasLayer.hide()
	print(rng.seed)

func _on_peer_connected(id: int):
	print("Peer connected: ", id)

@rpc("any_peer", "reliable")
func register_player(player_name: String):
	var sender_id = multiplayer.get_remote_sender_id()
	player_usernames[sender_id] = player_name
	print("Player registered: ", player_name, " (ID: ", sender_id, ")")
	
	add_player(sender_id)
	
	sync_all_players.rpc_id(sender_id, player_usernames)

@rpc("authority", "reliable")
func sync_all_players(all_usernames: Dictionary):
	player_usernames = all_usernames
	print("Received player sync: ", all_usernames)
	
	for id in player_usernames.keys():
		if id != multiplayer.get_unique_id():
			add_player(id)
	
	register_player.rpc_id(1, player_usernames[multiplayer.get_unique_id()])

func add_player(id: int):
	if has_node(str(id)):
		print("Player already exists: ", id)
		return
		
	var player = player_Scene.instantiate()
	player.name = str(id)
	
	var player_name = player_usernames.get(id, "Player_" + str(id))
	
	if player.has_method("set_username"):
		player.set_username(player_name)
	elif "username" in player:
		player.username = player_name
	
	print("Adding player: ", player_name, " with ID: ", id)
	call_deferred("add_child", player)
	
func exit_game(id):
	multiplayer.peer_disconnected.connect(del_player)
	del_player(id)
	
func del_player(id):
	if player_usernames.has(id):
		print("Player disconnected: ", player_usernames[id])
		player_usernames.erase(id)
	_del_player(id)
	
@rpc("any_peer", "call_local")
func _del_player(id):
	if has_node(str(id)):
		get_node(str(id)).queue_free()
