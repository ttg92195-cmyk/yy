extends CanvasLayer
## HUD - Horror themed heads-up display
## Dark horror style with red accents
## Throttled updates for mobile performance

var keys_container: HBoxContainer
var key_indicators: Dictionary = {}
var battery_bar: ProgressBar
var battery_label: Label
var ghost_warning: Label
var status_label: Label
var crosshair: CenterContainer

var is_ghost_near: bool = false
var update_timer: float = 0.0
var warning_anim_time: float = 0.0

func _ready():
	layer = 5
	_create_hud()


func _create_hud():
	# ---- TOP LEFT: Keys ----
	var top_panel = Panel.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_panel.offset_left = 8
	top_panel.offset_right = 260
	top_panel.offset_top = 8
	top_panel.offset_bottom = 52
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.03, 0.01, 0.01, 0.75)
	top_style.border_color = Color(0.4, 0.1, 0.1, 0.6)
	top_style.border_width_bottom = 1
	top_style.border_width_top = 1
	top_style.border_width_left = 1
	top_style.border_width_right = 1
	top_style.corner_radius_top_left = 4
	top_style.corner_radius_top_right = 4
	top_style.corner_radius_bottom_left = 4
	top_style.corner_radius_bottom_right = 4
	top_panel.add_theme_stylebox_override("panel", top_style)
	add_child(top_panel)

	var keys_label = Label.new()
	keys_label.text = "KEYS:"
	keys_label.position = Vector2(8, 4)
	keys_label.add_theme_font_size_override("font_size", 13)
	keys_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))
	top_panel.add_child(keys_label)

	keys_container = HBoxContainer.new()
	keys_container.position = Vector2(8, 22)
	keys_container.add_theme_constant_override("separation", 5)
	top_panel.add_child(keys_container)

	_create_key_indicator("key_red", Color(1, 0.2, 0.2), "R")
	_create_key_indicator("key_blue", Color(0.3, 0.5, 1), "B")
	_create_key_indicator("key_green", Color(0.2, 1, 0.3), "G")
	_create_key_indicator("car_key", Color(1, 0.85, 0.2), "C")

	# ---- TOP RIGHT: Battery ----
	var battery_panel = Panel.new()
	battery_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	battery_panel.offset_left = -170
	battery_panel.offset_right = -8
	battery_panel.offset_top = 8
	battery_panel.offset_bottom = 52
	var batt_style = StyleBoxFlat.new()
	batt_style.bg_color = Color(0.03, 0.01, 0.01, 0.75)
	batt_style.border_color = Color(0.4, 0.1, 0.1, 0.6)
	batt_style.border_width_bottom = 1
	batt_style.border_width_top = 1
	batt_style.border_width_left = 1
	batt_style.border_width_right = 1
	batt_style.corner_radius_top_left = 4
	batt_style.corner_radius_top_right = 4
	batt_style.corner_radius_bottom_left = 4
	batt_style.corner_radius_bottom_right = 4
	battery_panel.add_theme_stylebox_override("panel", batt_style)
	add_child(battery_panel)

	var flash_label = Label.new()
	flash_label.text = "BATTERY"
	flash_label.position = Vector2(8, 2)
	flash_label.add_theme_font_size_override("font_size", 10)
	flash_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	battery_panel.add_child(flash_label)

	battery_bar = ProgressBar.new()
	battery_bar.position = Vector2(8, 18)
	battery_bar.size = Vector2(140, 14)
	battery_bar.min_value = 0
	battery_bar.max_value = 100
	battery_bar.value = 100
	battery_bar.show_percentage = false
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.05, 0.05, 0.8)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	battery_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.8, 0.6, 0.15)
	bar_fill.corner_radius_top_left = 2
	bar_fill.corner_radius_top_right = 2
	bar_fill.corner_radius_bottom_left = 2
	bar_fill.corner_radius_bottom_right = 2
	battery_bar.add_theme_stylebox_override("fill", bar_fill)
	battery_panel.add_child(battery_bar)

	battery_label = Label.new()
	battery_label.position = Vector2(58, 19)
	battery_label.text = "100%"
	battery_label.add_theme_font_size_override("font_size", 10)
	battery_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	battery_panel.add_child(battery_label)

	# ---- CENTER: Crosshair ----
	crosshair = CenterContainer.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -8
	crosshair.offset_right = 8
	crosshair.offset_top = -8
	crosshair.offset_bottom = 8
	add_child(crosshair)

	var dot = ColorRect.new()
	dot.size = Vector2(4, 4)
	dot.position = Vector2(-2, -2)
	dot.color = Color(0.8, 0.2, 0.2, 0.6)
	crosshair.add_child(dot)

	# ---- BOTTOM CENTER: Ghost warning ----
	ghost_warning = Label.new()
	ghost_warning.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ghost_warning.offset_left = 60
	ghost_warning.offset_right = -60
	ghost_warning.offset_top = -35
	ghost_warning.offset_bottom = -8
	ghost_warning.text = "!! GHOST IS NEAR !!"
	ghost_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost_warning.add_theme_font_size_override("font_size", 18)
	ghost_warning.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
	ghost_warning.visible = false
	add_child(ghost_warning)

	# ---- BOTTOM LEFT: Status ----
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.offset_left = 8
	status_label.offset_top = -28
	status_label.offset_bottom = -5
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
	add_child(status_label)


func _create_key_indicator(key_name: String, color: Color, letter: String):
	var indicator = Panel.new()
	indicator.custom_minimum_size = Vector2(28, 20)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.04, 0.04, 0.8)
	style.border_color = Color(0.2, 0.1, 0.1, 0.5)
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	indicator.add_theme_stylebox_override("panel", style)
	keys_container.add_child(indicator)

	var letter_label = Label.new()
	letter_label.text = letter
	letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	letter_label.add_theme_font_size_override("font_size", 12)
	letter_label.add_theme_color_override("font_color", Color(0.3, 0.2, 0.2))
	indicator.add_child(letter_label)

	key_indicators[key_name] = {"panel": indicator, "label": letter_label, "color": color, "collected": false}


func _process(delta):
	# Throttle updates
	update_timer += delta
	if update_timer < 0.25:
		# Only animate warning
		if is_ghost_near:
			warning_anim_time += delta
			var alpha = (sin(warning_anim_time * 5.0) + 1.0) / 2.0
			ghost_warning.add_theme_color_override("font_color", Color(1, 0.15 * alpha, 0.15 * alpha))
		return
	update_timer = 0.0

	# Battery
	if battery_bar:
		battery_bar.value = GameManager.flashlight_battery
		if battery_label:
			battery_label.text = "%.0f%%" % GameManager.flashlight_battery
		var fill = battery_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			if GameManager.flashlight_battery > 50: fill.bg_color = Color(0.8, 0.6, 0.15)
			elif GameManager.flashlight_battery > 20: fill.bg_color = Color(0.8, 0.4, 0.1)
			else: fill.bg_color = Color(0.8, 0.15, 0.1)

	# Keys
	for key_name in GameManager.required_items:
		if key_indicators.has(key_name):
			var ki = key_indicators[key_name]
			if GameManager.required_items[key_name] and not ki.collected:
				ki.collected = true
				var style = ki.panel.get_theme_stylebox("panel") as StyleBoxFlat
				if style:
					style.bg_color = Color(ki.color.r*0.3, ki.color.g*0.3, ki.color.b*0.3, 0.9)
					style.border_color = ki.color
				ki.label.add_theme_color_override("font_color", ki.color)

	# Ghost proximity
	var ghost = get_tree().get_first_node_in_group("ghost")
	if ghost:
		var players = get_tree().get_nodes_in_group("player")
		var found = false
		for p in players:
			if p.is_local_player:
				if p.global_position.distance_to(ghost.global_position) < 15.0:
					found = true
				break
		is_ghost_near = found
		ghost_warning.visible = found
		if not found: warning_anim_time = 0.0
	else:
		ghost_warning.visible = false
		is_ghost_near = false

	# Status
	if GameManager.escape_door_unlocked and status_label:
		status_label.text = "All keys collected! Find the EXIT!"
		status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))


func show_damage_effect():
	pass
