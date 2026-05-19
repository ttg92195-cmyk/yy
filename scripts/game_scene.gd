extends Node3D
# GameScene V7 - BULLETPROOF: Fallback camera, loading overlay, single-player fix
# Every step creates visible output so we NEVER get a black screen
# Uses start_gameplay_singleplayer() so alive_humans=1 and items work

@export var use_ai_ghost: bool = true

var player_scene: PackedScene = null
var ghost_ai_scene: PackedScene = null
var player_spawn_points: Array = []
var ghost_spawn_point: Marker3D = null
var map_generator: Node3D = null
var players_container: Node3D = null
var items_container: Node3D = null
var hud: CanvasLayer = null
var touch_controls: CanvasLayer = null
var debug_label: Label = null
var fallback_camera: Camera3D = null
var status_label: Label = null
var loading_canvas: CanvasLayer = null


func _ready():
	# === STEP 1: Create fallback camera FIRST ===
	fallback_camera = Camera3D.new()
	fallback_camera.name = "FallbackCamera"
	fallback_camera.current = true
	fallback_camera.position = Vector3(0, 5, 10)
	fallback_camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	add_child(fallback_camera)

	# === STEP 2: Create LOADING OVERLAY ===
	_create_loading_overlay()

	# === STEP 3: Create bright environment IMMEDIATELY ===
	_setup_environment()

	# === STEP 4: Create emergency floor so SOMETHING is visible ===
	_create_emergency_floor()

	# === STEP 5: Create debug overlay ===
	_setup_debug_overlay()
	_debug("=== THE GHOST v0.7.0 ===")
	_debug("Device: " + OS.get_name())

	# === STEP 6: Create containers ===
	players_container = Node3D.new()
	players_container.name = "Players"
	add_child(players_container)

	items_container = Node3D.new()
	items_container.name = "Items"
	add_child(items_container)

	# === STEP 7: Load scenes ===
	_set_loading("Loading player...")
	player_scene = load("res://scenes/player.tscn")
	if player_scene:
		_debug("Player scene: OK")
	else:
		_debug("ERROR: Player scene FAILED!")

	_set_loading("Loading ghost...")
	ghost_ai_scene = load("res://scenes/ghost_ai.tscn")
	if ghost_ai_scene:
		_debug("Ghost AI scene: OK")
	else:
		_debug("ERROR: Ghost AI scene FAILED!")

	# === STEP 8: Generate map ===
	_set_loading("Building hospital...")
	_debug("Building hospital map...")
	var map_script = load("res://scripts/map_generator.gd")
	if map_script:
		map_generator = Node3D.new()
		map_generator.name = "Map"
		map_generator.set_script(map_script)
		add_child(map_generator)
		_debug("Map script: OK")
	else:
		_debug("ERROR: Map script FAILED! Using emergency floor only.")

	# === STEP 9: Setup spawn points ===
	_setup_spawn_points()

	# === STEP 10: Setup HUD ===
	_setup_hud()

	# === STEP 11: Setup touch controls ===
	_setup_touch_controls()

	# === STEP 12: Connect game state ===
	if GameManager:
		GameManager.game_state_changed.connect(_on_game_state_changed)

	# === STEP 13: Start game with SINGLE-PLAYER FIX ===
	if use_ai_ghost:
		_start_ai_ghost_game()
	else:
		_debug("Not using AI ghost mode")

	# === STEP 14: Schedule cleanup ===
	get_tree().create_timer(3.0).timeout.connect(_cleanup_fallback)
	get_tree().create_timer(15.0).timeout.connect(_hide_debug)

	# === STEP 15: Hide loading overlay ===
	_hide_loading()

	_debug("=== SETUP COMPLETE ===")


func _create_loading_overlay():
	loading_canvas = CanvasLayer.new()
	loading_canvas.name = "LoadingCanvas"
	loading_canvas.layer = 200
	add_child(loading_canvas)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.01, 0.03)
	loading_canvas.add_child(bg)

	var title = Label.new()
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_left = -200
	title.offset_right = 200
	title.offset_top = -80
	title.offset_bottom = -40
	title.text = "THE GHOST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	loading_canvas.add_child(title)

	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_CENTER)
	status_label.offset_left = -200
	status_label.offset_right = 200
	status_label.offset_top = -10
	status_label.offset_bottom = 30
	status_label.text = "Loading..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
	loading_canvas.add_child(status_label)


func _set_loading(text: String):
	if status_label:
		status_label.text = text


func _hide_loading():
	if loading_canvas:
		loading_canvas.visible = false


func _start_ai_ghost_game():
	_debug("Starting AI Ghost game...")

	if GameManager:
		# CRITICAL: Reset game state first
		GameManager.reset_game()
		GameManager.set_local_role("human")
		# CRITICAL: Use single-player mode so alive_humans=1 and items work
		GameManager.start_gameplay_singleplayer()
		_debug("GameManager: single-player mode, alive_humans=1")

	_spawn_player(1)
	_spawn_ai_ghost()
	_debug("Game started!")


func _setup_environment():
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.10, 0.15, 1)

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.60, 0.65, 1)
	env.ambient_light_energy = 5.0

	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.12, 0.18, 1)
	env.fog_density = 0.003
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 80.0

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 2.0

	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false

	world_env.environment = env
	add_child(world_env)

	var dir = DirectionalLight3D.new()
	dir.name = "Moonlight"
	dir.light_energy = 2.5
	dir.light_color = Color(0.7, 0.7, 0.85)
	dir.rotation = Vector3(deg_to_rad(-70), deg_to_rad(25), 0)
	dir.shadow_enabled = false
	add_child(dir)

	var dir2 = DirectionalLight3D.new()
	dir2.name = "FillLight"
	dir2.light_energy = 1.5
	dir2.light_color = Color(0.6, 0.6, 0.7)
	dir2.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-135), 0)
	dir2.shadow_enabled = false
	add_child(dir2)


func _create_emergency_floor():
	var floor_body = StaticBody3D.new()
	floor_body.name = "EmergencyFloor"
	floor_body.collision_layer = 1

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(60, 0.5, 60)
	col.shape = shape
	floor_body.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(60, 0.5, 60)
	mesh_inst.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.12, 0.12)
	mat.roughness = 0.9
	mesh_inst.set_surface_override_material(mat)
	floor_body.add_child(mesh_inst)

	floor_body.position = Vector3(0, -0.25, 0)
	add_child(floor_body)


func _setup_debug_overlay():
	var canvas = CanvasLayer.new()
	canvas.name = "DebugCanvas"
	canvas.layer = 100
	add_child(canvas)

	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(10, 10)
	debug_label.size = Vector2(600, 400)
	debug_label.add_theme_font_size_override("font_size", 14)
	debug_label.add_theme_color_override("font_color", Color(1, 1, 0))
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.85)
	bg.border_color = Color(1, 0.5, 0)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	debug_label.add_theme_stylebox_override("normal", bg)
	canvas.add_child(debug_label)


func _debug(msg):
	print("[GameScene] " + str(msg))
	if debug_label:
		var lines = debug_label.text.split("\n")
		if lines.size() > 18:
			lines = lines.slice(-17)
		lines.append(str(msg))
		debug_label.text = "\n".join(lines)


func _setup_spawn_points():
	var s = Marker3D.new()
	s.position = Vector3(0, 0.5, 0)
	s.name = "PlayerSpawn"
	add_child(s)
	player_spawn_points.append(s)

	ghost_spawn_point = Marker3D.new()
	ghost_spawn_point.position = Vector3(0, 0.5, -10)
	ghost_spawn_point.name = "GhostSpawn"
	add_child(ghost_spawn_point)


func _setup_hud():
	var hud_script = load("res://scripts/hud.gd")
	if hud_script:
		hud = CanvasLayer.new()
		hud.name = "HUD"
		hud.set_script(hud_script)
		add_child(hud)
		_debug("HUD: OK")
	else:
		_debug("ERROR: HUD script failed!")


func _setup_touch_controls():
	var tc_script = load("res://scripts/touch_controls.gd")
	if tc_script:
		touch_controls = CanvasLayer.new()
		touch_controls.name = "TouchControls"
		touch_controls.set_script(tc_script)
		add_child(touch_controls)
		_debug("Touch controls: OK")
	else:
		_debug("ERROR: Touch controls script failed!")


func _spawn_player(peer_id: int):
	if not player_scene:
		_debug("ERROR: No player scene! Creating emergency player...")
		_create_emergency_player()
		return

	var player = player_scene.instantiate()
	if not player:
		_debug("ERROR: Player instantiate failed!")
		_create_emergency_player()
		return

	player.name = "Player_%d" % peer_id

	if player_spawn_points.size() > 0:
		player.global_position = player_spawn_points[0].global_position

	players_container.add_child(player)

	if player.has_method("setup_as_local"):
		player.setup_as_local(peer_id)
		_debug("Player spawned OK")
	else:
		_debug("WARNING: Player missing setup_as_local")
		var cam = player.get_node_or_null("Head/Camera3D")
		if cam:
			cam.current = true
			_debug("Camera activated manually")
		else:
			_debug("ERROR: No camera on player!")

	player.add_to_group("player")
	_add_player_body(player)
	_debug("Player at: " + str(player.global_position))


func _create_emergency_player():
	# Create a minimal player if the scene fails to load
	var player = CharacterBody3D.new()
	player.name = "EmergencyPlayer"
	player.collision_layer = 2
	player.collision_mask = 1 | 4 | 16

	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position = Vector3(0, 0.9, 0)
	player.add_child(col)

	var head_node = Node3D.new()
	head_node.name = "Head"
	head_node.position = Vector3(0, 1.6, 0)
	player.add_child(head_node)

	var cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam.fov = 75.0
	head_node.add_child(cam)

	var flash = SpotLight3D.new()
	flash.name = "Flashlight"
	flash.visible = true
	flash.light_energy = 16.0
	flash.spot_range = 50.0
	flash.spot_angle = 65.0
	flash.spot_attenuation = 0.2
	flash.shadow_enabled = false
	head_node.add_child(flash)

	var step = AudioStreamPlayer3D.new()
	step.name = "StepAudio"
	step.max_distance = 15.0
	player.add_child(step)

	var heartbeat = AudioStreamPlayer3D.new()
	heartbeat.name = "HeartbeatAudio"
	heartbeat.max_distance = 5.0
	player.add_child(heartbeat)

	# Apply player controller script
	var pc_script = load("res://scripts/player_controller.gd")
	if pc_script:
		player.set_script(pc_script)
		player.set("alive_state", true)
		player.set("is_local_player", true)
		player.set("peer_id", 1)

	player.position = Vector3(0, 0.5, 0)
	players_container.add_child(player)

	player.add_to_group("player")
	_debug("Emergency player created!")


func _add_player_body(player: CharacterBody3D):
	var body_node = player.get_node_or_null("BodyMesh")
	if body_node and body_node is MeshInstance3D:
		var capsule = CapsuleMesh.new()
		capsule.radius = 0.3
		capsule.height = 1.4
		body_node.mesh = capsule
		var body_mat = StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.4, 0.35, 0.3)
		body_mat.roughness = 0.9
		body_node.set_surface_override_material(body_mat)


func _spawn_ai_ghost():
	if not ghost_ai_scene:
		_debug("ERROR: No ghost AI scene!")
		return

	var ghost = ghost_ai_scene.instantiate()
	if not ghost:
		_debug("ERROR: Ghost instantiate failed!")
		return

	ghost.name = "GhostAI"
	if ghost_spawn_point:
		ghost.global_position = ghost_spawn_point.global_position

	players_container.add_child(ghost)
	_debug("Ghost spawned at: " + str(ghost.global_position))


func _cleanup_fallback():
	if fallback_camera and is_instance_valid(fallback_camera):
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			var cam = p.get_node_or_null("Head/Camera3D")
			if cam and cam.current:
				fallback_camera.queue_free()
				fallback_camera = null
				_debug("Fallback camera removed")
				return
		_debug("WARNING: No player camera found, keeping fallback")


func _hide_debug():
	if debug_label:
		debug_label.visible = false


func _on_game_state_changed(new_state):
	if new_state == GameManager.GameState.GAME_OVER:
		_show_game_over("ghost")
	elif new_state == GameManager.GameState.ESCAPED:
		_show_game_over("human")


func _show_game_over(winner: String):
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	if winner == "ghost":
		overlay.color = Color(0.3, 0, 0, 0.85)
	else:
		overlay.color = Color(0, 0.25, 0, 0.85)

	var canvas = CanvasLayer.new()
	canvas.layer = 200
	canvas.add_child(overlay)
	add_child(canvas)

	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 42)
	if winner == "ghost":
		label.text = "THE GHOST GOT YOU!"
		label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	else:
		label.text = "YOU ESCAPED!"
		label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))
	canvas.add_child(label)

	var btn = Button.new()
	btn.text = "BACK TO MENU"
	btn.position = Vector2(get_viewport().size.x / 2 - 100, get_viewport().size.y / 2 + 80)
	btn.size = Vector2(200, 50)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.04, 0.04, 0.9)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
	btn.pressed.connect(func(): GameManager.return_to_menu())
	canvas.add_child(btn)
