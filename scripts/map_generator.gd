extends Node3D
## MapGenerator - Procedurally generates a horror hospital/house map
## Creates walls, floors, rooms, corridors with proper collision and navigation
## IMPORTANT: Lights must be bright enough to see on mobile!

@export var map_width: int = 50
@export var map_depth: int = 50
@export var wall_height: float = 3.0
@export var wall_thickness: float = 0.2
@export var corridor_width: float = 3.0
@export var room_size_min: float = 5.0
@export var room_size_max: float = 8.0

var floor_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var ceiling_mat: StandardMaterial3D

func _ready():
	_setup_materials()
	_generate_map()


func _setup_materials():
	# Floor material - slightly brighter so players can see the ground
	floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.18, 0.16, 0.15)
	floor_mat.roughness = 0.9
	floor_mat.metallic = 0.0

	# Wall material - brighter so players can see walls
	wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.22, 0.20, 0.21)
	wall_mat.roughness = 0.85
	wall_mat.metallic = 0.0

	# Ceiling material - slightly brighter
	ceiling_mat = StandardMaterial3D.new()
	ceiling_mat.albedo_color = Color(0.14, 0.12, 0.13)
	ceiling_mat.roughness = 0.95


func _generate_map():
	## Generate a grid-based horror map with rooms and corridors

	var half_w = map_width / 2.0
	var half_d = map_depth / 2.0

	# 1. Create floor
	_create_floor(map_width, map_depth)

	# 2. Create ceiling
	_create_ceiling(map_width, map_depth, wall_height)

	# 3. Create outer walls
	_create_outer_walls(half_w, half_d, wall_height)

	# 4. Create inner rooms and corridors
	_create_inner_structure(half_w, half_d)

	# 5. Add atmospheric lights - BRIGHTER for mobile visibility
	_add_lights()

	# 6. Add patrol point markers for ghost AI
	_add_patrol_markers()

	# 7. Place collectible items
	_place_items()

	# 8. Place escape door
	_place_escape_door()

	print("[MapGenerator] Map generated: %dx%d" % [map_width, map_depth])


func _create_floor(w: float, d: float):
	var floor_mesh = BoxShape3D.new()
	floor_mesh.size = Vector3(w, 0.1, d)

	var floor_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	collision.shape = floor_mesh
	floor_body.add_child(collision)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(w, 0.1, d)
	mesh_inst.mesh = box_mesh
	mesh_inst.set_surface_override_material(floor_mat)
	floor_body.add_child(mesh_inst)

	floor_body.position = Vector3(0, -0.05, 0)
	add_child(floor_body)


func _create_ceiling(w: float, d: float, h: float):
	var ceiling_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(w, 0.1, d)
	collision.shape = shape
	ceiling_body.add_child(collision)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(w, 0.1, d)
	mesh_inst.mesh = box_mesh
	mesh_inst.set_surface_override_material(ceiling_mat)
	ceiling_body.add_child(mesh_inst)

	ceiling_body.position = Vector3(0, h + 0.05, 0)
	add_child(ceiling_body)


func _create_outer_walls(half_w: float, half_d: float, h: float):
	# North wall
	_create_wall(Vector3(0, h/2, -half_d), Vector3(map_width, h, wall_thickness))
	# South wall
	_create_wall(Vector3(0, h/2, half_d), Vector3(map_width, h, wall_thickness))
	# East wall
	_create_wall(Vector3(half_w, h/2, 0), Vector3(wall_thickness, h, map_depth))
	# West wall
	_create_wall(Vector3(-half_w, h/2, 0), Vector3(wall_thickness, h, map_depth))


func _create_wall(position: Vector3, size: Vector3, has_door: bool = false):
	var wall_body = StaticBody3D.new()
	wall_body.collision_layer = 1  # Environment

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	wall_body.add_child(collision)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	mesh_inst.set_surface_override_material(wall_mat)
	wall_body.add_child(mesh_inst)

	wall_body.position = position
	add_child(wall_body)


func _create_inner_structure(half_w: float, half_d: float):
	## Create rooms and corridors using a grid pattern

	var room_positions = [
		# Room 1 - Reception (near spawn)
		{"pos": Vector3(-12, 0, -12), "size": Vector2(8, 8), "name": "Reception"},
		# Room 2 - Storage
		{"pos": Vector3(12, 0, -12), "size": Vector2(7, 6), "name": "Storage"},
		# Room 3 - Operating Room
		{"pos": Vector3(-12, 0, 8), "size": Vector2(8, 7), "name": "Operating Room"},
		# Room 4 - Morgue
		{"pos": Vector3(12, 0, 8), "size": Vector2(6, 6), "name": "Morgue"},
		# Room 5 - Office
		{"pos": Vector3(0, 0, -18), "size": Vector2(5, 5), "name": "Office"},
	]

	for room in room_positions:
		_create_room(room.pos, room.size, room.name)

	# Add corridor walls to create hallways
	# Main corridor (horizontal)
	_create_wall(Vector3(0, wall_height/2, -4), Vector3(map_width - 10, wall_height, wall_thickness))
	_create_wall(Vector3(0, wall_height/2, 4), Vector3(map_width - 10, wall_height, wall_thickness))

	# Main corridor (vertical)
	_create_wall(Vector3(-4, wall_height/2, 0), Vector3(wall_thickness, wall_height, map_depth - 10))
	_create_wall(Vector3(4, wall_height/2, 0), Vector3(wall_thickness, wall_height, map_depth - 10))

	# Add some furniture obstacles
	_create_obstacle(Vector3(-10, 0.5, -10), Vector3(2, 1, 1))  # Table in reception
	_create_obstacle(Vector3(10, 0.5, -10), Vector3(1.5, 1.5, 1.5))  # Cabinet in storage
	_create_obstacle(Vector3(-10, 0.5, 7), Vector3(3, 0.8, 1.5))  # Operating table
	_create_obstacle(Vector3(10, 0.5, 7), Vector3(2, 0.8, 3))  # Morgue slab


func _create_room(center: Vector3, size: Vector2, room_name: String):
	var hw = size.x / 2.0
	var hd = size.y / 2.0
	var h = wall_height

	# Room walls with door openings
	# North wall (with door gap in center)
	_create_wall(center + Vector3(-hw/2 - 0.5, h/2, -hd), Vector3(hw - 1, h, wall_thickness))
	_create_wall(center + Vector3(hw/2 + 0.5, h/2, -hd), Vector3(hw - 1, h, wall_thickness))

	# South wall (with door gap)
	_create_wall(center + Vector3(-hw/2 - 0.5, h/2, hd), Vector3(hw - 1, h, wall_thickness))
	_create_wall(center + Vector3(hw/2 + 0.5, h/2, hd), Vector3(hw - 1, h, wall_thickness))

	# East wall
	_create_wall(center + Vector3(hw, h/2, 0), Vector3(wall_thickness, h, size.y))

	# West wall
	_create_wall(center + Vector3(-hw, h/2, 0), Vector3(wall_thickness, h, size.y))

	# Room label (debug - invisible in game)
	var label = Label3D.new()
	label.text = room_name
	label.position = center + Vector3(0, 2.5, 0)
	label.modulate = Color(1, 1, 1, 0.3)
	add_child(label)

	# Room light - BRIGHTER for mobile visibility
	var room_light = OmniLight3D.new()
	room_light.position = center + Vector3(0, 2.5, 0)
	room_light.light_color = Color(0.65, 0.5, 0.3)  # Warmer, brighter
	room_light.light_energy = 1.2  # Much brighter than before (was 0.4)
	room_light.omni_range = 14.0  # Longer range
	room_light.shadow_enabled = false  # Performance on mobile
	add_child(room_light)


func _create_obstacle(position: Vector3, size: Vector3):
	var body = StaticBody3D.new()
	body.collision_layer = 1

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh

	var obs_mat = StandardMaterial3D.new()
	obs_mat.albedo_color = Color(0.25, 0.22, 0.20)  # Brighter
	obs_mat.roughness = 0.9
	mesh_inst.set_surface_override_material(obs_mat)
	body.add_child(mesh_inst)

	body.position = position
	add_child(body)


func _add_lights():
	## Add atmospheric lights along corridors - BRIGHTER for mobile
	var light_positions = [
		Vector3(0, 2.8, -15),
		Vector3(0, 2.8, -8),
		Vector3(0, 2.8, 0),
		Vector3(0, 2.8, 8),
		Vector3(0, 2.8, 15),
		Vector3(-15, 2.8, -8),
		Vector3(-15, 2.8, 8),
		Vector3(15, 2.8, -8),
		Vector3(15, 2.8, 8),
		Vector3(-8, 2.8, 0),
		Vector3(8, 2.8, 0),
		# Extra lights for better coverage
		Vector3(-8, 2.8, -12),
		Vector3(8, 2.8, -12),
		Vector3(-8, 2.8, 12),
		Vector3(8, 2.8, 12),
	]

	for pos in light_positions:
		var light = OmniLight3D.new()
		light.position = pos
		light.light_color = Color(0.7, 0.55, 0.3)  # Warmer, brighter
		light.light_energy = 1.0  # Much brighter (was 0.5)
		light.omni_range = 16.0  # Longer range (was 12)
		light.shadow_enabled = false  # Performance on mobile
		add_child(light)

		# Light fixture mesh (simple box) - glowing
		var fixture = MeshInstance3D.new()
		var fix_mesh = BoxMesh.new()
		fix_mesh.size = Vector3(0.3, 0.1, 0.3)
		fixture.mesh = fix_mesh
		fixture.position = pos + Vector3(0, 0.15, 0)
		var fix_mat = StandardMaterial3D.new()
		fix_mat.albedo_color = Color(0.9, 0.8, 0.4)
		fix_mat.emission_enabled = true
		fix_mat.emission = Color(0.7, 0.5, 0.2)
		fix_mat.emission_energy = 3.0  # Brighter glow
		fixture.set_surface_override_material(fix_mat)
		add_child(fixture)


func _add_patrol_markers():
	## Add patrol point markers for ghost AI
	var patrol_positions = [
		Vector3(0, 0, -15),
		Vector3(15, 0, -10),
		Vector3(-15, 0, -10),
		Vector3(15, 0, 10),
		Vector3(-15, 0, 10),
		Vector3(0, 0, 15),
		Vector3(0, 0, 0),
	]

	for pos in patrol_positions:
		var marker = Marker3D.new()
		marker.position = pos
		marker.add_to_group("patrol_point")
		add_child(marker)


func _place_items():
	## Place collectible key items around the map
	var item_data = [
		{"type": 0, "pos": Vector3(-12, 0.5, -14), "name": "KEY_RED"},      # Reception
		{"type": 1, "pos": Vector3(12, 0.5, -14), "name": "KEY_BLUE"},     # Storage
		{"type": 2, "pos": Vector3(-12, 0.5, 10), "name": "KEY_GREEN"},    # Operating Room
		{"type": 3, "pos": Vector3(12, 0.5, 10), "name": "CAR_KEY"},       # Morgue
	]

	for item in item_data:
		var item_scene = _create_item_node(item.type, item.name)
		item_scene.position = item.pos
		if has_node("Items"):
			$Items.add_child(item_scene)
		else:
			add_child(item_scene)


func _create_item_node(type: int, display_name: String) -> Node3D:
	## Create an item node with mesh and collision - GLOWING so players can find them
	var area = Area3D.new()
	area.collision_layer = 16  # Interactable
	area.collision_mask = 2    # Player
	area.add_to_group("items")
	area.add_to_group("interactable")
	area.set_script(load("res://scripts/item_collector.gd"))
	area.set("item_type", type)
	area.set("item_display_name", display_name)

	# Collision shape
	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 1.5  # Larger detection area
	col.shape = sphere
	area.add_child(col)

	# Item mesh - glowing orb (brighter for mobile)
	var mesh_inst = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.25  # Slightly bigger
	sphere_mesh.height = 0.5
	mesh_inst.mesh = sphere_mesh
	mesh_inst.position = Vector3(0, 0.8, 0)

	var mat = StandardMaterial3D.new()
	mat.transmission_enabled = true
	mat.emission_enabled = true
	mat.emission_energy = 4.0  # Much brighter glow

	match type:
		0: # KEY_RED
			mat.albedo_color = Color(0.9, 0.15, 0.15)
			mat.emission = Color(1.0, 0.3, 0.3)
		1: # KEY_BLUE
			mat.albedo_color = Color(0.15, 0.3, 0.9)
			mat.emission = Color(0.3, 0.4, 1.0)
		2: # KEY_GREEN
			mat.albedo_color = Color(0.15, 0.8, 0.15)
			mat.emission = Color(0.3, 1.0, 0.3)
		3: # CAR_KEY
			mat.albedo_color = Color(0.9, 0.8, 0.15)
			mat.emission = Color(1.0, 0.9, 0.3)

	mesh_inst.set_surface_override_material(mat)
	area.add_child(mesh_inst)

	# Glow light - BRIGHTER so players can see items from far away
	var glow = OmniLight3D.new()
	glow.position = Vector3(0, 0.8, 0)
	glow.light_energy = 2.5  # Brighter (was 1.5)
	glow.omni_range = 8.0  # Longer range (was 5)
	match type:
		0: glow.light_color = Color(1, 0.3, 0.3)
		1: glow.light_color = Color(0.3, 0.3, 1)
		2: glow.light_color = Color(0.3, 1, 0.3)
		3: glow.light_color = Color(1, 0.9, 0.3)
	area.add_child(glow)

	# Interaction label
	var label = Label3D.new()
	label.text = "[E] Pick up %s" % display_name
	label.position = Vector3(0, 1.5, 0)
	label.billboard = 1
	label.pixel_size = 0.02
	area.add_child(label)

	return area


func _place_escape_door():
	## Place escape door at the south end of the map
	var door = StaticBody3D.new()
	door.collision_layer = 1 | 16
	door.collision_mask = 2
	door.add_to_group("escape_door")
	door.add_to_group("interactable")
	door.set_script(load("res://scripts/escape_door.gd"))

	# Door frame
	var door_col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2, 2.8, 0.3)
	door_col.shape = box
	door.add_child(door_col)

	# Door mesh
	var door_mesh = MeshInstance3D.new()
	var door_box = BoxMesh.new()
	door_box.size = Vector3(1.8, 2.6, 0.15)
	door_mesh.mesh = door_box
	door_mesh.position = Vector3(0, 1.4, 0)

	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.35, 0.2, 0.08)
	door_mat.roughness = 0.8
	door_mat.emission_enabled = true
	door_mat.emission = Color(0.3, 0.05, 0.0)
	door_mat.emission_energy = 1.5
	door_mesh.set_surface_override_material(door_mat)
	door.add_child(door_mesh)

	# Door light - BRIGHTER
	var door_light = OmniLight3D.new()
	door_light.position = Vector3(0, 2.5, 0)
	door_light.light_color = Color(1, 0.2, 0.1)
	door_light.light_energy = 1.5  # Brighter (was 0.5)
	door_light.omni_range = 6.0
	door.add_child(door_light)

	# Label
	var door_label = Label3D.new()
	door_label.text = "ESCAPE DOOR"
	door_label.position = Vector3(0, 3.0, 0)
	door_label.billboard = 1
	door_label.pixel_size = 0.02
	door.add_child(door_label)

	# Detection area
	var detect = Area3D.new()
	var detect_col = CollisionShape3D.new()
	var detect_box = BoxShape3D.new()
	detect_box.size = Vector3(3, 3, 2)
	detect_col.shape = detect_box
	detect.add_child(detect_col)
	door.add_child(detect)

	door.position = Vector3(0, 0, map_depth/2.0 - 1)
	add_child(door)
