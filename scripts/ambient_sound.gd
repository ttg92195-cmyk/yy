extends Node
## AmbientSound - ULTRA LIGHTWEIGHT - NO AudioStreamGenerator
## AudioStreamGenerator was causing crashes on mobile
## This version does NOTHING during gameplay - zero audio processing
## Safe for mobile, no CPU usage

var is_in_game: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.game_state_changed.connect(_on_game_state_changed)


func _on_game_state_changed(new_state):
	if new_state == GameManager.GameState.PLAYING:
		is_in_game = true
	elif new_state == GameManager.GameState.MENU:
		is_in_game = false


func _process(_delta):
	# Do nothing - zero audio processing on mobile
	pass


func play_jumpscare():
	# No audio for now - prevents crash
	pass
