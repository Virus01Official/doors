extends Node3D

const LIGHT_BREAK_CHANCE := 0.2

const NORMAL_FLICKER_COUNT := 2
const NORMAL_FLICKER_INTERVAL := 0.08

const RUSH_FLICKER_TIME := 1.5
const RUSH_FLICKER_INTERVAL := 0.04

@onready var rng = get_node("../..").rng

var room_scenes: Array[PackedScene] = [
	preload("res://rooms/room_a.tscn"),
	preload("res://rooms/room_b.tscn"),
	preload("res://rooms/room_c.tscn"),
	preload("res://rooms/room_d.tscn"),
	preload("res://rooms/room_e.tscn"),
	preload("res://rooms/room_f.tscn"),
	preload("res://rooms/room_g.tscn"),
]

var specialRooms = {
	"Room 50" = preload("res://rooms/room_50.tscn"),
}

var secret_rooms := [
	{
		"scene": preload("res://rooms/secret_room_a.tscn"),
		"chance": 0.01 # 1%
	},
]

var MAX_ROOMS = 5

var roomNum = 1

var RushMonsters: Array[PackedScene] = [
	preload("res://monster.tscn"),
]

const STALKER_MONSTER_SCENE := preload("res://stalker.tscn")

const KEY_SCENE := preload("res://models/key.tscn")

const LOCKED_DOOR_CHANCE := 0.35

var active_rush = null
var active_stalker = null

const RUSH_COOLDOWN_ROOMS = 4

# Stalker monster settings
const STALKER_START_ROOM = 10
const STALKER_CHECK_INTERVAL = 3.0  # Check every 3 seconds if player is looking back
const STALKER_NO_LOOK_DURATION = 8.0  # Spawn if player doesn't look back for 8 seconds
const STALKER_SPAWN_DISTANCE = 15.0
const STALKER_SPAWN_CHANCE = 0.3  # 30% chance when conditions are met

var time_since_stalker_check := 0.0
var player_not_looking_back_time := 0.0

var rooms_since_last_rush := RUSH_COOLDOWN_ROOMS
var has_seen_wardrobe := false

const RUSH_START_ROOM = 7
const RUSH_SPAWN_OFFSET = 3
const RUSH_SPAWN_CHANCE = 0.5 # 50% chance

var generated_rooms = []

func _ready():
	var spawn_room = $spawnroom_v2
	generated_rooms.append(spawn_room)

func _process(delta):
	# Only server handles stalker spawning logic
	if not multiplayer.is_server():
		return
	
	# Check for stalker spawn conditions
	if roomNum >= STALKER_START_ROOM:
		time_since_stalker_check += delta
		
		if time_since_stalker_check >= STALKER_CHECK_INTERVAL:
			time_since_stalker_check = 0.0
			check_stalker_spawn()

func check_stalker_spawn():
	# Don't spawn if stalker already exists
	if active_stalker != null and is_instance_valid(active_stalker):
		player_not_looking_back_time = 0.0  # Reset timer
		return
	
	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	
	var player = players[0]  # Get first player for simplicity
	
	# Check if player is looking backwards
	if is_player_looking_backward(player):
		player_not_looking_back_time = 0.0
	else:
		player_not_looking_back_time += STALKER_CHECK_INTERVAL
	
	# Spawn stalker if player hasn't looked back for long enough
	if player_not_looking_back_time >= STALKER_NO_LOOK_DURATION:
		if seeded_randf() <= STALKER_SPAWN_CHANCE:
			spawn_stalker_monster(player)
			player_not_looking_back_time = 0.0

func is_player_looking_backward(player: Node) -> bool:
	# Get player's camera/head node
	var player_head = null
	if player.has_node("Head"):
		player_head = player.get_node("Head")
	elif player.has_node("Camera3D"):
		player_head = player.get_node("Camera3D")
	else:
		return false
	
	# Get player's forward direction
	var player_forward = -player_head.global_transform.basis.z.normalized()
	
	# Get player's movement direction (simplified - checking if looking opposite to forward progress)
	# A more sophisticated check would track actual room progression
	var backward_threshold = -0.5  # Looking more than 90 degrees backwards
	
	# For simplicity, we check if player's look direction has negative Z component
	# (assuming rooms progress in +Z direction)
	return player_forward.z < backward_threshold

func spawn_stalker_monster(player: Node):
	if not multiplayer.is_server():
		return
	
	var stalker = STALKER_MONSTER_SCENE.instantiate()
	
	# Spawn behind player
	var player_head = player.get_node("Head") if player.has_node("Head") else player
	var backward_dir = player_head.global_transform.basis.z.normalized()  # Behind player
	var spawn_pos = player.global_transform.origin + (backward_dir * STALKER_SPAWN_DISTANCE)
	spawn_pos.y = player.global_transform.origin.y  # Keep at player's height
	
	add_child(stalker)
	active_stalker = stalker
	
	stalker.global_transform.origin = spawn_pos
	
	print("Stalker monster spawned behind player!")
	
	# Sync stalker spawn to clients
	rpc("sync_stalker_spawn", spawn_pos)

@rpc("authority", "call_local", "reliable")
func sync_stalker_spawn(spawn_position: Vector3):
	if multiplayer.is_server():
		return  # Server already spawned it
	
	var stalker = STALKER_MONSTER_SCENE.instantiate()
	add_child(stalker)
	active_stalker = stalker
	stalker.global_transform.origin = spawn_position

func seeded_pick_random(array: Array):
	if array.is_empty():
		return null
	return array[rng.randi() % array.size()]

func seeded_randf() -> float:
	return rng.randf()

func seeded_randf_range(min_val: float, max_val: float) -> float:
	return rng.randf_range(min_val, max_val)
	
func get_room_scene_for_door(door_number: int) -> PackedScene:
	# Forced special rooms (like Room 50)
	if specialRooms.has("Room " + str(door_number)):
		return specialRooms["Room " + str(door_number)]

	# Roll for secret room
	var secret := roll_secret_room()
	if secret != null:
		print("SECRET ROOM SPAWNED at door ", door_number)
		return secret

	# Otherwise normal room
	return seeded_pick_random(room_scenes)
	
func roll_secret_room_for_door(_door_number: int) -> PackedScene:
	for entry in secret_rooms:
		var base_chance = float(entry["chance"])

		if seeded_randf() <= base_chance:
			return entry["scene"]

	return null
	
func generate_room(previous_room):
	# Only server generates rooms
	if not multiplayer.is_server():
		return
		
	var next_door_number = roomNum + 1
	var room_scene = get_room_scene_for_door(next_door_number)
	if not room_scene:
		push_error("room_scene is null!")
		return

	var new_room = room_scene.instantiate()

	var new_begin_pos = new_room.get_node("Begin_Pos") as MeshInstance3D
	var new_begin_local_offset = new_begin_pos.transform.origin
	
	add_child(new_room)
	maybe_break_lights_normal(new_room)
	maybe_make_room_locked(new_room)
	
	# Get where the previous room ends
	var prev_end_pos = previous_room.get_node("End_Pos") as MeshInstance3D
	
	new_room.global_transform.basis = prev_end_pos.global_transform.basis
	
	var rotated_offset = new_room.global_transform.basis * new_begin_local_offset
	new_room.global_transform.origin = prev_end_pos.global_transform.origin - rotated_offset
	
	generated_rooms.append(new_room)
	
	roomNum += 1
	
	if generated_rooms.size() > MAX_ROOMS:
		var old_room = generated_rooms[0]
		if is_instance_valid(old_room):
			old_room.queue_free()  
		generated_rooms.remove_at(0)

	rooms_since_last_rush += 1

	# Check if this room has a wardrobe
	if room_has_wardrobe(new_room):
		has_seen_wardrobe = true

	if roomNum >= RUSH_START_ROOM:
		if has_seen_wardrobe:
			if rooms_since_last_rush >= RUSH_COOLDOWN_ROOMS:
				if generated_rooms.size() > RUSH_SPAWN_OFFSET:
					if seeded_randf() <= RUSH_SPAWN_CHANCE:
						spawn_rush_monster()
						rooms_since_last_rush = 0
						
	update_rush_target()
	
	# Sync room generation to all clients
	var scene_index = get_room_scene_index(room_scene)
	var prev_room_path = get_path_to(previous_room)
	rpc("sync_room_generation", scene_index, prev_room_path, next_door_number)

# Get index of room scene for synchronization
func get_room_scene_index(scene: PackedScene) -> int:
	# Check normal rooms
	for i in range(room_scenes.size()):
		if room_scenes[i] == scene:
			return i
	
	# Check special rooms
	var special_index = 1000
	for key in specialRooms.keys():
		if specialRooms[key] == scene:
			return special_index
		special_index += 1
	
	# Check secret rooms
	var secret_index = 2000
	for entry in secret_rooms:
		if entry["scene"] == scene:
			return secret_index
		secret_index += 1
	
	return 0  # Default to first normal room

# Get scene from index
func get_scene_from_index(index: int) -> PackedScene:
	if index < 1000:
		# Normal room
		if index < room_scenes.size():
			return room_scenes[index]
	elif index < 2000:
		# Special room
		var special_index = index - 1000
		var keys = specialRooms.keys()
		if special_index < keys.size():
			return specialRooms[keys[special_index]]
	else:
		# Secret room
		var secret_index = index - 2000
		if secret_index < secret_rooms.size():
			return secret_rooms[secret_index]["scene"]
	
	return room_scenes[0]  # Fallback

@rpc("authority", "call_local", "reliable")
func sync_room_generation(scene_index: int, prev_room_path: NodePath, _door_number: int):
	# Clients receive and generate the same room
	if multiplayer.is_server():
		return  # Server already generated it
		
	var room_scene = get_scene_from_index(scene_index)
	var previous_room = get_node_or_null(prev_room_path)
	
	if not previous_room:
		push_error("Could not find previous room on client!")
		return
		
	var new_room = room_scene.instantiate()
	var new_begin_pos = new_room.get_node("Begin_Pos") as MeshInstance3D
	var new_begin_local_offset = new_begin_pos.transform.origin
	
	add_child(new_room)
	
	# Get where the previous room ends
	var prev_end_pos = previous_room.get_node("End_Pos") as MeshInstance3D
	
	new_room.global_transform.basis = prev_end_pos.global_transform.basis
	
	var rotated_offset = new_room.global_transform.basis * new_begin_local_offset
	new_room.global_transform.origin = prev_end_pos.global_transform.origin - rotated_offset
	
	generated_rooms.append(new_room)
	roomNum += 1
	
	if generated_rooms.size() > MAX_ROOMS:
		var old_room = generated_rooms[0]
		if is_instance_valid(old_room):
			old_room.queue_free()  
		generated_rooms.remove_at(0)

func room_has_wardrobe(room: Node) -> bool:
	return room.has_node("Wardrobe")
	
func _collect_lights(node: Node, arr: Array):
	if node is Light3D:
		arr.append(node)
	for child in node.get_children():
		_collect_lights(child, arr)
		
func get_all_lights() -> Array[Light3D]:
	var lights: Array[Light3D] = []
	for room in generated_rooms:
		_collect_lights(room, lights)
	return lights
	
func maybe_make_room_locked(room: Node):
	if not room.has_node("Door"):
		return

	if seeded_randf() > LOCKED_DOOR_CHANCE:
		return

	var door = room.get_node("Door")

	# mark door as locked 
	if door.has_method("set_locked"):
		door.set_locked(true)
	elif "is_locked" in door:
		door.is_locked = true
	else:
		door.set_meta("locked", true)

	spawn_key_for_room(room)

func update_rush_target():
	if active_rush == null:
		return
	if not is_instance_valid(active_rush):
		active_rush = null
		return
	var end_room = generated_rooms[generated_rooms.size() - 1]
	var end_pos = end_room.get_node("End_Pos") as Node3D
	active_rush.set("target_position", end_pos.global_transform.origin + Vector3(0, 2, 0))

func spawn_key_for_room(room: Node):
	var spawn_points := []

	_collect_key_spawns(room, spawn_points)

	if spawn_points.is_empty():
		push_warning("Locked room but no key spawn points!")
		return

	var point = seeded_pick_random(spawn_points)
	var key = KEY_SCENE.instantiate()
	add_child(key)

	key.global_transform.origin = point.global_transform.origin

func _collect_key_spawns(node: Node, arr: Array):
	if node.name.begins_with("KeySpawn"):
		arr.append(node)

	for child in node.get_children():
		_collect_key_spawns(child, arr)
	
func flicker_n_times_then_break(light: Light3D, count: int, interval: float):
	if not is_instance_valid(light):
		return

	var timer := Timer.new()
	timer.wait_time = interval
	timer.one_shot = false

	timer.set_meta("light", light)
	timer.set_meta("original_energy", light.light_energy)
	timer.set_meta("flicks", 0)
	timer.set_meta("max_flicks", count * 2)

	add_child(timer)

	timer.timeout.connect(_on_normal_flicker_timer.bind(timer))
	timer.start()

func roll_secret_room() -> PackedScene:
	for entry in secret_rooms:
		if seeded_randf() <= float(entry["chance"]):
			return entry["scene"]
	return null

func _on_normal_flicker_timer(timer: Timer):
	if not is_instance_valid(timer):
		return

	if not timer.has_meta("light"):
		timer.queue_free()
		return

	var light = timer.get_meta("light")
	if not is_instance_valid(light):
		timer.queue_free()
		return

	var original_energy: float = timer.get_meta("original_energy")
	var flicks: int = timer.get_meta("flicks")
	var max_flicks: int = timer.get_meta("max_flicks")

	if is_instance_valid(light):
		if light.light_energy > 0.0:
			light.light_energy = 0.0
		else:
			light.light_energy = original_energy

	flicks += 1
	timer.set_meta("flicks", flicks)

	if flicks >= max_flicks:
		if is_instance_valid(light):
			light.queue_free()
		timer.queue_free()

func maybe_break_lights_normal(room: Node):
	var lights: Array[Light3D] = []
	_collect_lights(room, lights)

	for light in lights:
		if seeded_randf() <= LIGHT_BREAK_CHANCE:
			flicker_n_times_then_break(light, NORMAL_FLICKER_COUNT, NORMAL_FLICKER_INTERVAL)
	
func _check_light_recursive(node: Node):
	if node.name == "SpotLight" or node.name.contains("Light"):
		if seeded_randf() <= LIGHT_BREAK_CHANCE:
			node.queue_free()
			return

	if node is Light3D:
		if seeded_randf() <= LIGHT_BREAK_CHANCE:
			node.queue_free()
			return

	for child in node.get_children():
		_check_light_recursive(child)
		
func flicker_lights_rush():
	var lights := get_all_lights()

	for light in lights:
		flicker_for_time_then_break(light, RUSH_FLICKER_TIME, RUSH_FLICKER_INTERVAL)
	
	# Sync light flickering to clients
	rpc("sync_flicker_lights_rush")

@rpc("authority", "call_local", "reliable")
func sync_flicker_lights_rush():
	if multiplayer.is_server():
		return  # Server already did it
		
	var lights := get_all_lights()
	for light in lights:
		flicker_for_time_then_break(light, RUSH_FLICKER_TIME, RUSH_FLICKER_INTERVAL)
		
func flicker_for_time_then_break(light: Light3D, duration: float, interval: float):
	if not is_instance_valid(light):
		return

	var timer := Timer.new()
	timer.wait_time = interval
	timer.one_shot = false

	timer.set_meta("light", light)
	timer.set_meta("original_energy", light.light_energy)
	timer.set_meta("elapsed", 0.0)
	timer.set_meta("duration", duration)

	add_child(timer)

	timer.timeout.connect(_on_rush_flicker_timer.bind(timer))
	timer.start()

func _on_rush_flicker_timer(timer: Timer):
	if not is_instance_valid(timer):
		return

	if not timer.has_meta("light"):
		timer.queue_free()
		return

	var light = timer.get_meta("light")
	if not is_instance_valid(light):
		timer.queue_free()
		return

	var original_energy: float = timer.get_meta("original_energy")
	var elapsed: float = timer.get_meta("elapsed")
	var duration: float = timer.get_meta("duration")

	if is_instance_valid(light):
		light.light_energy = original_energy * seeded_randf_range(0.0, 1.2)

	elapsed += timer.wait_time
	timer.set_meta("elapsed", elapsed)

	if elapsed >= duration:
		if is_instance_valid(light):
			light.queue_free()
		timer.queue_free()

func spawn_rush_monster():
	# Only server spawns monsters
	if not multiplayer.is_server():
		return
		
	var rush_scene = seeded_pick_random(RushMonsters)
	var rush = rush_scene.instantiate()

	var spawn_room: Node = null

	for i in range(generated_rooms.size() - 1 - RUSH_SPAWN_OFFSET, -1, -1):
		if room_has_wardrobe(generated_rooms[i]):
			spawn_room = generated_rooms[i]
			break

	if spawn_room == null:
		return 
		
	var begin_pos = spawn_room.get_node("Begin_Pos") as Node3D

	add_child(rush)
	active_rush = rush
	flicker_lights_rush()

	rush.global_transform.origin = begin_pos.global_transform.origin + Vector3(0, 2, 0)
	
	# Sync rush monster spawn to clients
	var spawn_pos = rush.global_transform.origin
	rpc("sync_rush_spawn", spawn_pos)

@rpc("authority", "call_local", "reliable")
func sync_rush_spawn(spawn_position: Vector3):
	if multiplayer.is_server():
		return  # Server already spawned it
		
	var rush_scene = RushMonsters[0]  # Use first monster type for clients
	var rush = rush_scene.instantiate()
	
	add_child(rush)
	active_rush = rush
	
	rush.global_transform.origin = spawn_position
