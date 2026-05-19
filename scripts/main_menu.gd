extends Control
# MainMenu V6 - Horror themed main menu

var title_label: Label
var subtitle_label: Label
var version_label: Label
var host_button: Button
var join_button: Button
var ai_ghost_button: Button
var settings_button: Button
var quit_button: Button
var status_label: Label

var join_panel: Panel
var ip_input: LineEdit
var name_input: LineEdit
var connect_button: Button
var back_button: Button

var host_panel: Panel
var host_name_input: LineEdit
var start_button: Button
var host_back_button: Button
var player_list: VBoxContainer

var title_anim_time: float = 0.0


func _ready():
	_create_ui()

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	ai_ghost_button.pressed.connect(_on_ai_ghost_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	back_button.pressed.connect(_on_back_from_join)
	start_button.pressed.connect(_on_start_game)
	host_back_button.pressed.connect(_on_back_from_host)

	join_panel.visible = false
	host_panel.visible = false
	status_label.text = ""


func _create_ui():
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.01, 0.03)
	add_child(bg)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_CENTER)
	main_vbox.offset_left = -200
	main_vbox.offset_right = 200
	main_vbox.offset_top = -250
	main_vbox.offset_bottom = 250
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	title_label = Label.new()
	title_label.text = "THE GHOST"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	title_label.add_theme_color_override("font_shadow_color", Color(0.3, 0.0, 0.0))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	main_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Can you escape?"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4))
	main_vbox.add_child(subtitle_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.05, 0.12, 0.8)
	btn_style.border_color = Color(0.4, 0.1, 0.1, 0.8)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(5)
	btn_style.content_margin_top = 10
	btn_style.content_margin_bottom = 10
	btn_style.content_margin_left = 20
	btn_style.content_margin_right = 20

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.2, 0.08, 0.15, 0.9)
	btn_hover.border_color = Color(0.7, 0.2, 0.2)

	var btn_pressed_style = btn_style.duplicate()
	btn_pressed_style.bg_color = Color(0.3, 0.1, 0.1, 1.0)

	var ai_btn_style = btn_style.duplicate()
	ai_btn_style.bg_color = Color(0.15, 0.03, 0.03, 0.9)
	ai_btn_style.border_color = Color(0.8, 0.15, 0.1, 1.0)
	ai_btn_style.set_border_width_all(3)

	var ai_hover_style = ai_btn_style.duplicate()
	ai_hover_style.bg_color = Color(0.3, 0.05, 0.05, 1.0)
	ai_hover_style.border_color = Color(1.0, 0.3, 0.2)

	ai_ghost_button = Button.new()
	ai_ghost_button.text = ">> PLAY WITH AI GHOST <<"
	ai_ghost_button.add_theme_stylebox_override("normal", ai_btn_style)
	ai_ghost_button.add_theme_stylebox_override("hover", ai_hover_style)
	ai_ghost_button.add_theme_stylebox_override("pressed", btn_pressed_style)
	ai_ghost_button.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	ai_ghost_button.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.4))
	ai_ghost_button.add_theme_font_size_override("font_size", 22)
	main_vbox.add_child(ai_ghost_button)

	host_button = Button.new()
	host_button.text = "Host Game"
	host_button.add_theme_stylebox_override("normal", btn_style)
	host_button.add_theme_stylebox_override("hover", btn_hover)
	host_button.add_theme_stylebox_override("pressed", btn_pressed_style)
	host_button.add_theme_color_override("font_color", Color(0.8, 0.7, 0.7))
	host_button.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(host_button)

	join_button = Button.new()
	join_button.text = "Join Game"
	join_button.add_theme_stylebox_override("normal", btn_style)
	join_button.add_theme_stylebox_override("hover", btn_hover)
	join_button.add_theme_stylebox_override("pressed", btn_pressed_style)
	join_button.add_theme_color_override("font_color", Color(0.8, 0.7, 0.7))
	join_button.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(join_button)

	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.add_theme_stylebox_override("normal", btn_style)
	settings_button.add_theme_stylebox_override("hover", btn_hover)
	settings_button.add_theme_stylebox_override("pressed", btn_pressed_style)
	settings_button.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))
	settings_button.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(settings_button)

	quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.add_theme_stylebox_override("normal", btn_style)
	quit_button.add_theme_stylebox_override("hover", btn_hover)
	quit_button.add_theme_stylebox_override("pressed", btn_pressed_style)
	quit_button.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4))
	quit_button.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(quit_button)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))
	status_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(status_label)

	version_label = Label.new()
	version_label.text = "v0.6.0 - VISIBLE FIX"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_color_override("font_color", Color(1, 0.5, 0))
	version_label.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(version_label)

	# JOIN PANEL
	join_panel = Panel.new()
	join_panel.set_anchors_preset(Control.PRESET_CENTER)
	join_panel.offset_left = -150
	join_panel.offset_right = 150
	join_panel.offset_top = -120
	join_panel.offset_bottom = 120
	join_panel.visible = false
	var join_panel_style = StyleBoxFlat.new()
	join_panel_style.bg_color = Color(0.05, 0.02, 0.08, 0.95)
	join_panel_style.set_border_width_all(2)
	join_panel.add_theme_stylebox_override("panel", join_panel_style)
	add_child(join_panel)

	var join_vbox = VBoxContainer.new()
	join_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	join_vbox.offset_left = 15
	join_vbox.offset_right = -15
	join_vbox.offset_top = 15
	join_vbox.offset_bottom = -15
	join_vbox.add_theme_constant_override("separation", 10)
	join_panel.add_child(join_vbox)

	var join_title = Label.new()
	join_title.text = "JOIN GAME"
	join_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_title.add_theme_font_size_override("font_size", 24)
	join_title.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	join_vbox.add_child(join_title)

	ip_input = LineEdit.new()
	ip_input.text = "127.0.0.1"
	ip_input.placeholder_text = "Enter IP address"
	join_vbox.add_child(ip_input)

	name_input = LineEdit.new()
	name_input.text = "Player"
	name_input.placeholder_text = "Enter name"
	join_vbox.add_child(name_input)

	connect_button = Button.new()
	connect_button.text = "Connect"
	connect_button.add_theme_stylebox_override("normal", ai_btn_style.duplicate())
	connect_button.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	join_vbox.add_child(connect_button)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.add_theme_stylebox_override("normal", btn_style.duplicate())
	back_button.add_theme_color_override("font_color", Color(0.7, 0.6, 0.6))
	join_vbox.add_child(back_button)

	# HOST PANEL
	host_panel = Panel.new()
	host_panel.set_anchors_preset(Control.PRESET_CENTER)
	host_panel.offset_left = -180
	host_panel.offset_right = 180
	host_panel.offset_top = -180
	host_panel.offset_bottom = 180
	host_panel.visible = false
	var host_panel_style = StyleBoxFlat.new()
	host_panel_style.bg_color = Color(0.05, 0.02, 0.08, 0.95)
	host_panel_style.set_border_width_all(2)
	host_panel.add_theme_stylebox_override("panel", host_panel_style)
	add_child(host_panel)

	var host_vbox = VBoxContainer.new()
	host_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	host_vbox.offset_left = 15
	host_vbox.offset_right = -15
	host_vbox.offset_top = 15
	host_vbox.offset_bottom = -15
	host_vbox.add_theme_constant_override("separation", 8)
	host_panel.add_child(host_vbox)

	var host_title = Label.new()
	host_title.text = "HOST GAME"
	host_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host_title.add_theme_font_size_override("font_size", 24)
	host_title.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	host_vbox.add_child(host_title)

	host_name_input = LineEdit.new()
	host_name_input.text = "Host"
	host_vbox.add_child(host_name_input)

	player_list = VBoxContainer.new()
	host_vbox.add_child(player_list)

	start_button = Button.new()
	start_button.text = "Start Game"
	start_button.add_theme_stylebox_override("normal", ai_btn_style.duplicate())
	start_button.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	host_vbox.add_child(start_button)

	host_back_button = Button.new()
	host_back_button.text = "Back"
	host_back_button.add_theme_stylebox_override("normal", btn_style.duplicate())
	host_back_button.add_theme_color_override("font_color", Color(0.7, 0.6, 0.6))
	host_vbox.add_child(host_back_button)


func _process(delta):
	title_anim_time += delta
	var pulse = (sin(title_anim_time * 2.0) + 1.0) / 2.0
	var r = lerp(0.6, 1.0, pulse)
	title_label.add_theme_color_override("font_color", Color(r, 0.1, 0.1))

	if randf() < 0.01:
		subtitle_label.visible = false
		get_tree().create_timer(0.05).timeout.connect(func(): subtitle_label.visible = true)


func _on_host_pressed():
	var player_name = host_name_input.text
	if player_name == "":
		player_name = "Host"
	if NetworkManager.host_game(player_name):
		status_label.text = "Server started! Waiting for players..."
		GameManager.enter_lobby()
	else:
		status_label.text = "Failed to start server!"


func _on_join_pressed():
	join_panel.visible = true
	host_panel.visible = false


func _on_ai_ghost_pressed():
	status_label.text = "Loading horror game..."
	status_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_connect_pressed():
	var address = ip_input.text
	var player_name = name_input.text
	if address == "":
		status_label.text = "Please enter an IP address!"
		return
	if player_name == "":
		player_name = "Player"
	if NetworkManager.join_game(address, player_name):
		status_label.text = "Connecting to %s..." % address
		GameManager.enter_lobby()
	else:
		status_label.text = "Failed to connect!"


func _on_start_game():
	var player_count = NetworkManager.get_player_count()
	if player_count < 2:
		status_label.text = "Not enough players! Starting with AI ghost..."
		NetworkManager.start_game_ai_ghost()
	else:
		NetworkManager.start_game()


func _on_back_from_join():
	join_panel.visible = false
	status_label.text = ""


func _on_back_from_host():
	NetworkManager.disconnect_game()
	host_panel.visible = false
	status_label.text = ""


func _on_player_connected(peer_id: int, player_info: Dictionary):
	status_label.text = "Player connected: %s" % player_info.get("player_name", "Unknown")
	_update_player_list()


func _on_player_disconnected(_peer_id: int):
	status_label.text = "Player disconnected"
	_update_player_list()


func _on_connection_failed():
	status_label.text = "Connection failed!"
	join_panel.visible = false


func _on_server_disconnected():
	status_label.text = "Disconnected from server!"
	host_panel.visible = false
	join_panel.visible = false


func _update_player_list():
	for child in player_list.get_children():
		child.queue_free()
	for pid in NetworkManager.players:
		var info = NetworkManager.players[pid]
		var label = Label.new()
		label.text = "%s (ID: %d) - %s" % [info.player_name, info.peer_id, info.role]
		label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.6))
		player_list.add_child(label)


func _on_settings_pressed():
	status_label.text = "Settings coming soon!"


func _on_quit_pressed():
	get_tree().quit()
