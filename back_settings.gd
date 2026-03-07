extends Button

func _on_pressed() -> void:
	$"../../Panel".visible = true
	$"..".visible = false
	$"../../Click".play()
