extends StaticBody3D
## EscapeDoor - The final door that players must unlock to escape and win
## Requires all items to be collected before it can be opened

@export var door_id: String = "main_exit"
@export var is_locked: bool = true

# Visual
@onready var door_mesh: MeshInstance3D = $DoorMesh
@onready var door_light: OmniLight3D = $DoorLight
@onready var interact_label: Label3D = $InteractLabel
@onready var open_audio: AudioStreamPlayer3D = $OpenAudio
@onready var locked_audio: AudioStreamPlayer3D = $LockedAudio

var is_open: bool = false
var door_open_angle: float = -90.0
var door_open_speed: float = 2.0
var target_rotation: float = 0.0

# Area for detection
@onready var detection_area: Area3D = $DetectionArea


func _ready():
	collision_layer = 1 | 16  # Environment + Interactable
	collision_mask = 2  # Player

	add_to_group("interactable")
	add_to_group("escape_door")

	# Connect detection
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)

	# Update visual state
	_update_door_visual()

	# Listen for all items collected
	GameManager.all_items_collected.connect(_on_all_items_collected)

	if interact_label:
		interact_label.visible = false


func _process(delta):
	if is_open and door_mesh:
		# Animate door opening
		var current_rot = door_mesh.rotation_degrees.y
		door_mesh.rotation_degrees.y = lerp(current_rot, door_open_angle, door_open_speed * delta)


func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		if interact_label:
			if is_locked:
				interact_label.text = "[E] Locked - Find all keys!"
			else:
				interact_label.text = "[E] Open Escape Door"
			interact_label.visible = true


func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		if interact_label:
			interact_label.visible = false


func on_interact(peer_id: int):
	if is_open:
		# Player is escaping!
		GameManager.on_player_escaped(peer_id)
		return

	if is_locked:
		# Door is locked - play locked sound
		if locked_audio:
			locked_audio.play()

		if GameManager.escape_door_unlocked:
			# All items collected - unlock the door!
			_unlock_door()
		else:
			# Show how many items remaining
			var remaining = GameManager.total_items_required - GameManager.items_collected_count
			print("[EscapeDoor] Still need %d more items!" % remaining)
	else:
		_open_door(peer_id)


func get_interaction_text() -> String:
	if is_open:
		return "[E] ESCAPE!"
	if is_locked:
		if GameManager.escape_door_unlocked:
			return "[E] Unlock Escape Door"
		return "[E] Locked - Find all keys!"
	return "[E] Open Escape Door"


func _on_all_items_collected():
	"""Called when all required items have been collected"""
	_unlock_door()
	# Visual feedback
	if door_light:
		door_light.light_color = Color(0, 1, 0)
		door_light.light_energy = 2.0

	# Play unlock sound
	if open_audio:
		open_audio.play()


func _unlock_door():
	is_locked = false
	_update_door_visual()
	print("[EscapeDoor] Door unlocked! Find the escape door!")


func _open_door(peer_id: int):
	is_open = true

	# Play open sound
	if open_audio:
		open_audio.play()

	# Player escapes
	GameManager.on_player_escaped(peer_id)

	if interact_label:
		interact_label.text = "[E] ESCAPE!"
		interact_label.visible = true


func _update_door_visual():
	"""Update the door's visual appearance"""
	if not door_mesh:
		return

	var mat = door_mesh.get_surface_override_material(0)
	if not mat:
		mat = StandardMaterial3D.new()
		door_mesh.set_surface_override_material(mat)

	if is_locked:
		mat.albedo_color = Color(0.4, 0.2, 0.2)
		mat.emission = Color(0.3, 0.0, 0.0)
		mat.emission_energy = 0.2
		if door_light:
			door_light.light_color = Color(1, 0, 0)
			door_light.light_energy = 0.5
	else:
		mat.albedo_color = Color(0.2, 0.5, 0.2)
		mat.emission = Color(0.0, 0.5, 0.0)
		mat.emission_energy = 0.3
		if door_light:
			door_light.light_color = Color(0, 1, 0)
			door_light.light_energy = 1.0
