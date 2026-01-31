extends Node3D

func _ready():
	$UI/StartButton.visible = multiplayer.is_server()
	pass

func _on_start_button_pressed():
	if multiplayer.is_server():
		get_parent().rpc("rpc_load_game")
