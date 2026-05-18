extends Node
## AmbientSoundManager - Horror ambient sounds and audio effects
## AutoLoad singleton that creates atmospheric sounds
## Uses generated AudioStream for basic effects (no external files needed)

# Audio players
var ambient_player: AudioStreamPlayer
var ambient_player_2: AudioStreamPlayer
var creak_player: AudioStreamPlayer
var drip_player: AudioStreamPlayer
var whisper_player: AudioStreamPlayer

# Timing
var creak_timer: float = 0.0
var drip_timer: float = 0.0
var whisper_timer: float = 0.0
var next_creak: float = 10.0
var next_drip: float = 5.0
var next_whisper: float = 20.0

# State
var is_in_game: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create audio players
	ambient_player = AudioStreamPlayer.new()
	ambient_player.volume_db = -15
	ambient_player.bus = "Master"
	add_child(ambient_player)

	ambient_player_2 = AudioStreamPlayer.new()
	ambient_player_2.volume_db = -20
	ambient_player_2.bus = "Master"
	add_child(ambient_player_2)

	creak_player = AudioStreamPlayer.new()
	creak_player.volume_db = -12
	creak_player.bus = "Master"
	add_child(creak_player)

	drip_player = AudioStreamPlayer.new()
	drip_player.volume_db = -18
	drip_player.bus = "Master"
	add_child(drip_player)

	whisper_player = AudioStreamPlayer.new()
	whisper_player.volume_db = -25
	whisper_player.bus = "Master"
	add_child(whisper_player)

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

	# Random creaking sounds
	creak_timer += delta
	if creak_timer >= next_creak:
		creak_timer = 0.0
		next_creak = randf_range(8.0, 25.0)
		_play_creak()

	# Water dripping
	drip_timer += delta
	if drip_timer >= next_drip:
		drip_timer = 0.0
		next_drip = randf_range(3.0, 10.0)
		_play_drip()

	# Ghost whispers
	whisper_timer += delta
	if whisper_timer >= next_whisper:
		whisper_timer = 0.0
		next_whisper = randf_range(15.0, 40.0)
		_play_whisper()


func _start_ambient_loop():
	## Start the ambient horror sound loop
	# Create a low drone sound using AudioStreamGenerator
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.5

	ambient_player.stream = generator
	ambient_player.play()

	# Generate low frequency drone
	_fill_ambient_buffer()

	# Second ambient layer - even lower
	var generator2 = AudioStreamGenerator.new()
	generator2.mix_rate = 22050
	generator2.buffer_length = 0.5
	ambient_player_2.stream = generator2
	ambient_player_2.play()


func _fill_ambient_buffer():
	## Fill the ambient audio buffer with a low drone
	if not ambient_player.playing:
		return

	var playback = ambient_player.get_stream_playback() as AudioStreamPlayback
	if playback:
		var frames_available = playback.get_frames_available()
		var buffer = PackedVector2Array()
		buffer.resize(frames_available)

		var phase = 0.0
		var freq = 55.0  # Low A note - scary drone
		var mix_rate = 22050.0

		for i in range(frames_available):
			# Low frequency drone with slight modulation
			var modulation = sin(phase * 0.001) * 0.3
			var sample = sin(phase) * (0.15 + modulation * 0.05)
			# Add some noise for texture
			sample += (randf() - 0.5) * 0.02
			buffer[i] = Vector2(sample, sample)
			phase += TAU * freq / mix_rate

		playback.push_buffer(buffer)

	# Schedule next buffer fill
	if is_in_game:
		get_tree().create_timer(0.4).timeout.connect(_fill_ambient_buffer)


func _play_creak():
	## Play a door creak-like sound
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.2

	creak_player.stream = generator
	creak_player.volume_db = randf_range(-18, -8)
	creak_player.play()

	var playback = creak_player.get_stream_playback() as AudioStreamPlayback
	if playback:
		var frames = playback.get_frames_available()
		var buffer = PackedVector2Array()
		buffer.resize(frames)

		var phase = 0.0
		var mix_rate = 22050.0
		var duration = 0.15

		for i in range(frames):
			var t = float(i) / mix_rate
			if t > duration:
				buffer[i] = Vector2.ZERO
				continue
			# Rising frequency creak
			var freq = lerp(300.0, 800.0, t / duration)
			var amplitude = sin(t / duration * PI) * 0.3  # Envelope
			var sample = sin(phase) * amplitude
			# Add metallic resonance
			sample += sin(phase * 2.7) * amplitude * 0.3
			sample += (randf() - 0.5) * 0.05 * amplitude
			buffer[i] = Vector2(sample, sample)
			phase += TAU * freq / mix_rate

		playback.push_buffer(buffer)


func _play_drip():
	## Play a water drip sound
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.1

	drip_player.stream = generator
	drip_player.volume_db = randf_range(-22, -12)
	drip_player.play()

	var playback = drip_player.get_stream_playback() as AudioStreamPlayback
	if playback:
		var frames = playback.get_frames_available()
		var buffer = PackedVector2Array()
		buffer.resize(frames)

		var phase = 0.0
		var mix_rate = 22050.0

		for i in range(frames):
			var t = float(i) / mix_rate
			if t > 0.08:
				buffer[i] = Vector2.ZERO
				continue
			# Quick high-pitched drip with fast decay
			var amplitude = exp(-t * 50.0) * 0.2
			var freq = 2000.0 + sin(t * 100) * 500.0  # Wobble
			var sample = sin(phase) * amplitude
			buffer[i] = Vector2(sample, sample)
			phase += TAU * freq / mix_rate

		playback.push_buffer(buffer)


func _play_whisper():
	## Play a ghost whisper sound
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.5

	whisper_player.stream = generator
	whisper_player.volume_db = randf_range(-30, -18)
	whisper_player.play()

	var playback = whisper_player.get_stream_playback() as AudioStreamPlayback
	if playback:
		var frames = playback.get_frames_available()
		var buffer = PackedVector2Array()
		buffer.resize(frames)

		var mix_rate = 22050.0

		for i in range(frames):
			var t = float(i) / mix_rate
			if t > 0.4:
				buffer[i] = Vector2.ZERO
				continue
			# Whispery noise with envelope
			var envelope = sin(t / 0.4 * PI) * 0.1
			# Filtered noise (whisper-like)
			var noise = (randf() - 0.5) * envelope
			# Add some tonal quality
			noise += sin(t * 400.0) * envelope * 0.1
			noise += sin(t * 600.0) * envelope * 0.05
			buffer[i] = Vector2(noise * 0.5, noise * 0.5)

		playback.push_buffer(buffer)


func _stop_all():
	ambient_player.stop()
	ambient_player_2.stop()
	creak_player.stop()
	drip_player.stop()
	whisper_player.stop()


## Play a jump scare sound (loud, startling)
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
			if t > 0.25:
				buffer[i] = Vector2.ZERO
				continue
			# Loud, harsh sound
			var envelope = exp(-t * 8.0)
			var sample = sin(phase) * envelope * 0.8
			sample += (randf() - 0.5) * envelope * 0.5
			sample += sin(phase * 3.0) * envelope * 0.3
			buffer[i] = Vector2(sample, sample)
			phase += TAU * 150.0 / mix_rate

		playback.push_buffer(buffer)

	player.finished.connect(func(): player.queue_free())
