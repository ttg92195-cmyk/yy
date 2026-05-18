extends Area3D
## ItemCollector - Collectible items (keys, car parts) that players need to find
## Place these around the map as collectible objects
## The Ghost style: Find items -> Unlock escape -> Escape to win

## Item types matching GameManager.required_items
enum ItemType {
	KEY_RED,
	KEY_BLUE,
	KEY_GREEN,
	CAR_KEY
}

@export var item_type: ItemType = ItemType.KEY_RED
@export var item_display_name: String = "Red Key"
@export var item_description: String = "A rusty red key. Where does it go?"

# Visual
var is_collected: bool = false
var float_speed: float = 2.0
var float_amplitude: float = 0.1
var rotate_speed: float = 1.5
var time_elapsed: float = 0.0

# References
@onready var mesh: MeshInstance3D = $ItemMesh
@onready var glow: OmniLight3D = $GlowLight
@onready var collect_audio: AudioStreamPlayer3D = $CollectAudio
@onready var interact_label: Label3D = $InteractLabel

# Item type -> GameManager key mapping
var item_key_map: Dictionary = {
	ItemType.KEY_RED: "key_red",
	ItemType.KEY_BLUE: "key_blue",
	ItemType.KEY_GREEN: "key_green",
	ItemType.CAR_KEY: "car_key"
}


func _ready():
	# Set collision layers
	collision_layer = 16  # Interactable layer
	collision_mask = 2    # Player layer

	# Connect body entered signal
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Setup visual based on item type
	_setup_visuals()

	# Add to items group
	add_to_group("items")

	# Setup interaction label
	if interact_label:
		interact_label.text = "[E] Pick up %s" % item_display_name
		interact_label.visible = false

	# Check if already collected (for late-joining clients)
	var key_name = item_key_map[item_type]
	if GameManager.required_items.get(key_name, false):
		is_collected = true
		_hide_item()


func _process(delta):
	if is_collected:
		return

	time_elapsed += delta

	# Floating animation
	if mesh:
		mesh.position.y = sin(time_elapsed * float_speed) * float_amplitude + 0.5
		mesh.rotate_y(rotate_speed * delta)

	# Glow pulse
	if glow:
		glow.light_energy = 1.0 + sin(time_elapsed * 3.0) * 0.3


func _setup_visuals():
	"""Setup visual appearance based on item type"""
	if not mesh:
		return

	var mat = StandardMaterial3D.new()
	mat.transmission_enabled = true
	mat.emission_enabled = true

	match item_type:
		ItemType.KEY_RED:
			mat.albedo_color = Color(0.8, 0.1, 0.1)
			mat.emission = Color(1.0, 0.2, 0.2)
			mat.emission_energy = 0.5
			if glow:
				glow.light_color = Color(1.0, 0.3, 0.3)
		ItemType.KEY_BLUE:
			mat.albedo_color = Color(0.1, 0.2, 0.8)
			mat.emission = Color(0.2, 0.3, 1.0)
			mat.emission_energy = 0.5
			if glow:
				glow.light_color = Color(0.3, 0.3, 1.0)
		ItemType.KEY_GREEN:
			mat.albedo_color = Color(0.1, 0.7, 0.1)
			mat.emission = Color(0.2, 1.0, 0.2)
			mat.emission_energy = 0.5
			if glow:
				glow.light_color = Color(0.3, 1.0, 0.3)
		ItemType.CAR_KEY:
			mat.albedo_color = Color(0.8, 0.7, 0.1)
			mat.emission = Color(1.0, 0.9, 0.2)
			mat.emission_energy = 0.5
			if glow:
				glow.light_color = Color(1.0, 0.9, 0.3)

	mesh.set_surface_override_material(mat)


func _on_body_entered(body: Node3D):
	"""Show interaction prompt when player is near"""
	if is_collected:
		return
	if body.is_in_group("player"):
		if interact_label:
			interact_label.visible = true


func _on_body_exited(body: Node3D):
	"""Hide interaction prompt when player leaves"""
	if body.is_in_group("player"):
		if interact_label:
			interact_label.visible = false


## Called when a player interacts with this item
func on_interact(peer_id: int):
	if is_collected:
		return

	is_collected = true

	# Play collect sound
	if collect_audio:
		collect_audio.play()

	# Notify GameManager
	var key_name = item_key_map[item_type]
	GameManager.on_item_collected(key_name, peer_id)

	# Hide the item
	_hide_item()

	# Sync to all clients
	if multiplayer.has_multiplayer_peer():
		_sync_collected.rpc()


func get_interaction_text() -> String:
	return "[E] Pick up %s" % item_display_name


func _hide_item():
	"""Hide the collected item"""
	if mesh:
		mesh.visible = false
	if glow:
		glow.visible = false
	if interact_label:
		interact_label.visible = false

	# Disable collision
	$CollisionShape3D.set_deferred("disabled", true)


@rpc("authority", "call_local")
func _sync_collected():
	"""Sync collection state across network"""
	is_collected = true
	_hide_item()
