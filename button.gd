extends Button

func _on_pressed() -> void:
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$"../..".visible = false
	$"../../../HBoxContainer".visible = true
