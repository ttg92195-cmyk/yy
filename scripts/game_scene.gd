extends Node3D
## GameScene - Mobile-optimized game scene
## Robust version with error handling and debug output
## NO NavigationMesh baking (causes freeze)
## NO AudioStreamGenerator (causes crash)

@export var use_ai_ghost: bool = true

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const GHOST_AI_SCENE = preload("res://scenes/ghost_ai.tscn")

var player_spawn_points: Array[Marker3D] = []
var ghost_spawn_point: Marker3D = null
var map_generator: Node3D = null
var players_container: Node3D = null
var items_container: Node3D = null
var hud: CanvasLayer = null
var touch_controls: CanvasLayer = null
var debug_label: Label = null


func _ready():
	# Debug label - always visible so we can see what's happening
	_create_debug_label()
	_debug("Game loading...")

	# Containers
	players_container = Node3D.new()
	players_container.name = "Players"
	add_child(players_container)

	items_container = Node3D.new()
	items_container.name = "Items"
	add_child(items_container)

	_debug("Creating map...")
	# Generate hospital map
	var map_script = load("res://scripts/map_generator.gd")
	if map_script:
		map_generator = Node3D.new()
		map_generator.name = "Map"
		map_generator.set_script(map_script)
		add_child(map_generator)
		_debug("Map script loaded OK")
	else:
		_debug("ERROR: Map script failed to load!")
		# Create emergency floor so player doesn't fall
		_create_emergency_floor()

	# Wait for map to generate
	await get_tree().process_frame
	_debug("Map generated, setting up...")

	# Spawn points
	_find_spawn_points()

	# Environment - MUST be bright for mobile
	_setup_environment()
	_debug("Environment ready")

	# HUD
	_setup_hud()
	_debug("HUD ready")

	# Touch controls (always create for mobile)
	_setup_touch_controls()
	_debug("Touch controls ready")

	# Connect game state
	GameManager.game_state_changed.connect(_on_game_state_changed)

	# Start game with AI ghost
	if use_ai_ghost:
		GameManager.set_local_role("human")
		GameManager.start_gameplay()
		_spawn_player(1)
		_spawn_ai_ghost()
		_debug("Game started! Player and ghost spawned.")

	# Hide debug label after 5 seconds
	get_tree().create_timer(5.0).timeout.connect(func():
		if debug_label:
			debug_label.visible = false
	)


func _create_debug_label():
	## Create a debug label that shows game state
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	debug_label.offset_left = 10
	debug_label.offset_top = 10
	debug_label.offset_right = 400
	debug_label.offset_bottom = 200
	debug_label.add_theme_font_size_override("font_size", 14)
	debug_label.add_theme_color_override("font_color", Color(1, 1, 0))
	# Black background for readability
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.7)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	debug_label.add_theme_stylebox_override("normal", bg)

	# Add to a CanvasLayer so it's always on top
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "DebugCanvas"
	add_child(canvas)
	canvas.add_child(debug_label)


func _debug(msg: String):
	## Print debug message to both console and screen
	print("[GameScene] " + msg)
	if debug_label:
		debug_label.text += msg + "\n"


func _create_emergency_floor():
	## Create a simple visible floor if map generation fails
	var floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(50, 0.5, 50)
	col.shape = shape
	floor_body.add_child(col)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(50, 0.5, 50)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.1, 0.1)  # Red tint so user sees it
	mat.roughness = 0.9
	mesh.set_surface_override_material(mat)
	floor_body.add_child(mesh)
	floor_body.position = Vector3(0, -0.25, 0)
	add_child(floor_body)


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
	env.background_color = Color(0.02, 0.02, 0.04, 1)

	# Ambient light - VERY bright for mobile visibility
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.40, 0.45, 1)
	env.ambient_light_energy = 5.0

	# Fog - very light, just for atmosphere
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.07, 0.10, 1)
	env.fog_density = 0.003
	env.fog_depth_begin = 20.0
	env.fog_depth_end = 60.0

	# Tone mapping - high exposure for mobile
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 2.0

	# Disable expensive effects for mobile
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false

	world_env.environment = env
	add_child(world_env)

	# Moonlight - bright for mobile
	var dir = DirectionalLight3D.new()
	dir.light_energy = 1.0
	dir.light_color = Color(0.5, 0.5, 0.7)
	dir.rotation = Vector3(deg_to_rad(-70), deg_to_rad(25), 0)
	dir.shadow_enabled = false
	add_child(dir)


func _setup_hud():
	var hud_script = load("res://scripts/hud.gd")
	if hud_script:
		hud = CanvasLayer.new()
		hud.set_script(hud_script)
		add_child(hud)
	else:
		_debug("ERROR: HUD script failed to load!")


func _setup_touch_controls():
	var tc_script = load("res://scripts/touch_controls.gd")
	if tc_script:
		touch_controls = CanvasLayer.new()
		touch_controls.set_script(tc_script)
		add_child(touch_controls)
	else:
		_debug("ERROR: Touch controls script failed to load!")


func _on_game_state_changed(new_state):
	if new_state == GameManager.GameState.GAME_OVER:
		_show_game_over("ghost")
	elif new_state == GameManager.GameState.ESCAPED:
		_show_game_over("human")


func _spawn_player(peer_id: int):
	var player = PLAYER_SCENE.instantiate()
	if not player:
		_debug("ERROR: Player scene failed to instantiate!")
		return

	player.name = "Player_%d" % peer_id
	if player_spawn_points.size() > 0:
		player.global_position = player_spawn_points[0].global_position
		player.position.y = 0.5
	players_container.add_child(player)

	# Setup as local player
	if player.has_method("setup_as_local"):
		player.setup_as_local(peer_id)
		_debug("Player setup OK")
	else:
		_debug("ERROR: Player missing setup_as_local method!")

	player.add_to_group("player")

	# Add visible body mesh
	_add_player_body(player)


func _add_player_body(player: CharacterBody3D):
	## Add a simple 3D body mesh to the player
	var body_node = player.get_node_or_null("BodyMesh")
	if body_node and body_node is MeshInstance3D:
		var capsule = CapsuleMesh.new()
		capsule.radius = 0.3
		capsule.height = 1.4
		body_node.mesh = capsule
		var body_mat = StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.25, 0.22, 0.2)
		body_mat.roughness = 0.9
		body_node.set_surface_override_material(body_mat)

	# Add head sphere
	var head_visual = MeshInstance3D.new()
	var head_mesh_res = SphereMesh.new()
	head_mesh_res.radius = 0.18
	head_mesh_res.height = 0.3
	head_visual.mesh = head_mesh_res
	head_visual.position = Vector3(0, 1.55, 0)
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.6, 0.5, 0.45)
	head_mat.roughness = 0.8
	head_visual.set_surface_override_material(head_mat)
	player.add_child(head_visual)


func _spawn_ai_ghost():
	var ghost = GHOST_AI_SCENE.instantiate()
	if not ghost:
		_debug("ERROR: Ghost scene failed to instantiate!")
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
