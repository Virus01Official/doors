extends CharacterBody3D

const MOVE_SPEED := 2.0
const RUN_AWAY_SPEED := 8.0
const DETECTION_ANGLE := 45.0  # degrees - how wide the player's vision is
const SPAWN_DISTANCE := 15.0  # How far behind player to spawn
const ATTACK_DISTANCE := 1.5  # How close before it attacks/kills player
const RETREAT_DISTANCE := 20.0  # How far to run back when spotted

enum State {
	IDLE,
	STALKING,
	RETREATING,
	ATTACKING
}

var current_state := State.IDLE
var target_player = null
var retreat_position := Vector3.ZERO
var original_spawn_position := Vector3.ZERO

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null

func _ready():
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
	
	original_spawn_position = global_transform.origin
	find_target_player()

func find_target_player():
	# Find the nearest player
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	
	var closest_player = null
	var closest_dist = INF
	
	for player in players:
		var dist = global_transform.origin.distance_to(player.global_transform.origin)
		if dist < closest_dist:
			closest_dist = dist
			closest_player = player
	
	target_player = closest_player

func _physics_process(delta):
	if not is_instance_valid(target_player):
		find_target_player()
		return
	
	match current_state:
		State.IDLE:
			_process_idle()
		State.STALKING:
			_process_stalking(delta)
		State.RETREATING:
			_process_retreating(delta)
		State.ATTACKING:
			_process_attacking()

func _process_idle():
	if not is_instance_valid(target_player):
		return
	
	# Start stalking if not being looked at
	if not is_player_looking_at_me():
		current_state = State.STALKING

func _process_stalking(_delta):
	if not is_instance_valid(target_player):
		current_state = State.IDLE
		return
	
	# If player looks at us, retreat!
	if is_player_looking_at_me():
		start_retreat()
		return
	
	var distance_to_player = global_transform.origin.distance_to(target_player.global_transform.origin)
	
	# Check if close enough to attack
	if distance_to_player <= ATTACK_DISTANCE:
		current_state = State.ATTACKING
		return
	
	# Move towards player
	var direction = (target_player.global_transform.origin - global_transform.origin).normalized()
	velocity = direction * MOVE_SPEED
	
	# Look at player
	look_at(target_player.global_transform.origin, Vector3.UP)
	
	move_and_slide()

func _process_retreating(_delta):
	# Run back to retreat position
	var distance_to_retreat = global_transform.origin.distance_to(retreat_position)
	
	if distance_to_retreat <= 1.0:
		# Reached retreat position, go back to idle
		current_state = State.IDLE
		return
	
	var direction = (retreat_position - global_transform.origin).normalized()
	velocity = direction * RUN_AWAY_SPEED
	
	# Look where we're running
	look_at(retreat_position, Vector3.UP)
	
	move_and_slide()

func _process_attacking():
	# Kill/damage player
	if is_instance_valid(target_player):
		if target_player.has_method("take_damage"):
			target_player.take_damage(100)  # Instant kill
		elif target_player.has_method("die"):
			target_player.die()
	
	# Monster disappears after attack
	queue_free()

func is_player_looking_at_me() -> bool:
	if not is_instance_valid(target_player):
		return false
	
	# Get player's camera/head node
	var player_head = null
	if target_player.has_node("Head"):
		player_head = target_player.get_node("Head")
	elif target_player.has_node("Camera3D"):
		player_head = target_player.get_node("Camera3D")
	else:
		player_head = target_player
	
	# Vector from player to monster
	var to_monster = (global_transform.origin - player_head.global_transform.origin).normalized()
	
	# Player's forward direction
	var player_forward = -player_head.global_transform.basis.z.normalized()
	
	# Calculate angle between player's look direction and monster direction
	var dot_product = player_forward.dot(to_monster)
	var angle = rad_to_deg(acos(dot_product))
	
	# Check if monster is within player's field of view
	if angle <= DETECTION_ANGLE:
		# Also check if there's line of sight
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			player_head.global_transform.origin,
			global_transform.origin
		)
		query.exclude = [target_player, self]
		
		var result = space_state.intersect_ray(query)
		
		# If nothing blocking, player can see us
		return result.is_empty()
	
	return false

func start_retreat():
	current_state = State.RETREATING
	
	# Calculate retreat position (behind where we spawned, away from player)
	var away_from_player = (global_transform.origin - target_player.global_transform.origin).normalized()
	retreat_position = global_transform.origin + (away_from_player * RETREAT_DISTANCE)
