extends Area3D
# ItemCollector V6 - Simple collectible (kept for compatibility but NOT used by map_generator)
# Map generator now handles items inline with lambda connections

@export var item_type: int = 0
@export var item_display_name: String = "Key"

var is_collected: bool = false

var item_key_map = {
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


func _on_body_entered(body):
	if is_collected:
		return
	if body.is_in_group("player"):
		var peer_id = 1
		if "peer_id" in body:
			peer_id = body.peer_id
		on_interact(peer_id)


func on_interact(peer_id: int):
	if is_collected:
		return
	is_collected = true

	var key_name = item_key_map.get(item_type, "")
	if key_name != "" and GameManager:
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
