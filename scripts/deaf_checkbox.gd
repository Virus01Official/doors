extends CheckBox

func _on_toggled(toggled_on: bool) -> void:
	data.deaf_mode = toggled_on
	data.save_settings()
	$"../../../../Click".play()
