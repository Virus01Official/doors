extends Camera3D

func _process(delta: float) -> void:
	fov = clamp(data.FOV, 1.0, 179.0)
