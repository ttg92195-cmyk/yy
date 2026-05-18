extends CanvasLayer
## HUD - Horror themed heads-up display
## Shows: Keys collected, flashlight battery, health, ghost proximity warning

# UI Elements
var keys_container: HBoxContainer
var key_indicators: Dictionary = {}
var battery_bar: ProgressBar
var battery_label: Label
var health_overlay: ColorRect
var ghost_warning: Panel
var ghost_warning_label: Label
var status_label: Label
var crosshair: CenterContainer
var interact_prompt: Label

# Animation
var warning_anim_time: float = 0.0
var health_flash_time: float = 0.0
var is_ghost_near: bool = false

func _ready():
	layer = 5
	_create_hud()


func _create_hud():
	## Create the horror HUD layout

	# ---- TOP AREA: Keys collected ----
	var top_panel = Panel.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_panel.offset_left = 10
	top_panel.offset_right = 350
	top_panel.offset_top = 10
	top_panel.offset_bottom = 65
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.02, 0.01, 0.03, 0.7)
	top_style.border_color = Color(0.3, 0.1, 0.1, 0.5)
	top_style.border_width_bottom = 1
	top_style.border_width_top = 1
	top_style.border_width_left = 1
	top_style.border_width_right = 1
	top_style.corner_radius_top_left = 5
	top_style.corner_radius_top_right = 5
	top_style.corner_radius_bottom_left = 5
	top_style.corner_radius_bottom_right = 5
	top_panel.add_theme_stylebox_override("panel", top_style)
	add_child(top_panel)

	# Keys label
	var keys_label = Label.new()
	keys_label.text = "KEYS:"
	keys_label.position = Vector2(10, 5)
	keys_label.add_theme_font_size_override("font_size", 16)
	keys_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.7))
	top_panel.add_child(keys_label)

	# Key indicators container
	keys_container = HBoxContainer.new()
	keys_container.position = Vector2(10, 28)
	keys_container.add_theme_constant_override("separation", 8)
	top_panel.add_child(keys_container)

	# Create key indicators
	_create_key_indicator("key_red", Color(1, 0.2, 0.2), "R")
	_create_key_indicator("key_blue", Color(0.2, 0.4, 1), "B")
	_create_key_indicator("key_green", Color(0.2, 1, 0.2), "G")
	_create_key_indicator("car_key", Color(1, 0.9, 0.2), "C")

	# ---- TOP RIGHT: Flashlight battery ----
	var battery_panel = Panel.new()
	battery_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	battery_panel.offset_left = -200
	battery_panel.offset_right = -10
	battery_panel.offset_top = 10
	battery_panel.offset_bottom = 70
	var batt_style = StyleBoxFlat.new()
	batt_style.bg_color = Color(0.02, 0.01, 0.03, 0.7)
	batt_style.border_color = Color(0.3, 0.1, 0.1, 0.5)
	batt_style.border_width_bottom = 1
	batt_style.border_width_top = 1
	batt_style.border_width_left = 1
	batt_style.border_width_right = 1
	batt_style.corner_radius_top_left = 5
	batt_style.corner_radius_top_right = 5
	batt_style.corner_radius_bottom_left = 5
	batt_style.corner_radius_bottom_right = 5
	battery_panel.add_theme_stylebox_override("panel", batt_style)
	add_child(battery_panel)

	# Flashlight icon label
	var flash_label = Label.new()
	flash_label.text = "FLASHLIGHT"
	flash_label.position = Vector2(10, 3)
	flash_label.add_theme_font_size_override("font_size", 12)
	flash_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	battery_panel.add_child(flash_label)

	battery_bar = ProgressBar.new()
	battery_bar.position = Vector2(10, 22)
	battery_bar.size = Vector2(170, 18)
	battery_bar.min_value = 0
	battery_bar.max_value = 100
	battery_bar.value = 100
	battery_bar.show_percentage = false
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	battery_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.8, 0.7, 0.2)
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	battery_bar.add_theme_stylebox_override("fill", bar_fill)
	battery_panel.add_child(battery_bar)

	battery_label = Label.new()
	battery_label.position = Vector2(75, 23)
	battery_label.text = "100%"
	battery_label.add_theme_font_size_override("font_size", 12)
	battery_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	battery_panel.add_child(battery_label)

	# ---- CENTER: Crosshair ----
	crosshair = CenterContainer.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -10
	crosshair.offset_right = 10
	crosshair.offset_top = -10
	crosshair.offset_bottom = 10
	add_child(crosshair)

	var dot = ColorRect.new()
	dot.size = Vector2(3, 3)
	dot.position = Vector2(-1.5, -1.5)
	dot.color = Color(1, 1, 1, 0.5)
	crosshair.add_child(dot)

	# ---- CENTER: Interact prompt ----
	interact_prompt = Label.new()
	interact_prompt.set_anchors_preset(Control.PRESET_CENTER)
	interact_prompt.offset_left = -100
	interact_prompt.offset_right = 100
	interact_prompt.offset_top = 30
	interact_prompt.offset_bottom = 55
	interact_prompt.text = ""
	interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_prompt.add_theme_font_size_override("font_size", 18)
	interact_prompt.add_theme_color_override("font_color", Color(1, 1, 0.7, 0.9))
	interact_prompt.visible = false
	add_child(interact_prompt)

	# ---- BOTTOM CENTER: Ghost proximity warning ----
	ghost_warning = Panel.new()
	ghost_warning.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ghost_warning.offset_left = 50
	ghost_warning.offset_right = -50
	ghost_warning.offset_top = -40
	ghost_warning.offset_bottom = -5
	ghost_warning.visible = false
	var warn_style = StyleBoxFlat.new()
	warn_style.bg_color = Color(0.3, 0.0, 0.0, 0.0)
	ghost_warning.add_theme_stylebox_override("panel", warn_style)
	add_child(ghost_warning)

	ghost_warning_label = Label.new()
	ghost_warning_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	ghost_warning_label.text = "!! GHOST IS NEAR !!"
	ghost_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ghost_warning_label.add_theme_font_size_override("font_size", 22)
	ghost_warning_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	ghost_warning.add_child(ghost_warning_label)

	# ---- FULL SCREEN: Health overlay (red tint when hurt) ----
	health_overlay = ColorRect.new()
	health_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	health_overlay.color = Color(0.5, 0, 0, 0)
	health_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(health_overlay)

	# ---- Status text ----
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.offset_left = 10
	status_label.offset_top = -30
	status_label.offset_bottom = -5
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))
	add_child(status_label)


func _create_key_indicator(key_name: String, color: Color, letter: String):
	## Create a key indicator box
	var indicator = Panel.new()
	indicator.custom_minimum_size = Vector2(35, 25)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_color = Color(0.2, 0.2, 0.2, 0.5)
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	indicator.add_theme_stylebox_override("panel", style)
	keys_container.add_child(indicator)

	# Key letter
	var letter_label = Label.new()
	letter_label.text = letter
	letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	letter_label.add_theme_font_size_override("font_size", 14)
	letter_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))  # Dim when not collected
	indicator.add_child(letter_label)

	key_indicators[key_name] = {
		"panel": indicator,
		"label": letter_label,
		"color": color,
		"collected": false
	}


func _process(delta):
	# Update battery bar
	if battery_bar:
		battery_bar.value = GameManager.flashlight_battery
		if battery_label:
			battery_label.text = "%.0f%%" % GameManager.flashlight_battery

		# Color changes based on battery level
		var fill_style = battery_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if GameManager.flashlight_battery > 50:
				fill_style.bg_color = Color(0.8, 0.7, 0.2)
			elif GameManager.flashlight_battery > 20:
				fill_style.bg_color = Color(0.8, 0.5, 0.1)
			else:
				fill_style.bg_color = Color(0.8, 0.2, 0.1)

	# Update key indicators
	for key_name in GameManager.required_items:
		if key_indicators.has(key_name):
			var ki = key_indicators[key_name]
			if GameManager.required_items[key_name] and not ki.collected:
				ki.collected = true
				# Light up the key indicator
				var style = ki.panel.get_theme_stylebox("panel") as StyleBoxFlat
				if style:
					style.bg_color = Color(ki.color.r * 0.3, ki.color.g * 0.3, ki.color.b * 0.3, 0.9)
					style.border_color = ki.color
					style.border_width_bottom = 2
					style.border_width_top = 2
					style.border_width_left = 2
					style.border_width_right = 2
				ki.label.add_theme_color_override("font_color", ki.color)

	# Check ghost proximity
	var ghost = get_tree().get_first_node_in_group("ghost")
	if ghost:
		var players = get_tree().get_nodes_in_group("player")
		for player in players:
			if player.is_local_player:
				var dist = player.global_position.distance_to(ghost.global_position)
				if dist < 15.0:
					is_ghost_near = true
					ghost_warning.visible = true
					# Pulse warning
					warning_anim_time += delta
					var alpha = (sin(warning_anim_time * 5.0) + 1.0) / 2.0
					ghost_warning_label.add_theme_color_override("font_color", Color(1, 0.2 * alpha, 0.2 * alpha))
					var warn_style = ghost_warning.get_theme_stylebox("panel") as StyleBoxFlat
					if warn_style:
						warn_style.bg_color = Color(0.3, 0, 0, alpha * 0.3)
				else:
					is_ghost_near = false
					ghost_warning.visible = false
					warning_anim_time = 0.0
				break
	else:
		ghost_warning.visible = false
		is_ghost_near = false

	# Health overlay fade
	if health_overlay.color.a > 0:
		health_overlay.color.a = max(0, health_overlay.color.a - delta * 0.5)

	# All keys collected message
	if GameManager.escape_door_unlocked and status_label:
		status_label.text = "All keys collected! Find the ESCAPE DOOR!"
		status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))


func show_damage_effect():
	## Flash red when taking damage
	health_overlay.color = Color(0.5, 0, 0, 0.4)


func show_interact_prompt(text: String):
	interact_prompt.text = text
	interact_prompt.visible = true


func hide_interact_prompt():
	interact_prompt.visible = false
