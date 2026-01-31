extends ProgressBar

func _on_value_changed(_value: float) -> void:
	if value < $".".max_value:
		$"..".visible = true
	else:
		$"..".visible = false
