extends CharacterBody3D

var time_elapsed: float = 0.0

func _ready() -> void:
	$AnimationPlayer.play("kitty/Take 001")

func _physics_process(delta: float) -> void:
	time_elapsed += delta
	if time_elapsed >= 15.0:
		time_elapsed = 0.0
		$AudioStreamPlayer3D.play()
