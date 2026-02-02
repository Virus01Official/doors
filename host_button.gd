extends Button

func _on_pressed() -> void:
	$"../../CreateLobby".visible = true
	$"..".visible = false
