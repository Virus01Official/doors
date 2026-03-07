extends HSlider

func _on_value_changed(valued: float) -> void:
	$"../../../../roll".play()
	data.Sensitivity = valued / 10000.0
