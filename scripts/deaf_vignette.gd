extends ColorRect

func _process(_delta: float) -> void:
	$".".visible = data.deaf_mode
