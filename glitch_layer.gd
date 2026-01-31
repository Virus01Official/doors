extends CanvasLayer

@onready var rect := $ColorRect
@onready var mat = rect.material

func _ready():
	rect.visible = false


func start_glitch():
	rect.visible = true
	mat.set_shader_parameter("strength", 1.0)


func stop_glitch():
	mat.set_shader_parameter("strength", 0.0)
	await get_tree().create_timer(0.1).timeout
	rect.visible = false
