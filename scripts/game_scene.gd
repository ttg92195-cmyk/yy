extends Node3D
## GameScene - V5 ROBUST - Survives script errors
## Key changes:
## - Uses load() instead of preload() so errors don't crash the whole scene
## - Creates a FALLBACK CAMERA so screen is never black
## - Creates a 2D loading overlay FIRST before any 3D setup
## - Debug info on screen at all times during loading

@export var use_ai_ghost: bool = true

# NOT using preload - we use load() with error handling instead
var player_scene: PackedScene = null
var ghost_ai_scene: PackedScene = null

var player_spawn_points: Array[Marker3D] = []
var ghost_spawn_point: Marker3D = null
var map_generator: Node3D = null
var players_container: Node3D = null
var items_container: Node3D = null
var hud: CanvasLayer = null
var touch_controls: CanvasLayer = null
var debug_label: Label = null
var fallback_camera: Camera3D = null
var loading_overlay: ColorRect = null
var loading_text: Label = null


func _ready():
	# STEP 1: Create 2D loading overlay FIRST - always visible
	_create_loading_overlay()
	_show_loading("THE GHOST v0.5.0\nLoading...")

	# STEP 2: Create fallback camera - so screen is NEVER black
	_create_fallback_camera()

	# STEP 3: Create debug label
	_create_debug_label()
	_debug("=== THE GHOST v0.5.0 ===")
	_debug("Device: " + OS.get_name())
	_debug("Renderer: " + ProjectSettings.get_setting("rendering/renderer/rendering_method"))

	# STEP 4: Load scenes with error handling
	_show_loading("Loading player...")
	player_scene = load("res://scenes/player.tscn")
	if player_scene:
		_debug("Player scene loaded OK")
		_show_loading("Player OK")
	else:
		_debug("ERROR: Player scene FAILED to load!")
		_show_loading("ERROR: Player scene failed!")

	ghost_ai_scene = load("res://scenes/ghost_ai.tscn")
	if ghost_ai_scene:
		_debug("Ghost AI scene loaded OK")
	else:
		_debug("ERROR: Ghost AI scene FAILED to load!")

	# STEP 5: Containers
	players_container = Node3D.new()
	players_container.name = "Players"
	add_child(players_container)

	items_container = Node3D.new()
	items_container.name = "Items"
	add_child(items_container)

	# STEP 6: Generate map
	_show_loading("Building hospital...")
	_debug("Creating map...")
	var map_script = load("res://scripts/map_generator.gd")
	if map_script:
		map_generator = Node3D.new()
		map_generator.name = "Map"
		map_generator.set_script(map_script)
		add_child(map_generator)
		_debug("Map script loaded OK")
	else:
		_debug("ERROR: Map script FAILED!")
		_create_emergency_floor()

	# Wait for map to generate
	await get_tree().process_frame
	await get_tree().process_frame  # Wait 2 frames to be safe
	_debug("Map generated!")

	# STEP 7: Spawn points
	_find_spawn_points()

	# STEP 8: Environment
	_show_loading("Setting up lights...")
	_setup_environment()
	_debug("Environment ready")

	# STEP 9: HUD
	_setup_hud()
	_debug("HUD ready")

	# STEP 10: Touch controls
	_setup_touch_controls()
	_debug("Touch controls ready")

	# STEP 11: Connect game state
	GameManager.game_state_changed.connect(_on_game_state_changed)

	# STEP 12: Start game
	_show_loading("Spawning player...")
	if use_ai_ghost:
		GameManager.set_local_role("human")
		GameManager.start_gameplay()
		_spawn_player(1)
		_spawn_ai_ghost()
		_debug("GAME STARTED!")
		_show_loading("Game started!")

	# Hide loading overlay after a short delay
	get_tree().create_timer(2.0).timeout.connect(func():
		if loading_overlay:
			loading_overlay.visible = false
		# Remove fallback camera if player camera is active
		if fallback_camera:
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				fallback_camera.queue_free()
				fallback_camera = null
				_debug("Player camera active, removed fallback")
	)

	# Hide debug label after 12 seconds
	get_tree().create_timer(12.0).timeout.connect(func():
		if debug_label:
			debug_label.visible = false
	)


func _create_loading_overlay():
	## 2D overlay that shows loading status - ALWAYS visible even if 3D fails
	loading_overlay = ColorRect.new()
	loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_overlay.color = Color(0.02, 0.01, 0.03, 1.0)
	loading_overlay.name = "LoadingOverlay"

	loading_text = Label.new()
	loading_text.set_anchors_preset(Control.PRESET_CENTER)
	loading_text.offset_left = -200
	loading_text.offset_right = 200
	loading_text.offset_top = -50
	loading_text.offset_bottom = 50
	loading_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_text.add_theme_font_size_override("font_size", 28)
	loading_text.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	loading_overlay.add_child(loading_text)

	var canvas = CanvasLayer.new()
	canvas.layer = 200
	canvas.name = "LoadingCanvas"
	add_child(canvas)
	canvas.add_child(loading_overlay)


func _show_loading(text: String):
	if loading_text:
		loading_text.text = text


func _create_fallback_camera():
	## Emergency camera - ensures screen is NEVER completely black
	fallback_camera = Camera3D.new()
	fallback_camera.name = "FallbackCamera"
	fallback_camera.current = true
	fallback_camera.position = Vector3(0, 5, 10)
	fallback_camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	add_child(fallback_camera)
	_debug("Fallback camera created")


func _create_debug_label():
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	debug_label.offset_left = 10
	debug_label.offset_top = 10
	debug_label.offset_right = 600
	debug_label.offset_bottom = 350
	debug_label.add_theme_font_size_override("font_size", 14)
	debug_label.add_theme_color_override("font_color", Color(1, 1, 0))
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.85)
	bg.border_color = Color(1, 0.5, 0)
	bg.border_width_bottom = 2
	bg.border_width_top = 2
	bg.border_width_left = 2
	bg.border_width_right = 2
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	debug_label.add_theme_stylebox_override("normal", bg)

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "DebugCanvas"
	add_child(canvas)
	canvas.add_child(debug_label)


func _debug(msg: String):
	print("[GameScene] " + msg)
	if debug_label:
		debug_label.text += msg + "\n"


func _create_emergency_floor():
	var floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(50, 0.5, 50)
	col.shape = shape
	floor_body.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(50, 0.5, 50)
	mesh_inst.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.15, 0.15)
	mat.roughness = 0.9
	mesh_inst.set_surface_override_material(mat)
	floor_body.add_child(mesh_inst)
	floor_body.position = Vector3(0, -0.25, 0)
	add_child(floor_body)
	_debug("Emergency floor created")


func _find_spawn_points():
	var positions = [Vector3(0, 0, 0), Vector3(-5, 0, 0), Vector3(5, 0, 0)]
	for i in range(positions.size()):
		var s = Marker3D.new()
		s.position = positions[i]
		s.name = "SpawnPoint%d" % i
		add_child(s)
		player_spawn_points.append(s)

	ghost_spawn_point = Marker3D.new()
	ghost_spawn_point.position = Vector3(0, 0, -10)
	ghost_spawn_point.name = "GhostSpawnPoint"
	add_child(ghost_spawn_point)


func _setup_environment():
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.12, 0.18, 1)

	# Ambient light - very bright for mobile visibility
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.65, 0.7, 1)
	env.ambient_light_energy = 6.0

	# Fog - very light
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.18, 0.22, 1)
	env.fog_density = 0.002
	env.fog_depth_begin = 40.0
	env.fog_depth_end = 100.0

	# Tone mapping
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 2.0

	# Disable expensive effects for mobile
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false

	world_env.environment = env
	add_child(world_env)

	# Moonlight
	var dir = DirectionalLight3D.new()
	dir.light_energy = 2.0
	dir.light_color = Color(0.7, 0.7, 0.85)
	dir.rotation = Vector3(deg_to_rad(-70), deg_to_rad(25), 0)
	dir.shadow_enabled = false
	add_child(dir)

	# Fill light from opposite side
	var dir2 = DirectionalLight3D.new()
	dir2.light_energy = 1.0
	dir2.light_color = Color(0.6, 0.6, 0.7)
	dir2.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-135), 0)
	dir2.shadow_enabled = false
	add_child(dir2)


func _setup_hud():
	var hud_script = load("res://scripts/hud.gd")
	if hud_script:
		hud = CanvasLayer.new()
		hud.set_script(hud_script)
		add_child(hud)
		_debug("HUD OK")
	else:
		_debug("ERROR: HUD script failed!")


func _setup_touch_controls():
	var tc_script = load("res://scripts/touch_controls.gd")
	if tc_script:
		touch_controls = CanvasLayer.new()
		touch_controls.set_script(tc_script)
		add_child(touch_controls)
		_debug("Touch controls OK")
	else:
		_debug("ERROR: Touch controls script failed!")


func _on_game_state_changed(new_state):
	if new_state == GameManager.GameState.GAME_OVER:
		_show_game_over("ghost")
	elif new_state == GameManager.GameState.ESCAPED:
		_show_game_over("human")


func _spawn_player(peer_id: int):
	if not player_scene:
		_debug("ERROR: No player scene!")
		return

	var player = player_scene.instantiate()
	if not player:
		_debug("ERROR: Player instantiate failed!")
		return

	player.name = "Player_%d" % peer_id
	if player_spawn_points.size() > 0:
		player.global_position = player_spawn_points[0].global_position
		player.position.y = 0.5
	players_container.add_child(player)

	# Check if player script is working
	if player.has_method("setup_as_local"):
		player.setup_as_local(peer_id)
		_debug("Player spawned with script OK")
	else:
		_debug("WARNING: Player has no setup_as_local method!")
		# Manually set up camera if script didn't work
		var cam = player.get_node_or_null("Head/Camera3D")
		if cam:
			cam.current = true
			_debug("Manually activated player camera")
		else:
			_debug("ERROR: No camera found on player!")

	player.add_to_group("player")
	_add_player_body(player)


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

	var head_visual = MeshInstance3D.new()
	var head_mesh_res = SphereMesh.new()
	head_mesh_res.radius = 0.18
	head_mesh_res.height = 0.3
	head_visual.mesh = head_mesh_res
	head_visual.position = Vector3(0, 1.55, 0)
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.7, 0.6, 0.5)
	head_mat.roughness = 0.8
	head_visual.set_surface_override_material(head_mat)
	player.add_child(head_visual)


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
		ghost.position.y = 0.5
	players_container.add_child(ghost)
	_debug("Ghost spawned OK")


func _show_game_over(winner: String):
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.3, 0, 0, 0.85) if winner == "ghost" else Color(0, 0.25, 0, 0.85)
	get_tree().root.add_child(overlay)

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
	get_tree().root.add_child(label)

	var sub_label = Label.new()
	sub_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub_label.offset_top = 60
	sub_label.add_theme_font_size_override("font_size", 20)
	if winner == "ghost":
		sub_label.text = "Better luck next time..."
		sub_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))
	else:
		sub_label.text = "You found all the keys and escaped!"
		sub_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
	get_tree().root.add_child(sub_label)

	var btn = Button.new()
	btn.text = "BACK TO MENU"
	btn.position = Vector2(get_viewport().size.x / 2 - 90, get_viewport().size.y / 2 + 80)
	btn.size = Vector2(180, 45)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.04, 0.04, 0.9)
	btn_style.border_color = Color(0.6, 0.15, 0.1)
	btn_style.border_width_bottom = 2
	btn_style.border_width_top = 2
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.corner_radius_top_left = 5
	btn_style.corner_radius_top_right = 5
	btn_style.corner_radius_bottom_left = 5
	btn_style.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
	btn.pressed.connect(func(): GameManager.return_to_menu())
	get_tree().root.add_child(btn)
