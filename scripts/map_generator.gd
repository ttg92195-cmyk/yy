extends Node3D
## MapGenerator - Abandoned Hospital for Mobile
## V2 - MUCH BRIGHTER for mobile screens
## Uses MeshInstance3D + StaticBody3D (NOT CSGBox3D - too heavy for mobile)

@export var map_width: int = 26
@export var map_depth: int = 26
@export var wall_height: float = 3.0
@export var wall_thickness: float = 0.15

# Materials
var floor_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var ceiling_mat: StandardMaterial3D
var dark_wall_mat: StandardMaterial3D
var blood_mat: StandardMaterial3D
var tile_floor_mat: StandardMaterial3D
var door_frame_mat: StandardMaterial3D
var furniture_wood_mat: StandardMaterial3D
var furniture_metal_mat: StandardMaterial3D
var bed_mat: StandardMaterial3D

var _node_count: int = 0


func _ready():
	_setup_materials()
	_generate_map()


func _setup_materials():
	# Floor - BRIGHTER hospital tile
	floor_mat = StandardMaterial3D.new()
	var floor_tex = _load_texture("res://assets/textures/plank_floor_diff.jpg")
	if floor_tex:
		floor_mat.albedo_texture = floor_tex
		floor_mat.albedo_color = Color(0.55, 0.50, 0.45)
	else:
		floor_mat.albedo_color = Color(0.50, 0.45, 0.40)
	floor_mat.roughness = 0.8
	floor_mat.uv1_scale = Vector3(4, 1, 4)

	# Corridor floor - lighter tile
	tile_floor_mat = StandardMaterial3D.new()
	tile_floor_mat.albedo_color = Color(0.45, 0.42, 0.38)
	tile_floor_mat.roughness = 0.7
	tile_floor_mat.uv1_scale = Vector3(3, 1, 3)

	# Wall - MUCH BRIGHTER
	wall_mat = StandardMaterial3D.new()
	var wall_tex = _load_texture("res://assets/textures/brick_wall_diff.jpg")
	if wall_tex:
		wall_mat.albedo_texture = wall_tex
		wall_mat.albedo_color = Color(0.65, 0.58, 0.52)
	else:
		wall_mat.albedo_color = Color(0.55, 0.48, 0.42)
	wall_mat.roughness = 0.8
	wall_mat.uv1_scale = Vector3(2, 1.5, 2)

	# Dark wall for scary rooms (still visible)
	dark_wall_mat = StandardMaterial3D.new()
	dark_wall_mat.albedo_color = Color(0.40, 0.35, 0.38)
	dark_wall_mat.roughness = 0.9

	# Ceiling - brighter
	ceiling_mat = StandardMaterial3D.new()
	ceiling_mat.albedo_color = Color(0.38, 0.35, 0.38)
	ceiling_mat.roughness = 0.9

	# Blood stain
	blood_mat = StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.5, 0.05, 0.05, 0.85)
	blood_mat.transparency_enabled = true
	blood_mat.roughness = 0.7

	# Door frame
	door_frame_mat = StandardMaterial3D.new()
	door_frame_mat.albedo_color = Color(0.40, 0.25, 0.15)
	door_frame_mat.roughness = 0.8

	# Furniture - wood (brighter)
	furniture_wood_mat = StandardMaterial3D.new()
	furniture_wood_mat.albedo_color = Color(0.45, 0.30, 0.18)
	furniture_wood_mat.roughness = 0.85

	# Furniture - metal
	furniture_metal_mat = StandardMaterial3D.new()
	furniture_metal_mat.albedo_color = Color(0.50, 0.50, 0.55)
	furniture_metal_mat.roughness = 0.4
	furniture_metal_mat.metallic = 0.6

	# Bed mattress (brighter)
	bed_mat = StandardMaterial3D.new()
	bed_mat.albedo_color = Color(0.65, 0.65, 0.60)
	bed_mat.roughness = 0.9


func _generate_map():
	var hw = map_width / 2.0
	var hd = map_depth / 2.0

	# === FLOOR ===
	_make_solid_box(Vector3(0, -0.05, 0), Vector3(map_width, 0.1, map_depth), floor_mat)
	# Corridor floor (slightly raised different color)
	_make_solid_box(Vector3(0, 0.01, 0), Vector3(20, 0.01, 4), tile_floor_mat)
	_make_solid_box(Vector3(0, 0.01, 7), Vector3(4, 0.01, 10), tile_floor_mat)

	# === CEILING ===
	_make_solid_box(Vector3(0, wall_height + 0.05, 0), Vector3(map_width, 0.1, map_depth), ceiling_mat)

	# === OUTER WALLS ===
	_make_solid_box(Vector3(0, wall_height/2, -hd), Vector3(map_width, wall_height, wall_thickness), wall_mat)
	_make_solid_box(Vector3(0, wall_height/2, hd), Vector3(map_width, wall_height, wall_thickness), wall_mat)
	_make_solid_box(Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, map_depth), wall_mat)
	_make_solid_box(Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, map_depth), wall_mat)

	# === MAIN CORRIDOR (Z: -2 to 2, X: -10 to 10) ===
	# North corridor wall with 3 door gaps
	_make_wall_segment_x(Vector3(-10, wall_height/2, -2), 3.0)
	_make_door_gap_x(Vector3(-8, wall_height/2, -2))
	_make_wall_segment_x(Vector3(-5.5, wall_height/2, -2), 2.0)
	_make_door_gap_x(Vector3(0, wall_height/2, -2))
	_make_wall_segment_x(Vector3(2.5, wall_height/2, -2), 2.0)
	_make_door_gap_x(Vector3(8, wall_height/2, -2))
	_make_wall_segment_x(Vector3(10.5, wall_height/2, -2), 3.0)

	# South corridor wall with 3 door gaps
	_make_wall_segment_x(Vector3(-10, wall_height/2, 2), 3.0)
	_make_door_gap_x(Vector3(-8, wall_height/2, 2))
	_make_wall_segment_x(Vector3(-5.5, wall_height/2, 2), 2.0)
	_make_door_gap_x(Vector3(0, wall_height/2, 2))
	_make_wall_segment_x(Vector3(2.5, wall_height/2, 2), 2.0)
	_make_door_gap_x(Vector3(8, wall_height/2, 2))
	_make_wall_segment_x(Vector3(10.5, wall_height/2, 2), 3.0)

	# === ROOM DIVIDERS (NORTH SIDE) ===
	_make_solid_box(Vector3(-4, wall_height/2, -5), Vector3(wall_thickness, wall_height, 6), wall_mat)
	_make_solid_box(Vector3(4, wall_height/2, -5), Vector3(wall_thickness, wall_height, 6), wall_mat)
	# North room back walls
	_make_solid_box(Vector3(-8, wall_height/2, -8), Vector3(8, wall_height, wall_thickness), wall_mat)
	_make_solid_box(Vector3(0, wall_height/2, -8), Vector3(8, wall_height, wall_thickness), wall_mat)
	_make_solid_box(Vector3(8, wall_height/2, -8), Vector3(8, wall_height, wall_thickness), wall_mat)

	# === ROOM DIVIDERS (SOUTH SIDE) ===
	_make_solid_box(Vector3(-4, wall_height/2, 5), Vector3(wall_thickness, wall_height, 6), wall_mat)
	_make_solid_box(Vector3(4, wall_height/2, 5), Vector3(wall_thickness, wall_height, 6), wall_mat)
	# South room back walls
	_make_solid_box(Vector3(-8, wall_height/2, 8), Vector3(8, wall_height, wall_thickness), wall_mat)
	_make_solid_box(Vector3(0, wall_height/2, 8), Vector3(8, wall_height, wall_thickness), wall_mat)
	_make_solid_box(Vector3(8, wall_height/2, 8), Vector3(8, wall_height, wall_thickness), wall_mat)

	# === SIDE CORRIDOR (X: -2 to 2, Z: 2 to 12) ===
	_make_solid_box(Vector3(-2, wall_height/2, 7), Vector3(wall_thickness, wall_height, 10), wall_mat)
	# East wall of side corridor with door gaps
	_make_wall_segment_z(Vector3(2, wall_height/2, 3.5), 2.0)
	_make_door_gap_z(Vector3(2, wall_height/2, 5))
	_make_wall_segment_z(Vector3(2, wall_height/2, 7), 2.0)
	_make_door_gap_z(Vector3(2, wall_height/2, 9))
	_make_wall_segment_z(Vector3(2, wall_height/2, 10.5), 2.0)

	# === MORGUE & END AREA (Z: 10 to 13) ===
	_make_solid_box(Vector3(0, wall_height/2, 12.5), Vector3(4, wall_height, wall_thickness), dark_wall_mat)
	_make_solid_box(Vector3(-2, wall_height/2, 11), Vector3(wall_thickness, wall_height, 3), dark_wall_mat)
	_make_solid_box(Vector3(2, wall_height/2, 11), Vector3(wall_thickness, wall_height, 3), dark_wall_mat)

	# === DOOR FRAMES ===
	_add_door_frames()

	# === ROOM LABELS ===
	_add_room_labels()

	# === FURNITURE ===
	_add_furniture()

	# === BLOOD STAINS ===
	_add_blood_stains()

	# === LIGHTS - MUCH BRIGHTER for mobile! ===
	# Main corridor - VERY bright warm lights
	_make_light(Vector3(0, 2.7, 0), Color(1.0, 0.9, 0.7), 5.0, 30.0)       # Center - SUPER BRIGHT
	_make_light(Vector3(-7, 2.7, 0), Color(0.9, 0.8, 0.6), 4.0, 25.0)      # West corridor
	_make_light(Vector3(7, 2.7, 0), Color(0.9, 0.8, 0.6), 4.0, 25.0)       # East corridor

	# Room lights - brighter
	_make_light(Vector3(-10, 2.7, -5), Color(0.8, 0.7, 0.5), 3.0, 20.0)    # Surgery
	_make_light(Vector3(0, 2.7, -5), Color(0.8, 0.75, 0.5), 3.0, 20.0)     # Patient room
	_make_light(Vector3(10, 2.7, -5), Color(0.8, 0.75, 0.5), 2.5, 20.0)    # Lab
	_make_light(Vector3(-10, 2.7, 5), Color(0.8, 0.7, 0.5), 2.5, 20.0)     # Pharmacy
	_make_light(Vector3(0, 2.7, 7), Color(0.8, 0.7, 0.5), 3.0, 20.0)       # Side corridor
	_make_light(Vector3(10, 2.7, 5), Color(0.8, 0.7, 0.5), 2.5, 20.0)      # Ward B
	_make_light(Vector3(0, 2.7, 11.5), Color(0.7, 0.3, 0.3), 2.0, 15.0)    # Morgue (red-ish)

	# EXTRA lights in corridor for mobile visibility
	_make_light(Vector3(-3, 2.7, 0), Color(0.9, 0.8, 0.6), 3.0, 20.0)      # Extra corridor light
	_make_light(Vector3(3, 2.7, 0), Color(0.9, 0.8, 0.6), 3.0, 20.0)       # Extra corridor light
	_make_light(Vector3(0, 2.7, 4), Color(0.8, 0.7, 0.5), 2.5, 18.0)       # Corridor junction

	# === PLAYER START MARKER (bright green pillar so player knows they spawned) ===
	var start_marker_mat = StandardMaterial3D.new()
	start_marker_mat.albedo_color = Color(0, 1, 0)
	start_marker_mat.emission_enabled = true
	start_marker_mat.emission = Color(0, 1, 0)
	start_marker_mat.emission_energy = 2.0
	start_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_make_decoration(Vector3(0, 0.5, 0), Vector3(0.3, 1.0, 0.3), start_marker_mat)

	# === PATROL POINTS ===
	var patrol_positions = [
		Vector3(0, 0, -5),
		Vector3(-8, 0, -5),
		Vector3(8, 0, -5),
		Vector3(0, 0, 0),
		Vector3(-8, 0, 5),
		Vector3(8, 0, 5),
		Vector3(0, 0, 10),
		Vector3(0, 0, 7),
	]
	for pos in patrol_positions:
		var m = Marker3D.new()
		m.position = pos
		m.add_to_group("patrol_point")
		add_child(m)
		_node_count += 1

	# === KEY ITEMS ===
	_place_items()

	# === ESCAPE DOOR ===
	_place_escape_door()

	print("[Map] Hospital map ready: %dx%d, %d nodes" % [map_width, map_depth, _node_count])


func _make_solid_box(position: Vector3, size: Vector3, material: Material):
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
	_node_count += 1


func _make_wall_segment_x(center: Vector3, length: float):
	_make_solid_box(center, Vector3(length, wall_height, wall_thickness), wall_mat)


func _make_door_gap_x(center: Vector3):
	_make_solid_box(center + Vector3(-1.1, 0, 0), Vector3(0.2, wall_height, wall_thickness), wall_mat)
	_make_solid_box(center + Vector3(1.1, 0, 0), Vector3(0.2, wall_height, wall_thickness), wall_mat)
	_make_solid_box(center + Vector3(0, (wall_height - 2.2) / 2.0 + 2.2, 0), Vector3(2.0, wall_height - 2.2, wall_thickness), wall_mat)


func _make_wall_segment_z(center: Vector3, length: float):
	_make_solid_box(center, Vector3(wall_thickness, wall_height, length), wall_mat)


func _make_door_gap_z(center: Vector3):
	_make_solid_box(center + Vector3(0, 0, -1.1), Vector3(wall_thickness, wall_height, 0.2), wall_mat)
	_make_solid_box(center + Vector3(0, 0, 1.1), Vector3(wall_thickness, wall_height, 0.2), wall_mat)
	_make_solid_box(center + Vector3(0, (wall_height - 2.2) / 2.0 + 2.2, 0), Vector3(wall_thickness, wall_height - 2.2, 2.0), wall_mat)


func _add_door_frames():
	var door_positions = [
		Vector3(-8, 1.1, -2),
		Vector3(0, 1.1, -2),
		Vector3(8, 1.1, -2),
		Vector3(-8, 1.1, 2),
		Vector3(0, 1.1, 2),
		Vector3(8, 1.1, 2),
		Vector3(2, 1.1, 5),
		Vector3(2, 1.1, 9),
	]
	for pos in door_positions:
		_make_decoration(pos + Vector3(-1.05, 0, 0), Vector3(0.12, 2.2, 0.2), door_frame_mat)
		_make_decoration(pos + Vector3(1.05, 0, 0), Vector3(0.12, 2.2, 0.2), door_frame_mat)
		_make_decoration(pos + Vector3(0, 1.15, 0), Vector3(2.1, 0.12, 0.2), door_frame_mat)


func _add_room_labels():
	var room_labels = [
		{"pos": Vector3(-8, 2.2, -2.2), "text": "SURGERY", "color": Color(1, 0.4, 0.4)},
		{"pos": Vector3(0, 2.2, -2.2), "text": "PATIENT ROOM", "color": Color(0.5, 1, 0.5)},
		{"pos": Vector3(8, 2.2, -2.2), "text": "LAB", "color": Color(0.5, 0.5, 1)},
		{"pos": Vector3(-8, 2.2, 2.2), "text": "PHARMACY", "color": Color(0.7, 1, 0.3)},
		{"pos": Vector3(0, 2.2, 2.2), "text": "STORAGE", "color": Color(1, 0.8, 0.4)},
		{"pos": Vector3(8, 2.2, 2.2), "text": "WARD B", "color": Color(0.4, 1, 1)},
		{"pos": Vector3(2.3, 2.2, 5), "text": "OFFICE", "color": Color(1, 1, 0.5)},
		{"pos": Vector3(2.3, 2.2, 9), "text": "MORGUE", "color": Color(1, 0.3, 0.3)},
	]
	for rl in room_labels:
		var label = Label3D.new()
		label.text = rl.text
		label.position = rl.pos
		label.pixel_size = 0.025
		label.modulate = rl.color
		label.billboard = 1
		label.font_size = 16
		add_child(label)
		_node_count += 1

	# Direction signs
	var dir_label = Label3D.new()
	dir_label.text = "MORGUE ->"
	dir_label.position = Vector3(-1.8, 2.2, 4)
	dir_label.pixel_size = 0.02
	dir_label.modulate = Color(1, 0.6, 0.4)
	dir_label.billboard = 1
	add_child(dir_label)

	var exit_sign = Label3D.new()
	exit_sign.text = "EXIT ->"
	exit_sign.position = Vector3(10, 2.2, 0.5)
	exit_sign.pixel_size = 0.025
	exit_sign.modulate = Color(0, 1, 0)
	exit_sign.billboard = 1
	add_child(exit_sign)


func _add_furniture():
	# Room 1: Surgery
	_make_decoration(Vector3(-9, 0.4, -5), Vector3(2.5, 0.8, 1.2), furniture_metal_mat)
	_make_decoration(Vector3(-9, 0.85, -5), Vector3(2.3, 0.1, 1.0), bed_mat)
	_make_decoration(Vector3(-11, 0.5, -7), Vector3(0.8, 1.0, 0.5), furniture_metal_mat)
	_make_decoration(Vector3(-7, 0.8, -3.5), Vector3(0.05, 1.6, 0.05), furniture_metal_mat)
	_make_decoration(Vector3(-7, 1.6, -3.5), Vector3(0.3, 0.05, 0.3), furniture_metal_mat)

	# Room 2: Patient Room
	_make_decoration(Vector3(-2, 0.3, -5), Vector3(1.8, 0.6, 0.9), furniture_wood_mat)
	_make_decoration(Vector3(-2, 0.6, -5), Vector3(1.6, 0.1, 0.7), bed_mat)
	_make_decoration(Vector3(2, 0.3, -5), Vector3(1.8, 0.6, 0.9), furniture_wood_mat)
	_make_decoration(Vector3(2, 0.6, -5), Vector3(1.6, 0.1, 0.7), bed_mat)
	_make_decoration(Vector3(-0.5, 0.3, -3.5), Vector3(0.5, 0.6, 0.4), furniture_wood_mat)

	# Room 3: Lab
	_make_decoration(Vector3(7, 0.4, -5), Vector3(3.0, 0.8, 0.8), furniture_wood_mat)
	_make_decoration(Vector3(10, 0.4, -6), Vector3(0.6, 0.8, 0.6), furniture_metal_mat)
	_make_decoration(Vector3(9, 1.5, -7.8), Vector3(2.0, 0.1, 0.4), furniture_wood_mat)

	# Room 4: Pharmacy
	_make_decoration(Vector3(-8, 0.5, 5), Vector3(2.5, 1.0, 0.6), furniture_wood_mat)
	_make_decoration(Vector3(-11, 1.2, 6), Vector3(0.4, 1.8, 0.3), furniture_wood_mat)
	_make_decoration(Vector3(-10, 1.2, 7), Vector3(0.4, 1.8, 0.3), furniture_wood_mat)

	# Room 5: Storage
	_make_decoration(Vector3(-2, 0.4, 5), Vector3(1.5, 0.8, 1.0), furniture_wood_mat)
	_make_decoration(Vector3(1, 0.3, 4), Vector3(0.8, 0.6, 0.8), furniture_wood_mat)
	_make_decoration(Vector3(2, 0.4, 6), Vector3(1.2, 0.8, 0.6), furniture_wood_mat)

	# Room 6: Ward B
	_make_decoration(Vector3(6, 0.3, 4), Vector3(1.8, 0.6, 0.9), furniture_wood_mat)
	_make_decoration(Vector3(6, 0.6, 4), Vector3(1.6, 0.1, 0.7), bed_mat)
	_make_decoration(Vector3(9, 0.3, 4), Vector3(1.8, 0.6, 0.9), furniture_wood_mat)
	_make_decoration(Vector3(9, 0.6, 4), Vector3(1.6, 0.1, 0.7), bed_mat)
	_make_decoration(Vector3(11, 0.3, 7), Vector3(0.7, 0.6, 0.7), furniture_metal_mat)

	# Office area
	_make_decoration(Vector3(5, 0.35, 6), Vector3(1.5, 0.05, 0.8), furniture_wood_mat)
	_make_decoration(Vector3(5, 0.35, 6), Vector3(1.5, 0.7, 0.05), furniture_wood_mat)
	_make_decoration(Vector3(5, 0.25, 7), Vector3(0.5, 0.5, 0.5), furniture_wood_mat)

	# Morgue area
	_make_decoration(Vector3(-1, 0.3, 11.5), Vector3(2.0, 0.5, 0.8), furniture_metal_mat)
	_make_decoration(Vector3(1, 0.5, 11.5), Vector3(0.8, 1.0, 1.5), furniture_metal_mat)
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.3, 0.3, 0.35)
	body_mat.roughness = 0.9
	_make_decoration(Vector3(-1, 0.58, 11.5), Vector3(0.4, 0.15, 1.5), body_mat)


func _add_blood_stains():
	_make_decoration(Vector3(-9, 0.06, -5.5), Vector3(1.5, 0.01, 1.0), blood_mat)
	_make_decoration(Vector3(-10, 0.06, -4), Vector3(0.6, 0.01, 0.4), blood_mat)
	_make_decoration(Vector3(-1, 0.06, 11.5), Vector3(1.2, 0.01, 0.8), blood_mat)
	_make_decoration(Vector3(0.5, 0.06, 12), Vector3(0.5, 0.01, 0.5), blood_mat)
	_make_decoration(Vector3(3, 0.06, 0.5), Vector3(0.3, 0.01, 2.0), blood_mat)
	_make_decoration(Vector3(1, 0.06, 1.5), Vector3(0.2, 0.01, 1.0), blood_mat)
	_make_decoration(Vector3(-9.8, 1.2, -5), Vector3(0.01, 0.3, 0.2), blood_mat)
	_make_decoration(Vector3(-1.8, 1.5, 11), Vector3(0.01, 0.4, 0.25), blood_mat)
	_make_decoration(Vector3(9, 0.06, 4.5), Vector3(0.8, 0.01, 0.5), blood_mat)


func _make_decoration(position: Vector3, size: Vector3, mat):
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	if mat is StandardMaterial3D:
		mesh_inst.set_surface_override_material(mat)
	elif mat is Color:
		var m = StandardMaterial3D.new()
		m.albedo_color = mat
		m.roughness = 0.9
		mesh_inst.set_surface_override_material(m)
	mesh_inst.position = position
	add_child(mesh_inst)
	_node_count += 1


func _make_light(position: Vector3, color: Color, energy: float, range_val: float):
	var light = OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_val
	light.shadow_enabled = false
	add_child(light)
	_node_count += 1


func _place_items():
	var item_data = [
		{"type": 0, "pos": Vector3(-11, 0.5, -7), "name": "KEY_RED"},
		{"type": 1, "pos": Vector3(10, 0.5, -6), "name": "KEY_BLUE"},
		{"type": 2, "pos": Vector3(-11, 0.5, 6), "name": "KEY_GREEN"},
		{"type": 3, "pos": Vector3(-1, 0.5, 11), "name": "CAR_KEY"},
	]
	for item in item_data:
		var node = _create_item_node(item.type, item.name)
		node.position = item.pos
		add_child(node)
		_node_count += 1


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

	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.15, 0.5, 0.08)
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(0, 0.8, 0)
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy = 5.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match type:
		0: mat.albedo_color = Color(1,0.2,0.2); mat.emission = Color(1,0.2,0.2)
		1: mat.albedo_color = Color(0.2,0.4,1); mat.emission = Color(0.2,0.4,1)
		2: mat.albedo_color = Color(0.2,1,0.3); mat.emission = Color(0.2,1,0.3)
		3: mat.albedo_color = Color(1,0.8,0.2); mat.emission = Color(1,0.8,0.2)
	mesh_inst.set_surface_override_material(mat)
	area.add_child(mesh_inst)

	var key_light = OmniLight3D.new()
	key_light.position = Vector3(0, 0.8, 0)
	key_light.light_energy = 2.0
	key_light.omni_range = 6.0
	key_light.shadow_enabled = false
	match type:
		0: key_light.light_color = Color(1, 0.3, 0.3)
		1: key_light.light_color = Color(0.3, 0.5, 1)
		2: key_light.light_color = Color(0.3, 1, 0.4)
		3: key_light.light_color = Color(1, 0.9, 0.3)
	area.add_child(key_light)

	return area


func _place_escape_door():
	var door = StaticBody3D.new()
	door.collision_layer = 1
	door.set_script(load("res://scripts/escape_door.gd"))
	door.position = Vector3(12.5, 1.5, 0)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.2, 3.0, 1.5)
	col.shape = shape
	door.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.15, 3.0, 1.5)
	mesh_inst.mesh = box
	var dmat = StandardMaterial3D.new()
	dmat.albedo_color = Color(0.45, 0.3, 0.15)
	dmat.roughness = 0.7
	dmat.emission_enabled = true
	dmat.emission = Color(0.1, 0.3, 0.1)
	dmat.emission_energy = 1.0
	mesh_inst.set_surface_override_material(dmat)
	door.add_child(mesh_inst)

	var label = Label3D.new()
	label.text = "EXIT"
	label.position = Vector3(0, 1.0, 0)
	label.pixel_size = 0.03
	label.modulate = Color(0, 1, 0)
	label.billboard = 1
	door.add_child(label)

	# EXIT light above door
	var exit_light = OmniLight3D.new()
	exit_light.position = Vector3(0, 2.5, 0)
	exit_light.light_color = Color(0, 1, 0)
	exit_light.light_energy = 2.0
	exit_light.omni_range = 8.0
	exit_light.shadow_enabled = false
	door.add_child(exit_light)

	add_child(door)
	_node_count += 1


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
