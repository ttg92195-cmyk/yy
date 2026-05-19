extends CanvasLayer
## TouchControls - Horror themed mobile touch controls
## D-pad style movement (not circular joystick) + action buttons
## Dark horror theme with red accents

signal joystick_input(direction: Vector2)

# D-pad state
var dpad_active: bool = false
var dpad_direction: Vector2 = Vector2.ZERO
var dpad_touch_id: int = -1

# Look
var look_sensitivity: float = 0.004
var last_touch_pos: Vector2 = Vector2.ZERO
var look_touch_id: int = -1

# UI elements
var dpad_container: Control
var dpad_up: Panel
var dpad_down: Panel
var dpad_left: Panel
var dpad_right: Panel
var dpad_center: Panel
var btn_sprint: Button
var btn_flashlight: Button
var btn_interact: Button

var root_control: Control
var screen_width: float = 960.0
var screen_height: float = 540.0

# D-pad position and size
var dpad_size: float = 44.0
var dpad_gap: float = 3.0


func _ready():
	layer = 10
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.name = "TouchRoot"
	add_child(root_control)
	_create_dpad()
	_create_buttons()


func _create_dpad():
	## Create D-pad (cross shape) instead of circular joystick
	dpad_container = Control.new()
	dpad_container.name = "DPadContainer"
	dpad_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	dpad_container.offset_left = 10
	dpad_container.offset_top = -185
	dpad_container.offset_right = 170
	dpad_container.offset_bottom = -10
	dpad_container.mouse_filter = Control.MOUSE_FILTER_PASS

	var base_x = 20.0
	var base_y = 20.0

	# D-pad style colors
	var arrow_normal = Color(0.12, 0.04, 0.06, 0.65)
	var arrow_border = Color(0.5, 0.1, 0.1, 0.6)

	# Center button
	dpad_center = Panel.new()
	dpad_center.position = Vector2(base_x + dpad_size + dpad_gap, base_y + dpad_size + dpad_gap)
	dpad_center.size = Vector2(dpad_size, dpad_size)
	dpad_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dpad_center.add_theme_stylebox_override("panel", _make_style(arrow_normal, arrow_border, 4))
	dpad_container.add_child(dpad_center)

	# Up arrow
	dpad_up = Panel.new()
	dpad_up.position = Vector2(base_x + dpad_size + dpad_gap, base_y)
	dpad_up.size = Vector2(dpad_size, dpad_size)
	dpad_up.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dpad_up.add_theme_stylebox_override("panel", _make_style(arrow_normal, arrow_border, 6))
	# Arrow label
	var up_label = Label.new()
	up_label.text = "^"
	up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	up_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	up_label.add_theme_font_size_override("font_size", 22)
	up_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 0.8))
	dpad_up.add_child(up_label)
	dpad_container.add_child(dpad_up)

	# Down arrow
	dpad_down = Panel.new()
	dpad_down.position = Vector2(base_x + dpad_size + dpad_gap, base_y + (dpad_size + dpad_gap) * 2)
	dpad_down.size = Vector2(dpad_size, dpad_size)
	dpad_down.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dpad_down.add_theme_stylebox_override("panel", _make_style(arrow_normal, arrow_border, 6))
	var down_label = Label.new()
	down_label.text = "v"
	down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	down_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	down_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	down_label.add_theme_font_size_override("font_size", 22)
	down_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 0.8))
	dpad_down.add_child(down_label)
	dpad_container.add_child(dpad_down)

	# Left arrow
	dpad_left = Panel.new()
	dpad_left.position = Vector2(base_x, base_y + dpad_size + dpad_gap)
	dpad_left.size = Vector2(dpad_size, dpad_size)
	dpad_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dpad_left.add_theme_stylebox_override("panel", _make_style(arrow_normal, arrow_border, 6))
	var left_label = Label.new()
	left_label.text = "<"
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_label.add_theme_font_size_override("font_size", 22)
	left_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 0.8))
	dpad_left.add_child(left_label)
	dpad_container.add_child(dpad_left)

	# Right arrow
	dpad_right = Panel.new()
	dpad_right.position = Vector2(base_x + (dpad_size + dpad_gap) * 2, base_y + dpad_size + dpad_gap)
	dpad_right.size = Vector2(dpad_size, dpad_size)
	dpad_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dpad_right.add_theme_stylebox_override("panel", _make_style(arrow_normal, arrow_border, 6))
	var right_label = Label.new()
	right_label.text = ">"
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_label.add_theme_font_size_override("font_size", 22)
	right_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 0.8))
	dpad_right.add_child(right_label)
	dpad_container.add_child(dpad_right)

	root_control.add_child(dpad_container)


func _create_buttons():
	## Horror-styled action buttons
	var btn_container = Control.new()
	btn_container.name = "ButtonContainer"
	btn_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_container.offset_left = -200
	btn_container.offset_top = -175
	btn_container.offset_right = -10
	btn_container.offset_bottom = -10
	btn_container.mouse_filter = Control.MOUSE_FILTER_PASS

	var btn_size = Vector2(55, 55)

	# Sprint button (RUN) - bottom right
	btn_sprint = Button.new()
	btn_sprint.text = "RUN"
	btn_sprint.position = Vector2(80, 95)
	btn_sprint.size = btn_size
	btn_sprint.add_theme_stylebox_override("normal", _make_btn_style(Color(0.18, 0.04, 0.04, 0.7), Color(0.6, 0.12, 0.08, 0.8)))
	btn_sprint.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.4, 0.08, 0.08, 0.9), Color(1, 0.3, 0.15, 1.0)))
	btn_sprint.add_theme_stylebox_override("hover", _make_btn_style(Color(0.28, 0.06, 0.06, 0.8), Color(0.8, 0.18, 0.12, 0.9)))
	btn_sprint.add_theme_color_override("font_color", Color(1, 0.5, 0.4, 0.9))
	btn_sprint.add_theme_color_override("font_hover_color", Color(1, 0.7, 0.5))
	btn_sprint.add_theme_font_size_override("font_size", 13)
	btn_sprint.button_down.connect(func(): Input.action_press("sprint"))
	btn_sprint.button_up.connect(func(): Input.action_release("sprint"))
	btn_container.add_child(btn_sprint)

	# Interact button (USE) - bottom left of button group
	btn_interact = Button.new()
	btn_interact.text = "USE"
	btn_interact.position = Vector2(10, 95)
	btn_interact.size = btn_size
	btn_interact.add_theme_stylebox_override("normal", _make_btn_style(Color(0.04, 0.12, 0.04, 0.7), Color(0.1, 0.5, 0.12, 0.8)))
	btn_interact.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.08, 0.28, 0.08, 0.9), Color(0.2, 0.8, 0.25, 1.0)))
	btn_interact.add_theme_stylebox_override("hover", _make_btn_style(Color(0.06, 0.18, 0.06, 0.8), Color(0.15, 0.6, 0.18, 0.9)))
	btn_interact.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 0.9))
	btn_interact.add_theme_color_override("font_hover_color", Color(0.7, 1, 0.7))
	btn_interact.add_theme_font_size_override("font_size", 13)
	btn_interact.pressed.connect(_on_interact_pressed)
	btn_container.add_child(btn_interact)

	# Flashlight button (LIGHT) - top center of button group
	btn_flashlight = Button.new()
	btn_flashlight.text = "LIGHT"
	btn_flashlight.position = Vector3(45, 25, 0) if false else Vector2(45, 25)
	btn_flashlight.size = btn_size
	btn_flashlight.add_theme_stylebox_override("normal", _make_btn_style(Color(0.12, 0.10, 0.02, 0.7), Color(0.5, 0.4, 0.1, 0.8)))
	btn_flashlight.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.28, 0.22, 0.04, 0.9), Color(0.9, 0.7, 0.15, 1.0)))
	btn_flashlight.add_theme_stylebox_override("hover", _make_btn_style(Color(0.18, 0.16, 0.03, 0.8), Color(0.7, 0.55, 0.12, 0.9)))
	btn_flashlight.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 0.9))
	btn_flashlight.add_theme_color_override("font_hover_color", Color(1, 1, 0.7))
	btn_flashlight.add_theme_font_size_override("font_size", 11)
	btn_flashlight.pressed.connect(_on_flashlight_pressed)
	btn_container.add_child(btn_flashlight)

	root_control.add_child(btn_container)


func _make_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _make_btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.2, 0.05, 0.05, 0.3)
	style.shadow_size = 3
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
			# D-pad area
			dpad_touch_id = event.index
			dpad_active = true
			_update_dpad(event.position)
		else:
			# Look area
			if look_touch_id == -1:
				look_touch_id = event.index
				last_touch_pos = event.position
	else:
		if event.index == dpad_touch_id:
			dpad_touch_id = -1
			dpad_active = false
			dpad_direction = Vector2.ZERO
			joystick_input.emit(Vector2.ZERO)
			Input.action_release("move_forward")
			Input.action_release("move_backward")
			Input.action_release("move_left")
			Input.action_release("move_right")
			# Reset D-pad visual
			_reset_dpad_visual()
		elif event.index == look_touch_id:
			look_touch_id = -1


func _handle_drag(event: InputEventScreenDrag):
	if event.index == dpad_touch_id:
		_update_dpad(event.position)
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
	if btn_sprint and btn_sprint.get_global_rect().has_point(pos):
		return true
	if btn_flashlight and btn_flashlight.get_global_rect().has_point(pos):
		return true
	if btn_interact and btn_interact.get_global_rect().has_point(pos):
		return true
	return false


func _update_dpad(touch_pos: Vector2):
	## Calculate which D-pad direction is pressed based on touch position
	var center = Vector2(
		dpad_container.global_position.x + dpad_center.position.x + dpad_size / 2.0,
		dpad_container.global_position.y + dpad_center.position.y + dpad_size / 2.0
	)
	var diff = touch_pos - center

	# Determine direction based on angle and distance
	dpad_direction = Vector2.ZERO
	if diff.length() > 10:
		if abs(diff.x) > abs(diff.y):
			dpad_direction.x = 1.0 if diff.x > 0 else -1.0
			dpad_direction.y = 0.3 if diff.y > 0 else -0.3
		else:
			dpad_direction.y = 1.0 if diff.y > 0 else -1.0
			dpad_direction.x = 0.3 if diff.x > 0 else -0.3

	joystick_input.emit(dpad_direction)

	Input.action_release("move_forward")
	Input.action_release("move_backward")
	Input.action_release("move_left")
	Input.action_release("move_right")

	if dpad_direction.y < -0.25:
		Input.action_press("move_forward")
	if dpad_direction.y > 0.25:
		Input.action_press("move_backward")
	if dpad_direction.x < -0.25:
		Input.action_press("move_left")
	if dpad_direction.x > 0.25:
		Input.action_press("move_right")

	# Highlight active direction
	_update_dpad_visual()


func _update_dpad_visual():
	## Highlight the currently pressed D-pad direction
	var active_color = Color(0.35, 0.08, 0.08, 0.85)
	var active_border = Color(0.9, 0.2, 0.15, 0.9)
	var normal_color = Color(0.12, 0.04, 0.06, 0.65)
	var normal_border = Color(0.5, 0.1, 0.1, 0.6)

	if dpad_up:
		var s = dpad_up.get_theme_stylebox("panel") as StyleBoxFlat
		if s:
			s.bg_color = active_color if dpad_direction.y < -0.25 else normal_color
			s.border_color = active_border if dpad_direction.y < -0.25 else normal_border
	if dpad_down:
		var s = dpad_down.get_theme_stylebox("panel") as StyleBoxFlat
		if s:
			s.bg_color = active_color if dpad_direction.y > 0.25 else normal_color
			s.border_color = active_border if dpad_direction.y > 0.25 else normal_border
	if dpad_left:
		var s = dpad_left.get_theme_stylebox("panel") as StyleBoxFlat
		if s:
			s.bg_color = active_color if dpad_direction.x < -0.25 else normal_color
			s.border_color = active_border if dpad_direction.x < -0.25 else normal_border
	if dpad_right:
		var s = dpad_right.get_theme_stylebox("panel") as StyleBoxFlat
		if s:
			s.bg_color = active_color if dpad_direction.x > 0.25 else normal_color
			s.border_color = active_border if dpad_direction.x > 0.25 else normal_border


func _reset_dpad_visual():
	var normal_color = Color(0.12, 0.04, 0.06, 0.65)
	var normal_border = Color(0.5, 0.1, 0.1, 0.6)
	for panel in [dpad_up, dpad_down, dpad_left, dpad_right]:
		if panel:
			var s = panel.get_theme_stylebox("panel") as StyleBoxFlat
			if s:
				s.bg_color = normal_color
				s.border_color = normal_border
