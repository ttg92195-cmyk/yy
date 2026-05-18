extends CharacterBody3D
## GhostAI - AI-controlled ghost with visual appearance and effects
## Uses NavigationAgent3D for pathfinding
## The Ghost behavior: Patrol -> Hunt -> Chase -> Catch
## Visual: Ghostly floating figure with glowing eyes, particle trail

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

# Visual effects
var ghost_float_time: float = 0.0
var ghost_visible_alpha: float = 0.6
var is_ghost_visible: bool = true
var flicker_timer: float = 0.0
var attack_flash: bool = false

# References
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var ghost_mesh: MeshInstance3D = $GhostMesh
@onready var ghost_audio: AudioStreamPlayer3D = $GhostAudio
@onready var catch_area: Area3D = $CatchArea

# Ghost body parts (created in code)
var head_mesh: MeshInstance3D
var body_mesh: MeshInstance3D
var left_eye: MeshInstance3D
var right_eye: MeshInstance3D
var eye_light: OmniLight3D
var trail_particles: GPUParticles3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready():
	# Set up collision layers
	collision_layer = 4  # Ghost layer
	collision_mask = 1   # Environment layer
	add_to_group("ghost")

	# Create ghost visual appearance
	_create_ghost_visual()

	# Connect signals
	if catch_area:
		catch_area.body_entered.connect(_on_catch_area_body_entered)

	# Navigation setup
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 1.0
		nav_agent.avoidance_enabled = true

	# Set initial state
	_set_state(GhostState.PATROL)
	_generate_patrol_points()


func _create_ghost_visual():
	## Create a detailed ghost appearance using primitive shapes

	# Ghost body material - semi-transparent white/grey
	var ghost_body_mat = StandardMaterial3D.new()
	ghost_body_mat.albedo_color = Color(0.6, 0.6, 0.7, 0.4)
	ghost_body_mat.transparency_enabled = true
	ghost_body_mat.roughness = 0.9
	ghost_body_mat.metallic = 0.0
	ghost_body_mat.emission_enabled = true
	ghost_body_mat.emission = Color(0.15, 0.1, 0.25)
	ghost_body_mat.emission_energy = 0.5

	# Head (slightly larger sphere)
	head_mesh = MeshInstance3D.new()
	var head = SphereMesh.new()
	head.radius = 0.3
	head.height = 0.55
	head_mesh.mesh = head
	head_mesh.position = Vector3(0, 1.7, 0)
	head_mesh.set_surface_override_material(ghost_body_mat)
	add_child(head_mesh)

	# Body (elongated cone/cylinder shape)
	body_mesh = MeshInstance3D.new()
	var body = CylinderMesh.new()
	body.top_radius = 0.25
	body.bottom_radius = 0.45
	body.height = 1.2
	body_mesh.mesh = body
	body_mesh.position = Vector3(0, 0.9, 0)
	body_mesh.set_surface_override_material(ghost_body_mat)
	add_child(body_mesh)

	# Tattered bottom part (wider cone)
	var bottom_mesh = MeshInstance3D.new()
	var bottom = CylinderMesh.new()
	bottom.top_radius = 0.45
	bottom.bottom_radius = 0.6
	bottom.height = 0.5
	bottom_mesh.mesh = bottom
	bottom_mesh.position = Vector3(0, 0.3, 0)
	bottom_mesh.set_surface_override_material(ghost_body_mat)
	add_child(bottom_mesh)

	# Arms (thin cylinders)
	var left_arm = MeshInstance3D.new()
	var arm_mesh_l = CylinderMesh.new()
	arm_mesh_l.top_radius = 0.06
	arm_mesh_l.bottom_radius = 0.04
	arm_mesh_l.height = 0.8
	left_arm.mesh = arm_mesh_l
	left_arm.position = Vector3(-0.4, 1.2, 0)
	left_arm.rotation = Vector3(0, 0, deg_to_rad(15))
	left_arm.set_surface_override_material(ghost_body_mat)
	add_child(left_arm)

	var right_arm = MeshInstance3D.new()
	var arm_mesh_r = CylinderMesh.new()
	arm_mesh_r.top_radius = 0.06
	arm_mesh_r.bottom_radius = 0.04
	arm_mesh_r.height = 0.8
	right_arm.mesh = arm_mesh_r
	right_arm.position = Vector3(0.4, 1.2, 0.1)
	right_arm.rotation = Vector3(0, 0, deg_to_rad(-20))
	right_arm.set_surface_override_material(ghost_body_mat)
	add_child(right_arm)

	# Glowing Eyes
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.1, 0.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.3, 0.0)
	eye_mat.emission_energy = 5.0

	left_eye = MeshInstance3D.new()
	var eye_l = SphereMesh.new()
	eye_l.radius = 0.06
	eye_l.height = 0.08
	left_eye.mesh = eye_l
	left_eye.position = Vector3(-0.12, 1.75, 0.25)
	left_eye.set_surface_override_material(eye_mat)
	add_child(left_eye)

	right_eye = MeshInstance3D.new()
	var eye_r = SphereMesh.new()
	eye_r.radius = 0.06
	eye_r.height = 0.08
	right_eye.mesh = eye_r
	right_eye.position = Vector3(0.12, 1.75, 0.25)
	right_eye.set_surface_override_material(eye_mat)
	add_child(right_eye)

	# Eye glow light
	eye_light = OmniLight3D.new()
	eye_light.position = Vector3(0, 1.75, 0.3)
	eye_light.light_color = Color(1.0, 0.2, 0.0)
	eye_light.light_energy = 2.0
	eye_light.omni_range = 8.0
	eye_light.shadow_enabled = false
	add_child(eye_light)

	# Ghost aura light (dim purple)
	var aura = OmniLight3D.new()
	aura.position = Vector3(0, 1.0, 0)
	aura.light_color = Color(0.4, 0.2, 0.6)
	aura.light_energy = 0.5
	aura.omni_range = 5.0
	aura.shadow_enabled = false
	add_child(aura)

	# Particle trail (ghost mist)
	_create_ghost_particles()

	# Hide original GhostMesh if it exists
	if ghost_mesh:
		ghost_mesh.visible = false


func _create_ghost_particles():
	## Create ghostly particle trail
	var particles = GPUParticles3D.new()
	particles.name = "GhostTrail"
	particles.position = Vector3(0, 0.5, 0)

	# Particle process material
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.3
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 30.0
	process_mat.gravity = Vector3(0, 0.3, 0)

	# Initial velocity
	process_mat.initial_velocity_min = 0.2
	process_mat.initial_velocity_max = 0.5

	# Scale
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 0.3))
	scale_curve.add_point(Vector2(0.5, 0.8))
	scale_curve.add_point(Vector2(1, 0.0))
	var scale_min_curve = CurveTexture.new()
	scale_min_curve.curve = scale_curve
	process_mat.scale_min = 0.1
	process_mat.scale_max = 0.3
	var scale_max_curve = CurveTexture.new()
	scale_max_curve.curve = scale_curve
	process_mat.scale_curve = scale_max_curve

	# Color
	var color_ramp = Gradient.new()
	color_ramp.add_point(0.0, Color(0.5, 0.4, 0.7, 0.3))
	color_ramp.add_point(0.5, Color(0.3, 0.2, 0.5, 0.15))
	color_ramp.add_point(1.0, Color(0.2, 0.1, 0.3, 0.0))
	var color_ramp_tex = GradientTexture1D.new()
	color_ramp_tex.gradient = color_ramp
	process_mat.color_ramp = color_ramp_tex

	particles.process_material = process_mat

	# Particle mesh (small spheres)
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.05
	particle_mesh.height = 0.1
	var particle_mat = StandardMaterial3D.new()
	particle_mat.albedo_color = Color(0.5, 0.4, 0.7, 0.3)
	particle_mat.transparency_enabled = true
	particle_mat.emission_enabled = true
	particle_mat.emission = Color(0.3, 0.2, 0.5)
	particle_mat.emission_energy = 1.0
	particle_mesh.material = particle_mat
	particles.draw_pass_1 = particle_mesh

	particles.amount = 20
	particles.lifetime = 1.5
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	particles.local_coords = false

	add_child(particles)
	trail_particles = particles


func _physics_process(delta):
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	state_timer += delta

	# Ghost floating animation
	ghost_float_time += delta
	var float_offset = sin(ghost_float_time * 2.0) * 0.1

	# Animate ghost parts
	if head_mesh:
		head_mesh.position.y = 1.7 + float_offset
	if body_mesh:
		body_mesh.position.y = 0.9 + float_offset * 0.5
	if left_eye:
		left_eye.position.y = 1.75 + float_offset
	if right_eye:
		right_eye.position.y = 1.75 + float_offset
	if eye_light:
		eye_light.position.y = 1.75 + float_offset

	# Eye flicker effect
	flicker_timer += delta
	if flicker_timer > 0.1:
		flicker_timer = 0.0
		if is_hunting:
			# Faster flicker when hunting
			eye_light.light_energy = randf_range(2.0, 5.0)
		else:
			eye_light.light_energy = randf_range(1.0, 2.5)

	# Ghost visibility flickering (random appear/disappear)
	if randf() < 0.002 and current_state == GhostState.PATROL:
		_set_ghost_visible(false)
		get_tree().create_timer(randf_range(0.5, 2.0)).timeout.connect(func(): _set_ghost_visible(true))

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

	# Gravity (reduced for ghost - floats slightly)
	if not is_on_floor():
		velocity.y -= gravity * 0.3 * delta

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

	# Ghost sounds
	_play_ghost_sounds()


func _set_ghost_visible(visible: bool):
	is_ghost_visible = visible
	if head_mesh: head_mesh.visible = visible
	if body_mesh: body_mesh.visible = visible
	if left_eye: left_eye.visible = visible
	if right_eye: right_eye.visible = visible
	if eye_light: eye_light.visible = visible
	if trail_particles: trail_particles.emitting = visible

	# Find and toggle all child meshes
	for child in get_children():
		if child is MeshInstance3D and child != ghost_mesh:
			child.visible = visible


func _set_state(new_state: GhostState):
	if current_state == new_state:
		return
	current_state = new_state
	state_timer = 0.0

	# Visual changes based on state
	match new_state:
		GhostState.HUNT:
			_set_ghost_visible(true)
			if eye_light:
				eye_light.light_color = Color(1.0, 0.5, 0.0)  # Orange when hunting
				eye_light.light_energy = 3.0
				eye_light.omni_range = 12.0
		GhostState.CHASE:
			_set_ghost_visible(true)
			if eye_light:
				eye_light.light_color = Color(1.0, 0.0, 0.0)  # Red when chasing
				eye_light.light_energy = 5.0
				eye_light.omni_range = 15.0
		GhostState.PATROL:
			if eye_light:
				eye_light.light_color = Color(1.0, 0.2, 0.0)  # Normal red
				eye_light.light_energy = 2.0
				eye_light.omni_range = 8.0

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
		_play_attack_sound()

		# Flash effect
		attack_flash = true
		_set_ghost_visible(false)
		get_tree().create_timer(0.3).timeout.connect(func():
			attack_flash = false
			_set_ghost_visible(true)
		)

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
		_play_attack_sound()
		_set_state(GhostState.RETURN)


# ============ HELPER FUNCTIONS ============

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


func _play_ghost_sounds():
	if ghost_audio and not ghost_audio.playing:
		if current_state == GhostState.CHASE:
			ghost_audio.volume_db = -10
		elif current_state == GhostState.HUNT:
			ghost_audio.volume_db = -20
		else:
			ghost_audio.volume_db = -30


func _play_hunt_announcement():
	print("[GhostAI] Ghost is now HUNTING!")
	if ghost_audio:
		ghost_audio.play()


func _play_attack_sound():
	print("[GhostAI] Ghost ATTACKED a player!")


func set_visible_to_players(visible: bool):
	_set_ghost_visible(visible)
