extends StaticBody3D
## EscapeDoor - Simple escape door
## Works WITHOUT onready child nodes (all created dynamically by map_generator)

@export var door_id: String = "main_exit"
@export var is_locked: bool = true

var is_open: bool = false


func _ready():
	collision_layer = 1 | 16
	collision_mask = 2
	add_to_group("interactable")
	add_to_group("escape_door")

	GameManager.all_items_collected.connect(_on_all_items_collected)


func on_interact(peer_id: int):
	if is_open:
		GameManager.on_player_escaped(peer_id)
		return

	if is_locked:
		if GameManager.escape_door_unlocked:
			_unlock_door()
			_open_door(peer_id)
		else:
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
	_unlock_door()
	# Change door color to green
	for child in get_children():
		if child is MeshInstance3D:
			var mat = child.get_surface_override_material(0)
			if mat:
				mat.emission = Color(0, 0.5, 0)
				mat.emission_energy = 1.0
		elif child is Label3D:
			child.modulate = Color(0, 1, 0)


func _unlock_door():
	is_locked = false
	print("[EscapeDoor] Door unlocked!")


func _open_door(peer_id: int):
	is_open = true
	GameManager.on_player_escaped(peer_id)
