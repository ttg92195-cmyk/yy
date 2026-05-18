extends Node3D
## MapGenerator - Procedurally generates a detailed horror hospital map
## Creates walls, floors, rooms, corridors, doors, furniture, decorations
## IMPORTANT: Everything visible on mobile with proper lighting!

@export var map_width: int = 50
@export var map_depth: int = 50
@export var wall_height: float = 3.2
@export var wall_thickness: float = 0.2

# Materials
var floor_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var ceiling_mat: StandardMaterial3D
var door_mat: StandardMaterial3D
var window_mat: StandardMaterial3D
var furniture_wood_mat: StandardMaterial3D
var furniture_metal_mat: StandardMaterial3D
var blood_mat: StandardMaterial3D
var tile_mat: StandardMaterial3D

func _ready():
        _setup_materials()
        _generate_map()


func _setup_materials():
        # Floor - plank flooring with REAL texture
        floor_mat = StandardMaterial3D.new()
        var floor_tex = _load_texture("res://assets/textures/plank_floor_diff.jpg")
        if floor_tex:
                floor_mat.albedo_texture = floor_tex
                # Darken slightly for horror atmosphere
                floor_mat.albedo_color = Color(0.6, 0.55, 0.5)
        else:
                floor_mat.albedo_color = Color(0.22, 0.20, 0.19)
        floor_mat.roughness = 0.8
        floor_mat.metallic = 0.05
        floor_mat.uv1_scale = Vector3(4, 4, 4)

        # Tile pattern for bathroom/operating rooms
        tile_mat = StandardMaterial3D.new()
        tile_mat.albedo_color = Color(0.28, 0.28, 0.30)
        tile_mat.roughness = 0.6
        tile_mat.metallic = 0.1

        # Walls - brick wall with REAL texture
        wall_mat = StandardMaterial3D.new()
        var wall_tex = _load_texture("res://assets/textures/brick_wall_diff.jpg")
        if wall_tex:
                wall_mat.albedo_texture = wall_tex
                # Darken for horror atmosphere
                wall_mat.albedo_color = Color(0.45, 0.4, 0.38)
        else:
                wall_mat.albedo_color = Color(0.28, 0.26, 0.25)
        wall_mat.roughness = 0.85
        wall_mat.uv1_scale = Vector3(3, 2, 3)

        # Bump/displacement map for walls (adds depth to brick)
        var wall_disp = _load_texture("res://assets/textures/brick_wall_disp.png")
        if wall_disp:
                wall_mat.heightmap_enabled = true
                wall_mat.heightmap_texture = wall_disp
                wall_mat.heightmap_scale = 0.02

        # Ceiling
        ceiling_mat = StandardMaterial3D.new()
        ceiling_mat.albedo_color = Color(0.18, 0.17, 0.18)
        ceiling_mat.roughness = 0.95

        # Door - dark wood (fallback if GLB doesn't load)
        door_mat = StandardMaterial3D.new()
        door_mat.albedo_color = Color(0.30, 0.18, 0.08)
        door_mat.roughness = 0.7
        door_mat.emission_enabled = true
        door_mat.emission = Color(0.1, 0.05, 0.0)
        door_mat.emission_energy = 0.3

        # Window - semi-transparent
        window_mat = StandardMaterial3D.new()
        window_mat.albedo_color = Color(0.3, 0.4, 0.5)
        window_mat.roughness = 0.1
        window_mat.metallic = 0.8
        window_mat.transmission_enabled = true
        window_mat.transmission = Color(0.2, 0.3, 0.4)

        # Furniture - wood
        furniture_wood_mat = StandardMaterial3D.new()
        furniture_wood_mat.albedo_color = Color(0.35, 0.22, 0.12)
        furniture_wood_mat.roughness = 0.8

        # Furniture - metal
        furniture_metal_mat = StandardMaterial3D.new()
        furniture_metal_mat.albedo_color = Color(0.4, 0.4, 0.42)
        furniture_metal_mat.roughness = 0.3
        furniture_metal_mat.metallic = 0.8

        # Blood stains
        blood_mat = StandardMaterial3D.new()
        blood_mat.albedo_color = Color(0.4, 0.02, 0.02)
        blood_mat.roughness = 0.6
        blood_mat.emission_enabled = true
        blood_mat.emission = Color(0.3, 0.0, 0.0)
        blood_mat.emission_energy = 0.2


func _generate_map():
        var half_w = map_width / 2.0
        var half_d = map_depth / 2.0

        # 1. Floor
        _create_floor(map_width, map_depth)

        # 2. Ceiling
        _create_ceiling(map_width, map_depth, wall_height)

        # 3. Outer walls with windows
        _create_outer_walls(half_w, half_d, wall_height)

        # 4. Inner structure - detailed rooms
        _create_inner_structure(half_w, half_d)

        # 5. Atmospheric lights
        _add_lights()

        # 6. Patrol markers
        _add_patrol_markers()

        # 7. Items
        _place_items()

        # 8. Escape door
        _place_escape_door()

        # 9. Decorations (blood, writings, cobwebs)
        _add_decorations()

        print("[MapGenerator] Detailed horror map generated: %dx%d" % [map_width, map_depth])


# ============ BASIC STRUCTURE ============

func _create_floor(w: float, d: float):
        var floor_body = StaticBody3D.new()
        floor_body.collision_layer = 1

        var collision = CollisionShape3D.new()
        var shape = BoxShape3D.new()
        shape.size = Vector3(w, 0.1, d)
        collision.shape = shape
        floor_body.add_child(collision)

        var mesh_inst = MeshInstance3D.new()
        var box_mesh = BoxMesh.new()
        box_mesh.size = Vector3(w, 0.1, d)
        mesh_inst.mesh = box_mesh
        mesh_inst.set_surface_override_material(floor_mat)
        floor_body.add_child(mesh_inst)

        floor_body.position = Vector3(0, -0.05, 0)
        add_child(floor_body)

        # Add floor tile lines for hospital look
        _create_floor_tiles()


func _create_floor_tiles():
        ## Create subtle floor tile grid lines
        var tile_line_mat = StandardMaterial3D.new()
        tile_line_mat.albedo_color = Color(0.15, 0.13, 0.13)
        tile_line_mat.roughness = 0.9

        for x in range(-24, 25, 3):
                var line = MeshInstance3D.new()
                var line_mesh = BoxMesh.new()
                line_mesh.size = Vector3(0.02, 0.002, map_depth)
                line.mesh = line_mesh
                line.set_surface_override_material(tile_line_mat)
                line.position = Vector3(x, 0.01, 0)
                add_child(line)

        for z in range(-24, 25, 3):
                var line = MeshInstance3D.new()
                var line_mesh = BoxMesh.new()
                line_mesh.size = Vector3(map_width, 0.002, 0.02)
                line.mesh = line_mesh
                line.set_surface_override_material(tile_line_mat)
                line.position = Vector3(0, 0.01, z)
                add_child(line)


func _create_ceiling(w: float, d: float, h: float):
        var ceiling_body = StaticBody3D.new()
        ceiling_body.collision_layer = 1

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

        # Ceiling pipes
        _create_ceiling_pipes()


func _create_ceiling_pipes():
        ## Add exposed pipes on ceiling for horror hospital feel
        var pipe_mat = StandardMaterial3D.new()
        pipe_mat.albedo_color = Color(0.3, 0.3, 0.25)
        pipe_mat.roughness = 0.5
        pipe_mat.metallic = 0.7

        var pipe_positions = [
                {"pos": Vector3(-8, wall_height - 0.2, 0), "size": Vector3(0.08, 0.08, 40)},
                {"pos": Vector3(8, wall_height - 0.2, 0), "size": Vector3(0.08, 0.08, 40)},
                {"pos": Vector3(0, wall_height - 0.15, -10), "size": Vector3(40, 0.06, 0.06)},
                {"pos": Vector3(0, wall_height - 0.15, 10), "size": Vector3(40, 0.06, 0.06)},
        ]

        for pipe in pipe_positions:
                var mesh_inst = MeshInstance3D.new()
                var box_mesh = BoxMesh.new()
                box_mesh.size = pipe.size
                mesh_inst.mesh = box_mesh
                mesh_inst.set_surface_override_material(pipe_mat)
                mesh_inst.position = pipe.pos
                add_child(mesh_inst)


func _create_outer_walls(half_w: float, half_d: float, h: float):
        # North wall (with windows)
        _create_wall_with_windows(Vector3(0, h/2, -half_d), Vector3(map_width, h, wall_thickness), "north")
        # South wall (with door opening)
        _create_wall_with_windows(Vector3(0, h/2, half_d), Vector3(map_width, h, wall_thickness), "south")
        # East wall
        _create_wall_with_windows(Vector3(half_w, h/2, 0), Vector3(wall_thickness, h, map_depth), "east")
        # West wall
        _create_wall_with_windows(Vector3(-half_w, h/2, 0), Vector3(wall_thickness, h, map_depth), "west")


func _create_wall_with_windows(position: Vector3, size: Vector3, side: String):
        ## Create wall with window openings for hospital feel
        # Main wall
        _create_wall(position, size)

        # Add windows along the wall
        if side == "north" or side == "south":
                for x in range(-20, 21, 10):
                        _create_window(Vector3(x, wall_height * 0.7, position.z), side)
        elif side == "east" or side == "west":
                for z in range(-15, 16, 10):
                        _create_window(Vector3(position.x, wall_height * 0.7, z), side)


func _create_window(position: Vector3, side: String):
        ## Create a window frame with glass
        var window_size = Vector3(1.5, 1.0, 0.05) if (side == "north" or side == "south") else Vector3(0.05, 1.0, 1.5)

        # Window glass
        var glass = MeshInstance3D.new()
        var glass_mesh = BoxMesh.new()
        glass_mesh.size = window_size
        glass.mesh = glass_mesh
        glass.set_surface_override_material(window_mat)
        glass.position = position
        add_child(glass)

        # Window frame
        var frame_mat = StandardMaterial3D.new()
        frame_mat.albedo_color = Color(0.25, 0.25, 0.23)
        frame_mat.roughness = 0.5
        frame_mat.metallic = 0.6

        # Top frame piece
        var frame_top = MeshInstance3D.new()
        var ft_mesh = BoxMesh.new()
        ft_mesh.size = window_size + Vector3(0.1, 0.05, 0.1)
        frame_top.mesh = ft_mesh
        frame_top.set_surface_override_material(frame_mat)
        frame_top.position = position + Vector3(0, 0.525, 0)
        add_child(frame_top)

        # Faint moonlight through window
        var moon_light = SpotLight3D.new()
        moon_light.position = position + Vector3(0, 0, 0.5 if side == "north" else -0.5)
        moon_light.light_color = Color(0.3, 0.35, 0.5)
        moon_light.light_energy = 0.3
        moon_light.spot_range = 8.0
        moon_light.spot_angle = 50.0
        moon_light.shadow_enabled = false
        add_child(moon_light)


func _create_wall(position: Vector3, size: Vector3):
        var wall_body = StaticBody3D.new()
        wall_body.collision_layer = 1

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


# ============ DETAILED ROOMS ============

func _create_inner_structure(half_w: float, half_d: float):
        ## Create detailed rooms with specific purposes

        # Main corridor walls (horizontal)
        _create_wall(Vector3(0, wall_height/2, -4), Vector3(map_width - 10, wall_height, wall_thickness))
        _create_wall(Vector3(0, wall_height/2, 4), Vector3(map_width - 10, wall_height, wall_thickness))

        # Main corridor walls (vertical)
        _create_wall(Vector3(-4, wall_height/2, 0), Vector3(wall_thickness, wall_height, map_depth - 10))
        _create_wall(Vector3(4, wall_height/2, 0), Vector3(wall_thickness, wall_height, map_depth - 10))

        # ---- ROOM 1: Reception/Lobby ----
        _create_room_reception()

        # ---- ROOM 2: Storage Room ----
        _create_room_storage()

        # ---- ROOM 3: Operating Room ----
        _create_room_operating()

        # ---- ROOM 4: Morgue ----
        _create_room_morgue()

        # ---- ROOM 5: Office ----
        _create_room_office()

        # ---- ROOM 6: Bathroom ----
        _create_room_bathroom()

        # ---- Corridor furniture ----
        _create_corridor_details()


func _create_room_reception():
        ## Reception - entrance area with desk, chairs, computer
        var center = Vector3(-12, 0, -12)
        var hw = 4.0
        var hd = 4.0

        # Room walls with door opening
        _create_wall(center + Vector3(-hw/2 - 0.5, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw/2 + 0.5, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(-hw/2 - 0.5, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw/2 + 0.5, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))
        _create_wall(center + Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))

        # Reception desk
        _create_furniture_box(center + Vector3(-1, 0.45, -1), Vector3(2.5, 0.9, 0.8), furniture_wood_mat)
        # Computer monitor on desk
        _create_furniture_box(center + Vector3(-0.5, 1.05, -1), Vector3(0.5, 0.4, 0.05), furniture_metal_mat)
        # Chair behind desk
        _create_furniture_box(center + Vector3(-1, 0.25, -0.2), Vector3(0.5, 0.5, 0.5), furniture_wood_mat)
        # Waiting chairs
        _create_furniture_box(center + Vector3(2, 0.25, -2), Vector3(0.5, 0.5, 0.5), furniture_wood_mat)
        _create_furniture_box(center + Vector3(2, 0.25, -1), Vector3(0.5, 0.5, 0.5), furniture_wood_mat)
        # Filing cabinet
        _create_furniture_box(center + Vector3(-3, 0.6, -2), Vector3(0.6, 1.2, 0.5), furniture_metal_mat)

        # Room label
        _create_room_label(center + Vector3(0, 2.8, 0), "RECEPTION")

        # Door model at room entrance
        _place_door_model(self, center + Vector3(0, 0, hd + 0.15), 0.0, 1.2)

        # Light
        _create_room_light(center + Vector3(0, 2.8, 0), Color(0.65, 0.55, 0.35), 1.5, 14.0)


func _create_room_storage():
        ## Storage room - shelves, boxes, cluttered
        var center = Vector3(12, 0, -12)
        var hw = 3.5
        var hd = 3.0

        _create_wall(center + Vector3(-hw/2 - 0.5, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw/2 + 0.5, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(-hw/2 - 0.5, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw/2 + 0.5, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))
        _create_wall(center + Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))

        # Shelving units (tall)
        _create_furniture_box(center + Vector3(-2, 1.0, -1), Vector3(0.4, 2.0, 1.5), furniture_metal_mat)
        _create_furniture_box(center + Vector3(-2, 1.0, 1), Vector3(0.4, 2.0, 1.5), furniture_metal_mat)
        # Boxes on floor
        _create_furniture_box(center + Vector3(0, 0.3, -1), Vector3(0.8, 0.6, 0.6), furniture_wood_mat)
        _create_furniture_box(center + Vector3(1, 0.25, 0), Vector3(0.5, 0.5, 0.5), furniture_wood_mat)
        _create_furniture_box(center + Vector3(1.5, 0.25, -1.5), Vector3(0.5, 0.5, 0.5), furniture_wood_mat)
        # Old cabinet
        _create_furniture_box(center + Vector3(2, 0.8, 0), Vector3(0.7, 1.6, 0.5), furniture_wood_mat)

        _create_room_label(center + Vector3(0, 2.8, 0), "STORAGE")
        _place_door_model(self, center + Vector3(0, 0, hd + 0.15), 0.0, 1.0)
        _create_room_light(center + Vector3(0, 2.8, 0), Color(0.55, 0.5, 0.35), 0.8, 12.0)  # Dimmer - storage


func _create_room_operating():
        ## Operating room - surgery table, equipment, bright clinical light
        var center = Vector3(-12, 0, 8)
        var hw = 4.0
        var hd = 3.5

        _create_wall(center + Vector3(-hw/2 - 0.5, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw/2 + 0.5, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(-hw/2 - 0.5, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw/2 + 0.5, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))
        _create_wall(center + Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))

        # Operating table (main)
        var table_mat = StandardMaterial3D.new()
        table_mat.albedo_color = Color(0.5, 0.5, 0.52)
        table_mat.roughness = 0.3
        table_mat.metallic = 0.7
        _create_furniture_box(center + Vector3(0, 0.4, 0), Vector3(2.0, 0.15, 0.8), table_mat)
        # Table legs
        _create_furniture_box(center + Vector3(-0.8, 0.2, 0.3), Vector3(0.08, 0.4, 0.08), table_mat)
        _create_furniture_box(center + Vector3(0.8, 0.2, 0.3), Vector3(0.08, 0.4, 0.08), table_mat)
        _create_furniture_box(center + Vector3(-0.8, 0.2, -0.3), Vector3(0.08, 0.4, 0.08), table_mat)
        _create_furniture_box(center + Vector3(0.8, 0.2, -0.3), Vector3(0.08, 0.4, 0.08), table_mat)

        # IV stand
        _create_furniture_box(center + Vector3(1.2, 0.03, 0), Vector3(0.3, 0.06, 0.3), furniture_metal_mat)
        _create_furniture_box(center + Vector3(1.2, 1.0, 0), Vector3(0.03, 2.0, 0.03), furniture_metal_mat)

        # Equipment tray
        _create_furniture_box(center + Vector3(-1.5, 0.5, 0.5), Vector3(0.8, 0.04, 0.5), furniture_metal_mat)
        _create_furniture_box(center + Vector3(-1.5, 0.25, 0.5), Vector3(0.4, 0.5, 0.4), furniture_metal_mat)

        # Surgery light (bright overhead)
        var surgery_light = SpotLight3D.new()
        surgery_light.position = center + Vector3(0, wall_height - 0.1, 0)
        surgery_light.light_color = Color(0.9, 0.9, 0.95)
        surgery_light.light_energy = 3.0
        surgery_light.spot_range = 8.0
        surgery_light.spot_angle = 60.0
        surgery_light.shadow_enabled = false
        add_child(surgery_light)

        _create_room_label(center + Vector3(0, 2.8, 0), "OPERATING ROOM")
        _place_door_model(self, center + Vector3(0, 0, hd + 0.15), 0.0, 1.2)
        _create_room_light(center + Vector3(0, 2.8, 0), Color(0.7, 0.7, 0.75), 1.0, 12.0)


func _create_room_morgue():
        ## Morgue - body drawers, cold atmosphere
        var center = Vector3(12, 0, 8)
        var hw = 3.0
        var hd = 3.0

        _create_wall(center + Vector3(-hw/2 - 0.5, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw/2 + 0.5, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(-hw/2 - 0.5, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw/2 + 0.5, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))
        _create_wall(center + Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))

        # Morgue drawer wall (stacked metal drawers)
        _create_furniture_box(center + Vector3(-2, 0.5, 0), Vector3(0.6, 1.0, 2.0), furniture_metal_mat)
        _create_furniture_box(center + Vector3(-2, 1.5, 0), Vector3(0.6, 1.0, 2.0), furniture_metal_mat)
        # Drawer handles
        var handle_mat = StandardMaterial3D.new()
        handle_mat.albedo_color = Color(0.6, 0.6, 0.6)
        handle_mat.roughness = 0.3
        handle_mat.metallic = 0.9
        _create_furniture_box(center + Vector3(-1.65, 0.5, 0.3), Vector3(0.05, 0.05, 0.3), handle_mat)
        _create_furniture_box(center + Vector3(-1.65, 1.5, -0.3), Vector3(0.05, 0.05, 0.3), handle_mat)

        # Body slab (pulled out partially)
        _create_furniture_box(center + Vector3(1, 0.4, 0), Vector3(1.8, 0.08, 0.7), furniture_metal_mat)

        # Cold blue light
        _create_room_label(center + Vector3(0, 2.8, 0), "MORGUE")
        _place_door_model(self, center + Vector3(0, 0, hd + 0.15), 0.0, 1.0)
        _create_room_light(center + Vector3(0, 2.8, 0), Color(0.3, 0.4, 0.6), 0.7, 10.0)  # Cold blue


func _create_room_office():
        ## Office - desk, bookshelf, papers
        var center = Vector3(0, 0, -18)
        var hw = 2.5
        var hd = 2.5

        _create_wall(center + Vector3(-hw/2 - 0.5, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw/2 + 0.5, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(-hw/2 - 0.5, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw/2 + 0.5, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))
        _create_wall(center + Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))

        # Desk
        _create_furniture_box(center + Vector3(0, 0.4, -1), Vector3(1.8, 0.08, 0.8), furniture_wood_mat)
        _create_furniture_box(center + Vector3(-0.7, 0.2, -1), Vector3(0.08, 0.4, 0.08), furniture_wood_mat)
        _create_furniture_box(center + Vector3(0.7, 0.2, -1), Vector3(0.08, 0.4, 0.08), furniture_wood_mat)

        # Chair
        _create_furniture_box(center + Vector3(0, 0.25, -0.3), Vector3(0.5, 0.5, 0.5), furniture_wood_mat)

        # Bookshelf
        _create_furniture_box(center + Vector3(1.5, 0.8, 0), Vector3(0.4, 1.6, 1.2), furniture_wood_mat)

        _create_room_label(center + Vector3(0, 2.8, 0), "DOCTOR'S OFFICE")
        _place_door_model(self, center + Vector3(0, 0, hd + 0.15), 0.0, 1.0)
        _create_room_light(center + Vector3(0, 2.8, 0), Color(0.65, 0.55, 0.35), 1.0, 10.0)


func _create_room_bathroom():
        ## Bathroom - tiles, mirror, sink, bathtub
        var center = Vector3(0, 0, 14)
        var hw = 2.5
        var hd = 2.0

        _create_wall(center + Vector3(-hw/2 - 0.5, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw/2 + 0.5, wall_height/2, -hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(-hw/2 - 0.5, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw/2 + 0.5, wall_height/2, hd), Vector3(hw - 1, wall_height, wall_thickness))
        _create_wall(center + Vector3(hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))
        _create_wall(center + Vector3(-hw, wall_height/2, 0), Vector3(wall_thickness, wall_height, hd * 2))

        # Bathtub
        _create_furniture_box(center + Vector3(-1, 0.3, 0.5), Vector3(1.8, 0.6, 0.8), tile_mat)

        # Sink
        _create_furniture_box(center + Vector3(1, 0.5, -1), Vector3(0.6, 0.1, 0.4), tile_mat)
        _create_furniture_box(center + Vector3(1, 0.25, -1), Vector3(0.4, 0.5, 0.3), furniture_metal_mat)

        # Mirror (above sink)
        var mirror_mat = StandardMaterial3D.new()
        mirror_mat.albedo_color = Color(0.6, 0.65, 0.7)
        mirror_mat.roughness = 0.05
        mirror_mat.metallic = 0.9
        _create_furniture_box(center + Vector3(1, 1.6, -1.45), Vector3(0.5, 0.7, 0.03), mirror_mat)

        _create_room_label(center + Vector3(0, 2.8, 0), "BATHROOM")
        _place_door_model(self, center + Vector3(0, 0, hd + 0.15), 0.0, 0.9)
        _create_room_light(center + Vector3(0, 2.8, 0), Color(0.5, 0.55, 0.65), 0.8, 10.0)


func _create_corridor_details():
        ## Add details to corridors - benches, signs, trash
        # Corridor bench
        _create_furniture_box(Vector3(0, 0.25, -2), Vector3(1.5, 0.08, 0.4), furniture_wood_mat)
        _create_furniture_box(Vector3(-0.6, 0.12, -2), Vector3(0.08, 0.25, 0.08), furniture_metal_mat)
        _create_furniture_box(Vector3(0.6, 0.12, -2), Vector3(0.08, 0.25, 0.08), furniture_metal_mat)

        # Another bench
        _create_furniture_box(Vector3(0, 0.25, 2), Vector3(1.5, 0.08, 0.4), furniture_wood_mat)

        # Trash can
        var trash_mat = StandardMaterial3D.new()
        trash_mat.albedo_color = Color(0.3, 0.3, 0.28)
        trash_mat.roughness = 0.6
        trash_mat.metallic = 0.4
        _create_furniture_box(Vector3(-2, 0.25, -2), Vector3(0.3, 0.5, 0.3), trash_mat)

        # Wheelchair (simplified)
        _create_furniture_box(Vector3(6, 0.3, -2), Vector3(0.6, 0.6, 0.6), furniture_metal_mat)
        _create_furniture_box(Vector3(6, 0.7, -2.3), Vector3(0.5, 0.4, 0.05), furniture_metal_mat)

        # Overturned gurney in corridor
        _create_furniture_box(Vector3(-6, 0.15, 2), Vector3(1.8, 0.08, 0.7), furniture_metal_mat)

        # Exit sign (glowing green)
        var exit_sign_mat = StandardMaterial3D.new()
        exit_sign_mat.albedo_color = Color(0.0, 0.3, 0.0)
        exit_sign_mat.emission_enabled = true
        exit_sign_mat.emission = Color(0.0, 0.8, 0.0)
        exit_sign_mat.emission_energy = 2.0
        var exit_sign = MeshInstance3D.new()
        var es_mesh = BoxMesh.new()
        es_mesh.size = Vector3(0.8, 0.3, 0.05)
        exit_sign.mesh = es_mesh
        exit_sign.set_surface_override_material(exit_sign_mat)
        exit_sign.position = Vector3(0, wall_height - 0.3, 4.5)
        add_child(exit_sign)

        # EXIT label
        var exit_label = Label3D.new()
        exit_label.text = "EXIT ->"
        exit_label.position = Vector3(0, wall_height - 0.3, 4.55)
        exit_label.billboard = 1
        exit_label.pixel_size = 0.02
        exit_label.modulate = Color(0, 1, 0)
        add_child(exit_label)


# ============ DECORATIONS ============

func _add_decorations():
        ## Add horror decorations: blood stains, wall writings, cobwebs, flickering lights

        # Blood stains on floor
        _create_blood_stain(Vector3(-5, 0.01, -8), Vector3(1.5, 0.002, 0.8))
        _create_blood_stain(Vector3(8, 0.01, 3), Vector3(0.8, 0.002, 1.2))
        _create_blood_stain(Vector3(-10, 0.01, 9), Vector3(2.0, 0.002, 1.0))
        _create_blood_stain(Vector3(0, 0.01, -6), Vector3(0.5, 0.002, 0.5))  # Blood drip trail
        _create_blood_stain(Vector3(0, 0.01, -5), Vector3(0.3, 0.002, 0.3))
        _create_blood_stain(Vector3(0, 0.01, -4), Vector3(0.2, 0.002, 0.2))

        # Blood on walls
        _create_wall_blood(Vector3(-12.1, 1.2, -10), Vector3(0.01, 1.0, 0.5))
        _create_wall_blood(Vector3(10, 0.8, -12.1), Vector3(0.5, 1.5, 0.01))

        # Wall writings (horror messages using Label3D)
        _create_wall_writing(Vector3(-4.1, 1.5, -8), "GET OUT", 0.03)
        _create_wall_writing(Vector3(4.1, 1.5, 5), "HELP ME", 0.025)
        _create_wall_writing(Vector3(-4.1, 1.8, 12), "IT'S WATCHING", 0.025)
        _create_wall_writing(Vector3(12.1, 1.3, 7), "DON'T LOOK BACK", 0.02)

        # Flickering light (corridor horror effect)
        _create_flickering_light(Vector3(0, 2.8, -12), Color(0.7, 0.55, 0.3), 0.8)
        _create_flickering_light(Vector3(-15, 2.8, 0), Color(0.6, 0.5, 0.3), 0.6)

        # Broken light (just fixture, no light)
        var broken_fixture = MeshInstance3D.new()
        var bf_mesh = BoxMesh.new()
        bf_mesh.size = Vector3(0.3, 0.1, 0.3)
        broken_fixture.mesh = bf_mesh
        broken_fixture.position = Vector3(8, 2.9, 0)
        var bf_mat = StandardMaterial3D.new()
        bf_mat.albedo_color = Color(0.2, 0.2, 0.18)
        broken_fixture.set_surface_override_material(bf_mat)
        add_child(broken_fixture)


func _create_blood_stain(position: Vector3, size: Vector3):
        var blood = MeshInstance3D.new()
        var mesh = BoxMesh.new()
        mesh.size = size
        blood.mesh = mesh
        blood.set_surface_override_material(blood_mat)
        blood.position = position
        add_child(blood)


func _create_wall_blood(position: Vector3, size: Vector3):
        var blood = MeshInstance3D.new()
        var mesh = BoxMesh.new()
        mesh.size = size
        blood.mesh = mesh
        blood.set_surface_override_material(blood_mat)
        blood.position = position
        add_child(blood)


func _create_wall_writing(position: Vector3, text: String, pixel_size: float):
        var label = Label3D.new()
        label.text = text
        label.position = position
        label.pixel_size = pixel_size
        label.modulate = Color(0.6, 0.0, 0.0)  # Dark red writing
        label.billboard = 0  # Face the wall direction
        label.rotation = Vector3(0, deg_to_rad(90) if abs(position.x) > abs(position.z) else 0, 0)
        add_child(label)


func _create_flickering_light(position: Vector3, color: Color, energy: float):
        ## Create a light that flickers (simulated by script)
        var light = OmniLight3D.new()
        light.position = position
        light.light_color = color
        light.light_energy = energy
        light.omni_range = 14.0
        light.shadow_enabled = false
        add_child(light)

        # Fixture
        var fixture = MeshInstance3D.new()
        var fix_mesh = BoxMesh.new()
        fix_mesh.size = Vector3(0.3, 0.1, 0.3)
        fixture.mesh = fix_mesh
        fixture.position = position + Vector3(0, 0.15, 0)
        var fix_mat = StandardMaterial3D.new()
        fix_mat.albedo_color = Color(0.8, 0.7, 0.3)
        fix_mat.emission_enabled = true
        fix_mat.emission = Color(0.5, 0.35, 0.2)
        fix_mat.emission_energy = 2.0
        fixture.set_surface_override_material(fix_mat)
        add_child(fixture)

        # Attach flicker script
        var flicker_script = GDScript.new()
        flicker_script.source_code = """
extends OmniLight3D

var base_energy: float
var flicker_timer: float = 0.0
var next_flicker: float = 0.0

func _ready():
        base_energy = light_energy

func _process(delta):
        flicker_timer += delta
        if flicker_timer >= next_flicker:
                flicker_timer = 0.0
                next_flicker = randf_range(0.05, 0.3)
                if randf() < 0.15:
                        light_energy = 0.0
                else:
                        light_energy = base_energy * randf_range(0.7, 1.1)
"""
        flicker_script.reload()
        light.set_script(flicker_script)


# ============ HELPER FUNCTIONS ============

func _load_texture(path: String) -> Texture2D:
        ## Safely load a texture - returns null if not found
        if ResourceLoader.exists(path):
                return load(path) as Texture2D
        else:
                print("[MapGenerator] Texture not found: %s (using fallback color)" % path)
                return null


func _place_door_model(parent: Node3D, position: Vector3, rotation_y: float = 0.0, scale: float = 1.0):
        ## Place a 3D door model from GLB, with fallback to box mesh
        var door_scene_path = "res://assets/models/door.glb"
        if ResourceLoader.exists(door_scene_path):
                var door_scene = load(door_scene_path)
                if door_scene:
                        var door_inst = door_scene.instantiate()
                        door_inst.position = position
                        door_inst.rotation.y = rotation_y
                        door_inst.scale = Vector3(scale, scale, scale)
                        parent.add_child(door_inst)
                        return
        # Fallback: simple box door
        var door_fallback = MeshInstance3D.new()
        var door_box = BoxMesh.new()
        door_box.size = Vector3(1.0, 2.2, 0.08)
        door_fallback.mesh = door_box
        door_fallback.position = position
        door_fallback.rotation.y = rotation_y
        door_fallback.set_surface_override_material(door_mat)
        parent.add_child(door_fallback)


func _place_flashlight_model(parent: Node3D, position: Vector3, rotation: Vector3 = Vector3.ZERO, scale: float = 0.3):
        ## Place a 3D flashlight model from GLB, with fallback
        var flashlight_path = "res://assets/models/flashlight.glb"
        if ResourceLoader.exists(flashlight_path):
                var flashlight_scene = load(flashlight_path)
                if flashlight_scene:
                        var flash_inst = flashlight_scene.instantiate()
                        flash_inst.position = position
                        flash_inst.rotation = rotation
                        flash_inst.scale = Vector3(scale, scale, scale)
                        parent.add_child(flash_inst)
                        return
        # Fallback: simple cylinder
        var flash_fallback = MeshInstance3D.new()
        var cyl = CylinderMesh.new()
        cyl.top_radius = 0.03
        cyl.bottom_radius = 0.05
        cyl.height = 0.2
        flash_fallback.mesh = cyl
        flash_fallback.position = position
        flash_fallback.rotation = rotation
        var flash_mat = StandardMaterial3D.new()
        flash_mat.albedo_color = Color(0.3, 0.3, 0.35)
        flash_mat.roughness = 0.4
        flash_mat.metallic = 0.7
        flash_fallback.set_surface_override_material(flash_mat)
        parent.add_child(flash_fallback)


func _create_furniture_box(position: Vector3, size: Vector3, material: Material):
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
        mesh_inst.set_surface_override_material(material)
        body.add_child(mesh_inst)

        body.position = position
        add_child(body)


func _create_room_label(position: Vector3, text: String):
        var label = Label3D.new()
        label.text = text
        label.position = position
        label.modulate = Color(1, 1, 1, 0.3)
        label.pixel_size = 0.025
        label.billboard = 1
        add_child(label)


func _create_room_light(position: Vector3, color: Color, energy: float, range: float):
        var light = OmniLight3D.new()
        light.position = position
        light.light_color = color
        light.light_energy = energy
        light.omni_range = range
        light.shadow_enabled = false
        add_child(light)

        # Light fixture
        var fixture = MeshInstance3D.new()
        var fix_mesh = BoxMesh.new()
        fix_mesh.size = Vector3(0.4, 0.08, 0.4)
        fixture.mesh = fix_mesh
        fixture.position = position + Vector3(0, 0.13, 0)
        var fix_mat = StandardMaterial3D.new()
        fix_mat.albedo_color = Color(0.8, 0.7, 0.3)
        fix_mat.emission_enabled = true
        fix_mat.emission = Color(0.5, 0.35, 0.2)
        fix_mat.emission_energy = 2.0
        fixture.set_surface_override_material(fix_mat)
        add_child(fixture)


func _add_lights():
        ## Corridor lights - bright enough for mobile
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
                Vector3(-8, 2.8, -12),
                Vector3(8, 2.8, -12),
                Vector3(-8, 2.8, 12),
                Vector3(8, 2.8, 12),
        ]

        for pos in light_positions:
                var light = OmniLight3D.new()
                light.position = pos
                light.light_color = Color(0.7, 0.55, 0.3)
                light.light_energy = 1.0
                light.omni_range = 16.0
                light.shadow_enabled = false
                add_child(light)

                # Fixture
                var fixture = MeshInstance3D.new()
                var fix_mesh = BoxMesh.new()
                fix_mesh.size = Vector3(0.3, 0.1, 0.3)
                fixture.mesh = fix_mesh
                fixture.position = pos + Vector3(0, 0.15, 0)
                var fix_mat = StandardMaterial3D.new()
                fix_mat.albedo_color = Color(0.8, 0.7, 0.3)
                fix_mat.emission_enabled = true
                fix_mat.emission = Color(0.5, 0.35, 0.2)
                fix_mat.emission_energy = 2.0
                fixture.set_surface_override_material(fix_mat)
                add_child(fixture)


func _add_patrol_markers():
        var patrol_positions = [
                Vector3(0, 0, -15),
                Vector3(15, 0, -10),
                Vector3(-15, 0, -10),
                Vector3(15, 0, 10),
                Vector3(-15, 0, 10),
                Vector3(0, 0, 15),
                Vector3(0, 0, 0),
                Vector3(-12, 0, -12),
                Vector3(12, 0, 8),
        ]

        for pos in patrol_positions:
                var marker = Marker3D.new()
                marker.position = pos
                marker.add_to_group("patrol_point")
                add_child(marker)


func _place_items():
        var item_data = [
                {"type": 0, "pos": Vector3(-12, 0.5, -14), "name": "KEY_RED"},
                {"type": 1, "pos": Vector3(12, 0.5, -14), "name": "KEY_BLUE"},
                {"type": 2, "pos": Vector3(-12, 0.5, 10), "name": "KEY_GREEN"},
                {"type": 3, "pos": Vector3(12, 0.5, 10), "name": "CAR_KEY"},
        ]

        for item in item_data:
                var item_scene = _create_item_node(item.type, item.name)
                item_scene.position = item.pos
                if has_node("Items"):
                        $Items.add_child(item_scene)
                else:
                        add_child(item_scene)


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

        # Key-shaped mesh (elongated)
        var mesh_inst = MeshInstance3D.new()
        var key_mesh = BoxMesh.new()
        key_mesh.size = Vector3(0.15, 0.5, 0.08)
        mesh_inst.mesh = key_mesh
        mesh_inst.position = Vector3(0, 0.8, 0)

        var mat = StandardMaterial3D.new()
        mat.transmission_enabled = true
        mat.emission_enabled = true
        mat.emission_energy = 4.0

        match type:
                0:
                        mat.albedo_color = Color(0.9, 0.15, 0.15)
                        mat.emission = Color(1.0, 0.3, 0.3)
                1:
                        mat.albedo_color = Color(0.15, 0.3, 0.9)
                        mat.emission = Color(0.3, 0.4, 1.0)
                2:
                        mat.albedo_color = Color(0.15, 0.8, 0.15)
                        mat.emission = Color(0.3, 1.0, 0.3)
                3:
                        mat.albedo_color = Color(0.9, 0.8, 0.15)
                        mat.emission = Color(1.0, 0.9, 0.3)

        mesh_inst.set_surface_override_material(mat)
        area.add_child(mesh_inst)

        # Ring part of key
        var ring = MeshInstance3D.new()
        var ring_mesh = CylinderMesh.new()
        ring_mesh.top_radius = 0.12
        ring_mesh.bottom_radius = 0.12
        ring_mesh.height = 0.04
        ring.mesh = ring_mesh
        ring.position = Vector3(0, 1.1, 0)
        ring.set_surface_override_material(mat)
        area.add_child(ring)

        # Glow light
        var glow = OmniLight3D.new()
        glow.position = Vector3(0, 0.8, 0)
        glow.light_energy = 2.5
        glow.omni_range = 8.0
        match type:
                0: glow.light_color = Color(1, 0.3, 0.3)
                1: glow.light_color = Color(0.3, 0.3, 1)
                2: glow.light_color = Color(0.3, 1, 0.3)
                3: glow.light_color = Color(1, 0.9, 0.3)
        area.add_child(glow)

        # Floating animation script
        var float_script = GDScript.new()
        float_script.source_code = """
extends Node3D

var time: float = 0.0
var base_y: float = 0.0

func _ready():
        base_y = position.y

func _process(delta):
        time += delta
        position.y = base_y + sin(time * 2.0) * 0.15
        rotation.y += delta * 1.5
"""
        float_script.reload()
        mesh_inst.get_parent().set_script(float_script)

        # Label
        var label = Label3D.new()
        label.text = "[E] Pick up %s" % display_name
        label.position = Vector3(0, 1.5, 0)
        label.billboard = 1
        label.pixel_size = 0.02
        area.add_child(label)

        return area


func _place_escape_door():
        var door = StaticBody3D.new()
        door.collision_layer = 1 | 16
        door.collision_mask = 2
        door.add_to_group("escape_door")
        door.add_to_group("interactable")
        door.set_script(load("res://scripts/escape_door.gd"))

        # Door frame
        var door_col = CollisionShape3D.new()
        var box = BoxShape3D.new()
        box.size = Vector3(2.2, 2.8, 0.3)
        door_col.shape = box
        door.add_child(door_col)

        # Door mesh - double door
        var door_mesh = MeshInstance3D.new()
        var door_box = BoxMesh.new()
        door_box.size = Vector3(0.9, 2.6, 0.1)
        door_mesh.mesh = door_box
        door_mesh.position = Vector3(-0.5, 1.4, 0)
        door_mesh.set_surface_override_material(door_mat)
        door.add_child(door_mesh)

        var door_mesh2 = MeshInstance3D.new()
        var door_box2 = BoxMesh.new()
        door_box2.size = Vector3(0.9, 2.6, 0.1)
        door_mesh2.mesh = door_box2
        door_mesh2.position = Vector3(0.5, 1.4, 0)
        door_mesh2.set_surface_override_material(door_mat)
        door.add_child(door_mesh2)

        # Door frame
        var frame_mat = StandardMaterial3D.new()
        frame_mat.albedo_color = Color(0.25, 0.25, 0.23)
        frame_mat.roughness = 0.5
        frame_mat.metallic = 0.6

        # Top frame
        _create_frame_piece(door, Vector3(0, 2.85, 0), Vector3(2.4, 0.15, 0.2), frame_mat)
        # Left frame
        _create_frame_piece(door, Vector3(-1.15, 1.4, 0), Vector3(0.15, 2.85, 0.2), frame_mat)
        # Right frame
        _create_frame_piece(door, Vector3(1.15, 1.4, 0), Vector3(0.15, 2.85, 0.2), frame_mat)

        # EXIT sign above door (glowing green)
        var exit_sign_mat = StandardMaterial3D.new()
        exit_sign_mat.albedo_color = Color(0, 0.3, 0)
        exit_sign_mat.emission_enabled = true
        exit_sign_mat.emission = Color(0, 1, 0)
        exit_sign_mat.emission_energy = 3.0
        var exit_sign = MeshInstance3D.new()
        var es_mesh = BoxMesh.new()
        es_mesh.size = Vector3(0.8, 0.25, 0.05)
        exit_sign.mesh = es_mesh
        exit_sign.set_surface_override_material(exit_sign_mat)
        exit_sign.position = Vector3(0, 3.1, 0.15)
        door.add_child(exit_sign)

        # Red door light
        var door_light = OmniLight3D.new()
        door_light.position = Vector3(0, 2.5, 0)
        door_light.light_color = Color(1, 0.2, 0.1)
        door_light.light_energy = 1.5
        door_light.omni_range = 6.0
        door.add_child(door_light)

        # Label
        var door_label = Label3D.new()
        door_label.text = "ESCAPE"
        door_label.position = Vector3(0, 3.3, 0.15)
        door_label.billboard = 1
        door_label.pixel_size = 0.02
        door_label.modulate = Color(0, 1, 0)
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


func _create_frame_piece(parent: Node3D, position: Vector3, size: Vector3, material: Material):
        var mesh_inst = MeshInstance3D.new()
        var box_mesh = BoxMesh.new()
        box_mesh.size = size
        mesh_inst.mesh = box_mesh
        mesh_inst.set_surface_override_material(material)
        mesh_inst.position = position
        parent.add_child(mesh_inst)
