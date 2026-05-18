extends CanvasLayer
## HUD - MOBILE-OPTIMIZED horror heads-up display
## Optimizations:
## - Throttled _process (updates every 0.2s instead of every frame)
## - Fixed ghost proximity detection bug
## - Simpler warning animation

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
var is_ghost_near: bool = false
var update_timer: float = 0.0
var update_interval: float = 0.2  # Update every 0.2s instead of every frame

func _ready():
	layer = 5
	_create_hud()


func _create_hud():
	# ---- TOP LEFT: Keys collected ----
	var top_panel = Panel.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_panel.offset_left = 10
	top_panel.offset_right = 280
	top_panel.offset_top = 10
	top_panel.offset_bottom = 55
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

	var keys_label = Label.new()
	keys_label.text = "KEYS:"
	keys_label.position = Vector2(10, 5)
	keys_label.add_theme_font_size_override("font_size", 14)
	keys_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.7))
	top_panel.add_child(keys_label)

	keys_container = HBoxContainer.new()
	keys_container.position = Vector2(10, 25)
	keys_container.add_theme_constant_override("separation", 6)
	top_panel.add_child(keys_container)

	_create_key_indicator("key_red", Color(1, 0.2, 0.2), "R")
	_create_key_indicator("key_blue", Color(0.2, 0.4, 1), "B")
	_create_key_indicator("key_green", Color(0.2, 1, 0.2), "G")
	_create_key_indicator("car_key", Color(1, 0.9, 0.2), "C")

	# ---- TOP RIGHT: Flashlight battery ----
	var battery_panel = Panel.new()
	battery_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	battery_panel.offset_left = -180
	battery_panel.offset_right = -10
	battery_panel.offset_top = 10
	battery_panel.offset_bottom = 60
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

	var flash_label = Label.new()
	flash_label.text = "FLASHLIGHT"
	flash_label.position = Vector2(10, 3)
	flash_label.add_theme_font_size_override("font_size", 11)
	flash_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	battery_panel.add_child(flash_label)

	battery_bar = ProgressBar.new()
	battery_bar.position = Vector2(10, 20)
	battery_bar.size = Vector2(150, 16)
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
	battery_label.position = Vector2(65, 21)
	battery_label.text = "100%"
	battery_label.add_theme_font_size_override("font_size", 11)
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
	interact_prompt.add_theme_font_size_override("font_size", 16)
	interact_prompt.add_theme_color_override("font_color", Color(1, 1, 0.7, 0.9))
	interact_prompt.visible = false
	add_child(interact_prompt)

	# ---- BOTTOM CENTER: Ghost proximity warning ----
	ghost_warning = Panel.new()
	ghost_warning.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ghost_warning.offset_left = 50
	ghost_warning.offset_right = -50
	ghost_warning.offset_top = -35
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
	ghost_warning_label.add_theme_font_size_override("font_size", 20)
	ghost_warning_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	ghost_warning.add_child(ghost_warning_label)

	# ---- FULL SCREEN: Health overlay ----
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
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))
	add_child(status_label)


func _create_key_indicator(key_name: String, color: Color, letter: String):
	var indicator = Panel.new()
	indicator.custom_minimum_size = Vector2(30, 22)
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

	var letter_label = Label.new()
	letter_label.text = letter
	letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	letter_label.add_theme_font_size_override("font_size", 13)
	letter_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	indicator.add_child(letter_label)

	key_indicators[key_name] = {
		"panel": indicator,
		"label": letter_label,
		"color": color,
		"collected": false
	}


func _process(delta):
	# Throttle HUD updates to save CPU
	update_timer += delta
	if update_timer < update_interval:
		# Still animate warning even between updates
		if is_ghost_near:
			warning_anim_time += delta
			var alpha = (sin(warning_anim_time * 5.0) + 1.0) / 2.0
			ghost_warning_label.add_theme_color_override("font_color", Color(1, 0.2 * alpha, 0.2 * alpha))
		return

	update_timer = 0.0

	# Update battery bar
	if battery_bar:
		battery_bar.value = GameManager.flashlight_battery
		if battery_label:
			battery_label.text = "%.0f%%" % GameManager.flashlight_battery

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
				var style = ki.panel.get_theme_stylebox("panel") as StyleBoxFlat
				if style:
					style.bg_color = Color(ki.color.r * 0.3, ki.color.g * 0.3, ki.color.b * 0.3, 0.9)
					style.border_color = ki.color
					style.border_width_bottom = 2
					style.border_width_top = 2
					style.border_width_left = 2
					style.border_width_right = 2
				ki.label.add_theme_color_override("font_color", ki.color)

	# Check ghost proximity (FIXED bug)
	var ghost = get_tree().get_first_node_in_group("ghost")
	if ghost:
		var players = get_tree().get_nodes_in_group("player")
		var found_near = false
		for player in players:
			if player.is_local_player:
				var dist = player.global_position.distance_to(ghost.global_position)
				if dist < 15.0:
					found_near = true
				break

		if found_near:
			is_ghost_near = true
			ghost_warning.visible = true
		else:
			is_ghost_near = false
			ghost_warning.visible = false
			warning_anim_time = 0.0
	else:
		ghost_warning.visible = false
		is_ghost_near = false

	# Health overlay fade
	if health_overlay.color.a > 0:
		health_overlay.color.a = max(0, health_overlay.color.a - delta * 0.5)

	# All keys collected message
	if GameManager.escape_door_unlocked and status_label:
		status_label.text = "All keys collected! Find the EXIT!"
		status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))


func show_damage_effect():
	health_overlay.color = Color(0.5, 0, 0, 0.4)


func show_interact_prompt(text: String):
	interact_prompt.text = text
	interact_prompt.visible = true


func hide_interact_prompt():
	interact_prompt.visible = false
