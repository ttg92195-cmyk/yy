extends CharacterBody3D
## PlayerController - MOBILE-OPTIMIZED first-person player
## V7 - ROBUST: No @onready with $ paths, null-safe camera references
## CRITICAL FIX: @onready $NodePath can return null and crash _physics_process

# Movement
const MOUSE_SENSITIVITY: float = 0.002
var walk_speed: float = 3.5
var sprint_speed: float = 5.5
var current_speed: float = 3.5
var acceleration: float = 8.0
var deceleration: float = 6.0

# Sprint / Stamina
var max_stamina: float = 100.0
var stamina: float = 100.0
var stamina_drain_rate: float = 18.0
var stamina_recharge_rate: float = 12.0
var is_sprinting: bool = false
var can_sprint: bool = true

# Head bob (reduced for mobile)
var head_bob_frequency: float = 1.5
var head_bob_amplitude: float = 0.04
var head_bob_timer: float = 0.0

# Interaction
var interact_range: float = 3.0
var interact_target: Node3D = null

# References - SAFE: no @onready with $ paths, use get_node_or_null in _ready
var head: Node3D = null
var camera: Camera3D = null
var flashlight: SpotLight3D = null
var interact_ray: RayCast3D = null
var collision_shape: CollisionShape3D = null
var step_audio: AudioStreamPlayer3D = null
var heartbeat_audio: AudioStreamPlayer3D = null
var interact_label: Label3D = null

# Flashlight
var is_flashlight_on: bool = false

# Player state - variable is alive_state NOT is_alive (function name conflict)
var gravity: float = 9.8
var peer_id: int = 1
var is_local_player: bool = false
var alive_state: bool = true

# Heartbeat timer (throttled)
var heartbeat_check_timer: float = 0.0
var heartbeat_check_interval: float = 0.5

# Footstep timer
var footstep_timer: float = 0.0


func _ready():
	# Get node references SAFELY - NO @onready with $ paths
	head = get_node_or_null("Head")
	if head:
		camera = head.get_node_or_null("Camera3D")
	if camera:
		flashlight = camera.get_node_or_null("Flashlight")
		interact_ray = camera.get_node_or_null("InteractRay")
		interact_label = camera.get_node_or_null("InteractLabel")
	collision_shape = get_node_or_null("CollisionShape3D")
	step_audio = get_node_or_null("StepAudio")
	heartbeat_audio = get_node_or_null("HeartbeatAudio")

	collision_layer = 2
	collision_mask = 1 | 4 | 16

	# Flashlight setup
	if flashlight:
		flashlight.visible = false
		flashlight.light_energy = 16.0
		flashlight.spot_range = 50.0
		flashlight.spot_angle = 65.0
		flashlight.spot_attenuation = 0.2
		flashlight.shadow_enabled = false

	# Load sounds
	if step_audio:
		var footstep_path = "res://assets/sounds/footsteps.ogg"
		if ResourceLoader.exists(footstep_path):
			step_audio.stream = load(footstep_path)

	if heartbeat_audio:
		var interact_path = "res://assets/sounds/interact_click.wav"
		if ResourceLoader.exists(interact_path):
			heartbeat_audio.stream = load(interact_path)

	# Add flashlight visual
	_add_flashlight_visual()

	if interact_ray:
		interact_ray.target_position = Vector3(0, 0, -interact_range)
		interact_ray.collision_mask = 16

	if interact_label:
		interact_label.visible = false

	print("[PlayerController] _ready() OK. Camera=%s Flashlight=%s" % [camera != null, flashlight != null])


func setup_as_local(player_peer_id: int):
	peer_id = player_peer_id
	is_local_player = true
	alive_state = true
	name = "Player_%d" % peer_id

	if camera:
		camera.current = true
		print("[PlayerController] Camera set as current")
	else:
		push_error("[PlayerController] ERROR: No camera found!")

	var is_mobile = OS.has_feature("android") or OS.has_feature("ios")
	if not is_mobile:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if GameManager.is_ghost_player:
		current_speed = GameManager.ghost_speed
		walk_speed = GameManager.ghost_speed
		sprint_speed = GameManager.ghost_speed * 1.3
	else:
		current_speed = GameManager.human_walk_speed
		walk_speed = GameManager.human_walk_speed
		sprint_speed = GameManager.human_sprint_speed

	# Auto-enable flashlight after delay
	if flashlight:
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_local_player and flashlight:
				is_flashlight_on = true
				flashlight.visible = true
				flashlight.light_energy = 16.0
				flashlight.spot_range = 50.0
				flashlight.spot_angle = 65.0
				print("[PlayerController] Flashlight ON")
		)


func setup_as_remote(player_peer_id: int):
	peer_id = player_peer_id
	is_local_player = false
	name = "Player_%d" % peer_id

	if camera:
		camera.current = false

	set_process_input(false)
	set_process_unhandled_input(false)


func _input(event: InputEvent):
	if not is_local_player or not alive_state:
		return

	if current_state_not_playing():
		return

	# Mouse look (desktop only)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		if head:
			head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	# Flashlight toggle
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()

	# Interact
	if event.is_action_pressed("interact"):
		try_interact()


func _physics_process(delta):
	if not is_local_player or not alive_state:
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

		# Head bob (null-safe)
		head_bob_timer += delta * head_bob_frequency * (2.0 if is_sprinting else 1.0)
		if camera:
			camera.position.y = sin(head_bob_timer) * head_bob_amplitude
	else:
		velocity.x = lerp(velocity.x, 0.0, deceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, deceleration * delta)
		head_bob_timer = 0.0
		if camera:
			camera.position.y = lerp(camera.position.y, 0.0, 5.0 * delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Footstep sounds
	if direction and is_on_floor():
		footstep_timer += delta
		var step_interval = 0.45 if is_sprinting else 0.6
		if footstep_timer >= step_interval:
			footstep_timer = 0.0
			if step_audio and not step_audio.playing:
				step_audio.play()
	else:
		footstep_timer = 0.3

	# Interaction check
	check_interact()

	# Update flashlight battery
	_update_flashlight(delta)

	# Heartbeat (throttled)
	heartbeat_check_timer += delta
	if heartbeat_check_timer >= heartbeat_check_interval:
		heartbeat_check_timer = 0.0
		_update_heartbeat()

	move_and_slide()

	# Sync position to other players (only if multiplayer is active)
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
	if GameManager.flashlight_battery <= 0 and not is_flashlight_on:
		return

	is_flashlight_on = !is_flashlight_on

	if flashlight:
		flashlight.visible = is_flashlight_on
		if is_flashlight_on:
			var battery_ratio = GameManager.flashlight_battery / 100.0
			flashlight.light_energy = lerp(8.0, 16.0, battery_ratio)
			flashlight.spot_range = lerp(25.0, 50.0, battery_ratio)
			flashlight.spot_angle = 65.0


func _update_flashlight(delta: float):
	if flashlight and is_flashlight_on:
		GameManager.update_flashlight(delta, true)
		var battery_ratio = GameManager.flashlight_battery / 100.0

		flashlight.light_energy = lerp(8.0, 16.0, battery_ratio)
		flashlight.spot_range = lerp(25.0, 50.0, battery_ratio)

		# Low battery - occasional flicker
		if battery_ratio < 0.15:
			if randf() < 0.02:
				flashlight.visible = false
				get_tree().create_timer(0.1).timeout.connect(func():
					if is_flashlight_on and flashlight:
						flashlight.visible = true
				)

		# Battery empty
		if GameManager.flashlight_battery <= 0:
			flashlight.visible = false
			is_flashlight_on = false
	else:
		GameManager.update_flashlight(delta, false)


func _update_heartbeat():
	if GameManager.is_ghost_player:
		return

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
		interact_target.on_interact(peer_id)


func current_state_not_playing() -> bool:
	return GameManager.current_state != GameManager.GameState.PLAYING


func _add_flashlight_visual():
	if not camera:
		return

	var flashlight_path = "res://assets/models/flashlight.glb"
	if ResourceLoader.exists(flashlight_path):
		var flashlight_scene = load(flashlight_path)
		if flashlight_scene:
			var flash_inst = flashlight_scene.instantiate()
			flash_inst.position = Vector3(0.25, -0.2, -0.4)
			flash_inst.rotation = Vector3(deg_to_rad(10), deg_to_rad(-15), 0)
			flash_inst.scale = Vector3(0.15, 0.15, 0.15)
			flash_inst.name = "FlashlightModel"
			camera.add_child(flash_inst)
			return

	# Fallback: simple cylinder
	var flash_model = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.04
	cyl.height = 0.15
	flash_model.mesh = cyl
	flash_model.position = Vector3(0.25, -0.2, -0.4)
	flash_model.rotation = Vector3(deg_to_rad(10), 0, 0)
	flash_model.name = "FlashlightModel"
	var flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(0.3, 0.3, 0.35)
	flash_mat.roughness = 0.3
	flash_mat.metallic = 0.7
	flash_model.set_surface_override_material(flash_mat)
	camera.add_child(flash_model)


@rpc("any_peer", "unreliable_ordered")
func _sync_position(pos: Vector3, rot: Vector3):
	if not is_local_player:
		global_position = pos
		rotation = rot


func on_caught_by_ghost():
	if not alive_state:
		return
	alive_state = false
	GameManager.on_player_caught(peer_id)

	if is_local_player:
		_show_caught_screen()


func _show_caught_screen():
	var canvas = CanvasLayer.new()
	canvas.layer = 50
	canvas.name = "CaughtCanvas"
	add_child(canvas)

	var overlay = ColorRect.new()
	overlay.color = Color(0.6, 0, 0, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)

	var tween = get_tree().create_tween()
	tween.tween_property(overlay, "color:a", 0.8, 0.5)

	await get_tree().create_timer(0.5).timeout

	var label = Label.new()
	label.text = "YOU HAVE BEEN CAUGHT!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(label)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_process(false)


func is_alive() -> bool:
	return alive_state
