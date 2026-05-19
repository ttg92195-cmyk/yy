extends Node3D
## GameScene - ULTRA LIGHTWEIGHT for mobile
## NO NavigationMesh baking (was causing freeze/crash)
## Ghost moves directly to target instead
## NO AudioStreamGenerator (was causing crash)
## Minimal environment setup

@export var use_ai_ghost: bool = true

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const GHOST_PLAYER_SCENE = preload("res://scenes/ghost_player.tscn")
const GHOST_AI_SCENE = preload("res://scenes/ghost_ai.tscn")

var player_spawn_points: Array[Marker3D] = []
var ghost_spawn_point: Marker3D = null
var map_generator: Node3D = null
var players_container: Node3D = null
var items_container: Node3D = null
var hud: CanvasLayer = null
var touch_controls: CanvasLayer = null


func _ready():
	players_container = Node3D.new()
	players_container.name = "Players"
	add_child(players_container)

	items_container = Node3D.new()
	items_container.name = "Items"
	add_child(items_container)

	# Generate map
	map_generator = Node3D.new()
	map_generator.name = "Map"
	map_generator.set_script(load("res://scripts/map_generator.gd"))
	add_child(map_generator)

	await get_tree().process_frame

	# NO NavigationMesh baking - this was causing the freeze!
	# Ghost uses direct movement instead of nav mesh pathfinding

	# Spawn points
	_find_spawn_points()

	# Simple environment
	_setup_environment()

	# HUD
	_setup_hud()

	# Touch controls (always create)
	_setup_touch_controls()

	# Connect game state
	GameManager.game_state_changed.connect(_on_game_state_changed)

	# Start game
	if use_ai_ghost:
		GameManager.set_local_role("human")
		GameManager.start_gameplay()
		_spawn_player(1)
		_spawn_ai_ghost()


func _find_spawn_points():
	var positions = [Vector3(0,0,0), Vector3(5,0,0), Vector3(-5,0,0)]
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

	# Bright enough to see on mobile
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.17, 0.22, 1)
	env.ambient_light_energy = 2.0

	# Light fog
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.08, 1)
	env.fog_density = 0.012
	env.fog_depth_begin = 8.0
	env.fog_depth_end = 35.0

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.3

	# NO glow, NO SSAO
	env.glow_enabled = false
	env.ssao_enabled = false

	world_env.environment = env
	add_child(world_env)

	# Single moonlight
	var dir = DirectionalLight3D.new()
	dir.light_energy = 0.5
	dir.light_color = Color(0.4, 0.4, 0.6)
	dir.rotation = Vector3(deg_to_rad(-60), deg_to_rad(30), 0)
	dir.shadow_enabled = false
	add_child(dir)


func _setup_hud():
	hud = CanvasLayer.new()
	hud.set_script(load("res://scripts/hud.gd"))
	add_child(hud)


func _setup_touch_controls():
	touch_controls = CanvasLayer.new()
	touch_controls.set_script(load("res://scripts/touch_controls.gd"))
	add_child(touch_controls)


func _on_game_state_changed(new_state):
	if new_state == GameManager.GameState.GAME_OVER:
		_show_game_over("ghost")
	elif new_state == GameManager.GameState.ESCAPED:
		_show_game_over("human")


func _spawn_player(peer_id: int):
	var player = PLAYER_SCENE.instantiate()
	player.name = "Player_%d" % peer_id
	if player_spawn_points.size() > 0:
		player.global_position = player_spawn_points[0].global_position
		player.position.y = 0.5
	players_container.add_child(player)
	player.setup_as_local(peer_id)
	player.add_to_group("player")


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
	overlay.color = Color(0.3, 0, 0, 0.8) if winner == "ghost" else Color(0, 0.3, 0, 0.8)
	get_tree().root.add_child(overlay)

	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 42)
	if winner == "ghost":
		label.text = "THE GHOST WINS!"
		label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	else:
		label.text = "YOU ESCAPED!"
		label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))
	get_tree().root.add_child(label)

	var btn = Button.new()
	btn.text = "Menu"
	btn.position = Vector2(get_viewport().size.x / 2 - 80, get_viewport().size.y / 2 + 70)
	btn.size = Vector2(160, 45)
	btn.pressed.connect(func(): GameManager.return_to_menu())
	get_tree().root.add_child(btn)
