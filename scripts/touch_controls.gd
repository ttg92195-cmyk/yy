extends CanvasLayer
## TouchControls - Mobile touch controls for the game (LANDSCAPE optimized)
## Virtual joystick + action buttons for Android/iOS
## CRITICAL: Buttons use _gui_input and proper anchoring for reliable touch
## Layout: Left side = Joystick, Right side = Buttons, Center = Camera look

signal joystick_input(direction: Vector2)
signal joystick_released()

# Joystick
var joystick_active: bool = false
var joystick_start_pos: Vector2 = Vector2.ZERO
var joystick_direction: Vector2 = Vector2.ZERO
var joystick_max_distance: float = 65.0

# UI Elements
var joystick_bg: Panel
var joystick_knob: Panel
var joystick_container: Control
var button_sprint: Button
var button_flashlight: Button
var button_interact: Button

# Look sensitivity
var look_sensitivity: float = 0.003
var last_touch_pos: Vector2 = Vector2.ZERO

# Touch tracking - separate IDs for joystick, look, and buttons
var joystick_touch_id: int = -1
var look_touch_id: int = -1

# Root control for layout
var root_control: Control

# Screen size cache
var screen_width: float = 1280.0
var screen_height: float = 720.0


func _ready():
	# Only show on mobile
	var is_mobile = OS.has_feature("android") or OS.has_feature("ios")
	if not is_mobile:
		# Still create but hide for testing
		pass

	layer = 10  # Above game UI

	# Create root control with full rect
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.name = "TouchRoot"
	add_child(root_control)

	_create_joystick()
	_create_buttons()


func _create_joystick():
	## Create virtual joystick on the left side - LANDSCAPE optimized
	joystick_container = Control.new()
	joystick_container.name = "JoystickContainer"
	joystick_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_container.offset_left = 15
	joystick_container.offset_top = -200
	joystick_container.offset_right = 200
	joystick_container.offset_bottom = -15
	joystick_container.mouse_filter = Control.MOUSE_FILTER_PASS

	# Background circle using Panel - larger for landscape
	joystick_bg = Panel.new()
	joystick_bg.position = Vector2(15, 15)
	joystick_bg.size = Vector2(140, 140)
	joystick_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Style for background
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(1, 1, 1, 0.08)
	bg_style.border_color = Color(1, 1, 1, 0.15)
	bg_style.border_width_bottom = 2
	bg_style.border_width_top = 2
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.corner_radius_top_left = 70
	bg_style.corner_radius_top_right = 70
	bg_style.corner_radius_bottom_left = 70
	bg_style.corner_radius_bottom_right = 70
	joystick_bg.add_theme_stylebox_override("panel", bg_style)
	joystick_container.add_child(joystick_bg)

	# Knob (draggable circle) - larger for landscape
	joystick_knob = Panel.new()
	joystick_knob.position = Vector2(60, 60)
	joystick_knob.size = Vector2(50, 50)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Style for knob
	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color(1, 1, 1, 0.45)
	knob_style.corner_radius_top_left = 25
	knob_style.corner_radius_top_right = 25
	knob_style.corner_radius_bottom_left = 25
	knob_style.corner_radius_bottom_right = 25
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	joystick_container.add_child(joystick_knob)

	joystick_start_pos = joystick_knob.position
	root_control.add_child(joystick_container)


func _create_buttons():
	## Create action buttons on the right side - LANDSCAPE optimized layout
	# Button container anchored to bottom-right
	var btn_container = Control.new()
	btn_container.name = "ButtonContainer"
	btn_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_container.offset_left = -220
	btn_container.offset_top = -180
	btn_container.offset_right = -10
	btn_container.offset_bottom = -10
	btn_container.mouse_filter = Control.MOUSE_FILTER_PASS

	# Larger buttons for landscape
	var btn_size = Vector2(64, 64)

	# Button style
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.2, 0.3, 0.55)
	btn_style.border_color = Color(0.5, 0.5, 0.7, 0.7)
	btn_style.border_width_bottom = 2
	btn_style.border_width_top = 2
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.corner_radius_top_left = 32
	btn_style.corner_radius_top_right = 32
	btn_style.corner_radius_bottom_left = 32
	btn_style.corner_radius_bottom_right = 32

	# ---- Bottom row: SPRINT + INTERACT side by side ----

	# Sprint button (bottom-left of button area)
	button_sprint = Button.new()
	button_sprint.text = "RUN"
	button_sprint.position = Vector2(5, 80)
	button_sprint.size = btn_size
	button_sprint.add_theme_stylebox_override("normal", btn_style.duplicate())
	button_sprint.add_theme_stylebox_override("pressed", _create_pressed_style(Color(0.3, 0.6, 0.3, 0.7)))
	button_sprint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	button_sprint.add_theme_font_size_override("font_size", 14)
	# Sprint is held down, so use button_down/button_up
	button_sprint.button_down.connect(func(): Input.action_press("sprint"))
	button_sprint.button_up.connect(func(): Input.action_release("sprint"))
	btn_container.add_child(button_sprint)

	# Interact button (bottom-right of button area)
	var interact_style = btn_style.duplicate()
	interact_style.bg_color = Color(0.1, 0.3, 0.4, 0.55)
	interact_style.border_color = Color(0.2, 0.6, 0.8, 0.7)

	button_interact = Button.new()
	button_interact.text = "USE"
	button_interact.position = Vector2(78, 80)
	button_interact.size = btn_size
	button_interact.add_theme_stylebox_override("normal", interact_style)
	button_interact.add_theme_stylebox_override("pressed", _create_pressed_style(Color(0.2, 0.6, 0.8, 0.8)))
	button_interact.add_theme_color_override("font_color", Color(0.7, 1, 1, 0.85))
	button_interact.add_theme_font_size_override("font_size", 14)
	button_interact.pressed.connect(_on_interact_pressed)
	btn_container.add_child(button_interact)

	# ---- Top: FLASHLIGHT button (centered above bottom row) ----
	var flash_style = btn_style.duplicate()
	flash_style.bg_color = Color(0.4, 0.35, 0.1, 0.55)
	flash_style.border_color = Color(0.8, 0.7, 0.2, 0.7)

	button_flashlight = Button.new()
	button_flashlight.text = "LIGHT"
	button_flashlight.position = Vector2(40, 8)
	button_flashlight.size = btn_size
	button_flashlight.add_theme_stylebox_override("normal", flash_style)
	button_flashlight.add_theme_stylebox_override("pressed", _create_pressed_style(Color(0.8, 0.7, 0.2, 0.8)))
	button_flashlight.add_theme_color_override("font_color", Color(1, 1, 0.7, 0.85))
	button_flashlight.add_theme_font_size_override("font_size", 12)
	button_flashlight.pressed.connect(_on_flashlight_pressed)
	btn_container.add_child(button_flashlight)

	root_control.add_child(btn_container)


func _create_pressed_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 32
	style.corner_radius_top_right = 32
	style.corner_radius_bottom_left = 32
	style.corner_radius_bottom_right = 32
	return style


func _on_flashlight_pressed():
	## Toggle flashlight - use Input action so player_controller picks it up
	Input.action_press("flashlight")
	# Release after a short delay so it registers as a "pressed" event
	await get_tree().create_timer(0.05).timeout
	Input.action_release("flashlight")


func _on_interact_pressed():
	## Trigger interact action
	Input.action_press("interact")
	await get_tree().create_timer(0.05).timeout
	Input.action_release("interact")


func _input(event: InputEvent):
	## Handle touch input for joystick and camera look
	## Buttons handle their own input via Button signals, so we only
	## handle the joystick area (left side) and look area (right side, not on buttons)

	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch):
	# Update screen size cache
	screen_width = DisplayServer.window_get_size().x
	screen_height = DisplayServer.window_get_size().y

	# Check if touch is on a button - if so, let the button handle it
	if _is_on_button(event.position):
		return  # Don't process - let button signals handle it

	if event.pressed:
		# Left 35% of screen, bottom 60% = joystick area (landscape)
		if event.position.x < screen_width * 0.35 and event.position.y > screen_height * 0.35:
			joystick_touch_id = event.index
			joystick_active = true
			_update_joystick(event.position)
		else:
			# Right side or top = look
			if joystick_touch_id == -1:  # Don't override joystick touch
				look_touch_id = event.index
				last_touch_pos = event.position
	else:
		if event.index == joystick_touch_id:
			joystick_touch_id = -1
			joystick_active = false
			joystick_direction = Vector2.ZERO
			joystick_knob.position = joystick_start_pos
			joystick_input.emit(Vector2.ZERO)
			# Release movement inputs
			Input.action_release("move_forward")
			Input.action_release("move_backward")
			Input.action_release("move_left")
			Input.action_release("move_right")
		elif event.index == look_touch_id:
			look_touch_id = -1


func _handle_drag(event: InputEventScreenDrag):
	if event.index == joystick_touch_id:
		_update_joystick(event.position)
	elif event.index == look_touch_id:
		# Camera look - simulate mouse motion
		var delta = event.position - last_touch_pos
		last_touch_pos = event.position

		# Find local player and rotate directly
		var players = get_tree().get_nodes_in_group("player")
		for player in players:
			if player.is_local_player:
				player.rotate_y(-delta.x * look_sensitivity)
				if player.head:
					player.head.rotate_x(-delta.y * look_sensitivity)
					player.head.rotation.x = clamp(player.head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
				break


func _is_on_button(pos: Vector2) -> bool:
	## Check if a touch position is over any of our buttons
	if button_sprint and button_sprint.get_global_rect().has_point(pos):
		return true
	if button_flashlight and button_flashlight.get_global_rect().has_point(pos):
		return true
	if button_interact and button_interact.get_global_rect().has_point(pos):
		return true
	return false


func _update_joystick(touch_pos: Vector2):
	## Update joystick position and direction
	var center = Vector2(
		joystick_bg.position.x + joystick_bg.size.x / 2.0,
		joystick_bg.position.y + joystick_bg.size.y / 2.0
	)

	# Convert to local coordinates
	var local_pos = touch_pos - joystick_container.global_position
	var diff = local_pos - center
	var dist = diff.length()

	if dist > joystick_max_distance:
		diff = diff.normalized() * joystick_max_distance

	# Update knob position
	joystick_knob.position = center + diff - joystick_knob.size / 2.0

	# Calculate direction (-1 to 1)
	joystick_direction = diff / joystick_max_distance
	joystick_input.emit(joystick_direction)

	# Simulate keyboard inputs
	Input.action_release("move_forward")
	Input.action_release("move_backward")
	Input.action_release("move_left")
	Input.action_release("move_right")

	if joystick_direction.y < -0.25:
		Input.action_press("move_forward")
	if joystick_direction.y > 0.25:
		Input.action_press("move_backward")
	if joystick_direction.x < -0.25:
		Input.action_press("move_left")
	if joystick_direction.x > 0.25:
		Input.action_press("move_right")
