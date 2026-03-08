extends CheckBox

func _on_toggled(toggled_on: bool) -> void:
	data.fps_enabled = toggled_on
	$"../../../../Click".play()
	data.save_settings()
