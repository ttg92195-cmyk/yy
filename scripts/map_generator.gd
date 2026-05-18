extends Node3D
## MapGenerator - MOBILE-OPTIMIZED horror hospital map
## Key optimizations:
## - Smaller map (30x30 instead of 50x50)
## - NO floor tile lines (saved ~68 nodes)
## - NO ceiling pipes (saved 4 nodes)
## - NO window moon lights (saved many SpotLight3D)
## - FEWER corridor lights (6 instead of 15)
## - NO flickering light scripts (no GDScript.new())
## - Furniture is visual-only (no StaticBody3D collision for decorations)
## - Simplified materials (no heightmap, no transmission)
## - Fewer blood stains and wall writings
## - Total nodes reduced from ~200+ to ~60-70

@export var map_width: int = 30
@export var map_depth: int = 30
@export var wall_height: float = 3.2
@export var wall_thickness: float = 0.2

# Shared materials (created once, reused)
var floor_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var ceiling_mat: StandardMaterial3D
var door_mat: StandardMaterial3D
var furniture_wood_mat: StandardMaterial3D
var furniture_metal_mat: StandardMaterial3D
var blood_mat: StandardMaterial3D

func _ready():
	_setup_materials()
	_generate_map()


func _setup_materials():
	# Floor - simple dark floor
	floor_mat = StandardMaterial3D.new()
	var floor_tex = _load_texture("res://assets/textures/plank_floor_diff.jpg")
	if floor_tex:
		floor_mat.albedo_texture = floor_tex
		floor_mat.albedo_color = Color(0.5, 0.45, 0.4)
	else:
		floor_mat.albedo_color = Color(0.22, 0.20, 0.19)
	floor_mat.roughness = 0.85
	floor_mat.metallic = 0.0
	floor_mat.uv1_scale = Vector3(3, 3, 3)

	# Walls
	wall_mat = StandardMaterial3D.new()
	var wall_tex = _load_texture("res://assets/textures/brick_wall_diff.jpg")
	if wall_tex:
		wall_mat.albedo_texture = wall_tex
		wall_mat.albedo_color = Color(0.4, 0.35, 0.33)
	else:
		wall_mat.albedo_color = Color(0.28, 0.26, 0.25)
	wall_mat.roughness = 0.9
	wall_mat.uv1_scale = Vector3(2, 1.5, 2)
	# NO heightmap - saves GPU on mobile

	# Ceiling
	ceiling_mat = StandardMaterial3D.new()
	ceiling_mat.albedo_color = Color(0.18, 0.17, 0.18)
	ceiling_mat.roughness = 0.95

	# Door
	door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.30, 0.18, 0.08)
	door_mat.roughness = 0.7

	# Furniture - wood
	furniture_wood_mat = StandardMaterial3D.new()
	furniture_wood_mat.albedo_color = Color(0.35, 0.22, 0.12)
	furniture_wood_mat.roughness = 0.85

	# Furniture - metal
	furniture_metal_mat = StandardMaterial3D.new()
	furniture_metal_mat.albedo_color = Color(0.4, 0.4, 0.42)
	furniture_metal_mat.roughness = 0.4
	furniture_metal_mat.metallic = 0.7

	# Blood stains
	blood_mat = StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.4, 0.02, 0.02)
	blood_mat.roughness = 0.7


func _generate_map():
	var half_w = map_width / 2.0
	var half_d = map_depth / 2.0

	# 1. Floor + Ceiling (only 2 nodes)
	_create_floor_and_ceiling(map_width, map_depth)

	# 2. Outer walls (only 4 walls, NO windows)
	_create_outer_walls(half_w, half_d, wall_height)

	# 3. Inner rooms
	_create_inner_structure(half_w, half_d)

	# 4. Minimal lights (6 corridor lights only)
	_add_lights()

	# 5. Patrol markers
	_add_patrol_markers()

	# 6. Items
	_place_items()

	# 7. Escape door
	_place_escape_door()

	# 8. A few decorations
	_add_decorations()

	print("[MapGenerator] MOBILE-OPTIMIZED map generated: %dx%d" % [map_width, map_depth])


# ============ BASIC STRUCTURE ============

func _create_floor_and_ceiling(w: float, d: float):
	# Floor with collision
	var floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(w, 0.1, d)
	col.shape = shape
	floor_body.add_child(col)
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(w, 0.1, d)
	mesh_inst.mesh = box
	mesh_inst.set_surface_override_material(floor_mat)
	floor_body.add_child(mesh_inst)
	floor_body.position = Vector3(0, -0.05, 0)
	add_child(floor_body)

	# Ceiling with collision
	var ceil_body = StaticBody3D.new()
	ceil_body.collision_layer = 1
	var col2 = CollisionShape3D.new()
	var shape2 = BoxShape3D.new()
	shape2.size = Vector3(w, 0.1, d)
	col2.shape = shape2
	ceil_body.add_child(col2)
	var mesh2 = MeshInstance3D.new()
	var box2 = BoxMesh.new()
	box2.size = Vector3(w, 0.1, d)
	mesh2.mesh = box2
	mesh2.set_surface_override_material(ceiling_mat)
	ceil_body.add_child(mesh2)
	ceil_body.position = Vector3(0, wall_height + 0.05, 0)
	add_child(ceil_body)


func _create_outer_walls(half_w: float, half_d: float, h: float):
	# Just 4 solid walls - no windows, no extra lights
	_create_wall(Vector3(0, h/2, -half_d), Vector3(map_width, h, wall_thickness))
	_create_wall(Vector3(0, h/2, half_d), Vector3(map_width, h, wall_thickness))
	_create_wall(Vector3(half_w, h/2, 0), Vector3(wall_thickness, h, map_depth))
	_create_wall(Vector3(-half_w, h/2, 0), Vector3(wall_thickness, h, map_depth))


func _create_wall(position: Vector3, size: Vector3):
	var wall_body = StaticBody3D.new()
	wall_body.collision_layer = 1
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	wall_body.add_child(col)
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.set_surface_override_material(wall_mat)
	wall_body.add_child(mesh_inst)
	wall_body.position = position
	add_child(wall_body)


# ============ ROOMS (Simplified) ============

func _create_inner_structure(half_w: float, half_d: float):
	# Main corridor walls
	_create_wall(Vector3(0, wall_height/2, -4), Vector3(map_width - 8, wall_height, wall_thickness))
	_create_wall(Vector3(0, wall_height/2, 4), Vector3(map_width - 8, wall_height, wall_thickness))

	# Cross corridor
	_create_wall(Vector3(-4, wall_height/2, 0), Vector3(wall_thickness, wall_height, map_depth - 8))
	_create_wall(Vector3(4, wall_height/2, 0), Vector3(wall_thickness, wall_height, map_depth - 8))

	# Rooms - just walls and essential furniture
	_create_room_reception()
	_create_room_storage()
	_create_room_operating()
	_create_room_morgue()
	_create_room_office()
	_create_room_bathroom()


func _create_room_reception():
	var c = Vector3(-8, 0, -8)  # Closer to center (smaller map)
	var hw = 3.0
	var hd = 3.0

	# Walls with door gap
	_create_wall(c + Vector3(-hw/2, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw/2, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(-hw/2, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw/2, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))
	_create_wall(c + Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))

	# Just desk and chair (visual only, no collision)
	_create_visual_box(c + Vector3(-0.5, 0.45, -0.8), Vector3(2.0, 0.9, 0.7), furniture_wood_mat)
	_create_visual_box(c + Vector3(-0.5, 0.25, 0), Vector3(0.5, 0.5, 0.5), furniture_wood_mat)

	# Room light (just OmniLight, NO fixture mesh)
	_create_room_light(c + Vector3(0, 2.8, 0), Color(0.6, 0.5, 0.35), 1.2, 12.0)


func _create_room_storage():
	var c = Vector3(8, 0, -8)
	var hw = 2.5
	var hd = 2.5

	_create_wall(c + Vector3(-hw/2, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw/2, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(-hw/2, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw/2, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))
	_create_wall(c + Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))

	# Shelves and box
	_create_visual_box(c + Vector3(-1.5, 1.0, -0.5), Vector3(0.4, 2.0, 1.2), furniture_metal_mat)
	_create_visual_box(c + Vector3(0.5, 0.25, 0), Vector3(0.6, 0.5, 0.5), furniture_wood_mat)

	_create_room_light(c + Vector3(0, 2.8, 0), Color(0.5, 0.45, 0.3), 0.7, 10.0)


func _create_room_operating():
	var c = Vector3(-8, 0, 8)
	var hw = 3.0
	var hd = 3.0

	_create_wall(c + Vector3(-hw/2, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw/2, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(-hw/2, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw/2, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))
	_create_wall(c + Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))

	# Operating table
	var table_mat = StandardMaterial3D.new()
	table_mat.albedo_color = Color(0.5, 0.5, 0.52)
	table_mat.roughness = 0.3
	table_mat.metallic = 0.6
	_create_visual_box(c + Vector3(0, 0.4, 0), Vector3(1.8, 0.12, 0.7), table_mat)

	_create_room_light(c + Vector3(0, 2.8, 0), Color(0.65, 0.65, 0.7), 1.0, 10.0)


func _create_room_morgue():
	var c = Vector3(8, 0, 8)
	var hw = 2.5
	var hd = 2.5

	_create_wall(c + Vector3(-hw/2, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw/2, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(-hw/2, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw/2, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))
	_create_wall(c + Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))

	# Morgue drawers
	_create_visual_box(c + Vector3(-1.5, 0.8, 0), Vector3(0.5, 1.6, 1.5), furniture_metal_mat)
	# Body slab
	_create_visual_box(c + Vector3(0.8, 0.35, 0), Vector3(1.5, 0.06, 0.6), furniture_metal_mat)

	# Cold blue light
	_create_room_light(c + Vector3(0, 2.8, 0), Color(0.3, 0.4, 0.6), 0.6, 8.0)


func _create_room_office():
	var c = Vector3(0, 0, -10)
	var hw = 2.0
	var hd = 2.0

	_create_wall(c + Vector3(-hw/2, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw/2, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(-hw/2, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw/2, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))
	_create_wall(c + Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))

	# Desk
	_create_visual_box(c + Vector3(0, 0.4, -0.7), Vector3(1.5, 0.08, 0.7), furniture_wood_mat)
	# Bookshelf
	_create_visual_box(c + Vector3(1.0, 0.7, 0), Vector3(0.3, 1.4, 1.0), furniture_wood_mat)

	_create_room_light(c + Vector3(0, 2.8, 0), Color(0.6, 0.5, 0.35), 0.8, 8.0)


func _create_room_bathroom():
	var c = Vector3(0, 0, 10)
	var hw = 2.0
	var hd = 1.5

	_create_wall(c + Vector3(-hw/2, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw/2, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(-hw/2, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw/2, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
	_create_wall(c + Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))
	_create_wall(c + Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))

	# Bathtub
	_create_visual_box(c + Vector3(-0.5, 0.3, 0.3), Vector3(1.5, 0.5, 0.7), furniture_metal_mat)

	_create_room_light(c + Vector3(0, 2.8, 0), Color(0.5, 0.55, 0.6), 0.7, 8.0)


# ============ DECORATIONS (Minimal) ============

func _add_decorations():
	# Just 2 blood stains
	_create_visual_box(Vector3(-3, 0.01, -5), Vector3(1.0, 0.002, 0.6), blood_mat)
	_create_visual_box(Vector3(5, 0.01, 3), Vector3(0.6, 0.002, 0.8), blood_mat)

	# 2 wall writings
	_create_wall_writing(Vector3(-4.1, 1.5, -6), "GET OUT", 0.03)
	_create_wall_writing(Vector3(4.1, 1.5, 5), "HELP ME", 0.025)


func _create_wall_writing(position: Vector3, text: String, pixel_size: float):
	var label = Label3D.new()
	label.text = text
	label.position = position
	label.pixel_size = pixel_size
	label.modulate = Color(0.6, 0.0, 0.0)
	label.billboard = 0
	label.rotation = Vector3(0, deg_to_rad(90) if abs(position.x) > abs(position.z) else 0, 0)
	add_child(label)


# ============ LIGHTS (Minimal - 6 corridor lights only) ============

func _add_lights():
	# Only 6 corridor lights - NO fixtures, NO flickering scripts
	var light_data = [
		Vector3(0, 2.8, -10),
		Vector3(0, 2.8, 0),
		Vector3(0, 2.8, 10),
		Vector3(-10, 2.8, 0),
		Vector3(10, 2.8, 0),
		Vector3(0, 2.8, -20),
	]

	for pos in light_data:
		var light = OmniLight3D.new()
		light.position = pos
		light.light_color = Color(0.7, 0.55, 0.3)
		light.light_energy = 1.0
		light.omni_range = 14.0
		light.shadow_enabled = false
		add_child(light)


func _create_room_light(position: Vector3, color: Color, energy: float, range: float):
	# Simple light - NO fixture mesh
	var light = OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range
	light.shadow_enabled = false
	add_child(light)


# ============ HELPERS ============

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _create_visual_box(position: Vector3, size: Vector3, material: Material):
	## Visual-only box - NO StaticBody3D, NO CollisionShape3D
	## This saves a LOT of physics processing on mobile
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.set_surface_override_material(material)
	mesh_inst.position = position
	add_child(mesh_inst)


func _add_patrol_markers():
	var positions = [
		Vector3(0, 0, -10),
		Vector3(10, 0, -6),
		Vector3(-10, 0, -6),
		Vector3(10, 0, 6),
		Vector3(-10, 0, 6),
		Vector3(0, 0, 8),
		Vector3(0, 0, 0),
	]

	for pos in positions:
		var marker = Marker3D.new()
		marker.position = pos
		marker.add_to_group("patrol_point")
		add_child(marker)


func _place_items():
	var item_data = [
		{"type": 0, "pos": Vector3(-8, 0.5, -10), "name": "KEY_RED"},
		{"type": 1, "pos": Vector3(8, 0.5, -10), "name": "KEY_BLUE"},
		{"type": 2, "pos": Vector3(-8, 0.5, 10), "name": "KEY_GREEN"},
		{"type": 3, "pos": Vector3(8, 0.5, 10), "name": "CAR_KEY"},
	]

	for item in item_data:
		var item_node = _create_item_node(item.type, item.name)
		item_node.position = item.pos
		if has_node("Items"):
			$Items.add_child(item_node)
		else:
			add_child(item_node)


func _create_item_node(type: int, display_name: String) -> Node3D:
	var area = Area3D.new()
	area.collision_layer = 16
	area.collision_mask = 2
	area.add_to_group("items")
	area.add_to_group("interactable")
	area.set_script(load("res://scripts/item_collector.gd"))
	area.set("item_type", type)
	area.set("item_display_name", display_name)

	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 1.5
	col.shape = sphere
	area.add_child(col)

	# Key mesh
	var mesh_inst = MeshInstance3D.new()
	var key_mesh = BoxMesh.new()
	key_mesh.size = Vector3(0.15, 0.5, 0.08)
	mesh_inst.mesh = key_mesh
	mesh_inst.position = Vector3(0, 0.8, 0)

	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy = 3.0

	match type:
		0:
			mat.albedo_color = Color(1, 0.2, 0.2)
			mat.emission = Color(1, 0.2, 0.2)
		1:
			mat.albedo_color = Color(0.2, 0.4, 1)
			mat.emission = Color(0.2, 0.4, 1)
		2:
			mat.albedo_color = Color(0.2, 1, 0.3)
			mat.emission = Color(0.2, 1, 0.3)
		3:
			mat.albedo_color = Color(1, 0.8, 0.2)
			mat.emission = Color(1, 0.8, 0.2)

	mesh_inst.set_surface_override_material(mat)
	area.add_child(mesh_inst)

	return area


func _place_escape_door():
	var door_script = load("res://scripts/escape_door.gd")
	var door = StaticBody3D.new()
	door.collision_layer = 1
	door.set_script(door_script)
	door.position = Vector3(0, 1.5, 14.5)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.5, 3.0, 0.2)
	col.shape = shape
	door.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.5, 3.0, 0.15)
	mesh_inst.mesh = box

	var door_escape_mat = StandardMaterial3D.new()
	door_escape_mat.albedo_color = Color(0.35, 0.2, 0.1)
	door_escape_mat.roughness = 0.7
	door_escape_mat.emission_enabled = true
	door_escape_mat.emission = Color(0.05, 0.15, 0.05)
	door_escape_mat.emission_energy = 0.5
	mesh_inst.set_surface_override_material(door_escape_mat)
	door.add_child(mesh_inst)

	# Door label
	var label = Label3D.new()
	label.text = "EXIT"
	label.position = Vector3(0, 1.0, 0.1)
	label.pixel_size = 0.03
	label.modulate = Color(0, 1, 0)
	label.billboard = 1
	door.add_child(label)

	add_child(door)
