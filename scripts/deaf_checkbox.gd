extends CheckBox

func _on_toggled(toggled_on: bool) -> void:
	$"../../../../../..".deaf_enabled = toggled_on
	$"../../../../Click".play()
