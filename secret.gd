extends AudioStreamPlayer

func _ready():
	randomize()

func _process(_delta):
	if randi() % 10000 == 0:
		play_rare_sound()

func play_rare_sound():
	$".".play()
