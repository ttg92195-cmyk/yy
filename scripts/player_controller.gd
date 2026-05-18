extends CharacterBody3D
## PlayerController - First-person 3D player with movement, sprint, flashlight, and interaction
## Attached to Player scene root node

# Movement
const MOUSE_SENSITIVITY: float = 0.002
var walk_speed: float = 3.5
var sprint_speed: float = 6.0
var current_speed: float = 3.5
var acceleration: float = 10.0
var deceleration: float = 8.0

# Sprint / Stamina
var max_stamina: float = 100.0
var stamina: float = 100.0
var stamina_drain_rate: float = 20.0
var stamina_recharge_rate: float = 10.0
var is_sprinting: bool = false
var can_sprint: bool = true

# Head bob
var head_bob_frequency: float = 2.0
var head_bob_amplitude: float = 0.08
var head_bob_timer: float = 0.0

# Interaction
var interact_range: float = 3.0
var interact_target: Node3D = null

# References
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var step_audio: AudioStreamPlayer3D = $StepAudio
@onready var heartbeat_audio: AudioStreamPlayer3D = $HeartbeatAudio
@onready var interact_label: Label3D = $Head/Camera3D/InteractLabel

var is_flashlight_on: bool = true
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var peer_id: int = 1
var is_local_player: bool = false


func _ready():
	# Set up collision layers
	collision_layer = 2  # Player layer
	collision_mask = 1 | 4 | 16  # Environment, Items, Interactable

	# Flashlight setup
	if flashlight:
		flashlight.visible = true
		flashlight.light_energy = 2.5
		flashlight.spot_range = 20.0
		flashlight.spot_angle = 40.0
		flashlight.spot_attenuation = 0.5

	# Interaction ray setup
	if interact_ray:
		interact_ray.target_position = Vector3(0, 0, -interact_range)
		interact_ray.collision_mask = 16  # Interactable layer

	# Hide interact label initially
	if interact_label:
		interact_label.visible = false


func setup_as_local(player_peer_id: int):
	"""Configure this player as the local (controllable) player"""
	peer_id = player_peer_id
	is_local_player = true
	name = "Player_%d" % peer_id

	# Enable camera and input
	if camera:
		camera.current = true

	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Set role-based speed
	if GameManager.is_ghost_player:
		current_speed = GameManager.ghost_speed
		walk_speed = GameManager.ghost_speed
		sprint_speed = GameManager.ghost_speed * 1.3
	else:
		current_speed = GameManager.human_walk_speed
		walk_speed = GameManager.human_walk_speed
		sprint_speed = GameManager.human_sprint_speed


func setup_as_remote(player_peer_id: int):
	"""Configure this player as a remote (other player's) character"""
	peer_id = player_peer_id
	is_local_player = false
	name = "Player_%d" % peer_id

	# Disable camera for remote players
	if camera:
		camera.current = false

	# Disable input processing
	set_process_input(false)
	set_process_unhandled_input(false)


func _input(event: InputEvent):
	if not is_local_player:
		return

	if current_state_not_playing():
		return

	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	# Flashlight toggle
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()

	# Interact
	if event.is_action_pressed("interact"):
		try_interact()


func _physics_process(delta):
	if not is_local_player:
		return

	if current_state_not_playing():
		return

	# Handle movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Sprint handling
	handle_sprint(delta, direction)

	# Apply movement
	if direction:
		velocity.x = lerp(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, acceleration * delta)

		# Head bob
		head_bob_timer += delta * head_bob_frequency * (2.0 if is_sprinting else 1.0)
		camera.position.y = sin(head_bob_timer) * head_bob_amplitude
	else:
		velocity.x = lerp(velocity.x, 0.0, deceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, deceleration * delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Footstep sounds
	if direction and is_on_floor():
		if not step_audio.playing:
			step_audio.play()

	# Interaction check
	check_interact()

	# Update flashlight battery
	if flashlight and flashlight.visible:
		GameManager.update_flashlight(delta, true)
		flashlight.light_energy = 2.5 * (GameManager.flashlight_battery / 100.0)
		if GameManager.flashlight_battery <= 0:
			flashlight.visible = false
			is_flashlight_on = false
	else:
		GameManager.update_flashlight(delta, false)

	# Heartbeat when ghost is near
	_update_heartbeat()

	move_and_slide()

	# Sync position to other players
	if multiplayer.has_multiplayer_peer():
		_sync_position.rpc(position, rotation)


func handle_sprint(delta: float, direction: Vector3):
	if Input.is_action_pressed("sprint") and direction and stamina > 0 and not GameManager.is_ghost_player:
		is_sprinting = true
		current_speed = sprint_speed
		stamina = max(0, stamina - stamina_drain_rate * delta)
		if stamina <= 0:
			can_sprint = false
	elif not can_sprint and stamina < 20:
		can_sprint = true
		is_sprinting = false
		current_speed = walk_speed
	else:
		is_sprinting = false
		current_speed = walk_speed
		stamina = min(max_stamina, stamina + stamina_recharge_rate * delta)


func toggle_flashlight():
	if GameManager.flashlight_battery <= 0:
		return
	is_flashlight_on = !is_flashlight_on
	if flashlight:
		flashlight.visible = is_flashlight_on
		if is_flashlight_on:
			_play_flashlight_sound()


func _play_flashlight_sound():
	# Play click sound
	pass


func check_interact():
	if not interact_ray:
		return

	if interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		if collider and collider.has_method("on_interact"):
			interact_target = collider
			if interact_label:
				interact_label.visible = true
				interact_label.text = collider.get_interaction_text() if collider.has_method("get_interaction_text") else "[E] Interact"
		else:
			interact_target = null
			if interact_label:
				interact_label.visible = false
	else:
		interact_target = null
		if interact_label:
			interact_label.visible = false


func try_interact():
	if interact_target and interact_target.has_method("on_interact"):
		interact_target.on_interact(multiplayer.get_unique_id())


func _update_heartbeat():
	"""Play heartbeat sound when ghost is nearby"""
	if GameManager.is_ghost_player:
		return

	# Find ghost in scene
	var ghost = get_tree().get_first_node_in_group("ghost")
	if ghost:
		var distance = global_position.distance_to(ghost.global_position)
		if distance < 15.0:
			var intensity = 1.0 - (distance / 15.0)
			if heartbeat_audio:
				heartbeat_audio.volume_db = lerp(-40, -10, intensity)
				if not heartbeat_audio.playing:
					heartbeat_audio.play()
		else:
			if heartbeat_audio and heartbeat_audio.playing:
				heartbeat_audio.stop()


func current_state_not_playing() -> bool:
	return GameManager.current_state != GameManager.GameState.PLAYING


## Sync position to other players via RPC
@rpc("any_peer", "unreliable_ordered")
func _sync_position(pos: Vector3, rot: Vector3):
	if not is_local_player:
		global_position = pos
		rotation = rot


## Called when this player is caught by the ghost
func on_caught_by_ghost():
	GameManager.on_player_caught(peer_id)

	# Visual effects for being caught
	if is_local_player:
		# Screen goes red, jump scare
		_show_caught_screen()


func _show_caught_screen():
	"""Show the caught/death screen"""
	var overlay = ColorRect.new()
	overlay.color = Color(0.5, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(overlay)

	var label = Label.new()
	label.text = "YOU HAVE BEEN CAUGHT!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(label)

	# Disable input
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_process(false)
