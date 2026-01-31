extends CharacterBody3D

@export var speed := 15.0
var target_position: Vector3

@onready var raycast = $RayCast3D
@onready var raycast2 = $RayCast3D2
@onready var raycast3 = $RayCast3D3
@onready var raycast4 = $RayCast3D4

func _ready() -> void:
	$Scream.play()

func _physics_process(_delta):
	if target_position == Vector3.ZERO:
		return

	var direction = (target_position - global_transform.origin)
	
	if direction.length() < 1.0:
		queue_free()
		return

	velocity = direction.normalized() * speed
	move_and_slide()
	
	for rc in [raycast, raycast2, raycast3, raycast4]:
		if rc.is_colliding():
			var collider = rc.get_collider()
			if collider is CharacterBody3D and not collider.hidden:
				collider.health = 0
				queue_free()
				return
