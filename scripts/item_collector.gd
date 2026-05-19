extends Area3D
## ItemCollector - Simple collectible item
## Works WITHOUT onready child nodes (all created dynamically by map_generator)

@export var item_type: int = 0
@export var item_display_name: String = "Key"

var is_collected: bool = false

var item_key_map: Dictionary = {
	0: "key_red",
	1: "key_blue",
	2: "key_green",
	3: "car_key"
}


func _ready():
	collision_layer = 16
	collision_mask = 2
	add_to_group("items")
	add_to_group("interactable")

	body_entered.connect(_on_body_entered)

	# Check if already collected
	var key_name = item_key_map.get(item_type, "")
	if key_name != "" and GameManager.required_items.get(key_name, false):
		is_collected = true
		_hide_item()


func _process(delta):
	if is_collected: return
	# Rotate the key mesh if it exists
	for child in get_children():
		if child is MeshInstance3D:
			child.rotate_y(1.5 * delta)
			child.position.y = 0.8 + sin(delta * 2.0) * 0.05


func _on_body_entered(body: Node3D):
	if is_collected: return
	if body.is_in_group("player"):
		# Auto-collect when player walks near
		on_interact(body.peer_id if body.has_method("peer_id") else 1)


func on_interact(peer_id: int):
	if is_collected: return
	is_collected = true

	var key_name = item_key_map.get(item_type, "")
	if key_name != "":
		GameManager.on_item_collected(key_name, peer_id)

	_hide_item()


func get_interaction_text() -> String:
	return "[E] Pick up %s" % item_display_name


func _hide_item():
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false
		elif child is CollisionShape3D:
			child.set_deferred("disabled", true)
