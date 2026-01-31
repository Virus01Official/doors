extends Node3D
@export var coin_scene: PackedScene

func _ready():
	call_deferred("spawn_coin")

func spawn_coin():
	var spawn_point = get_parent().get_node("SpawnPoint")
	if !spawn_point:
		push_error("SpawnPoint not found!")
		return
	
	var coin = coin_scene.instantiate()
	get_parent().add_child(coin)
	
	coin.global_position = spawn_point.global_position
	coin.get_node("Area3D").add_to_group("door")
	
	queue_free()
