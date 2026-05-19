extends CharacterBody3D
# GhostAI V6 - NO @onready for scene nodes, creates everything in code
# Uses direct movement to targets (no NavigationAgent3D)

enum GhostState { IDLE, PATROL, HUNT, CHASE, ATTACK, RETURN }

var move_speed: float = 3.5
var chase_speed: float = 5.0
var catch_distance: float = 2.0
var detection_range: float = 12.0
var lose_sight_range: float = 20.0

var current_state: GhostState = GhostState.IDLE
var state_timer: float = 0.0
var hunt_cooldown: float = 0.0
var is_hunting: bool = false
var target_player: Node3D = null
var last_known_position: Vector3 = Vector3.ZERO

var patrol_points: Array = []
var current_patrol_index: int = 0
var patrol_direction: int = 1

var ghost_float_time: float = 0.0
var is_ghost_visible: bool = true

var head_mesh: MeshInstance3D
var body_mesh: MeshInstance3D
var eye_light: OmniLight3D
var ghost_audio: AudioStreamPlayer3D
var catch_area: Area3D

var gravity: float = 9.8
var move_target: Vector3 = Vector3.ZERO


func _ready():
	collision_layer = 4
	collision_mask = 1
	add_to_group("ghost")

	# Find scene nodes safely (no @onready)
	ghost_audio = get_node_or_null("GhostAudio")
	catch_area = get_node_or_null("CatchArea")

	# Create ghost visual
	_create_ghost_visual()

	# Connect catch area
	if catch_area:
		catch_area.body_entered.connect(_on_catch_area_body_entered)

	_set_state(GhostState.PATROL)
	_generate_patrol_points()


func _create_ghost_visual():
	var ghost_mat = StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(0.6, 0.6, 0.7, 0.5)
	ghost_mat.transparency_enabled = true
	ghost_mat.emission_enabled = true
	ghost_mat.emission = Color(0.15, 0.1, 0.25)
	ghost_mat.emission_energy = 0.5

	head_mesh = MeshInstance3D.new()
	var head = SphereMesh.new()
	head.radius = 0.25
	head.height = 0.45
	head_mesh.mesh = head
	head_mesh.position = Vector3(0, 1.6, 0)
	head_mesh.set_surface_override_material(ghost_mat)
	add_child(head_mesh)

	body_mesh = MeshInstance3D.new()
	var body = CylinderMesh.new()
	body.top_radius = 0.22
	body.bottom_radius = 0.4
	body.height = 1.2
	body_mesh.mesh = body
	body_mesh.position = Vector3(0, 0.8, 0)
	body_mesh.set_surface_override_material(ghost_mat)
	add_child(body_mesh)

	# Eyes
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1, 0.1, 0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1, 0.3, 0)
	eye_mat.emission_energy = 3.0

	for x_pos in [-0.09, 0.09]:
		var eye = MeshInstance3D.new()
		var es = SphereMesh.new()
		es.radius = 0.04
		es.height = 0.05
		eye.mesh = es
		eye.position = Vector3(x_pos, 1.65, 0.2)
		eye.set_surface_override_material(eye_mat)
		add_child(eye)

	eye_light = OmniLight3D.new()
	eye_light.position = Vector3(0, 1.65, 0.25)
	eye_light.light_color = Color(1, 0.2, 0)
	eye_light.light_energy = 1.5
	eye_light.omni_range = 5.0
	eye_light.shadow_enabled = false
	add_child(eye_light)


func _physics_process(delta):
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	state_timer += delta

	# Float animation
	ghost_float_time += delta
	var fo = sin(ghost_float_time * 1.5) * 0.06
	if head_mesh and is_instance_valid(head_mesh):
		head_mesh.position.y = 1.6 + fo
	if body_mesh and is_instance_valid(body_mesh):
		body_mesh.position.y = 0.8 + fo * 0.5

	if hunt_cooldown > 0:
		hunt_cooldown -= delta

	match current_state:
		GhostState.IDLE:
			_process_idle()
		GhostState.PATROL:
			_process_patrol()
		GhostState.HUNT:
			_process_hunt()
		GhostState.CHASE:
			_process_chase()
		GhostState.ATTACK:
			_process_attack()
		GhostState.RETURN:
			_process_return()

	# Gravity (reduced for ghost)
	if not is_on_floor():
		velocity.y -= gravity * 0.3 * delta

	# Direct movement toward target
	var spd = chase_speed if current_state == GhostState.CHASE else move_speed
	if move_target != Vector3.ZERO:
		var dir = (move_target - global_position)
		dir.y = 0
		if dir.length() > 0.5:
			dir = dir.normalized()
			velocity.x = dir.x * spd
			velocity.z = dir.z * spd
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 5.0 * delta)
		else:
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)

	move_and_slide()


func _set_state(s: GhostState):
	if current_state == s:
		return
	current_state = s
	state_timer = 0.0
	if eye_light and is_instance_valid(eye_light):
		match s:
			GhostState.HUNT:
				eye_light.light_color = Color(1, 0.5, 0)
				eye_light.omni_range = 8.0
			GhostState.CHASE:
				eye_light.light_color = Color(1, 0, 0)
				eye_light.omni_range = 10.0
			GhostState.PATROL:
				eye_light.light_color = Color(1, 0.2, 0)
				eye_light.omni_range = 5.0


func _process_idle():
	velocity.x = 0
	velocity.z = 0
	move_target = Vector3.ZERO
	if state_timer > 3.0:
		_set_state(GhostState.PATROL)
	if hunt_cooldown <= 0 and randf() < 0.01:
		_start_hunt()


func _process_patrol():
	if patrol_points.is_empty():
		_set_state(GhostState.IDLE)
		return
	move_target = patrol_points[current_patrol_index]
	if global_position.distance_to(patrol_points[current_patrol_index]) < 2.0:
		current_patrol_index += patrol_direction
		if current_patrol_index >= patrol_points.size() or current_patrol_index < 0:
			patrol_direction *= -1
			current_patrol_index += patrol_direction
	if hunt_cooldown <= 0 and randf() < 0.005:
		_start_hunt()


func _start_hunt():
	is_hunting = true
	_set_state(GhostState.HUNT)
	get_tree().create_timer(20.0).timeout.connect(func():
		is_hunting = false
		hunt_cooldown = randf_range(30.0, 60.0)
		if current_state == GhostState.HUNT or current_state == GhostState.CHASE:
			_set_state(GhostState.PATROL)
	)


func _process_hunt():
	var nearest = _find_nearest_player()
	if nearest:
		target_player = nearest
		move_target = nearest.global_position
		last_known_position = nearest.global_position
		if global_position.distance_to(nearest.global_position) < detection_range:
			_set_state(GhostState.CHASE)
	else:
		if last_known_position != Vector3.ZERO:
			move_target = last_known_position
			if global_position.distance_to(last_known_position) < 2.0:
				last_known_position = Vector3.ZERO
				move_target = Vector3.ZERO


func _process_chase():
	if not target_player or not is_instance_valid(target_player):
		target_player = null
		_set_state(GhostState.PATROL)
		return
	var dist = global_position.distance_to(target_player.global_position)
	move_target = target_player.global_position
	if dist > lose_sight_range:
		last_known_position = target_player.global_position
		target_player = null
		_set_state(GhostState.HUNT)
		return
	if dist < catch_distance:
		_set_state(GhostState.ATTACK)


func _process_attack():
	if target_player and is_instance_valid(target_player):
		if target_player.has_method("on_caught_by_ghost"):
			target_player.on_caught_by_ghost()
	_set_state(GhostState.RETURN)


func _process_return():
	if patrol_points.is_empty():
		_set_state(GhostState.IDLE)
		return
	move_target = patrol_points[0]
	if global_position.distance_to(patrol_points[0]) < 2.0:
		_set_state(GhostState.PATROL)


func _on_catch_area_body_entered(body):
	if body.is_in_group("player") and body.has_method("on_caught_by_ghost"):
		body.on_caught_by_ghost()
	_set_state(GhostState.RETURN)


func _find_nearest_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	var nearest: Node3D = null
	var nd: float = 99999.0
	for p in players:
		if p is CharacterBody3D and p.has_method("is_alive") and p.is_alive():
			var d = global_position.distance_to(p.global_position)
			if d < nd:
				nd = d
				nearest = p
	return nearest


func _generate_patrol_points():
	for m in get_tree().get_nodes_in_group("patrol_point"):
		patrol_points.append(m.global_position)
	if patrol_points.is_empty():
		for i in range(5):
			var a = (i / 5.0) * TAU
			patrol_points.append(global_position + Vector3(cos(a) * 8, 0, sin(a) * 8))
