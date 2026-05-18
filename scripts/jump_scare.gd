extends Node
## JumpScare - Manages jump scare effects when ghost catches a player
## Attached to the Game scene or as a child of the UI layer

# Jump scare images/scenes to randomly choose from
var scare_resources: Array[String] = [
	"res://assets/textures/scare_01.png",
	"res://assets/textures/scare_02.png",
	"res://assets/textures/scare_03.png",
]

var is_showing: bool = false
var scare_overlay: ColorRect
var scare_texture: TextureRect
var scare_audio: AudioStreamPlayer

# Scare timing
var scare_duration: float = 1.5
var fade_duration: float = 0.3
var screen_shake_intensity: float = 10.0
var screen_shake_duration: float = 0.5


func _ready():
	# Create UI elements
	_create_scare_ui()

	# Connect to game signals
	GameManager.player_caught.connect(_on_player_caught)


func _create_scare_ui():
	"""Create the jump scare overlay UI"""
	# Full screen overlay
	scare_overlay = ColorRect.new()
	scare_overlay.color = Color(0, 0, 0, 0)
	scare_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	scare_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scare_overlay.z_index = 100

	# Scare image
	scare_texture = TextureRect.new()
	scare_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	scare_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scare_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	scare_texture.visible = false

	# Scare audio
	scare_audio = AudioStreamPlayer.new()
	scare_audio.volume_db = 0.0

	scare_overlay.add_child(scare_texture)
	scare_overlay.add_child(scare_audio)

	# Don't add to tree yet - add when needed
	# Will be added to the viewport when triggered


func trigger_jump_scare():
	"""Trigger a jump scare effect"""
	if is_showing:
		return

	is_showing = true

	# Add overlay to viewport
	var viewport = get_viewport()
	if viewport:
		viewport.get_root().add_child(scare_overlay)

	# Flash screen red then show scare image
	_flash_screen()

	# Play scare sound
	if scare_audio:
		scare_audio.play()

	# Screen shake
	_shake_camera()

	# Show scare image
	_show_scare_image()

	# Auto dismiss after duration
	get_tree().create_timer(scare_duration).timeout.connect(dismiss_scare)


func _flash_screen():
	"""Flash the screen red"""
	scare_overlay.color = Color(0.5, 0, 0, 0.8)

	# Fade from red to show scare
	var tween = create_tween()
	tween.tween_property(scare_overlay, "color", Color(0, 0, 0, 1), fade_duration)


func _show_scare_image():
	"""Show the jump scare image"""
	scare_texture.visible = true

	# Try to load a scare texture
	var scare_path = scare_resources[randi() % scare_resources.size()]
	if ResourceLoader.exists(scare_path):
		scare_texture.texture = load(scare_path)
	else:
		# No texture available - use text as fallback
		scare_texture.visible = false
		# Create a label instead
		var label = Label.new()
		label.text = "GHOST!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 128)
		label.add_theme_color_override("font_color", Color(1, 0, 0))
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		scare_overlay.add_child(label)

	# Scale animation - zoom in effect
	scare_texture.scale = Vector2(2.0, 2.0)
	var tween = create_tween()
	tween.tween_property(scare_texture, "scale", Vector2(1.0, 1.0), 0.2)


func _shake_camera():
	"""Shake the camera for dramatic effect"""
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var original_offset = camera.h_offset
	var shake_tween = create_tween()

	for i in range(10):
		var offset_x = randf_range(-screen_shake_intensity, screen_shake_intensity) / 100.0
		var offset_y = randf_range(-screen_shake_intensity, screen_shake_intensity) / 100.0
		shake_tween.tween_property(camera, "h_offset", offset_x, 0.02)
		shake_tween.parallel().tween_property(camera, "v_offset", offset_y, 0.02)

	shake_tween.tween_property(camera, "h_offset", original_offset, 0.1)
	shake_tween.parallel().tween_property(camera, "v_offset", 0.0, 0.1)


func dismiss_scare():
	"""Dismiss the jump scare overlay"""
	var tween = create_tween()
	tween.tween_property(scare_overlay, "color:a", 0.0, fade_duration)
	tween.tween_callback(func():
		is_showing = false
		scare_texture.visible = false
		if scare_overlay.get_parent():
			scare_overlay.get_parent().remove_child(scare_overlay)
	)


func _on_player_caught(peer_id: int):
	"""Called when a player is caught - trigger jump scare for local player"""
	if peer_id == multiplayer.get_unique_id():
		trigger_jump_scare()
