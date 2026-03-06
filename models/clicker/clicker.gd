extends Node3D

func _ready() -> void:
	$Area3D.add_to_group("item")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("use") and get_parent().name == "items":
		$AudioStreamPlayer3D.play()
