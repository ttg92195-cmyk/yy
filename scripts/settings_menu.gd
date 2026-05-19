extends Control
## SettingsMenu - Game settings (sensitivity, volume, graphics)

var back_button: Button = null
var sensitivity_slider: HSlider = null
var sensitivity_label: Label = null
var volume_slider: HSlider = null
var volume_label: Label = null
var fog_check: CheckBox = null
var glow_check: CheckBox = null

# Settings values
var mouse_sensitivity: float = 0.002
var master_volume: float = 80.0
var fog_enabled: bool = true
var glow_enabled: bool = true


func _ready():
	# Load saved settings
	_load_settings()

	# Connect signals
	back_button.pressed.connect(_on_back_pressed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	fog_check.toggled.connect(_on_fog_toggled)
	glow_check.toggled.connect(_on_glow_toggled)

	# Set initial values
	sensitivity_slider.value = mouse_sensitivity * 1000.0
	volume_slider.value = master_volume
	fog_check.button_pressed = fog_enabled
	glow_check.button_pressed = glow_enabled

	_update_labels()


func _on_sensitivity_changed(value: float):
	mouse_sensitivity = value / 1000.0
	_update_labels()


func _on_volume_changed(value: float):
	master_volume = value
	AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))
	_update_labels()


func _on_fog_toggled(enabled: bool):
	fog_enabled = enabled
	# Update environment
	var env = get_viewport().find_world_3d().environment
	if env:
		env.fog_enabled = enabled


func _on_glow_toggled(enabled: bool):
	glow_enabled = enabled
	var env = get_viewport().find_world_3d().environment
	if env:
		env.glow_enabled = enabled


func _update_labels():
	sensitivity_label.text = "%.1f" % (mouse_sensitivity * 1000.0)
	volume_label.text = "%d%%" % int(master_volume)


func _on_back_pressed():
	_save_settings()
	visible = false
	# Show main menu buttons again
	var main_menu = get_parent()
	if main_menu and main_menu.has_node("VBoxContainer"):
		main_menu.get_node("VBoxContainer").visible = true


func _save_settings():
	var config = ConfigFile.new()
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("graphics", "fog_enabled", fog_enabled)
	config.set_value("graphics", "glow_enabled", glow_enabled)
	config.save("user://settings.cfg")


func _load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", 0.002)
		master_volume = config.get_value("audio", "master_volume", 80.0)
		fog_enabled = config.get_value("graphics", "fog_enabled", true)
		glow_enabled = config.get_value("graphics", "glow_enabled", true)
