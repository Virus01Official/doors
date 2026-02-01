extends CharacterBody3D

var SPEED = 10.0
const DEFAULT_SPEED = 10.0
const JUMP_VELOCITY = 4.5

var CROUCH_SPEED = 4.0
var CROUCH_CAMERA_HEIGHT = 0.5
var STAND_CAMERA_HEIGHT = 1.6

var health = 100
var max_health = 100

@export var void_y := -50.0
@export var respawn_position: Vector3

@onready var glitch_layer := $GlitchLayer

var sensitivity := 0.002  # Adjust sensitivity for mouse input

var target_rotation := Vector3.ZERO
var smooth_rotation := Vector3.ZERO

var CrucifixHeld = false

var is_crouching := false
var hidden = false

var batteries = 0

const max_batteries = 5

var coins = 0
var knobs = 0

var teleporting := false

@onready var camera := $Camera3D  
@onready var raycast := $Camera3D/RayCast3D
@onready var UI := $Control
@onready var coinsLabel := $Control/Coins/Label
@onready var roomNumLabel := $Control/Label2
@onready var timer = $Timer
@onready var timerItem = $TimerItems

@onready var healthUI = $Control/health/Health

@onready var deathUI = $Control/Death

@onready var item_holder := $Camera3D/items

@onready var shadow_overlay := $Camera3D/ShadowOverlay

@onready var anim_player := $AnimationPlayer

@onready var battery_Label = $Control/BatteryAmount/Label

var wardrobe_timer := 0.0
const WARDROBE_SAFE_TIME := 5.0
const WARDROBE_MAX_TIME := 12.0

var roomNum = 1

var inventory := ["", "", ""]  # 3 slots
var selected_slot := 0

var interact_handlers := {
	"coins": _interact_coin,
	"door": _interact_door,
	"giveHealth": _interact_health,
	"shelf": _interact_shelf,
	"wardrobe": _interact_wardrobe,
	"item": _interact_item,
	"battery": _interact_battery,
	"door2": _interact_side_door,
}

# item renders for the hotbar
var item_renders = {
	
}

var item_scenes := {
	"pills": preload("res://models/pills.tscn"),
	"flashlight": preload("res://models/flashlight.tscn"),
	"key": preload("res://models/key.tscn"),
}

func _ready() -> void:
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	STAND_CAMERA_HEIGHT = camera.position.y

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		target_rotation.x -= event.relative.y * sensitivity
		target_rotation.y -= event.relative.x * sensitivity
		
		target_rotation.x = clamp(target_rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
func update_held_item():
	# Remove current item
	for child in item_holder.get_children():
		child.queue_free()

	var item = inventory[selected_slot]
			
	if item == "":
		return

	if not item_scenes.has(item):
		return

	# Spawn new item
	var item_instance = item_scenes[item].instantiate()
	item_holder.add_child(item_instance)

	item_instance.position = Vector3.ZERO
	item_instance.rotation_degrees = Vector3(0, 90, 0)

# why the fuck the player's physics process holds all the logic?!
# to me from the past: sybau 

func _physics_process(delta: float) -> void:
	_smooth_rotation(delta)
	
	coinsLabel.text = "$" + str(coins)
	
	battery_Label.text = str(batteries) + "/" + str(max_batteries)
	
	healthUI.value = health
	healthUI.max_value = max_health
	
	if healthUI.value_changed:
		if healthUI.value <= 0:
			deathUI.visible = true
			if coins > 0:
				knobs = coins / 2.5
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider is Area3D:
			for group in interact_handlers.keys():
				if collider.is_in_group(group):
					UI.get_node("Label").visible = true
	else:
		UI.get_node("Label").visible = false

	if Input.is_action_pressed("crouch"):
		is_crouching = true
		SPEED = CROUCH_SPEED
	else:
		is_crouching = false
		SPEED = DEFAULT_SPEED
		
	if hidden:
		wardrobe_timer += delta
	else:
		wardrobe_timer = 0.0
		
	var shadow_strength := 0.0

	if hidden and wardrobe_timer > WARDROBE_SAFE_TIME:
		shadow_strength = clamp(
			(wardrobe_timer - WARDROBE_SAFE_TIME) / (WARDROBE_MAX_TIME - WARDROBE_SAFE_TIME),
			0.0, 1.0
		)

	# Apply to shader or modulate
	if shadow_overlay.material:
		shadow_overlay.material.set_shader_parameter("strength", shadow_strength)
	else:
		shadow_overlay.modulate.a = shadow_strength
		
	if hidden and wardrobe_timer >= WARDROBE_MAX_TIME:
		_force_exit_wardrobe()

		
	var target_cam_height = CROUCH_CAMERA_HEIGHT if is_crouching else STAND_CAMERA_HEIGHT
	camera.position.y = lerp(camera.position.y, target_cam_height, delta * 10)
	
	if global_position.y < void_y and not teleporting:
		teleporting = true
		start_void_teleport()
	
	if Input.is_action_just_pressed("slot_1"):
		selected_slot = 0
		update_held_item()
	elif Input.is_action_just_pressed("slot_2"):
		selected_slot = 1
		update_held_item()
	elif Input.is_action_just_pressed("slot_3"):
		selected_slot = 2
		update_held_item()

	if Input.is_action_just_pressed("use") and timerItem.is_stopped():
		var item = inventory[selected_slot]

		if item == "":
			return

		if "pills" in item:
			timerItem.start(2)
			SPEED = DEFAULT_SPEED * 2
			inventory[selected_slot] = ""
			print("Used pills from slot", selected_slot + 1)
			update_held_item()
	
	if Input.is_action_just_pressed("interact") and raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider is Area3D:
			try_interact(collider)
		
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	_handle_animation(direction)
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _handle_animation(direction: Vector3) -> void:
	if not anim_player:
		return
	
	var _current_item = inventory[selected_slot]
		
	# Check if player is moving
	var is_moving = direction.length() > 0.1
	
	if is_moving:
		if is_crouching:
			# Play crouch walk animation if you have one
			if anim_player.has_animation("test/crouch_walk"):
				if anim_player.current_animation != "test/crouch_walk":
					anim_player.play("test/crouch_walk")
			else:
				# Fall back to regular walk at slower speed
				if anim_player.current_animation != "test/walk":
					anim_player.play("test/walk")
				anim_player.speed_scale = 0.5
		else:
			# Play walk animation
			if anim_player.current_animation != "test/run":
				anim_player.play("test/run")
			anim_player.speed_scale = 1.0
	else:
		# Play idle animation when not moving
		if is_crouching:
			if anim_player.has_animation("test/crouch_idle"):
				if anim_player.current_animation != "test/crouch_idle":
					anim_player.play("test/crouch_idle")
			else:
				if anim_player.current_animation != "test/idle":
					anim_player.play("test/idle")
		else:
			if anim_player.current_animation != "test/idle":
				anim_player.play("test/idle")
			
func try_interact(collider: Area3D):
	for group in interact_handlers.keys():
		if collider.is_in_group(group):
			interact_handlers[group].call(collider)
			return
			
func _force_exit_wardrobe():
	hidden = false
	wardrobe_timer = 0.0

	camera.current = true

	health -= 35

	if shadow_overlay.material:
		shadow_overlay.material.set_shader_parameter("strength", 0.0)
	else:
		shadow_overlay.modulate.a = 0.0

func _interact_coin(collider):
	coins += collider.coins
	$coin.play()
	collider.queue_free()

func _interact_door(collider):
	var door_parent = collider.get_parent()
		
	if door_parent.open:
		return

	if door_parent.has_meta("locked") and door_parent.get_meta("locked") == true:
		if not player_has_key():
			print("Door is locked")
			return
		else:
			consume_key()
			door_parent.set_meta("locked", false)
				
	open_door(collider)
	
func _interact_side_door(collider):
	if collider.get_parent().open:
		return
		
	open_side_door(collider)
	
func _interact_shelf(collider: Area3D) -> void:
	collider.get_parent().get_node("Open").play()
	var shelf_door = collider.get_parent().get_node("Shelfdoor")
	var target_position = collider.get_parent().get_node("Marker3D").global_position
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(shelf_door, "global_position", target_position, 0.5)
	
	await tween.finished
	collider.queue_free()

func player_has_key() -> bool:
	for item in inventory:
		if item == "key":
			return true
	return false

func consume_key():
	for i in inventory.size():
		if inventory[i] == "key":
			inventory[i] = ""
			if i == selected_slot:
				update_held_item()
			return
			
func _interact_item(collider: Area3D) -> void:
	var item_name := collider.get_parent().name.to_lower()

	for i in inventory.size():
		if inventory[i] == "":
			inventory[i] = item_name
			collider.get_parent().queue_free()

			if i == selected_slot:
				update_held_item()

			print("Picked up:", item_name, "in slot", i + 1)
			return

func _interact_wardrobe(collider: Area3D) -> void:
	if hidden == false:
		var target_pos = collider.get_parent().get_node("MeshInstance3D").global_position
		global_position = target_pos
		hidden = true
		collider.get_parent().get_node("Camera3D").current = true
		wardrobe_timer = 0.0
	else:
		var target_pos = collider.get_parent().get_node("leaveTeleport").global_position
		global_position = target_pos
		hidden = false
		camera.current = true
		wardrobe_timer = 0.0

func _interact_health(collider):
	if health < max_health:
		health += collider.give_health
		collider.queue_free()
		
func _interact_battery(collider):
	if batteries != max_batteries:
		batteries += 1
		collider.queue_free()

func start_void_teleport():
	if glitch_layer:
		glitch_layer.start_glitch()
		
	$glitch.play()
	health -= 30

	await get_tree().create_timer(0.5).timeout

	global_position = respawn_position
	velocity = Vector3.ZERO

	await get_tree().create_timer(0.2).timeout

	if glitch_layer:
		glitch_layer.stop_glitch()

	teleporting = false
	
func open_door(door):
	var door_parent = door.get_parent()
	
	var door_width = 1.0  
	
	var original_pos = door_parent.global_position
	
	door_parent.translate(Vector3(-door_width / 2, 0, 0))  
	
	# Create a tween for smooth animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	var target_rotation2 = door_parent.global_rotation_degrees.y + 90
	tween.tween_property(door_parent, "global_rotation_degrees:y", target_rotation2, 0.5)
	
	var rooms_node = get_tree().current_scene.get_node("Game").get_node("Rooms")
	var current_room = door_parent.get_parent().get_parent()  
	rooms_node.generate_room(current_room)
	
	roomNum += 1
	door_parent.open = true
	door_parent.get_node("CollisionShape3D").disabled = true
	door_parent.get_node("OpenSound").play()
	respawn_position = original_pos
	
	roomNumLabel.text = "Room: " + str(roomNum)
	roomNumLabel.visible = true
	timer.start(1)
	
	await tween.finished
	door.queue_free()
	
func open_side_door(door):
	var door_parent = door.get_parent()
	
	var door_width = 1.0  
	
	var original_pos = door_parent.global_position
	
	door_parent.translate(Vector3(-door_width / 2, 0, 0))  
	
	# Create a tween for smooth animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	var target_rotation2 = door_parent.global_rotation_degrees.y + 90
	tween.tween_property(door_parent, "global_rotation_degrees:y", target_rotation2, 0.5)
	
	roomNum += 1
	door_parent.open = true
	door_parent.get_node("CollisionShape3D").disabled = true
	door_parent.get_node("OpenSound").play()
	respawn_position = original_pos
	
	roomNumLabel.text = "Room: " + str(roomNum)
	roomNumLabel.visible = true
	timer.start(1)
	
	await tween.finished
	door.queue_free()
	
func _smooth_rotation(delta: float) -> void:
	smooth_rotation = smooth_rotation.lerp(target_rotation, delta * 10)
	rotation.y = smooth_rotation.y  
	camera.rotation.x = smooth_rotation.x  

func _on_timer_timeout() -> void:
	roomNumLabel.visible = false

func _on_timer_items_timeout() -> void:
	SPEED = DEFAULT_SPEED
