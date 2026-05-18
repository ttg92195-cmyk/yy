extends Node3D
## GameScene - Main game scene controller
## Manages spawning players, ghost, items, map generation, and game flow

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
var escape_door_node: Node3D = null

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

	# Create a simple navigation mesh
	_create_nav_mesh()

	# Find spawn points from map
	_find_spawn_points()

	# Setup World Environment - BRIGHT ENOUGH TO SEE ON MOBILE
	_setup_environment()

	# Setup HUD
	_setup_hud()

	# Setup touch controls for mobile
	_setup_touch_controls()

	# Connect game state signal
	GameManager.game_state_changed.connect(_on_game_state_changed)

	# Start the game immediately for AI ghost mode
	if use_ai_ghost:
		GameManager.set_local_role("human")
		GameManager.start_gameplay()
		_spawn_player(1)
		_spawn_ai_ghost()


func _create_nav_mesh():
	## Create a basic navigation mesh for the floor area
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_max_climb = 0.4

	# Define walkable area
	var vertices = PackedVector3Array([
		Vector3(-24, 0.1, -24),
		Vector3(24, 0.1, -24),
		Vector3(24, 0.1, 24),
		Vector3(-24, 0.1, 24),
	])
	nav_mesh.vertices = vertices

	var polygons = PackedInt32Array([0, 1, 2, 3])
	nav_mesh.add_polygon(polygons)

	nav_region.navigation_mesh = nav_mesh
	nav_region.bake_navigation_mesh()


func _find_spawn_points():
	## Create spawn points
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

	var spawn3 = Marker3D.new()
	spawn3.position = Vector3(0, 0, 5)
	spawn3.name = "SpawnPoint3"
	add_child(spawn3)
	player_spawn_points.append(spawn3)

	# Ghost spawn point (far from players)
	ghost_spawn_point = Marker3D.new()
	ghost_spawn_point.position = Vector3(0, 0, -18)
	ghost_spawn_point.name = "GhostSpawnPoint"
	add_child(ghost_spawn_point)


func _setup_environment():
	## Setup the horror world environment - VISIBLE on mobile!
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"

	var env = Environment.new()

	# Background - dark but not pure black
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04, 1)

	# Ambient light - CRITICAL: Must be bright enough to see walls/floor
	# Use SKY_COLOR source for better results on mobile
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.13, 0.18, 1)
	env.ambient_light_energy = 1.5

	# Fog - LIGHT fog for horror atmosphere but still visible
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.08, 1)
	env.fog_light_energy = 0.8
	env.fog_density = 0.008
	env.fog_depth_begin = 15.0
	env.fog_depth_end = 60.0

	# Tone mapping - increase exposure for better visibility
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.5
	env.tonemap_white = 6.0

	# Glow for flashlight effects and item glows
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 0.8
	env.glow_bloom = 0.3
	env.glow_blend_mode = 0

	# SSAO disabled for mobile performance
	env.ssao_enabled = false

	world_env.environment = env
	add_child(world_env)

	# Moonlight - brighter so players can see
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "MoonLight"
	dir_light.light_energy = 0.4
	dir_light.light_color = Color(0.4, 0.4, 0.6)
	dir_light.rotation = Vector3(deg_to_rad(-60), deg_to_rad(30), 0)
	dir_light.shadow_enabled = false  # Performance on mobile
	add_child(dir_light)

	# Add a secondary fill light from below for better visibility
	var fill_light = DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_energy = 0.15
	fill_light.light_color = Color(0.2, 0.15, 0.25)
	fill_light.rotation = Vector3(deg_to_rad(45), deg_to_rad(-30), 0)
	fill_light.shadow_enabled = false
	add_child(fill_light)


func _setup_hud():
	## Setup the game HUD
	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))
	add_child(hud)


func _setup_touch_controls():
	## Setup touch controls for mobile - ALWAYS create on Android
	var is_mobile = OS.has_feature("android") or OS.has_feature("ios")
	if is_mobile:
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

	# Set spawn position
	if player_spawn_points.size() > 0:
		var spawn_index = players_container.get_child_count() % player_spawn_points.size()
		player.global_position = player_spawn_points[spawn_index].global_position
		# Slightly above ground
		player.position.y = 0.5

	players_container.add_child(player)

	# Setup as local player
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
	# Create game over overlay
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
	label.add_theme_font_size_override("font_size", 64)

	if winner == "ghost":
		label.text = "THE GHOST WINS!\nAll humans have been caught."
		label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	else:
		label.text = "HUMANS ESCAPED!\nYou survived the ghost."
		label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))

	get_tree().root.add_child(label)

	# Return to menu button
	var button = Button.new()
	button.text = "Return to Menu"
	button.position = Vector2(get_viewport().size.x / 2 - 100, get_viewport().size.y / 2 + 100)
	button.size = Vector2(200, 50)
	button.pressed.connect(func():
		GameManager.return_to_menu()
	)
	get_tree().root.add_child(button)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
