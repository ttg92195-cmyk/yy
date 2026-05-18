extends CharacterBody3D
## GhostAI - AI-controlled ghost that hunts players
## Uses NavigationAgent3D for pathfinding around the map
## The Ghost behavior: Patrol -> Hunt -> Chase -> Catch

enum GhostState {
	IDLE,
	PATROL,
	HUNT,
	CHASE,
	ATTACK,
	RETURN
}

# Ghost stats
var move_speed: float = 4.5
var chase_speed: float = 6.0
var catch_distance: float = 2.0
var detection_range: float = 15.0
var lose_sight_range: float = 25.0
var patrol_wait_time: float = 3.0

# State management
var current_state: GhostState = GhostState.IDLE
var state_timer: float = 0.0
var hunt_cooldown: float = 0.0
var hunt_interval: float = 45.0
var hunt_duration: float = 20.0
var is_hunting: bool = false
var target_player: Node3D = null
var last_known_position: Vector3 = Vector3.ZERO

# Patrol
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var patrol_direction: int = 1

# References
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var detection_area: Area3D = $DetectionArea
@onready var ghost_mesh: MeshInstance3D = $GhostMesh
@onready var ghost_audio: AudioStreamPlayer3D = $GhostAudio
@onready var catch_area: Area3D = $CatchArea

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready():
	# Set up collision layers
	collision_layer = 4  # Ghost layer
	collision_mask = 1  # Environment layer

	add_to_group("ghost")

	# Connect signals
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	if catch_area:
		catch_area.body_entered.connect(_on_catch_area_body_entered)

	# Navigation setup
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 1.0
		nav_agent.avoidance_enabled = true

	# Set initial state
	_set_state(GhostState.PATROL)

	# Generate patrol points from markers in the scene
	_generate_patrol_points()


func _physics_process(delta):
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	state_timer += delta

	# Update hunt cooldown
	if hunt_cooldown > 0:
		hunt_cooldown -= delta

	# State machine
	match current_state:
		GhostState.IDLE:
			_process_idle(delta)
		GhostState.PATROL:
			_process_patrol(delta)
		GhostState.HUNT:
			_process_hunt(delta)
		GhostState.CHASE:
			_process_chase(delta)
		GhostState.ATTACK:
			_process_attack(delta)
		GhostState.RETURN:
			_process_return(delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Move along navigation path
	if nav_agent and nav_agent.is_navigation_finished() == false:
		var next_position = nav_agent.get_next_path_position()
		var direction = (next_position - global_position).normalized()
		var speed = chase_speed if current_state == GhostState.CHASE else move_speed
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		# Face movement direction
		if direction.length() > 0.1:
			var target_rotation = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, 5.0 * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)

	move_and_slide()

	# Play ambient ghost sounds
	_play_ghost_sounds()


func _set_state(new_state: GhostState):
	if current_state == new_state:
		return
	current_state = new_state
	state_timer = 0.0
	print("[GhostAI] State -> %s" % GhostState.keys()[new_state])


# ============ STATE PROCESSORS ============

func _process_idle(_delta: float):
	"""Wait briefly before starting patrol"""
	velocity.x = 0
	velocity.z = 0

	if state_timer > patrol_wait_time:
		_set_state(GhostState.PATROL)

	# Random chance to start hunting
	if hunt_cooldown <= 0 and randf() < 0.01:
		_start_hunt()


func _process_patrol(_delta: float):
	"""Move between patrol points"""
	if patrol_points.is_empty():
		_set_state(GhostState.IDLE)
		return

	var target = patrol_points[current_patrol_index]
	nav_agent.target_position = target

	if global_position.distance_to(target) < 2.0:
		current_patrol_index += patrol_direction
		if current_patrol_index >= patrol_points.size() or current_patrol_index < 0:
			patrol_direction *= -1
			current_patrol_index += patrol_direction

	# Random chance to start hunting
	if hunt_cooldown <= 0 and randf() < 0.005:
		_start_hunt()


func _start_hunt():
	"""Begin a hunt phase - ghost becomes more aggressive"""
	is_hunting = true
	_set_state(GhostState.HUNT)
	_play_hunt_announcement()

	# After hunt duration, return to patrol
	get_tree().create_timer(hunt_duration).timeout.connect(func():
		is_hunting = false
		hunt_cooldown = randf_range(GameManager.ghost_hunt_interval_min, GameManager.ghost_hunt_interval_max)
		if current_state == GhostState.HUNT or current_state == GhostState.CHASE:
			_set_state(GhostState.PATROL)
	)


func _process_hunt(_delta: float):
	"""Actively search for players"""
	# Find nearest player
	var nearest = _find_nearest_player()
	if nearest:
		target_player = nearest
		nav_agent.target_position = nearest.global_position
		last_known_position = nearest.global_position

		# If close enough, switch to chase
		if global_position.distance_to(nearest.global_position) < detection_range:
			_set_state(GhostState.CHASE)
	else:
		# Move to last known position
		if last_known_position != Vector3.ZERO:
			nav_agent.target_position = last_known_position
			if global_position.distance_to(last_known_position) < 2.0:
				last_known_position = Vector3.ZERO


func _process_chase(_delta: float):
	"""Chase a detected player"""
	if not target_player or not is_instance_valid(target_player):
		target_player = null
		_set_state(GhostState.PATROL)
		return

	var distance = global_position.distance_to(target_player.global_position)

	# Update navigation target
	nav_agent.target_position = target_player.global_position

	# If player is too far, lose them
	if distance > lose_sight_range:
		last_known_position = target_player.global_position
		target_player = null
		_set_state(GhostState.HUNT)
		return

	# If close enough, attack
	if distance < catch_distance:
		_set_state(GhostState.ATTACK)


func _process_attack(_delta: float):
	"""Catch a player"""
	if target_player and is_instance_valid(target_player):
		# Trigger catch
		if target_player.has_method("on_caught_by_ghost"):
			target_player.on_caught_by_ghost()

		# Play attack animation/sound
		_play_attack_sound()

	# Return to patrol after attack
	_set_state(GhostState.RETURN)


func _process_return(_delta: float):
	"""Return to a patrol point after attacking"""
	if patrol_points.is_empty():
		_set_state(GhostState.IDLE)
		return

	var target = patrol_points[0]
	nav_agent.target_position = target

	if global_position.distance_to(target) < 2.0:
		_set_state(GhostState.PATROL)


# ============ SIGNAL HANDLERS ============

func _on_detection_area_body_entered(body: Node3D):
	"""A body entered the ghost's detection area"""
	if body.is_in_group("player") and current_state != GhostState.CHASE:
		target_player = body
		_set_state(GhostState.CHASE)


func _on_detection_area_body_exited(body: Node3D):
	"""A body left the ghost's detection area"""
	if body == target_player and current_state == GhostState.CHASE:
		# Don't immediately stop chasing - use lose_sight_range instead
		pass


func _on_catch_area_body_entered(body: Node3D):
	"""A body entered the catch range"""
	if body.is_in_group("player"):
		if body.has_method("on_caught_by_ghost"):
			body.on_caught_by_ghost()
		_play_attack_sound()
		_set_state(GhostState.RETURN)


# ============ HELPER FUNCTIONS ============

func _find_nearest_player() -> Node3D:
	"""Find the nearest alive player"""
	var players = get_tree().get_nodes_in_group("player")
	var nearest: Node3D = null
	var nearest_dist: float = INF

	for player in players:
		if not player is CharacterBody3D:
			continue
		# Skip if player is dead
		if player.has_method("is_alive") and not player.is_alive():
			continue
		var dist = global_position.distance_to(player.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = player

	return nearest


func _generate_patrol_points():
	"""Generate patrol points from PatrolPoint markers in the scene"""
	var markers = get_tree().get_nodes_in_group("patrol_point")
	for marker in markers:
		patrol_points.append(marker.global_position)

	# If no patrol points, create some around spawn
	if patrol_points.is_empty():
		for i in range(5):
			var angle = (i / 5.0) * TAU
			patrol_points.append(global_position + Vector3(cos(angle) * 10, 0, sin(angle) * 10))


func _play_ghost_sounds():
	"""Play ambient ghost sounds based on state"""
	if ghost_audio and not ghost_audio.playing:
		if current_state == GhostState.CHASE:
			# More intense sounds during chase
			ghost_audio.volume_db = -10
		elif current_state == GhostState.HUNT:
			ghost_audio.volume_db = -20
		else:
			ghost_audio.volume_db = -30


func _play_hunt_announcement():
	"""Play a sound to warn players the ghost is hunting"""
	# Could be a distant whisper, door slam, etc.
	print("[GhostAI] Ghost is now HUNTING!")
	if ghost_audio:
		ghost_audio.play()


func _play_attack_sound():
	"""Play attack/catch sound"""
	print("[GhostAI] Ghost ATTACKED a player!")


## Set ghost visibility (ghost can appear/disappear)
func set_visible_to_players(visible: bool):
	if ghost_mesh:
		ghost_mesh.visible = visible
