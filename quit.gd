extends Button

func _on_pressed() -> void:
	$"../../../Click".play()
	get_tree().quit()
