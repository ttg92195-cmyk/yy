extends Node3D
## MapGenerator - ULTRA LIGHTWEIGHT for mobile
## Bare minimum: floor, ceiling, 4 outer walls, 2 corridor walls, 3 lights
## No rooms, no decorations, no blood, no writings
## Just a playable corridor layout

@export var map_width: int = 24
@export var map_depth: int = 24
@export var wall_height: float = 3.0

var floor_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var ceiling_mat: StandardMaterial3D

func _ready():
	_setup_materials()
	_generate_map()


func _setup_materials():
	floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.22, 0.20, 0.19)
	floor_mat.roughness = 0.9

	wall_mat = StandardMaterial3D.new()
	var wall_tex = _load_texture("res://assets/textures/brick_wall_diff.jpg")
	if wall_tex:
		wall_mat.albedo_texture = wall_tex
		wall_mat.albedo_color = Color(0.4, 0.35, 0.33)
	else:
		wall_mat.albedo_color = Color(0.28, 0.26, 0.25)
	wall_mat.roughness = 0.9
	wall_mat.uv1_scale = Vector3(2, 1.5, 2)

	ceiling_mat = StandardMaterial3D.new()
	ceiling_mat.albedo_color = Color(0.18, 0.17, 0.18)
	ceiling_mat.roughness = 0.95


func _generate_map():
	var hw = map_width / 2.0
	var hd = map_depth / 2.0

	# Floor (1 node)
	_make_solid_box(Vector3(0, -0.05, 0), Vector3(map_width, 0.1, map_depth), floor_mat)

	# Ceiling (1 node)
	_make_solid_box(Vector3(0, wall_height + 0.05, 0), Vector3(map_width, 0.1, map_depth), ceiling_mat)

	# 4 outer walls (4 nodes)
	_make_solid_box(Vector3(0, wall_height/2, -hd), Vector3(map_width, wall_height, 0.2), wall_mat)
	_make_solid_box(Vector3(0, wall_height/2, hd), Vector3(map_width, wall_height, 0.2), wall_mat)
	_make_solid_box(Vector3(-hw, wall_height/2, 0), Vector3(0.2, wall_height, map_depth), wall_mat)
	_make_solid_box(Vector3(hw, wall_height/2, 0), Vector3(0.2, wall_height, map_depth), wall_mat)

	# 2 corridor walls to make L-shape corridors (2 nodes)
	_make_solid_box(Vector3(0, wall_height/2, -5), Vector3(map_width - 6, wall_height, 0.2), wall_mat)
	_make_solid_box(Vector3(-5, wall_height/2, 0), Vector3(0.2, wall_height, map_depth - 6), wall_mat)

	# Only 4 lights total (4 nodes)
	_make_light(Vector3(0, 2.7, -8), Color(0.7, 0.55, 0.3), 1.0, 14.0)
	_make_light(Vector3(0, 2.7, 0), Color(0.7, 0.55, 0.3), 1.0, 14.0)
	_make_light(Vector3(0, 2.7, 8), Color(0.7, 0.55, 0.3), 1.0, 14.0)
	_make_light(Vector3(-8, 2.7, 0), Color(0.6, 0.5, 0.3), 0.8, 12.0)

	# Patrol markers (7 nodes)
	for pos in [Vector3(0,0,-8), Vector3(8,0,-5), Vector3(-8,0,-5), Vector3(8,0,5), Vector3(-8,0,5), Vector3(0,0,8), Vector3(0,0,0)]:
		var m = Marker3D.new()
		m.position = pos
		m.add_to_group("patrol_point")
		add_child(m)

	# 4 key items
	_place_items()

	# Escape door
	_place_escape_door()

	print("[Map] Ultra-light map ready: %dx%d, ~18 nodes" % [map_width, map_depth])


func _make_solid_box(position: Vector3, size: Vector3, material: Material):
	## Floor/Ceiling/Wall with collision
	var body = StaticBody3D.new()
	body.collision_layer = 1
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.set_surface_override_material(material)
	body.add_child(mesh)
	body.position = position
	add_child(body)


func _make_light(position: Vector3, color: Color, energy: float, range: float):
	var light = OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range
	light.shadow_enabled = false
	add_child(light)


func _place_items():
	var item_data = [
		{"type": 0, "pos": Vector3(-8, 0.5, -8), "name": "KEY_RED"},
		{"type": 1, "pos": Vector3(8, 0.5, -8), "name": "KEY_BLUE"},
		{"type": 2, "pos": Vector3(-8, 0.5, 8), "name": "KEY_GREEN"},
		{"type": 3, "pos": Vector3(8, 0.5, 8), "name": "CAR_KEY"},
	]
	for item in item_data:
		var node = _create_item_node(item.type, item.name)
		node.position = item.pos
		add_child(node)


func _create_item_node(type: int, display_name: String) -> Area3D:
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

	# Simple glowing key
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.15, 0.5, 0.08)
	mesh.mesh = box
	mesh.position = Vector3(0, 0.8, 0)
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy = 3.0
	match type:
		0: mat.albedo_color = Color(1,0.2,0.2); mat.emission = Color(1,0.2,0.2)
		1: mat.albedo_color = Color(0.2,0.4,1); mat.emission = Color(0.2,0.4,1)
		2: mat.albedo_color = Color(0.2,1,0.3); mat.emission = Color(0.2,1,0.3)
		3: mat.albedo_color = Color(1,0.8,0.2); mat.emission = Color(1,0.8,0.2)
	mesh.set_surface_override_material(mat)
	area.add_child(mesh)

	return area


func _place_escape_door():
	var door = StaticBody3D.new()
	door.collision_layer = 1
	door.set_script(load("res://scripts/escape_door.gd"))
	door.position = Vector3(0, 1.5, 11.5)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.5, 3.0, 0.2)
	col.shape = shape
	door.add_child(col)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.5, 3.0, 0.15)
	mesh.mesh = box
	var dmat = StandardMaterial3D.new()
	dmat.albedo_color = Color(0.35, 0.2, 0.1)
	dmat.roughness = 0.7
	dmat.emission_enabled = true
	dmat.emission = Color(0.05, 0.15, 0.05)
	dmat.emission_energy = 0.5
	mesh.set_surface_override_material(dmat)
	door.add_child(mesh)

	var label = Label3D.new()
	label.text = "EXIT"
	label.position = Vector3(0, 1.0, 0.1)
	label.pixel_size = 0.03
	label.modulate = Color(0, 1, 0)
	label.billboard = 1
	door.add_child(label)

	add_child(door)


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
