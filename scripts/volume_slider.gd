extends HSlider

func _on_value_changed(valued: float) -> void:
	$"../../../../roll".play()
	var db = linear_to_db(valued / 100.0)
	AudioServer.set_bus_volume_db(0, db)
