extends MeshInstance3D

@export var spawn_scenes: Array[PackedScene] = []
@export var spawn_chance := 3  # 1 in 3 chance

func _ready():
	randomize()

	if spawn_scenes.is_empty():
		queue_free()
		return

	if randi() % spawn_chance == 0:
		spawn_random_scene()

	queue_free()

func spawn_random_scene():
	var scene: PackedScene = spawn_scenes.pick_random()
	var instance = scene.instantiate()
	
	instance.position = position

	get_parent().add_child.call_deferred(instance)
