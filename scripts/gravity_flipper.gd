extends Area3D

@export var flip_direction: int = 0
# 0=DOWN, 1=UP, 2=LEFT, 3=RIGHT, 4=FORWARD, 5=BACKWARD

@export var one_shot := true  # disable after first use to avoid spam
var triggered := false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if one_shot and triggered:
		return
	if body.has_method("set_gravity_direction"):
		triggered = true
		body.set_gravity_direction(body.GravityDir.values()[flip_direction])
