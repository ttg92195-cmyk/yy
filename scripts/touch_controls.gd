extends CanvasLayer
## TouchControls - Horror themed mobile touch controls (LANDSCAPE)
## New design: Dark horror style with red accents
## Joystick: Dark circle with red glow
## Buttons: Horror themed with icons

signal joystick_input(direction: Vector2)

# Joystick
var joystick_active: bool = false
var joystick_start_pos: Vector2 = Vector2.ZERO
var joystick_direction: Vector2 = Vector2.ZERO
var joystick_max_distance: float = 55.0

# UI
var joystick_bg: Panel
var joystick_knob: Panel
var joystick_container: Control
var button_sprint: Button
var button_flashlight: Button
var button_interact: Button

# Look
var look_sensitivity: float = 0.004
var last_touch_pos: Vector2 = Vector2.ZERO

# Touch tracking
var joystick_touch_id: int = -1
var look_touch_id: int = -1

var root_control: Control
var screen_width: float = 960.0
var screen_height: float = 540.0


func _ready():
	layer = 10

	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.name = "TouchRoot"
	add_child(root_control)

	_create_joystick()
	_create_buttons()


func _create_joystick():
	## Horror-styled joystick - dark with red glow
	joystick_container = Control.new()
	joystick_container.name = "JoystickContainer"
	joystick_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_container.offset_left = 15
	joystick_container.offset_top = -190
	joystick_container.offset_right = 185
	joystick_container.offset_bottom = -15
	joystick_container.mouse_filter = Control.MOUSE_FILTER_PASS

	# Dark circle with red border
	joystick_bg = Panel.new()
	joystick_bg.position = Vector2(10, 10)
	joystick_bg.size = Vector2(130, 130)
	joystick_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.02, 0.02, 0.25)
	bg_style.border_color = Color(0.6, 0.1, 0.1, 0.5)
	bg_style.border_width_bottom = 2
	bg_style.border_width_top = 2
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.corner_radius_top_left = 65
	bg_style.corner_radius_top_right = 65
	bg_style.corner_radius_bottom_left = 65
	bg_style.corner_radius_bottom_right = 65
	bg_style.shadow_color = Color(0.3, 0.05, 0.05, 0.3)
	bg_style.shadow_size = 4
	joystick_bg.add_theme_stylebox_override("panel", bg_style)
	joystick_container.add_child(joystick_bg)

	# Red-tinted knob
	joystick_knob = Panel.new()
	joystick_knob.position = Vector2(45, 45)
	joystick_knob.size = Vector2(60, 60)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color(0.4, 0.08, 0.08, 0.6)
	knob_style.border_color = Color(0.8, 0.2, 0.15, 0.7)
	knob_style.border_width_bottom = 2
	knob_style.border_width_top = 2
	knob_style.border_width_left = 2
	knob_style.border_width_right = 2
	knob_style.corner_radius_top_left = 30
	knob_style.corner_radius_top_right = 30
	knob_style.corner_radius_bottom_left = 30
	knob_style.corner_radius_bottom_right = 30
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	joystick_container.add_child(joystick_knob)

	joystick_start_pos = joystick_knob.position
	root_control.add_child(joystick_container)


func _create_buttons():
	## Horror-styled action buttons - dark with red/yellow/green accents
	var btn_container = Control.new()
	btn_container.name = "ButtonContainer"
	btn_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_container.offset_left = -210
	btn_container.offset_top = -175
	btn_container.offset_right = -10
	btn_container.offset_bottom = -10
	btn_container.mouse_filter = Control.MOUSE_FILTER_PASS

	var btn_size = Vector2(60, 60)

	# Sprint button - red/dark
	button_sprint = Button.new()
	button_sprint.text = "RUN"
	button_sprint.position = Vector2(5, 80)
	button_sprint.size = btn_size
	button_sprint.add_theme_stylebox_override("normal", _make_btn_style(Color(0.2, 0.05, 0.05, 0.6), Color(0.6, 0.15, 0.1, 0.8)))
	button_sprint.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.4, 0.1, 0.1, 0.8), Color(1, 0.3, 0.2, 0.9)))
	button_sprint.add_theme_stylebox_override("hover", _make_btn_style(Color(0.3, 0.08, 0.08, 0.7), Color(0.8, 0.2, 0.15, 0.9)))
	button_sprint.add_theme_color_override("font_color", Color(1, 0.6, 0.5, 0.9))
	button_sprint.add_theme_color_override("font_hover_color", Color(1, 0.7, 0.6))
	button_sprint.add_theme_font_size_override("font_size", 13)
	button_sprint.button_down.connect(func(): Input.action_press("sprint"))
	button_sprint.button_up.connect(func(): Input.action_release("sprint"))
	btn_container.add_child(button_sprint)

	# Interact button - green/dark
	button_interact = Button.new()
	button_interact.text = "USE"
	button_interact.position = Vector2(75, 80)
	button_interact.size = btn_size
	button_interact.add_theme_stylebox_override("normal", _make_btn_style(Color(0.05, 0.15, 0.05, 0.6), Color(0.1, 0.5, 0.15, 0.8)))
	button_interact.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.1, 0.3, 0.1, 0.8), Color(0.2, 0.8, 0.3, 0.9)))
	button_interact.add_theme_stylebox_override("hover", _make_btn_style(Color(0.08, 0.2, 0.08, 0.7), Color(0.15, 0.6, 0.2, 0.9)))
	button_interact.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 0.9))
	button_interact.add_theme_color_override("font_hover_color", Color(0.7, 1, 0.7))
	button_interact.add_theme_font_size_override("font_size", 13)
	button_interact.pressed.connect(_on_interact_pressed)
	btn_container.add_child(button_interact)

	# Flashlight button - yellow/dark
	button_flashlight = Button.new()
	button_flashlight.text = "LIGHT"
	button_flashlight.position = Vector2(38, 10)
	button_flashlight.size = btn_size
	button_flashlight.add_theme_stylebox_override("normal", _make_btn_style(Color(0.15, 0.12, 0.02, 0.6), Color(0.5, 0.4, 0.1, 0.8)))
	button_flashlight.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.3, 0.25, 0.05, 0.8), Color(0.9, 0.7, 0.2, 0.9)))
	button_flashlight.add_theme_stylebox_override("hover", _make_btn_style(Color(0.2, 0.18, 0.03, 0.7), Color(0.7, 0.55, 0.15, 0.9)))
	button_flashlight.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 0.9))
	button_flashlight.add_theme_color_override("font_hover_color", Color(1, 1, 0.7))
	button_flashlight.add_theme_font_size_override("font_size", 11)
	button_flashlight.pressed.connect(_on_flashlight_pressed)
	btn_container.add_child(button_flashlight)

	root_control.add_child(btn_container)


func _make_btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 30
	style.corner_radius_top_right = 30
	style.corner_radius_bottom_left = 30
	style.corner_radius_bottom_right = 30
	return style


func _on_flashlight_pressed():
	Input.action_press("flashlight")
	await get_tree().create_timer(0.05).timeout
	Input.action_release("flashlight")


func _on_interact_pressed():
	Input.action_press("interact")
	await get_tree().create_timer(0.05).timeout
	Input.action_release("interact")


func _input(event: InputEvent):
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch):
	screen_width = DisplayServer.window_get_size().x
	screen_height = DisplayServer.window_get_size().y

	if _is_on_button(event.position):
		return

	if event.pressed:
		if event.position.x < screen_width * 0.35 and event.position.y > screen_height * 0.4:
			joystick_touch_id = event.index
			joystick_active = true
			_update_joystick(event.position)
		else:
			if look_touch_id == -1:
				look_touch_id = event.index
				last_touch_pos = event.position
	else:
		if event.index == joystick_touch_id:
			joystick_touch_id = -1
			joystick_active = false
			joystick_direction = Vector2.ZERO
			joystick_knob.position = joystick_start_pos
			joystick_input.emit(Vector2.ZERO)
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
		var delta = event.position - last_touch_pos
		last_touch_pos = event.position
		var players = get_tree().get_nodes_in_group("player")
		for player in players:
			if player.is_local_player:
				player.rotate_y(-delta.x * look_sensitivity)
				if player.head:
					player.head.rotate_x(-delta.y * look_sensitivity)
					player.head.rotation.x = clamp(player.head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
				break


func _is_on_button(pos: Vector2) -> bool:
	if button_sprint and button_sprint.get_global_rect().has_point(pos): return true
	if button_flashlight and button_flashlight.get_global_rect().has_point(pos): return true
	if button_interact and button_interact.get_global_rect().has_point(pos): return true
	return false


func _update_joystick(touch_pos: Vector2):
	var center = Vector2(
		joystick_bg.position.x + joystick_bg.size.x / 2.0,
		joystick_bg.position.y + joystick_bg.size.y / 2.0
	)
	var local_pos = touch_pos - joystick_container.global_position
	var diff = local_pos - center
	var dist = diff.length()
	if dist > joystick_max_distance:
		diff = diff.normalized() * joystick_max_distance

	joystick_knob.position = center + diff - joystick_knob.size / 2.0
	joystick_direction = diff / joystick_max_distance
	joystick_input.emit(joystick_direction)

	Input.action_release("move_forward")
	Input.action_release("move_backward")
	Input.action_release("move_left")
	Input.action_release("move_right")

	if joystick_direction.y < -0.25: Input.action_press("move_forward")
	if joystick_direction.y > 0.25: Input.action_press("move_backward")
	if joystick_direction.x < -0.25: Input.action_press("move_left")
	if joystick_direction.x > 0.25: Input.action_press("move_right")
