extends Node3D
## GameScene - Mobile-optimized game scene
## NO NavigationMesh baking (causes freeze)
## NO AudioStreamGenerator (causes crash)
## Ghost uses direct movement
## Proper horror atmosphere

@export var use_ai_ghost: bool = true

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const GHOST_PLAYER_SCENE = preload("res://scenes/ghost_player.tscn")
const GHOST_AI_SCENE = preload("res://scenes/ghost_ai.tscn")

var player_spawn_points: Array[Marker3D] = []
var ghost_spawn_point: Marker3D = null
var map_generator: Node3D = null
var players_container: Node3D = null
var items_container: Node3D = null
var hud: CanvasLayer = null
var touch_controls: CanvasLayer = null


func _ready():
        players_container = Node3D.new()
        players_container.name = "Players"
        add_child(players_container)

        items_container = Node3D.new()
        items_container.name = "Items"
        add_child(items_container)

        # Generate hospital map
        map_generator = Node3D.new()
        map_generator.name = "Map"
        map_generator.set_script(load("res://scripts/map_generator.gd"))
        add_child(map_generator)

        await get_tree().process_frame

        # Spawn points
        _find_spawn_points()

        # Environment
        _setup_environment()

        # HUD
        _setup_hud()

        # Touch controls (always create for mobile)
        _setup_touch_controls()

        # Connect game state
        GameManager.game_state_changed.connect(_on_game_state_changed)

        # Start game with AI ghost
        if use_ai_ghost:
                GameManager.set_local_role("human")
                GameManager.start_gameplay()
                _spawn_player(1)
                _spawn_ai_ghost()


func _find_spawn_points():
        var positions = [Vector3(0, 0, 0), Vector3(-5, 0, 0), Vector3(5, 0, 0)]
        for i in range(positions.size()):
                var s = Marker3D.new()
                s.position = positions[i]
                s.name = "SpawnPoint%d" % i
                add_child(s)
                player_spawn_points.append(s)

        ghost_spawn_point = Marker3D.new()
        ghost_spawn_point.position = Vector3(0, 0, -10)
        ghost_spawn_point.name = "GhostSpawnPoint"
        add_child(ghost_spawn_point)


func _setup_environment():
        var world_env = WorldEnvironment.new()
        world_env.name = "WorldEnvironment"

        var env = Environment.new()
        env.background_mode = Environment.BG_COLOR
        env.background_color = Color(0.02, 0.02, 0.04, 1)

        # Ambient light - MUST be bright enough to see on mobile!
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.35, 0.30, 0.35, 1)
        env.ambient_light_energy = 4.0

        # Fog - very light, just for atmosphere, NOT blocking visibility
        env.fog_enabled = true
        env.fog_light_color = Color(0.08, 0.07, 0.10, 1)
        env.fog_density = 0.005
        env.fog_depth_begin = 15.0
        env.fog_depth_end = 50.0

        # Tone mapping - higher exposure for mobile visibility
        env.tonemap_mode = Environment.TONE_MAPPER_ACES
        env.tonemap_exposure = 1.8

        # Disable expensive effects for mobile
        env.glow_enabled = false
        env.ssao_enabled = false
        env.ssr_enabled = false
        env.sdfgi_enabled = false

        world_env.environment = env
        add_child(world_env)

        # Moonlight - brighter for mobile visibility
        var dir = DirectionalLight3D.new()
        dir.light_energy = 0.8
        dir.light_color = Color(0.5, 0.5, 0.7)
        dir.rotation = Vector3(deg_to_rad(-70), deg_to_rad(25), 0)
        dir.shadow_enabled = false
        add_child(dir)


func _setup_hud():
        hud = CanvasLayer.new()
        hud.set_script(load("res://scripts/hud.gd"))
        add_child(hud)


func _setup_touch_controls():
        touch_controls = CanvasLayer.new()
        touch_controls.set_script(load("res://scripts/touch_controls.gd"))
        add_child(touch_controls)


func _on_game_state_changed(new_state):
        if new_state == GameManager.GameState.GAME_OVER:
                _show_game_over("ghost")
        elif new_state == GameManager.GameState.ESCAPED:
                _show_game_over("human")


func _spawn_player(peer_id: int):
        var player = PLAYER_SCENE.instantiate()
        player.name = "Player_%d" % peer_id
        if player_spawn_points.size() > 0:
                player.global_position = player_spawn_points[0].global_position
                player.position.y = 0.5
        players_container.add_child(player)
        player.setup_as_local(peer_id)
        player.add_to_group("player")

        # Add visible body mesh for the player (other players / ghost can see)
        _add_player_body(player)


func _add_player_body(player: CharacterBody3D):
        ## Add a simple 3D body mesh to the player
        var body_node = player.get_node_or_null("BodyMesh")
        if body_node and body_node is MeshInstance3D:
                var capsule = CapsuleMesh.new()
                capsule.radius = 0.3
                capsule.height = 1.4
                body_node.mesh = capsule
                var body_mat = StandardMaterial3D.new()
                body_mat.albedo_color = Color(0.25, 0.22, 0.2)
                body_mat.roughness = 0.9
                body_node.set_surface_override_material(body_mat)

        # Add head sphere
        var head_visual = MeshInstance3D.new()
        var head_mesh = SphereMesh.new()
        head_mesh.radius = 0.18
        head_mesh.height = 0.3
        head_visual.mesh = head_mesh
        head_visual.position = Vector3(0, 1.55, 0)
        var head_mat = StandardMaterial3D.new()
        head_mat.albedo_color = Color(0.6, 0.5, 0.45)
        head_mat.roughness = 0.8
        head_visual.set_surface_override_material(head_mat)
        player.add_child(head_visual)


func _spawn_ai_ghost():
        var ghost = GHOST_AI_SCENE.instantiate()
        ghost.name = "GhostAI"
        if ghost_spawn_point:
                ghost.global_position = ghost_spawn_point.global_position
                ghost.position.y = 0.5
        players_container.add_child(ghost)


func _show_game_over(winner: String):
        var overlay = ColorRect.new()
        overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        overlay.color = Color(0.3, 0, 0, 0.85) if winner == "ghost" else Color(0, 0.25, 0, 0.85)
        get_tree().root.add_child(overlay)

        var label = Label.new()
        label.set_anchors_preset(Control.PRESET_FULL_RECT)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 42)
        if winner == "ghost":
                label.text = "THE GHOST GOT YOU!"
                label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
        else:
                label.text = "YOU ESCAPED!"
                label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))
        get_tree().root.add_child(label)

        var sub_label = Label.new()
        sub_label.set_anchors_preset(Control.PRESET_FULL_RECT)
        sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        sub_label.offset_top = 60
        sub_label.add_theme_font_size_override("font_size", 20)
        if winner == "ghost":
                sub_label.text = "Better luck next time..."
                sub_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))
        else:
                sub_label.text = "You found all the keys and escaped!"
                sub_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
        get_tree().root.add_child(sub_label)

        var btn = Button.new()
        btn.text = "BACK TO MENU"
        btn.position = Vector2(get_viewport().size.x / 2 - 90, get_viewport().size.y / 2 + 80)
        btn.size = Vector2(180, 45)
        # Horror style button
        var btn_style = StyleBoxFlat.new()
        btn_style.bg_color = Color(0.15, 0.04, 0.04, 0.9)
        btn_style.border_color = Color(0.6, 0.15, 0.1)
        btn_style.border_width_bottom = 2
        btn_style.border_width_top = 2
        btn_style.border_width_left = 2
        btn_style.border_width_right = 2
        btn_style.corner_radius_top_left = 5
        btn_style.corner_radius_top_right = 5
        btn_style.corner_radius_bottom_left = 5
        btn_style.corner_radius_bottom_right = 5
        btn.add_theme_stylebox_override("normal", btn_style)
        btn.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
        btn.pressed.connect(func(): GameManager.return_to_menu())
        get_tree().root.add_child(btn)
