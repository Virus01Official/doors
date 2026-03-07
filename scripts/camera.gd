extends Camera3D

func _process(_delta: float) -> void:
	fov = clamp(data.FOV, 1.0, 179.0)
