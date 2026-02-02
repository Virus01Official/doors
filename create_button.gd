extends Button

var peer = ENetMultiplayerPeer.new()

@onready var main = $"../../.."

@onready var lobbyname = $"../../CreateLobby/LobbyName"
@onready var username = $"../../CreateLobby/PlayerName"

func _on_pressed() -> void:
	peer.create_server(int(lobbyname.text))
	multiplayer.multiplayer_peer = peer
