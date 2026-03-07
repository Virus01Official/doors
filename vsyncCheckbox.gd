extends CheckBox

func _on_pressed() -> void:
	$"../../../../Click".play()
	if not $".".button_pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
