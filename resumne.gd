extends Button

func _on_pressed() -> void:
	$"..".visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
