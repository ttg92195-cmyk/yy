extends Node
## AmbientSoundManager - MOBILE-OPTIMIZED horror ambient sounds
## Optimizations:
## - Only 2 audio players instead of 5
## - Simpler sound generation
## - Less frequent random sounds

# Audio players
var ambient_player: AudioStreamPlayer
var effect_player: AudioStreamPlayer

# Timing
var effect_timer: float = 0.0
var next_effect: float = 15.0

# State
var is_in_game: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Only 2 audio players
	ambient_player = AudioStreamPlayer.new()
	ambient_player.volume_db = -18
	add_child(ambient_player)

	effect_player = AudioStreamPlayer.new()
	effect_player.volume_db = -15
	add_child(effect_player)

	# Connect to game state
	GameManager.game_state_changed.connect(_on_game_state_changed)


func _on_game_state_changed(new_state):
	if new_state == GameManager.GameState.PLAYING:
		is_in_game = true
		_start_ambient_loop()
	elif new_state == GameManager.GameState.MENU:
		is_in_game = false
		_stop_all()


func _process(delta):
	if not is_in_game:
		return

	# Occasional random effect (creak/drip/whisper)
	effect_timer += delta
	if effect_timer >= next_effect:
		effect_timer = 0.0
		next_effect = randf_range(10.0, 30.0)
		_play_random_effect()


func _start_ambient_loop():
	# Low drone ambient
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.5

	ambient_player.stream = generator
	ambient_player.play()
	_fill_ambient_buffer()


func _fill_ambient_buffer():
	if not ambient_player.playing:
		return

	var playback = ambient_player.get_stream_playback() as AudioStreamPlayback
	if playback:
		var frames = playback.get_frames_available()
		var buffer = PackedVector2Array()
		buffer.resize(frames)

		var phase = 0.0
		var freq = 55.0
		var mix_rate = 22050.0

		for i in range(frames):
			var sample = sin(phase) * 0.1 + (randf() - 0.5) * 0.01
			buffer[i] = Vector2(sample, sample)
			phase += TAU * freq / mix_rate

		playback.push_buffer(buffer)

	if is_in_game:
		get_tree().create_timer(0.4).timeout.connect(_fill_ambient_buffer)


func _play_random_effect():
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.2

	effect_player.stream = generator
	effect_player.volume_db = randf_range(-20, -8)
	effect_player.play()

	var playback = effect_player.get_stream_playback() as AudioStreamPlayback
	if playback:
		var frames = playback.get_frames_available()
		var buffer = PackedVector2Array()
		buffer.resize(frames)

		var phase = 0.0
		var mix_rate = 22050.0

		for i in range(frames):
			var t = float(i) / mix_rate
			if t > 0.15:
				buffer[i] = Vector2.ZERO
				continue
			# Simple creak-like effect
			var freq = lerp(300.0, 600.0, t / 0.15)
			var amplitude = sin(t / 0.15 * PI) * 0.2
			var sample = sin(phase) * amplitude + (randf() - 0.5) * 0.03
			buffer[i] = Vector2(sample, sample)
			phase += TAU * freq / mix_rate

		playback.push_buffer(buffer)


func _stop_all():
	if ambient_player:
		ambient_player.stop()
	if effect_player:
		effect_player.stop()


func play_jumpscare():
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.3

	var player = AudioStreamPlayer.new()
	player.volume_db = -5
	player.stream = generator
	add_child(player)
	player.play()

	var playback = player.get_stream_playback() as AudioStreamPlayback
	if playback:
		var frames = playback.get_frames_available()
		var buffer = PackedVector2Array()
		buffer.resize(frames)

		var phase = 0.0
		var mix_rate = 44100.0

		for i in range(frames):
			var t = float(i) / mix_rate
			if t > 0.2:
				buffer[i] = Vector2.ZERO
				continue
			var envelope = exp(-t * 8.0)
			var sample = sin(phase) * envelope * 0.7 + (randf() - 0.5) * envelope * 0.4
			buffer[i] = Vector2(sample, sample)
			phase += TAU * 150.0 / mix_rate

		playback.push_buffer(buffer)

	player.finished.connect(func(): player.queue_free())
