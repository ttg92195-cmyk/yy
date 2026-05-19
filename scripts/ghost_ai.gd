extends CharacterBody3D
## GhostAI - Lightweight ghost with improved 3D visual
## Uses direct movement (NO NavigationAgent3D - prevents crash)
## Creates a scary-looking ghost figure with dark robes and glowing eyes

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

var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var patrol_direction: int = 1

var ghost_float_time: float = 0.0
var is_ghost_visible: bool = true

@onready var ghost_audio: AudioStreamPlayer3D = $GhostAudio
@onready var catch_area: Area3D = $CatchArea

# Visual parts
var head_mesh: MeshInstance3D
var body_mesh: MeshInstance3D
var robe_mesh: MeshInstance3D
var left_hand_mesh: MeshInstance3D
var right_hand_mesh: MeshInstance3D
var eye_left: MeshInstance3D
var eye_right: MeshInstance3D
var eye_light: OmniLight3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var move_target: Vector3 = Vector3.ZERO


func _ready():
	collision_layer = 4
	collision_mask = 1
	add_to_group("ghost")

	_build_ghost_visual()

	if catch_area:
		catch_area.body_entered.connect(_on_catch_area_body_entered)

	_set_state(GhostState.PATROL)
	_generate_patrol_points()


func _build_ghost_visual():
	## Build a scary ghost figure from simple meshes
	# Dark ghost material
	var ghost_mat = StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(0.08, 0.06, 0.12, 0.75)
	ghost_mat.transparency_enabled = true
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.emission_enabled = true
	ghost_mat.emission = Color(0.03, 0.01, 0.06)
	ghost_mat.emission_energy = 0.3
	ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Darker robe material
	var robe_mat = StandardMaterial3D.new()
	robe_mat.albedo_color = Color(0.04, 0.02, 0.08, 0.85)
	robe_mat.transparency_enabled = true
	robe_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	robe_mat.emission_enabled = true
	robe_mat.emission = Color(0.02, 0.005, 0.04)
	robe_mat.emission_energy = 0.2
	robe_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Head - slightly larger, distorted sphere
	head_mesh = MeshInstance3D.new()
	var head = SphereMesh.new()
	head.radius = 0.3
	head.height = 0.5
	head_mesh.mesh = head
	head_mesh.position = Vector3(0, 1.7, 0)
	head_mesh.scale = Vector3(1.0, 1.2, 0.9)
	head_mesh.set_surface_override_material(ghost_mat)
	add_child(head_mesh)

	# Body - tapered cylinder (torso)
	body_mesh = MeshInstance3D.new()
	var body = CylinderMesh.new()
	body.top_radius = 0.28
	body.bottom_radius = 0.15
	body.height = 0.8
	body_mesh.mesh = body
	body_mesh.position = Vector3(0, 1.15, 0)
	body_mesh.set_surface_override_material(ghost_mat)
	add_child(body_mesh)

	# Robe - wider cone shape hanging down
	robe_mesh = MeshInstance3D.new()
	var robe = CylinderMesh.new()
	robe.top_radius = 0.32
	robe.bottom_radius = 0.55
	robe.height = 1.2
	robe_mesh.mesh = robe
	robe_mesh.position = Vector3(0, 0.6, 0)
	robe_mesh.set_surface_override_material(robe_mat)
	add_child(robe_mesh)

	# Left hand - small elongated shape reaching forward
	left_hand_mesh = MeshInstance3D.new()
	var lhand = BoxMesh.new()
	lhand.size = Vector3(0.08, 0.25, 0.06)
	left_hand_mesh.mesh = lhand
	left_hand_mesh.position = Vector3(-0.4, 1.2, 0.3)
	left_hand_mesh.rotation = Vector3(deg_to_rad(30), deg_to_rad(-20), 0)
	var hand_mat = StandardMaterial3D.new()
	hand_mat.albedo_color = Color(0.12, 0.08, 0.15, 0.8)
	hand_mat.transparency_enabled = true
	hand_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hand_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	left_hand_mesh.set_surface_override_material(hand_mat)
	add_child(left_hand_mesh)

	# Right hand
	right_hand_mesh = MeshInstance3D.new()
	var rhand = BoxMesh.new()
	rhand.size = Vector3(0.08, 0.25, 0.06)
	right_hand_mesh.mesh = rhand
	right_hand_mesh.position = Vector3(0.4, 1.2, 0.3)
	right_hand_mesh.rotation = Vector3(deg_to_rad(30), deg_to_rad(20), 0)
	right_hand_mesh.set_surface_override_material(hand_mat)
	add_child(right_hand_mesh)

	# Arms (thin cylinders connecting hands to body)
	var arm_mat = ghost_mat
	# Left arm
	var left_arm = MeshInstance3D.new()
	var la = CylinderMesh.new()
	la.top_radius = 0.04
	la.bottom_radius = 0.03
	la.height = 0.5
	left_arm.mesh = la
	left_arm.position = Vector3(-0.35, 1.2, 0.1)
	left_arm.rotation = Vector3(deg_to_rad(60), 0, deg_to_rad(15))
	left_arm.set_surface_override_material(arm_mat)
	add_child(left_arm)
	# Right arm
	var right_arm = MeshInstance3D.new()
	var ra = CylinderMesh.new()
	ra.top_radius = 0.04
	ra.bottom_radius = 0.03
	ra.height = 0.5
	right_arm.mesh = ra
	right_arm.position = Vector3(0.35, 1.2, 0.1)
	right_arm.rotation = Vector3(deg_to_rad(60), 0, deg_to_rad(-15))
	right_arm.set_surface_override_material(arm_mat)
	add_child(right_arm)

	# Eyes - glowing red
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1, 0.1, 0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1, 0.3, 0)
	eye_mat.emission_energy = 4.0
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	eye_left = MeshInstance3D.new()
	var el = SphereMesh.new()
	el.radius = 0.055
	el.height = 0.06
	eye_left.mesh = el
	eye_left.position = Vector3(-0.1, 1.75, 0.22)
	eye_left.set_surface_override_material(eye_mat)
	add_child(eye_left)

	eye_right = MeshInstance3D.new()
	var er = SphereMesh.new()
	er.radius = 0.055
	er.height = 0.06
	eye_right.mesh = er
	eye_right.position = Vector3(0.1, 1.75, 0.22)
	eye_right.set_surface_override_material(eye_mat)
	add_child(eye_right)

	# Eye glow light
	eye_light = OmniLight3D.new()
	eye_light.position = Vector3(0, 1.75, 0.3)
	eye_light.light_color = Color(1, 0.2, 0)
	eye_light.light_energy = 1.5
	eye_light.omni_range = 6.0
	eye_light.shadow_enabled = false
	add_child(eye_light)


func _physics_process(delta):
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	state_timer += delta

	# Floating animation
	ghost_float_time += delta
	var float_y = sin(ghost_float_time * 1.5) * 0.08
	var float_tilt = sin(ghost_float_time * 0.8) * 0.02
	if head_mesh:
		head_mesh.position.y = 1.7 + float_y
	if body_mesh:
		body_mesh.position.y = 1.15 + float_y * 0.7
	if robe_mesh:
		robe_mesh.position.y = 0.6 + float_y * 0.3
	# Subtle hand swaying
	if left_hand_mesh:
		left_hand_mesh.rotation.x = deg_to_rad(30) + sin(ghost_float_time * 2.0) * 0.1
	if right_hand_mesh:
		right_hand_mesh.rotation.x = deg_to_rad(30) + sin(ghost_float_time * 2.0 + 1.0) * 0.1

	if hunt_cooldown > 0:
		hunt_cooldown -= delta

	match current_state:
		GhostState.IDLE: _process_idle()
		GhostState.PATROL: _process_patrol()
		GhostState.HUNT: _process_hunt()
		GhostState.CHASE: _process_chase()
		GhostState.ATTACK: _process_attack()
		GhostState.RETURN: _process_return()

	# Gravity (reduced for ghost - they float)
	if not is_on_floor():
		velocity.y -= gravity * 0.2 * delta

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


func _set_ghost_visible(v: bool):
	is_ghost_visible = v
	for child in get_children():
		if child is MeshInstance3D or child is OmniLight3D:
			child.visible = v


func _set_state(s: GhostState):
	if current_state == s:
		return
	current_state = s
	state_timer = 0.0
	# Change eye color based on state
	if s == GhostState.HUNT and eye_light:
		eye_light.light_color = Color(1, 0.5, 0)
		eye_light.omni_range = 8.0
		eye_light.light_energy = 2.5
		if eye_left and eye_right:
			var hunt_eye = eye_left.get_surface_override_material(0) as StandardMaterial3D
			if hunt_eye:
				hunt_eye.emission = Color(1, 0.5, 0)
				hunt_eye.emission_energy = 6.0
	elif s == GhostState.CHASE and eye_light:
		eye_light.light_color = Color(1, 0, 0)
		eye_light.omni_range = 10.0
		eye_light.light_energy = 3.5
		if eye_left and eye_right:
			var chase_eye = eye_left.get_surface_override_material(0) as StandardMaterial3D
			if chase_eye:
				chase_eye.emission = Color(1, 0, 0)
				chase_eye.emission_energy = 8.0
	elif s == GhostState.PATROL and eye_light:
		eye_light.light_color = Color(1, 0.2, 0)
		eye_light.omni_range = 6.0
		eye_light.light_energy = 1.5
		if eye_left and eye_right:
			var patrol_eye = eye_left.get_surface_override_material(0) as StandardMaterial3D
			if patrol_eye:
				patrol_eye.emission = Color(1, 0.3, 0)
				patrol_eye.emission_energy = 4.0


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


func _on_catch_area_body_entered(body: Node3D):
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
			patrol_points.append(global_position + Vector3(cos(a)*8, 0, sin(a)*8))
