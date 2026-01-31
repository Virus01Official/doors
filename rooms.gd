extends Node3D

const LIGHT_BREAK_CHANCE := 0.2

const NORMAL_FLICKER_COUNT := 2
const NORMAL_FLICKER_INTERVAL := 0.08

const RUSH_FLICKER_TIME := 1.5
const RUSH_FLICKER_INTERVAL := 0.04

@export var use_seed := false
@export var world_seed := 0

var rng := RandomNumberGenerator.new()

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
	#{
		#"scene": preload("res://rooms/secret_room_b.tscn"),
		#"chance": 0.0001 # ultra rare
	#},
]

var MAX_ROOMS = 5

var roomNum = 1

var RushMonsters: Array[PackedScene] = [
	preload("res://monster.tscn"),
]

const KEY_SCENE := preload("res://models/key.tscn")

const LOCKED_DOOR_CHANCE := 0.35

var active_rush = null

const RUSH_COOLDOWN_ROOMS = 4

var rooms_since_last_rush := RUSH_COOLDOWN_ROOMS
var has_seen_wardrobe := false

const RUSH_START_ROOM = 7
const RUSH_SPAWN_OFFSET = 3
const RUSH_SPAWN_CHANCE = 0.5 # 50% chance

var generated_rooms = []

func _ready():
	if use_seed:
		rng.seed = world_seed
		print("Using seed: ", world_seed)
	else:
		rng.randomize()
		print("Using random seed: ", rng.seed)
	
	var spawn_room = $spawnroom_v2
	generated_rooms.append(spawn_room)

func seeded_pick_random(array: Array):
	if array.is_empty():
		return null
	return array[rng.randi() % array.size()]

func seeded_randf_range(min_val: float, max_val: float) -> float:
	return rng.randf_range(min_val, max_val)
	
func get_room_scene_for_door(door_number: int) -> PackedScene:
	# Forced special rooms (like Room 50)
	if specialRooms.has(door_number):
		return specialRooms[door_number]

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

		# slightly increase chance later in game
		#var scaled = base_chance * clamp(door_number / 50.0, 1.0, 3.0)

		if randf() <= base_chance:
			return entry["scene"]

	return null
	
func generate_room(previous_room):
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
					if randf() <= RUSH_SPAWN_CHANCE:
						spawn_rush_monster()
						rooms_since_last_rush = 0
						
	update_rush_target()

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

	if randf() > LOCKED_DOOR_CHANCE:
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

	var point = spawn_points.pick_random()
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
		if randf() <= float(entry["chance"]):
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
		if randf() <= LIGHT_BREAK_CHANCE:
			flicker_n_times_then_break(light, NORMAL_FLICKER_COUNT, NORMAL_FLICKER_INTERVAL)
	
func _check_light_recursive(node: Node):
	if node.name == "SpotLight" or node.name.contains("Light"):
		if randf() <= LIGHT_BREAK_CHANCE:
			node.queue_free()
			return

	if node is Light3D:
		if randf() <= LIGHT_BREAK_CHANCE:
			node.queue_free()
			return

	for child in node.get_children():
		_check_light_recursive(child)
		
func flicker_lights_rush():
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
		light.light_energy = original_energy * randf_range(0.0, 1.2)

	elapsed += timer.wait_time
	timer.set_meta("elapsed", elapsed)

	if elapsed >= duration:
		if is_instance_valid(light):
			light.queue_free()
		timer.queue_free()

func spawn_rush_monster():
	var rush_scene = RushMonsters.pick_random()
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
