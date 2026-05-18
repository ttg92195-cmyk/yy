extends CanvasLayer
## TouchControls - Mobile touch controls for the game
## Virtual joystick + action buttons for Android/iOS

signal joystick_input(direction: Vector2)
signal joystick_released()

# Joystick
var joystick_active: bool = false
var joystick_start_pos: Vector2 = Vector2.ZERO
var joystick_direction: Vector2 = Vector2.ZERO
var joystick_max_distance: float = 80.0

# UI Elements
var joystick_bg: ColorRect
var joystick_knob: ColorRect
var joystick_container: Control
var button_sprint: Button
var button_flashlight: Button
var button_interact: Button
var button_look_area: Control

# Look sensitivity
var look_sensitivity: float = 0.003
var last_touch_pos: Vector2 = Vector2.ZERO

# Touch tracking
var joystick_touch_id: int = -1
var look_touch_id: int = -1


func _ready():
	# Only show on mobile
	var is_mobile = OS.has_feature("android") or OS.has_feature("ios")
	if not is_mobile:
		# Still create but hide - useful for testing
		pass

	layer = 10  # Above game UI
	_create_joystick()
	_create_buttons()
	_create_look_area()


func _create_joystick():
	## Create virtual joystick on the left side
	joystick_container = Control.new()
	joystick_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_container.offset_left = 30
	joystick_container.offset_top = -200
	joystick_container.offset_right = 230
	joystick_container.offset_bottom = -30
	joystick_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background circle
	joystick_bg = ColorRect.new()
	joystick_bg.position = Vector2(30, 30)
	joystick_bg.size = Vector2(140, 140)
	joystick_bg.color = Color(1, 1, 1, 0.15)
	joystick_container.add_child(joystick_bg)

	# Knob (draggable circle)
	joystick_knob = ColorRect.new()
	joystick_knob.position = Vector2(75, 75)
	joystick_knob.size = Vector2(50, 50)
	joystick_knob.color = Color(1, 1, 1, 0.4)
	joystick_container.add_child(joystick_knob)

	joystick_start_pos = joystick_knob.position
	add_child(joystick_container)


func _create_buttons():
	## Create action buttons on the right side
	var btn_size = Vector2(70, 70)
	var right_offset = 20

	# Sprint button
	button_sprint = Button.new()
	button_sprint.text = "🏃"
	button_sprint.position = Vector2(
		DisplayServer.window_get_size().x - btn_size.x - right_offset - 80,
		DisplayServer.window_get_size().y - btn_size.y - 160
	)
	button_sprint.size = btn_size
	button_sprint.modulate = Color(1, 1, 1, 0.6)
	button_sprint.pressed.connect(func(): Input.action_press("sprint"))
	button_sprint.button_up.connect(func(): Input.action_release("sprint"))
	add_child(button_sprint)

	# Flashlight button
	button_flashlight = Button.new()
	button_flashlight.text = "🔦"
	button_flashlight.position = Vector2(
		DisplayServer.window_get_size().x - btn_size.x - right_offset,
		DisplayServer.window_get_size().y - btn_size.y - 160
	)
	button_flashlight.size = btn_size
	button_flashlight.modulate = Color(1, 1, 1, 0.6)
	button_flashlight.pressed.connect(func(): Input.action_press("flashlight"))
	button_flashlight.button_up.connect(func(): Input.action_release("flashlight"))
	add_child(button_flashlight)

	# Interact button
	button_interact = Button.new()
	button_interact.text = "E"
	button_interact.position = Vector2(
		DisplayServer.window_get_size().x - btn_size.x - right_offset - 40,
		DisplayServer.window_get_size().y - btn_size.y - 80
	)
	button_interact.size = btn_size
	button_interact.modulate = Color(1, 1, 0.5, 0.7)
	button_interact.pressed.connect(func(): Input.action_press("interact"))
	button_interact.button_up.connect(func(): Input.action_release("interact"))
	add_child(button_interact)


func _create_look_area():
	## Create an invisible touch area for camera look on the right half
	button_look_area = Control.new()
	button_look_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	button_look_area.mouse_filter = Control.MOUSE_FILTER_PASS
	button_look_area.z_index = -1
	add_child(button_look_area)


func _input(event: InputEvent):
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch):
	var screen_center_x = DisplayServer.window_get_size().x / 2.0

	if event.pressed:
		if event.position.x < screen_center_x:
			# Left side - joystick
			joystick_touch_id = event.index
			joystick_active = true
			_update_joystick(event.position)
		else:
			# Right side - look
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
		# Camera look
		var delta = event.position - last_touch_pos
		last_touch_pos = event.position

		# Simulate mouse motion for camera
		var motion_event = InputEventMouseMotion.new()
		motion_event.relative = delta
		Input.parse_input_event(motion_event)


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

	if joystick_direction.y < -0.3:
		Input.action_press("move_forward")
	if joystick_direction.y > 0.3:
		Input.action_press("move_backward")
	if joystick_direction.x < -0.3:
		Input.action_press("move_left")
	if joystick_direction.x > 0.3:
		Input.action_press("move_right")
