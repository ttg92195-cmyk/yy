extends CanvasLayer
## HUD - Heads-up display for the game
## Shows: Health/Stamina, Flashlight battery, Items collected, Interaction prompts

@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer/StaminaBar
@onready var flashlight_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer/FlashlightBar
@onready var items_label: Label = $MarginContainer/VBoxContainer/ItemsLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var crosshair: CenterContainer = $Crosshair
@onready var ghost_warning: Panel = $GhostWarning
@onready var role_label: Label = $MarginContainer/VBoxContainer/RoleLabel


func _ready():
	# Initial state
	ghost_warning.visible = false
	status_label.text = ""
	crosshair.visible = false

	# Connect signals
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.item_collected.connect(_on_item_collected)
	GameManager.all_items_collected.connect(_on_all_items_collected)
	GameManager.ghost_victory.connect(_on_ghost_victory)
	GameManager.human_victory.connect(_on_human_victory)


func _process(_delta):
	if GameManager.current_state != GameManager.GameState.PLAYING:
		crosshair.visible = false
		return

	crosshair.visible = true

	# Update stamina bar
	var player = _get_local_player()
	if player:
		stamina_bar.value = player.stamina

	# Update flashlight battery
	flashlight_bar.value = GameManager.flashlight_battery

	# Update items label
	items_label.text = "Items: %d / %d" % [GameManager.items_collected_count, GameManager.total_items_required]

	# Update role label
	if GameManager.is_ghost_player:
		role_label.text = "[ GHOST ]"
		role_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		role_label.text = "[ SURVIVOR ]"
		role_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))

	# Flashlight bar color based on battery
	if GameManager.flashlight_battery < 15:
		flashlight_bar.modulate = Color(1, 0.3, 0.3)
	elif GameManager.flashlight_battery < 30:
		flashlight_bar.modulate = Color(1, 1, 0.3)
	else:
		flashlight_bar.modulate = Color(1, 1, 1)


func _on_game_state_changed(new_state):
	match new_state:
		GameManager.GameState.PLAYING:
			status_label.text = "Find all keys and escape!"
			# Fade out status after a few seconds
			get_tree().create_timer(5.0).timeout.connect(func():
				status_label.text = ""
			)
		GameManager.GameState.CAUGHT:
			status_label.text = "You have been caught by the ghost!"
			status_label.add_theme_color_override("font_color", Color(1, 0, 0))
		GameManager.GameState.ESCAPED:
			status_label.text = "You escaped!"
			status_label.add_theme_color_override("font_color", Color(0, 1, 0))


func _on_item_collected(item_name: String, _peer_id: int):
	status_label.text = "Found: %s!" % item_name.replace("key_", "").replace("_", " ").to_upper()
	status_label.add_theme_color_override("font_color", Color(1, 1, 0.5))
	get_tree().create_timer(3.0).timeout.connect(func():
		status_label.text = ""
		status_label.add_theme_color_override("font_color", Color(1, 1, 1))
	)


func _on_all_items_collected():
	status_label.text = "ALL KEYS FOUND! Find the escape door!"
	status_label.add_theme_color_override("font_color", Color(0, 1, 0))
	ghost_warning.visible = true
	get_tree().create_timer(3.0).timeout.connect(func():
		ghost_warning.visible = false
	)


func _on_ghost_victory():
	status_label.text = "THE GHOST WINS!"


func _on_human_victory():
	status_label.text = "SURVIVORS ESCAPED!"


func show_ghost_warning():
	"""Flash a warning that the ghost is hunting"""
	ghost_warning.visible = true
	ghost_warning.modulate = Color(1, 0, 0, 0.5)
	var tween = create_tween()
	tween.tween_property(ghost_warning, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): ghost_warning.visible = false)


func _get_local_player():
	"""Find the local player node"""
	for player in get_tree().get_nodes_in_group("player"):
		if player.is_local_player:
			return player
	return null
