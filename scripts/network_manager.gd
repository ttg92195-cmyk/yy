extends Node
## NetworkManager - Handles all multiplayer networking using Godot's built-in ENetMultiplayerPeer
## Supports: Host game, Join game, Role assignment (Ghost/Human)

signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal connection_failed()
signal server_disconnected()

const PORT = 7777
const MAX_PLAYERS = 5  ## 4 Humans + 1 Ghost

var peer: ENetMultiplayerPeer
var players: Dictionary = {}  ## peer_id -> player_info
var is_host: bool = false

## Player info structure
class PlayerInfo:
	var peer_id: int
	var player_name: String
	var role: String  ## "human" or "ghost"
	var is_alive: bool = true
	var ready: bool = false

	func to_dict() -> Dictionary:
		return {
			"peer_id": peer_id,
			"player_name": player_name,
			"role": role,
			"is_alive": is_alive,
			"ready": ready
		}

	static func from_dict(data: Dictionary) -> PlayerInfo:
		var info = PlayerInfo.new()
		info.peer_id = data.get("peer_id", 1)
		info.player_name = data.get("player_name", "Player")
		info.role = data.get("role", "human")
		info.is_alive = data.get("is_alive", true)
		info.ready = data.get("ready", false)
		return info


func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Host a game server
func host_game(player_name: String) -> bool:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		push_error("Failed to create server: %s" % error)
		return false

	multiplayer.multiplayer_peer = peer
	is_host = true

	# Register host as a player
	var host_info = PlayerInfo.new()
	host_info.peer_id = 1
	host_info.player_name = player_name
	host_info.role = "human"
	host_info.ready = false
	players[1] = host_info

	print("[Network] Server started on port %d" % PORT)
	return true


## Join a game server
func join_game(address: String, player_name: String) -> bool:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error != OK:
		push_error("Failed to create client: %s" % error)
		return false

	multiplayer.multiplayer_peer = peer
	is_host = false

	# Store local player info temporarily
	var join_info = PlayerInfo.new()
	join_info.peer_id = multiplayer.get_unique_id()
	join_info.player_name = player_name
	join_info.role = "human"
	join_info.ready = false

	print("[Network] Connecting to %s:%d..." % [address, PORT])
	return true


## Disconnect from the current game
func disconnect_game():
	if peer:
		peer.close()
	players.clear()
	is_host = false
	print("[Network] Disconnected from game")


## Called when a new peer connects
func _on_peer_connected(peer_id: int):
	print("[Network] Peer connected: %d" % peer_id)
	# Request player info from the new peer
	if multiplayer.is_server():
		_send_player_info.rpc_id(peer_id, _get_local_player_info())


## Called when a peer disconnects
func _on_peer_disconnected(peer_id: int):
	print("[Network] Peer disconnected: %d" % peer_id)
	players.erase(peer_id)
	player_disconnected.emit(peer_id)

	if multiplayer.is_server():
		GameManager.on_player_left(peer_id)


## Called when successfully connected to server
func _on_connected_to_server():
	print("[Network] Connected to server!")
	# Send our info to the server
	_register_player.rpc(_get_local_player_info())


## Called when connection fails
func _on_connection_failed():
	print("[Network] Connection failed!")
	connection_failed.emit()


## Called when server disconnects
func _on_server_disconnected():
	print("[Network] Server disconnected!")
	server_disconnected.emit()
	players.clear()


## Get local player info as dictionary
func _get_local_player_info() -> Dictionary:
	var info = PlayerInfo.new()
	info.peer_id = multiplayer.get_unique_id()
	info.player_name = "Player_%d" % info.peer_id
	info.role = "human"
	info.ready = false
	return info.to_dict()


## Register a player on the server (server-side)
@rpc("any_peer", "call_local")
func _register_player(player_data: Dictionary):
	var info = PlayerInfo.from_dict(player_data)
	info.peer_id = multiplayer.get_remote_sender_id()
	players[info.peer_id] = info
	player_connected.emit(info.peer_id, player_data)

	print("[Network] Player registered: %s (ID: %d, Role: %s)" % [info.player_name, info.peer_id, info.role])

	# Sync all existing players to the new player
	if multiplayer.is_server():
		_sync_player_list.rpc_id(info.peer_id, _get_all_players_dict())


## Send player info to a specific peer
@rpc("authority", "call_local")
func _send_player_info(player_data: Dictionary):
	var info = PlayerInfo.from_dict(player_data)
	players[info.peer_id] = info
	player_connected.emit(info.peer_id, player_data)


## Sync the full player list to a peer
@rpc("authority")
func _sync_player_list(all_players: Dictionary):
	players.clear()
	for peer_id_str in all_players:
		var pid = int(peer_id_str)
		players[pid] = PlayerInfo.from_dict(all_players[peer_id_str])
	print("[Network] Player list synced: %d players" % players.size())


## Get all players as a dictionary
func _get_all_players_dict() -> Dictionary:
	var result = {}
	for pid in players:
		result[str(pid)] = players[pid].to_dict()
	return result


## Assign ghost role (server only)
func assign_ghost_role(peer_id: int):
	if not multiplayer.is_server():
		return
	if players.has(peer_id):
		# Reset all players to human first
		for pid in players:
			players[pid].role = "human"
		# Assign ghost to specified player
		players[peer_id].role = "ghost"
		_notify_role_assignment.rpc(peer_id, "ghost")
		print("[Network] Ghost role assigned to peer %d" % peer_id)


## Assign ghost to AI (no real player controls ghost)
func assign_ghost_to_ai():
	if not multiplayer.is_server():
		return
	# All players are humans, ghost will be AI controlled
	for pid in players:
		players[pid].role = "human"
	_notify_role_assignment.rpc(-1, "ai_ghost")
	print("[Network] Ghost assigned to AI")


## Notify all clients about role assignment
@rpc("authority", "call_local")
func _notify_role_assignment(peer_id: int, role: String):
	if peer_id == multiplayer.get_unique_id():
		GameManager.set_local_role(role)
	elif role == "ai_ghost":
		GameManager.set_local_role("human")
	print("[Network] Role notification - Peer: %d, Role: %s" % [peer_id, role])


## Get number of connected players
func get_player_count() -> int:
	return players.size()


## Check if server is active
func is_server_active() -> bool:
	return peer != null and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


## Start the game (server only) - assigns roles and loads game scene
func start_game():
	if not multiplayer.is_server():
		return

	# Randomly assign ghost role to one player
	var player_ids = players.keys()
	if player_ids.size() > 0:
		var ghost_peer = player_ids[randi() % player_ids.size()]
		assign_ghost_role(ghost_peer)

	# Notify all clients to start the game
	_on_game_start.rpc()


## Start game with AI ghost
func start_game_ai_ghost():
	if not multiplayer.is_server():
		return
	assign_ghost_to_ai()
	_on_game_start.rpc()


## Notify all clients that game has started
@rpc("authority", "call_local")
func _on_game_start():
	print("[Network] Game starting!")
	GameManager.start_gameplay()
