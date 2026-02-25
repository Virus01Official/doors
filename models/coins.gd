extends Area3D

@export var coins = 25

func _ready() -> void:
	add_to_group("coins")
