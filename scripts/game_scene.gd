extends Node3D
## GameScene - MOBILE-OPTIMIZED game scene controller
## Optimizations:
## - Simpler environment (no glow, lighter fog)
## - Only 1 directional light (removed fill light)
## - Smaller nav mesh
## - Touch controls always created (not just on mobile)

@export var use_ai_ghost: bool = true

# Scene references
const PLAYER_SCENE = preload("res://scenes/player.tscn")
const GHOST_PLAYER_SCENE = preload("res://scenes/ghost_player.tscn")
const GHOST_AI_SCENE = preload("res://scenes/ghost_ai.tscn")

# Spawn points
var player_spawn_points: Array[Marker3D] = []
var ghost_spawn_point: Marker3D = null

# Game objects
var nav_region: NavigationRegion3D = null
var map_generator: Node3D = null
var players_container: Node3D = null
var items_container: Node3D = null

# HUD & Controls
var hud: CanvasLayer = null
var touch_controls: CanvasLayer = null


func _ready():
	# Create containers
	players_container = Node3D.new()
	players_container.name = "Players"
	add_child(players_container)

	items_container = Node3D.new()
	items_container.name = "Items"
	add_child(items_container)

	# Generate the map
	map_generator = Node3D.new()
	map_generator.name = "Map"
	map_generator.set_script(load("res://scripts/map_generator.gd"))
	add_child(map_generator)

	# Wait a frame for map to generate
	await get_tree().process_frame

	# Setup navigation region
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	add_child(nav_region)

	_create_nav_mesh()

	# Find spawn points
	_find_spawn_points()

	# Setup environment (optimized for mobile)
	_setup_environment()

	# Setup HUD
	_setup_hud()

	# Setup touch controls (always create - lightweight)
	_setup_touch_controls()

	# Connect game state signal
	GameManager.game_state_changed.connect(_on_game_state_changed)

	# Start game in AI ghost mode
	if use_ai_ghost:
		GameManager.set_local_role("human")
		GameManager.start_gameplay()
		_spawn_player(1)
		_spawn_ai_ghost()


func _create_nav_mesh():
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_max_climb = 0.4

	# Smaller walkable area for 30x30 map
	var vertices = PackedVector3Array([
		Vector3(-14, 0.1, -14),
		Vector3(14, 0.1, -14),
		Vector3(14, 0.1, 14),
		Vector3(-14, 0.1, 14),
	])
	nav_mesh.vertices = vertices

	var polygons = PackedInt32Array([0, 1, 2, 3])
	nav_mesh.add_polygon(polygons)

	nav_region.navigation_mesh = nav_mesh
	nav_region.bake_navigation_mesh()


func _find_spawn_points():
	var spawn = Marker3D.new()
	spawn.position = Vector3(0, 0, 0)
	spawn.name = "SpawnPoint0"
	add_child(spawn)
	player_spawn_points.append(spawn)

	var spawn1 = Marker3D.new()
	spawn1.position = Vector3(5, 0, 0)
	spawn1.name = "SpawnPoint1"
	add_child(spawn1)
	player_spawn_points.append(spawn1)

	var spawn2 = Marker3D.new()
	spawn2.position = Vector3(-5, 0, 0)
	spawn2.name = "SpawnPoint2"
	add_child(spawn2)
	player_spawn_points.append(spawn2)

	# Ghost spawn (far from players)
	ghost_spawn_point = Marker3D.new()
	ghost_spawn_point.position = Vector3(0, 0, -12)
	ghost_spawn_point.name = "GhostSpawnPoint"
	add_child(ghost_spawn_point)


func _setup_environment():
	## MOBILE-OPTIMIZED environment
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"

	var env = Environment.new()

	# Background
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04, 1)

	# Ambient light - bright enough to see
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.15, 0.2, 1)
	env.ambient_light_energy = 1.5

	# Fog - LIGHT for visibility
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.08, 1)
	env.fog_light_energy = 0.6
	env.fog_density = 0.01
	env.fog_depth_begin = 10.0
	env.fog_depth_end = 40.0

	# Tone mapping
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.3
	env.tonemap_white = 4.0

	# NO glow (saves GPU on mobile)
	env.glow_enabled = false

	# NO SSAO
	env.ssao_enabled = false

	world_env.environment = env
	add_child(world_env)

	# Single moonlight (removed fill light)
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "MoonLight"
	dir_light.light_energy = 0.5
	dir_light.light_color = Color(0.4, 0.4, 0.6)
	dir_light.rotation = Vector3(deg_to_rad(-60), deg_to_rad(30), 0)
	dir_light.shadow_enabled = false
	add_child(dir_light)


func _setup_hud():
	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))
	add_child(hud)


func _setup_touch_controls():
	## Always create touch controls (lightweight when not touching)
	touch_controls = CanvasLayer.new()
	touch_controls.name = "TouchControls"
	touch_controls.set_script(load("res://scripts/touch_controls.gd"))
	add_child(touch_controls)


func _on_game_state_changed(new_state):
	match new_state:
		GameManager.GameState.PLAYING:
			_on_game_started()
		GameManager.GameState.GAME_OVER:
			_show_game_over("ghost")
		GameManager.GameState.ESCAPED:
			_show_game_over("human")


func _on_game_started():
	print("[GameScene] Game started!")


func _spawn_player(peer_id: int):
	var player = PLAYER_SCENE.instantiate()
	player.name = "Player_%d" % peer_id

	if player_spawn_points.size() > 0:
		var spawn_index = players_container.get_child_count() % player_spawn_points.size()
		player.global_position = player_spawn_points[spawn_index].global_position
		player.position.y = 0.5

	players_container.add_child(player)
	player.setup_as_local(peer_id)
	player.add_to_group("player")


func _spawn_ghost_player(peer_id: int):
	var ghost = GHOST_PLAYER_SCENE.instantiate()
	ghost.name = "GhostPlayer_%d" % peer_id

	if ghost_spawn_point:
		ghost.global_position = ghost_spawn_point.global_position
		ghost.position.y = 0.5

	players_container.add_child(ghost)

	if peer_id == multiplayer.get_unique_id():
		ghost.setup_as_local(peer_id)
	else:
		ghost.setup_as_remote(peer_id)


func _spawn_ai_ghost():
	var ghost = GHOST_AI_SCENE.instantiate()
	ghost.name = "GhostAI"

	if ghost_spawn_point:
		ghost.global_position = ghost_spawn_point.global_position
		ghost.position.y = 0.5

	players_container.add_child(ghost)


func _show_game_over(winner: String):
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	if winner == "ghost":
		overlay.color = Color(0.3, 0, 0, 0.8)
	else:
		overlay.color = Color(0, 0.3, 0, 0.8)

	get_tree().root.add_child(overlay)

	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)

	if winner == "ghost":
		label.text = "THE GHOST WINS!"
		label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	else:
		label.text = "HUMANS ESCAPED!"
		label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))

	get_tree().root.add_child(label)

	# Return to menu button
	var button = Button.new()
	button.text = "Return to Menu"
	button.position = Vector2(get_viewport().size.x / 2 - 100, get_viewport().size.y / 2 + 80)
	button.size = Vector2(200, 50)
	button.pressed.connect(func():
		GameManager.return_to_menu()
	)
	get_tree().root.add_child(button)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
