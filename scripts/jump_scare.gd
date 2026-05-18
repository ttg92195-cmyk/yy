extends Node
## JumpScare - Manages jump scare effects when ghost catches a player
## Creates a dramatic visual + audio scare using code (no external assets needed)

var is_showing: bool = false
var scare_overlay: ColorRect
var scare_label: Label
var scare_sub_label: Label

# Scare timing
var scare_duration: float = 2.0
var fade_duration: float = 0.3


func _ready():
	_create_scare_ui()
	GameManager.player_caught.connect(_on_player_caught)


func _create_scare_ui():
	## Create the jump scare overlay UI
	scare_overlay = ColorRect.new()
	scare_overlay.color = Color(0, 0, 0, 0)
	scare_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	scare_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scare_overlay.z_index = 100

	# Main scare text
	scare_label = Label.new()
	scare_label.text = "GHOST!"
	scare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scare_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scare_label.add_theme_font_size_override("font_size", 120)
	scare_label.add_theme_color_override("font_color", Color(1, 0, 0))
	scare_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	scare_overlay.add_child(scare_label)

	# Sub text
	scare_sub_label = Label.new()
	scare_sub_label.text = "IT FOUND YOU"
	scare_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scare_sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scare_sub_label.add_theme_font_size_override("font_size", 36)
	scare_sub_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	scare_sub_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	scare_sub_label.offset_top = 80
	scare_overlay.add_child(scare_sub_label)

	# Red vignette edges
	var vignette_left = ColorRect.new()
	vignette_left.color = Color(0.3, 0, 0, 0)
	vignette_left.set_anchors_preset(Control.PRESET_FULL_RECT)
	scare_overlay.add_child(vignette_left)


func trigger_jump_scare():
	if is_showing:
		return

	is_showing = true

	# Add overlay to viewport
	var viewport = get_viewport()
	if viewport:
		viewport.get_root().add_child(scare_overlay)

	# Play jump scare sound
	AmbientSound.play_jumpscare()

	# Flash screen red
	scare_overlay.color = Color(0.6, 0, 0, 0.9)

	# Screen shake
	_shake_camera()

	# Zoom animation for text
	scare_label.scale = Vector2(3.0, 3.0)
	scare_label.modulate = Color(1, 1, 1, 0)

	var tween = create_tween()
	tween.tween_property(scare_label, "scale", Vector2(1.0, 1.0), 0.15)
	tween.parallel().tween_property(scare_label, "modulate:a", 1.0, 0.1)

	# Fade from red to show text
	var fade_tween = create_tween()
	fade_tween.tween_property(scare_overlay, "color", Color(0.1, 0, 0, 0.95), 0.2)

	# Pulsing red text
	var pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(scare_label, "add_theme_color_override:font_color", Color(1, 0.3, 0.3), 0.3)
	pulse_tween.tween_property(scare_label, "add_theme_color_override:font_color", Color(1, 0, 0), 0.3)

	# Auto dismiss
	get_tree().create_timer(scare_duration).timeout.connect(dismiss_scare)


func _shake_camera():
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var shake_tween = create_tween()
	for i in range(15):
		var offset_x = randf_range(-0.1, 0.1)
		var offset_y = randf_range(-0.1, 0.1)
		shake_tween.tween_property(camera, "h_offset", offset_x, 0.02)
		shake_tween.parallel().tween_property(camera, "v_offset", offset_y, 0.02)

	shake_tween.tween_property(camera, "h_offset", 0.0, 0.1)
	shake_tween.parallel().tween_property(camera, "v_offset", 0.0, 0.1)


func dismiss_scare():
	var tween = create_tween()
	tween.tween_property(scare_overlay, "color:a", 0.0, fade_duration)
	tween.tween_callback(func():
		is_showing = false
		if scare_overlay.get_parent():
			scare_overlay.get_parent().remove_child(scare_overlay)
	)


func _on_player_caught(peer_id: int):
	if peer_id == multiplayer.get_unique_id():
		trigger_jump_scare()
