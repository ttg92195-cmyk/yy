extends Node
## GameManager - Global game state management (AutoLoad singleton)
## V7 - FIXED for single-player AI Ghost mode
## Key fixes:
## - start_gameplay_singleplayer() properly sets alive_humans=1
## - on_player_caught/on_item_collected work WITHOUT multiplayer
## - return_to_menu() safe when no multiplayer peer

enum GameState {
	MENU,
	LOBBY,
	PLAYING,
	CAUGHT,
	ESCAPED,
	GAME_OVER
}

signal game_state_changed(new_state: GameState)
signal player_caught(peer_id: int)
signal player_escaped(peer_id: int)
signal item_collected(item_name: String, peer_id: int)
signal all_items_collected()
signal ghost_victory()
signal human_victory()

var current_state: GameState = GameState.MENU
var local_role: String = "human"
var is_ghost_player: bool = false

## Items needed to escape
var required_items: Dictionary = {
	"key_red": false,
	"key_blue": false,
	"key_green": false,
	"car_key": false
}
var items_collected_count: int = 0
var total_items_required: int = 4

## Player stats
var alive_humans: int = 0
var total_humans: int = 0
var escape_door_unlocked: bool = false

## Game settings
var ghost_speed: float = 4.5
var human_walk_speed: float = 3.5
var human_sprint_speed: float = 6.0
var flashlight_battery: float = 100.0
var flashlight_drain_rate: float = 2.0
var flashlight_recharge_rate: float = 5.0
var ghost_catch_distance: float = 2.0
var ghost_hunt_interval_min: float = 30.0
var ghost_hunt_interval_max: float = 60.0
var ghost_hunt_duration: float = 20.0

## Single player mode flag
var is_single_player: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_state(new_state: GameState):
	if current_state == new_state:
		return
	current_state = new_state
	game_state_changed.emit(new_state)
	print("[GameManager] State changed to: %s" % GameState.keys()[new_state])


func set_local_role(role: String):
	local_role = role
	is_ghost_player = (role == "ghost")
	print("[GameManager] Local role set to: %s" % role)


## Called when entering the lobby
func enter_lobby():
	set_state(GameState.LOBBY)
	reset_game()


## Start the actual gameplay (multiplayer version)
func start_gameplay():
	is_single_player = false
	set_state(GameState.PLAYING)
	alive_humans = _count_humans()
	total_humans = alive_humans
	flashlight_battery = 100.0
	print("[GameManager] Gameplay started! Humans: %d, Ghost: %s" % [alive_humans, "Player/AI"])


## Start gameplay in single-player AI Ghost mode
## This is the KEY fix - properly counts the local player as a human
func start_gameplay_singleplayer():
	is_single_player = true
	set_state(GameState.PLAYING)
	alive_humans = 1  # The local player is the only human
	total_humans = 1
	flashlight_battery = 100.0
	print("[GameManager] Single-player mode started! You are human, AI is ghost.")


## Reset all game data for a new round
func reset_game():
	required_items = {
		"key_red": false,
		"key_blue": false,
		"key_green": false,
		"car_key": false
	}
	items_collected_count = 0
	escape_door_unlocked = false
	flashlight_battery = 100.0
	alive_humans = 0
	total_humans = 0
	local_role = "human"
	is_ghost_player = false
	is_single_player = false


## A player has been caught by the ghost
func on_player_caught(peer_id: int):
	if current_state != GameState.PLAYING:
		return

	player_caught.emit(peer_id)

	# Single-player mode - handle directly
	if is_single_player:
		alive_humans -= 1
		if alive_humans <= 0:
			_on_ghost_wins()
		set_state(GameState.CAUGHT)
		print("[GameManager] You have been caught by the ghost!")
		return

	# Multiplayer mode
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		alive_humans -= 1
		if alive_humans <= 0:
			_on_ghost_wins()

	if peer_id == multiplayer.get_unique_id():
		set_state(GameState.CAUGHT)
		print("[GameManager] You have been caught by the ghost!")


## A player has escaped through the exit
func on_player_escaped(peer_id: int):
	if current_state != GameState.PLAYING:
		return

	player_escaped.emit(peer_id)

	# Single-player mode - handle directly
	if is_single_player:
		_on_humans_win()
		set_state(GameState.ESCAPED)
		print("[GameManager] You have escaped!")
		return

	# Multiplayer mode
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		alive_humans -= 1
		if alive_humans <= 0:
			_on_humans_win()

	if peer_id == multiplayer.get_unique_id():
		set_state(GameState.ESCAPED)
		print("[GameManager] You have escaped!")


## An item has been collected
func on_item_collected(item_name: String, peer_id: int):
	if not required_items.has(item_name):
		return

	# Single-player mode - handle directly
	if is_single_player:
		if not required_items[item_name]:
			required_items[item_name] = true
			items_collected_count += 1
			item_collected.emit(item_name, peer_id)
			print("[GameManager] Item collected: %s (%d/%d)" % [item_name, items_collected_count, total_items_required])
			if items_collected_count >= total_items_required:
				escape_door_unlocked = true
				all_items_collected.emit()
				print("[GameManager] All items collected! Escape door unlocked!")
		return

	# Multiplayer mode
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		if not required_items[item_name]:
			required_items[item_name] = true
			items_collected_count += 1
			_sync_item_state.rpc(item_name, true)
			item_collected.emit(item_name, peer_id)
			print("[GameManager] Item collected: %s by peer %d (%d/%d)" % [item_name, peer_id, items_collected_count, total_items_required])
			if items_collected_count >= total_items_required:
				escape_door_unlocked = true
				all_items_collected.emit()
				print("[GameManager] All items collected! Escape door unlocked!")


## Sync item collection state to all clients
@rpc("authority", "call_local")
func _sync_item_state(item_name: String, collected: bool):
	required_items[item_name] = collected
	if collected:
		items_collected_count += 1
		if items_collected_count >= total_items_required:
			escape_door_unlocked = true
			all_items_collected.emit()


## Ghost wins - all humans caught
func _on_ghost_wins():
	set_state(GameState.GAME_OVER)
	ghost_victory.emit()
	if not is_single_player and multiplayer.has_multiplayer_peer():
		_notify_game_result.rpc("ghost_wins")


## Humans win
func _on_humans_win():
	set_state(GameState.GAME_OVER)
	human_victory.emit()
	if not is_single_player and multiplayer.has_multiplayer_peer():
		_notify_game_result.rpc("humans_win")


## Notify all clients about game result
@rpc("authority", "call_local")
func _notify_game_result(result: String):
	match result:
		"ghost_wins":
			if current_state != GameState.CAUGHT:
				set_state(GameState.GAME_OVER)
			ghost_victory.emit()
		"humans_win":
			if current_state != GameState.ESCAPED:
				set_state(GameState.ESCAPED)
			human_victory.emit()


## Return to main menu
func return_to_menu():
	reset_game()
	set_state(GameState.MENU)
	# Only disconnect if we have a multiplayer peer
	if multiplayer.has_multiplayer_peer():
		NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Called when a player leaves the game (server only)
func on_player_left(peer_id: int):
	if current_state != GameState.PLAYING:
		return
	if not is_single_player and NetworkManager.players.has(peer_id):
		var role = NetworkManager.players[peer_id].role
		if role == "human":
			alive_humans -= 1
			total_humans -= 1
			if alive_humans <= 0:
				_on_ghost_wins()
		elif role == "ghost":
			print("[GameManager] Ghost player left, switching to AI ghost")


## Count humans from player list (multiplayer only)
func _count_humans() -> int:
	if is_single_player:
		return 1
	var count = 0
	for pid in NetworkManager.players:
		if NetworkManager.players[pid].role == "human":
			count += 1
	return count


## Update flashlight battery
func update_flashlight(delta: float, is_on: bool):
	if is_on:
		flashlight_battery = max(0, flashlight_battery - flashlight_drain_rate * delta)
	else:
		flashlight_battery = min(100, flashlight_battery + flashlight_recharge_rate * delta)
