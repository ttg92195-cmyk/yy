extends Node3D
## GameScene - Main game scene controller
## Manages spawning players, ghost, items, and game flow

@export var use_ai_ghost: bool = false

# Scene references
const PLAYER_SCENE = preload("res://scenes/player.tscn")
const GHOST_PLAYER_SCENE = preload("res://scenes/ghost_player.tscn")
const GHOST_AI_SCENE = preload("res://scenes/ghost_ai.tscn")

# Spawn points
@onready var player_spawn_points: Array[Marker3D] = []
@onready var ghost_spawn_point: Marker3D = $GhostSpawnPoint

# Game objects
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var items_container: Node3D = $Items
@onready var escape_door: Node3D = $EscapeDoor

# HUD
@onready var hud: CanvasLayer = $HUD


func _ready():
	# Find all spawn points
	for child in $SpawnPoints.get_children():
		if child is Marker3D:
			player_spawn_points.append(child)

	# Connect game state signal
	GameManager.game_state_changed.connect(_on_game_state_changed)

	# Wait for navigation to bake
	if nav_region and not nav_region.is_baked():
		nav_region.bake_navigation_mesh()

	# If this is a single-player/AI ghost game
	if use_ai_ghost or multiplayer.is_server() == false:
		_setup_local_game()


func _setup_local_game():
	"""Setup a local game (for testing or AI ghost mode)"""
	# Spawn local player
	_spawn_player(multiplayer.get_unique_id())

	# Spawn AI ghost if needed
	if use_ai_ghost:
		_spawn_ai_ghost()


func _on_game_state_changed(new_state):
	match new_state:
		GameManager.GameState.PLAYING:
			_on_game_started()
		GameManager.GameState.GAME_OVER:
			_show_game_over("ghost")
		GameManager.GameState.ESCAPED:
			_show_game_over("human")


func _on_game_started():
	"""Called when the game actually starts playing"""
	print("[GameScene] Game started!")

	# Spawn players based on network
	if multiplayer.is_server():
		# Server spawns all players
		for pid in NetworkManager.players:
			var info = NetworkManager.players[pid]
			if info.role == "ghost":
				_spawn_ghost_player(pid)
			else:
				_spawn_player(pid)

		# If AI ghost mode, spawn AI ghost
		if use_ai_ghost:
			_spawn_ai_ghost()


func _spawn_player(peer_id: int):
	"""Spawn a human player"""
	var player = PLAYER_SCENE.instantiate()
	player.name = "Player_%d" % peer_id

	# Set spawn position
	if player_spawn_points.size() > 0:
		var spawn_index = (players_count()) % player_spawn_points.size()
		player.global_position = player_spawn_points[spawn_index].global_position

	# Add to scene
	$Players.add_child(player)

	# Setup as local or remote
	if peer_id == multiplayer.get_unique_id():
		player.setup_as_local(peer_id)
	else:
		player.setup_as_remote(peer_id)

	player.add_to_group("player")


func _spawn_ghost_player(peer_id: int):
	"""Spawn a player-controlled ghost"""
	var ghost = GHOST_PLAYER_SCENE.instantiate()
	ghost.name = "GhostPlayer_%d" % peer_id

	# Set spawn position
	if ghost_spawn_point:
		ghost.global_position = ghost_spawn_point.global_position

	$Players.add_child(ghost)

	# Setup
	if peer_id == multiplayer.get_unique_id():
		ghost.setup_as_local(peer_id)
	else:
		ghost.setup_as_remote(peer_id)


func _spawn_ai_ghost():
	"""Spawn an AI-controlled ghost"""
	var ghost = GHOST_AI_SCENE.instantiate()
	ghost.name = "GhostAI"

	if ghost_spawn_point:
		ghost.global_position = ghost_spawn_point.global_position

	$Players.add_child(ghost)


func players_count() -> int:
	if $Players:
		return $Players.get_child_count()
	return 0


func _show_game_over(winner: String):
	"""Show game over screen"""
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

	# Unlock mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
