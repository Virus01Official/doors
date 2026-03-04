extends CheckBox

func _on_toggled(toggled_on: bool) -> void:
	$"../../../../../..".fps_enabled = toggled_on
