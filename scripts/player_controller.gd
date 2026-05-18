extends CharacterBody3D
## PlayerController - First-person 3D player with movement, sprint, flashlight, and interaction
## Includes: Screen shake, flashlight flicker, visual effects

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

# Flashlight
var is_flashlight_on: bool = false
var flashlight_flicker_time: float = 0.0
var flashlight_is_flickering: bool = false

# Screen shake
var shake_intensity: float = 0.0
var shake_decay: float = 5.0
var shake_offset: Vector3 = Vector3.ZERO

# Player state
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var peer_id: int = 1
var is_local_player: bool = false
var is_alive: bool = true


func _ready():
        collision_layer = 2
        collision_mask = 1 | 4 | 16

        # Flashlight setup - starts OFF
        if flashlight:
                flashlight.visible = false
                flashlight.light_energy = 5.0
                flashlight.spot_range = 30.0
                flashlight.spot_angle = 50.0
                flashlight.spot_attenuation = 0.3
                flashlight.shadow_enabled = false

        # Load real footstep sound
        if step_audio:
                var footstep_path = "res://assets/sounds/footsteps.ogg"
                if ResourceLoader.exists(footstep_path):
                        step_audio.stream = load(footstep_path)
                        print("[Player] Loaded footstep sound from assets")

        # Load interact click sound
        if heartbeat_audio:
                var interact_path = "res://assets/sounds/interact_click.wav"
                if ResourceLoader.exists(interact_path):
                        heartbeat_audio.stream = load(interact_path)
                        print("[Player] Loaded interact sound from assets")

        # Add 3D flashlight model to camera
        _add_flashlight_visual()

        if interact_ray:
                interact_ray.target_position = Vector3(0, 0, -interact_range)
                interact_ray.collision_mask = 16

        if interact_label:
                interact_label.visible = false


func setup_as_local(player_peer_id: int):
        peer_id = player_peer_id
        is_local_player = true
        is_alive = true
        name = "Player_%d" % peer_id

        if camera:
                camera.current = true

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

        # Auto-enable flashlight after a short delay
        if flashlight:
                get_tree().create_timer(0.5).timeout.connect(func():
                        if is_local_player and flashlight:
                                is_flashlight_on = true
                                flashlight.visible = true
                                flashlight.light_energy = 5.0
                                flashlight.spot_range = 30.0
                                flashlight.spot_angle = 50.0
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
        if not is_local_player or not is_alive:
                return

        if current_state_not_playing():
                return

        # Mouse look (desktop only)
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
        if not is_local_player or not is_alive:
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
                camera.position.x = cos(head_bob_timer * 0.5) * head_bob_amplitude * 0.3
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

        # Update flashlight battery + visual effects
        _update_flashlight(delta)

        # Heartbeat when ghost is near
        _update_heartbeat()

        # Screen shake
        _update_screen_shake(delta)

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
        if GameManager.flashlight_battery <= 0 and not is_flashlight_on:
                return

        is_flashlight_on = !is_flashlight_on

        if flashlight:
                flashlight.visible = is_flashlight_on
                if is_flashlight_on:
                        var battery_ratio = GameManager.flashlight_battery / 100.0
                        flashlight.light_energy = lerp(2.0, 5.0, battery_ratio)
                        flashlight.spot_range = lerp(15.0, 30.0, battery_ratio)
                        flashlight.spot_angle = 50.0

                        # Turn on flicker effect briefly
                        flashlight_is_flickering = true
                        get_tree().create_timer(0.2).timeout.connect(func(): flashlight_is_flickering = false)

        print("[Player] Flashlight: %s (battery: %.1f%%)" % ["ON" if is_flashlight_on else "OFF", GameManager.flashlight_battery])


func _update_flashlight(delta: float):
        ## Update flashlight with battery drain and visual flicker effects
        if flashlight and is_flashlight_on:
                GameManager.update_flashlight(delta, true)
                var battery_ratio = GameManager.flashlight_battery / 100.0

                # Flashlight flicker when toggling on
                if flashlight_is_flickering:
                        flashlight_flicker_time += delta * 30.0
                        flashlight.light_energy = 5.0 * (0.5 + 0.5 * sin(flashlight_flicker_time))
                else:
                        # Normal operation - slight random variation for atmosphere
                        flashlight_flicker_time += delta
                        var flicker = sin(flashlight_flicker_time * 8.0) * 0.05
                        flashlight.light_energy = lerp(2.0, 5.0, battery_ratio) + flicker

                flashlight.spot_range = lerp(15.0, 30.0, battery_ratio)

                # Low battery flicker effect
                if battery_ratio < 0.15:
                        if randf() < 0.03:
                                flashlight.visible = false
                                get_tree().create_timer(0.1).timeout.connect(func():
                                        if is_flashlight_on:
                                                flashlight.visible = true
                                )
                        flashlight.light_energy *= randf_range(0.5, 1.0)

                # Battery empty
                if GameManager.flashlight_battery <= 0:
                        flashlight.visible = false
                        is_flashlight_on = false
                        # Screen shake when flashlight dies
                        add_screen_shake(0.3)
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
                        # Screen shake when ghost is very close
                        if distance < 5.0:
                                add_screen_shake(0.05 * intensity)
                else:
                        if heartbeat_audio and heartbeat_audio.playing:
                                heartbeat_audio.stop()


func add_screen_shake(intensity: float):
        ## Add screen shake effect
        shake_intensity = max(shake_intensity, intensity)


func _update_screen_shake(delta: float):
        ## Apply screen shake to camera
        if shake_intensity > 0:
                shake_offset = Vector3(
                        randf_range(-1, 1) * shake_intensity,
                        randf_range(-1, 1) * shake_intensity,
                        0
                )
                shake_intensity = max(0, shake_intensity - shake_decay * delta)
        else:
                shake_offset = Vector3.ZERO

        if camera:
                camera.position += shake_offset


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
                # Small screen shake on interact
                add_screen_shake(0.05)


func current_state_not_playing() -> bool:
        return GameManager.current_state != GameManager.GameState.PLAYING


func _add_flashlight_visual():
        ## Add 3D flashlight model from GLB file to the camera view
        if not camera:
                return

        var flashlight_path = "res://assets/models/flashlight.glb"
        if ResourceLoader.exists(flashlight_path):
                var flashlight_scene = load(flashlight_path)
                if flashlight_scene:
                        var flash_inst = flashlight_scene.instantiate()
                        # Position in bottom-right of camera view (first person)
                        flash_inst.position = Vector3(0.25, -0.2, -0.4)
                        flash_inst.rotation = Vector3(deg_to_rad(10), deg_to_rad(-15), 0)
                        flash_inst.scale = Vector3(0.15, 0.15, 0.15)
                        flash_inst.name = "FlashlightModel"
                        camera.add_child(flash_inst)
                        print("[Player] Loaded 3D flashlight model")
                        return

        # Fallback: simple cylinder flashlight model
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
        flash_mat.metallic = 0.8
        flash_model.set_surface_override_material(flash_mat)
        camera.add_child(flash_model)


@rpc("any_peer", "unreliable_ordered")
func _sync_position(pos: Vector3, rot: Vector3):
        if not is_local_player:
                global_position = pos
                rotation = rot


func on_caught_by_ghost():
        if not is_alive:
                return
        is_alive = false
        GameManager.on_player_caught(peer_id)

        if is_local_player:
                add_screen_shake(1.0)  # Big shake when caught
                _show_caught_screen()


func _show_caught_screen():
        var overlay = ColorRect.new()
        overlay.color = Color(0.6, 0, 0, 0.0)
        overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        get_tree().root.add_child(overlay)

        # Animate the red overlay fading in
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
        get_tree().root.add_child(label)

        # Sub-text
        var sub_label = Label.new()
        sub_label.text = "The ghost got you..."
        sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        sub_label.add_theme_font_size_override("font_size", 24)
        sub_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
        sub_label.set_anchors_preset(Control.PRESET_FULL_RECT)
        sub_label.offset_top = 60
        get_tree().root.add_child(sub_label)

        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        set_process(false)


## Check if player is alive
func is_alive() -> bool:
        return is_alive
