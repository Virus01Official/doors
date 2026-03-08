extends StaticBody3D

@export var open = false
@export var locked = false

func _ready():
	pass  

func try_open():
	if locked:
		print("Door is locked!")
		return
	open_door()

func open_door():
	open = true
