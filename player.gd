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

var sensitivity := 0.010

var target_rotation := Vector3.ZERO
var smooth_rotation := Vector3.ZERO

var CrucifixHeld = false

var is_crouching := false
var hidden = false

var username := ""

var batteries = 0
const max_batteries = 5

var coins = 0
var knobs = 0

var teleporting := false

@onready var camera := $Camera3D  
@onready var raycast := $Camera3D/RayCast3D
@onready var UI := $Control
@onready var coinsLabel := $Control/Coins/Label
@onready var coinsUI := $Control/Coins
@onready var roomNumLabel := $Control/Label2
@onready var DeafAlert := $Control/DeafVignette
@onready var timer = $Timer
@onready var timerItem = $TimerItems

@onready var healthUI = $Control/health/Health
@onready var deathUI = $Control/Death
@onready var item_holder := $items
@onready var shadow_overlay := $Camera3D/ShadowOverlay
@onready var anim_player := $AnimationPlayer
@onready var battery_Label = $Control/BatteryAmount/Label
@onready var batteryUI = $Control/BatteryAmount
@onready var hotbarUI = $Control/Hotbar
@onready var shop = $Control/shop
@onready var animationtree = $AnimationTree

# Cached AnimationTree playback reference
var _anim_state_machine: AnimationNodeStateMachinePlayback

var wardrobe_timer := 0.0
const WARDROBE_SAFE_TIME := 5.0
const WARDROBE_MAX_TIME := 12.0

var roomNum = 1

var inventory := ["", "", "", "", "", "", "", "", ""]
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
	"ladder": _interact_ladder,
	"car": _interact_cat,
	"shelf2": _interact_shelf2,
}

var item_renders = {}

var item_scenes := {
	"pills": preload("res://models/pills.tscn"),
	"flashlight": preload("res://models/flashlight.tscn"),
	"key": preload("res://models/key.tscn"),
	"clicker": preload("res://models/clicker/clicker.tscn"),
}

func _ready() -> void:
	camera.current = is_multiplayer_authority()
	shop.visible = is_multiplayer_authority()
	coinsUI.visible = is_multiplayer_authority()
	batteryUI.visible = is_multiplayer_authority()

	STAND_CAMERA_HEIGHT = camera.position.y

	# Set up AnimationTree
	animationtree.active = true
	_anim_state_machine = animationtree["parameters/StateMachine/playback"]

	if username != "":
		print("Player loaded: ", username)

func set_username(new_username: String) -> void:
	username = new_username
	$PlayerUser.text = username

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		target_rotation.x -= event.relative.y * sensitivity
		target_rotation.y -= event.relative.x * sensitivity
		target_rotation.x = clamp(target_rotation.x, deg_to_rad(-80), deg_to_rad(80))

func update_held_item():
	for child in item_holder.get_children():
		child.queue_free()

	var item = inventory[selected_slot]
	if item == "":
		return
	if not item_scenes.has(item):
		return

	var item_instance = item_scenes[item].instantiate()
	item_holder.add_child(item_instance)
	#item_instance.position = Vector3.ZERO
	item_instance.rotation_degrees = Vector3(0, 90, 0)

func _update_flashlight_blend() -> void:
	var holding_flashlight = inventory[selected_slot] == "flashlight"
	var target_blend := 1.0 if holding_flashlight else 0.0
	animationtree["parameters/Blend2/blend_amount"] = target_blend
	
func _update_pills_blend() -> void:
	var holding_pills = inventory[selected_slot] == "pills"
	var target_blend := 1.0 if holding_pills else 0.0
	animationtree["parameters/Blend2Again/blend_amount"] = target_blend
	
func _update_keycard_blend() -> void:
	var holding_key = inventory[selected_slot] == "key"
	var target_blend := 1.0 if holding_key else 0.0
	animationtree["parameters/Blend2 2/blend_amount"] = target_blend
	
func _update_remote_use_blend() -> void:
	var holding_key = inventory[selected_slot] == "remote"
	var target_blend := 1.0 if holding_key else 0.0
	animationtree["parameters/Blend2 3/blend_amount"] = target_blend
	
func _update_remote_hold_blend() -> void:
	var holding_key = inventory[selected_slot] == "remote"
	var target_blend := 1.0 if holding_key else 0.0
	animationtree["parameters/Blend2 4/blend_amount"] = target_blend
	
func _handle_animation(direction: Vector3) -> void:
	if not _anim_state_machine:
		return

	var is_moving := direction.length() > 0.1

	if is_moving:
		if is_crouching:
			# Try crouch_walk first, fall back to walk
			if animationtree.get_animation_list().has("test/crouch_walk") if animationtree.has_method("get_animation_list") else false:
				_anim_state_machine.travel("test_crouch_walk")
			else:
				_anim_state_machine.travel("test_walk")
		else:
			_anim_state_machine.travel("test_run")
	else:
		if is_crouching:
			if animationtree.get_animation_list().has("test/crouch_idle") if animationtree.has_method("get_animation_list") else false:
				_anim_state_machine.travel("test_crouch_idle")
			else:
				_anim_state_machine.travel("test_idle")
		else:
			_anim_state_machine.travel("test_idle")

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
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
		
		if data.rusher_spawned:
			DeafAlert.material.set_shader_parameter("active", true)
		else:
			DeafAlert.material.set_shader_parameter("active", false)
		
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

		# Update animations every frame
		_handle_animation(direction)
		_update_flashlight_blend()
		_update_pills_blend()
		_update_keycard_blend()
		_update_remote_hold_blend()

		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

		move_and_slide()

func try_interact(collider: Area3D):
	if not is_multiplayer_authority():
		return
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
	var coin_path = get_path_to(collider)
	rpc("sync_coin_collection", coin_path, collider.coins)

@rpc("any_peer", "call_local", "reliable")
func sync_coin_collection(coin_path: NodePath, coin_value: int):
	var coin_node = get_node_or_null(coin_path)
	if coin_node and is_instance_valid(coin_node):
		if is_multiplayer_authority():
			coins += coin_value
			$coin.play()
		coin_node.queue_free()

func _interact_door(collider):
	if not is_multiplayer_authority():
		return
	var door_parent = collider.get_parent()
	if door_parent.open:
		return
	if door_parent.locked:
		if not player_has_key():
			door_parent.get_node("LockedSound").play()
			return
		else:
			consume_key()
			door_parent.locked = false
	var door_path = get_path_to(collider)
	rpc("sync_door_open", door_path, false)

func _interact_side_door(collider):
	if not is_multiplayer_authority():
		return
	if collider.get_parent().open:
		return
	var door_path = get_path_to(collider)
	rpc("sync_door_open", door_path, true)

@rpc("any_peer", "call_local", "reliable")
func sync_door_open(door_path: NodePath, is_side_door: bool):
	var door = get_node_or_null(door_path)
	if not door or not is_instance_valid(door):
		return
	if is_side_door:
		await open_side_door_internal(door)
	else:
		await open_door_internal(door)

func _interact_cat(_collider):
	if not is_multiplayer_authority():
		return
	print("pet")

func open_door_internal(door):
	var door_parent = door.get_parent()
	if door_parent.open:
		return
	var original_pos = door_parent.global_position
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	var target_position = door_parent.global_position + Vector3(0, 3.0, 0)
	tween.tween_property(door_parent, "global_position", target_position, 0.5)
	if multiplayer.is_server():
		var rooms_node = get_tree().current_scene.get_node("Game").get_node("Rooms")
		var current_room = door_parent.get_parent().get_parent()
		rooms_node.generate_room(current_room)
	if is_multiplayer_authority():
		roomNum += 1
		respawn_position = original_pos
		roomNumLabel.text = "Room: " + str(roomNum)
		roomNumLabel.visible = true
		timer.start(1)
	door_parent.open = true
	door_parent.get_node("CollisionShape3D").disabled = true
	door_parent.get_node("OpenSound").play()
	await tween.finished
	door.queue_free()
	
func open_side_door_internal(door):
	var door_parent = door.get_parent()
	if door_parent.open:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	var target_position = door_parent.global_position + Vector3(0, 3.0, 0)
	tween.tween_property(door_parent, "global_position", target_position, 0.5)
	door_parent.open = true
	door_parent.get_node("CollisionShape3D").disabled = true
	door_parent.get_node("OpenSound").play()
	await tween.finished
	door.queue_free()

func open_door(door):
	if is_multiplayer_authority():
		var door_path = get_path_to(door)
		rpc("sync_door_open", door_path, false)

func open_side_door(door):
	if is_multiplayer_authority():
		var door_path = get_path_to(door)
		rpc("sync_door_open", door_path, true)

func _interact_shelf(collider: Area3D) -> void:
	if not is_multiplayer_authority():
		return
	var shelf_path = get_path_to(collider)
	rpc("sync_shelf_open", shelf_path)

func _interact_shelf2(collider: Area3D) -> void:
	if not is_multiplayer_authority():
		return
	var shelf_path = get_path_to(collider)
	rpc("sync_shelf_open2", shelf_path)

@rpc("any_peer", "call_local", "reliable")
func sync_shelf_open(shelf_path: NodePath):
	var collider = get_node_or_null(shelf_path)
	if not collider or not is_instance_valid(collider):
		return
	collider.get_parent().get_node("Open").play()
	var shelf_door = collider.get_parent().get_node("Shelfdoor")
	var target_position = collider.get_parent().get_node("Marker3D").global_position
	collider.queue_free()
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(shelf_door, "global_position", target_position, 0.5)
	await tween.finished

@rpc("any_peer", "call_local", "reliable")
func sync_shelf_open2(shelf_path: NodePath):
	var collider = get_node_or_null(shelf_path)
	if not collider or not is_instance_valid(collider):
		return
	collider.get_parent().get_node("Open").play()
	var shelf_door = collider.door
	var target_position = collider.marker.global_position
	collider.queue_free()
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(shelf_door, "global_position", target_position, 0.5)
	await tween.finished

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
	if not is_multiplayer_authority():
		return
	var item_name := collider.get_parent().name.to_lower()
	for i in inventory.size():
		if inventory[i] == "":
			inventory[i] = item_name
			var item_path = get_path_to(collider.get_parent())
			rpc("sync_item_pickup", item_path)
			if i == selected_slot:
				update_held_item()
			print("Picked up:", item_name, "in slot", i + 1)
			return

@rpc("any_peer", "call_local", "reliable")
func sync_item_pickup(item_path: NodePath):
	var item = get_node_or_null(item_path)
	if item and is_instance_valid(item):
		item.queue_free()

func _interact_wardrobe(collider: Area3D) -> void:
	if hidden == false:
		var wardrobe = collider.get_parent()
		# Use a dedicated inside marker instead of MeshInstance3D center
		var inside_marker = wardrobe.get_node_or_null("InsideTeleport")
		var target_pos = inside_marker.global_position if inside_marker else wardrobe.get_node("MeshInstance3D").global_position
		global_position = target_pos
		hidden = true
		wardrobe.get_node("Camera3D").current = true
		wardrobe_timer = 0.0
	else:
		var wardrobe = collider.get_parent()
		global_position = wardrobe.get_node("leaveTeleport").global_position
		hidden = false
		camera.current = true
		wardrobe_timer = 0.0

func _interact_ladder(collider: Area3D) -> void:
	var target_pos = collider.get_node("Teleport").global_position
	global_position = target_pos

func _interact_health(collider):
	if health < max_health:
		var health_path = get_path_to(collider)
		rpc("sync_health_pickup", health_path, collider.give_health)

@rpc("any_peer", "call_local", "reliable")
func sync_health_pickup(health_path: NodePath, health_amount: int):
	var health_pickup = get_node_or_null(health_path)
	if health_pickup and is_instance_valid(health_pickup):
		if is_multiplayer_authority():
			health += health_amount
		health_pickup.queue_free()

func _interact_battery(collider):
	if batteries != max_batteries:
		var battery_path = get_path_to(collider)
		rpc("sync_battery_pickup", battery_path)

@rpc("any_peer", "call_local", "reliable")
func sync_battery_pickup(battery_path: NodePath):
	var battery = get_node_or_null(battery_path)
	if battery and is_instance_valid(battery):
		if is_multiplayer_authority():
			batteries += 1
		battery.queue_free()

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

func _smooth_rotation(delta: float) -> void:
	smooth_rotation = smooth_rotation.lerp(target_rotation, delta * 10)
	rotation.y = smooth_rotation.y
	camera.rotation.x = smooth_rotation.x

func _on_timer_timeout() -> void:
	roomNumLabel.visible = false

func _on_timer_items_timeout() -> void:
	SPEED = DEFAULT_SPEED
