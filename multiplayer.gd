extends Button

func _on_pressed() -> void:
	$"../../../MultiplayerPanel".visible = true
	$"../..".visible = false
	$"../../../Click".play()
