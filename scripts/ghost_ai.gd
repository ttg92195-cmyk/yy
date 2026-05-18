extends CharacterBody3D
## GhostAI - MOBILE-OPTIMIZED AI ghost
## Optimizations:
## - NO GPUParticles3D (huge GPU saver)
## - Simple body: just head + body (no arms, no bottom cone)
## - Only 1 light (eye light, reduced range)
## - NO aura light
## - Reduced float animation
## - Less frequent visibility flickering

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

# Visual effects (simplified)
var ghost_float_time: float = 0.0
var is_ghost_visible: bool = true
var flicker_timer: float = 0.0

# References
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var ghost_mesh: MeshInstance3D = $GhostMesh
@onready var ghost_audio: AudioStreamPlayer3D = $GhostAudio
@onready var catch_area: Area3D = $CatchArea

# Ghost body parts (minimal)
var head_mesh: MeshInstance3D
var body_mesh: MeshInstance3D
var eye_light: OmniLight3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready():
	collision_layer = 4
	collision_mask = 1
	add_to_group("ghost")

	_create_ghost_visual()

	if catch_area:
		catch_area.body_entered.connect(_on_catch_area_body_entered)

	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 1.0
		nav_agent.avoidance_enabled = false  # Save CPU on mobile

	_set_state(GhostState.PATROL)
	_generate_patrol_points()


func _create_ghost_visual():
	## MINIMAL ghost visual - just head + body + 1 light
	var ghost_body_mat = StandardMaterial3D.new()
	ghost_body_mat.albedo_color = Color(0.6, 0.6, 0.7, 0.5)
	ghost_body_mat.transparency_enabled = true
	ghost_body_mat.roughness = 0.9
	ghost_body_mat.emission_enabled = true
	ghost_body_mat.emission = Color(0.15, 0.1, 0.25)
	ghost_body_mat.emission_energy = 0.5

	# Head
	head_mesh = MeshInstance3D.new()
	var head = SphereMesh.new()
	head.radius = 0.28
	head.height = 0.5
	head_mesh.mesh = head
	head_mesh.position = Vector3(0, 1.7, 0)
	head_mesh.set_surface_override_material(ghost_body_mat)
	add_child(head_mesh)

	# Body (single piece)
	body_mesh = MeshInstance3D.new()
	var body = CylinderMesh.new()
	body.top_radius = 0.25
	body.bottom_radius = 0.45
	body.height = 1.4
	body_mesh.mesh = body
	body_mesh.position = Vector3(0, 0.8, 0)
	body_mesh.set_surface_override_material(ghost_body_mat)
	add_child(body_mesh)

	# Eyes - just 2 small emissive spheres
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.1, 0.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.3, 0.0)
	eye_mat.emission_energy = 4.0

	var left_eye = MeshInstance3D.new()
	var eye_l = SphereMesh.new()
	eye_l.radius = 0.05
	eye_l.height = 0.06
	left_eye.mesh = eye_l
	left_eye.position = Vector3(-0.1, 1.75, 0.22)
	left_eye.set_surface_override_material(eye_mat)
	add_child(left_eye)

	var right_eye = MeshInstance3D.new()
	var eye_r = SphereMesh.new()
	eye_r.radius = 0.05
	eye_r.height = 0.06
	right_eye.mesh = eye_r
	right_eye.position = Vector3(0.1, 1.75, 0.22)
	right_eye.set_surface_override_material(eye_mat)
	add_child(right_eye)

	# Single eye light (reduced range)
	eye_light = OmniLight3D.new()
	eye_light.position = Vector3(0, 1.75, 0.3)
	eye_light.light_color = Color(1.0, 0.2, 0.0)
	eye_light.light_energy = 1.5
	eye_light.omni_range = 6.0
	eye_light.shadow_enabled = false
	add_child(eye_light)

	# NO aura light
	# NO particle trail
	# NO arms

	# Hide original mesh if exists
	if ghost_mesh:
		ghost_mesh.visible = false


func _physics_process(delta):
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	state_timer += delta

	# Simple float animation (less frequent update)
	ghost_float_time += delta
	var float_offset = sin(ghost_float_time * 1.5) * 0.08
	if head_mesh:
		head_mesh.position.y = 1.7 + float_offset
	if body_mesh:
		body_mesh.position.y = 0.8 + float_offset * 0.5

	# Eye flicker (less frequent - every 0.3s instead of 0.1s)
	flicker_timer += delta
	if flicker_timer > 0.3 and eye_light:
		flicker_timer = 0.0
		if is_hunting:
			eye_light.light_energy = randf_range(2.0, 4.0)
		else:
			eye_light.light_energy = randf_range(0.8, 2.0)

	# Ghost visibility flickering (much less frequent)
	if randf() < 0.001 and current_state == GhostState.PATROL:
		_set_ghost_visible(false)
		get_tree().create_timer(randf_range(0.5, 1.5)).timeout.connect(func(): _set_ghost_visible(true))

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

	# Gravity (reduced for ghost)
	if not is_on_floor():
		velocity.y -= gravity * 0.3 * delta

	# Move along navigation path
	if nav_agent and nav_agent.is_navigation_finished() == false:
		var next_pos = nav_agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		var speed = chase_speed if current_state == GhostState.CHASE else move_speed
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		# Face direction
		if direction.length() > 0.1:
			var target_rot = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)

	move_and_slide()


func _set_ghost_visible(visible: bool):
	is_ghost_visible = visible
	for child in get_children():
		if child is MeshInstance3D and child != ghost_mesh:
			child.visible = visible
		elif child is OmniLight3D:
			child.visible = visible


func _set_state(new_state: GhostState):
	if current_state == new_state:
		return
	current_state = new_state
	state_timer = 0.0

	match new_state:
		GhostState.HUNT:
			_set_ghost_visible(true)
			if eye_light:
				eye_light.light_color = Color(1.0, 0.5, 0.0)
				eye_light.light_energy = 3.0
				eye_light.omni_range = 10.0
		GhostState.CHASE:
			_set_ghost_visible(true)
			if eye_light:
				eye_light.light_color = Color(1.0, 0.0, 0.0)
				eye_light.light_energy = 4.0
				eye_light.omni_range = 12.0
		GhostState.PATROL:
			if eye_light:
				eye_light.light_color = Color(1.0, 0.2, 0.0)
				eye_light.light_energy = 1.5
				eye_light.omni_range = 6.0

	print("[GhostAI] State -> %s" % GhostState.keys()[new_state])


# ============ STATE PROCESSORS ============

func _process_idle(_delta: float):
	velocity.x = 0
	velocity.z = 0
	if state_timer > patrol_wait_time:
		_set_state(GhostState.PATROL)
	if hunt_cooldown <= 0 and randf() < 0.01:
		_start_hunt()


func _process_patrol(_delta: float):
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

	if hunt_cooldown <= 0 and randf() < 0.005:
		_start_hunt()


func _start_hunt():
	is_hunting = true
	_set_state(GhostState.HUNT)
	_play_hunt_announcement()
	get_tree().create_timer(hunt_duration).timeout.connect(func():
		is_hunting = false
		hunt_cooldown = randf_range(GameManager.ghost_hunt_interval_min, GameManager.ghost_hunt_interval_max)
		if current_state == GhostState.HUNT or current_state == GhostState.CHASE:
			_set_state(GhostState.PATROL)
	)


func _process_hunt(_delta: float):
	var nearest = _find_nearest_player()
	if nearest:
		target_player = nearest
		nav_agent.target_position = nearest.global_position
		last_known_position = nearest.global_position
		if global_position.distance_to(nearest.global_position) < detection_range:
			_set_state(GhostState.CHASE)
	else:
		if last_known_position != Vector3.ZERO:
			nav_agent.target_position = last_known_position
			if global_position.distance_to(last_known_position) < 2.0:
				last_known_position = Vector3.ZERO


func _process_chase(_delta: float):
	if not target_player or not is_instance_valid(target_player):
		target_player = null
		_set_state(GhostState.PATROL)
		return

	var distance = global_position.distance_to(target_player.global_position)
	nav_agent.target_position = target_player.global_position

	if distance > lose_sight_range:
		last_known_position = target_player.global_position
		target_player = null
		_set_state(GhostState.HUNT)
		return

	if distance < catch_distance:
		_set_state(GhostState.ATTACK)


func _process_attack(_delta: float):
	if target_player and is_instance_valid(target_player):
		if target_player.has_method("on_caught_by_ghost"):
			target_player.on_caught_by_ghost()
	_set_state(GhostState.RETURN)


func _process_return(_delta: float):
	if patrol_points.is_empty():
		_set_state(GhostState.IDLE)
		return

	var target = patrol_points[0]
	nav_agent.target_position = target

	if global_position.distance_to(target) < 2.0:
		_set_state(GhostState.PATROL)


# ============ SIGNAL HANDLERS ============

func _on_catch_area_body_entered(body: Node3D):
	if body.is_in_group("player"):
		if body.has_method("on_caught_by_ghost"):
			body.on_caught_by_ghost()
		_set_state(GhostState.RETURN)


# ============ HELPERS ============

func _find_nearest_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	var nearest: Node3D = null
	var nearest_dist: float = INF
	for player in players:
		if not player is CharacterBody3D:
			continue
		if player.has_method("is_alive") and not player.is_alive():
			continue
		var dist = global_position.distance_to(player.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = player
	return nearest


func _generate_patrol_points():
	var markers = get_tree().get_nodes_in_group("patrol_point")
	for marker in markers:
		patrol_points.append(marker.global_position)
	if patrol_points.is_empty():
		for i in range(5):
			var angle = (i / 5.0) * TAU
			patrol_points.append(global_position + Vector3(cos(angle) * 10, 0, sin(angle) * 10))


func _play_hunt_announcement():
	print("[GhostAI] Ghost is now HUNTING!")
	if ghost_audio:
		ghost_audio.play()


func set_visible_to_players(visible: bool):
	_set_ghost_visible(visible)
