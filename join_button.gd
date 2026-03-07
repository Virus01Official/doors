extends Button

func _on_pressed() -> void:
	$"../../JoinLobby".visible = true
	$"..".visible = false
	$"../../Click".play()
