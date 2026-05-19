extends CharacterBody3D
## GhostPlayer - Player-controlled ghost (when a real player is the ghost)
## Similar to PlayerController but with ghost abilities

# Ghost movement
var move_speed: float = 4.5
var chase_speed: float = 7.0
var current_speed: float = 4.5
var acceleration: float = 8.0

# Ghost abilities
var can_phase_through_walls: bool = false
var catch_distance: float = 2.5
var is_hunting: bool = false
var hunt_ability_cooldown: float = 0.0
var hunt_cooldown_time: float = 30.0
var hunt_duration: float = 20.0

# References
var head: Node3D = null
var camera: Camera3D = null
var ghost_mesh: MeshInstance3D = null
var ghost_audio: AudioStreamPlayer3D = null
var catch_area: Area3D = null

const MOUSE_SENSITIVITY: float = 0.002
var gravity: float = 0.0
var peer_id: int = 1
var is_local_player: bool = false


func _ready():
	collision_layer = 4
	collision_mask = 1
	add_to_group("ghost")

	catch_area = get_node_or_null("CatchArea")
	if catch_area:
		catch_area.body_entered.connect(_on_catch_area_body_entered)

	head = get_node_or_null("Head")
	if head:
		camera = head.get_node_or_null("Camera3D")
	ghost_mesh = get_node_or_null("GhostMesh")
	ghost_audio = get_node_or_null("GhostAudio")


func setup_as_local(player_peer_id: int):
	peer_id = player_peer_id
	is_local_player = true
	name = "GhostPlayer_%d" % peer_id

	if camera:
		camera.current = true

	var is_mobile = OS.has_feature("android") or OS.has_feature("ios")
	if not is_mobile:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Ghost-specific visual setup
	if ghost_mesh:
		var mat = ghost_mesh.get_surface_override_material(0)
		if mat:
			mat.transparency_enabled = true
			mat.albedo_color.a = 0.3


func setup_as_remote(player_peer_id: int):
	peer_id = player_peer_id
	is_local_player = false
	name = "GhostPlayer_%d" % peer_id

	if camera:
		camera.current = false

	set_process_input(false)
	set_process_unhandled_input(false)


func _input(event: InputEvent):
	if not is_local_player:
		return

	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		if head:
			head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	# Hunt ability
	if event.is_action_pressed("interact"):
		_activate_hunt()


func _physics_process(delta):
	if not is_local_player:
		return

	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Update hunt cooldown
	if hunt_ability_cooldown > 0:
		hunt_ability_cooldown -= delta

	# Movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var speed = chase_speed if is_hunting else move_speed

	if direction:
		velocity.x = lerp(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * speed, acceleration * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, acceleration * delta)

	# Ghost can fly up/down
	if Input.is_key_pressed(KEY_Q):
		velocity.y = -3.0
	elif Input.is_key_pressed(KEY_E):
		velocity.y = 3.0
	else:
		velocity.y = lerp(velocity.y, 0.0, 5.0 * delta)

	move_and_slide()

	# Sync to other players
	if multiplayer.has_multiplayer_peer():
		_sync_position.rpc(position, rotation)


func _activate_hunt():
	if hunt_ability_cooldown > 0:
		return

	is_hunting = true
	hunt_ability_cooldown = hunt_cooldown_time
	current_speed = chase_speed

	# End hunt after duration
	get_tree().create_timer(hunt_duration).timeout.connect(func():
		is_hunting = false
		current_speed = move_speed
	)


func _on_catch_area_body_entered(body: Node3D):
	if body.is_in_group("player") and body != self:
		if body.has_method("on_caught_by_ghost"):
			body.on_caught_by_ghost()
		if ghost_audio:
			ghost_audio.play()


@rpc("any_peer", "unreliable_ordered")
func _sync_position(pos: Vector3, rot: Vector3):
	if not is_local_player:
		global_position = pos
		rotation = rot
