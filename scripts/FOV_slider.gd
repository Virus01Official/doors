extends HSlider

func _on_value_changed(valued: float) -> void:
	$"../../../../roll".play()
	data.FOV = valued
